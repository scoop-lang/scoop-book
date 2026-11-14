# 第 14 章　继承与接口

继承和接口是 Kotlin 开发者再熟悉不过的东西：`open class`、`abstract class`、`interface`、`override`、`is`、`as`，Scoop 里都有，写法也基本相同。差别集中在几个“默认值”和“显式性”上：

- class 和方法默认都是 `final`，这一点和 Kotlin 一样；
- 一个类型实现了某个接口，**必须在声明里写出来**，方法同名不算数；
- 接口成员和 `override` 默认都是 `internal`，实现 `public` 接口时要写 `public override`；
- struct 和 enum 也能实现接口，这时会发生**装箱**；
- 读取属性得到的值不会被 smart cast。

本章介绍：

- 单继承：`open`、`abstract`、`final` 和 `super`；
- 接口、默认实现，以及多个默认实现冲突时怎么办；
- 显式 conformance：为什么方法同名不等于实现接口；
- sealed 继承与穷尽性；
- 值类型实现接口和装箱；
- `is`、`as`、`as?` 与 smart cast。

## 14.1　单继承：`open` 与 `override`

```scoop
{{#include ../../examples/ch14/inherit.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/inherit.expected}}
```

规则和 Kotlin 相同：

- class 默认是 `final`，只有声明为 `open`（或 `abstract`、`sealed`）的 class 才能被继承。
- 一个 class 只能继承一个父类，写在冒号后面，并调用父类的构造器：`Dog(name: String): Animal(name)`。
- 父类 `open` 了，不代表它的方法都能覆写。方法同样默认 `final`，要覆写的方法必须声明为 `open fun`。
- 覆写时必须写 `override`。`override` 的方法默认仍然是 `open` 的，子类还可以继续覆写它。
- 在子类里用 `super.sound()` 调用父类的实现。
- 通过父类类型调用 `open` 方法时，执行的是对象实际类型的实现：`describe` 是父类里的普通方法，但它调用的 `sound()` 会分派到 `Dog` 或 `Puppy` 的版本。

`scoop fmt` 会把类型和冒号写在一起，即 `class Dog(name: String): Animal(name)`，冒号前不留空格。

违反这些规则都会得到直接的报错。继承一个没有 `open` 的 class：

```scoop
{{#include ../../examples/ch14/final_class_fail.scoop}}
```

```text
{{#include ../../examples/ch14/final_class_fail.error}}
```

覆写一个没有 `open` 的方法：

```scoop
{{#include ../../examples/ch14/final_method_fail.scoop}}
```

```text
{{#include ../../examples/ch14/final_method_fail.error}}
```

漏写 `override`，Scoop 不会把它当作“恰好同名的新方法”，而是要求你明确表态：

```scoop
{{#include ../../examples/ch14/missing_override_fail.scoop}}
```

```text
{{#include ../../examples/ch14/missing_override_fail.error}}
```

反过来，写了 `override` 却没有可以覆写的方法，同样是错误：

```scoop
{{#include ../../examples/ch14/override_nothing_fail.scoop}}
```

```text
{{#include ../../examples/ch14/override_nothing_fail.error}}
```

## 14.2　抽象类与 `final override`

```scoop
{{#include ../../examples/ch14/abstract.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/abstract.expected}}
```

- `abstract class` 不能直接构造，可以包含没有函数体的 `abstract fun`。抽象方法隐含 `open`，子类必须实现它。
- 抽象类里的普通方法可以调用抽象方法，`describe` 调用 `area()` 就是这样，这是“模板方法”的常见写法。
- `final override` 覆写父类方法，同时禁止更下层的子类再覆写它。`Rect` 把 `area` 定死了，`Square` 只能覆写 `describe`。

三种常见错误：

```scoop
{{#include ../../examples/ch14/abstract_new_fail.scoop}}
```

```text
{{#include ../../examples/ch14/abstract_new_fail.error}}
```

```scoop
{{#include ../../examples/ch14/abstract_missing_fail.scoop}}
```

```text
{{#include ../../examples/ch14/abstract_missing_fail.error}}
```

```scoop
{{#include ../../examples/ch14/final_override_fail.scoop}}
```

