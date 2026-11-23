# 第 18 章　注解与编译期能力

在 Kotlin/JVM 上，很多“框架级”的功能都建立在**运行期反射**之上：ORM 读取 `@Column` 注解把字段映射到数据库列，序列化库遍历类的属性生成 JSON，依赖注入框架按类型查找构造器。程序运行起来之后，再去“看”自己的类型长什么样。

Scoop 没有运行期反射（第 1 章）。取而代之的是一组**编译期能力**：类型的结构在编译时就已经确定，编译器把它整理成普通的描述数据交给程序；注解是这些描述的一部分；编码、解码这类机械的代码由编译期运行的代码生成器写出；配置文件、版本号这类构建时就知道的东西，可以直接嵌入可执行文件。

本章介绍：

- 用 `typeInfo<T>()` 取得类型的静态描述；
- 声明、使用和读取自定义注解；
- 用 `@GenerateWith` 请求生成编码和解码方法，为第 33 章的 JSON 做铺垫；
- 用 `includeStr`、`includeBytes`、`includeDir` 把文件嵌入程序，用 `env` 读取构建时的环境变量；
- 用 `SourceLocation` 取得调用处的源码位置；
- 文档注释的写法。

## 18.1　静态类型描述

```scoop
{{#include ../../examples/ch18/describe.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/describe.expected}}
```

`typeInfo<T>()` 返回类型 `T` 的描述入口 `TypeInfo<T>`。它属于核心库，不需要 import。常用的成员只有两个：

- `type` 是一个 `TypeRef`，代表这个类型本身。`displayName` 是给人看的名字；两个 `TypeRef` 用 `==` 比较时看的是完整的类型身份，所以 `Array<Long>` 和 `Array<Int>` 不相等。
- `describe()` 返回一层 `TypeDescription`，其中 `annotations` 是类型上的注解，`shape` 说明这个类型是什么“形状”。

`shape` 是一个 enum，`case` 匹配它就能拿到对应的结构信息：

| 分支 | 内容 |
| --- | --- |
| `TypeShape.Struct` | 按声明顺序排列的字段 `fields`、构造器、实现的接口 |
| `TypeShape.Enum` | 按声明顺序排列的 `variants`，每个 variant 的名字和 payload |
| `TypeShape.Class` | 基类、属性 `properties`、实际存储 `storage`、构造器、是否 final |
| `TypeShape.Interface`、`Object`、`Tuple`、`Unit` | 各自的父接口、属性或元素 |
| `TypeShape.Intrinsic` | `Int`、`String`、`Array` 等内建类型的类别 |
| `TypeShape.Function`、`Pointer` 等 | 函数签名、指针指向的类型 |

字段的名字是 `MemberName`：普通字段是 `MemberName.Named(名字)`，enum 里按位置声明的 payload 是 `MemberName.Positional(下标)`。字段的类型又是一个 `TypeRef`，可以继续 `describe()`；描述是一层一层惰性展开的，所以递归类型也没有问题。

注意 `describeType` 是一个普通的泛型函数，`typeInfo<T>()` 直接写在里面就能用。Scoop 的泛型是单态化的（第 17 章）：每种 `T` 都会生成一份专用代码，编译器在每一份里都知道 `T` 的真实类型，所以不需要 Kotlin 的 `inline` 加 `reified`。

静态描述能替代反射的一部分用途：遍历字段、读取注解、比较类型。但它**只是数据**：

- 不能按名字查找类型，也没有 `Class.forName` 一类的入口；
- 不能通过描述构造对象、调用方法或读写字段；
- 描述里没有方法列表；
- 私有成员也会出现在描述里，但这不会让它变得可以访问。

需要“根据类型结构生成代码”时，Scoop 的做法是在编译期生成（18.4），而不是在运行期根据描述去动态调用。

## 18.2　自定义注解

注解用 `annotation class` 声明，用法和 Kotlin 一样，写在声明前面：

```scoop
{{#include ../../examples/ch18/annotations.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/annotations.expected}}
```

先看声明的部分：

