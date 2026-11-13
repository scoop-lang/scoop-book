# 第 6 章　函数

函数是 Scoop 程序最基本的组织单位。好消息是，Kotlin 里写函数的那套语法几乎可以原样搬过来：`fun` 关键字、表达式体、默认参数、命名参数、`vararg`、扩展函数、`infix`、局部函数，全都在。

不过有几处细节和 Kotlin 不一样，而且往往在你最想不到的地方报错：块体里随手写的一个表达式会被拒绝，局部函数不能修改外层的 `var`，`vararg` 的展开对类型要求更严格。本章把这些差别逐一讲清楚。

本章介绍：

- 表达式体和块体两种写法，以及块体为什么必须写 `return`；
- 参数是不可变绑定，传参时到底复制了什么；
- 默认参数、命名参数、`vararg`，以及实参的求值顺序；
- `Nothing`：所有类型的子类型，以及“返回 `Nothing` 的函数不会正常返回”的约定；
- 扩展函数、扩展属性和 `infix`；
- 局部函数；
- 重载：编译器怎样在同名函数中挑选，以及怎样读懂“没有可用候选”和“二义性”报错。

函数类型、lambda、函数引用和闭包放在第 7 章。

## 6.1　表达式体与块体

```scoop
{{#include ../../examples/ch06/bodies.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/bodies.expected}}
```

函数有两种写法：

- **表达式体**：`fun square(x: Int): Int = x * x`。等号后面的表达式就是结果。返回类型可以省略，由编译器从表达式推断，比如 `average` 的返回类型推断为 `Int`。
- **块体**：用花括号包住一组语句。返回非 `Unit` 的值时，**必须用 `return`**。块体函数如果省略返回类型，返回类型就是 `Unit`，不会去推断，比如 `report`。

返回类型的推断只发生在表达式体上。对外公开的函数，建议始终写出返回类型：签名一眼可见，改函数体时也不会不小心改变签名。

### 块体必须显式返回

块体里的最后一个表达式不会自动成为返回值。下面的函数看起来“算出了结果”，但编译器不接受：

```scoop
{{#include ../../examples/ch06/missing_return_fail.scoop}}
```

```text
{{#include ../../examples/ch06/missing_return_fail.error}}
```

编译器要求返回非 `Unit` 的函数，**每一条能正常走到结尾的路径**都必须 `return` 一个值（或者抛出异常）。只在 `if` 的某个分支里 `return`、另一个分支忘了写，也会得到同样的错误。

如果最后一行不是函数调用，而是 `a + b` 这样的普通表达式，报错会更早出现：

```scoop
{{#include ../../examples/ch06/bare_expression_fail.scoop}}
```

```text
{{#include ../../examples/ch06/bare_expression_fail.error}}
```

Scoop 不允许把一个“只算值、什么也不做”的表达式单独写成一条语句：语句位置的表达式必须是函数调用（或赋值等有效果的操作）。`a + b` 单独成行，结果马上被丢弃，这几乎一定是写错了，所以编译器直接拒绝。

反过来，表达式体里不能写 `return`：

```scoop
{{#include ../../examples/ch06/expression_return_fail.scoop}}
```

```text
{{#include ../../examples/ch06/expression_return_fail.error}}
```

省略了返回类型的块体函数是 `Unit` 函数，在里面 `return 42` 同样是错误：

```scoop
{{#include ../../examples/ch06/implicit_unit_fail.scoop}}
```

```text
{{#include ../../examples/ch06/implicit_unit_fail.error}}
```

想让它返回 `Int`，要么写成 `fun answer(): Int { return 42 }`，要么写成表达式体 `fun answer() = 42`。

顶层函数之间没有声明顺序的要求：`main` 可以调用写在它后面的函数，两个函数也可以互相递归。

> **从 Kotlin 过来**
>
> “块体必须 `return`”“表达式体不能 `return`”这两条和 Kotlin 完全一样。真正的区别是 `a + b` 这种**无效果的表达式语句**：Kotlin 只是默默忽略它（IDE 可能给个警告），Scoop 则是编译错误。从 lambda 的写法（最后一个表达式就是结果，见第 7 章）切换到块体函数时，最容易犯这个错。

## 6.2　参数是不可变绑定

```scoop
{{#include ../../examples/ch06/params.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/params.expected}}
```

函数参数和 `val` 一样，是**不可重新赋值**的绑定。给参数赋值是编译错误：

```scoop
{{#include ../../examples/ch06/param_assign_fail.scoop}}
```