```text
{{#include ../../examples/ch14/final_override_fail.error}}
```

## 14.3　接口与默认实现

```scoop
{{#include ../../examples/ch14/interfaces.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/interfaces.expected}}
```

接口的写法也和 Kotlin 一样：

- 接口里可以声明方法和属性。没有函数体的方法是**抽象**的，实现者必须提供；有函数体的是**默认实现**，实现者可以直接使用，也可以覆写。
- 接口里的属性（如 `val name: String`）没有存储，由实现者提供。class 可以在主构造器里用 `override val name` 实现它。
- 一个 class 可以实现任意多个接口，和父类一起写在冒号后面，用逗号分隔：`Coffee(...): Named, Priced`。
- 接口是引用类型，可以用作参数、变量和数组元素的类型，`printMenu` 接受的就是 `Array<Priced>`。

两个接口给同一个方法都提供了默认实现时，编译器不会替你挑一个：

```scoop
{{#include ../../examples/ch14/diamond_fail.scoop}}
```

```text
{{#include ../../examples/ch14/diamond_fail.error}}
```

这时要在 class 里显式覆写，并可以用 `super<接口名>.方法()` 调用指定接口的默认实现：

```scoop
{{#include ../../examples/ch14/diamond.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/diamond.expected}}
```

当前版本的 `scoop fmt` 会把 `super<Walker>` 排成 `super < Walker >`，这只是格式上的问题，两种写法含义相同，都能正常编译。

## 14.4　实现接口必须显式声明

这是本章最需要记住的一条规则：**一个类型是否实现某个接口，只看它的声明里有没有写出这个接口。** 方法名、参数、返回值都对得上也不算：

```scoop
{{#include ../../examples/ch14/duck_fail.scoop}}
```

```text
{{#include ../../examples/ch14/duck_fail.error}}
```

`Person` 确实有一个 `displayName(): String`，但它没有声明 `: Named`，所以它不是 `Named` 的子类型。修正方法是在类型头部加上 `: Named`，并把方法标成 `override`。

Kotlin 本身也是这样做的，但 Scoop 把这条原则贯彻得更彻底：`println` 要求 `ToString`，`HashMap` 的 key 要求 `Equals<T>` 和 `Hash`，这些“能力”同样只认显式声明（第 8 章 8.7）。

### `public override`

第二条规则和可见性有关。Scoop 的声明默认是 `internal`（只在当前 Cone 内可见，第 15 章），**`override` 也不例外**：省略修饰符的 `override` 是 internal 的，不会从被覆写的成员那里继承可见性。如果接口成员是 `public` 的，internal 的实现“覆盖不了”它：

```scoop
{{#include ../../examples/ch14/public_override_fail.scoop}}
```

```text
{{#include ../../examples/ch14/public_override_fail.error}}
```

所以实现 `public` 接口的成员时，要写 **`public override`**。core 里的 `ToString`、`Equals<T>`、`Hash` 都是 public 接口，第 8 章的示例因此一直写的是 `public override fun toString()`。

同样的道理，`public interface` 的成员也不会自动变成 public。public 接口里的成员必须显式写 `public`：

```scoop
{{#include ../../examples/ch14/public_member_fail.scoop}}
```

```text
{{#include ../../examples/ch14/public_member_fail.error}}
```

本章其他示例里的接口没有写 `public`，它们是 internal 接口，成员和实现也都是 internal，所以只写 `override` 就够了。规则可以归结为一句话：**实现方的可见性不能比接口成员窄。** 第 15 章会完整地讨论可见性。

> **从 Kotlin 过来**
>
> Kotlin 默认 `public`，覆写时省略修饰符会继承父成员的可见性，所以 `override fun toString()` 就够了。在 Scoop 里照搬这一行，会得到 “visibility of `toString` does not cover inherited slot `ToString.toString`”。看到 “does not cover inherited slot”，就在 `override` 前面加上 `public`。

## 14.5　sealed 继承

第 11 章已经介绍过 sealed 接口配合 `when` 的穷尽性检查。sealed 同样可以用在 class 上：

```scoop
{{#include ../../examples/ch14/sealed.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/sealed.expected}}
```

