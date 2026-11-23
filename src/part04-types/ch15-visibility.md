# 第 15 章　可见性与 API 边界

Kotlin 的声明默认是 `public`：只要不加修饰符，任何模块都能看到它。Scoop 正好相反，**声明默认是 `internal`**，只在当前 Cone 内可见；想让别的 Cone 使用，必须逐项写上 `public`。

这个差别在单文件程序和单个 Cone 里几乎感觉不到，因为同一个 Cone 内的代码本来就能互相访问。一旦你把代码拆成库 Cone 和应用 Cone，它就会立刻显现出来：从 Kotlin 习惯过来的人，常常会遇到“明明写了这个方法，却说找不到”的报错。

本章介绍：

- 四种可见性 `public`、`internal`、`private`、`protected` 各自的范围；
- 为什么“边界是 Cone”，以及 package 为什么不是可见性边界；
- `public class` 不会自动公开构造器和成员，`public interface` 的成员必须显式 `public`，实现时要写 `public override`；
- 公开签名不能泄漏非公开类型；
- 怎样设计一个库的公开面；
- 为什么 Kotlin 默认用 `public`，而 Scoop 选择了 `internal`。

## 15.1　一个库，一个应用

先看一个完整的例子。`geometry` 是一个库 Cone，提供几种图形；`app` 是一个可执行 Cone，依赖 `geometry`。两个目录并排放置：

```text
geometry/
  Cone.toml
  src/shapes.scoop
  src/util.scoop
app/
  Cone.toml
  src/main.scoop
```

库的清单声明 `kind = "library"`：

```toml
{{#include ../../examples/ch15/geometry/Cone.toml}}
```

库的公开 API：

```scoop
{{#include ../../examples/ch15/geometry/src/shapes.scoop}}
```

库内部的辅助代码，没有任何 `public`：

```scoop
{{#include ../../examples/ch15/geometry/src/util.scoop}}
```

应用的清单通过 `path` 依赖库（依赖的写法见第 29 章）：

```toml
{{#include ../../examples/ch15/app/Cone.toml}}
```

应用代码：

```scoop
{{#include ../../examples/ch15/app/src/main.scoop}}
```

在 `app` 目录执行 `scoop run --release`，输出：

```text
{{#include ../../examples/ch15/app/expected.txt}}
```

注意库里每一个要给 `app` 用的东西都写了 `public`：接口 `Shape` 本身和它的两个成员、类 `Circle` 和它的构造器、`Rect` 的 companion 和其中的工厂函数、顶层函数 `totalArea`。而 `PI`、`requireNonNegative` 没有修饰符，它们是 `internal` 的：`shapes.scoop` 可以直接使用它们（同一个 Cone），`app` 则完全看不到。

## 15.2　四种可见性

| 修饰符 | 顶层声明 | 类型的成员 |
| --- | --- | --- |
| `public` | 所有能依赖这个 Cone 的代码 | 所有能看到这个类型的代码 |
| `internal`（默认） | 当前 Cone | 当前 Cone |
| `private` | **当前源文件** | 当前类型的内部 |
| `protected` | 不允许 | 只用于 class 成员：声明它的 class 及其子类内部 |

几个要点：

- **省略修饰符就是 `internal`**，不论是顶层函数、类、类的方法、属性、构造器还是接口成员，都一样。成员不会从所在的类型或实现的接口“继承”可见性。
- 成员的实际可见范围，还要和它所在类型的范围取交集：`internal class` 里的 `public` 方法，在 Cone 外仍然看不到，因为外面连这个类都看不到。
- `main` 是例外：它是程序入口，编译器按签名找到它，不需要 `public`。
- 局部变量、参数和 `init` 块没有可见性可言，不能加修饰符。

### `private`：文件内和类型内

顶层的 `private` 声明只在**当前源文件**里可见。下面这个 Cone 有两个源文件：

