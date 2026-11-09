# 第 9 章　enum 与 tuple

第 8 章的 struct 描述的是“同时具有这些字段”的数据，比如一个点同时有 `x` 和 `y`。程序里还有另一类同样常见的数据：它是**几种情况之一**。一个形状要么是圆、要么是矩形；一次网络请求要么还在加载、要么成功、要么失败。

在 Kotlin 里，“几种情况之一”通常用 `sealed class` 层级来表达；如果每种情况都不带数据，就用 `enum class`。Scoop 把这两者合并成了一个值类型：**enum**。每种情况称为一个 **variant**，每个 variant 可以携带自己的数据，也可以什么都不带。

本章后半部分介绍 **tuple**：不需要声明、按位置组合几个值的匿名值类型，Kotlin 中 `Pair`、`Triple` 的用途都可以用它代替。

本章介绍：

- enum 的四种 variant 形式及其构造方法；
- 什么时候可以省略 `Shape.` 前缀；
- 给 enum 添加方法、计算属性、companion 和接口实现；
- 泛型 enum、递归 enum；
- 整型枚举：有名字的整数常量；
- tuple 的写法，以及 tuple 与 struct 怎么选。

读取 variant 中的数据要用 `when` 模式匹配。本章只用最基本的写法 `case Shape.Circle(val r) -> ...`：`val r` 表示把这个位置的值取出来，放进一个叫 `r` 的新变量。完整的规则留到第 11 章。

## 9.1　第一个 enum

```scoop
{{#include ../../examples/ch09/shapes.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/shapes.expected}}
```

`Shape` 的五个 variant 展示了全部四种形式：

| 形式 | 例子 | 构造 |
| --- | --- | --- |
| 单元 variant | `Dot` | `Shape.Dot` |
| 位置 payload | `Circle(Double)`、`Rect(Double, Double)` | `Shape.Rect(2.0, 3.0)` |
| 命名字段（block 式） | `Text { content: String, size: Int }` | `Shape.Text(content = "hi", size = 12)` |
| 命名字段（构造器式） | `Line(val length: Double, val width: Int = 1)` | `Shape.Line(4.0)` 或 `Shape.Line(length = 4.0, width = 3)` |

variant 携带的数据叫作 **payload**。几点说明：

- 每个 variant 都是一个构造器，用 `Shape.Circle(1.5)` 这样的写法构造，和调用函数一样。
- 位置 payload 的各项没有名字，只能按位置传参，读取时也按位置绑定：`case Shape.Rect(val w, val h)` 把两个值分别绑定到新变量 `w` 和 `h`。
- 两种命名字段形式意义相同，区别在于构造方式。构造器式的写法和 struct 主构造器完全一样，支持位置参数、命名参数和默认值；block 式**只能**用命名参数构造：

```scoop
{{#include ../../examples/ch09/named_variant_fail.scoop}}
```

```text
{{#include ../../examples/ch09/named_variant_fail.error}}
```

- 读取命名字段时按名字绑定：`case Shape.Text {val content, val size}` 把字段 `content`、`size` 分别取到同名的变量里。

和 struct 一样，enum 是值类型：构造后不可修改，没有身份，不能用 `===` 比较。只要所有 payload 都能比较，enum 就自动支持 `==`：两个值相等，当且仅当它们是同一个 variant，并且 payload 相等。

> **从 Kotlin 过来**
>
> 上面的 `Shape` 在 Kotlin 中大致是这样：
>
> ```kotlin
> sealed class Shape {
>     object Dot : Shape()
>     data class Circle(val radius: Double) : Shape()
>     data class Rect(val w: Double, val h: Double) : Shape()
>     ...
> }
> ```
>
> 每个子类都是一个独立的 class，实例分配在堆上。Scoop 的 enum 是一个值类型，所有 variant 共享同一个类型 `Shape`，值直接存放在变量、字段或数组中，不需要单独分配对象。

## 9.2　variant 不是类型

在 Kotlin 的 sealed class 层级中，`Circle` 本身也是一个类型，可以写 `fun area(c: Circle)`，也可以用 `is Circle` 判断。Scoop 的 variant **不是类型**，只是 `Shape` 这个类型的一种取值：

```scoop
{{#include ../../examples/ch09/variant_type_fail.scoop}}
```