- `sealed class` 隐含 `abstract`，不能直接构造；它的构造器默认是 `protected`，只能被子类调用。
- 直接子类必须和 sealed 类型在**同一个 Cone、同一个 package** 中声明。编译器因此知道全部直接子类，`when` 列出所有直接子类就构成穷尽匹配，不需要 `else`。
- 直接子类本身可以是 `final`、`open` 或继续 `sealed`。`Voucher` 是 `open` 的，它下面还有 `GiftCard`，`is Voucher` 一个分支就覆盖了整个 `Voucher` 家族。
- sealed 只限制“谁能直接继承”，不改变其他规则：成员是否可覆写，仍然由 `open`、`abstract` 决定。

```scoop
{{#include ../../examples/ch14/sealed_new_fail.scoop}}
```

```text
{{#include ../../examples/ch14/sealed_new_fail.error}}
```

sealed class 和 sealed interface 怎么选？需要在父类型里放共同的字段或构造逻辑时用 sealed class；只需要一组类型共享一个“身份”时用 sealed interface，它还允许 struct 和 enum 作为子类型（第 11 章的 `Shape` 就是这样）。如果每个分支只是“一组数据”，没有自己的行为，带数据的 enum（第 9 章）通常是更简单的选择。

## 14.6　值类型实现接口与装箱

struct 和 enum 不能继承，也不能被继承，但可以实现接口。第 8 章 8.8 节提到过，这时会发生**装箱**。现在来看它到底什么时候发生、有什么影响：

```scoop
{{#include ../../examples/ch14/boxing.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/boxing.expected}}
```

**装箱**的意思是：在堆上分配一个对象，把值复制进去，再把这个对象的引用当作接口类型或 `Any` 使用。之所以需要它，是因为接口和 `Any` 都是引用类型，变量里存的是一个引用，而 struct 的值本身不是引用。

什么时候会装箱：

- **不会装箱**：直接在 struct 上调用方法，比如 `p.describe()`；把 struct 存进 `Array<Point>`、作为另一个 struct 的字段；在泛型函数里使用（第 17 章的单态化会为 `Point` 生成专门的代码）。
- **会装箱**：值被转换成接口类型或 `Any` 的那一刻，比如 `show(p)` 传给 `Describable` 参数、`val d: Describable = p`、`val a: Any = p`，以及从返回接口类型的函数里返回一个 struct。

装箱是自动的，但**只在单个值的转换上自动发生**。数组字面量是批量构造，编译器不会悄悄为每个元素都分配一个对象，所以要显式写 `as`：

```scoop
{{#include ../../examples/ch14/array_box_fail.scoop}}
```

```text
{{#include ../../examples/ch14/array_box_fail.error}}
```

上面 `boxing.scoop` 里写的是 `[p as Describable, Label("origin")]`：struct 元素要 `as`，class 元素 `Label` 本来就是引用，不需要。

装箱后的对象有这样几个性质：

- **它有身份**：例子里 `a === a` 为 `true`；而 `a` 和 `b` 是同一个 `p` 分别装箱得到的两个对象，`a === b` 为 `false`。不要依赖装箱对象的身份做任何判断。
- **它不可修改**：箱子里是值的一份副本，和原来的 `p` 互不影响（反正 struct 本来也改不了）。
- **能取回原来的值**：`is Point` 判断，`as Point` 取回，取回的是一个普通的 `Point` 值，可以和 `p` 用 `==` 比较。
- **`Any` 上不能用 `==`**：`Any` 没有任何成员，`val a: Any = p; a == b` 会报 “type `Any` has no applicable member operator `equals`”。

### 值类型不能借接口获得可变性

值类型通过接口也不能变得可修改。如果接口要求一个 `var` 属性，struct 就无法实现它：

```scoop
{{#include ../../examples/ch14/var_prop_fail.scoop}}
```

```text
{{#include ../../examples/ch14/var_prop_fail.error}}
```

### struct 怎样实现接口属性

接口里的 `val` 属性，class 可以在主构造器里直接用 `override val` 实现，但 struct 的主构造器参数**不能**加 `override`。字段和接口属性同名时，会得到一个看起来很矛盾的报错：

```scoop
{{#include ../../examples/ch14/struct_field_fail.scoop}}
```

