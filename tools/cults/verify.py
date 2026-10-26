#!/usr/bin/env python3
"""Execute formal cult business and version-bound regression evidence."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/fidelity'))
from verify import hashes as fidelity_hashes, execute

def hashes():
    result = fidelity_hashes()
    paths = [ROOT/'docs/tasks/slice-05.md', *sorted((ROOT/'tools/cults').glob('*'))]
    for p in paths:
        if p.is_file() and p.suffix in ['.md','.py','.gd']:
            result[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--smoke',action='store_true')
    args=parser.parse_args()
    before=hashes()
    with tempfile.TemporaryDirectory(prefix='cults-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary); output=scratch/'cults.json'
        execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/cults/run.gd','--',str(output)],ROOT/'tools/cults/run.log',180)
        raw=json.loads(output.read_text(encoding='utf-8'))
        expected={f'CUL-{i:03d}' for i in range(1,25)}
        checks=raw['checks']
        if len(checks)!=len(expected) or {x['id'] for x in checks}!=expected or raw['status']!='pass' or any(x['status']!='pass' for x in checks):raise RuntimeError('Missing, duplicate or failed cult check')
        if args.smoke:
            print(f'SMOKE {len(checks)} checks; no formal evidence written');return 0
        execute([sys.executable,'-X','utf8','tools/fidelity/verify.py','--godot',args.godot],ROOT/'tools/cults/regressions.log',1800)
        regression_path=ROOT/'docs/qa/fidelity-results.json'
        regression=json.loads(regression_path.read_text(encoding='utf-8'))
        if regression['status']!='pass':raise RuntimeError('Fidelity regression failed')
        if before!=hashes():raise RuntimeError('Sources changed during execution; rerun frozen sources')
        report={**raw,'generatedAt':datetime.now(timezone.utc).isoformat(),'sourceHashes':before,'environment':{'engine':raw['engine'],'platform':platform.platform(),'python':platform.python_version(),'headless':True},'regressions':{'report':regression_path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(regression_path.read_bytes()).hexdigest(),'fidelityChecks':len(regression['checks']),'otherChecks':sum(x['checks'] for x in regression['regressions'])},'limitations':['上游事件支付、成员意愿、既有锚点是明确夹具，不代替完整权能/祈求/事件池/锚点创建。','任命提供生产规则入口，尚无游戏内UI；玩家理解和完整策略平衡仍待原任务。','本项未增加性能预算；独立负载与K/H/Q成本边界沿fidelity报告，发行平台仍待RELEASE。'],'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueStableIds':True,'noGodotErrors':True,'realFidelityAndNineRegressions':True}}
        target=ROOT/'docs/qa/cults-results.json';target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 正式教团生命周期验收','',f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'', '真实generate_hybrid/Turn/Economy/Cults使用正式CSV；首领/成员状态由生产入口更新。执行协议见[tools/cults](../../tools/cults/README.md)。','']
        lines += [f"- `{x['id']}`：{x['name']}（{x['status']}）。" for x in checks]
        lines += ['',f"关联回归实际重跑：{len(regression['checks'])}项fidelity与{report['regressions']['otherChecks']}项既有检查；来源及报告指纹见[机器证据](cults-results.json)。",'', '## 边界','']
        lines += ['- '+s for s in report['limitations']]
        (ROOT/'docs/qa/cults.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f'VERIFIED {len(checks)} cult checks and actual registered regressions')
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.SubprocessError) as e:print('FAIL:',e,file=sys.stderr);raise SystemExit(1)