```text
{{#include ../../examples/ch06/param_assign_fail.error}}
```

需要一个“从参数开始、之后会变”的变量时，像 `clamp` 那样先复制到一个 `var` 里。如果只是想换一个规整后的值，也可以像 `normalize` 那样用同名的 `val` 遮蔽参数：`val count = if (count < 0) 0 else count`。右边的 `count` 还是参数，左边声明的是新绑定，之后的代码看到的都是新值。

### 传参时复制了什么

Scoop 的调用一律**按值传递**：每个实参先求值，再用得到的值初始化参数。“值”是什么取决于类型，这和第 8 章讲的赋值规则完全一致：

- struct、enum、tuple 这类值类型，复制的是整个值，函数里拿到的是独立的副本；
- class 等引用类型，复制的是**引用**。函数和调用方持有两份引用，指向同一个对象。

所以 `addItem` 往 `items` 里添加元素，调用方的 `names` 能看到变化：两边是同一个 `ArrayList`。但如果函数里写 `items = ArrayList()`，那是给参数重新赋值，本来就不允许；即使允许，也只会让函数自己那份引用指向新对象，不影响调用方。这就是 Java 和 Kotlin 里大家熟悉的语义，Scoop 没有“按引用传递”。

## 6.3　默认参数与命名参数

```scoop
{{#include ../../examples/ch06/defaults.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/defaults.expected}}
```

这一节的写法和 Kotlin 一样：

- 参数可以带默认值，调用时省略就用默认值。
- 默认值表达式可以引用**排在前面**的参数，`box` 的 `height` 默认等于 `width`。
- 调用时可以写 `name = value` 按名字传参。命名实参可以打乱顺序，比如 `greeting(ending = "?", name = "Kai", prefix = "Hey")`。
- 位置实参和命名实参可以混用，比如 `box(3, depth = 4)`：先按位置给 `width`，再用名字跳过 `height`。

混用时有一条规则：**一旦某个命名实参不在它自己的位置上，后面的实参就必须全部写名字**。否则编译器无法判断后面那个未命名的值该给谁：

```scoop
{{#include ../../examples/ch06/named_order_fail.scoop}}
```

```text
{{#include ../../examples/ch06/named_order_fail.error}}
```

漏掉必需参数、写错参数名，都会在报错里点明是哪个参数：

```scoop
{{#include ../../examples/ch06/arguments_fail.scoop}}
```

```text
{{#include ../../examples/ch06/arguments_fail.error}}
```

默认值只能引用前面的参数，不能反过来：

```scoop
{{#include ../../examples/ch06/default_order_fail.scoop}}
```

```text
{{#include ../../examples/ch06/default_order_fail.error}}
```

参数名是函数对外接口的一部分：调用方一旦用了命名实参，你再改参数名，调用方就编译不过了。给公开函数起参数名时，要像起函数名一样认真。

### 实参的求值顺序

```scoop
{{#include ../../examples/ch06/eval_order.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/eval_order.expected}}
```

一次调用按下面的顺序执行：

1. 所有**写出来的实参**按它们在源码中出现的顺序，从左到右各求值一次。命名实参只决定“值属于哪个参数”，不改变求值顺序，所以 `box(depth = ..., width = ...)` 先算 `depth`、再算 `width`。
2. 然后，对**确实被省略**的参数，按参数声明顺序求值默认值表达式。默认值在每次调用时重新计算，不会缓存；显式传了值的参数，默认值表达式根本不会执行。
3. 最后进入函数体。

日常编程中，你很少需要依赖这个顺序；但当实参里有打印、读文件、修改状态之类的副作用时，知道“从左到右、默认值最后”可以免去很多猜测。

> **深入一点：默认值在哪里解析**
>
> 默认值表达式里的名字在**声明函数的地方**解析，而不是在调用的地方。即使调用方恰好有一个同名的局部变量或另一个重载，也不会改变默认值的含义。对公开的库函数，这还意味着默认值只能引用调用方也看得见的东西：`public` 函数的默认值不能调用一个 `internal` 的辅助函数（可见性见第 15 章）。

## 6.4　`vararg`：可变数量的参数

```scoop
{{#include ../../examples/ch06/vararg.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/vararg.expected}}
```

`vararg numbers: Int` 声明的是**元素类型**；在函数体里，`numbers` 的类型是 `Array<Int>`。（注意数组的 `size` 和下标都是 `Long`，所以 `join` 用 `0L until parts.size` 遍历，见第 3 章。）

