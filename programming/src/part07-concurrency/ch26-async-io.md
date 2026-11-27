# 第 26 章　异步 IO

第 25 章用 `sleep` 模拟了等待。本章介绍真正的异步操作：定时器、文件、网络，以及怎样在协程中使用那些只有同步版本的 API。这些能力由 `scoop.asyncio` 库提供，它建立在平台库 `scoop.platform` 之上：文件路径、网络地址、缓冲区这些类型都来自平台库，第 31 章会介绍它们的同步用法。

本章介绍：

- 事件循环提供的异步操作；
- 定时器，以及用定时器实现超时；
- 异步文件与目录操作，`NativeByteBuffer`；
- TCP 网络；
- `AsyncCloseable` 与 `useAsync`；
- 用阻塞池执行同步操作；
- task-local context：在任务中传递请求 ID 这类上下文。

## 26.1　事件循环提供的操作

`eventLoop()` 返回的事件循环实现了 `EventLoop` 接口，异步操作大多是这个接口的挂起方法。在 `run` 之内，用 `currentEventLoop()` 取得它：

| 类别 | 方法 |
| --- | --- |
| 定时 | `sleep(duration)`、`schedule(duration) { ... }` |
| 文件 | `openFile(path, options)`、`createTempFile(...)`、`metadata(path)`、`moveFile`、`deleteFile`、`createDirectories`、`openDirectory` |
| 网络 | `connectTcp(address)`、`connectTcp(host, port)`、`listenTcp(address)`、`bindUdp(address)`、`resolve(host, port)` |
| 终端 | `openTty()` |
| 执行 | `executor`，以及配置的阻塞池 |

这些方法有几条共同的规则：

- **只能在 `run` 之内、由属于这个事件循环的任务调用。** `run` 结束时，事件循环会关闭还没有关闭的资源，所以不要把文件或连接带到 `run` 之外。
- **都可以被取消。** 正在等待的操作在任务被取消时抛出 `CancellationException`。取消要等底层的系统操作真正停止后才生效，所以 `join` 可能要多等一会儿。
- **失败时抛出平台库的异常**，比如 `PlatformException`，它的 `kind` 字段说明失败的类别（第 19 章）；资源关闭后再使用抛出 `IoClosedException`。

## 26.2　定时器与超时

```scoop
{{#include ../../examples/ch26/timers.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/timers.expected}}
```

除了第 25 章用过的 `sleep`，事件循环还有一个 `schedule`：到期时调用一个**普通函数**（不是挂起函数），返回一个 `Disposable`，在到期之前调用 `dispose()` 就能撤销它。回调的参数是 `Throwable?`：正常到期时为 `None`，计时器本身出错时是那个错误。

`schedule` 的回调在事件循环的线程上执行，应该很快返回，通常只用来修改一个标记、取消某个任务，或者通知正在等待的任务。它抛出的异常会被当作整个事件循环的失败。需要“等待一段时间后做一件复杂的事”时，用 `launch` 加 `sleep`。

### 超时

Scoop 没有 kotlinx.coroutines 的 `withTimeout`。用 `schedule` 和取消可以组合出一个：

```scoop
{{#include ../../examples/ch26/timeout.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/timeout.expected}}
```

`withTimeoutOrNone` 的思路是：

1. 在一个 `coroutineScope` 中用 `async` 执行代码块；
2. 用 `schedule` 设一个定时器，到期时只取消这个子任务，并记下“是定时器取消的”；
3. `await` 等待结果。子任务被取消时，`await` 抛出 `CancellationException`；如果标记表明是定时器取消的，就返回 `None`，否则说明是外面取消了整个任务，要把取消继续抛出（第 25 章“不要吞掉取消”）；
4. 不论结果如何，在 `finally` 中撤销定时器。

`schedule` 的回调和 `await` 运行在同一个事件循环线程上，所以回调中修改 `flag.fired` 不需要额外的同步。`TimeoutFlag` 是一个 class，因为 lambda 不能捕获 `var` 局部变量（第 7 章）。

HTTP 等上层库有自己的超时配置（第 34 章），可以优先使用它们。

## 26.3　文件

```scoop
{{#include ../../examples/ch26/files.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/files.expected}}
```

