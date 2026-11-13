#!/bin/zsh
set -e
cd "${0:A:h}"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --rendering-method gl_compatibility --script tools/card-carrier-study/category_preview.gd -- --interactive
