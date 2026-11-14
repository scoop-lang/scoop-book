# 第 17 章　泛型

泛型让你写一次代码，用于多种类型：一个 `Box<T>` 既能装 `Int` 也能装 `String`，一个 `largest` 函数既能比较数字也能比较字符串。Kotlin 开发者对这些再熟悉不过，Scoop 的基本写法也和 Kotlin 一样：尖括号里声明类型参数，用 `T : Bound` 写上界，用 `where` 写多个约束。

不同之处在于泛型的**实现方式**和**子类型规则**。Kotlin/JVM 的泛型在运行时会被擦除，`List<String>` 和 `List<Int>` 到了运行时都是同一个 `List`；Scoop 的泛型则在编译时为每一组实际类型生成一份专用代码，运行时完全知道真实类型。另一方面，Kotlin 用 `in`/`out` 让 `List<User>` 可以当作 `List<Named>` 使用，Scoop 则规定泛型类型一律**不变**，没有 `in`、`out` 和 `*`。

本章介绍：

- 泛型函数、泛型类型和泛型方法的写法；
- 用上界和 `where` 给类型参数加上能力；
- 类型位置必须写全类型实参，调用处可以用 `_` 只写一部分；
- 泛型为什么不变，以及代替 `in`/`out`/`*` 的写法；
- 接口方法不能有自己的类型参数；
- 运行时知道真实类型：不需要 `reified`；
- `typealias`；
- 条件接口实现：只在类型参数满足条件时才成立的能力。

## 17.1　泛型函数与泛型类型

```scoop
{{#include ../../examples/ch17/basics.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/basics.expected}}
```

写法和 Kotlin 相同：

- **泛型类型**在名字后面声明类型参数：`struct Box<T>`、`class Stack<T>`。class、struct、enum 和 interface 都可以是泛型的。
- **泛型函数**把类型参数写在 `fun` 和函数名之间：`fun <A, B> swap(pair: (A, B)): (B, A)`。
- **泛型方法**是在类型内部再声明自己的类型参数，比如 `Box<T>` 的 `fun <R> map(transform: (T) -> R): Box<R>`。它同时用到了宿主的 `T` 和方法自己的 `R`。

使用时，类型实参通常可以省略，由编译器从参数推断：`Box("Scoop")` 推断为 `Box<String>`，`swap((1, "one"))` 推断出 `A = Int`、`B = String`。也可以显式写出来，比如 `Box<Int>(42)`、`Stack<String>()`。像 `Stack<String>()` 这种没有参数可供推断的情况，就必须显式写。

`Box<Int>` 和 `Box<String>` 是**两个不同的类型**。这听起来理所当然，但它是本章后面几条规则的基础：Scoop 不会因为 `Int` 和 `String` 都是 `Any` 的子类型，就认为 `Box<Int>` 和 `Box<String>` 有什么关系。

## 17.2　上界：让类型参数具备能力

一个没有任何约束的类型参数 `T`，编译器对它一无所知，所以几乎什么都不能对它做。连打印都不行，因为 `println` 要求参数实现 `ToString`：

```scoop
{{#include ../../examples/ch17/member_fail.scoop}}
```

```text
{{#include ../../examples/ch17/member_fail.error}}
```

要使用某种能力，就用**上界**（upper bound）声明它：

```scoop
{{#include ../../examples/ch17/bounds.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/bounds.expected}}
```

- `fun <T : Named> greeting(value: T)` 要求 `T` 实现 `Named` 接口，函数体里因此可以调用 `value.displayName()`。struct `User` 和 class `Project` 都满足。
- `fun <T : Compare<T>> largest(values: Array<T>)` 要求 `T` 能和自己比较大小。`Compare<T>` 是 core 里的比较接口，实现了它的类型就能用 `<`、`>`。`Int`、`String` 等都实现了 `Compare`。上界里引用 `T` 自身是合法的，`T : Compare<T>` 的意思是“`T` 能和另一个 `T` 比较”。
- 需要多个约束时，用 `where` 子句列出：`where T : Named, T : ToString`。也可以把一个约束写在尖括号里，其余写在 `where` 里。

