# 第 36 章　调用 C 代码

> 第十部分面向需要调用 C 库的读者；只写应用的读者可以跳过。

Scoop 编译成原生机器码，调用 C 函数不需要 JNI 那样的中间层：声明一下函数签名，就可以像调用普通函数一样调用它。这一能力称为 **FFI**（foreign function interface，外部函数接口）。标准库本身大量使用 FFI，`scoop.platform` 的文件和网络操作、`scoop.compression` 的 zstd 和 gzip，底层都是 C 代码。

FFI 的代价是：编译器无法检查 C 代码做了什么。C 函数可能越界写内存、释放两次、在你不知道的时候保存一个指针。Scoop 用 `@Unsafe` 把这些“需要你自己保证正确”的代码标出来，让它们集中在少数几个地方，而不是散落在整个程序中。

本章介绍：

- 什么时候应该用 FFI，什么时候应该找现成的库；
- 用 `@Extern` 声明 C 函数，以及 Scoop 与 C 的类型对应关系；
- `@Unsafe` 和 `@Safe`：标出需要自己保证安全的代码；
- 指针 `Ptr<T>`、`sizeOf` / `alignOf`、`addressOf`；
- 把 Scoop 的字符串和数组临时借给 C 使用；
- 回调函数 `FunPtr`，以及读取 `errno`；
- 在 Cone 中编译 C 源码、链接系统库，`@CLayout` struct；
- 把 C 句柄封装成安全的 `Closeable` class；
- 深入一点：能捕获变量、在任意线程上调用、使用 GC 和 Context 的回调 `ForeignCallback`；
- 深入一点：让 C 直接接收 Scoop 对象的 Scoop ABI。

最后两节是高级内容，但遇到对应的场景时是必需的：C 库在自己的线程上回调（GUI 事件循环、线程池、异步 IO 库），或者 C 代码必须直接读写 Scoop 对象。第一次阅读可以先跳过。

## 36.1　先找现成的库

需要某个功能时，按这个顺序考虑：

1. **标准库和官方库**。文件、目录、进程、环境变量、时间、套接字在 `scoop.platform`（第 31 章）；HTTP、JSON、TLS、压缩、正则表达式、加密也都有对应的库（第 33～35 章）。它们已经处理好了平台差异、错误转换和资源释放。
2. **别人封装好的 Cone**（第 29 章）。
3. **自己写 FFI**。适合这些情况：要用的 C 库没有现成的封装；需要调用操作系统的某个特殊 API；已有一段 C 代码，想直接复用。

自己写 FFI 时，通常分两层：底层是一组与 C 头文件一一对应的 `@Extern` 声明，只在 Cone 内部可见；上层是一个普通的 Scoop API，把指针、错误码和资源释放都包装起来，使用者完全不需要接触 `@Unsafe`。本章最后的例子就是这样组织的。

## 36.2　第一个 extern 函数

```scoop
{{#include ../../examples/ch36/libc.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/libc.expected}}
```

`@Extern` 把一个**没有函数体**的顶层函数声明为外部函数：

- `name` 是 C 中的符号名，省略时使用 Scoop 函数名。这里把 C 的 `abs` 声明成 `cAbs`，避免和 Scoop 自己的函数混淆，这是一个常用的约定。
- `lib` 是逻辑库名，省略时表示默认的库，C 标准库（libc）中的函数都在这里。链接其他库的方法见 36.8。
- 参数和返回值必须使用 C 能理解的类型，见 36.3。

外部函数有几个限制：只能是顶层函数，不能是成员函数、局部函数或扩展函数；不能是泛型函数，也不能是 `suspend` 函数；不支持 C 的可变参数（`printf(const char *fmt, ...)` 这种）。需要调用可变参数函数时，先用 C 写一个参数固定的包装函数。

声明可以带默认参数，默认值在 Scoop 一侧填好，C 函数总是收到完整的参数。

### `@Unsafe`：需要自己保证安全的地方

C 函数默认是 **unsafe** 的，只能在 **unsafe 上下文**中调用。直接调用会报错：

```scoop
{{#include ../../examples/ch36/call_unsafe_fail.scoop}}
```

```text
{{#include ../../examples/ch36/call_unsafe_fail.error}}
```

unsafe 上下文有两种：

- 标了 `@Unsafe` 的块，例如上面 `main` 中的 `@Unsafe { ... }`；
- 标了 `@Unsafe` 的函数的函数体。这样的函数本身也变成了 unsafe 函数，调用它同样需要 unsafe 上下文。

`@Unsafe` 并不会关闭任何检查，类型检查、空安全等规则照常生效。它只是一个声明：**这里调用了编译器无法验证的操作，正确性由我负责。** 代码评审时，可以重点查看这些块。`@Unsafe` 块中如果有一小段又想恢复检查，可以在里面再写 `@Safe { ... }`。

`scoop fmt` 会把 `@Unsafe` 放在单独的一行，下一行才是块的 `{`，就像注解写在函数前面一样。`@Unsafe` 块是语句，不是表达式，所以不能写 `val n = @Unsafe { ... }`。需要结果时，像 `utf8Length` 那样在块里 `return`，或者先在块外声明一个 `var`，在块里给它赋值。

### lambda 不继承 unsafe 上下文

unsafe 上下文只覆盖块或函数**自己的**代码。块里写的 lambda 有自己的函数体，不在外层的 unsafe 上下文中：

```scoop
{{#include ../../examples/ch36/lambda_unsafe_fail.scoop}}
```

```text
{{#include ../../examples/ch36/lambda_unsafe_fail.error}}
```

