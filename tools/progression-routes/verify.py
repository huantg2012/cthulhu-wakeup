"""Finite static summary for Critical Progression Routes and Opportunity Guarantees."""
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
TASK = "TASK-PROGRESSION-ROUTES"
TITLE = "Critical Progression Routes and Opportunity Guarantees"
BASE = "503809d"
SHARED = ("data/progression_routes.csv", "data/progression_route_operations.csv", "data/progression_route_sources.csv")
DESCRIPTIONS = {"data/civilization_conditions.csv": ("profile_id", {"entry_requirement", "spread_requirement", "institution_acceptance", "forbidden_shortcut"}),
                "data/civilization_profiles.csv": ("id", {"entry_route", "spread_route", "anchor_route"})}
INPUTS = SHARED + (
    "data/opportunity_parameters.csv", "data/progression_opportunity_goals.csv",
    "data/foundation_route_parameters.csv", "data/memory_contract_route_parameters.csv",
    "data/civilization_conditions.csv", "data/civilization_profiles.csv", "data/civilization_parameters.csv",
    "data/fidelity_parameters.csv", "data/run_parameters.csv", "data/event_parameters.csv", "data/powers.csv",
    "data/anchor_conditions.csv", "data/cult_spread_conditions.csv", "data/prayer_root_rules.csv",
    "docs/specs/system-events.md", "docs/specs/system-civilizations.md", "docs/specs/system-progression.md",
    "docs/specs/system-powers-cults.md", "docs/specs/system-turn-economy.md", "docs/architecture.md",
    "docs/implementation/traceability.json", "docs/tasks/slice-14.md",
    "tools/progression-routes/verify.py", "tools/progression-routes/README.md",
)
ROUTE_HEADER = ["id", "goal_id", "profile", "branch", "entry_ids", "material_rule", "delivery_mode", "delivery_bound",
                "producer_task", "coordination_task", "consumer_task", "runtime_status"]
OP_HEADER = ["id", "mode", "cost_rule", "check_rule", "cooldown_turns", "success_pollution", "always_alert", "always_sanity_loss",
             "participants_max", "repeat_turns", "runtime_status", "rationale"]
SOURCE_HEADER = ["id", "phase", "handler", "product_kind", "due_policy", "producer_task", "runtime_status"]
GOAL_HEADER = ["id", "milestone", "instance_scope", "profile_id", "completion_rule", "route_design_task", "runtime_status"]
GOALS = {"GOAL_FIRST_CULT", "GOAL_MANIFEST"} | {f"GOAL_ANCHOR_CIV{number:02d}" for number in range(1, 9)}
BUSINESS = {
    "TASK-AXIOM-OPERATIONS": {"ROUTE_AXIOM_PROBE", "ROUTE_AXIOM_RECHECK", "ROUTE_AXIOM_REPEAT"},
    "TASK-NETWORK-OPERATIONS": {"ROUTE_GUIDED_DREAM", "ROUTE_NETWORK_EXCHANGE"},
    "TASK-FOUNDATION-CONTACT-OPERATIONS": {"ROUTE_PRIVATE_DEVOTION", "ROUTE_JOINT_WORK", "ROUTE_COVERT_GATHERING"},
    "TASK-FOUNDATION-RECORD-OPERATIONS": {"ROUTE_RECORD_PRACTICE"},
    "TASK-FOUNDATION-RITUAL-OPERATIONS": {"ROUTE_CALENDAR_RITE", "ROUTE_CALENDAR_KEEPING", "ROUTE_RITUAL_TRANSMISSION"},
    "TASK-MEMORY-OPERATIONS": {"ROUTE_MEMORY_CIRCLE", "ROUTE_MEMORY_PRACTICE", "ROUTE_DISSENT_PRACTICE"},
    "TASK-CONTRACT-OPERATIONS": {"ROUTE_PACT_AGREEMENT", "ROUTE_PACT_PERFORMANCE", "ROUTE_RECIPROCAL_COVENANT"},
}
UI_GROUPS = {
    "TASK-PROGRESSION-OPERATION-UI": ("TASK-PROGRESSION-INTERFACE-DESIGN", {"TASK-AXIOM-OPERATIONS", "TASK-NETWORK-OPERATIONS"}),
    "TASK-FOUNDATION-OPERATION-UI": ("TASK-FOUNDATION-INTERFACE-DESIGN", {"TASK-FOUNDATION-CONTACT-OPERATIONS", "TASK-FOUNDATION-RECORD-OPERATIONS", "TASK-FOUNDATION-RITUAL-OPERATIONS"}),
    "TASK-MEMORY-CONTRACT-OPERATION-UI": ("TASK-MEMORY-CONTRACT-INTERFACE-DESIGN", {"TASK-MEMORY-OPERATIONS", "TASK-CONTRACT-OPERATIONS"}),
}
DESIGN_TASKS = {"TASK-OPPORTUNITY-CONTRACT-DESIGN", "TASK-AXIOM-NETWORK-ROUTES", "TASK-FOUNDATION-ROUTES-DESIGN", "TASK-MEMORY-CONTRACT-ROUTES"}
BUILTINS = {"POWER_MANIFEST_CONTINUE", "SESSION_REST", "SESSION_SET_ECONOMY_PLAN"}
PARAMETERS = {
    "data/opportunity_parameters.csv": {"policy_version": "version", "base_goal_weight": "weight", "missed_slot_weight_step": "weight_per_missed_due_slot", "forced_after_missed_slots": "eligible_due_slot", "retry_cooldown_due_slots": "due_slot", "minimum_action_windows": "complete_actions_phase"},
    "data/foundation_route_parameters.csv": {"private_whispers": "whispers", "private_faith": "faith", "joint_work_whispers": "whispers", "joint_work_faith": "faith", "gathering_whispers": "whispers", "gathering_faith": "faith", "gathering_followers": "persons", "rite_followers": "persons", "practice_required_turns": "turns", "transmission_required_stages": "stages", "foundation_schema": "version"},
    "data/memory_contract_route_parameters.csv": {"preparation_whispers": "whispers", "preparation_faith": "faith", "pair_participants": "persons", "practice_turns": "distinct_turns", "reciprocal_legs": "obligations", "memory_contract_schema": "version"},
}