调用时，实际类型必须满足全部上界，否则报错：

```scoop
{{#include ../../examples/ch17/bound_fail.scoop}}
```

```text
{{#include ../../examples/ch17/bound_fail.error}}
```

关于上界，还要知道几点：

- 上界只能是 class 或 interface，并且必须写全类型实参，比如 `Compare<T>`，而不是 `Compare`。一个类型参数最多有一个 class 上界，但可以有多个 interface 上界。
- **能力只来自声明**。`T : Equals<T>` 要求实际类型显式声明了 `Equals<T>`，仅仅“有一个叫 `equals` 的方法”或“能用 `==` 比较”都不算。这和第 8 章 8.7 节讲的 struct 规则是同一回事。
- 类型参数没有隐含的 `Any` 能力。`Any` 本身没有任何成员，所以无界的 `T` 上没有 `toString`、`equals`、`hashCode` 可调用。
- 此外还有 `T : value` 和 `T : ref` 两种约束，分别要求实际类型是值类型或引用类型。它们主要用于和 C 互操作、控制内存的代码（第 36、37 章），日常很少用到。

> **从 Kotlin 过来**
>
> Kotlin 里 `fun <T> show(value: T) = println(value)` 可以直接编译，因为每个对象都有 `toString()`。Scoop 中 `Any` 没有成员，泛型函数要打印、比较或哈希 `T`，必须分别声明 `T : ToString`、`T : Equals<T>`、`T : Hash`。泛型代码里见到 “must satisfy upper bound” 的报错，多半就是漏了这类约束。

## 17.3　类型实参要写全；调用处可以用 `_`

在**类型位置**（变量、参数、返回值、字段的类型标注），泛型类型必须写全类型实参，不能只写一个裸名字：

```scoop
{{#include ../../examples/ch17/bare_fail.scoop}}
```

```text
{{#include ../../examples/ch17/bare_fail.error}}
```

要么写全 `Box<Int>`，要么省略整个类型标注，让编译器推断。

在**调用处**，规则宽松一些：类型实参可以整组省略，也可以显式写出；如果只想指定其中一部分，没写的位置用 `_` 表示“这个让编译器推断”：

```scoop
{{#include ../../examples/ch17/explicit.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/explicit.expected}}
```

- `Entry("port", 8080)` 全部推断，得到 `Entry<String, Int>`。
- `Entry<String, Long>("timeout", 30)` 全部显式写出，所以字面量 `30` 被当作 `Long`。
- `Entry<_, String?>("user", None)` 只指定第二个参数。`None` 本身看不出是哪种 `Option`，必须有人告诉编译器；第一个参数从 `"user"` 推断就够了，所以写 `_`。
- 泛型函数同样可以显式写类型实参，比如 `repeatValue<Long>(0, 3)`。

如果去掉 `<_, String?>`，编译器无法确定 `None` 的类型：

```scoop
{{#include ../../examples/ch17/none_fail.scoop}}
```

```text
{{#include ../../examples/ch17/none_fail.error}}
```

`_` 只能出现在调用和构造的类型实参列表里，它不是一个类型，不能用在类型标注中：

```scoop
{{#include ../../examples/ch17/underscore_fail.scoop}}
```

```text
{{#include ../../examples/ch17/underscore_fail.error}}
```

## 17.4　泛型是不变的

假设 `User` 实现了 `Named` 接口。一个 `User` 可以当作 `Named` 使用，那一个 `Box<User>` 能不能当作 `Box<Named>` 使用？在 Scoop 里，**不能**：

```scoop
{{#include ../../examples/ch17/invariant_fail.scoop}}
```

```text
{{#include ../../examples/ch17/invariant_fail.error}}
```

这条规则叫**不变**（invariance）：同一个泛型类型的两个实例，只有在类型实参完全相同时才能互相赋值，`Box<User>` 和 `Box<Named>` 之间没有任何子类型关系。它适用于所有泛型类型，包括数组：

```scoop
{{#include ../../examples/ch17/array_invariant_fail.scoop}}
```

```text
{{#include ../../examples/ch17/array_invariant_fail.error}}
```

