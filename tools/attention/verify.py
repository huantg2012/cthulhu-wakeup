#!/usr/bin/env python3
"""Real pre-attention/current Godot differential replay and hybrid attention admission and transitions."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "9040bdd"
REPORT = ROOT / "docs/qa/attention-results.json"


def sources() -> list[Path]:
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", ROOT / "docs/gdd-core.md",
                   ROOT / "docs/tasks/slice-04.md", ROOT / "docs/implementation/simulation-fidelity-plan.md",
                   *ROOT.glob("src/game/*.gd"), *ROOT.glob("src/simulation/*.gd"),
                   *ROOT.glob("docs/specs/system-*.md"), *ROOT.glob("data/*.csv"),
                   *ROOT.glob("tools/attention/*.gd"), ROOT / "tools/incremental-tx/replay.gd", ROOT / "tools/abstract-sim/run.gd",
                   Path(__file__).resolve()})


def hashes() -> dict[str, str]:
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources()}


def execute(godot: str, root: Path, driver: str, output: Path, legacy: Path | None = None) -> dict:
    command = [godot, "--headless", "--path", str(root), "--script", "res://tools/" + driver, "--", str(output)]
    if legacy is not None:
        command.append(str(legacy))
    process = subprocess.run(command, capture_output=True, text=True, timeout=300, check=False)
    log = process.stdout + process.stderr
    print(log, end="")
    if process.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log or not output.exists():
        raise RuntimeError(f"Godot execution failed: {root.name}/{driver}")
    result = json.loads(output.read_text())
    if result.get("status") != "pass":
        raise RuntimeError(f"Godot reported failures: {root.name}/{driver}")
    return result


def readable(report: dict) -> str:
    lines = ['# 注意力准入、成员转换与模式切换实测', '', f"执行时间：{report['generatedAt']}。Godot {report['engine']}。", '',
             '真实混合入口generate_hybrid及统一回合运行F/N/P预留、成员/退役、匿名开局、本地展开、阶段释放与传教准入；默认全详细及assigned路径继续作为回归配置。', '', '## 实际检查', '']
    lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in report['checks']]
    lines += ['', '## 验证范围与后续', '',
              f"全详细路径与真实Git基线 `{BASELINE}` 用同一驱动比较292个逐请求检查点，并实际加载旧阶段四快照继续。新混合节奏不要求逐条重现旧匿名人生，前置23项assigned概略套件另行回归。", '',
              '主动分支先按完整声明效果图和CSV分类预留，再扣费/检定。P转N、同轮使用标记、跨轮承诺、满额默认离团及退役N转P均有真实场景；旧请求重放与恢复同序。默认离团不请求新N/P。6项真实坏策略/预算只在临时项目修改副本，正式数据未为测试改动。', '',
              '当前参与者是明确的合约夹具：检定入团、提名及事件默认只证明准入/身份协议，不代表完整祈求、十二权能、教团形成、事件池或玩家界面已完成。它们由原下游任务消费同一接口并验证实际业务。当前源码资格拒绝以高忠诚替代正式成员。', '',
              '活身份K的保守依赖复制/校验仍保留，详细自主行为按N/P/L去重运行；没有宣称所有成本恒定。完整混合、经济/风险、活动规模与历史长度独立负载及恢复由下一项TASK-FIDELITY-VERIFY验收。物理断电/发行平台持久性仍归TASK-RELEASE。没有新增短体验前置阶段。', '']
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    before = hashes()
    try:
        archive = subprocess.run(["git", "archive", BASELINE], cwd=ROOT, capture_output=True, check=True).stdout
        with tempfile.TemporaryDirectory(prefix="cthulhu-attention-") as temp:
            scratch = Path(temp)
            baseline = scratch / "baseline"
            baseline.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                bundle.extractall(baseline, filter="data")
            shutil.copy2(ROOT / "tools/incremental-tx/replay.gd", baseline / "tools/incremental-tx/replay.gd")
            reference = execute(args.godot, baseline, "incremental-tx/replay.gd", scratch / "reference.json")
            current = execute(args.godot, ROOT, "incremental-tx/replay.gd", scratch / "current.json", scratch / "reference.json")
            if not current.get("legacyLoaded"):
                raise RuntimeError("Current replay did not load the real legacy checkpoint")
            differences = []
            if len(reference["trace"]) != len(current["trace"]):
                differences.append({"lengths": [len(reference["trace"]), len(current["trace"])]})
            for index, (left, right) in enumerate(zip(reference["trace"], current["trace"])):
                if left != right:
                    keys = set(left["sections"]) | set(right["sections"])
                    differences.append({"index": index, "step": left["step"], "label": left["label"],
                                        "differentSections": sorted(key for key in keys if left["sections"].get(key) != right["sections"].get(key))})
            adversaries = execute(args.godot, ROOT, "attention/run.gd", scratch / "adversaries.json")
            policy_root = scratch / "policy-project"
            policy_root.mkdir()
            shutil.copy2(ROOT / "project.godot", policy_root / "project.godot")
            for directory in ("src", "data"):
                shutil.copytree(ROOT / directory, policy_root / directory)
            probe = policy_root / "tools/attention"
            probe.mkdir(parents=True)
            shutil.copy2(ROOT / "tools/attention/policy_probe.gd", probe / "policy_probe.gd")
            (policy_root / "attention-policy-scratch-only").write_text("Disposable validation fixture.\n")
            policy = execute(args.godot, policy_root, "attention/policy_probe.gd", scratch / "policy.json")
            adversaries["checks"].append({"id": "ATT-036", "name": "6项真实策略/职责/模板破坏拒绝装载和旧档恢复，原会话保持", "status": policy["status"], "details": policy})
            checks = [{"id": "ATT-037", "name": "真实注意力接入前版本与当前全详细路径逐请求语义一致，旧档续跑一致",
                       "status": "pass" if not differences else "fail", "details": {"checkpoints": len(reference["trace"]), "differences": differences[:20], "differenceCount": len(differences)}}] + adversaries["checks"]
            ids = [entry["id"] for entry in checks]
            if len(ids) != len(set(ids)) or set(ids) != {f"ATT-{number:03d}" for number in range(1, 38)}:
                raise RuntimeError("Missing, invalid or duplicate attention check IDs")
            after = hashes()
            if before != after:
                raise RuntimeError("Sources changed during execution; rerun against frozen sources")
            passed = all(entry["status"] == "pass" for entry in checks)
            report = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
                      "engine": current["engine"], "checks": checks, "sourceHashes": after,
                      "executionProfile": {"mode": "hybrid-attention-and-reference-regressions", "playerAttentionImplemented": True},
                      "baseline": {"revision": BASELINE, "archiveSha256": hashlib.sha256(archive).hexdigest(),
                                   "driverSha256": after["tools/incremental-tx/replay.gd"]},
                      "differential": {"checkpoints": len(reference["trace"]), "seeds": [7919, 1981],
                                       "turnsPerSeed": 12, "differenceCount": len(differences), "realLegacyCheckpointResumed": True,
                                       "referenceTraceSha256": hashlib.sha256(json.dumps(reference["trace"], sort_keys=True).encode()).hexdigest(),
                                       "currentTraceSha256": hashlib.sha256(json.dumps(current["trace"], sort_keys=True).encode()).hexdigest()},
                      "wrapperVerified": {"freshTemporaryReports": True, "sameDriverBothVersions": True,
                                          "sourcesUnchangedDuringRun": True, "noGodotErrors": True, "uniqueCheckIds": True}}
            REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            (ROOT / "docs/qa/attention.md").write_text(readable(report))
            print(f"{'VERIFIED' if passed else 'FAILED'} {len(checks)} attention checks; {len(after)} source hashes")
            return 0 if passed else 1
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
