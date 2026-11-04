#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_path="${GODOT_EXECUTABLE:-/Applications/Godot.app/Contents/MacOS/Godot}"
if ! command -v node >/dev/null 2>&1; then
  printf '%s\n' "规范同步检查需要 Node.js，请先安装或将 node 加入 PATH。"
  exit 1
fi
if ! node "$project_dir/tools/echoes-art-master/design_sync.mjs" --check; then
  printf '%s\n' "样板与设计规范尚未同步。请更新对应规范和证据，再按 visual-system.md D2 显式记录。"
  exit 1
fi
if [[ ! -x "$godot_path" ]]; then
  printf '%s\n' "没有找到 Godot。请设置 GODOT_EXECUTABLE 为 Godot 可执行文件路径。"
  exit 1
fi
exec "$godot_path" --path "$project_dir" res://tools/echoes-art-master/scene.tscn
