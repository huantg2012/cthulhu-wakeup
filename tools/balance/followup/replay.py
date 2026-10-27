"""Repeat the identical iteration-2 policy through its first-cult safe point."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("iteration_wrapper", HERE / "verify.py")
iteration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(iteration)


def safe_point(directory):
    body = json.loads((directory / "first-cult.json").read_text(encoding="utf-8"))
    campaign = body["campaign"]
    # Only Session's wall-clock campaign identity changes. All RNG and rule
    # identities, command sequence, facts, receipts and knowledge must agree.
    normalized = json.dumps(body, ensure_ascii=False, sort_keys=True).replace(campaign, "<campaign>")
    return json.loads(normalized)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    original_path = HERE / "results.json"
    original = json.loads(original_path.read_text(encoding="utf-8"))
    before = iteration.hashes()
    if original["sourceHashes"] != before or original["campaign"]["first_cult_turn"] < 0:
        raise RuntimeError("Replay requires an actually observed first cult and current iteration-2 sources")
    target = HERE / "runs/replay-19-expansion"
    target.mkdir(parents=True, exist_ok=True)
    result_path = target / "result.json"
    if result_path.exists(): result_path.unlink()
    safe_path = target / "first-cult.json"
    if safe_path.exists(): safe_path.unlink()
    command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(target / "godot.log"), "--script", "res://tools/balance/followup/run.gd", "--", str(target), "19", "expansion", str(original["campaign"]["first_cult_turn"])]
    with (target / "process.log").open("w", encoding="utf-8", newline="\n") as log:
        execution = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    repeated = json.loads(result_path.read_text(encoding="utf-8"))
    log = (target / "process.log").read_text(encoding="utf-8")
    errors = [line for line in log.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
    first = safe_point(HERE / "runs/19-expansion")
    second = safe_point(target)
    equivalent = first == second
    checks = [{"id": "BAL-REPLAY-001", "status": "pass" if equivalent else "fail", "evidence": {"entireTurnSnapshotAndKnownCollectionsEqual": equivalent, "comparedFields": sorted(first), "firstCultTurn": [original["campaign"]["first_cult_turn"], repeated["first_cult_turn"]]}}, {"id": "BAL-REPLAY-PROCESS-001", "status": "pass" if execution.returncode == 0 and not errors and all(c["status"] == "pass" for c in repeated["checks"]) else "fail", "evidence": {"exit": execution.returncode, "errors": errors}}]
    if before != iteration.hashes(): raise RuntimeError("Sources changed during replay")
    report = {"status": "pass" if all(c["status"] == "pass" for c in checks) else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "kind": "actual-identical-policy-reexecution", "sourceHashes": before, "checks": checks, "parent": {"path": original_path.relative_to(ROOT).as_posix(), "sha256": iteration.balance.sha(original_path)}, "artifactHashes": {p.relative_to(ROOT).as_posix(): iteration.balance.sha(p) for p in [result_path, target / "trace.jsonl", target / "process.log", target / "first-cult.json"]}, "limitations": ["Same engine, same host and same sources; not cross-platform or cross-version determinism.", "Only Session's wall-clock campaign identity is normalized; complete first-cult Turn snapshot and known collections are compared."]}
    (HERE / "replay-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8", newline="\n")
    print(f"ACTUAL REPLAY {report['status']} entire_safe_point_equal={equivalent}")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
