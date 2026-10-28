"""Static design-data checks; this tool never loads or runs the game."""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
INPUTS = (
    "data/opportunity_parameters.csv",
    "data/progression_opportunity_goals.csv",
    "data/civilization_parameters.csv",
    "data/civilization_profiles.csv",
    "data/fidelity_parameters.csv",
    "docs/specs/system-events.md",
    "docs/specs/system-progression.md",
    "docs/tasks/slice-14.md",
    "docs/implementation/traceability.json",
    "tools/opportunity-contract/verify.py",
    "tools/opportunity-contract/README.md",
)
PARAMETERS = {
    "policy_version": "version",
    "base_goal_weight": "weight",
    "missed_slot_weight_step": "weight_per_missed_due_slot",
    "forced_after_missed_slots": "eligible_due_slot",
    "retry_cooldown_due_slots": "due_slot",
    "minimum_action_windows": "complete_actions_phase",
}
ROUTE_TASKS = {
    "TASK-AXIOM-NETWORK-ROUTES",
    "TASK-FOUNDATION-ROUTES-DESIGN",
    "TASK-MEMORY-CONTRACT-ROUTES",
}
GOAL_IDS = {"GOAL_FIRST_CULT", "GOAL_MANIFEST"} | {
    f"GOAL_ANCHOR_CIV{number:02d}" for number in range(1, 9)
}


class InvalidContract(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidContract(message)


def read_csv(path: str, header: list[str] | None = None) -> dict[str, dict[str, str]]:
    with (ROOT / path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream, strict=True)
        actual = next(reader, None)
        require(actual is not None and bool(actual) and actual[0] == "id", f"{path}: missing id header")
        if header is not None:
            require(actual == header, f"{path}: unexpected header {actual}")
        require(len(set(actual)) == len(actual), f"{path}: duplicate header")
        rows = {}
        for line, cells in enumerate(reader, 2):
            require(len(cells) == len(actual), f"{path}:{line}: wrong field count")
            require(all(cell == cell.strip() for cell in cells), f"{path}:{line}: padded field")
            row = dict(zip(actual, cells))
            key = row["id"]
            require(bool(key) and key not in rows, f"{path}:{line}: blank/duplicate id {key!r}")
            rows[key] = row
    require(bool(rows), f"{path}: no data")
    return rows


def positive(row: dict[str, str], unit: str) -> int:
    require(bool(re.fullmatch(r"[1-9][0-9]*", row["value"])), f"{row['id']}: expected positive integer")
    require(row["unit"] == unit and bool(row["rationale"]), f"{row['id']}: unit/rationale mismatch")
    return int(row["value"])


def hashes() -> dict[str, str]:
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS}


def check_parameters() -> dict:
    rows = read_csv(INPUTS[0], ["id", "value", "unit", "rationale"])
    require(set(rows) == set(PARAMETERS), "Opportunity parameter IDs differ from the finite contract")
    values = {key: positive(rows[key], unit) for key, unit in PARAMETERS.items()}
    return {"parameters": values, "units": PARAMETERS}


