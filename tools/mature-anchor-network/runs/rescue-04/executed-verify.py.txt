"""One fixed seed/world: 72 logical stages, with a bounded original-phase tail."""
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
SPEC = importlib.util.spec_from_file_location("mature_shared", ROOT / "tools/cult-spread/verify.py")
SHARED = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SHARED)
SCRIPT = "res://tools/mature-anchor-network/run.gd"
STAGES = 72
RESUME_STAGE = 46
ROUND_STAGES = {46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70}
ACTION_STAGES = set(range(49, 70, 2))
TOOLS = {"tools/mature-anchor-network/run.gd", "tools/mature-anchor-network/verify.py"}


def inputs() -> dict[str, str]:
    result = SHARED.inputs([SCRIPT, "res://src/presentation/game_root.gd"])
    result[Path(__file__).relative_to(ROOT).as_posix()] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    return result


def read_prefix(directory: Path, current: dict[str, str]) -> tuple[dict, dict]:
    """Check the retained historical run; never rewrite its reports or snapshots."""
    execution = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    old = execution["sourceHashes"]
    assert old.keys() == current.keys()
    assert {name for name in old if old[name] != current[name]} == TOOLS
    assert execution["status"] == "fail" and execution["changedInputs"] == []
    assert len(execution["runs"]) == 48 and execution["runs"][-1]["label"] == "stage-46"
    assert execution["runs"][-1]["exit"] == -1 and not execution["runs"][-1]["passed"]
    assert all(row["passed"] and not row["engineErrors"] for row in execution["runs"][:-1])
    for name in ("run.gd", "verify.py"):
        assert hashlib.sha256((directory / ("executed-" + name + ".txt")).read_bytes()).hexdigest() == old["tools/mature-anchor-network/" + name]
    previous = None
    for stage in range(RESUME_STAGE):
        path = directory / f"stage-{stage:02d}.json"
        report = json.loads(path.read_text(encoding="utf-8"))
        assert report["stage"] == stage and report["status"] == "pass" and report["totalStages"] == STAGES
        assert hashlib.sha256(Path(report["snapshot"]).read_bytes()).hexdigest() == report["snapshotSha256"]
        if previous is None:
            assert report["restoreAttempted"] is False and report["restoreExact"] is None
        else:
            assert report["restoreAttempted"] is True and report["restoreExact"] is True
            assert report["parentSnapshotSha256"] == previous["snapshotSha256"]
            assert report["parentReport"] == str(directory / f"stage-{stage - 1:02d}.json")
        previous = report
    assert previous["state"]["phase"] == "actions"
    return execution, previous


def sequence_matches(report: dict, previous: dict, stage: int, part: int) -> bool:
    before = previous["state"]["commitSequence"]
    after = report.get("state", {}).get("commitSequence", -1)
    start = previous["nextRequestSequence"] if part > 0 else before + 1000 * stage
    return after >= before and report.get("nextRequestSequence") == start + after - before


