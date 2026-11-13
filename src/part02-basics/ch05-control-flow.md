# 第 5 章　控制流

控制流是 Kotlin 开发者最不需要重新学习的部分：`if`、`when`、`for`、`while`、`do-while`、`break`、`continue`、`return`，写法几乎和 Kotlin 一模一样，`if` 和 `when` 也同样是表达式。

不过，有几处细节和 Kotlin 不同，而且大多会在你第一次照搬 Kotlin 代码时以编译错误的形式出现：容器的下标是 `Long`，`0 until list.size` 编译不过；没有 `indices`、`withIndex()`、`repeat` 这些便利函数；`Char` 没有区间；分支类型不一致时得到的 `Any` 不能直接打印。本章把这些细节和基本用法一起讲清楚：

- `if` 和 `when` 作为表达式时的规则：什么时候必须有 `else`；
- `when` 的普通条件分支：按值、按区间、无 subject 的条件；
- 区间：`..`、`..<`、`until`、`downTo`、`step`；
- `for` 遍历数组、字符串、列表和区间，以及按下标遍历的正确写法；
- `while` 和 `do-while`；
- `break`、`continue`、`return`，以及用标签跳出外层循环。

`when` 还有另一半能力，即用 `case` 分支做模式匹配，那是第 11 章的主题。本章只讲普通条件分支。

## 5.1　`if` 是表达式

```scoop
{{#include ../../examples/ch05/if_expr.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/if_expr.expected}}
```

和 Kotlin 一样，Scoop 没有三元运算符 `?:`（`?:` 在 Scoop 里是给 `Option` 提供默认值的运算符，见第 12 章），条件选择直接用 `if` 表达式：`if (条件) 值1 else 值2`。

分支可以是一个表达式，也可以是一个块。**块的结果是它的最后一个表达式**：上例中 `fan` 的第一个分支先打印一行，再以 `3` 作为结果。

`if` 有两种用法，规则不同：

- **作为值使用**（赋给变量、作为函数结果、作为参数）：必须有 `else`，因为条件为假时也必须得到一个值。
- **作为语句使用**（结果被丢弃）：`else` 可以省略。

缺少 `else` 时编译器会直接指出：

```scoop
{{#include ../../examples/ch05/if_noelse_fail.scoop}}
```

```text
{{#include ../../examples/ch05/if_noelse_fail.error}}
```

`else if` 并不是一个单独的语法，它只是“`else` 分支里又放了一个 `if`”。`scoop fmt` 会把它排成上例 `level` 那样，内层的 `if` 缩进一级，正好体现了这种嵌套关系。同样，`scoop fmt` 也会把单条语句的分支体放到下一行，比如 `if (fan > 2)` 后面的 `println`。这些只是排版，不影响含义。

### 分支类型不一致时

作为值使用时，两个分支的类型应该一致。如果有期望类型（比如 `val x: String = if ...`），每个分支都必须符合它；没有期望类型时，Scoop 取两个分支类型的**共同上界**。`Int` 和 `String` 的共同上界只有 `Any`，而 `Any` 什么能力都没有，连打印都不行：

```scoop
{{#include ../../examples/ch05/if_any_fail.scoop}}
```

```text
{{#include ../../examples/ch05/if_any_fail.error}}
```

报错指向的是 `println`，而不是 `if`：`if` 本身合法，它的结果类型是 `Any`；`println` 要求参数实现 `ToString`，`Any` 不满足。遇到这种报错，回头检查分支类型是否本来就该一致，比如把 `n` 改成 `n.toString()`。

> **从 Kotlin 过来**
>
> Kotlin 里 `println(if (n > 0) n else "none")` 能正常运行，因为 Kotlin 的 `Any` 一定有 `toString()`。Scoop 的 `Any` 只是所有类型的公共父类型，不附带 `toString`、`equals` 或 `hashCode`（第 8 章 8.7 节）。所以“混合类型的分支结果”在 Scoop 中通常意味着代码写错了。

## 5.2　`when`：多路分支

```scoop
{{#include ../../examples/ch05/when_expr.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/when_expr.expected}}
```

`when` 有两种形式。

**带 subject**：`when (score) { ... }` 先求出 `score` 的值（只求一次），然后从上到下逐个尝试分支：

