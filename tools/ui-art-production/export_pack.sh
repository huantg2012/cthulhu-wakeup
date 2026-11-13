#!/bin/bash
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
godot="${GODOT_EXECUTABLE:-/Applications/Godot.app/Contents/MacOS/Godot}"
destination="${1:-}"
if [[ "$destination" != /*.pck ]]; then
  printf 'Usage: %s /absolute/path/game.pck\n' "$0" >&2
  exit 2
fi
staging="$(mktemp -d "${TMPDIR:-/tmp}/cthulhu-production.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
study="docs/art/visual-generation/ui-study"
mkdir -p "$staging/data" "$staging/$study" "$(dirname -- "$destination")"
cp "$root/project.godot" "$root/export_presets.cfg" "$staging/"
cp -R "$root/src" "$staging/"
# Shared physical card stock is a production dependency, not an exploration asset.
cp -R "$root/assets" "$staging/"
cp "$root/data/"*.csv "$staging/data/"
cp -R "$root/$study/type" "$staging/$study/"
for resource in card_fan.gd painted_card.gd painted_backdrop.gd painted_material.gd occult_marks.gd peripheral_atmosphere.gd peripheral_tendrils.gd peripheral_fields.gdshaderinc peripheral_mist.gdshader peripheral_veil.gdshader peripheral_surface.gdshader; do
  cp "$root/$study/$resource" "$staging/$study/"
done
# Gameplay reads authored CSV bytes; importing these as translation tables would omit them.
for csv in "$staging"/data/*.csv; do
  printf '[remap]\n\nimporter="keep"\n' > "$csv.import"
done
"$godot" --headless --editor --path "$staging" --import
"$godot" --headless --path "$staging" --export-pack Production "$destination"
