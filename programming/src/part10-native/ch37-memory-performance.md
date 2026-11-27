# 第 37 章　内存与性能：应用开发者需要知道的

Scoop 有 GC，大多数时候你不需要考虑内存：创建对象，用完就不管了。但 Scoop 又是一门编译成原生代码的语言，值类型、单态化的泛型、能直接调用 C，这些特性让你**有机会**写出很快的代码，前提是知道它们在底层是怎样工作的。

本章不讲编译器和 GC 的实现，只讲应用开发者需要知道的部分：

- GC 从开发者的角度看是什么样的，为什么不能长期持有对象的裸地址；
- 值类型和引用类型在性能上的区别；
- 怎样正确地测量性能，怎样查看编译器做了哪些优化；
- “深入一点”：`@NoGC`、`@GCLeaf`、`@Global` / `@ThreadLocal`、`MaybeUninit`、`pin` 和 `GcHandle`，以及它们各自的使用场景。

前三节适合所有读者。最后一节主要面向写 FFI 封装（第 36 章）或性能敏感代码的读者。

## 37.1　从开发者的角度看 GC

Scoop 的 GC 有这样几个特点，每一个都对写代码有实际影响：

- **自动回收。** class 实例、字符串、数组等引用类型的对象由 GC 管理。没有 `free`，也没有引用计数，循环引用同样会被回收。
- **精确。** GC 准确地知道每个变量、每个字段里是不是引用，不会把一个碰巧像地址的整数当成引用。这也是第 36 章要求 C 函数的签名中不能出现引用类型的原因之一。
- **分代。** 新创建的对象先放在“年轻代”，大部分对象很快就不再使用，回收年轻代的代价很低；活得久的对象才进入“老年代”。所以创建短命的小对象比你想象的便宜，但并不是免费的。
- **会移动对象。** 回收时，GC 会把存活的对象挪到一起，以减少内存碎片。对象的地址因此会变化，所有指向它的引用由 GC 自动更新。
- **暂停所有线程。** 回收的关键步骤会让所有线程在安全的位置停下来（stop-the-world），完成后再继续。

对普通代码来说，“会移动”是不可见的，引用总是有效的。只有在你取得对象的**裸地址**时，它才变得重要：GC 不知道一个 `ULong` 或 C 那边的 `void *` 里存的是地址，移动对象时不会去更新它。这就是第 36 章那些规则的来由：

- `withDataPointer`、`withCString` 这些借用函数在回调期间**固定**对象，回调结束后，指针就失效了；
- 需要让 C 长期持有一个对象时，要用 37.5 介绍的 `pin` 或 `GcHandle`。

还有两点值得一提。第一，GC 只知道它自己管理的内存。C 库分配的内存再大，GC 也看不见，所以封装 C 资源的 class 要实现 `close`（第 36.9 节），不能指望 GC 及时回收。第二，GC 不提供“对象何时被回收”的保证。第 36 章的 `release` 块是兜底手段，不是析构函数。

> **从 Kotlin 过来**
>
> Kotlin/JVM 的 GC 同样是精确、分代、会移动对象的，开发者的体验很接近。最大的区别在于值类型：JVM 上几乎所有东西都是堆上的对象，`List<Int>` 中的每个元素都是装箱的 `Integer`；Scoop 的 struct、enum 和基本类型不经过堆，下一节会看到这带来的差别。

## 37.2　值类型与引用类型

第 8 章从语义上比较了 struct 和 class：struct 是值，没有身份；class 是对象，有身份。它们在内存中的表示也不同：

| | struct（值类型） | class（引用类型） |
| --- | --- | --- |
| 创建 | 不分配堆内存 | 在堆上分配一个对象 |
| 存放 | 直接存在变量、字段、数组元素中 | 变量、字段、数组元素中只存一个引用 |
| 额外开销 | 无 | 每个对象有一个对象头 |
| `Array<T>` | 元素连续排列，没有装箱 | 一组引用，对象分散在堆上 |
| 传参、赋值 | 复制整个值 | 复制一个引用 |
| GC | 不需要回收 | 需要扫描、移动、回收 |

