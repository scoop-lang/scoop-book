# 第 19 章　异常

前面的章节已经多次用到异常：整数除以零会抛出 `ArithmeticException`（第 3 章），`step 0` 会抛出 `IllegalArgumentException`（第 5 章），`!!` 遇到 `None` 会抛出 `UnwrapException`（第 12 章）。当时只是用 `try`/`catch` 把它们接住，没有细说。本章把异常讲完整。

Scoop 的异常模型和 Kotlin 几乎一样：用 `throw` 抛出，用 `try`/`catch`/`finally` 处理，`try` 是表达式，也**没有受检异常**，函数签名里不声明会抛出什么，编译器也不强迫调用方处理。从 Kotlin 过来的读者需要留意的是几处细节：异常消息的类型是 `String?`，`Exception` 没有 `cause`，内置的异常类不能继承，未捕获异常的报告里不包含消息。

本章介绍：

- `throw`、`try`/`catch`/`finally` 的规则，以及 `try` 作为表达式的用法；
- `finally` 什么时候执行、什么时候不执行；
- 核心库的异常层级；
- 异常消息和构造参数；
- 怎样设计自定义异常；
- 未捕获的异常会发生什么，以及怎样在程序边界统一处理异常。

## 19.1　抛出与捕获

```scoop
{{#include ../../examples/ch19/ports.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/ports.expected}}
```

这个程序把一段文本解析成端口号。它涉及异常处理的三个基本动作：

- **抛出。** `throw` 后面跟一个异常对象。执行到 `throw` 时，当前函数立即停止，异常沿着调用链向外传递，直到遇到能处理它的 `catch`。`parsePort` 里有两处会抛出异常：`text.toInt()` 在文本不是整数时抛出 `NumberFormatException`，范围检查不通过时由 `throw` 抛出 `IllegalArgumentException`。`throw` 表达式的类型是 `Nothing`（第 6 章），所以它可以出现在任何需要值的地方，比如 `?:` 的右侧。
- **捕获。** `try` 后面可以跟多个 `catch`。异常发生时，按书写顺序逐个检查 `catch` 的类型，执行**第一个**匹配的分支。“匹配”的意思是异常对象 `is` 这个类型，子类也算。在分支里，`e` 就是这个类型的值，可以读取它的成员。
- **收尾。** `finally` 块无论 `try` 是正常结束还是抛出了异常，都会执行。三次调用都打印了 `-- checked`。

`toInt` 和 `NumberFormatException` 都在 `scoop.text` 包中，所以文件开头写了 `import scoop.text.*`。

因为 `catch` 按顺序匹配，范围大的类型要写在后面。把 `Exception` 写在 `NumberFormatException` 前面，后者就永远轮不到，编译器会报错：

```scoop
{{#include ../../examples/ch19/catch_order_fail.scoop}}
```

```text
{{#include ../../examples/ch19/catch_order_fail.error}}
```

`throw` 和 `catch` 的类型都必须是 `Throwable` 的子类型。不能像某些语言那样直接抛出一个字符串：

```scoop
{{#include ../../examples/ch19/throw_string_fail.scoop}}
```

```text
{{#include ../../examples/ch19/throw_string_fail.error}}
```

和 Kotlin 一样，Scoop 不要求在函数签名中声明可能抛出的异常。一个函数会抛出哪些异常、在什么情况下抛出，只能写在文档注释里（第 18 章）。标准库的文档注释通常会写明这一点，比如 `toInt` 的说明里写了解析失败时抛出 `NumberFormatException`。

## 19.2　`try` 是表达式

和 `if`、`when` 一样，`try` 可以产生一个值：

```scoop
{{#include ../../examples/ch19/try_expr.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/try_expr.expected}}
```

规则如下：

