# 第 10 章　解构

拿到一个 struct 或 tuple 之后，常常需要把其中几个字段分别取出来使用。写 `val x = p.x; val y = p.y` 当然可以，但字段一多就显得啰嗦。**解构**（destructuring）让你用一个声明一次取出多个部分：

```scoop
val(x, y) = point
```

（`val` 和括号之间没有空格，这是 `scoop fmt` 的格式，本书的示例都遵循它。写成 `val (x, y)` 含义相同。）

Kotlin 也有解构，但只能按位置、只能通过 `componentN` 方法实现。Scoop 的解构是语言内建的，能力也更多：可以按位置，也可以按字段名；可以用 `..` 忽略不关心的部分；可以任意嵌套；在 `for` 循环和 lambda 参数中也能使用。

本章介绍：

- 按位置和按字段名解构 struct 与 tuple；
- 用 `_` 和 `..` 跳过不需要的部分；
- 嵌套解构，以及 `var` 解构；
- 在 `for` 循环和 lambda 参数中解构；
- 为什么 `val Some(x) = o` 不合法；
- 让普通 class 支持解构。

## 10.1　按位置，按字段名

```scoop
{{#include ../../examples/ch10/basics.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/basics.expected}}
```

解构有两种基本形式：

- **位置模式** `(a, b, ...)`：按顺序把各部分绑定到变量。对 tuple 是元素顺序，对 struct 是主构造器里字段的声明顺序。
- **字段模式** `{field: name, ...}`：按字段名取值，`field: name` 把字段 `field` 绑定到变量 `name`，写成 `{x, y}` 则表示变量与字段同名。字段模式只能用于 struct，书写顺序不必和声明顺序一致。

位置模式中，`_` 占住一个位置但不绑定变量。字段模式中可以写 `field: _`，不过不需要的字段通常直接不写，配合下一节的 `..` 使用。

单元素 tuple 的模式和单元素 tuple 本身一样，要带尾随逗号：`val(answer,) = single`。没有逗号的 `val(side) = square` **不是解构**，括号里只是一个加了括号的名字，`side` 绑定的是整个 `square`：

```scoop
{{#include ../../examples/ch10/paren_name.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/paren_name.expected}}
```

想取出只有一个字段的 struct 的字段，写字段模式 `val {side} = square`，或者直接写 `square.side`。

两种形式各有用处：位置模式简短，适合字段少且顺序一目了然的类型，比如坐标和 tuple；字段模式不依赖字段顺序，以后调整 struct 的字段顺序也不会悄悄取错值，适合字段多或者容易混淆的类型。

注意，本章所有模式里的名字都**直接**就是新变量，前面已经有了 `val` 或 `var`，模式内部不再重复写。第 11 章的 `when` 不一样：`case` 分支的模式里，每个要取出的值都要单独写 `val`，例如 `case (val a, val b)`。原因到 11.5 节再讲。

> **从 Kotlin 过来**
>
> Kotlin 的解构只有按位置一种，由 `data class` 自动生成的 `component1()`、`component2()`……实现。Scoop 中 struct 和 tuple 的解构是语言内建的，不调用任何方法，也不需要 struct 生成 `componentN`。Kotlin 没有按字段名解构，也没有下面要介绍的 `..`。

## 10.2　`..`：忽略其余部分

```scoop
{{#include ../../examples/ch10/rest.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/rest.expected}}
```

`..` 表示“其余的部分我不关心”，它本身不绑定任何值。规则因模式而异：

- **位置模式**中，`..` 代表任意个（包括零个）连续的元素，可以放在开头、中间或结尾，但一个模式里最多出现一次。用了 `..` 就不要求模式的元素个数和值一致。
- **字段模式**中，`..` 只能放在最后。没有列出全部字段时**必须**写 `..`；列全了可以省略。

字段模式前面还可以写类型名，如 `val Rgba {alpha: opacity, ..} = color`。写不写类型名，含义是一样的，写上可以让读者一眼看出解构的是什么类型。

这些规则都有对应的编译期检查。位置模式的元素个数不对：

```scoop
{{#include ../../examples/ch10/arity_fail.scoop}}
```

```text
{{#include ../../examples/ch10/arity_fail.error}}
```

字段模式漏写了字段又没有加 `..`：

```scoop
{{#include ../../examples/ch10/fields_fail.scoop}}
```