下面的程序比较两种类型的数组，字段完全相同：

```scoop
{{#include ../../examples/ch37/layout/src/main.scoop}}
```

计时用的 `measureTimedValue` 来自 `scoop.platform`，所以这个例子是一个依赖了 `scoop.platform` 的 Cone（第 29 章）。在一台 Apple M4 Pro 上用 `scoop run --release` 运行，某一次的输出是：

```text
create struct array: 2 ms
create class array:  10 ms
true
sum struct array:          2021 µs
sum class array:           3179 µs
sum class array, shuffled: 7849 µs
```

具体数字和机器有关，每次运行也不完全相同，但趋势很稳定：

- **创建**：struct 数组只需要分配一块连续的内存；class 数组要分配两百万个对象，慢了大约 5 倍，而且这些对象之后都要由 GC 处理。
- **顺序遍历**：struct 数组的元素紧挨在一起，CPU 缓存的效率最高。class 数组要先读引用，再跳到对象处读字段。这里的对象是按顺序分配的，在堆上也挨得很近，所以只慢了一半左右。
- **打乱顺序后遍历**：真实程序中的对象往往是在不同时候创建的，在内存中并不相邻。`shuffled` 模拟了这种情况，此时慢了将近 4 倍，主要是缓存未命中造成的。

这些差别来自内存布局，所以不止适用于数组：class 的字段如果是 struct，这个 struct 会直接嵌在对象里面；`ArrayList<PointValue>` 的元素同样不装箱。Scoop 的泛型是**单态化**的，`ArrayList<PointValue>` 有一份专门为 `PointValue` 生成的代码，元素直接按值存储，不存在 JVM 上那样的类型擦除和装箱。

### 什么时候会装箱

值类型被当作**引用类型**使用时，会被装箱，也就是复制到一个堆上的对象中：

- 赋给 `Any` 类型的变量或参数；
- 赋给它实现的某个接口类型，例如把一个 struct 当作 `ToString` 传递；
- 放进 `Array<Any>`、`ArrayList<Shape>`（`Shape` 是接口）这类元素是引用类型的容器。

装箱很便宜，但在热循环中频繁发生，就相当于又回到了“每个元素一个对象”的情况。性能敏感的代码中，尽量让容器和参数使用具体的值类型，或者使用以值类型为实参的泛型函数，而不是接口类型。

### struct 并不总是更快

值类型每次传参、赋值都复制整个值。一个有十几个字段的大 struct 被频繁传来传去，复制的代价就可能超过一次引用传递。经验上：

- 几个数值字段组成的小数据，比如坐标、颜色、区间、金额，用 struct；
- 字段很多、需要共享、需要身份或可变状态的数据，用 class（第 8.9 节）。

不确定时，先按语义选择，再用下一节的方法测量。

## 37.3　正确地测量

### 在 release 下测量

`scoop run` 默认使用 debug 配置：不做优化，保留完整的调试信息。用 debug 构建测量性能没有意义。同一个程序不加 `--release` 运行的结果：

```text
create struct array: 16 ms
create class array:  34 ms
true
sum struct array:          25481 µs
sum class array:           12454 µs
sum class array, shuffled: 41125 µs
```

所有数字都慢了很多倍，struct 数组的遍历甚至比 class 数组还慢，结论完全颠倒了。原因是 debug 构建不做优化：下一节会看到，release 构建会把循环中的迭代器调用、运算符调用都内联进来，而在 debug 构建中，它们都是真正的函数调用。不同写法在优化前后的差别并不相同，所以 debug 下的相对快慢没有参考价值。

所以，**测量性能时总是加上 `--release`**（`scoop run --release`、`scoop build --release`）。

### 几条测量的原则

