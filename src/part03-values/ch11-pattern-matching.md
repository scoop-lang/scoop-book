# 第 11 章　用 `when` 做模式匹配

Kotlin 的 `when` 能按值、按区间、按类型分支，但取数据时总要绕一步：先用 `is Circle ->` 判断类型，再在分支里通过 smart cast 读 `shape.radius`。如果数据是嵌套的，比如“一个点击事件，位置在原点”，就只能在分支里再写 `if`。

Scoop 保留了 Kotlin `when` 的全部普通用法，并加入了 **模式匹配**：用 `case` 开头的分支可以直接描述数据的“形状”，在判断的同时把需要的部分取出来。第 9 章已经用过最简单的 `case Shape.Circle(val r) ->`，第 10 章介绍了解构的写法。本章把这些组合起来，讲清楚 `when` 的完整用法：

- 普通条件分支与 `case` 分支的区别；
- enum、struct、tuple 和字面量模式，以及它们的嵌套组合；
- 模式里的名字：裸名字只表示 variant，取出数据要写 `val`；
- 守卫、smart cast 和 `when (val x = ...)`；
- `when` 作为表达式，以及编译器如何检查分支是否“穷尽”。

本章最后用模式匹配写一个小型算术表达式计算器。

## 11.1　两种分支：普通条件与 `case`

先看一个混合了各种写法的例子：

```scoop
{{#include ../../examples/ch11/conditions.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/conditions.expected}}
```

`classify`、`sign` 和 `kind` 里的大多数分支都是 Kotlin 写法，含义也和 Kotlin 一样：

| 分支头 | 含义 |
| --- | --- |
| `0 ->` | subject 等于这个值，即 `n == 0` |
| `1, 2, 3 ->` | 等于其中任意一个 |
| `in 4..9 ->` | subject 在这个范围或集合里 |
| `is String ->` | subject 是这个类型；分支中可以按该类型使用它 |
| `else ->` | 前面都不成立时进入，必须放在最后 |
| 无 subject 的 `n > 0 ->` | 条件为真时进入 |

`classify` 中的 `case val x if x < 0 ->` 是一个 **`case` 分支**。分支头以 `case` 开头，后面跟的是一个**模式**，而不是表达式。这条界线非常重要：

- **普通分支**的分支头是表达式，会被求值，然后和 subject 比较。
- **`case` 分支**的分支头是模式，描述 subject 应该具有的形状。模式里的 `val x` 表示把匹配到的值**绑定**到一个新变量 `x`，它可以在守卫和分支体中使用。这里的 `val` 和 `val x = 1` 中的 `val` 是同一个意思：声明一个只读的新变量。

同一个 `when` 里可以混用两种分支，各个分支按书写顺序依次尝试，进入第一个成功的分支后就结束，不会“贯穿”到下一个分支。

模式描述的是 subject 的形状，所以 `case` 分支需要有 subject。无 subject 的 `when` 中写 `case` 会被拒绝：

```scoop
{{#include ../../examples/ch11/no_subject_fail.scoop}}
```

```text
{{#include ../../examples/ch11/no_subject_fail.error}}
```

## 11.2　enum 模式

模式匹配最常见的用途是拆开 enum：

```scoop
{{#include ../../examples/ch11/shapes.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/shapes.expected}}
```

enum 有几种 variant，就有几种对应的模式：

- **位置 payload**：`Circle(val r)`、`Rect(val w, val h)`，按位置把每一项绑定到一个新变量。不关心的位置写 `_`，例如 `Rect(val w, _)`。
- **命名字段**：`Polygon {val name, ..}` 按字段名绑定。`val name` 表示把字段 `name` 取到同名变量 `name` 中；`sides: 3` 表示这个字段必须等于 3；末尾的 `..` 表示其余字段不关心。没有列出全部字段时，必须以 `..` 结尾。
- **单元 variant**：直接写名字，比如 `Empty`，不加 `val`。

