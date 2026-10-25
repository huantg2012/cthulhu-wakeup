#!/usr/bin/env python3
"""Build a portable, self-contained reading snapshot (never modifies its sources)."""
import json
import re
from pathlib import Path
from server import ATLAS, ROOT, WEB, load_model


def render_snapshot(model):
    model = {**model, 'meta': {**model['meta'], 'mode': 'offline'}}
    # JSON goes into a script element; even quoted source excerpts must not close it.
    payload = json.dumps(model, ensure_ascii=False).replace('<', '\\u003c').replace('\u2028', '\\u2028').replace('\u2029', '\\u2029')
    logic = re.sub(r'^export ', '', (WEB / 'logic.mjs').read_text(encoding='utf-8'), flags=re.M)
    app = re.sub(r'^import .*?;\n', '', (WEB / 'app.js').read_text(encoding='utf-8'), count=1)
    script = 'window.WORKBENCH_SNAPSHOT = ' + payload + ';\n' + logic + '\n' + app
    html = (WEB / 'index.html').read_text(encoding='utf-8')
    html = html.replace('<link rel="stylesheet" href="/style.css">', '<style>' + (WEB / 'style.css').read_text(encoding='utf-8') + '</style>')
    html = html.replace('<script type="module" src="/app.js"></script>', '<script type="module">' + script + '</script>')
    return html


if __name__ == '__main__':
    target = ROOT / ATLAS / 'terminal.html'
    target.write_text(render_snapshot(load_model()), encoding='utf-8')
    print(f'Built {target.relative_to(ROOT)} ({target.stat().st_size:,} bytes)')
