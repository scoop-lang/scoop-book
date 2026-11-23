# 第 16 章　委托与运算符

Kotlin 有不少“约定”：属性写成 `by lazy { ... }` 就能延迟计算，类声明里写 `: List<T> by inner` 就能把整个接口转交给另一个对象，给方法加上 `operator` 就能用 `+`、`[]`、`()` 来调用它。这些约定让代码读起来更接近问题本身，而不是一串方法调用。

Scoop 保留了这三类约定，写法也基本相同。不同的地方主要在细节上：属性委托不传 `KProperty`，标准库没有现成的 `lazy`；比较运算要求 `compareTo` 返回 `Long`；`+=` 在 `plusAssign` 和 `plus` 都适用时会报歧义；泛型代码要通过 core 里的运算符接口才能使用运算符。

本章介绍：

- 属性委托：`getValue` / `setValue` 协议，以及怎样自己写一个 `Lazy`；
- 接口实现委托：`: Logger by inner`；
- `operator` 约定：算术、比较、索引、`in`、`invoke`、复合赋值和自增自减；
- core 中的运算符接口，例如 `Add`、`Compare`，以及它们和泛型、排序的关系。

## 16.1　属性委托

属性委托把属性的读写转交给另一个对象。下面先自己实现一个延迟计算的委托：

```scoop
{{#include ../../examples/ch16/lazy.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/lazy.expected}}
```

`val body: String by Lazy<String> { ... }` 的意思是：构造 `Report` 时求值一次 `by` 后面的表达式，得到一个委托对象，把它存在一个看不见的字段里；之后每次读取 `report.body`，都调用这个对象的 `getValue`。输出说明了两点：构造 `Report` 时并没有计算 `body`；第一次读取时才计算，第二次读取直接返回缓存的结果。

委托对象需要提供的方法叫作**委托协议**：

| 属性 | 委托对象必须提供 |
| --- | --- |
| `val` | `operator fun getValue(thisRef: R): T` |
| `var` | 上面的 `getValue`，加上 `operator fun setValue(thisRef: R, value: T)` |

- 两个方法都必须写 `operator`。只是名字对上而没有 `operator` 的方法不算数。
- `T` 是属性的类型。`setValue` 接受的类型必须和 `getValue` 返回的类型相同。
- `thisRef` 是属性所在的对象：类的属性是这个类的实例，扩展属性是接收者，顶层属性和局部变量是 `Unit`。上例写成 `thisRef: Any`，所以同一个委托可以用在任何地方。
- 和 Kotlin 不同，**没有第二个 `KProperty` 参数**。Scoop 没有运行期反射，委托拿不到属性名；需要属性名时，像下面的例子那样在 `by` 表达式里显式传进去。

`var` 属性的委托还要提供 `setValue`。下面的委托在每次赋值时打印新旧值：

```scoop
{{#include ../../examples/ch16/observable.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/observable.expected}}
```

`settings.volume += 2` 先通过 `getValue` 读出旧值，加 2，再通过 `setValue` 写回。局部变量也可以用委托：`var retries: Int by Logged("retries", 0)`，这时 `thisRef` 是 `Unit`。

委托方法忘了写 `operator` 时，编译器的报错是：

```scoop
{{#include ../../examples/ch16/delegate_operator_fail.scoop}}
```

```text
{{#include ../../examples/ch16/delegate_operator_fail.error}}
```

struct 和 enum 的成员不能使用委托属性。值类型的全部数据都在主构造器里，体内的属性只能是计算属性（第 8 章）：

```scoop
{{#include ../../examples/ch16/struct_delegate_fail.scoop}}
```

```text
{{#include ../../examples/ch16/struct_delegate_fail.error}}
```

> **从 Kotlin 过来**
>
> Kotlin 标准库的 `by lazy { }`、`Delegates.observable`、`Delegates.vetoable`、`by map` 在 Scoop 的 core 和 `scoop.std` 中都**没有现成的实现**，需要时自己写一个委托类，就像本节的 `Lazy` 和 `Logged`。协议也简化了：Kotlin 的 `getValue(thisRef, property: KProperty<*>)` 在 Scoop 中只有 `thisRef` 一个参数。
>
> 还要注意，上面的 `Lazy` 没有做任何同步。Kotlin 的 `lazy` 默认是线程安全的；在 Scoop 里，多个线程同时首次读取同一个延迟属性，需要你自己加锁（第 27 章）。

## 16.2　接口实现委托

