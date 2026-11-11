#!/bin/zsh
set -eu
cd "${0:A:h}"
url='http://127.0.0.1:8952/'
if ! curl -fsS "${url}api/config" >/dev/null 2>&1; then
  nohup python3 docs/art/visual-generation/procedural-study/painted/surface/server.py > /tmp/cthulhu-surface-study.log 2>&1 &
  for i in {1..60}; do
    if curl -fsS "${url}api/config" >/dev/null 2>&1; then break; fi
    sleep 0.25
  done
fi
open "${url}painted/surface/people.html"
