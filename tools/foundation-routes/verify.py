"""Static contract checks for First Cult, Isolated Character, Record, and Ritual Route Design."""
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
TASK = "TASK-FOUNDATION-ROUTES-DESIGN"
TITLE = "First Cult, Isolated Character, Record, and Ritual Route Design"
BASE = "d800583"
SHARED = ("data/progression_routes.csv", "data/progression_route_operations.csv",
          "data/progression_route_sources.csv")
INPUTS = SHARED + (
    "data/foundation_route_parameters.csv", "data/progression_opportunity_goals.csv",
    "data/civilization_profiles.csv", "data/powers.csv", "data/npc_profiles.csv",
    "data/prayers.csv", "data/run_parameters.csv", "data/fidelity_parameters.csv",
    "data/civilization_parameters.csv", "data/intervention_policies.csv",
    "data/prayer_root_rules.csv", "data/cult_spread_conditions.csv", "data/anchor_conditions.csv",
    "docs/specs/system-events.md", "docs/specs/system-civilizations.md",
    "docs/specs/system-progression.md", "docs/specs/system-powers-cults.md",
    "docs/architecture.md", "docs/implementation/traceability.json", "docs/tasks/slice-14.md",
    "tools/foundation-routes/verify.py", "tools/foundation-routes/README.md",
)
ROUTE_HEADER = ["id", "goal_id", "profile", "branch", "entry_ids", "material_rule",
                "delivery_mode", "delivery_bound", "producer_task", "coordination_task", "consumer_task", "runtime_status"]
OP_HEADER = ["id", "mode", "cost_rule", "check_rule", "cooldown_turns", "success_pollution",
             "always_alert", "always_sanity_loss", "participants_max", "repeat_turns", "runtime_status", "rationale"]
SOURCE_HEADER = ["id", "phase", "handler", "product_kind", "due_policy", "producer_task", "runtime_status"]
CONTACT = "TASK-FOUNDATION-CONTACT-OPERATIONS"
RECORD = "TASK-FOUNDATION-RECORD-OPERATIONS"
RITUAL = "TASK-FOUNDATION-RITUAL-OPERATIONS"
NEW_ROUTES = {
    "ROUTE_FIRST_CULT_GATHERING": ("GOAL_FIRST_CULT", "", "covert_gathering", "true_cult_gathering", CONTACT, "ROUTE_PRIVATE_DEVOTION|ROUTE_COVERT_GATHERING"),
    "ROUTE_FIRST_CULT_RITES": ("GOAL_FIRST_CULT", "", "ritual_congregation", "true_cult_rites", RITUAL, "ROUTE_PRIVATE_DEVOTION|ROUTE_CALENDAR_RITE"),
    "ROUTE_CIV01_TESTIMONIES": ("GOAL_ANCHOR_CIV01", "CIV_01", "independent_testimonies", "record_testimonies", "TASK-NETWORK-OPERATIONS", "ROUTE_GUIDED_DREAM|POWER_ANCHOR"),
    "ROUTE_CIV01_PRACTICE": ("GOAL_ANCHOR_CIV01", "CIV_01", "repeated_record_practice", "record_dependency", RECORD, "ROUTE_RECORD_PRACTICE|POWER_ANCHOR"),
    "ROUTE_CIV02_RITES": ("GOAL_ANCHOR_CIV02", "CIV_02", "calendar_rites", "calendar_rites", RITUAL, "ROUTE_CALENDAR_RITE|POWER_ANCHOR"),
    "ROUTE_CIV02_KEEPING": ("GOAL_ANCHOR_CIV02", "CIV_02", "calendar_keeping", "calendar_dependency", RITUAL, "ROUTE_CALENDAR_KEEPING|POWER_ANCHOR"),
    "ROUTE_CIV04_KEEPER": ("GOAL_ANCHOR_CIV04", "CIV_04", "keeper_rite", "ritual_keeper", RITUAL, "ROUTE_CALENDAR_RITE|POWER_ANCHOR"),
    "ROUTE_CIV04_PRACTICE": ("GOAL_ANCHOR_CIV04", "CIV_04", "transmitted_practice", "ritual_practice", RITUAL, "ROUTE_JOINT_WORK|ROUTE_RITUAL_TRANSMISSION|POWER_ANCHOR"),
}
# The finite table grammar is checked here; prose eligibility remains manual QA.
NEW_OPS = {
    "ROUTE_PRIVATE_DEVOTION": ("private_devotion", "foundation_private", "deterministic", "0", "0", "0", "0", "1", ""),
    "ROUTE_JOINT_WORK": ("joint_work", "foundation_joint_work", "social_influence", "0", "0", "0", "0", "2", ""),
    "ROUTE_COVERT_GATHERING": ("covert_gathering", "foundation_gathering", "social_influence", "0", "1", "2", "0", "1", ""),
    "ROUTE_CALENDAR_RITE": ("calendar_rite", "prayer_deep", "occult_adaptation", "0", "2", "4", "2", "1", ""),
    "ROUTE_RECORD_PRACTICE": ("record_practice", "prayer_deep", "occult_adaptation", "1", "2", "2", "2", "1", "2"),
    "ROUTE_CALENDAR_KEEPING": ("calendar_keeping", "prayer_deep", "occult_adaptation", "1", "2", "2", "2", "1", "2"),
    "ROUTE_RITUAL_TRANSMISSION": ("ritual_transmission", "prayer_deep", "occult_adaptation", "0", "2", "4", "2", "2", "2"),
}
PARAMETERS = {
    "private_whispers": "whispers", "private_faith": "faith", "joint_work_whispers": "whispers",
    "joint_work_faith": "faith", "gathering_whispers": "whispers", "gathering_faith": "faith",
    "gathering_followers": "persons", "rite_followers": "persons", "practice_required_turns": "turns",
    "transmission_required_stages": "stages", "foundation_schema": "version",
}
BUILTINS = {"SESSION_REST", "SESSION_SET_ECONOMY_PLAN", "POWER_MANIFEST_CONTINUE"}


