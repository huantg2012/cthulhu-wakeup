"""One bounded retained-Session continuation; preserve every actual failure."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/startup-balance/runs/calibration-02/natural-1/1793428397-2120124.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source_hash = digest(SOURCE)
    copied = output / "input-session.json"
    shutil.copyfile(SOURCE, copied)
    files = sorted([*ROOT.joinpath("src").rglob("*.gd"), *ROOT.joinpath("data").glob("*.csv"), Path(__file__).resolve(), Path(__file__).with_name("run.gd"), SOURCE])
    hashes = {p.relative_to(ROOT).as_posix(): digest(p) for p in files}
    (output / "input-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    commands = [("parse", ["--headless", "--path", str(ROOT), "--script", "res://tools/natural-verify/run.gd", "--check-only"]), ("core", ["--headless", "--path", str(ROOT), "--script", "res://tools/natural-verify/run.gd", "--", str(output / "core.json"), str(copied)]), ("startup", ["--headless", "--path", str(ROOT), "--quit-after", "2"])]
    start = time.monotonic()
    stages = []
    status = "pass"
    for name, command in commands:
        tick = time.monotonic()
        try:
            result = subprocess.run([args.godot, *command], capture_output=True, timeout=max(0.1, 60 - (tick - start)))
            stdout, stderr, code = result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired as exc:
            stdout, stderr, code = exc.stdout or b"", exc.stderr or b"", -1
        (output / f"{name}-stdout.rawlog").write_bytes(stdout)
        (output / f"{name}-stderr.rawlog").write_bytes(stderr)
        errors = bool(re.search(rb"SCRIPT ERROR|ERROR:", stdout + stderr))
        passed = code == 0 and not errors
        if name == "core":
            core = output / "core.json"
            passed = passed and core.exists() and json.loads(core.read_text(encoding="utf-8"))["status"] == "pass"
        stages.append({"name": name, "exit": code, "engineErrors": errors, "seconds": round(time.monotonic() - tick, 3), "status": "pass" if passed else "fail"})
        if not passed:
            status = "fail"
            break
    drift = [p for p, h in hashes.items() if digest(ROOT / p) != h]
    if drift or digest(copied) != source_hash:
        status = "fail"
    execution = {"status": status, "seconds": round(time.monotonic() - start, 3), "budgetSeconds": 60, "stages": stages, "inputDrift": drift, "inputCopyUnchanged": digest(copied) == source_hash, "sourceSha256": source_hash, "maxAdditionalActionWindows": 3, "controlledRolls": False, "taskCompletionClaim": False}
    (output / "execution.json").write_text(json.dumps(execution, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(execution))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
