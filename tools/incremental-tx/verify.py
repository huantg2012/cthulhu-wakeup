#!/usr/bin/env python3
"""Compare real pre-refactor Godot replay with current code; run transaction adversaries."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "bdc31eb56c5551333db364da9fd654c9fae746b7"
REPORT = ROOT / "docs/qa/incremental-tx-results.json"


def sources() -> list[Path]:
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", ROOT / "docs/gdd-core.md",
                   ROOT / "docs/tasks/slice-04.md",
                   ROOT / "docs/implementation/simulation-fidelity-plan.md",
                   *ROOT.glob("src/game/*.gd"), *ROOT.glob("src/simulation/*.gd"),
                   *ROOT.glob("docs/specs/system-*.md"), *ROOT.glob("data/*.csv"),
                   *ROOT.glob("tools/incremental-tx/*.gd"), Path(__file__).resolve()})


def hashes() -> dict[str, str]:
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sources()}


def execute(godot: str, root: Path, driver: str, output: Path, legacy: Path | None = None) -> tuple[dict, float]:
    start = time.monotonic()
    command = [godot, "--headless", "--path", str(root), "--script",
               "res://tools/incremental-tx/" + driver, "--", str(output)]
    if legacy is not None:
        command.append(str(legacy))
    process = subprocess.run(command,
                             capture_output=True, text=True, timeout=240, check=False)
    log = process.stdout + process.stderr
    print(log, end="")
    if process.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log or not output.exists():
        raise RuntimeError(f"Godot execution failed: {root.name}/{driver}")
    result = json.loads(output.read_text())
    if result.get("status") != "pass":
        raise RuntimeError(f"Godot reported failures: {root.name}/{driver}")
    return result, time.monotonic() - start


def difference(reference: list[dict], current: list[dict]) -> list[dict]:
    errors = []
    if len(reference) != len(current):
        errors.append({"lengths": [len(reference), len(current)]})
    for index, (left, right) in enumerate(zip(reference, current)):
        if left != right:
            names = sorted(set(left.get("sections", {})) | set(right.get("sections", {})))
            errors.append({"index": index, "seed": left.get("seed"), "label": left.get("label"),
                           "step": left.get("step"), "phase": left.get("phase"),
                           "differentSections": [name for name in names
                               if left.get("sections", {}).get(name) != right.get("sections", {}).get(name)]})
    return errors


def alias_probe(godot: str, output: Path) -> dict:
    process = subprocess.run([godot, "--headless", "--path", str(ROOT), "--script",
                              "res://tools/incremental-tx/alias_probe.gd", "--", str(output)],
                             capture_output=True, text=True, timeout=60, check=False)
    log = process.stdout + process.stderr
    errors = re.findall(r"^(?:SCRIPT )?ERROR: (.+)$", log, re.MULTILINE)
    # Exactly these three intentional writes must fail; no unrelated script error allowed.
    expected = ["Dictionary is in read-only state.",
                "Invalid assignment on read-only value (on base: 'Dictionary').",
                "Array is in read-only state.",
                "Dictionary is in read-only state.",
                "Invalid assignment on read-only value (on base: 'Dictionary')."]
    if process.returncode or errors != expected or not output.exists():
        print(log, end="")
        raise RuntimeError("Alias probe did not produce exactly the expected read-only rejections")
    result = json.loads(output.read_text())
    if result.get("status") != "pass" or not result.get("unchanged"):
        raise RuntimeError("Captured aliases changed committed state")
    print("PASS TX-016 captured aliases: exactly 5 expected read-only error headers; committed state unchanged")
    return {"id": "TX-016", "name": "首次接管前捕获的旧事实、人物与上下文别名不可改写已提交状态",
            "status": "pass", "details": {**result, "expectedErrorHeaders": errors,
                                           "isolatedProcess": True, "noUnexpectedErrors": True}}


def readable(report: dict) -> str:
    lines = ["# 增量事务与受限读取实测", "",
             f"实际执行时间：{report['generatedAt']}。全详细参考模式，未接入概略模拟或注意力预算。", "",
             "`python3 tools/incremental-tx/verify.py` 使用 Git 中固定的改造前版本，"
             "把同一份独立驱动分别交给旧版和当前 Godot 代码执行；没有用两份新实现相互比较。", "",
             f"基线：`{BASELINE}`。两种子各 12 轮，共 {report['differential']['checkpoints']} 个逐请求检查点。"
             "包含正式经济、两域教团及锚点、每六轮真实暴露与神迹来源、随机检定、合并超支失败、"
             "请求重放、计划预览和阶段四存续。当前代码实际加载旧版生成的阶段四存档，再完成后续同命令重放。"
             "每点比较全部世界字段、事实、费用、随机位置、统计、上下文与响应的规范化 SHA-256。", "",
             "唯一允许剔除的表示元数据为顶层提交序号；不剔除事实、费用、回执、阶段或随机内容。"
             "实际 driver 直接对 world snapshot 的 body 和 turn context 分区比较，外层保存校验和不作为玩法字段。", "",
             "## 检查", ""]
    lines.extend(f"- `{check['id']}`：{check['name']}（{check['status']}）。" for check in report["checks"])
    lines += ["", "## 边界", "",
              "- 这是事务安全及既有行为等价性证据，不证明完整游戏、概略模拟或玩家体验已完成。",
              "- 当前候选共享不可变历史树；原生历史容器根的浅复制与身份核对、全量导出及读档审计仍有历史长度成本。"
              "剩余根与保存成本交给 TASK-ARCHIVE-SAVE；不能由本项推导长战役耗时有界。",
              "- 差分驱动为每个检查点额外做全量序列化，运行秒数仅用于复现诊断，不能当作普通回合性能基准。",
              "- 验证参与者只提供明确授权的场景条件与效果；经济、NPC、文明和提交规则使用生产实现。",
              "- GDScript 参与者是受信任规则代码，受限接口约束集成，不是对任意反射/私有字段访问的安全沙箱。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    before = hashes()
    try:
        archive = subprocess.run(["git", "archive", BASELINE], cwd=ROOT, capture_output=True,
                                 check=True).stdout
        with tempfile.TemporaryDirectory(prefix="cthulhu-tx-") as temp:
            scratch = Path(temp)
            baseline = scratch / "baseline"
            baseline.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                bundle.extractall(baseline, filter="data")
            (baseline / "tools/incremental-tx").mkdir(parents=True)
            shutil.copy2(ROOT / "tools/incremental-tx/replay.gd", baseline / "tools/incremental-tx/replay.gd")
            reference, reference_seconds = execute(args.godot, baseline, "replay.gd", scratch / "reference.json")
            current, current_seconds = execute(args.godot, ROOT, "replay.gd", scratch / "current.json", scratch / "reference.json")
            if not current.get("legacyLoaded"):
                raise RuntimeError("Current replay did not load the real legacy checkpoint")
            adversaries, adversary_seconds = execute(args.godot, ROOT, "run.gd", scratch / "adversaries.json")
            aliases = alias_probe(args.godot, scratch / "aliases.json")
            errors = difference(reference["trace"], current["trace"])
            check = {"id": "TX-001", "name": "改造前真实版本与当前代码逐请求语义差分一致", "status": "pass" if not errors else "fail",
                     "details": {"checkpoints": len(reference["trace"]), "differences": errors[:20], "differenceCount": len(errors), "realLegacyCheckpointResumed": True}}
            after = hashes()
            if before != after:
                raise RuntimeError("Sources changed during execution; rerun against a stable source set")
            checks = [check, *adversaries["checks"], aliases]
            ids = [entry["id"] for entry in checks]
            if len(ids) != len(set(ids)) or not all(item.startswith("TX-") for item in ids):
                raise RuntimeError("Invalid/duplicate check IDs")
            passed = all(entry["status"] == "pass" for entry in checks)
            report = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
                      "engine": current["engine"], "checks": checks, "sourceHashes": after,
                      "executionProfile": {"mode": "all-detailed-reference", "hybridImplemented": False},
                      "baseline": {"revision": BASELINE, "archiveSha256": hashlib.sha256(archive).hexdigest(),
                                   "driverSha256": after["tools/incremental-tx/replay.gd"]},
                      "differential": {"checkpoints": len(reference["trace"]), "seeds": [7919, 1981],
                                       "turnsPerSeed": 12, "differenceCount": len(errors), "realLegacyCheckpointResumed": True,
                                       "referenceTraceSha256": hashlib.sha256(json.dumps(reference["trace"], sort_keys=True).encode()).hexdigest(),
                                       "currentTraceSha256": hashlib.sha256(json.dumps(current["trace"], sort_keys=True).encode()).hexdigest()},
                      "diagnosticSeconds": {"referenceWithFullTracing": reference_seconds,
                                            "currentWithFullTracing": current_seconds, "adversaries": adversary_seconds},
                      "wrapperVerified": {"freshTemporaryReports": True, "sameDriverBothVersions": True,
                                          "sourcesUnchangedDuringRun": True, "noUnexpectedGodotErrors": True,
                                          "expectedAliasErrorsIsolated": True, "uniqueCheckIds": True}}
            REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            (ROOT / "docs/qa/incremental-tx.md").write_text(readable(report))
            print(f"{'VERIFIED' if passed else 'FAILED'} {len(checks)} transaction checks; {len(after)} source hashes")
            return 0 if passed else 1
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