```text
{{#include ../../examples/ch09/variant_type_fail.error}}
```

同样，`shape is Shape.Circle` 也不能写。判断一个值是哪个 variant、取出它的 payload，都要通过 `when`。

如果确实需要一个“只能是圆”的类型，就单独声明一个 struct，再让 variant 携带它：

```scoop
struct Circle(val radius: Double)

enum Shape {
    Dot,
    Round(Circle)
}
```

这样 `fun area(c: Circle)` 就只接受圆。

## 9.3　省略 `Shape.` 前缀

每次都写 `Shape.` 有些啰嗦。有三种情况可以省略它。

**第一，在 `case` 分支里。** 编译器知道 `when` 匹配的值的类型，所以 `case Circle(val r)` 会在 `Shape` 中查找 `Circle`。9.4 的例子在 `when (this)` 中就是这样写的。

**第二，在类型已经明确的地方构造。** 如果变量声明了类型、函数参数或返回值的类型是这个 enum，就可以只写 variant 名：

```scoop
{{#include ../../examples/ch09/contextual.scoop}}
```

`val d: Direction = North` 和 `opposite` 的两个返回值都省略了前缀，因为那里期望的类型就是 `Direction`。如果没有期望类型，编译器不会到处去猜 `North` 属于哪个 enum：

```scoop
{{#include ../../examples/ch09/contextual_fail.scoop}}
```

```text
{{#include ../../examples/ch09/contextual_fail.error}}
```

**第三，用 `import` 引入全部 variant。** `import Light.*` 之后，`Red`、`Yellow`、`Green` 在整个文件中都可以直接使用，不再依赖期望类型：

```scoop
{{#include ../../examples/ch09/light.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/light.expected}}
```

后面第 12 章会看到，`Some` 和 `None` 能直接使用，也是因为核心库默认导入了 `Option` 的全部 variant。

## 9.4　给 enum 添加成员

enum 的花括号体中，在 variant 列表之后可以声明方法、计算属性和 companion object，也可以实现接口：

```scoop
{{#include ../../examples/ch09/coffee.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/coffee.expected}}
```

- variant 列表和成员之间不需要分号，换行即可。
- 在成员里通常用 `when (this)` 区分当前值是哪个 variant。这里的 `case` 都省略了 `Coffee.` 前缀。
- `case Latte(_)` 中的 `_` 表示“不关心这个值”；`case Custom {val cost, ..}` 中的 `..` 表示“其余字段不关心”。第 10、11 章会详细介绍。
- enum 不能有构造器、`init` 块或带存储的属性：数据只能放在各 variant 的 payload 里。

能力方面的规则和 struct 一样：`==` 是自动的，`ToString`、`Equals<T>`、`Hash` 需要显式实现（见 8.7）。上例实现了 `ToString`，所以可以把 `coffee` 直接插入 f-string。

## 9.5　泛型 enum

enum 可以有类型参数。下面的 `Loaded<T>` 描述一份“正在加载”的数据所处的状态：

```scoop
{{#include ../../examples/ch09/loaded.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/loaded.expected}}
```

`Loaded<Int>` 和 `Loaded<String>` 是两个不同的类型，它们之间不能互相转换。

你其实已经用过一个泛型 enum：`Option<T>`。它在核心库中的定义就是一个有 `Some(T)` 和 `None` 两个 variant 的 enum。第 12 章会专门介绍它。

## 9.6　递归 enum

用 enum 表示表达式树是一个经典的例子：一个表达式要么是数字，要么是两个表达式相加。直觉上会这样写：

```scoop
{{#include ../../examples/ch09/recursive_fail.scoop}}
```

但编译器会拒绝：

```text
{{#include ../../examples/ch09/recursive_fail.error}}
```

原因在于 enum 是值类型，payload 直接存放在 enum 值内部。如果 `Add` 里直接装着两个 `Expr`，那么一个 `Expr` 就要装得下两个 `Expr`，它的大小就无法确定了。解决办法是在递归的位置**经过一次引用**：引用的大小是固定的，它指向的对象放在堆上。最直接的做法是用一个 class 包一层：

```scoop
{{#include ../../examples/ch09/expr.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/expr.expected}}
```

