"""Finite static checks for Axiom, Network, and Manifestation Routes design."""
from __future__ import annotations

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TITLE = "Axiom, Network, and Manifestation Routes"
INPUTS = (
    "data/progression_routes.csv", "data/progression_route_operations.csv",
    "data/progression_route_sources.csv", "data/progression_opportunity_goals.csv",
    "data/civilization_profiles.csv", "data/powers.csv", "data/run_parameters.csv",
    "data/fidelity_parameters.csv", "data/civilization_parameters.csv",
    "data/intervention_policies.csv", "data/prayer_root_rules.csv",
    "docs/specs/system-events.md", "docs/specs/system-civilizations.md",
    "docs/specs/system-progression.md", "docs/implementation/traceability.json",
    "docs/tasks/slice-14.md", "tools/axiom-network-routes/verify.py",
    "tools/axiom-network-routes/README.md",
)
ROUTE_HEADER = ["id", "goal_id", "profile", "branch", "entry_ids", "material_rule",
                "delivery_mode", "delivery_bound", "producer_task", "coordination_task", "consumer_task", "runtime_status"]
OP_HEADER = ["id", "mode", "cost_rule", "check_rule", "cooldown_turns", "success_pollution",
             "always_alert", "always_sanity_loss", "participants_max", "repeat_turns", "runtime_status", "rationale"]
SOURCE_HEADER = ["id", "phase", "handler", "product_kind", "due_policy", "producer_task", "runtime_status"]
OPERATIONS = {
    "ROUTE_GUIDED_DREAM": "guided_dream", "ROUTE_AXIOM_PROBE": "axiom_probe",
    "ROUTE_AXIOM_RECHECK": "axiom_recheck", "ROUTE_AXIOM_REPEAT": "axiom_repeat",
    "ROUTE_NETWORK_EXCHANGE": "network_exchange",
}
ROUTES = {
    "ROUTE_CIV07_NODES": ("GOAL_ANCHOR_CIV07", "CIV_07", "independent_nodes", "axiom_nodes"),
    "ROUTE_CIV07_ARCHIVE": ("GOAL_ANCHOR_CIV07", "CIV_07", "repeated_archive", "axiom_archive"),
    "ROUTE_CIV05_DREAMS": ("GOAL_ANCHOR_CIV05", "CIV_05", "independent_dreams", "network_independent"),
    "ROUTE_CIV05_EXCHANGE": ("GOAL_ANCHOR_CIV05", "CIV_05", "reciprocal_exchange", "network_exchange"),
    "ROUTE_MANIFEST_ANCHOR": ("GOAL_MANIFEST", "", "restore_unpaid_anchor", "upkeep_restorable_manifest_configuration"),
    "ROUTE_MANIFEST_WOUNDS": ("GOAL_MANIFEST", "", "recover_wounds", "wound_restorable_manifest_configuration"),
}
# Finite design entry references, not a test that these handlers are installed.
BUILTINS = {
    "POWER_MANIFEST_CONTINUE": {"interface": "Session.execute_action", "action": "POWER_MANIFEST_CONTINUE"},
    "SESSION_REST": {"interface": "Session.rest", "op": "rest"},
    "SESSION_SET_ECONOMY_PLAN": {"interface": "Session.set_plan", "op": "set_plan", "participant": "economy"},
}


class InvalidDesign(ValueError):
    pass


def require(value: bool, message: str) -> None:
    if not value:
        raise InvalidDesign(message)


def table(path: str, header: list[str] | None = None, key: str = "id") -> dict:
    with (ROOT / path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream, strict=True)
        actual = next(reader, None)
        require(bool(actual) and key in actual and len(set(actual)) == len(actual), f"{path}: invalid header")
        require(header is None or actual == header, f"{path}: unexpected schema")
        result = {}
        for line, values in enumerate(reader, 2):
            require(len(values) == len(actual), f"{path}:{line}: field count")
            require(all(value == value.strip() for value in values), f"{path}:{line}: padded field")
            row = dict(zip(actual, values))
            require(bool(row[key]) and row[key] not in result, f"{path}:{line}: blank/duplicate {key}")
            result[row[key]] = row
    require(bool(result), f"{path}: empty table")
    return result


def integer(value: str, name: str, minimum: int = 0) -> int:
    require(bool(re.fullmatch(r"0|[1-9][0-9]*", value)), f"{name}: expected canonical integer")
    parsed = int(value)
    require(parsed >= minimum, f"{name}: below {minimum}")
    return parsed


