"""Read-only visual adapters to existing prayer cases; never creates game NPCs."""
import csv
from server import REPO, digest


def context_catalog():
    case_path = REPO / 'data/prayer_space_cases.csv'
    rules_path = REPO / 'data/portrait_context_rules.csv'
    with case_path.open(newline='') as source:
        cases = {r['id']: r for r in csv.DictReader(source)}
    result = []
    with rules_path.open(newline='') as source:
        for rule in csv.DictReader(source):
            case = cases[rule['case_id']]
            result.append({
                'caseId': case['id'], 'role': case['petitioner'], 'frame': case['frame'],
                'scene': case['scene'], 'title': case['title'], 'context': case['context'],
                'appeal': case['appeal'], 'goal': case['goal'],
                'garments': rule['garments'].split('|'), 'heads': rule['heads'].split('|'),
                'gestures': rule['gestures'].split('|'), 'material': rule['material'],
                'pigment': rule['pigment'], 'workDetail': rule['work_detail'],
                'genderRule': rule['gender_rule'], 'appearanceNote': rule['appearance_note'],
                'source': {'cases': 'data/prayer_space_cases.csv', 'caseHash': digest(case_path.read_bytes()),
                           'visualRules': 'data/portrait_context_rules.csv', 'rulesHash': digest(rules_path.read_bytes())},
                'binding': '美术探索采用既有祈求角色槽；未绑定正式 Session 人物，不新增游戏事实'
            })
    world_path = REPO / 'data/portrait_world_rules.csv'
    with world_path.open(newline='') as source:
        worlds = list(csv.DictReader(source))
    environment_path = REPO / 'data/portrait_environment_rules.csv'
    with environment_path.open(newline='') as source:
        environments = list(csv.DictReader(source))
    counts = {}
    templates = ['tide'] + sorted({row['template'] for row in worlds})
    for template in templates:
        rules = result if template == 'tide' else [row for row in worlds if row['template'] == template]
        counts[template] = {'backgrounds': len(rules), 'discreteCombinations': sum(
            len(row['garments'] if isinstance(row['garments'], list) else row['garments'].split('|')) *
            len(row['heads'] if isinstance(row['heads'], list) else row['heads'].split('|')) *
            len(row['gestures'] if isinstance(row['gestures'], list) else row['gestures'].split('|')) for row in rules)}
    return {'counts': counts, 'environments': environments, 'environmentRulesHash': digest(environment_path.read_bytes()), 'worldRules': worlds, 'worldRulesHash': digest(world_path.read_bytes()), 'contexts': result, 'availableCaseCount': len(cases), 'coveredCaseCount': len(result)}