- `annotation class Table(val name: String)` 声明了一个带一个参数的注解。参数都是 `val`，可以有默认值，比如 `Column` 的 `nullable`。没有参数的注解可以省略括号，写成 `annotation class Marker`。
- 使用时参数可以按位置写，也可以按名字写：`@Column("email", nullable = true)`。
- 注解可以标在类型、字段、属性、函数、构造器、参数、enum variant 和 `typealias` 上。主构造器里的 `@Column("account_id") val id: Long` 标的是字段 `id`。
- 同一个位置默认只能出现一次同一个注解。`Tag` 前面的 `@Repeatable` 允许它重复，`Account` 上的两个 `@Tag` 会按源码顺序保留。

再看读取的部分。**注解本身没有任何运行期效果**，它只是被编译器记录进静态描述，程序通过 18.1 的描述读取它：

- `annotationKey<Table>()` 取得注解声明 `Table` 的“钥匙” `AnnotationKey`，用来指明要找的是哪个注解。它按声明身份比较，另一个也叫 `Table` 的注解不会被混淆。
- `findAnnotations(列表, key)` 从一组注解中筛出指定的那一种，返回 `Array<AnnotationInfo>`。类型的注解在 `description.annotations` 里，字段的注解在 `field.annotations` 里。
- `AnnotationInfo.arguments` 是按声明顺序排列的参数，**默认值已经补齐**：没有写 `nullable` 的 `@Column`，`arguments[1L]` 仍然存在，值为 `false`。每个参数的 `value` 是一个 `AnnotationValue`，要用 `case AnnotationValue.String(val text)`、`case AnnotationValue.Boolean(val flag)` 这样的分支取出具体的值。

注解只在你读的地方生效：`findAnnotations` 只看你给它的那个列表，不会沿着基类、属性的 getter 去找继承来的注解。

> **从 Kotlin 过来**
>
> Kotlin 的注解有保留策略 `@Retention`：`RUNTIME` 的注解可以在运行期通过 `KClass.annotations` 读到，`SOURCE` 的注解编译后就消失了。Scoop 没有这个区分，也没有运行期的注解对象：所有注解都在编译期记录进静态描述，程序只能通过 `typeInfo<T>()` 读到类型和成员上的注解。函数上的注解是合法的，但目前的描述里没有方法列表，普通程序读不到它们。
>
> Kotlin 的 kapt、KSP 这类通用的注解处理器在 Scoop 中也没有对应物。自定义注解不会触发任何代码。最接近的是 18.4 的 `@GenerateWith`：它请求随工具链发布的生成器，为类型已经声明的接口补齐缺少的方法。生成器只能填写这些方法的方法体，不能新增声明或改动别处的代码。

## 18.3　注解的规则

注解是**编译期的静态数据**，所以它的参数和用法都有严格的限制。

**参数必须是常量。** 参数的类型只能是 `Boolean`、`String`、`Char`、各种定宽整数、`Float`/`Double`、整型枚举（第 9 章）、另一个注解，以及这些类型的一维 `Array`。传入的值只能是字面量或者 `const val`：

```scoop
{{#include ../../examples/ch18/const_arg.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/const_arg.expected}}
```

普通的 `val` 不行，函数调用、字符串拼接等表达式也不行：

```scoop
{{#include ../../examples/ch18/argument_fail.scoop}}
```

```text
{{#include ../../examples/ch18/argument_fail.error}}
```

**不能重复，除非声明了 `@Repeatable`：**

```scoop
{{#include ../../examples/ch18/repeat_fail.scoop}}
```

```text
{{#include ../../examples/ch18/repeat_fail.error}}
```

**可以用 `@Target` 限定使用位置。** 不写 `@Target` 时注解可以用在任何支持的位置；写了以后只能用在列出的位置。`AnnotationTarget` 的取值包括 `Class`（class、struct、enum、interface、object）、`Field`、`Property`、`Function`、`Constructor`、`ValueParameter`、`EnumVariant`、`TypeAlias` 等：

```scoop
{{#include ../../examples/ch18/target_fail.scoop}}
```

```text
{{#include ../../examples/ch18/target_fail.error}}
```

`@Column` 只允许用在字段上，所以标在 struct 上报错，标在字段 `id` 上则没有问题。

