"""One bounded source regression and six original-RNG startup trajectories."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--natural-only", action="store_true")
    parser.add_argument("--fifo-core", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    files = sorted([*ROOT.joinpath("src").rglob("*.gd"), *ROOT.joinpath("data").glob("*.csv"), Path(__file__).resolve(), Path(__file__).with_name("run.gd"), Path(__file__).with_name("fifo.gd")])
    hashes = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (output / "input-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    stages = []
    start = time.monotonic()
    status = "pass"
    commands = [("parse", ["--headless", "--path", str(ROOT), "--script", "res://tools/startup-balance/run.gd", "--check-only"]), ("core", ["--headless", "--path", str(ROOT), "--script", "res://tools/startup-balance/run.gd", "--", str(output / "core.json")]), ("startup", ["--headless", "--path", str(ROOT), "--quit-after", "2"])]
    if args.natural_only:
        commands[1][1].append("--natural-only")
    if args.fifo_core:
        commands.insert(1, ("parse-fifo", ["--headless", "--path", str(ROOT), "--script", "res://tools/startup-balance/fifo.gd", "--check-only"]))
        commands.insert(-1, ("fifo", ["--headless", "--path", str(ROOT), "--script", "res://tools/startup-balance/fifo.gd", "--", str(output / "fifo.json")]))
    for name, command in commands:
        tick = time.monotonic()
        try:
            result = subprocess.run([args.godot, *command], capture_output=True, timeout=max(0.1, 300 - (tick - start)))
            stdout, stderr, code = result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired as exc:
            stdout, stderr, code = exc.stdout or b"", exc.stderr or b"", -1
        (output / f"{name}-stdout.rawlog").write_bytes(stdout)
        (output / f"{name}-stderr.rawlog").write_bytes(stderr)
        engine_errors = bool(re.search(rb"SCRIPT ERROR|ERROR:", stdout + stderr))
        passed = code == 0 and not engine_errors
        if name in {"core", "fifo"}:
            passed = passed and (output / f"{name}.json").exists() and json.loads((output / f"{name}.json").read_text(encoding="utf-8"))["status"] == "pass"
        stages.append({"name": name, "exit": code, "engineErrors": engine_errors, "seconds": round(time.monotonic() - tick, 3), "status": "pass" if passed else "fail"})
        if not passed:
            status = "fail"
            break
    drift = [p for p, h in hashes.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
    if drift:
        status = "fail"
    result = {"status": status, "seconds": round(time.monotonic() - start, 3), "budgetSeconds": 300, "stages": stages, "inputDrift": drift, "samplePlan": {"seeds": [1, 2, 3, 4, 5, 6], "gatheringPreferred": [1, 2, 3, 4], "ritePreferred": [5, 6], "horizonActionWindows": 8, "naturalRngOverrides": False, "controlledSourceRegressionRepeated": not args.natural_only, "finiteFifoCore": args.fifo_core}}
    (output / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