每个要取出的值都要单独写 `val`：`Rect(val w, val h)` 中的两个 `val` 一个都不能省。和第 9.3 节讲的一样，`case` 分支里可以省略 `Shape.` 前缀，编译器按 subject 的类型查找 variant。例子中第一个分支写了完整的 `Shape.Circle(val r)`，其余都省略了，两种写法效果相同。

带 payload 的 variant 必须写出形状，不能只写名字：

```scoop
{{#include ../../examples/ch11/payload_fail.scoop}}
```

```text
{{#include ../../examples/ch11/payload_fail.error}}
```

不需要 payload 时写 `Circle(_)`。

每个 `case` 分支只能有一个模式。想让几个 variant 走同一个分支时，要分开写：

```scoop
{{#include ../../examples/ch11/alternatives_fail.scoop}}
```

```text
{{#include ../../examples/ch11/alternatives_fail.error}}
```

对于没有 payload 的 variant，也可以改用普通分支 `Light.Red, Light.Yellow ->`：普通分支支持逗号，比较的是相等性。

## 11.3　struct 与 tuple 模式

struct 和 tuple 同样可以作为模式：

```scoop
{{#include ../../examples/ch11/points.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/points.expected}}
```

struct 模式的结构和第 10 章的解构一致，区别有两点：模式可以失败；要绑定的名字前面要写 `val`。

- `Point(0, 0)`：按位置匹配，两个字段都必须是 0；
- `(0, val y)`：subject 的类型已经确定是 `Point`，类型名可以省略；
- `{x: val px, y: 0}`：按字段名匹配，`y` 必须是 0，字段 `x` 绑定到新变量 `px`，相当于第 10 章的重命名 `{x: px}`；
- `Point {val x, val y}`：按字段名把全部字段绑定到同名变量，配合守卫判断；
- `_`：匹配任何值，常放在最后兜底。

tuple 模式 `(true, false)` 按位置逐项匹配。`both` 没有写 `else`，因为四个分支已经覆盖了两个 `Boolean` 的全部组合，编译器能够确认这一点（见 11.8）。

struct 模式只能用在 subject 的静态类型**就是**这个 struct 的时候。如果 subject 是 `Any` 或某个接口，就不能直接写 struct 模式：

```scoop
{{#include ../../examples/ch11/any_fail.scoop}}
```

```text
{{#include ../../examples/ch11/any_fail.error}}
```

这种情况先用 `is Point ->` 判断类型，再在分支里使用它，见 11.6。

## 11.4　嵌套模式与字面量

模式可以任意嵌套：variant 的 payload 位置可以再放 struct 模式，struct 字段的位置可以再放字面量。下面的例子处理一组界面事件：

```scoop
{{#include ../../examples/ch11/events.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/events.expected}}
```

- `Click(Point(0, 0))`：`Click` 的 payload 必须是坐标为 (0, 0) 的点。
- `Click(Point {val x, ..}) if x < 0`：取出点的 `x`，再用守卫判断。
- `Click(val p)`：整个 `Point` 绑定到 `p`。`val` 可以放在任何一层，取出的是这一层的值。
- `Key('q', true)`：字符字面量和布尔字面量。
- `Scroll(-1)`：负数字面量。
- `Resize { width: 0, .. }`：命名字段的值是字面量。

可以用作模式的字面量包括整数、浮点数、`Char`、`String` 和 `Boolean`。模式里只能写字面量，不能写表达式，也不能写常量名或变量名，原因见下一节。

用 Kotlin 写这段逻辑，需要先判断事件类型，再用嵌套的 `if` 检查坐标和按键。在 Scoop 中，每种情况就是一行，读起来就像一张规则表。

## 11.5　模式里的名字：variant 还是新变量？

前面的模式中出现过三种“名字”：`Empty`、`Red` 这样的裸名字，`val r` 这样带 `val` 的名字，以及 `_`。它们的含义各不相同，而且没有例外：

| 写法 | 含义 |
| --- | --- |
| `Red` | 裸名字：**只能**是 subject 的一个 variant，匹配这个 variant |
| `val r` | 声明新变量 `r`，匹配这个位置上的任何值 |
| `_` | 匹配任何值，但不绑定 |

