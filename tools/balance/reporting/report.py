"""Archive and analyse a frozen strategy run without rerunning or rewriting it.

Campaign provenance is checked against its original inputs. Reporting has its
own fingerprint, separate from the scripts actually used to run the campaigns.
The command also works from the committed baseline and compressed traces.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / "docs/qa"
BASELINE = QA / "balance-baseline.json"
OUTPUT = QA / "balance-results.json"
ARCHIVES = QA / "balance-traces"
EXPECTED = {(s, p) for s in (19, 42, 7919)
            for p in ("baseline", "aggressive", "conceal", "expansion")}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def project_file(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f"Missing or unsafe evidence path: {relative}")
    return path


def write_json(path: Path, data: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                         encoding="utf-8", newline="\n")
    temporary.replace(path)


def distribution(values: list[float]) -> dict:
    if not values:
        return {"count": 0}
    ordered = sorted(values)
    return {"count": len(values), "min": ordered[0],
            "median": statistics.median(ordered),
            "p95": ordered[max(0, math.ceil(.95 * len(ordered)) - 1)],
            "max": ordered[-1]}


def execution_hashes() -> dict:
    spec = importlib.util.spec_from_file_location("balance_execution", ROOT / "tools/balance/verify.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.hashes()


def validate_campaign_metadata(campaign: dict, original: dict) -> None:
    for key, value in original.items():
        if campaign.get(key) != value:
            raise ValueError(f"Campaign metadata differs from raw result: {key}")


def archived_bytes(relative: str, digest: str, prefix: str, archive_only: bool = False) -> tuple[bytes, dict]:
    original = (ROOT / relative).resolve()
    if not original.is_relative_to(ROOT):
        raise ValueError(f"Unsafe artifact path: {relative}")
    target = ARCHIVES / (prefix + "-" + Path(relative).name + ".gz")
    if not archive_only and original.is_file():
        raw = original.read_bytes()
        if sha(raw) != digest:
            raise ValueError(f"Artifact changed since actual execution: {relative}")
        target.write_bytes(gzip.compress(raw, mtime=0))
    elif target.is_file():
        raw = gzip.decompress(target.read_bytes())
    else:
        raise ValueError(f"Neither raw nor archived artifact exists: {relative}")
    if sha(raw) != digest:
        raise ValueError(f"Corrupt archived evidence: {relative}")
    return raw, {"path": target.relative_to(ROOT).as_posix(),
                 "sha256": sha(target.read_bytes()), "rawSha256": digest,
                 "rawBytes": len(raw), "compressedBytes": target.stat().st_size}


def analyse(baseline: dict, baseline_digest: str | None = None, archive_only: bool = False) -> dict:
    if baseline.get("executionStatus") != "complete":
        raise ValueError("A partial run cannot be published as completed evidence")
    sources = dict(baseline["sourceHashes"])
    if set(sources) != set(execution_hashes()):
        raise ValueError("Execution source inventory is incomplete or changed")
    for path, recorded in sources.items():
        if sha(project_file(path).read_bytes()) != recorded:
            raise ValueError(f"Execution input is stale: {path}; actually rerun campaigns")
    campaigns = baseline["campaigns"]
    pairs = [(c["seed"], c["strategy"]) for c in campaigns]
    if set(pairs) != EXPECTED or len(pairs) != len(EXPECTED):
        raise ValueError("Missing, extra or duplicate campaign identities")
    if any(c["limit"] != 60 for c in campaigns):
        raise ValueError("Formal distribution requires the registered 60-turn limit")
    ARCHIVES.mkdir(exist_ok=True)
    artifacts, summaries = {}, []
    phase_costs, observed_strategies = defaultdict(list), Counter()
    effective_strategy_facts, seen_economy_facts = Counter(), set()
    expected_execution_checks = []
    invariant_records, zero_resource_records = [], []
    all_turns, statuses = 0, Counter()
    for campaign in campaigns:
        prefix = f"{campaign['seed']}-{campaign['strategy']}"
        traces, original_result, process_text = None, None, None
        expected_artifacts = {f"tools/balance/runs/{prefix}/{name}" for name in ("trace.jsonl", "result.json", "process.log")}
        if set(campaign["artifactHashes"]) != expected_artifacts:
            raise ValueError(f"Campaign artifact inventory differs: {prefix}")
        for relative, digest in campaign["artifactHashes"].items():
            raw, artifact = archived_bytes(relative, digest, prefix, archive_only)
            artifacts[relative] = artifact
            sources[artifact["path"]] = artifact["sha256"]
            if relative.endswith("trace.jsonl"):
                traces = [json.loads(line) for line in raw.decode("utf-8").splitlines()]
            elif relative.endswith("result.json"):
                original_result = json.loads(raw)
            elif relative.endswith("process.log"):
                process_text = raw.decode("utf-8")
        if traces is None or original_result is None or process_text is None:
            raise ValueError(f"Campaign is missing an execution artifact: {prefix}")
        validate_campaign_metadata(campaign, original_result)
        godot_errors = [line for line in process_text.splitlines() if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
        if godot_errors != campaign["godotErrors"]:
            raise ValueError(f"Godot error metadata differs from process log: {prefix}")
        expected_execution_checks.extend({**check, "id": f"{check['id']}/{campaign['seed']}/{campaign['strategy']}"}
                                         for check in original_result["checks"])
        expected_execution_checks.append({"id": f"BAL-PROCESS-001/{campaign['seed']}/{campaign['strategy']}",
            "status": "pass" if campaign["processExitCode"] == 0 and not godot_errors else "fail",
            "evidence": {"exit": campaign["processExitCode"], "errors": godot_errors}})
        start = next(r for r in traces if r["type"] == "start")
        if (start["seed"], start["strategy"], start["limit"]) != (campaign["seed"], campaign["strategy"], 60):
            raise ValueError(f"Trace identity disagrees: {prefix}")
        rounds = [r for r in traces if r["type"] == "round"]
        actual_turns = [r["after"]["turn"] for r in rounds]
        if len(rounds) != campaign["rounds"] or actual_turns != list(range(1, len(rounds) + 1)):
            raise ValueError(f"Missing/repeated/out-of-order actual rounds: {prefix}")
        if campaign["status"] == "censored" and len(rounds) != 60:
            raise ValueError(f"Prematurely censored run: {prefix}")
        if not rounds:
            raise ValueError(f"No completed round to assess: {prefix}")
        for field in ("turn", "phase", "faith", "whispers", "awakening", "insight", "wounds", "members", "cults", "anchors", "domains", "disconnected", "facts", "living", "outcome"):
            if rounds[-1]["after"][field] != original_result["final"][field]:
                raise ValueError(f"Final observation differs from last actual round: {prefix}/{field}")
        first_cult = next((r["after"]["turn"] for r in rounds if r["after"]["cults"]), -1)
        if first_cult != original_result["first_cult_turn"]:
            raise ValueError(f"First cult is not backed by a recorded round: {prefix}")
        statuses[campaign["status"]] += 1
        all_turns += len(rounds)
        steps = [r for r in traces if r["type"] == "progress"]
        for row in steps:
            phase_costs[row["from"]].append(row["elapsed_ms"])
        actions = [r for r in traces if r["type"] == "action"]
        for row in actions:
            invariant_records.append(row["preview_pure"] and row["rejected_atomic"])
        for row in traces:
            for fact in row.get("result", {}).get("facts", []):
                identity = (prefix, fact["id"])
                if fact.get("kind") != "economy_strategy_payment" or identity in seen_economy_facts:
                    continue
                seen_economy_facts.add(identity)
                data = fact["changes"]
                if data.get("reason", "") == "" and (data.get("effective") != "expand" or data.get("fee", 0) > 0):
                    effective_strategy_facts[data["effective"]] += 1
        views = [r["public"] for r in traces if r["type"] == "decision_view"]
        for view in views:
            if view["faith"] == 0:
                progression = [r for r in steps if r["turn"] == view["turn"]
                               and r["from"] == "actions" and r["result"].get("ok")]
                if progression:
                    zero_resource_records.append({"campaign": prefix, "turn": view["turn"]})
        for row in rounds:
            for cult in row["after"]["cults"].values():
                observed_strategies[cult.get("strategy", "unknown")] += 1
        errors = Counter(str(r["result"].get("error", "unknown"))
                         for r in actions if not r["result"].get("ok"))
        offers = Counter(p["card"]["content_id"] for view in views for p in view["prayers"])
        known_attention = {key: max((v["attention"][key] for v in views), default=0)
                           for key in ("focus", "members", "people", "identities")}
        phase_sums = defaultdict(float)
        for step in steps:
            phase_sums[step["turn"]] += step["elapsed_ms"]
        first = rounds[:10]
        tail = rounds[-10:]
        summaries.append({"seed": campaign["seed"], "strategy": campaign["strategy"],
            "status": campaign["status"], "turns": len(rounds),
            "firstCultTurn": campaign["first_cult_turn"],
            "finalFaith": campaign["final"]["faith"],
            "finalMembers": len(campaign["final"]["members"]),
            "roundEndMaxMembers": max((len(r["after"]["members"]) for r in rounds), default=0),
            "finalHistoricalCultEntries": len(campaign["final"]["cults"]),
            "roundEndMaxHistoricalCultEntries": max((len(r["after"]["cults"]) for r in rounds), default=0),
            "finalActiveCults": sum(c["status"] == "active" for c in campaign["final"]["cults"].values()),
            "finalAnchors": len(campaign["final"]["anchors"]),
            "finalAwakening": campaign["final"]["awakening"],
            "finalFacts": campaign["final"]["facts"],
            "roundEndMaxStaticMemoryBytes": max((r["after"]["static_memory_bytes"] for r in rounds), default=0),
            "postRestoreStaticMemoryBytes": campaign["final"]["static_memory_bytes"],
            "attentionPeakFromPublicView": known_attention,
            "prayerOfferAppearances": dict(offers), "actionRejectedReasons": dict(errors),
            "acceptedActions": sum(bool(r["result"].get("ok")) for r in actions),
            "acceptedPlans": sum(bool(r["result"].get("ok")) for r in traces if r["type"] == "plan"),
            "saveMs": campaign["save_ms"], "loadMs": campaign["load_ms"],
            "sessionProgressSumPerTurnMs": distribution(list(phase_sums.values())),
            "instrumentedRoundMs": distribution([r["elapsed_ms"] for r in rounds]),
            "instrumentedHead10MedianMs": statistics.median(r["elapsed_ms"] for r in first),
            "instrumentedTail10MedianMs": statistics.median(r["elapsed_ms"] for r in tail),
            "observedHeadFacts": first[0]["after"]["facts"],
            "observedTailFacts": tail[-1]["after"]["facts"],
            "roundFieldsNotUsed": ["turn (use after.turn)", "before/after.temporary (invalid field)"]})
    expected_execution_checks.append({"id": "BAL-FIRST-CULT-001", "status": "pass" if any(c["first_cult_turn"] >= 0 for c in campaigns) else "fail",
        "evidence": {"campaignsWithCult": sum(c["first_cult_turn"] >= 0 for c in campaigns), "finiteSearchOnly": True}})
    expected_execution_checks.append({"id": "BAL-COVERAGE-001", "status": "pass" if len(campaigns) == 12 and all(c["status"] in ("ended", "censored") for c in campaigns) else "fail",
        "evidence": {"campaigns": len(campaigns), "limit": 60}})
    if expected_execution_checks != baseline["checks"]:
        raise ValueError("Aggregate checks differ from original per-campaign evidence")
    expected_status = "pass" if all(c["status"] == "pass" for c in expected_execution_checks) else "fail"
    if baseline["status"] != expected_status:
        raise ValueError("Aggregate status contradicts original checks")
    checks = expected_execution_checks
    checks += [
        {"id": "BAL-EVIDENCE-001", "status": "pass", "method": "artifact and execution-source hash validation",
         "evidence": {"campaigns": len(campaigns), "rounds": all_turns, "archivedArtifacts": len(artifacts)}},
        {"id": "BAL-PREVIEW-ATOMIC-001", "status": "pass" if invariant_records and all(invariant_records) else "fail",
         "evidence": {"observedActionAttempts": len(invariant_records), "violations": invariant_records.count(False)}},
        {"id": "BAL-ZERO-RESOURCE-001", "status": "pass" if zero_resource_records else "fail",
         "evidence": {"actualZeroFaithActionPhaseAdvances": zero_resource_records}},
        {"id": "BAL-ECONOMIC-STRATEGIES-001", "status": "pass" if {"hold", "conceal", "expand"} <= set(effective_strategy_facts) else "fail",
         "evidence": {"storedIntentRoundSamples": dict(observed_strategies),
                      "actualEffectiveStrategyPaymentFacts": dict(effective_strategy_facts),
                      "qualification": "Paid expansion requires a positive fee and no fallback reason; stored intent is not effective work."}},
    ]
    review_path = project_file("docs/qa/balance-source-review.json")
    review = json.loads(review_path.read_bytes())
    for relative, recorded in review["sourceHashes"].items():
        if sha(project_file(relative).read_bytes()) != recorded:
            raise ValueError(f"Independent source review is stale: {relative}")
    checks.extend(review["checks"])
    check_ids = [check["id"] for check in checks]
    if len(check_ids) != len(set(check_ids)):
        raise ValueError("Duplicate stable check identity")
    sources.update(review["sourceHashes"])
    sources[review_path.relative_to(ROOT).as_posix()] = sha(review_path.read_bytes())
    sources[BASELINE.relative_to(ROOT).as_posix()] = baseline_digest or sha(BASELINE.read_bytes())
    sources[Path(__file__).relative_to(ROOT).as_posix()] = sha(Path(__file__).read_bytes())
    sources[Path(__file__).with_name("test_report.py").relative_to(ROOT).as_posix()] = sha(Path(__file__).with_name("test_report.py").read_bytes())
    sources["docs/qa/balance-review.md"] = sha(project_file("docs/qa/balance-review.md").read_bytes())
    return {"suite": "TASK-BALANCE / ACC-STRATEGIES", "generatedAt": datetime.now(timezone.utc).isoformat(),
            "status": "pass" if all(c["status"] == "pass" for c in checks) else "fail",
            "executionStatus": "complete", "sourceHashes": dict(sorted(sources.items())),
            "checks": checks, "campaigns": summaries, "artifacts": artifacts,
            "metrics": {"campaigns": len(campaigns), "actualRounds": all_turns, "outcomes": dict(statuses),
                        "sessionProgressByPhaseMs": {k: distribution(v) for k, v in phase_costs.items()}},
            "environment": baseline["environment"],
            "limitations": baseline["limitations"] + [
                "Instrumented round/action timings include full snapshot checks, projections, observations and logging; progress phase timings exclude those external probes.",
                "P occupancy comes from public.attention.people, not the invalid diagnostic temporary field.",
                "Policies resolve at most one chosen main event per turn; remaining events follow their real defaults.",
                "Idempotency checks cover the first accepted action per campaign; no exhaustive profit-loop or dominance proof.",
                "No fresh-engine semantic strategy replay is claimed unless separately recorded.",
                "Observed costs mix changing activity and history; this is not an isolated H/K causal comparison or target-platform certification.",
                "Static memory figures are round-end samples and a post-restore sample, not engine/process peak memory; Session.save_game currently exports a full Turn snapshot, not an incremental archive write.",
                "Static source-closure failure is explicitly distinguished from automated campaign observations."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "tools/balance/results.json")
    parser.add_argument("--archive-only", action="store_true", help="Read compressed evidence even when local runs exist")
    args = parser.parse_args()
    source = args.input if args.input.is_file() else BASELINE
    raw = source.read_bytes()
    baseline = json.loads(raw)
    result = analyse(baseline, sha(raw), args.archive_only)
    if source.resolve() != BASELINE.resolve():
        temporary = BASELINE.with_suffix(".json.tmp")
        temporary.write_bytes(raw)
        temporary.replace(BASELINE)
    write_json(OUTPUT, result)
    print(json.dumps({"report": str(OUTPUT.relative_to(ROOT)), "status": result["status"],
                      "execution": result["executionStatus"], "metrics": result["metrics"]}, ensure_ascii=False))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        raise SystemExit(f"Evidence not published: {error}")
