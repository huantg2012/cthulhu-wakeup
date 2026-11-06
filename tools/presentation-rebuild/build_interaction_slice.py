#!/usr/bin/env python3
"""Package the independent interaction fixture, never run game rules or write saves."""
import csv
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'docs/art/presentation-rebuild'
def read(path):
    with path.open(newline='') as f:
        return list(csv.DictReader(f))
def main():
    data = {name: read(ROOT / 'data' / f'{name}.csv') for name in
            ['powers', 'relics', 'civilization_profiles', 'prayers', 'run_parameters', 'events', 'event_effects', 'world_intelligence_bands', 'world_observation_sources']}
    data['fixture'] = read(HERE / 'interaction_fixture.csv')
    data['power_fields'] = read(HERE / 'power_preparation_fields.csv')
    data['observations'] = read(HERE / 'world_observation_fixture.csv')
    template = (HERE / 'interaction_slice.template.html').read_text()
    template = template.replace('</style>', (HERE / 'interaction_refinements.css').read_text() + (HERE / 'ritual_experience.css').read_text() + '</style>')
    template = template.replace("window.addEventListener('resize',resize);setupScene();dust();render();resize();", (HERE / 'interaction_refinements.js').read_text() + (HERE / 'ritual_experience.js').read_text() + "\nwindow.addEventListener('resize',resize);setupScene();dust();render();resize();")
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    (OUT / 'interaction-slice.html').write_text(template.replace('__INTERACTION_DATA__', payload))
    print('Built interaction-slice.html: CSV catalog + explicit demonstration fixture; no Session/save access.')
if __name__ == '__main__':
    main()
