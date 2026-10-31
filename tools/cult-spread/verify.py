"""Four small production groups, exact transitive source fingerprints and raw logs."""
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

def inputs(scripts: list[str]) -> dict[str, str]:
    paths = {Path(__file__).resolve()}
    pending = [ROOT / script.removeprefix("res://") for script in scripts]
    while pending:
        path = pending.pop()
        if path in paths:
            continue
        paths.add(path)
        for dependency in re.findall(r'(?:preload\(|load\(|extends )"res://([^"\n]+\.(?:gd|tscn))"', path.read_text(encoding="utf-8-sig")):
            pending.append(ROOT / dependency)
        if path.suffix == ".tscn":
            pending.extend(ROOT / match for match in re.findall(r'path="res://([^"\n]+\.gd)"', path.read_text(encoding="utf-8-sig")))
    catalog = (ROOT / "src/simulation/catalog.gd").read_text(encoding="utf-8-sig")
    names = {"fidelity_parameters", "background_templates", "simulation_responsibilities", "intervention_policies"}
    for constant in ("FILES", "EXTENSIONS"):
        match = re.search(rf"const {constant}:[^=]+?= \[(.*?)\]", catalog, re.S)
        if match:
            names.update(re.findall(r'"([a-z_]+)"', match.group(1)))
    paths.update(ROOT / "data" / (name + ".csv") for name in names)
    paths.add(ROOT / "project.godot")
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(paths)}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--regressions", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script = "res://tools/cult-spread/run.gd"
    jobs = [("parse", ["--check-only", "--script", script], 0), ("core", ["--script", script, "--", str(output / "core.json")], 4)]
    if args.regressions:
        for name, path, count in [("material", "tools/material-transfer/run.gd", 4), ("anchors", "tools/anchor-routes/run.gd", 4), ("shared", "tools/prayer-producers/source-contract.gd", 17)]:
            jobs.append((name, ["--script", "res://" + path, "--", str(output / (name + ".json"))], count))
        jobs.append(("dev", ["--quit-after", "2"], 0))
    scripts = [script] + [options[options.index("--script") + 1] for _, options, _ in jobs if "--script" in options]
    before = inputs(scripts)
    runs = []
    for label, options, count in jobs:
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(output / (label + "-engine.rawlog"))] + options
        started = time.perf_counter()
        try:
            process = subprocess.run(command, capture_output=True, timeout=55)
            stdout, stderr, code = process.stdout, process.stderr, process.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, code = error.stdout or b"", error.stderr or b"", -1
        (output / (label + "-stdout.rawlog")).write_bytes(stdout)
        (output / (label + "-stderr.rawlog")).write_bytes(stderr)
        engine = output / (label + "-engine.rawlog")
        raw = stdout + stderr + (engine.read_bytes() if engine.exists() else b"")
        report_path = output / (label + ".json")
        report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
        passed = code == 0 and b"ERROR:" not in raw and (not count or (report.get("status") == "pass" and len(report.get("checks", [])) == count))
        entry = {"label": label, "command": command, "exit": code, "seconds": round(time.perf_counter() - started, 3), "engineErrors": b"ERROR:" in raw, "passed": passed}
        runs.append(entry)
        print(json.dumps(entry, ensure_ascii=False), flush=True)
        if not passed:
            break
    after = inputs(scripts)
    changed = [name for name in before if before[name] != after.get(name)]
    passed = len(runs) == len(jobs) and not changed and all(item["passed"] for item in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "runs": runs, "sourceHashes": before, "changedInputs": changed, "seconds": round(sum(item["seconds"] for item in runs), 3)}
    (output / "execution.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return 0 if passed else 1

if __name__ == "__main__":
    raise SystemExit(main())