- `try` 块正常结束时，整个表达式的值是 `try` 块最后一个表达式的值；抛出异常并被某个 `catch` 处理时，值是这个 `catch` 块最后一个表达式的值。所以 `portOrDefault("auto")` 得到 `8080`。
- `catch` 块也可以不提供值，而是 `return` 或者 `throw`。这两个表达式的类型都是 `Nothing`，不影响整个 `try` 的类型。`timeoutSeconds("soon")` 就是从 `catch` 块里直接返回了 `30`。
- `finally` 块**不参与**求值，它的最后一个表达式会被丢掉。`finally` 只用来做收尾的副作用，这里是打印一行日志。注意 `timeoutSeconds("soon")` 从 `catch` 中返回时，`finally` 照样执行了。

`portOrDefault` 这样“解析失败就用默认值”的写法，用第 12 章的 `"auto".toIntOrNone() ?: 8080` 更直接。`try` 表达式适合用在只有抛异常版本的 API 上，或者需要区分不同异常类型的场合。什么时候该用 `Option`，什么时候该用异常，第 20 章会专门讨论。

## 19.3　`finally`

`finally` 的用途是“不管发生什么，这段代码都要执行”。离开 `try` 有三种方式：正常执行完、抛出异常、用 `return`（或 `break`、`continue`）跳出。三种情况下 `finally` 都会执行：

```scoop
{{#include ../../examples/ch19/finally.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/finally.expected}}
```

几个细节：

- `early` 的情况里，`return` 的值先计算好，再执行 `finally`，最后才真正返回。所以 `cleanup after early` 出现在 `result: returned early` 之前。
- `fail` 的情况里，`finally` 在异常继续向外传递之前执行，然后异常才到达 `main` 中的 `catch`。
- 如果 `catch` 块里又抛出了新的异常，`finally` 仍然会执行，之后向外传递的是新异常。

**不要在 `finally` 中写 `return`，也不要让 `finally` 抛出异常。** 两者都会让 `try` 中原来的异常消失：

```scoop
{{#include ../../examples/ch19/finally_return.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/finally_return.expected}}
```

`loadCount` 里的 `disk error` 异常被 `finally` 中的 `return 0` 丢弃了，调用方拿到的是一个看起来正常的 `0`。编译器不会对这种写法给出警告。同样，如果 `finally` 块本身抛出异常，这个新异常会取代原来的异常向外传递，原来的异常就丢失了。`finally` 中的清理代码本身可能失败时（比如关闭文件），应该交给第 21 章的 `use`，它会把两次失败都保留下来。

有一种情况 `finally` 不会执行：调用 `exit` 结束进程。

```scoop
{{#include ../../examples/ch19/exit_finally.scoop}}
```

```sh
$ scoop run exit_finally.scoop --release
saving
$ echo $?
3
```

`exit(code)` 是核心库提供的函数，返回类型是 `Nothing`。它刷新标准输出和标准错误后立即结束整个进程，不展开调用栈，所以不会执行任何 `finally`，也不会执行第 21 章介绍的资源清理。需要正常收尾的程序，应该让 `main` 返回一个 `Int` 作为退出码（第 2 章），而不是在深处调用 `exit`。19.7 会给出这种写法。

## 19.4　异常的类型层级

所有能被抛出的值都是 `Throwable` 的子类。核心库的异常层级很浅：

| 类型 | 什么时候出现 |
| --- | --- |
| `Throwable` | 所有可抛出值的共同基类，可以继承 |
| `Exception(message: String?)` | 通用的异常基类，可以继承；下面所有类型都是它的子类 |
| `IllegalArgumentException` | 参数不满足函数的要求，例如 `step 0` |
| `IllegalStateException` | 对象当前的状态不允许这个操作，例如读取已经关闭的资源 |
| `UnwrapException` | `!!` 遇到 `None`（第 12 章） |
| `ClassCastException` | `as` 转换失败（第 14 章） |
| `ArithmeticException` | 整数除以零或对零取余（第 3 章） |
| `IndexOutOfBoundsException` | 数组下标越界 |
| `CharacterCodingException` | 严格 UTF-8 解码失败，`byteOffset` 记录第一个非法字节的位置 |
| `ResourceUseException` | `use` 的正文和清理都失败了（第 21 章） |
| `CancellationException` | 协程任务被取消（第 25 章） |