**打开与关闭。** `openFile(path, options)` 返回一个 `AsyncFile`。`OpenOptions` 和 `Path` 都来自平台库的 `scoop.platform.fs`，默认只读打开；写文件要设 `write = true`，不存在时创建要设 `create = true`。`AsyncFile` 实现了 `AsyncCloseable`，用 `useAsync` 保证关闭（26.5）。

**读写使用 `NativeByteBuffer`。** 异步读写不直接接受 `Array<Byte>`，而是使用平台库的 `NativeByteBuffer`：一块由 Scoop 管理之外分配的内存，系统在后台读写它的时候，GC 不会移动它。它有两个位置：`writeBytes` 等写入方法推进**写位置**，`writeFully` 这类发送方法从**读位置**开始把数据取走。`NativeByteBuffer` 是 `Closeable`，用 `use` 及时释放。例子中 `use` 的 lambda 里调用了挂起函数 `writeFully`，编译器会自动选择 `use` 的挂起版本（第 21 章）。

**常用的读写函数**都是 `AsyncByteSource`、`AsyncByteSink` 接口上的挂起函数：

- `readInto(buffer, count)`、`writeFrom(buffer, count)`：读或写一次，可能只完成一部分，返回实际的字节数；读到 0 表示文件结束。
- `readFully(buffer, count)`、`writeFully(buffer)`：一直读或写，直到完成指定的字节数。
- `readAllBytes()`：读到文件结束，返回 `Array<Byte>`。不确定内容有多大时，用 `readAllBytes(maxBytes)` 设一个上限，超过时抛出 `ReadLimitException`，避免把一个意外巨大的文件整个读进内存。
- `copyTo(destination)`：把一个来源的内容全部复制到另一个目标。

**目录与路径操作**也在事件循环上：`createDirectories` 逐层创建目录，`openDirectory` 返回一个可以逐项读取的 `AsyncDirectoryEntries`，`next()` 返回 `None` 表示结束；`metadata`、`moveFile`、`deleteFile` 分别查询、移动和删除。

例子开头和结尾的 `createTempDirectory`、`deleteRecursively` 是平台库的**同步**函数，事件循环没有提供它们的异步版本，所以用 `blocking { ... }` 交给阻塞池执行（26.6）。

`close` 只是关闭文件，不保证数据已经写入磁盘；需要持久化时，在关闭前调用 `syncAll()`（第 21 章）。

## 26.4　网络

下面的程序在同一个事件循环里运行一个 TCP 回显服务和一个客户端：

```scoop
{{#include ../../examples/ch26/echo.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/echo.expected}}
```

- `listenTcp(address)` 在指定地址上监听，返回 `AsyncTcpListener`。端口写 0 表示由系统分配一个空闲端口，实际地址从 `listener.localAddress` 读取，测试和示例中常这样写，以免端口冲突。
- `accept()` 等待并返回下一个连接 `AsyncTcpStream`，它同时是 `AsyncByteSource` 和 `AsyncByteSink`，前一节的读写函数都能用。
- `connectTcp(address)` 连接到指定地址。`connectTcp(host, port)` 接受主机名，自动解析并同时尝试 IPv4 和 IPv6 地址。
- `shutdownOutput()` 关闭连接的发送方向，告诉对方“不会再发送了”，对方的读取随之得到 EOF，但连接的接收方向仍然可以使用。这里客户端发完请求就关闭发送方向，服务端的 `copyTo` 读到 EOF 后结束，再关闭自己的发送方向，客户端的 `readAllBytes` 随之结束。
- 服务端在一个 `launch` 出来的任务中运行，客户端在 `run` 的主体中运行。它们在同一个线程上，靠挂起轮流执行。

`bindUdp` 用于 UDP，`resolve` 只做域名解析。HTTP 客户端和服务端由更上层的库提供（第 34 章），一般不需要直接使用 TCP。

## 26.5　`AsyncCloseable` 与 `useAsync`

第 21 章的 `Closeable.close()` 是普通函数。异步资源的关闭往往也需要等待：把缓冲的数据发出去、等系统操作停止。所以 `scoop.asyncio` 定义了单独的接口：

