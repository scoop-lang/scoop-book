# 第 3 章　变量、数值与基本类型

变量和数字是任何语言里最先接触的东西。Scoop 在这方面看上去和 Kotlin 几乎一样：`val` 和 `var`、`Int` 和 `Long`、`Double` 和 `Boolean`，写法都没变。但有几处细节和 Kotlin 不同，而且恰好是 Kotlin 程序员最容易“凭手感”写错的地方：

- 不同数值类型之间**完全没有隐式转换**，`Int` 加 `Long` 是编译错误；
- 整数溢出时**回绕**，不抛异常；
- 数组、列表的 `size` 和下标都是 **`Long`**，不是 `Int`；
- 局部变量必须在声明时初始化。

本章介绍：

- `val` / `var` 与类型推断；
- 整数类型、字面量写法，以及字面量怎样适配目标类型；
- 显式类型转换；
- 整数运算的规则：回绕、除法、位运算；
- `Float` / `Double`，以及 NaN 的比较规则；
- `Boolean` 和 `Char`；
- 为什么容器的下标是 `Long`；
- 反引号标识符。

## 3.1　`val` 与 `var`

```scoop
{{#include ../../examples/ch03/variables.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/variables.expected}}
```

（`f"...${name}..."` 是 Scoop 的字符串插值写法，第 4 章详细介绍。）

规则和 Kotlin 一样：

- `val` 声明**不可重新赋值**的绑定，`var` 声明可以重新赋值的绑定。
- 类型可以省略，由初始值推断：`val name = "Ada"` 的类型是 `String`，`var score = 0` 的类型是 `Int`。也可以显式写出，如 `val ratio: Double = 0.75`。
- 类型一旦确定就不会变。`score` 是 `Int`，之后只能赋给它 `Int`。
- `+=`、`-=` 等复合赋值和 `++`、`--` 都可以用在 `var` 上。
- 顶层（函数外面）也可以声明 `val` 和 `var`，比如这里的 `title` 和 `rounds`。
- `const val` 声明**编译期常量**：值必须是字面量或由其他常量算出来的结果，而且必须写明类型。它只能放在顶层、`object` 或 companion object 里（后两者见第 13 章）。

给 `val` 重新赋值是编译错误：

```scoop
{{#include ../../examples/ch03/reassign_fail.scoop}}
```

```text
{{#include ../../examples/ch03/reassign_fail.error}}
```

### 局部变量必须当场初始化

Kotlin 允许先声明、后赋值：

```kotlin
val answer: Int
answer = 42
```

Scoop 不允许。局部的 `val` 和 `var` 都必须在声明时给出初始值：

```scoop
{{#include ../../examples/ch03/deferred_fail.scoop}}
```

```text
{{#include ../../examples/ch03/deferred_fail.error}}
```

这是一个语法错误，报错位置在第 3 行（编译器读到 `answer` 时还在等第 2 行的 `=`）。改写的方式通常是把计算初始值的逻辑写成一个表达式：`val answer = if (ok) 42 else 0`（`if` 是表达式，见第 5 章）。

同一个作用域里也不能用同一个名字声明两次变量，哪怕类型不同；编译器会报 “`x` is already declared in this scope”。

> **从 Kotlin 过来**
>
> Kotlin 的 `lateinit var` 在 Scoop 里**永久不支持**。需要“稍后才有值”的变量，写成 `var x: T? = None`（`Option`，见第 12 章），用到时显式处理“还没有值”的情况。

## 3.2　整数类型

Scoop 有八种整数类型，四种有符号、四种无符号：

| 宽度 | 有符号 | 无符号 | 等价的别名 |
| --- | --- | --- | --- |
| 8 位 | `Int8` | `UInt8` | `Byte` / `UByte` |
| 16 位 | `Int16` | `UInt16` | `Short` / `UShort` |
| 32 位 | `Int` | `UInt` | `Int32` / `UInt32` |
| 64 位 | `Long` | `ULong` | `Int64` / `UInt64` |

“等价的别名”指两个名字是同一个类型，比如 `Byte` 和 `Int8` 完全可以互换，报错信息里可能出现其中任何一个。日常代码用 Kotlin 风格的 `Byte`、`Short`、`Int`、`Long` 即可；定宽名字主要用在和 C 交互、读写二进制格式的地方。