它们都不需要 import。各个库还定义了自己的异常，放在各自的包里，例如：

- `scoop.text` 的 `NumberFormatException`：`toInt`、`toDouble` 等解析失败；
- `scoop.collections` 的 `NoSuchElementException`：对空集合取 `first()` 之类的操作；
- `scoop.platform.system` 的 `PlatformException`：文件、进程等系统操作失败，它带有一个 `kind` 字段说明失败的类别（第 31 章）。

使用一个库时，它的 API 文档会写明会抛出哪些异常。

`catch (e: Exception)` 能接住上面所有的异常，是最常用的“兜底”写法。`catch (e: Throwable)` 范围更大，还能接住直接继承 `Throwable` 而不继承 `Exception` 的类型，但这样的类型很少见，普通代码不需要定义它。

有些失败**不是异常**，无法用 `catch` 处理：内存耗尽这类致命错误，以及语言层面的 trap（运行时检测到的、无法恢复的错误）会直接终止进程，不执行 `finally`。`exit` 也是这样。

> **从 Kotlin 过来**
>
> Kotlin/JVM 有 `Exception` 和 `Error` 两个分支，`OutOfMemoryError`、`StackOverflowError` 属于后者，理论上可以被 `catch (e: Throwable)` 捕获。Scoop 没有 `Error` 分支，也没有可捕获的内存耗尽异常，这类问题会直接结束进程。另外，Kotlin 的 `IOException` 层级在 Scoop 中对应各个库自己的异常类型，比如 `PlatformException`，并不存在一个统一的 IO 异常基类。

## 19.5　异常消息

`Exception` 的 `message` 属性类型是 `String?`，因为异常不一定带消息。构造异常时也要按这个类型传参：

```scoop
{{#include ../../examples/ch19/messages.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/messages.expected}}
```

- `Exception` 的构造器**必须**传一个 `String?`，没有默认值。有消息时写 `Some("...")`，明确不带消息时写 `None`。
- `IllegalArgumentException` 和 `IllegalStateException` 的参数有默认值，不传时消息是 `illegal argument`、`illegal state`。
- `ArithmeticException`、`UnwrapException`、`IndexOutOfBoundsException` 等由语言自身抛出的异常没有构造参数，消息是固定的。

照搬 Kotlin 写 `Exception("disk is full")`，或者写 `Exception()`，都会报错：

```scoop
{{#include ../../examples/ch19/message_fail.scoop}}
```

```text
{{#include ../../examples/ch19/message_fail.error}}
```

读取消息时，用 `?:` 给缺失的情况一个说明，这是书中一直在用的 `e.message ?: "..."`。

异常对象本身不能直接打印。Kotlin 中 `println(e)` 会调用 `Throwable.toString()`，输出类名和消息；Scoop 的异常没有实现 `ToString`（第 8 章）：

```scoop
{{#include ../../examples/ch19/print_fail.scoop}}
```

```text
{{#include ../../examples/ch19/print_fail.error}}
```

需要展示异常时，读取它的 `message` 或者自定义异常的字段。自定义的异常类也可以像第 8 章的 struct 那样自己实现 `ToString`，之后就能直接打印，但内置异常没有这个能力。

## 19.6　自定义异常

当调用方需要区分“哪一种失败”、或者需要失败的细节时，就该定义自己的异常类型：

```scoop
{{#include ../../examples/ch19/custom.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/custom.expected}}
```

这个例子读取配置项，演示了设计自定义异常的几条做法。

**用一个 `open` 基类把同一类失败归到一起。** `ConfigException` 是所有配置错误的基类，调用方既可以单独处理 `MissingKeyException`，也可以用 `catch (e: ConfigException)` 一次处理所有配置错误。Scoop 的 class 默认是 final 的（第 14 章），作为基类必须写 `open`。`catch` 的顺序仍然是先子类后基类。