为什么要这样规定？一个原因是**安全**：如果 `MutableArray<User>` 可以当作 `MutableArray<Named>`，就可以往里面放一个不是 `User` 的 `Named`，原来的 `MutableArray<User>` 就被破坏了。另一个原因来自值类型：`Array<User>` 中的 `User` 是不装箱、连续存放的（第 8 章），而 `Array<Named>` 中每个元素都是一个接口引用，两者在内存里的样子完全不同，不可能把一个“直接当作”另一个。

需要在两者之间转换时，有三种常用写法：

```scoop
{{#include ../../examples/ch17/invariance.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/invariance.expected}}
```

1. **让函数本身成为泛型的**。与其要求参数是 `Array<Named>`，不如写 `fun <T : Named> printAll(values: Array<T>)`：它接受任何元素类型满足 `Named` 的数组，`Array<User>` 直接就能传进去。这是最推荐的写法，因为不需要任何转换，而且单态化后 `T` 就是 `User`，没有装箱。
2. **直接构造目标类型**。`val boxed: Box<Named> = Box(linus)` 从一开始就构造 `Box<Named>`：编译器根据期望类型把 `linus` 当作 `Named` 放进去。
3. **逐个转换元素**。已经有一个 `Array<User>` 时，用 `map` 把每个元素显式转换成 `Named`，得到一个新的集合。`map` 来自 `scoop.collections`（第 7 章 7.9 节）。

数组字面量也遵守同样的规则：元素不会自动装箱成接口类型。想要一个 `Array<Named>` 字面量，需要对每个元素写 `as Named`：

```scoop
{{#include ../../examples/ch17/array_box_fail.scoop}}
```

```text
{{#include ../../examples/ch17/array_box_fail.error}}
```

函数类型不受这条规则约束：期望 `(Child) -> Parent` 的地方可以传入 `(Parent) -> Child`，见第 7 章 7.5 节。不变性说的是 `Box<T>`、`Array<T>` 这样的**名义泛型类型**。

## 17.5　没有 `in`、`out` 和 `*`

Kotlin 用声明处型变（`class Box<out T>`）和使用处投影（`Box<out Named>`、`Box<*>`）来放宽不变性。Scoop 不支持这些语法，编译器会直接拒绝：

```scoop
{{#include ../../examples/ch17/out_fail.scoop}}
```

```text
{{#include ../../examples/ch17/out_fail.error}}
```

```scoop
{{#include ../../examples/ch17/star_fail.scoop}}
```

```text
{{#include ../../examples/ch17/star_fail.error}}
```

第二条报错已经给出了替代方案：

- **带上界的泛型函数**：代替 `Box<out Named>`，写 `fun <T : Named> f(box: Box<T>)`，也就是 17.4 节的第一种写法。
- **显式的接口**：代替 `Box<*>`。`Box<*>` 的用途通常是“我不关心里面是什么类型，只想调用某几个操作”。那就把这几个操作定义成一个**非泛型接口**，让 `Box<T>` 实现它，然后保存和传递这个接口类型。

第二种写法在下一节的例子里会用到。

## 17.6　接口方法不能有自己的类型参数

class 和 struct 的方法可以有自己的类型参数（如 17.1 节的 `map`），接口的方法却不可以：

```scoop
{{#include ../../examples/ch17/iface_method_fail.scoop}}
```

```text
{{#include ../../examples/ch17/iface_method_fail.error}}
```

原因在于单态化：泛型方法要为每一组类型实参生成一份代码，而接口方法是通过虚表在运行时分派的。“运行时根据实际对象选一个实现，再根据调用处的类型实参生成一份代码”，这两件事没办法同时做到。同样的道理，class 里的泛型方法必须是 final 的，不能是 `open`、`abstract` 或 `override`：

```scoop
{{#include ../../examples/ch17/open_generic_fail.scoop}}
```

```text
{{#include ../../examples/ch17/open_generic_fail.error}}
```

替代写法是**把类型参数移到接口本身**：

```scoop
{{#include ../../examples/ch17/iface.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/iface.expected}}
```

