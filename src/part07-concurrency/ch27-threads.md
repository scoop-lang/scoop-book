# 第 27 章　线程与同步

前两章的协程都运行在一个线程上，任务只在挂起点轮流执行。这有一个很大的好处：两个挂起点之间的代码不会被打断，共享的数据不需要加锁。代价是只能用一个 CPU 核心。

需要让多个核心**同时**计算时，就要用到多个线程：直接启动线程，或者让协程运行在多线程的执行器上。这时多个线程可能同时访问同一份数据，就必须考虑**同步**。

这是 Scoop 和 Rust、Swift 明显不同的地方：**Scoop 不在编译时检查跨线程的数据访问是否安全。** 编译器不会阻止你在两个线程中同时修改同一个对象，正确地同步是程序员的责任。本章会花一节专门讲清楚什么是数据竞争、为什么它很危险，以及怎样避免。

本章介绍：

- 用 `Thread` 启动线程；
- 数据竞争；
- 锁与条件变量；
- 原子类型与内存序；
- 多线程执行器：`asyncRuntime`、`multiThreadExecutor`、`withExecutor`；
- `scoop.concurrent` 中的 `Channel`、`AsyncMutex`、`AsyncConditionVariable`；
- 一个生产者/消费者的例子。

## 27.1　线程

```scoop
{{#include ../../examples/ch27/threads.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/threads.expected}}
```

线程相关的类型在平台库的 `scoop.platform.concurrent` 包中：

- `Thread.start { ... }` 启动一个新的操作系统线程，执行 lambda，立即返回一个 `Thread`。
- `join()` 等待线程结束。线程中未捕获的异常不会让程序崩溃，而是在 `join` 时重新抛出。`isFinished` 查询线程的代码是否已经执行完。
- `Thread` 实现了 `Disposable`，`dispose` 时如果还没有 `join`，就 `join` 它。所以可以用 `use` 保证线程被等待。**启动的线程都应该被 `join`**：程序不会在退出前自动等待它们。
- 线程继承启动时的 task-local context（第 26 章）。`currentThreadId()` 返回当前线程的标识，`yield()` 请求让出当前线程。

例子中四个线程各自计算一段范围的和，写进**自己的** `Box`，主线程在 `join` 之后再读取它们。这是多线程程序最简单、最安全的模式：每个线程只写自己的数据，`join` 之后再汇总。`join` 保证线程中的所有写入，对 `join` 返回之后的代码都是可见的。

## 27.2　数据竞争

先看一个错误的例子。四个线程各把同一个计数器加 10 万次：

```scoop
{{#include ../../examples/ch27/counters.scoop:racy}}
```

你可能期望结果是 40 万，或者认为最坏不过是“少加了几次”。实际情况比这更糟。

`counter.value += 1L` 看起来是一步，实际上是三步：读出当前值，加 1，写回去。两个线程同时执行时，可能都读到了 100，都写回 101，其中一次加法就丢了。但这只是最直观的一种后果。编译器和 CPU 为了速度，会在不改变**单线程**结果的前提下调整代码：把值留在寄存器里，暂时不写回内存；改变读写的先后顺序；把一次读写拆成几次。每个 CPU 核心还有自己的缓存，一个核心写入的值，另一个核心不一定马上看得到。这些优化对单线程程序是安全的，对没有同步的多线程程序却会产生各种无法预料的结果。

所以，**数据竞争**的定义是：

> 两个线程访问同一个存储位置（字段、数组元素、全局变量等），其中至少一个是写入，至少一个不是原子操作，而且两次访问之间没有任何同步来确定先后顺序。

Scoop 规定，**数据竞争是未定义行为**。“未定义”的意思是语言对程序的行为不做任何保证：可能得到错误的数值，可能读到一个“一半是旧值、一半是新值”的引用，进而让程序崩溃或者破坏内存；而且这些后果可能只在某台机器、某种负载下出现，平时测试一切正常。这和“结果偏小”有本质的区别：你无法通过检查结果来判断程序是否出了问题。因此 `racyCount` 在例子中只定义、不运行。

注意以下几点**不能**防止数据竞争：

