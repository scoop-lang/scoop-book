# 第 8 章　struct：真正的值

在 Kotlin 里，表示“一组数据”的首选是 `data class`：编译器自动生成 `equals`、`hashCode`、`toString` 和 `copy`，写起来很省事。但 `data class` 本质上仍是 class：每个实例都是堆上的对象，有自己的身份（identity），属性可以声明成 `var`，赋值和传参传递的都是引用。

Scoop 用 **struct** 取代了 `data class`。struct 是真正的**值类型**：它就是一组数据本身，没有身份，构造之后不能修改，赋值时复制的是整个值。这种模型和 `Int`、`Double` 的行为一致，只不过值由多个字段组成。

本章介绍：

- 怎样声明和构造 struct；
- “值不可修改”和“值语义”在实际编程中意味着什么；
- 用副本更新表达式 `p.{x: 1}` 得到修改了部分字段的新值；
- 为什么 struct 能用 `==` 比较，却不能直接 `println`；
- 什么时候用 struct，什么时候用 class。

## 8.1　第一个 struct

```scoop
{{#include ../../examples/ch08/point.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/point.expected}}
```

struct 的字段写在主构造器里，形式和 Kotlin 的构造器属性一样，但**只能用 `val`**。构造 struct 的唯一方式是调用构造器，所以它支持 Kotlin 函数调用的全部便利：

- 位置参数：`Point(3, 4)`；
- 命名参数：`Point(y = 4, x = 3)`，顺序可以任意；
- 默认值：`Size(5)` 省略了 `height`。默认值表达式可以引用排在前面的参数，所以 `Size(5)` 得到一个 5×5 的正方形。

字段总是公开的，不能加 `private` 之类的修饰符：struct 就是“这几个字段的组合”，没有需要隐藏的内部状态。（如果 struct 本身是 `internal` 的，它的字段自然也只在当前 Cone 内可见，见第 15 章。）

struct 自动支持 `==` 和 `!=`：两个值的所有字段依次相等，它们就相等。这里比较的是内容，`p` 和 `q` 是分别构造的，但它们相等。

## 8.2　值不可修改

struct 构造完成之后，任何字段都不能再改变。试图声明 `var` 字段会直接报错：

```scoop
{{#include ../../examples/ch08/var_field_fail.scoop}}
```

```text
{{#include ../../examples/ch08/var_field_fail.error}}
```

给字段赋值同样不行，即使变量本身是 `var`：

```scoop
{{#include ../../examples/ch08/assign_field_fail.scoop}}
```

```text
{{#include ../../examples/ch08/assign_field_fail.error}}
```

这里要分清两件事：

- **绑定可不可以重新指向别的值**：由 `val` / `var` 决定。`var p` 可以写 `p = Point(10, 2)`。
- **值本身能不能改**：struct 的值永远不能改。

所以 `var p = Point(1, 2)` 的意思是“变量 `p` 以后可以换成另一个 `Point`”，而不是“`p` 里的 `Point` 可以被修改”。`Int` 也是这样：`var n = 1; n = 2` 是换了一个值，而不是把 1 改成了 2。

## 8.3　值语义：复制，而不是共享

下面的程序对比 struct 和 class 在赋值、传参时的区别：

```scoop
{{#include ../../examples/ch08/value_semantics.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/value_semantics.expected}}
```

Scoop 的赋值和传参一律**按值传递**，区别在于“值”是什么：

- 对 struct，值就是整个数据。`val saved = a` 得到一份独立的副本，之后 `a` 换成新值，`saved` 不受影响。
- 对 class，值是**引用**。`val alias = c` 复制的是引用，两个变量指向同一个对象，通过 `c` 做的修改在 `alias` 上也能看到。

这和 Kotlin（以及 Java）对 class 的处理完全相同；新的只是 struct 这一半。

因为 struct 没有身份，“这两个 struct 是不是同一个对象”这个问题没有意义，所以 `===` 不能用于 struct：

```scoop
{{#include ../../examples/ch08/identity_fail.scoop}}
```

```text
{{#include ../../examples/ch08/identity_fail.error}}
```

比较 struct 一律用 `==`。

> **从 Kotlin 过来**
>
> Kotlin 的 `data class` 实例有身份：`a === b` 能区分“内容相同的两个对象”和“同一个对象”；把实例传进函数后，函数可以修改它的 `var` 属性，调用方也会看到修改。
>
> Scoop 的 struct 没有这两种情况：没有身份，也不能修改。如果你的代码依赖“传进去、在里面改、外面看到变化”这种用法，那个类型应该写成 class，而不是 struct。

