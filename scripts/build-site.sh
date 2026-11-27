#!/usr/bin/env bash
# 构建两本书并组装成完整站点：
#   _site/               首页（site/ 中的文件）
#   _site/programming/   《Scoop 程序设计》
#   _site/ui/            《Scoop UI 编程指南》
#
# 用法：scripts/build-site.sh [输出目录]，默认 _site。
# 本地预览：scripts/build-site.sh && python3 -m http.server -d _site 8000
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-_site}"
BOOKS=(programming ui)

rm -rf "$OUT"
mkdir -p "$OUT"

for book in "${BOOKS[@]}"; do
    echo "==> mdbook build $book"
    mdbook build "$book"
    cp -R "$book/book" "$OUT/$book"
done

cp -R site/. "$OUT/"

# 兼容旧网址：《Scoop 程序设计》原来直接发布在站点根目录。
# 为它的每个页面在根目录生成一个跳转页，指向 programming/ 下的同名页面，
# 保留 #锚点。根目录的 index.html 和 404.html 由 site/ 提供，不生成跳转。
redirects=0
while IFS= read -r page; do
    page="${page#./}"
    [[ "$page" == "index.html" || "$page" == "404.html" ]] && continue
    [[ -e "$OUT/$page" ]] && continue
    depth="$(tr -cd '/' <<<"$page" | wc -c | tr -d ' ')"
    prefix=""
    for ((i = 0; i < depth; i++)); do prefix+="../"; done
    target="${prefix}programming/$page"
    mkdir -p "$OUT/$(dirname "$page")"
    cat >"$OUT/$page" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>页面已迁移</title>
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=$target">
<script>location.replace("$target" + location.hash);</script>
</head>
<body><p>本页已迁移到 <a href="$target">新地址</a>。</p></body>
</html>
EOF
    redirects=$((redirects + 1))
done < <(cd programming/book && find . -name '*.html' | sort)

echo "==> 站点已输出到 $OUT/（旧网址跳转页 $redirects 个）"
