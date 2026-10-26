#!/usr/bin/env python3
"""Run the registered hybrid workload and real regression suites; never rebind old results."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / 'docs/qa/fidelity-results.json'
SUITES = ['fidelity-rules','formal-simulation','turn-cycle','economy','incremental-tx','history-index','archive-save','abstract-sim','attention']
REPORTS = {'formal-simulation':'formal-simulation', 'turn-cycle':'turn-cycle', **{x:x for x in SUITES if x not in ['formal-simulation','turn-cycle']}}

def hashes():
    paths = {ROOT/'project.godot', ROOT/'docs/architecture.md', ROOT/'docs/gdd-core.md', ROOT/'docs/tasks/slice-04.md', ROOT/'docs/implementation/simulation-fidelity-plan.md', ROOT/'tools/fidelity/README.md'}
    for pattern in ['src/game/*.gd','src/simulation/*.gd','data/*.csv','docs/specs/system-*.md','tools/fidelity/*.py','tools/fidelity/*.gd']:
        paths.update(ROOT.glob(pattern))
    for suite in SUITES:
        paths.update((ROOT/'tools'/suite).glob('*.gd'))
        paths.update((ROOT/'tools'/suite).glob('*.py'))
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}

def execute(command, log_path, timeout=900):
    env = os.environ.copy(); env['PYTHONUTF8']='1'; env['PYTHONIOENCODING']='utf-8'
    result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',env=env,timeout=timeout)
    log = result.stdout + result.stderr
    log_path.write_text(log,encoding='utf-8',newline='\n')
    print(log[-3000:],flush=True)
    if result.returncode or 'SCRIPT ERROR:' in log or 'ERROR:' in log:
        raise RuntimeError(f'Execution failed: {command}; see {log_path}')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    args=parser.parse_args()
    before=hashes()
    checks=[]; regressions=[]
    with tempfile.TemporaryDirectory(prefix='fidelity-',dir=ROOT/'.godot') as temporary:
        scratch=Path(temporary)
        output=scratch/'hybrid.json'
        execute([args.godot,'--headless','--path',str(ROOT),'--log-file',str(scratch/'godot.log'),'--script','res://tools/fidelity/run.gd','--',str(output)], ROOT/'tools/fidelity/run.log')
        raw=json.loads(output.read_text(encoding='utf-8'))
        checks=raw['checks']
        expected={f'FID-{i:03d}' for i in range(1,16)}|{f'FID-LONG-{i}' for i in [7919,1981,104729]}
        if {c['id'] for c in checks}!=expected or len(checks)!=len(expected): raise RuntimeError('Missing or duplicate integration checks')
        if raw['status']!='pass' or any(c['status']!='pass' for c in checks): raise RuntimeError('Hybrid assertions failed')
        for suite in SUITES:
            target=ROOT/'docs/qa'/f'{REPORTS[suite]}-results.json'
            old=target.stat().st_mtime_ns if target.exists() else -1
            command=[sys.executable,'-X','utf8',f'tools/{suite}/verify.py']
            if suite!='fidelity-rules': command+=['--godot',args.godot]
            print('RUN REGRESSION',suite,flush=True)
            execute(command,ROOT/'tools/fidelity'/f'{suite}.log')
            if not target.exists() or target.stat().st_mtime_ns==old: raise RuntimeError(f'No fresh {suite} evidence')
            evidence=json.loads(target.read_text(encoding='utf-8'))
            if evidence.get('status', 'pass')!='pass' or any(c['status']!='pass' for c in evidence['checks']): raise RuntimeError(f'{suite} failed')
            regressions.append({'suite':suite,'report':target.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'checks':len(evidence['checks']),'generatedAt':evidence['generatedAt']})
        if hashes()!=before: raise RuntimeError('Sources changed during execution; rerun frozen sources')
        checks.append({'id':'FID-REGRESSION','name':'真实旧性质与分层反例重跑，不以旧报告指纹刷新替代','status':'pass','details':regressions})
        report={**raw,'checks':checks,'sourceHashes':before,'generatedAt':datetime.now(timezone.utc).isoformat(),'environment':{'engine':raw['engine'],'platform':platform.platform(),'processor':platform.processor(),'python':platform.python_version(),'headless':True},'regressions':regressions,'executionProfile':{'mode':'real-generate-hybrid','completeDownstreamBusiness':False},'wrapperVerified':{'freshTemporaryReport':True,'sourcesUnchangedDuringRun':True,'uniqueCheckIds':True,'noGodotErrors':True,'realRegressions':True},'limitations':['上游神迹/建团授权/未来工作是合约夹具，不代表完整CULTS/POWERS/PRAYERS/EVENTS。','复制载荷字节是非共享当前记录的Variant编码计量，非堆分配字节或全部复制。','K仍有保守复制/校验成本；H冷档案、完整导出与恢复继续增长。','本机工程预算不替代发行平台断电、性能、完整业务平衡与真人体验。']}
        REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        lines=['# 混合集成与负载验收','',f"执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。",'', '真实generate_hybrid、正式CSV与六阶段/Economy；预算及复制计量口径见[执行协议](../../tools/fidelity/README.md)。', '', '## 检查','']
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        lines += ['','## 独立负载结果','','| 样本 | K / F / Q | 详细更新 | 回合或阶段3–6 ms | 当前复制载荷 bytes | 增量保存 bytes |','|---|---|---:|---:|---:|---:|']
        for sample in raw['samples']:
            if 'label' in sample: lines.append(f"| {sample['label']} | {sample['K']} / {sample['F']} / {sample['Q']} | {sample['updates']} | {sample['ms']:.3f} | {sample['copied_current_payload_bytes']} | {sample['delta']['bytes_written']} |")
            else: lines.append(f"| seed {sample['seed']} ×60 | 实际逐窗见JSON | {sample['stats']['npc_updates']} | p95 {sample['turn_ms']['p95']:.3f}, max {sample['turn_ms']['max']:.3f} | 未在长局启用字节探针 | 首存 {sample['save']['initial']['bytes_written']} |")
        lines += ['',f"Godot静态内存峰值：{raw['memory_static_peak']} bytes。保存/完整导出/恢复和每阶段明细见[机器证据](fidelity-results.json)。",'', '## 实际修复与边界','','普通主体或嵌套检定中的未来任务必须先持久预留，不能在行动完成时释放仍被承诺的容量。独立审查及新增反例见[fidelity-review.md](fidelity-review.md)。','']
        lines += ['- '+x for x in report['limitations']]
        (ROOT/'docs/qa/fidelity.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
        print(f"VERIFIED {len(checks)} fidelity checks; {sum(x['checks'] for x in regressions)} actual regression checks",flush=True)
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print('FAIL:',error,file=sys.stderr); raise SystemExit(1)
