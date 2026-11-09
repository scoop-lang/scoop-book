# 第 12 章　`Option`：没有 null 的世界

Kotlin 用可空类型 `String?` 把“可能没有值”写进了类型系统，比 Java 前进了一大步。但在运行时，`null` 仍然是一个特殊的值：它不属于任何类，靠编译器的规则和 `?.`、`!!` 等运算符来防止误用；和 Java 代码打交道时，平台类型 `String!` 还会让检查失效。

Scoop 没有 `null`。“可能没有值”由一个普通的 enum 表示：

```scoop
enum Option<T> {
    Some(T),
    None
}
```

这就是核心库里 `Option` 的定义（省略了 companion）。你在第 9～11 章学到的 enum 知识可以直接用在它身上：用 `Some(v)` 构造有值的情况，用 `None` 表示没有值，用 `when` 匹配取出值，编译器检查两种情况都处理了。`String?` 这种熟悉的写法仍然保留，它只是 `Option<String>` 的简写。

本章介绍：

- 怎样构造和读取 `Option`；
- `?.`、`?:`、`!!` 在 Scoop 中的含义；
- 为什么判断“不是 None”之后不能直接使用值，以及应该怎么写；
- 嵌套的 `T??`；
- 标准库提供的 `Option` 工具函数和返回 `Option` 的 API 约定。

## 12.1　`T?` 就是 `Option<T>`

```scoop
{{#include ../../examples/ch12/lookup.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/lookup.expected}}
```

要点：

- 返回类型 `User?` 和 `Option<User>` 完全是同一个类型，例子最后把一个 `Option<User>` 直接赋给了 `User?` 变量。书中和标准库通常使用更短的 `T?`。
- 有值时写 `Some(User(1, "Ada"))`，没有值时写 `None`。`Some` 和 `None` 默认可用，不需要 import，也不需要写成 `Option.Some`。
- 读取值的基本方式是 `when` 加 `case Some(val user)`，和匹配其他 enum 完全一样：`val user` 把 `Some` 里的值取到新变量 `user` 中。漏掉 `None` 分支，编译器会报告 `when` 不完整。
- `case None` 匹配的是 variant `None`，不要写成 `case val None`，那样会声明一个叫 `None`、能匹配任何值的新变量，编译器会给出遮蔽警告（11.5）。
- 只要 payload 类型能比较，`Option` 也能用 `==` 比较，所以 `sugar == Some(User(1, "Ada"))` 成立。

Scoop 中没有 `null` 字面量：

```scoop
{{#include ../../examples/ch12/null_fail.scoop}}
```

```text
{{#include ../../examples/ch12/null_fail.error}}
```

编译器把 `null` 当成了一个找不到的变量名，因为它在 Scoop 里只是一个普通标识符。

> **从 Kotlin 过来**
>
> 在 Kotlin 中，一个 `String` 值可以直接赋给 `String?` 变量。在 Scoop 中，`String` 和 `String?` 是两个不同的类型，有值时必须写 `Some("Ada")` 把它包起来。这条规则一开始可能显得啰嗦，但它让“这里可能没有值”在每个构造的地方都清清楚楚。

## 12.2　`?.`、`?:` 与 `!!`

Kotlin 的三个空安全运算符在 Scoop 中都保留了，含义也基本相同，只是作用对象变成了 `Option`：

```scoop
{{#include ../../examples/ch12/operators.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/operators.expected}}
```

**安全调用 `a?.b`**：`a` 是 `Some(v)` 时访问 `v.b`，并把结果包进 `Some`；`a` 是 `None` 时，结果直接是 `None`，`.b` 不会执行。所以 `?.` 的结果**始终是 `Option`**：`findUser(1)?.name?.charLength` 的类型是 `Long?`。安全调用可以连续使用，链条上任何一环是 `None`，整个结果就是 `None`。

**Elvis `a ?: b`**：`a` 是 `Some(v)` 时取 `v`，是 `None` 时取 `b`。结果是普通值，不再是 `Option`，所以 `?:` 通常放在链条的最后，用来“给缺失的情况一个答案”。`?:` 有几个实用的特性：

- 右侧只在 `a` 为 `None` 时才求值。
- 右侧可以是 `return` 或 `throw`，例如 `findUser(id) ?: throw IllegalArgumentException(...)`，这是“找不到就报错”的惯用写法。
- 可以连写：`primary ?: secondary ?: "default"` 从左到右找第一个有值的。