lambda 可能在任何时候被调用，比如被保存起来、等外层块结束之后再执行，所以编译器要求它自己声明 unsafe。`utf8Length` 的写法是把回调写成匿名函数 `fun(p: Ptr<Int8>): ULong { ... }`，在它的函数体里再写一个 `@Unsafe` 块并 `return` 结果。标准库内部也是这样写的。

### 把 unsafe 包起来

`utf8Length` 本身是一个**安全**函数：它的签名里没有指针，调用方不需要写 `@Unsafe`。它在内部保证了正确性：`withCString` 提供的指针指向一个以 0 结尾的字节序列，`strlen` 只会读到这个 0 为止。

这是使用 FFI 的基本方式：**unsafe 代码放在小的、容易检查的函数里，对外只暴露安全的接口。** 输出中的 `6` 也说明了一件事：`strlen` 数的是 UTF-8 **字节**，`é` 占两个字节。

## 36.3　类型对应表

C 函数的参数和返回值只能使用 **C-FFI-safe** 的类型：它在 C 中有确定的表示，并且不包含任何 GC 管理的引用。

| C | Scoop | 说明 |
| --- | --- | --- |
| `int8_t` / `uint8_t` | `Int8` / `UInt8`（即 `Byte` / `UByte`） | |
| `int16_t` / `uint16_t` | `Int16` / `UInt16`（即 `Short` / `UShort`） | |
| `int32_t` / `uint32_t`、通常的 `int` / `unsigned` | `Int` / `UInt` | |
| `int64_t` / `uint64_t` | `Long` / `ULong` | |
| `size_t` | `ULong` | Scoop 只支持 64 位目标 |
| `long` | 看平台：Linux、macOS 上是 `Long`，Windows 上是 `Int` | 尽量选用 `int64_t` 这样的定宽类型 |
| `float` / `double` | `Float` / `Double` | |
| `bool` | `Boolean` | |
| `void`（返回值） | `Unit` | 只能用作返回类型 |
| `T *` | `Ptr<T>` | 不能为 null，见 36.4 |
| 可能为 null 的 `T *` | `Ptr<T>?`，即 `Option<Ptr<T>>` | 与裸指针一样大，`None` 就是 null |
| `void *`、不透明句柄 `struct Foo *` | `Ptr<Unit>` | |
| `const char *` | `Ptr<Int8>` 或 `Ptr<UInt8>` | 见 36.5 |
| 函数指针 | `FunPtr<(A, B) -> R>` | 见 36.6 |
| 按值传递的 struct | `@CLayout` struct | 见 36.8 |
| 整数常量的 enum | 整型枚举 `enum E: Int { ... }`（第 9.7 节） | C 只能传入已声明的值 |

C 的类型名本身不会被解析，Scoop 只看你写的类型。如果 C 函数的参数是 `int64_t`，你声明成了 `Int`，编译器无从发现，运行时就会读到错误的值。所以声明时要对照头文件，逐个核对每个参数。

`String`、`Array`、class 实例这些引用类型都不能出现在 C 函数的签名中：

```scoop
{{#include ../../examples/ch36/string_param_fail.scoop}}
```

```text
{{#include ../../examples/ch36/string_param_fail.error}}
```

原因是 GC 会移动对象（第 37 章），C 代码也不知道 Scoop 对象的内部布局。要把字符串或数组交给 C，就把它的内容临时“借”给 C，见 36.5。

## 36.4　指针 `Ptr<T>`

`Ptr<T>` 是一个原始指针，指向一块存放着 `T` 的内存。下面的例子用 C 的 `malloc` 分配内存，自己读写，再用 `free` 释放：

```scoop
{{#include ../../examples/ch36/pointers.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/pointers.expected}}
```

`Ptr<T>` 是一个值类型，大小就是一个机器指针。它的操作都是 unsafe 的：

| 操作 | 含义 |
| --- | --- |
| `p.load()`、`p.load(i)` | 读出 `p` 指向的值，或第 `i` 个元素 |
| `p.store(v)`、`p.store(i, v)` | 写入 |
| `p + n`、`p - n` | 指针移动 `n` 个**元素**，不是 `n` 个字节 |
| `p.cast<U>()` | 把它当作指向 `U` 的指针 |
| `p.toULong()` | 取得地址的数值 |
| `Ptr<T>(raw)` | 从一个地址数值构造指针 |

`T` 必须是不含引用的值类型，所以 `Ptr<Int>`、`Ptr<Point>`（`Point` 只有数值字段）可以，`Ptr<String>` 不行。

`sizeOf<T>()` 和 `alignOf<T>()` 在编译期给出类型的大小和对齐要求，单位是字节，类型是 `ULong`，与 C 的 `sizeof`、`_Alignof` 对应。分配内存时用它们计算字节数。

### null 指针

`Ptr<T>` **永远不是 null**。可能为 null 的指针要写成 `Ptr<T>?`，所以例子把 `malloc` 的返回值声明为 `Ptr<Unit>?`：分配失败时得到 `None`，用 `?: throw` 处理。`Option<Ptr<T>>` 和 `Ptr<T>` 一样大，`None` 在内存中就是全零，也就是 C 的 `NULL`（第 12.6 节的“深入一点”）。

这意味着你**无法**构造一个 null 的 `Ptr`，编译器会直接拒绝：

```scoop
{{#include ../../examples/ch36/null_ptr_fail.scoop}}
```

```text
{{#include ../../examples/ch36/null_ptr_fail.error}}
```