def check_goals() -> dict:
    goals = read_csv(INPUTS[1], ["id", "milestone", "instance_scope", "profile_id", "completion_rule", "route_design_task", "runtime_status"])
    profiles = read_csv("data/civilization_profiles.csv")
    require(set(goals) == GOAL_IDS, "Exactly first cult, CIV01–08 anchor, and manifest goals are required")
    tuples = set()
    for key, row in goals.items():
        require(row["runtime_status"] == "design_only", f"{key}: runtime status must remain design_only")
        require(row["route_design_task"] in ROUTE_TASKS, f"{key}: unknown route task")
        if key.startswith("GOAL_ANCHOR_"):
            profile = "CIV_" + key.removeprefix("GOAL_ANCHOR_CIV")
            require(profile in profiles and row["profile_id"] == profile, f"{key}: invalid formal civilization profile")
            expected = ("active_anchor", "institution", "current_anchor_active")
        elif key == "GOAL_FIRST_CULT":
            require(row["profile_id"] == "", f"{key}: run goal must not select a profile")
            expected = ("first_cult", "run", "first_cult_established")
        else:
            require(row["profile_id"] == "", f"{key}: run goal must not select a profile")
            expected = ("manifest_complete", "run", "manifest_complete")
        require((row["milestone"], row["instance_scope"], row["completion_rule"]) == expected, f"{key}: invalid milestone/scope/completion enum combination")
        identity = (row["milestone"], row["instance_scope"], row["profile_id"])
        require(identity not in tuples, f"{key}: duplicate target")
        tuples.add(identity)
    require({row["route_design_task"] for row in goals.values()} == ROUTE_TASKS, "A route-design group is omitted")
    return {"count": len(goals), "goals": list(goals.values()), "runtimeVerified": False}


def check_references() -> dict:
    civilization = read_csv("data/civilization_parameters.csv", ["id", "value", "unit", "rationale"])
    fidelity = read_csv("data/fidelity_parameters.csv", ["id", "value", "unit", "activation", "rationale"])
    needed = {"domains_total", "institutions_per_domain", "planet_domains", "system_domains", "cosmic_domains"}
    require(needed <= set(civilization), "Missing formal world-budget parameter")
    require("background_tick_interval" in fidelity and "background_candidate_trials" in fidelity, "Missing shared B-slot parameters")
    domains = positive(civilization["domains_total"], "domain")
    institutions = positive(civilization["institutions_per_domain"], "institution")
    tiers = sum(positive(civilization[key], "domain") for key in ("planet_domains", "system_domains", "cosmic_domains"))
    require(domains == tiers, "domains_total differs from planet/system/cosmic sum")
    interval = positive(fidelity["background_tick_interval"], "turn")
    trials = positive(fidelity["background_candidate_trials"], "trial_per_due_domain")
    require(trials == 1 and fidelity["background_tick_interval"]["activation"] == "hybrid", "Proof requires the formal shared single-trial B slot")
    return {"D": domains, "I": institutions, "interval": interval, "trialsPerDueDomain": trials,
            "references": ["civilization_parameters.domains_total", "civilization_parameters.institutions_per_domain", "fidelity_parameters.background_tick_interval", "fidelity_parameters.background_candidate_trials"]}


def check_tasks() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    tasks = tracking.get("tasks")
    require(isinstance(tasks, list), "Traceability has no actual task list")
    required = ROUTE_TASKS | {"TASK-PROGRESSION-ROUTES", "TASK-OPPORTUNITY-CONTRACT-DESIGN"}
    found = {}
    brief = (ROOT / "docs/tasks/slice-14.md").read_text(encoding="utf-8-sig")
    for key in sorted(required):
        matches = [task for task in tasks if isinstance(task, dict) and task.get("id") == key]
        require(len(matches) == 1, f"{key}: absent/duplicate real task object")
        task = matches[0]
        require(task.get("owner") == "design" and bool(task.get("scope")) and bool(task.get("deliverables")) and bool(task.get("acceptance")), f"{key}: missing design ownership/scope/deliverables/acceptance")
        require(task.get("status") in {"planned", "in-progress", "blocked", "implemented", "verified"}, f"{key}: unknown task status")
        if key in ROUTE_TASKS:
            declarations = re.findall(r"^\| " + re.escape(key) + r" \|", brief, re.MULTILINE)
            require(len(declarations) == 1, f"{key}: missing/duplicate slice14 task declaration")
            require("TASK-OPPORTUNITY-CONTRACT-DESIGN" in task.get("dependsOn", []), f"{key}: no shared-contract dependency")
        found[key] = {"owner": task["owner"], "status": task["status"], "acceptance": task["acceptance"]}
    require(found["TASK-PROGRESSION-ROUTES"]["status"] in {"planned", "in-progress", "blocked"}, "Parent routes must remain incomplete before all route-design batches")
    return {"taskObjects": found, "routeTaskCount": len(ROUTE_TASKS), "parentComplete": False,
            "scope": "Existence/ownership/dependency check; not route quality or implementation evidence"}


