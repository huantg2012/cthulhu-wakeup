"""Build the offline experience wireframe. Data definitions flow from CSV.

The fixture states and scripted outcomes are presentation studies, not a second
game engine. No production code or save format is modified.
"""
from pathlib import Path
import csv
import json

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'docs/game-state/ui-experience.html'
TABLES = ['powers', 'prayers', 'events', 'event_effects', 'relics',
          'civilization_profiles', 'progression_route_operations', 'run_parameters',
          'foundation_route_parameters', 'material_transfer_parameters', 'memory_contract_route_parameters']
data = {}
for name in TABLES:
    with (ROOT / 'data' / (name + '.csv')).open(encoding='utf-8-sig', newline='') as f:
        data[name] = list(csv.DictReader(f))
data['params'] = {r['id']: float(r['value']) for name in TABLES if name.endswith('parameters') for r in data[name]}
payload = json.dumps(data, ensure_ascii=False).replace('</', '<\\/')
html = (HERE / 'shell.html').read_text(encoding='utf-8')
html = html.replace('/* STYLES */', (HERE / 'style.css').read_text(encoding='utf-8'))
html = html.replace('/* CATALOG */', 'window.CATALOG = ' + payload + ';')
html = html.replace('/* APPLICATION */', (HERE / 'app.js').read_text(encoding='utf-8'))
OUT.write_text(html, encoding='utf-8')
print(f'{OUT} ({len(html.encode("utf-8")):,} bytes; {len(data["powers"])} powers; {len(data["progression_route_operations"])} route definitions)')
