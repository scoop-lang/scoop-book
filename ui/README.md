# 《Scoop UI 编程指南》

用 Scoop 编写桌面图形界面的教程，《Scoop 程序设计》的姊妹篇，使用 [mdBook](https://rust-lang.github.io/mdBook/) 构建，在线阅读：<https://book.scoop-lang.org/ui/>。大纲与写作计划见 [OUTLINE.md](OUTLINE.md)。本书和《Scoop 程序设计》放在同一个仓库中，仓库的整体结构和发布方式见[上级目录的 README](../README.md)。下面的命令都在本目录（`ui/`）中执行。

## 目录结构

```text
book.toml                   mdBook 配置
src/                        书稿；SUMMARY.md 是目录
src/images/chNN/            各章截图
examples/chNN/              各章示例，书稿用 {{#include}} 引入
scripts/check-examples.sh   用本机工具链校验示例
scripts/snap-window.sh      截取窗口内容区（macOS）
scripts/crop.swift          裁剪截图
theme/                      ```scoop 代码块的高亮和网站图标
```

## 常用命令

```sh
mdbook serve --open                       # 本地预览
mdbook build                              # 输出到 book/
scripts/check-examples.sh                 # 校验全部示例（默认使用 ~/.scoop/bin/scoop）
scripts/check-examples.sh examples/ch04   # 只校验某一章
```

示例按 `0.0.0-dev.20261128`（`ec7df9db`）版工具链校验，需要安装 GUI 组件（`scoop-install component add gui --target <目标>`）。可用 `SCOOP=/path/to/toolchain/bin/scoop scripts/check-examples.sh` 显式选择工具链。每个 GUI 程序的构建要二十秒左右，全部示例校验一遍需要几分钟。

## 示例约定

| 文件 | 含义 |
| --- | --- |
| `NAME.scoop` | 单文件示例：依次执行 fmt --check、check、build |
| `NAME.expected` | 预期 stdout，可选；有它时才运行程序并比对输出（GUI 程序通常没有） |
| `NAME.args` | 运行参数，可选 |
| `NAME_fail.scoop` | 演示错误写法，预期编译失败 |
| `NAME_fail.error` | 报错中必须出现的文字，每行一段 |
| `NAME/Cone.toml` | Cone 示例：fmt --check、check、test（有 `tests/` 时）、build；有 `expected.txt` 时运行并比对 |

书中出现的完整程序都应放在 `examples/` 下并能通过校验，不要直接把代码写进书稿。示例提交前先用 `scoop fmt` 格式化。

GUI 程序打开窗口后会一直等待操作，校验脚本只验证它们能构建出可执行文件。窗口中的行为（点击后的变化、终端输出、截图）需要在真实窗口中操作验证，修改示例或升级工具链后要重新验证书中描述的结果。

## 发布

推送到 `main` 后，GitHub Actions 构建两本书和首页，本书发布在站点的 `/ui/` 下，详见[上级目录的 README](../README.md)。CI 只构建书，不校验示例；推送前请先在本机运行 `scripts/check-examples.sh`。

## 截图

截图在 macOS 上以浅色主题截取，按 Retina 2 倍像素保存，书稿中用 `<img width="...">` 按一半宽度显示：

```sh
scripts/snap-window.sh <窗口 ID> src/images/ch02/counter.png      # 截取窗口并去掉标题栏
swift scripts/crop.swift in.png out.png <x> <y> [<w> <h>]          # 需要时再裁剪到内容区
```

窗口 ID 是 CGWindowID，可以用任意能列出窗口的工具查到。窗口被其他窗口遮住时也能截取。

## 行文约定

- 正文中的引号用中文引号 “”。mdBook 的智能标点会把英文 `"` 转错。
- `{{#include}}` 不要放在 `>` 引用块或缩进的列表项里，否则引入的多行内容没有相应的缩进，会打断引用块或列表。
- 提示框统一写作 `> **从其他框架过来**`、`> **深入一点：标题**` 和 `> **注意：标题**`。
- 每章以“读完本章，你会知道”开头，以“常见误用”“小结”“练习”结尾。
- 只写当前工具链实际支持并验证过的行为；尚在补齐的平台能力要明确说明。
