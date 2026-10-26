#!/usr/bin/env python3
"""Real pre-index/current Godot differential replay and indexed-history adversaries."""
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
BASELINE = "528e3e4871ae783f8bed84e265d2720041d89289"
REPORT = ROOT / "docs/qa/history-index-results.json"


def sources() -> list[Path]:
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", ROOT / "docs/gdd-core.md",
                   ROOT / "docs/tasks/slice-04.md", ROOT / "docs/implementation/simulation-fidelity-plan.md",
                   *ROOT.glob("src/game/*.gd"), *ROOT.glob("src/simulation/*.gd"),
                   *ROOT.glob("docs/specs/system-*.md"), *ROOT.glob("data/*.csv"),
                   *ROOT.glob("tools/history-index/*.gd"), ROOT / "tools/incremental-tx/replay.gd",
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
    lines = ["# 有效决策投影与历史索引实测", "", f"执行时间：{report['generatedAt']}。全详细参考模式。", "",
             f"旧版基线 `{BASELINE}` 从 Git 实际导出；两版本使用同一驱动、两种子各 12 轮，"
             "逐请求比较世界各字段、事实、费用、随机、统计、上下文和响应。新版本也实际载入旧版阶段四存档后继续。", "",
             "## 检查", ""]
    lines.extend(f"- `{check['id']}`：{check['name']}（{check['status']}）。" for check in report["checks"])
    lines += ["", "## 成本与范围", "",
              "追加无关历史的成对场景先执行完整初始校验和投影构建，再清零普通操作计量。"
              "报告分别记录当前对象/有效来源、冷历史根和完整审计；不把初始化成本混入普通决策，也不将其隐藏。",
              "历史事实、人物见闻、成长/消费来源、旧回执及死亡身份仍完整保留。"
              "增长型根与增量保存另由archive-save专项验证；完整导出、读档审计仍随历史增长。",
              "索引不意味着概略模拟、注意力预算、完整玩法或长战役最终性能已完成。"
              "有效活来源实际增加时允许必要工作增加；不能把分页上限解释成截断全部合法候选。", ""]
    indexed = {check["id"]: check for check in report["checks"]}
    pair = indexed["HIST-002"]["details"]
    small, large = pair["small"], pair["large"]
    lines += ["## 实际操作计量", "",
              f"阶段四在原场景／追加历史场景中，有效来源读取为 {small['evolution']['decision_reads']}／{large['evolution']['decision_reads']}，"
              f"当前对象复制为 {small['evolution']['copied_current_objects']}／{large['evolution']['copied_current_objects']}；"
              "两场景普通决策、预览、行动和阶段四的完整历史扫描、重建与历史值深复制计数均为零。", "",
              f"持久树路径读取仍由 {small['evolution']['tree_nodes_read']} 增至 {large['evolution']['tree_nodes_read']}；"
              f"根身份条目核对为 {small['evolution']['root_identity_entries']}／{large['evolution']['root_identity_entries']}，"
              f"事务原生历史根浅复制条目为 {small['evolutionTransaction']['history_root_entries']}／{large['evolutionTransaction']['history_root_entries']}。"
              "这是当前实现的有序树路径与根处理实测，不能将本报告解读为总耗时与历史长度无关。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    before = hashes()
    try:
        archive = subprocess.run(["git", "archive", BASELINE], cwd=ROOT, capture_output=True, check=True).stdout
        with tempfile.TemporaryDirectory(prefix="cthulhu-history-") as temp:
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
            adversaries = execute(args.godot, ROOT, "history-index/run.gd", scratch / "adversaries.json")
            policy_root = scratch / "policy-project"
            policy_root.mkdir()
            shutil.copy2(ROOT / "project.godot", policy_root / "project.godot")
            for directory in ("src", "data"):
                shutil.copytree(ROOT / directory, policy_root / directory)
            probe_path = policy_root / "tools/history-index"
            probe_path.mkdir(parents=True)
            shutil.copy2(ROOT / "tools/history-index/policy_probe.gd", probe_path / "policy_probe.gd")
            (policy_root / "history-policy-scratch-only").write_text("Disposable QA fixture; authored project CSV is never modified.\n")
            policy_probe = execute(args.godot, policy_root, "history-index/policy_probe.gd", scratch / "policy-probe.json")
            boundary = next(item for item in adversaries["checks"] if item["id"] == "HIST-012")
            boundary["details"]["isolatedPolicyFailure"] = policy_probe
            boundary["name"] += "；坏查询策略拒绝恢复且不替换现有会话"
            checks = [{"id": "HIST-001", "name": "真实改造前版本与当前索引实现逐请求语义一致，旧档续跑一致",
                       "status": "pass" if not differences else "fail", "details": {"checkpoints": len(reference["trace"]), "differences": differences[:20], "differenceCount": len(differences)}}] + adversaries["checks"]
            ids = [entry["id"] for entry in checks]
            if len(ids) != len(set(ids)) or set(ids) != {f"HIST-{number:03d}" for number in range(1, 21)}:
                raise RuntimeError("Missing, invalid or duplicate history check IDs")
            after = hashes()
            if before != after:
                raise RuntimeError("Sources changed during execution; rerun against frozen sources")
            passed = all(entry["status"] == "pass" for entry in checks)
            report = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
                      "engine": current["engine"], "checks": checks, "sourceHashes": after,
                      "executionProfile": {"mode": "all-detailed-reference", "hybridImplemented": False},
                      "baseline": {"revision": BASELINE, "archiveSha256": hashlib.sha256(archive).hexdigest(),
                                   "driverSha256": after["tools/incremental-tx/replay.gd"]},
                      "differential": {"checkpoints": len(reference["trace"]), "seeds": [7919, 1981],
                                       "turnsPerSeed": 12, "differenceCount": len(differences), "realLegacyCheckpointResumed": True,
                                       "referenceTraceSha256": hashlib.sha256(json.dumps(reference["trace"], sort_keys=True).encode()).hexdigest(),
                                       "currentTraceSha256": hashlib.sha256(json.dumps(current["trace"], sort_keys=True).encode()).hexdigest()},
                      "wrapperVerified": {"freshTemporaryReports": True, "sameDriverBothVersions": True,
                                          "sourcesUnchangedDuringRun": True, "noGodotErrors": True, "uniqueCheckIds": True}}
            REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            (ROOT / "docs/qa/history-index.md").write_text(readable(report))
            print(f"{'VERIFIED' if passed else 'FAILED'} {len(checks)} history checks; {len(after)} source hashes")
            return 0 if passed else 1
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
