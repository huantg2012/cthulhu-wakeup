#!/usr/bin/env python3
"""Run Endings specialty assertions and the complete fresh resistance regression chain."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import platform
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("resistance_wrapper", ROOT / "tools/resistance/verify.py")
resistance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resistance)
execute = resistance.events.anchors.prayers.powers.fidelity.execute


def hashes():
    result = resistance.hashes()
    paths = [ROOT / "docs/tasks/slice-11.md", ROOT / "docs/specs/system-progression.md", *sorted((ROOT / "tools/endings").glob("*"))]
    for path in paths:
        if path.is_file() and path.suffix in {".gd", ".py", ".md"}:
            result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def expected_ids():
    return resistance.expected_ids() | {
        "END-CONTACT-001", "END-CONTACT-002", "END-CONTACT-003", "END-CONTACT-004", "END-LIFE-001", "END-LIFE-002", "END-LIFE-003", "END-SAVE-001", "END-SAVE-004",
        *{f"END-MANIFEST/{outcome}" for outcome in ["deep", "success", "failure", "disaster"]},
        *{f"END-PRIORITY/{kind}" for kind in ["death", "anchor", "zero", "upkeep"]},
        "END-MANIFEST-LOCK", "END-MANIFEST-CANCEL", "END-MANIFEST-UNPAID",
        "END-SAVE-002", "END-SAVE-003",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()
    before = hashes()
    with tempfile.TemporaryDirectory(prefix="endings-", dir=ROOT / ".godot") as temporary:
        scratch = Path(temporary)
        output = scratch / "endings.json"
        execute([args.godot, "--headless", "--path", str(ROOT), "--log-file", str(scratch / "godot.log"), "--script", "res://tools/endings/manifest_cases.gd", "--", str(output)], ROOT / "tools/endings/run.log", 600)
        raw = json.loads(output.read_text(encoding="utf-8"))
        checks = raw["checks"]
        specialty_count = sum(item["id"].startswith("END-") for item in checks)
        inherited_count = len(checks) - specialty_count
        actual = {item["id"] for item in checks}
        expected = expected_ids()
        if actual != expected or len(checks) != len(expected):
            raise RuntimeError(f"Missing/duplicate endings checks: missing={expected-actual}, extra={actual-expected}")
        if raw["status"] != "pass" or any(item["status"] != "pass" for item in checks):
            raise RuntimeError("Endings assertions failed")
        if before != hashes():
            raise RuntimeError("Sources changed during specialty run")
        if args.smoke:
            print(f"SMOKE {specialty_count} new endings checks + {inherited_count} inherited resistance checks; no formal evidence written")
            return 0
        target = ROOT / "docs/qa/resistance-results.json"
        previous = target.stat().st_mtime_ns if target.exists() else None
        execute([sys.executable, "-X", "utf8", "tools/resistance/verify.py", "--godot", args.godot], ROOT / "tools/endings/regressions.log", 3600)
        if not target.exists() or target.stat().st_mtime_ns == previous:
            raise RuntimeError("No fresh resistance regression report")
        regression = json.loads(target.read_text(encoding="utf-8"))
        if regression["status"] != "pass" or any(item["status"] != "pass" for item in regression["checks"]):
            raise RuntimeError("Resistance regression failed")
        if before != hashes():
            raise RuntimeError("Sources changed during execution; rerun frozen sources")
        limitations = [
            "机会接收人资格与满N退休释放N→P仅静态复核，本专项未独立端到端覆盖；拘禁窗口反例验证初态实际来源和纯读预览，不冒称完整后续释放链。",
            "合法中局机构证明、既存教团与明确初始处境是夹具；三轮仪式、费用、原随机流、终局和存档结果由生产系统实际执行。",
            "旧22项抵抗专项在完整Endings安装下重复执行；父链另由真实独立包装器重跑，不手动刷新旧结果。",
            "断联检验当前可执行入口与有期限的真实计划，不预测所有未来解法。",
            "无游戏内UI，不证明叙事、策略平衡、终局可达率或发行性能通过。",
            "当前CSV在第三轮要求A≥90，失败伤害10、灾变20加所选宇宙锚10损失，因此同笔终骰后直接寂灭不可达；实跑失败后复算并继续，未改表造假场景。",
            "有效仪式锚要求教团，而活跃/休眠教团排除彻底断联；同轮第三次断联与仍完整仪式资格不可并存。独立实跑断联三轮和第三轮死亡/失锚/归零优先。",
        ]
        report = {**raw, "generatedAt": datetime.now(timezone.utc).isoformat(), "sourceHashes": before,
                  "checkCounts": {"newEndings": specialty_count, "inheritedResistanceWithEndings": inherited_count},
                  "environment": {"engine": raw["engine"], "platform": platform.platform(), "python": platform.python_version(), "headless": True},
                  "regressions": {"report": "docs/qa/resistance-results.json", "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "resistanceChecks": len(regression["checks"]), **{k: v for k, v in regression["regressions"].items() if k.endswith("Checks")}},
                  "limitations": limitations,
                  "wrapperVerified": {"freshTemporaryReport": True, "sourcesUnchangedDuringRun": True, "uniqueStableIds": True, "noGodotErrors": True, "realResistanceAndCompleteRegressionChain": True}}
        (ROOT / "docs/qa/endings-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        total = len(regression["checks"]) + sum(v for k, v in regression["regressions"].items() if k.endswith("Checks"))
        lines = ["# 正式终局与封存验收", "", f"实际执行：{report['generatedAt']}；Godot {raw['engine']}；{report['environment']['platform']}。", "", "执行边界与初始夹具说明见 [tools/endings](../../tools/endings/README.md)。", ""]
        lines += [f"- `{c['id']}`：{c['name']}（{c['status']}）。" for c in checks]
        lines += ["", f"本项新增 {specialty_count} 项；完整Endings安装下继承复跑 {inherited_count} 项抵抗。独立父链另实际重跑 {total} 项（不把继承复跑计为新增）。来源与父报告 SHA 见 [机器证据](endings-results.json)。", ""] + ["- " + item for item in limitations]
        (ROOT / "docs/qa/endings.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        print(f"VERIFIED {specialty_count} new endings + {inherited_count} inherited resistance checks and {total} actual registered regressions")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print("FAIL:", error, file=sys.stderr)
        raise SystemExit(1)