## 8.4　复制是浅的

“复制整个值”只复制 struct 自己的字段。如果某个字段是引用类型，复制的是引用，两份副本仍然指向同一个对象：

```scoop
{{#include ../../examples/ch08/shallow_copy.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/shallow_copy.expected}}
```

`yours` 是 `mine` 的副本，它们的 `name` 各自独立，但 `songs` 字段保存的是同一个 `ArrayList` 的引用，所以往 `yours.songs` 里添加歌曲，`mine.songs` 也会变化。

也就是说，**struct 的不可变只是“一层”**：字段本身不能换成别的值，字段指向的对象却可能是可变的。想让一个 struct 从里到外都不可变，它的字段也应该是不可变的类型，比如 `Int`、`String`、其他 struct，或者只读的集合。

## 8.5　副本更新：`p.{x: 1}`

值不能修改，“修改”就变成了“基于旧值构造新值”。Scoop 为此提供了**副本更新表达式**：

```scoop
{{#include ../../examples/ch08/update.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/update.expected}}
```

`origin.{x: 5}` 的意思是：拿 `origin` 的全部字段，把 `x` 换成 `5`，构造一个新的 `Point`。`origin` 本身不变。规则很简单：

- 花括号里列出要换的字段，用逗号分隔，每个字段最多出现一次；没有列出的字段从原值复制。
- 只能用于 struct，不能用于 enum、tuple 或 class。
- 字段名写错、类型不匹配都是编译错误。
- 嵌套的 struct 要逐层更新：`line.{end: line.end.{x: 10}}`。

例子的后半部分说明了一个常用的组织方式：**可变状态放在 `var` 绑定或 class 的 `var` 属性里，struct 只负责表示某一时刻的值。** `cursor = cursor.{y: cursor.y + 1}` 用新值替换旧值；`Player` 是 class，它的 `position` 属性可以换成新的 `Point`。

### 数组里的 struct

同样的道理也适用于数组。从数组中取出的元素是一份副本，要“修改”数组里的某个 struct，就构造新值写回原位置：

```scoop
{{#include ../../examples/ch08/arrays.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/arrays.expected}}
```

> **从 Kotlin 过来**
>
> Kotlin 的 `p.copy(x = 5)` 在 Scoop 里写成 `p.{x: 5}`。struct 没有 `copy` 方法，调用它会得到 “type `Point` has no method `copy`” 的报错。

## 8.6　struct 的成员

struct 的花括号体里可以声明方法、计算属性、companion object 和次构造器：

```scoop
{{#include ../../examples/ch08/members.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/members.expected}}
```

- **方法**和 class 的方法写法相同。因为值不能修改，“改变”自己的方法通常返回一个新值，比如 `warmer` 用 `this.{...}` 构造新的温度。
- **计算属性**每次读取时执行 getter，本身不占存储。struct 体里不能声明带存储的属性：struct 的全部数据都在主构造器里。
- **companion object** 适合放常量和工厂函数，用法和 Kotlin 相同，如 `Temperature.freezing`。
- **次构造器**提供另一种构造方式，它必须通过 `this(...)` 委托给主构造器，大括号里还可以写额外的检查或副作用。

struct 不支持 `init` 块：

```scoop
{{#include ../../examples/ch08/init_fail.scoop}}
```

```text
{{#include ../../examples/ch08/init_fail.error}}
```

这背后有一条重要的设计：**struct 的主构造器永远是公开的**，不能写成 `private constructor`。struct 被看作“字段的透明组合”，任何人都可以用任意字段值构造它。因此，像“`Percent` 的值必须在 0 到 100 之间”这种**必须始终成立的约束**，struct 无法强制保证；次构造器里的检查只对走次构造器的调用生效。

需要强制约束时，用 class 封装：把构造器设为私有，只通过会做检查的工厂函数创建实例。第 13 章会介绍具体写法。

## 8.7　相等、打印与哈希：能力要显式声明

前面的例子一直在用 f-string 打印各个字段，而不是直接 `println(p)`。原因是直接打印会报错：

```scoop
{{#include ../../examples/ch08/println_fail.scoop}}
```

```text
{{#include ../../examples/ch08/println_fail.error}}
```

`println` 只接受实现了 `ToString` 接口的类型，f-string 插值也是如此。Scoop 不会为 struct 自动生成 `toString`。