**用字段携带结构化的信息。** `MissingKeyException` 有一个 `key` 字段，调用方直接读 `e.key`，而不是从消息文本里解析。消息是给人看的，字段是给程序用的。标准库也是这么做的：`PlatformException` 的 `kind` 字段区分“文件不存在”“没有权限”等情况，程序应该判断 `e.kind == PlatformErrorKind.NotFound`，而不是比较消息字符串。

**需要保留原因时，自己加一个 `cause` 字段。** 把底层异常换成更有意义的异常时（这里把 `NumberFormatException` 换成了 `InvalidValueException`），通常要保留原来的异常，方便排查。Kotlin 的 `Throwable` 自带 `cause`，Scoop 的没有，构造器也不接受第二个参数：

```scoop
{{#include ../../examples/ch19/cause_fail.scoop}}
```

```text
{{#include ../../examples/ch19/cause_fail.error}}
```

所以 `ConfigException` 自己声明了 `val cause: Throwable? = None`。字段类型用 `Throwable?` 而不是 `Exception?`，这样任何异常都能放进来；代价是 `Throwable` 没有 `message`，读取时要像 `describe` 那样先用 `is Exception` 判断一下。

**在构造时算好消息。** `message` 是 `Exception` 的 final 属性，子类不能 override：

```scoop
{{#include ../../examples/ch19/override_message_fail.scoop}}
```

```text
{{#include ../../examples/ch19/override_message_fail.error}}
```

正确的做法是像 `MissingKeyException` 那样，在调用基类构造器时把消息拼好：`ConfigException(f"missing key: ${key}")`。

**不能继承内置的异常类。** 核心库中除了 `Throwable` 和 `Exception`，其他异常类都是 final 的：

```scoop
{{#include ../../examples/ch19/inherit_builtin_fail.scoop}}
```

```text
{{#include ../../examples/ch19/inherit_builtin_fail.error}}
```

（第二条报错是第一条的连带结果：继承失败后，`InvalidPortException` 不再被当作 `Throwable` 的子类型。）在 Kotlin 中，`class InvalidPortException : IllegalArgumentException(...)` 是常见写法；在 Scoop 中，让它继承 `Exception` 或者你自己的 `open` 基类。

最后，捕获异常之后有两种继续传递的方式：

- **原样重新抛出**：`catch (e: X) { log(...); throw e }`。抛出的是同一个对象，类型、字段和下一节的栈记录都不变。适合“记一笔日志再交给上层”的场合。
- **包装成新异常**：像 `requireInt` 那样 `throw InvalidValueException(..., Some(e))`。适合把底层的、调用方不关心的异常，翻译成这一层 API 的异常。

## 19.7　未捕获的异常

如果一个异常一路传出了 `main`，程序就会终止：

```scoop
{{#include ../../examples/ch19/uncaught.scoop}}
```

标准输出只有：

```text
{{#include ../../examples/ch19/uncaught.expected}}
```

标准错误：

```text
{{#include ../../examples/ch19/uncaught.stderr}}
```

进程的退出码是 `1`。报告的第一行是异常的**完整类型标识**：`c=` 后面是定义它的 Cone（`scoop:scoop.core:0.1.0`，`%3A` 是转义后的冒号），`x=` 后面是类型名 `IllegalStateException`。注意报告中**没有异常消息**：运行时生成这份报告时不调用任何用户代码，也就不会去读取 `message`。

第二行说明没有调用栈信息，原因是 release 构建默认不采集栈。去掉 `--release`，用 debug 构建运行，就能看到异常是从哪里抛出的（摘录，省略了路径和地址）：

```text
scoop: uncaught exception: n(c=scoop%3Ascoop.core%3A0.1.0;p=;o=-;k=C;x=IllegalStateException)
  at loadConfig (…/uncaught.scoop:2) …
  at main (…/uncaught.scoop:7) …
```