反过来，如果把一个可能返回 null 的 C 函数声明成返回 `Ptr<T>`，一旦它真的返回了 null，程序的行为就是未定义的。所以，**只要 C 文档说“失败时返回 NULL”，就声明成 `Ptr<T>?`。**

### `addressOf`：取变量的地址

`addressOf(x)` 取得一个变量的地址，常用于 C 的“输出参数”：C 函数接收一个指针，把结果写进它指向的地方。例子最后把 `answer` 的地址交给 `store`，`answer` 就变成了 42。36.8 中的 `tally_stddev` 是一个真实的例子。

只有真正存放在某处的值才有地址：局部变量、参数、`@Global` 全局变量（第 37 章），以及值类型方法中的 `this`。表达式的结果没有地址：

```scoop
{{#include ../../examples/ch36/address_temp_fail.scoop}}
```

```text
{{#include ../../examples/ch36/address_temp_fail.error}}
```

取到的指针只在变量的生命周期内有效。函数返回后，它的局部变量就不存在了，不要把局部变量的地址保存下来，留到以后再用。

> **从 Kotlin 过来**
>
> Kotlin/Native 的 cinterop 有 `CPointer<T>`、`nativeHeap.alloc`、`memScoped` 等工具。Scoop 的 `Ptr<T>` 更接近 C 指针本身：没有自动的作用域管理，`malloc` 出来的内存要自己 `free`。好在大多数时候并不需要自己分配内存，下一节的借用方式更常用。

## 36.5　把 Scoop 的数据借给 C

字符串和数组是 GC 管理的对象，GC 随时可能移动它们，所以不能直接把它们的地址交给 C。核心库提供了三个**有作用域的借用**函数：

| 函数 | 回调参数 | 说明 |
| --- | --- | --- |
| `array.withDataPointer { p, count -> ... }` | 元素区指针、元素个数 | 用于 `Array<T>` 和 `MutableArray<T>`，`T` 不能含引用 |
| `text.withUtf8Bytes { p, length -> ... }` | UTF-8 字节指针、字节数 | 不以 0 结尾 |
| `text.withCString { p -> ... }` | 以 0 结尾的 `Ptr<Int8>` | 先复制一份；字符串中间有 `\0` 时抛出 `IllegalArgumentException` |

它们的共同规则：

- 回调执行期间，对象被**固定**在原地，不会被移动或回收，C 可以放心读写这个指针。
- **指针只在回调中有效。** 回调返回后，对象可能被移动，指针就失效了。不要把它保存起来，也不要交给会在以后才使用它的 C 函数（比如异步 IO 的接口）。编译器不会检查这一点。
- `Array` 和 `String` 是不可变的，借出来的指针只能读；要让 C 写入，就借 `MutableArray`。

这三个函数本身也是 unsafe 的，并且和 36.2 讲的一样，传给它们的回调需要自己的 `@Unsafe` 块。

反方向，C 返回的字符串要先复制成 Scoop 的 `String` 才能使用：`String.fromCString(p)` 读到第一个 0 字节为止，`String.fromUtf8(p, length)` 读取指定的字节数。两者都会检查内容是不是合法的 UTF-8，不合法时抛出 `CharacterCodingException`；它们也是 unsafe 的，因为编译器无法知道 `p` 是否有效。复制完成后，`String` 与 C 的内存就没有关系了，C 那边的字符串该由谁释放，仍然按 C 库的约定处理。

需要在一次调用之外长期持有对象的场景，例如 C 库保存一个 `void *userdata`，要用第 37 章介绍的 `pin` 或 `GcHandle`。

## 36.6　回调：`FunPtr`

有些 C 函数接收一个函数指针作为参数，比如 C 标准库的 `qsort`，它用调用方提供的比较函数来排序：

```scoop
{{#include ../../examples/ch36/qsort.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/qsort.expected}}
```

`FunPtr<(Ptr<Unit>, Ptr<Unit>) -> Int>` 是一个 C 函数指针，尖括号里的函数类型描述它的签名，其中的类型同样要符合 36.3 的对应表。在期望类型是 `FunPtr` 的位置写 `::compareInts`，编译器就会生成这个函数的 C 地址。

能作为 C 回调的函数有严格的限制：

- 必须是**顶层的普通命名函数**，不能是 lambda、匿名函数、局部函数、成员函数或扩展函数，也不能是泛型函数或 `suspend` 函数；
- 签名必须和 `FunPtr` 中的函数类型**完全一致**；
- 必须标注 **`@NoGC`**：函数中不能创建或使用任何引用类型的值，比如不能拼接字符串、不能调用 `println`。

lambda 不行，是因为 lambda 可能捕获变量，而 C 的函数指针没有地方存放这些变量：

```scoop
{{#include ../../examples/ch36/callback_lambda_fail.scoop}}
```

```text
{{#include ../../examples/ch36/callback_lambda_fail.error}}
```

忘记 `@NoGC` 时，报错也会指出来：

```scoop
{{#include ../../examples/ch36/callback_nogc_fail.scoop}}
```

```text
{{#include ../../examples/ch36/callback_nogc_fail.error}}
```

`@NoGC` 的含义和用途在第 37 章详细介绍。这里只要知道：回调是从 C 代码中直接进入的，那里没有 GC 需要的信息，所以回调不能和 GC 打交道。`compareInts` 还标了 `@Unsafe`，因为它要读取指针。

`FunPtr` 本身也可以调用：`p(a, b)`，这需要 unsafe 上下文。C 函数返回的函数指针，或 C struct 中的函数指针字段，都可以这样调用。可能为 null 的函数指针同样写成 `FunPtr<F>?`。

