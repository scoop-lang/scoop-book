# 第 2 章　安装与第一个程序

> 本章尚在编写中。下面是本章计划涵盖的内容。

- 安装工具包，`scoop --version`；Windows 上的命令名 `sco`
- `hello.scoop`，以及 `scoop run main.scoop --release`
- `main` 的几种合法形式：`Array<String>` 参数、返回 `Int` 作为退出码；**`args[0L]` 是程序路径**
- `scoop fmt` / `scoop check` / `scoop run` 分别做什么，`check` 通过不等于程序能运行
- 用 `scoop example` 浏览离线示例
- 配置 VS Code 扩展和 LSP
- 「从 Kotlin 过来」：没有 `fun main(args)` 的 JVM 启动语义

## 草稿：第一个程序

```scoop
{{#include ../../examples/ch02/hello.scoop}}
```

输出：

```text
{{#include ../../examples/ch02/hello.expected}}
```
