# 第 2 章　安装与第一个程序

本章把 Scoop 装到你的电脑上，并运行第一个程序。读完本章，你会知道：

- 怎样用安装脚本或 `scoop-install` 安装和管理工具链；
- 怎样运行一个单文件程序，`--release` 是什么意思；
- `main` 函数有哪几种合法的写法，命令行参数从哪里开始；
- `scoop fmt`、`scoop check`、`scoop run` 分别做什么；
- 怎样用 `scoop example` 查阅离线示例；
- 怎样配置 VS Code。

## 2.1　安装工具链

Scoop 的安装由独立的安装器 **`scoop-install`** 负责：它下载指定版本的工具链，安装本机目标平台的预编译库，并管理多个版本。官网提供的一行安装脚本只做一件事：下载适合本机的 `scoop-install`，再用它安装最新的工具链。

### 支持的平台

| 宿主 | 默认目标平台 | 构建应用的前提 |
| --- | --- | --- |
| Apple Silicon macOS | `aarch64-apple-darwin` | Xcode 或 Command Line Tools，以及 macOS SDK |
| x86-64 GNU/Linux | `x86_64-unknown-linux-gnu` | GCC、GNU ld 和开发文件 |
| x64 Windows | `x86_64-pc-windows-msvc-ucrt` | C++ Build Tools 和 Windows SDK |

Scoop 生成原生程序，最后一步要调用平台的链接器和系统库，所以需要上表最后一列的开发工具。工具链本身自带 LLVM、LLDB 等组件，不需要另外安装 Rust、Python 或 LLVM。

### macOS 和 Linux

在终端运行：

```sh
curl -fsSL https://scoop-lang.org/install.sh | sh
```

工具链默认安装在 `~/.scoop`，脚本会把 `~/.scoop/bin` 加入 Bash、Zsh、Fish 或 POSIX shell 的配置文件。安装完成后**打开一个新终端**，或者在当前终端执行：

```sh
export PATH="$HOME/.scoop/bin:$PATH"
```

如果想安装到别的目录，可以用 `--home DIR` 参数或 `SCOOP_HOME` 环境变量；不想让脚本修改 shell 配置，设置 `SCOOP_NO_MODIFY_PATH=1`。要安装某个确定的版本，把版本号作为参数传给脚本：

```sh
curl -fsSL https://scoop-lang.org/install.sh | sh -s -- 0.0.0-dev.20261113
```

### Windows

在 PowerShell（Windows PowerShell 5.1 或 PowerShell 7）中运行：

```powershell
irm https://scoop-lang.org/install.ps1 | iex
```

工具链默认安装在 `%USERPROFILE%\.scoop`，脚本会更新用户的 `PATH`；设置 `$env:SCOOP_NO_MODIFY_PATH = '1'` 可以跳过这一步。

> **注意：Windows 上的命令叫 `sco`**
>
> Windows 上有一个同样叫 `scoop` 的知名包管理器。为了避免冲突，Scoop 语言在 Windows 上的主命令是 **`sco`**。本书中所有的 `scoop …` 命令，在 Windows 上都写作 `sco …`，例如 `sco run hello.scoop`。安装器仍然叫 `scoop-install`，其他工具和 `SCOOP_*` 环境变量也保持原名。

### 确认安装成功

```sh
scoop --version
```

能看到类似 `scoop 0.0.0-dev.20261113 (…)` 的输出，就说明安装成功了。括号里是工具链的源码版本号，报告问题时可以附上这一行。

## 2.2　管理工具链版本

日常使用只需要记住一条命令：

```sh
scoop-install update
```

它安装最新的工具链并切换为默认版本，旧版本继续保留，所以升级出了问题可以随时切回去。其他常用的管理命令：

```sh
scoop-install show                # 当前状态
scoop-install toolchain list      # 已安装的版本
scoop-install default 0.0.0-dev.20261113   # 切换默认版本
scoop +0.0.0-dev.20261113 --version        # 临时用某个版本执行一条命令
```

默认安装只包含宿主命令、本机目标平台的预编译基础库，以及供语言服务器做源码导航用的库源码。图形界面库、交叉编译用的其他目标平台等可以按需添加，例如 `scoop-install component add gui --target aarch64-apple-darwin`。`scoop-install target list` 和 `scoop-install component list` 会列出可用的选项。

团队项目通常希望每个人用同一个版本。在项目根目录（或者它的任意上级目录）放一个 `scoop-toolchain.toml`：

