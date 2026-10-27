"""One explicitly authorized second-iteration strategy diagnostic, after baseline."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("balance_wrapper", ROOT / "tools/balance/verify.py")
balance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(balance)


def hashes():
    result = balance.hashes()
    for path in HERE.glob("*"):
        if path.is_file() and path.suffix in {".gd", ".py", ".md"}:
            result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return dict(sorted(result.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    parent_path = ROOT / "tools/balance/results.json"
    parent = json.loads(parent_path.read_text(encoding="utf-8"))
    expected = {(seed, strategy) for seed in [19, 42, 7919] for strategy in ["baseline", "aggressive", "conceal", "expansion"]}
    actual = {(c["seed"], c["strategy"]) for c in parent["campaigns"]}
    if parent["executionStatus"] != "complete" or expected != actual or len(parent["campaigns"]) != 12 or parent["sourceHashes"] != balance.hashes():
        raise RuntimeError("The actual frozen first 12 campaigns must finish before iteration 2")
    before = hashes()
    target = HERE / "runs/19-expansion"
    target.mkdir(parents=True, exist_ok=True)
    result_path = target / "result.json"
    if result_path.exists():
        result_path.unlink()
    command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(target / "godot.log"), "--script", "res://tools/balance/followup/run.gd", "--", str(target), "19", "expansion", "60"]
    with (target / "process.log").open("w", encoding="utf-8", newline="\n") as log:
        execution = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    raw = json.loads(result_path.read_text(encoding="utf-8"))
    trace = [json.loads(line) for line in (target / "trace.jsonl").read_text(encoding="utf-8").splitlines()]
    log = (target / "process.log").read_text(encoding="utf-8")
    errors = [line for line in log.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
    raw["phaseTimingsMs"] = {phase: balance.distribution([r["elapsed_ms"] for r in trace if r["type"] == "progress" and r["from"] == phase]) for phase in ["between", "events", "actions", "evolution", "settlement", "ending"]}
    raw["roundTimingsMs"] = balance.distribution([r["elapsed_ms"] for r in trace if r["type"] == "round"])
    checks = raw["checks"] + [{"id": "BAL-ITERATION2-PROCESS-001", "status": "pass" if execution.returncode == 0 and not errors else "fail", "evidence": {"exit": execution.returncode, "errors": errors}}, {"id": "BAL-ITERATION2-FIRST-CULT-001", "status": "pass" if raw["first_cult_turn"] >= 0 else "fail", "evidence": {"first_cult_turn": raw["first_cult_turn"]}}]
    if before != hashes():
        raise RuntimeError("Sources changed during iteration 2; no report published")
    artifacts = [result_path, target / "trace.jsonl", target / "process.log"]
    if raw["first_cult_turn"] >= 0: artifacts.append(target / "first-cult.json")
    result = {"status": "pass" if all(c["status"] == "pass" for c in checks) else "fail", "executionStatus": "complete", "iteration": 2, "generatedAt": datetime.now(timezone.utc).isoformat(), "sourceHashes": before, "checks": checks, "campaign": raw, "baseline": {"path": parent_path.relative_to(ROOT).as_posix(), "sha256": balance.sha(parent_path)}, "artifactHashes": {p.relative_to(ROOT).as_posix(): balance.sha(p) for p in artifacts}, "limitations": ["One seed and one revised event preference, separate from first-iteration distribution.", "The first-cult result does not prove higher-level institutions, propagation or victory reachable.", "No source mutation, no RNG override, no free population or resources."]}
    (HERE / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8", newline="\n")
    print(f"ITERATION2 {result['status']} {raw['status']} {raw['rounds']} rounds first_cult={raw['first_cult_turn']}")
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
