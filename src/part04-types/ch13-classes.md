# 第 13 章　类与对象

第三部分花了很多篇幅讲 struct、enum 这些值类型。但并不是所有东西都适合当作“值”：一个银行账户、一个网络会话、一个播放器的游标，它们有身份，状态会随时间变化，被程序的多个部分共享。这类东西在 Scoop 里仍然用 **class** 表示。

Scoop 的 class 和 Kotlin 的 class 非常接近：主构造器、次构造器、`init`、属性的 getter 和 setter、`object`、companion object、嵌套类、`inner class`、匿名 object，写法基本一致。本章逐一介绍这些内容，重点放在和 Kotlin 不同的地方：

- 属性必须在声明处初始化，没有 `lateinit`；
- 构造过程中各部分的执行顺序，以及编译器会拒绝哪些“读得太早”的写法；
- 怎样用私有构造器加工厂函数，保证“对象一旦存在就一定合法”（第 8 章留下的问题）；
- `const val`、`object` 和 companion 的规则；
- 嵌套类、`inner class`、匿名 object 和局部类；
- 从 class 的角度看，什么时候该用 class，什么时候该用 struct。

继承和接口是第 14 章的内容，可见性的完整规则在第 15 章。本章的示例都是单文件程序，声明默认是 `internal` 的，在同一个文件里可以直接使用。

## 13.1　第一个 class

```scoop
{{#include ../../examples/ch13/account.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/account.expected}}
```

这个例子覆盖了 class 最常用的几种成员：

- **主构造器**写在类名后面。带 `val` / `var` 的参数（`owner`）同时声明了一个属性；不带的参数（`initial`）只是普通的构造参数。
- **body 里的存储属性** `balance` 用 `initial` 初始化。它是 `var`，但 setter 被声明为 `private`：类外可以读，不能写。
- **计算属性** `isEmpty` 没有存储，每次读取时执行 getter。
- **自定义 setter**：给 `note` 赋值时会执行 setter，`field` 表示这个属性背后的存储。
- **方法** `deposit` 修改 `balance`。

最后两行说明 class 是**引用类型**：`val b = a` 复制的是引用，`a` 和 `b` 指向同一个对象，通过 `b` 存的钱在 `a` 上也能看到，`a === b` 为 `true`。这和第 8 章的 struct 正好相反。

### 普通构造参数只在初始化时可见

不带 `val` / `var` 的主构造参数不会成为对象的一部分。它只能在属性的初始值、`init` 块和基类构造参数里使用，方法里看不到它：

```scoop
{{#include ../../examples/ch13/ctor_param_fail.scoop}}
```

```text
{{#include ../../examples/ch13/ctor_param_fail.error}}
```

需要在方法里使用，就把它写成 `val initial: Long`，让它成为属性。

### 私有 setter 的写法

`balance` 的 setter 写成了完整的形式：

```scoop
var balance: Long = initial
    private set(value) {
        field = value
    }
```

Kotlin 里可以只写 `private set`，但 Scoop 要求 setter 带上参数和函数体。类外给 `balance` 赋值会被拒绝：

```scoop
{{#include ../../examples/ch13/private_setter_fail.scoop}}
```

```text
{{#include ../../examples/ch13/private_setter_fail.error}}
```

### `==` 不是自动的

class 没有自动生成的相等比较。Scoop 的 `Any` 没有任何成员，所以两个 class 实例默认**不能**用 `==` 比较：

```scoop
{{#include ../../examples/ch13/class_equals_fail.scoop}}
```

```text
{{#include ../../examples/ch13/class_equals_fail.error}}
```

想比较身份，用 `===`；想按内容比较，就像第 8 章 8.7 节那样实现 `Equals<T>`（打印则需要实现 `ToString`）。这和 struct 不同：struct 的 `==` 是按字段自动可用的，因为 struct 本身就是“这几个字段的值”；而 class 的两个实例内容相同，也未必是同一个东西。

## 13.2　属性必须在声明处初始化

