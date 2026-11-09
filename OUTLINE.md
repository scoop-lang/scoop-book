# 《Scoop 程序设计》大纲（第一阶段）

## 编写约定

- **读者**：有 Kotlin 使用经验的应用开发者。不要求懂编译原理、类型论或 GC 实现。
- **范围**：第一阶段不含 GUI（`scoop.window`、`scoop.ui*`、`scoop.surface`、`scoop.tray`、`scoop.graphics*`），GUI 另行规划。
- **讲解方式**：
  - 先给能运行的完整程序，再讲规则，最后列"常见误用"。
  - 每章固定设一个 **「从 Kotlin 过来」** 栏，用 Kotlin 写法 → Scoop 写法的对照，说明直接照搬会出什么问题。
  - 术语第一次出现时用一句话的白话解释。实现层面的细节（布局、ABI、IR 等）只放进可跳过的 **「深入一点」** 栏，正文不依赖这些内容。
  - 只讲读者写程序时用得到的规则，不逐条复述规范。规范里的边界条件留给附录或者直接给出处。
- **示例**：每个示例是独立的 `.scoop` 文件或 Cone，并附上预期输出；由 CI 执行 `scoop fmt --check`、`scoop check`、`scoop run`/`scoop test`。能用 `scoop example` 现有主题的地方优先复用。

---

## 第一部分　起步

### 第 1 章　为什么是 Scoop
- 一句话定位：语法像 Kotlin，编译成原生程序，有真正的值类型
- 对 Kotlin 开发者来说，哪些熟悉、哪些新增、哪些被拿掉了（总览，细节在后面各章）
- 不做的事：JVM 互操作、运行期反射、`null`；也不在编译期保证没有数据竞争
- 白话解释"编译到原生代码""有 GC""值类型"分别意味着什么
- 本书的阅读路线

### 第 2 章　安装与第一个程序
- 安装工具包，`scoop --version`；Windows 上的命令名 `sco`
- `hello.scoop`，以及 `scoop run main.scoop --release`
- `main` 的几种合法形式：`Array<String>` 参数、返回 `Int` 作为退出码；**`args[0L]` 是程序路径**
- `scoop fmt` / `scoop check` / `scoop run` 分别做什么，`check` 通过不等于程序能运行
- 用 `scoop example` 浏览离线示例
- 配置 VS Code 扩展和 LSP
- 「从 Kotlin 过来」：没有 `fun main(args)` 的 JVM 启动语义

---

## 第二部分　语言基础

### 第 3 章　变量、数值与基本类型
- `val`/`var`、类型推断
- `Int`/`Long`/定宽整数、`Float`/`Double`、`Boolean`、`Char`
- 数值之间没有隐式转换，要用显式转换函数；整数溢出时回绕
- **容器的 `size` 和索引都是 `Long`**（`values[0L]`）
- 反引号标识符
- 「从 Kotlin 过来」：`Int` 和 `Long` 混用时报的编译错误

### 第 4 章　字符串
- `String` 不可变；用 `StringBuilder` 拼接
- f-string：`f"Hello, ${name}"`；普通字符串里的 `${}` 会原样保留
- UTF-8 字节、Unicode 标量（`Char`）、字素簇、显示宽度：这四个"长度"各是什么
- 常用文本 API 和数值解析，以 `OrNone` 命名约定的函数为例
- 示例：`text/strings`
- 「从 Kotlin 过来」：`$name` 不会插值

### 第 5 章　控制流
- `if`、`when` 都是表达式
- `for`、`while`、`do-while`；区间与迭代
- `break`、`continue`、`return`，以及标签的写法
- 本章只讲 `when` 的条件分支形式，模式匹配放到第 11 章

### 第 6 章　函数
- 表达式体和块体的区别：块体返回非 `Unit` 时必须写 `return`
- 参数是不可变绑定
- 默认参数、命名参数、`vararg`；实参从左到右求值
- 扩展函数、扩展属性、`infix`、局部函数
- 重载：读者需要知道的规则就够了，以及看懂"二义性"类报错
- 示例：`language/functions`

