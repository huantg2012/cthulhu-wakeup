#!/usr/bin/env python3
"""Validate formal fidelity data contracts, without simulating gameplay."""
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TABLES = ('fidelity_parameters', 'intervention_policies', 'simulation_responsibilities',
          'civilization_parameters', 'event_parameters', 'run_parameters',
          'powers', 'prayers', 'events', 'event_effects')
SCHEMAS = {
    'fidelity_parameters': {'id', 'value', 'unit', 'activation', 'rationale'},
    'intervention_policies': {'id', 'family', 'content_id', 'variant', 'focus_scope', 'person_scope', 'member_scope', 'rationale'},
    'simulation_responsibilities': {'id', 'focused', 'background', 'commit_owner', 'phase'},
}
# Protocol shape, not a second source of tuning values.
PARAMETER_TYPES = {
    'focused_domain_limit': ('domain', 'hybrid'),
    'initial_focused_domains': ('domain', 'hybrid'),
    'bound_member_limit': ('person', 'hybrid'),
    'temporary_actor_limit': ('person', 'hybrid'),
    'local_actor_limit': ('person_per_focused_domain', 'hybrid'),
    'background_tick_interval': ('turn', 'hybrid'),
    'background_candidate_trials': ('trial_per_due_domain', 'hybrid'),
    'pending_candidate_limit': ('candidate', 'hybrid'),
    'candidate_actor_limit': ('person_per_candidate', 'hybrid'),
    'decision_query_page_limit': ('record_per_page', 'indexed'),
    'archive_page_records': ('record_per_segment', 'segmented'),
}
SYSTEM_ENTRIES = {'CULT_FORM', 'CULT_SUCCESSION', 'MEMBER_ENROLL', 'MEMBER_LEAVE',
                  'RELIC_EQUIP', 'RELIC_UNBIND', 'RELIC_FAITH', 'RELIC_INSIGHT',
                  'RELIC_FOLLOWERS', 'RELIC_WHISPERS', 'RELIC_RECOVER', 'RELIC_PUBLIC',
                  'MANIFEST_CONTINUE', 'REST'}
DUTIES = {
    'npc_agency': ('detailed', 'selected_detailed_only', 'world', '4'),
    'civilization_routine': ('detailed', 'abstract_due', 'world', '4'),
    'risk_selection': ('risk', 'risk', 'world', '4'),
    'evidence_from_actor': ('detailed', 'selected_detailed_only', 'world', '4'),
    'economy': ('economy', 'economy', 'economy', '4|5'),
    'identity_and_population': ('authorized_effects', 'authorized_effects', 'world', 'bootstrap|1|2|3|4|5'),
    'due_obligations': ('scheduler', 'scheduler', 'turn', '1|5'),
    'candidate_generation': ('detailed_candidates', 'abstract_candidates_due', 'events', 'bootstrap|4'),
    'candidate_selection': ('events', 'events', 'turn', '2'),
    'candidate_fixation': ('events', 'events', 'events', 'bootstrap|2|3|4'),
    'attention_admission': ('attention', 'attention', 'turn', 'bootstrap|1|2|3|4|5'),
    'derived_progress': ('derived', 'derived', 'world', 'after_commit'),
    'ending': ('ending', 'ending', 'turn', '6'),
    'history_and_receipts': ('commit', 'commit', 'transaction', 'after_commit'),
}


def load(root: Path = ROOT) -> dict[str, list[dict]]:
    tables = {}
    for name in TABLES:
        with (root / 'data' / f'{name}.csv').open(newline='', encoding='utf-8-sig') as file:
            reader = csv.DictReader(file, strict=True)
            if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
                raise ValueError(f'{name}: missing/duplicate headers')
            rows = list(reader)
            if not rows or any(None in row or None in row.values() for row in rows):
                raise ValueError(f'{name}: empty or ragged table')
            tables[name] = rows
    return tables