`Node` 是 class，`Add(Node, Node)` 中只保存两个引用，大小就固定了。`Array<Expr>` 这样的数组字段同样可以打破递归，因为数组本身也是引用类型。

> **从 Kotlin 过来**
>
> 在 Kotlin 里，`sealed class Expr` 的子类本来就是堆上的对象，递归不需要任何额外处理。在 Scoop 中，递归的数据结构要在某处显式经过一个引用类型，这是值类型的代价。

## 9.7　整型枚举

有时你只需要一组“有名字的整数”，比如 HTTP 状态码、协议里的消息类型、C 库中的常量。这时可以在 enum 名后写上一个整数类型：

```scoop
{{#include ../../examples/ch09/status.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/status.expected}}
```

整型枚举的规则：

- 父类型必须是一种整数类型（`Int`、`Long`、`UByte` 等）。
- 每个 variant 都必须写出它的值，不会按顺序自动编号，也不能带 payload。值不能重复。
- `Status` 的值可以直接当作 `Int` 使用：赋给 `Int` 变量、传给 `Int` 参数都可以，没有运行时开销。
- 反过来不行。一个 `Int` 不能变成 `Status`，即使它的值恰好是 404：

```scoop
{{#include ../../examples/ch09/status_from_int_fail.scoop}}
```

```text
{{#include ../../examples/ch09/status_from_int_fail.error}}
```

- 整型枚举没有自己的运算符，算术运算使用 `Int` 的运算符，结果也是 `Int`。所以 `status + 1` 得到 `405`，而 `status += 1` 会报错，因为结果无法存回 `Status` 类型的变量：

```scoop
{{#include ../../examples/ch09/status_math_fail.scoop}}
```

```text
{{#include ../../examples/ch09/status_math_fail.error}}
```

要把外部传来的整数转换成 `Status`，需要自己写一个函数，用 `when` 逐个匹配，遇到不认识的值时返回 `None` 或抛出异常。这正是整型枚举的意义：`Status` 类型的值一定是声明过的某个 variant。

> **从 Kotlin 过来**
>
> Kotlin 的 `enum class Status(val code: Int)` 是一组单例对象，`code` 是它们的属性，`Status.NotFound.code` 才是整数。Scoop 的整型枚举本身就是整数：`Status.NotFound` 可以直接当 `Int` 用。如果你需要的是 Kotlin `enum class` 那种“一组常量，每个都附带若干属性”，用普通 enum 加计算属性（9.4）即可。

## 9.8　tuple

tuple 把几个值按位置组合在一起，不需要预先声明：

```scoop
{{#include ../../examples/ch09/tuples.scoop}}
```

输出：

```text
{{#include ../../examples/ch09/tuples.expected}}
```

- tuple 字面量写作 `(1, "one")`，类型写作 `(Int, String)`。
- 元素按位置访问：`pair._1`、`pair._2`……编号**从 1 开始**。
- 用 tuple 让函数返回多个值很方便，如 `minMax` 返回 `(Int, Int)`。调用方可以按位置读取，也可以用 `val (lo, hi) = ...` 直接解构（第 10 章）。
- 只有一个元素的 tuple 必须写尾随逗号：`(42,)`。不带逗号的 `(42)` 只是加了括号的表达式，结果就是 `42`。
- 零个元素的 tuple 写作 `()`，它就是 `Unit`，`()` 和 `Unit` 是同一个值。
- tuple 是值类型：不可修改，没有身份；所有元素都能比较时，自动支持 `==`。

tuple 是匿名的，所以它不能声明实现任何接口，也就没有 `ToString`、`Equals<T>`、`Hash`。不能直接打印 tuple：

```scoop
{{#include ../../examples/ch09/tuple_print_fail.scoop}}
```

```text
{{#include ../../examples/ch09/tuple_print_fail.error}}
```

也不能把它作为 `HashMap` 的 key：

```scoop
{{#include ../../examples/ch09/tuple_key_fail.scoop}}
```

```text
{{#include ../../examples/ch09/tuple_key_fail.error}}
```

遇到这些需求时，就该把 tuple 换成一个 struct 了。

### tuple 还是 struct？