```text
{{#include ../../examples/ch10/fields_fail.error}}
```

`..` 出现了两次。这时编译器无法确定中间的 `b` 应该对应哪个元素：

```scoop
{{#include ../../examples/ch10/two_rest_fail.scoop}}
```

```text
{{#include ../../examples/ch10/two_rest_fail.error}}
```

你可能会担心 `..` 和区间运算符 `1..5` 混淆。它们不会冲突：模式里单独的 `..` 总是表示“其余部分”，而区间是表达式，不能写在模式中。

## 10.3　嵌套解构

模式的每一个位置都可以再放一个模式，位置模式和字段模式可以自由组合：

```scoop
{{#include ../../examples/ch10/nested.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/nested.expected}}
```

`val {end: {y: height, ..}, ..} = line` 一步取出了“终点的 y 坐标”：外层字段模式取出 `end`，冒号右边是另一个字段模式，再从 `end` 中取出 `y`。冒号右边可以是任何模式，不只是一个变量名。

同一个模式中的变量名不能重复。比如第 8 章的 `Point` 嵌套在 `Line` 里时，起点和终点都有 `x`，就要分别改名为 `x0`、`x1`。

## 10.4　`var` 解构

把 `val` 换成 `var`，解构出来的每个变量都可以重新赋值：

```scoop
{{#include ../../examples/ch10/mutable.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/mutable.expected}}
```

解构得到的是各部分的副本。修改 `x`、`y` 只是让这两个变量换成别的值，不会影响 `start`。这和第 8 章的值语义一致：struct 本来也不能修改。

## 10.5　在循环和 lambda 中解构

解构不只用于 `val` / `var` 声明，`for` 的循环变量和 lambda 参数也可以直接写成模式：

```scoop
{{#include ../../examples/ch10/loops.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/loops.expected}}
```

- `for ((x, y) in points)`：每次循环取出一个 `Point` 并解构。
- 遍历 `Map` 时，每个条目是一个 `(key, value)` tuple，所以可以写 `for ((fruit, count) in stock)`。
- lambda 参数写成模式时，注意要用括号把模式括起来：`{ (w, h) -> w * h }` 接收**一个**参数并把它解构，`{ w, h -> ... }` 则表示接收**两个**参数。

循环变量和 lambda 参数中解构出来的变量都不能重新赋值，与普通的循环变量、参数一样：

```scoop
{{#include ../../examples/ch10/reassign_fail.scoop}}
```

```text
{{#include ../../examples/ch10/reassign_fail.error}}
```

## 10.6　解构必须一定成功

到目前为止，所有模式都有一个共同点：只要类型对得上，匹配就**一定成功**。一个 `Point` 一定有 `x` 和 `y`，一个三元素 tuple 一定有三个元素。

有些模式却可能失败。`Some(name)` 只能匹配有值的 `Option`，遇到 `None` 就匹配不上；字面量 `0` 只能匹配等于 0 的值。这类模式不能用在声明里：

```scoop
{{#include ../../examples/ch10/refutable_fail.scoop}}
```

```text
{{#include ../../examples/ch10/refutable_fail.error}}
```

道理很简单：如果 `nickname` 是 `None`，`name` 应该是什么呢？声明没有“匹配失败”时的出路。可能失败的匹配要写在 `when` 里，由各个分支分别处理成功和失败的情况，这是第 11 章的内容。

同样的规则也适用于 `for`。有人会想用模式过滤掉 `None`，但这样写不合法：

```scoop
{{#include ../../examples/ch10/for_filter_fail.scoop}}
```

```text
{{#include ../../examples/ch10/for_filter_fail.error}}
```

`for` 的模式不会过滤元素。想跳过 `None`，就在循环体里用 `when` 判断。

这里还有一个要小心的陷阱。在声明中，一个**单独的名字**永远是声明一个新变量，即使这个名字恰好和某个 enum variant 同名：

```scoop
{{#include ../../examples/ch10/none_trap.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/none_trap.expected}}
```

`val None = result` 不是“断言 `result` 是 `None`”，而是声明了一个名叫 `None` 的变量，它的值就是 `result`，也就是 `Some(5)`。这段代码能够编译，结果却和直觉完全相反。好在编译器会给出警告：

```text
{{#include ../../examples/ch10/none_trap.warning}}
```

