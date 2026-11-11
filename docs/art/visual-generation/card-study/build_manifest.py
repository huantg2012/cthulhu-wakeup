"""Compile CSV study identity/parameters into ui.js for offline file:// use."""
import csv
import hashlib
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
manifest = {}
for row in csv.DictReader((HERE / 'study-manifest.csv').open()):
    value = row['value']
    value = {'int': int, 'float': float, 'bool': lambda x: x == 'true', 'string': str}[row['type']](value)
    manifest.setdefault(row['section'], {})[row['key']] = value
names = list(csv.DictReader((REPO / 'data/player_text.csv').open()))
# Keep the actual formal display title as the sole source; never copy the old profile label.
name_row = next(r for r in names if r['table'] == 'civilization_profiles' and r['key'] == manifest['identity']['world_template_id'] and r['field'] == 'name')
manifest['identity']['world_name'] = name_row['text']
report = HERE / 'reference-check' / 'fidelity.json'
if report.exists():
    evidence = json.loads(report.read_text())
    if evidence['parameters'] != manifest['params']:
        raise SystemExit('CSV parameters differ from independently rendered reference; reconcile before publishing.')
    for asset in ('reference', 'sample'):
        file_path = HERE / evidence[asset]['path']
        if hashlib.sha256(file_path.read_bytes()).hexdigest() != evidence[asset]['sha256']:
            raise SystemExit(f'{asset} PNG changed since fidelity measurement; rerun comparison first.')
    comparison = evidence['comparison']
    manifest['comparison'] = {'status': 'measured', 'summary': f"源资产比对：不同像素 {comparison['different_pixels']}；RGBA 完全一致：{comparison['rgba_pixels_equal']}；平均 RGB 绝对误差 {comparison['mean_absolute_rgb_error']}。结果只证明 PNG 还原，不代表 UI 缩放或审美通过。", 'evidence': evidence}
else:
    manifest['comparison'] = {'status': 'pending', 'summary': '待完成同参数原作基准与当前资产的像素比对；未声明通过。'}
start = '// BEGIN GENERATED STUDY MANIFEST'
end = '// END GENERATED STUDY MANIFEST'
p = HERE / 'ui.js'
s = p.read_text()
block = start + '\nconst STUDY_MANIFEST = ' + json.dumps(manifest, ensure_ascii=False, indent=2) + ';\n' + end
if start in s:
    s = s[:s.index(start)] + block + s[s.index(end) + len(end):]
else:
    s = block + '\n' + s
p.write_text(s)
print('Compiled study identity and parameters from CSV; comparison status:', manifest['comparison'].get('status', 'reported'))
