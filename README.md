# 《Scoop 程序设计》

Scoop 语言的在线教程，使用 [mdBook](https://rust-lang.github.io/mdBook/) 构建，在线阅读：<https://book.scoop-lang.org>。大纲见 [OUTLINE.md](OUTLINE.md)。

## 目录结构

```text
book.toml                 mdBook 配置
src/                      书稿；SUMMARY.md 是目录
examples/chNN/            各章示例，书稿用 {{#include}} 引入
scripts/check-examples.sh 用本机工具链校验示例
theme/                    ```scoop 代码块的高亮
```

## 常用命令

```sh
mdbook serve --open          # 本地预览
mdbook build                 # 输出到 book/
scripts/check-examples.sh    # 校验全部示例（默认使用 ~/.scoop/bin/scoop）
scripts/check-examples.sh examples/ch08   # 只校验某一章
```

示例按 `0.0.0-dev.20261123`（`3910a8c5`）版工具链校验。这个版本包含[诊断编号](https://github.com/scoop-lang/scoop/pull/146)、[Kotlin 风格的 `scoop fmt`](https://github.com/scoop-lang/scoop/pull/183) 和[用 `@GenerateWith` 生成 codec](https://github.com/scoop-lang/scoop/pull/150)，更早的工具链无法通过编号断言、格式检查和第 18 章的 codec 示例。可用 `SCOOP=/path/to/toolchain/bin/scoop scripts/check-examples.sh` 显式选择工具链。

## 示例约定

| 文件 | 含义 |
| --- | --- |
| `NAME.scoop` | 单文件示例：依次执行 fmt --check、check、run |
| `NAME.expected` | 预期 stdout，可选 |
| `NAME.args` | 运行参数，可选 |
| `NAME.warning` | 编译警告中必须出现的文字，每行一段，保留警告及附属信息的编号，可选 |
| `NAME.status` | 运行时的预期退出码，可选，默认 0 |
| `NAME.stderr` | 运行时 stderr 中必须出现的文字，每行一段，可选 |
| `NAME_fail.scoop` | 演示错误写法，预期编译失败 |
| `NAME_fail.error` | 报错中必须出现的文字，每行一段，保留编号与 error/cause/note/help 角色；书稿可直接 include 它来展示报错 |
| `NAME/Cone.toml` | Cone 示例；有 `tests/` 时运行测试，可执行 Cone 的预期输出放 `expected.txt` |

书中出现的完整程序都应放在 `examples/` 下并能通过校验，不要直接把代码写进书稿。示例提交前先用 `scoop fmt` 格式化。

`.error` 和 `.warning` 是字面文本片段断言，不是完整输出快照。保留理解当前规则所需的主诊断、候选、原因和建议，不记录本机绝对路径。正文引用省略了路径或其他候选的片段时，应说明摘录范围；诊断树中相同的原因可能出现在不同候选下。

## 发布

推送到 `main` 后，GitHub Actions（`.github/workflows/deploy.yml`）用 mdBook 构建并部署到 GitHub Pages。自定义域名由 `book.toml` 中的 `cname` 写入构建产物。CI 只构建书，不校验示例；推送前请先在本机运行 `scripts/check-examples.sh`。

## 行文约定

- 正文中的引号用中文引号 “”。mdBook 的智能标点会把英文 `"` 转错。
- `{{#include}}` 不要放在 `>` 引用块或缩进的列表项里，否则引入的多行内容没有相应的缩进，会打断引用块或列表。需要在列表中间展示代码时，先结束列表；有编号的列表在代码块之后从下一个编号继续写即可。
- 提示框统一写作 `> **从 Kotlin 过来**` 和 `> **深入一点：标题**`。
