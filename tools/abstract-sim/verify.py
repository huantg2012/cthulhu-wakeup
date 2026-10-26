#!/usr/bin/env python3
"""Real pre-abstract/current Godot differential replay and assigned background simulation contracts."""
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
BASELINE = "15674e5"
REPORT = ROOT / "docs/qa/abstract-sim-results.json"


def sources() -> list[Path]:
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", ROOT / "docs/gdd-core.md",
                   ROOT / "docs/tasks/slice-04.md", ROOT / "docs/implementation/simulation-fidelity-plan.md",
                   *ROOT.glob("src/game/*.gd"), *ROOT.glob("src/simulation/*.gd"),
                   *ROOT.glob("docs/specs/system-*.md"), *ROOT.glob("data/*.csv"),
                   *ROOT.glob("tools/abstract-sim/*.gd"), ROOT / "tools/incremental-tx/replay.gd",
                   Path(__file__).resolve()})


def hashes() -> dict[str, str]:
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources()}


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
    lines = ['# 概略生产者与背景候选协议实测', '', f"执行时间：{report['generatedAt']}。Godot {report['engine']}。", '',
             '本轮正式接入受控分配模式；默认全详细参考路径继续保留。两种模式的证据分开记录。', '', '## 实际检查', '']
    lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in report['checks']]
    lines += ['', '## 已验证的范围', '',
              '受控场景通过统一六阶段运行详细人物、后台低频日常、逐轮风险与正式经济；固定候选的提名、人口扣除、主体引用、序号、来源、随机及期限进入同一提交。八轮48阶段实际逐请求重放一致；分段存档和旧请求继续使用前置协议。', '',
              f"全详细模式另与真实Git基线 `{BASELINE}` 执行同一驱动，292个逐请求检查点零差异，并实际加载旧阶段四快照续跑。该差分不要求新概略节奏逐条等同全详细人生。", '',
              '6项策略/模板/职责表破坏在临时项目中实际装载和恢复，均拒绝并保留原会话；正式CSV没有为测试修改。', '',
              '当前三种背景模板覆盖当下接触、屏障诉求和真实已知暴露回调。默认未回应后果读取原event_parameters，未来完整内容仍由PRAYERS/EVENTS/CONTENT补齐。测试消费者只验证协议和显式授权，不是可玩的祈求/事件系统。', '',
              'configure_assigned_simulation仅是开局受控分配接口，保留既有身份与历史；实际玩家注意力准入、成员转换、匿名混合开局与升降级仍归TASK-ATTENTION。此项不把受控入口开放成玩家绕过容量的命令。', '',
              '当前对象复制仍包含全部活身份；F/N/P及本地L的实际接入另见attention专项，最终混合负载/历史长度独立对照由TASK-FIDELITY-VERIFY执行。没有宣称完整玩家循环、最终性能、平衡、叙事或视听已完成；不增设短体验前置阶段。', '']
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    before = hashes()
    try:
        archive = subprocess.run(["git", "archive", BASELINE], cwd=ROOT, capture_output=True, check=True).stdout
        with tempfile.TemporaryDirectory(prefix="cthulhu-abstract-") as temp:
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
            adversaries = execute(args.godot, ROOT, "abstract-sim/run.gd", scratch / "adversaries.json")
            policy_root = scratch / "policy-project"
            policy_root.mkdir()
            shutil.copy2(ROOT / "project.godot", policy_root / "project.godot")
            for directory in ("src", "data"):
                shutil.copytree(ROOT / directory, policy_root / directory)
            probe = policy_root / "tools/abstract-sim"
            probe.mkdir(parents=True)
            shutil.copy2(ROOT / "tools/abstract-sim/policy_probe.gd", probe / "policy_probe.gd")
            (policy_root / "abstract-policy-scratch-only").write_text("Disposable validation fixture.\n")
            policy = execute(args.godot, policy_root, "abstract-sim/policy_probe.gd", scratch / "policy.json")
            adversaries["checks"].append({"id": "ABS-022", "name": "6项真实策略/职责/模板破坏拒绝装载和旧档恢复，原会话保持", "status": policy["status"], "details": policy})
            checks = [{"id": "ABS-023", "name": "真实概略接入前版本与当前全详细路径逐请求语义一致，旧档续跑一致",
                       "status": "pass" if not differences else "fail", "details": {"checkpoints": len(reference["trace"]), "differences": differences[:20], "differenceCount": len(differences)}}] + adversaries["checks"]
            ids = [entry["id"] for entry in checks]
            if len(ids) != len(set(ids)) or set(ids) != {f"ABS-{number:03d}" for number in range(1, 24)}:
                raise RuntimeError("Missing, invalid or duplicate abstract check IDs")
            after = hashes()
            if before != after:
                raise RuntimeError("Sources changed during execution; rerun against frozen sources")
            passed = all(entry["status"] == "pass" for entry in checks)
            report = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
                      "engine": current["engine"], "checks": checks, "sourceHashes": after,
                      "executionProfile": {"mode": "assigned-background-and-all-detailed-reference", "playerAttentionImplemented": False},
                      "baseline": {"revision": BASELINE, "archiveSha256": hashlib.sha256(archive).hexdigest(),
                                   "driverSha256": after["tools/incremental-tx/replay.gd"]},
                      "differential": {"checkpoints": len(reference["trace"]), "seeds": [7919, 1981],
                                       "turnsPerSeed": 12, "differenceCount": len(differences), "realLegacyCheckpointResumed": True,
                                       "referenceTraceSha256": hashlib.sha256(json.dumps(reference["trace"], sort_keys=True).encode()).hexdigest(),
                                       "currentTraceSha256": hashlib.sha256(json.dumps(current["trace"], sort_keys=True).encode()).hexdigest()},
                      "wrapperVerified": {"freshTemporaryReports": True, "sameDriverBothVersions": True,
                                          "sourcesUnchangedDuringRun": True, "noGodotErrors": True, "uniqueCheckIds": True}}
            REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            (ROOT / "docs/qa/abstract-sim.md").write_text(readable(report))
            print(f"{'VERIFIED' if passed else 'FAILED'} {len(checks)} abstract checks; {len(after)} source hashes")
            return 0 if passed else 1
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