- **用单调时钟。** `scoop.platform.time` 中的 `measureTime { ... }` 返回代码块耗费的 `Duration`；`measureTimedValue { ... }` 同时返回代码块的结果。它们使用 `MonotonicTimeSource`，不受系统时间调整的影响。
- **先预热，再计时。** 第一次运行一段代码时，内存可能还没有分配好，缓存也是空的。例子中先调用了一次 `sumValues` 和 `sumObjects`，再开始计时。
- **使用计算的结果。** 例子打印了两个总和是否相等。如果结果完全没有被使用，编译器可能把整个计算删掉，测到的就是一段空代码。
- **多跑几次。** 只看一次的结果容易被干扰。至少运行几次，看结果是否稳定。
- **测量真实的工作量。** 微小的基准测试只能回答很窄的问题。优化之前，先确认程序的时间到底花在了哪里。

## 37.4　查看编译器的优化决策

release 构建中，编译器的优化器会做两件对性能影响很大的事：

- **内联**：把被调用函数的函数体直接放进调用处，省掉调用的开销，并让后续的优化能够跨越函数边界。
- **消除分配**：如果一个对象只在局部使用、不会被外部看到，就不在堆上创建它。

想知道某个函数有没有被内联，可以让编译器输出它的优化记录：

```scoop
{{#include ../../examples/ch37/optimizations.scoop}}
```

```sh
scoop build optimizations.scoop --release --emit optimizations --dump-dir dump
```

`--emit optimizations` 必须配合 `--dump-dir` 使用。编译器会在 `dump/` 下的一个子目录中写入 `optimizations.json`，记录每一个调用点的优化决策。这个文件是给工具读的，内容很多，可以用 `jq` 筛选出 `total` 函数中的记录：

```sh
jq -r '
  (.functions | map({key: (.id | tostring), value: .name}) | from_entries) as $name
  | .events[]
  | select($name[.site.function | tostring] == "total")
  | [.pass,
     (if .target.callee.kind == "function" then $name[.target.callee.id | tostring] else "-" end),
     (if (.outcome | type) == "string" then .outcome else .outcome.reason end)]
  | @tsv' dump/*/optimizations.json | sort -u
```

输出（每一行是优化阶段、被调用的函数和结果）：

```text
allocation-elision	-	eliminated
allocation-elision	-	unreplaced-uses
inline	-	no-mir-body
inline	Collection.$get$size	indirect-call
inline	ctor.Vec2.$c0	inlined
inline	get	inlined
inline	init.ListIterator.$c0	inlined
inline	iterator	inlined
inline	Iterator.next	indirect-call
inline	List.get	indirect-call
inline	next	inlined
inline	size	inlined
inline	Vec2.length2	inlined
inline	Vec2.plus	inlined
```

从中可以读出：

- `Vec2.plus`、`Vec2.length2` 和 `Vec2` 的构造器都被内联进了 `total`，循环中的 `sum + p` 不再是一次函数调用。
- `for (p in points)` 背后的 `iterator()`、`next()` 也被内联了。第一轮优化时，`Iterator.next`、`List.get` 还是接口调用（`indirect-call`），编译器不知道具体会调用哪个实现；内联之后，编译器知道了迭代的是一个数组，于是在后面的轮次中直接内联了数组的 `size` 和 `get`。
- `allocation-elision` 一行的 `eliminated` 表示一次堆分配被消除了，这里消除的是 `for` 循环创建的迭代器对象。
- `no-mir-body` 表示被调用的函数没有可供内联的函数体，比如运行时或 C 实现的函数；`not-profitable` 表示编译器认为内联得不偿失，比如函数体太大。

`--emit` 还可以输出 `ast`、`hir`、`mir`、`lir`、`symbols` 等其他阶段，主要供编译器开发者使用。`optimizations.json` 的格式随编译器版本变化，适合偶尔用来回答“这里有没有内联”“这个对象有没有被分配”这样的具体问题，不要在脚本中依赖它的细节。

## 37.5　深入一点：底层工具

下面这些注解和类型都是为特定的场景准备的，大多数程序完全用不到。了解它们，主要是为了在读标准库源码或写 FFI 封装时知道它们是什么意思。

### `@NoGC`：保证不与 GC 打交道

```scoop
{{#include ../../examples/ch37/nogc.scoop}}
```

输出：

```text
{{#include ../../examples/ch37/nogc.expected}}
```

