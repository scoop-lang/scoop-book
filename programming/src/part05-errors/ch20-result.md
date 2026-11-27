# 第 20 章　`Result` 与错误建模

到目前为止，表示失败的手段有两种：

- **`Option`**（第 12 章）能表达“没有结果”，但说不出**为什么**没有；
- **异常**（第 19 章）能携带任意详细的失败信息，但它不出现在函数签名中，调用方看不出一个函数会不会失败、会怎样失败，忘记处理也不会有任何提示。

很多失败介于两者之间：它是**预期之内**的（用户输错了、业务规则不允许），调用方**必须**处理，而且需要知道具体原因才能处理好。标准库为这种情况提供了 `Result<T, E>`：成功时带着 `T` 类型的值，失败时带着 `E` 类型的错误，两种情况都写在返回类型里。

本章介绍：

- `Result` 的定义、构造和读取；
- 怎样为错误选择合适的类型；
- `map`、`flatMap`、`recover`、`fold` 等组合函数；
- 在函数中遇到失败就提前返回的写法；
- `Result` 和异常之间的相互转换：`runCatching`、`getOrThrow`；
- 异常、`Result`、`Option` 各自适合的场合。

## 20.1　`Result` 是一个 enum

和 `Option` 一样，`Result` 也是一个普通的 enum。它定义在标准库 `scoop.std` 中（省略了成员）：

```scoop
enum Result<T, E> {
    Success(T),
    Failure(E)
}
```

`T` 是成功值的类型，`E` 是错误的类型。下面的例子把文本解析成端口号，失败时说明原因：

```scoop
{{#include ../../examples/ch20/ports.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/ports.expected}}
```

要点：

- `Result` 在 `scoop` 包中，要 `import scoop.*`。单文件程序默认就能使用标准库；在 Cone 中要先声明 `scoop.std` 依赖（第 23 章）。
- 构造时写 `Result.Success(port)` 和 `Result.Failure(PortError.Empty)`。和第 9.3 节讲的一样，在有期望类型的位置（比如这里的返回值）和 `case` 分支中，可以省略前缀，写成 `Success(port)`、`case Success(val port)`。本书的例子保留 `Result.` 前缀，让读者一眼看出这是 `Result`。
- 读取时用 `when` 匹配，`case Result.Success(val port)` 取出成功值，`case Result.Failure(val error)` 取出错误。两种情况都必须处理，漏掉一个，编译器会报告 `when` 不完整。这就是 `Result` 比异常好的地方：**调用方不可能忘记失败的情况**。
- `parsePort` 的签名 `Result<Int, PortError>` 本身就是文档：它可能失败，失败的原因是 `PortError` 中的某一种。

缺少 `import` 时，编译器会提示从哪里导入：

```scoop
{{#include ../../examples/ch20/import_fail.scoop}}
```

```text
{{#include ../../examples/ch20/import_fail.error}}
```

构造 `Result` 时，编译器需要知道 `T` 和 `E` 两个类型参数。在 `parsePort` 中，它们来自函数的返回类型。没有这样的“期望类型”时，`Result.Success(8080)` 只能推断出 `T` 是 `Int`，推断不出 `E`：

```scoop
{{#include ../../examples/ch20/infer_fail.scoop}}
```

```text
{{#include ../../examples/ch20/infer_fail.error}}
```

这时要么给变量写上类型 `val result: Result<Int, String> = Result.Success(8080)`，要么显式写出类型参数 `Result.Success<Int, String>(8080)`。

和 `Option` 一样，`Result` 没有实现 `ToString`，不能直接 `println`；payload 能比较时可以用 `==` 比较。

## 20.2　为错误选择类型

`E` 可以是任何类型，没有“必须是异常”的限制。常见的选择有三种：

- **`String`**：最省事，适合小脚本或者错误只用来显示给人看的场合。缺点是调用方只能显示它，无法根据错误的种类做不同的处理。
- **enum**：最推荐的做法。每个 variant 是一种失败，带着各自需要的数据，比如 `NotANumber` 带着原文，`OutOfRange` 带着解析出的数值。调用方用 `when` 区分处理，编译器检查是否覆盖了全部情况。
- **异常类型**：错误需要在某些时候转换成异常抛出（20.5），或者错误本身来自某个异常时，可以直接用异常类作为 `E`。

