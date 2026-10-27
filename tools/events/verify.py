#!/usr/bin/env python3
"""Execute formal events and managed deadlines and the complete registered regression chain."""
from __future__ import annotations
import argparse,csv,hashlib,importlib.util,json,platform,subprocess,sys,tempfile
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('anchors_wrapper',ROOT/'tools/anchors/verify.py')
anchors=importlib.util.module_from_spec(spec);spec.loader.exec_module(anchors)

def hashes():
    result=anchors.hashes()
    for p in [ROOT/'docs/tasks/slice-09.md', ROOT/'docs/content/narrative-catalog.md', *sorted((ROOT/'tools/events').glob('*'))]:
        if p.is_file() and p.suffix in ['.gd','.py','.md']:result[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def expected_ids():
    return {f'EVENT/EVENT_{i:02d}/{option}' for i in range(1,13) for option in ['A','B']} | {f'EVENT-BLUEPRINT/CIV_{i:02d}' for i in range(1,9)} | {f'EVT-LIFE-{i:03d}' for i in range(1,13)} | {f'EVT-POOL-{i:03d}' for i in range(1,6)} | {f'EVT-REVIEW-{i:03d}' for i in range(1,10)} | {f'EVT-OPPORTUNITY/{x}' for x in ['public','wait','recover','expiry']}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--smoke',action='store_true');args=parser.parse_args()
    before=hashes()
    with tempfile.TemporaryDirectory(prefix='events-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary);output=scratch/'events.json'
        anchors.prayers.powers.fidelity.execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/events/lifecycle_cases.gd','--',str(output)],ROOT/'tools/events/run.log',600)
        raw=json.loads(output.read_text(encoding='utf-8'));checks=raw['checks'];actual={x['id'] for x in checks};expected=expected_ids()
        if actual!=expected or len(checks)!=len(expected):raise RuntimeError(f'Missing/duplicate event checks: missing={expected-actual}, extra={actual-expected}')
        if raw['status']!='pass' or any(x['status']!='pass' for x in checks):raise RuntimeError('Event assertions failed')
        if before!=hashes():raise RuntimeError('Sources changed during specialty run')
        if args.smoke:print(f'SMOKE {len(checks)} checks; no formal evidence written');return 0
        target=ROOT/'docs/qa/anchors-results.json';previous=target.stat().st_mtime_ns
        anchors.prayers.powers.fidelity.execute([sys.executable,'-X','utf8','tools/anchors/verify.py','--godot',args.godot],ROOT/'tools/events/regressions.log',3000)
        if target.stat().st_mtime_ns==previous:raise RuntimeError('No fresh anchors regression report')
        regression=json.loads(target.read_text(encoding='utf-8'))
        if regression['status']!='pass' or any(x['status']!='pass' for x in regression['checks']):raise RuntimeError('Anchors regression failed')
        if before!=hashes():raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':'docs/qa/anchors-results.json','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'anchorChecks':len(regression['checks']),**{k:v for k,v in regression['regressions'].items() if k.endswith('Checks')}}, 'limitations':['使用真实generate_hybrid与正式CSV、Prayers/Events/Anchors/World/Relics/Economy；特殊初始人物关系/既存处境为明确来源前提，不预置事件结果。','本项实现原12事件24分支及有限机会处置；首发条目扩量和叙事体验、完整抵抗/终局/UI/平衡/视听/发行仍归原任务。','到期概率身份的额外分支使用明确受限调度合同验证共同仲裁；原24事件选项确定性，不为它们增加额外骰。','不宣称本项是恒定成本、发行性能或完整游戏体验通过。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realAnchorsPrayersPowersCultFidelityAndNineRegressions':True}}
        (ROOT/'docs/qa/events-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 正式事件池与到期调度验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'','真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers/Anchors/Events，正式CSV、原对象与当前来源。执行协议见[tools/events](../../tools/events/README.md)。','']
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        total=len(regression['checks'])+sum(v for k,v in regression['regressions'].items() if k.endswith('Checks'))
        lines += ['',f"关联{total}项检查实际重跑；来源与父报告SHA见[机器证据](events-results.json)。",'']+['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/events.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} event checks and {total} actual registered regressions')
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:print('FAIL:',error,file=sys.stderr);raise SystemExit(1)