- `interface Parser<T>` 是泛型接口，`IntParser` 实现 `Parser<Int>`，`YesNoParser` 实现 `Parser<Boolean>`。接口方法 `parse` 用的是接口的 `T`，自己没有类型参数，所以是合法的。
- 泛型函数 `parseAll` 接受任意 `Parser<T>`，它自己可以有类型参数，因为普通函数不经过虚表分派。
- 后半部分演示了 17.5 节说的“用非泛型接口代替 `Box<*>`”：`Box<Int>` 和 `Box<String>` 是不同的类型，但它们都实现了 `Describable`，所以可以放进同一个 `Array<Describable>` 里。数组字面量里要写 `as Describable`（17.4 节）。

`Parser<Int>` 和 `Parser<Boolean>` 是两个不同的接口。一个类型可以同时实现二者，但要分别满足它们的全部方法。

## 17.7　运行时知道真实类型

```scoop
{{#include ../../examples/ch17/reified.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/reified.expected}}
```

在 Kotlin/JVM 上，这段程序的大部分都写不出来：`boxed is Box<Int>` 会因为类型擦除报错，`value is T` 要求函数是 `inline` 的并且 `T` 标为 `reified`。Scoop 没有这些限制：

- `is Box<Int>` 和 `is Box<String>` 是两个不同的检查，结果分别是 `true` 和 `false`。
- 泛型函数里可以直接写 `value is T`，检查之后照常有 smart cast（`Some(value)` 中的 `value` 已经是 `T`）。
- 调用 `isInstance<String>(...)` 时显式给出 `T`，因为参数类型是 `Any`，没有可供推断的线索。

这背后的机制就是**单态化**。

> **深入一点：单态化**
>
> “单态化”（monomorphization）的意思是：编译器为泛型代码的每一种实际用法生成一份专门的代码。程序里用到了 `Box<Int>` 和 `Box<String>`，编译器就生成两份 `Box`，一份的 `value` 是 `Int`，另一份是 `String`；调用了 `largest<Int>` 和 `largest<String>`，就生成两个 `largest` 函数。最终的程序里没有“泛型”，只有一组普通的具体代码。
>
> 好处是：
>
> - 运行时知道每个类型参数的真实类型，所以 `is T`、`is Box<Int>` 都能工作，不需要 `reified`；
> - 值类型作为类型实参时不需要装箱，`Box<Int>` 里存的就是一个 `Int`，`Array<Point>` 里的元素连续存放；
> - 调用 `T` 上的方法时，编译器知道具体类型，可以直接调用甚至内联，没有额外的间接层。
>
> 代价是**体积和编译时间**：每多一种用法就多一份代码。泛型用得越多、类型实参的组合越多，可执行文件越大，编译越慢。这和 C++ 模板、Rust 泛型是同一种取舍。
>
### 泛型代码在定义处选定调用

和 C++ 模板不同，Scoop 的泛型代码在**定义处**就完成了类型检查和重载选择，单态化只是把选好的代码代入具体类型，不会重新挑选：

```scoop
{{#include ../../examples/ch17/overload.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/overload.expected}}
```

直接调用 `show(42)` 时，两个 `show` 都适用，编译器选择约束更具体的那个（`T : ToString`），所以打印 `42`；`show(Secret(7))` 只有无约束的版本适用。`showLater(42)` 却打印 `<hidden>`：`showLater` 的 `T` 没有 `ToString` 约束，定义它时编译器只能选择无约束的 `show`，之后用 `Int` 实例化也不会改选。这保证了泛型函数的行为只由它的签名和约束决定，不会因为调用方传入了什么类型而“悄悄变成另一个函数”。

## 17.8　`typealias`

`typealias` 给一个类型起别名：

```scoop
{{#include ../../examples/ch17/aliases.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/aliases.expected}}
```

- 别名可以指向任何类型：基本类型（`UserId = Long`）、具体的泛型类型（`Names = Array<String>`）、函数类型（`Check<T> = (T) -> Boolean`）。
- 别名本身也可以带类型参数：`Table<V>` 展开为 `HashMap<String, V>`。使用时同样要写全，`Table<Int>`。
- 别名可以写在顶层，也可以写在类型体或函数体内。顶层别名和其他声明一样，默认是 `internal` 的（第 15 章）。