由 `::name` 得到的回调，只能在**当前这次 C 调用期间**、在**同一个线程**上被同步调用，`qsort` 正是这样。如果 C 库会把回调保存下来，以后在别的线程上调用它，或者回调需要捕获变量、创建对象、调用普通的 Scoop 函数，就要用 36.10 介绍的 `ForeignCallback`。

## 36.7　`errno`

很多 C 函数失败时返回 `-1`，并把具体的错误码写进全局的 `errno`。问题在于，Scoop 运行时自己也会调用 C 函数，`errno` 随时可能被覆盖，等你再去读它时，已经不是那次调用留下的值了。所以 Scoop 让 `errno` 和返回值一起返回：

```scoop
{{#include ../../examples/ch36/errno.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/errno.expected}}
```

`captureErrno = true` 时，声明的返回类型必须写成 `(R, Int)`：第一项是 C 函数真正的返回值（`void` 函数写 `(Unit, Int)`），第二项是调用**刚结束时** `errno` 的值。调用之前 `errno` 会被清零。9 是 `EBADF`（无效的文件描述符），因为 -1 不是一个打开的文件。

要注意的是，`errno` 只是一个快照，Scoop 不会根据它抛出异常或判断成败。是否失败仍然要按 C 文档的约定判断，通常是看返回值是不是 -1；调用成功时 `errno` 也可能不是 0。把这些判断封装起来、转换成异常或 `Result`（第 20 章），是上层安全 API 的工作。

## 36.8　在 Cone 中编译 C 代码

前面的例子调用的都是 C 标准库，单文件就够了。要编译自己的 C 源码或链接其他库，就需要一个 Cone（第 28 章）。下面是一个完整的例子：一个用 C 写的小统计库 `tally`，以及它的 Scoop 封装。

```text
tally/
├── Cone.toml
├── native/
│   ├── tally.h
│   └── tally.c
└── src/
    ├── native.scoop     与 tally.h 对应的 @Extern 声明
    ├── tally.scoop      对外的安全 API
    └── main.scoop
```

C 头文件和实现：

```c
{{#include ../../examples/ch36/tally/native/tally.h}}
```

```c
{{#include ../../examples/ch36/tally/native/tally.c}}
```

`Cone.toml`：

```toml
{{#include ../../examples/ch36/tally/Cone.toml}}
```

- `[[native.sources]]` 列出要编译的 C 文件，每个文件一项，路径相对于 Cone 根目录。`.c` 按 C 编译，`.cc`、`.cpp` 按 C++ 编译（还需要在 `[native]` 中写 `cxx = true`）。编译好的目标文件会和 Scoop 代码链接在一起。
- `[[native.libraries]]` 声明要链接的系统库，`name` 是库名，不是路径，也不是链接器参数：这里的 `"m"` 是数学库 libm，C 代码中的 `sqrt` 来自它。`kind` 可以指定 `dynamic`、`static` 或 macOS 的 `framework`，省略时由平台决定。
- `[native]` 表中还可以写 `include = ["vendor/include"]` 添加头文件搜索目录，`c_flags = ["-O2"]` 传递编译选项。
- 这三种配置都可以加上 `when = { os = "linux" }` 这样的平台条件，写法和第 28 章选择 Scoop 源码的条件一样。

单文件模式不读取这些配置，所以带 C 源码的程序必须是 Cone。

### `@CLayout`：和 C 布局相同的 struct

`tally_summary` 按值返回一个 C struct。Scoop 这边要声明一个字段顺序、类型都相同的 struct，并标注 `@CLayout`：

```scoop
{{#include ../../examples/ch36/tally/src/native.scoop}}
```

`@CLayout` 要求编译器按 C 的规则排列字段：顺序与声明一致，每个字段按自身的对齐要求放置，必要时插入填充。普通 struct 的布局由编译器决定，不保证和 C 一样，所以不能用在 C 函数的签名中。`@CLayout(packed = 1L)`、`@CLayout(aligned = 16L)` 分别对应 C 的 `#pragma pack(1)` 和 `__attribute__((aligned(16)))`。

`@CLayout` struct 的每个字段都必须是 C-FFI-safe 的，不能含有引用：

```scoop
{{#include ../../examples/ch36/clayout_ref_fail.scoop}}
```

```text
{{#include ../../examples/ch36/clayout_ref_fail.error}}
```

再看 `native.scoop` 中的其他声明：

- C 的 `Tally *` 是一个不透明的指针，Scoop 不关心它指向什么，所以用 `Ptr<Unit>`。`tally_new` 可能返回 `NULL`，声明为 `Ptr<Unit>?`。
- `tally_stddev` 的第二个参数 `double *out` 是输出参数，对应 `Ptr<Double>`。
- 所有声明都是 `internal`，只在这个 Cone 内部可见（第 15 章）。外部代码只能使用下面的安全封装。

## 36.9　封装成安全的 class

```scoop
{{#include ../../examples/ch36/tally/src/tally.scoop}}
```

```scoop
{{#include ../../examples/ch36/tally/src/main.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/tally/expected.txt}}
```

`Tally` 的使用者看不到任何指针，也不需要写 `@Unsafe`。这个封装体现了几条通用的做法：