Kotlin 允许先声明属性，稍后再赋值（`lateinit var`，或者在 `init` 里给 `val` 赋值）。Scoop 不允许：**每个存储属性都必须在声明处写出初始值。**

`lateinit` 根本不存在：

```scoop
{{#include ../../examples/ch13/lateinit_fail.scoop}}
```

```text
{{#include ../../examples/ch13/lateinit_fail.error}}
```

报错同时给出了替代写法。唯一可以省略初始值的属性是**可变的 `Option` 属性**：`var user: String?` 等价于 `var user: String? = None`。其他属性省略初始值都是错误：

```scoop
{{#include ../../examples/ch13/no_initializer_fail.scoop}}
```

```text
{{#include ../../examples/ch13/no_initializer_fail.error}}
```

“稍后才知道的值”就用 `Option` 表示，读取时处理没有值的情况：

```scoop
{{#include ../../examples/ch13/session.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/session.expected}}
```

这样做的好处是，“还没登录”这个状态在类型上一目了然，不会出现 Kotlin 里访问未初始化的 `lateinit` 属性、运行时才抛出 `UninitializedPropertyAccessException` 的情况。

> **从 Kotlin 过来**
>
> Kotlin 的 `lateinit var user: User` 改写成 `var user: User?`，在用到的地方用 `?:`、`?.` 或 `when` 取值（第 12 章）。如果属性在构造之后一定有值、只是计算它的代码比较长，那就把计算放进一个函数，在声明处调用：`val config: Config = loadConfig(path)`。

## 13.3　次构造器

主构造器之外，class 还可以声明任意多个**次构造器**：

```scoop
{{#include ../../examples/ch13/secondary.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/secondary.expected}}
```

规则和 Kotlin 基本一致：

- class 有主构造器时，每个次构造器都必须通过 `: this(...)` 直接或间接委托给主构造器。`Rect(4)` 先执行 `Rect(4, 4)`，再执行次构造器自己的函数体。
- class 没有主构造器时（`Box`），次构造器直接执行；如果有基类，用 `: super(...)` 调用基类构造器（第 14 章）。
- 次构造器的参数不能写 `val` / `var`。
- **次构造器必须有函数体**，即使是空的也要写 `{}`。`constructor(side: Int) : this(side, side)` 后面不加花括号会报 “secondary constructors require a block body”。正确的写法是 `constructor(side: Int) : this(side, side) {}`。

注意 `Box` 的 `items` 仍然有初始值 `0`，次构造器里再给它赋新值。像 Kotlin 那样只声明 `val width: Int`、留到构造器里赋值，在 Scoop 中不成立，因为属性必须在声明处初始化：

```scoop
{{#include ../../examples/ch13/assign_in_ctor_fail.scoop}}
```

```text
{{#include ../../examples/ch13/assign_in_ctor_fail.error}}
```

大多数情况下，更好的写法是把这些属性放进主构造器：`class Rect(val width: Int, val height: Int)`，次构造器只负责提供其他的构造方式。

## 13.4　`init` 与初始化顺序

构造一个对象时，各部分按固定的顺序执行。下面的程序把每一步打印出来：

```scoop
{{#include ../../examples/ch13/init_order.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/init_order.expected}}
```

顺序是：

1. 先求值构造调用的实参；
2. 如果有基类，先完成基类的构造（第 14 章）；
3. 把主构造器中带 `val` / `var` 的参数写入属性；
4. body 里的属性初始值和 `init` 块，**按它们在源码中出现的顺序**交替执行；
5. 最后执行次构造器的函数体（如果是通过次构造器创建的）。

`init` 可以写多个，它们和属性初始值交错执行。方法、计算属性和次构造器的声明本身不执行任何东西，写在哪里都不影响顺序。

既然是按源码顺序执行，排在前面的初始值就不能读取排在后面的属性，编译器会直接报错：

```scoop
{{#include ../../examples/ch13/forward_read_fail.scoop}}
```

```text
{{#include ../../examples/ch13/forward_read_fail.error}}
```