def read_tail(directory: Path, prefix: Path, current: dict[str, str], previous: dict) -> tuple[dict, dict]:
    """Retain formal/resume successes; resume only the last complete original state."""
    execution = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    old = execution["sourceHashes"]
    assert old.keys() == current.keys()
    assert {name for name in old if old[name] != current[name]} == TOOLS
    assert execution["status"] == "fail" and execution["changedInputs"] == []
    assert len(execution["runs"]) == 15
    assert execution["runs"][-1]["label"] == "stage-49" and execution["runs"][-1]["exit"] == -1
    assert not execution["runs"][-1]["passed"] and not execution["runs"][-1]["engineErrors"]
    assert all(row["passed"] and not row["engineErrors"] for row in execution["runs"][:-1])
    assert execution["historicalPrefix"]["execution"] == str(prefix / "execution.json")
    assert execution["historicalPrefix"]["executionSha256"] == hashlib.sha256((prefix / "execution.json").read_bytes()).hexdigest()
    for name in ("run.gd", "verify.py"):
        assert hashlib.sha256((directory / ("executed-" + name + ".txt")).read_bytes()).hexdigest() == old["tools/mature-anchor-network/" + name]
    steps = [(46, part) for part in range(6)] + [(47, -1)] + [(48, part) for part in range(6)]
    parent_path = prefix / "stage-45.json"
    for index, (stage, part) in enumerate(steps, 1):
        label = f"stage-{stage:02d}" + (f"-part-{part}" if part >= 0 else "")
        assert execution["runs"][index]["label"] == label
        path = directory / (label + ".json")
        report = json.loads(path.read_text(encoding="utf-8"))
        assert report["status"] == "pass" and report["stage"] == stage and report["roundPart"] == part and report["totalStages"] == STAGES
        assert report["snapshot"] == str(directory / (label + ".turn.json"))
        assert hashlib.sha256(Path(report["snapshot"]).read_bytes()).hexdigest() == report["snapshotSha256"]
        assert report["restoreAttempted"] is True and report["restoreExact"] is True and report["continuationKind"] == "original_restore"
        assert report["parentReport"] == str(parent_path) and report["parentSnapshotSha256"] == previous["snapshotSha256"]
        assert sequence_matches(report, previous, stage, part)
        assert report["state"]["phase"] == (["evolution", "settlement", "ending", "between", "events", "actions"][part] if part >= 0 else "actions")
        previous, parent_path = report, path
    assert hashlib.sha256(parent_path.read_bytes()).hexdigest() == "b3fabca38b4c48f7b56ce964ca2efecfd65e516fef5b337df79035d3cafc6e99"
    assert previous["snapshotSha256"] == "d3d61b0b9353d4b0dce79fe1c9e1a6fee8958540d2d8ea614e72a3bb52b87872"
    return execution, previous


def make_jobs(output: Path, prefix: Path | None, tail: Path | None, repair: Path | None = None, finish: Path | None = None) -> list:
    jobs = [("parse", ["--check-only", "--script", SCRIPT], None, -1, None)]
    parent_path = repair / "stage-55-part-0.json" if repair else (tail / "stage-48-part-5.json" if tail else (prefix / "stage-45.json" if prefix else None))
    start = 55 if repair else (49 if tail else (RESUME_STAGE if prefix else 0))
    if finish:
        parent_path = finish / "stage-55-part-1.json"
        name = "stage-55-part-2"
        jobs.append((name, ["--script", SCRIPT, "--", str(output / (name + ".json")), "55", str(parent_path), "2"], 55, 2, parent_path))
        parent_path = output / (name + ".json")
        start = 56
    for stage in range(start, STAGES):
        parts = range(6) if prefix and stage in ROUND_STAGES else (range(2) if tail and stage in ACTION_STAGES else [-1])
        if repair and stage == 55: parts = range(1, 2)
        for part in parts:
            name = f"stage-{stage:02d}" + (f"-part-{part}" if part >= 0 else "")
            options = ["--script", SCRIPT, "--", str(output / (name + ".json")), str(stage)]
            if stage: options.append(str(parent_path))
            if part >= 0: options.append(str(part))
            jobs.append((name, options, stage, part, parent_path))
            parent_path = output / (name + ".json")
    if prefix: assert len(jobs) - 1 == (64 if repair else (89 if tail else 91))
    jobs.append(("dev", ["--quit-after", "2"], None, -1, None))
    return jobs