release 构建也可以用 `--enable-stack-trace` 打开采集，比如 `scoop run uncaught.scoop --release --enable-stack-trace`，不过优化后的代码经过内联，栈里的帧可能和源码对不上。对于已经捕获的异常，可以调用 `e.printStackTrace()`，把它的类型和栈记录打印到标准错误。

因为未捕获的报告里没有消息，**面向用户的程序应该在边界上自己处理预期的异常**。最常见的边界就是 `main`：

```scoop
{{#include ../../examples/ch19/toplevel.scoop}}
```

```sh
$ scoop run toplevel.scoop --release -- many hello
count must be an integer: many
$ echo $?
2
```

这个程序的结构是：

- 业务代码（`run`、`parseCount`）只管抛出异常，不打印、不退出；
- `main` 返回 `Int` 作为退出码，在这里集中捕获预期之内的 `UsageException`，用 `eprintln` 把消息写到标准错误，返回 `2`；
- 预期之外的异常（程序的 bug）不在这里捕获，让它以退出码 `1` 终止进程，并在 debug 构建中留下调用栈。

`eprintln` 和 `println` 一样属于核心库，区别是写到标准错误。错误信息写到标准错误，是为了在 `repeat 3 hi > out.txt` 这样重定向输出时，错误信息仍然能显示在终端上。

> **深入一点：栈记录在什么时候采集**
>
> 打开栈采集时，栈是在异常对象**第一次被 `throw`** 的那一刻采集的，而不是在构造异常对象时。只构造不抛出的异常对象没有栈记录，对它调用 `printStackTrace()` 会说明“尚未采集”。
>
> 同一个对象被重新抛出（`throw e`），或者被保存起来、在别的地方再次抛出，都保留第一次抛出时的栈，不会被覆盖。包装成新异常再抛出时，新对象记录的是新的抛出位置，所以 19.6 中自己加的 `cause` 字段也有助于排查：原来的异常对象带着自己的栈。
>
> 采集栈需要回溯调用帧，有一定开销，这是 release 构建默认关闭它的原因。关闭时异常的传播、`catch` 匹配和对象的内存布局都不变，只是没有栈记录。

## 19.8　没有 `require`、`check` 和 `error`

Kotlin 标准库有几个常用的前置条件函数：`require` 检查参数，失败抛出 `IllegalArgumentException`；`check` 检查状态，失败抛出 `IllegalStateException`；`error` 直接抛出 `IllegalStateException`；`TODO()` 表示尚未实现。Scoop 的核心库和标准库都没有这些函数：

```scoop
{{#include ../../examples/ch19/require_fail.scoop}}
```

```text
{{#include ../../examples/ch19/require_fail.error}}
```

需要时自己写几个辅助函数即可：

```scoop
{{#include ../../examples/ch19/checks.scoop}}
```

输出：

```text
{{#include ../../examples/ch19/checks.expected}}
```

消息参数用 `() -> String` 而不是 `String`，这样只有在检查失败时才拼接消息，和 Kotlin 的 `require(cond) { "..." }` 一样。只是抛出异常、永远不会正常返回的辅助函数，返回类型声明为 `Nothing`，调用方就可以像写 `throw` 一样使用它（第 6 章的 `fail`）。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `throw Exception("text")` | `throw Exception(Some("text"))` |
| `throw Exception()` | `throw Exception(None)` |
| `IllegalArgumentException("text")` | `IllegalArgumentException(Some("text"))` |
| `e.message`（类型 `String?`） | 相同，但读取时用 `e.message ?: "..."` 或 `when` 取值（第 12 章） |
| `e.cause` | 不存在；自定义异常自己声明 `val cause: Throwable?` |
| `override val message` | 不允许；在调用基类构造器时传入消息 |
| `class E : IllegalArgumentException()` | 内置异常是 final 的；继承 `Exception` 或自己的 `open` 基类 |
| `println(e)`、`"$e"` | 不能直接打印；打印 `e.message` 或自定义字段 |
| `e.printStackTrace()` | 相同；release 构建默认没有栈，用 `--enable-stack-trace` 打开 |
| `require(x)`、`check(x)`、`error("...")`、`TODO()` | 不存在；自己写辅助函数（19.8） |
| `catch (e: Error)` | 没有 `Error` 分支；内存耗尽等致命错误不能捕获 |
| `exitProcess(3)` | `exit(3)`，同样不执行 `finally` |
| `addSuppressed` / `suppressed` | 不存在；`use` 用 `ResourceUseException` 同时保存两个异常（第 21 章） |