```text
{{#include ../../examples/ch14/struct_field_fail.error}}
```

struct 的写法是：字段换一个名字，再用计算属性实现接口属性：

```scoop
{{#include ../../examples/ch14/struct_property.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/struct_property.expected}}
```

> **深入一点：装箱的代价**
>
> 每次装箱是一次堆分配，箱子由 GC 管理。偶尔装箱一次（比如把配置传给一个接受接口的函数）完全不用在意；但在热循环里把大量 struct 反复转成接口，就会产生许多短命对象。这种场景可以考虑：让函数直接接受具体的 struct 类型；或者用泛型函数加上界（第 17 章），单态化后不需要装箱就能调用接口方法；或者干脆用 class。
>
> 通过接口调用方法时，Scoop 用接口方法表（itable）分派，class 的 `open` 方法用虚方法表（vtable）分派，`final` 方法和 struct 方法直接调用。这些都是实现细节，写程序时不需要关心。
>
> 还要说明的是，本节讲的装箱是**语义上**的模型，经过优化后不一定真的出现在最终程序里。比如 `val d: Describable = p; d.describe()` 这样的代码，编译器在上下文中能确定 `d` 里装的一定是 `Point`，就会做**去虚化**（devirtualization）：把通过接口表的间接调用换成对 `Point.describe` 的直接调用，进而可能把它内联展开，这时装箱也就不需要了。哪些地方能这样优化由编译器决定，但它保证优化不改变程序的实际语义，你看到的结果和按本节规则推出来的完全一致。所以上面关于代价的建议针对的是编译器无法确定具体类型的场合，比如接口值来自集合、函数参数或其他 Cone。

## 14.7　`is`、`as`、`as?` 与 smart cast

```scoop
{{#include ../../examples/ch14/casts.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/casts.expected}}
```

三个运算符的含义和 Kotlin 一致：

| 运算符 | 含义 | 失败时 |
| --- | --- | --- |
| `x is T` / `x !is T` | 判断 `x` 的实际类型是不是 `T` | 返回 `false` / `true` |
| `x as T` | 把 `x` 转换成 `T` | 抛出 `ClassCastException` |
| `x as? T` | 尝试转换 | 返回 `None` |

唯一需要注意的是 `as?` 的结果类型：它是 `T?`，也就是 `Option<T>`（第 12 章），失败时是 `None` 而不是 `null`。所以后面接的是 `?.`、`?:` 或者 `when` 的 `case Some(...)`。

**smart cast** 也和 Kotlin 一样：`is` 判断成功的分支里，变量自动被当作目标类型使用，不需要再写 `as`：

- `if (a !is Dog) return ...` 之后，函数剩下的部分都把 `a` 当作 `Dog`，可以调用 `fetch()`；
- `when (value) { is String -> ... }` 的分支里，`value` 是 `String`。

### smart cast 只作用于局部变量和参数

smart cast 依赖“判断之后值没有变”。Scoop 只对**局部变量、参数**和 `when (val x = ...)` 这类绑定做 smart cast，**读取属性得到的值不会被收窄，即使属性是 `val`**：

```scoop
{{#include ../../examples/ch14/smart_cast_fail.scoop}}
```

```text
{{#include ../../examples/ch14/smart_cast_fail.error}}
```

属性的读取可能经过自定义 getter，每次的结果不一定相同，所以编译器不把它当作稳定的值。解决方法是先把属性读到一个局部 `val` 里，或者用 `when (val p = ...)`：

```scoop
{{#include ../../examples/ch14/smart_cast_fix.scoop}}
```

输出：

```text
{{#include ../../examples/ch14/smart_cast_fix.expected}}
```

局部 `var` 可以被 smart cast，但每次重新赋值都会让之前的判断失效。另外，smart cast 只用于 `is` 判断；对 `Option` 判断 `!= None` 不会收窄类型，那是第 12 章讨论的问题。

