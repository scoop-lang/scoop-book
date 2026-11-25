# 第 25 章　协程入门

程序经常要**等待**：等网络响应、等文件读完、等定时器到期。等待期间 CPU 无事可做，如果让整个线程停下来干等，就浪费了这个线程；如果为每一个等待都开一个线程，线程又太贵。协程（coroutine）是解决这个问题的常见办法：一个任务需要等待时，就把自己**暂停**，让出线程去执行别的任务，等待的事情完成后再从暂停的地方**继续**。

Kotlin 的协程由 kotlinx.coroutines 库提供。Scoop 的协程是语言和核心库的一部分，概念大体相同：`suspend` 函数、`launch`、`async`/`await`、结构化并发、协作式取消。不同的地方主要有三点：

- **入口是显式的事件循环。** 没有 `runBlocking`，也没有全局的调度器，普通的 `main` 要先创建一个事件循环，再在里面运行挂起代码。
- **没有 kotlinx.coroutines 的那一大套 API。** 没有 `Dispatchers`、`withTimeout`、`supervisorScope`、`Flow`、`select`，需要时用更基本的部件组合。
- **集合操作不能挂起。** Kotlin 中能在 `map { }` 里调用挂起函数，是因为 `map` 是 `inline` 函数；Scoop 的 lambda 规则（第 7 章）不允许这样做。

本章介绍：

- 第一个异步程序：事件循环、挂起函数、`async`/`await`；
- `suspend` 是什么、不是什么；
- 挂起 lambda 的类型规则；
- 结构化并发：`launch`、`async`、`coroutineScope`，以及失败的传播；
- 取消：`cancel`、`join`、`finally` 与 `nonCancellableScope`；
- 为什么不能用睡眠来同步。

本章和后面两章的例子用到 `scoop.asyncio` 等几个库，单文件程序要用 `//! dep:` 声明依赖（第 28 章）。

## 25.1　第一个异步程序

```scoop
{{#include ../../examples/ch25/first.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/first.expected}}
```

逐行来看：

- **`suspend fun fetchPrice`** 是一个挂起函数。它调用 `sleep` 等待 50 毫秒，等待期间它所在的任务暂停，线程可以去执行别的任务。这里用 `sleep` 模拟一次网络请求，第 26 章会换成真正的网络和文件操作。
- **`eventLoop()`** 创建一个事件循环，它来自 `scoop.asyncio` 库。事件循环负责执行任务、在等待的事情完成时唤醒任务。
- **`loop.run { ... }`** 运行事件循环，lambda 中就是挂起代码可以运行的地方。`run` 会一直运行到 lambda 和它启动的所有任务都结束，然后返回 lambda 的结果，所以 `total` 是 `apple.await() + kiwi.await()` 的值。一个事件循环只能 `run` 一次。
- **`async { ... }`** 启动一个新任务，立即返回一个 `Deferred<Int>`，不等任务完成。`run` 的参数是带接收者的函数类型 `suspend CoroutineScope.() -> T`（第 7 章 7.7 节），lambda 中的 `this` 是一个 `CoroutineScope`，所以可以直接写 `async`。
- **`await()`** 等待任务完成并取得结果。两个请求是同时发出的，所以总共只等了大约 50 毫秒，而不是 100 毫秒。
- **`currentEventLoop()`** 取得当前正在运行的事件循环。在 `run` 之外调用它会抛出 `MissingContextException`。

挂起函数只能在另一个挂起函数中调用，或者在 `run`、`async` 这类入口提供的挂起 lambda 中调用。普通的 `main` 不能直接调用它：

```scoop
{{#include ../../examples/ch25/call_fail.scoop}}
```

```text
{{#include ../../examples/ch25/call_fail.error}}
```

`main` 本身也不能是 `suspend` 的：

```scoop
{{#include ../../examples/ch25/suspend_main_fail.scoop}}
```

```text
{{#include ../../examples/ch25/suspend_main_fail.error}}
```

所以每个使用协程的程序都是这样的结构：普通的 `main` 创建事件循环，调用 `run`，在 `run` 里面调用挂起函数。

## 25.2　`suspend` 是什么、不是什么

`suspend` 只表示**这个函数可以在中途暂停**。它不会开新线程，也不会让代码并行执行：

```scoop
{{#include ../../examples/ch25/one_thread.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/one_thread.expected}}
```