```scoop
{{#include ../../examples/ch15/files/src/greeting.scoop}}
```

```scoop
{{#include ../../examples/ch15/files/src/main.scoop}}
```

输出：

```text
{{#include ../../examples/ch15/files/expected.txt}}
```

`greet` 是 `internal` 的，`main.scoop` 可以调用；`greetingWord` 和 `decorate` 是 `greeting.scoop` 私有的。`main.scoop` 自己也声明了一个 `private fun decorate`，两个同名的私有函数各管各的文件，互不冲突。如果在 `main.scoop` 里读取 `greetingWord`，编译器会报（这是把上例 `main.scoop` 改写后实际得到的输出，路径已省略）：

```text
error[E0403]: value `greetingWord` is not accessible here
 --> src/main.scoop:4:13
  |
4 |     println(greetingWord)
  |             ^^^^^^^^^^^^
note[N0002]: candidate declared here
 --> src/greeting.scoop:3:13
  |
3 | private val greetingWord = "Hello"
  |             ^^^^^^^^^^^^
```

类型里的 `private` 成员只在这个类型内部可见：

```scoop
{{#include ../../examples/ch15/private_member_fail.scoop}}
```

```text
{{#include ../../examples/ch15/private_member_fail.error}}
```

注意报错的措辞：不是“不可访问”，而是“没有这个属性”。从外面看，私有成员就像不存在一样。15.6 节会再讨论这一点。

### `protected` 与访问器的可见性

`protected` 只能用于 class 的成员，表示“这个 class 和它的子类内部可以用”。属性的 setter 还可以单独声明更窄的可见性，常见的写法是“公开读、私有写”：

```scoop
{{#include ../../examples/ch15/account.scoop}}
```

输出：

```text
{{#include ../../examples/ch15/account.expected}}
```

`balance` 外部可以读，但只有 `Account` 自己能写，所以 `Savings` 必须通过 `deposit` 改变余额；`audit` 是 `protected` 的，`Account` 和子类 `Savings` 都能调用。在类的外面，两者都会被拒绝：

```scoop
{{#include ../../examples/ch15/protected_fail.scoop}}
```

```text
{{#include ../../examples/ch15/protected_fail.error}}
```

注意 Scoop 的访问器写法和 Kotlin 略有不同：单独改变 setter 的可见性时，要写出完整的 `private set(value) { field = value }`，不能只写 `private set`。

## 15.3　边界是 Cone，不是 package

`internal` 的范围是 **Cone**，也就是一个带 `Cone.toml` 的项目（第 28 章）。同一个 Cone 里的所有源文件，不论属于哪个 package，都能互相访问 `internal` 声明；不同的 Cone 之间，只能看到 `public` 声明。

package 只负责给名字分组，不授予任何访问权限。你也不能通过“把自己的代码声明在对方的 package 里”来绕过边界：Scoop 要求一个 Cone 的 package 等于它的 group 或其子包。在 `app`（group 为 `book.app`）里写 `package book.geometry`，得到的是：

```text
error[E2007]: package `book.geometry` must equal Cone group `book.app` or one of its subpackages
```

这和 Kotlin 的 `internal` 很像：Kotlin 的 `internal` 表示“同一个模块”（一个 Gradle 模块、一个 Maven 项目），Scoop 的 Cone 就扮演模块的角色。区别只在于哪一个是默认值。

单文件程序是一个只有一个文件的 Cone，所以在单文件里，`internal` 和 `public` 的效果没有区别。本书前面各章的示例都没写 `public`，原因就在这里。

## 15.4　公开类型不等于公开全部

### `public class` 不会公开构造器和成员

一个常见的误会是：类写了 `public`，它的构造器和成员也就跟着公开了。在 Scoop 里，**每个声明的可见性都是独立的**。假设一个库这样写：

```scoop
public class Counter(val start: Int) {
    var count: Int = start

    fun increment() {
        count = count + 1
    }
}
```