enum 的好处在 API 演化时最明显。假设后来给 `PortError` 加了一个 `Reserved` variant，表示系统保留的端口，所有没有处理它的 `when` 都会在编译时报错：

```scoop
{{#include ../../examples/ch20/exhaustive_fail.scoop}}
```

```text
{{#include ../../examples/ch20/exhaustive_fail.error}}
```

（报错中的 `Reserved(-2147483648)` 是编译器举出的一个没有被覆盖的值，payload 取什么都可以。）如果错误是用字符串或异常表示的，新增的失败情况只能靠调用方自己发现。

> **从 Kotlin 过来**
>
> Kotlin 标准库的 `Result<T>` 只有一个类型参数，失败的一方**总是** `Throwable`，主要用于 `runCatching` 一类的场合。Scoop 的 `Result<T, E>` 更接近 Rust 的 `Result` 或者 Arrow 库的 `Either`：错误类型由你决定，通常是一个描述业务失败的 enum。在 Kotlin 里为了同样的目的，你可能会写一个 `sealed class` 层级；在 Scoop 中，直接用带数据的 enum（第 9 章）作为 `E`。

## 20.3　组合函数

用 `when` 读取 `Result` 总是可行的，但对于“成功就继续处理，失败就原样传下去”这类常见的写法，标准库提供了一组扩展函数：

```scoop
{{#include ../../examples/ch20/combinators.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/combinators.expected}}
```

循环中的三步构成了一条处理链：先解析数量，再检查库存，最后计算总价。任何一步失败，后面的步骤都被跳过，错误原样传到最后，由 `fold` 统一转换成要打印的文本。

| 函数 | `Success(v)` 时 | `Failure(e)` 时 | 结果类型 |
| --- | --- | --- | --- |
| `map { v -> r }` | `Success(r)` | 原样保留 | `Result<R, E>` |
| `mapError { e -> f }` | 原样保留 | `Failure(f)` | `Result<T, F>` |
| `flatMap { v -> result }` | 函数返回的 `Result` | 原样保留 | `Result<R, E>` |
| `recover { e -> v }` | 原样保留 | `Success(v)` | `Result<T, E>` |
| `fold({ v -> r }, { e -> r })` | 调用第一个函数 | 调用第二个函数 | `R` |
| `getOrElse { e -> v }` | `v` | 调用函数得到的值 | `T` |
| `getOrNone()`、`toOption()` | `Some(v)` | `None` | `T?` |
| `errorOrNone()` | `None` | `Some(e)` | `E?` |
| `onSuccess { v -> }`、`onFailure { e -> }` | 只在对应情况下执行，返回原来的 `Result` | | `Result<T, E>` |
| `getOrThrow()` | `v` | 抛出 `e`（要求 `E` 是异常类型，见 20.5） | `T` |

另外，`isSuccess`、`isFailure` 两个属性判断是哪一种情况；`Option` 的 `toResult { e }` 把 `None` 变成带错误的 `Failure`，例子中的 `parseQuantity` 用它把 `toIntOrNone` 的结果转换成 `Result`。

几点说明：

- `map` 和 `flatMap` 的区别和 `Option` 中一样：变换函数返回普通值用 `map`，返回 `Result` 用 `flatMap`，否则会得到嵌套的 `Result<Result<R, E>, E>`。
- `flatMap` 要求变换函数返回**同一个错误类型** `E`。两步的错误类型不同时，先用 `mapError` 把它们统一起来。
- `getOrElse`、`getOrNone` 会丢掉错误信息，适合在“已经不关心为什么失败”的地方使用，比如处理链的最末端。

`.flatMap(::checkStock)` 把一个已有的函数作为变换函数传进去（第 7 章的函数引用）。如果改成直接写 lambda，会遇到一个类型推断的问题：

```scoop
{{#include ../../examples/ch20/lambda_infer_fail.scoop}}
```

```text
{{#include ../../examples/ch20/lambda_infer_fail.error}}
```