def parameter(rows: dict, key: str, unit: str) -> int:
    require(key in rows and rows[key]["unit"] == unit and bool(rows[key]["rationale"]), f"{key}: missing formal parameter/unit/rationale")
    return integer(rows[key]["value"], key)


def ids(value: str, name: str) -> list[str]:
    parsed = value.split("|")
    require(all(parsed) and len(set(parsed)) == len(parsed), f"{name}: empty/duplicate reference")
    return parsed


def hashes() -> dict:
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS}


def route_tables() -> dict:
    rows = table(INPUTS[0], ROUTE_HEADER)
    goals = table("data/progression_opportunity_goals.csv")
    profiles = table("data/civilization_profiles.csv")
    powers = table("data/powers.csv")
    require(set(rows) == set(ROUTES), "Exactly the six frozen route IDs are required; READY is not a second causal route")
    counts = Counter()
    branches = set()
    used_ops = set()
    for key, row in rows.items():
        require((row["goal_id"], row["profile"], row["branch"], row["material_rule"]) == ROUTES[key], f"{key}: unknown goal/profile/branch/material enum combination")
        require(row["goal_id"] in goals and goals[row["goal_id"]]["runtime_status"] == "design_only", f"{key}: invalid goal reference")
        require(row["profile"] == goals[row["goal_id"]]["profile_id"], f"{key}: goal/profile mismatch")
        require(not row["profile"] or row["profile"] in profiles, f"{key}: missing formal profile")
        require(row["runtime_status"] == "design_only", f"{key}: route must remain design_only")
        require(row["delivery_mode"] in {"direct_action", "bounded_pipeline"}, f"{key}: unknown delivery mode")
        if row["delivery_mode"] == "direct_action":
            require(row["delivery_bound"] == "0", f"{key}: current-qualified design step has bound zero")
        else:
            require(row["delivery_bound"] == "", f"{key}: unknown real pipeline L must remain unspecified")
        for entry in ids(row["entry_ids"], key):
            require(entry in OPERATIONS or entry in powers or entry in BUILTINS, f"{key}: unresolved finite entry reference {entry}")
            if entry in OPERATIONS:
                used_ops.add(entry)
        require(all(row[field] for field in ["producer_task", "coordination_task", "consumer_task"]), f"{key}: task owner reference is empty")
        identity = (row["goal_id"], row["branch"])
        require(identity not in branches, f"{key}: duplicate declared branch")
        branches.add(identity)
        counts[row["goal_id"]] += 1
    require(dict(counts) == {"GOAL_ANCHOR_CIV07": 2, "GOAL_ANCHOR_CIV05": 2, "GOAL_MANIFEST": 2}, "Three goals need two indexed branches each")
    require(used_ops == set(OPERATIONS), "An operation is omitted from route references")
    return {"routeCount": len(rows), "perGoalCount": dict(counts), "routes": list(rows.values()),
            "builtinEntryReferences": BUILTINS, "realPipelineLatencyL": None,
            "routeCompletionBound": None, "distinctCausalBranches": "manual_QA_required",
            "scope": "Finite index/reference coverage only; distinct strings do not prove distinct gameplay paths or installed handlers."}


def operation_tables() -> dict:
    rows = table(INPUTS[1], OP_HEADER)
    powers = table("data/powers.csv")
    run = table("data/run_parameters.csv")
    require(set(rows) == set(OPERATIONS), "Exactly five finite operation IDs are required")
    costs = {}
    inherited = ["cooldown_turns", "success_pollution", "always_alert", "always_sanity_loss", "repeat_turns"]
    for key, row in rows.items():
        require(row["runtime_status"] == "design_only" and row["mode"] == OPERATIONS[key] and bool(row["rationale"]), f"{key}: invalid mode/status/rationale")
        participants = integer(row["participants_max"], key + ".participants_max", 1)
        if key == "ROUTE_GUIDED_DREAM":
            require(row["cost_rule"] == row["check_rule"] == "POWER_DREAM" and participants == 1, "Guided dream must delegate the original power")
            require(all(row[field] == "" for field in inherited), "Guided dream must not duplicate inherited numerical effects")
            dream = powers["POWER_DREAM"]
            costs[key] = {"faith": integer(dream["faith"], "POWER_DREAM.faith"), "whispers": integer(dream["whispers"], "POWER_DREAM.whispers"), "cooldown": integer(dream["cooldown_turns"], "POWER_DREAM.cooldown_turns"), "outcomeEffects": "delegated_to_original_power"}
        else:
            require(row["cost_rule"] == "prayer_deep" and row["check_rule"] == "occult_adaptation", f"{key}: unknown cost/check reference")
            for field in inherited[:-1]:
                integer(row[field], key + "." + field)
            if key == "ROUTE_AXIOM_REPEAT":
                require(integer(row["repeat_turns"], key + ".repeat_turns", 2) == 2, "Archive design requires two different actual turns")
            else:
                require(row["repeat_turns"] == "", f"{key}: unexpected repeat-turn field")
            require(participants == (2 if key in {"ROUTE_AXIOM_RECHECK", "ROUTE_NETWORK_EXCHANGE"} else 1), f"{key}: participant shape disagrees with its finite operation")
            costs[key] = {"faith": parameter(run, "prayer_deep_faith", "faith"), "whispers": parameter(run, "prayer_deep_whispers", "whispers"), "participants": participants}
    require(powers["POWER_DREAM"]["check_kind"] == "occult" and powers["POWER_DREAM"]["attribute"] == "adaptation", "Original occult/adaptation reference changed")
    return {"operationCount": len(rows), "operations": list(rows.values()), "formalCostReferences": costs,
            "scope": "Schema and formal numerical references; no payment, RNG, knowledge or effect handler executed."}