> **从 Kotlin 过来**
>
> Kotlin 允许对同一模块内、没有自定义 getter 的 `val` 属性做 smart cast，所以 `if (owner.pet is Dog) owner.pet.fetch()` 能编译。Scoop 不允许，报错是 “type `Animal` has no method `fetch`”：编译器认为 `owner.pet` 仍然是 `Animal`。照着上面的方法先存到局部 `val` 即可。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop | 说明 |
| --- | --- | --- |
| `open class`、`open fun`、`override` | 相同 | class 和方法默认 `final` |
| `abstract class`、`final override` | 相同 | |
| `override fun toString()` | `public override fun toString()` | `override` 默认 internal，不继承被覆写成员的可见性 |
| 接口成员默认 `public` | 接口成员默认 `internal`；public 接口的成员要显式写 `public` | 第 15 章 |
| `super<A>.foo()` | 相同 | 格式化器目前会排成 `super < A >` |
| `sealed class` / `sealed interface` | 相同 | 子类型须在同一 Cone、同一 package；struct、enum 可以实现 sealed interface |
| 值类型（`value class`）实现接口时装箱 | struct、enum 转为接口或 `Any` 时装箱 | 数组字面量里要显式 `as` |
| `x as? T` 返回 `T?`（可空） | 返回 `Option<T>` | 失败时是 `None` |
| `val` 属性可以 smart cast | 属性读取不 smart cast | 先存入局部 `val` |
| `class P(override val name: String) : Named` | class 相同；struct 用计算属性实现接口属性 | |

## 常见误用

- **方法同名就以为实现了接口**：必须在类型声明里写 `: 接口名`，方法标 `override`（14.4）。
- **实现 public 接口时只写 `override`**：报 “does not cover inherited slot” 时，改成 `public override`。
- **以为父类 `open` 了，方法就能覆写**：方法也要单独 `open`。
- **在数组字面量里混放 struct 和接口类型**：struct 元素要写 `as 接口名`。
- **用 `===` 判断装箱后的值**：同一个 struct 每次装箱都得到新对象，比较身份没有意义。
- **对 `owner.pet is Dog` 之后直接调用 `owner.pet.fetch()`**：属性不做 smart cast，先存到局部 `val`。
- **把 `as?` 的结果当作可空引用**：它是 `Option`，要用 `?.`、`?:` 或 `case Some(...)` 取值。

## 小结

- class 单继承，class 和方法默认 `final`；`open` 允许继承或覆写，`abstract` 要求子类实现，`final override` 终止覆写。
- 覆写必须写 `override`；没有可覆写的方法却写了 `override` 也是错误。
- 接口可以有默认实现；多个接口的默认实现冲突时要显式覆写，可用 `super<I>.f()` 选择其中一个。
- 实现接口只认显式声明；`override` 默认 internal，实现 public 接口要写 `public override`。
- sealed class 和 sealed interface 的直接子类型都在同一 Cone、同一 package 内，`when` 可以据此做穷尽检查。
- struct、enum 实现接口后，转换成接口或 `Any` 时自动装箱；数组字面量里要显式 `as`；装箱对象有身份但不可修改。
- `is`、`as`、`as?` 与 Kotlin 相同，`as?` 返回 `Option`；smart cast 只作用于局部变量、参数和 `when` 绑定，不作用于属性读取。

## 练习

1. 写一个 `abstract class Account(val owner: String)`，带抽象方法 `fun monthlyFee(): Long`，以及普通方法 `fun summary(): String`。实现 `Checking` 和 `Savings` 两个子类，用 `Array<Account>` 打印每个账户的摘要。
2. 让 `Account` 实现 `ToString`，`println(account)` 时输出 `summary()` 的结果。想一想 `toString` 应该写在父类还是子类里，修饰符要怎么写。
3. 定义 `interface Shape { fun area(): Double }`，用 struct 实现 `Circle` 和 `Square`，再写一个函数计算 `Array<Shape>` 的总面积。构造数组时遇到了什么报错？怎样修正？
4. 把第 3 题的 `Shape` 改成 `sealed interface`，写一个 `when` 返回每种图形的名字，确认不写 `else` 也能通过编译。再新增一个 `Triangle`，看看编译器在哪里提醒你。
5. 写一个 `class Box(val content: Any)`，再写一个函数：如果 `box.content` 是 `String`，就返回它的长度，否则返回 `-1L`。先试试直接对 `box.content` 用 `is`，再按 14.7 的方法改写。