lambda 中的 `Result.Success(quantity)` 没有期望类型可以参考，推断不出 `E`，这就是第一条报错。第二条报错是连带的结果：`Option` 也有一个 `flatMap`，编译器尝试了它，也没有成功。看到这种成对的报错时，先看第一条。解决方法是在 lambda 中显式写出类型参数：

```scoop
{{#include ../../examples/ch20/lambda_infer.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/lambda_infer.expected}}
```

或者像 `combinators.scoop` 那样，把逻辑写成一个声明了返回类型的函数，再传入函数引用。后一种写法通常更清楚。

## 20.4　遇到失败就提前返回

一个函数要依次调用几个返回 `Result` 的函数，只要有一个失败就把错误返回给调用方。这是 `Result` 最常见的用法：

```scoop
{{#include ../../examples/ch20/early_return.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/early_return.expected}}
```

**写法一** 对每个 `Result` 用 `when` 取值：成功时 `when` 的值就是取出的值，失败时直接 `return Result.Failure(error)`。`return` 的类型是 `Nothing`，所以这个分支不影响 `when` 的类型，`host` 的类型就是 `String`。这种写法啰嗦一点，但代码是从上到下的直线，步骤再多也不会变复杂。

**写法二** 用 `flatMap` 和 `map` 把步骤串起来。只有两三步的时候很简洁，步骤一多，lambda 就会一层套一层，后面的步骤还要用到前面的结果时尤其明显。

注意写法一中**不能**用 `getOrElse` 来代替 `when`：

```scoop
{{#include ../../examples/ch20/lambda_return_fail.scoop}}
```

```text
{{#include ../../examples/ch20/lambda_return_fail.error}}
```

真正的原因是第二条：lambda 中不能写裸 `return`（第 7 章），`return` 无法从 lambda 里直接返回外层的 `doubledPort`。第一条报错同样是编译器尝试 `Option.getOrElse` 留下的。

> **从 Kotlin 过来**
>
> Kotlin 中 `val port = parse(text).getOrElse { return Failure(it) }` 能用，是因为 Kotlin 的 `getOrElse` 是 `inline` 函数，lambda 中的 `return` 是“非局部返回”，直接从外层函数返回。Scoop 没有非局部返回，`inline` 也不改变语义（第 7 章）。
>
> Rust 用 `?` 运算符做同样的事：`let port = parse(text)?;`。Scoop 没有这个运算符，写法一的 `when` 加 `return` 就是对应的写法。

## 20.5　与异常相互转换

`Result` 和异常经常需要互相转换：调用的库抛出异常，而你想返回 `Result`；或者反过来，在某一层你已经不打算处理错误，想把它变成异常交给上层。

```scoop
{{#include ../../examples/ch20/convert.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/convert.expected}}
```

**异常 → `Result`。** 最直接的做法是 `try` 表达式：`try` 块返回 `Success`，`catch` 块返回 `Failure`。`parseTimeout` 就是这样。注意它**只捕获 `NumberFormatException`**，也就是这一层知道怎么处理的那一种异常，其他异常照常向外传递。

标准库还提供了 `runCatching { ... }`：执行代码块，正常结束时得到 `Success`，抛出**任何**异常时得到 `Failure`，结果类型是 `Result<T, Throwable>`。它用起来方便，但要小心：

- 错误类型是 `Throwable`，调用方要处理时，还得用 `is` 判断具体是哪种异常，失去了 `Result` 在类型上的好处；
- 它会捕获所有异常，包括程序的 bug（`IndexOutOfBoundsException`、`UnwrapException`），以及协程被取消时的 `CancellationException`（第 25 章），把它们和预期之内的失败混在一起。

所以 `runCatching` 适合用在程序的边界上，比如测试中、或者“任何失败都记录下来然后继续”的批处理循环里；在业务代码中，优先像 `parseTimeout` 那样只捕获预期的异常。

**`Result` → 异常。** `getOrThrow()` 在成功时返回值，在失败时把错误**作为异常抛出**。因此它要求 `E` 是 `Throwable` 的子类型：