- **`val`。** `val counter = Counter()` 只保证 `counter` 这个变量不被重新赋值，不保证它指向的对象不被修改，也不提供任何跨线程的同步。
- **GC。** GC 保证对象不会在使用中被回收，但不保证并发访问的正确性。
- **“这个操作很小”。** 读写一个 `Long`、一个引用，同样可能发生数据竞争。

避免数据竞争的办法，按推荐程度排列：

1. **不共享。** 每个线程只操作自己的数据，像 27.1 那样在 `join` 之后汇总。
2. **只共享不再修改的数据。** 在启动线程之前准备好数据，线程只读不写。启动线程本身就是一次同步，启动前的写入对新线程是可见的。
3. **传递消息而不是共享数据。** 用 `Channel`（27.6）把数据从一个任务交给另一个任务，交出去之后就不再访问它。
4. **用锁保护共享的数据**（27.3）。
5. **用原子类型**（27.4），适合计数器、标志这类单个的值。

同样的规则也适用于协程。单线程的事件循环上，任务只在挂起点轮流执行，不会发生数据竞争；但在 27.5 的多线程执行器上，不同的任务可能同时运行在不同的线程上，它们共享的数据同样需要同步。

> **从 Kotlin 过来**
>
> JVM 对数据竞争的后果有一定的限制：读到的值至少是某个线程曾经写入的值，引用不会“撕裂”，所以有数据竞争的 Kotlin 程序通常只是结果出错，不会破坏内存。Scoop 是编译到原生代码的语言，没有这样的保证，规则更接近 C、C++ 和 Rust 的 `unsafe` 代码。另外，Kotlin 的 `@Volatile` 在 Scoop 中没有对应物，需要类似的效果时，使用原子类型。

## 27.3　锁与条件变量

27.2 的 `racyCount` 来自下面这个程序，另外两个函数分别用锁和原子类型修正了它：

```scoop
{{#include ../../examples/ch27/counters.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/counters.expected}}
```

`lockedCount` 用 `scoop.platform.concurrent` 中的 `Mutex` 保护计数器：

- `lock.withLock { ... }` 获得锁、执行 lambda、释放锁，lambda 抛出异常时也会释放。同一时刻只有一个线程能持有锁，其他线程在 `withLock` 处等待。
- **所有**访问共享数据的地方都要在同一把锁的保护下，包括最后读取结果的 `lock.withLock { counter.value }`。只在写入时加锁、读取时不加锁，仍然是数据竞争。
- 也可以手动调用 `lock()`、`unlock()`，`tryLock()` 在锁被占用时立即返回 `false`。优先使用 `withLock`，不会忘记解锁。
- `Mutex` **不可重入**：已经持有锁的线程再次 `lock()` 会抛出 `PlatformException`，而不是像 Kotlin 的 `synchronized` 那样直接进入。
- `Mutex` 实现了 `Disposable`，不再使用时可以 `dispose`。

### 条件变量

“等到某个条件成立”是另一种常见的需求，比如消费者等待队列中有数据。用 `ConditionVariable`：

```scoop
{{#include ../../examples/ch27/queue.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/queue.expected}}
```

- `ConditionVariable(lock)` 和一把 `Mutex` 绑定。
- `await()` 必须在持有锁时调用：它**原子地**释放锁并开始等待，被唤醒后重新获得锁再返回。`await(timeout)` 多了一个超时，返回 `false` 表示超时。
- `signal()` 唤醒一个等待者，`broadcast()` 唤醒全部等待者。
- **`await` 返回不代表条件已经成立**：可能被另一个线程抢先取走了数据，也可能是系统的“虚假唤醒”。所以总是在 `while` 循环中检查条件，而不是 `if`。

例子中的 `BlockingQueue<Int?>` 用 `None` 作为“没有更多数据了”的标记。

**在协程中不要使用平台库的 `Mutex` 和 `ConditionVariable`。** 它们会阻塞整个线程，在事件循环上会让所有任务停顿；而且 `withLock` 的 lambda 是普通函数，里面不能挂起：

```scoop
{{#include ../../examples/ch27/mutex_suspend_fail.scoop}}
```

```text
{{#include ../../examples/ch27/mutex_suspend_fail.error}}
```

协程中使用 27.6 的 `AsyncMutex` 和 `AsyncConditionVariable`。

## 27.4　原子类型

