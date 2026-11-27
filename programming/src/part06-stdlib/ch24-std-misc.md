# 第 24 章　`scoop.std` 的其他内容

除了集合，标准库还提供了几组和平台无关的基础工具：

| 包 | 内容 |
| --- | --- |
| `scoop.bytes` | 构建和读取二进制数据、字节序 |
| `scoop.text` | 其中的 `toHexString`、`hexToByteArray`（文本部分见第 4 章） |
| `scoop.io.encoding` | Base64 |
| `scoop.random` | 随机数接口、可复现的随机数生成器 |
| `scoop.uuid` | UUID |
| `scoop.time` | 时长 `Duration`、时刻 `Instant`、时钟与单调时间的接口 |
| `scoop.datetime` | 日期、时间、固定的 UTC 偏移 |

标准库有一个设计原则：**它只处理数据，不和操作系统打交道。** 所以 `scoop.std` 里没有“读取当前时间”的系统时钟，也没有从操作系统获取熵的随机数源，它只定义了 `Clock`、`TimeSource`、`Random` 这样的接口和纯计算的类型。真正连接操作系统的实现在 `scoop.platform` 中：`SystemClock`、`MonotonicTimeSource`、`SystemRandom`。本章在需要时会用到它们，`scoop.platform` 的其他内容见第 31 章。

这样分开的好处是，处理时间、随机数的代码可以依赖接口，在测试中换成可控的实现（24.6 有一个例子）。

本章介绍：

- 用 `ByteArrayBuilder`、`ByteArrayReader` 处理二进制数据；
- Hex 和 Base64 编码；
- 随机数：可复现的生成器与系统随机源；
- `Uuid`；
- `Duration` 与 `Instant`；
- 墙上时钟与单调时钟；
- 日期、时间与 UTC 偏移。

## 24.1　字节

Scoop 没有单独的 `ByteArray` 类型，字节数据就是 `Array<Byte>`、`MutableArray<Byte>` 或 `List<Byte>`。`Byte` 是有符号的 8 位整数（第 3 章），字符串和 UTF-8 字节之间的转换用 `toByteArray()` 和 `String.fromUtf8`（第 4 章）。

需要按固定格式读写二进制数据（文件头、网络协议、自定义存储格式）时，用 `scoop.bytes` 中的两个类：

```scoop
{{#include ../../examples/ch24/bytes.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/bytes.expected}}
```

- **`ByteArrayBuilder`** 是一个可以不断追加的字节缓冲区。`append` 追加单个字节或一组字节，并返回 builder 本身，可以链式调用；`writeInt32`、`writeUInt16`、`writeDouble` 等按固定宽度写入数值；`toByteArray()` 取得当前内容的快照。
- **`ByteArrayReader`** 从一组字节中按顺序读取。`position` 是当前位置，`remaining` 是剩余的字节数，`readBytes(n)` 读取 n 个字节，`skip`、`seek` 移动位置。读取时剩余的字节不够，抛出 `IndexOutOfBoundsException`，并且这次读取不移动位置。
- **多字节数值必须写明字节序**：`ByteOrder.BigEndian`（高位在前，网络协议常用）或 `ByteOrder.LittleEndian`（低位在前，x86 和 ARM 的内存中常用）。没有“按本机字节序”的默认值，避免写出在另一台机器上读不出来的数据。从输出的十六进制可以看到区别：版本号 2 写成 `0002`，条目数 1000 写成 `e8030000`。
- 方法名以位宽命名：`Int8`、`UInt8`、`Int16`、`UInt16`、`Int32`、`UInt32`、`Int64`、`UInt64`，以及 `Float`、`Double`。

## 24.2　Hex 与 Base64

```scoop
{{#include ../../examples/ch24/encoding.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/encoding.expected}}
```

