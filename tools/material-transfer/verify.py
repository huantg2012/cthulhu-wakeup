#!/usr/bin/env python3
"""Freeze the four material component groups, then reuse the bounded anchor/core gate."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tools/material-transfer/run.gd"
ANCHOR_GATE = ROOT / "tools/anchor-routes/verify.py"


def inputs() -> dict[str, str]:
    # Reuse the existing dependency collector and extend it for this component,
    # dynamically loaded presentation resources and the reused shared-core job.
    spec = importlib.util.spec_from_file_location("anchor_gate", ANCHOR_GATE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    paths = {ROOT / name for name in module.inputs()}
    paths.update(path for path in (ROOT / "src").rglob("*") if path.suffix in {".gd", ".tscn", ".tres", ".gdshader"})
    paths.update((ROOT / "data").glob("*.csv"))
    paths.update([Path(__file__).resolve(), ROOT / "tools/material-transfer/README.md", ROOT / "tools/material-transfer/.gitattributes"])
    pending = [ROOT / SCRIPT.removeprefix("res://")]
    while pending:
        path = pending.pop()
        if path in paths:
            continue
        paths.add(path)
        for name in re.findall(r'"res://([^"\n]+\.(?:gd|tscn|tres))"', path.read_text(encoding="utf-8-sig")):
            pending.append(ROOT / name)
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(paths)}


def run(label: str, command: list[str], output: Path, report_name: str | None = None) -> dict:
    started = time.perf_counter()
    try:
        process = subprocess.run(command, capture_output=True, timeout=60)
        console = process.stdout + process.stderr
        exit_code = process.returncode
    except subprocess.TimeoutExpired as error:
        console = (error.stdout or b"") + (error.stderr or b"")
        exit_code = -1
    (output / (label + "-console.log")).write_bytes(console)
    report_path = output / report_name if report_name else None
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path and report_path.exists() else {}
    engine_path = output / (label + "-engine.log")
    diagnostic = console + (engine_path.read_bytes() if engine_path.exists() else b"")
    passed = exit_code == 0
    if label == "materials":
        passed = passed and report.get("status") == "pass" and len(report.get("checks", [])) == 4 and all(check.get("status") == "pass" for check in report.get("checks", []))
    elif label == "anchor-core":
        passed = passed and report.get("status") == "pass" and len(report.get("runs", [])) == 4
    result = {"label": label, "command": command, "exit": exit_code, "seconds": round(time.perf_counter() - started, 3), "engineErrors": b"ERROR:" in diagnostic, "passed": passed, "report": report_path.relative_to(ROOT).as_posix() if report_path and report_path.exists() else None}
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.perf_counter()
    before = inputs()
    for name in before:
        target = output / "frozen-inputs" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    (output / "input-sha256.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
    engine = [args.godot, "--headless", "--path", str(ROOT)]
    jobs = [
        ("parse", engine + ["--log-file", str(output / "parse-engine.log"), "--check-only", "--script", SCRIPT], None),
        ("materials", engine + ["--log-file", str(output / "materials-engine.log"), "--script", SCRIPT, "--", str(output / "materials.json")], "materials.json"),
        ("anchor-core", ["python", str(ANCHOR_GATE), "--godot", args.godot, "--output", str(output / "anchor-core"), "--shared-core"], "anchor-core/execution.json"),
    ]
    runs = []
    for label, command, report_name in jobs:
        result = run(label, command, output, report_name)
        runs.append(result)
        if result["exit"] != 0 or result["engineErrors"] or not result["passed"]:
            break
    after = inputs()
    changed = sorted(name for name in before.keys() | after.keys() if before.get(name) != after.get(name))
    passed = len(runs) == len(jobs) and not changed and all(result["passed"] and not result["engineErrors"] for result in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "runs": runs, "sourceHashes": before, "frozenInputCount": len(before), "changedInputs": changed, "seconds": round(time.perf_counter() - started, 3), "scope": "four_material_component_groups_plus_existing_four_anchor_and_seventeen_source_core_checks_and_menu", "limitations": ["Explicit initial cult/membership/contact/funding/RNG and display projection prerequisites; no natural first-cult or full Session startup/save claim.", "Wrapped learn uses actual prior paid-transfer receipt and production Prayers effect inside a managed component transaction with a controlled outer PR04 plan; checks material receipt restore validation only, then rolls back.", "PlayerSources schema2 installation guard remains; 09A full execution, future raw producers and full campaign closure remain downstream."]}
    (output / "execution.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "frozenInputCount": len(before), "changedInputs": changed, "seconds": result["seconds"]}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