原子类型是核心库提供的、可以被多个线程安全地同时读写的单个值，不需要 import：

```scoop
{{#include ../../examples/ch27/atomics.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/atomics.expected}}
```

| 类型 | 保存的值 |
| --- | --- |
| `AtomicInt`、`AtomicLong` | 整数 |
| `AtomicBoolean` | 布尔值 |
| `AtomicRef<T>` | 一个引用，`T` 必须是引用类型 |
| `Atomic<T>` | 一个值类型（struct、tuple 等），`T` 必须是值类型 |

它们的共同操作：

| 方法 | 作用 |
| --- | --- |
| `load()`、`store(v)` | 读取、写入 |
| `exchange(v)` | 写入并返回旧值 |
| `compareAndSet(expected, v)` | 当前值等于 `expected` 时写入 `v`，返回是否成功 |
| `compareAndExchange(expected, v)` | 同上，返回操作时看到的旧值 |
| `getAndUpdate { }`、`updateAndGet { }` | 用函数计算新值，竞争失败时自动重试，分别返回旧值、新值 |
| `fetchAdd`、`fetchSub`、`fetchAnd`、`fetchOr`、`fetchXor` | 整数（布尔值只有后三个）的原子运算，返回旧值 |

几点说明：

- 原子操作是**一步完成**的，`fetchAdd(1L)` 不会出现 27.2 中“读、加、写”被打断的问题，所以 27.3 的 `atomicCount` 也得到了正确的 40 万。整数运算溢出时回绕。
- **`AtomicRef` 比较的是对象身份，不是内容。** `compareAndSet(Settings(1), ...)` 失败了，因为新构造的 `Settings(1)` 和当前保存的不是同一个对象。CAS 时要传入之前 `load()` 得到的那个引用。字符串也是如此：内容相同的两个字符串不一定是同一个对象。
- **`AtomicRef` 只保护引用本身。** 通过它取得的对象，后续对字段的读写仍然需要同步，最好让这样的对象是不可变的，需要修改时创建新对象，再用 CAS 替换引用。
- `Atomic<T>` 原子地读写一个完整的值类型，内部用一个很小的锁实现，适合保存 tuple、struct 这样的小值。
- 原子对象本身没有实现 `Equals`、`ToString`，比较和打印时先 `load()`。

### 内存序

原子操作的方法都有一个可选的 `MemoryOrder` 参数，默认是 `SeqCst`。内存序决定了一个原子操作除了保证自身原子之外，还对**其他**内存访问的可见性做出什么保证。常用的只有三种情况。

**默认的 `SeqCst`**：最强、最容易理解的保证。不确定时就用它，大多数程序不需要更改。

**`Release` 写和 `Acquire` 读配对**：用来“发布”数据。一个线程先准备好普通的数据，再以 `Release` 写入一个标志；另一个线程以 `Acquire` 读到这个标志之后，就一定能看到前者在 `Release` 之前写入的数据：

```scoop
{{#include ../../examples/ch27/publish.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/publish.expected}}
```

如果标志的写入或读取用了 `Relaxed`，`reader` 读到 `true` 之后，仍然可能看到 `config` 的旧内容，这就是数据竞争。（例子中 `reader` 用循环反复检查标志，只是为了演示；实际程序中等待一个条件应该用条件变量或 `Channel`，而不是空转。）

**`Relaxed`**：只保证这个操作本身是原子的，不对其他数据做任何保证。适合只用来统计的计数器，比如“处理了多少个请求”，只在最后读取一次总数。

内存序必须是写在代码中的常量，每种操作允许的内存序也有限制，比如 `load` 不能用 `Release`。这些都在编译时检查：

```scoop
{{#include ../../examples/ch27/order_fail.scoop}}
```

```text
{{#include ../../examples/ch27/order_fail.error}}
```

```scoop
{{#include ../../examples/ch27/order_variable_fail.scoop}}
```

```text
{{#include ../../examples/ch27/order_variable_fail.error}}
```