def source_table() -> dict:
    rows = table(INPUTS[2], SOURCE_HEADER)
    original = table("data/prayer_root_rules.csv")
    require(set(rows) == {"ROOT_COSMIC_RECHECK"} and "ROOT_COSMIC_RECHECK" not in original, "One separate natural recheck root declaration is required")
    row = rows["ROOT_COSMIC_RECHECK"]
    require(row["phase"] == "4" and row["handler"] == "current_same_exception_recheck" and row["due_policy"] == "source_validity" and row["runtime_status"] == "design_only", "Unknown recheck root enum/phase/status")
    require(set(ids(row["product_kind"], "ROOT_COSMIC_RECHECK")) == {"exception_reference_read", "law_observation"}, "Unexpected recheck products")
    require(row["producer_task"] == "TASK-SOURCE-EXCEPTION" and "ROOT_COSMIC_OBSERVATION" in original, "Natural observation/recheck ownership/reference missing")
    return {"sourceCount": 1, "source": row, "naturalReachabilityVerified": False}


def task_references() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    tasks = tracking["tasks"]
    scenarios = tracking["scenarios"]
    require(isinstance(tasks, list) and isinstance(scenarios, list), "Missing structured tasks/scenarios")
    require(all(isinstance(task, dict) for task in tasks) and all(isinstance(case, dict) for case in scenarios), "Malformed task/scenario object")
    required = {"TASK-AXIOM-NETWORK-ROUTES": "design"}
    for row in table(INPUTS[0], ROUTE_HEADER).values():
        for field in ["producer_task", "coordination_task", "consumer_task"]:
            required[row[field]] = "code"
    for row in table(INPUTS[2], SOURCE_HEADER).values():
        required[row["producer_task"]] = "code"
    parents = [task for task in tasks if task.get("id") == "TASK-PROGRESSION-OPERATIONS"]
    require(len(parents) == 1, "Progression Route Operations needs a real unique task object")
    for child in parents[0].get("dependsOn", []):
        required[child] = "code"
    required["TASK-PROGRESSION-INTERFACE-DESIGN"] = "design"
    new_handoff = set(parents[0].get("dependsOn", [])) | {"TASK-PROGRESSION-OPERATIONS", "TASK-PROGRESSION-INTERFACE-DESIGN"}
    brief = (ROOT / "docs/tasks/slice-14.md").read_text(encoding="utf-8-sig")
    found = {}
    for key, owner in sorted(required.items()):
        matches = [task for task in tasks if task.get("id") == key]
        require(len(matches) == 1, f"{key}: absent/duplicate actual task")
        task = matches[0]
        require(task.get("owner") == owner and bool(task.get("title")) and bool(task.get("scope")) and bool(task.get("deliverables")) and bool(task.get("acceptance")), f"{key}: missing owner/scope/deliverables/ACC")
        if key in new_handoff:
            require(task["title"] in brief or key in brief, f"{key}: no new-batch taskbook reference")
        evidence = []
        for acceptance in task["acceptance"]:
            matching = [case for case in scenarios if case.get("id") == acceptance]
            require(len(matching) == 1 and bool(matching[0].get("given")) and bool(matching[0].get("when")) and bool(matching[0].get("then")), f"{key}: missing/empty real ACC scenario {acceptance}")
            evidence.append({"id": acceptance, "kind": matching[0].get("kind")})
        found[key] = {"title": task["title"], "owner": task["owner"], "status": task["status"], "acceptance": evidence}
    parent = [task for task in tasks if task.get("id") == "TASK-PROGRESSION-ROUTES"]
    require(len(parent) == 1 and parent[0]["status"] in {"planned", "in-progress", "blocked"}, "The full route-design parent must remain incomplete")
    return {"tasks": found, "parentComplete": False,
            "scope": "Actual structured ownership/ACC references, not implementation or manual design acceptance."}


