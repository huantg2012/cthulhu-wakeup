#!/usr/bin/env python3
"""Run static configuration checks plus mutation regressions; bind real evidence."""
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from check import ROOT, TABLES, load, validate


def sources():
    return sorted({*(ROOT / 'data' / f'{t}.csv' for t in TABLES),
                   *ROOT.glob('docs/specs/system-*.md'),
                   ROOT / 'docs/architecture.md', ROOT / 'docs/tasks/slice-04.md',
                   *Path(__file__).parent.glob('*.py'), Path(__file__).with_name('README.md')})


def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources()}


def main():
    before = hashes()
    tables = load()
    errors = validate(tables)
    result = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(Path(__file__).parent),
                             '-p', 'test_*.py'], capture_output=True, text=True, timeout=30)
    print(result.stdout + result.stderr, end='')
    after = hashes()
    params = {r['id']: int(r['value']) for r in tables['fidelity_parameters']}
    checks = [
        {'id': 'FID-RULES-CATALOG', 'status': 'fail' if errors else 'pass', 'details': {
            'errors': errors, 'entryCount': len(tables['intervention_policies']),
            'dutyCount': len(tables['simulation_responsibilities']),
            'detailedActorUpperBound': params['bound_member_limit'] + params['temporary_actor_limit'] + params['focused_domain_limit'] * params['local_actor_limit'],
            'scope': 'Formal schema, references, default admission and finite duty contracts only'}},
        {'id': 'FID-RULES-NEGATIVE', 'status': 'pass' if result.returncode == 0 else 'fail',
         'details': {'output': result.stdout + result.stderr, 'scope': 'Real config mutations, no runtime simulator'}},
        {'id': 'FID-RULES-SOURCES', 'status': 'pass' if before == after else 'fail',
         'details': {'unchangedDuringRun': before == after}},
    ]
    report = {'generatedAt': datetime.now(timezone.utc).isoformat(), 'checks': checks,
              'sourceHashes': after,
              'scope': 'TASK-FIDELITY-RULES static data contract only; hybrid simulation and load remain unimplemented.'}
    (ROOT / 'docs/qa/fidelity-rules-results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for c in checks:
        print(c['status'].upper(), c['id'])
    return int(any(c['status'] != 'pass' for c in checks))


if __name__ == '__main__':
    raise SystemExit(main())