def instance_bounds() -> dict:
    world = check_references()
    parameters = check_parameters()["parameters"]
    require(parameters["policy_version"] == 1, "Unknown abstract opportunity policy version")
    goals = read_csv(INPUTS[1])
    run_goals = [key for key, row in goals.items() if row["instance_scope"] == "run"]
    require(set(run_goals) == {"GOAL_FIRST_CULT", "GOAL_MANIFEST"}, "The two run goals must each have only one current host")
    global_max = world["D"] * world["I"] + len(run_goals)
    per_domain = world["I"] + len(run_goals)
    return {"domains": world["D"], "institutionsPerDomain": world["I"],
            "runGoalCount": len(run_goals), "globalInstanceMax": global_max,
            "perDomainStepMax": per_domain, "interval": world["interval"],
            "forcedAfterMissedSlots": parameters["forced_after_missed_slots"],
            "globalFormula": "domains_total * institutions_per_domain + run_goal_count",
            "perDomainFormula": "institutions_per_domain + run_goal_count",
            "premises": ["Each institutional slot matches exactly one profile-specific anchor goal.",
                         "Each goal has at most one current step; multiple routes share that competition item.",
                         "Each run-goal step has only one host domain; migration arrives at the new queue tail."]}


def fifo_bound() -> dict:
    values = instance_bounds()
    count = values["perDomainStepMax"]
    threshold = values["forcedAfterMissedSlots"]
    interval = values["interval"]
    bound = interval * (threshold + count)
    cases = []
    worst = None
    # These are queue ranks and B-slot phase offsets, not simulated game turns.
    # All ordinary slots miss. Newly forced arrivals go behind the waiting target;
    # treating arrivals as already forced is at least as adverse as their real debt.
    for rank in range(1, count + 1):
        for first_delay in range(1, interval + 1):
            queue = [f"original-{index}" for index in range(1, count + 1)]
            queue[rank - 1] = "target"
            trace = []
            grant_slot = None
            for offset in range(1, count + 1):
                chosen = queue.pop(0)
                slot = threshold + offset
                elapsed = first_delay + interval * (slot - 1)
                trace.append({"dueSlot": slot, "elapsed": elapsed, "BGranted": chosen})
                if chosen == "target":
                    grant_slot = slot
                    break
                queue.append(f"late-or-reentered-{offset}")
                require(len(queue) <= count, "Abstract queue exceeded its instance premise")
            require(grant_slot is not None, "FIFO failed to dispatch an existing target")
            require(grant_slot <= threshold + count and elapsed <= bound, "FIFO exceeded the pure B bound")
            case = {"initialRank": rank, "firstSlotDelay": first_delay,
                    "grantedDueSlot": grant_slot, "elapsed": elapsed}
            cases.append(case)
            if worst is None or elapsed > worst["elapsed"]:
                worst = {**case, "trace": trace}
    require(worst is not None and worst["elapsed"] == bound, "The finite worst-rank/phase witness did not reach the conservative bound")
    return {"formula": "interval * (forced_after_missed_slots + per_domain_step_max)",
            "pureBBoundTurns": bound, "casesChecked": len(cases), "cases": cases,
            "worstWitness": worst,
            "scope": "Committed grant in the abstract B queue only; no A/fix/offer/actions service is represented.",
            "premises": ["Same host; continuously serviceable; no real block or player change.",
                         "Every eligible ordinary slot may miss; forced queue bypasses the random gate.",
                         "At most one committed grant per due domain slot; monotonic tickets; no newcomer/reentry overtakes.",
                         "Each committed B grant consumes its ticket; inflight steps do not occupy B. Legal failed-pipeline retry keeps debt but receives a new tail ticket.",
                         "An uncommitted transaction rolls back its ticket and is not a consumed B slot; this tool does not test real rollback."],
            "unproved": {"pipelineLatencyL": None, "actualServiceBound": None,
                         "obligation": "Later route-specific real pipeline evidence must prove L; service_bound <= B_bound + L is conditional."}}