def witness() -> dict:
    run = table("data/run_parameters.csv")
    civilization = table("data/civilization_parameters.csv")
    fidelity = table("data/fidelity_parameters.csv")
    base = parameter(run, "initial_awakening", "awakening")
    insight = parameter(run, "insight_cap", "insight")
    recovery = parameter(run, "rest_wound_recovery", "wounds")
    goal = parameter(run, "manifest_requirement", "awakening")
    cap = parameter(run, "awakening_before_final_cap", "awakening")
    value = {tier: parameter(run, f"anchor_{tier}_contribution", "awakening") for tier in ("planet", "system", "cosmic")}
    fee = {tier: parameter(run, f"anchor_{tier}_upkeep", "faith_per_turn") for tier in value}
    active = {"cosmic": 2, "system": 5, "planet": 2}
    wounds = 6  # Controlled algebra input from progression section 12.1, not a runtime parameter.
    contribution = sum(active[tier] * value[tier] for tier in active)
    awakening = lambda current_wounds, optional: max(0, min(cap, base + insight + contribution + optional - current_wounds))
    before = awakening(wounds, 0)
    restored_anchor = awakening(wounds, value["planet"])
    restored_wounds = awakening(wounds - min(wounds, recovery), 0)
    require(before == 87 and restored_anchor == 91 and restored_wounds == 90, "Frozen witness changed: review formal values instead of silently changing the example")
    require(before < goal <= restored_anchor and goal <= restored_wounds, "Both independent algebra causes must bridge the original shortfall")
    slots = parameter(civilization, "institutions_per_domain", "institution")
    layout = {"cosmic": [2], "system": [3, 2], "planet": [3]}
    for tier, used in layout.items():
        require(len(used) <= parameter(civilization, f"{tier}_domains", "domain") and max(used) <= slots, f"{tier}: witness exceeds domain/slot budget")
    domains = sum(len(used) for used in layout.values())
    guardians = sum(active.values()) + 1
    n_limit = parameter(fidelity, "bound_member_limit", "person")
    f_limit = parameter(fidelity, "focused_domain_limit", "domain")
    require(domains <= parameter(civilization, "domains_total", "domain") and guardians <= n_limit and 2 <= f_limit, "Witness exceeds D/N/F budget")
    upkeep = sum(active[tier] * fee[tier] for tier in active)
    rest_fee = parameter(run, "rest_faith_cost", "faith")
    start_fee = integer(table("data/powers.csv")["POWER_MANIFEST"]["faith"], "POWER_MANIFEST.faith")
    cash = max(upkeep + fee["planet"] + start_fee, rest_fee + upkeep + start_fee)
    capacity = parameter(run, "faith_capacity_base", "faith") + before * parameter(run, "faith_capacity_per_peak_awakening", "faith")
    require(cash <= capacity, "Conditional current-cash witness exceeds the capacity at the initial peak")
    return {"fixtureOrigin": "Controlled example in system-progression section 12.1; fixture counts are not runtime parameters",
            "inputs": {"base": base, "insight": insight, "activeAnchors": active, "contribution": contribution, "beforeWoundsB": base + insight + contribution, "wounds": wounds, "optionalUnpaidPlanetAnchors": 1, "manifestThreshold": goal},
            "before": before, "upkeepOnly": restored_anchor, "restOnlyWithOptionalRefused": restored_wounds,
            "necessaryBudgets": {"domains": domains, "slotsByTierAndDomain": layout, "guardians": guardians, "NLimit": n_limit, "ritualF": 2, "FLimit": f_limit, "newPersons": 0},
            "conditionalCashWithoutFutureIncome": {"existingUpkeep": upkeep, "optionalUpkeep": fee["planet"], "REST": rest_fee, "manifestStart": start_fee, "cashReserveForRecoveryThenStart": cash, "capacityAtInitialPeak": capacity},
            "assumptions": ["Every anchor, guardian, cult, material, medium and knowledge source is already genuine and otherwise qualified.",
                            "All cult strategies are hold with zero strategy fee; no expansion or other higher-priority fees compete for this cash reserve.",
                            "Upkeep branch actually pays and passes final eligibility before optional contribution resumes.",
                            "REST branch explicitly refuses the optional anchor; omitting priority is not refusal.",
                            "Unchanged required anchors/world conditions and sufficient current cash; no future income is used.",
                            "Neither branch starts manifestation during the recovery actions window; both recheck at a later real actions boundary."],
            "scope": "Algebra and necessary finite budget checks only; no legal saved game, payment or reactivation fact was constructed."}