def validate(tables: dict) -> list[str]:
    errors = []
    for name, fields in SCHEMAS.items():
        rows = tables.get(name, [])
        if not rows or any(set(row) != fields for row in rows):
            errors.append(f'{name}: schema mismatch')
            return errors
        ids = [row['id'] for row in rows]
        if any(not value for row in rows for value in row.values()) or len(ids) != len(set(ids)):
            errors.append(f'{name}: empty field or duplicate identity')
    params = {r['id']: r for r in tables['fidelity_parameters']}
    if set(params) != set(PARAMETER_TYPES):
        errors.append('parameter coverage mismatch')
    numeric = {}
    for key, row in params.items():
        try:
            value = int(row['value'])
            if str(value) != row['value'] or value <= 0:
                raise ValueError()
            numeric[key] = value
        except (ValueError, TypeError):
            errors.append(f'{key}: expected positive canonical integer')
        if (row['unit'], row['activation']) != PARAMETER_TYPES.get(key):
            errors.append(f'{key}: invalid unit or activation')
    owners = ('civilization_parameters', 'event_parameters', 'run_parameters')
    if any(set(params) & {r['id'] for r in tables[name]} for name in owners):
        errors.append('new parameter duplicates existing owner')
    if set(numeric) == set(PARAMETER_TYPES):
        civ = {r['id']: int(r['value']) for r in tables['civilization_parameters']}
        event = {r['id']: int(r['value']) for r in tables['event_parameters']}
        if not (numeric['initial_focused_domains'] <= civ['initial_known_domains'] <= civ['domains_total']
                and numeric['initial_focused_domains'] <= numeric['focused_domain_limit'] <= civ['domains_total']):
            errors.append('initial/known/focused/world capacities inconsistent')
        if numeric['focused_domain_limit'] < 2:
            errors.append('cannot admit two-domain migration or manifestation')
        if numeric['local_actor_limit'] < civ['institutions_per_domain']:
            errors.append('local budget cannot fit institution roles')
        detailed = numeric['bound_member_limit'] + numeric['temporary_actor_limit'] + numeric['focused_domain_limit'] * numeric['local_actor_limit']
        if detailed > civ['living_named_global_limit']:
            errors.append('detailed capacity exceeds persistent living identity capacity')
        if numeric['candidate_actor_limit'] > numeric['temporary_actor_limit']:
            errors.append('one maximal nonmember candidate cannot fit temporary capacity')
        if numeric['pending_candidate_limit'] < max(event['prayer_offer_limit'], event['major_event_limit']):
            errors.append('candidate pool smaller than an individual display limit')
    rows = tables['intervention_policies']
    keys = [(r['family'], r['content_id'], r['variant']) for r in rows]
    expected = ({('power', r['id'], 'use') for r in tables['powers']}
                | {('prayer', r['id'], mode) for r in tables['prayers'] for mode in ('shallow', 'deep')}
                | {('event', r['event_id'], r['option']) for r in tables['event_effects']}
                | {('strategy', name, 'plan') for name in ('proselytize', 'conceal', 'maintain')}
                | {('system', name, 'use') for name in SYSTEM_ENTRIES})
    if len(keys) != len(set(keys)) or set(keys) != expected:
        errors.append('entry coverage mismatch or duplicate content branch')
    policies = dict(zip(keys, rows))
    for row in rows:
        if row['focus_scope'] not in {'none', 'target', 'source_and_target', 'ritual_domains'}:
            errors.append(f"{row['id']}: invalid focus scope")
        if row['person_scope'] not in {'none', 'participants', 'fixed'}:
            errors.append(f"{row['id']}: invalid person scope")
        if row['member_scope'] not in {'none', 'nominees'}:
            errors.append(f"{row['id']}: invalid member scope")
        if row['member_scope'] == 'nominees' and row['person_scope'] != 'participants':
            errors.append(f"{row['id']}: enrollment without participants")
        if row['family'] == 'prayer' and (row['variant'] == 'deep' or row['content_id'] == 'PRAYER_09') and row['focus_scope'] != 'target':
            errors.append(f"{row['id']}: deep/barrier intervention bypasses focus")
    def require(key, field, expected_value):
        if key in policies and policies[key][field] != expected_value:
            errors.append(f'{key}: {field} must be {expected_value}')
    for e in tables['events']:
        key = ('event', e['id'], e['default_result'].removeprefix('option:'))
        for field, value in [('focus_scope', 'none'), ('person_scope', 'fixed'), ('member_scope', 'none')]:
            require(key, field, value)
    for name in ('POWER_DREAM', 'POWER_BESTOW', 'POWER_APPOINT', 'POWER_SACRIFICE', 'POWER_BREACH', 'POWER_SEED', 'POWER_ANCHOR', 'POWER_VEIL'):
        require(('power', name, 'use'), 'focus_scope', 'target')
    require(('power', 'POWER_TRANSFER', 'use'), 'focus_scope', 'source_and_target')
    require(('power', 'POWER_MANIFEST', 'use'), 'focus_scope', 'ritual_domains')
    require(('system', 'MANIFEST_CONTINUE', 'use'), 'focus_scope', 'ritual_domains')
    for mode in ('shallow', 'deep'):
        require(('prayer', 'PRAYER_08', mode), 'member_scope', 'nominees')
    for name in ('POWER_APPOINT', 'POWER_ANCHOR'):
        require(('power', name, 'use'), 'member_scope', 'nominees')
    for name in ('CULT_FORM', 'CULT_SUCCESSION', 'MEMBER_ENROLL'):
        require(('system', name, 'use'), 'member_scope', 'nominees')
    for name, focus in [('proselytize', 'target'), ('conceal', 'none'), ('maintain', 'none')]:
        require(('strategy', name, 'plan'), 'focus_scope', focus)
    duties = {r['id']: tuple(r[f] for f in ('focused', 'background', 'commit_owner', 'phase'))
              for r in tables['simulation_responsibilities']}
    if duties != DUTIES:
        errors.append('duty coverage/producer/owner/phase differs from finite protocol')
    return errors


if __name__ == '__main__':
    problems = validate(load())
    print('\n'.join(problems) if problems else 'PASS fidelity data contracts (static only)')
    raise SystemExit(bool(problems))
