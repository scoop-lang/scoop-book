# 第 4 章　字符串

从使用者的角度看，Kotlin 的 `String` 和 Scoop 的 `String` 很像：都是不可变的，都用 `+` 拼接，都可以在字面量里插入表达式。但两者的内部表示不同。Kotlin（JVM）的字符串是一串 UTF-16 编码单元，`length` 数的就是编码单元的个数；Scoop 的字符串是一串 **UTF-8 字节**，它刻意不提供含糊的 `length`，而是让你说清楚想数的是什么：字节、字符，还是用户眼中的“一个字”。

另一个区别会在第一天就碰到：Scoop 的插值字符串必须写成 `f"..."`，而且插值一律写 `${...}`。

本章介绍：

- 字符串和字符字面量、转义、raw 字符串；
- 为什么拼接大量文本时要用 `StringBuilder`；
- f-string 插值，以及普通字符串里的 `${}` 为什么原样保留；
- 字节、字符、字素簇、显示宽度这四种“长度”；
- 按位置读取字符、截取子串、遍历；
- `scoop.text` 里的常用文本函数，以及 `toIntOrNone` 这类数值解析函数；
- 字符串的比较，以及 Unicode 规范化带来的意外。

## 4.1　字面量

```scoop
{{#include ../../examples/ch04/literals.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/literals.expected}}
```

字符串字面量有两种：

- **普通字符串** `"..."`：支持转义 `\t`、`\b`、`\n`、`\r`、`\'`、`\"`、`\\`、`\$`，以及 Unicode 转义。Unicode 转义有两种写法：固定四位的 `\u96EA`，和花括号里写一到六位的 `\u{1F600}`。后者能表示 BMP 之外的字符（比如 emoji），不需要像 Java 那样拼一对代理项。
- **raw 字符串** `"""..."""`：可以跨行，不处理任何反斜杠转义，`\n` 就是反斜杠加字母 n。适合写 Windows 路径、正则表达式和大段文本。注意 raw 字符串会原样保留每一行开头的空格，上例第二行的四个空格就留在了结果里。

**字符**（`Char`）用单引号写，转义规则与普通字符串相同。一个 `Char` 是一个 **Unicode 标量值**——白话说，就是 Unicode 码表里的“一个编号”：`'A'`、`'雪'`、`'😀'` 都各是一个 `Char`。单引号里必须恰好是一个标量值，`''` 或 `'ab'` 都是编译错误。

`Char` 和 `String` 是两种不同的类型，双引号的 `"A"` 不能当 `Char` 用：

```scoop
{{#include ../../examples/ch04/char_fail.scoop}}
```

```text
{{#include ../../examples/ch04/char_fail.error}}
```

## 4.2　不可变的 `String` 与 `StringBuilder`

`String` 是不可变的引用类型：一旦创建，内容就不会再变。`+` 不会修改原字符串，而是生成一个新字符串。这和 Kotlin 完全一样，所以 `val` 的字符串既不能重新赋值，也不存在“原地追加”的方法：

```scoop
{{#include ../../examples/ch04/immutable_fail.scoop}}
```

```text
{{#include ../../examples/ch04/immutable_fail.error}}
```

`+` 的两边都必须是 `String`。Kotlin 允许 `"n = " + n` 把整数自动转成文本，Scoop 不允许：

```scoop
{{#include ../../examples/ch04/plus_fail.scoop}}
```

```text
{{#include ../../examples/ch04/plus_fail.error}}
```

要么写 `"n = " + n.toString()`，要么用下一节的 f-string `f"n = ${n}"`，后者更常用。

在循环里反复用 `+` 拼接，每一次都会复制之前的全部内容，文本越长越慢。这时应该用 `StringBuilder`：

```scoop
{{#include ../../examples/ch04/builder.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/builder.expected}}
```

- `StringBuilder()` 创建一个空的缓冲区；如果大致知道最终大小，可以传初始容量（单位是字节），如 `StringBuilder(1024L)`。
- `append` 接受 `String`、`Char`、`Boolean`、各种整数，以及任何实现了 `ToString` 的类型，并返回 builder 本身，所以可以连着写。
- `toString()` 复制出一个独立的 `String`。之后再修改 builder（比如 `clear()` 后重新追加），已经得到的 `result` 不受影响。

## 4.3　f-string：字符串插值

```scoop
{{#include ../../examples/ch04/fstring.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/fstring.expected}}
```

规则只有几条：