def negative_obligations() -> dict:
    example = witness()
    recovery = parameter(table("data/run_parameters.csv"), "rest_wound_recovery", "wounds")
    higher = max(example["upkeepOnly"], example["restOnlyWithOptionalRefused"]) + 1
    require(example["upkeepOnly"] < higher and example["restOnlyWithOptionalRefused"] < higher, "Threshold-change counterexample failed")
    no_wounds_recovery = min(0, recovery)
    require(no_wounds_recovery == 0, "No-wound algebra unexpectedly recovers wounds")
    require(example["before"] != example["upkeepOnly"], "Saving a plan must not already include unpaid contribution")
    return {"higherThreshold": {"hypotheticalOnly": higher, "bothCausesInsufficient": True},
            "noTrueWounds": {"wounds": 0, "recoverable": no_wounds_recovery, "obligation": "Actual REST must reject; no fictional recovery or +3."},
            "savedPlanOnly": {"optionalContributionBeforeActualPaymentAndRevalidation": 0, "awakening": example["before"], "obligation": "A saved plan or paid_pending_final_check is not active-anchor proof."},
            "branchIsolation": "REST must explicitly refuse optional upkeep; otherwise two positive causes can be combined.",
            "scope": "Static algebra counterexamples and future handler obligations, not runtime fault injection or atomic-save tests."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tables-only", action="store_true")
    args = parser.parse_args()
    checks = []
    before = {}
    try:
        before = hashes()
    except OSError as error:
        checks.append({"id": "ANM-INPUTS", "status": "fail", "error": str(error)})
    operations = [("ANM-ROUTES", route_tables), ("ANM-OPERATIONS", operation_tables),
                  ("ANM-NATURAL-SOURCE", source_table), ("ANM-TASK-OWNERS-ACC", task_references)]
    if not args.tables_only:
        operations += [("ANM-ALGEBRA-WITNESS", witness), ("ANM-NEGATIVE-OBLIGATIONS", negative_obligations)]
    for key, operation in operations:
        try:
            checks.append({"id": key, "status": "pass", "details": operation()})
        except (OSError, ValueError, KeyError, TypeError, csv.Error) as error:
            checks.append({"id": key, "status": "fail", "error": str(error)})
    try:
        frozen = bool(before) and hashes() == before
    except OSError:
        frozen = False
    checks.append({"id": "ANM-SOURCE-FROZEN", "status": "pass" if frozen else "fail"})
    passed = all(check["status"] == "pass" for check in checks)
    result = {"schemaVersion": 1, "title": TITLE, "task": "TASK-AXIOM-NETWORK-ROUTES",
              "status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
              "acceptanceScope": "static_tables_only" if args.tables_only else "static_design_and_algebra_only",
              "command": ["python", "tools/axiom-network-routes/verify.py"] + (["--tables-only"] if args.tables_only else []),
              "pythonVersion": sys.version.split()[0], "sourceHashes": before, "checks": checks,
              "limitations": ["Distinct causal routes require independent manual QA; counts or branch names do not prove them.",
                              "All new data remain design_only; no Catalog, handler, Turn, Session or natural new game was run.",
                              "direct_action bound 0 is a target contract for one currently qualified step after implementation, not current executability or a zero-turn entire route.",
                              "Real pipeline L and route completion bounds are unknown/null; no guaranteed response success or victory.",
                              "No transaction, knowledge, material production, reactivation, save/restore or runtime fault-injection evidence is produced."]}
    with (HERE / "results.json").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{'PASS' if passed else 'FAIL'} {TITLE}: {sum(check['status'] == 'pass' for check in checks)}/{len(checks)} ({result['acceptanceScope']})")
    for check in checks:
        if check["status"] == "fail":
            print(f"  {check['id']}: {check.get('error', 'source bytes changed during run')}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
