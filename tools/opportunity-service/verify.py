"""Four bounded direct-service groups, affected shared checks and one isolated behavior control."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("shared_gate", ROOT / "tools/cult-spread/verify.py")
SHARED = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SHARED)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    own = Path(__file__).resolve()
    script = "res://tools/opportunity-service/run.gd"
    scripts = [script, "res://tools/opportunity-eligibility/run.gd", "res://src/presentation/game_root.gd"]

    def inputs() -> dict[str, str]:
        result = SHARED.inputs(scripts)
        result[own.relative_to(ROOT).as_posix()] = hashlib.sha256(own.read_bytes()).hexdigest()
        return result

    before = inputs()
    (output / "input-sha256.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
    runs = []
    started_batch = time.perf_counter()

    def run(label: str, root: Path, options: list[str], count: int, negative: bool = False) -> bool:
        command = [args.godot, "--headless", "--path", str(root), "--log-file", str(output / (label + "-engine.rawlog"))] + options
        started = time.perf_counter()
        remaining = max(1, 58 - (started - started_batch))
        try:
            process = subprocess.run(command, capture_output=True, timeout=remaining)
            stdout, stderr, code = process.stdout, process.stderr, process.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, code = error.stdout or b"", error.stderr or b"", -1
        (output / (label + "-stdout.rawlog")).write_bytes(stdout)
        (output / (label + "-stderr.rawlog")).write_bytes(stderr)
        engine = output / (label + "-engine.rawlog")
        raw = stdout + stderr + (engine.read_bytes() if engine.exists() else b"")
        report_path = output / (label + ".json")
        report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
        engine_errors = any(marker in raw for marker in (b"ERROR:", b"SCRIPT ERROR", b"Parse Error"))
        if negative:
            checks = report.get("checks", [])
            passed = code == 1 and not engine_errors and report.get("status") == "fail" and len(checks) == 1 and checks[0].get("id") == "OS-COMPONENTS" and checks[0].get("details", {}).get("forgedStepRejected") is False
        else:
            passed = code == 0 and not engine_errors and (not count or (report.get("status") == "pass" and len(report.get("checks", [])) == count))
        entry = {"label": label, "command": command, "exit": code,
                 "seconds": round(time.perf_counter() - started, 3), "engineErrors": engine_errors,
                 "passed": passed, "expectedBehaviorFailure": negative}
        runs.append(entry)
        print(json.dumps(entry), flush=True)
        return passed

    jobs = [("parse", ["--check-only", "--script", script], 0),
            ("core", ["--script", script, "--", str(output / "core.json")], 4),
            ("eligibility", ["--script", scripts[1], "--", str(output / "eligibility.json")], 4),
            ("dev", ["--quit-after", "2"], 0)]
    normal_passed = True
    for label, options, count in jobs:
        if not run(label, ROOT, options, count):
            normal_passed = False
            break
    mutation = {}
    if normal_passed:
        isolated = output / "negative-project"
        for name in before:
            destination = isolated / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)
        target = isolated / "src/game/opportunity_service.gd"
        source = target.read_text(encoding="utf-8")
        guard = 'return ["Invalid direct opportunity service receipt"]'
        if source.count(guard) != 1:
            raise RuntimeError("The isolated behavior guard must have one exact binding")
        changed = source.replace(guard, "return []", 1)
        target.write_text(changed, encoding="utf-8", newline="\n")
        mutation = {"file": "src/game/opportunity_service.gd", "guard": "receipt/step binding",
                    "originalSha256": hashlib.sha256(source.encode()).hexdigest(),
                    "mutatedSha256": hashlib.sha256(changed.encode()).hexdigest()}
        run("negative", isolated, ["--script", script, "--", str(output / "negative.json"), "negative"], 1, True)
    after = inputs()
    changed_inputs = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
    passed = len(runs) == 5 and not changed_inputs and all(row["passed"] for row in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
              "runs": runs, "sourceHashes": before, "changedInputs": changed_inputs, "isolatedMutation": mutation,
              "seconds": round(time.perf_counter() - started_batch, 3)}
    (output / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