调用时有几种写法：

- 什么都不传：得到一个空数组，`sum()` 返回 0；
- 逐个传：`sum(1, 2, 3)`；
- 用 `*` 展开一个已有数组，并且可以和单个元素混合：`sum(1, *more, 6)`。展开时会构造一个新数组，函数拿到的不是 `more` 本身；
- 用名字传一整个数组：`sum(numbers = more)`。

一个参数列表最多只能有一个 `vararg`。`vararg` 后面还有参数时，后面的参数要用名字传，比如 `join("a", "b", separator = " | ")`：位置实参一旦到达 `vararg`，后面所有未命名的实参都归它。

直接把数组当作一个元素传进去是不行的，必须用 `*` 展开：

```scoop
{{#include ../../examples/ch06/vararg_array_fail.scoop}}
```

```text
{{#include ../../examples/ch06/vararg_array_fail.error}}
```

报错里的 `fun sum(numbers: Array<Int>)` 说明了编译器眼中的真实签名：`vararg x: T` 和 `x: Array<T>` 是**同一个参数类型**，`vararg` 只是调用方的一种书写便利。因此不能靠这一点重载：

```scoop
{{#include ../../examples/ch06/vararg_overload_fail.scoop}}
```

```text
{{#include ../../examples/ch06/vararg_overload_fail.error}}
```

还有一条比 Kotlin 严格的规则：用 `*` 展开的数组，类型必须**恰好**是 `Array<T>`。即使 `Dog` 是 `Animal` 的子类，`Array<Dog>` 也不能展开给 `vararg animals: Animal`：

```scoop
{{#include ../../examples/ch06/vararg_spread_fail.scoop}}
```

```text
{{#include ../../examples/ch06/vararg_spread_fail.error}}
```

逐个传 `Dog()` 没有问题，每个元素各自满足 `Animal` 即可；但整个数组的类型不会“向上转”。原因是 Scoop 的泛型是不变的，`Array<Dog>` 不是 `Array<Animal>`（第 17 章详细讨论）。需要时，先构造一个 `Array<Animal>` 再展开。

> **从 Kotlin 过来**
>
> Kotlin 里 `vararg xs: Int` 在函数体中的类型是 `IntArray`，`vararg xs: Animal` 是 `Array<out Animal>`，所以 `*dogs` 能直接展开。Scoop 只有 `Array<T>` 一种数组，展开要求类型完全一致。

## 6.5　`Nothing`：底类型

```scoop
{{#include ../../examples/ch06/nothing.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/nothing.expected}}
```

`Nothing` 是 Scoop 类型系统里的**底类型**（bottom type），也就是**所有类型的子类型**。它和 `Any` 正好处在两端：`Any` 在最顶上，任何类型都是 `Any` 的子类型；`Nothing` 在最底下，它是任何类型的子类型。

按照子类型的一般规则，需要某个类型的地方都可以放它的子类型，所以从形式上说，`Nothing` 类型的表达式**可以用在需要任何类型的地方**。例子里的 `fail(...)` 就是这样：在 `percent` 里它出现在需要 `Int` 的 `else` 分支，在 `grade` 里它出现在需要 `String` 的 `when` 分支，两处都能通过类型检查。合并分支类型时，`Nothing` 分支不影响结果：`if (...) value else fail(...)` 的类型就是 `Int`。

“返回 `Nothing` 的函数不会正常返回”，是建立在底类型之上的**另一层约定**。一个函数的返回类型写成 `Nothing`，它就承诺自己永远不会正常返回：只能抛出异常、调用另一个返回 `Nothing` 的函数，或者进入一个不会结束的循环。编译器会检查这一点：这样的函数里不能写 `return`，也不能正常执行到函数体结尾，否则会报 “non-Unit function `bad` may complete without returning a value” 这类错误。

也正因为这些函数从不返回，没有任何途径能真正得到一个 `Nothing` 类型的值，所以 **`Nothing` 类型没有任何值**。这和底类型的身份是一致的：一个值不可能同时是 `Int`、`String` 以及其他所有类型。`Nothing` 不是 `Unit`：`Unit` 有一个值，表示“正常结束了，但没有有用的结果”；`Nothing` 一个值也没有，表示“根本不会正常结束”。

这两层合在一起，就是 `Nothing` 在调用方的用处：

- 调用 `fail(...)` 的表达式可以放在任何需要值的位置（底类型）；
- 编译器知道调用之后的代码不会执行（不返回的约定），所以 `checkAge` 的 `if` 分支即使没有 `return`，也不算“可能不返回值”的路径。

