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

## 示例约定

| 文件 | 含义 |
| --- | --- |
| `NAME.scoop` | 单文件示例：依次执行 fmt --check、check、run |
| `NAME.expected` | 预期 stdout，可选 |
| `NAME.args` | 运行参数，可选 |
| `NAME.warning` | 编译警告中必须出现的文字，每行一段，可选 |
| `NAME_fail.scoop` | 演示错误写法，预期编译失败 |
| `NAME_fail.error` | 报错中必须出现的文字，每行一段；书稿可直接 include 它来展示报错 |
| `NAME/Cone.toml` | Cone 示例；有 `tests/` 时运行测试，可执行 Cone 的预期输出放 `expected.txt` |

书中出现的完整程序都应放在 `examples/` 下并能通过校验，不要直接把代码写进书稿。示例提交前先用 `scoop fmt` 格式化。

## 发布

推送到 `main` 后，GitHub Actions（`.github/workflows/deploy.yml`）用 mdBook 构建并部署到 GitHub Pages。自定义域名由 `book.toml` 中的 `cname` 写入构建产物。CI 只构建书，不校验示例；推送前请先在本机运行 `scripts/check-examples.sh`。

## 行文约定

- 正文中的引号用中文引号 “”。mdBook 的智能标点会把英文 `"` 转错。
- `{{#include}}` 不要放在 `>` 引用块里，否则引入的多行内容会打断引用块。
- 提示框统一写作 `> **从 Kotlin 过来**` 和 `> **深入一点：标题**`。