相等也有类似的细节。struct 自动支持 `==`，但这只是“可以比较”，并**不等于**实现了 `Equals<T>` 接口。如果某个泛型函数要求类型参数实现 `Equals<T>`，直接传 struct 进去会被拒绝：

```scoop
{{#include ../../examples/ch08/equals_bound_fail.scoop}}
```

```text
{{#include ../../examples/ch08/equals_bound_fail.error}}
```

第一行的 `==` 没有问题，第二行调用 `same` 失败。标准库的 `HashMap`、`HashSet` 等容器正是用 `Equals<T>` 和 `Hash` 来约束 key 的，所以要把 struct 当作 key，就必须显式实现这些接口：

```scoop
{{#include ../../examples/ch08/capabilities.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/capabilities.expected}}
```

struct 名字后面的 `: ToString, Equals<Point>, Hash` 声明了它实现的接口，体里的 `override` 方法给出实现：

| 能力 | 用途 | 自动提供？ |
| --- | --- | --- |
| `==` / `!=` | 直接比较两个值 | 是，所有字段都能比较时自动可用 |
| `Equals<T>` | 泛型代码中的相等约束，例如 Map 的 key | 否，需要显式实现 |
| `ToString` | `println`、f-string 插值 | 否，需要显式实现 |
| `Hash` | 哈希容器，例如 `HashMap`、`HashSet` 的 key | 否，需要显式实现 |

实现时注意几点：

- `Equals<T>` 的 `equals` 是运算符方法，重写时要保留 `operator` 修饰符。
- `Hash` 和 `Equals` 必须一致：`a == b` 为真时，`a.hash()` 和 `b.hash()` 必须相等。编译器不会检查这一点，这是实现者的责任。上例用 `x` 和 `y` 计算哈希，与 `equals` 比较的字段一致。
- `Int`、`Long`、`String`、`Char`、`Boolean` 等常用类型已经实现了这几个接口，所以可以写 `x.hash()`。注意 `Float` 和 `Double` 没有实现 `Hash`，不能直接作为哈希 key。

Scoop 的原则是：**一个类型具备什么能力，由它的声明决定，而不是由它“长什么样”推断。** 两个字段都能比较，不代表这个 struct 就适合当 Map 的 key；它要不要能打印、怎样打印，也应该由作者决定。多写几行声明，换来的是每种能力都有明确的出处。

> **从 Kotlin 过来**
>
> `data class` 会自动生成 `equals`、`hashCode` 和 `toString`。在 Scoop 中，只有 `==` 是自动的；`ToString`、`Equals<T>`、`Hash` 都需要显式实现。从 Kotlin 移植的代码在 `println` 一个 struct 或把它放进 `HashMap` 时报错，大多是这个原因。

## 8.8　实现接口

除了 `ToString` 这类核心接口，struct 可以实现任何接口：

```scoop
{{#include ../../examples/ch08/interface.scoop}}
```

输出：

```text
{{#include ../../examples/ch08/interface.expected}}
```

struct 不能继承其他类型，但可以实现任意多个接口。实现的方法不能修改 `this` 的字段（本来也改不了），所以要求可变行为的接口（比如带 `var` 属性的接口）不能由 struct 实现。

当 struct 的值被当作接口类型（这里是 `Shape`）或 `Any` 使用时，Scoop 会自动把它**装箱**：在堆上分配一个对象来存放这个值，这样它就能和 class 实例一样通过接口调用方法。装箱后可以用 `is` 判断原来的类型，用 `as` 取回原值。装箱是自动的，你通常不需要关心；只需知道它会带来一次堆分配，第 14 章还会详细讨论。

## 8.9　什么时候用 struct

一个简单的判断方法：**这个类型的两个实例，如果所有字段都相等，它们是不是“同一个东西”？**

- 是：坐标、颜色、金额、日期、配置项、消息……用 struct。
- 不是：用户账户、网络连接、游戏中的角色、打开的文件……它们有身份，状态会随时间变化，用 class。

| | struct | class |
| --- | --- | --- |
| 身份（`===`） | 没有 | 有 |
| 修改字段 | 不能，用 `.{}` 得到新值 | `var` 属性可以修改 |
| 赋值、传参 | 复制整个值 | 复制引用，共享同一个对象 |
| 继承 | 不能继承，只能实现接口 | 单继承加接口 |
| 隐藏构造器 | 不能 | 可以 |
| 存储位置 | 内联在变量、字段、数组中 | 堆上 |

