# 第 7 章　lambda 与闭包

Kotlin 程序里到处是 lambda：`list.filter { it > 0 }`、`button.setOnClickListener { ... }`、`buildString { append(...) }`。函数可以像普通值一样保存在变量里、作为参数传递、作为结果返回，这种写法在 Scoop 里同样成立，语法也几乎一样。

不同之处集中在几条规则上，而且这些规则都由编译器检查，不会留到运行时才出问题：

- lambda 不能捕获外层的 `var`，读也不行；
- lambda 里不能写裸 `return`，也没有 Kotlin 的“非局部返回”；
- 函数一旦变成函数值，就只能按位置传全部参数，命名参数和默认参数不再可用；
- `inline`、`crossinline` 这些修饰符可以写，但不会改变上面任何一条。

本章介绍：

- 函数类型、lambda、匿名函数和函数引用 `::f` 这几种“函数值”；
- lambda 的结果是什么，怎样从 lambda 中提前返回；
- 闭包能捕获什么，以及需要共享可变状态时的标准写法；
- 带接收者的函数类型；
- 标准库里 `map`、`filter`、`fold` 等常用高阶函数。

## 7.1　函数也是值

```scoop
{{#include ../../examples/ch07/basics.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/basics.expected}}
```

`(Int) -> Int` 是一个**函数类型**：接收一个 `Int`、返回一个 `Int` 的函数。写法和 Kotlin 相同：

- 多个参数用逗号分隔：`(Int, Int) -> Int`；
- 没有参数时括号不能省：`() -> String`；
- 不返回有意义的结果时写 `Unit`：`(String) -> Unit`。

类型为函数类型的值叫**函数值**。`{ x -> x * x }` 是一个 **lambda**：一段写在花括号里、可以当作值传来传去的代码。`->` 左边是参数，右边是函数体。

调用函数值和调用普通函数一样写 `square(4)`；`square.invoke(5)` 是同一件事的显式写法，很少需要。

把函数值作为参数传给另一个函数时，有三种常见写法，例子里的最后几行依次演示了它们：

- 传一个已有的函数值：`applyTwice(3, square)`；
- 在括号里直接写 lambda：`applyTwice(3, { x -> x + 10 })`；
- **尾随 lambda**：最后一个参数是函数类型时，lambda 可以写在括号外面，`applyTwice(3) { x -> x - 1 }`。如果括号里没有其他参数，括号也可以省略。

只有一个参数的 lambda 可以不写参数列表，直接用隐式名称 `it` 指代它，例如 `{ it * 2 }`。这些都和 Kotlin 一致。

像 `applyTwice` 这样接收或返回函数值的函数，叫**高阶函数**。

## 7.2　lambda 的写法

```scoop
{{#include ../../examples/ch07/forms.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/forms.expected}}
```

### 参数类型从哪里来

lambda 的参数类型可以写在参数名后面，如 `{ a: Int, b: Int -> a + b }`；也可以不写，由**期望类型**提供。期望类型就是“这个位置需要什么类型”：`val describe: (Int) -> String = ...` 的声明、高阶函数的参数类型，都会告诉编译器 lambda 的参数是 `Int`。

两者都没有时，编译器无从推断，会直接报错，而不是像某些语言那样退回 `Any`：

```scoop
{{#include ../../examples/ch07/lambda_type_fail.scoop}}
```

```text
{{#include ../../examples/ch07/lambda_type_fail.error}}
```

解决办法是给参数写上类型，或者给变量写上函数类型，二选一即可。

### 最后一个表达式就是结果

lambda 的函数体可以有多行，**最后一个表达式的值就是 lambda 的结果**，不需要（也不能，见 7.3）写 `return`。`describe` 先声明了局部变量 `kind`，最后一行的 f-string 就是返回值。

有期望类型时，编译器会检查结果类型是否匹配：

```scoop
{{#include ../../examples/ch07/result_fail.scoop}}
```

```text
{{#include ../../examples/ch07/result_fail.error}}
```

注意报错的形状：lambda 写在调用的实参位置时，编译器会先说“`applyTo` 没有可用的候选”，再在候选后面说明具体原因。读这类报错时，直接看破折号后面的部分。