```scoop
{{#include ../../examples/ch20/get_or_throw_fail.scoop}}
```

```text
{{#include ../../examples/ch20/get_or_throw_fail.error}}
```

错误类型不是异常时，先用 `mapError` 把它换成异常，再调用 `getOrThrow`，这就是 `requireTimeout` 的写法。`runCatching` 的结果错误类型是 `Throwable`，可以直接 `getOrThrow()`，抛出的是原来那个异常对象。

## 20.6　异常、`Result` 还是 `Option`

三种手段各有适合的场合。下面这个例子在一个小小的注册流程中同时用到了它们：

```scoop
{{#include ../../examples/ch20/signup.scoop}}
```

输出：

```text
{{#include ../../examples/ch20/signup.expected}}
```

- **查询用户是否存在，用 `Option`。** `ageOf` 找不到用户是完全正常的情况，“为什么没有”也不需要解释：就是没有。
- **校验用户输入，用 `Result`。** 名字太短、名字已被占用、年龄不是数字，这些都是预期之内的失败，调用方需要知道具体原因，才能给用户一个有用的提示。`signup` 用 20.4 的写法一取出年龄，失败时直接返回提示文本。
- **存储故障，用异常。** `store is full` 不是用户的错，`signup` 这一层也无能为力，所以 `save` 抛出 `StorageException`，`signup` 不处理它，让它一直传到 `main`，由最外层统一报告“服务不可用”，后续请求也不再处理。

可以把选择归纳成一张表：

| 情况 | 用什么 | 例子 |
| --- | --- | --- |
| 值可能不存在，不需要说明原因 | `Option` | Map 查询、`firstOrNone`、`toIntOrNone` |
| 预期之内的失败，调用方要根据原因处理 | `Result` | 校验用户输入、业务规则检查、解析外部数据并报告错误位置 |
| 调用方用错了：参数不合法、状态不对 | 异常 | `IllegalArgumentException`、`IllegalStateException` |
| 环境出了问题：文件、网络、系统调用失败 | 异常 | `PlatformException`、HTTP 库的各种异常 |
| 这一层处理不了，要交给上层统一处理 | 异常 | 上例的 `StorageException` |

Scoop 的标准库和官方库也遵循这套约定：

- 普通的解析和转换函数在失败时抛出具体的异常，比如 `toInt` 抛出 `NumberFormatException`；
- 带 `OrNone` 后缀的配对函数把**约定好的正常失败**变成 `None`，比如 `toIntOrNone`；其他无关的异常照常抛出；
- 只问“是不是”的函数返回 `Boolean`；
- 需要把失败的原因交给调用方时，返回 `Result`。例如 `scoop.http` 中的 `HttpSetCookie.resolve` 检查服务器发来的 cookie 是否可以接受，返回 `Result<HttpCookie, HttpCookieRejection>`：cookie 被拒绝是常有的事，`HttpCookieRejection` 这个 enum 说明了被拒绝的原因。

此外还有几条经验：

- **不要把不同的失败压成同一个 `None`。** “配置项没写”和“配置项写错了”对用户来说是两回事，前者可能用默认值就好，后者应该报错。把它们都变成 `None`，就丢失了这个区别。
- **不要用异常做普通的流程控制。** 判断一段文本是不是数字，用 `toIntOrNone`，而不是调用 `toInt` 再捕获异常。
- **在层的边界上转换。** 底层库抛出的异常，到了业务层，如果调用方需要逐个处理，就转换成 `Result`（20.5）；如果处理不了，就让它继续传递，或者包装成这一层的异常（第 19 章）。到了程序的最外层，再把剩下的异常统一报告给用户。
- **同一种失败只用一种方式报告。** 一个函数既返回 `Failure` 又可能为同样的原因抛出异常，调用方就得两头都防着。

