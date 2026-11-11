"""Fail if the accepted generator or its raw displayed world asset drifts."""
from pathlib import Path
import hashlib, json
from PIL import Image, ImageChops
ROOT = Path(__file__).resolve().parent
record = json.loads((ROOT / 'reference-check/fidelity.json').read_text())
source = ROOT.parent / 'godot-base'
manifest_path = ROOT / record['source_manifest']
assert hashlib.sha256(manifest_path.read_bytes()).hexdigest() == record['source_manifest_sha256'], 'Source manifest changed'
for name, digest in json.loads(manifest_path.read_text()).items():
    assert hashlib.sha256((source / name).read_bytes()).hexdigest() == digest, f'Generator drift: {name}'
paths = [ROOT / record[key]['path'] for key in ('reference', 'sample')]
for key, path in zip(('reference', 'sample'), paths):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record[key]['sha256'], f'Image drift: {path.name}'
images = [Image.open(path).convert('RGBA') for path in paths]
assert images[0].size == images[1].size == tuple(record['capture']['output_size'])
assert images[0].tobytes() == images[1].tobytes(), 'Reference/sample pixels differ'
print('PASS: original source fingerprints unchanged; reference/sample bytes and 960x960 RGBA pixels identical.')
print('Browser rendering and companion-art quality require their own visual review.')