期望结果是 `Unit` 时，最后一个表达式的值会被丢弃。`record` 的最后一行 `it.charLength` 算出了一个 `Long`，但 `record` 的类型是 `(String) -> Unit`，这个值就被扔掉了，不算错误。

### 匿名函数

`parse` 用的是另一种写法：**匿名函数**，即省略了名字的 `fun` 声明。它的参数、返回类型和函数体都按普通函数的规则写，包括用 `return` 返回。函数体里需要多处提前返回时，匿名函数往往比 lambda 读起来更清楚。

## 7.3　从 lambda 中返回

在 Kotlin 里，lambda 中的 `return` 有时返回外层函数（非局部返回），有时是编译错误，取决于高阶函数是否 `inline`。Scoop 把规则简化为一条：**lambda 里的裸 `return` 一律是编译错误。**

```scoop
{{#include ../../examples/ch07/return_fail.scoop}}
```

```text
{{#include ../../examples/ch07/return_fail.error}}
```

要从 lambda 中提前结束，用带标签的 `return@label`，它只结束当前这个 lambda：

```scoop
{{#include ../../examples/ch07/labels.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/labels.expected}}
```

标签有两种来源：

- **显式标签**：在 lambda 前写 `名字@`，如 `clamp@{ ... }`，之后用 `return@clamp 100` 返回值 `100`。
- **隐式标签**：lambda 直接作为某个函数调用的实参时，自动以函数名为标签。传给 `forEachValue` 的 lambda 可以写 `return@forEachValue`。它的结果类型是 `Unit`，所以 `return@forEachValue` 后面不带值，效果相当于普通循环里的 `continue`：跳过这个元素，处理下一个。

`return@label` 只能命中**当前**这个 lambda，不能跨出去返回外层函数：

```scoop
{{#include ../../examples/ch07/nonlocal_fail.scoop}}
```

```text
{{#include ../../examples/ch07/nonlocal_fail.error}}
```

需要“找到就从整个函数返回”时，用普通的 `for` 循环。循环体不是 lambda，`return` 返回的就是外层函数：

```scoop
{{#include ../../examples/ch07/first_negative.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/first_negative.expected}}
```

同样，lambda 里也不能用 `break` 或 `continue` 控制 lambda 外面的循环。匿名函数则不受“裸 `return`”的限制：它的 `return` 返回匿名函数自己，和具名函数一样。

> **从 Kotlin 过来**
>
> Kotlin 里常见的 `list.forEach { if (it < 0) return }` 依赖 `forEach` 是 `inline` 函数，`return` 会直接返回外层函数。Scoop 没有非局部返回：只想跳过当前元素就写 `return@forEach`，想结束整个函数就改用 `for` 循环。

## 7.4　函数引用：`::`

已有的函数也可以变成函数值，写法是在名字前加 `::`：

```scoop
{{#include ../../examples/ch07/references.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/references.expected}}
```

几种形式与 Kotlin 相同：

| 写法 | 含义 | 得到的函数类型 |
| --- | --- | --- |
| `::double` | 顶层函数或局部函数 | `(Int) -> Int` |
| `hi::greet` | 绑定到对象 `hi` 的方法 | `(String) -> String` |
| `Greeter::greet` | 未绑定的方法，接收者成为第一个参数 | `(Greeter, String) -> String` |
| `String::shout` 或 `::shout` | 扩展函数，接收者成为第一个参数 | `(String) -> String` |
| `::Tag` | 构造器 | `(String) -> Tag` |

`hi::greet` 在创建时就记下了 `hi`，之后每次调用都作用在这个对象上；`Greeter::greet` 则在调用时才接收对象。

和 Kotlin 一样，不加 `::` 的函数名不是值。Scoop 的报错会直接告诉你该怎么写：

```scoop
{{#include ../../examples/ch07/reference_fail.scoop}}
```

```text
{{#include ../../examples/ch07/reference_fail.error}}
```

## 7.5　闭包：捕获外层的值

lambda 可以使用定义它的地方能看到的变量。使用了外层变量的函数值叫**闭包**，被使用的外层变量叫做被闭包**捕获**了。

```scoop
{{#include ../../examples/ch07/capture.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/capture.expected}}
```