标了 `@NoGC` 的函数中**不能创建、读取或写入任何引用类型的值**。编译器会逐项检查参数、返回值、局部变量和每一个表达式：

```scoop
{{#include ../../examples/ch37/nogc_fail.scoop}}
```

```text
{{#include ../../examples/ch37/nogc_fail.error}}
```

f-string 会生成一个 `String`，返回值也是 `String`，所以报了错。由此可以推出几条规则：class 的方法不能标 `@NoGC`，因为 `this` 本身就是引用；`@NoGC` 函数只能调用其他 `@NoGC` 函数，即使被调用的普通函数看起来什么都没分配；泛型的 `@NoGC` 函数只能用不含引用的类型实参实例化。

`@NoGC` 也可以标在 struct 或 enum 上，含义是“这个类型永远不包含引用”。以后有人给 `Rgb` 加了一个 `String` 字段，编译器就会报错。

使用场景：

- **C 回调**（第 36.6 节）：必须是 `@NoGC` 函数。
- **`release` 块中调用的辅助函数**（第 36.9 节）：同样要是 `@NoGC` 函数，并且不能调用 C 函数。
- **记录并检查一个约定**：标在热路径的小函数上，保证它不分配内存。将来有人修改了这个函数，让它开始分配，编译器会发现。

`@NoGC` 不是一个“让代码变快”的开关。普通函数如果没有分配，也一样快；`@NoGC` 只是让编译器**保证**这一点。

### `@GCLeaf`：很短的 C 调用

```scoop
{{#include ../../examples/ch37/leaf.scoop}}
```

输出：

```text
{{#include ../../examples/ch37/leaf.expected}}
```

默认情况下，调用 C 函数前后，Scoop 都要和 GC 做一次协调：调用前告诉 GC“这个线程进入 C 代码了，可以不等我”，返回时再确认 GC 是否正在移动对象。这样 C 函数阻塞多久都不会拖住 GC。对 `abs` 这样只有几条指令的函数，这个协调的开销比函数本身还大。

`@GCLeaf` 省掉这次协调，代价是你要保证 C 函数满足一份严格的约定：

- 很快返回，不阻塞：不做 IO，不等待锁或条件变量，不 sleep；
- 不回调任何 Scoop 代码；
- 不改变浮点运算环境。

违反约定的后果是未定义行为，编译器无法检查。还有一点容易被忽略：`@GCLeaf` 调用期间，GC 必须等这个线程返回才能开始回收，一个很慢的 leaf 调用会让**所有线程**都等着。

`@NoGC` 函数中只能调用 `@GCLeaf` 的 C 函数，因为普通的 C 调用需要与 GC 协调，这本身就是和 GC 打交道：

```text
{{#include ../../examples/ch37/leaf_fail.error}}
```

除非性能测量表明 C 调用的开销确实是瓶颈，否则不需要 `@GCLeaf`。

### `@Global` 与 `@ThreadLocal`：有固定地址的全局变量

```scoop
{{#include ../../examples/ch37/globals.scoop}}
```

输出：

```text
{{#include ../../examples/ch37/globals.expected}}
```

普通的顶层 `var` 由编译器管理：它可以存放任何类型，包括 `String` 这样的引用，初始值可以是任意表达式，在 `main` 之前计算。大多数时候用它就够了，成组的全局状态则建议放进 `object`。

`@Global` 和 `@ThreadLocal` 声明的是 **raw 存储**：一块有固定地址的内存，初始值在编译期确定。

- `@Global` 整个程序只有一份；`@ThreadLocal` 每个线程各有一份，线程之间互不影响。
- 类型不能含有引用，因为这块内存不受 GC 管理：

  ```text
  {{#include ../../examples/ch37/global_ref_fail.error}}
  ```

- 可以用 `addressOf` 取得地址，交给 C 读写。普通的顶层变量没有固定的存储位置，不能取址：

  ```text
  {{#include ../../examples/ch37/address_plain_fail.error}}
  ```

使用场景主要是 FFI：C 库要求传入一个全局变量的地址，或者用 `@Extern` 声明 C 库中可写的全局变量（这时也要写 `@Global` 或 `@ThreadLocal`，说明它是不是线程局部的）。