def read_repair(directory: Path, prefix: Path, tail: Path, current: dict[str, str], previous: dict) -> tuple[dict, dict]:
    """Check 25 successful repair calls without adopting its timed-out attempt."""
    execution = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    old = execution["sourceHashes"]
    assert old.keys() == current.keys()
    assert {name for name in old if old[name] != current[name]} == TOOLS
    assert execution["status"] == "fail" and execution["changedInputs"] == []
    assert len(execution["runs"]) == 27
    assert execution["runs"][-1]["label"] == "stage-55-part-1" and execution["runs"][-1]["exit"] == -1
    assert not execution["runs"][-1]["passed"] and not execution["runs"][-1]["engineErrors"]
    assert all(row["passed"] and not row["engineErrors"] for row in execution["runs"][:-1])
    for field, origin in (("historicalPrefix", prefix), ("historicalTail", tail)):
        assert execution[field]["execution"] == str(origin / "execution.json")
        assert execution[field]["executionSha256"] == hashlib.sha256((origin / "execution.json").read_bytes()).hexdigest()
    for name in ("run.gd", "verify.py"):
        assert hashlib.sha256((directory / ("executed-" + name + ".txt")).read_bytes()).hexdigest() == old["tools/mature-anchor-network/" + name]
    steps = [row for row in make_jobs(directory, prefix, tail) if row[2] is not None][:25]
    assert steps[-1][0] == "stage-55-part-0"
    for index, (label, _, stage, part, parent_path) in enumerate(steps, 1):
        assert execution["runs"][index]["label"] == label
        path = directory / (label + ".json")
        report = json.loads(path.read_text(encoding="utf-8"))
        assert report["status"] == "pass" and report["stage"] == stage and report["roundPart"] == part and report["totalStages"] == STAGES
        assert report["snapshot"] == str(directory / (label + ".turn.json"))
        assert hashlib.sha256(Path(report["snapshot"]).read_bytes()).hexdigest() == report["snapshotSha256"]
        assert report["restoreAttempted"] is True and report["restoreExact"] is True and report["continuationKind"] == "original_restore"
        assert report["parentReport"] == str(parent_path) and report["parentSnapshotSha256"] == previous["snapshotSha256"]
        assert sequence_matches(report, previous, stage, part)
        assert report["state"]["phase"] == (["evolution", "settlement", "ending", "between", "events", "actions"][part] if stage in ROUND_STAGES else "actions")
        if stage in ACTION_STAGES:
            actions = report["actions"]
            assert (len(actions) <= 1 and all(row["stage"] == "actual_required_person_response" for row in actions) if part == 0 else all(row["stage"] != "actual_required_person_response" for row in actions))
        previous = report
    assert hashlib.sha256((directory / "stage-55-part-0.json").read_bytes()).hexdigest() == "5e7dc003266b17b5e7189362f85f95db19412e1ce8fdd86b94ed4bbb6c4a3816"
    assert previous["snapshotSha256"] == "6cb30df90216e76d9e336bc72d5c9624807549782322863026bec4ec9ef49d9d"
    assert previous["nextRequestSequence"] == 55203 and previous["state"]["commitSequence"] == 203
    return execution, previous


def read_finish(directory: Path, prefix: Path, tail: Path, repair: Path, current: dict[str, str], previous: dict) -> tuple[dict, dict]:
    """Adopt only the one living stage-55-part-1 success, before the dead branch."""
    execution = json.loads((directory / "execution.json").read_text(encoding="utf-8"))
    old = execution["sourceHashes"]
    assert old.keys() == current.keys()
    assert {name for name in old if old[name] != current[name]} == TOOLS
    assert execution["status"] == "fail" and execution["changedInputs"] == [] and len(execution["runs"]) == 12
    assert execution["runs"][0]["label"] == "parse" and execution["runs"][0]["passed"]
    assert execution["runs"][1]["label"] == "stage-55-part-1" and execution["runs"][1]["passed"] and not execution["runs"][1]["engineErrors"]
    assert execution["runs"][-1]["label"] == "stage-58-part-1" and not execution["runs"][-1]["passed"]
    for field, origin in (("historicalPrefix", prefix), ("historicalTail", tail), ("historicalRepair", repair)):
        assert execution[field]["execution"] == str(origin / "execution.json")
        assert execution[field]["executionSha256"] == hashlib.sha256((origin / "execution.json").read_bytes()).hexdigest()
    for name in ("run.gd", "verify.py"):
        assert hashlib.sha256((directory / ("executed-" + name + ".txt")).read_bytes()).hexdigest() == old["tools/mature-anchor-network/" + name]
    path = directory / "stage-55-part-1.json"
    assert hashlib.sha256(path.read_bytes()).hexdigest() == "c9d5558c040926f06d47002c29030caa30097aa0995bd06f94faa299890931c3"
    report = json.loads(path.read_text(encoding="utf-8"))
    assert report["status"] == "pass" and report["stage"] == 55 and report["roundPart"] == 1 and report["totalStages"] == STAGES
    assert report["snapshot"] == str(directory / "stage-55-part-1.turn.json")
    assert report["snapshotSha256"] == "37ec415d29447a62041fc9a31079399ada350bdf6198568befce3bf0d0321d32"
    assert hashlib.sha256(Path(report["snapshot"]).read_bytes()).hexdigest() == report["snapshotSha256"]
    assert report["restoreAttempted"] is True and report["restoreExact"] is True and report["continuationKind"] == "original_restore"
    assert report["parentReport"] == str(repair / "stage-55-part-0.json") and report["parentSnapshotSha256"] == previous["snapshotSha256"]
    assert sequence_matches(report, previous, 55, 1) and report["nextRequestSequence"] == 55204
    assert report["state"]["turn"] == 28 and report["state"]["phase"] == "actions" and report["state"]["awakening"] == 73
    body = json.loads(Path(report["snapshot"]).read_text(encoding="utf-8"))["body"]
    state = json.loads(body["world"])["body"]["state"]
    assert body["context"]["responses"] == 0 and state["whispers"] == 3
    request = state["prayer_system"]["requests"]["BACKGROUND-00000045"]
    assert request["status"] == "open" and "BACKGROUND-00000045" in state["prayer_system"]["offered"]
    assert request["descriptor"]["subjects"] == {"petitioner": "NPC-00000039", "relative": "NPC-00000013"}
    assert request["descriptor"]["facts"]["condition"] == "FACT-00002211" and request["descriptor"]["crisis"]["due"] == 28
    assert "FACT-00002211" not in state["invalid_records"]
    assert all(state["npcs"][person]["status"] == "active" for person in ("NPC-00000013", "NPC-00000039"))
    return execution, report