把 `subtotal` 移到 `total` 前面就好了。

> **深入一点：编译器能查出多少“读得太早”**
>
> 编译器能诊断初始化代码里**直接**读取尚未初始化的属性，比如上面的例子。但如果初始化代码调用了一个方法，而这个方法又读取了还没初始化的属性，编译器不会去追踪这种间接访问，这时的行为是未定义的。在初始值和 `init` 里调用本类的方法时要注意这一点，尤其是会被子类覆写的方法：构造期间调用虚方法，执行的是最终子类的版本，而子类的属性此时还没有初始化。

### 构造调用不能单独成为一条语句

有时只想“构造一个对象，看看副作用”，比如上面例子里打印出来的初始化过程。直接写一行 `Widget("a")` 是不行的：

```scoop
{{#include ../../examples/ch13/ctor_statement_fail.scoop}}
```

```text
{{#include ../../examples/ch13/ctor_statement_fail.error}}
```

第 6 章说过，语句位置只能写函数调用、赋值这类有效果的东西，构造表达式不算函数调用。要把结果保存下来，比如 `val a = Widget("a", 3)`，就像上面的 `init_order` 那样。

## 13.5　私有构造器与工厂函数

第 8 章 8.6 节提到，struct 的主构造器总是公开的，所以“`Percent` 必须在 0 到 100 之间”这样的约束，struct 无法强制保证。class 可以：把构造器设为 `private`，只通过会做检查的工厂函数创建实例。

```scoop
{{#include ../../examples/ch13/percent.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/percent.expected}}
```

`private constructor` 让构造器只在 `Percent` 自己的 body 里可用，包括它的 companion object。companion 里提供两个工厂函数，代表两种常见风格：

- `of` 返回 `Percent?`：不合法时返回 `None`，调用方必须处理这种情况；
- `parse` 返回 `Percent`：不合法时抛出异常。

在类外直接调用构造器会被拒绝，即使是在同一个文件里：

```scoop
{{#include ../../examples/ch13/percent_ctor_fail.scoop}}
```

```text
{{#include ../../examples/ch13/percent_ctor_fail.error}}
```

这样，程序里任何一个 `Percent` 对象都一定经过了检查。再加上 `value` 是 `val`，对象创建之后也不会变成不合法的值。这是 class 相对 struct 的一个重要能力：**class 能保护自己的不变式**，struct 不能。

## 13.6　`const val`

`const val` 声明一个**编译期常量**：它的值在编译时就确定，直接嵌入到使用它的地方，不需要在运行时计算或初始化。

```scoop
{{#include ../../examples/ch13/config.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/config.expected}}
```

`APP_NAME` 和 `MAX_USERS` 都是 `const val`。规则如下：

- 只能声明在**顶层**、`object` 或 companion object 中，不能声明在普通 class 里，也不能是局部变量；
- 必须是 `val`，必须有初始值，不能带 getter 或委托；
- 类型可以是 `Boolean`、各种数值类型、`Char`、`String`，以及由这些组成的 struct、tuple 和 enum 值。类型可以省略，由初始值推断；
- 初始值必须是编译期能算出来的表达式：字面量、其他 `const val`、以及由它们组成的运算。**普通函数调用不行**，构造器调用也不行。

放进普通 class 会报错：

```scoop
{{#include ../../examples/ch13/const_class_fail.scoop}}
```

```text
{{#include ../../examples/ch13/const_class_fail.error}}
```

初始值调用了普通函数：

```scoop
{{#include ../../examples/ch13/const_call_fail.scoop}}
```

```text
{{#include ../../examples/ch13/const_call_fail.error}}
```

不能写成 `const val` 的常量，写成普通的 `val` 即可，区别只是它在运行时初始化。

## 13.7　`object`：单例

`object` 同时声明了一个类型和这个类型**唯一的实例**。上面的 `Config` 就是一个 object：