第一条规则意味着，裸名字从来不会变成变量，也不会去读外面已有的变量。如果它不是 subject 的 variant，编译器会直接报错。这样设计主要是为了防止**拼错 variant 名**：

```scoop
{{#include ../../examples/ch11/typo_fail.scoop}}
```

```text
{{#include ../../examples/ch11/typo_fail.error}}
```

试想一下，如果裸名字在找不到 variant 时就当作新变量，`Gren` 会变成一个匹配所有剩余值的兜底分支：传入 `Yellow` 时程序会输出 `go`，而最后的 `case Yellow` 永远不会执行，编译器也无从提醒你。要求绑定写 `val`，就把“拼错了”和“我想要一个变量”区分开了。

同样的规则也挡住了第二个常见的错误：**想拿 subject 和已有的变量比较**。

```scoop
{{#include ../../examples/ch11/capture_fail.scoop}}
```

```text
{{#include ../../examples/ch11/capture_fail.error}}
```

`case target` 不会读取外面的 `target`。subject 是 `Int`，没有叫 `target` 的 variant，所以报错。报错信息建议改成 `val target`，但这里**不要照做**，因为那不是你的本意：

```scoop
{{#include ../../examples/ch11/capture_val.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/capture_val.expected}}
```

`case val target` 声明了一个同名的新变量，它遮蔽了外面的 `target`，并且匹配任何值。所以无论传入什么，结果都是“匹配”，分支中的 `target` 是 5，不是 3。（这个分支能匹配任何值，所以 `when` 已经穷尽，不需要 `else`。）

和已有的值比较，有两种正确的写法：用普通分支（不加 `case`），或者用守卫：

```scoop
{{#include ../../examples/ch11/capture_fixed.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/capture_fixed.expected}}
```

反过来，如果在 variant 名前**多写**了 `val`，它就变成了一个碰巧和 variant 同名的新变量。这能通过编译，但编译器会给出警告：

```scoop
{{#include ../../examples/ch11/shadow.scoop}}
```

```text
{{#include ../../examples/ch11/shadow.warning}}
```

输出：

```text
{{#include ../../examples/ch11/shadow.expected}}
```

`val Green` 匹配了 `Yellow`，所以输出 `go`。警告指出这个变量遮蔽了 variant `Green`；去掉 `val` 之后，编译器就会发现 `Yellow` 没有被处理（见 11.8）。

关于 `val` 还有几点细节：

- `val` 只修饰紧跟在它后面的**一个名字**。tuple 的每个元素要分别写：`case (val a, val b)`，不能写 `case val (a, b)`。
- 只能写 `val`，不能写 `var`，也不能加类型标注，例如 `val x: Int`。变量的类型由模式所在的位置决定。
- 命名字段中，`val name` 是 `name: val name` 的简写；要换个变量名，写 `name: val other`。不写 `val` 的 `{name}` 表示“字段 `name` 匹配一个叫 `name` 的 variant”，通常会报错。
- 忽略一个值直接写 `_`，不写 `val _`。

记住一条原则：**在 `case` 里，要“取出”数据就写 `val 名字`；要“比较”数据，用字面量、普通分支或守卫；裸名字只用来表示 variant。**

> **从 Kotlin 过来**
>
> Kotlin 的 `when (n) { target -> ... }` 在 Scoop 里含义不变，仍然是比较。从 Kotlin 移植代码时，不要顺手给普通分支加上 `case`。另外要注意，第 10 章的解构声明 `val (a, b) = pair` 里，`val` 已经写在了最前面，模式内部的名字不再加 `val`；只有 `case` 分支的模式才要求每个绑定都写 `val`。

## 11.6　守卫与 smart cast

分支后面可以跟 `if 条件`，称为**守卫**。前面的例子已经多次用到：

```scoop
case Rect(val w, val h) if w == h -> f"square, side ${w}"
```

