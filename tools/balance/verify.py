"""Run one frozen sequential 12-campaign strategy audit; preserve negative evidence."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ui_wrapper", ROOT / "tools/ui/verify.py")
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes():
    result = ui.hashes()
    for pattern in ["tools/balance/*.gd", "tools/balance/*.py", "tools/balance/*.md"]:
        for path in ROOT.glob(pattern):
            result[path.relative_to(ROOT).as_posix()] = sha(path)
    result["docs/tasks/slice-13.md"] = sha(ROOT / "docs/tasks/slice-13.md")
    return dict(sorted(result.items()))


def distribution(values):
    if not values:
        return {"count": 0}
    ordered = sorted(values)
    return {"count": len(values), "min": ordered[0], "median": statistics.median(values),
            "p95": ordered[min(len(ordered)-1, int(len(ordered)*.95))], "max": ordered[-1], "total": sum(values)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--explore", action="store_true", help="One 19/expansion campaign; never writes formal results")
    parser.add_argument("--limit", type=int, default=60)
    args = parser.parse_args()
    if not 1 <= args.limit <= 60:
        raise SystemExit("limit must be 1..60")
    before = hashes()
    directory = HERE / ("exploration-full" if args.explore else "runs")
    directory.mkdir(exist_ok=True)
    campaigns = []
    checks = []
    cases = [(19, "expansion")] if args.explore else [(seed, strategy) for seed in [19, 42, 7919] for strategy in ["baseline", "aggressive", "conceal", "expansion"]]
    for seed, strategy in cases:
        target = directory / f"{seed}-{strategy}"
        target.mkdir(exist_ok=True)
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(target / "godot.log"), "--script", "res://tools/balance/run.gd", "--", str(target), str(seed), strategy, str(args.limit)]
        print(f"START {seed}/{strategy}", flush=True)
        with (target / "process.log").open("w", encoding="utf-8", newline="\n") as log:
            completed = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, text=True, timeout=900)
        raw_path = target / "result.json"
        if not raw_path.exists():
            raise RuntimeError(f"Missing result for {seed}/{strategy}; partial JSONL preserved")
        raw = json.loads(raw_path.read_text(encoding="utf-8"))
        text = (target / "process.log").read_text(encoding="utf-8")
        raw["processExitCode"] = completed.returncode
        raw["godotErrors"] = [line for line in text.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
        lines = [json.loads(line) for line in (target / "trace.jsonl").read_text(encoding="utf-8").splitlines()]
        raw["phaseTimingsMs"] = {phase: distribution([line["elapsed_ms"] for line in lines if line["type"] == "progress" and line["from"] == phase]) for phase in ["between", "events", "actions", "evolution", "settlement", "ending"]}
        raw["roundTimingsMs"] = distribution([line["elapsed_ms"] for line in lines if line["type"] == "round"])
        raw["artifactHashes"] = {path.relative_to(ROOT).as_posix(): sha(path) for path in [raw_path, target / "trace.jsonl", target / "process.log"]}
        raw["commandCounts"] = {kind: sum(line["type"] == kind for line in lines) for kind in ["action", "progress", "plan"]}
        raw["actionResults"] = {"accepted": sum(line["type"] == "action" and line["result"]["ok"] for line in lines), "rejected": sum(line["type"] == "action" and not line["result"]["ok"] for line in lines)}
        campaigns.append(raw)
        for check in raw["checks"]:
            checks.append({**check, "id": f"{check['id']}/{seed}/{strategy}"})
        checks.append({"id": f"BAL-PROCESS-001/{seed}/{strategy}", "status": "pass" if completed.returncode == 0 and not raw["godotErrors"] else "fail", "evidence": {"exit": completed.returncode, "errors": raw["godotErrors"]}})
        print(f"DONE {seed}/{strategy}: {raw['status']} round={raw['rounds']} first_cult={raw['first_cult_turn']} faith={raw['final']['faith']} members={len(raw['final']['members'])}", flush=True)
        # Persist each campaign immediately. The aggregate explicitly stays running.
        (directory / "progress.json").write_text(json.dumps({"status": "running", "sourceHashes": before, "campaigns": campaigns}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        if before != hashes():
            raise RuntimeError("Sources changed during strategy audit; partial evidence preserved, not published")
    checks.append({"id": "BAL-FIRST-CULT-001", "status": "pass" if any(c["first_cult_turn"] >= 0 for c in campaigns) else "fail", "evidence": {"campaignsWithCult": sum(c["first_cult_turn"] >= 0 for c in campaigns), "finiteSearchOnly": True}})
    expected_count = 1 if args.explore else 12
    checks.append({"id": "BAL-COVERAGE-001", "status": "pass" if len(campaigns) == expected_count and all(c["status"] in ["ended", "censored"] for c in campaigns) else "fail", "evidence": {"campaigns": len(campaigns), "limit": args.limit}})
    result = {"status": "pass" if all(c["status"] == "pass" for c in checks) else "fail", "executionStatus": "complete", "generatedAt": datetime.now(timezone.utc).isoformat(), "sourceHashes": before, "checks": checks, "campaigns": campaigns, "environment": {"engine": campaigns[0]["engine"], "platform": platform.platform(), "python": platform.python_version(), "headless": True}, "limitations": ["A surviving run at turn limit is censored, not a completed failure.", "Finite strategies and seeds cannot prove absence of dominance or global reachability.", "Only player projection and known sources enter Policy; hidden state is diagnostics only.", "No mutation of resources, population, RNG or eligibility; all actions pass the real Session and production rules.", "Godot headless timings include Session projection, requests and automatic saves; they are not target-platform frame budgets."]}
    destination = directory / "results.json" if args.explore else HERE / "results.json"
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8", newline="\n")
    print(f"COMPLETE {len(campaigns)} campaigns, {len(checks)} checks, result={result['status']}; {destination}")
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