> **深入一点：happens-before**
>
> 多线程程序中，“先”和“后”不是由时间决定的，而是由一个叫 **happens-before** 的关系决定的。它由三部分组成：同一个线程中，按代码顺序先执行的操作 happens-before 后执行的操作；线程同步建立的跨线程关系，比如 `Release` 写与读到这个值的 `Acquire` 读、`unlock` 与之后的 `lock`、启动线程与线程的第一条语句、线程的最后一条语句与 `join` 返回；以及以上关系的传递。如果一次写入 happens-before 一次读取，读取就一定能看到这次写入（或者更新的值）。数据竞争就是两次冲突的访问之间没有 happens-before 关系。
>
> Scoop 的原子操作和内存序采用 C11/C++11 的内存模型。五种内存序中，`AcqRel` 用于既读又写的操作（如 `fetchAdd`、CAS），同时具有 `Acquire` 和 `Release` 的效果；`SeqCst` 在此基础上，还保证所有 `SeqCst` 操作在所有线程看来有同一个先后顺序。CAS 失败时的内存序不能强于成功时的内存序。更多细节可以参考 C++ 的 `std::memory_order` 文档，语言规范第 1.2 节和第 11.14 节给出了 Scoop 的完整规则。

## 27.5　多线程执行器

第 25 章的事件循环只有一个线程。需要让协程在多个核心上并行执行时，有两种方式。

**`asyncRuntime`**：一个多线程的运行时，用法和 `eventLoop` 相同，但有多个工作线程，每个都能执行任务和处理 IO：

```scoop
{{#include ../../examples/ch27/runtime.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/runtime.expected}}
```

`workers` 默认是 CPU 的逻辑核心数。四个 `async` 任务可能被分到不同的线程上，同时计算。

**`multiThreadExecutor` 加 `withExecutor`**：保留单线程的事件循环处理 IO，只把计算密集的部分放到一个独立的线程池上：

```scoop
{{#include ../../examples/ch27/with_executor.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/with_executor.expected}}
```

- `multiThreadExecutor { workers = 2 }` 创建一个有两个工作线程的执行器，它来自 `scoop.concurrent`。它实现了 `Closeable`，用完要关闭，`use` 结束时会等待所有工作线程退出。
- `withExecutor(pool) { ... }` 把代码块放到 `pool` 上执行，里面启动的子任务也在 `pool` 上；代码块结束后，回到原来的事件循环线程继续执行。它和 `coroutineScope` 一样，等待所有子任务，失败时在这里抛出。

什么时候用哪一种：

| 需求 | 用什么 |
| --- | --- |
| 主要是等待 IO，计算很少 | `eventLoop()`，单线程最简单，不用考虑数据竞争 |
| 调用会阻塞线程的同步 API | `blocking { }`（第 26 章） |
| 有计算密集的部分 | `withExecutor(multiThreadExecutor { ... })`，或者直接用 `asyncRuntime` |
| 大量并发连接，IO 和计算都多 | `asyncRuntime` |

**在多线程执行器上，任务之间共享的数据必须同步：**

```scoop
{{#include ../../examples/ch27/shared_state.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/shared_state.expected}}
```

8 个任务被分到了不同的线程上，它们都要向同一个 `HashSet` 中添加元素，所以用 `AsyncMutex` 保护。`HashSet` 本身不是线程安全的，不加锁就是数据竞争。

## 27.6　`scoop.concurrent`

`scoop.concurrent` 提供了协程之间的同步工具。它们可以在单线程的事件循环上使用，也可以跨多个执行器、跨线程使用。等待时它们**挂起任务**，而不是阻塞线程，并且都能响应取消。

### `Channel`

`Channel` 是一个先进先出的消息通道，可以有多个发送方和多个接收方：

```scoop
{{#include ../../examples/ch27/channel.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/channel.expected}}
```

- **构造时必须指定容量。** `Channel<Int>(2L)` 最多缓冲 2 条消息，缓冲满了，`send` 就挂起，直到有接收方取走消息，这样快的发送方就不会无限制地堆积数据。容量为 0 时，发送方和接收方要“碰头”才能交接。Scoop 没有容量无限的 Channel。
- `send` 发送，`receive` 接收；`receiveOrNone` 在 Channel 已关闭且没有剩余消息时返回 `None`，适合写成 `?: break` 的循环。
- **`close()` 表示不会再发送了。** 之后的 `send` 抛出 `ChannelClosedException`；已经发送的消息仍然可以被取完，取完之后 `receive` 抛出 `ChannelClosedException`。第一次 `close` 返回 `true`，之后返回 `false`。
- `trySend`、`tryReceive` 不挂起：`trySend` 返回 `TrySendResult`（`Sent`、`Full`、`Closed`），`tryReceive` 返回 `TryReceiveResult`（`Value(v)`、`Empty`、`Closed`）。