### 第 7 章　lambda 与闭包
- 函数类型、lambda、匿名函数、函数引用 `::f`
- lambda 最后一个表达式就是结果；裸 `return` 不合法，要用 `return@label`
- **闭包只能捕获 `val`**：需要共享可变状态时，用 `val` 持有一个对象
- 函数值只能按位置调用，原函数的命名参数和默认参数在这里用不了
- `inline` 等修饰符：可以写，但 Scoop 不会据此改变语义
- 示例：`language/lambdas`
- 「从 Kotlin 过来」：Kotlin 允许捕获 `var` 计数器，Scoop 不允许，给出改写方法

---

## 第三部分　值类型与模式匹配

### 第 8 章　struct：真正的值
- 声明和构造；字段只能是 `val`
- 值语义：赋值即复制，没有 identity，`===` 不能用于值类型
- 浅复制：struct 里的引用字段仍然指向同一个对象
- 副本更新 `p.{ x: 8 }`，代替 `data class` 的 `.copy(x = 8)`
- `==` 能用，不代表已经满足 `Equals`、`Hash`、`ToString` 约束；什么时候要显式声明 conformance
- 「深入一点」：值类型在内存里的样子、数组元素是内联存储的、零尺寸类型
- 示例：`language/struct`

### 第 9 章　enum 与 tuple
- 带数据的 enum（tagged union）；构造写 `Lookup.Found(x)`
- 整型枚举
- tuple 的写法、元素访问和复制语义
- 「从 Kotlin 过来」：用 `sealed class` 层级或 `enum class` 做的事，Scoop 里怎么写
- 示例：`language/enum`

### 第 10 章　解构
- `val (x, y) = point`、字段解构 `{ x, y: renamed }`
- `_` 和 `..`
- 嵌套解构；在 `for` 和 lambda 参数中解构
- 绑定位置只接受"一定能匹配成功"的模式，所以 `for (Some(x) in xs)` 不是过滤
- 普通类通过 `componentN` 支持解构

### 第 11 章　用 `when` 做模式匹配
- `case` 分支：匹配 enum variant、struct、tuple、字面量
- 守卫、smart cast、`when (val x = ...)`
- 穷尽性检查：编译器怎么帮你发现漏掉的分支
- 小练习：用 enum 和 `when` 写一个表达式求值器
- 示例：`language/overview`

### 第 12 章　`Option`：没有 null 的世界
- `T?` 就是 `Option<T>`；用 `Some(v)` / `None`
- `?.`、`?:`、`!!`
- **判断非空后类型不会自动收窄**，需要用 `when` / `case Some(v)` 取出值
- `T??` 是两层嵌套，不会自动展平
- 库的 `Option` 约定：哪些 API 返回 `Option`，哪些抛异常
- 示例：`language/option`
- 「从 Kotlin 过来」：`if (x != null) x.foo()` 的几种改写方式

---

## 第四部分　类、接口与泛型

### 第 13 章　类与对象
- 主构造与次构造、`init`、属性初始化顺序
- `const val`、`object`、companion
- 嵌套类、`inner class`、匿名 object
- 什么时候用 class，什么时候用 struct：一张选择表
- 示例：`language/companion`

### 第 14 章　继承与接口
- 单继承，`open`/`abstract`/`final`
- 接口与默认实现；**实现接口必须显式声明**，并写 `public override`
- sealed 继承配合穷尽性检查
- 值类型实现接口；装箱：只需了解什么时候会发生
- `is`/`as`/`as?` 与 smart cast
- 示例：`language/interfaces`

### 第 15 章　可见性与 API 边界
- **默认可见性是 `internal`，边界是 Cone**
- `public class` 不会自动公开构造器；`public interface` 也不会自动公开所有成员
- 设计一个对外库的公开面
- 示例：`language/visibility`
- 「从 Kotlin 过来」：Kotlin 默认 `public`，在 Scoop 里常见的"找不到符号"问题

### 第 16 章　委托与运算符
- 属性委托、接口实现委托
- `operator` 约定：算术、比较、索引、`invoke`、复合赋值
- core 中的运算符接口（如 `Equals`、`Hash`、`Comparable`）

### 第 17 章　泛型
- 类型参数、上界、`where`
- 白话解释"单态化"：每种类型参数生成一份专用代码，所以运行期能知道真实类型，代价是体积和编译时间
- **泛型是不变的**：`Box<Child>` 不是 `Box<Parent>`；没有 `in`/`out`/`*`，介绍替代写法
- 接口方法不能有自己的类型参数
- `typealias`、条件接口实现（把它当作"特定条件下才成立的能力"）
- 示例：`language/generics`