**非空断言 `a!!`**：`a` 是 `Some(v)` 时取 `v`，是 `None` 时抛出 `UnwrapException`：

```scoop
{{#include ../../examples/ch12/unwrap.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/unwrap.expected}}
```

`!!` 表示“我确定这里一定有值，如果没有，那是程序的 bug”。只有在业务逻辑确实能保证有值时才使用它；如果缺失是正常情况，应该用 `when` 或 `?:` 处理。

安全调用也可以单独作为语句使用，用来“有值就调用，没值就什么都不做”，见下一节的写法三。

## 12.3　判断之后不会自动收窄

在 Kotlin 中，下面的写法很常见：

```kotlin
if (name != null) {
    println(name.length)   // 这里 name 已经被收窄为 String
}
```

照搬到 Scoop：

```scoop
{{#include ../../examples/ch12/no_narrowing_fail.scoop}}
```

```text
{{#include ../../examples/ch12/no_narrowing_fail.error}}
```

`name != None` 本身是合法的比较，结果也正确，但比较之后，`name` 的类型仍然是 `Option<String>`，而 `Option` 没有 `charLength` 这个成员。Scoop 不会因为一次比较就把 `Option<String>` 当成 `String` 使用。用 `is` 判断也不行，因为 `Some` 是 enum 的变体，不是类型：

```scoop
{{#include ../../examples/ch12/is_some_fail.scoop}}
```

```text
{{#include ../../examples/ch12/is_some_fail.error}}
```

规则很一致：**要使用 `Option` 里的值，就得把它取出来。** 取出值的写法有下面几种：

```scoop
{{#include ../../examples/ch12/rewrite.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/rewrite.expected}}
```

- **写法一：`when` 取出值。** 两种情况都需要处理时使用，`case Some(val s)` 中的 `s` 就是普通的 `Session`。
- **写法二：`?: return` 提前退出。** `val s = session ?: return` 之后，`s` 是普通值，函数剩下的部分都可以直接使用它。这是“没有值就什么都不做”的最常用写法，也可以换成 `?: throw ...`，或在循环里用 `?: break`、`?: continue`。
- **写法三：`?.` 直接调用。** 只需要在有值时调用一个方法、不关心结果时，写 `active?.touch()` 就够了。

此外，下一节介绍的 `map`、`getOrElse` 等函数也能在不显式取值的情况下处理 `Option`。

用 `== None` 判断还有一个限制：它要求 payload 类型能比较。如果 payload 是一个没有定义 `equals` 的 class，这个比较本身就无法通过编译：

```scoop
{{#include ../../examples/ch12/compare_fail.scoop}}
```

```text
{{#include ../../examples/ch12/compare_fail.error}}
```

所以，判断“有没有值”时也应该优先用 `when`，而不是 `== None`。

## 12.4　嵌套的 `T??`

在 Kotlin 中，`String??` 和 `String?` 是同一个类型。Scoop 不是这样：`String??` 是 `Option<Option<String>>`，两层 `Option` 各自有意义。

```scoop
{{#include ../../examples/ch12/nested.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/nested.expected}}
```

`findUser(id)` 返回 `User?`，`User` 的 `email` 字段又是 `String?`，所以 `findUser(id)?.email` 的结果是 `String??`，它有三种可能：

| 值 | 含义 |
| --- | --- |
| `Some(Some(address))` | 找到用户，用户有邮箱 |
| `Some(None)` | 找到用户，但用户没有邮箱 |
| `None` | 没有找到用户 |

这种区分有时恰好是你需要的，比如在缓存中，“缓存了‘没有邮箱’这个结果”和“还没有缓存”是两回事。如果不关心是哪一层缺失，可以用 `?: None` 去掉一层：`Some(x)` 取出 `x`（本身是 `String?`），`None` 换成 `None`，结果就是 `String?`。下一节的 `flatMap` 也能做到同样的事。

> **从 Kotlin 过来**
>
> 当 `?.` 调用的方法本身返回 `Option` 时，结果会多出一层。Kotlin 中 `user?.email` 的类型是 `String?`，Scoop 中是 `String??`。遇到 `must be of type Option<String>, found Option<Option<String>>` 这样的报错时，通常就是这个原因。

## 12.5　`Option` 的工具函数