把“抛出某种异常”包装成辅助函数时，把返回类型声明成 `Nothing`，调用方就能像写 `throw` 一样使用它。第 5 章的 `return`、`break`、`continue` 能写在 `if` 分支里，也是因为它们作为表达式的类型是 `Nothing`。

（例子里 `IllegalArgumentException(Some(message))` 的 `Some` 是因为异常消息的类型是 `String?`，见第 12 章和第 19 章。）

## 6.6　扩展函数与扩展属性

```scoop
{{#include ../../examples/ch06/extensions.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/extensions.expected}}
```

扩展让你“给已有类型添加方法”，而不用修改它的源码，也不用继承它：

- `fun String.exclaim(): String` 声明了 `String` 上的扩展函数。函数体里的 `this` 是调用时点号左边的值，叫作**接收者**（receiver）。和普通方法一样，`this.` 通常可以省略，比如 `Counter.bump` 里直接写 `count`。
- 扩展函数和普通函数一样可以有默认参数、命名参数，`counter.bump(by = 5)`。
- `val String.initial: Char` 声明了扩展属性。扩展属性**没有存储**，只能通过 getter 计算出来：

```scoop
{{#include ../../examples/ch06/extension_property_fail.scoop}}
```

```text
{{#include ../../examples/ch06/extension_property_fail.error}}
```

扩展并没有真的修改那个类型，它只是一个“第一个参数写在点号左边”的普通函数。理解了这一点，下面几条规则就很自然了：

```scoop
{{#include ../../examples/ch06/extension_rules.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/extension_rules.expected}}
```

- **成员优先**：类型自己已经有同名、参数也匹配的方法时，调用的是成员，扩展被忽略。`greeter.hello()` 调用的是 `member hello`。扩展只能“添加”，不能“覆盖”。
- **按静态类型选择**：调用哪个扩展，看的是变量在编译期的类型，而不是运行时对象的真实类型。`shape` 声明为 `Shape`，所以 `shape.kind()` 调用的是 `Shape.kind`，尽管它实际上是 `Circle`。需要按运行时类型分派的行为，应该写成 `open` 方法并 `override`（第 14 章）。
- **看不到私有成员**：扩展函数站在类型外部，只能访问调用方本来就能访问的成员：

```scoop
{{#include ../../examples/ch06/extension_private_fail.scoop}}
```

```text
{{#include ../../examples/ch06/extension_private_fail.error}}
```

扩展函数也有可见性，默认只在当前 Cone 内可用；别的文件、别的 Cone 要用，还需要 `import`（第 15 章、第 28 章）。

## 6.7　`infix`：中缀调用

```scoop
{{#include ../../examples/ch06/infix.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/infix.expected}}
```

标记了 `infix` 的函数可以写成 `a name b` 的形式，它完全等价于 `a.name(b)`。`infix` 函数必须满足：

- 是成员函数或扩展函数（要有接收者充当左边的操作数）；
- 恰好有一个参数，而且这个参数不能有默认值、不能是 `vararg`。

不满足时，编译器在声明处报错：

```scoop
{{#include ../../examples/ch06/infix_fail.scoop}}
```

```text
{{#include ../../examples/ch06/infix_fail.error}}
```

注意 `1 + 2 pow 2` 的结果是 9，而不是 5：**中缀函数调用的优先级低于算术运算**，这一行实际上是 `(1 + 2) pow 2`。所有中缀函数的优先级都相同，不能自定义，从左到右结合。把中缀调用和算术混在一起时，加上括号会清楚得多。

`infix` 适合读起来像一句话的操作，比如 `Tag("b") with "bold"`。如果你想让 `a * b` 这样的符号对自己的类型生效，那是运算符重载，见第 16 章。

## 6.8　局部函数

```scoop
{{#include ../../examples/ch06/local.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/local.expected}}
```

函数体里可以再声明函数，叫作**局部函数**。它只在外层函数内部可见，适合放那些“只为这一个函数服务”的小步骤。局部函数可以使用外层的参数和 `val`（`pad` 用了 `width`，`row` 用了 `border`），也可以递归调用自己（`loop`）。

局部函数和局部变量一样，**要先声明后使用**：

```scoop
{{#include ../../examples/ch06/local_order_fail.scoop}}
```

```text
{{#include ../../examples/ch06/local_order_fail.error}}
```