def negative_controls() -> dict:
    values = instance_bounds()
    count = values["perDomainStepMax"]
    threshold = values["forcedAfterMissedSlots"]
    interval = values["interval"]
    require(count >= 2, "Insertion counterexample requires a predecessor")
    deadline = interval * (threshold + count)
    queue = [f"older-{index}" for index in range(count - 1)] + ["target"]
    trace = []
    # Isolate the prohibited change: allow each fresh/reentered item at the front.
    # The queue still never exceeds the same finite capacity.
    for offset in range(1, count + 2):
        chosen = queue.pop(0)
        trace.append({"dueSlot": threshold + offset, "BGranted": chosen})
        require(chosen != "target", "The insertion counterexample unexpectedly granted B to its target")
        queue.insert(0, f"illegal-front-arrival-{offset}")
        require(len(queue) == count, "Negative control accidentally changed capacity")
    horizon = interval * (threshold + count + 1)
    require(horizon > deadline and "target" in queue, "No finite insertion counterexample was found")
    ordinary_hits = [False] * (threshold + count + 1)
    granted_without_force = any(ordinary_hits)
    require(not granted_without_force, "The all-miss negative control unexpectedly granted B")
    return {"frontInsertion": {"counterexampleFound": True, "deadline": deadline,
                               "observedUntil": horizon, "targetStillWaitingForB": "target" in queue,
                               "queueCapacityUnchanged": count, "trace": trace},
            "noForcedQueue": {"counterexampleFound": True, "ordinaryMisses": threshold + count + 1,
                              "observedUntil": horizon, "ordinaryHits": ordinary_hits,
                              "targetStillWaitingForB": not granted_without_force,
                              "reason": "An all-miss finite random sequence is still possible without forced selection; positive or increasing weight is not a finite guarantee."},
            "scope": "Finite abstract counterexamples; no production implementation was disabled or tested."}