| 分支头 | 含义 |
| --- | --- |
| `100 ->` | `score == 100` |
| `90, 95 ->` | 等于其中任意一个；按顺序尝试，一个成立就选中 |
| `in 60 .. 89 ->` | `score` 在这个区间里（5.3 节） |
| `!in ... ->` | 不在里面 |
| `else ->` | 前面都不成立；必须放在最后 |

**不带 subject**：`when { ... }` 的每个分支头是一个 `Boolean` 条件，第一个为真的分支被选中，相当于一串 `if`/`else if`。`bmiClass` 就是这种形式，分支的顺序很重要：`bmi < 24.0` 之所以能表示“18.5 到 24 之间”，是因为前一个分支已经排除了 `bmi < 18.5`。

分支体同样可以是块，块的最后一个表达式是这个分支的结果，见 `kind` 的例子。

### 什么时候必须有 `else`

`when` 作为值使用时，必须**穷尽**：无论 subject 是什么，都要有一个分支命中。对 `Int`、`String` 这类取值很多的类型，几个字面量不可能覆盖全部取值，所以需要 `else`：

```scoop
{{#include ../../examples/ch05/when_int_fail.scoop}}
```

```text
{{#include ../../examples/ch05/when_int_fail.error}}
```

`-2147483648` 是 `Int` 的最小值，编译器举它作为“没有分支处理的值”的例子。

不带 subject 的 `when` 作为值时**必须写 `else`**。即使你的条件在逻辑上已经覆盖了所有情况（比如 `n > 0`、`n <= 0`），编译器也不会去推理这些条件，它只认 `else`：

```scoop
{{#include ../../examples/ch05/when_noelse_fail.scoop}}
```

```text
{{#include ../../examples/ch05/when_noelse_fail.error}}
```

作为语句使用时，大多数 `when` 可以不穷尽，没有分支命中就什么也不做，比如 `when_expr.scoop` 最后那个 `when (day)`。但有一个例外：**subject 是 `Boolean`、enum（包括 `Option`）或 sealed 类型时，即使作为语句也必须穷尽**。这些类型的取值是有限的，漏掉一个通常是疏忽：

```scoop
{{#include ../../examples/ch05/when_bool_fail.scoop}}
```

```text
{{#include ../../examples/ch05/when_bool_fail.error}}
```

只想处理一种情况时，`Boolean` 直接用 `if (verbose)` 更自然。enum 和 sealed 类型的穷尽性，以及 `case` 分支的完整规则，见第 11 章 11.8 节。

## 5.3　区间

```scoop
{{#include ../../examples/ch05/ranges.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/ranges.expected}}
```

Scoop 提供 Kotlin 中常用的几种区间写法：

| 写法 | 含义 | 例子 |
| --- | --- | --- |
| `a .. b` | 从 `a` 升到 `b`，包含 `b` | `1 .. 5` → 1 2 3 4 5 |
| `a ..< b` | 从 `a` 升到 `b`，不包含 `b` | `1 ..< 5` → 1 2 3 4 |
| `a until b` | 同 `a ..< b` | `1 until 5` → 1 2 3 4 |
| `a downTo b` | 从 `a` 降到 `b`，包含 `b` | `5 downTo 1` → 5 4 3 2 1 |
| `r step n` | 把步长换成 `n`，方向和端点不变 | `0 .. 10 step 3` → 0 3 6 9 |

几个要点：

- `scoop fmt` 会在 `..` 和 `..<` 两边加空格，写成 `1 .. 5`。
- `5 .. 1` 是**空区间**，不会反过来数。要倒数，用 `downTo`。
- `step` 的参数必须大于 0；方向由区间本身决定，所以倒数写 `10 downTo 0 step 4`，而不是 `step -4`。`step 0` 或负数不会在编译时报错，而是在运行时抛出 `IllegalArgumentException`：

  ```scoop
  {{#include ../../examples/ch05/step_zero.scoop}}
  ```

  输出：

  ```text
  {{#include ../../examples/ch05/step_zero.expected}}
  ```

  （`try`/`catch` 是第 19 章的内容，这里只是用它来展示异常。）

- `x in r` 和 `x !in r` 判断一个值是否在区间里，它们就是在调用区间的 `contains` 方法。对带 `step` 的区间，`contains` 还会检查步长是否对齐：`0 .. 10 step 3` 包含 6，但不包含 7。
- 端点取到类型的最大值（如 `Int.MAX_VALUE`）时，循环也能正确结束，不会因为溢出而变成死循环。