```toml
[toolchain]
version = "0.0.0-dev.20261113"
targets = ["aarch64-apple-darwin"]
```

在这个目录下执行的 `scoop` 命令就会使用指定版本。版本的选择顺序是：命令行上的 `+VERSION`、`SCOOP_TOOLCHAIN` 环境变量、最近的 `scoop-toolchain.toml`、全局默认版本。项目要求的版本没有安装时，`scoop` 会提示安装命令，而不会在编译时自动下载。

> **深入一点：安装目录的结构**
>
> `~/.scoop/bin` 里的 `scoop` 等命令只是“代理”，它们按上面的规则选出版本，再启动 `~/.scoop/toolchains/<版本>-<宿主>/bin/` 下真正的工具。每个版本的目录里还有预编译库（`lib/<target>/`）、库源码（`src/`）、编辑器工具（`tooling/`）和安装时生成的离线 API 文档（`docs/<target>/`）。构建缓存按工具链版本隔离，切换版本后不需要手动清理。

## 2.3　第一个程序

新建一个文件 `hello.scoop`：

```scoop
{{#include ../../examples/ch02/hello.scoop}}
```

在它所在的目录执行：

```sh
scoop run hello.scoop --release
```

输出：

```text
{{#include ../../examples/ch02/hello.expected}}
```

`scoop run` 先编译，再运行编译出来的程序。编译过程中会在终端（标准错误输出）打印几行进度信息，最后一行 `Hello, Scoop!` 才是程序本身的输出。

几点说明：

- 这是一个**单文件程序**：不需要项目文件，一个 `.scoop` 文件就能编译运行。单文件程序默认可以使用核心库 `scoop.core` 和标准库 `scoop.std`。
- `println` 打印一行文本。它属于核心库，不需要 import。
- 编译产物放在当前目录的 `target/` 下，例如 `target/aarch64-apple-darwin/release/hello`。这是一个普通的可执行文件，可以直接运行，也可以复制到同平台的其他机器上运行。
- `--release` 表示用**优化模式**编译：编译稍慢，生成的程序更快。不加时是 `debug` 模式：不做优化，保留完整的调试信息，异常时打印调用栈。本书的示例一律用 `--release` 运行。

想只编译、不运行，用 `scoop build`：

```sh
scoop build hello.scoop --release
```

## 2.4　`main` 的几种写法

程序从 `main` 函数开始执行。Scoop 接受四种 `main`：

| 写法 | 程序正常结束时的退出码 |
| --- | --- |
| `fun main()` | `0` |
| `fun main(args: Array<String>)` | `0` |
| `fun main(): Int` | `main` 返回的值 |
| `fun main(args: Array<String>): Int` | `main` 返回的值 |

参数名不一定叫 `args`。返回 `Int` 的 `main` 用返回值作为进程的退出码，这在写命令行工具时很有用：

```scoop
{{#include ../../examples/ch02/exit_code.scoop}}
```

需要读取命令行参数时，声明一个 `Array<String>` 参数：

```scoop
{{#include ../../examples/ch02/args.scoop}}
```

```sh
scoop run args.scoop --release -- Ada
```

输出：

```text
{{#include ../../examples/ch02/args.expected}}
```

这里有两个要点：

- **`args[0L]` 是程序本身的路径**，用户传入的参数从 `args[1L]` 开始。所以检查参数个数时，要求的是 `args.size >= 2L`，而不是 `>= 1L`。
- 下标和 `size` 都是 `Long`，所以写 `args[1L]` 和 `2L`。第 3 章会解释为什么容器的下标是 `Long`。

命令行上的 `--` 用来分隔 Scoop 自己的选项和传给程序的参数：`--` 之前的归 `scoop run`，之后的原样交给程序。养成总是写 `--` 的习惯，可以避免程序参数恰好和 Scoop 的选项同名时被误解。

`main` 的写法不在上面四种之内，或者干脆找不到 `main`，都是编译错误：

```scoop
{{#include ../../examples/ch02/main_fail.scoop}}
```

```text
error[SCOOPC_HIR_ERROR]: missing executable entry: declare exactly one ordinary `fun main(): Unit`, `fun main(): Int`, `fun main(args: Array<String>): Unit`, or `fun main(args: Array<String>): Int`
note: `fun main(count: Int): Unit` is not eligible because its parameters must be empty or one `Array<String>`
```