注意，`@Global` **不提供任何线程安全**。两个线程同时读写同一个全局变量（无论是普通的还是 `@Global` 的），而其中至少一个是写，就构成数据竞争，结果是未定义的。跨线程共享的计数器要用原子类型（第 27 章）。

### `MaybeUninit<T>`：暂时还没有值的存储

```scoop
{{#include ../../examples/ch37/uninit.scoop}}
```

输出：

```text
{{#include ../../examples/ch37/uninit.expected}}
```

有时需要先准备好存储，稍后才填入值，而这个类型又没有合理的默认值。用 `Reading?` 当然可以，但 `Option` 要多占空间记录 Some / None，读取时也要判断。`MaybeUninit<T>` 和 `T` 一样大，它把“这里到底有没有值”的责任交给了程序：

- `MaybeUninit<T>.uninit()`：存储全部清零，表示“还没有值”。
- `MaybeUninit<T>.initialized(v)`：包含一个合法的值 `v`。
- `x.assumeInit()`：取出其中的 `T`。这是 unsafe 的，必须由程序保证这里确实已经放入了合法的值，例子中用 `filled` 数组记录这一点。

`MaybeUninit` 没有 `isInitialized()`，它自己不记录是否已初始化，这正是它省掉的那部分开销。对一个 `uninit()` 的值调用 `assumeInit()` 是 unsafe 契约违规，得到的可能是一个“全零”的 `T`，而对 class 引用或 enum 来说，全零不一定是合法的值。

大多数应用代码应该使用 `Option`。`MaybeUninit` 适合两类场景：给 C 函数准备一个用于输出的 struct，由 C 负责填写；以及自己实现容器，容器中有一部分槽位暂时空着。

### `pin` 与 `GcHandle`：把对象交给 C 长期持有

37.1 讲过，GC 会移动对象，裸地址不能长期保存。如果 C 库需要保存一个 Scoop 对象，比如注册回调时传入的 `void *userdata`，有两种做法：

| | `pin(obj)` → `PinnedPtr<T>` | `getGcHandle(obj)` → `GcHandle<T>` |
| --- | --- | --- |
| 对象不会被回收 | 是 | 是 |
| 对象不会被移动 | 是，`raw` 就是对象的实际地址 | 否，`raw` 只是一个句柄编号 |
| 取回对象 | `unpin(p)` | `releaseGcHandle(h)` |
| 代价 | 妨碍 GC 整理内存，固定时间要尽量短 | 不影响 GC 移动对象 |

```scoop
{{#include ../../examples/ch37/handle.scoop}}
```

输出：

```text
{{#include ../../examples/ch37/handle.expected}}
```

`PinnedPtr` 和 `GcHandle` 都只是包含一个 `ULong` 的 struct，可以直接交给 C 保存。这里用一个 `@Global` 变量代替 C 那一侧的存储。这些函数都是 unsafe 的：

- 每次 `pin` 必须恰好对应一次 `unpin`，每个 handle 必须恰好释放一次。忘记释放，对象就永远不会被回收；释放两次是致命错误。
- 从 `raw` 重新构造 `GcHandle<Session>` 时，类型参数由你保证，编译器无法验证它真的是一个 `Session`。

需要固定对象的地址时用 `pin`，例如 C 要在一段时间内读写对象的内存；只需要“以后能找回这个对象”时用 `GcHandle`。如果只在一次 C 调用期间使用，第 36.5 节的借用函数更简单，也更安全。

如果 C 保存对象的目的是“以后回调时用到它”，通常不需要自己管理 handle：用第 36.10 节的 `foreignCallback` 注册一个捕获了这个对象的闭包，运行时会替你保活闭包和它捕获的一切。`GcHandle` 适合 C 只是暂存一个对象、之后再交还给 Scoop 代码的场景。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| JVM 的 GC：精确、分代、会移动对象 | 相同 |
| `List<Int>` 的元素是装箱的 `Integer` | 值类型元素不装箱，`Array<T>` 中连续存放 |
| 泛型类型擦除 | 单态化，每组类型实参一份代码 |
| `@JvmInline value class` | struct，任意字段数，都不装箱 |
| JIT 在运行时优化，需要预热 | 编译期优化；`--release` 才开启 |
| JMH 做基准测试 | `measureTime` / `measureTimedValue`，自己预热、重复 |
| `finalize()` / `Cleaner` | `release` 块（第 36.9 节），只是兜底 |
| `@Volatile`、`AtomicLong` | 原子类型（第 27 章）；`@Global` 不提供同步 |