守卫的执行顺序是：先匹配模式，匹配成功后才计算守卫；守卫为假时，就像这个分支没有匹配一样，继续尝试下一个分支。所以守卫中可以使用模式刚刚绑定的变量。条件外面的括号可写可不写。

守卫不只用于 `case` 分支，普通分支也可以加：

- `is String if value.charLength > 3L ->`（11.1 的 `kind` 函数）：先判断类型，再判断条件。
- `else if 条件 ->`：带条件的后备分支，可以写多个，最后仍然可以有一个普通的 `else`。

`is` 分支中，subject 自动按判断出的类型使用，这就是 Kotlin 中熟悉的 smart cast。`kind` 函数的 `is Int` 分支里可以直接写 `value + 1`，因为在那里 `value` 已经被当作 `Int`。

smart cast 还有一个常见用法，就是处理 `sealed` 接口：

```scoop
{{#include ../../examples/ch11/sealed.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/sealed.expected}}
```

`s` 的静态类型是接口 `Shape`，不能直接写 struct 模式（11.3），但可以用 `is Circle ->` 判断，然后在分支中把 `s` 当作 `Circle` 读取字段，或者用第 10 章的解构 `val {side} = s` 取出字段。`sealed` 接口的全部实现都已知，所以三个 `is` 分支就构成了穷尽的匹配，不需要 `else`（见 11.8）。

## 11.7　`when (val x = ...)`：给 subject 起名字

subject 可以在 `when` 的括号里声明成一个变量：

```scoop
{{#include ../../examples/ch11/subject.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/subject.expected}}
```

`when (val n = compute())` 先计算一次表达式，把结果绑定到 `n`，所有分支、守卫和分支体中都能使用 `n`；离开 `when` 后，`n` 就不再可见。这比先在外面写一行 `val n = ...` 更紧凑，也能避免变量“泄漏”到后面的代码中。

Scoop 在这里还支持解构：`when (val (x, y) = point)` 同时得到 `x` 和 `y`。要注意，**分支匹配的仍然是完整的 `point`**，不是 `x` 或 `y`。所以 `Point(0, 0) ->` 这个普通分支比较的是整个点；而要根据 `x`、`y` 做判断，则使用守卫，例如 `case _ if x == y`。

括号里的解构必须一定成功（第 10.6 节），所以不能写 `when (val Some(v) = option)`。可能失败的模式应该放在 `case` 分支里。

`guess` 函数展示了 `else if`：第一个分支是普通分支 `target ->`，比较 `n == target`；两个 `else` 分支按条件区分“太大”和“太小”。

## 11.8　`when` 是表达式，必须穷尽

和 Kotlin 一样，`when` 是表达式，可以直接作为函数的结果，也可以赋值给变量。分支的结果还可以是 tuple，配合解构一次得到多个值：

```scoop
{{#include ../../examples/ch11/results.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/results.expected}}
```

这个例子也顺便展示了 `Option` 的匹配：`case Some(val value)` 取出其中的值，`case None` 处理缺失的情况。`Option` 是第 12 章的主题。

作为表达式使用时，每个分支的结果类型都要符合期望。函数声明返回 `String`，某个分支却给出 `Int`，就会报错：

```scoop
{{#include ../../examples/ch11/branch_type_fail.scoop}}
```

```text
{{#include ../../examples/ch11/branch_type_fail.error}}
```

### 穷尽性检查

**穷尽**的意思是：无论 subject 是什么值，都有一个分支能处理它。下面的情况要求 `when` 穷尽：

| 情况 | 是否必须穷尽 |
| --- | --- |
| `when` 的结果被使用（作为值） | 必须 |
| 包含 `case` 分支的 `when`，即使作为语句使用 | 必须 |
| subject 是 `Boolean`、enum（包括 `Option`）或 sealed 类型，作为语句使用 | 必须 |
| 其他作为语句使用的 `when` | 不必；没有分支匹配时什么也不做 |

不满足时，编译器会给出一个**没有被覆盖的例子**。漏掉一个 variant：