- `AsyncCloseable`：只有一个方法 `suspend fun close()`；
- `useAsync { ... }`：和 `use` 一样，正文结束后（不论是否抛出异常）调用 `close`，正文和关闭都失败时抛出 `ResourceUseException`。

`AsyncFile`、`AsyncTcpStream`、`AsyncTcpListener`、`AsyncDirectoryEntries` 都实现了 `AsyncCloseable`。自己的类也可以实现它：

```scoop
{{#include ../../examples/ch26/session.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/session.expected}}
```

`s2` 的正文抛出了异常，`useAsync` 仍然调用了 `close`，然后把原来的异常抛出来。实现 `close` 的规则和第 21 章一样：重复调用什么也不做，先修改状态，再执行清理。

注意 `AsyncCloseable` 不是 `Closeable` 或 `Disposable` 的子类型，不能对它调用 `use`，也不能在普通函数中关闭它。

## 26.6　阻塞池

协程中不能调用阻塞线程的函数（第 25 章）。但很多现成的 API 只有同步版本：平台库的文件系统函数、某个 C 库、一段耗时的计算。这时用核心库的 `blocking { ... }`：

```scoop
{{#include ../../examples/ch26/blocking.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/blocking.expected}}
```

- `blocking { ... }` 把一个**普通函数**交给事件循环的**阻塞池**，在池中的某个线程上执行，当前任务挂起等待，结果或异常原样交回来。事件循环线程在此期间继续执行其他任务。
- 阻塞池默认有 4 个线程，可以在创建事件循环时用 `eventLoop { blocking { threads = 2 } }` 配置。两个 `slowLookup` 在两个线程上同时执行，所以总共只花了大约 100 毫秒。

**取消对阻塞操作的影响：** 排队中、还没有开始执行的阻塞操作被取消时，不会执行；已经开始执行的，不会被强行中断，要等它真正结束，`join` 也会一直等到那时。所以不要把可能无限期阻塞的操作放进阻塞池，比如等待一个永远不来的输入。

`blocking` 中的代码运行在另一个线程上，和事件循环线程上的任务是**真正并行**的。它和其他任务共享数据时，需要第 27 章介绍的同步手段。

## 26.7　task-local context

一个服务同时处理很多请求时，日志中最好带上请求 ID，才能分清哪条日志属于哪个请求。把请求 ID 作为参数传给每一个函数很繁琐；用全局变量又不行，因为多个请求在同时执行。Scoop 为此提供了 **task-local context**：把一个值绑定到当前的**逻辑任务**上，任务调用的函数可以按类型取得它。

```scoop
{{#include ../../examples/ch26/request_id.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/request_id.expected}}
```

**声明需要的上下文。** 在函数前面写 `context(id: RequestId, logger: Logger)`，表示这个函数要从当前任务中取得一个 `RequestId` 和一个 `Logger`，在函数体中分别叫 `id` 和 `logger`。调用方不需要传这两个参数，`log("start")` 只传了消息。

**绑定上下文。** `context(值) { ... }` 在花括号的范围内把一个值绑定到当前任务。`handle` 为每个请求绑定一个新的 `RequestId`；`main` 为整个运行绑定一个 `Logger`。同类型的内层绑定覆盖外层，离开花括号后恢复。

**传递规则：**

- 普通的函数调用、挂起调用共享当前任务的上下文。
- `launch`、`async` 启动的子任务**继承**启动时的绑定，所以 `audit` 和 `loadUser` 都能看到所属请求的 ID。之后父子任务各自重新绑定，互不影响。
- 两个请求是两个独立的任务，各自看到自己的 `RequestId`，这正是全局变量做不到的。
- `blocking` 中的代码和 `Thread.start` 启动的线程（第 27 章）也继承启动时的绑定。

**缺失时的行为。** 调用一个声明了上下文的函数，而当前任务中没有对应的绑定时，在进入这个函数时抛出 `MissingContextException`。这是一个**运行时**错误，编译器不会检查调用方有没有提供绑定。可选的上下文用 `contextOrNone<T>()` 查询，没有绑定时返回 `None`，如 `loadUser` 中的写法。

**key 是精确的静态类型。** 上下文按类型查找，而且只认**完全相同**的类型，不考虑子类型：

```scoop
{{#include ../../examples/ch26/exact_key.scoop}}
```