- **句柄放在 `Option` 里。** `handle` 的类型是 `Ptr<Unit>?`，`close` 之后变成 `None`。每次使用前通过 `live()` 取出，已关闭时抛出异常，而不是把一个已经释放的指针交给 C。
- **实现 `Closeable`。** 第 21 章介绍过，`use { ... }` 结束时一定会调用 `close`，即使中间抛出了异常。`close` 先把字段置为 `None`，再调用 `tally_free`，所以重复调用 `close` 是安全的。
- **把 C 的约定翻译成 Scoop 的约定。** `tally_stddev` 用返回值 0 / 1 加输出参数表示“可能没有结果”，封装成 `stddev: Double?`；`addressOf(result)` 把局部变量的地址交给 C，C 把结果写进 `result`。
- **构造失败时立即报告。** `tally_new` 返回 `NULL` 时，构造器抛出异常，不会得到一个半初始化的对象。

### `release`：忘记 `close` 时的兜底

`Tally` 最后的 `release { ... }` 块会在**对象被 GC 回收之前**执行，用来释放使用者忘记 `close` 的资源。它不是 Kotlin/JVM 的 `finalize`，限制要严格得多：

- 只能写在 final class 中（普通 class 默认就是 final 的），每个 class 最多一个。
- 块里没有 `this`，只能读取本 class 自己声明的字段，并且读取到的值不能含有引用。这里只读了 `handle`，它是一个 `Ptr<Unit>?`。
- 不能分配对象、抛出或捕获异常、调用普通的 Scoop 函数；可以在 `@Unsafe` 中直接调用 C 函数，但这个 C 函数不能回调 Scoop、不能阻塞。
- 它是“尽力而为”的：不保证什么时候执行、在哪个线程执行，程序退出时也不会补做。

所以，`release` 只是安全网。**确定性的释放仍然要靠 `close` 和 `use`。** 不要依赖 `release` 去刷新缓冲区、提交事务或释放锁，这些操作必须在确定的时间点完成。

如果 C 资源占用的内存很大，GC 并不知道它的存在，可能迟迟不回收这些 Scoop 对象。这种情况下更要及时 `close`。

## 36.10　深入一点：`ForeignCallback`

36.6 的 `FunPtr` 回调限制很多：不能捕获变量，不能分配对象，只能在同一个线程上同步调用。实际的 C 库往往需要更多：GUI 库在事件循环中回调，线程库在新线程中运行用户函数，网络库在 IO 线程上通知完成。这些回调要访问 Scoop 对象，自然也会分配内存、触发 GC。

核心库为此提供了 `foreignCallback`。它把一个**普通的 Scoop 闭包**注册到运行时，得到一对值：一个 C 函数指针和一个 context 指针。C 库调用这个函数指针时，原样传回 context 指针，运行时就能找到对应的闭包，进入 Scoop 执行它。

这要求 C API 本身提供一个 `void *userdata`（或叫 `context`、`arg`）参数，大多数设计良好的 C 回调接口都有。没有这个参数的 API 只能使用 36.6 的 `@NoGC` 回调。

下面的 C 库有两个回调接口：`events_each_prime` 在返回之前同步回调；`events_ticker_start` 启动一个 C 线程，在那个线程上回调。

```c
{{#include ../../examples/ch36/events/native/events.h}}
```

Scoop 这边的声明：

```scoop
{{#include ../../examples/ch36/events/src/native.scoop}}
```

### 注册与释放

```scoop
{{#include ../../examples/ch36/events/src/primes.scoop}}
```

`foreignCallback<F>(closure, contextIndex, mode)` 的三个参数：

- **`F`** 是回调在 C 中的**完整**签名，包括 context 参数，必须显式写出，这里是 `(Ptr<Unit>, Int) -> Unit`，对应 `void (*)(void *context, int32_t value)`。和 `FunPtr` 一样，其中只能使用 C-FFI-safe 的类型。
- **`contextIndex`** 指出哪个参数是 context，从 0 开始计数，必须是常量，那个参数的类型必须是 `Ptr<Unit>`。
- **`closure`** 是真正执行的 Scoop 函数。它的类型是 `F` **去掉** context 参数之后的函数类型，这里是 `(Int) -> Unit`，因为 context 指针由运行时消费，闭包看不到它。闭包可以捕获变量、分配对象、调用任何普通函数，这里调用了局部函数 `accept`，后者修改捕获的 `found`。闭包不能是 `suspend` 函数。
- **`mode`** 是 `ForeignCallbackMode.Reusable`（可以调用任意多次）或 `OneShot`（恰好调用一次），也必须是常量。

结果 `ForeignCallback<F>` 有两个字段：`function` 是 `FunPtr<F>`，`context` 是 `Ptr<Unit>`，把它们分别传给 C 函数的两个参数。

注册会让运行时持有这个闭包，所以必须**恰好释放一次**：`releaseForeignCallback(callback)`。释放的时机是关键：

- **`Reusable`**：确认 C 库**不会再调用它**之后才能释放。同步接口在 C 函数返回之后即可，所以 `primesUpTo` 把释放放在 `finally` 中；保存回调的接口，要等对应的“取消注册”函数返回，或者线程已经 join 之后。释放后 C 再调用它，是致命错误，程序会终止。
- **`OneShot`**：C 库成功接受回调之后，释放的责任就**转移**给了这次回调本身，调用结束后由运行时释放；如果 C 函数报告失败、回调根本不会被调用，就由你自己释放。标准库 `scoop.platform` 的 `Thread.start` 就是这样启动原生线程的。如果之后还想读取回调的状态，要在转移之前先用 `retainForeignCallback` 多取得一份所有权，读完再释放这一份。

`ForeignCallback` 本身是一个普通的值，复制它不会增加所有权，也就不需要多释放一次。

### 回调中的异常

异常不能穿过 C 代码向上传播：C 不知道怎样展开 Scoop 的栈帧。所以运行时会在回调的边界处**捕获**闭包抛出的异常：

