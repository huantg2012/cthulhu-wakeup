#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_path="${GODOT_EXECUTABLE:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_path" ]]; then
  printf '%s\n' "没有找到 Godot。请设置 GODOT_EXECUTABLE 为 Godot 可执行文件路径。"
  exit 1
fi
printf '%s\n' "UI 视觉探索：F1 三界 / F2 十二张 / F3 二十四张 / F4 三类立绘；F5 暂停或继续外围氛围；左右拖动翻牌。此入口使用独立存档。"
exec "$godot_path" --path "$project_dir" --script res://docs/art/visual-generation/ui-study/study.gd -- "$@"