**注解类不是普通的类。** 它不能被实例化，也不能有方法、继承其他类型或带泛型参数：

```scoop
{{#include ../../examples/ch18/instance_fail.scoop}}
```

```text
{{#include ../../examples/ch18/instance_fail.error}}
```

想要一个运行期可以使用的配置对象，就声明一个普通的 struct 或 class。

## 18.4　生成编码与解码

把值转换成 JSON 之类的外部格式，是反射最常见的用途。Scoop 用两个普通接口描述这件事，它们都在核心库里：

- `ValueEncoder<T>`：有一个方法 `encode(value: T, encoder: Encoder)`，把 `T` 的值写出去；
- `ValueDecoder<T>`：有一个方法 `decode(decoder: Decoder): T`，读出一个 `T`。

实现这两个接口的对象叫 **codec**，通常由类型的 companion object 来充当。这两个方法可以手写，但它们多半只是逐个字段地读写，相当机械。所以工具链附带了一个**代码生成器** `scoop.codec`：在 companion 上声明这两个接口，再用 `@GenerateWith` 指定由它生成，编译时生成器就会根据类型的结构写出 `encode` 和 `decode`：

```scoop
{{#include ../../examples/ch18/codec.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/codec.expected}}
```

`scoop.json` 不在单文件程序默认可用的库里，所以第一行用 `//! dep:` 声明了依赖（第 29 章）。程序里要注意这几点：

- `@GenerateWith("scoop.codec", ["ValueEncoder<User>", "ValueDecoder<User>"])` 标在 companion 上。第一个参数是生成器的名字，第二个参数列出要生成的接口，每一项都是完整的类型写法。`GenerateWith` 属于核心库，不需要 import。
- `public companion object : ValueEncoder<User>, ValueDecoder<User>` 没有花括号体，两个接口方法都还没有实现，正好交给生成器补齐：编码按字段的声明顺序写出一个 record；解码读出全部字段，再用具名实参调用主构造器。生成的方法和手写的方法一样要经过类型检查。
- `Json.encodeToString(ada)` 和 `Json.decodeFromString<User>(text)` 通过 `User` 的 companion 找到 codec。这要求 companion 是 `public` 的，因为 JSON 库在另一个 Cone 中（第 15 章）。
- `String?` 字段的值为 `None` 时，编码会省略这个字段；解码时缺少的字段使用声明里的默认值，所以 `{"name": "Grace"}` 也能解码。
- enum 编码成只有一个 key 的对象，key 是 variant 的名字：`{"Member":{"since":2024}}`。

`@GenerateWith` 只负责补齐缺少的方法，不会替类型添加接口，接口要自己写在 companion 的声明里。两个方向互相独立：可以只声明、只列出其中一个接口；companion 里已经手写的方法会被保留，生成器只生成剩下的。比如手写 `decode` 来校验输入，`encode` 仍然可以交给生成器。

`@Serialize` 是核心库提供的注解，用来调整生成的代码：

| 参数 | 作用 |
| --- | --- |
| `rename` | 外部使用的字段名或 variant 名，例如 `"e-mail"` |
| `required` | 为 `true` 时，解码要求输入中必须有这个 key |
| `emitNull` | 为 `true` 时，`None` 也写出来（JSON 中为 `null`），而不是省略 |
| `ignore` | 为 `true` 时，这个字段不参与编码和解码，解码时使用默认值 |

上例中 `cachedScore` 被忽略：编码结果里没有它，解码回来是默认值 `0`。

**每个字段的类型都要有 codec，而且在编译时就检查。** `Int`、`String`、`Boolean` 等基本类型，以及 `Option`、`Array`、`ArrayList`、tuple，核心库已经提供了 codec；你自己定义的类型要自己声明。上例的 `Role` 也声明了 companion，如果漏掉：

```scoop
{{#include ../../examples/ch18/codec_field_fail.scoop}}
```

下面摘录了报错中的主要几行，省略了位置：

```text
{{#include ../../examples/ch18/codec_field_fail.error}}
```