这一点和顶层函数不同：顶层函数之间没有顺序要求，局部函数则从声明处开始才可见。所以两个局部函数也无法互相递归；需要互相递归时，把它们提到顶层。

另一条更重要的限制：局部函数**不能读写外层的 `var`**：

```scoop
{{#include ../../examples/ch06/local_capture_fail.scoop}}
```

```text
{{#include ../../examples/ch06/local_capture_fail.error}}
```

这和 lambda 捕获变量的规则是同一条：只能捕获不会被重新赋值的绑定。第 7 章会详细解释原因，并给出几种改写方法；最简单的一种是让局部函数通过参数和返回值交换数据，比如把 `tick` 写成 `fun tick(n: Int): Int = n + 1`。

> **从 Kotlin 过来**
>
> Kotlin 的局部函数可以自由修改外层的 `var`，很多人用它在递归遍历中累加计数。在 Scoop 里，这样的代码会得到 “cannot capture mutable local” 错误。把计数器作为参数传入、返回新值，或者用一个 `val` 持有的可变对象（第 7 章）来代替。

## 6.9　重载

同一个作用域里可以有多个同名函数，只要它们的参数类型不同。调用时，编译器根据实参挑选一个：

```scoop
{{#include ../../examples/ch06/overloads.scoop}}
```

输出：

```text
{{#include ../../examples/ch06/overloads.expected}}
```

编译器挑选的过程，可以简化成三步理解：

1. **找出所有能用的候选**：参数个数、参数名、类型都要对得上。
2. **从中选出最具体的那个**：如果候选 A 能接受的实参，候选 B 也都能接受，而反过来不成立，那么 A 更具体。`greet(Dog())` 中，`greet(dog: Dog)` 比 `greet(animal: Animal)` 更具体；`describe(true)` 只有 `describe(x: Any)` 能用。
3. **仍然并列时的附加规则**：比如用到默认值更少的候选优先。`area(3)` 两个候选都能用，`area(side: Int)` 不需要默认值，所以它胜出。

有两点值得特别注意：

- **重载按静态类型选择**，和扩展一样。`pet` 声明为 `Animal`，所以 `greet(pet)` 调用的是 `Animal` 版本。
- **整数字面量没有固定类型**，它会去适配候选。`describe(1)` 选中 `Int` 版本，`describe(1L)` 选中 `Long` 版本；`10000000000` 超出了 `Int` 的范围，所以选中 `Long` 版本。没有更多线索时，整数字面量优先当作 `Int`，放不下再当作 `Long`。

### 读懂重载报错

重载出问题时，Scoop 的报错会列出它考虑过的**每一个候选**，以及每个候选失败的原因。

第一种是**没有可用的候选**。Scoop 的数值类型之间没有隐式转换（第 3 章），一个 `Byte` 既不会自动变成 `Int`，也不会变成 `Double`：

```scoop
{{#include ../../examples/ch06/no_candidate_fail.scoop}}
```

```text
{{#include ../../examples/ch06/no_candidate_fail.error}}
```

报错中的 `Int8` 就是 `Byte`。读这类报错时，逐行看每个候选后面的原因，找出你本来想调用的那一个，问题通常就一目了然。前面 6.3 节的 “required parameter has no argument”“has no parameter named” 也是同一种报错，只是那里只有一个候选。

第二种是**二义性**：有多个候选都能用，而且谁也不比谁更具体：

```scoop
{{#include ../../examples/ch06/ambiguous_fail.scoop}}
```

```text
{{#include ../../examples/ch06/ambiguous_fail.error}}
```

`pair(n, n)` 中，第一个候选在第一个参数上更具体，第二个候选在第二个参数上更具体，打成平手（报错里的 “tied”）。解决办法是让调用方说清楚意图，比如先 `val anything: Any = n` 再传，让只有一个候选能用；或者重新设计这组重载，避免这种交叉。

最后，有些重载在**声明时**就会被拒绝。重载只看参数类型，返回类型、参数名、默认值都不能区分两个函数：

```scoop
{{#include ../../examples/ch06/return_overload_fail.scoop}}
```

```text
{{#include ../../examples/ch06/return_overload_fail.error}}
```

把 `fun move(dx: Int)` 和 `fun move(dy: Int)` 放在一起也会得到同样的错误。要么改用不同的函数名（比如 `parseInt`、`parseLong`），要么让参数类型真的不同。

