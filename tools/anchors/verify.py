#!/usr/bin/env python3
"""Execute formal institutional anchors and the complete registered regression chain."""
from __future__ import annotations
import argparse,csv,hashlib,importlib.util,json,platform,subprocess,sys,tempfile
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prayers_wrapper',ROOT/'tools/prayers/verify.py')
prayers=importlib.util.module_from_spec(spec);spec.loader.exec_module(prayers)

def hashes():
    result=prayers.hashes()
    for p in [ROOT/'docs/tasks/slice-08.md', ROOT/'docs/content/narrative-catalog.md', *sorted((ROOT/'tools/anchors').glob('*'))]:
        if p.is_file() and p.suffix in ['.gd','.py','.md']:result[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def expected_ids():
    return {f'ANC-{kind}/CIV_{i:02d}' for kind in ['PROFILE','BUILD','CONTRACT','CONDITION','ADMISSION'] for i in range(1,9)} | {f'ANC-OUTCOME/{outcome}' for outcome in ['deep','success','failure','disaster']} | {'ANC-SUCCESSOR','ANC-LATE-KNOWLEDGE','ANC-RESTRICTION'} | {f'ANC-LIFE-{i:03d}' for i in range(1,17)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--smoke',action='store_true');args=parser.parse_args()
    before=hashes()
    with tempfile.TemporaryDirectory(prefix='anchors-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary);output=scratch/'anchors.json'
        prayers.powers.fidelity.execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/anchors/lifecycle_cases.gd','--',str(output)],ROOT/'tools/anchors/run.log',600)
        raw=json.loads(output.read_text(encoding='utf-8'));checks=raw['checks'];actual={x['id'] for x in checks};expected=expected_ids()
        if actual!=expected or len(checks)!=len(expected):raise RuntimeError(f'Missing/duplicate anchor checks: missing={expected-actual}, extra={actual-expected}')
        if raw['status']!='pass' or any(x['status']!='pass' for x in checks):raise RuntimeError('Anchor assertions failed')
        if before!=hashes():raise RuntimeError('Sources changed during specialty run')
        if args.smoke:print(f'SMOKE {len(checks)} checks; no formal evidence written');return 0
        target=ROOT/'docs/qa/prayers-results.json';previous=target.stat().st_mtime_ns
        prayers.powers.fidelity.execute([sys.executable,'-X','utf8','tools/prayers/verify.py','--godot',args.godot],ROOT/'tools/anchors/regressions.log',3000)
        if target.stat().st_mtime_ns==previous:raise RuntimeError('No fresh prayers regression report')
        regression=json.loads(target.read_text(encoding='utf-8'))
        if regression['status']!='pass' or any(x['status']!='pass' for x in regression['checks']):raise RuntimeError('Prayers regression failed')
        if before!=hashes():raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':'docs/qa/prayers-results.json','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'prayerChecks':len(regression['checks']),**{k:v for k,v in regression['regressions'].items() if k.endswith('Checks')}}, 'limitations':['真实制度资格与Powers创建修复/Relics绑定/Economy供奉均由生产代码执行；特殊初始关系/证据根与未实施EVENTS结果是明确有源合同夹具。','本项提供首次制度承认的锚定前有限唯一遗物机会；完整事件池、选项/回收处置、抵抗整合及终局/封存仍沿EVENTS/RESISTANCE/ENDINGS。','无游戏内UI；完整策略平衡、叙事体验及发行平台可靠性/性能仍由原任务。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realPrayersPowersCultFidelityAndNineRegressions':True}}
        (ROOT/'docs/qa/anchors-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 完整机构锚点验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'','真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers/Anchors，正式CSV与固定机构/当前证据/人物/媒介。执行协议见[tools/anchors](../../tools/anchors/README.md)。','']
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        total=len(regression['checks'])+sum(v for k,v in regression['regressions'].items() if k.endswith('Checks'))
        lines += ['',f"关联{total}项检查实际重跑；来源与父报告SHA见[机器证据](anchors-results.json)。",'']+['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/anchors.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} anchor checks and {total} actual registered regressions')
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:print('FAIL:',error,file=sys.stderr);raise SystemExit(1)
