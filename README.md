# Scoop 图书

Scoop 语言的中文在线教程，在线阅读：<https://book.scoop-lang.org>。仓库中有两本书，都用 [mdBook](https://rust-lang.github.io/mdBook/) 构建，和首页一起发布在同一个网址下：

| 目录 | 书 | 网址 |
| --- | --- | --- |
| `programming/` | 《Scoop 程序设计》 | <https://book.scoop-lang.org/programming/> |
| `ui/` | 《Scoop UI 编程指南》 | <https://book.scoop-lang.org/ui/> |
| `site/` | 首页：两本书的封面和入口 | <https://book.scoop-lang.org/> |

每本书的写作约定、示例校验方法见各自目录下的 README.md。

## 目录结构

```text
programming/              《Scoop 程序设计》：book.toml、src/、examples/、scripts/、theme/
ui/                       《Scoop UI 编程指南》：结构相同，另有截图脚本
site/                     首页、404 页、样式、封面缩略图、CNAME
scripts/build-site.sh     构建两本书并组装成完整站点
.github/workflows/        推送到 main 后构建并部署到 GitHub Pages
```

## 常用命令

```sh
mdbook serve programming --open    # 只预览一本书
mdbook serve ui --open
scripts/build-site.sh              # 构建两本书和首页，输出到 _site/
python3 -m http.server -d _site 8000   # 在 http://localhost:8000 预览完整站点
```

## 发布

推送到 `main` 后，GitHub Actions（`.github/workflows/deploy.yml`）运行 `scripts/build-site.sh`，把 `_site/` 部署到 GitHub Pages；Pull Request 只构建、不部署。CI 只构建书，不校验示例，推送前请先在本机用各书的 `scripts/check-examples.sh` 校验。

站点的结构：

- `/` 是 `site/` 中的首页；
- `/programming/` 和 `/ui/` 是两本书，各自的 `book.toml` 用 `site-url` 声明了这个路径；
- 自定义域名写在 `site/CNAME`。

《Scoop 程序设计》原来直接发布在站点根目录。为了不让已有的链接失效，`build-site.sh` 为它的每个页面在根目录生成一个跳转页，例如 `/part01-start/ch01-why-scoop.html` 跳转到 `/programming/part01-start/ch01-why-scoop.html`。

## 封面

两本书的封面在 `programming/src/images/cover.png` 和 `ui/src/images/cover.png`，书的前言中引用它们。首页使用缩小后的副本，更换封面后重新生成：

```sh
sips -s format jpeg -s formatOptions 82 -Z 900 programming/src/images/cover.png --out site/covers/programming.jpg
sips -s format jpeg -s formatOptions 82 -Z 900 ui/src/images/cover.png --out site/covers/ui.jpg
```