`scale` 捕获了 `factor`；`makeGreeter` 返回的 lambda 捕获了参数 `greeting`，即使 `makeGreeter` 已经返回，闭包里仍然保存着这个值，所以 `hello` 和 `howdy` 各自记着不同的问候语。

Scoop 的捕获规则很简单：

- **只能捕获不能重新赋值的东西**：`val`、函数参数、`this`。
- 捕获**按值**进行，发生在函数值被创建的那一刻。对引用类型复制的是引用，对值类型（如第 8 章的 struct）复制的是整个值。

### 不能捕获 `var`

外层的 `var` 不能被捕获，**连读取都不行**：

```scoop
{{#include ../../examples/ch07/capture_read_fail.scoop}}
```

```text
{{#include ../../examples/ch07/capture_read_fail.error}}
```

写入当然也不行。下面是 Kotlin 里很常见的“在 lambda 里累加计数器”：

```scoop
{{#include ../../examples/ch07/capture_write_fail.scoop}}
```

```text
{{#include ../../examples/ch07/capture_write_fail.error}}
```

局部函数也遵守同一条规则，在局部 `fun` 里修改外层的 `var` 同样会报这个错。

为什么这么严格？如果允许捕获 `var`，就必须回答“闭包看到的是创建时的值，还是最新的值”。Kotlin 的答案是最新的值，为此编译器会悄悄把这个 `var` 搬到堆上的一个包装对象里，让外层和闭包共享它。这个对象在源码里是看不见的，一旦闭包被保存起来或交给别的线程，就很难看清是谁在修改它。Scoop 不做这种隐式转换，要求你在两种意图中明确选一种。

报错信息里已经给出了这两种改法：

1. **只需要当时的值**：先把它存进一个 `val` 快照，再捕获快照。上面 `capture.scoop` 的最后一段就是这样：`report` 捕获的是 `snapshot`，之后 `total` 改成 99，`report()` 打印的仍是 10。
2. **需要共享、修改同一份状态**：把状态放进一个对象里，用 `val` 持有这个对象，捕获这个 `val`。

### 用对象共享可变状态

```scoop
{{#include ../../examples/ch07/shared_state.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/shared_state.expected}}
```

`Counter` 是一个只有一个 `var` 属性的小 class（class 的完整介绍见第 13 章）。`val sum = Counter(0)` 让 `sum` 这个绑定不能再换成别的对象，但对象内部的 `value` 可以修改。闭包捕获的是 `sum` 这个引用，于是闭包里的 `sum.value = ...` 和外面读到的 `sum.value` 是同一个属性。

这个模式能解决 Kotlin 里捕获 `var` 的所有用法：

- **累加**：`sum` 在 lambda 里被累加，外面读到 6。
- **生成器**：`makeCounter` 每次被调用都创建一个新的 `Counter`，返回的闭包各自持有自己的那个，所以 `next` 和 `other` 互不干扰。
- **多个闭包共享状态**：`press` 和 `reset` 捕获了同一个 `clicks`，一个修改的结果另一个能看到。

这样写比 Kotlin 多了一个类名，但共享的状态在源码中有了名字和类型，谁持有它、谁会修改它，一眼就能看出来。

> **深入一点：闭包在内存里的样子**
>
> 函数类型是引用类型。一个闭包在运行时是堆上的一个小对象，里面存着代码的入口和一块“捕获环境”：创建闭包时，被捕获的值逐个复制到这块环境里。捕获的是引用就复制引用，捕获的是 struct 就把整个值内联存进去，不会为它额外装箱。闭包由 GC 管理，只要闭包还能被访问到，它捕获的对象也就一直存活。
>
> 因为闭包有身份，可以用 `===` 判断两个变量是否保存着同一个函数值；但函数值之间没有 `==` 意义上的相等，两次对同一个函数写 `::f` 是否得到同一个对象，也没有保证。
>
> 函数类型之间还有一条型变规则：参数类型可以更宽，返回类型可以更窄。例如期望 `(Child) -> Parent` 的地方可以传入 `(Parent) -> Child` 的函数值。这和第 17 章“泛型类型不变”的规则不冲突，后者说的是 `Box<Child>` 这样的泛型类。

