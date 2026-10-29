"""Static contracts for Memory and Contract Civilization Route Design; no game execution."""
from __future__ import annotations

from collections import Counter
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TASK = "TASK-MEMORY-CONTRACT-ROUTES"
TITLE = "Memory and Contract Civilization Route Design"
BASE = "763eaa4"
SHARED = ("data/progression_routes.csv", "data/progression_route_operations.csv", "data/progression_route_sources.csv")
INPUTS = SHARED + (
    "data/memory_contract_route_parameters.csv", "data/progression_opportunity_goals.csv",
    "data/civilization_profiles.csv", "data/powers.csv", "data/prayers.csv", "data/run_parameters.csv",
    "data/fidelity_parameters.csv", "data/event_parameters.csv", "data/civilization_parameters.csv",
    "data/intervention_policies.csv", "data/prayer_root_rules.csv", "data/prayer_origin_rules.csv",
    "data/prayer_effects.csv", "data/anchor_conditions.csv", "data/cult_spread_conditions.csv",
    "docs/specs/system-events.md", "docs/specs/system-civilizations.md", "docs/specs/system-progression.md",
    "docs/specs/system-powers-cults.md", "docs/architecture.md", "docs/implementation/traceability.json",
    "docs/tasks/slice-14.md", "tools/memory-contract-routes/verify.py", "tools/memory-contract-routes/README.md",
)
ROUTE_HEADER = ["id", "goal_id", "profile", "branch", "entry_ids", "material_rule", "delivery_mode",
                "delivery_bound", "producer_task", "coordination_task", "consumer_task", "runtime_status"]
OP_HEADER = ["id", "mode", "cost_rule", "check_rule", "cooldown_turns", "success_pollution", "always_alert",
             "always_sanity_loss", "participants_max", "repeat_turns", "runtime_status", "rationale"]
SOURCE_HEADER = ["id", "phase", "handler", "product_kind", "due_policy", "producer_task", "runtime_status"]
MEMORY = "TASK-MEMORY-OPERATIONS"
CONTRACT = "TASK-CONTRACT-OPERATIONS"
ROUTES = {
    "ROUTE_CIV03_CIRCLE": ("GOAL_ANCHOR_CIV03", "CIV_03", "registered_shared_memory", "memory_circle", MEMORY, "ROUTE_MEMORY_CIRCLE|POWER_ANCHOR"),
    "ROUTE_CIV03_PRACTICE": ("GOAL_ANCHOR_CIV03", "CIV_03", "repeated_pair_recollection", "memory_practice", MEMORY, "ROUTE_MEMORY_PRACTICE|POWER_ANCHOR"),
    "ROUTE_CIV06_PERFORMANCE": ("GOAL_ANCHOR_CIV06", "CIV_06", "specific_contract_performance", "contract_performance", CONTRACT, "ROUTE_PACT_AGREEMENT|ROUTE_PACT_PERFORMANCE|POWER_ANCHOR"),
    "ROUTE_CIV06_RECIPROCAL": ("GOAL_ANCHOR_CIV06", "CIV_06", "reciprocal_contract_dependency", "contract_reciprocal", CONTRACT, "ROUTE_RECIPROCAL_COVENANT|POWER_ANCHOR"),
    "ROUTE_CIV08_CIRCLE": ("GOAL_ANCHOR_CIV08", "CIV_08", "registered_dissent_memory", "dissent_circle", MEMORY, "ROUTE_MEMORY_CIRCLE|POWER_ANCHOR"),
    "ROUTE_CIV08_PRACTICE": ("GOAL_ANCHOR_CIV08", "CIV_08", "returned_pair_dissent", "dissent_practice", MEMORY, "ROUTE_DISSENT_PRACTICE|POWER_ANCHOR"),
}
OPERATIONS = {
    "ROUTE_MEMORY_CIRCLE": ("memory_circle", "memory_circle_stage", "stage_deterministic_or_occult", "0", "2", "8", "3", "4", ""),
    "ROUTE_MEMORY_PRACTICE": ("memory_practice", "prayer_deep", "occult_adaptation", "1", "2", "4", "2", "2", "2"),
    "ROUTE_DISSENT_PRACTICE": ("dissent_practice", "prayer_deep", "occult_adaptation", "1", "2", "6", "3", "2", "2"),
    "ROUTE_PACT_AGREEMENT": ("pact_agreement", "memory_contract_preparation", "deterministic", "0", "0", "0", "0", "2", ""),
    "ROUTE_PACT_PERFORMANCE": ("pact_performance", "prayer_deep", "occult_adaptation", "0", "2", "4", "2", "2", ""),
    "ROUTE_RECIPROCAL_COVENANT": ("reciprocal_covenant", "reciprocal_covenant_stage", "stage_deterministic_or_occult", "0", "2", "4", "2", "2", "2"),
}
PARAMETERS = {"preparation_whispers": "whispers", "preparation_faith": "faith", "pair_participants": "persons",
              "practice_turns": "distinct_turns", "reciprocal_legs": "obligations", "memory_contract_schema": "version"}