`Int` 在所有平台上都是 32 位，`Long` 都是 64 位，不随 CPU 变化。Scoop 没有“和指针一样宽”的整数类型。

```scoop
{{#include ../../examples/ch03/integers.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/integers.expected}}
```

整数字面量的写法：

- 十进制 `42`、十六进制 `0xFF`、二进制 `0b1010`。**没有八进制**。
- `_` 可以放在两个数字之间作分隔：`3_000_000_000`。
- 后缀 `L` 表示 `Long`，`u` 表示无符号，`uL` / `UL` 表示 `ULong`。
- 没有后缀时，默认是 `Int`；值超出 `Int` 范围就自动成为 `Long`。所以上例里 `large` 的类型是 `Long`。

每种整数类型都有 `MIN_VALUE` 和 `MAX_VALUE` 两个常量，例如 `Int.MAX_VALUE`、`Byte.MIN_VALUE`。

### 字面量会适配目标类型

字面量本身并没有“固定”的类型。当上下文已经确定需要哪种整数时，字面量会直接按那种类型处理，只要值放得下：

```scoop
{{#include ../../examples/ch03/literal_fit.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/literal_fit.expected}}
```

`val total: Long = 5` 不需要写 `5L`；`val b: Byte = 100` 也不需要转换。但有两条限制。

第一，值必须放得下。`Byte` 的范围是 -128 到 127：

```scoop
{{#include ../../examples/ch03/byte_range_fail.scoop}}
```

```text
{{#include ../../examples/ch03/byte_range_fail.error}}
```

第二，有符号和无符号不互相适配：没有 `u` 后缀的字面量不能当作无符号数，带 `u` 的字面量也不能当作有符号数。

```scoop
{{#include ../../examples/ch03/unsigned_fail.scoop}}
```

```text
{{#include ../../examples/ch03/unsigned_fail.error}}
```

改成 `5u` 就可以了。

注意“适配”只对**字面量**生效。一个已经有类型的变量，不会因为目标是另一种整数就自动转换，这正是下一节的内容。

## 3.3　没有隐式转换

在 Kotlin 里，`Int` 和 `Long` 混合运算是可以的，`intValue + longValue` 的结果是 `Long`。Scoop 不做这种提升：**二元运算的两边必须是同一种类型**。

```scoop
{{#include ../../examples/ch03/mix_fail.scoop}}
```

```text
{{#include ../../examples/ch03/mix_fail.error}}
```

比较也一样，`a > b`、`a == b` 两边类型不同就报错。赋值时同样不会自动转换，即使是从窄类型赋给宽类型，或者反过来：

```scoop
{{#include ../../examples/ch03/assign_long_fail.scoop}}
```

```text
{{#include ../../examples/ch03/assign_long_fail.error}}
```

整数字面量也不会适配成浮点数，`1` 不能当 `1.0` 用：

```scoop
{{#include ../../examples/ch03/double_literal_fail.scoop}}
```

```text
{{#include ../../examples/ch03/double_literal_fail.error}}
```

需要换类型时，调用显式转换函数。每种整数都有 `toByte()`、`toShort()`、`toInt()`、`toLong()`、`toUByte()`、`toUShort()`、`toUInt()`、`toULong()`，以及 `toFloat()`、`toDouble()`：

```scoop
{{#include ../../examples/ch03/conversions.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/conversions.expected}}
```

整数之间的转换**永远不会失败、不会抛异常**。目标类型装不下时，只保留低位，再按目标类型解释：

- `5_000_000_000L.toInt()` 得到 `705032704`（只保留低 32 位）；
- `300.toByte()` 得到 `44`（300 − 256）；
- `(-1).toUInt()` 得到 `4294967295`（32 个 1 按无符号解释）。

所以把 `Long` 缩成 `Int` 之前，要自己确认值在范围内。

> **为什么这么严格？**
>
> 隐式提升看起来方便，但它让“这个表达式到底是什么类型”变得需要推理，而且一些情况下结果和直觉不符（比如有符号和无符号混合比较）。Scoop 的选择是让每次类型变化都在代码里可见：多写一个 `toLong()`，换来的是读代码时不需要猜。

## 3.4　整数运算

```scoop
{{#include ../../examples/ch03/arithmetic.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/arithmetic.expected}}
```

