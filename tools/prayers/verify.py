#!/usr/bin/env python3
"""Execute formal prayer business and the complete registered regression chain."""
from __future__ import annotations
import argparse,csv,hashlib,importlib.util,json,platform,subprocess,sys,tempfile
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('powers_wrapper',ROOT/'tools/powers/verify.py')
powers=importlib.util.module_from_spec(spec);spec.loader.exec_module(powers)

def hashes():
    result=powers.hashes()
    for p in [ROOT/'docs/tasks/slice-07.md', *sorted((ROOT/'tools/prayers').glob('*'))]:
        if p.is_file() and p.suffix in ['.gd','.py','.md']:result[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def expected_ids():
    rows=list(csv.DictReader((ROOT/'data/prayers.csv').read_text(encoding='utf-8').splitlines()))
    assert len(rows)==12
    result={f"PRAYER/{r['id']}/{variant}/{outcome}" for r in rows for variant in ['shallow','deep'] for outcome in ['deep','success','failure','disaster']}
    result |= {f"EXPIRY/{r['id']}" for r in rows}
    result |= {f'PRY-001/{seed}' for seed in [7919,104729,2027]}
    result |= {'PRY-002','PRY-003/death','PRY-003/migrate','PRY-004/failed','PRY-004/rescued','PRY-005','PRY-006','PRY-007','PRY-008','PRY-009','PRY-010','PRY-011/objects','PRY-011/deadline','PRY-011/omitted','PRY-012/answered','PRY-012/unanswered','PRY-013/private','PRY-013/known','PRY-015/PRAYER_04','PRY-015/PRAYER_07','PRY-016/subjects','PRY-016/facts'}
    result |= {f'PRY-014/{i}' for i in range(3)}
    result |= {f'PRY-REOPEN-{i:03}' for i in range(1,6)}
    result |= {f'PRY-INTEGRATION-{i:03}' for i in range(1,5)}
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--smoke',action='store_true');args=parser.parse_args()
    before=hashes()
    with tempfile.TemporaryDirectory(prefix='prayers-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary);output=scratch/'prayers.json'
        powers.fidelity.execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/prayers/integration_cases.gd','--',str(output)],ROOT/'tools/prayers/run.log',600)
        raw=json.loads(output.read_text(encoding='utf-8'));checks=raw['checks'];actual={x['id'] for x in checks};expected=expected_ids()
        if actual!=expected or len(checks)!=len(expected):raise RuntimeError(f'Missing/duplicate prayer checks: missing={expected-actual}, extra={actual-expected}')
        if raw['status']!='pass' or any(x['status']!='pass' for x in checks):raise RuntimeError('Prayer assertions failed')
        if before!=hashes():raise RuntimeError('Sources changed during specialty run')
        if args.smoke:print(f'SMOKE {len(checks)} checks; no formal evidence written');return 0
        target=ROOT/'docs/qa/powers-results.json';previous=target.stat().st_mtime_ns
        powers.fidelity.execute([sys.executable,'-X','utf8','tools/powers/verify.py','--godot',args.godot],ROOT/'tools/prayers/regressions.log',3000)
        if target.stat().st_mtime_ns==previous:raise RuntimeError('No fresh powers regression report')
        regression=json.loads(target.read_text(encoding='utf-8'))
        if regression['status']!='pass' or any(x['status']!='pass' for x in regression['checks']):raise RuntimeError('Powers regression failed')
        if before!=hashes():raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':'docs/qa/powers-results.json','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'powersChecks':len(regression['checks']),**{k:v for k,v in regression['regressions'].items() if k.endswith('Checks')}},'limitations':['特殊初始亲属、契约、病危、证据等是明确有版本/对象/前因的既存处境夹具；实际候选/回应/危机后果均由生产Prayers和共享World提交。','完整事件池及其来源生产、EVENT_12B当轮重开事件消费者、八蓝本制度证明和终局封存仍由EVENTS/ANCHORS/ENDINGS原任务验收。','无游戏内UI；完整策略平衡、叙事体验和发行目标平台性能/耐久性仍按原任务。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realPowersCultFidelityAndNineRegressions':True}}
        (ROOT/'docs/qa/prayers-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 正式祈求与危机验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'','真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers，正式CSV与固定来源/主体/原危机。执行协议见[tools/prayers](../../tools/prayers/README.md)。','']
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        total=len(regression['checks'])+sum(v for k,v in regression['regressions'].items() if k.endswith('Checks'))
        lines += ['',f"关联{total}项检查实际重跑；来源与父报告SHA见[机器证据](prayers-results.json)。",'']+['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/prayers.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} prayer checks and {total} actual registered regressions')
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:print('FAIL:',error,file=sys.stderr);raise SystemExit(1)