- C 收到的返回值是全零，对 `void` 回调来说就是正常返回；C 库会继续它的工作，例子中 C 还会继续回调 13、17……
- 运行时只保存**第一个**异常，状态变为 `ForeignCallbackState.Failed`。

所以 C 函数返回之后，要主动检查：`foreignCallbackFailure(callback)` 返回保存的异常，`native.scoop` 中的 `rethrowFailure` 把它重新抛出。`primesUpTo(30, max = 10)` 在遇到 11 时抛出的异常，就是这样回到调用方的：

```text
failed: prime 11 is larger than 10
```

如果 C 的回调有返回值，比如“返回 0 表示继续，返回 1 表示停止”，要想清楚全零的返回值对这个 C 库意味着什么。必要时可以在闭包内部捕获异常，返回一个明确的“停止”值。

### 在 C 的线程上回调，以及 Context

```scoop
{{#include ../../examples/ch36/events/src/ticker.scoop}}
```

`events_ticker_start` 创建的线程是 C 自己的线程，Scoop 运行时从未见过它。回调第一次在这个线程上进入时，运行时会自动登记这个线程，建立 Scoop 代码需要的线程状态，回调结束后再撤销。闭包内可以正常分配对象、触发 GC，就像在 Scoop 自己的线程上一样。

回调中的 **Context** 需要特别注意。Context 是属于一个逻辑任务的动态绑定（第 26 章）：`context(logger) { ... }` 在块内绑定一个 `Logger`，块内直接或间接调用的、声明了 `context(logger: Logger)` 的函数都能取得它，不需要层层传参。C 的线程上没有任何 Scoop 绑定，所以 `foreignCallback` 在**注册的那一刻**拍下当前所有绑定的快照，以后每次调用都从这个快照开始，各次调用之间互不影响。`runTicker` 在 `context(logger) { ... }` 中注册，回调里的 `onTick` 就能取得 `logger`。

快照只看注册时的绑定，调用时外层有没有绑定都不起作用，同步的 C 调用也是如此。`runTickerWithoutContext` 在注册之后才绑定 `logger`，回调中的 `onTick` 找不到它，抛出 `MissingContextException`，这个异常同样被保存起来，在 join 之后重新抛出。完整的输出：

```text
{{#include ../../examples/ch36/events/expected.txt}}
```

```scoop
{{#include ../../examples/ch36/events/src/main.scoop}}
```

### 两种回调的比较

| | `@NoGC` 函数加 `::name`（36.6） | `foreignCallback`（本节） |
| --- | --- | --- |
| 回调函数 | 顶层 `@NoGC` 函数 | 任意普通闭包 |
| 捕获变量、分配对象、调用普通函数 | 不能 | 能 |
| 抛出异常 | 不能 | 能，在边界处捕获并保存 |
| 调用线程 | 只能在发起调用的线程上同步调用 | 任意线程，可以在以后调用 |
| Context | 无 | 注册时的快照 |
| C API 要求 | 任意函数指针参数 | 必须有 `void *userdata` 参数 |
| 生命周期 | 无需管理 | 必须恰好释放一次 |
| 开销 | 一次普通的 C 函数调用 | 每次调用都要进入运行时 |

还有几点限制：

- 回调由 C 代码同步调用，不能是 `suspend` 函数。需要把 C 的完成通知交给协程时，在闭包中调用某个 `Continuation` 的 `resume`（第 25 章）。核心库把阻塞操作交给后台线程执行时（第 26 章的阻塞池）就是这样做的：原生线程上的 `OneShot` 回调完成工作后，恢复等待中的协程。
- `function` 指针进入 Scoop 时会与 GC 协调，所以它不能当作 `GCLeafFunPtr` 使用（第 37 章）。
- 释放之后再调用、`OneShot` 回调被调用两次、程序退出之后还在调用，都是致命错误，运行时会打印诊断信息并终止程序。

## 36.11　深入一点：Scoop ABI

到目前为止，C 函数都按 **C ABI** 调用：参数只能是 C 理解的类型，字符串和数组要先借出指针。`@Extern` 还有另一种模式 `abi = "scoop"`，C 函数按 **Scoop 自己的调用约定**接收参数，引用类型的值直接以 Scoop 对象指针的形式传进来：

```c
{{#include ../../examples/ch36/scoopabi/native/text.c}}
```

```scoop
{{#include ../../examples/ch36/scoopabi/src/main.scoop}}
```

输出：

```text
{{#include ../../examples/ch36/scoopabi/expected.txt}}
```

C 代码包含的 `scoop_rt.h` 是运行时的公开头文件，Cone 中的 C 源码编译时自动可用。其中定义了对象的布局（`ScoopString` 是对象头、字节数 `len` 和 UTF-8 字节 `data`），以及 GC 相关的函数。

Scoop ABI 主要供运行时和核心库的作者使用，标准库中也只有少数地方用到，比如 `scoop.json` 用它直接解析 `String` 中的浮点数，省掉一次复制。应用代码几乎总是应该使用 C ABI。只有当你**必须**让 C 直接读写 Scoop 对象，又不能接受复制的开销时，才考虑它。

### 调用方几乎没有限制，C 一方的责任很重

和 C ABI 正好相反，**Scoop ABI 的函数默认是安全的**，调用处不需要 `@Unsafe`：`main` 直接调用了 `countUpper`。编译器不检查 C 实现做了什么，它假定 C 实现遵守下面的全部约定。所以这样的声明应该放在 `internal` 层，由封装者保证正确；如果函数对参数有前提条件，可以给声明加上 `@Unsafe`，让调用方也必须进入 unsafe 上下文。