报错列出了全部合法形式，`note` 指出了这个候选为什么不合格。把 `main` 拼错（比如写成 `mian`）时，得到的是同一条 “missing executable entry” 错误。

> **从 Kotlin 过来**
>
> Kotlin/JVM 的 `fun main(args: Array<String>)` 中，`args[0]` 是第一个用户参数，程序名不在数组里；退出码要调用 `exitProcess(n)` 设置。Scoop 和 C 的约定相同：`args[0L]` 是程序路径，返回 `Int` 的 `main` 直接用返回值作为退出码。
>
> 另外，Scoop 没有 JVM 的启动过程：没有类路径、`Main-Class`，也不需要把 `main` 放进 `object` 并加 `@JvmStatic`。`main` 就是一个顶层函数，编译器在编译时找到它，把它链接成可执行文件的入口。

## 2.5　`fmt`、`check`、`run`

开发时最常用的是三条命令，它们的分工不同：

| 命令 | 做什么 | 不做什么 |
| --- | --- | --- |
| `scoop fmt` | 按统一风格重新排版源码 | 不检查程序是否正确 |
| `scoop check` | 解析源码，做名称解析和类型检查，报告编译错误 | 不生成机器码，不链接，不运行 |
| `scoop run` | 完整编译、链接，然后运行 | — |

**`scoop fmt`** 直接改写文件。加上 `--check` 时只检查、不改写，有文件需要格式化就以非零状态退出，适合放在 CI 里：

```sh
scoop fmt hello.scoop           # 改写文件
scoop fmt hello.scoop --check   # 只检查
```

Scoop 的格式化风格是固定的，没有配置项。书中所有示例都经过 `scoop fmt` 排版，你会发现它在一些地方和 Kotlin 的习惯写法不同，比如区间写成 `1 .. 5`，单条语句的分支也会换行。

**`scoop check`** 比 `run` 快得多，适合在写代码的过程中频繁执行：

```scoop
{{#include ../../examples/ch02/type_fail.scoop}}
```

```sh
scoop check type_fail.scoop --release
```

```text
error[SCOOPC_HIR_ERROR]: initializer of `n` must be of type Int, found String
 --> type_fail.scoop:2:18
  |
2 |     val n: Int = "x"
  |                  ^^^
```

报错给出了错误代码、说明、文件位置，并用 `^^^` 标出出错的表达式。

需要强调的是：**`check` 通过，不等于程序能运行。** `check` 只覆盖编译器的前端，生成机器码、链接 C 库这些后续步骤它都不做；程序运行时还可能抛出异常，或者像 `args.scoop` 那样因为缺少参数而返回非零退出码。`check` 是“程序写得对不对”的快速检查，最终还是要用 `run` 或测试（第 30 章）来验证。

一个顺手的工作流是：写一段代码，`scoop fmt`，`scoop check`，没有错误再 `scoop run`。

## 2.6　把 Scoop 文件当脚本运行

单文件程序的第一行可以是 `#!` 开头的解释器注释，这样 `.scoop` 文件就可以像 shell 脚本一样直接执行：

```scoop
{{#include ../../examples/ch02/script.scoop}}
```

```sh
chmod +x script.scoop
./script.scoop
```

输出：

```text
{{#include ../../examples/ch02/script.expected}}
```

每次执行都会经过 `scoop run` 的编译步骤；源码没有变化时会直接复用上次的编译结果，所以第二次以后运行很快。

## 2.7　从单文件到项目

单文件适合小工具和试验。程序变大，需要多个源文件、测试或第三方依赖时，用 `scoop new` 创建一个 **Cone** 项目：

```sh
scoop new --group dev.example hello
cd hello
scoop run --release
```

生成的目录结构是：

```text
hello/
  Cone.toml          项目清单：名字、版本、依赖
  src/main.scoop     源码
  tests/basic.scoop  测试，只在 scoop test 时编译
```

在 Cone 目录里执行 `scoop run`、`scoop check`、`scoop test` 时不需要写文件名，命令会使用当前目录的 `Cone.toml`。`--group` 是项目的组名，作用类似 Maven 的 groupId。Cone、依赖和测试分别在第 28、29、30 章介绍，在此之前，本书的示例都是单文件程序。

## 2.8　用 `scoop example` 查阅示例

工具链附带一套离线示例，每个主题都是一个完整的小程序，配有运行步骤、预期结果、关键规则和常见误用：

