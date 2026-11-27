# 第 21 章　确定性资源释放

Scoop 有 GC，不再使用的对象会被自动回收，写程序时不用操心 `free`。但 GC 只负责**内存**。程序还会占用很多内存之外的东西：打开的文件、网络连接、文件锁、子进程、C 库分配的句柄。这些东西统称为**资源**，它们有两个共同点：

- **数量有限，或者别人在等。** 一个进程能同时打开的文件数有上限；数据库连接池里的连接是有数的；你持有的文件锁会让其他进程一直等下去。
- **释放的时机有意义。** 写文件时，缓冲区里的数据要在关闭时写出去；锁要在操作完成后立刻放开，而不是“将来某个时候”。

GC 什么时候回收一个对象是不确定的，可能是几毫秒后，也可能直到程序退出都不回收。所以资源不能交给 GC，而要在**确定的时间点**显式释放，这就是本章标题中“确定性”的含义。这一点和 Kotlin/JVM 完全一样：在 Kotlin 中你也要用 `use { }` 关闭流，而不是指望 finalizer。

本章介绍：

- `Closeable`、`Disposable` 接口与 `use` 函数；
- 怎样实现一个资源类；
- 同时使用多个资源时的写法和清理顺序；
- 正文和清理都失败时的 `ResourceUseException`；
- `use` 作为普通函数带来的限制；
- 库 API 中“谁负责关闭”的命名约定：`withX`、`takeX`、`takeOwnership`；
- 兜底的 `release` 块。

## 21.1　`Closeable` 与 `use`

```scoop
{{#include ../../examples/ch21/connection.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/connection.expected}}
```

`Closeable` 是核心库中的接口，不需要 import。实现它只需要提供一个 `close()` 方法，因为它是 public 接口的成员，要写 `public override`（第 14 章）。

`use` 是核心库为所有资源提供的扩展函数：它把资源本身作为参数调用 lambda，lambda 结束后**一定**关闭资源，不论 lambda 是正常返回还是抛出了异常。具体来说：

- `use` 的结果就是 lambda 的结果，所以 `row` 得到了查询结果。注意输出中 `close db1` 出现在 `db1: select 1` 之前：`use` 先关闭连接，再把结果交给 `println`。
- lambda 抛出异常时，`use` 先关闭资源，再把**同一个**异常继续抛出。`db2` 的查询失败了，但它仍然被关闭了。
- `use` 结束后，变量 `conn` 仍然指向那个对象，对象也没有消失（它的内存由 GC 管理），只是已经关闭了。再次使用它应该报错，这是 `Connection` 自己的 `query` 检查 `closed` 实现的，`use` 不会替你做这件事。

`use` 大致相当于取得资源之后写 `try { 调用 lambda } finally { 关闭资源 }`，但它比手写的 `try`/`finally` 多做了一件事：正文和关闭**都**失败时，两个异常都不会丢失（21.4），而第 19 章讲过，`finally` 中抛出的异常会把原来的异常顶掉。所以需要关闭资源时，优先用 `use`。

`use` 只能用在实现了 `Disposable` 的类型上（`Closeable` 是它的子接口，下一节介绍）。仅仅有一个名叫 `close` 的方法是不够的：

```scoop
{{#include ../../examples/ch21/use_type_fail.scoop}}
```

```text
{{#include ../../examples/ch21/use_type_fail.error}}
```

真正的原因是第二条报错：`Socket` 不满足 `Disposable` 约束。第一条报错说的是挂起函数，看起来毫不相干，它来自 `use` 的另一个重载：核心库还有一个接受挂起 lambda 的 `use`（用于协程，第 25 章），编译器在普通版本失败后尝试了它，又因为 `main` 不是挂起函数而失败。以后看到“suspend function `use` cannot be called”，先检查后面的报错。

文件、网络连接等标准库资源都实现了 `Closeable`。读写真实文件的完整例子可以运行 `scoop example io/resources` 查看，第 31 章会详细介绍文件 API。

## 21.2　`Disposable` 与资源类的写法

核心库中有两个资源接口：

```scoop
public interface Disposable {
    public fun dispose()
}

public interface Closeable : Disposable {
    public fun close()
    public override fun dispose() { close() }
}
```