BUILTINS = {"SESSION_REST", "SESSION_SET_ECONOMY_PLAN", "POWER_MANIFEST_CONTINUE"}


class InvalidContract(ValueError):
    pass


def require(value: bool, message: str) -> None:
    if not value:
        raise InvalidContract(message)


def read_rows(raw: bytes, name: str, header: list[str] | None = None, key: str = "id") -> dict:
    reader = csv.reader(io.StringIO(raw.decode("utf-8-sig"), newline=""), strict=True)
    fields = next(reader, None)
    require(bool(fields) and key in fields and len(set(fields)) == len(fields), f"{name}: invalid header")
    require(header is None or fields == header, f"{name}: unexpected schema")
    rows = {}
    for line, cells in enumerate(reader, 2):
        require(len(cells) == len(fields) and all(cell == cell.strip() for cell in cells), f"{name}:{line}: malformed fields")
        row = dict(zip(fields, cells))
        require(bool(row[key]) and row[key] not in rows, f"{name}:{line}: blank/duplicate {key}")
        rows[row[key]] = row
    require(bool(rows), f"{name}: empty table")
    return rows


def table(path: str, header: list[str] | None = None, key: str = "id") -> dict:
    return read_rows((ROOT / path).read_bytes(), path, header, key)


def baseline(path: str) -> bytes:
    result = subprocess.run(["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, check=False)
    require(result.returncode == 0, f"Missing git baseline {BASE}:{path}")
    return result.stdout


def integer(value: str, name: str) -> int:
    require(bool(re.fullmatch(r"0|[1-9][0-9]*", value)), f"{name}: expected canonical nonnegative integer")
    return int(value)


def parameter(rows: dict, name: str, unit: str) -> int:
    require(name in rows and rows[name]["unit"] == unit and bool(rows[name]["rationale"]), f"{name}: missing formal parameter/unit/rationale")
    return integer(rows[name]["value"], name)


def hashes() -> dict:
    result = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS}
    result.update({f"git:{BASE}:{path}": hashlib.sha256(baseline(path)).hexdigest() for path in SHARED})
    return result


def preservation() -> dict:
    result = {}
    for path, count, header in zip(SHARED, (14, 12, 1), (ROUTE_HEADER, OP_HEADER, SOURCE_HEADER)):
        old = baseline(path)
        require(len(read_rows(old, path, header)) == count, f"{path}: unexpected baseline count")
        current = (ROOT / path).read_bytes()
        require(current.startswith(old), f"{path}: old rows are not an exact byte prefix")
        if path == SHARED[2]:
            require(current == old, "Original natural source table changed")
        result[path] = {"rows": count, "bytes": len(old), "sha256": hashlib.sha256(old).hexdigest()}
    return {"baseline": BASE, "tables": result, "scope": "Three-table prefix preservation only; root separately protects all other source/data/QA/tool files."}


def routes() -> dict:
    rows = table(SHARED[0], ROUTE_HEADER)
    old = read_rows(baseline(SHARED[0]), SHARED[0], ROUTE_HEADER)
    require(len(rows) == 20 and set(rows) == set(old) | set(ROUTES), "Exactly twenty route IDs required")
    goals = table("data/progression_opportunity_goals.csv")
    require(len(goals) == 10 and all(row["runtime_status"] == "design_only" for row in goals.values()), "All ten goals must stay design_only")
    profiles, powers, ops = table("data/civilization_profiles.csv"), table("data/powers.csv"), table(SHARED[1], OP_HEADER)
    counts = Counter()
    for key, row in rows.items():
        require(row["runtime_status"] == "design_only" and row["delivery_mode"] == "direct_action" and row["delivery_bound"] == "0", f"{key}: unexpected status/delivery enum")
        require(row["goal_id"] in goals and row["profile"] == goals[row["goal_id"]]["profile_id"] and (not row["profile"] or row["profile"] in profiles), f"{key}: unresolved goal/profile")
        entries = row["entry_ids"].split("|")
        require(all(entries) and len(set(entries)) == len(entries) and all(entry in ops or entry in powers or entry in BUILTINS for entry in entries), f"{key}: invalid finite entry references")
        if key in ROUTES:
            require(tuple(row[field] for field in ("goal_id", "profile", "branch", "material_rule", "producer_task", "entry_ids")) == ROUTES[key], f"{key}: unexpected new route binding")
            require(row["coordination_task"] == "TASK-OPPORTUNITY-SCHEDULER" and row["consumer_task"] == "TASK-ANCHOR-ROUTES", f"{key}: wrong coordinator/consumer")
            counts[row["goal_id"]] += 1
    require(dict(counts) == {"GOAL_ANCHOR_CIV03": 2, "GOAL_ANCHOR_CIV06": 2, "GOAL_ANCHOR_CIV08": 2}, "Three current goals require two route indices each")
    return {"total": len(rows), "newPerGoal": dict(counts), "newRoutes": [rows[key] for key in ROUTES],
            "causalDistinctness": "independent_manual_QA_required", "realPipelineLatencyL": None, "wholeRouteBound": None}


def parameters() -> dict:
    rows = table("data/memory_contract_route_parameters.csv", ["id", "value", "unit", "rationale"])
    require(set(rows) == set(PARAMETERS), "Unexpected/missing memory-contract parameter")
    values = {key: parameter(rows, key, unit) for key, unit in PARAMETERS.items()}
    require(values["memory_contract_schema"] == 1 and values["pair_participants"] == 2 and values["practice_turns"] == 2 and values["reciprocal_legs"] == 2, "Unsupported finite parameter schema/shape")
    return values


def operations() -> dict:
    rows = table(SHARED[1], OP_HEADER)
    old = read_rows(baseline(SHARED[1]), SHARED[1], OP_HEADER)
    require(len(rows) == 18 and set(rows) == set(old) | set(OPERATIONS), "Exactly eighteen operation IDs required")
    for key, expected in OPERATIONS.items():
        row = rows[key]
        require(tuple(row[field] for field in OP_HEADER[1:10]) == expected and row["runtime_status"] == "design_only" and bool(row["rationale"]), f"{key}: unsupported grammar/parameters/status")
    values = parameters()
    for key in ("ROUTE_MEMORY_PRACTICE", "ROUTE_DISSENT_PRACTICE"):
        require(integer(rows[key]["participants_max"], key) == values["pair_participants"] and integer(rows[key]["repeat_turns"], key) == values["practice_turns"], f"{key}: pair/practice reference mismatch")
    require(integer(rows["ROUTE_RECIPROCAL_COVENANT"]["repeat_turns"], "reciprocal") == values["reciprocal_legs"], "Reciprocal leg reference mismatch")
    return {"total": len(rows), "newOperations": [rows[key] for key in OPERATIONS], "scope": "Finite declaration grammar, not installed handler coverage."}


def source_table() -> dict:
    rows = table(SHARED[2], SOURCE_HEADER)
    require(set(rows) == {"ROOT_COSMIC_RECHECK"} and rows["ROOT_COSMIC_RECHECK"]["runtime_status"] == "design_only", "Keep the sole original source declaration")
    roots = table("data/prayer_root_rules.csv")
    for key, owner in (("ROOT_CURRENT_PACT", "TASK-SOURCE-CONTRACT"), ("ROOT_SHARED_OBSERVATION", "TASK-SOURCE-MEMORY"), ("ROOT_MEMORY_REVIEW", "TASK-SOURCE-MEMORY")):
        require(roots[key]["producer_task"] == owner, f"{key}: wrong original natural owner")
    return {"total": 1, "newNaturalSourceRows": 0, "naturalSourceProductionVerified": False}


def task_dag() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    rows, cases = tracking["tasks"], tracking["scenarios"]
    require(isinstance(rows, list) and isinstance(cases, list), "Malformed task/scenario registry")
    by_id = {}
    for row in rows:
        require(isinstance(row, dict) and row.get("id") and row["id"] not in by_id, "Missing/duplicate actual task")
        by_id[row["id"]] = row
    required = {TASK: "design", MEMORY: "code", CONTRACT: "code", "TASK-MEMORY-CONTRACT-INTERFACE-DESIGN": "design",
                "TASK-MEMORY-CONTRACT-OPERATION-UI": "code", "TASK-CONTRACT-SUCCESSION-DESIGN": "design",
                "TASK-PROGRESSION-OPERATION-CORE": "code", "TASK-PROGRESSION-OPERATIONS": "code",
                "TASK-SOURCE-CONTRACT": "code", "TASK-SOURCE-MEMORY": "code", "TASK-ANCHOR-ROUTES": "code",
                "TASK-OPPORTUNITY-SCHEDULER": "code"}
    found = {}
    for key, owner in sorted(required.items()):
        require(key in by_id, f"{key}: missing actual task")
        row = by_id[key]
        require(row.get("owner") == owner and all(row.get(field) for field in ("title", "scope", "deliverables", "acceptance")), f"{key}: incomplete owner/brief/ACC")
        for acceptance in row["acceptance"]:
            matches = [case for case in cases if case.get("id") == acceptance]
            require(len(matches) == 1 and all(matches[0].get(field) for field in ("given", "when", "then")), f"{key}: missing real acceptance {acceptance}")
        found[key] = {field: row.get(field) for field in ("title", "owner", "status", "acceptance", "dependsOn")}
    parent = by_id["TASK-PROGRESSION-OPERATIONS"]
    require({MEMORY, CONTRACT, "TASK-MEMORY-CONTRACT-OPERATION-UI"} <= set(parent["dependsOn"]), "Implementation parent omits memory/contract children")
    require("TASK-MEMORY-CONTRACT-INTERFACE-DESIGN" in by_id["TASK-MEMORY-CONTRACT-OPERATION-UI"]["dependsOn"], "UI must depend on actual interface design")
    require("TASK-CONTRACT-SUCCESSION-DESIGN" in by_id["TASK-SOURCE-CONTRACT"]["dependsOn"], "Natural contract producer must wait for prospective succession design")
    require("TASK-SOURCE-MEMORY" in by_id[MEMORY]["dependsOn"] and "TASK-SOURCE-CONTRACT" in by_id[CONTRACT]["dependsOn"], "Operations must reuse their source kernels")
    require(by_id["TASK-PROGRESSION-ROUTES"]["status"] in {"planned", "in-progress", "blocked"}, "The full design parent needs its separate final integration")
    visited, active = set(), set()

    def visit(key: str) -> None:
        require(key in by_id, f"Unresolved real dependency {key}")
        require(key not in active, f"Task dependency cycle at {key}")
        if key in visited:
            return
        active.add(key)
        for dependency in by_id[key].get("dependsOn", []):
            visit(dependency)
        active.remove(key)
        visited.add(key)

    for key in required:
        visit(key)
    return {"tasks": found, "dependencyClosureNodes": len(visited), "cycle": False, "parentComplete": False,
            "scope": "Actual structured ownership, ACC and dependency references; not implementation acceptance."}


def old_witness_rules() -> dict:
    events = table("data/event_parameters.csv")
    required = parameter(events, "collective_required_witnesses", "person")
    anchor = table("data/anchor_conditions.csv", key="profile_id")
    spread = table("data/cult_spread_conditions.csv", key="profile_id")
    require(required == 3, "Original collective witness count changed")
    for profile in ("CIV_03", "CIV_08"):
        require(anchor[profile]["count_parameter"] == "collective_required_witnesses" and spread[profile]["count_parameter"] == "collective_required_witnesses", f"{profile}: original witness count reference lost")
        require(spread[profile]["alive_parameter"] == "collective_required_witnesses", f"{profile}: original strengthened spread requires three live witnesses")
    require(anchor["CIV_03"]["alive_parameter"] == "collective_required_witnesses" and anchor["CIV_03"]["alive_min"] == "", "CIV03 original anchor must retain all three")
    require(anchor["CIV_08"]["alive_parameter"] == "" and integer(anchor["CIV_08"]["alive_min"], "CIV08 alive") == 2, "CIV08 original anchor history3/current2 differs from spread3")
    return {"originalCIV03": {"history": required, "anchorCurrentAlive": required, "strengthenedSpreadAlive": required},
            "originalCIV08": {"history": required, "anchorCurrentAlive": 2, "strengthenedSpreadAlive": required},
            "newPairParticipants": parameters()["pair_participants"], "scope": "Original and new branches are distinct; two-person practice does not issue a third original witness or PR07 qualification."}


def stage_costs() -> dict:
    values = parameters()
    run, ops = table("data/run_parameters.csv"), table(SHARED[1], OP_HEADER)
    preparation = {"faith": values["preparation_faith"], "whispers": values["preparation_whispers"]}
    deep = {"faith": parameter(run, "prayer_deep_faith", "faith"), "whispers": parameter(run, "prayer_deep_whispers", "whispers")}
    # Finite stage grammar of events section 14.12.2. These are declarations
    # for future authorized handlers, not a separate effect implementation.
    stages = {
        "ROUTE_MEMORY_CIRCLE": {"convene": "preparation", "preserve": "deep"},
        "ROUTE_MEMORY_PRACTICE": {"empty_series": "deep", "existing_series": "deep"},
        "ROUTE_DISSENT_PRACTICE": {"empty_series": "deep", "existing_series": "deep"},
        "ROUTE_PACT_AGREEMENT": {"agreement": "preparation"},
        "ROUTE_PACT_PERFORMANCE": {"performance": "deep"},
        "ROUTE_RECIPROCAL_COVENANT": {"agree": "preparation", "fulfill_each_original_leg": "deep"},
    }
    require(set(stages) == set(OPERATIONS), "A new operation has no finite stage-cost declaration")
    result = {}
    for key, modes in stages.items():
        row = ops[key]
        expected_rule = "memory_circle_stage" if key == "ROUTE_MEMORY_CIRCLE" else (
            "reciprocal_covenant_stage" if key == "ROUTE_RECIPROCAL_COVENANT" else (
                "memory_contract_preparation" if key == "ROUTE_PACT_AGREEMENT" else "prayer_deep"))
        require(row["cost_rule"] == expected_rule, f"{key}: stage cost selector changed")
        result[key] = {}
        for stage, mode in modes.items():
            side_effects = {field: 0 if mode == "preparation" else integer(row[field], key + "." + field)
                            for field in ("success_pollution", "always_alert", "always_sanity_loss")}
            result[key][stage] = {"formalCostReference": "memory_contract_route_parameters.preparation" if mode == "preparation" else "run_parameters.prayer_deep",
                                 **(preparation if mode == "preparation" else deep),
                                 "check": "deterministic" if mode == "preparation" else "occult_adaptation", **side_effects}
    return {"operations": result, "preparation": preparation, "deep": deep,
            "scope": "Finite cost-reference and phase mapping from the authored protocol; no handler payment, deterministic result or effect was executed."}


def budgets() -> dict:
    values, costs = parameters(), stage_costs()
    run, fidelity = table("data/run_parameters.csv"), table("data/fidelity_parameters.csv")
    events, ops = table("data/event_parameters.csv"), table(SHARED[1], OP_HEADER)
    faith = parameter(run, "initial_faith", "faith")
    whispers = parameter(run, "whisper_base", "whispers_per_turn")
    lifetime = parameter(events, "prayer_lifetime_default", "turn")
    p_limit = parameter(fidelity, "temporary_actor_limit", "person")
    n_limit = parameter(fidelity, "bound_member_limit", "person")
    actor_limit = parameter(fidelity, "candidate_actor_limit", "person_per_candidate")
    f_limit = parameter(fidelity, "focused_domain_limit", "domain")
    require(4 <= actor_limit and 3 <= p_limit and 2 <= n_limit and f_limit >= 1, "Necessary four-person/one-domain or two-bound-person budget unavailable")
    require(all(stage["whispers"] <= whispers for stages in costs["operations"].values() for stage in stages.values()), "An isolated stage exceeds original base-whisper budget")
    prep, deep = costs["preparation"], costs["deep"]
    practice = values["practice_turns"]
    legs = values["reciprocal_legs"]
    require(lifetime >= 1 and legs <= lifetime, "Earliest later-turn preservation/two legs cannot fit the original fixed due window")
    trials = {
        "memory_circle": {"preparations": 1, "successfulOccultActions": 1, "relativeTurns": [0, 1], "minimumDistinctPeople": 4, "exampleN": 1, "exampleP": 3, "dueOffset": lifetime},
        "memory_practice": {"preparations": 0, "successfulOccultActions": practice, "relativeTurns": [index * (integer(ops["ROUTE_MEMORY_PRACTICE"]["cooldown_turns"], "memory cooldown") + 1) for index in range(practice)], "minimumDistinctPeople": values["pair_participants"], "exampleN": 1, "exampleP": 1, "dueOffset": None},
        "dissent_practice": {"preparations": 0, "successfulOccultActions": practice, "relativeTurns": [index * (integer(ops["ROUTE_DISSENT_PRACTICE"]["cooldown_turns"], "dissent cooldown") + 1) for index in range(practice)], "minimumDistinctPeople": values["pair_participants"], "exampleN": 1, "exampleP": 1, "dueOffset": None},
        "contract_performance": {"preparations": 1, "successfulOccultActions": 1, "relativeTurns": [0, 1], "minimumDistinctPeople": 2, "exampleN": 1, "exampleP": 1, "dueOffset": lifetime},
        "contract_reciprocal": {"preparations": 1, "successfulOccultActions": legs, "relativeTurns": list(range(legs + 1)), "minimumDistinctPeople": 2, "exampleN": 2, "exampleP": 0, "dueOffset": lifetime},
    }
    for name, row in trials.items():
        row["faithForListedSuccessfulMaterialActions"] = row["preparations"] * prep["faith"] + row["successfulOccultActions"] * deep["faith"]
        row["whispersAcrossDifferentTurns"] = row["preparations"] * prep["whispers"] + row["successfulOccultActions"] * deep["whispers"]
        require(row["faithForListedSuccessfulMaterialActions"] <= faith, f"{name}: listed material sequence exceeds unchanged initial faith")
        require(len(set(row["relativeTurns"])) == len(row["relativeTurns"]), f"{name}: stages incorrectly share an actor opportunity")
        if row["dueOffset"] is not None:
            require(max(row["relativeTurns"]) <= row["dueOffset"], f"{name}: earliest successful sequence exceeds its fixed due")
        require(row["exampleN"] <= n_limit and row["exampleP"] <= p_limit and row["exampleN"] + row["exampleP"] == row["minimumDistinctPeople"], f"{name}: invalid deduplicated capacity example")
    return {"materialSequences": trials, "formalLimits": {"N": n_limit, "P": p_limit, "F": f_limit, "candidateActors": actor_limit, "baseWhispers": whispers, "initialFaith": faith},
            "assumptions": ["All listed real people, bound actors, records, relations, reciprocal links, institution duties and knowledge already qualify.",
                            "Required N/P slots and actual participant opportunities are free; all participants remain eligible throughout.",
                            "Every listed occult action actually succeeds; there are no competing payments or world losses and no income is predicted.",
                            "Relative turns are conditional earliest opportunities from T=0, not the campaign initialization phase or a route completion guarantee."],
            "fullAnchorFundingOrPollutionProved": False, "scope": "Necessary material-stage arithmetic only. It neither builds a legal snapshot nor proves natural reachability, real service, complete anchor funding or success."}


def main() -> int:
    checks, before = [], {}
    try:
        before = hashes()
    except (OSError, ValueError) as error:
        checks.append({"id": "MCR-INPUTS", "status": "fail", "error": str(error)})
    checks_to_run = [("MCR-PRESERVED-PREFIX", preservation), ("MCR-ROUTES", routes), ("MCR-OPERATIONS", operations),
                     ("MCR-PARAMETERS", parameters), ("MCR-SOURCE", source_table), ("MCR-TASK-DAG-ACC", task_dag),
                     ("MCR-ORIGINAL-WITNESS-RULES", old_witness_rules)]
    checks_to_run += [("MCR-STAGE-COSTS", stage_costs), ("MCR-CONDITIONAL-BUDGET", budgets)]
    for key, operation in checks_to_run:
        try:
            checks.append({"id": key, "status": "pass", "details": operation()})
        except (OSError, ValueError, KeyError, TypeError, csv.Error) as error:
            checks.append({"id": key, "status": "fail", "error": str(error)})
    try:
        frozen = bool(before) and before == hashes()
    except (OSError, ValueError):
        frozen = False
    checks.append({"id": "MCR-SOURCE-FROZEN", "status": "pass" if frozen else "fail"})
    passed = all(check["status"] == "pass" for check in checks)
    result = {"schemaVersion": 1, "task": TASK, "title": f"{TASK} — {TITLE}", "status": "pass" if passed else "fail",
              "generatedAt": datetime.now(timezone.utc).isoformat(), "command": ["python", "tools/memory-contract-routes/verify.py"],
              "pythonVersion": sys.version.split()[0], "acceptanceScope": "static_contract_and_conditional_algebra_only",
              "sourceHashes": before, "checks": checks, "realPipelineLatencyL": None, "wholeRouteCompletionBound": None,
              "limitations": ["All declarations remain design_only; twenty route indices do not complete the full parent.", "Causal alternatives and knowledge/material eligibility require independent manual QA, not counts or matching strings.", "No game, natural generation, transaction, save/restore, UI or handler fault injection was executed.", "Admission, source expiry, actual participants, check outcomes and per-person opportunity remain real implementation obligations.", "direct_action zero applies only to one installed currently qualified step; it is not a zero-turn route or success guarantee."]}
    with (HERE / "results.json").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{'PASS' if passed else 'FAIL'} {TASK} — {TITLE}: {sum(check['status'] == 'pass' for check in checks)}/{len(checks)} (static only)")
    for check in checks:
        if check["status"] == "fail":
            print(f"  {check['id']}: {check.get('error', 'source bytes changed during run')}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
