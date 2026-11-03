#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_path="${GODOT_EXECUTABLE:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_path" ]]; then
  printf '%s\n' "没有找到 Godot。请设置 GODOT_EXECUTABLE 为 Godot 可执行文件路径。"
  exit 1
fi
exec "$godot_path" --path "$project_dir" res://tools/echoes-art-master/scene.tscn