前两条错误指向 `User` 的 `roles` 字段，但没有 `E` 开头的编号：它们是生成器 `scoop.codec` 报告的，`note[N0003]` 注明了来源。代码生成器这类外部工具自己报告的问题，使用外部标识 `GENERATOR_DIAGNOSTIC`，而不是 Scoop 的规则编号。生成器没能写出方法，所以后面还跟着缺少方法的普通错误 `E1008`。这类问题不会拖到运行期才暴露。

**忘了写 `@GenerateWith`** 时，companion 声明了接口，却没有人提供方法，得到的就只是普通的“没有实现接口方法”：

```scoop
{{#include ../../examples/ch18/no_generate_fail.scoop}}
```

```text
{{#include ../../examples/ch18/no_generate_fail.error}}
```

所以在 codec 接口上看到 `E1008` 时，先检查 companion 上有没有 `@GenerateWith`，以及其中是否列全了接口。反过来，`@GenerateWith` 列出了 companion 并没有声明的接口时，报的是 `E1317`。

如果类型完全没有声明 codec，`Json.encodeToString(value)` 的报错就不那么直接了：

```scoop
{{#include ../../examples/ch18/no_codec_fail.scoop}}
```

```text
{{#include ../../examples/ch18/no_codec_fail.error}}
```

`encodeToString` 有两个重载：只有一个参数的那个要求 `T` 的 companion 实现 `ValueEncoder<T>`，`User` 不满足，编译器只好拿另一个重载 `encodeToString(value, codec)` 来报错。看到这条报错时，先检查类型有没有声明 `public companion object : ValueEncoder<…>`。

codec 也可以显式传入。这时 companion 不必是 `public`：

```scoop
{{#include ../../examples/ch18/explicit_codec.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/explicit_codec.expected}}
```

`scoop.codec` 只为“形状明确”的类型生成代码：struct、enum、tuple，以及没有基类的 final class。开放的 class、带基类的 class、需要特殊表示的类型，要手写 `encode`、`decode`。生成 `decode` 还有一条构造器规则：**主构造器必须是唯一可见的构造器**，因为生成的代码要用它来构造结果。类型有次构造器时，生成器会报 “automatic construction requires the primary constructor to be the only visible constructor”，并建议把这个构造入口改成 companion 上的具名工厂函数。只生成编码时没有这条限制。手写 codec、为泛型类型组合 codec、JSON 的完整用法，都留到第 33 章。

> **深入一点：查看生成的代码**
>
> 生成器是随工具链发布的独立程序，`scoop.codec` 对应 `scoop-codec-generator`。编译器把需要补齐的方法交给它，它查询类型的字段、注解和默认值，返回这些方法的方法体，编译器再像对待手写代码一样检查和编译它们。想看看生成了什么，可以让 `scoop build` 把生成的源码保存下来：
>
> ```sh
> scoop build codec.scoop --release --emit generated --dump-dir generated-src
> ```
>
> 结果在 `generated-src` 下以 Cone 标识命名的子目录里，文件名是 `generated.scoop`。这份代码是写给编译器的：局部变量都叫 `generated0` 这样的名字，也没有经过排版，但能看清每个字段是怎样读写的。

> **从 Kotlin 过来**
>
> 这套机制对应 kotlinx.serialization：`@Serializable` 对应“companion 声明 `ValueEncoder<T>`、`ValueDecoder<T>`，并标注 `@GenerateWith("scoop.codec", [...])`”，`@SerialName("x")` 对应 `@Serialize(rename = "x")`，`@Transient` 对应 `@Serialize(ignore = true)`。区别在于，kotlinx.serialization 依靠编译器插件为类生成序列化器，Scoop 的生成器只为你声明的接口填写方法体，生成的代码照常经过类型检查；而且编码和解码是两个独立的接口，可以只声明其中一个。

## 18.5　把文件嵌入程序

有些数据在构建时就确定了：帮助文本、默认配置、模板、图标。与其在运行期去找这些文件，不如在编译时把它们直接嵌入可执行文件：

```scoop
{{#include ../../examples/ch18/embed.scoop}}
```