别名是**透明**的：它只是另一个名字，不是新的类型。`UserId` 和 `Long` 完全是同一个类型，所以 `val plain: Long = id` 可以直接赋值，`lookup(plain)` 也能接受一个普通的 `Long`。因此，不能用别名来区分重载：

```scoop
{{#include ../../examples/ch17/alias_dup_fail.scoop}}
```

```text
{{#include ../../examples/ch17/alias_dup_fail.error}}
```

如果你想要的是“一个和 `Long` 不能混用的 `UserId`”，应该用第 8 章 8.9 节介绍的单字段 struct：`struct UserId(val value: Long)`。它是一个新类型，编译器会阻止你把普通 `Long` 传给需要 `UserId` 的参数，运行时开销和一个 `Long` 相同。

| | `typealias UserId = Long` | `struct UserId(val value: Long)` |
| --- | --- | --- |
| 是不是新类型 | 不是，和 `Long` 完全相同 | 是 |
| 能否和 `Long` 互相赋值 | 能 | 不能，要构造或取 `.value` |
| 能否区分重载 | 不能 | 能 |
| 用途 | 缩短长类型名，给类型起个说明用途的名字 | 让编译器检查单位或含义 |

## 17.9　条件接口实现

`Box<T>` 能不能打印？这取决于 `T`：`Box<Int>` 里的 `Int` 可以打印，`Box` 理应也可以；`Box<Secret>` 里的 `Secret` 没有实现 `ToString`，`Box` 也就无从打印。

如果在 `Box` 的声明头写 `: ToString`，就要求所有 `Box<T>` 都能打印，这对 `Box<Secret>` 做不到。如果给 `T` 加上界 `struct Box<T : ToString>`，又会让 `Box<Secret>` 连构造都不行。Scoop 的解决办法是**条件接口实现**：一种“只在特定条件下才成立的能力”。

```scoop
{{#include ../../examples/ch17/conditional.scoop}}
```

输出：

```text
{{#include ../../examples/ch17/conditional.expected}}
```

`override interface ToString where T : ToString { ... }` 读作：“当 `T` 实现了 `ToString` 时，`Box<T>` 也实现 `ToString`，实现方式如下。”于是：

- `Box<Int>`、`Box<String>` 满足条件，可以直接 `println`；
- `Box<Box<Double>>` 也可以：内层的 `Box<Double>` 满足条件，所以它实现了 `ToString`，外层也就满足条件；
- `Box<Secret>` 照样可以构造和使用，只是没有 `ToString` 这项能力。试图打印它，会得到和打印普通 struct 一样的报错：

```scoop
{{#include ../../examples/ch17/conditional_fail.scoop}}
```

```text
{{#include ../../examples/ch17/conditional_fail.error}}
```

写条件实现时注意：

- 实现块写在类型的花括号体里，语法是 `override interface 接口 where 条件 { 成员 }`。每块对应一个接口，`where` 不能省略；没有条件的实现照常写在类型名后面的接口列表里。
- 块里只能放兑现这个接口的 `override` 成员，不能放字段、构造器或其他辅助方法。和普通接口实现一样，成员要写 `public override`。
- 条件只影响这一项能力，不影响类型本身：`Box<Secret>` 仍然是合法的类型。
- 同样的写法也适用于 `Equals<Box<T>>` 和 `Hash`：只在 `T` 可以比较、哈希时，让 `Box<T>` 能作为 `HashMap` 的 key。

> **从 Kotlin 过来**
>
> Kotlin 没有对应的功能。最接近的是 Rust 的 `impl<T: Display> Display for Box<T>`，或 Swift 的 `extension Box: CustomStringConvertible where T: CustomStringConvertible`。如果你在 Kotlin 里习惯用扩展函数给 `Box<String>` 单独加方法，那在 Scoop 里，凡是涉及接口（能否打印、能否作为 key、能否比较）的需求，都应该用条件接口实现来表达。

除了本章介绍的上界和条件实现，泛型函数还可以使用负向约束（`T : !I`，要求 `T` 没有实现某个接口）等更细的条件，它们主要用于编写通用库，日常应用开发很少需要。