C 实现必须遵守的约定：

1. **传入的引用只在本次调用中有效。** 在调用任何可能触发 GC 的运行时函数之前，可以直接读取它们，`text_count_upper` 就是这样，不需要 pin。返回之后不能再使用这些引用。
2. **跨越可能触发 GC 的操作时，必须登记 root。** 分配对象（`scoop_rt_alloc`）、调用 Scoop 回调、强制回收等操作都可能移动对象。在此之前，把引用存进 C 的局部变量，用 `scoop_rt_push_native_roots` 登记这些变量的地址；操作结束后，**从这些变量重新读取**引用，因为 GC 可能已经把对象移走，并更新了变量里的地址。`text_total_length` 演示了这个模式，其中的 `scoop_runtime_gc_collect()` 只是一个代表，代表“任何可能触发 GC 的调用”。
3. **root 的登记要严格按栈的顺序撤销**，任何返回路径上都要 `pop`，包括出错时的路径。
4. **要在调用之后保留引用**，用 `scoop_rt_get_handle` 取得 handle，或者用 `scoop_rt_pin` 固定，对应 37.5 的 `GcHandle` 和 `pin`。
5. **向 Scoop 对象中写入引用之后，要调用 `scoop_rt_gc_write_barrier`**，否则分代 GC 可能漏掉这个引用。
6. **不要从对象地址加上自己算出的偏移读取数组元素。** 元素区的位置与元素类型的对齐有关，由编译器决定。需要数组数据时，在 Scoop 一侧用 `withDataPointer` 借出指针。
7. **不要让异常或 `longjmp` 穿过边界。** 用返回值报告错误，在 Scoop 一侧的封装函数中抛出异常。
8. **不要长时间运行或阻塞。** 调用 Scoop ABI 函数期间，线程仍可能持有对象的引用，GC 必须等它返回或进入运行时函数，才能开始回收，这会拖住所有线程。这一点和普通的 C ABI 调用不同。
9. **值类型参数使用 Scoop 自己的布局**，不一定和同样字段的 C struct 相同。在 Scoop ABI 函数中，参数尽量只用基本类型和引用类型。

违反这些约定的后果，通常不会立刻出现，而是在某次 GC 恰好发生在错误的时刻时才暴露。测试这类代码时，可以使用带 GC 压力测试的运行时，让 GC 尽可能频繁地发生，并强制移动对象：

```sh
SCOOP_GC_STRESS_MOVE=1 SCOOP_GC_STRESS_MINOR=1 scoop --enable-gc-stress run .
```

`--enable-gc-stress` 写在 `run` 之前，它让程序链接一个带压力测试功能的运行时；两个环境变量分别开启“强制移动”和“频繁的年轻代回收”。如果把 `text_total_length` 中登记 root 的代码删掉，在这种模式下就可能读到已经失效的地址。

### 其他规则

- Scoop ABI 的 extern 和 C ABI 一样，只能是顶层的、非泛型、非 `suspend` 的函数，不支持 `captureErrno`，也不能声明 extern 变量，不能用 `@GCLeaf`。
- 可以标注 `@NoGC`，表示 C 实现保证不会进入 GC。但 `@NoGC` 要求签名中没有引用类型，而 Scoop ABI 的意义恰恰在于传递引用，所以这种组合很少见：

  ```text
  {{#include ../../examples/ch36/scoop_abi_nogc_fail.error}}
  ```

- C ABI 的 C 函数如果想回调 Scoop，仍然要用 36.10 的 `foreignCallback`；它不会因此获得接收 Scoop 引用的能力。

## 36.12　几点补充

**C++。** Scoop 只按 C 的调用约定调用外部函数。调用 C++ 库时，先写一层 `extern "C"` 的包装函数，再声明这些包装函数。C++ 异常必须在 C++ 一侧捕获，不能穿过 FFI 边界；`longjmp` 也一样。

**阻塞调用。** 普通的 C 调用期间，GC 照常工作，所以 C 函数可以阻塞，比如等待文件或网络。对于很短的 C 函数，可以标注 `@GCLeaf` 省掉调用前后与 GC 的协调，见第 37 章。

**线程。** C 代码可能有自己的线程要求，比如某些 GUI 库只能在主线程调用。Scoop 不会替你检查，要看 C 库的文档。

**平台差异。** 同一个 C 函数在不同平台上的签名可能不同，比如 `long` 的宽度。可以把与平台有关的声明放在不同文件里，用第 28 章的 `[[sources]]` 平台条件选择。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| JVM：JNI，需要写 C 胶水代码 | `@Extern` 直接声明 C 函数 |
| Kotlin/Native：cinterop 从 `.def` 和头文件生成绑定 | 手写 `@Extern` 声明，逐个对照头文件 |
| `CPointer<T>`、`COpaquePointer` | `Ptr<T>`、`Ptr<Unit>` |
| `CPointer<T>?` | `Ptr<T>?`，`None` 就是 null |
| `memScoped { alloc<IntVar>() }` | 局部 `var` 加 `addressOf`，或者 `malloc` / `free` |
| `"text".cstr`、`refTo` | `withCString`、`withUtf8Bytes`、`withDataPointer` |
| `staticCFunction { ... }` | `@NoGC` 顶层函数加 `::name` |
| `StableRef.create(obj).asCPointer()` 作为 userdata，在回调中 `asStableRef().get()` | `foreignCallback` 注册闭包，C 原样传回 context（36.10） |
| `StableRef` | `GcHandle`（第 37 章） |
| JNI 的 `jobject`、局部引用和全局引用 | Scoop ABI 的直接引用、native root 和 handle（36.11） |
| `@OptIn(ExperimentalForeignApi::class)` | `@Unsafe` 块或函数 |
| `posix.errno` | `@Extern(captureErrno = true)` |