（为了让输出固定，例子只打印了比较的结果，没有打印具体的毫秒数。）

- `eventLoop()` 的事件循环只用**一个线程**执行任务，新任务和 `run` 的 lambda 在同一个线程上。
- 两个任务各用 `loop.sleep` 等待 100 毫秒，总共只花了 100 毫秒左右：一个任务暂停时，线程去执行另一个任务，两段等待重叠在了一起。
- 换成 `scoop.platform.time` 中的 `sleep` 后，总时间变成了 200 毫秒以上。这个 `sleep` **阻塞**整个线程（第 24 章）：第一个任务睡着时，线程停在那里，第二个任务根本没有机会执行。

这就是协程的基本模型：多个任务轮流使用同一个线程，**只在挂起点交接**。由此可以得出几条规则：

- **在协程中不要调用会阻塞线程的函数**，比如平台库的 `sleep`、同步的文件和网络操作、长时间的计算。它们会让同一个事件循环上的所有任务停顿。阻塞操作应该交给阻塞池（第 26 章），计算密集的工作可以放到多线程的执行器上（第 27 章）。
- **协程带来的是并发（concurrency），不是并行（parallelism）。** 并发是“同时处理多件事”，比如同时等待两个网络请求；并行是“同时执行多件事”，需要多个 CPU 核心一起计算。单线程的事件循环只有并发。
- **两个挂起点之间的代码不会被其他任务打断。** 在单线程的事件循环上，任务只在挂起点让出线程，所以修改共享的变量时，只要中间没有挂起调用，就不会和其他任务冲突。多线程的执行器没有这个保证（第 27 章）。

## 25.3　挂起 lambda

函数类型也区分是否挂起：`suspend () -> Int` 是挂起函数类型，`() -> Int` 是普通函数类型，两者**不能互相转换**。

```scoop
{{#include ../../examples/ch25/lambdas.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/lambdas.expected}}
```

一个 lambda 是不是挂起的，由它的**期望类型**决定：

- 期望类型是挂起函数类型时，`{ ... }` 就是挂起 lambda，比如 `typed` 的类型标注，或者 `twice` 的参数类型。`async`、`launch`、`run` 的参数都是挂起函数类型，所以传给它们的 lambda 里可以调用挂起函数。
- 也可以显式写 `suspend { ... }`，如 `marked`。
- 没有期望类型时，`{ ... }` 是普通 lambda，里面不能调用挂起函数：

```scoop
{{#include ../../examples/ch25/plain_lambda_fail.scoop}}
```

```text
{{#include ../../examples/ch25/plain_lambda_fail.error}}
```

报错中的 `$lambda.1` 指的就是这个 lambda。

- 已经有类型的普通函数值，不能当作挂起函数传入：

```scoop
{{#include ../../examples/ch25/plain_value_fail.scoop}}
```

```text
{{#include ../../examples/ch25/plain_value_fail.error}}
```

需要时用一个新的 lambda 把它包起来：`twice { plain() }`。

这条规则带来一个和 Kotlin 很不一样的后果：**集合操作的 lambda 不能挂起。** `map`、`filter`、`forEach` 的参数都是普通函数类型：

```scoop
{{#include ../../examples/ch25/map_await_fail.scoop}}
```

```text
{{#include ../../examples/ch25/map_await_fail.error}}
```

第一个 `map` 没有问题，因为 `async { ... }` 本身是普通函数，它只是启动任务；第二个 `map` 中的 `await()` 是挂起函数，不能出现在普通 lambda 里。需要对每个元素调用挂起函数时，用 `for` 循环，下一节的例子就是这样写的。

> **从 Kotlin 过来**
>
> Kotlin 中 `tasks.map { it.await() }`、`list.forEach { delay(10) }` 都能编译，因为这些集合函数是 `inline` 的，lambda 被展开到调用处，成了外层挂起函数的一部分。Scoop 的 `inline` 不改变语义（第 7 章），lambda 就是一个普通的函数值，所以只能用 `for` 循环。

## 25.4　结构化并发

“结构化并发”的意思是：**任务形成一棵树，父任务要等所有子任务结束才算结束。** 这样就不会有“被遗忘在后台的任务”：只要一个函数返回了，它启动的所有任务也都结束了。

```scoop
{{#include ../../examples/ch25/structured.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/structured.expected}}
```