**Hex**（十六进制）在 `scoop.text` 中：`toHexString()` 把字节转成十六进制文本，默认小写，传 `uppercase = true` 得到大写；`hexToByteArray()` 反过来解析，接受大小写，长度必须是偶数。它不接受空格、分隔符和 `0x` 前缀，所以 `"0x12"` 解析失败。失败时 `hexToByteArray` 抛出 `IllegalArgumentException`，`hexToByteArrayOrNone` 返回 `None`。

**Base64** 在 `scoop.io.encoding` 中（这个包名不表示它会做任何 IO）：

- `Base64.Default` 使用标准字母表，`Base64.UrlSafe` 把其中的 `+`、`/` 换成 `-`、`_`，适合放在 URL 和文件名中。
- `withPadding(...)` 得到一个改变了填充方式的新配置：`Required`（默认，必须有结尾的 `=`）、`Absent`（不写也不接受 `=`）、`Optional`（解码时两种都接受）。
- `encode` 接受字节，返回文本；`decode` 接受文本，返回 `Array<Byte>`，非法输入抛出 `IllegalArgumentException`；`decodeOrNone` 返回 `None`。解码很严格：不接受空白和换行，也不接受混用两种字母表。

## 24.3　随机数

### 可复现的随机数

```scoop
{{#include ../../examples/ch24/random.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/random.expected}}
```

`scoop.random.Random` 是一个接口。`Random.seeded(种子)` 返回一个用指定种子初始化的生成器（算法是 xoshiro256\*\*，类名 `Xoshiro256StarStar`）。**种子相同，调用顺序相同，得到的随机数就完全相同**，而且在所有平台上都一样，所以 `a` 和 `b` 掷出了同样的点数，上面的输出也能作为示例的预期结果。这在模拟、生成测试数据、游戏的“种子”功能中很有用。

常用的方法：

- `nextInt()`、`nextLong()` 等返回整个取值范围内的随机数；
- `nextInt(until)`、`nextInt(from, until)` 返回 `[from, until)` 范围内的随机数，**不包含** `until`，所以掷骰子写 `nextInt(1, 7)`；
- `nextDouble()`、`nextFloat()` 返回 `[0, 1)` 范围内的浮点数，`nextBoolean()` 返回随机的 `true` 或 `false`；
- `nextBytes(n)` 返回 n 个随机字节。

集合上的 `shuffled`、`random`，以及 `MutableList` 的原地 `shuffle`，都要**显式传入**一个 `Random`。

### 系统随机源

Scoop 没有 Kotlin 的 `Random.Default`，也没有任何“隐式的全局随机数生成器”：

```scoop
{{#include ../../examples/ch24/default_random_fail.scoop}}
```

```text
{{#include ../../examples/ch24/default_random_fail.error}}
```

需要每次运行都不同、不可预测的随机数时，使用 `scoop.platform` 中的 `SystemRandom`，它从操作系统获取随机数：

```scoop
{{#include ../../examples/ch24/system_random.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/system_random.expected}}
```

`SystemRandom` 同样实现了 `Random` 接口，所以前面所有的方法都可以用。为了让输出固定，这个例子只打印了随机结果的性质，没有打印随机数本身。

选择的原则是：

- 需要可复现：`Random.seeded(...)`。注意它**不是**密码学安全的，知道了一部分输出，就能推算出后面的输出。
- 需要不可预测：`SystemRandom`。
- 生成密钥、令牌等安全敏感的数据：使用 `scoop.crypto` 提供的接口（第 35 章）。
- 写接受随机源的函数时，参数类型写成 `Random` 接口，由调用方决定传哪一种，这样测试时可以传入固定种子的生成器。

## 24.4　Uuid

```scoop
{{#include ../../examples/ch24/uuid.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/uuid.expected}}
```