struct 还有一种很实用的用法：给普通数值“起个类型名”，让编译器帮你检查单位或含义。

```scoop
{{#include ../../examples/ch08/newtype.scoop}}
```

如果把参数顺序写反：

```scoop
{{#include ../../examples/ch08/newtype_fail.scoop}}
```

编译器会指出：

```text
{{#include ../../examples/ch08/newtype_fail.error}}
```

如果用两个 `Double` 参数，这种错误只能在运行时才被发现，甚至根本不会被发现。由于 struct 不装箱时就是它的字段本身，`Meters` 在运行时的开销和一个 `Double` 相同。

> **深入一点：值在内存里的样子**
>
> class 实例总是在堆上分配，变量里存的是指向它的引用。struct 则直接存放在使用它的地方：作为局部变量时由编译器放在栈或寄存器里，作为其他类型的字段时嵌在那个类型里面，作为数组元素时直接放在数组里。
>
> 以数组为例，`Array<Point>` 和 `MutableArray<Point>` 中的元素**不装箱、连续存放**，每个元素就是两个紧挨着的 `Int`。遍历时访问的内存是连续的，也不需要为每个元素单独分配对象，这对性能很友好。
>
> 极端情况是没有字段的 struct，比如 `struct Marker()`（空括号不能省略）。它的大小是 0，复制时不需要复制任何字节，但它仍然是一个独立的类型。这类“零大小类型”常用作类型标记。

## 从 Kotlin 过来：`data class` 对照表

| Kotlin `data class` | Scoop `struct` |
| --- | --- |
| `data class Point(val x: Int, val y: Int)` | `struct Point(val x: Int, val y: Int)` |
| 属性可以是 `var` | 字段只能是 `val` |
| `p.copy(x = 5)` | `p.{x: 5}` |
| 自动生成 `equals` | 自动支持 `==`；`Equals<T>` 需显式实现 |
| 自动生成 `hashCode` | 显式实现 `Hash` |
| 自动生成 `toString` | 显式实现 `ToString` |
| 自动生成 `componentN`，支持解构 | 内建解构，按字段顺序或字段名（第 10 章） |
| `init { require(...) }` | 不支持 `init`；需要强制约束时改用 class |
| `private constructor` 加工厂函数 | 不支持；需要隐藏构造器时改用 class |
| 可以继承 class | 只能实现接口 |
| 有身份，可以用 `===` | 没有身份，只能用 `==` |

## 常见误用

- **把 Kotlin 的 `copy` 照搬过来**：改用 `p.{x: 5}`。
- **想在 struct 里放一个计数器之类的可变状态**：struct 不能修改。把状态放在 `var` 变量或 class 里，struct 只表示某一时刻的值。
- **以为 struct 是“深度不可变”的**：引用类型的字段指向的对象仍然可能被修改（8.4）。
- **`println` 一个 struct，或把它作为 `HashMap` 的 key**：需要先实现 `ToString`，或者 `Equals<T>` 加 `Hash`（8.7）。
- **用 struct 承载必须始终成立的约束**：主构造器总是公开的，这类类型应该写成 class。
- **用 `===` 比较 struct**：值类型没有身份，用 `==`。

## 小结

- struct 是值类型：一组字段的组合，没有身份，构造后不可修改。
- 赋值和传参复制整个 struct；但复制是浅的，引用字段指向的对象仍然共享。
- 用副本更新表达式 `p.{x: 1}` 基于旧值构造新值；可变状态放在 `var` 绑定或 class 中。
- struct 可以有方法、计算属性、companion 和次构造器，但不能有 `init` 块，主构造器总是公开。
- `==` 是自动的，`ToString`、`Equals<T>`、`Hash` 需要显式声明。
- 有身份、会随时间变化的东西用 class，其余的数据优先考虑 struct。

## 练习

1. 定义 `struct Money(val cents: Long, val currency: String)`，实现 `ToString`，让 `println(Money(1999L, "USD"))` 输出 `19.99 USD`。
2. 给 `Money` 加一个方法 `plus(other: Money): Money`，币种不同时抛出 `IllegalArgumentException`。
3. 让 `Money` 可以作为 `HashMap` 的 key，并验证 `Money(100L, "USD")` 和另一个分别构造的 `Money(100L, "USD")` 能查到同一个条目。
4. 写一个 class `Wallet`，用 `var` 属性保存余额（类型为 `Money`），提供 `deposit` 方法。思考：为什么 `Wallet` 适合用 class，`Money` 适合用 struct？