- **`launch { ... }`** 启动一个不需要返回结果的任务，返回一个 `Job`；`job.join()` 等待它结束。**`async { ... }`** 启动一个有结果的任务，返回 `Deferred<T>`，它是 `Job` 的子类，多了 `await()`。
- **`launch` 和 `async` 是 `CoroutineScope` 的方法。** `run` 的 lambda、`launch`/`async` 的 lambda 都以 `CoroutineScope` 为 receiver，所以在它们里面可以直接调用。普通的挂起函数里没有现成的作用域，要用 **`coroutineScope { ... }`** 建立一个。
- **`coroutineScope` 等待它里面启动的所有任务。** `warmUp` 启动了两个任务，自己没有 `join`，但 `coroutineScope` 要等它们都结束才返回，所以 `main` 中能看到 3 条日志。这也是 `run` 的行为：它等待 lambda 中启动的所有任务。
- **作用域结束后不能再启动任务。** 把作用域带到 `coroutineScope` 之外再调用 `launch`，会抛出 `IllegalStateException`：

```scoop
{{#include ../../examples/ch25/closed_scope.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/closed_scope.expected}}
```

Scoop 没有 Kotlin 的 `GlobalScope`。所有任务都必须属于某个作用域，最外层的作用域就是 `run` 建立的那一个。

### 失败的传播

子任务抛出异常（取消除外）时，失败会**向上传播**：父作用域取消它的其他子任务，等它们收尾，然后把原来的异常抛出来。

```scoop
{{#include ../../examples/ch25/failure.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/failure.expected}}
```

`bad` 任务失败后，同一个作用域里的 `slow` 任务被取消了，它的 `finally` 执行了清理；然后 `coroutineScope` 抛出了 `IllegalStateException`，在外面被捕获。**失败在 `coroutineScope` 的边界停下**：它不会继续取消 `coroutineScope` 外面的任务，调用方可以像处理普通函数的异常一样处理它。

这带来一个容易出错的地方：**`async` 失败时，只在 `await()` 外面写 `try`/`catch` 是不够的。** 失败在 `await()` 返回之前就已经传给了父作用域：

```scoop
{{#include ../../examples/ch25/async_failure.scoop}}
```

这个程序没有任何标准输出，而是以退出码 1 结束，标准错误中报告了未捕获的 `IllegalStateException`。`task` 失败后，失败传到了 `run` 的作用域，作用域被取消，正在 `await()` 的代码被取消打断，`catch` 根本没有机会执行；最后 `run` 抛出了这个异常。正确的写法是 `failure.scoop` 后半部分那样，用 `coroutineScope` 把要单独处理失败的任务包起来，再在外面 `catch`。

> **从 Kotlin 过来**
>
> 这和 kotlinx.coroutines 默认的行为是一样的：在普通的 `coroutineScope` 中，`async` 的失败也会取消父作用域。区别是 Scoop 没有 `supervisorScope` 和 `SupervisorJob`，需要“一个子任务失败不影响其他子任务”时，把每个子任务的正文各自用 `coroutineScope` 包起来并捕获异常。

## 25.5　取消

`job.cancel()` 请求取消一个任务。取消是**协作式**的：它不会强行终止任务，而是在任务下一次挂起时（或者已经挂起时），让那个挂起调用抛出 `CancellationException`。异常沿着调用栈向外传，`finally` 照常执行，就像任何其他异常一样。

```scoop
{{#include ../../examples/ch25/cancel.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/cancel.expected}}
```

**`cancel` 之后还要 `join`。** `cancel()` 只是发出请求，它返回时任务还没有结束：`isCancelled` 已经是 `true`，`isCompleted` 还是 `false`。任务要等到下一次被调度，收到 `CancellationException`，执行完 `finally` 才真正结束。`join()` 等待这个过程完成。如果在 `cancel()` 之后马上关闭任务正在使用的资源，任务的清理代码可能还没来得及执行。

例子用一个 `Channel` 确认任务已经进入了 `try`，再取消它（25.6 会解释为什么不用 `sleep`）。`Channel` 来自 `scoop.concurrent`，第 27 章会详细介绍。

### 不要吞掉取消

`CancellationException` 是 `Exception` 的子类，所以 `catch (e: Exception)` 也会捕获它：

```scoop
{{#include ../../examples/ch25/swallow.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/swallow.expected}}
```

