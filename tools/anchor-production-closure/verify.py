"""Six finite route groups; each engine invocation has a short execution bound."""
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
SPEC = importlib.util.spec_from_file_location("closure_shared", ROOT / "tools/cult-spread/verify.py")
SHARED = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SHARED)
GROUPS = ("contract", "network", "records-calendar", "ritual", "axiom", "memory-dissent")
MEMORY_ROUTES = ("memory_circle", "memory_practice", "dissent_circle", "dissent_practice")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script = "res://tools/anchor-production-closure/run.gd"

    def inputs() -> dict[str, str]:
        hashes = SHARED.inputs([script, "res://src/presentation/game_root.gd"])
        hashes[Path(__file__).relative_to(ROOT).as_posix()] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        return hashes

    before = inputs()
    (output / "input-sha256.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
    runs = []
    jobs = [("parse", ["--check-only", "--script", script], 0)]
    for group in GROUPS:
        if group == "memory-dissent":
            jobs.extend((group + "-" + route, ["--script", script, "--", str(output / (group + "-" + route + ".json")), group, route], 1) for route in MEMORY_ROUTES)
        else:
            jobs.append((group, ["--script", script, "--", str(output / (group + ".json")), group], 1))
    jobs.append(("dev", ["--quit-after", "2"], 0))
    for label, options, count in jobs:
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(output / (label + "-engine.rawlog"))] + options
        started = time.perf_counter()
        try:
            process = subprocess.run(command, capture_output=True, timeout=58)
            stdout, stderr, code = process.stdout, process.stderr, process.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, code = error.stdout or b"", error.stderr or b"", -1
        (output / (label + "-stdout.rawlog")).write_bytes(stdout)
        (output / (label + "-stderr.rawlog")).write_bytes(stderr)
        engine = output / (label + "-engine.rawlog")
        raw = stdout + stderr + (engine.read_bytes() if engine.exists() else b"")
        report = json.loads((output / (label + ".json")).read_text(encoding="utf-8")) if (output / (label + ".json")).exists() else {}
        errors = any(marker in raw for marker in (b"ERROR:", b"SCRIPT ERROR", b"Parse Error"))
        passed = code == 0 and not errors and (not count or (report.get("status") == "pass" and len(report.get("checks", [])) == count))
        entry = {"label": label, "command": command, "exit": code, "seconds": round(time.perf_counter() - started, 3), "engineErrors": errors, "passed": passed}
        runs.append(entry)
        print(json.dumps(entry), flush=True)
        if not passed:
            break
    memory_reports = [output / ("memory-dissent-" + route + ".json") for route in MEMORY_ROUTES]
    if all(path.exists() for path in memory_reports):
        parts = [json.loads(path.read_text(encoding="utf-8")) for path in memory_reports]
        cases = [case for part in parts for check in part["checks"] for case in check["details"]["cases"]]
        memory_passed = len(cases) == len(MEMORY_ROUTES) and [case["route"] for case in cases] == list(MEMORY_ROUTES) and all(part["status"] == "pass" for part in parts)
        combined = {key: value for key, value in parts[0].items() if key not in ("status", "checks")}
        combined.update({"status": "pass" if memory_passed else "fail", "checks": [{"id": "APC-MEMORY-DISSENT", "status": "pass" if memory_passed else "fail", "name": "Actual route production and paid active anchors: memory-dissent", "details": {"cases": cases}}], "caseReports": [path.relative_to(ROOT).as_posix() for path in memory_reports]})
        (output / "memory-dissent.json").write_text(json.dumps(combined, indent=2) + "\n", encoding="utf-8")
    after = inputs()
    changed = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
    result = {"status": "pass" if len(runs) == len(jobs) and not changed and all(row["passed"] for row in runs) else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "runs": runs, "sourceHashes": before, "changedInputs": changed, "seconds": round(sum(row["seconds"] for row in runs), 3), "perInvocationLimitSeconds": 58}
    (output / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