`assets` 目录中有四个文件：`banner.txt`（内容 `Hello, Scoop!` 加换行）、`docs/help.txt`、`private/notes.txt` 和 `settings.json`。输出：

```text
{{#include ../../examples/ch18/embed.expected}}
```

这些函数在核心库的 `scoop.compiler` 包中，**需要显式 import**（`import scoop.compiler.*`，或逐个导入）：

| 函数 | 结果 |
| --- | --- |
| `includeStr(path)` | `String`：文件的全部文本，必须是合法的 UTF-8，换行原样保留 |
| `includeBytes(path)` | `Array<Byte>`：文件的原始字节 |
| `includeDir(path, include = [...], exclude = [...])` | `EmbeddedDir`：目录中匹配的文件 |

几条规则：

- **路径相对于调用所在的源码文件**，而不是执行命令时的当前目录。在 Cone 项目里，`src/main.scoop` 要用 `"../assets/banner.txt"` 才能找到 Cone 根目录下的 `assets`。
- **文件必须位于所属 Cone 内。** 项目的边界是 `Cone.toml` 所在目录；单文件程序的边界是这个文件所在的目录。越界在编译时报错，经由符号链接越界也不行。
- `includeDir` 的 `include` 和 `exclude` 是 glob 模式：`*.txt` 只匹配根目录的文件，`**/*.txt` 匹配任意层子目录，`private/**` 匹配 `private` 下的全部文件。多个 `include` 取并集，然后去掉 `exclude` 匹配的部分。上例中 `settings.json` 不匹配 `**/*.txt`，`private/notes.txt` 被排除。
- `EmbeddedDir.files` 按路径排序，每一项有 `path` 和 `bytes`；`bundled["docs/help.txt"]` 按精确路径查找，返回 `Array<Byte>?`，找不到是 `None`。
- **参数必须在编译时确定**：字符串字面量或 `const val`。

文件内容在编译时读入，此后程序运行时不再访问这些文件。修改了资源文件，要重新构建才能生效。

不 import 就调用，会得到 “unknown function” 错误：

```scoop
{{#include ../../examples/ch18/missing_import_fail.scoop}}
```

```text
{{#include ../../examples/ch18/missing_import_fail.error}}
```

路径来自普通变量时，编译器在编译时无法知道它的值：

```scoop
{{#include ../../examples/ch18/path_fail.scoop}}
```

```text
{{#include ../../examples/ch18/path_fail.error}}
```

路径越出 Cone 的边界时：

```scoop
{{#include ../../examples/ch18/outside_fail.scoop}}
```

下面只摘录错误编号和说明片段，省略与本机目录有关的实际路径：

```text
{{#include ../../examples/ch18/outside_fail.error}}
```

## 18.6　构建时的环境变量

`env(name)` 读取**编译器进程**的环境变量，把结果嵌入程序，适合注入版本号、构建渠道这类信息：

```scoop
{{#include ../../examples/ch18/env.scoop}}
```

没有设置这两个变量时，输出是：

```text
{{#include ../../examples/ch18/env.expected}}
```

- `env` 返回 `String?`：变量不存在是 `None`，设置为空串是 `Some("")`。后者不会触发 `?:` 的默认值。
- 名字**必须以 `SCOOP_` 开头**（区分大小写）。这样一来，构建时只有专门为程序准备的变量会被嵌入，`HOME`、`PATH` 这类与构建机器有关的信息不会意外地进入产物。
- 值在编译时确定。下面先用 `SCOOP_BOOK_CHANNEL=beta` 构建，再用另一个值运行编译出来的程序，输出仍然是 `channel=beta`：

```sh
SCOOP_BOOK_CHANNEL=beta scoop build env.scoop --release
SCOOP_BOOK_CHANNEL=stable ./target/aarch64-apple-darwin/release/env
```

```text
channel=beta
SCOOP_BOOK_UNSET_EXAMPLE is not set
```

需要在**运行时**读取环境变量，用平台库 `scoop.platform` 的 API（第 31 章）。

读取不以 `SCOOP_` 开头的变量是编译错误，而不是返回 `None`：

```scoop
{{#include ../../examples/ch18/env_name_fail.scoop}}
```