- 通过名字直接访问它的成员：`Config.record()`、`Config.requests`；
- `Config` 本身也是一个值，可以赋给变量。`same === Config` 为 `true`，因为只有这一个实例；
- object 可以有 `var` 属性，它们就是全局共享的可变状态。

输出里值得注意的是 `Config initialized` 出现的位置：它在 `before first access` **之后**。object 在**第一次被访问时**才初始化，而且只初始化一次；多个线程同时首次访问时，也只有一个线程执行初始化，其他线程等待它完成。另外，读取 `Config.MAX_USERS` 没有触发初始化，因为 `const val` 在编译时就已经确定，不需要对象存在。

object 不是构造器，不能用括号调用：

```scoop
{{#include ../../examples/ch13/object_ctor_fail.scoop}}
```

```text
{{#include ../../examples/ch13/object_ctor_fail.error}}
```

object 不能有构造器和类型参数，但可以继承一个类、实现接口（第 14 章）。

> **深入一点：顶层属性什么时候初始化**
>
> object 是“首次访问时初始化”。顶层的普通 `val` / `var` 则不同：需要在运行时计算的顶层属性，会在程序启动后、进入 `main` 之前统一初始化一次。不同文件之间的顶层属性没有规定的初始化顺序，所以不要让一个文件的顶层属性依赖另一个文件的顶层属性的副作用。如果初始化代码之间直接形成了循环依赖，编译器会报错。

## 13.8　companion object

class、struct、enum 和接口里可以声明一个 **companion object**，它是依附在这个类型上的 object。Kotlin 开发者对它很熟悉：它承担了 Java 里 `static` 成员的角色。

```scoop
{{#include ../../examples/ch13/companion.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/companion.expected}}
```

- companion 的成员通过**类型名**访问：`User.create("Ada")`、`User.created`。
- companion 可以有名字。不写名字时它叫 `Companion`，所以 `User.Companion.created` 也能访问；`Temperature` 的 companion 叫 `Factory`，`Temperature.Factory.fromFahrenheit(...)` 和 `Temperature.fromFahrenheit(...)` 是一回事。
- companion 里可以放 `const val`、可变状态和工厂函数。它可以调用宿主类型的私有构造器，这正是 13.5 的工厂函数能工作的原因。
- 和普通 object 一样，companion 在第一次被访问时初始化；只构造 `User` 的实例不会触发它的初始化。

companion 的成员**不是**实例的成员，不能通过实例访问：

```scoop
{{#include ../../examples/ch13/companion_instance_fail.scoop}}
```

```text
{{#include ../../examples/ch13/companion_instance_fail.error}}
```

companion 也不会被子类继承。

> **深入一点：泛型类的 companion**
>
> 对泛型类 `Box<T>` 来说，每一种完整的类型都有自己的 companion：`Box<Int>.Companion` 和 `Box<String>.Companion` 是两个不同的对象，各自有自己的状态。因此访问泛型类的 companion 时要写全类型实参，例如 `Box<Int>.create(1)`，不能写成 `Box.create(1)`。第 17 章会再讨论这一点。

## 13.9　嵌套类与 `inner class`

class 里面可以再声明 class。和 Kotlin 一样，有两种：

```scoop
{{#include ../../examples/ch13/playlist.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/playlist.expected}}
```

- **嵌套类**（`class Stats`）只是把名字放在外层类的命名空间里，写作 `Playlist.Stats`。它和外层类的实例没有任何关系，可以独立构造：`Playlist.Stats(7L)`。
- **inner class**（`inner class Cursor`）的每个实例都关联着一个外层实例，可以直接访问外层的属性和方法，包括私有的 `songs`。

嵌套类看不到外层实例的成员：

```scoop
{{#include ../../examples/ch13/nested_outer_fail.scoop}}
```

```text
{{#include ../../examples/ch13/nested_outer_fail.error}}
```

inner class 则必须通过一个外层实例来构造。在外层类的方法里可以直接写 `Cursor()`，外层实例就是当前的 `this`；在类外要写 `list.Cursor()`。只写类型名是不行的：

