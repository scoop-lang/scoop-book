#!/usr/bin/env bash
# 用本机 Scoop 工具链校验 examples/ 下的全部示例。
#
# 本书的示例大多是 GUI 程序，运行后会打开窗口并一直等待用户操作，所以默认只做到“能链接出程序”：
#   examples/chNN/NAME.scoop           单文件示例：fmt --check、check、build
#   examples/chNN/NAME.expected        （可选）有这个文件时才运行 NAME.scoop，并比对 stdout
#   examples/chNN/NAME.args            （可选）运行时传给程序的参数，空白分隔
#   examples/chNN/NAME/Cone.toml       Cone 示例：fmt --check、check、test（有 tests/ 时）、build；
#                                      有 NAME/expected.txt 时才运行并比对 stdout
#   名字以 _fail 结尾的示例预期编译失败，用于演示错误写法；
#   NAME_fail.error（可选）每行是报错中必须出现的一段文字
#
# 窗口里的交互和截图需要人工（或 GUI 操作工具）验证，见 README.md。
#
# 用法：scripts/check-examples.sh [examples/chNN ...]
# 环境变量 SCOOP 可覆盖工具链路径，默认 ~/.scoop/bin/scoop。
set -uo pipefail

SCOOP="${SCOOP:-$HOME/.scoop/bin/scoop}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -x "$SCOOP" ]]; then
    echo "找不到 Scoop 工具链：$SCOOP" >&2
    exit 2
fi
echo "工具链：$("$SCOOP" --version)"

targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=(examples)

passed=0
failed=()
log="$(mktemp)"
out_dir="$(mktemp -d)"
trap 'rm -rf "$log" "$out_dir"' EXIT

step() {  # step 名称 命令...
    local name="$1"; shift
    if ! "$@" >"$log" 2>&1; then
        echo "  ✗ $name"
        sed 's/^/    /' "$log"
        return 1
    fi
}

compare() {  # compare 预期文件 命令...
    local expected="$1"; shift
    local actual
    actual="$(mktemp)"
    if ! "$@" >"$actual" 2>"$log"; then
        echo "  ✗ 运行失败"
        sed 's/^/    /' "$log"
        rm -f "$actual"; return 1
    fi
    if ! diff -u "$expected" "$actual" >"$log"; then
        echo "  ✗ 输出与 $expected 不一致"
        sed 's/^/    /' "$log"
        rm -f "$actual"; return 1
    fi
    rm -f "$actual"
}

check_single() {
    local file="$1" base="${1%.scoop}"
    echo "• $file"
    if [[ "$base" == *_fail ]]; then
        if "$SCOOP" check "$file" --release >"$log" 2>&1; then
            echo "  ✗ 预期编译失败，实际通过"; return 1
        fi
        if [[ -f "$base.error" ]]; then
            while IFS= read -r needle; do
                [[ -z "$needle" ]] && continue
                if ! grep -qF -- "$needle" "$log"; then
                    echo "  ✗ 报错中没有找到：$needle"
                    sed 's/^/    /' "$log"
                    return 1
                fi
            done < "$base.error"
        fi
        return 0
    fi
    local program="$out_dir/$(basename "$base")"
    step "格式" "$SCOOP" fmt "$file" --check || return 1
    step "检查" "$SCOOP" check "$file" --release || return 1
    step "构建" "$SCOOP" build "$file" --release -o "$program" || return 1
    if [[ -f "$base.expected" ]]; then
        local args=()
        [[ -f "$base.args" ]] && read -r -a args < "$base.args"
        compare "$base.expected" "$program" ${args[@]+"${args[@]}"} || return 1
    fi
}

check_cone() {
    local dir="$1"
    local program="$out_dir/$(basename "$dir")"
    echo "• $dir"
    step "格式" "$SCOOP" fmt "$dir" --check || return 1
    step "检查" "$SCOOP" check "$dir" --release || return 1
    if [[ -d "$dir/tests" ]]; then
        step "测试" "$SCOOP" test "$dir" --release || return 1
    fi
    if grep -Eq '^kind *= *"executable"' "$dir/Cone.toml" || ! grep -Eq '^kind *=' "$dir/Cone.toml"; then
        step "构建" "$SCOOP" build "$dir" --release -o "$program" || return 1
        if [[ -f "$dir/expected.txt" ]]; then
            compare "$dir/expected.txt" "$program" || return 1
        fi
    else
        step "构建" "$SCOOP" build "$dir" --release || return 1
    fi
}

while IFS= read -r item; do
    if [[ "$item" == */Cone.toml ]]; then
        dir="$(dirname "$item")"
        check_cone "$dir" && passed=$((passed + 1)) || failed+=("$dir")
    else
        # 跳过 Cone 内部的源码
        parent="$(dirname "$item")"
        while [[ "$parent" != "." && "$parent" != "/" ]]; do
            [[ -f "$parent/Cone.toml" ]] && continue 2
            parent="$(dirname "$parent")"
        done
        check_single "$item" && passed=$((passed + 1)) || failed+=("$item")
    fi
done < <(find "${targets[@]}" \( -name Cone.toml -o -name '*.scoop' \) -not -path '*/target/*' | sort)

echo
echo "通过 $passed 个，失败 ${#failed[@]} 个"
if [[ ${#failed[@]} -gt 0 ]]; then
    for f in "${failed[@]}"; do echo "  - $f"; done
fi
[[ ${#failed[@]} -eq 0 ]]