警告的意思是：这个新变量遮蔽（shadow）了当前可用的 variant `None`，要么给变量换个名字，要么在使用 variant 的地方写完整的 `Option.None`。不要用 variant 的名字给变量起名，看到这条警告时也不要忽略它。

## 10.7　让 class 支持解构

struct 和 tuple 的解构是内建的。普通 class 默认不能解构：

```scoop
{{#include ../../examples/ch10/class_fail.scoop}}
```

```text
{{#include ../../examples/ch10/class_fail.error}}
```

报错指出缺少 `component1` 方法。和 Kotlin 一样，给 class 声明 `operator fun component1()`、`component2()`……之后，它就支持按位置解构：

```scoop
{{#include ../../examples/ch10/component.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/component.expected}}
```

写了几个位置，就会依次调用 `component1` 到 `componentN`。class 的解构有两个限制：

- 只支持位置模式，不支持字段模式：class 不是“字段的透明组合”，它的属性可能是计算出来的，也可能是私有的。
- 不能使用 `..`：编译器不知道一个 class 总共有几个 component，也就无法确定 `..` 代表哪些元素。

```scoop
{{#include ../../examples/ch10/component_rest_fail.scoop}}
```

```text
{{#include ../../examples/ch10/component_rest_fail.error}}
```

大多数时候，需要解构的数据类型本来就应该是 struct（第 8 章 8.9 节）。只有当类型确实需要是 class、又希望支持解构时，才需要手写 `componentN`。

## 10.8　右侧只求值一次

无论模式多复杂，`=` 右边的表达式都只求值一次，各个部分都从这同一个值中取出：

```scoop
{{#include ../../examples/ch10/eval_once.scoop}}
```

输出：

```text
{{#include ../../examples/ch10/eval_once.expected}}
```

所以把函数调用直接写在解构的右边是安全的，不必先存进一个临时变量。

## 常见误用

- **用位置模式解构字段多、顺序容易混淆的 struct**：以后调整字段顺序时，位置模式会悄悄取到错误的字段。这种情况改用字段模式。
- **字段模式只写了部分字段**：要在最后加 `..`。
- **想用 `val Some(x) = o` 取出 `Option` 的值**：声明里的模式必须一定成功，用 `when`（第 11、12 章）或 `?:`。
- **想用 `for (Some(x) in xs)` 过滤**：`for` 的模式不过滤，在循环体里用 `when`。
- **写了 `val None = o`**：这是声明了一个叫 `None` 的变量，编译器会警告它遮蔽了 variant。
- **用 `val(side) = square` 解构单字段 struct**：这只是给整个值起了个名字，改用 `val {side} = square`。
- **lambda 参数的解构漏掉括号**：`{ (a, b) -> ... }` 是一个参数解构，`{ a, b -> ... }` 是两个参数。
- **给 class 的解构写 `..` 或字段模式**：class 只支持完整的位置模式。

## 小结

- 位置模式 `(a, b)` 按顺序解构 tuple 和 struct；字段模式 `{field: name}` 按字段名解构 struct。
- `_` 跳过一个位置；`..` 忽略其余部分，在位置模式中最多出现一次，在字段模式中只能放在最后。
- 模式可以任意嵌套；`var` 解构得到可以重新赋值的变量。
- `for` 循环变量和 lambda 参数可以直接解构，遍历 `Map` 时每个条目是 `(key, value)`。
- 声明、`for` 和 lambda 中的模式必须一定成功；可能失败的模式要写在 `when` 里。
- 这些位置的模式里，名字直接就是新变量，不写 `val`；`when` 的 `case` 模式则要求每个绑定写 `val`。
- 普通 class 通过 `operator fun componentN` 支持完整的位置解构。

## 练习

1. 定义 `struct Employee(val name: String, val department: String, val salary: Long, val manager: String)`，分别用位置模式和字段模式取出 `name` 和 `salary`。哪种写法更不容易出错？
2. 有一个 `Array<(String, Point)>`，每个元素是地点名称和坐标。用一个 `for` 循环打印每个地点的名称和 `x` 坐标，不使用 `.` 访问字段。
3. 用 `LinkedHashMap<String, Int>` 统计一组单词的出现次数，再用 `for ((word, count) in ...)` 打印出现次数大于 1 的单词。
4. 下面的代码能编译吗？如果能，它输出什么？编译器会给出什么提示？为什么？

   ```scoop
   val some: Int? = None
   val Some = some
   println(Some ?: -1)
   ```