`close` 不会清理 Channel 中尚未取走的消息。如果消息中带有需要关闭的资源，要安排好由谁取走并关闭它们。

### `AsyncMutex`

`AsyncMutex` 是协程用的锁。和平台库的 `Mutex` 不同，等待锁时挂起任务而不是阻塞线程，而且**持有锁的期间可以挂起**：

```scoop
{{#include ../../examples/ch27/async_mutex.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/async_mutex.expected}}
```

`withdraw` 先检查余额，然后等待（模拟调用风控服务），再扣款。即使在单线程的事件循环上，检查和扣款之间有一个挂起点，其他任务可能在这时执行，如果不加锁，三个任务可能都看到余额 100，都扣款成功，余额变成 -20。用 `AsyncMutex` 把“检查加扣款”整个保护起来，就只有两次扣款成功。这说明：**单线程只保证两个挂起点之间不被打断；跨越挂起点的操作，在单线程上也需要同步。**

`AsyncMutex` 同样不可重入，同一个任务重复获取会永远等待自己。`withLock` 的 lambda 以 `AsyncMutexGuard` 为 receiver，它代表这一次持有的锁；也可以用 `lock()` 取得 guard，用 `dispose()` 释放。

### `AsyncConditionVariable`

```scoop
{{#include ../../examples/ch27/gate.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/gate.expected}}
```

`AsyncConditionVariable` 和一个 `AsyncMutex` 绑定，用法和 27.3 的条件变量相同：持有锁时 `await(guard)`，被唤醒后在 `while` 循环中重新检查条件；`signal(guard)`、`broadcast(guard)` 唤醒等待者。所有方法都要传入当前持有的 guard，在 `withLock` 的 lambda 中就是 `this`。

## 27.7　生产者与消费者

把前面的内容组合起来：两个生产者和三个消费者在多线程运行时上并行工作，通过一个 `Channel` 传递订单：

```scoop
{{#include ../../examples/ch27/pipeline.scoop}}
```

输出：

```text
{{#include ../../examples/ch27/pipeline.expected}}
```

这个结构可以推广到大多数“流水线”式的程序：

- **数据通过 `Channel` 传递**，生产者和消费者不直接共享订单对象。`Order` 是 struct，发送时复制了一份，更不会有共享的问题。
- **有限的容量**让生产者不会比消费者快太多：消费者跟不上时，`send` 挂起，生产者自然放慢。
- **关闭表示结束**：所有生产者结束后关闭 Channel，消费者取完剩余的订单，`receiveOrNone` 返回 `None`，循环结束。注意关闭要等**所有**生产者都结束，这里用 `join` 等待它们。
- **共享的统计用原子类型**，三个消费者并行地累加 `revenue` 和 `processed`。
- **`coroutineScope` 等待全部任务**，然后才读取最终结果。

## 从 Kotlin 过来：常见写法对照

| Kotlin / JVM | Scoop |
| --- | --- |
| `thread { }`、`Thread(...).start()` | `Thread.start { }`（`scoop.platform.concurrent`） |
| `thread.join()` | 相同；线程中的异常在 `join` 时重新抛出 |
| `synchronized(lock) { }` | `Mutex` 的 `withLock { }`；不可重入 |
| `ReentrantLock` | `Mutex`，但不可重入 |
| `Object.wait()`/`notify()`、`Condition` | `ConditionVariable` 的 `await`、`signal`、`broadcast` |
| `@Volatile var` | 原子类型，如 `AtomicBoolean`，配合 `Release`/`Acquire` |
| `AtomicInteger`、`AtomicLong`、`AtomicBoolean`、`AtomicReference` | `AtomicInt`、`AtomicLong`、`AtomicBoolean`、`AtomicRef`；`AtomicRef` 按身份比较 |
| `incrementAndGet()` | `fetchAdd(1)` 返回旧值；需要新值时 `updateAndGet { v -> v + 1 }` |
| `ConcurrentHashMap` | 不存在；用锁保护普通的 `HashMap` |
| `Executors.newFixedThreadPool(n)` | `multiThreadExecutor { workers = n }`，或用于阻塞任务的 `BlockingTaskPool` |
| `Dispatchers.Default` | `asyncRuntime { }` 或 `withExecutor(multiThreadExecutor { })` |
| kotlinx `Channel(UNLIMITED)` | `Channel<T>(capacity)`，容量必须指定，没有无限容量 |
| kotlinx `Mutex().withLock { }` | `AsyncMutex().withLock { }` |
| JVM 内存模型对数据竞争的限制 | 没有；数据竞争是未定义行为 |

