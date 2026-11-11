"""Individual content-addressed portraits, batched through unchanged NPR source."""
import base64
import binascii
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
from server import CACHE, SOURCE, RENDER_LOCK, canonical, digest, source_fingerprint

HERE = Path(__file__).resolve().parent


def style_people(generator, body, subject='person'):
    if not isinstance(body, dict) or set(body) != {'request', 'images'}:
        raise ValueError('Expected request and images')
    params, identity, sid = generator.validate_request(body['request'])
    images = body['images']
    if not isinstance(images, dict) or not 1 <= len(images) <= 8:
        raise ValueError('Supply 1 to 8 portraits per batch')
    payloads = {}
    for key, value in images.items():
        if not re.fullmatch(('c' if subject == 'cult' else 'p') + r'[0-9]{1,10}', key):
            raise ValueError('Invalid portrait ID')
        if not isinstance(value, str) or not value.startswith('data:image/png;base64,') or len(value) > 7_000_000:
            raise ValueError('Expected PNG data URL under 5 MB')
        try:
            png = base64.b64decode(value.split(',', 1)[1], validate=True)
        except binascii.Error as error:
            raise ValueError('Invalid base64') from error
        if len(png) < 33 or len(png) > 5_242_880 or not png.startswith(b'\x89PNG\r\n\x1a\n') or png[12:16] != b'IHDR' or struct.unpack('>II', png[16:24]) != (960, 960):
            raise ValueError('Expected 960 x 960 PNG')
        payloads[key] = png
    fingerprint = source_fingerprint()
    adapter = HERE / 'style_people.gd'
    contract = {'schema': 'cult-npr-1' if subject == 'cult' else 'people-npr-1', 'sourceFingerprint': fingerprint,
                'adapterFingerprint': digest(adapter.read_bytes()), 'params': params, 'time': 3.0}
    entries = {}
    with RENDER_LOCK:
        missing = {}
        for key, png in payloads.items():
            stamp = digest(canonical({**contract, 'inputHash': digest(png)}))
            target, meta = CACHE / f'{stamp}-{subject}.png', CACHE / f'{stamp}-{subject}.json'
            if target.is_file() and meta.is_file():
                saved = json.loads(meta.read_text())
                if saved.get('hash') == digest(target.read_bytes()):
                    entries[key] = {**saved, 'cached': True}
                    continue
            missing[key] = (target, meta)
        if missing:
            project = generator.prepare(fingerprint)
            shutil.copy2(adapter, project / 'style_people.gd')
            scene = (SOURCE / 'main.tscn').read_text().replace('res://scripts/main.gd', 'res://style_people.gd')
            (project / 'style_people.tscn').write_text(scene)
            with tempfile.TemporaryDirectory(prefix='cthulhu-people-') as temporary:
                scratch = Path(temporary)
                inputs, outputs = {}, {}
                for key in missing:
                    path = scratch / f'{key}-in.png'
                    path.write_bytes(payloads[key])
                    inputs[key], outputs[key] = str(path), str(scratch / f'{key}-out.png')
                job = {'params': params, 'inputs': inputs, 'outputs': outputs, 'lighting': str(scratch / 'lighting.json')}
                job_path = scratch / 'job.json'
                job_path.write_text(json.dumps(job))
                run = subprocess.run([generator.godot, '--path', str(project), '--position', '20000,20000',
                    'res://style_people.tscn', '--', '--style-job=' + str(job_path)], capture_output=True, text=True, timeout=60)
                if run.returncode or 'SCRIPT ERROR:' in run.stderr or 'SHADER ERROR:' in run.stderr or not all(Path(p).is_file() for p in outputs.values()):
                    raise RuntimeError('Portrait NPR failed: ' + (run.stderr or run.stdout)[-1800:])
                for key, (target, meta) in missing.items():
                    png = Path(outputs[key]).read_bytes()
                    result = {**contract, 'url': '/cache/' + target.name, 'hash': digest(png),
                              'inputHash': digest(payloads[key]), 'cached': False}
                    target.write_bytes(png)
                    meta.write_bytes(canonical(result))
                    entries[key] = result
    return {'scenes' if subject == 'cult' else 'portraits': entries, 'sourceFingerprint': fingerprint, 'identity': identity, 'styleSid': sid}