```sh
scoop example                 # 分类目录和建议起点
scoop example --list          # 列出所有主题
scoop example language/option # 阅读一个主题
scoop example --search "JSON" # 按关键词搜索
```

主题按分类组织，例如 `start/hello`、`language/lambdas`、`text/strings`、`json/typed`、`http/get`。只想要源码时，加 `--format source`：

```sh
scoop example start/hello --format source --file main.scoop > main.scoop
```

示例和你安装的工具链版本一致，遇到书中没讲到的 API 时，它们是很好的参考。本书各章也会注明对应的示例主题。另外，安装器在安装时生成了离线 API 文档，位于工具链目录的 `docs/<target>/` 下，用浏览器打开即可查阅全部库的 API。

## 2.9　配置 VS Code

工具链附带语言服务器 `scoop-lsp` 和一个 VS Code 扩展。扩展提供：

- 语法高亮、代码折叠和自动缩进；
- 实时诊断（和 `scoop check` 报的是同样的错误）；
- 补全、悬停文档、签名提示；
- 跳转到定义、查找引用、重命名；
- 在 `main` 和测试方法上方显示 Run／Debug 按钮。

扩展以 VSIX 文件的形式随工具链发布，位于工具链目录的 `tooling/` 下（默认是 `~/.scoop/toolchains/<版本>-<宿主>/tooling/`）。用命令行安装：

```sh
code --install-extension ~/.scoop/toolchains/<版本>-<宿主>/tooling/scoop-language-support-*.vsix
```

也可以在 VS Code 的扩展面板中选择“从 VSIX 安装…”。需要 VS Code 1.100 或更新版本。

安装后打开任意 `.scoop` 文件，扩展就会启动。它会自动在 `~/.scoop/bin/scoop-lsp` 或 `PATH` 中找到语言服务器，通常不需要任何配置。如果你把工具链装在了别的位置，在设置里指定：

```json
{
  "scoop.server.path": "/absolute/path/to/scoop-lsp"
}
```

语言服务器出问题时，命令面板里的 `Scoop: Show Language Server Output` 可以查看日志，`Scoop: Restart Language Server` 可以重启它。语法高亮等功能不依赖语言服务器，即使服务器没有启动也能正常使用。

## 常见误用

- **在 Windows 上输入 `scoop`**：如果装过同名的包管理器，执行的会是它。Scoop 语言的命令是 `sco`。
- **把 `args[0L]` 当作第一个参数**：它是程序路径，用户参数从 `args[1L]` 开始。
- **把程序参数直接写在文件名后面**：`scoop run app.scoop --verbose` 中的 `--verbose` 会被当作 `scoop run` 的选项。写成 `scoop run app.scoop --release -- --verbose`。
- **以为 `check` 通过就万事大吉**：`check` 不生成代码、不链接、不运行，最终还要 `run` 或测试。
- **在 Cone 目录里执行 `scoop run src/main.scoop`**：传入单个文件会进入单文件模式，忽略 `Cone.toml` 和其中的依赖。在 Cone 里直接执行 `scoop run`。

## 小结

- 用 `curl -fsSL https://scoop-lang.org/install.sh | sh`（Windows 上用 `install.ps1`）安装；`scoop-install update` 升级，`scoop-toolchain.toml` 为项目固定版本。
- Windows 上的命令是 `sco`。
- `scoop run file.scoop --release` 编译并运行单文件程序，产物在 `target/` 下。
- `main` 有四种合法形式；返回 `Int` 时作为退出码；`args[0L]` 是程序路径。
- `fmt` 排版，`check` 做前端检查，`run` 完整编译并运行。
- `scoop example` 提供离线示例；VS Code 扩展和 `scoop-lsp` 随工具链发布。

## 练习

1. 安装工具链，运行 `scoop --version`，再用 `scoop example start/hello` 读一读第一个示例。
2. 修改 `args.scoop`，打印出用户传入的参数个数（不包括程序路径）。
3. 写一个 `main(): Int`，返回 `3`。运行后在 shell 里用 `echo $?`（PowerShell 中用 `$LASTEXITCODE`）查看退出码。
4. 故意把 `hello.scoop` 的缩进打乱，先运行 `scoop fmt hello.scoop --check` 看看输出，再运行 `scoop fmt hello.scoop` 修复。
5. 用 `scoop new` 创建一个项目，分别运行 `scoop run --release` 和 `scoop test --release`。
