#!/usr/bin/env python3
"""Small, bounded route-consumer gate; optionally reuse the existing 17 core checks."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tools/anchor-routes/run.gd"

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inputs() -> dict[str, str]:
    pending = [ROOT / SCRIPT.removeprefix("res://")]
    paths = {Path(__file__).resolve()}
    while pending:
        path = pending.pop()
        if path in paths:
            continue
        paths.add(path)
        for dependency in re.findall(r'(?:preload\(|extends )"res://([^"]+\.gd)"', path.read_text(encoding="utf-8-sig")):
            pending.append(ROOT / dependency)
    catalog = (ROOT / "src/simulation/catalog.gd").read_text(encoding="utf-8-sig")
    names = {"fidelity_parameters", "background_templates", "simulation_responsibilities", "intervention_policies"}
    for constant in ("FILES", "EXTENSIONS"):
        match = re.search(rf"const {constant}:[^=]+?= \[(.*?)\]", catalog, re.S)
        if match:
            names.update(re.findall(r'"([a-z_]+)"', match.group(1)))
    paths.update(ROOT / "data" / (name + ".csv") for name in names)
    paths.add(ROOT / "project.godot")
    return {path.relative_to(ROOT).as_posix(): digest(path) for path in sorted(paths)}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shared-core", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = inputs()
    runs = []
    jobs = [("parse", ["--check-only", "--script", SCRIPT]), ("routes", ["--script", SCRIPT, "--", str(output / "routes.json")])]
    if args.shared_core:
        jobs.extend([("shared-core", ["--script", "res://tools/prayer-producers/source-contract.gd", "--", str(output / "shared-core.json")]), ("menu", ["--quit-after", "2"])])
    for label, options in jobs:
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(output / (label + "-engine.log"))] + options
        started = time.perf_counter()
        try:
            process = subprocess.run(command, capture_output=True, text=True, timeout=30)
            console = process.stdout + process.stderr
            exit_code = process.returncode
        except subprocess.TimeoutExpired as error:
            console = str(error.stdout or "") + str(error.stderr or "")
            exit_code = -1
        (output / (label + "-console.log")).write_text(console, encoding="utf-8", newline="\n")
        report_path = output / (label + ".json")
        report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
        run = {"label": label, "command": command, "exit": exit_code, "seconds": round(time.perf_counter() - started, 3), "engineErrors": "ERROR:" in console or "SCRIPT ERROR:" in console, "report": str(report_path.relative_to(ROOT)) if report_path.exists() else None}
        if label in ("routes", "shared-core"):
            run["passed"] = report.get("status") == "pass" and len(report.get("checks", [])) == (4 if label == "routes" else 17)
        else:
            run["passed"] = exit_code == 0
        runs.append(run)
        print(json.dumps(run, ensure_ascii=False), flush=True)
        if exit_code != 0 or run["engineErrors"] or not run["passed"]:
            break
    after = inputs()
    changed = [path for path in before if before[path] != after.get(path)]
    passed = len(runs) == len(jobs) and not changed and all(run["exit"] == 0 and run["passed"] and not run["engineErrors"] for run in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "runs": runs, "sourceHashes": before, "changedInputs": changed, "seconds": round(sum(run["seconds"] for run in runs), 3), "scope": "four_shared_route_groups_and_optional_existing_core", "limitations": ["Normalized material inputs test consumers only; eight alternate raw producers remain uninstalled.", "Full Session/new game, first relic/upkeep/endings and complete alternative route activation are separate tasks."]}
    (output / "execution.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": result["status"], "seconds": result["seconds"], "changedInputs": changed}), flush=True)
    return 0 if passed else 1

if __name__ == "__main__":
    raise SystemExit(main())
