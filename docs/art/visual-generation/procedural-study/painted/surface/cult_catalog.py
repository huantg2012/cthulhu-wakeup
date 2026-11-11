"""Visual candidates, authored in CSV; original style/palette metadata stays source-owned."""
import csv
import re
from server import REPO, SOURCE, load_configuration, digest


def cult_catalog():
    config = load_configuration()
    source = (SOURCE / 'scripts/data.gd').read_text()
    palette_block = source.split('const PALETTES := [', 1)[1].split('\n]', 1)[0]
    originals = re.findall(r'\{"name":.*?\}', palette_block, re.S)
    for palette, original in zip(config['palettes'], originals):
        palette['star'] = '#' + re.search(r'"star": \["([a-fA-F0-9]+)"', original)[1]
        palette['corruption'] = '#' + re.search(r'"cor": \["[a-fA-F0-9]+", "([a-fA-F0-9]+)"', original)[1]
    path = REPO / 'data/cult_visual_rules.csv'
    with path.open(newline='') as source_file:
        rules = list(csv.DictReader(source_file))
    for rule in rules:
        rule['archetype'] = int(rule['archetype'])
        rule['default_palette'] = int(rule['default_palette'])
    config['cultRules'] = rules
    config['rulesFingerprint'] = digest(path.read_bytes())
    config['scope'] = '独立视觉候选；未绑定正式 Session 教团'
    return config
