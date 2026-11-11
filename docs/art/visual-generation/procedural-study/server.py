#!/usr/bin/env python3
"""Local exploration bridge: call the unmodified original Godot world generator."""
from __future__ import annotations
import argparse
import base64
import binascii
import struct
import csv
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SOURCE = HERE.parent / 'godot-base'
CACHE = HERE / 'cache'
STYLE_ROWS = [
    {'id': 0, 'sid': 0, 'index': 0, 'name': '暗黑厚涂'},
    {'id': 1, 'sid': 1, 'index': 1, 'name': '赛璐璐漫画'},
    {'id': 2, 'sid': 2, 'index': 2, 'name': '古典铜版画'},
    {'id': 4, 'sid': 4, 'index': 3, 'name': '复古像素'},
    {'id': 6, 'sid': 6, 'index': 4, 'name': '水彩手稿'},
    {'id': 7, 'sid': 7, 'index': 5, 'name': '怪奇杂志'},
]
STYLE_INDEX = {row['id']: row['index'] for row in STYLE_ROWS}
RENDER_LOCK = threading.Lock()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_configuration() -> dict:
    names = {}
    with (REPO / 'data/player_text.csv').open(newline='') as source:
        for row in csv.reader(source):
            if len(row) >= 4 and row[0] == 'civilization_profiles' and row[2] == 'name':
                names[row[1]] = row[3]
    with (HERE / 'templates.csv').open(newline='') as source:
        templates = list(csv.DictReader(source))
    for row in templates:
        row['archetype'] = int(row['archetype'])
        row['name'] = names.get(row['civilization_id'], row['archetype_name'] + '（候选世界）')
        row['world_name'] = row['name']
        row['identity_status'] = '视觉候选；非正式 Session 对象'
    palettes = json.loads((HERE / 'palettes.json').read_text())
    original = (SOURCE / 'scripts/data.gd').read_text()
    palette_block = original.split('const PALETTES := [', 1)[1].split('\n]', 1)[0]
    original_palettes = re.findall(r'\{"name": "([^"]+)", "c": \[(.*?)\]', palette_block)
    for palette in palettes:
        name, values = original_palettes[palette['id']]
        colors = re.findall(r'"([0-9a-fA-F]{6})"', values)
        if palette['name'] != name or any(palette[key].lower() != '#' + color.lower() for key, color in zip(('dark', 'shadow', 'mid', 'light', 'glow'), colors)):
            raise RuntimeError('Palette snapshot differs from the original generator')
    return {'templates': templates, 'palettes': palettes,
            'styles': STYLE_ROWS, 'defaults': {'template': 'tide', 'seed': 1337, 'style': 0, 'palette': 7}}


def source_fingerprint() -> str:
    entries = {}
    for path in sorted(SOURCE.rglob('*')):
        if path.is_file() and '.godot' not in path.parts and path.name != '.DS_Store':
            entries[path.relative_to(SOURCE).as_posix()] = digest(path.read_bytes())
    return digest(canonical(entries))


def require_integer(value: object, name: str, minimum: int, maximum: int) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f'{name} must be an integer between {minimum} and {maximum}')
    return value