## 常见误用

- **在 debug 构建中测量性能**：结论可能完全颠倒，用 `--release`（37.3）。
- **把计算结果丢掉不用**：编译器可能把整段计算删掉（37.3）。
- **在热循环中把值类型当作 `Any` 或接口使用**：每次都会装箱（37.2）。
- **所有数据都用 struct**：大 struct 频繁复制也有代价，先按语义选择，再测量（37.2）。
- **把对象的地址保存在 C 中，却没有 `pin` 或 `GcHandle`**：GC 移动对象后，这个地址就失效了（37.1、37.5）。
- **`pin` 之后忘记 `unpin`**：对象永远不会被回收，还会妨碍 GC 整理内存（37.5）。
- **以为 `@NoGC` 能让代码变快**：它只是一个由编译器检查的约定（37.5）。
- **给会阻塞的 C 函数标 `@GCLeaf`**：会让所有线程都等待这次调用（37.5）。
- **用 `@Global` 变量在线程之间共享计数**：没有同步，构成数据竞争，用原子类型（37.5）。
- **用 `MaybeUninit` 代替 `Option`**：除非确实需要省掉标记的开销，否则 `Option` 更安全（37.5）。

## 小结

- Scoop 的 GC 精确、分代、会移动对象。普通代码不受影响；取得对象的裸地址时，要借用、`pin` 或使用 `GcHandle`。
- GC 看不见 C 分配的内存，也不保证回收的时机。C 资源要靠 `close` 及时释放。
- struct 不分配堆内存，在数组和容器中连续存放、不装箱，适合小的数值型数据；当作 `Any` 或接口使用时才会装箱。
- 泛型是单态化的，`ArrayList<Point>` 中的 `Point` 不装箱。
- 测量性能要用 `--release`，用单调时钟，预热、重复，并使用计算结果。
- `--emit optimizations --dump-dir` 可以查看哪些调用被内联、哪些分配被消除。
- `@NoGC` 保证函数不与 GC 交互，用于 C 回调和 `release`；`@GCLeaf` 省掉很短的 C 调用与 GC 的协调；`@Global` / `@ThreadLocal` 是有固定地址、不含引用的全局存储；`MaybeUninit` 是不记录初始化状态的存储。

## 练习

1. 在 37.2 的程序中，把 `PointValue` 改为包含 8 个 `Double` 字段的 struct，`PointObject` 也同样改。结果有什么变化？再把 `sumValues` 的参数类型改成 `Array<Any>`，元素用 `as` 取回，又会怎样？
2. 给 37.4 的 `Vec2` 增加一个实现了 `ToString` 的 `toString()`，在 `total` 中把每个点都拼接进一个字符串。用 `--emit optimizations` 查看，`total` 中多出了哪些没有内联的调用？
3. 写一个 `@NoGC` 函数 `fun mix(a: Rgb, b: Rgb): Rgb`，返回两种颜色各分量的平均值。试着在里面加一行 `println`，阅读编译器的报错。
4. 第 36 章的 `qsort` 回调 `compareInts` 为什么必须是 `@NoGC`？如果 C 函数在调用比较函数的同时，GC 正在另一个线程上移动对象，会发生什么？
5. 一个 C 库提供 `void set_listener(void (*fn)(void *userdata), void *userdata)`，并会在以后的某个时候、在库自己的线程上调用 `fn`。为什么 `@NoGC` 函数加 `::name` 不能满足需求？分别用 `GcHandle` 和第 36.10 节的 `foreignCallback` 设计方案，比较两者需要你自己保证的事情。