- `Uuid.parse` 接受 `8-4-4-4-12` 的带横线形式和 32 位十六进制两种写法，大小写都可以；不接受花括号、`urn:uuid:` 前缀和首尾空白。`parseOrNone` 在格式不对时返回 `None`。
- `toString()` 总是输出小写、带横线的标准形式；`toHexString()` 输出不带横线的形式。
- `Uuid.random(random)` 生成随机的 UUID（RFC 9562 的第 4 版），同样要显式传入随机源，通常传 `SystemRandom`。
- `Uuid` 是一个 struct，实现了 `Equals`、`Hash`、`Compare` 和 `ToString`，可以直接作为 `HashMap` 的 key、排序和打印。`NIL` 是全零的 UUID。

## 24.5　`Duration` 与 `Instant`

### `Duration`：一段时长

```scoop
{{#include ../../examples/ch24/durations.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/durations.expected}}
```

- **创建**：`90.seconds()`、`5.minutes()` 这样的扩展函数，或者 `Duration.milliseconds(1500L)` 这样的 companion 工厂。单位有 `nanoseconds`、`microseconds`、`milliseconds`、`seconds`、`minutes`、`hours`、`days`，一天固定是 86400 秒。
- **运算**：`+`、`-`、乘以或除以 `Long`、取负，以及 `<`、`>` 比较。
- **换算**：`inWholeMinutes`、`inWholeSeconds` 等属性得到整数，**向零截断**，所以 93 秒是 1 分钟。`toComponents()` 拆成整秒和纳秒两部分，返回一个 tuple。
- **文本**：`toString()` 和 `toIsoString()` 都输出 ISO 8601 格式，比如 `PT93S`、`-PT1.5S`；`Duration.parse` 解析同样的格式，比如 `PT1H30M`。
- **精确且有限**：精度是纳秒，结果超出表示范围时抛出 `ArithmeticException`，不会溢出回绕。没有 Kotlin 的 `Duration.INFINITE`。

注意 `seconds()` 是**函数**，不是属性：

```scoop
{{#include ../../examples/ch24/seconds_fail.scoop}}
```

```text
{{#include ../../examples/ch24/seconds_fail.error}}
```

Kotlin 中 `5.seconds` 是一个扩展属性。Scoop 写成函数，是因为它可能失败（数值太大时抛出异常），而按照 Scoop 库的约定，可能失败或需要计算的操作用函数，廉价的已有状态才用属性。

### `Instant`：一个时刻

```scoop
{{#include ../../examples/ch24/instants.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/instants.expected}}
```

- `Instant` 表示时间轴上的一个**绝对时刻**，内部是距离 1970-01-01T00:00:00Z（Unix 纪元）的秒数和纳秒数。`fromEpochSeconds`、`fromEpochMilliseconds` 从数值创建，`epochSeconds`、`toEpochMilliseconds()` 取回数值。
- `Instant.parse` 解析 ISO 8601 文本，**必须**带 `Z` 或 `+08:00` 这样的 UTC 偏移。没有偏移的文本，比如 `2026-11-26T09:30:00`，不知道是哪里的 9 点半，所以不能解析成 `Instant`。输出时总是换算成 UTC，以 `Z` 结尾。
- `Instant` 加减 `Duration` 得到新的 `Instant`，两个 `Instant` 相减得到 `Duration`。
- `toLocalDateTime(offset)` 把时刻换算成某个 UTC 偏移下的日期和时间（24.7）。
- 和大多数系统一样，`Instant` 把每一天都当作 86400 秒，不表示闰秒。

`Duration`、`Instant` 以及下面的日期时间类型都实现了 `Equals`、`Hash`、`Compare`（`OffsetDateTime` 除外，见 24.7）和 `ToString`，可以比较、排序、作为 key。它们的 companion 还提供了 codec，编码成上面这些标准文本，第 33 章的 JSON 可以直接使用。

## 24.6　墙上时钟与单调时钟

“现在几点”和“过了多久”是两个不同的问题，要用两种不同的时钟回答：