### 区间的类型

区间的类型取决于端点的类型：`Int` 的区间是 `IntRange`，`Long` 的区间是 `LongRange`（还有无符号的 `UIntRange` 和 `ULongRange`）。它们是不同的类型，两个端点的类型必须相同：`0 .. 10L` 这种混合写法会报错，因为数值之间没有隐式转换（第 3 章）。

Scoop **没有 `Char` 区间**：

```scoop
{{#include ../../examples/ch05/char_range_fail.scoop}}
```

```text
{{#include ../../examples/ch05/char_range_fail.error}}
```

需要遍历一段字母时，可以遍历一个写好的字符串，比如 `for (c in "abcde")`，或者用 `Char` 的编号组成整数区间，再用 `toChar()` 转回来：`for (n in 'a'.code .. 'e'.code)`，循环体里用 `n.toChar()`。

> **从 Kotlin 过来**
>
> Kotlin 的 `'a'..'z'` 是 `CharRange`，`(1..5).reversed()` 能得到倒序区间。Scoop 只有整数区间，区间上也只有 `step` 和 `contains` 两个方法：倒序用 `downTo`，字母用字符串或 `code` / `toChar()` 转换。

## 5.4　`for`：遍历

```scoop
{{#include ../../examples/ch05/iterate.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/iterate.expected}}
```

`for (x in 来源)` 可以遍历任何**可迭代**的东西：区间、数组（`Array`、`MutableArray`）、`ArrayList` 等集合，以及 `String`。遍历字符串时，每一轮得到一个 `Char`，即一个 Unicode 标量，所以 `"héllo"` 是 5 轮，而不是 UTF-8 编码的 6 个字节（第 4 章会详细讨论这些“长度”）。

循环变量是只读的，相当于每一轮都声明了一个新的 `val`，不能给它赋值：

```scoop
{{#include ../../examples/ch05/loopvar_fail.scoop}}
```

```text
{{#include ../../examples/ch05/loopvar_fail.error}}
```

需要可变的值时，在循环体里另外声明一个 `var`。

### 按下标遍历：下标是 `Long`

Scoop 中数组、列表等容器的 `size` 和下标都是 `Long`（第 3 章）。所以按下标遍历要用 `Long` 区间：

```scoop
for (i in 0L until names.size) { ... }
```

照搬 Kotlin 的 `0 until names.size` 会报错，因为 `0` 是 `Int`，`names.size` 是 `Long`，两者不能组成一个区间：

```scoop
{{#include ../../examples/ch05/index_fail.scoop}}
```

```text
{{#include ../../examples/ch05/index_fail.error}}
```

同理，倒序遍历下标写成 `names.size - 1L downTo 0L`，`while (i < names.size)` 中的计数器 `i` 也要声明成 `Long`（`var i = 0L`）。

不需要下标时，直接 `for (name in names)` 更简洁，也不会写错边界。

> **从 Kotlin 过来**
>
> Kotlin 遍历下标的几种惯用写法在 Scoop 中都要换掉：
>
> | Kotlin | Scoop |
> | --- | --- |
> | `for (i in 0 until list.size)` | `for (i in 0L until list.size)` |
> | `for (i in list.indices)` | `for (i in 0L until list.size)`，没有 `indices` |
> | `for ((i, v) in list.withIndex())` | 用下标循环，在循环体里读 `list[i]` |
> | `for (i in list.lastIndex downTo 0)` | `for (i in list.size - 1L downTo 0L)` |
> | `repeat(3) { ... }` | `for (i in 1 .. 3) { ... }`，没有 `repeat` |

> **深入一点：`for` 是怎么工作的**
>
> `for (x in source)` 背后是一个很简单的协议。`source` 要有一个 `iterator()` 方法，返回一个 `Iterator<T>`；`Iterator<T>` 只有一个方法 `next(): Option<T>`，有下一个元素时返回 `Some(元素)`，没有了就返回 `None`。`for` 循环先调用一次 `iterator()`，然后反复调用 `next()`，直到得到 `None`。
>
> 这和 Kotlin 的 `hasNext()` 加 `next()` 两步不同：Scoop 一步完成，“还有没有”和“下一个是什么”由同一个 `Option` 表示。任何类型只要实现了 `Iterable<T>` 接口（即提供 `iterator()`），就可以用在 `for` 里。`Option` 见第 12 章，接口见第 14 章。