```text
{{#include ../../examples/ch18/env_name_fail.error}}
```

`includeStr`、`includeBytes`、`includeDir` 和 `env` 都在编译时求值，程序里没有对应的运行期函数，所以不能写 `::includeStr` 这样的函数引用（第 7 章）。

## 18.7　`SourceLocation`：我在哪一行

日志、断言和测试框架常常需要报告“问题出在哪一行”。`currentSourceLocation()` 返回它所在位置的源码信息，结果是一个 struct：

| 字段 | 类型 | 内容 |
| --- | --- | --- |
| `file` | `String` | 源码文件，见下文 |
| `line`、`column` | `Long` | 行号和列号，从 1 开始 |
| `functionName` | `String` | 所在函数的名字 |
| `typeName` | `String` | 所在类型的名字，不在任何类型中时为空串 |

它最有用的地方是和默认参数配合，取得**调用者**的位置：

```scoop
{{#include ../../examples/ch18/location.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/location.expected}}
```

`log` 的参数 `location` 的默认值是 `currentSourceLocation()`。默认值在调用处求值（第 6 章），所以 `main` 第 19 行调用 `log("hello")` 时，得到的就是第 19 行，而不是 `log` 函数内部的位置。

要点：

- **转发时要继续传递。** `warn` 自己也声明了带默认值的 `location` 参数，再把它传给 `log`，所以报告的是 `main` 中调用 `warn` 的第 20 行。如果 `warn` 写成 `fun warn(message: String) = log(f"warning: ${message}")`，报告的就是 `warn` 函数内部的那一行。
- `file` 不是你电脑上的绝对路径，而是可重现的“逻辑路径”：项目中形如 `group:name:version/src/main.scoop`，单文件程序固定为 `scoop:single-file:0.0.0/main.scoop`。因此构建结果不会因为源码放在哪个目录而改变。
- 这些信息在编译时就已确定，不依赖调试信息，`--release` 下同样可用。
- 只能直接调用，不能取函数引用：

```scoop
{{#include ../../examples/ch18/reference_fail.scoop}}
```

```text
{{#include ../../examples/ch18/reference_fail.error}}
```

通过函数引用间接调用时，“调用处”就不存在了，所以编译器干脆禁止这种写法。第 30 章的测试断言正是用这个方法报告失败的位置。

## 18.8　文档注释

文档注释写在声明前面，有块形式 `/** ... */` 和行形式 `/// ...` 两种，正文是 Markdown：

```scoop
{{#include ../../examples/ch18/docs.scoop}}
```

输出：

```text
{{#include ../../examples/ch18/docs.expected}}
```

- 第一段是摘要，会显示在 API 文档的列表里。
- 行首的标签说明具体的部分：`@param`、`@return`、`@property`、`@receiver`、`@constructor`、`@throws`、`@see`、`@since`，和 KDoc 基本一致。
- `[Rect.area]`、`[factor]` 这样的方括号引用会链接到对应的符号。
- `/***` 开头的块注释、`////` 开头的行注释，以及 `//!` 都是普通注释，不是文档。
- 核心库的注解 `@DocHidden` 让声明不出现在生成的 API 文档中，`@DocAlias("resize")` 为它增加一个搜索关键词。它们只影响文档，不改变可见性和程序行为。

文档注释对普通编译没有任何影响：引用写错、标签不认识，`scoop check` 都不会报错。这些问题由 `scoop doc` 在生成文档时以警告的形式报告，见第 30 章。工具链安装时生成的离线 API 文档，就来自各个库源码中的文档注释。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop |
| --- | --- |
| `annotation class Table(val name: String)` | 相同 |
| `@Retention(RUNTIME)` + `KClass.annotations` | 没有保留策略；用 `typeInfo<T>().describe().annotations` 读取 |
| `@Target(AnnotationTarget.FIELD)` | `@Target([AnnotationTarget.Field])`，参数是数组 |
| `@Repeatable` | 相同 |
| `T::class`、`KClass<T>` | `typeInfo<T>()`、`TypeRef`，只读描述 |
| `inline fun <reified T>` | 普通 `fun <T>` 即可，单态化保证类型已知 |
| `Class.forName`、反射构造、反射调用 | 不支持 |
| kapt、KSP 注解处理器 | 没有通用的注解处理器；`@GenerateWith` 请求工具链附带的生成器补齐接口方法 |
| `@Serializable` | companion 声明 `ValueEncoder<T>`、`ValueDecoder<T>`，并标注 `@GenerateWith("scoop.codec", [...])` |
| `@SerialName("x")`、`@Transient` | `@Serialize(rename = "x")`、`@Serialize(ignore = true)` |
| 读取 resources 目录的资源文件 | `includeStr`、`includeBytes`、`includeDir`，编译时嵌入 |
| Gradle 生成的 `BuildConfig.VERSION` | `env("SCOOP_VERSION")`，编译时嵌入 |
| KDoc `/** */` | `/** */` 或 `///`，标签基本相同 |

