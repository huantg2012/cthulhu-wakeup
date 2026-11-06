#!/bin/bash
set -eo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
node "$project_dir/tools/echoes-art-master/design_sync.mjs" --check --manifest docs/art/presentation-rebuild/design-sync.json --root "$project_dir"
godot_path="$(printenv GODOT_EXECUTABLE || true)"
if [[ -z "$godot_path" ]]; then godot_path="/Applications/Godot.app/Contents/MacOS/Godot"; fi
if [[ ! -x "$godot_path" ]]; then
 printf '%s\n' "没有找到 Godot，请设置 GODOT_EXECUTABLE。"
 exit 1
fi
exec "$godot_path" --path "$project_dir" res://src/presentation/reconstruction/lesson.tscn