```scoop
{{#include ../../examples/ch13/inner_outer_fail.scoop}}
```

```text
{{#include ../../examples/ch13/inner_outer_fail.error}}
```

inner class 和外层类有同名成员时，`this.name` 指 inner 自己的，`this@Outer.name` 指外层的：

```scoop
{{#include ../../examples/ch13/inner_this.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/inner_this.expected}}
```

`inner` 只能修饰直接写在 class 里面的 class，不能用在 struct、enum、接口或 object 里。

## 13.10　匿名 object 与局部类

有时只需要一个“一次性”的对象，不值得为它单独起个类名。`object { ... }` 表达式每次求值都创建一个新的匿名对象：

```scoop
{{#include ../../examples/ch13/anonymous.scoop}}
```

输出：

```text
{{#include ../../examples/ch13/anonymous.expected}}
```

- `object : Greeter { ... }` 创建一个实现了 `Greeter` 接口的匿名对象，它可以有自己的状态（`count`）。函数 `politeGreeter` 的返回类型要写成 `Greeter`：匿名类型不能出现在非局部函数的签名里。
- 不实现任何接口的 `object { ... }` 也可以用，保存在局部变量里时可以访问它自己的成员（`point.x`）。
- 函数体里还可以声明**局部类**（`class Length`），它只在声明之后、所在的代码块内可用。

匿名 object 和局部类可以使用外层作用域里的 `val`（例子里的 `prefix` 和 `unit`），但和 lambda 一样，**不能捕获外层的 `var`**（第 7 章）：

```scoop
{{#include ../../examples/ch13/anonymous_var_fail.scoop}}
```

```text
{{#include ../../examples/ch13/anonymous_var_fail.error}}
```

需要共享可变状态时，把状态放进对象自己的属性里，就像 `Greeter` 的 `count` 那样。

> **从 Kotlin 过来**
>
> Kotlin 里常用匿名 object 实现只有一个方法的接口；如果是 Java 接口，还可以用 SAM 转换直接传 lambda。Scoop 没有 SAM 转换。对只有一个方法的“回调”，更自然的做法是直接使用函数类型（第 7 章），比如参数写成 `(String) -> String`；需要多个方法或自身状态时，再用接口加匿名 object。

## 13.11　class 还是 struct

第 8 章 8.9 节从 struct 的角度给出了一张对照表，判断方法是：**两个实例如果所有字段都相等，它们是不是“同一个东西”？** 从 class 的角度，可以再补充几个具体的信号。出现下面任何一种情况，就应该用 class：

| 信号 | 例子 | 为什么 struct 不行 |
| --- | --- | --- |
| 状态会随时间变化，并且需要被多处共享 | 账户余额、会话的登录状态 | struct 不能修改，每次“修改”得到的是新值，别人手里的旧值不会跟着变 |
| 必须始终成立的约束 | `Percent` 在 0 到 100 之间 | struct 的主构造器总是公开的，绕不过去 |
| 需要隐藏内部表示 | `Playlist` 的 `songs` 是私有的 | struct 的字段总是公开的 |
| 需要继承 | 一组有共同基类的组件 | struct 不能继承，只能实现接口 |
| 代表外部资源或有生命周期的东西 | 打开的文件、网络连接 | 复制一份“连接”没有意义，需要身份（第 21 章） |
| 需要 `lateinit` 式的“稍后再设置” | 登录后才有的用户 | struct 构造时就必须给出全部字段 |

反过来，如果一个类型只是“一组数据”，没有上表中的任何需求，优先考虑 struct：它不分配堆对象，不需要实现 `Equals` 就能 `==`，也不会被别人意外修改。

