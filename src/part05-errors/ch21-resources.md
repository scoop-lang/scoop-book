# 第 21 章　确定性资源释放

> 本章尚在编写中。下面是本章计划涵盖的内容。

- 为什么有了 GC 还要手动关闭资源
- `Closeable`/`Disposable` 与 `use`
- 正文和清理都失败时：`ResourceUseException`
- 库 API 的命名约定：`withX`、`takeX`、`takeOwnership`
- 「深入一点」：`release { }`：遗漏显式关闭时的兜底，不能当作主要手段
- 示例：`io/resources`