## 7.6　函数值只能按位置调用

第 6 章介绍的默认参数和命名参数，是**函数声明**提供的调用便利。函数变成函数值之后，类型里只剩下 `(String, String) -> String`，参数名和默认值都不再存在。因此：

```scoop
{{#include ../../examples/ch07/named_fail.scoop}}
```

```text
{{#include ../../examples/ch07/named_fail.error}}
```

省略有默认值的参数也不行：

```scoop
{{#include ../../examples/ch07/default_fail.scoop}}
```

```text
{{#include ../../examples/ch07/default_fail.error}}
```

通过函数值调用时，必须按位置传入函数类型要求的全部参数。如果需要一个“只传名字、问候语用默认值”的函数值，就写一个 lambda 包一层，在 lambda 里按名字直接调用原函数：

```scoop
{{#include ../../examples/ch07/positional.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/positional.expected}}
```

同理，`vararg` 参数在函数类型中表现为普通的 `Array<T>` 参数，通过函数值调用时要传一个数组。

## 7.7　带接收者的函数类型

Kotlin 的 `buildString { append("...") }` 之类的 DSL 写法依赖**带接收者的函数类型** `A.() -> R`：lambda 体内的 `this` 是一个 `A`，可以直接调用它的方法。Scoop 也支持：

```scoop
{{#include ../../examples/ch07/receiver.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/receiver.expected}}
```

`build` 的类型是 `StringBuilder.() -> Unit`，所以传入的 lambda 里 `append(...)` 指的是 `this.append(...)`。调用这类函数值有两种写法：`builder.build()`，或者把接收者当作第一个参数，`shout("Scoop")`。

注意 Scoop 的核心库里没有 Kotlin 的 `let`、`apply`、`also`、`run`、`with` 这一组作用域函数，也没有 `buildString`。需要时可以像上面这样自己写一个，通常只要几行。

## 7.8　`inline` 等修饰符

Kotlin 的 `inline`、`crossinline`、`noinline`、`reified` 和 `tailrec` 在 Scoop 中**可以写，但会被完全忽略**。允许它们出现，只是为了让从 Kotlin 移植过来的代码少改几处：

```scoop
{{#include ../../examples/ch07/modifiers.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/modifiers.expected}}
```

具体来说：

- `inline` 不会让函数内联，也**不会**允许非局部返回（见下面的例子）。
- `tailrec` 不会把递归改写成循环，也不检查函数是否真的是尾递归。递归很深时可能栈溢出，需要常量栈空间就直接写循环。
- `reified` 不需要：Scoop 的泛型按每种类型参数分别生成代码（第 17 章），运行时本来就知道真实类型。

下面的高阶函数加了 `inline`，lambda 里的裸 `return` 照样报错：

```scoop
{{#include ../../examples/ch07/inline_return_fail.scoop}}
```

```text
{{#include ../../examples/ch07/inline_return_fail.error}}
```

函数要不要内联，由编译器在优化时自行决定，和这些修饰符无关。

## 7.9　标准库里的高阶函数

集合上的 `map`、`filter`、`fold` 等函数由 `scoop.std` 提供，不在默认可用的核心库里。单文件程序不需要声明 `scoop.std` 依赖，但要先导入 `scoop.collections`：

```scoop
{{#include ../../examples/ch07/collections.scoop}}
```

输出：

```text
{{#include ../../examples/ch07/collections.expected}}
```

它们的用法和 Kotlin 基本相同，lambda 规则也和本章前面讲的一样。`map` 和 `filter` 返回一个新的只读 `List`，不修改原数组。import 的细节见第 28 章，`scoop.std` 集合的完整介绍见第 23 章。

## 从 Kotlin 过来：捕获 `var` 的计数器

下面这段 Kotlin 代码在 Scoop 里无法编译：

```kotlin
var count = 0
items.forEach { if (it.isValid) count++ }
println(count)
```

按意图不同，有三种改写方式：