输出：

```text
{{#include ../../examples/ch26/exact_key.expected}}
```

`console` 的静态类型是 `ConsoleLogger`，绑定它只提供了 `ConsoleLogger` 这个 key，满足不了 `log` 对 `Logger` 的要求。先把它赋给一个 `Logger` 类型的变量再绑定，才能匹配。`request_id.scoop` 中的 `val bound: Logger = logger` 也是这个原因。

此外，上下文的类型必须是引用类型（class、interface、`String` 等），不能是 `Int` 这样的值类型或 `Option`：

```scoop
{{#include ../../examples/ch26/context_value_fail.scoop}}
```

```text
{{#include ../../examples/ch26/context_value_fail.error}}
```

同一个类型需要表示不同的角色时（比如“请求 ID”和“会话 ID”都是字符串），为每个角色定义一个 class，就像例子中的 `RequestId`。

> **从 Kotlin 过来**
>
> kotlinx.coroutines 用 `CoroutineContext` 的元素（比如 `MDCContext`、自定义的 `AbstractCoroutineContextElement`）在协程中传递这类数据，JVM 上还常用 `ThreadLocal`。Scoop 的 task-local context 是语言的一部分，跟随的是逻辑任务而不是线程，任务在线程之间迁移时不会丢失。语法上它类似 Kotlin 的 context parameters，但不在编译时检查调用方是否提供了绑定，而是在运行时按类型查找。

## 常见误用

- **把文件、连接带到 `run` 之外使用**：`run` 结束时它们已经被关闭。
- **对异步资源用 `use`**：异步资源实现的是 `AsyncCloseable`，用 `useAsync`。
- **在协程中直接调用平台库的同步文件函数**：它们会阻塞事件循环线程；用 `blocking { }`，或者使用事件循环提供的异步版本。
- **把可能永远不结束的操作放进 `blocking`**：已经开始的阻塞操作不能被取消中断。
- **在 `schedule` 的回调中做复杂的工作**：回调应该很快返回，复杂的工作用 `launch` 加 `sleep`。
- **用 `readAllBytes()` 读取大小未知的输入**：用 `readAllBytes(maxBytes)` 设上限。
- **以为 `close` 会把数据写入磁盘**：需要时先 `syncAll()`。
- **绑定上下文时用了子类型的变量**：key 是精确的静态类型，先转成要求的类型再绑定。
- **用 `Int`、`String?` 这样的类型作为上下文**：定义一个 class 作为 key。

## 小结

- `scoop.asyncio` 的事件循环提供定时器、文件、目录、TCP/UDP 和终端等异步操作，它们只能在 `run` 之内使用，都可以被取消。
- `sleep` 挂起等待，`schedule` 到期时调用普通回调并可以撤销；用 `schedule` 加取消可以实现超时。
- 异步读写使用 `NativeByteBuffer`；`readFully`、`writeFully`、`readAllBytes`、`copyTo` 是常用的组合函数。
- `AsyncCloseable` 的 `close` 是挂起函数，用 `useAsync` 保证关闭。
- `blocking { }` 把同步操作交给阻塞池，在其他线程上执行；已经开始的阻塞操作不能被中断。
- task-local context 把值绑定到逻辑任务上：`context(name: T)` 声明需要的上下文，`context(value) { }` 绑定，子任务继承绑定；按精确的静态类型查找，缺失时在运行时抛出 `MissingContextException`。

## 练习

1. 写一个挂起函数 `copyFile(from: Path, to: Path)`，用 `openFile` 和 `copyTo` 复制文件，确保两个文件在任何情况下都被关闭。
2. 修改 26.4 的回显服务：在一个循环中不断接受连接，为每个连接 `launch` 一个任务；客户端并发地发出 5 个请求，最后取消服务端任务。
3. 给 26.2 的 `withTimeoutOrNone` 写一个变体 `withTimeout`，超时时抛出一个自定义的 `TimeoutException`，而不是返回 `None`。思考：为什么超时异常不应该是 `CancellationException` 的子类？
4. 在 26.7 的例子中增加一个 `UserId` 上下文，只在用户登录之后绑定。写一个函数，用 `contextOrNone<UserId>()` 在日志中带上用户 ID（如果有的话）。