**溢出时回绕。** `Int.MAX_VALUE + 1` 得到 `Int.MIN_VALUE`，不报错也不抛异常。这和 Kotlin 在 JVM 上的行为一致。如果担心溢出，先转成更宽的类型再算，比如第三行先 `toLong()` 再加。

**除法向零截断。** `7 / 2` 是 `3`，`-7 / 2` 是 `-3`（不是 `-4`）。`%` 的结果和被除数同号，所以 `-7 % 2` 是 `-1`。整数除以零抛出 `ArithmeticException`（`try`/`catch` 见第 19 章）。

**位运算用中缀函数。** 和 Kotlin 一样，Scoop 没有 `&`、`|`、`<<` 这类符号，而是用 `and`、`or`、`xor`、`inv()`、`shl`、`shr`、`ushr`。和 Kotlin 不同的一点是：**移位的位数必须是 `Long`**。`1 shl 4L` 可以；`1 shl 4` 也可以，因为字面量 `4` 会适配成 `Long`；但如果位数是一个 `Int` 变量 `n`，就要写 `1 shl n.toLong()`。

> **从 Kotlin 过来**
>
> 在 Kotlin 里 `shl` 的参数是 `Int`；在 Scoop 里是 `Long`。如果你的代码里移位次数来自一个 `Int` 变量，会看到和 3.3 一样的“convert this operand explicitly with `toLong()`”报错。

## 3.5　浮点数：`Float` 与 `Double`

`Float` 是 32 位浮点数，`Double` 是 64 位浮点数，都遵循 IEEE 754。它们也有别名 `Float32` 和 `Float64`。

```scoop
{{#include ../../examples/ch03/floats.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/floats.expected}}
```

字面量规则：

- 带小数点或指数的数字是浮点字面量：`1.5`、`1e3`、`2.5e10`。小数点后面必须有数字，`1.` 不是浮点数。
- 默认类型是 `Double`；后缀 `f` / `F` 表示 `Float`。没有 `d` 后缀。
- 和整数字面量一样，没有后缀的浮点字面量会适配目标类型：`val g: Float = 0.1` 合法。

浮点数之间也**不会隐式转换**。`Float` 和 `Double` 不能直接混算，浮点数和整数也不能：

```scoop
{{#include ../../examples/ch03/float_mix_fail.scoop}}
```

```text
{{#include ../../examples/ch03/float_mix_fail.error}}
```

```scoop
{{#include ../../examples/ch03/int_double_fail.scoop}}
```

```text
{{#include ../../examples/ch03/int_double_fail.error}}
```

在 Kotlin 里 `total / 4.0` 会得到 `2.5`；在 Scoop 里要写 `total.toDouble() / 4.0`。

浮点运算的其余行为基本符合直觉：

- 除以零不抛异常，而是得到 `Infinity`、`-Infinity` 或 `NaN`。
- `0.1 + 0.2` 不精确等于 `0.3`，这是二进制浮点数的本性，各种语言都一样。
- 浮点数转整数时**向零截断**；超出范围时**取边界值**（`1e20.toInt()` 得到 `Int.MAX_VALUE`），`NaN` 转成 `0`。这和整数之间“保留低位”的转换不同。

### NaN 和 NaN 相等

有一处和 Kotlin（以及大多数语言）不同：在 Scoop 里，**`NaN == NaN` 是 `true`**，而且 `-0.0 == 0.0` 也是 `true`。

Scoop 的默认比较把所有 NaN 当作同一个值，并让它排在 `+Infinity` 之后。这样，`==`、`<` 等运算对所有浮点数都构成一个一致的全序，浮点数可以安全地用于排序、去重之类的场合，不会因为 NaN 而出现“自己不等于自己”的怪现象。

代价是 Kotlin 中常见的 NaN 检测写法 `x != x` 不再有效。检测 NaN 要用 `x.isNaN()`；此外还有 `isInfinite()`、`isFinite()`。如果确实需要 IEEE 754 原始的比较语义（NaN 与任何值都“无序”），用 `a.ieeeCompare(b)`。

另外，`Float` 和 `Double` 能用 `==` 比较，但**没有实现 `Hash`**，不能直接作为 `HashMap` 的 key（第 8 章 8.7 节讨论过 `Hash`）。