另一个 Cone 能看到 `Counter` 这个类型，却不能构造它（以下报错都是用一个真实的库 Cone 和应用 Cone 编译得到的）：

```text
error[E0403]: constructor `Counter` is not accessible here
 --> src/main.scoop:6:13
  |
6 |     val c = Counter(1)
  |             ^^^^^^^
```

把构造器改成 `public constructor(val start: Int)` 之后，构造通过了，但成员仍然是 `internal` 的：

```text
error[E0402]: type `Counter` has no method `increment`
 --> src/main.scoop:7:7
  |
7 |     c.increment()
  |       ^^^^^^^^^
error[E0402]: class `Counter` has no property `count`
 --> src/main.scoop:8:19
  |
8 |     println(f"${c.count}")
  |                   ^^^^^
```

要让下游完整使用这个类，需要写成：

```scoop
public class Counter public constructor(public val start: Int) {
    public var count: Int = start

    public fun increment() {
        count = count + 1
    }
}
```

规则总结如下：

- class 的构造器默认是 `internal`。给主构造器加修饰符时，要写出 `constructor` 关键字：`public class Circle public constructor(...)`。
- 没有声明构造器的 class，隐式的无参构造器也是 `internal`。
- 构造器参数上的 `val`/`var` 属性也有自己的可见性，`public val width` 才是公开属性。
- 反过来，你可以**有意**不公开构造器：`Rect` 的构造器是 `private` 的，下游只能通过会做检查的 `Rect.of` 创建实例。这是在类上维护约束的标准做法（第 13 章）。

> **说明**
>
> 上面 `Counter` 的两段代码只用来说明规则，没有放进示例目录；报错文本是用真实的库 Cone 和应用 Cone 编译得到的，只省略了绝对路径。

struct 和 enum 是例外：它们的字段、enum 的各个分支以及 struct 的主构造器都是“公开的表示”，没有单独的可见性，只要 struct 或 enum 本身是 `public`，下游就能构造它们、读取字段、匹配分支（第 8、9 章）。

### `public interface` 的成员必须显式 `public`

接口的成员同样默认是 `internal`。但对 `public interface`，Scoop 不允许省略：

```scoop
{{#include ../../examples/ch15/interface_member_fail.scoop}}
```

```text
{{#include ../../examples/ch15/interface_member_fail.error}}
```

原因是：如果公开接口里有一个下游看不到的成员，下游就无法实现这个接口，也看不出它到底要求什么。Scoop 选择直接报错，而不是悄悄地把它升级成 `public`。

### 实现公开接口要写 `public override`

`override` 也不会继承被覆写成员的可见性，省略修饰符时仍然是 `internal`。实现一个 `public` 接口成员时，必须写 `public override`，即使实现它的类本身是 `internal` 的：

```scoop
{{#include ../../examples/ch15/override_fail.scoop}}
```

```text
{{#include ../../examples/ch15/override_fail.error}}
```

报错说的是：这个实现的可见范围，覆盖不了它要实现的接口槽位 `Named.name`。改成 `public override fun name()` 即可。这条规则保证了：任何拿到 `Named` 的代码，都一定能调用 `name()`，不管背后的实现类是谁。

## 15.5　公开签名不能泄漏非公开类型

公开声明的签名里出现的类型（参数、返回值、父类型、泛型上界），必须至少和这个声明一样可见：

```scoop
{{#include ../../examples/ch15/exposes_fail.scoop}}
```

```text
{{#include ../../examples/ch15/exposes_fail.error}}
```

`issue` 是 `public` 的，下游可以调用它，却拿不到 `Token` 这个类型，这样的 API 没法使用。要么把 `Token` 也公开，要么把 `issue` 改成 `internal`，要么让它返回一个公开的接口类型。

## 15.6　读懂“找不到符号”

跨 Cone 访问 `internal` 声明时，编译器的报错往往不是“不可访问”，而是“不存在”。以 15.1 的库为例，在 `app` 里使用它的 `internal` 声明：