def retry_tickets() -> dict:
    values = instance_bounds()
    count = values["perDomainStepMax"]
    threshold = values["forcedAfterMissedSlots"]
    interval = values["interval"]
    horizon = 2 * count + 1
    initial = [{"goal": f"X{index}", "ticket": index} for index in range(1, count)]
    initial.append({"goal": "Y", "ticket": count})

    def run(reuse_old_ticket: bool) -> dict:
        queue = [item.copy() for item in initial]
        next_ticket = count + 1
        trace = []
        y_grant = None
        x1_grants = 0
        for offset in range(1, horizon + 1):
            item = queue.pop(0)
            event = {"dueSlot": threshold + offset, "BGranted": item["goal"],
                     "consumedTicket": item["ticket"]}
            if item["goal"] == "Y":
                require(y_grant is None, "Inflight Y occupied B twice")
                y_grant = threshold + offset
                event["retryTicket"] = None  # Y is now inflight, outside B.
            else:
                if item["goal"] == "X1":
                    x1_grants += 1
                # Adversarial peer fails its hypothetical pipeline and is
                # immediately legal again. No L or real game outcome is modeled.
                ticket = item["ticket"] if reuse_old_ticket else next_ticket
                if not reuse_old_ticket:
                    next_ticket += 1
                queue.append({"goal": item["goal"], "ticket": ticket})
                queue.sort(key=lambda current: current["ticket"])
                event.update({"retryTicket": ticket, "retainedMissedSlotDebt": threshold})
            require(len(queue) <= count and len({item["ticket"] for item in queue}) == len(queue), "Retry counterexample changed finite capacity or duplicated a pending ticket")
            trace.append(event)
        return {"YGrantedDueSlot": y_grant, "X1FailedGrantCount": x1_grants, "trace": trace}

    correct = run(False)
    broken = run(True)
    require(correct["YGrantedDueSlot"] is not None and correct["YGrantedDueSlot"] <= threshold + count, "Fresh retry tickets starved Y")
    require(correct["X1FailedGrantCount"] >= 2, "Positive retry case did not exercise repeated X failure")
    require(broken["YGrantedDueSlot"] is None and threshold + horizon > threshold + count, "Old-ticket reuse did not expose the fairness violation")
    return {"freshTailTickets": {**correct, "YBGrantBoundTurns": interval * (threshold + count)},
            "illegalOldTicketReuse": {**broken, "counterexampleFound": True,
                                      "observedUntil": interval * (threshold + horizon)},
            "scope": "Finite committed B grants with adversarial hypothetical retry only; queue tickets and unserved debt are distinct. No opportunity_served, physical pipeline, L or rollback was executed."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tables-only", action="store_true", help="Validate finite design tables/references only")
    args = parser.parse_args()
    checks = []
    before = {}
    try:
        before = hashes()
    except OSError as error:
        checks.append({"id": "OC-SOURCES", "status": "fail", "error": str(error)})
    for key, operation in (
        ("OC-PARAMETERS", check_parameters), ("OC-GOALS", check_goals),
        ("OC-FORMAL-REFERENCES", check_references), ("OC-ROUTE-TASKS", check_tasks),
    ):
        try:
            checks.append({"id": key, "status": "pass", "details": operation()})
        except (OSError, ValueError, KeyError, TypeError, StopIteration, csv.Error) as error:
            checks.append({"id": key, "status": "fail", "error": str(error)})
    if not args.tables_only:
        for key, operation in (("OC-INSTANCE-BOUNDS", instance_bounds),
                               ("OC-FIFO-BOUND", fifo_bound),
                               ("OC-NEGATIVE-CONTROLS", negative_controls),
                               ("OC-RETRY-TICKETS", retry_tickets)):
            try:
                checks.append({"id": key, "status": "pass", "details": operation()})
            except (OSError, ValueError, KeyError, TypeError, StopIteration, csv.Error) as error:
                checks.append({"id": key, "status": "fail", "error": str(error)})
    try:
        frozen = bool(before) and hashes() == before
    except OSError:
        frozen = False
    checks.append({"id": "OC-SOURCE-FROZEN", "status": "pass" if frozen else "fail"})
    passed = all(check["status"] == "pass" for check in checks)
    result = {
        "schemaVersion": 1, "status": "pass" if passed else "fail",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "task": "TASK-OPPORTUNITY-CONTRACT-DESIGN",
        "command": ["python", "tools/opportunity-contract/verify.py"] + (["--tables-only"] if args.tables_only else []),
        "pythonVersion": sys.version.split()[0],
        "acceptanceScope": "static_tables_only" if args.tables_only else "abstract_contract_only",
        "sourceHashes": before, "checks": checks,
        "limitations": ["No game code, natural world or scheduler was run.",
                        "Every goal remains design_only; the parent route task remains incomplete.",
                        "This is not proof of route availability, actionable delivery, response success or victory.",
                        "No real wait/block/decline/failure/save state transition or service receipt was verified.",
                        "A/fix/offer/actions latency L and capacity/eligibility blocks require later real pipeline evidence."],
    }
    (HERE / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{'PASS' if passed else 'FAIL'} opportunity-contract: {sum(c['status'] == 'pass' for c in checks)}/{len(checks)} ({result['acceptanceScope']})")
    for check in checks:
        if check["status"] == "fail":
            print(f"  {check['id']}: {check.get('error', 'inputs changed during run')}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