`Disposable` 表示“用完后需要清理”的一般资源；`Closeable` 是它的子接口，用于清理动作自然地叫作“关闭”的资源，它的 `dispose` 默认就是调用 `close`。`use` 只认 `Disposable`，所以对两者都能用。

选择哪一个，看清理动作叫什么：

- 文件、socket、管道、C 库的句柄等，清理就是“关闭”，实现 `Closeable`，并提供 `isClosed` 属性表示是否已关闭；
- 取消订阅、释放锁、注销回调、线程等，清理不是“关闭”，实现 `Disposable`。`scoop.platform` 的 `Mutex`、`Thread` 就是这样。

下面是一个 `Disposable` 的例子：订阅事件后得到一个 `Subscription`，`dispose` 就是取消订阅。

```scoop
{{#include ../../examples/ch21/subscription.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/subscription.expected}}
```

`audit` 订阅只在 `use` 期间有效，所以只收到了 `login`；`logger` 是手动 `dispose` 的，之后的 `ignored` 没有任何订阅者收到。

从 `Connection` 和 `Subscription` 可以总结出实现资源类的几条规则：

- **重复释放是无操作。** 第二次调用 `close` 或 `dispose` 时什么也不做，而不是报错或者再释放一次。两个例子都用一个状态字段做到了这一点。
- **先改状态，再做实际的清理。** `close` 一开始就把 `closed` 设为 `true`，然后才执行清理。这样即使清理本身抛出异常，再次调用 `close` 也不会重复释放同一个资源。
- **关闭之后的操作报错。** 关闭后调用 `query` 抛出 `IllegalStateException`，而不是静默地返回一个错误的结果。标准库的 `File`、`BufferedSink` 等资源也是这样。
- **只释放自己拥有的东西。** 一个资源类关闭时，只清理它自己创建或者明确接管的资源，不去关闭别人借给它的对象（21.6）。
- **`close` 是普通的方法。** 它可以抛出异常，也可以阻塞（比如等待数据写出）。

还有一条容易忽略的：**构造器中途失败时，要自己清理已经取得的资源。** 如果一个类的构造器先打开了文件 A，再打开文件 B，而打开 B 失败了，构造器抛出异常，调用方根本拿不到这个对象，也就无法调用 `close`。这时文件 A 必须由构造器自己在抛出异常之前关闭。

## 21.3　同时使用多个资源

需要同时使用多个资源时，嵌套地使用 `use`：

```scoop
{{#include ../../examples/ch21/nested.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/nested.expected}}
```

- **清理顺序与打开顺序相反。** `a.txt` 先打开，后关闭；`b.txt` 后打开，先关闭。这通常正是你想要的：后打开的资源可能依赖先打开的资源，比如在连接上开启的事务，要先于连接结束。
- **后一个资源打开失败时，前一个仍然会被关闭。** 打开 `d.txt` 失败时，异常从内层传出，经过外层的 `use`，`c.txt` 被正确关闭。
- **`copyLeaky` 是错误的写法。** 它先把两个资源都打开，再进入 `use`。打开 `f.txt` 失败时，`e.txt` 已经打开，但还没有进入任何 `use`，于是永远不会被关闭。输出中只有 `open e.txt`，没有对应的 `close`。

规则是：**一取得资源，就立刻交给 `use`**，写成 `Resource(...).use { ... }` 或者 `File.open(...).use { ... }`，中间不要插入其他可能失败的代码。

> **从 Kotlin 过来**
>
> Java 的 try-with-resources 可以在一个 `try (...)` 中写多个资源，Kotlin 没有对应的语法，也是嵌套 `use`。Scoop 和 Kotlin 一样。

## 21.4　正文和清理都失败

`use` 的正文和清理各自可能成功或失败，一共四种组合：

```scoop
{{#include ../../examples/ch21/double_failure.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/double_failure.expected}}
```

| 正文 | 清理 | `use` 的结果 |
| --- | --- | --- |
| 正常返回 | 成功 | 返回正文的结果 |
| 抛出异常 | 成功 | 重新抛出正文的异常 |
| 正常返回 | 抛出异常 | 抛出清理的异常 |
| 抛出异常 | 抛出异常 | 抛出 `ResourceUseException`，同时保存两个异常 |