## 常见误用

- **声明的类型和 C 头文件不一致**：编译器无法发现，运行时读到错误的值。逐个参数对照头文件，优先使用定宽类型（36.3）。
- **把可能返回 `NULL` 的函数声明成返回 `Ptr<T>`**：应声明为 `Ptr<T>?`（36.4）。
- **以为外层的 `@Unsafe` 也覆盖 lambda**：lambda 和匿名函数要自己写 `@Unsafe` 块（36.2）。
- **保存借来的指针**：`withDataPointer`、`withCString` 的指针只在回调内有效（36.5）。
- **把局部变量的地址保存到函数返回之后**：变量不存在了，指针也就失效了（36.4）。
- **用 lambda 或普通函数作为 C 回调**：回调必须是 `@NoGC` 的顶层函数（36.6）。
- **调用一个 C 函数之后再单独读取 `errno`**：值可能已经被覆盖，用 `captureErrno`（36.7）。
- **普通 struct 用在 C 函数的签名中**：要加 `@CLayout`，字段顺序与 C 一致（36.8）。
- **只靠 `release` 释放资源**：它不保证执行时机，要用 `close` 和 `use`（36.9）。
- **让 C++ 异常穿过边界**：在 `extern "C"` 包装函数中捕获（36.12）。
- **在 C 可能还会调用时就释放 `ForeignCallback`**：释放要等到取消注册或线程 join 之后（36.10）。
- **C 返回后不检查 `foreignCallbackFailure`**：回调中的异常被悄悄吞掉了（36.10）。
- **以为回调会看到调用时的 Context**：它看到的是注册时的快照，要在 `context(...)` 中注册（36.10）。
- **Scoop ABI 函数在可能触发 GC 的调用之后还使用旧的引用**：要登记 root 并重新读取（36.11）。
- **在 Scoop ABI 函数中阻塞**：GC 会一直等待这个线程（36.11）。

## 小结

- 优先使用现成的库。自己写 FFI 时，分成内部的 `@Extern` 声明和对外的安全 API 两层。
- `@Extern` 声明一个没有函数体的顶层函数；C 函数是 unsafe 的，只能在 `@Unsafe` 块或 `@Unsafe` 函数中调用，lambda 要自己声明 `@Unsafe`。
- C 签名中只能使用 C-FFI-safe 的类型：定宽整数、浮点数、`Boolean`、`Ptr`、`FunPtr`、`@CLayout` struct 和整型枚举，不能有引用类型。
- `Ptr<T>` 不为 null，可能为 null 的指针写 `Ptr<T>?`；指针运算以元素为单位；`addressOf` 取变量地址，用于输出参数。
- 字符串和数组通过 `withCString`、`withUtf8Bytes`、`withDataPointer` 临时借给 C，指针只在回调内有效。
- C 回调用 `@NoGC` 顶层函数和 `::name` 得到 `FunPtr`；`errno` 用 `captureErrno` 随返回值取得。
- 在 Cone 中用 `[[native.sources]]` 编译 C 源码，用 `[[native.libraries]]` 链接系统库。
- 封装 C 句柄的 class 实现 `Closeable`，句柄放在 `Option` 中；`release` 块只是兜底。
- C 库需要在其他线程或以后回调、回调需要访问 Scoop 对象时，用 `foreignCallback` 注册闭包，恰好释放一次；回调中的异常要在 C 返回后检查，Context 来自注册时的快照。
- `abi = "scoop"` 让 C 直接接收 Scoop 引用，调用方不需要 `@Unsafe`，但 C 实现必须遵守 root、handle、写屏障和不阻塞等约定。

## 练习

1. 用 C 标准库的 `toupper`（`int toupper(int c)`）写一个安全函数 `asciiUpper(text: String): String`，只转换 ASCII 字母。提示：先用 `text.withUtf8Bytes` 读出字节。
2. 用 `getenv`（`char *getenv(const char *name)`，变量不存在时返回 `NULL`）写一个函数 `env(name: String): String?`，用 `String.fromCString` 复制结果（36.5）。完成后，再与 `scoop.platform` 中的 `environmentVariable` 对比（第 31 章）：它为什么返回 `OsString?` 而不是 `String?`？
3. 给 36.8 的 C 库增加 `void tally_reset(Tally *tally)`，在 `Tally` 中加上对应的 `reset()` 方法。
4. 修改 36.6 的例子，把 `MutableArray<Double>` 按降序排序。如果把 `compareDoubles` 写成 `return (a.cast<Double>().load() - b.cast<Double>().load()).toInt()`，会有什么问题？
5. 把 36.10 的 `runTicker` 改为使用 `ForeignCallbackMode.OneShot`，让 C 只调用一次（`count = 1`）。哪些释放调用需要调整？如果 `events_ticker_start` 返回了 `NULL` 呢？
6. 给 36.11 的 C 代码增加一个 Scoop ABI 函数 `int64_t text_count_byte(const ScoopString *text, int32_t byte)`，统计某个字节出现的次数。它需要登记 root 吗？为什么？
7. 下面的封装有什么问题？

   ```scoop
   class Buffer(size: ULong) {
       val data: Ptr<Unit> = ...   // 用 malloc 分配

       fun close() {
           @Unsafe
           {
               cFree(data)
           }
       }
   }
   ```