class WorldGenerator:
    def __init__(self, godot: str):
        self.godot = godot
        self.project: Path | None = None
        self.project_fingerprint = ''
        CACHE.mkdir(exist_ok=True)
        # A local generated-cache exclusion, not an edit to the repository's shared ignore file.
        (CACHE / '.gitignore').write_text('*\n!.gitignore\n')

    def prepare(self, fingerprint: str) -> Path:
        if self.project is not None and self.project_fingerprint == fingerprint:
            return self.project
        project = Path(tempfile.mkdtemp(prefix='cthulhu-procedural-world-')) / 'project'
        shutil.copytree(SOURCE, project, ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
        result = subprocess.run([self.godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'],
                                capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError('Godot asset import failed: ' + (result.stderr or result.stdout)[-2000:])
        self.project, self.project_fingerprint = project, fingerprint
        return project

    def validate_request(self, request: object) -> tuple[dict, dict, int]:
        if not isinstance(request, dict) or set(request) != {'template', 'seed', 'style', 'palette'}:
            raise ValueError('Expected exactly template, seed, style, palette')
        configuration = load_configuration()
        templates = {row['id']: row for row in configuration['templates']}
        template_id = request['template']
        if not isinstance(template_id, str) or template_id not in templates:
            raise ValueError('Unknown world template')
        seed = require_integer(request['seed'], 'seed', 0, 999999)
        style = require_integer(request['style'], 'style', 0, 7)
        palette = require_integer(request['palette'], 'palette', 0, 9)
        if style not in STYLE_INDEX or palette not in {p['id'] for p in configuration['palettes']}:
            raise ValueError('Unsupported style or palette')
        identity = templates[template_id]
        params = {'scene': 0, 'style': STYLE_INDEX[style], 'seed': seed, 'archetype': identity['archetype'],
                  'palette': palette, 'composition': 1, 'star_type': -1, 'wonder': -1, 'count': 0, 'rings': 2,
                  'tentacles': 0.0, 'eyes': 0.0, 'glyphs': 0.0, 'corruption': 0.2, 'madness': 0.06,
                  'nebula': 0.25, 'aspect': 1, 'quality': 1, 'animate': 0, 'show_title': 0,
                  'show_labels': 0, 'show_frame': 0, 'show_swatch': 0}
        return params, identity, style

    def generate(self, request: object) -> dict:
        params, identity, style = self.validate_request(request)
        seed = params['seed']
        fingerprint = source_fingerprint()
        contract = {'schema': 1, 'sourceFingerprint': fingerprint, 'template': identity,
                    'params': params, 'time': 3.0, 'framesAfterRebuild': 4}
        key = digest(canonical(contract))
        target, metadata = CACHE / f'{key}.png', CACHE / f'{key}.json'
        with RENDER_LOCK:
            if target.is_file() and metadata.is_file():
                saved = json.loads(metadata.read_text())
                if saved.get('hash') == digest(target.read_bytes()):
                    return {**saved, 'cached': True}
            project = self.prepare(fingerprint)
            with tempfile.TemporaryDirectory(prefix='cthulhu-world-shot-') as shots:
                config = ','.join(f'{name}:{value}' for name, value in params.items())
                command = [self.godot, '--path', str(project), '--position', '20000,20000', '--',
                           '--shots=' + shots, '--cfg=' + config]
                run = subprocess.run(command, capture_output=True, text=True, timeout=60)
                name = f'00_s0_st{STYLE_INDEX[style]}_{seed}.png'
                output = Path(shots) / name
                if run.returncode or not output.is_file() or 'SCRIPT ERROR:' in run.stderr or 'SHADER ERROR:' in run.stderr:
                    raise RuntimeError('Original Godot render failed: ' + (run.stderr or run.stdout)[-2000:])
                payload = output.read_bytes()
                if not payload.startswith(b'\x89PNG\r\n\x1a\n'):
                    raise RuntimeError('Godot returned an invalid image')
                temporary = target.with_suffix('.tmp')
                temporary.write_bytes(payload)
                temporary.replace(target)
            result = {'url': f'/cache/{key}.png', 'params': params, 'hash': digest(payload),
                      'sourceFingerprint': fingerprint, 'identity': identity, 'styleSid': style,
                      'time': 3.0, 'framesAfterRebuild': 4, 'size': [960, 960], 'cached': False,
                      'method': 'unmodified original Godot generator', 'request': request}
            metadata.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            return result


    def style_images(self, body: object) -> dict:
        if not isinstance(body, dict) or set(body) != {'request', 'images', 'normals'}:
            raise ValueError('Expected exactly request, images and normals')
        params, identity, style = self.validate_request(body['request'])
        encoded_images = body['images']
        if not isinstance(encoded_images, dict) or set(encoded_images) != {'cult', 'person'}:
            raise ValueError('Expected cult and person PNG data URLs')
        encoded_normals = body['normals']
        if not isinstance(encoded_normals, dict) or set(encoded_normals) != {'cult', 'person'}:
            raise ValueError('Expected cult and person normal maps')
        images = {}
        for kind, encoded in {**encoded_images, **{k + '_normal': v for k, v in encoded_normals.items()}}.items():
            if not isinstance(encoded, str) or not encoded.startswith('data:image/png;base64,'):
                raise ValueError(kind + ' must be a PNG data URL')
            if len(encoded) > 7_000_000:
                raise ValueError(kind + ' PNG exceeds 5 MB')
            try:
                payload = base64.b64decode(encoded.split(',', 1)[1], validate=True)
            except binascii.Error as error:
                raise ValueError('Invalid PNG base64') from error
            if len(payload) > 5 * 1024 * 1024 or len(payload) < 33 or not payload.startswith(b'\x89PNG\r\n\x1a\n') or payload[12:16] != b'IHDR':
                raise ValueError('Invalid PNG or PNG exceeds 5 MB')
            width, height = struct.unpack('>II', payload[16:24])
            if not 1 <= width <= 4096 or not 1 <= height <= 4096:
                raise ValueError('PNG dimensions must be within 4096 pixels')
            images[kind] = payload
        fingerprint = source_fingerprint()
        adapter = getattr(self, 'adapter_dir', HERE) / 'style_2d.gd'
        adapter_fingerprint = digest(adapter.read_bytes())
        surface_shader = getattr(self, 'adapter_dir', HERE) / 'surface_2d.gdshader'
        surface_fingerprint = digest(surface_shader.read_bytes())
        input_hashes = {kind: digest(payload) for kind, payload in images.items()}
        contract = {'schema': 1, 'sourceFingerprint': fingerprint, 'adapterFingerprint': adapter_fingerprint,
                    'params': params, 'time': 3.0, 'framesAfterRebuild': 4, 'inputHashes': input_hashes,
                    'surfaceShaderFingerprint': surface_fingerprint}
        key = digest(canonical(contract))
        targets = {kind: CACHE / f'{key}-{kind}.png' for kind in ('cult', 'person')}
        metadata = CACHE / f'{key}-style.json'
        with RENDER_LOCK:
            if metadata.is_file() and all(path.is_file() for path in targets.values()):
                saved = json.loads(metadata.read_text())
                if all(saved.get('hashes', {}).get(kind) == digest(path.read_bytes()) for kind, path in targets.items()):
                    return {**saved, 'cached': True}
            project = self.prepare(fingerprint)
            shutil.copy2(adapter, project / 'style_2d.gd')
            shutil.copy2(surface_shader, project / 'surface_2d.gdshader')
            scene = (SOURCE / 'main.tscn').read_text().replace('res://scripts/main.gd', 'res://style_2d.gd')
            (project / 'style_2d.tscn').write_text(scene)
            with tempfile.TemporaryDirectory(prefix='cthulhu-style2d-') as temporary:
                scratch = Path(temporary)
                inputs = {kind: scratch / f'{kind}-raw.png' for kind in images}
                outputs = {kind: scratch / f'{kind}-styled.png' for kind in ('cult', 'person')}
                for kind, payload in images.items():
                    inputs[kind].write_bytes(payload)
                job = {'params': params, 'inputs': {k: str(inputs[k]) for k in ('cult', 'person')},
                       'normals': {k: str(inputs[k + '_normal']) for k in ('cult', 'person')}, 'lighting': str(scratch / 'lighting.json'), 'outputs': {k: str(v) for k, v in outputs.items()}}
                job_path = scratch / 'job.json'
                job_path.write_text(json.dumps(job))
                command = [self.godot, '--path', str(project), '--position', '20000,20000',
                           'res://style_2d.tscn', '--', '--style-job=' + str(job_path)]
                run = subprocess.run(command, capture_output=True, text=True, timeout=60)
                if run.returncode or not all(path.is_file() for path in outputs.values()) or 'SCRIPT ERROR:' in run.stderr or 'SHADER ERROR:' in run.stderr:
                    raise RuntimeError('Original post pipeline failed: ' + (run.stderr or run.stdout)[-2000:])
                lighting = json.loads((scratch / 'lighting.json').read_text())
                hashes = {}
                for kind, output in outputs.items():
                    payload = output.read_bytes()
                    hashes[kind] = digest(payload)
                    output.replace(targets[kind])
            result = {'urls': {k: '/cache/' + v.name for k, v in targets.items()}, 'hashes': hashes,
                      'params': params, 'sourceFingerprint': fingerprint, 'adapterFingerprint': adapter_fingerprint,
                      'inputHashes': input_hashes, 'surfaceShaderFingerprint': surface_fingerprint, 'lighting': lighting, 'identity': identity, 'styleSid': style, 'time': 3.0,
                      'framesAfterRebuild': 4, 'size': [960, 960], 'cached': False,
                      'method': '2D albedo + normals -> original noise/common style_shade -> original bloom_down -> bloom_blur -> post.gdshader',
                      'postShaderHash': digest((SOURCE / 'shaders/post.gdshader').read_bytes())}
            metadata.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            return result


class StudyHandler(SimpleHTTPRequestHandler):
    generator: WorldGenerator

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(HERE), **kwargs)

    def send_json(self, status: int, value: object) -> None:
        body = canonical(value)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def local_request(self) -> bool:
        host = self.headers.get('Host', '')
        allowed = {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}
        if host not in allowed:
            self.send_json(403, {'error': 'Local host required'})
            return False
        origin = self.headers.get('Origin')
        if origin and origin not in {'http://' + entry for entry in allowed}:
            self.send_json(403, {'error': 'Same-origin request required'})
            return False
        return True

    def do_GET(self) -> None:
        if not self.local_request():
            return
        if urlsplit(self.path).path == '/api/config':
            self.send_json(200, load_configuration())
        else:
            super().do_GET()

    def do_POST(self) -> None:
        if not self.local_request():
            return
        endpoint = urlsplit(self.path).path
        if endpoint not in {'/api/world', '/api/style'}:
            self.send_json(404, {'error': 'Unknown endpoint'})
            return
        if self.headers.get('Content-Type', '').split(';', 1)[0].strip() != 'application/json':
            self.send_json(415, {'error': 'application/json required'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            maximum = 28_001_000 if endpoint == '/api/style' else 4096
            if not 0 < length <= maximum:
                raise ValueError('Invalid request size')
            request = json.loads(self.rfile.read(length))
            result = self.generator.style_images(request) if endpoint == '/api/style' else self.generator.generate(request)
            self.send_json(200, result)
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json(400, {'error': str(error)})
        except subprocess.TimeoutExpired:
            self.send_json(504, {'error': 'Godot rendering exceeded 60 seconds'})
        except (OSError, RuntimeError) as error:
            self.send_json(500, {'error': str(error)})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8950)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    if not Path(args.godot).is_file():
        parser.error('Godot executable not found; set GODOT_BIN or --godot')
    StudyHandler.generator = WorldGenerator(args.godot)
    server = ThreadingHTTPServer(('127.0.0.1', args.port), StudyHandler)
    print(f'Procedural study: http://127.0.0.1:{args.port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