最后一种情况下，两个异常都很重要：正文的异常说明出了什么问题，清理的异常说明资源可能没有被正确释放。`use` 不会丢掉其中任何一个，而是抛出一个新的 `ResourceUseException`：

- `primaryFailure` 是正文抛出的异常；
- `cleanupFailure` 是清理时抛出的异常；
- 它的 `message` 是 `resource body and cleanup both failed`。

两个字段的类型是 `Throwable`，保存的就是原来的异常对象。`ResourceUseException` 是 `Exception` 的子类，`catch (e: Exception)` 也能捕获它。

这带来一个容易出错的地方：**只捕获正文异常类型的 `catch` 会漏掉这种情况。**

```scoop
{{#include ../../examples/ch21/missed_catch.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/missed_catch.expected}}
```

内层的 `catch (e: IllegalArgumentException)` 本意是处理 `bad input`，但关闭同时失败了，`use` 抛出的是 `ResourceUseException`，内层的 `catch` 匹配不上，异常传到了外层。资源的 `close` 可能失败时，要么在外层单独处理 `ResourceUseException`，要么用 `catch (e: Exception)` 兜底。

嵌套 `use` 时，每一层都按这个规则处理，所以 `ResourceUseException` 也可能嵌套：内层两次失败得到的 `ResourceUseException`，作为外层的正文异常，再和外层的清理异常组合在一起。

> **从 Kotlin 过来**
>
> Kotlin 的 `use` 在两次都失败时，抛出的是**正文的异常**，清理的异常通过 `addSuppressed` 附加在它上面，可以用 `e.suppressed` 读到。所以在 Kotlin 中，`catch (e: IllegalArgumentException)` 仍然能接住它。Scoop 的异常没有 suppressed 列表，`use` 抛出的是一个新的 `ResourceUseException`，异常的类型变了。

## 21.5　`use` 是一个普通函数

`use` 没有任何特殊的语法地位，它就是核心库中一个普通的泛型扩展函数，lambda 也是普通的 lambda。这意味着第 7 章关于 lambda 的规则在这里全部适用，其中最常遇到的是：**lambda 中不能用 `return` 从外层函数返回。**

```scoop
{{#include ../../examples/ch21/use_return_fail.scoop}}
```

```text
{{#include ../../examples/ch21/use_return_fail.error}}
```

第一条报错又是那个误导性的挂起重载，真正的原因是第二条。改法是利用“`use` 的结果就是 lambda 的结果”：

```scoop
{{#include ../../examples/ch21/use_return.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/use_return.expected}}
```

- 函数的结果就是 `use` 的结果时，直接 `return Config().use { ... }`，或者像 `firstLine` 那样写成表达式体。
- 需要在 lambda 中途结束时，用 `return@use`，它只结束 lambda，`use` 照常关闭资源，并把这个值作为结果。

另外几点：

- `use` 不检查资源是否已经关闭，也不会阻止你在 `use` 结束后继续使用这个对象。在 lambda 之外保存资源的引用，再在 `use` 结束后使用它，得到的是一个已关闭的资源。
- `use` 不会让资源变得线程安全，多个线程同时使用同一个资源仍然要自己同步（第 27 章）。
- `use` 只管同步的清理。协程中正文可以挂起时，有对应的 `use` 重载；清理本身也需要挂起的资源实现 `AsyncCloseable`，配合 `useAsync` 使用（第 26 章）。

> **从 Kotlin 过来**
>
> Kotlin 的 `use` 是 `inline` 函数，lambda 中的 `return` 会直接从外层函数返回，所以 Kotlin 代码里常见 `reader.use { return it.readLine() }`。Scoop 没有非局部返回，要写成 `return reader.use { it.readLine() }`，或者在 lambda 中用 `return@use`。

## 21.6　谁负责关闭：`withX`、`takeX`、`takeOwnership`

资源的规则说起来简单：用完了就关闭。真正容易出错的问题是：**这个资源该由谁关闭？** 一个对象把资源交给另一个对象时，可能只是“借给它用一下”，也可能是“交给它全权负责”。两者弄混了，要么资源被关了两次、或者在别人还在用的时候被关掉，要么谁都没有关。

Scoop 的库用命名约定来回答这个问题：