## 常见误用

- **以为 `val` 能防止数据竞争**：它只防止重新赋值，不提供同步。
- **只在写入时加锁，读取时不加锁**：读写都要在同一把锁的保护下。
- **在 `if` 中而不是 `while` 中等待条件变量**：被唤醒不代表条件成立。
- **在协程中使用平台库的 `Mutex`、`ConditionVariable`**：它们会阻塞线程，`withLock` 中也不能挂起；用 `AsyncMutex`、`AsyncConditionVariable`。
- **重复获取同一把锁**：`Mutex` 和 `AsyncMutex` 都不可重入。
- **用新构造的对象调用 `AtomicRef.compareAndSet`**：比较的是身份，要传入之前读到的引用。
- **随意使用 `Relaxed`**：它不保证其他数据的可见性；不确定时用默认的 `SeqCst`。
- **以为单线程的事件循环上永远不需要锁**：跨越挂起点的“检查后修改”同样需要 `AsyncMutex`。
- **在多线程执行器上的任务之间共享集合而不加锁**：标准库的集合都不是线程安全的。
- **启动线程后不 `join`**：用 `join` 或 `use` 等待线程结束。
- **在生产者还没有全部结束时关闭 Channel**：其他生产者的 `send` 会失败。

## 小结

- `Thread.start` 启动线程，`join` 等待它并重新抛出其中的异常；`Thread` 实现了 `Disposable`。
- 数据竞争是两个线程在没有同步的情况下访问同一位置、且至少一个是写入；在 Scoop 中它是未定义行为，编译器不检查。
- 避免数据竞争：不共享、只共享不可变的数据、传递消息、加锁、使用原子类型。
- 平台库的 `Mutex` 和 `ConditionVariable` 用于线程，会阻塞线程；条件变量要在 `while` 中等待。
- 原子类型提供单个值的原子读写和更新；默认的 `SeqCst` 内存序最安全，`Release`/`Acquire` 用于发布数据，`Relaxed` 只用于纯计数。`AtomicRef` 按身份比较。
- `asyncRuntime`、`multiThreadExecutor` 加 `withExecutor` 让协程在多个线程上并行执行，此时任务之间共享的数据需要同步。
- `scoop.concurrent` 的 `Channel`、`AsyncMutex`、`AsyncConditionVariable` 在等待时挂起任务，可以跨执行器和线程使用；`Channel` 必须指定容量，关闭表示不再发送。

## 练习

1. 用 4 个线程并行地统计一个大数组中每个数字出现的次数：每个线程统计自己的一段，写进自己的 `HashMap`，`join` 之后合并。和“所有线程共享一个加锁的 `HashMap`”的写法比较，哪种更快？为什么？
2. 给 27.3 的 `BlockingQueue` 加上容量限制：队列满时，`put` 等待到有空位为止。需要几个条件变量？
3. 用 `AtomicRef` 实现一个线程安全的“配置持有者”：配置对象是不可变的 class，`update` 方法用 `load` 和 `compareAndSet` 循环地替换成新配置。为什么配置对象必须是不可变的？
4. 把 27.7 的例子改成“三级流水线”：生产者产生订单，第一组消费者计算税费后把结果发送到第二个 Channel，第二组消费者汇总。注意每个 Channel 应该在什么时候关闭。
5. 下面的代码在单线程的事件循环上运行，它有数据竞争吗？结果一定正确吗？如果改为在 `asyncRuntime` 上运行呢？

```scoop
{{#include ../../examples/ch27/exercise_counter.scoop:counter}}
```