### 第 18 章　注解与编译期能力
- 声明和使用注解
- 静态类型描述：Scoop 用它替代反射能做的部分事情
- 由 conformance 自动生成编码/解码：为第 30 章 JSON 做铺垫
- 编译期嵌入：`includeStr`/`includeBytes`/`includeDir`、`env("SCOOP_...")`
- `SourceLocation`
- 文档注释（与第 27 章 `scoop doc` 衔接）
- 示例：`language/compiler-inputs`

---

## 第五部分　错误处理与资源

### 第 19 章　异常
- `try`/`catch`/`finally`，异常层级
- `Exception.message` 的类型是 `Option`；构造异常时要传什么参数
- 自定义异常

### 第 20 章　`Result` 与错误建模
- `scoop.Result<T, E>`：`Success`/`Failure`，以及 `map`、`flatMap`、`fold`、`recover`
- `runCatching`、`getOrThrow`
- 选型指南：异常、`Result`、`Option` 各用在什么场合
- 示例：`language/errors`

### 第 21 章　确定性资源释放
- 为什么有了 GC 还要手动关闭资源
- `Closeable`/`Disposable` 与 `use`
- 正文和清理都失败时：`ResourceUseException`
- 库 API 的命名约定：`withX`、`takeX`、`takeOwnership`
- 「深入一点」：`release { }`：遗漏显式关闭时的兜底，不能当作主要手段
- 示例：`io/resources`

---

## 第六部分　集合与标准库

### 第 22 章　数组与列表
- `Array`（只读）、`MutableArray`、`ArrayList`
- 数组字面量 `[7, 9]`
- `List`/`MutableList` 接口；快照 `toArray()` 的语义
- 示例：`collections/list`

### 第 23 章　`scoop.std` 集合
- 在 Cone 中声明 `scoop.std` 依赖并 import
- Map/Set 的三种顺序：无序、保持插入顺序、排序
- 作为 key 的类型需要满足哪些约束
- Deque、优先队列
- 急切的集合操作与惰性 `Sequence`
- 示例：`collections/map`（词频统计）

### 第 24 章　`scoop.std` 的其他内容
- 字节、Hex、Base64
- `Random`、可复现的随机数生成器、`Uuid`
- 时间：`Duration`、`Instant`、单调时钟 `TimeMark`、日期与时区偏移
- 「从 Kotlin 过来」：与 `kotlin.time` 的对照

---

## 第七部分　并发与异步

### 第 25 章　协程入门
- `suspend` 是什么、不是什么：它不等于开线程，也不等于并行
- 普通 `main` 里不能直接调用挂起函数：用 `EventLoop` 和 `loop.run` 进入
- 挂起 lambda 要显式写 `suspend { }`
- 结构化并发：`scope.async`/`await`、`scope.launch`/`join`
- 取消：`cancel` 之后还要 `join`；用 `finally` 做清理
- 不要用 `sleep` 当同步手段
- 示例：`async/tasks`
- 「从 Kotlin 过来」：不用 kotlinx.coroutines，各概念的对照表

### 第 26 章　异步 IO
- `scoop.asyncio`：事件循环、异步读写、定时器
- 把阻塞操作交给阻塞池
- `AsyncCloseable` 与 `useAsync`
- task-local context（`context(...)`）：在任务里传递请求 ID 之类的上下文

### 第 27 章　线程与同步
- 线程；什么情况下需要多线程 executor
- 数据竞争：用一节白话讲清楚什么是数据竞争、为什么后果是"未定义行为"、怎么避免
- 原子类型：只讲常用的内存序和适用场景，完整模型放进「深入一点」
- `scoop.concurrent`：Channel、AsyncMutex、条件变量
- 一个生产者/消费者示例

---

## 第八部分　工程化

### 第 28 章　从单文件到 Cone
- 单文件模式和 `//! dep:` 依赖头
- `scoop new`；`Cone.toml` 字段逐个讲解
- 依赖坐标和 import 包名是两回事（例如 `scoop.std` 提供 `scoop.collections`）
- `package`/`import`、re-export、块级 import
- 多文件组织；`sources` 的选择规则
- 示例：`start/single-file`、`start/cone`、`language/imports`