## 5.5　`while` 与 `do-while`

```scoop
{{#include ../../examples/ch05/while_loops.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/while_loops.expected}}
```

`while (条件) { ... }` 先判断条件，条件为真才执行循环体，所以循环体可能一次也不执行。`do { ... } while (条件)` 先执行循环体，再判断条件，所以循环体至少执行一次。

`digitCount` 是 `do-while` 的典型用法：`0` 也有一位数字，所以“数一位”这个动作至少要做一次。如果改成 `while (n != 0)`，`digitCount(0)` 会得到 0。

`do-while` 有一个方便之处：**循环体最外层声明的名字，在 `while` 条件里可以使用**。上例最后的 `square` 就是这样，这和 Kotlin 一样。但这些名字只在循环内部有效，循环结束后就不可见了：

```scoop
{{#include ../../examples/ch05/do_scope_fail.scoop}}
```

```text
{{#include ../../examples/ch05/do_scope_fail.error}}
```

需要在循环之后使用的值，要在循环之前用 `var` 声明。

## 5.6　`break`、`continue` 与标签

```scoop
{{#include ../../examples/ch05/jumps.scoop}}
```

输出：

```text
{{#include ../../examples/ch05/jumps.expected}}
```

- `break` 结束最内层的循环，接着执行循环之后的代码。
- `continue` 跳过本轮剩下的部分，进入下一轮：`for` 循环取下一个元素，`while` 和 `do-while` 重新判断条件。

`break` 和 `continue` 可以出现在 `when`、`if` 的分支里，作用于包围它们的循环，见 `readings` 的例子。

### 标签

嵌套循环中，`break` 和 `continue` 只作用于最内层的循环。要直接跳出或继续外层循环，就给外层循环加一个**标签**：在循环前面写 `名字@`，跳转时写 `break@名字` 或 `continue@名字`。

- `break@search` 在找到 0 之后立刻结束两层循环。没有标签的话，就需要一个额外的 `Boolean` 变量在外层再判断一次。
- `continue@rows` 遇到 0 时放弃当前这一行，直接开始下一行，所以第二行 `[4, 0, 6]` 没有被打印。

标签只能加在循环（`for`、`while`、`do`）上，只用于 `break` 和 `continue`；它不是 `goto`，不能跳到任意位置。

不在循环里使用 `break` / `continue`，或者使用不存在的标签，都是编译错误：

```scoop
{{#include ../../examples/ch05/break_fail.scoop}}
```

```text
{{#include ../../examples/ch05/break_fail.error}}
```

```scoop
{{#include ../../examples/ch05/label_fail.scoop}}
```

```text
{{#include ../../examples/ch05/label_fail.error}}
```

### 跳转不能穿过函数边界

`break` 和 `continue` 只能跳到**同一个函数内**的循环。lambda 也算一个单独的函数，所以在 lambda 里不能 `break` 外面的循环：

```scoop
{{#include ../../examples/ch05/lambda_break_fail.scoop}}
```

```text
{{#include ../../examples/ch05/lambda_break_fail.error}}
```

外层的 `for (round in ...)` 虽然在源码上包围着 lambda，但 lambda 是另一个函数，它内部看不到这个循环。需要“提前结束”的遍历，用普通的 `for` 循环来写。lambda 本身的返回规则（`return@label`）见第 7 章。

## 5.7　`return`，以及跳转也是表达式

`return` 结束当前函数。在循环里，它会同时结束循环，`firstNegative` 找到第一个负数就直接返回。

`return`、`break`、`continue` 在 Scoop 中都是**表达式**，它们的类型是 `Nothing`。`Nothing` 是**底类型**，也就是所有类型的子类型（第 6 章 6.5 节），所以这些表达式可以出现在需要任何类型的值的地方；它们本身不会产生值，控制流已经去了别处。比如放在 `if` 的一个分支里：

```scoop
val h = if (n % 2 == 0) n / 2 else return "odd"
```

`if` 的结果类型只由能正常产生值的分支决定，这里是 `Int`；`else` 分支直接从函数返回 `"odd"`，不参与类型计算。注意 `return "odd"` 返回的是**函数的**结果（`String`），和 `h` 的类型无关。`when` 的分支同理，`readings` 例子中的 `r < 0 -> continue` 就是这样。