标准库 `scoop.std` 为 `Option` 提供了一组扩展函数，位于 `scoop` 包中，使用前需要 `import scoop.*`：

```scoop
{{#include ../../examples/ch12/helpers.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/helpers.expected}}
```

| 函数 | 有值时 | 没有值时 | 结果类型 |
| --- | --- | --- | --- |
| `map { v -> r }` | `Some(r)` | `None` | `R?` |
| `flatMap { v -> optR }` | 函数的结果 | `None` | `R?` |
| `filter { v -> bool }` | 条件为真时保持原值，否则 `None` | `None` | `T?` |
| `getOrElse { default }` | `v` | 调用函数得到的默认值 | `T` |
| `orElse { otherOpt }` | 原值 | 调用函数得到的另一个 `Option` | `T?` |
| `fold({ v -> r }, { r })` | 调用第一个函数 | 调用第二个函数 | `R` |

它们和 `?.`、`?:` 的关系：

- `opt.map { v -> v.name }` 和 `opt?.name` 效果相同。简单的成员访问用 `?.` 更简洁；需要对值做更复杂的计算时用 `map`。
- `opt.getOrElse { ... }` 和 `opt ?: ...` 效果相似。
- `flatMap` 只保留一层 `Option`，用于变换函数本身返回 `Option` 的情况。

`Option` 本身没有实现 `ToString`，所以不能直接 `println` 一个 `Option`：

```scoop
{{#include ../../examples/ch12/print_fail.scoop}}
```

```text
{{#include ../../examples/ch12/print_fail.error}}
```

打印之前，先用 `?:` 或 `when` 把它变成一个确定的值。

## 12.6　标准库中的 `Option`

标准库遵循一个统一的约定：**“没有找到”或“格式不对”这类正常的缺失情况返回 `Option`；参数非法、内部故障这类错误抛出异常。** 常见的例子：

```scoop
{{#include ../../examples/ch12/stdlib.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/stdlib.expected}}
```

- **Map 查询**：`ages["Bob"]` 的类型是 `Int?`，键不存在时为 `None`。
- **`OrNone` 后缀**：名字以 `OrNone` 结尾的函数返回 `Option`，它们对应 Kotlin 中以 `OrNull` 结尾的函数，例如 `toIntOrNone`（在 `scoop.text` 包中）、`firstOrNone`、`lastOrNone`、`singleOrNone`。
- **`NotNone` 后缀**：`mapNotNone` 对每个元素做变换并丢弃 `None` 的结果，`filterNotNone` 从 `Option` 列表中提取所有 `Some` 的值。它们对应 Kotlin 的 `mapNotNull`、`filterNotNull`。
- **迭代器**：`next()` 返回 `Option`，没有更多元素时为 `None`，配合 `?: break` 非常自然。
- **`as?`**：转换失败时得到 `None`。
- **异常的 `message`**：类型是 `String?`，因为异常不一定带消息。前面的例子一直用 `e.message ?: "..."` 读取它。

`Option` 只能表达“有”或“没有”，不能说明**为什么**没有。需要携带失败原因时，标准库使用 `Result<T, E>`，第 20 章会介绍它，以及如何在异常、`Option` 和 `Result` 之间做选择。

> **深入一点：`Option` 的内存开销**
>
> 一般情况下，`Option<T>` 需要比 `T` 多一点空间，用来记录“是 Some 还是 None”，就像其他带数据的 enum 一样。
>
> 但对于引用类型（class 实例、接口等）和指针，Scoop 保证 `Option<T>` 和 `T` **一样大**。原因是合法的引用永远不会是全零的地址，编译器就用全零表示 `None`，不需要额外的标记。这个空着不用的位模式被称为“空位”（niche）。因此 `Option<User>`（若 `User` 是 class）在运行时的表示和 Kotlin 的可空引用一样紧凑，用 `Option` 包装引用类型不会带来额外开销。

## 12.7　可选属性：代替 `lateinit`

Kotlin 用 `lateinit var` 表示“稍后才会初始化”的属性。Scoop 不支持 `lateinit`：

```scoop
{{#include ../../examples/ch12/lateinit_fail.scoop}}
```

```text
{{#include ../../examples/ch12/lateinit_fail.error}}
```

替代做法是把属性声明为 `Option`。class 中 `Option` 类型的 `var` 属性可以省略初值，默认为 `None`：