### 第 29 章　依赖管理
- 版本要求：caret、`=`、tilde
- path、Git/GitHub、registry 三种来源
- `Cone.lock`：要提交到仓库；`--locked`/`--frozen` 的含义
- `scoop pm resolve/update/fetch/deps --why/add/remove`
- workspace 与成员继承
- 当前尚未提供：发布流程（标注版本状态）

### 第 30 章　测试、格式化与文档
- `scoop.test`：`@Test`、断言、预期异常
- `scoop test --filter/--list/--nocapture`
- `scoop fmt --check` 在 CI 中的用法
- `scoop doc` 与文档注释
- 读懂编译器诊断；`--message-format json`
- release 与 debug 的区别；跨目标编译 `--target`
- 示例：`test/assertions`

---

## 第九部分　常用库实战

每章以一个可运行的小工具为主线。

### 第 31 章　文件与系统（`scoop.platform`）
- 路径、文件读写、目录、临时文件
- 进程、环境变量、系统时间
- 示例：`io/files`

### 第 32 章　命令行程序
- `scoop.cli`：参数、选项、子命令、帮助、错误退出
- `scoop.log` 与 console provider
- `scoop.terminal` 和 `scoop.readline`：交互式输入
- 项目：一个带子命令的文本统计工具
- 示例：`cli/options`

### 第 33 章　JSON
- `scoop.json` 的类型化 codec：把 struct/enum 和 JSON 互相转换
- 自定义字段名、可选字段、错误处理
- 无类型的 JSON 树
- 示例：`json/typed`

### 第 34 章　网络与 HTTP
- `scoop.url`、`scoop.http.client`：GET/POST、读取与关闭响应、TLS
- `scoop.http.server`：路由、请求与响应
- WebSocket、Server-Sent Events、NDJSON 流
- 示例：`http/get`

### 第 35 章　其他库速览
- `scoop.regex`
- `scoop.math`：BigInteger/BigDecimal 与舍入
- `scoop.crypto`、`scoop.compression`、`scoop.charset`、`scoop.idna`
- 每个库一段示例，并指向其 API 文档

---

## 第十部分　与原生世界打交道

本部分面向需要调用 C 库的读者；只写应用的读者可以跳过。

### 第 36 章　调用 C 代码
- 什么时候应该用 FFI，什么时候应该找现成的库
- `@Extern` 声明 C 函数；类型对应表
- `@CLayout` struct；`Ptr<T>`、`sizeOf`/`alignOf`
- `@Unsafe`/`@Safe`：标出"这里需要自己保证安全"的代码
- 回调函数 `FunPtr`；errno（`captureErrno`）
- 在 Cone 中编译 C 源码、链接系统库
- 把 native 句柄封装成 `Closeable`（与第 21 章呼应）
- 项目：封装一个小 C 库

### 第 37 章　内存与性能：应用开发者需要知道的
- GC 从开发者角度看：自动回收；对象可能被移动，所以不能长期持有裸指针
- 值类型与引用类型对性能的影响
- 在 release 下测量；查看优化决策（`--emit optimizations`）
- 「深入一点」：`@NoGC`、`@GCLeaf`、`@Global`/`@ThreadLocal`、`MaybeUninit`，以及它们各自的使用场景

---

## 第十一部分　综合项目

- **项目 A：命令行待办管理器**：值类型建模、JSON 持久化、文件 IO、CLI、测试
- **项目 B：异步 HTTP API 服务**：asyncio、http.server、JSON、日志、结构化并发与取消
- （备选）**项目 C：小型脚本语言解释器**：enum、`when`、Result 错误处理、readline 交互

---

## 附录

- **A　Kotlin → Scoop 速查表**：按"我在 Kotlin 里这样写"组织，每条附章节链接
- **B　常见编译错误及其含义**
- **C　`scoop` 命令速查**
- **D　core 默认可用的名称（prelude）**
- **E　中英术语对照**
- **F　进一步阅读**：语言规范、库规范、`scoop example` 主题索引

---

## 待定事项

- 书籍构建工具（mdBook 或其他）与目录结构
- 示例 CI：需要选定工具链版本，并决定示例跟随哪个快照更新
- 语言仍在演进：需要约定书中标注"适用版本"的方式