## 常见误用

- **`Exception("...")` 少了 `Some`**：消息的类型是 `String?`。
- **把宽泛的 `catch` 写在前面**：`catch` 按顺序匹配，`Exception` 写在前面会让后面的分支不可达，编译器报错。
- **在 `finally` 里 `return` 或抛出异常**：原来的异常会悄悄消失（19.3）。
- **依赖未捕获异常的报告给用户看**：报告里只有类型，没有消息；在 `main` 中捕获预期的异常，把消息打印出来（19.7）。
- **在深处调用 `exit`**：`finally` 和资源清理都不会执行。让 `main` 返回退出码。
- **解析异常消息来判断失败类型**：用异常的类型和字段区分，比如 `PlatformException.kind`。
- **继承 `IllegalArgumentException` 等内置异常**：它们是 final 的。
- **用 `catch (e: Exception)` 吞掉所有异常却什么也不做**：程序的 bug 也会被一起吞掉。只捕获当前这一层能处理的异常，其余的让它继续传递。

## 小结

- `throw` 抛出 `Throwable` 的子类对象；`try`/`catch`/`finally` 的语法和 Kotlin 相同，`catch` 按顺序匹配第一个符合的类型；没有受检异常。
- `try` 是表达式，值来自 `try` 块或处理异常的 `catch` 块；`finally` 不参与求值。
- `finally` 在正常结束、抛出异常、`return` 跳出时都会执行；`exit` 和致命错误不会执行它。不要在 `finally` 中 `return` 或抛出异常。
- `Exception.message` 是 `String?`，构造 `Exception` 必须传 `Some(...)` 或 `None`；异常不能直接打印。
- 自定义异常继承 `Exception` 或自己的 `open` 基类，用字段携带结构化信息；需要原因链时自己加 `cause` 字段；`message` 不能 override，内置异常不能继承。
- 未捕获的异常以退出码 `1` 结束进程，报告里有类型、没有消息；release 默认不采集栈。面向用户的程序在 `main` 中处理预期的异常并返回合适的退出码。

## 练习

1. 写一个函数 `divide(a: Int, b: Int): Int`，`b` 为 0 时抛出带消息的 `IllegalArgumentException`，而不是让 `ArithmeticException` 传出去。在 `main` 中分别用正常的参数和 `b = 0` 调用它，打印结果或错误消息。
2. 用 `try` 表达式写 `parseOr(text: String, fallback: Int): Int`。然后用 `toIntOrNone` 再写一遍，比较两种写法。
3. 为一个简单的银行账户设计异常：基类 `AccountException`，子类 `InsufficientFundsException` 带有 `balance` 和 `requested` 两个字段。写 `withdraw` 方法，并在调用方根据字段打印“余额 X，不足以支取 Y”。
4. 把 19.7 的 `toplevel.scoop` 改成：参数个数不对时退出码为 `2`；次数不是正整数时也作为用法错误处理。思考：为什么不应该在 `main` 里再加一个 `catch (e: Exception)` 返回 `1`？
5. 下面的函数有什么问题？改正它。

   ```kotlin
   fun readCount(): Int {
       try {
           return loadFromDisk()
       } finally {
           return -1
       }
   }
   ```