> **深入一点：候选从哪里来**
>
> 编译器查找同名函数时是分层进行的：先找局部声明，再找成员，然后是当前 Cone 的顶层函数、import 进来的函数、core 默认提供的函数等。它在**第一个有可用候选的层**里选择最具体的那个，不会跨层比较。所以报错里会写明 “in current-unit top-level candidate layer” 这样的层名。实际效果是：离调用点更近的声明优先，例如成员优先于扩展；但如果近处的同名函数根本用不了（参数对不上），编译器会继续去外层找，而不是直接报错。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `fun f(x: Int) = x * 2`、块体 `return` | 相同 |
| 块体里单独一行 `a + b`：被忽略 | 编译错误：“statement must be a function call” |
| 参数不可赋值 | 相同；可以用同名 `val` 遮蔽 |
| 默认参数、命名参数、命名与位置混用 | 相同 |
| `vararg xs: Int` 在体内是 `IntArray` | 是 `Array<Int>` |
| `*dogs` 可以展开给 `vararg Animal` | 展开的数组类型必须恰好是 `Array<Animal>` |
| 扩展函数 / 扩展属性，成员优先、静态分派 | 相同 |
| `infix` 的声明要求和优先级 | 相同 |
| 局部函数可以修改外层 `var` | 不能读写外层 `var`（第 7 章） |
| 不能只靠返回类型重载 | 相同 |
| `tailrec` 保证尾递归优化 | 可以写，但会被忽略，不保证（第 7 章） |

## 常见误用

- **块体函数最后一行写结果却不 `return`**：编译器会报 “may complete without returning a value” 或 “statement must be a function call”。要么加 `return`，要么改成表达式体。
- **省略块体函数的返回类型，却 `return` 一个值**：省略返回类型的块体函数是 `Unit` 函数。
- **给参数赋值**：先复制到 `var`，或用同名 `val` 遮蔽。
- **把数组直接传给 `vararg`**：要写 `*array` 或 `name = array`。
- **展开子类型数组给 `vararg`**：`Array<Dog>` 不能展开给 `vararg Animal`。
- **以为扩展能覆盖成员，或会按运行时类型分派**：成员总是优先，扩展按静态类型选择。
- **把中缀调用和算术混用而不加括号**：`1 + 2 pow 2` 是 `(1 + 2) pow 2`。
- **在局部函数里修改外层计数器**：改用参数和返回值传递状态。
- **用参数名或返回类型区分重载**：只有参数类型能区分重载。

## 小结

- 表达式体用 `=` 给出结果，可以推断返回类型；块体必须用 `return` 返回非 `Unit` 的值，省略返回类型时就是 `Unit`。
- 语句位置不能单独写一个无效果的表达式。
- 参数是不可变绑定；传参按值进行，值类型复制整个值，引用类型复制引用。
- 默认值可以引用前面的参数；实参从左到右求值，被省略参数的默认值随后按声明顺序求值。
- `vararg x: T` 在体内是 `Array<T>`；展开要用 `*`，而且数组类型必须完全一致。
- `Nothing` 是底类型，是所有类型的子类型，可以用在需要任何类型的地方；返回 `Nothing` 的函数约定不会正常返回，因此 `Nothing` 没有任何值。
- 扩展函数是“接收者写在点号左边”的普通函数：成员优先、按静态类型选择、看不到私有成员；扩展属性没有存储。
- `infix` 函数必须有接收者和恰好一个参数，优先级低于算术运算。
- 局部函数先声明后使用，不能读写外层 `var`。
- 重载只看参数类型；报错会列出每个候选及其失败原因。

## 练习

1. 写一个表达式体函数 `fun max3(a: Int, b: Int, c: Int): Int`，再把它改写成块体函数。两种写法各自需要注意什么？
2. 写 `fun repeat(text: String, times: Int = 2, separator: String = ""): String`，并分别用 `repeat("ab")`、`repeat("ab", 3)`、`repeat("ab", separator = "-")` 调用它。
3. 写 `fun average(vararg values: Double): Double`，没有参数时抛出 `IllegalArgumentException`。用 `average(1.0, 2.0)` 和 `average(*[1.0, 2.0, 3.0])` 测试。
4. 给 `Int` 写一个扩展属性 `isPrime: Boolean`，打印 1 到 30 之间的素数。
5. 下面两个重载在调用 `show(1, 2)` 时会发生什么？先推测，再实际编译验证：

   ```text
   fun show(a: Int, b: Long): String
   fun show(a: Long, b: Int): String
   ```

6. 写一个函数，用局部递归函数计算一个 `Array<Int>` 中所有元素的和，不使用任何 `var`。
