#!/usr/bin/env python3
"""Serve the author reader and its read-only Godot preview on loopback."""
import argparse
from collections import OrderedDict
from http.server import SimpleHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import shutil
import subprocess
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tools/prayer-space/generator_preview.gd'
PAGE = '/docs/content/prayer-space.html'
GODOT_APP = Path('/Applications/Godot.app/Contents/MacOS/Godot')


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def reply(self, payload, code=200):
        data = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlsplit(self.path)
        if path.path in ('/', PAGE):
            self.path = PAGE
            super().do_GET()
            return
        if path.path != '/__prayer_generator':
            self.send_error(404)
            return
        query = parse_qs(path.query)
        try:
            seed = int(query.get('seed', ['1'])[0])
            draw = int(query.get('draw', ['0'])[0])
            if abs(seed) > 2**53 - 1 or draw < 0 or draw > 10**7:
                raise ValueError
        except ValueError:
            self.reply({'error': '种子或批次游标超出范围。'}, 400)
            return
        filters = {key: query[key][0][:64] for key in ('frame', 'grammar', 'stance') if query.get(key)}
        request = {'seed': seed, 'draw': draw, 'filters': filters}
        if query.get('root'):
            root = self.server.roots.get((seed, query['root'][0]))
            if root is None:
                self.reply({'error': '该处境已离开预览缓存，请重新生成原批次。'}, 400)
                return
            request['situation'] = root
        try:
            result = subprocess.run(
                [self.server.godot, '--headless', '--path', str(ROOT), '--script', str(SCRIPT), '--', json.dumps(request, ensure_ascii=False)],
                capture_output=True, text=True, timeout=20, check=False,
            )
            line = next(line for line in result.stdout.splitlines() if line.startswith('PRAYER_GENERATOR_JSON '))
            data = json.loads(line.partition(' ')[2])
        except (OSError, ValueError, StopIteration, subprocess.TimeoutExpired):
            self.reply({'error': 'Godot 未返回生成结果，请检查预览服务终端。'}, 500)
            return
        if result.stderr:
            self.log_error('%s', result.stderr.strip())
        for root_id, root in data.pop('roots', {}).items():
            key = (seed, root_id)
            self.server.roots[key] = root
            self.server.roots.move_to_end(key)
        while len(self.server.roots) > 128:
            self.server.roots.popitem(last=False)
        self.reply(data, 500 if data.get('error') else 200)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8766)
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4') or str(GODOT_APP))
    args = parser.parse_args()
    with HTTPServer(('127.0.0.1', args.port), Handler) as server:
        server.godot = args.godot
        server.roots = OrderedDict()
        print(f'http://127.0.0.1:{args.port}{PAGE}', flush=True)
        server.serve_forever()


if __name__ == '__main__':
    main()