```text
error[E0401]: unknown function `requireNonNegative`
help[H0402]: bare enum variants without an exact enum expected type must be qualified as `E.V` or given a type annotation
error[E0401]: unknown variable `PI`
help[H0402]: bare enum variants without an exact enum expected type must be qualified as `E.V` or given a type annotation
error[E0402]: class `Circle` has no property `radius`
```

用 exact import 导入一个 `internal` 顶层函数时，报错发生在 import 这一行：

```text
error[E0406]: import target is not available in the current compilation unit
```

调用 `private` 或 `internal` 的构造器时，报错则是：

```text
error[E0403]: constructor `Rect` is not accessible here
```

这样设计是因为，从另一个 Cone 看过去，`internal` 声明根本不属于这个库的 API，编译器不会把它们列为候选。代价是报错不会直接告诉你“它存在，但不是 public”。所以，当你确定库里有某个名字、编译器却说 `unknown`、`has no method`、`has no property` 或 `not available` 时，第一件事是去库的源码里检查它（以及它所在的类型）有没有写 `public`。

这些失败分别属于名称查找（`E0401`）、成员查找（`E0402`）、可访问性（`E0403`）和导入（`E0406`）规则。这里的 `H0402` 是名称查找失败时附带的限定名建议，并不表示 `PI` 或 `requireNonNegative` 是 enum 变体；修复时仍要结合主错误与库的公开声明。

## 15.7　设计一个库的公开面

公开面（public surface）就是一个 Cone 对外承诺的全部内容：下游可以依赖的类型、函数、成员和构造器。它一旦发布，修改就可能破坏别人的代码。默认 `internal` 让你从“什么都不公开”开始，逐个决定要承诺什么。几条实用的原则：

- **只公开下游真正需要的东西。** 15.1 的库公开了 `Shape`、`Circle`、`Rect`、`totalArea`，而 `PI`、`requireNonNegative` 这些实现细节留在 Cone 内部，以后可以随意修改或删除。
- **面向接口公开。** 下游只需要“能算面积的东西”时，公开 `Shape` 接口就够了，具体的类可以不公开，或者只公开工厂函数。
- **用私有构造器加工厂函数保护约束。** `Rect` 的构造器是 `private` 的，所有实例都经过 `Rect.of` 的检查，下游无法构造出宽度为负数的 `Rect`。
- **属性公开读、私有写。** `public var` 加 `private set(...)`，或者干脆用 `public val`，避免下游绕过你的方法修改状态。
- **签名里的类型都要公开。** 一个公开函数用到的每个类型都必须对下游可见（15.5）。
- **不要因为“下游可能用得到”就提前公开。** 把 `internal` 改成 `public` 永远是兼容的；把 `public` 收回成 `internal` 则会破坏下游。

> **深入一点：公开面就是产物的导出表面**
>
> 库 Cone 编译后得到一个 `.slib` 产物，里面记录了这个 Cone 导出的声明，下游编译时只读取这些导出信息。`public` 决定了一个声明是否进入导出表面；`internal` 和 `private` 声明不会出现在下游可见的 API 中，`main` 即使存在也不会被导出。所以“公开面”不只是一个设计上的说法，它在产物格式里有实际对应。

## 15.8　为什么 Kotlin 默认用 `public`

两门语法相近的语言，在这个问题上做了相反的选择，各有道理。

**Kotlin 的考虑。** Kotlin 团队在 1.0 发布之前专门讨论过默认可见性该用什么，最终选择了 `public`。主要的理由是：

