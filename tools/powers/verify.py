#!/usr/bin/env python3
"""Run actual powers/relics plus the registered, source-frozen regression chain."""
from __future__ import annotations
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fidelity_wrapper', ROOT/'tools/fidelity/verify.py')
fidelity = importlib.util.module_from_spec(spec); spec.loader.exec_module(fidelity)

def hashes():
    result = fidelity.hashes()
    paths = [ROOT/'docs/tasks/slice-05.md', ROOT/'docs/tasks/slice-06.md']
    for directory in ['cults','powers']:
        paths += [p for p in (ROOT/'tools'/directory).glob('*') if p.is_file() and p.suffix in ['.md','.py','.gd']]
    for p in paths:
        result[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def expected_ids():
    rows = list(csv.DictReader((ROOT/'data/powers.csv').read_text(encoding='utf-8').splitlines()))
    assert len(rows) == 12
    expected = {f"PWR/{r['id']}/{o}" for r in rows for o in (['success'] if r['check_kind']=='deterministic' else ['deep','success','failure','disaster'])}
    expected |= {'INVALID/'+r['id'] for r in rows}
    expected |= {f'PWR-{i:03d}' for i in range(1,22) if i!=14}
    expected |= {'PWR-014/heal','PWR-014/insight'}
    relics = list(csv.DictReader((ROOT/'data/relics.csv').read_text(encoding='utf-8').splitlines()))
    assert len(relics) == 6
    expected |= {f"RELIC/convert/{r['id']}/{mode}" for r in relics for mode in ['faith','insight','followers','whispers']}
    expected |= {'RELIC/capacity/'+mode for mode in ['faith','insight','followers','whispers']}
    expected |= {'RELIC/'+name for name in ['inventory','binding-save','unbind','seal-expiry','seize-recover','destroy','transfer-carry','death-ground']}
    expected |= {'RELIC/carry/'+r['id'] for r in relics}
    return expected

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True); parser.add_argument('--smoke', action='store_true')
    args=parser.parse_args(); before=hashes()
    with tempfile.TemporaryDirectory(prefix='powers-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary); output=scratch/'powers.json'
        fidelity.execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/powers/run.gd','--',str(output)], ROOT/'tools/powers/run.log',600)
        raw=json.loads(output.read_text(encoding='utf-8')); checks=raw['checks']; expected=expected_ids()
        actual={x['id'] for x in checks}
        if actual!=expected or len(checks)!=len(expected): raise RuntimeError(f'Missing/duplicate checks: missing={expected-actual}, extra={actual-expected}')
        if raw['status']!='pass' or any(x['status']!='pass' for x in checks): raise RuntimeError('Power or relic assertions failed')
        if before!=hashes(): raise RuntimeError('Sources changed during specialty execution')
        if args.smoke:
            print(f'SMOKE {len(checks)} checks; no formal evidence written'); return 0
        target=ROOT/'docs/qa/cults-results.json'; previous=target.stat().st_mtime_ns
        fidelity.execute([sys.executable,'-X','utf8','tools/cults/verify.py','--godot',args.godot],ROOT/'tools/powers/regressions.log',2400)
        if target.stat().st_mtime_ns==previous: raise RuntimeError('Missing fresh cult regression report')
        regression=json.loads(target.read_text(encoding='utf-8'))
        if regression['status']!='pass' or any(x['status']!='pass' for x in regression['checks']): raise RuntimeError('Cult regressions failed')
        if before!=hashes(): raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':'docs/qa/cults-results.json','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'cultChecks':len(regression['checks']),'fidelityChecks':regression['regressions']['fidelityChecks'],'otherChecks':regression['regressions']['otherChecks']},'limitations':['上游联系/制度条件/见证/掉落和夺回授权是明确的版本化合同夹具；完整来源生产仍由PRAYERS/EVENTS/ANCHORS实现。','高阶既存世界由真实身份、机构、经济资格、媒介和锚点贡献构造；不直接改苏醒值、注入骰或权能结果。','本项实现锚定与三轮降临；完整制度条件、断联/终局优先级及封存仍分别由ANCHORS/ENDINGS验收。','无游戏内界面；真人理解、完整策略平衡、叙事及发行平台持久性/性能仍按原任务。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realCultFidelityAndNineRegressions':True}}
        (ROOT/'docs/qa/powers-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 正式权能与圣物验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'','真实generate_hybrid/Turn/Economy/Cults/Powers/Relics使用正式CSV。执行协议见[tools/powers](../../tools/powers/README.md)。','']
        lines += [f"- `{x['id']}`：{x['name']}（{x['status']}）。" for x in checks]
        lines += ['',f"关联回归实际重跑：{len(regression['checks'])}教团、{regression['regressions']['fidelityChecks']}混合与{regression['regressions']['otherChecks']}既有检查。全部来源/报告指纹见[机器证据](powers-results.json)。",'']
        lines += ['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/powers.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} powers/relics checks and actual registered regressions')
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as error: print('FAIL:',error,file=sys.stderr); raise SystemExit(1)
