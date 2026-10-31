"""Finite actual Session save compatibility batch; no campaign replay."""
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
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = sorted([*ROOT.joinpath("src").rglob("*.gd"), *ROOT.joinpath("data").glob("*.csv"), Path(__file__).resolve(), Path(__file__).with_name("run.gd")])
    hashes = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    (output / "input-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    started = time.monotonic()
    stages = []
    status = "pass"
    commands = [("parse", ["--headless", "--path", str(ROOT), "--script", "res://tools/cult-save-compat/run.gd", "--check-only"]), ("core", ["--headless", "--path", str(ROOT), "--script", "res://tools/cult-save-compat/run.gd", "--", str(output / "core.json")]), ("startup", ["--headless", "--path", str(ROOT), "--quit-after", "2"])]
    for name, command in commands:
        tick = time.monotonic()
        try:
            result = subprocess.run([args.godot, *command], capture_output=True, timeout=max(0.1, 300 - (tick - started)))
            stdout, stderr, code = result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired as exc:
            stdout, stderr, code = exc.stdout or b"", exc.stderr or b"", -1
        (output / f"{name}-stdout.rawlog").write_bytes(stdout)
        (output / f"{name}-stderr.rawlog").write_bytes(stderr)
        errors = bool(re.search(rb"SCRIPT ERROR|ERROR:", stdout + stderr))
        passed = code == 0 and not errors
        if name == "core":
            passed = passed and (output / "core.json").exists() and json.loads((output / "core.json").read_text(encoding="utf-8"))["status"] == "pass"
        stages.append({"name": name, "exit": code, "engineErrors": errors, "seconds": round(time.monotonic() - tick, 3), "status": "pass" if passed else "fail"})
        if not passed:
            status = "fail"
            break
    drift = [p for p, h in hashes.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
    if drift:
        status = "fail"
    summary = {"status": status, "seconds": round(time.monotonic() - started, 3), "budgetSeconds": 300, "stages": stages, "inputDrift": drift}
    (output / "execution.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