工具链附带的 `scoop example language/errors` 是一个把第 19 章和本章结合起来的短例子：用 `finally` 保证收尾，用 `toResult` 和 `flatMap` 组合解析与业务校验。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `Result<T>`（失败总是 `Throwable`） | `Result<T, E>`，`E` 由你决定；`runCatching` 的结果是 `Result<T, Throwable>` |
| `Result.success(v)`、`Result.failure(e)` | `Result.Success(v)`、`Result.Failure(e)`，需要能推断出两个类型参数 |
| `sealed class` 表示的成功 / 失败层级 | 带数据的 enum 作为 `E`（第 9 章） |
| `r.getOrNull()` | `r.getOrNone()` |
| `r.exceptionOrNull()` | `r.errorOrNone()` |
| `r.getOrDefault(0)` | `r.getOrElse { 0 }` |
| `r.getOrElse { return ... }` | lambda 中不能 `return`；用 `when` 取值并 `return`（20.4） |
| `r.mapCatching { ... }` | 不存在；在 `flatMap` 的函数中用 `try` 表达式捕获预期的异常，返回 `Failure`（20.5） |
| `r.isSuccess`、`r.onSuccess { }`、`r.fold(...)` | 相同 |
| `r.getOrThrow()` | 相同，但要求 `E` 是异常类型 |
| `when (r) { is Success -> ... }` | `when (r) { case Result.Success(val v) -> ... }` |
| Rust 的 `?` | 不存在；用 `when` 加 `return` |

## 常见误用

- **忘记 `import scoop.*`**：`Result` 和所有组合函数都在 `scoop` 包中。
- **在没有期望类型的地方构造 `Result`**：推断不出 `E`，给变量写上类型，或者显式写出类型参数。lambda 中尤其常见（20.3）。
- **在 lambda 中写 `return` 想提前返回**：Scoop 没有非局部返回，用 `when` 取值（20.4）。
- **把错误类型都写成 `String`**：调用方只能显示，不能区分处理。需要区分时用 enum。
- **处处使用 `runCatching`**：它会把 bug 和取消也变成 `Failure`。只捕获预期的异常。
- **对错误类型不是异常的 `Result` 调用 `getOrThrow`**：先 `mapError` 成异常。
- **直接打印 `Result`**：它没有实现 `ToString`，用 `when` 或 `fold` 转换成文本。
- **把所有失败都变成 `None`**：调用方无法区分“没有”和“出错了”。

## 小结

- `Result<T, E>` 是标准库中的 enum，variant 为 `Success(T)` 和 `Failure(E)`，使用时要 `import scoop.*`；构造和匹配的写法与其他 enum 相同。
- 失败写进了返回类型，调用方用 `when` 读取时必须处理两种情况。
- 错误类型 `E` 可以是任何类型，推荐用带数据的 enum 描述各种失败，让编译器检查是否处理完整。
- `map`、`mapError`、`flatMap`、`recover`、`fold`、`getOrElse` 等函数组合 `Result`；lambda 中构造 `Result` 时可能需要显式写出类型参数。
- 遇到失败就提前返回，用 `when` 取值加 `return`；Scoop 没有 `?` 运算符，lambda 中也不能 `return`。
- `try` 表达式和 `runCatching` 把异常变成 `Result`，`getOrThrow` 把 `Result` 变回异常；优先只捕获预期的异常。
- 正常的缺失用 `Option`，预期之内、需要说明原因的失败用 `Result`，调用方的错误和环境故障用异常。

## 练习

1. 为第 12 章练习 1 的 `parsePort` 写一个 `Result` 版本，错误类型是本章的 `PortError`。然后写 `portOrDefault(text: String): Int`：文本为空时返回 8080，其他错误时抛出 `IllegalArgumentException`，消息说明原因。
2. 写一个函数 `parseDate(text: String): Result<Date, DateError>`，解析 `2026-11-26` 格式的日期，其中 `Date` 是一个 struct，`DateError` 是一个 enum，至少区分“格式不对”“月份不合法”“日期不合法”三种情况。分别用 20.4 的写法一和写法二实现。
3. 下面的代码哪里需要改？为什么？

```scoop
{{#include ../../examples/ch20/exercise_total.scoop:total}}
```

4. 给 20.6 的 `UserStore` 增加一个 `rename(old: String, new: String)` 操作：原名字不存在、新名字已被占用时如何报告？存储已满呢？说明你为每种情况选择 `Option`、`Result` 还是异常的理由。