class InvalidContract(ValueError):
    pass


def require(value: bool, message: str) -> None:
    if not value:
        raise InvalidContract(message)


def decode(raw: bytes, name: str, header: list[str] | None = None, key: str = "id") -> tuple[list[str], dict]:
    reader = csv.reader(io.StringIO(raw.decode("utf-8-sig"), newline=""), strict=True)
    fields = next(reader, None)
    require(bool(fields) and key in fields and len(set(fields)) == len(fields), f"{name}: malformed header")
    require(header is None or fields == header, f"{name}: unexpected schema")
    rows = {}
    for line, cells in enumerate(reader, 2):
        require(len(cells) == len(fields) and all(cell == cell.strip() for cell in cells), f"{name}:{line}: malformed fields")
        row = dict(zip(fields, cells))
        require(bool(row[key]) and row[key] not in rows, f"{name}:{line}: blank/duplicate {key}")
        rows[row[key]] = row
    require(bool(rows), f"{name}: empty table")
    return fields, rows


def table(path: str, header: list[str] | None = None, key: str = "id") -> dict:
    return decode((ROOT / path).read_bytes(), path, header, key)[1]


def baseline(path: str) -> bytes:
    result = subprocess.run(["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, check=False)
    require(result.returncode == 0, f"Cannot read baseline {BASE}:{path}")
    return result.stdout


def integer(value: str, name: str) -> int:
    require(bool(re.fullmatch(r"0|[1-9][0-9]*", value)), f"{name}: noncanonical nonnegative integer")
    return int(value)


def parameter(rows: dict, key: str, unit: str) -> int:
    require(key in rows and rows[key]["unit"] == unit and bool(rows[key]["rationale"]), f"{key}: missing parameter/unit/rationale")
    return integer(rows[key]["value"], key)


def hashes() -> dict:
    result = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS}
    result.update({f"git:{BASE}:{path}": hashlib.sha256(baseline(path)).hexdigest() for path in SHARED + tuple(DESCRIPTIONS)})
    return result


def frozen_tables() -> dict:
    result = {}
    for path, count, header in zip(SHARED, (20, 18, 1), (ROUTE_HEADER, OP_HEADER, SOURCE_HEADER)):
        old = baseline(path)
        require((ROOT / path).read_bytes() == old, f"{path}: full frozen table differs from {BASE}")
        require(len(decode(old, path, header)[1]) == count, f"{path}: incorrect full baseline count")
        result[path] = {"rows": count, "bytes": len(old), "sha256": hashlib.sha256(old).hexdigest()}
    return {"baseline": BASE, "tables": result, "scope": "Full three-table byte equality; root independently checks every other protected old source/data/QA/tool file."}


def goal_routes() -> dict:
    goals = table("data/progression_opportunity_goals.csv", GOAL_HEADER)
    rows, profiles = table(SHARED[0], ROUTE_HEADER), table("data/civilization_profiles.csv")
    require(set(goals) == GOALS and set(profiles) == {f"CIV_{index:02d}" for index in range(1, 9)}, "Goal/profile index differs from the finite ten/eight contract")
    require(len(rows) == 20 and all(goal["runtime_status"] == "design_only" for goal in goals.values()), "Twenty routes and ten design-only goals required")
    counts, branches = Counter(), set()
    for key, row in rows.items():
        require(row["goal_id"] in goals and row["runtime_status"] == "design_only", f"{key}: invalid goal/status")
        goal = goals[row["goal_id"]]
        require(row["profile"] == goal["profile_id"] and bool(row["branch"]) and bool(row["material_rule"]), f"{key}: missing/mismatched profile/branch/material")
        identity = (row["goal_id"], row["branch"])
        require(identity not in branches, f"{key}: duplicate declared branch")
        branches.add(identity); counts[row["goal_id"]] += 1
        require(row["delivery_mode"] == "direct_action" and row["delivery_bound"] == "0", f"{key}: unexpected delivery declaration")
        require(goal["route_design_task"] in DESIGN_TASKS, f"{key}: unassigned design batch")
        if row["profile"]:
            require(goal["instance_scope"] == "institution" and row["profile"] in profiles and goal["milestone"] == "active_anchor" and goal["completion_rule"] == "current_anchor_active", f"{key}: invalid institutional goal")
        else:
            require(row["goal_id"] in {"GOAL_FIRST_CULT", "GOAL_MANIFEST"} and goal["instance_scope"] == "run", f"{key}: invalid run goal")
            expected = ("first_cult", "first_cult_established") if row["goal_id"] == "GOAL_FIRST_CULT" else ("manifest_complete", "manifest_complete")
            require((goal["milestone"], goal["completion_rule"]) == expected, f"{key}: invalid run milestone/completion enum")
    require(dict(counts) == {key: 2 for key in GOALS}, "Each of ten goals needs two indexed routes")
    return {"goals": len(goals), "routeCount": len(rows), "perGoal": dict(sorted(counts.items())),
            "causalDistinctnessAndEligibility": "independent_manual_QA_required", "allRuntimeStatus": "design_only",
            "deliveryBoundary": "zero is only one installed currently qualified direct step, not whole-route latency, current executability or success",
            "realPipelineLatencyL": None, "wholeRouteBound": None}


def parameter_tables() -> dict:
    result = {}
    for path, expected in PARAMETERS.items():
        rows = table(path, ["id", "value", "unit", "rationale"])
        require(set(rows) == set(expected), f"{path}: unexpected finite parameter IDs")
        result[path] = {key: parameter(rows, key, unit) for key, unit in expected.items()}
    require(all(value > 0 for value in result["data/opportunity_parameters.csv"].values()), "All six shared opportunity parameters must be positive")
    require(result["data/opportunity_parameters.csv"]["policy_version"] == 1 and result["data/foundation_route_parameters.csv"]["foundation_schema"] == 1 and result["data/memory_contract_route_parameters.csv"]["memory_contract_schema"] == 1, "Unknown design parameter schema")
    return result


def operation_sources() -> dict:
    ops, powers, rows = table(SHARED[1], OP_HEADER), table("data/powers.csv"), table(SHARED[0], ROUTE_HEADER)
    require(set(ops) == set().union(*BUSINESS.values()) and len(ops) == 18, "Eighteen finite operations need unique business assignment")
    params, run = parameter_tables(), table("data/run_parameters.csv")
    found = params["data/foundation_route_parameters.csv"]
    memory = params["data/memory_contract_route_parameters.csv"]
    deep = {"faith": parameter(run, "prayer_deep_faith", "faith"), "whispers": parameter(run, "prayer_deep_whispers", "whispers")}
    prep = {"faith": memory["preparation_faith"], "whispers": memory["preparation_whispers"]}
    costs = {}
    for key, row in ops.items():
        require(row["mode"] == key.removeprefix("ROUTE_").lower() and row["runtime_status"] == "design_only" and bool(row["rationale"]), f"{key}: unknown mode/status")
        participants = integer(row["participants_max"], key)
        require(1 <= participants <= 4, f"{key}: participants outside finite bound")
        rule = row["cost_rule"]
        if rule == "POWER_DREAM":
            require(key == "ROUTE_GUIDED_DREAM" and row["check_rule"] == "POWER_DREAM", "Only guided DREAM delegates original power")
            require(all(row[field] == "" for field in ("cooldown_turns", "success_pollution", "always_alert", "always_sanity_loss", "repeat_turns")), "Guided DREAM must not duplicate inherited effects")
            costs[key] = {"use": {"faith": integer(powers["POWER_DREAM"]["faith"], "DREAM faith"), "whispers": integer(powers["POWER_DREAM"]["whispers"], "DREAM whispers")}}
            continue
        for field in ("cooldown_turns", "success_pollution", "always_alert", "always_sanity_loss"):
            integer(row[field], key + "." + field)
        if row["repeat_turns"]:
            require(integer(row["repeat_turns"], key) == 2, f"{key}: unknown repeat contract")
        if rule == "prayer_deep":
            require(row["check_rule"] == "occult_adaptation", f"{key}: deep trial check mismatch")
            costs[key] = {"each_real_trial": deep.copy()}
        elif rule in {"foundation_private", "foundation_joint_work", "foundation_gathering"}:
            prefix = {"foundation_private": "private", "foundation_joint_work": "joint_work", "foundation_gathering": "gathering"}[rule]
            require(row["check_rule"] == ("deterministic" if prefix == "private" else "social_influence"), f"{key}: foundation check mismatch")
            costs[key] = {"use": {"faith": found[prefix + "_faith"], "whispers": found[prefix + "_whispers"]}}
        elif rule == "memory_contract_preparation":
            require(key == "ROUTE_PACT_AGREEMENT" and row["check_rule"] == "deterministic", "Only original finite agreement preparation is declared")
            costs[key] = {"agreement": prep.copy()}
        elif rule in {"memory_circle_stage", "reciprocal_covenant_stage"}:
            require(row["check_rule"] == "stage_deterministic_or_occult", f"{key}: stage-check mismatch")
            expected = "ROUTE_MEMORY_CIRCLE" if rule == "memory_circle_stage" else "ROUTE_RECIPROCAL_COVENANT"
            require(key == expected, f"{key}: invalid stage selector")
            stages = ("convene", "preserve") if rule == "memory_circle_stage" else ("agree", "fulfill_each_original_leg")
            costs[key] = {stages[0]: prep.copy(), stages[1]: deep.copy()}
        else:
            raise InvalidContract(f"{key}: unknown cost rule {rule}")
    referenced = set()
    for key, row in rows.items():
        entries = row["entry_ids"].split("|")
        require(all(entries) and len(set(entries)) == len(entries), f"{key}: empty/duplicate entry")
        require(all(entry in ops or entry in powers or entry in BUILTINS for entry in entries), f"{key}: unresolved entry")
        referenced.update(set(entries) & set(ops))
    require(referenced == set(ops), "An operation has no route reference")
    sources = table(SHARED[2], SOURCE_HEADER)
    require(set(sources) == {"ROOT_COSMIC_RECHECK"}, "One original natural root declaration required")
    source = sources["ROOT_COSMIC_RECHECK"]
    require(source["phase"] == "4" and source["handler"] == "current_same_exception_recheck" and source["due_policy"] == "source_validity" and source["producer_task"] == "TASK-SOURCE-EXCEPTION" and source["runtime_status"] == "design_only", "Invalid original root grammar")
    require(set(source["product_kind"].split("|")) == {"exception_reference_read", "law_observation"}, "Invalid original root products")
    return {"operations": len(ops), "sources": len(sources), "formalStageCosts": costs,
            "preparationBoundary": "Deterministic preparation does not apply occult-stage pollution/alert/sanity or issue dependencies",
            "scope": "Static finite references and cost declarations only; not handler installation, payment or natural source execution."}


def registry_ownership() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    operations = table(SHARED[1], OP_HEADER)
    registry = {}
    for task, entries in BUSINESS.items():
        for entry in entries:
            require(entry not in registry and entry in operations, f"{entry}: duplicate/unresolved business registration")
            interfaces = [ui for ui, (_, owners) in UI_GROUPS.items() if task in owners]
            require(len(interfaces) == 1, f"{entry}: ambiguous UI responsibility")
            registry[entry] = {"businessTask": task, "interfaceTask": interfaces[0], "coreTask": "TASK-PROGRESSION-OPERATION-CORE"}
    require(len(registry) == 18, "The finite operation responsibility manifest omits entries")
    for key, row in table(SHARED[0], ROUTE_HEADER).items():
        require(row["coordination_task"] == "TASK-OPPORTUNITY-SCHEDULER", f"{key}: wrong shared coordinator")
        require(row["consumer_task"] == ("TASK-ENDINGS" if row["goal_id"] == "GOAL_MANIFEST" else "TASK-CULT-SPREAD" if row["goal_id"] == "GOAL_FIRST_CULT" else "TASK-ANCHOR-ROUTES"), f"{key}: wrong route consumer")
        require(row["producer_task"] in BUSINESS or row["producer_task"] in {"TASK-ANCHOR-LIFECYCLE", "TASK-ECONOMY"}, f"{key}: no finite producer task")
    writes = {"SET-OPPORTUNITY": {"opportunities.goals", "opportunities.next_queue_seq"},
              "SET-PROGRESSION-OPERATIONS": {"progression_routes.cooldowns", "progression_routes.use_heads", "progression_routes.network_heads", "progression_routes.foundation_heads", "progression_routes.memory_heads", "progression_routes.contract_heads"}}
    for contract, fields in writes.items():
        matches = [item for item in tracking["contracts"] if item.get("id") == contract]
        require(len(matches) == 1 and set(matches[0]["writes"]) == fields and len(matches[0]["writes"]) == len(fields), f"{contract}: missing/ambiguous structured writer fields")
        for field in fields:
            owners = [item["id"] for item in tracking["contracts"] if field in item.get("writes", [])]
            require(owners == [contract], f"{field}: multiple settlement-contract declarations")
    return {"operations": registry, "settlementWrites": {key: sorted(value) for key, value in writes.items()},
            "scope": "Unique static business/UI and settlement-field declarations; this does not inspect or certify actual source-code writers."}


def task_dag() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    by_id = {}
    for row in tracking["tasks"]:
        require(isinstance(row, dict) and row.get("id") and row["id"] not in by_id, "Missing/duplicate structured task")
        by_id[row["id"]] = row
    required = {key: "code" for key in set(BUSINESS) | set(UI_GROUPS)}
    required.update({design: "design" for design, _ in UI_GROUPS.values()})
    required.update({key: "design" for key in DESIGN_TASKS | {TASK, "TASK-CONTRACT-SUCCESSION-DESIGN"}})
    required.update({key: "code" for key in ("TASK-PROGRESSION-OPERATION-CORE", "TASK-PROGRESSION-OPERATIONS", "TASK-SOURCE-MEMORY", "TASK-SOURCE-CONTRACT", "TASK-SOURCE-EXCEPTION", "TASK-ANCHOR-ROUTES", "TASK-CULT-SPREAD", "TASK-ANCHOR-LIFECYCLE", "TASK-ECONOMY", "TASK-ENDINGS", "TASK-OPPORTUNITY-SCHEDULER", "TASK-CULT-SAVE-COMPAT", "TASK-SOURCE-CLOSURE")})
    required["TASK-NATURAL-VERIFY"] = "qa"
    found = {}
    for key, owner in sorted(required.items()):
        require(key in by_id, f"{key}: no real task object")
        row = by_id[key]
        require(row.get("owner") == owner and all(row.get(field) for field in ("title", "scope", "deliverables", "acceptance")), f"{key}: incomplete owner/brief/ACC")
        for acceptance in row["acceptance"]:
            cases = [case for case in tracking["scenarios"] if case.get("id") == acceptance]
            require(len(cases) == 1 and all(cases[0].get(field) for field in ("given", "when", "then")), f"{key}: unresolved real ACC {acceptance}")
        found[key] = {field: row.get(field) for field in ("title", "owner", "status", "acceptance", "dependsOn")}
    require(DESIGN_TASKS <= set(by_id[TASK]["dependsOn"]), "Parent design omits a design batch")
    for ui, (design, business) in UI_GROUPS.items():
        require({design} | business <= set(by_id[ui]["dependsOn"]), f"{ui}: missing real design/business dependency")
    require(set(BUSINESS) | set(UI_GROUPS) | {"TASK-PROGRESSION-OPERATION-CORE"} <= set(by_id["TASK-PROGRESSION-OPERATIONS"]["dependsOn"]), "Implementation parent omits a required operation/UI child")
    require("TASK-CONTRACT-SUCCESSION-DESIGN" in by_id["TASK-SOURCE-CONTRACT"]["dependsOn"], "SourceContract must wait for actual succession design")
    require("TASK-SOURCE-MEMORY" in by_id["TASK-MEMORY-OPERATIONS"]["dependsOn"] and "TASK-SOURCE-CONTRACT" in by_id["TASK-CONTRACT-OPERATIONS"]["dependsOn"], "Business operations must reuse their natural source kernels")
    visited, active = set(), set()

    def visit(key: str) -> None:
        require(key in by_id and key not in active, f"Missing dependency or cycle at {key}")
        if key in visited:
            return
        active.add(key)
        for dependency in by_id[key].get("dependsOn", []):
            visit(dependency)
        active.remove(key); visited.add(key)

    for key in required:
        visit(key)
    return {"tasks": found, "dependencyClosureNodes": len(visited), "cycle": False,
            "scope": "Actual structured task ownership/ACC/DAG; status labels are metadata, not gameplay evidence."}


def opportunity_bound() -> dict:
    params = parameter_tables()["data/opportunity_parameters.csv"]
    civilization, fidelity = table("data/civilization_parameters.csv"), table("data/fidelity_parameters.csv")
    d = parameter(civilization, "domains_total", "domain")
    i = parameter(civilization, "institutions_per_domain", "institution")
    require(d == sum(parameter(civilization, tier + "_domains", "domain") for tier in ("planet", "system", "cosmic")), "Formal domain count differs from tier sum")
    interval = parameter(fidelity, "background_tick_interval", "turn")
    require(parameter(fidelity, "background_candidate_trials", "trial_per_due_domain") == 1, "Pure B proof requires original one-trial due slots")
    run_goals = [row for row in table("data/progression_opportunity_goals.csv").values() if row["instance_scope"] == "run"]
    q, maximum = i + len(run_goals), d * i + len(run_goals)
    threshold = params["forced_after_missed_slots"]
    bound = interval * (threshold + q)
    require((d, i, maximum, q, interval, threshold, bound) == (12, 3, 38, 5, 4, 2, 28), "Frozen shared B formula changed; review formal inputs")
    ranks = [{"rank": rank, "firstDueDelay": delay, "grantAfterTurns": delay + interval * (threshold + rank - 1)}
             for rank in range(1, q + 1) for delay in range(1, interval + 1)]
    require(max(row["grantAfterTurns"] for row in ranks) == bound, "Finite FIFO rank/phase algebra fails to reach the conservative maximum")
    # One small abstract ticket example: failed X consumes its committed ticket
    # and rejoins behind Y. This is not a world or pipeline simulator.
    tickets = ["X", "Y"]
    first = tickets.pop(0); tickets.append(first)
    second = tickets.pop(0)
    require(first == "X" and second == "Y", "Fresh retry ticket must not overtake Y")
    return {"globalInstanceMax": maximum, "perDomainMax": q, "interval": interval, "forcedAfterMisses": threshold,
            "pureCommittedBDispatchBound": bound, "rankPhaseCases": ranks, "failedPeerNewTailTicket": [first, second],
            "premises": ["Same host, continuously serviceable, one current step per goal; route count grants no extra tickets.", "All ordinary random slots can miss; FIFO force bypasses that random gate.", "Committed grant consumes its unique ticket; inflight has no B ticket; legal retry preserves debt but rejoins at tail.", "Uncommitted faults restore ticket and do not consume a slot; normal precommit invalidation rechecks at most Q current tickets without monopolizing a committed grant."],
            "realPipelineLatencyL": None, "actualServiceBound": None, "scope": "B dispatch algebra only. No A/fix/offer/actions pipeline, real transaction rollback or natural service was tested."}


def material_budgets() -> dict:
    params = parameter_tables(); run, events = table("data/run_parameters.csv"), table("data/event_parameters.csv")
    found, memory = params["data/foundation_route_parameters.csv"], params["data/memory_contract_route_parameters.csv"]
    deep = parameter(run, "prayer_deep_faith", "faith")
    prep = memory["preparation_faith"]
    costs = {"circle": prep + deep, "pairPractice": memory["practice_turns"] * deep, "singleContract": prep + deep, "reciprocal": prep + memory["reciprocal_legs"] * deep}
    require(costs == {"circle": 5, "pairPractice": 8, "singleContract": 5, "reciprocal": 9}, "Frozen conditional material costs changed")
    followers, spend = parameter(run, "cult_form_followers", "followers"), parameter(run, "cult_form_local_spend", "faith_spent")
    require(2 * found["gathering_followers"] == 2 * found["rite_followers"] == followers and 2 * found["gathering_faith"] == 2 * deep == spend, "Two-success first-cult arithmetic no longer matches original thresholds")
    original = parameter(events, "collective_required_witnesses", "person")
    anchor = table("data/anchor_conditions.csv", key="profile_id"); spread = table("data/cult_spread_conditions.csv", key="profile_id")
    require(original == 3 and anchor["CIV_03"]["alive_parameter"] == "collective_required_witnesses" and integer(anchor["CIV_08"]["alive_min"], "CIV08 alive") == 2, "Original memory alive/historical distinctions changed")
    require(all(spread[key]["alive_parameter"] == "collective_required_witnesses" for key in ("CIV_03", "CIV_08")), "Original strengthened memory spread still requires three alive")
    lifetime = parameter(events, "prayer_lifetime_default", "turn")
    operations = table(SHARED[1], OP_HEADER)
    pair_intervals = {key: integer(operations[key]["cooldown_turns"], key + ".cooldown_turns") + 1
                      for key in ("ROUTE_MEMORY_PRACTICE", "ROUTE_DISSENT_PRACTICE")}
    require(set(pair_intervals.values()) == {2}, "Pair practice must retain the complete intervening cooldown turn")
    require(memory["reciprocal_legs"] <= lifetime and memory["practice_turns"] == 2, "Conditional staged sequence cannot fit fixed deadline/count")
    require(max(costs.values()) <= parameter(run, "initial_faith", "faith"), "Listed material-only success costs exceed original starting cash")
    return {"conditionalMaterialFaith": costs, "firstCult": {"actualSuccessfulActivities": 2, "convertedIfPoolAvailable": followers, "actualLocalSpend": spend},
            "originalMemory": {"CIV03HistoryAndAlive": original, "CIV08History": original, "CIV08AnchorAlive": 2, "strengthenedSpreadAlive": original},
            "relativeEarliestTurns": {"circleOrSingleContract": [0, 1], "pairPractices": {key: [0, interval] for key, interval in pair_intervals.items()}, "reciprocal": list(range(memory["reciprocal_legs"] + 1))},
            "fixedDueOffset": lifetime, "wholeRouteFundingProved": False,
            "assumptions": ["Genuine eligible actors, relations, records, roles, carriers and capacity already exist; every listed occult activity succeeds.", "Only current cash is used; no competing spending, adverse world change or predicted income. These costs exclude earlier acquisition, anchor casting and upkeep."],
            "scope": "Necessary conditional material arithmetic only; not a lawful new-game fixture, payment/knowledge/custody proof, negative behavior test or success guarantee."}


def manifestation_capacity() -> dict:
    run, fidelity, civilization = table("data/run_parameters.csv"), table("data/fidelity_parameters.csv"), table("data/civilization_parameters.csv")
    base = parameter(run, "initial_awakening", "awakening"); insight = parameter(run, "insight_cap", "insight")
    contribution = {tier: parameter(run, "anchor_" + tier + "_contribution", "awakening") for tier in ("planet", "system", "cosmic")}
    upkeep = {tier: parameter(run, "anchor_" + tier + "_upkeep", "faith_per_turn") for tier in contribution}
    # Counts and wounds are the controlled section 12.1 example, not new rules.
    active = {"cosmic": 2, "system": 5, "planet": 2}; wounds = 6
    b = base + insight + sum(active[tier] * contribution[tier] for tier in active)
    cap = parameter(run, "awakening_before_final_cap", "awakening")
    current = max(0, min(cap, b - wounds))
    by_anchor = max(0, min(cap, b + contribution["planet"] - wounds))
    recovery = parameter(run, "rest_wound_recovery", "wounds")
    by_rest = max(0, min(cap, b - wounds + min(wounds, recovery)))
    goal = parameter(run, "manifest_requirement", "awakening")
    require((b, current, by_anchor, by_rest, goal) == (93, 87, 91, 90, 90), "Controlled A87 optional-anchor/REST witness changed")
    layouts = {"cosmic": [2], "system": [3, 2], "planet": [3]}
    slots = parameter(civilization, "institutions_per_domain", "institution")
    for tier, domains in layouts.items():
        require(len(domains) <= parameter(civilization, tier + "_domains", "domain") and all(used <= slots for used in domains), "Controlled anchor layout exceeds formal domain/slot budget")
    guardians = sum(sum(domains) for domains in layouts.values())
    require(guardians <= parameter(fidelity, "bound_member_limit", "person") and 2 <= parameter(fidelity, "focused_domain_limit", "domain"), "Manifestation fixture exceeds N/F")
    require(4 <= parameter(fidelity, "temporary_actor_limit", "person") and 4 <= parameter(fidelity, "candidate_actor_limit", "person_per_candidate"), "Four-person circle exceeds explicit finite actor budget")
    existing_upkeep = sum(active[tier] * upkeep[tier] for tier in active)
    rest_cost = parameter(run, "rest_faith_cost", "faith")
    start_cost = integer(table("data/powers.csv")["POWER_MANIFEST"]["faith"], "manifest start")
    cash = max(existing_upkeep + upkeep["planet"] + start_cost, existing_upkeep + rest_cost + start_cost)
    capacity = parameter(run, "faith_capacity_base", "faith") + current * parameter(run, "faith_capacity_per_peak_awakening", "faith")
    require(cash == 46 and cash <= capacity, "Conditional recovery/start cash reserve changed")
    return {"controlledInputs": {"B": b, "wounds": wounds, "activeAnchors": active, "optionalIntactUnpaidNonRitualPlanet": 1},
            "before": current, "actualUpkeepOnly": by_anchor, "RESTOnlyOptionalExplicitlyRefused": by_rest,
            "guardians": guardians, "slotsByTier": layouts, "conditionalCurrentCash": cash, "capacityAtInitialPeak": capacity,
            "assumptions": ["All material/binding/guardian/cult prerequisites already genuine; all cult plans hold with zero strategy fee and no priority expansion cost.", "Upkeep branch actually pays and passes final eligibility before contribution resumes; saved plan or paid_pending_final_check is insufficient.", "REST branch explicitly refuses optional upkeep; no forecast income and no later world loss; subsequent start rechecks in a later actions window."],
            "scope": "Controlled algebra and necessary capacity only; no reactivation, REST, three-turn ritual, legal save or full route was run."}


def description_columns() -> dict:
    result = {}
    for path, (key, allowed) in DESCRIPTIONS.items():
        old_fields, old = decode(baseline(path), path, key=key)
        fields, rows = decode((ROOT / path).read_bytes(), path, key=key)
        require(fields == old_fields and list(rows) == list(old) and len(rows) == 8, f"{path}: description edit changed schema/ordered IDs")
        require(allowed < set(fields), f"{path}: invalid explicit text-column allowlist")
        changes = []
        for identity, row in rows.items():
            for field in fields:
                if row[field] == old[identity][field]:
                    continue
                require(field in allowed and bool(row[field]), f"{path}/{identity}/{field}: protected column changed")
                changes.append({"id": identity, "field": field})
        result[path] = {"allowedTextColumns": sorted(allowed), "changedCells": changes, "allOtherCellsUnchanged": True}
    return {"baseline": BASE, "tables": result, "proseSemanticAcceptance": "author_and_independent_QA_required",
            "scope": "Schema/reference and explicit column protection only; no natural-language description is parsed as a runtime rule."}


def main() -> int:
    checks, before = [], {}
    try:
        before = hashes()
    except (OSError, ValueError) as error:
        checks.append({"id": "PGR-INPUTS", "status": "fail", "error": str(error)})
    gates = [("PGR-FROZEN-THREE-TABLES", frozen_tables), ("PGR-TEN-GOAL-COVERAGE", goal_routes),
             ("PGR-PARAMETER-REFERENCES", parameter_tables), ("PGR-OPERATIONS-SOURCE", operation_sources),
             ("PGR-DECLARED-OWNERSHIP", registry_ownership), ("PGR-TASK-DAG-ACC", task_dag),
             ("PGR-B-DISPATCH-BOUND", opportunity_bound), ("PGR-MATERIAL-BUDGETS", material_budgets),
             ("PGR-MANIFEST-CAPACITY", manifestation_capacity), ("PGR-DESCRIPTION-COLUMNS", description_columns)]
    for key, operation in gates:
        try:
            checks.append({"id": key, "status": "pass", "details": operation()})
        except (OSError, ValueError, KeyError, TypeError, csv.Error) as error:
            checks.append({"id": key, "status": "fail", "error": str(error)})
    try:
        frozen = bool(before) and before == hashes()
    except (OSError, ValueError):
        frozen = False
    checks.append({"id": "PGR-SOURCE-FROZEN", "status": "pass" if frozen else "fail"})
    passed = all(check["status"] == "pass" for check in checks)
    result = {"schemaVersion": 1, "task": TASK, "title": f"{TASK} — {TITLE}", "status": "pass" if passed else "fail",
              "generatedAt": datetime.now(timezone.utc).isoformat(), "command": ["python", "tools/progression-routes/verify.py"],
              "pythonVersion": sys.version.split()[0], "acceptanceScope": "static_parent_summary_and_conditional_algebra_only",
              "sourceHashes": before, "checks": checks, "realPipelineLatencyL": None, "actualServiceBound": None, "wholeRouteCompletionBound": None,
              "limitations": ["Ten goals and twenty route indices do not prove causal independence, eligibility, knowledge, custody or complete playable routes.", "All runtime declarations remain design_only; actual producer/consumer/writer/UI registration needs real implementation and acceptance.", "B<=28 is conditional committed-dispatch algebra, not an A/fix/offer/actions or natural-service bound.", "direct_action zero applies only to one installed currently qualified step; no current executability, route-wide zero delay, success or survival is guaranteed.", "No game, natural new game, previous checker, old QA, transaction, save/restore, UI or behavior-negative test was executed.", "Description meaning is author/manual-QA work; this tool only enforces the finite column allowlist and all other cells unchanged."]}
    with (HERE / "results.json").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{'PASS' if passed else 'FAIL'} {TASK} — {TITLE}: {sum(check['status'] == 'pass' for check in checks)}/{len(checks)} (static only)")
    for check in checks:
        if check["status"] == "fail":
            print(f"  {check['id']}: {check.get('error', 'source bytes changed during run')}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