1. **不用 lambda，改用 `for` 循环。** 循环体不是闭包，可以直接修改局部 `var`。这是最简单的写法，大多数时候应该首选它。
2. **用 `fold` 或 `count` 这类返回结果的函数**，把“累加”变成“计算出一个值”，例如 7.9 中的 `scores.fold(0) { sum, score -> sum + score }`。
3. **确实需要让闭包修改外部状态**（比如回调、事件处理）时，把状态放进 `val` 持有的对象里，如 7.5 的 `Counter`。

| Kotlin | Scoop |
| --- | --- |
| `(Int) -> Int`、`{ x -> x * 2 }`、`it` | 相同 |
| 尾随 lambda | 相同 |
| lambda 参数类型推不出来时退回宽松类型 | 编译错误，需要写出参数类型或期望类型 |
| lambda 中的 `return`（`inline` 时为非局部返回） | 裸 `return` 一律报错；用 `return@label`，或改用 `for` 循环 |
| `::f`、`obj::method`、`Type::method`、`::Class` | 相同 |
| 捕获并修改 `var` | 不能捕获 `var`，读也不行；用 `val` 快照或 `val` 持有的对象 |
| 通过函数引用使用命名参数、默认参数 | 不支持；函数值只能按位置传全部参数 |
| `inline`、`crossinline`、`noinline`、`reified`、`tailrec` | 可以写，但被忽略 |
| `let`、`apply`、`also`、`run`、`with`、`buildString` | 核心库中没有，需要时自己写 |
| 集合的 `map`、`filter`、`fold` | 由 `scoop.std` 提供，需要 `import scoop.collections.*` |

## 常见误用

- **在 lambda 里读写外层 `var`**：改用 `for` 循环、`val` 快照，或用 `val` 持有一个可变对象（7.5）。
- **在 lambda 里写 `return` 想结束外层函数**：Scoop 没有非局部返回，改用 `for` 循环（7.3）。
- **以为加上 `inline` 就能非局部返回**：`inline` 被忽略，不改变任何规则（7.8）。
- **通过函数值使用命名参数或省略默认参数**：函数值只认位置参数，需要时用 lambda 包装原函数（7.6）。
- **把函数名直接当值传**：要写 `::f`。
- **没有期望类型又不写参数类型**：`val add = { a, b -> a + b }` 会报错，给参数或变量加上类型（7.2）。
- **调用 `map`、`filter` 时报“没有这个方法”**：检查是否 `import scoop.collections.*`（7.9）。

## 小结

- 函数类型写作 `(A, B) -> R`，函数值可以存进变量、作为参数传递、作为结果返回。
- lambda、匿名函数、函数引用 `::f` 都会产生函数值；lambda 最后一个表达式是它的结果。
- lambda 里不能写裸 `return`，用 `return@label` 局部返回；没有非局部返回。
- 闭包只能捕获 `val`、参数和 `this`，按值、在创建时捕获；外层 `var` 读写都不能捕获。
- 共享可变状态的标准写法：用 `val` 持有一个带 `var` 属性的对象，捕获这个 `val`。
- 函数值只能按位置调用，不保留参数名、默认值和 `vararg`。
- `inline` 等 Kotlin 修饰符被接受但忽略；集合高阶函数来自 `scoop.std`。

## 练习

1. 写一个高阶函数 `compose(f: (Int) -> Int, g: (Int) -> Int): (Int) -> Int`，返回“先 `f` 后 `g`”的函数。用 `{ x: Int -> x + 1 }` 和 `{ x: Int -> x * 2 }` 验证 `compose(inc, dbl)(3)` 和 `compose(dbl, inc)(3)` 的结果分别是 8 和 7。
2. 写 `fun makeAccumulator(): (Int) -> Int`，返回的函数每次被调用时把参数加到内部的总和上，并返回当前总和。分别创建两个累加器，验证它们互不影响。
3. 把下面的 Kotlin 代码改写成 Scoop，分别用 `for` 循环和 `fold` 两种方式实现：
   ```kotlin
   var longest = ""
   words.forEach { if (it.length > longest.length) longest = it }
   ```
4. 写一个 `fun retry(times: Int, action: () -> Boolean): Boolean`，最多调用 `action` `times` 次，某次返回 `true` 就立即返回 `true`。想一想：为什么这里用 `for` 循环实现比用一个“对每次尝试执行 lambda”的辅助函数更自然？