> **深入一点：浮点数怎样打印**
>
> `println` 一个浮点数时，Scoop 输出能精确读回同一个值的**最短**十进制表示，所以 `0.1` 打印成 `0.1`，而 `0.1 + 0.2` 打印成 `0.30000000000000004`。数量级在 10⁻³ 到 10⁷ 之间用普通小数，否则用科学记数法（`2.5e10`）。结果总有小数点，所以 `1000.0` 不会被打印成 `1000`。输出不受系统地区设置影响。

## 3.6　`Boolean` 与 `Char`

```scoop
{{#include ../../examples/ch03/bool_char.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/bool_char.expected}}
```

`Boolean` 只有 `true` 和 `false`，运算符是 `&&`、`||`、`!`，和 Kotlin 相同。

`Char` 有一处重要差别：Kotlin 的 `Char` 是一个 16 位的 UTF-16 码元，表示不了 emoji 这样的字符；Scoop 的 `Char` 是一个完整的 **Unicode 标量值**（Unicode 中一个“字符编号”），`'雪'` 和 `'😀'` 都是一个 `Char`。字面量写在单引号里，也可以用 `'\u{1F600}'` 这样的转义。

`Char` 和整数之间不会自动互换：

- `c.code` 得到字符的编号（`Int`）；
- `n.toChar()` 把编号变回字符。编号不是合法的 Unicode 标量时，它抛出 `IllegalArgumentException`；
- `Char` 之间可以用 `==`、`<` 比较，按编号排序；
- `Char` **不能做算术**。

```scoop
{{#include ../../examples/ch03/char_math_fail.scoop}}
```

```text
{{#include ../../examples/ch03/char_math_fail.error}}
```

要得到“下一个字母”，写 `(c.code + 1).toChar()`。

> **从 Kotlin 过来**
>
> Kotlin 已经废弃的 `c.toInt()` 在 Scoop 中不存在，统一用 `c.code`。Kotlin 的 `'a' + 1` 和 `'a'..'z'` 在 Scoop 中都不可用：Scoop 没有字符区间。字符串里的“字符”、字节和用户看到的“字”是不同的东西，第 4 章会专门讲。

## 3.7　容器的大小和下标是 `Long`

这是 Kotlin 程序员最常碰到的一个差别：数组、列表等容器的 `size` 类型是 **`Long`**，下标参数也是 **`Long`**。

```scoop
{{#include ../../examples/ch03/indices.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/indices.expected}}
```

（`[90, 75, 60]` 是数组字面量，第 22 章介绍数组。）

写字面量下标时，`scores[1]` 和 `scores[0L]` 都可以，因为字面量会适配成 `Long`。本书示例里常写 `0L`，是为了提醒读者下标的真实类型。

麻烦出在**变量**上。一个 `Int` 变量不能直接当下标：

```scoop
{{#include ../../examples/ch03/index_fail.scoop}}
```

```text
{{#include ../../examples/ch03/index_fail.error}}
```

`size` 也不能直接赋给 `Int`：

```scoop
{{#include ../../examples/ch03/size_fail.scoop}}
```

```text
{{#include ../../examples/ch03/size_fail.error}}
```

建议的做法是：**凡是表示下标、长度、计数的变量，一开始就用 `Long`**，比如 `var i = 0L`、`val last = scores.size - 1L`。这样整段代码里都不需要转换。只有在和需要 `Int` 的 API 打交道时，才在边界上写一次 `toInt()` 或 `toLong()`。

Scoop 选择 `Long` 的理由很简单：在 64 位机器上，一个数组完全可能超过 21 亿个元素（尤其是字节数组），用 `Int` 当长度迟早不够。

## 3.8　反引号标识符

用反引号包起来的任意文本都是一个合法的名字，包括关键字和带空格的文字：

```scoop
{{#include ../../examples/ch03/backticks.scoop}}
```

输出：

```text
{{#include ../../examples/ch03/backticks.expected}}
```

规则和 Kotlin 相同：`` `when` `` 就是名为 `when` 的变量，不会触发 `when` 语法；`` `is valid` `` 是一个含空格的函数名。名字 `x` 和 `` `x` `` 是同一个名字。反引号里不能为空，也不能包含反引号或换行。

它最常见的用途是：调用一个恰好和 Scoop 关键字同名的库函数，或者在测试里写一句话作为测试函数名（第 30 章）。普通代码里不需要用它。