接口实现委托把“实现某个接口”这件事转交给另一个对象，只覆写你关心的那几个方法：

```scoop
{{#include ../../examples/ch16/interface_by.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/interface_by.expected}}
```

`class CountingLogger(private val inner: Logger) : Logger by inner` 的意思是：`CountingLogger` 实现 `Logger`，凡是它自己没有写的方法（这里是 `info` 和 `alert`），都自动转发给 `inner`。它自己写了 `warn`，所以 `warn` 用的是它自己的版本。

几条规则：

- `by` 后面的表达式在构造时求值一次，结果保存在实例里。之后即使外面的变量换成了别的对象，委托也不会跟着变。
- 自己写的 `override` 优先于委托。两个委托都能提供同一个方法时，必须自己写 `override` 决定用哪个。
- **委托对象内部的 `this` 始终是它自己。** 输出的最后两行说明了这一点：`logger.alert(...)` 转发给 `ConsoleLogger.alert`，它内部调用的 `warn` 是 `ConsoleLogger` 自己的 `warn`，而不是 `CountingLogger` 覆写的那个，所以计数没有增加。委托是“转发”，不是“继承”。这一点和 Kotlin 相同。
- 只有 class 和 object 能使用接口实现委托，struct 和 enum 不行：

```scoop
{{#include ../../examples/ch16/by_struct_fail.scoop}}
```

```text
{{#include ../../examples/ch16/by_struct_fail.error}}
```

需要“值类型 + 转发”的组合时，可以手写转发方法，或者把它改成 class。

## 16.3　运算符就是带 `operator` 的方法

Scoop 的运算符是普通方法调用的另一种写法：`a + b` 就是 `a.plus(b)`，`-a` 就是 `a.unaryMinus()`。要让自己的类型支持某个运算符，声明一个对应名字的方法，并加上 `operator`：

```scoop
{{#include ../../examples/ch16/vector.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/vector.expected}}
```

- 运算符方法可以是成员，也可以是扩展函数。`operator fun Double.times(v: Vec2)` 给 `Double` 加了一个扩展运算符，于是 `2.0 * a` 也能写了。
- 运算符的优先级是固定的，和内建类型相同：`a + b * 2.0` 先算乘法。
- 右操作数可以是别的类型，比如 `Vec2 * Double`；返回类型也不限。

和属性委托一样，**`operator` 修饰符不能省**。只有名字叫 `plus` 的普通方法不会被 `+` 使用：

```scoop
{{#include ../../examples/ch16/no_operator_fail.scoop}}
```

```text
{{#include ../../examples/ch16/no_operator_fail.error}}
```

注意报错说的是“没有 `plus` 方法”，即使类型里明明写了 `plus`。看到这条报错时，先检查方法有没有加 `operator`。

能重载的运算符只有固定的一组，名字不在其中的方法不能加 `operator`：

```scoop
{{#include ../../examples/ch16/unknown_operator_fail.scoop}}
```

```text
{{#include ../../examples/ch16/unknown_operator_fail.error}}
```

下表列出了全部运算符和对应的方法：

| 写法 | 对应的调用 | 要求 |
| --- | --- | --- |
| `+a` / `-a` / `!a` | `a.unaryPlus()` / `a.unaryMinus()` / `a.not()` | 无参数 |
| `a + b`、`-`、`*`、`/`、`%` | `a.plus(b)`、`minus`、`times`、`div`、`rem` | 一个参数 |
| `a..b` / `a..<b` | `a.rangeTo(b)` / `a.rangeUntil(b)` | 一个参数 |
| `a in b` / `a !in b` | `b.contains(a)` / `!b.contains(a)` | 返回 `Boolean` |
| `a[i, j]` | `a.get(i, j)` | 至少一个参数 |
| `a[i, j] = v` | `a.set(i, j, v)` | 返回 `Unit` |
| `a(x, y)` | `a.invoke(x, y)` | 参数任意 |
| `a += b` 等 | `a.plusAssign(b)`，或 `a = a.plus(b)` | 见 16.6 |
| `a++` / `a--` | `a = a.inc()` / `a = a.dec()` | 返回接收者的类型 |
| `a < b` 等 | `a.compareTo(b)` 与 0 比较 | 返回 **`Long`** |
| `a == b` / `a != b` | `a.equals(b)` | 必须是成员函数（第 8 章） |

`&&`、`||`、`===`、`=`、`?:`、`!!`、`is`、`as` 不能重载。`infix` 函数（第 6 章）不属于运算符，不需要 `operator`。