| 命名 | 含义 | 例子 |
| --- | --- | --- |
| `withX { ... }` | **作用域借用**：在 block 执行期间使用 X，结束时由 `withX` 负责收尾 | `File.withLock { }`：持有文件锁，结束时解锁 |
| `takeX()` | **取走**：把一个对象原本负责的资源拿出来，之后由你负责关闭 | `ChildProcess.takeStdout()`：取出子进程的标准输出管道 |
| `takeOwnership(x)` | **接管**：你传入的资源交给新对象，新对象关闭时一并关闭它 | `BufferedSink.takeOwnership(file)` |
| 普通构造器 | 通常是**借用**：新对象使用你传入的资源，但不关闭它 | `BufferedSink(file)` |

下面的例子用真实的文件演示了这几种关系：

```scoop
{{#include ../../examples/ch21/ownership.scoop}}
```

输出：

```text
{{#include ../../examples/ch21/ownership.expected}}
```

`scoop.platform` 不在单文件程序默认可用的库中，所以第一行用 `//! dep:` 声明了依赖（第 28 章）。程序依次演示了：

- **借用。** `BufferedSink(file)` 是一个带缓冲的写入器，它借用 `file`。关闭 `buffered` 时，它把缓冲区中的数据写出去，释放自己的缓冲区，但不关闭 `file`。所以之后 `file.isClosed` 是 `false`，还能继续写入。`file` 由外面的 `withAppendFile` 负责关闭。
- **接管。** `BufferedSink.takeOwnership(file)` 成功返回之后，关闭 `file` 的责任就转移给了 `owned`：关闭 `owned` 时，`file` 也被关闭了。这时你不应该再单独关闭 `file`，更不应该在 `owned` 之外继续使用它。
- **作用域借用。** `f.withLock { ... }` 在执行 block 之前加锁，block 结束后解锁，不论 block 是否抛出异常；正文和解锁都失败时，同样抛出 `ResourceUseException`。
- **自己写的 `withX`。** `withAppendFile` 打开文件，把它借给 block，结束时关闭。它的实现只有一行，就是 `File.open(...).use(block)`：把函数类型的参数 `block` 直接传给 `use`。

`withX` 形式的函数对调用方最友好：调用方不可能忘记关闭，也不可能在作用域之外使用资源（除非刻意把引用保存下来）。如果你写的 API 需要让调用方使用一个资源，优先提供这种形式。

> **注意**：`withX` 这个名字只在**接受 block 的资源函数**中表示作用域借用。`withIndex()`、`withPadding(...)` 这类函数和资源无关，前者是惰性的迭代变换，后者返回修改了某项配置的新值。

### `close` 不代表一切都完成了

`close` 只执行这个类型自己规定的本地清理。“数据写出去了”“压缩流结束了”“数据已经落盘了”往往是**另外的**步骤：

- `BufferedSink.close` 会先把缓冲区的数据写出，再释放资源；但对于一般的写入器，要确认数据已经交给下一层，应该显式调用 `flush`。
- `File.close` 成功不代表数据已经写入磁盘，需要持久化保证时，先调用 `syncAll`。
- 压缩格式需要写出结尾，网络协议需要正常关闭，这些动作在各自的库中有专门的方法，例如 `finish`、`shutdownGracefully`。

使用一个资源时，看它的文档说明 `close` 做什么、不做什么。

> **深入一点：`release` 块**
>
> 如果使用者忘记了 `close`，资源会不会永远泄漏？对于封装 C 库句柄的类，Scoop 提供了一个兜底机制：在 final class 中写一个 `release { ... }` 块，它会在对象被 GC 回收之前尽力执行一次，释放还没有释放的 C 资源。
>
> 它的限制非常严格：块中没有 `this`，只能读取本类自己声明的、不含引用的字段，不能分配对象、不能抛出或捕获异常、不能调用普通的 Scoop 函数，只能在 `@Unsafe` 中调用 C 函数。更重要的是，它是“尽力而为”的：不保证什么时候执行、在哪个线程执行，程序退出时也不会补做。
>
> 所以 `release` 只是安全网，不能代替 `close` 和 `use`，也不能用来刷新缓冲区、提交事务或释放锁。普通的应用代码不需要写它。第 36 章 36.9 节有一个完整的例子，说明怎样把 C 句柄封装成同时有 `close` 和 `release` 的 class。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `AutoCloseable` / `java.io.Closeable` | `Closeable`（core，无需 import） |
| 非“关闭”语义的清理 | `Disposable`，方法是 `dispose()` |
| `override fun close()` | `public override fun close()` |
| `resource.use { ... }` | 相同 |
| `reader.use { return it.readLine() }` | `return reader.use { it.readLine() }`，或在 lambda 中 `return@use`（21.5） |
| 两次失败时 `e.suppressed` | 抛出 `ResourceUseException`，读取 `primaryFailure`、`cleanupFailure`（21.4） |
| try-with-resources 的多个资源 | 嵌套 `use`（21.3） |
| `finalize()`、`Cleaner` | `release { }` 块，只用于 C 资源的兜底（第 36 章） |
| `Mutex.withLock { }`（kotlinx） | 标准库的 `withLock`，以及 `scoop.concurrent` 的异步锁（第 27 章） |