## 常见误用

- **想在运行期按名字找到类型或调用方法**：Scoop 没有这种能力。用接口、`when` 或编译期生成的代码表达需要的行为。
- **用普通 `val` 或函数调用作为注解参数**：只能用字面量和 `const val`（18.3）。
- **以为注解会自动产生效果**：自定义注解只是数据，必须有代码通过 `typeInfo` 读取它才会起作用。
- **companion 声明了 codec 接口，却忘了 `@GenerateWith`**：没有人提供方法，报 `E1008`（18.4）。
- **companion 不是 `public`，或者字段类型没有 codec**：前者让 `Json.encodeToString(value)` 找不到 codec，后者由生成器在编译时报错（18.4）。
- **忘了 `import scoop.compiler.*`**：`includeStr`、`env` 等不在默认可用的名称中。
- **在 Cone 的 `src/main.scoop` 中写 `includeStr("assets/x.txt")`**：路径相对于源码文件，应写 `"../assets/x.txt"`。
- **用 `env` 读取运行时配置**：它读的是编译时的环境。运行时的环境变量用 `scoop.platform`。
- **转发日志函数时忘了传递 `location`**：记录到的会是中间函数的位置（18.7）。

## 小结

- Scoop 没有运行期反射；`typeInfo<T>()` 提供编译期整理好的只读类型描述：字段、variant、属性、构造器和注解。
- 注解用 `annotation class` 声明，参数只能是常量；`@Repeatable` 允许重复，`@Target` 限制位置。注解本身没有效果，通过类型描述和 `findAnnotations` 读取。
- 在 companion 上声明 `ValueEncoder<T>`、`ValueDecoder<T>`，再标注 `@GenerateWith("scoop.codec", [...])`，生成器就会在编译时写出编码和解码方法；`@Serialize` 调整字段名、必填和忽略等行为，缺少字段 codec 在编译时报错。
- `scoop.compiler` 包的 `includeStr`、`includeBytes`、`includeDir` 在编译时嵌入 Cone 内的文件，`env` 嵌入以 `SCOOP_` 开头的构建环境变量。
- `currentSourceLocation()` 配合默认参数可以取得调用者的源码位置；多层转发时每一层都要传递。
- 文档注释用 `/** */` 或 `///`，正文是 Markdown，由 `scoop doc` 处理。

## 练习

1. 写一个泛型函数 `fun <T> fieldCount(): Long`，返回 struct 的字段个数；对不是 struct 的类型返回 `-1L`。分别用 `Point`、`Int`、`(Int, String)` 测试。
2. 声明 `@Target([AnnotationTarget.Field]) annotation class Secret`，写一个泛型函数，打印 struct 中所有**没有**标 `@Secret` 的字段名。
3. 给 18.4 的 `User` 增加一个 `@Serialize(required = true) val id: Long` 字段，分别解码 `{"id": 1, "name": "Ada"}` 和 `{"name": "Ada"}`，观察第二种情况抛出的异常。
4. 用 `includeStr` 嵌入一个多行的帮助文本，写一个程序在收到 `--help` 参数时打印它。
5. 写一个 `check(condition: Boolean, location: SourceLocation = currentSourceLocation())`，条件为假时打印 `check failed at 行:列`，并在 `main` 中故意让它失败一次。