- **大部分代码是应用代码，而不是库。** 在一个应用里，绝大多数类和函数本来就是要被别处使用的。如果默认是 `internal`，开发者要在大量声明前写 `public`，这些修饰符几乎不传递任何信息，只是样板。
- **减少“为什么访问不到”的摩擦。** 应用通常由多个模块组成，默认 `internal` 会让跨模块调用频繁出现访问错误，而这些错误多数时候并不代表设计问题。
- **贴近 Java 开发者的习惯。** Kotlin 的目标用户主要来自 Java，在 Java 里大多数类和方法也都写成 `public`，默认 `public` 让迁移更自然。

这个选择的代价落在库作者身上：一个 Kotlin 库很容易**无意中**把实现细节暴露成公开 API，一旦被下游用上，就成了需要维持兼容的承诺。为此 Kotlin 1.4 引入了 **Explicit API mode**（Gradle 里的 `explicitApi()`，编译器参数 `-Xexplicit-api`）：开启后，库代码中的公开声明必须显式写出可见性和返回类型，否则编译器报错或警告。也就是说，Kotlin 为库作者提供了一个“必须显式公开”的选项，但默认值仍然照顾应用开发者。

**Scoop 的考虑。** Scoop 把这个选项变成了默认值，理由来自 Cone 的角色：

- **Cone 同时是编译单元、发布单元和可见性边界。** 一个 Cone 编译成一个 `.slib`，它的公开面就是这个产物的导出表面，也是对下游的兼容承诺。默认 `internal` 让“公开”成为一个显式的决定，而不是遗漏修饰符的副作用。
- **对应用代码的摩擦很小。** 同一个 Cone 内部的代码可以自由互相访问。一个单文件程序或单 Cone 应用，完全不需要写 `public`。只有当你把代码拆成多个 Cone、需要跨 Cone 调用时，才需要决定公开什么，而这恰好是应该认真考虑 API 的时候。
- **规则一致，没有例外。** 构造器、成员、override 都不会从别处继承可见性，读代码时看到修饰符就知道范围，看不到就是 `internal`。

Scoop 和 Kotlin 的 Explicit API mode 目标相同，都是让“公开”必须显式写出来，但做法不同：Explicit API mode 在库代码省略可见性时报错或警告，要求你在 `public` 和 `internal` 之间明确选一个；Scoop 则把省略直接当作 `internal`，不会报错。结果是，在 Scoop 里忘写修饰符的代价是“下游看不到”，而不是“意外公开”，这类遗漏总能在下游第一次使用时被发现，并且只在跨 Cone 时才会遇到。

> **深入一点：Kotlin 的 inline 函数与 `@PublishedApi`**
>
> 在 Kotlin 里，公开 API 的边界还受 `inline` 函数的影响。inline 函数的函数体（编译后的字节码）会被复制到调用处，成为调用方二进制的一部分。所以 Kotlin 规定：`public` 的 inline 函数不能引用 `private` 或 `internal` 的声明，否则报 “Public-API inline function cannot access non-public-API …”。原因有两层：`private` 成员被复制到别的类里，过不了 JVM 的访问检查；`internal` 声明在字节码里虽然是公开的，但库的新版本可能改名或删除它，已经内联进下游的代码就会失效。
>
> 官方的办法是给被引用的 `internal` 声明加 `@PublishedApi`。这并没有真正绕开限制：加了注解的声明在源码里仍然是 `internal`，在二进制层面却成了公开 API，要和 `public` 声明一样维持兼容。也就是说，一个 `public` inline 函数碰到的所有东西，实际上都是公开 API。
>
> Scoop 没有这个限制。`inline` 修饰符被接受但不起作用（第 7 章 7.8 节），更接近 inline 的是泛型：泛型函数按单态化在下游为每种类型参数生成代码（第 17 章）。但可见性在函数**定义处**就检查完了，生成代码由编译器负责，下游不会按自己的权限重新检查函数体。所以 `public` 的泛型函数可以自由调用同一 Cone 里的 `internal` 辅助函数，辅助函数也不会因此成为公开 API。下面的 `labels` 是一个库 Cone，`labelapp` 依赖它。

`labels/src/labels.scoop`：

