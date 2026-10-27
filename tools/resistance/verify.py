#!/usr/bin/env python3
"""Execute formal resistance and cross-domain propagation and the complete registered regression chain."""
from __future__ import annotations
import argparse,csv,hashlib,importlib.util,json,platform,subprocess,sys,tempfile
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('events_wrapper',ROOT/'tools/events/verify.py')
events=importlib.util.module_from_spec(spec);spec.loader.exec_module(events)

def hashes():
    result=events.hashes()
    for p in [ROOT/'docs/tasks/slice-10.md', ROOT/'docs/content/narrative-catalog.md', *sorted((ROOT/'tools/resistance').glob('*'))]:
        if p.is_file() and p.suffix in ['.gd','.py','.md']:result[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def expected_ids():
    return {f'RES/{rule}/{mode}' for rule in ['RESIST_TRACE','RESIST_PURGE','RESIST_SEIZE','RESIST_REPAIR','RESIST_ERASE'] for mode in ['resolve','cancel']} | {'RES/RESIST_REWRITE/resolve'} | {f'RES-LIFE-{i:03d}' for i in range(1,5)} | {f'RES-PROP-{i:03d}' for i in range(1,4)} | {f'RES-REVIEW-{i:03d}' for i in range(1,5)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--smoke',action='store_true');args=parser.parse_args()
    before=hashes()
    with tempfile.TemporaryDirectory(prefix='resistance-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary);output=scratch/'resistance.json'
        events.anchors.prayers.powers.fidelity.execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/resistance/review_cases.gd','--',str(output)],ROOT/'tools/resistance/run.log',600)
        raw=json.loads(output.read_text(encoding='utf-8'));checks=raw['checks'];actual={x['id'] for x in checks};expected=expected_ids()
        if actual!=expected or len(checks)!=len(expected):raise RuntimeError(f'Missing/duplicate resistance checks: missing={expected-actual}, extra={actual-expected}')
        if raw['status']!='pass' or any(x['status']!='pass' for x in checks):raise RuntimeError('Resistance assertions failed')
        if before!=hashes():raise RuntimeError('Sources changed during specialty run')
        if args.smoke:print(f'SMOKE {len(checks)} checks; no formal evidence written');return 0
        target=ROOT/'docs/qa/events-results.json';previous=target.stat().st_mtime_ns
        events.anchors.prayers.powers.fidelity.execute([sys.executable,'-X','utf8','tools/events/verify.py','--godot',args.godot],ROOT/'tools/resistance/regressions.log',3000)
        if target.stat().st_mtime_ns==previous:raise RuntimeError('No fresh events regression report')
        regression=json.loads(target.read_text(encoding='utf-8'))
        if regression['status']!='pass' or any(x['status']!='pass' for x in regression['checks']):raise RuntimeError('Events regression failed')
        if before!=hashes():raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':'docs/qa/events-results.json','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'eventChecks':len(regression['checks']),**{k:v for k,v in regression['regressions'].items() if k.endswith('Checks')}}, 'limitations':['既存中局人物/教团/锚点与已确认证据是明确初始夹具；预告、到期、失效、损害和迁引均由生产代码实际运行。','修正现实例外通过正式祈求/事件生产；迁引沿现有POWER_TRANSFER，不新增自动跨域污染。','不宣称真人策略/叙事/UI/发行性能或平衡通过。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realEventsAnchorsPrayersPowersCultFidelityAndNineRegressions':True}}
        (ROOT/'docs/qa/resistance-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 正式抵抗与跨域传播验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'','真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers/Anchors/Events，正式CSV、原对象与当前来源。执行协议见[tools/resistance](../../tools/resistance/README.md)。','']
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        total=len(regression['checks'])+sum(v for k,v in regression['regressions'].items() if k.endswith('Checks'))
        lines += ['',f"关联{total}项检查实际重跑；来源与父报告SHA见[机器证据](resistance-results.json)。",'']+['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/resistance.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} resistance checks and {total} actual registered regressions')
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as error:print('FAIL:',error,file=sys.stderr);raise SystemExit(1)