- **只有带 `f` 前缀的字符串才会插值**：`f"..."` 是单行版本，`f"""..."""` 是多行 raw 版本。
- 插值一律写 `${表达式}`，花括号里可以是任意表达式：变量、算术、属性访问、函数调用都行。
- 普通字符串里的 `${name}` **不是插值**，而是 6 个普通字符，原样输出（上例的 `plain: ${name}`）。
- 在单行 f-string 里想输出字面的 `$`，写 `\$`；单独的 `$` 和不跟在 `$` 后面的花括号也都是普通字符。f-string 的 raw 多行版本和普通 raw 字符串一样不处理反斜杠，所以 `C:\docs\${name}.txt` 中的 `\` 原样保留，`${name}` 照常插值。

Kotlin 的简写 `$name` 在 f-string 里是编译错误，编译器会直接告诉你改法：

```scoop
{{#include ../../examples/ch04/dollar_fail.scoop}}
```

```text
{{#include ../../examples/ch04/dollar_fail.error}}
```

### 为什么要加 `f` 前缀

Kotlin 的每个字符串字面量都会处理 `$`，Scoop 改成只有 `f` 前缀的字符串才插值，主要是为了避开两类常见问题。

第一类是**和 JSON 之类的文本打架**。JSON Schema 的 `"$schema"`、`"$ref"`，MongoDB 查询里的 `"$set"`，以及各种模板语言的 `${...}`，都含有 `$`。在 Kotlin 里写这些文本，要么把 `$` 转义，要么在 raw 字符串里写成 `${'$'}schema` 这样的绕法，一不小心就会把某段文字当成了插值。Scoop 的普通字符串从不插值，这类文本可以原样写进去；需要插值时再加 `f`，而且插值的地方一律带花括号，一眼就能分辨：

```scoop
{{#include ../../examples/ch04/json_dollar.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/json_dollar.expected}}
```

第二类是**简写 `$name` 的边界不明显**。Kotlin 的 `"$age+42"` 只会把 `age` 插进去，结果是 `30+42`，而不是 `72`；`"$user.name"` 也只插入 `user`，后面的 `.name` 原样留下。这些写法都能正常编译，错误往往要到看见输出时才被发现。Scoop 只接受 `${...}`：花括号里是什么，插入的就是什么，`f"${age + 42}"` 得到 `72`。f-string 里写出 `$name` 这种简写，编译器会直接报错（见上例），不会悄悄生成一个意外的结果。

插入的值必须实现 `ToString` 接口。`Int`、`Double`、`Boolean`、`Char`、`String` 等基本类型都实现了；你自己定义的类型要显式实现（第 8 章）。否则会得到这样的错误：

```scoop
{{#include ../../examples/ch04/tostring_fail.scoop}}
```

```text
{{#include ../../examples/ch04/tostring_fail.error}}
```

> **深入一点：f-string 做了什么**
>
> 编译器把 `f"a ${x} b ${y}"` 展开成“依次求值 `x`、转成文本，再求值 `y`、转成文本，最后拼起来”，效果等价于用 `StringBuilder` 逐段 `append`。各段严格按从左到右的顺序求值；如果某个表达式抛出异常，后面的段就不会再执行。也因为它是运行期拼接，f-string 不能用于 `const val`，即使里面没有任何插值。

> **从 Kotlin 过来**
>
> Kotlin 的 `"Hello, $name"` 搬到 Scoop 里**不会报错**，只是不会插值。移植代码时，搜索所有含 `$` 的字符串字面量，补上 `f` 前缀并把 `$name` 改成 `${name}`。下面的程序演示了这个差别：

```scoop
{{#include ../../examples/ch04/kotlin_dollar.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/kotlin_dollar.expected}}
```

前两行在 Kotlin 里都会输出 `Hello, Ada`，在 Scoop 里都原样输出。

## 4.4　四种“长度”

“这个字符串有多长”在 Unicode 下至少有四种合理的答案：

| 单位 | 白话解释 | 怎么得到 |
| --- | --- | --- |
| UTF-8 字节 | 字符串在内存、文件、网络中占多少字节 | `text.byteLength`（core） |
| Unicode 标量（`Char`） | Unicode 码表里的编号有几个 | `text.charLength`（core） |
| 字素簇 | 用户眼中的“一个字”有几个，比如带声调的字母、带肤色的 emoji | `graphemes(text).size`（`scoop.charset`） |
| 显示宽度 | 在等宽终端里占几列，中文、emoji 一般占两列 | `unicodeScalarWidth(c)`（`scoop.charset`，按单个字符） |

下面的程序把四种长度并排打印出来：

```scoop
{{#include ../../examples/ch04/lengths.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/lengths.expected}}
```

逐行看：

- `cat`：纯 ASCII，四种长度都相同。这也是为什么只处理英文时很难发现长度用错了。
- `Ada 雪`：`雪` 在 UTF-8 中占 3 个字节，所以字节数是 7；它在终端里占两列，所以宽度是 6。
- `e\u0301`：字母 `e` 后面跟一个“组合用尖音符”（U+0301），显示出来是一个 `é`。它是 **2 个** `Char`、但只是 **1 个**字素簇。
- `👍🏽`：竖大拇指加一个肤色修饰符，2 个 `Char`，1 个字素簇，8 个字节。把两个字符各自的宽度加起来得到 4 列，而实际终端只显示 2 列——这说明逐字符累加宽度只是近似值。

怎么选：

- 和存储、协议、文件打交道（缓冲区大小、`Content-Length`）用 `byteLength`。它是 O(1) 的。
- 程序内部按字符处理文本（遍历、截取、查找）用 `charLength` 和本章后面的标量索引。它需要从头扫描一遍字符串，是 O(n) 的，在循环里反复调用要当心。
- 面向用户的“字数”、光标移动、按“字”截断，用字素簇。
- 终端排版对齐用显示宽度。`unicodeScalarWidth` 只给出单个字符的列数（控制字符返回 -1），带修饰符的 emoji 等组合序列需要按字素簇判断，完整的终端排版策略由 `scoop.readline` 负责。

`graphemes`、`unicodeScalarWidth` 属于独立的 `scoop.charset` 库，不在默认的 core 里。单文件程序在开头用 `//! dep: scoop:scoop.charset:0.1.0` 声明依赖，再 `import scoop.charset.*`；在 Cone 项目里则写进 `Cone.toml` 的依赖表（第 29 章）。

> **从 Kotlin 过来**
>
> Kotlin 的 `"😀".length` 是 2，因为它数的是 UTF-16 编码单元；Scoop 里没有 `length`，`"😀".charLength` 是 1，`byteLength` 是 4。Kotlin 代码里凡是用到 `length` 的地方，移植时都要想一想它原本想数的是哪一种。

### 字节层面的转换

`toByteArray()` 得到 UTF-8 字节的只读快照；反方向有三种解码函数，区别在于遇到非法 UTF-8 时怎么办：`String.fromUtf8` 抛出 `CharacterCodingException`，`String.fromUtf8OrNone` 返回 `None`，`String.fromUtf8Lossy` 把非法部分替换成 U+FFFD（显示为 �）。

```scoop
{{#include ../../examples/ch04/bytes.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/bytes.expected}}
```

`Byte` 是有符号的，`0xE9` 这样大于 127 的字节读出来是负数，所以打印前用 `toUByte()` 转成无符号数。GBK 等其他编码的转换由 `scoop.charset` 的 `Charset` 负责。

## 4.5　按位置读取：标量索引

```scoop
{{#include ../../examples/ch04/access.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/access.expected}}
```

String 上按位置读取的 API 都以 **Unicode 标量**为单位、用 **`Long`** 计数：

- `getCharAt(i)`：第 `i` 个字符，从 `0L` 开始。
- `slice(start, endExclusive)`：取半开区间 `[start, endExclusive)` 的子串。`slice(n, n)` 合法，得到空串。
- `for (c in text)`：按顺序遍历每个 `Char`。String 实现了 `Iterable<Char>`。
- `toCharArray()` / `toMutableCharArray()`：复制出一份字符数组。修改可写数组不会影响原字符串，改完可以用 `String.fromChars(...)` 编回字符串。
- `Char.code` 返回标量编号（`Int`），`Int.toChar()` 反过来把编号变回 `Char`；编号不合法时抛出 `IllegalArgumentException`。`Char` 不能直接做加减，`'a' + 1` 要写成 `(a.code + 1).toChar()`。

索引越界时，`getCharAt` 和 `slice` 抛出 `IndexOutOfBoundsException`：

```scoop
{{#include ../../examples/ch04/bounds.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/bounds.expected}}
```

Scoop **没有** `text[i]` 下标，也没有 `length` 属性：

```scoop
{{#include ../../examples/ch04/index_fail.scoop}}
```

```text
{{#include ../../examples/ch04/index_fail.error}}
```

这是有意为之。UTF-8 中每个字符占 1 到 4 个字节，找到第 `i` 个字符需要从头扫描，`getCharAt` 最坏是 O(n)。写成 `text[i]` 会让人误以为它和数组下标一样是常数时间，在循环里写 `for (i in 0L until text.charLength) text.getCharAt(i)` 就成了 O(n²)。需要逐个处理字符时，直接用 `for (c in text)`；需要反复随机访问时，先 `toCharArray()` 一次。

索引的类型必须是 `Long`，`Int` 不会自动转换（第 3 章）：

```scoop
{{#include ../../examples/ch04/int_index_fail.scoop}}
```

```text
{{#include ../../examples/ch04/int_index_fail.error}}
```

## 4.6　常用文本函数：`scoop.text`

core 里的 `String` 只提供最基础的能力。`trim`、`split`、`replace` 这些日常函数以扩展函数的形式放在标准库的 `scoop.text` 包中，**需要先 import**：

```scoop
{{#include ../../examples/ch04/no_import_fail.scoop}}
```

```text
{{#include ../../examples/ch04/no_import_fail.error}}
```

看到 “type `String` has no method …” 时，先检查是不是忘了 `import scoop.text.*`。导入之后：

```scoop
{{#include ../../examples/ch04/text_api.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/text_api.expected}}
```

按用途归类：

| 用途 | 函数 |
| --- | --- |
| 去空白 | `trim()`、`trimStart()`、`trimEnd()`；也可以传入判断函数，如 `trim { c -> c == '#' }` |
| 判断 | `isBlank()`、`isNotBlank()`、`contains`（也可以写 `"Love" in value`）、`startsWith`、`endsWith` |
| 查找 | `indexOf`、`lastIndexOf`，返回标量索引，找不到返回 `-1L` |
| 截取 | `substring`、`substringBefore`、`substringAfter`、`removePrefix`、`removeSuffix` |
| 拆分 | `split(分隔符)` 返回 `List<String>`，空段会保留；`lines()` 同时识别 `\n` 和 `\r\n` |
| 替换 | `replace`、`replaceFirst` |
| 填充与重复 | `padStart`、`padEnd`、`repeat` |
| 大小写 | `uppercaseAscii()`、`lowercaseAscii()`，只转换 ASCII 字母 |

几点说明：

- 这些函数接受字符串或 `Char` 两种参数，例如 `split(',')` 和 `split(",")` 都可以。
- 所有位置和计数参数仍然是 `Long`：`padStart(3L, '0')`、`repeat(3L)`。
- 大小写转换刻意只处理 ASCII，因为完整的 Unicode 大小写映射要考虑上下文（例如德语 `ß` 转大写会变成两个字母）。需要完整转换时，用 `scoop.charset` 的 `unicodeUppercase`、`unicodeLowercase` 和 `unicodeCasefold`。
- 把列表拼成字符串的 `joinToString` 属于集合函数，在 `scoop.collections` 包里，要另外 import（第 22 章）。

## 4.7　数值解析与格式化

把文本变成数字，同样用 `scoop.text` 里的函数：

```scoop
{{#include ../../examples/ch04/parse.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/parse.expected}}
```

每种数值类型都有成对的两个函数，这是 Scoop 库里通用的命名约定：

- **`toIntOrNone()`**：解析失败时返回 `None`，成功时返回 `Some(值)`。它的返回类型是 `Int?`，也就是 `Option<Int>`。最常见的用法是紧跟一个 `?:` 给出默认值：`"80x".toIntOrNone() ?: 80`。`Option` 的完整用法见第 12 章。
- **`toInt()`**：解析失败时抛出 `NumberFormatException`。适合“输入必须合法，不合法就是程序错误”的场合。

类似的还有 `toLongOrNone`、`toDoubleOrNone`、`toFloatOrNone`、`toBooleanStrictOrNone`，以及无符号的 `toUIntOrNone` 等。名字以 `OrNone` 结尾的函数，在全书和所有标准库中都表示“正常的失败返回 `None`，而不是抛异常”。

需要注意：

- 解析是严格的：`" 42"` 带前导空格就会失败，先 `trim()` 再解析。
- 整数解析可以指定进制：`"ff".toIntOrNone(16)`。
- `toBooleanStrict` 只接受 `"true"` 和 `"false"`。

反方向，数值的 `toString()` 得到十进制文本，`toString(radix)` 按指定进制格式化（`255.toString(16)` 是 `ff`）。更复杂的格式（补零、对齐）可以组合 `padStart` 和 f-string 完成。

> **从 Kotlin 过来**
>
> Kotlin 的 `toIntOrNull()` 在 Scoop 里叫 `toIntOrNone()`：Scoop 没有 `null`，“没有值”用 `None` 表示。返回值的用法和 Kotlin 几乎一样，`?:` 照常工作。

## 4.8　比较与相等

```scoop
{{#include ../../examples/ch04/compare.scoop}}
```

输出：

```text
{{#include ../../examples/ch04/compare.expected}}
```

- `==` 比较内容。分别构造、内容相同的两个字符串相等。不要用 `===` 比较字符串：它比较的是“是不是同一个对象”，而内容相同的字符串是否共享同一个对象，Scoop 不作任何保证。
- `<`、`>`、`compareTo` 按 Unicode 标量编号逐个比较（字典序）。这是机器的顺序，不是人类语言的排序习惯：大写字母的编号都小于小写字母，所以 `"Zebra" < "apple"`。

最后两行揭示了一个容易踩的坑。`é` 在 Unicode 中有两种写法：一个预组合字符 U+00E9，或者 `e` 加组合尖音符 U+0301。它们显示得一模一样，但 `charLength` 不同，`==` 也不相等，因为 Scoop 不会自动做 **Unicode 规范化**（把等价的不同写法统一成同一种）。比较用户输入的用户名、文件名之类的文本时，先用 `scoop.charset` 的 `normalizeNfc` 统一成 NFC 形式再比较。

## 从 Kotlin 过来：字符串对照表

| Kotlin | Scoop |
| --- | --- |
| `"Hello, $name"` | `f"Hello, ${name}"` |
| `"Total: ${a + b}"` | `f"Total: ${a + b}"` |
| `"""raw $x"""` | `f"""raw ${x}"""`；不插值时写 `"""..."""` |
| `"n = " + n` | `"n = " + n.toString()` 或 `f"n = ${n}"` |
| `s.length` | `s.charLength`（字符）或 `s.byteLength`（字节） |
| `s[i]` | `s.getCharAt(i)`，`i` 是 `Long` |
| `s.substring(a, b)` | `s.slice(a, b)`，或导入 `scoop.text` 后用 `substring` |
| `s.trim()`、`s.split(",")` | 相同，但要 `import scoop.text.*` |
| `s.uppercase()` | `s.uppercaseAscii()`，或 `scoop.charset` 的 `unicodeUppercase(s)` |
| `s.toIntOrNull()` | `s.toIntOrNone()` |
| `s.isEmpty()` | `s == ""` 或 `s.byteLength == 0L` |
| `buildString { append(...) }` | `StringBuilder()` 加 `append`，最后 `toString()` |
| `'a' + 1` | `('a'.code + 1).toChar()` |

## 常见误用

- **普通字符串里写 `$name` 或 `${name}` 期望插值**：只有 `f"..."` 才插值，普通字符串不报错、原样输出。
- **用 `+` 拼接字符串和数字**：`+` 两边都必须是 `String`，改用 f-string。
- **把 `charLength` 当作显示宽度或“字数”**：中文、emoji、组合字符都会让它和用户看到的不一致（4.4）。
- **在循环里用 `getCharAt(i)` 遍历**：每次调用都要从头扫描，改用 `for (c in text)` 或先 `toCharArray()`。
- **用 `Int` 做索引**：容器和字符串的索引都是 `Long`，写 `0L`。
- **忘了 `import scoop.text.*`**：`trim`、`split`、`toIntOrNone` 等都在这个包里。
- **直接比较来源不同的 Unicode 文本**：先 `normalizeNfc` 再比较。

## 小结

- `String` 是不可变的 UTF-8 文本；大量拼接用 `StringBuilder`。
- 普通字符串支持转义，`"""..."""` 是不处理转义的 raw 字符串；`Char` 是一个 Unicode 标量值。
- 只有 `f"..."` / `f"""..."""` 插值，插值必须写 `${...}`，插入的值必须实现 `ToString`。
- “长度”有四种：`byteLength`、`charLength`、字素簇、显示宽度；后两种在 `scoop.charset` 中。
- 按位置读取用 `getCharAt`、`slice`，单位是标量、类型是 `Long`；没有 `s[i]` 和 `length`。
- 日常文本函数在 `scoop.text`；`toXxxOrNone` 解析失败返回 `None`，`toXxx` 抛出 `NumberFormatException`。
- `==` 比较内容，但不会做 Unicode 规范化。

## 练习

1. 写一个程序，打印 `"Hello, 世界! 👋"` 的 `byteLength`、`charLength` 和字素簇数量，先自己预测结果再运行。
2. 用 `split` 和 `toIntOrNone` 解析 `"3,14,x,15,9"`，跳过无法解析的项，用 f-string 打印剩下数字的和。
3. 写函数 `fun reverse(text: String): String`，用 `StringBuilder` 按字符反转字符串。用 `"e\u0301x"` 测试它，观察结果中的尖音符跑到了哪里，再用 `graphemes` 改写成按字素簇反转。
4. 写一个函数，接收一组名字和分数，用 `padEnd` 和 `padStart` 打印出左对齐名字、右对齐分数的表格。如果名字里有中文，表格还对齐吗？为什么？