def response_only(actions: list) -> bool:
    allowed = {"actual_required_person_response", "required_guardian_rescue_prepare", "actual_required_guardian_cure"}
    return sum(row["stage"] == "actual_required_person_response" for row in actions) <= 1 and all(row["stage"] in allowed for row in actions)


def rescue_report_valid(row: dict) -> bool:
    """Require the complete measured closure and its two detached counterexamples."""
    names = {"resolution_kind", "resolution_crisis", "resolution_due", "resolution_root", "resolution_parents", "closed_kind", "closed_request", "closed_crisis", "closed_reason", "closed_parents", "request_removed", "crisis_removed", "response_result", "root_invalidated_to_cure", "resolution_identity", "closed_identity", "original_condition_cured", "patient_active", "one_response", "original_faith_cost", "original_whispers_cost", "wrong_result_parent_rejected", "wrong_closed_resolution_rejected"}
    predicates = row.get("predicates", {})
    resolution = row.get("crisisResolution", {})
    closed = row.get("closedReceipt", {})
    crisis = row.get("crisis", {})
    return (row.get("valid") is True and predicates.keys() == names
            and all(value is True for value in predicates.values()) and row.get("failedPredicates") == []
            and row.get("counterexamples") == {"wrong-result-parent": ["resolution_parents"], "wrong-closed-resolution": ["closed_parents"]}
            and resolution.get("id") == row.get("resolutionId") and closed.get("id") == row.get("closedId")
            and row.get("rootInvalidatedBy") == row.get("cure", {}).get("id") == row.get("responseResult", {}).get("changes", {}).get("produced", {}).get("condition_cured")
            and resolution.get("kind") == "prayer_crisis_resolved"
            and resolution.get("changes", {}) == {"crisis": crisis.get("id"), "due": crisis.get("due")}
            and crisis.get("source") == row.get("root")
            and resolution.get("causal_parents") == [row.get("root"), row.get("resultId")]
            and closed.get("kind") == "prayer_closed"
            and closed.get("changes", {}) == {"request": row.get("request"), "reason": "resolved", "crisis": crisis.get("id")}
            and closed.get("causal_parents") == [row.get("registered"), row.get("resolutionId")]
            and row.get("faithPaid") == 0 and row.get("whispersPaid") == 1)


def call_budget(limit: float, remaining: float | None) -> float:
    return limit if remaining is None else max(0.0, min(limit, remaining))