除反引号外，普通标识符可以使用 Unicode 字母，例如中文变量名也是合法的；编译器不做大小写折叠，`count` 和 `Count` 是两个名字。

## 从 Kotlin 过来：对照表

| Kotlin | Scoop | 说明 |
| --- | --- | --- |
| `val x: Int` 之后再赋值 | 必须 `val x: Int = ...` | 局部变量当场初始化 |
| `lateinit var x: T` | `var x: T? = None` | 不支持 `lateinit` |
| `intValue + longValue` | `intValue.toLong() + longValue` | 没有隐式提升 |
| `total / 4.0`（`total: Int`） | `total.toDouble() / 4.0` | 整数和浮点数不能混算 |
| `val d: Double = 1` 报错 | 同样报错，写 `1.0` | 整数字面量不适配浮点 |
| `val u: UInt = 5u` | 相同 | 无符号字面量必须带 `u` |
| `x shl n`（`n: Int`） | `x shl n.toLong()` | 移位位数是 `Long` |
| `Double.NaN == Double.NaN` 为 `false` | 为 `true` | 用 `isNaN()` 检测 NaN |
| `Char` 是 UTF-16 码元 | `Char` 是 Unicode 标量 | emoji 也是一个 `Char` |
| `c.toInt()` / `c.code` | `c.code` | |
| `'a' + 1` | `(c.code + 1).toChar()` | `Char` 没有算术 |
| `list.size: Int`，`list[i]` 的 `i: Int` | `size: Long`，下标 `Long` | 计数变量用 `Long` |
| 八进制字面量（Kotlin 也没有） | 没有 | |

## 常见误用

- **`Int` 和 `Long` 混用**：报错里出现 “primitive integer operands require one exact type” 时，在提示的那一侧加 `toLong()` 或 `toInt()`；更好的做法是一开始就统一用一种类型。
- **用 `Int` 变量当下标或接收 `size`**：下标、长度、计数一律用 `Long`（3.7）。
- **以为 `Long` 转 `Int` 会报错或饱和**：整数转换只保留低位，`5_000_000_000L.toInt()` 是 `705032704`。缩窄之前自己检查范围。
- **用 `x != x` 检测 NaN**：在 Scoop 中这永远是 `false`，用 `x.isNaN()`。
- **给无符号类型写不带 `u` 的字面量**：`val id: UInt = 5` 报错，写 `5u`。
- **先声明后赋值**：局部变量必须带初始值，改用 `if` 表达式或 `Option`。
- **把 `Float` / `Double` 当 `HashMap` 的 key**：它们没有实现 `Hash`。

## 小结

- `val` 不可重新赋值，`var` 可以；类型可以推断，一旦确定不变；局部变量必须当场初始化。
- 八种整数：`Byte`/`Short`/`Int`/`Long` 及其无符号版本，宽度在所有平台上固定。
- 字面量会适配上下文需要的整数或浮点类型，但必须放得下，且有符号、无符号、整数、浮点各不相通。
- 已有类型的值之间**没有任何隐式转换**，用 `toLong()`、`toDouble()` 等显式转换。整数转换保留低位，浮点转整数截断并取边界值。
- 整数溢出回绕，除法向零截断，除以零抛 `ArithmeticException`；移位位数是 `Long`。
- 浮点默认比较中 `NaN == NaN`，用 `isNaN()` 检测 NaN。
- `Char` 是 Unicode 标量，与整数通过 `code` / `toChar()` 互转，不能做算术。
- 容器的 `size` 和下标都是 `Long`。

## 练习

1. 写一个程序，声明 `val seconds: Long = 100_000L`，计算它是多少天、多少小时、多少分钟、多少秒，并打印出来，如 `1 d 3 h 46 min 40 s`。
2. 声明 `val count: Int = 7` 和 `val total: Long = 100L`，打印 `total` 除以 `count` 的平均值，保留小数（结果应该是 `14.285714285714286`）。想一想需要几次转换，分别放在哪里。
3. 打印 `Int.MAX_VALUE * 2` 的结果，再用 `Long` 算一遍正确的值。解释两次结果为什么不同。
4. 不使用任何字符串函数，只用 `Char` 的 `code` 和 `toChar()`，把 `'a'` 转换成 `'A'`。
5. 声明 `val nums = [3, 1, 4, 1, 5]`，打印最后一个元素。分别用字面量下标和 `nums.size` 各写一次。
