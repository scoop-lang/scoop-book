# 第 25 章　协程入门

> 本章尚在编写中。下面是本章计划涵盖的内容。

- `suspend` 是什么、不是什么：它不等于开线程，也不等于并行
- 普通 `main` 里不能直接调用挂起函数：用 `EventLoop` 和 `loop.run` 进入
- 挂起 lambda 要显式写 `suspend { }`
- 结构化并发：`scope.async`/`await`、`scope.launch`/`join`
- 取消：`cancel` 之后还要 `join`；用 `finally` 做清理
- 不要用 `sleep` 当同步手段
- 示例：`async/tasks`
- 「从 Kotlin 过来」：不用 kotlinx.coroutines，各概念的对照表