两者也常常配合使用：class 持有状态，状态的每个“快照”用 struct 表示。第 8 章的 `Player` 就是这样，`Player` 是 class，它的 `position` 属性是一个 `Point` struct。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `class A(val x: Int)` | 相同 |
| `lateinit var x: T` | 不支持；用 `var x: T?`（省略初始值即 `None`） |
| `val x: Int` 在 `init` 或构造器里赋值 | 不支持；属性必须在声明处初始化 |
| `var x = 0; private set` | `private set(value) { field = value }` |
| `constructor(a: Int) : this(a, a)` | 必须有函数体：`constructor(a: Int): this(a, a) {}` |
| 两个实例 `a == b` 默认比较身份 | 没有默认的 `==`；身份用 `===`，内容相等实现 `Equals<T>` |
| 默认 `toString()` 输出 `A@1b6d3586` | 没有默认 `toString`；需要时实现 `ToString` |
| `A(1)` 单独作为语句 | 不合法；构造结果要保存，例如 `val a = A(1)` |
| `const val` 在顶层、object、companion | 相同；类型可以省略 |
| `object O`，首次访问时初始化 | 相同；线程安全，失败后不重试 |
| `companion object`，`A.Companion` | 相同；不能通过实例访问，不被继承 |
| 泛型类的 companion 只有一个 | 每个完整类型实参各有一个：`Box<Int>.Companion` |
| 嵌套类、`inner class`、`this@Outer` | 相同 |
| `object : I { ... }` 匿名对象 | 相同；不能捕获外层 `var` |
| SAM 转换 | 不支持；用函数类型或匿名 object |

## 常见误用

- **照搬 `lateinit`**：改成 `var x: T?`，或者在声明处调用一个函数算出初始值。
- **只声明属性、在构造器里赋值**：Scoop 要求在声明处初始化，把属性放进主构造器通常是最简单的改法。
- **只写 `private set`**：要写成 `private set(value) { field = value }`。
- **次构造器省略 `{}`**：次构造器必须有函数体。
- **用 `==` 比较两个 class 实例**：class 没有默认的相等比较，按需要选择 `===` 或实现 `Equals<T>`。
- **想用 struct 承载必须成立的约束**：改用 class 加私有构造器和工厂函数（13.5）。
- **通过实例调用 companion 的函数**：companion 成员用类型名访问。
- **在嵌套类里访问外层实例的属性**：需要访问外层实例时用 `inner class`，或者把外层对象作为参数传进去。

## 小结

- class 是引用类型：赋值和传参共享同一个对象，有身份，可以有可变状态。
- 主构造器中带 `val` / `var` 的参数是属性，不带的只在初始化时可见；属性可以有自定义 getter、setter 和私有 setter。
- 存储属性必须在声明处初始化；没有 `lateinit`，“稍后才有”的值用可变 `Option` 属性表示。
- 构造顺序：实参、基类、主构造器属性、body 中的属性初始值与 `init`（按源码顺序）、次构造器函数体。直接读取尚未初始化的属性是编译错误。
- 私有构造器加工厂函数，可以保证每个实例都满足约束，这是 class 相对 struct 的重要能力。
- `const val` 是编译期常量，只能在顶层、object 和 companion 中声明。
- `object` 是首次访问时初始化的单例；companion object 承担“静态成员”的角色，通过类型名访问。
- 嵌套类和外层实例无关；`inner class` 关联一个外层实例。匿名 object 和局部类不能捕获外层 `var`。

## 练习

1. 写一个 class `Counter`，有一个只能在类内修改的 `count` 属性和 `increment()` 方法。验证类外给 `count` 赋值会报错。
2. 把第 8 章练习中的 `Money` 改写成 class：构造器私有，companion 提供 `of(cents: Long, currency: String): Money?`，币种不是三个大写字母时返回 `None`。
3. 写一个 `object IdGenerator`，提供 `next(): Long`，每次调用返回递增的编号。在 object 的初始化代码里打印一行文字，观察它在什么时候出现。
4. 给 13.9 的 `Playlist` 增加一个 `inner class` `Shuffler`，按相反的顺序返回歌曲。思考：为什么它适合写成 inner class，而 `Stats` 不需要？
5. 用匿名 object 写一个函数 `makeLogger(prefix: String)`，返回一个带 `log(message: String)` 方法和已记录条数的对象（先声明一个接口）。