## 从 Kotlin 过来：泛型对照表

| Kotlin | Scoop |
| --- | --- |
| `class Box<T>(val value: T)` | 相同；也可以写成 `struct Box<T>` |
| `fun <T : Comparable<T>> max(...)` | `fun <T : Compare<T>> largest(...)` |
| `where T : A, T : B` | 相同 |
| `fun <T> show(x: T) = println(x)` | 要写 `T : ToString` |
| 类型擦除，`is List<String>` 报错 | 不擦除，`is Box<Int>` 正常工作 |
| `inline fun <reified T>` | 不需要 `reified`，直接 `value is T` |
| `class Box<out T>`、`List<User>` 可当 `List<Named>` | 一律不变，没有 `in`/`out` |
| `Box<*>` | 用一个非泛型接口代替 |
| `Box<out Named>` 作参数 | `fun <T : Named> f(box: Box<T>)` |
| 接口方法 `fun <T> convert(): T` | 不允许；把类型参数移到接口上 |
| `open fun <T> f()` | 不允许；泛型方法必须是 final |
| `typealias` | 相同，透明别名 |
| 无对应 | 条件接口实现 `override interface I where T : I` |

## 常见误用

- **在泛型函数里打印或比较 `T`，却没有加约束**：`Any` 没有成员，要写 `T : ToString`、`T : Equals<T>` 等（17.2）。
- **类型标注里只写 `Box`**：类型位置必须写全 `Box<Int>`；`_` 只能用在调用处（17.3）。
- **把 `Array<User>` 传给 `Array<Named>` 参数**：泛型不变。把函数改成 `fun <T : Named> f(values: Array<T>)`，或者显式转换元素（17.4）。
- **照搬 Kotlin 的 `out T`、`Box<*>`**：不支持，改用带上界的泛型函数或非泛型接口（17.5）。
- **给接口方法声明类型参数**：把类型参数移到接口上，`interface Parser<T>`（17.6）。
- **用 `typealias` 区分含义相同、用途不同的值**：别名是透明的，改用单字段 struct（17.8）。
- **为了让 `Box<T>` 能打印，给 `T` 加上界**：这会让其他 `Box` 无法构造，用条件接口实现（17.9）。

## 小结

- 泛型的基本写法和 Kotlin 相同：类型参数、上界、`where`，类型实参通常可以推断。
- 无界的 `T` 什么能力都没有；需要打印、比较、哈希时，显式声明对应的上界。
- 类型位置必须写全类型实参；调用处可以整组省略，或用 `_` 只指定一部分。
- 泛型一律不变，没有 `in`/`out`/`*`。用带上界的泛型函数、直接构造目标类型、逐个转换元素，或非泛型接口来代替。
- 接口方法和 class 的可覆写方法不能有自己的类型参数；把类型参数放到接口上。
- 泛型通过单态化实现：运行时知道真实类型，`is T` 直接可用，值类型不装箱；代价是代码体积和编译时间。
- `typealias` 是透明别名，不是新类型。
- 条件接口实现让 `Box<T>` 只在 `T` 满足条件时具备某项能力。

## 练习

1. 写一个泛型函数 `fun <T : Compare<T>> clamp(value: T, low: T, high: T): T`，分别用 `Int` 和 `String` 调用它。
2. 定义 `struct Pair<A, B>(val first: A, val second: B)`，用条件接口实现让它在 `A` 和 `B` 都实现 `ToString` 时可以打印，输出形如 `(1, one)`。
3. 给第 2 题的 `Pair` 再加上条件的 `Equals<Pair<A, B>>` 和 `Hash` 实现，然后把 `Pair<String, Int>` 用作 `HashMap` 的 key。
4. 有一个函数 `fun total(shapes: Array<Shape>): Double`，其中 `Shape` 是接口。现在手上有一个 `Array<Circle>`。给出两种让它能调用 `total` 的改法，并比较它们的优缺点。
5. 设计一个 `interface Storage<T>`，包含 `save(value: T)` 和 `load(): T?` 两个方法，分别用 `Int` 和 `String` 实现它。思考：为什么不能把它设计成非泛型接口加上 `fun <T> save(value: T)`？
