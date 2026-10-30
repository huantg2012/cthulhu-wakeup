"""Reuse the existing input fingerprint collector and four bounded Godot groups."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("cult_spread_gate", ROOT / "tools/cult-spread/verify.py")
SHARED = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SHARED)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--regressions", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script = "res://tools/anchor-lifecycle/run.gd"
    jobs = [("parse", ["--check-only", "--script", script], 0), ("core", ["--script", script, "--", str(output / "core.json")], 4)]
    if args.regressions:
        jobs.append(("cult-spread", ["--script", "res://tools/cult-spread/run.gd", "--", str(output / "cult-spread.json")], 4))
        jobs.append(("dev", ["--quit-after", "2"], 0))
    scripts = [options[options.index("--script") + 1] for _, options, _ in jobs if "--script" in options]
    before = SHARED.inputs(scripts)
    own = Path(__file__).resolve()
    before[own.relative_to(ROOT).as_posix()] = hashlib.sha256(own.read_bytes()).hexdigest()
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
        print(json.dumps(entry), flush=True)
        if not passed:
            break
    after = SHARED.inputs(scripts)
    after[own.relative_to(ROOT).as_posix()] = hashlib.sha256(own.read_bytes()).hexdigest()
    changed = [name for name in before if before[name] != after.get(name)]
    passed = len(runs) == len(jobs) and not changed and all(row["passed"] for row in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "runs": runs, "sourceHashes": before, "changedInputs": changed, "seconds": round(sum(row["seconds"] for row in runs), 3)}
    (output / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