| 场景 | 选择 |
| --- | --- |
| 函数返回两三个值，调用方马上就解构 | tuple |
| 局部的临时组合，例如遍历 Map 时的 `(key, value)` | tuple |
| 数据会在多个函数之间传递，或者出现在公开 API 中 | struct |
| 各个值需要有名字才能看懂，例如宽和高 | struct |
| 需要打印、作为 Map 的 key、实现接口 | struct |

经验法则：如果你开始纠结 `_1` 到底是宽还是高，就应该给它起个名字，改用 struct。

> **从 Kotlin 过来**
>
> Kotlin 的 `Pair<A, B>` 和 `Triple<A, B, C>` 在 Scoop 里写成 `(A, B)` 和 `(A, B, C)`，`first`、`second` 分别对应 `_1`、`_2`。Scoop 的 tuple 不限元素个数，并且是值类型。`1 to "one"` 这种写法在 Scoop 中不存在，直接写 `(1, "one")` 即可。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `sealed class` 加若干子类 | `enum`，每个子类对应一个 variant |
| `object Dot : Shape()` | 单元 variant `Dot` |
| `data class Circle(val r: Double) : Shape()` | `Circle(Double)` 或 `Circle(val r: Double)` |
| `is Circle` 判断，smart cast 后访问属性 | `when` 中的 `case Circle(val r)` |
| `fun f(c: Circle)`，子类作为类型 | 不支持；需要时把数据提取成单独的 struct |
| `enum class Light { RED, GREEN }` | `enum Light { Red, Green }` |
| `enum class Status(val code: Int)` | 整型枚举 `enum Status: Int { Ok = 200 }`，或普通 enum 加计算属性 |
| `Status.values()`、`ordinal`、`name` | 没有自动生成，需要时自己写 |
| `Pair`、`Triple`、`a to b` | `(A, B)`、`(A, B, C)`、`(a, b)` |
| `pair.first`、`pair.second` | `pair._1`、`pair._2` |

## 常见误用

- **把 variant 当作类型**：`fun f(c: Shape.Circle)`、`x is Shape.Circle` 都不能写。用 `when` 匹配，或者把数据提取成单独的 struct。
- **block 式命名字段 variant 用位置参数构造**：`Text("hi", 12)` 会报错，改写为 `Text(content = "hi", size = 12)`，或改用构造器式的 `Text(val content: String, val size: Int)`。
- **省略前缀，却没有期望类型**：`val d = North` 会报错。写 `Direction.North`、给变量标注类型，或者 `import Direction.*`。
- **直接递归的 enum**：payload 中要经过一个引用类型，例如一个 class 或数组。
- **想把整数直接变成整型枚举**：只能自己写转换函数，处理不认识的值。
- **打印 tuple、把 tuple 当 Map 的 key**：tuple 没有这些能力，改用 struct。
- **把 `(42)` 当作单元素 tuple**：要写 `(42,)`。

## 小结

- enum 表示“几种情况之一”，每个 variant 可以不带数据，也可以带位置 payload 或命名字段。
- enum 是值类型：不可修改、没有身份，`==` 自动可用，`ToString` 等能力需要显式实现。
- variant 不是类型，判断和取数据都通过 `when`。
- 在 `case` 分支中、有期望类型的位置，或者 `import E.*` 之后，可以省略 enum 名前缀。
- enum 可以有方法、计算属性、companion，可以实现接口，也可以是泛型的；`Option<T>` 就是一个泛型 enum。
- 递归的 enum 需要在 payload 中经过一个引用类型。
- 整型枚举是一组有名字的整数，可以当作底层整数使用，但整数不能隐式转回枚举。
- tuple 是匿名的按位置组合，适合临时返回多个值；需要名字或能力时改用 struct。

## 练习

1. 定义 `enum Command { Quit, Move(Int, Int), Say { text: String } }`，写一个函数把它转换成描述字符串，并让 `Command` 实现 `ToString`。
2. 给 9.7 的 `Status` 写一个函数 `fun statusOf(code: Int): Status?`，不认识的状态码返回 `None`。
3. 在 9.6 的 `Expr` 中增加减法 `Sub` 和取负 `Neg`，并扩展 `eval`。
4. 写一个函数 `fun divide(a: Int, b: Int): (Int, Int)`，返回商和余数；再思考：如果这个结果要在多个模块之间传来传去，你会把它改成什么？