## 常见误用

- **依赖 GC 关闭资源**：GC 只回收内存，回收的时间也不确定。用 `use` 或 `withX`。
- **先取得几个资源，再进入 `use`**：中间失败时，已经取得的资源会泄漏。每取得一个，立刻交给 `use`（21.3）。
- **只写 `close` 方法，不实现接口**：`use` 只认 `Disposable`。
- **在 `use` 的 lambda 中写 `return`**：Scoop 没有非局部返回，让 `use` 的结果作为返回值，或者用 `return@use`。
- **被“suspend function `use` cannot be called”误导**：这通常不是协程的问题，先看后面的报错。
- **只捕获正文的异常类型**：正文和关闭都失败时抛出的是 `ResourceUseException`（21.4）。
- **关闭了借来的资源，或者没有关闭接管的资源**：按 `withX`、`takeX`、`takeOwnership` 的约定判断谁负责关闭。
- **`close` 不是幂等的**：重复调用 `close` 应该什么都不做。
- **在 `use` 结束后继续使用资源**：对象还在，但已经关闭了。
- **以为 `close` 就完成了 flush、持久化或协议收尾**：看清资源的文档，需要时显式调用对应的方法。

## 小结

- GC 只管内存。文件、连接、锁等资源要在确定的时间点显式释放。
- `Disposable` 表示需要清理的资源，方法是 `dispose`；`Closeable` 是它的子接口，方法是 `close`。实现时写 `public override`。
- `use` 调用 lambda，结束时一定释放资源，结果就是 lambda 的结果；正文和清理都失败时抛出 `ResourceUseException`，保存两个异常。
- 资源类的 `close` 应该是幂等的：先改状态再清理，关闭后的操作抛出 `IllegalStateException`，只释放自己拥有的资源。
- 多个资源嵌套使用 `use`，清理顺序与打开顺序相反；取得资源后立刻交给 `use`。
- `use` 是普通函数，lambda 中不能 `return`；用 `use` 的结果或 `return@use`。
- `withX` 表示作用域借用，`takeX` 表示取走，`takeOwnership` 表示接管；普通构造器通常只是借用。
- `release` 块只是 C 资源的兜底，不能代替 `close`。

## 练习

1. 写一个 `Timer` 类，实现 `Disposable`：创建时记下名字并打印 `start <名字>`，`dispose` 时打印 `stop <名字>`。用嵌套的 `use` 验证 21.3 所说的清理顺序。
2. 给 21.1 的 `Connection` 增加一个 `transaction()` 方法，返回一个实现了 `Closeable` 的 `Transaction`：`commit()` 提交，`close()` 时如果还没有提交就回滚。用 `use` 写一个“正文抛出异常时自动回滚”的例子。思考：`Transaction` 关闭时应不应该关闭它所属的 `Connection`？
3. 修改 21.4 的 `Flaky`，让它的 `close` 第一次调用时抛出异常，以后的调用什么都不做。在 `use` 结束后再手动调用一次 `close`，观察结果。这个设计符合 21.2 中“先改状态，再做实际的清理”这一条吗？
4. 写一个函数 `fun <R> withTempDirectory(block: (Path) -> R): R`：创建临时目录，把路径交给 block，结束时删除整个目录。提示：参考 `ownership.scoop` 中 `try`/`finally` 的用法。为什么这里用 `try`/`finally` 而不是 `use`？
