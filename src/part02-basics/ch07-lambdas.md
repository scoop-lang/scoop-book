# 第 7 章　lambda 与闭包

> 本章尚在编写中。下面是本章计划涵盖的内容。

- 函数类型、lambda、匿名函数、函数引用 `::f`
- lambda 最后一个表达式就是结果；裸 `return` 不合法，要用 `return@label`
- **闭包只能捕获 `val`**：需要共享可变状态时，用 `val` 持有一个对象
- 函数值只能按位置调用，原函数的命名参数和默认参数在这里用不了
- `inline` 等修饰符：可以写，但 Scoop 不会据此改变语义
- 示例：`language/lambdas`
- 「从 Kotlin 过来」：Kotlin 允许捕获 `var` 计数器，Scoop 不允许，给出改写方法
