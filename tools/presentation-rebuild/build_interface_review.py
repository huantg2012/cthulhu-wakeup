#!/usr/bin/env python3
"""Build a self-contained design review. CSV supplies catalog facts; no game simulation."""
from pathlib import Path
import csv
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/presentation-rebuild'

def rows(name):
    with (ROOT / 'data' / f'{name}.csv').open(newline='') as stream:
        return list(csv.DictReader(stream))

def main():
    tasks = []
    for line in (OUT / 'interface-design.md').read_text().splitlines():
        if line.startswith('| T'):
            parts = [part.strip() for part in line.strip('|').split('|')]
            tasks.append(dict(zip(['name', 'question', 'information', 'entry', 'source'], parts)))
    data = {'tasks': tasks, 'powers': rows('powers'), 'relics': rows('relics'),
            'worlds': rows('civilization_profiles'),
            'scope': '设计夹具；不执行游戏规则，场景中的实例、状态和人员用于说明导航，不是正式存档。',
            'sources': ['docs/gdd-core.md', 'docs/art/echoes-ui/component-map.md',
                        'data/powers.csv', 'data/relics.csv', 'data/civilization_profiles.csv']}
    template = Path(__file__).with_name('interface_review.template.html').read_text()
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    (OUT / 'interface-review.html').write_text(template.replace('__DESIGN_DATA__', payload))
    (OUT / 'interface-coverage.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f'Built design review: {len(tasks)} task families, {len(data["powers"])} CSV powers; no Session or game saves.')

if __name__ == '__main__':
    main()