```scoop
{{#include ../../examples/ch12/property.scoop}}
```

输出：

```text
{{#include ../../examples/ch12/property.expected}}
```

和 `lateinit` 相比，“还没有初始化”变成了类型的一部分：每次读取都必须处理 `None` 的情况，不会在运行时意外遇到“属性尚未初始化”的异常。省略初值只适用于 class 的属性，局部变量仍然要写 `= None`。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `val s: String? = null` | `val s: String? = None` |
| `val s: String? = "Ada"` | `val s: String? = Some("Ada")` |
| `if (s != null) use(s)` | `when (s) { case Some(val v) -> use(v); case None -> {} }` |
| `val v = s ?: return` | 相同 |
| `s?.let { use(it) }` | `s?.let` 不存在；用 `when` 或 `val v = s ?: return` 取出值；只调用 `s` 自己的方法时可以写 `s?.method()` |
| `s?.length ?: 0` | `s?.charLength ?: 0L` |
| `s!!` | 相同，缺失时抛 `UnwrapException` |
| `x as? String` | 相同，结果是 `String?` |
| `list.firstOrNull()` | `list.firstOrNone()` |
| `"42".toIntOrNull()` | `"42".toIntOrNone()`（`import scoop.text.*`） |
| `list.mapNotNull { ... }` | `list.mapNotNone { ... }` |
| `lateinit var conn: Connection` | `var conn: Connection?`（属性可省略初值，默认 `None`），使用时用 `when` 或 `!!` 取值（12.7） |
| 平台类型 `String!` | 不存在；来自 C 的指针用 `Option<Ptr<T>>` 表示（第 36 章） |
| `String??` 等同于 `String?` | `String??` 是两层 `Option`，`Some(None)` 和 `None` 不同 |

## 常见误用

- **写 `null`**：Scoop 没有 `null`，用 `None`。
- **把普通值直接赋给 `T?`**：要写 `Some(value)`。
- **判断 `!= None` 后直接使用值**：类型不会收窄。用 `when`、`?: return` 或 `?.`（12.3）。
- **用 `== None` 判断有没有值**：payload 不支持比较时无法编译，优先用 `when`。
- **对正常的缺失情况使用 `!!`**：缺失是预期之内的事时，用 `?:` 给出默认值或提前返回。
- **忘记 `?.` 的结果会多一层**：方法本身返回 `Option` 时，安全调用得到 `T??`（12.4）。
- **直接 `println` 一个 `Option`**：`Option` 没有实现 `ToString`，先用 `?:` 或 `when` 取出值。
- **使用 `lateinit`**：改用 `Option` 类型的属性（12.7）。
- **找不到 `map`、`getOrElse` 等函数**：它们在 `scoop` 包中，需要 `import scoop.*`。

## 小结

- Scoop 没有 `null`。`T?` 是 `Option<T>` 的简写，后者是一个普通的 enum，变体为 `Some(T)` 和 `None`。
- 读取值用 `when`，或者用 `?.` 安全调用、`?:` 提供默认值；`!!` 在缺失时抛出 `UnwrapException`。
- `?.` 的结果仍是 `Option`，`?:` 的结果是普通值；`?:` 的右侧可以是 `return` 或 `throw`。
- 比较或判断之后，`Option` 的类型不会收窄；要使用值，就把值取出来。
- `T??` 是两层 `Option`，不会自动合并。
- 标准库中，正常的缺失情况返回 `Option`（如 Map 查询、`OrNone` 系列函数），错误则抛出异常。

## 练习

1. 写一个函数 `parsePort(text: String): Int?`：文本能解析为 1～65535 之间的整数时返回 `Some`，否则返回 `None`。提示：使用 `toIntOrNone` 和 `filter`。
2. 用上题的函数实现 `portOrDefault(text: String): Int`，解析失败时返回 8080。分别用 `?:` 和 `getOrElse` 各写一遍。
3. 有一个 `HashMap<String, String?>`，保存用户名到昵称的映射（用户可能没有设置昵称）。写一个函数，对给定的用户名返回三种不同的描述：“用户不存在”、“用户没有昵称”、“昵称是 xxx”。
4. 下面的 Kotlin 代码改写成 Scoop：

   ```kotlin
   fun firstLong(words: List<String>): Int {
       val w = words.firstOrNull { it.length > 5 } ?: return 0
       return w.length
   }
   ```
