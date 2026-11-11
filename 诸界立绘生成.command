#!/bin/zsh
set -eu
cd "${0:A:h}"
godot_binary="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_binary" ]]; then
  print -u2 '找不到 Godot。请设置 GODOT_BIN 指向 Godot 可执行文件。'
  exit 1
fi
exec "$godot_binary" --path "$PWD" res://src/art_generation/workbench/workbench.tscn "$@"