异常被吞掉之后，任务继续执行，直到下一个挂起点再次抛出 `CancellationException`：任务处于已取消的状态，之后每一次挂起都会立即失败。程序最终还是结束了，但取消之后多执行了一段本不该执行的代码。所以：**捕获 `Exception` 或 `Throwable` 的地方，要单独让 `CancellationException` 继续抛出**，像 `cancel.scoop` 那样先写一个 `catch (e: CancellationException) { throw e }`，或者只捕获具体的异常类型。

### 计算循环要让出

取消只在挂起点生效。一个没有挂起点的计算循环永远不会被取消，而且在单线程的事件循环上，它还会霸占线程，让其他任务（包括要调用 `cancel()` 的那个任务）都无法执行：

```scoop
{{#include ../../examples/ch25/cpu_loop.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/cpu_loop.expected}}
```

`yieldCoroutine()` 主动让出线程，让其他任务有机会执行，并且在让出前后检查任务是否已被取消。只需要检查取消、不需要让出时，调用 `ensureActive()`，它在任务已被取消时抛出 `CancellationException`。长时间的计算最好放到多线程的执行器上（第 27 章），而不是放在事件循环里。

### 取消之后的异步清理

任务被取消后，它的每一次挂起都会立即失败，`finally` 中的挂起调用也不例外。清理工作本身需要挂起时（比如把缓冲的日志异步写出去），要用 `nonCancellableScope { ... }` 把它包起来：

```scoop
{{#include ../../examples/ch25/cleanup.scoop}}
```

输出：

```text
{{#include ../../examples/ch25/cleanup.expected}}
```

`nonCancellableScope` 中的代码不受外面的取消影响，会一直执行到完成。只在 `finally` 中做必要的清理时使用它，不要用它包住普通的业务逻辑，否则任务就无法被取消了。

## 25.6　不要用睡眠来同步

“先启动一个任务，`sleep` 一小会儿，假设它已经开始执行了，再做下一步”是一种常见但错误的写法。睡眠的时长只是一个猜测：机器忙的时候、调度顺序变化的时候，猜测就会失败，而且这种失败很难复现。

需要“等某件事发生”时，用明确的同步手段：

- 等一个任务结束：`join()`；等它的结果：`await()`。
- 等一个任务到达某个状态：让它通过 `Channel` 发出信号，像 25.5 的 `started.send(Unit)` 和 `started.receive()`。
- 等多个任务都结束：把它们放在同一个 `coroutineScope` 里。

`sleep` 只应该用于真的需要等待一段时间的场合，比如重试之间的退避、定时任务的间隔。同样，也不要用睡眠时长来决定输出的顺序：本书的例子都是在 `await` 或 `join` 之后才打印结果的。

> **深入一点：挂起是怎么实现的**
>
> 编译器把每个挂起函数改写成一个状态机：函数中的每个挂起点是一个状态，跨越挂起点还要使用的局部变量被保存在一个对象里。挂起时，函数保存当前状态并返回到事件循环；等待的事情完成后，事件循环通过一个 `Continuation` 对象调用状态机，从保存的状态继续执行。
>
> 核心库提供了这一层的原语：`suspendCoroutine` 让你拿到当前的 `Continuation`，在某个回调中调用 `resume` 继续；`suspendCancellableCoroutine` 还能响应取消。`launch`、`async`、`EventLoop.sleep` 都建立在它们之上。普通的应用代码不需要直接使用这些原语，它们主要用于把基于回调的 API 包装成挂起函数。

## 从 Kotlin 过来：概念对照