- **墙上时钟**（wall clock）回答“现在是什么时刻”，结果是 `Instant`。它会被调整：用户修改系统时间、网络校时，都可能让它向前跳或者向后跳。
- **单调时钟**（monotonic clock）回答“从某个时间点到现在过了多久”。它只会向前走，不受系统时间调整的影响，但它的读数和日历时间没有关系，只能用来计算间隔。

在 `scoop.time` 中，它们分别是两个接口：

- `Clock`：方法 `now(): Instant`；
- `TimeSource`：方法 `markNow(): TimeMark`。`TimeMark` 是某个时间源的一次读数，同一个时间源的两个读数相减得到 `Duration`。

`scoop.platform` 提供了操作系统的实现：

```scoop
{{#include ../../examples/ch24/elapsed.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/elapsed.expected}}
```

- `SystemClock.now()` 读取墙上时钟。
- `MonotonicTimeSource.markNow()` 读取单调时钟；`elapsedNow()` 计算从这个读数到现在经过的时间。
- `measureTime { ... }` 执行代码块并返回它花费的时间，默认使用单调时钟；`measureTimedValue { ... }` 同时返回代码块的结果和花费的时间。
- `scoop.platform.time` 中还有 `sleep(duration)`，它会阻塞当前线程。协程中不要用它，用第 26 章的异步等待。

**计算耗时一定要用单调时钟。** 用两次 `SystemClock.now()` 相减，如果中间系统时间被调整了，可能得到负数或者一个很大的值。（测量性能时还要用 release 构建，见第 37 章。）

### 在测试中控制时间

依赖 `TimeSource` 接口而不是 `MonotonicTimeSource` 本身，测试时就可以换成一个由测试代码控制的时间源：

```scoop
{{#include ../../examples/ch24/fake_time.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/fake_time.expected}}
```

`Cooldown` 限制一个动作每 30 秒最多执行一次。它从构造器接收 `TimeSource`，生产代码传入 `MonotonicTimeSource`，测试中传入 `ManualTimeSource`，于是测试不需要真的等待 30 秒，结果也完全确定。

`TimeMark` 记录了自己来自哪个时间源。**不同时间源的读数不能相减或比较**，否则抛出 `IllegalArgumentException`，因为两个单调时钟的起点没有任何关系。

## 24.7　日期、时间与 UTC 偏移

### 本地日期和时间

```scoop
{{#include ../../examples/ch24/dates.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/dates.expected}}
```

`scoop.datetime` 中的“本地”类型表示日历上的日期和钟表上的时间，**不包含**它是哪个地方的日期和时间：

| 类型 | 表示 | 例子 |
| --- | --- | --- |
| `LocalDate` | 日期 | `2024-01-31` |
| `LocalTime` | 一天中的时间 | `07:30:00` |
| `LocalDateTime` | 日期加时间 | `2026-12-25T07:30:00` |
| `YearMonth` | 年和月 | `2024-02` |
| `Month`、`DayOfWeek` | 月份、星期几，都是 enum | `Month.February`、`Wednesday` |
| `DatePeriod` | 按日历计算的年、月、天 | `DatePeriod(years = 1, months = 1)` |

几个要点：

- **构造时检查合法性。** `LocalDate(2026, 2, 30)` 抛出 `IllegalArgumentException`；`parseOrNone` 在格式不对时返回 `None`，只接受 ISO 格式，比如 `2026-11-26`。
- **月份按自然数编号**，1 月是 1，也可以传 `Month` 的值：`YearMonth(2024, Month.February)`。
- **加月份时，目标月份没有这一天，就取月末。** 2024-01-31 加一个月是 2024-02-29，加 1 年 1 个月是 2025-02-28。所以日历运算不一定可逆：2024-02-29 减一个月是 2024-01-29，回不到 31 日。
- **`DatePeriod` 和 `Duration` 是两回事。** “一个月”的长度取决于是哪个月，不能换算成固定的秒数；“一天”在 `Duration` 中则固定是 86400 秒。按日历加减用 `plusDays`、`plusMonths`、`DatePeriod`，按精确时长加减用 `Duration`。
- `daysUntil` 计算两个日期之间的天数，`dayOfWeek`、`dayOfYear` 查询星期几和一年中的第几天。
- `LocalTime` 加减 `Duration` 时按 24 小时回绕，23:00 加 2 小时是 01:00。

