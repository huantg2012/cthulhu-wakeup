#!/usr/bin/env python3
"""Package the independent interaction fixture, never run game rules or write saves."""
import csv
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'docs/art/presentation-rebuild'
START = "window.addEventListener('resize',resize);setupScene();dust();render();resize();"


def read(path):
    with path.open(newline='') as f:
        return list(csv.DictReader(f))


def write_page(name, template, data):
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    (OUT / name).write_text(template.replace('__INTERACTION_DATA__', payload))


def comparison_data(data):
    snapshots = json.loads((HERE / 'comparison_worlds.json').read_text())
    scenes = read(HERE / 'comparison_scenes.csv')
    cases = {scene['case'] for scene in scenes}
    return {
        **data,
        'comparison': [dict(scene, **snapshots[scene['seed']]) for scene in scenes],
        'comparison_prayers': [row for row in read(ROOT / 'data/prayer_space_cases.csv') if row['id'] in cases],
        'comparison_contracts': [row for row in read(ROOT / 'data/prayer_space_response_contracts.csv') if row['case_id'] in cases],
        'comparison_costs': read(ROOT / 'data/prayer_space_costs.csv'),
    }


def main():
    data = {name: read(ROOT / 'data' / f'{name}.csv') for name in
            ['powers', 'relics', 'civilization_profiles', 'prayers', 'run_parameters', 'events', 'event_effects', 'world_intelligence_bands', 'world_observation_sources']}
    data['fixture'] = read(HERE / 'interaction_fixture.csv')
    data['power_fields'] = read(HERE / 'power_preparation_fields.csv')
    data['observations'] = read(HERE / 'world_observation_fixture.csv')
    template = (HERE / 'interaction_slice.template.html').read_text()
    template = template.replace('</style>', (HERE / 'interaction_refinements.css').read_text() + (HERE / 'ritual_experience.css').read_text() + '</style>')
    template = template.replace(START, (HERE / 'interaction_refinements.js').read_text() + (HERE / 'ritual_experience.js').read_text() + "\n" + START)
    write_page('interaction-slice.html', template, data)
    comparison = template.replace('</title>', ' · 美术对照</title>')
    comparison = comparison.replace('</style>', (HERE / 'art_comparison.css').read_text() + '</style>')
    comparison = comparison.replace(START, (HERE / 'art_comparison.js').read_text() + "\n" + START)
    write_page('art-comparison.html', comparison, comparison_data(data))
    perspective = template.replace('</title>', ' · 视角探索</title>')
    perspective = perspective.replace('</style>', (HERE / 'perspective_exploration.css').read_text() + '</style>')
    perspective = perspective.replace('PRAYER_04', 'PRAYER_08')
    perspective = perspective.replace('镜证议会', '阿纳瓦邦联').replace('第三记录院', '沿岸见证所')
    perspective = perspective.replace('记录者·伊弥', '求告者·米拉').replace('记录者伊弥', '求告者米拉')
    perspective = perspective.replace(START, (HERE / 'perspective_exploration.js').read_text() + "\n" + START)
    write_page('perspective-slice.html', perspective, comparison_data(data))
    print('Built interaction-slice.html, art-comparison.html and perspective-slice.html.')
if __name__ == '__main__':
    main()
