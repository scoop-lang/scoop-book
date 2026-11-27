#!/usr/bin/env bash
# 截取一个窗口的内容区（去掉标题栏），用于书中的截图。仅限 macOS。
#
# 用法：scripts/snap-window.sh WINDOW_ID 输出.png [标题栏高度，单位为点，默认 32]
#
# WINDOW_ID 是 CGWindowID，可以用任意能列出窗口的工具查到。窗口被其他窗口遮住时也能截取。
# 截图按 Retina 2 倍像素保存，例如 800×632 点的窗口得到 1600×1200 像素的内容区。
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "用法：$0 WINDOW_ID 输出.png [标题栏高度]" >&2
    exit 2
fi
id="$1" out="$2" titlebar="${3:-32}"
here="$(cd "$(dirname "$0")" && pwd)"

tmp="$(mktemp -t snap).png"
trap 'rm -f "$tmp"' EXIT
screencapture -x -o -l "$id" "$tmp"
swift "$here/crop.swift" "$tmp" "$out" 0 $((titlebar * 2))