这个写法最常见的用途，是配合 `?:` 处理缺失值：`val number = value ?: return "missing"`。第 12 章会再见到它。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop | 说明 |
| --- | --- | --- |
| `if (a) x else y` | 相同 | 作为值时必须有 `else` |
| `println(if (a) 1 else "x")` | 编译错误 | 结果是 `Any`，没有 `ToString` |
| `when (x) { 1, 2 -> ...; in 3..9 -> ... }` | 相同 | 格式化后写作 `in 3 .. 9` |
| `when (flag) { true -> ... }` 作为语句 | 编译错误 | `Boolean` subject 必须穷尽 |
| `for (i in 0 until list.size)` | `for (i in 0L until list.size)` | 下标是 `Long` |
| `list.indices`、`withIndex()`、`lastIndex` | 没有 | 用 `0L until size` |
| `repeat(n) { }` | 没有 | 用 `for (i in 1 .. n)` |
| `'a'..'z'` | 没有 `Char` 区间 | 遍历字符串或整数 |
| `(1..5).reversed()` | `5 downTo 1` | 区间只有 `step`、`contains` |
| `1..10 step 0` | 相同，运行时抛 `IllegalArgumentException` | |
| `outer@ for ... break@outer` | 相同 | |
| `list.forEach { if (...) return@forEach }` | 用 `for` 循环 + `continue` | lambda 中不能 `break` / `continue` 外层循环 |
| `println()` | `println("")` | `println` 必须有一个参数 |

## 常见误用

- **用 `Int` 区间遍历下标**：`0 until names.size` 报 “`size` has type Long, expected Int”，改成 `0L until names.size`。
- **值位置的 `if` 或无 subject 的 `when` 漏写 `else`**：即使条件在逻辑上已经覆盖全部情况，也要写 `else`。
- **分支类型不一致**：得到的 `Any` 什么都做不了，报错往往出现在后面使用它的地方，而不是 `if` 本身。
- **用 `5 .. 1` 倒数**：这是空区间，倒数用 `downTo`。
- **`step` 写负数**：步长必须为正，方向由 `..` 或 `downTo` 决定。
- **在 `Boolean` subject 的 `when` 语句里只写一个分支**：要么补全 `true`/`false`，要么改用 `if`。
- **在 lambda 里 `break` 外层循环**：lambda 是独立的函数，改用普通循环。
- **给 `for` 的循环变量赋值**：它是只读的，另外声明 `var`。

## 小结

- `if` 和 `when` 都是表达式；作为值使用时，`if` 必须有 `else`，`when` 必须穷尽，无 subject 的 `when` 必须有 `else`。
- 块的结果是最后一个表达式；分支类型不一致时退化为 `Any`。
- `Boolean`、enum、sealed 类型作 subject 的 `when`，即使作为语句也必须穷尽。
- 区间有 `..`、`..<`、`until`、`downTo` 和 `step`；只有整数区间，端点类型必须一致。
- `for` 遍历任何可迭代对象，循环变量只读；容器下标是 `Long`，按下标遍历写 `0L until xs.size`。
- `do-while` 至少执行一次，循环体中声明的名字在条件中可见。
- `break`、`continue` 可以带标签跳到外层循环，但不能穿过 lambda 等函数边界；`return`、`break`、`continue` 都是 `Nothing` 类型的表达式。

## 练习

1. 写一个函数 `fizzBuzz(n: Int): String`，用无 subject 的 `when` 实现：能被 15 整除返回 `"FizzBuzz"`，能被 3 整除返回 `"Fizz"`，能被 5 整除返回 `"Buzz"`，否则返回数字本身。然后用 `for` 打印 1 到 20 的结果。
2. 给定 `val words = ["apple", "kiwi", "banana", "fig"]`，按下标倒序打印每个单词和它的下标。注意下标的类型。
3. 用 `while` 循环计算一个 `Long` 的各位数字之和；再用 `do-while` 改写，比较输入为 `0L` 时两者的结果。
4. 用两层 `for` 循环和标签，在 `[[3, 8, 1], [9, 2, 7], [4, 6, 5]]` 中找出第一个大于 8 的数，找到后立即结束全部循环，并打印它的行号和列号。
5. 把 `for (c in 'a' .. 'e')` 改写成能在 Scoop 中编译通过的版本。