class InvalidContract(ValueError):
    pass


def require(value: bool, message: str) -> None:
    if not value:
        raise InvalidContract(message)


def read_rows(raw: bytes, name: str, header: list[str] | None = None) -> dict:
    reader = csv.reader(io.StringIO(raw.decode("utf-8-sig"), newline=""), strict=True)
    fields = next(reader, None)
    require(bool(fields) and "id" in fields and len(set(fields)) == len(fields), f"{name}: invalid header")
    require(header is None or fields == header, f"{name}: unexpected schema")
    result = {}
    for number, values in enumerate(reader, 2):
        require(len(values) == len(fields) and all(v == v.strip() for v in values), f"{name}:{number}: malformed fields")
        row = dict(zip(fields, values))
        require(bool(row["id"]) and row["id"] not in result, f"{name}:{number}: blank/duplicate ID")
        result[row["id"]] = row
    require(bool(result), f"{name}: empty table")
    return result


def table(path: str, header: list[str] | None = None) -> dict:
    return read_rows((ROOT / path).read_bytes(), path, header)


def baseline(path: str) -> bytes:
    result = subprocess.run(["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, check=False)
    require(result.returncode == 0, f"Cannot read frozen git source {BASE}:{path}")
    return result.stdout


def number(value: str, name: str) -> int:
    require(bool(re.fullmatch(r"0|[1-9][0-9]*", value)), f"{name}: noncanonical nonnegative integer")
    return int(value)


def parameter(rows: dict, name: str, unit: str) -> int:
    require(name in rows and rows[name]["unit"] == unit and bool(rows[name]["rationale"]), f"{name}: invalid parameter/unit/rationale")
    return number(rows[name]["value"], name)


def source_hashes() -> dict:
    result = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS}
    for path in SHARED:
        result[f"git:{BASE}:{path}"] = hashlib.sha256(baseline(path)).hexdigest()
    return result


def preservation() -> dict:
    result = {}
    for path, count, header in zip(SHARED, (6, 5, 1), (ROUTE_HEADER, OP_HEADER, SOURCE_HEADER)):
        old = baseline(path)
        require(len(read_rows(old, path, header)) == count, f"{path}: unexpected baseline row count")
        current = (ROOT / path).read_bytes()
        require(current.startswith(old), f"{path}: old bytes are not an exact preserved prefix")
        if path == SHARED[2]:
            require(current == old, "The original natural source table must be byte-identical")
        result[path] = {"preservedRows": count, "preservedBytes": len(old), "sha256": hashlib.sha256(old).hexdigest()}
    return {"baseline": BASE, "tables": result, "scope": "Only the three shared tables; the root performs the separate 243-file preservation audit."}


def routes() -> dict:
    rows = table(SHARED[0], ROUTE_HEADER)
    previous = read_rows(baseline(SHARED[0]), SHARED[0], ROUTE_HEADER)
    require(set(rows) == set(previous) | set(NEW_ROUTES) and len(rows) == 14, "Exactly fourteen route IDs are required")
    goals = table("data/progression_opportunity_goals.csv")
    require(len(goals) == 10 and all(goal["runtime_status"] == "design_only" for goal in goals.values()), "All ten goals must remain design_only")
    profiles = table("data/civilization_profiles.csv")
    operations = table(SHARED[1], OP_HEADER)
    powers = table("data/powers.csv")
    counts = Counter()
    for key, row in rows.items():
        require(row["runtime_status"] == "design_only" and row["delivery_mode"] == "direct_action" and row["delivery_bound"] == "0", f"{key}: unexpected status/delivery enum")
        require(row["goal_id"] in goals and goals[row["goal_id"]]["runtime_status"] == "design_only", f"{key}: unresolved goal")
        require(row["profile"] == goals[row["goal_id"]]["profile_id"] and (not row["profile"] or row["profile"] in profiles), f"{key}: goal/profile mismatch")
        entries = row["entry_ids"].split("|")
        require(all(entries) and len(set(entries)) == len(entries), f"{key}: empty/duplicate entry")
        require(all(entry in operations or entry in powers or entry in BUILTINS for entry in entries), f"{key}: unresolved entry")
        if key in NEW_ROUTES:
            expected = NEW_ROUTES[key]
            require(tuple(row[field] for field in ("goal_id", "profile", "branch", "material_rule", "producer_task", "entry_ids")) == expected, f"{key}: invalid finite foundation route binding")
            require(row["coordination_task"] == "TASK-OPPORTUNITY-SCHEDULER", f"{key}: wrong coordinator")
            require(row["consumer_task"] == ("TASK-CULT-SPREAD" if row["goal_id"] == "GOAL_FIRST_CULT" else "TASK-ANCHOR-ROUTES"), f"{key}: wrong consumer")
            counts[row["goal_id"]] += 1
    require(dict(counts) == {"GOAL_FIRST_CULT": 2, "GOAL_ANCHOR_CIV01": 2, "GOAL_ANCHOR_CIV02": 2, "GOAL_ANCHOR_CIV04": 2}, "Each foundation goal needs exactly two indexed branches")
    return {"total": len(rows), "newPerGoal": dict(counts), "routes": [rows[key] for key in NEW_ROUTES],
            "causalDistinctness": "independent_manual_QA_required", "realPipelineLatencyL": None, "wholeRouteBound": None}


def operations() -> dict:
    rows = table(SHARED[1], OP_HEADER)
    old = read_rows(baseline(SHARED[1]), SHARED[1], OP_HEADER)
    require(set(rows) == set(old) | set(NEW_OPS) and len(rows) == 12, "Exactly twelve operation IDs are required")
    params = table("data/foundation_route_parameters.csv", ["id", "value", "unit", "rationale"])
    run = table("data/run_parameters.csv")
    costs = {}
    fields = OP_HEADER[1:10]
    for key, expected in NEW_OPS.items():
        row = rows[key]
        require(tuple(row[field] for field in fields) == expected and row["runtime_status"] == "design_only" and bool(row["rationale"]), f"{key}: unexpected grammar/shape/numerical contract")
        if row["cost_rule"] == "prayer_deep":
            faith = parameter(run, "prayer_deep_faith", "faith")
            whispers = parameter(run, "prayer_deep_whispers", "whispers")
        else:
            prefix = {"foundation_private": "private", "foundation_joint_work": "joint_work", "foundation_gathering": "gathering"}[row["cost_rule"]]
            faith = parameter(params, prefix + "_faith", "faith")
            whispers = parameter(params, prefix + "_whispers", "whispers")
        costs[key] = {"faith": faith, "whispers": whispers, "participantsMax": number(row["participants_max"], key)}
    return {"total": len(rows), "newOperations": list(NEW_OPS), "formalCosts": costs,
            "scope": "Finite table grammar and parameter references; no handler, qualification, roll or payment was executed."}


def parameters() -> dict:
    rows = table("data/foundation_route_parameters.csv", ["id", "value", "unit", "rationale"])
    require(set(rows) == set(PARAMETERS), "Unexpected/missing foundation parameter")
    values = {key: parameter(rows, key, unit) for key, unit in PARAMETERS.items()}
    require(values["foundation_schema"] == 1, "Unknown foundation parameter schema")
    for key in ("ROUTE_RECORD_PRACTICE", "ROUTE_CALENDAR_KEEPING"):
        require(number(table(SHARED[1])[key]["repeat_turns"], key) == values["practice_required_turns"], "Operation and practice parameter disagree")
    require(number(table(SHARED[1])["ROUTE_RITUAL_TRANSMISSION"]["repeat_turns"], "transmission") == values["transmission_required_stages"], "Transmission stages disagree")
    return values


def source_table() -> dict:
    rows = table(SHARED[2], SOURCE_HEADER)
    require(len(rows) == 1 and set(rows) == {"ROOT_COSMIC_RECHECK"}, "No foundation natural root may be fabricated by this batch")
    require(rows["ROOT_COSMIC_RECHECK"]["runtime_status"] == "design_only", "Source became active without implementation")
    return {"count": 1, "newNaturalSources": 0, "naturalReachabilityVerified": False}


def tasks() -> dict:
    tracking = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8-sig"))
    task_rows, scenarios = tracking["tasks"], tracking["scenarios"]
    require(isinstance(task_rows, list) and isinstance(scenarios, list), "Malformed structured tasks/scenarios")
    required = {TASK: "design", CONTACT: "code", RECORD: "code", RITUAL: "code",
                "TASK-FOUNDATION-INTERFACE-DESIGN": "design", "TASK-FOUNDATION-OPERATION-UI": "code",
                "TASK-PROGRESSION-OPERATION-CORE": "code", "TASK-PROGRESSION-OPERATIONS": "code"}
    for row in table(SHARED[0]).values():
        for field in ("producer_task", "coordination_task", "consumer_task"):
            required[row[field]] = "code"
    required["TASK-SOURCE-EXCEPTION"] = "code"
    found = {}
    for key, owner in sorted(required.items()):
        matches = [row for row in task_rows if row.get("id") == key]
        require(len(matches) == 1, f"{key}: missing/duplicate actual task")
        row = matches[0]
        require(row.get("owner") == owner and all(row.get(field) for field in ("title", "scope", "deliverables", "acceptance")), f"{key}: incomplete ownership/brief/ACC")
        for acceptance in row["acceptance"]:
            cases = [case for case in scenarios if case.get("id") == acceptance]
            require(len(cases) == 1 and all(cases[0].get(field) for field in ("given", "when", "then")), f"{key}: unresolved real ACC {acceptance}")
        found[key] = {"title": row["title"], "owner": owner, "status": row["status"], "acceptance": row["acceptance"], "dependsOn": row.get("dependsOn", [])}
    children = {CONTACT, RECORD, RITUAL, "TASK-FOUNDATION-OPERATION-UI"}
    require(children <= set(found["TASK-PROGRESSION-OPERATIONS"]["dependsOn"]), "Implementation parent omits a foundation child")
    require("TASK-FOUNDATION-INTERFACE-DESIGN" in found["TASK-FOUNDATION-OPERATION-UI"]["dependsOn"], "UI implementation needs its real design dependency")
    parent = [row for row in task_rows if row.get("id") == "TASK-PROGRESSION-ROUTES"]
    require(len(parent) == 1 and parent[0]["status"] in {"planned", "in-progress", "blocked"}, "Full twenty-route parent must remain incomplete")
    return {"tasks": found, "parentComplete": False, "scope": "Structured ownership and acceptance references, not implementation acceptance."}


def budgets() -> dict:
    params = parameters()
    run, fidelity = table("data/run_parameters.csv"), table("data/fidelity_parameters.csv")
    threshold = parameter(run, "cult_form_followers", "followers")
    spend = parameter(run, "cult_form_local_spend", "faith_spent")
    faith = parameter(run, "initial_faith", "faith")
    whispers = parameter(run, "whisper_base", "whispers_per_turn")
    branches = {}
    for label, people, fee, whisper in (("gathering", params["gathering_followers"], params["gathering_faith"], params["gathering_whispers"]),
                                       ("rites", params["rite_followers"], parameter(run, "prayer_deep_faith", "faith"), parameter(run, "prayer_deep_whispers", "whispers"))):
        require(2 * people == threshold and 2 * fee == spend and 2 * fee <= faith and whisper <= whispers, f"{label}: conditional two-success budget does not meet original thresholds")
        branches[label] = {"assumedSuccessfulActivities": 2, "actualConvertedIfPoolSufficient": 2 * people, "actualLocalFaithSpent": 2 * fee, "remainingInitialFaith": faith - 2 * fee, "whispersPerActivity": whisper}
    ops = table(SHARED[1])
    largest = max(number(row["participants_max"], key) for key, row in ops.items() if key in NEW_OPS)
    require(largest <= parameter(fidelity, "temporary_actor_limit", "person") and largest <= parameter(fidelity, "candidate_actor_limit", "person_per_candidate"), "Finite participant budget exceeded")
    require(parameter(fidelity, "focused_domain_limit", "domain") >= 1 and parameter(fidelity, "bound_member_limit", "person") >= 1, "One-domain member budget unavailable")
    require(params["private_faith"] == 0 and params["private_whispers"] <= whispers, "Private contact is not zero-faith and affordable in next base-whisper window")
    return {"branches": branches, "largestExplicitParticipants": largest, "unnamedParticipantsUseNamedSlots": False,
            "assumptions": ["An actual eligible, informed, willing actor exists; the rite branch additionally requires a real ritual keeper and ritual institution.", "At least six real unnamed nonfollowers remain; both selected activities actually succeed and pay.", "Current F/N/P admission and one actual actor opportunity per turn pass; no competing cost or adverse world change."],
            "scope": "Necessary conditional arithmetic only, not a runtime fixture, success frequency, new-game guarantee or full anchor funding proof."}


def isolated_example() -> dict:
    npc = table("data/npc_profiles.csv")["NPC_PROFILE_01"]
    dream = table("data/powers.csv")["POWER_DREAM"]
    run = table("data/run_parameters.csv")
    start = number(npc["loyalty"], "bootstrap loyalty")
    minimum = parameter(run, "cult_form_loyalty", "loyalty")
    # Only the two authored DREAM result cells use this finite static grammar.
    # This is not the runtime effect parser and grants no implemented capability.
    loyalty = {}
    for field in ("success", "deep_success"):
        matched = re.fullmatch(r"忠诚加(0|[1-9][0-9]*)且理智减(0|[1-9][0-9]*)且本域污染加(0|[1-9][0-9]*)察觉加(0|[1-9][0-9]*)", dream[field])
        require(matched is not None, f"POWER_DREAM.{field}: unsupported finite result grammar")
        loyalty[field] = int(matched.group(1))
    ordinary, deep = loyalty["success"], loyalty["deep_success"]
    require(start == 15 and start + 2 * ordinary < minimum and start + ordinary + deep == minimum, "Bootstrap DREAM example incorrectly assumes initial25 or two ordinary successes")
    cooldown = number(dream["cooldown_turns"], "DREAM cooldown")
    require(cooldown == 1 and 1 + cooldown + 1 == 3, "T1 to T3 original cooldown arithmetic changed")
    require("record_keeper" in npc["role_tags"].split(";") and "ritual_keeper" not in npc["role_tags"].split(";"), "Bootstrap profile cannot be silently treated as a ritual keeper")
    return {"initialLoyalty": start, "authoredDreamLoyaltyIncrements": {"ordinary": ordinary, "deep": deep}, "twoOrdinary": start + 2 * ordinary,
            "ordinaryPlusDeep": start + ordinary + deep, "membershipMinimum": minimum, "earliestDreamTurnsIfOriginalContactStillValid": [1, 3],
            "earliestLaterPrivateDevotion": 4, "scope": "Conditional arithmetic only. Original fixed-card presence/due, real identity knowledge, opportunity and F/N/P remain required; no card lifetime is extended and no call is rerolled."}


def obligations() -> dict:
    example = isolated_example()
    params = parameters()
    followers_required = parameter(table("data/run_parameters.csv"), "cult_form_followers", "followers")
    require(example["twoOrdinary"] < example["membershipMinimum"], "Insufficient-loyalty negative obligation lost")
    require(min(params["gathering_followers"], 0) == 0 and 2 * min(params["gathering_followers"], 2) < followers_required, "Limited population algebra failed")
    return {"kind": "static_negative_obligations_not_runtime_tests", "obligations": [
        "No real identity knowledge, willingness, N admission or active local actor: private devotion must not enroll or count as executable ending contact.",
        "Zero unnamed population: gathering rejects; rite can produce a genuine nonrecruiting rite but zero people.",
        "Initial loyalty15 plus two ordinary DREAM successes is35, not40; old contact/due/cooldown remains binding.",
        "One actual actor cannot privately devote and gather in the same actions window even if summed whispers fit.",
        "Same use/turn copy, same-turn teach/perform, mere lesson, nominal keeper or received copy cannot create completed independent material.",
        "Private prepare must be identical for Session and Endings, rechecking next-window real budgets without future income or random rescue.",
        "Previews and route labels create no members, cooperation, carriers, spending, completed goals or service facts; missing delivery contracts stay unserved."],
        "eligibilityAndCausalDistinctness": "independent_manual_spec_QA_required", "transactionSaveOrHandlerFaultInjectionPerformed": False}


def main() -> int:
    checks, before = [], {}
    try:
        before = source_hashes()
    except (OSError, ValueError) as error:
        checks.append({"id": "FND-INPUTS", "status": "fail", "error": str(error)})
    for key, operation in (("FND-PRESERVED-PREFIX", preservation), ("FND-ROUTES", routes), ("FND-OPERATIONS", operations),
                           ("FND-PARAMETERS", parameters), ("FND-SOURCE", source_table), ("FND-TASK-OWNERS-ACC", tasks),
                           ("FND-CONDITIONAL-BUDGET", budgets), ("FND-ISOLATED-EXAMPLE", isolated_example), ("FND-NEGATIVE-OBLIGATIONS", obligations)):
        try:
            checks.append({"id": key, "status": "pass", "details": operation()})
        except (OSError, ValueError, KeyError, TypeError, csv.Error) as error:
            checks.append({"id": key, "status": "fail", "error": str(error)})
    try:
        frozen = bool(before) and before == source_hashes()
    except (OSError, ValueError):
        frozen = False
    checks.append({"id": "FND-SOURCE-FROZEN", "status": "pass" if frozen else "fail"})
    passed = all(check["status"] == "pass" for check in checks)
    result = {"schemaVersion": 1, "task": TASK, "title": f"{TASK} — {TITLE}", "status": "pass" if passed else "fail",
              "generatedAt": datetime.now(timezone.utc).isoformat(), "command": ["python", "tools/foundation-routes/verify.py"],
              "pythonVersion": sys.version.split()[0], "acceptanceScope": "static_contract_and_conditional_algebra_only", "sourceHashes": before,
              "realPipelineLatencyL": None, "wholeRouteCompletionBound": None, "checks": checks,
              "limitations": ["All declarations remain design_only; the full parent is incomplete.", "No game, natural new game, actual production, transaction, save/restore or UI was run.", "Causal alternatives, knowledge, material custody and admission semantics require independent manual QA and later real implementation tests.", "direct_action zero applies only to one currently qualified installed step, not current executability or a zero-turn complete route.", "Conditional outcome arithmetic does not guarantee a success, survival, early contact or victory."]}
    with (HERE / "results.json").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{'PASS' if passed else 'FAIL'} {TASK} — {TITLE}: {sum(check['status'] == 'pass' for check in checks)}/{len(checks)} (static only)")
    for check in checks:
        if check["status"] == "fail":
            print(f"  {check['id']}: {check.get('error', 'source bytes changed during run')}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