### UTC 偏移

```scoop
{{#include ../../examples/ch24/offsets.scoop}}
```

输出：

```text
{{#include ../../examples/ch24/offsets.expected}}
```

- `UtcOffset` 是一个**固定**的偏移量，比如 `+08:00`、`-05:00`，零偏移输出为 `Z`。
- `OffsetDateTime` 是本地日期时间加上偏移，能唯一确定一个时刻，`toInstant()` 换算成 `Instant`。
- `withOffsetSameInstant` 保持时刻不变，换算成另一个偏移下的本地时间：北京时间 21 点是纽约（`-05:00`）早上 8 点。`withOffsetSameLocal` 保持本地时间不变，只替换偏移，表示的就是另一个时刻了。
- `LocalDateTime.toInstant(offset)` 和 `Instant.toLocalDateTime(offset)` 在本地时间和时刻之间互相换算，偏移必须显式给出。
- `OffsetDateTime` 的 `==` 比较本地时间和偏移两者：`21:00+08:00` 和 `13:00Z` 是同一时刻，但用 `==` 比较不相等。它也没有实现 `Compare`。要按时刻比较或排序，先 `toInstant()`。

**标准库没有时区。** `UtcOffset` 只是一个固定的偏移量，不是“Asia/Shanghai”“America/New_York”这样的地区时区。地区时区的偏移会随夏令时和历史规则变化，计算它需要时区数据库，这超出了标准库“只处理数据”的范围。目前要处理夏令时，需要自己确定每个时刻对应的偏移。

## 从 Kotlin 过来：与 `kotlin.time`、`kotlinx.datetime` 的对照

| Kotlin | Scoop |
| --- | --- |
| `5.seconds`、`500.milliseconds` | `5.seconds()`、`500.milliseconds()`（`import scoop.time.*`） |
| `Duration.INFINITE` | 不存在；`Duration` 总是有限的，超出范围抛出 `ArithmeticException` |
| `duration.toString()` 输出 `1m 33s` | 输出 ISO 格式 `PT93S` |
| `duration.inWholeSeconds` | 相同 |
| `TimeSource.Monotonic.markNow()` | `MonotonicTimeSource.markNow()`（`scoop.platform.time`） |
| `mark.elapsedNow()`、`measureTime { }` | 相同，在 `scoop.platform.time` 中 |
| `Clock.System.now()` | `SystemClock.now()`（`scoop.platform.time`） |
| `Instant.parse(...)`、`Instant.fromEpochSeconds(...)` | 相同，`scoop.time.Instant`；解析时必须带偏移 |
| `LocalDate(2024, 1, 31)`、`plus(1, DateTimeUnit.MONTH)` | `LocalDate(2024, 1, 31)`、`plusMonths(1L)` |
| `TimeZone.of("Asia/Shanghai")`、`toLocalDateTime(timeZone)` | 没有地区时区；只有固定偏移 `UtcOffset`，`toLocalDateTime(offset)` |
| `Thread.sleep(ms)`、`delay(ms)` | `sleep(duration)`（`scoop.platform.time`，阻塞线程）；协程中用异步等待（第 26 章） |
| `Random.Default`、`Random.nextInt(10)` | 不存在；可复现用 `Random.seeded(seed)`，不可预测用 `SystemRandom` |
| `Random(42)` | `Random.seeded(42L)`，在所有平台上结果相同 |
| `list.shuffled()`、`list.random()` | `list.shuffled(random)`、`list.random(random)`，必须传入 `Random` |
| `Uuid.random()`（`kotlin.uuid`） | `Uuid.random(SystemRandom)` |
| `ByteArray` | `Array<Byte>`、`MutableArray<Byte>` |
| `ByteBuffer`（JVM） | `ByteArrayBuilder`、`ByteArrayReader`，字节序必须显式给出 |
| `bytes.toHexString()`、`"..".hexToByteArray()` | 相同（`import scoop.text.*`） |
| `Base64.encode(bytes)`（`kotlin.io.encoding`） | `Base64.Default.encode(bytes)`（`import scoop.io.encoding.*`） |