## 16.4　比较：`compareTo` 与 `Compare<T>`

比较运算符 `<`、`<=`、`>`、`>=` 都通过 `compareTo` 实现：它返回负数、零或正数，分别表示“小于”“等于”“大于”。

```scoop
{{#include ../../examples/ch16/compare.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/compare.expected}}
```

这个例子有三个要点。

**第一，`compareTo` 返回 `Long`，不是 `Int`。** 这是 Scoop 的统一约定，`Int` 的 `compareTo` 也返回 `Long`，所以上面可以直接写 `major.compareTo(other.major)`。照 Kotlin 习惯返回 `Int` 会报错：

```scoop
{{#include ../../examples/ch16/compare_int_fail.scoop}}
```

```text
{{#include ../../examples/ch16/compare_int_fail.error}}
```

**第二，排序需要 `Compare<T>` 接口。** 只写 `operator fun compareTo` 就能使用 `<`，但 `sorted()`、`sortedDescending()`、`sortedSetOf()` 这些库函数要求元素类型实现 core 的 `Compare<T>` 接口。`Version` 在声明里写了 `: Compare<Version>`，并用 `public override operator fun compareTo` 实现它，所以能排序。少了这个声明：

```scoop
{{#include ../../examples/ch16/compare_bound_fail.scoop}}
```

```text
{{#include ../../examples/ch16/compare_bound_fail.error}}
```

第 10 行的 `a < b` 没有问题，第 11 行的 `sorted()` 被拒绝。这和第 8 章讲的 `==` 与 `Equals<T>` 是同一个道理：**能用运算符，不等于实现了对应的接口**。

**第三，比较和相等是分开的。** `current == Version(1, 4, 2)` 用的是 struct 自动提供的 `==`，和 `compareTo` 无关。自己实现时，要保证 `compareTo` 返回 0 的两个值也用 `==` 判断为相等，否则排序和查找的结果会让人困惑。

不想（或不能）给类型加 `Compare<T>` 时，可以按某个字段排序：`sortedBy { v -> v.patch }`，选出的字段只要实现了 `Compare`。更复杂的排序规则可以用 `scoop.comparisons` 包里的 `Comparator`、`compareBy`、`thenBy`，配合 `sortedWith` 使用，第 23 章会介绍。

> **从 Kotlin 过来**
>
> Kotlin 的 `Comparable<T>` 在 Scoop 中叫 `Compare<T>`，`compareTo` 返回 `Long`。Kotlin 的 `Comparator` 对应 `scoop.comparisons.Comparator<T>`，它的方法 `compare(left, right)` 同样返回 `Long`。

## 16.5　索引、`in` 与 `invoke`

`get` 和 `set` 让类型支持方括号访问，参数个数不限；`contains` 让类型支持 `in`：

```scoop
{{#include ../../examples/ch16/grid.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/grid.expected}}
```

- `grid[1L, 2L] = '@'` 调用 `grid.set(1L, 2L, '@')`。`set` 的最后一个参数是写入的值，前面的都是索引；它必须返回 `Unit`。
- `(1L, 4L) in grid` 调用 `grid.contains((1L, 4L))`，这里用一个 tuple 表示坐标。注意 `in` 的接收者在右边。
- 在类的内部可以写 `this[row, col]` 调用自己的 `get`。

`invoke` 让对象可以像函数一样调用：

```scoop
{{#include ../../examples/ch16/invoke.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/invoke.expected}}
```

`invoke` 可以重载，也可以有默认参数和命名参数，`hello("Ada")` 就是 `hello.invoke("Ada")`。这和第 7 章的函数值不同：函数值只能按位置调用，而 `invoke` 是普通方法，具备普通方法调用的全部便利。

## 16.6　复合赋值与自增

`a += b` 有两种可能的含义：

- **就地修改**：调用 `a.plusAssign(b)`，`a` 本身不变，它引用的对象被修改了；
- **计算后写回**：计算 `a.plus(b)`，再把结果赋给 `a`。

编译器按下面的规则选择：只有 `plusAssign` 可用时用它，只有 `plus` 可用时计算后写回，两者都可用时报错。`-=`、`*=`、`/=`、`%=` 同理。

```scoop
{{#include ../../examples/ch16/assign.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/assign.expected}}
```