```scoop
{{#include ../../examples/ch11/missing_fail.scoop}}
```

```text
{{#include ../../examples/ch11/missing_fail.error}}
```

编译器按这些规则判断覆盖情况：

- **enum**：要覆盖每一个 variant，而且要覆盖 variant 的全部 payload。只写了 `Scroll(0)` 不算覆盖了 `Scroll`。
- **struct 和 tuple**：可以由多个分支共同覆盖，比如 `(true, _)` 加上 `(false, _)`。
- **`Boolean`**：`true` 和 `false` 都写了就算穷尽，11.8 的 `switchLabel` 就是这样。
- **sealed 类型**：每个直接子类型都要有对应的 `is` 分支，11.6 的 `area` 就是这样。
- **数值与字符串**：`Int`、`String` 这类类型的取值太多，写几个字面量覆盖不全，需要 `else` 或 `case _` 兜底。
- **带守卫的分支不算覆盖**，因为守卫可能为假。

下面分别看后面三种情况的报错。sealed 接口漏掉一个子类型时：

```scoop
{{#include ../../examples/ch11/sealed_fail.scoop}}
```

```text
{{#include ../../examples/ch11/sealed_fail.error}}
```

数值只列出了几个字面量时：

```scoop
{{#include ../../examples/ch11/int_fail.scoop}}
```

```text
{{#include ../../examples/ch11/int_fail.error}}
```

`-2147483648` 是 `Int` 的最小值，编译器用它作为“没有覆盖的值”的例子。

唯一不带守卫的 `Circle` 分支也带上了守卫时：

```scoop
{{#include ../../examples/ch11/guard_fail.scoop}}
```

```text
{{#include ../../examples/ch11/guard_fail.error}}
```

报错中的 `Circle(Double.NaN)` 只是编译器举出的一个例子，意思是“守卫不成立的 `Circle`”没有分支处理。解决方法是去掉守卫，或者再加一个不带守卫的 `Circle(_)` 兜底。

### 什么时候写 `else`

`else`（或 `case _`）能让任何 `when` 立刻穷尽，但对 enum 和 sealed 类型要谨慎使用。如果把所有 variant 都明确列出来，以后给 enum 增加新 variant 时，每个需要处理它的 `when` 都会报错，提醒你补上；而写了 `else` 的地方会悄悄把新 variant 归入 `else`，这个提醒就丢失了。

经验上：**对 enum 和 sealed 类型，尽量逐个列出所有情况；对数值、字符串这类开放的类型，才使用 `else`。**

## 11.9　综合练习：表达式计算器

最后，把本章的内容组合起来，写一个可以计算、打印和化简算术表达式的小程序。表达式树的定义沿用第 9.6 节的写法，在递归的位置经过 class `Node`：

```scoop
{{#include ../../examples/ch11/calculator.scoop}}
```

输出：

```text
{{#include ../../examples/ch11/calculator.expected}}
```

三个函数各自展示了模式匹配的一个方面：

- **`eval`** 是最基本的形式：每种 variant 一个分支，取出 payload 后递归计算。四个分支都没有守卫，正好覆盖全部 variant，不需要 `else`。
- **`show`** 用守卫区分负数和非负数：负数需要加括号。注意分支的顺序，带守卫的 `Num(val n) if n < 0` 必须写在 `Num(val n)` 之前，否则它永远不会被执行。
- **`simplify`** 是最有意思的一个。模式不能“看穿”class，`Add(Num(0), val x)` 这样的模式写不出来，因为 `Add` 的 payload 是 `Node`。这里的做法是先递归化简两边，把两个结果组成一个 tuple，再对这个 tuple 做模式匹配。`(Num(0), val x)` 表示“左边是 0”，`(val x, Num(1))` 表示“右边是 1”，一条规则一行，写起来很接近数学上的化简规则。`Neg` 分支则用了 `when (val s = ...)`，同时处理“负的数字”和“负负得正”。