## 常见误用

- **把 `5.seconds()` 写成 `5.seconds`**：它是函数。
- **用墙上时钟计算耗时**：系统时间可能被调整，用单调时钟。
- **把不同时间源的 `TimeMark` 相减**：会抛出异常。
- **把 `LocalDateTime` 当作一个时刻**：它没有偏移，不能直接换算成 `Instant`，也不能和另一个地方的时间比较。
- **把 `UtcOffset` 当作时区**：它不会随夏令时变化。
- **用 `==` 比较两个 `OffsetDateTime` 是不是同一时刻**：先 `toInstant()` 再比较。
- **把一个月当作 30 天**：日历运算用 `plusMonths` 或 `DatePeriod`。
- **寻找全局的随机数生成器**：显式创建 `Random.seeded(...)` 或使用 `SystemRandom`，并作为参数传递。
- **用 `Random.seeded` 生成密钥或令牌**：它是可预测的。
- **写入多字节数值时假设本机字节序**：`ByteArrayBuilder` 要求显式给出字节序，读取时要用同一个字节序。
- **Base64 文本中带有换行**：标准库的解码不接受空白，先去掉换行。

## 小结

- `scoop.std` 只处理数据，不访问操作系统。系统时钟、单调时钟和系统随机源由 `scoop.platform` 提供：`SystemClock`、`MonotonicTimeSource`、`SystemRandom`。
- 字节数据就是 `Array<Byte>`；`ByteArrayBuilder` 和 `ByteArrayReader` 按显式的字节序读写定宽数值。
- `toHexString`、`hexToByteArray` 处理十六进制，`Base64.Default`、`Base64.UrlSafe` 处理 Base64，解码都很严格。
- `Random` 是接口，没有全局默认实例；`Random.seeded` 可复现但不安全，`SystemRandom` 不可预测。集合的随机操作要显式传入 `Random`。
- `Uuid` 是可比较、可哈希、可打印的 struct，随机生成需要传入随机源。
- `Duration` 是精确、有限的时长，`Instant` 是绝对时刻；两者都用 ISO 8601 文本表示。
- 问“现在几点”用墙上时钟，问“过了多久”用单调时钟；依赖接口，测试时可以替换。
- 日期类型按日历计算，加月份时取月末；只有固定的 UTC 偏移，没有地区时区。

## 练习

1. 用 `ByteArrayBuilder` 设计一个简单的格式来保存一组 `(String, Int)`：先写条目数，每个条目先写名字的字节数，再写名字的 UTF-8 字节，最后写数值。再用 `ByteArrayReader` 读回来。
2. 写一个函数 `randomPassword(random: Random, length: Long): String`，从大小写字母和数字中随机选取字符。用固定种子测试它总是返回同样的结果，再说明在真实程序中应该传入哪种 `Random`。
3. 写一个函数，接受一个 `Duration`，输出 `1h 02m 03s` 这样的文本。负数时长怎么处理？
4. 写一个函数 `nextBillingDate(start: LocalDate, months: Long): LocalDate`，计算从 `start` 开始第 `months` 个月的账单日。用 2024-01-31 测试，观察 2 月、4 月的结果，并解释为什么不应该写成“上一个账单日加一个月”。
5. 修改 24.6 的 `Cooldown`，让它记录最近 10 秒内的调用次数，超过 3 次就拒绝（滑动窗口限流）。用 `ManualTimeSource` 写几个检查。提示：用 `ArrayDeque<TimeMark>` 保存调用时间。