def read_interrupted(directory: Path, prefix: Path, tail: Path, repair: Path, finish: Path, current: dict[str, str], previous: dict) -> dict:
    """Accept only the 48 complete rescue-03 states, never its interrupted call."""
    assert not (directory / "execution.json").exists()
    old = json.loads((directory / "input-sha256.json").read_text(encoding="utf-8"))
    assert old.keys() == current.keys()
    assert {name for name in old if old[name] != current[name]} == {"tools/mature-anchor-network/verify.py"}
    for name in ("run.gd", "verify.py"):
        assert hashlib.sha256((directory / ("executed-" + name + ".txt")).read_bytes()).hexdigest() == old["tools/mature-anchor-network/" + name]
    jobs = [row for row in make_jobs(directory, prefix, tail, repair, finish) if row[2] is not None]
    present = {path.stem for path in directory.glob("stage-*.json") if not path.name.endswith(".turn.json")}
    assert present == {job[0] for job in jobs[:48]}
    for label, _, stage, part, parent_path in jobs[:48]:
        report = json.loads((directory / (label + ".json")).read_text(encoding="utf-8"))
        assert report["status"] == "pass" and report["stage"] == stage and report["roundPart"] == part and report["totalStages"] == STAGES
        assert report["snapshot"] == str(directory / (label + ".turn.json"))
        assert hashlib.sha256(Path(report["snapshot"]).read_bytes()).hexdigest() == report["snapshotSha256"]
        assert report["restoreAttempted"] is True and report["restoreExact"] is True and report["continuationKind"] == "original_restore"
        assert report["parentReport"] == str(parent_path) and report["parentSnapshotSha256"] == previous["snapshotSha256"]
        assert sequence_matches(report, previous, stage, part)
        assert report["state"]["phase"] == (["evolution", "settlement", "ending", "between", "events", "actions"][part] if stage in ROUND_STAGES else "actions")
        if stage in ACTION_STAGES:
            actions = report["actions"]
            if stage == 55 and part == 2:
                assert [row["stage"] for row in actions] == ["required_guardian_rescue_prepare", "actual_required_person_response", "actual_required_guardian_cure"]
                assert actions[0]["pure"] is True and actions[0]["result"]["ok"] is True and rescue_report_valid(actions[2])
            else:
                assert response_only(actions) if part == 0 else all(row["stage"] != "actual_required_person_response" for row in actions)
        logs = [(directory / (label + suffix)).read_bytes() for suffix in ("-stdout.rawlog", "-stderr.rawlog", "-engine.rawlog")]
        assert not any(marker in b"".join(logs) for marker in (b"ERROR:", b"SCRIPT ERROR", b"Parse Error"))
        assert b"MATURE_STAGE" in logs[0]
        previous = report
    last = directory / "stage-67-part-0.json"
    assert hashlib.sha256(last.read_bytes()).hexdigest() == "3674300c61c4dc4cf864452658b04ca3c60106d31da22c55d0a2b9fe2d4ea715"
    assert previous["snapshotSha256"] == "abb9a974639d9e6f1bfe5a043ca0ca37ac0619830ace316d5a2a11cedef85658"
    assert previous["nextRequestSequence"] == 67251
    return previous


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--resume-prefix", type=Path, help="Retained formal-01 directory; resume its exact stage-45 snapshot")
    parser.add_argument("--resume-tail", type=Path, help="Retained resume-01; split response/main actions after exact stage-48-part-5")
    parser.add_argument("--resume-repair", type=Path, help="Retained repair-01; resume exact stage-55-part-0 with 120s/call and 5400s total")
    parser.add_argument("--resume-finish", type=Path, help="Retained finish-01; adopt only living stage-55-part-1, rescue once, then original 63 tail calls; 240s/call and 5400s total")
    parser.add_argument("--resume-rescue", type=Path, help="Interrupted rescue-03; retain exactly 48 complete calls and run only the remaining 16 with 240s/call and 3000s total")
    args = parser.parse_args()
    if args.resume_tail and not args.resume_prefix: parser.error("--resume-tail requires --resume-prefix")
    if args.resume_repair and not args.resume_tail: parser.error("--resume-repair requires --resume-tail and --resume-prefix")
    if args.resume_finish and not args.resume_repair: parser.error("--resume-finish requires --resume-repair, --resume-tail and --resume-prefix")
    if args.resume_rescue and not args.resume_finish: parser.error("--resume-rescue requires the original four retained prefixes")
    output = args.output.resolve()
    before = inputs()
    prefix = args.resume_prefix.resolve() if args.resume_prefix else None
    historical, previous = read_prefix(prefix, before) if prefix else (None, None)
    tail = args.resume_tail.resolve() if args.resume_tail else None
    tail_history, previous = read_tail(tail, prefix, before, previous) if tail else (None, previous)
    repair = args.resume_repair.resolve() if args.resume_repair else None
    repair_history, previous = read_repair(repair, prefix, tail, before, previous) if repair else (None, previous)
    finish = args.resume_finish.resolve() if args.resume_finish else None
    finish_history, previous = read_finish(finish, prefix, tail, repair, before, previous) if finish else (None, previous)
    rescue = args.resume_rescue.resolve() if args.resume_rescue else None
    if rescue: previous = read_interrupted(rescue, prefix, tail, repair, finish, before, previous)
    invocation_limit = 240 if finish else (120 if repair else 58)
    total_limit = 3000 if rescue else (5400 if repair else None)
    output.mkdir(parents=True, exist_ok=False)
    (output / "input-sha256.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
    for name in ("run.gd", "verify.py"):
        (output / ("executed-" + name + ".txt")).write_bytes((ROOT / "tools/mature-anchor-network" / name).read_bytes())
    runs = []
    jobs = make_jobs(output, prefix, tail, repair, finish)
    if rescue:
        jobs = [jobs[0], *jobs[49:]]
        label, options, stage, part, _ = jobs[1]
        assert label == "stage-67-part-1" and len(jobs) == 18
        parent = rescue / "stage-67-part-0.json"
        options[options.index(str(output / "stage-67-part-0.json"))] = str(parent)
        jobs[1] = (label, options, stage, part, parent)
    reports = []
    batch_started = time.perf_counter()
    for label, options, stage, part, expected_parent in jobs:
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(output / (label + "-engine.rawlog"))] + options
        started = time.perf_counter()
        budget = call_budget(invocation_limit, total_limit - (started - batch_started) if total_limit is not None else None)
        if budget <= 0:
            stdout, stderr, code = b"", b"Total batch budget exhausted before launch", -1
        else:
            try:
                process = subprocess.run(command, capture_output=True, timeout=budget)
                stdout, stderr, code = process.stdout, process.stderr, process.returncode
            except subprocess.TimeoutExpired as error:
                stdout, stderr, code = error.stdout or b"", error.stderr or b"", -1
        (output / (label + "-stdout.rawlog")).write_bytes(stdout)
        (output / (label + "-stderr.rawlog")).write_bytes(stderr)
        engine = output / (label + "-engine.rawlog")
        raw = stdout + stderr + (engine.read_bytes() if engine.exists() else b"")
        errors = any(marker in raw for marker in (b"ERROR:", b"SCRIPT ERROR", b"Parse Error"))
        passed = code == 0 and not errors
        if stage is not None:
            report_path = output / (label + ".json")
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
            snapshot_path = Path(report.get("snapshot", "missing"))
            snapshot_hash = hashlib.sha256(snapshot_path.read_bytes()).hexdigest() if snapshot_path.is_file() else ""
            passed = passed and report.get("status") == "pass" and report.get("stage") == stage and report.get("roundPart") == part and report.get("totalStages") == STAGES and snapshot_hash == report.get("snapshotSha256")
            if stage:
                passed = passed and report.get("restoreAttempted") is True and report.get("restoreExact") is True and report.get("continuationKind") == "original_restore" and report.get("parentSnapshotSha256") == previous["snapshotSha256"] and report.get("parentReport") == str(expected_parent)
                passed = passed and sequence_matches(report, previous, stage, part)
                if part >= 0:
                    expected_phase = ["evolution", "settlement", "ending", "between", "events", "actions"][part] if stage in ROUND_STAGES else "actions"
                    passed = passed and report.get("state", {}).get("phase") == expected_phase
                    if stage in ACTION_STAGES and not (stage == 55 and part == 2):
                        actions = report.get("actions", [])
                        passed = passed and (response_only(actions) if part == 0 else all(row["stage"] != "actual_required_person_response" for row in actions))
                    if stage == 55 and part == 2:
                        actions = report.get("actions", [])
                        passed = passed and [row["stage"] for row in actions] == ["required_guardian_rescue_prepare", "actual_required_person_response", "actual_required_guardian_cure"] and actions[0].get("pure") is True and actions[0].get("result", {}).get("ok") is True and rescue_report_valid(actions[2])
            else:
                passed = passed and report.get("restoreAttempted") is False and report.get("restoreExact") is None and report.get("continuationKind") == "initial_baseline" and report.get("parentSnapshotSha256") == "" and report.get("parentReport") == ""
            reports.append(report)
            previous = report
        row = {"label": label, "command": command, "exit": code, "seconds": round(time.perf_counter() - started, 3), "timeBudgetSeconds": budget, "engineErrors": errors, "passed": bool(passed)}
        runs.append(row)
        print(json.dumps(row), flush=True)
        if not passed:
            break
    after = inputs()
    changed = sorted(name for name in before.keys() | after.keys() if before.get(name) != after.get(name))
    passed = len(runs) == len(jobs) and not changed and all(row["passed"] for row in runs)
    result = {"status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(), "sourceHashes": before, "changedInputs": changed, "runs": runs, "seconds": round(sum(row["seconds"] for row in runs), 3), "perInvocationLimitSeconds": invocation_limit, "totalBudgetSeconds": total_limit, "totalElapsedSeconds": round(time.perf_counter() - batch_started, 3), "fixedStageLimit": STAGES, "fixedTailInvocations": 16 if rescue else ((64 if repair else (89 if tail else 91)) if prefix else None),
              "historicalInterruptedRescue": {"directory": str(rescue), "interruptionManifest": str(rescue.parent / "rescue-03-interruption.json"), "interruptionManifestSha256": hashlib.sha256((rescue.parent / "rescue-03-interruption.json").read_bytes()).hexdigest(), "retainedCompleteInvocations": 48, "parentReport": str(rescue / "stage-67-part-0.json"), "parentSnapshotSha256": "abb9a974639d9e6f1bfe5a043ca0ca37ac0619830ace316d5a2a11cedef85658", "missingExecution": True, "excludedInvocation": "stage-67-part-1: partial engine log only; no report or snapshot", "scope": "Complete reports, snapshots and raw logs revalidated; original aggregate exit codes/timings unavailable after external interruption."} if rescue else None,
              "historicalPrefix": {"execution": str(prefix / "execution.json"), "executionSha256": hashlib.sha256((prefix / "execution.json").read_bytes()).hexdigest(), "stages": [0, 45], "resumeSnapshotSha256": json.loads((prefix / "stage-45.json").read_text())["snapshotSha256"], "toolInputDifferences": sorted(TOOLS), "originalBatchStatus": historical["status"]} if prefix else None,
              "historicalTail": {"execution": str(tail / "execution.json"), "executionSha256": hashlib.sha256((tail / "execution.json").read_bytes()).hexdigest(), "stages": [46, 48], "successfulInvocations": 13, "parentReport": str(tail / "stage-48-part-5.json"), "parentSnapshotSha256": "d3d61b0b9353d4b0dce79fe1c9e1a6fee8958540d2d8ea614e72a3bb52b87872", "toolInputDifferences": sorted(TOOLS), "originalBatchStatus": tail_history["status"]} if tail else None,
              "historicalRepair": {"execution": str(repair / "execution.json"), "executionSha256": hashlib.sha256((repair / "execution.json").read_bytes()).hexdigest(), "successfulInvocations": 25, "parentReport": str(repair / "stage-55-part-0.json"), "parentSnapshotSha256": "6cb30df90216e76d9e336bc72d5c9624807549782322863026bec4ec9ef49d9d", "nextRequestSequence": 55203, "toolInputDifferences": sorted(TOOLS), "originalBatchStatus": repair_history["status"]} if repair else None,
              "historicalFinish": {"execution": str(finish / "execution.json"), "executionSha256": hashlib.sha256((finish / "execution.json").read_bytes()).hexdigest(), "retainedSuccessfulInvocations": 1, "parentReport": str(finish / "stage-55-part-1.json"), "parentSnapshotSha256": "37ec415d29447a62041fc9a31079399ada350bdf6198568befce3bf0d0321d32", "nextRequestSequence": 55204, "toolInputDifferences": sorted(TOOLS), "originalBatchStatus": finish_history["status"], "excludedBranch": "All finish-01 stage-56 and later reports; guardian died after the causal fork"} if finish else None,
              "logicalGroups": {"planet": [0, 22], "system": [23, 40], "cosmic": [41, 70], "final": [71, 71]},
              "baseline": {"report": str(output / "stage-71.json"), "snapshot": str(output / "stage-71.turn.json")} if passed else None,
              "scope": "One original full-Catalog world, actual production and current payments. Component continuation only; no full Session save or recovery/victory claim."}
    (output / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