如果给 `Expr` 增加一个 `Sub` variant，编译器会在 `eval`、`show` 和 `simplify` 中分别指出缺少的分支。这就是 11.8 推荐逐个列出 variant 的原因。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `is Circle -> shape.radius` | `case Circle(val r) -> r` |
| `is Rect -> if (shape.w == shape.h) ... else ...` | `case Rect(val w, val h) if w == h ->` 加上 `case Rect(val w, val h) ->` |
| 嵌套的 `if` 检查字段的值 | 嵌套模式，如 `case Click(Point(0, 0))` |
| `when (x) { 1, 2 -> }` | 不变；`case` 分支不支持逗号 |
| `when (val x = f())` 只能声明一个名字 | 可以解构，如 `when (val (a, b) = pair)` |
| `sealed class` 加 `is` 穷尽 | 同样支持；enum 用 `case` 穷尽 |
| `else` 兜底 | 同样支持；对 enum 尽量逐个列出 |

## 常见误用

- **绑定时漏写 `val`**：`case Some(x)` 会报错，要写 `case Some(val x)`；`Rect(val w, val h)` 中每个名字都要写 `val`（11.5）。
- **用 `case name` 和已有变量比较**：裸名字只表示 variant，编译器会报错；按提示改成 `case val name` 也不对，那是声明新变量。比较用普通分支 `name ->` 或守卫（11.5）。
- **在 variant 名前多写 `val`**：`case val Green` 是一个匹配任何值的新变量，编译器会警告它遮蔽了 variant（11.5）。
- **带 payload 的 variant 只写名字**：要写成 `Circle(_)`（11.2）。
- **在一个 `case` 中用逗号列出多个模式**：要拆成多个分支（11.2）。
- **以为带守卫的分支能覆盖某个 variant**：守卫可能为假，需要不带守卫的兜底分支（11.8）。
- **把宽的分支写在窄的分支前面**：分支按顺序尝试，`Num(val n)` 写在 `Num(val n) if n < 0` 之前，后者就永远不会执行。
- **对接口或 `Any` 直接写 struct 模式**：先用 `is` 判断类型（11.3、11.6）。
- **对 enum 习惯性地写 `else`**：增加新 variant 时就失去了编译器的提醒（11.8）。

## 小结

- `when` 有两种分支：普通分支的分支头是表达式，用来比较；`case` 分支的分支头是模式，用来匹配形状并取出数据。两者可以混用，按顺序尝试。
- 模式可以是 enum variant、struct、tuple、字面量、`_`，并且可以任意嵌套。
- `case` 中的裸名字只表示 subject 的 variant，找不到就报错；取出数据要写 `val 名字`，每个绑定单独写。
- 守卫 `if 条件` 在模式匹配成功后计算，为假时继续尝试后面的分支。
- `when (val x = ...)` 给 subject 起名字，还可以解构，但分支匹配的仍然是完整的 subject。
- 作为值使用或包含 `case` 的 `when` 必须穷尽；编译器会给出没有覆盖的例子；带守卫的分支不计入覆盖。

## 练习

1. 给 11.9 的 `Expr` 增加 `Sub(Node, Node)`，先观察编译器在哪些地方报错，再逐一补全。为 `simplify` 加上规则：`x - 0` 化简为 `x`。
2. 给 11.4 的 `Event` 增加一个 variant `Drag { from: Point, to: Point }`，在 `handle` 中区分“水平拖动”（两个点的 `y` 相同）和其他拖动。
3. 写一个函数 `fizzBuzz(n: Int): String`：对 tuple `(n % 3, n % 5)` 做模式匹配，实现经典的 FizzBuzz，不使用 `if`。
4. 下面的代码有什么问题？编译器会怎样提示？如果按提示把 `Sotuh` 改成 `val Sotuh`，程序能编译吗？运行结果会是什么？正确的改法是什么？

   ```scoop
   enum Direction { North, South, East, West }

   fun opposite(d: Direction): Direction =
       when (d) {
           case North -> Direction.South
           case Sotuh -> Direction.North
           case East -> Direction.West
           case West -> Direction.East
       }
   ```