| kotlinx.coroutines | Scoop |
| --- | --- |
| `runBlocking { }` | `eventLoop().run { }`（`scoop.asyncio`） |
| `suspend fun main()` | 不允许；普通 `main` 中调用 `run` |
| `GlobalScope.launch { }` | 不存在；任务必须属于某个作用域 |
| `CoroutineScope.launch`、`async`、`await`、`join` | 相同 |
| `coroutineScope { }` | 相同 |
| `supervisorScope { }`、`SupervisorJob` | 不存在；每个子任务各自用 `coroutineScope` 包起来并捕获异常 |
| `delay(100)` | `currentEventLoop().sleep(100.milliseconds())` |
| `withContext(Dispatchers.IO) { }` | `blocking { }`（第 26 章） |
| `Dispatchers.Default` | 多线程执行器：`asyncRuntime`、`multiThreadExecutor`、`withExecutor`（第 27 章） |
| `job.cancelAndJoin()` | `job.cancel()` 之后 `job.join()` |
| `isActive`、`ensureActive()` | `!job.isCancelled`、`ensureActive()` |
| `yield()` | `yieldCoroutine()` |
| `withContext(NonCancellable) { }` | `nonCancellableScope { }` |
| `withTimeout`、`withTimeoutOrNull` | 不存在；第 26 章用定时器组合出一个 |
| `list.map { it.await() }` | 集合 lambda 不能挂起；用 `for` 循环 |
| `Channel`、`Mutex` | `scoop.concurrent` 的 `Channel`、`AsyncMutex`（第 27 章） |
| `Flow`、`select` | 不存在 |
| `CoroutineContext` 元素、`ThreadLocal` | task-local context：`context(...)`（第 26 章） |
| `CoroutineExceptionHandler` | 不存在；未处理的失败从 `run` 抛出 |
| `suspendCancellableCoroutine` | 相同 |

## 常见误用

- **在普通 `main` 中直接调用挂起函数**：先创建事件循环，在 `run` 中调用。
- **在协程中调用阻塞线程的函数**：平台库的 `sleep`、同步 IO、长时间计算会让整个事件循环停顿；交给阻塞池或多线程执行器。
- **以为 `suspend` 函数会在后台线程执行**：它只是可以暂停，仍在调用它的线程上执行。
- **在 `map`、`forEach` 的 lambda 中调用挂起函数**：用 `for` 循环。
- **只在 `await()` 外面 `catch` 子任务的失败**：失败会先传给父作用域；用 `coroutineScope` 包起来。
- **`cancel()` 之后不 `join()`**：任务的清理可能还没有执行。
- **吞掉 `CancellationException`**：捕获宽泛的异常时，让取消继续抛出。
- **计算循环中没有挂起点**：定期调用 `yieldCoroutine()` 或 `ensureActive()`。
- **在 `finally` 中直接做异步清理**：任务已被取消时会立即失败；用 `nonCancellableScope`。
- **用 `sleep` 等待另一个任务到达某个状态**：用 `Channel`、`join`、`await`。

## 小结

- 挂起函数可以在中途暂停，只能在挂起上下文中调用。普通的 `main` 用 `eventLoop().run { ... }` 进入挂起上下文，`run` 返回 lambda 的结果。
- `suspend` 不等于开线程。`eventLoop()` 的事件循环只用一个线程，任务在挂起点轮流执行；阻塞线程的调用会让所有任务停顿。
- 挂起函数类型和普通函数类型不能互相转换；lambda 是否挂起由期望类型决定，也可以写 `suspend { }`。集合操作的 lambda 不能挂起。
- `launch` 启动任务并返回 `Job`，`async` 返回 `Deferred`；它们是 `CoroutineScope` 的方法，挂起函数中用 `coroutineScope` 建立作用域。作用域等待所有子任务结束。
- 子任务的失败会取消兄弟任务并向上传播，在 `coroutineScope` 的边界停下。
- 取消是协作式的，在挂起点抛出 `CancellationException`；`cancel` 之后要 `join`，不要吞掉取消，计算循环要让出，取消后的异步清理用 `nonCancellableScope`。
- 用 `join`、`await`、`Channel` 等明确的手段同步，不要用睡眠。

## 练习

1. 写一个挂起函数 `fetchAll(names: List<String>): Int`，为每个名字启动一个 `async` 任务，模拟耗时不同的请求，返回所有结果的总和。验证总耗时接近最慢的那个请求，而不是所有请求之和。
2. 修改 25.4 的 `failure.scoop`：让三个下载任务中的一个失败，但其他两个照常完成，最后打印成功的结果和失败的数量。提示：每个任务的正文各自用 `coroutineScope` 和 `try` 包起来。
3. 写一个“心跳”任务，每隔 10 毫秒打印一次计数，在主任务中等待它打印 5 次之后取消它。用 `Channel` 传递“已打印 5 次”的信号，而不是猜测睡眠时长。
4. 下面这段代码有什么问题？分别说明在单线程的事件循环中会发生什么。

```scoop
{{#include ../../examples/ch25/exercise_wrong.scoop:wrong}}
```