- `Money` 是 struct，只有 `plus`，所以 `total += Money(1L)` 等价于 `total = total + Money(1L)`，`total` 必须是 `var`。
- `Basket` 是 class，有 `plusAssign`，所以 `basket += "apple"` 直接修改对象，`basket` 是 `val` 也没关系。
- `total++` 调用 `inc`，再把结果写回 `total`。`inc` / `dec` 不修改接收者，而是返回一个新值，所以它天然适用于不可修改的 struct；返回类型必须是接收者的类型。

对只有 `plus` 的类型，在 `val` 上使用 `+=` 会报错，因为结果无处写回：

```scoop
{{#include ../../examples/ch16/assign_val_fail.scoop}}
```

```text
{{#include ../../examples/ch16/assign_val_fail.error}}
```

同时提供 `plus` 和 `plusAssign` 的类型，在 `var` 上使用 `+=` 时编译器无法判断你想要哪一种，直接报歧义：

```scoop
{{#include ../../examples/ch16/assign_ambiguous_fail.scoop}}
```

```text
{{#include ../../examples/ch16/assign_ambiguous_fail.error}}
```

Kotlin 在这种情况下也会报歧义，只不过 Scoop 把规则写得更直白：编译器不会替你偏向其中一个。设计类型时，**可变的 class 提供 `plusAssign`，不可变的值类型提供 `plus`**，一般不要两个都提供。

## 16.7　core 的运算符接口

运算符方法本身不需要实现任何接口。但在泛型代码里，编译器只知道类型参数 `T` 满足哪些约束，不知道它有没有 `plus` 方法：

```scoop
{{#include ../../examples/ch16/add_nobound_fail.scoop}}
```

```text
{{#include ../../examples/ch16/add_nobound_fail.error}}
```

core 为每种运算符提供了一个普通接口，用作泛型约束。加法对应 `Add<Rhs, Result>`：

```scoop
{{#include ../../examples/ch16/generic_add.scoop}}
```

输出：

```text
{{#include ../../examples/ch16/generic_add.expected}}
```

`T : Add<T, T>` 表示“`T` 加 `T` 得到 `T`”，函数体里的 `sum + value` 因此合法。所有整数类型、`Float`、`Double` 和 `String` 都实现了 `Add<自己, 自己>`，`Vec2` 通过显式声明 `: Add<Vec2, Vec2>` 加入进来。和 `Compare` 一样，只有 `operator fun plus` 而没有声明接口的类型不满足这个约束：

```scoop
{{#include ../../examples/ch16/add_bound_fail.scoop}}
```

```text
{{#include ../../examples/ch16/add_bound_fail.error}}
```

常用的运算符接口：

| 接口 | 方法 | core 中谁实现了它 |
| --- | --- | --- |
| `Add<Rhs, Result>` | `plus(other: Rhs): Result` | 整数、`Float`、`Double`、`String` |
| `Sub`、`Mul`、`Div`、`Rem` | `minus`、`times`、`div`、`rem` | 整数、`Float`、`Double` |
| `UnaryMinus<Result>`、`UnaryPlus<Result>` | `unaryMinus()`、`unaryPlus()` | 整数、`Float`、`Double` |
| `Not<Result>` | `not()` | `Boolean` |
| `Increment<Result>`、`Decrement<Result>` | `inc()`、`dec()` | 整数、`Float`、`Double` |
| `Compare<Rhs>` | `compareTo(other: Rhs): Long` | 整数、`Float`、`Double`、`Char`、`String` |
| `Equals<Rhs>` | `equals(other: Rhs): Boolean` | 基本类型、`String`、`Unit` |
| `Hash` | `hash(): Long` | 基本类型（`Float`、`Double` 除外）、`String` |
| `Contains<Element>` | `contains(value: Element): Boolean` | 整数区间 |
| `IndexGet<Index, Value>`、`IndexSet<Index, Value>` | `get`、`set` | `List`、`MutableList`、`MutableArray` 等 |
| `Invoke0<R>`、`Invoke<A, R>`、`Invoke2<A, B, R>` | `invoke` | 由用户类型实现 |
| `AddAssign<Rhs>` 等 | `plusAssign` 等 | 由用户类型实现 |

这些接口的类型参数都是不变的，也没有隐含的 “Self” 类型：`Add<Vec2, Vec2>` 必须把两个 `Vec2` 都写出来。实现接口方法时写 `public override operator fun`，三个修饰符都要有。

