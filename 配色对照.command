#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
godot_path="${GODOT_EXECUTABLE:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$godot_path" --path "$project_dir" --script res://tools/palette-study/preview.gd -- "$@"