```scoop
{{#include ../../examples/ch15/labels/src/labels.scoop}}
```

`labelapp/src/main.scoop`：

```scoop
{{#include ../../examples/ch15/labelapp/src/main.scoop}}
```

输出：

```text
{{#include ../../examples/ch15/labelapp/expected.txt}}
```

`label` 是 `public` 的泛型函数，`bracket` 是默认的 `internal`。`labelapp` 用 `String`、`Int`、`Double` 三种类型调用 `label`，编译器为每种类型各生成一份代码，其中对 `bracket` 的调用都正常工作；而 `labelapp` 自己直接调用 `bracket` 仍然会报错，和 15.6 节的情况相同。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| 默认 `public` | 默认 `internal`，边界是 Cone |
| `internal`：同一模块 | `internal`：同一 Cone |
| 顶层 `private`：当前文件 | 相同 |
| `public class Foo(val x: Int)` 构造器和属性都公开 | 构造器、属性默认 `internal`，要写 `public constructor(public val x: Int)` |
| 接口成员默认 `public` | 接口成员默认 `internal`；`public interface` 的成员必须写 `public` |
| `override` 继承被覆写成员的可见性 | `override` 默认 `internal`，实现公开成员要写 `public override` |
| `private set` | `private set(value) { field = value }` |
| 在别的模块声明同名 package 不影响访问 | package 必须等于 Cone 的 group 或其子包 |
| Explicit API mode：省略可见性时报错，可选开启 | 省略可见性就是 `internal`，始终如此 |

## 常见误用

- **只写 `public class`**：构造器和成员仍是 `internal`，下游会看到 “constructor is not accessible” 或 “has no method”。
- **`public interface` 的成员没写 `public`**：直接编译错误（15.4）。
- **实现接口时只写 `override`**：公开接口的成员要写 `public override`。
- **看到 `unknown function`、`has no property` 就以为拼错了**：如果名字确实存在，先检查它和它所在的类型有没有写 `public`（15.6）。
- **以为 package 相同就能访问 `internal`**：可见性的边界是 Cone，不是 package。
- **公开函数返回内部类型**：签名中的类型也必须公开（15.5）。
- **为了省事把所有东西都写成 `public`**：公开面越大，以后能自由修改的地方就越少。

## 小结

- 声明默认是 `internal`，在当前 Cone 内可见；`public` 才能被其他 Cone 使用。
- 顶层 `private` 限于当前文件，成员 `private` 限于当前类型；`protected` 只用于 class 成员。
- 每个声明的可见性独立：`public class` 不公开构造器和成员，`override` 不继承可见性，`public interface` 的成员必须显式 `public`。
- 公开签名不能用到非公开类型。
- 跨 Cone 访问非公开声明时，报错常常是“找不到”，而不是“不可访问”。
- Kotlin 默认 `public` 是为了照顾占多数的应用代码；Scoop 默认 `internal`，因为 Cone 的公开面就是它的发布承诺，而 Cone 内部不受影响。

## 练习

1. 照着 15.1 搭建 `geometry` 和 `app` 两个 Cone，在 `app` 里调用 `Rect(2.0, 3.0)`，观察报错，再说明为什么 `Rect.of` 可以调用。
2. 给 `geometry` 加一个 `public class Triangle`，只公开工厂函数 `Triangle.of(a, b, c)`，在三边不能构成三角形时抛出 `IllegalArgumentException`。
3. 把 `Shape` 接口的 `area` 改成不写 `public`，看看编译器在哪里报错；再改回来，把 `Circle` 的 `public override` 改成 `override`，又会怎样？
4. 写一个 class `Inventory`，用 `public var count` 加私有 setter 表示库存，只能通过 `add` 和 `remove` 方法修改；`remove` 在库存不足时抛出异常。
5. 回顾一个你写过的 Kotlin 库或模块，列出其中哪些声明在 Scoop 里应该保持 `internal`。