> **深入一点：为什么要显式声明？**
>
> 有人会问：既然 `Vec2` 已经有了 `operator fun plus`，编译器为什么不能自动认为它满足 `Add<Vec2, Vec2>`？原因和第 8 章的 `Equals`、`Hash` 一样：Scoop 的泛型在编译时为每种实际类型生成一份专用代码（第 17 章），接口关系决定了这份代码怎么生成、值类型要不要装箱、`is` 检查的结果是什么。如果“长得像”就算实现，引入一个新的扩展函数就可能悄悄改变别处泛型代码的含义。显式声明让每一种能力都有确定的出处。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `val x by lazy { ... }` | 标准库没有 `lazy`，自己写委托类（16.1） |
| `Delegates.observable(...)` | 没有现成实现，自己写带 `setValue` 的委托 |
| `getValue(thisRef, property: KProperty<*>)` | `getValue(thisRef)`，没有 `property` 参数 |
| `class A(b: B) : I by b` | 相同；struct 和 enum 不能用 |
| `operator fun plus(...)` | 相同；不写 `operator` 时 `+` 报“没有 `plus` 方法” |
| `operator fun compareTo(...): Int` | 返回 **`Long`** |
| `Comparable<T>` | `Compare<T>` |
| `Comparator<T>` | `scoop.comparisons.Comparator<T>`，`compare` 返回 `Long` |
| `list.sorted()` 只要求 `Comparable` | 要求显式实现 `Compare<T>` |
| 泛型里无法表达“支持 `+`” | 用 `T : Add<T, T>` 等 core 运算符接口 |
| `+=` 在 `plus`/`plusAssign` 都可用时报歧义 | 相同 |

## 常见误用

- **忘了写 `operator`**：委托报 “has no applicable property delegate operator”，运算符报“没有这个方法”。
- **`compareTo` 返回 `Int`**：改成 `Long`。整数的 `compareTo` 本身就返回 `Long`，可以直接用。
- **有了 `compareTo` 就以为能排序**：`sorted()` 等函数要求 `Compare<T>`，需要在类型声明里写出来，并用 `public override operator fun compareTo` 实现。
- **在泛型函数里直接用 `+`**：给类型参数加上 `Add<T, T>` 之类的约束。
- **同时提供 `plus` 和 `plusAssign`**：在 `var` 上 `+=` 会报歧义。可变类型提供 `plusAssign`，值类型提供 `plus`。
- **以为接口委托会回调宿主的覆写方法**：委托对象内部的调用只到它自己的方法。
- **在 struct 上使用 `by`**：属性委托和接口委托都只能用在 class（以及 object）里。
- **期待标准库提供 `lazy`**：目前需要自己写；跨线程使用时还要自己处理同步。

## 小结

- 属性委托：`val p: T by d` 每次读取调用 `d.getValue(thisRef)`，`var` 还需要 `setValue(thisRef, value)`；两者都要写 `operator`，没有 `KProperty` 参数。
- 标准库没有 `lazy`、`observable` 等现成委托，自己写一个类即可。
- 接口实现委托 `: I by expr` 把未覆写的成员转发给 `expr`；委托对象内部的 `this` 是它自己。
- 运算符是带 `operator` 的普通方法，可以是成员或扩展；可重载的运算符是固定的一组。
- 比较通过返回 `Long` 的 `compareTo` 实现；排序等库函数要求显式实现 `Compare<T>`。
- `a += b` 优先选唯一可用的 `plusAssign` 或 `plus`，两者都可用时报歧义；`++` 调用 `inc` 并写回。
- core 的运算符接口（`Add`、`Compare`、`IndexGet` 等）用作泛型约束，类型必须显式声明实现它们。

## 练习

1. 给 16.1 的 `Lazy` 加一个 `isInitialized` 属性，并写一个程序验证：读取属性之前它是 `false`，读取之后是 `true`。
2. 写一个委托 `NonNegative`，用于 `var` 属性：赋值为负数时抛出 `IllegalArgumentException`，否则正常保存。
3. 写一个 `struct Fraction(val num: Long, val den: Long)`，支持 `+`、`*`、一元 `-` 和比较运算，并实现 `Compare<Fraction>`，让 `[Fraction(1L, 2L), Fraction(1L, 3L)].sorted()` 能正常工作。
4. 写一个 class `Matrix`，用 `operator fun get(row: Long, col: Long)` 和 `set` 访问元素，并用 `operator fun times(other: Matrix)` 实现矩阵乘法。
5. 写一个泛型函数 `fun <T : Compare<T>> maxOf(values: Array<T>): T`，用 `Version` 和 `String` 分别调用它。
