#!/usr/bin/env python3
"""Static integrity checks for the authored planning documents and CSV catalogs.

No external dependencies. This checks data/link consistency and narrow arithmetic
properties; it does not simulate a playable strategy or prove economic balance.
"""

from __future__ import annotations

import csv
from datetime import datetime
from decimal import Decimal, InvalidOperation
import hashlib
import itertools
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/qa/planning-check-results.json"
CHECKS: list[dict] = []
TABLES: dict[str, list[dict[str, str]]] = {}
SOURCES: set[Path] = set()


def record(name: str, errors: list[str], **details: object) -> None:
    CHECKS.append({"name": name, "status": "FAIL" if errors else "PASS", "errors": errors, "detail": details})
    print(f"{'FAIL' if errors else 'PASS'} {name}")
    for error in errors:
        print(f"  {error}")


def number(value: str, location: str, errors: list[str], *, lower: Decimal | int | None = None,
           upper: Decimal | int | None = None, integer: bool = False) -> Decimal | None:
    try:
        parsed = Decimal(value)
    except (InvalidOperation, ValueError, TypeError):
        errors.append(f"{location}: expected a finite number, got {value!r}")
        return None
    if not parsed.is_finite():
        errors.append(f"{location}: non-finite number")
        return None
    if integer and parsed != parsed.to_integral_value():
        errors.append(f"{location}: expected integer, got {value}")
    if lower is not None and parsed < lower:
        errors.append(f"{location}: {value} < {lower}")
    if upper is not None and parsed > upper:
        errors.append(f"{location}: {value} > {upper}")
    return parsed


def load_tables() -> None:
    errors: list[str] = []
    counts: dict[str, int] = {}
    for path in sorted((ROOT / "data").glob("*.csv")):
        SOURCES.add(path)
        location = str(path.relative_to(ROOT))
        try:
            with path.open(newline="", encoding="utf-8-sig") as file:
                matrix = list(csv.reader(file, strict=True))
        except (OSError, UnicodeError, csv.Error) as exc:
            errors.append(f"{location}: {exc}")
            continue
        if not matrix or not matrix[0]:
            errors.append(f"{location}: empty file/header")
            continue
        header = matrix[0]
        if any(not field for field in header) or len(set(header)) != len(header):
            errors.append(f"{location}: empty or duplicate column name")
        rows: list[dict[str, str]] = []
        seen: set[tuple[str, ...]] = set()
        identity = ["event_id", "option"] if path.stem == "event_effects" else ["id" if "id" in header else header[0]]
        for index, cells in enumerate(matrix[1:], 2):
            if not cells:
                continue
            if len(cells) != len(header):
                errors.append(f"{location}:{index}: {len(cells)} cells for {len(header)} columns")
                continue
            row = dict(zip(header, cells))
            key = tuple(row.get(field, "") for field in identity)
            if any(not field for field in key):
                errors.append(f"{location}:{index}: empty identity {identity}")
            if key in seen:
                errors.append(f"{location}:{index}: duplicate identity {key}")
            seen.add(key)
            rows.append(row)
        TABLES[path.stem] = rows
        counts[path.name] = len(rows)
    record("CSV structure and per-table identities", errors, files=len(counts), row_counts=counts,
           composite_identity="event_effects uses (event_id, option); IDs are not globally unique across unrelated tables")


def required(name: str, fields: set[str]) -> list[dict[str, str]]:
    errors: list[str] = []
    rows = TABLES.get(name, [])
    if not rows:
        errors.append(f"data/{name}.csv: missing or empty required catalog")
    for index, row in enumerate(rows, 2):
        missing = fields - row.keys()
        if missing:
            errors.append(f"data/{name}.csv:{index}: missing columns {sorted(missing)}")
    if errors:
        record(f"Required schema {name}", errors)
        return []
    return rows


def parameters(name: str) -> dict[str, Decimal]:
    errors: list[str] = []
    output: dict[str, Decimal] = {}
    for row in required(name, {"id", "value"}):
        value = number(row["value"], f"data/{name}.csv:{row['id']}", errors)
        if value is not None:
            output[row["id"]] = value
    record(f"Numeric parameter catalog {name}", errors, parameters=len(output))
    return output


def check_civilizations() -> None:
    profiles = required("civilization_profiles", {"id", "tier", "tech", "occult", "faith", "meme", "barrier", "stability", "authority"})
    conditions = required("civilization_conditions", {"profile_id", "allowed_authority", "relic_pool"})
    relic_ids = {row["id"] for row in TABLES.get("relics", [])}
    condition_by_id = {row["profile_id"]: row for row in conditions}
    profile_ids = {row["id"] for row in profiles}
    errors: list[str] = []
    if profile_ids != set(condition_by_id):
        errors.append(f"profiles/conditions ID sets differ: {sorted(profile_ids ^ set(condition_by_id))}")
    for row in profiles:
        identity = row["id"]
        weights = [number(row[field], f"{identity}.{field}", errors, lower=0, upper=100, integer=True) for field in ("tech", "occult", "faith", "meme")]
        if all(weight is not None for weight in weights) and sum(weights) != 100:
            errors.append(f"{identity}: paradigm weights total {sum(weights)}, expected 100")
        for field in ("barrier", "stability"):
            number(row[field], f"{identity}.{field}", errors, lower=0, upper=100, integer=True)
        if row["tier"] not in {"planet", "system", "cosmic"}:
            errors.append(f"{identity}: unknown tier {row['tier']}")
        condition = condition_by_id.get(identity)
        if condition:
            allowed = condition["allowed_authority"].split("|")
            if row["authority"] not in allowed:
                errors.append(f"{identity}: default authority absent from allowed_authority")
            if not set(allowed) <= {"council", "hierarchy", "decentralized", "unified"}:
                errors.append(f"{identity}: unknown allowed authority")
            for relic_id in condition["relic_pool"].split("|"):
                if relic_id not in relic_ids:
                    errors.append(f"{identity}: missing relic_pool reference {relic_id}")
    record("Civilization weights, paired conditions and relic pools", errors, profiles=len(profiles), conditions=len(conditions))


def check_narrative() -> None:
    events = required("events", {"id", "min_age", "max_age", "cooldown", "priority", "default_result"})
    effects = required("event_effects", {"event_id", "option", "faith_cost"})
    prayers = required("prayers", {"id", "lifetime", "callback_event"})
    event_ids = {row["id"] for row in events}
    effects_by_key = {(row["event_id"], row["option"]): row for row in effects}
    errors: list[str] = []
    for row in effects:
        if row["event_id"] not in event_ids:
            errors.append(f"event_effects: orphan event {row['event_id']}")
        if row["option"] not in {"A", "B"}:
            errors.append(f"event_effects:{row['event_id']}: unknown option {row['option']}")
        number(row["faith_cost"], f"event_effects:{row['event_id']}:{row['option']}.faith_cost", errors, lower=0, integer=True)
    for row in events:
        identity = row["id"]
        lower = number(row["min_age"], f"{identity}.min_age", errors, lower=0, integer=True)
        upper = number(row["max_age"], f"{identity}.max_age", errors, lower=0, integer=True)
        if lower is not None and upper is not None and lower > upper:
            errors.append(f"{identity}: min_age exceeds max_age")
        for field in ("cooldown", "priority"):
            number(row[field], f"{identity}.{field}", errors, lower=0, integer=True)
        for option in ("A", "B"):
            if (identity, option) not in effects_by_key:
                errors.append(f"{identity}: missing option {option}")
        match = re.fullmatch(r"option:([AB])", row["default_result"])
        if not match:
            errors.append(f"{identity}: unsupported default_result {row['default_result']!r}")
        else:
            default = effects_by_key.get((identity, match.group(1)))
            default_cost = number(default["faith_cost"], f"{identity}.default.faith_cost", errors) if default else None
            if default is None or default_cost != 0:
                errors.append(f"{identity}: default option must exist and cost zero faith")
    for row in prayers:
        number(row["lifetime"], f"{row['id']}.lifetime", errors, lower=1, integer=True)
        if row["callback_event"] not in event_ids:
            errors.append(f"{row['id']}: missing callback {row['callback_event']}")
    record("Prayer callbacks and complete event branches", errors, prayers=len(prayers), events=len(events), branches=len(effects),
           scope="Checks stated monetary default cost; actor invalidation and narrative feasibility remain governed by spec, not inferred from prose")


def check_powers_relics(run: dict[str, Decimal]) -> None:
    powers = required("powers", {"id", "unlock_awakening", "whispers", "faith", "cooldown_turns", "check_kind", "attribute"})
    relics = required("relics", {"id", "faith_disassembly", "insight_disassembly", "follower_gift", "whisper_release"})
    errors: list[str] = []
    tiers: set[int] = set()
    for row in powers:
        for field in ("unlock_awakening", "whispers", "faith", "cooldown_turns"):
            value = number(row[field], f"{row['id']}.{field}", errors, lower=0, integer=True,
                           upper=run.get("awakening_before_final_cap", 99) if field == "unlock_awakening" else None)
            if value is not None and field == "unlock_awakening":
                tiers.add(int(value))
        if row["check_kind"] not in {"deterministic", "occult", "social"}:
            errors.append(f"{row['id']}: unknown check_kind")
        if row["attribute"] not in {"none", "insight", "will", "influence", "adaptation"}:
            errors.append(f"{row['id']}: unknown attribute")
        if row["check_kind"] == "deterministic" and row["attribute"] != "none":
            errors.append(f"{row['id']}: deterministic power declares a dice attribute")
    for row in relics:
        for field in ("faith_disassembly", "insight_disassembly", "follower_gift", "whisper_release"):
            number(row[field], f"{row['id']}.{field}", errors, lower=0, integer=True)
    by_id = {row["id"]: row for row in powers}
    if "POWER_ANCHOR" in by_id and "initial_awakening" in run:
        unlock = number(by_id["POWER_ANCHOR"]["unlock_awakening"], "POWER_ANCHOR.unlock", errors)
        if unlock is not None and unlock > run["initial_awakening"]:
            errors.append("POWER_ANCHOR: unlock exceeds initial awakening, risking circular progress dependency")
    if "POWER_MANIFEST" in by_id and "manifest_requirement" in run:
        unlock = number(by_id["POWER_MANIFEST"]["unlock_awakening"], "POWER_MANIFEST.unlock", errors)
        if unlock is not None and unlock != run["manifest_requirement"]:
            errors.append("POWER_MANIFEST: unlock differs from manifest_requirement")
    record("Power/relic numeric fields and unlock thresholds", errors, powers=len(powers), relics=len(relics), unlock_ladder=sorted(tiers),
           scope="Threshold consistency only; prerequisite acquisition and actual play routes are not proven")


def check_prayer_facts_and_resistance() -> None:
    facts = required("prayer_facts", {"prayer_id", "success_fact", "failure_fact", "expiry_fact", "cost_semantics"})
    errors: list[str] = []
    prayer_ids = {row["id"] for row in TABLES.get("prayers", [])}
    fact_ids = {row["prayer_id"] for row in facts}
    if prayer_ids != fact_ids:
        errors.append(f"prayers/prayer_facts ID sets differ: {sorted(prayer_ids ^ fact_ids)}")
    for row in facts:
        for field in ("success_fact", "failure_fact", "expiry_fact", "cost_semantics"):
            if not row[field].strip():
                errors.append(f"prayer_facts:{row['prayer_id']}: empty {field}")
    record("Prayer outcome fact coverage", errors, prayers=len(prayer_ids), fact_records=len(facts),
           scope="One-to-one identity and nonempty outcome/cost semantics; prose is not executed or semantically proven")
    plans = required("resistance_plans", {"id", "min_alert", "tier", "required_target", "priority", "warning_turns", "cooldown_turns"})
    errors = []
    for row in plans:
        for field in ("min_alert", "priority", "warning_turns", "cooldown_turns"):
            number(row[field], f"{row['id']}.{field}", errors, lower=0, upper=100 if field == "min_alert" else None, integer=True)
        tiers = row["tier"].split("|")
        if not set(tiers) <= {"planet", "system", "cosmic"} or len(tiers) != len(set(tiers)):
            errors.append(f"{row['id']}: unknown or duplicate tier membership")
        if not row["required_target"].strip():
            errors.append(f"{row['id']}: required_target is empty")
    record("Resistance plans numeric bounds and target declarations", errors, plans=len(plans),
           scope="Static catalog only; target qualification, warnings and resistance behavior are not run in Godot")


def check_npcs() -> None:
    errors: list[str] = []
    checked: dict[str, int] = {}
    # Character profiles have attributes; behavior definitions refer to one
    # attribute and must not be mistaken for another character catalog.
    for name in ("npc_profiles",):
        rows = required(name, {"id", "will", "insight", "influence", "adaptation", "sanity", "loyalty", "institution_roles", "requires_ritual", "requires_route", "requires_crisis", "requires_listener"})
        fields = ("insight", "will", "influence", "adaptation")
        for row in rows:
            for field in fields:
                if field not in row:
                    errors.append(f"{name}:{row.get('id')}: missing attribute {field}")
                else:
                    number(row[field], f"{name}:{row.get('id')}.{field}", errors, lower=0, upper=5, integer=True)
            for field in ("sanity", "loyalty"):
                if field in row:
                    number(row[field], f"{name}:{row.get('id')}.{field}", errors, lower=0, upper=100, integer=True)
            for field in ("requires_ritual", "requires_route", "requires_crisis", "requires_listener"):
                if row.get(field) not in {"0", "1"}:
                    errors.append(f"{name}:{row.get('id')}: invalid qualification flag {field}")
            if not set(row.get("institution_roles", "").split("|")).issubset({"interpretation", "propagation", "order", "none"}):
                errors.append(f"{name}:{row.get('id')}: invalid institution roles")
        checked[name] = len(rows)
    record("Formal NPC four-attribute bounds", errors, catalogs=checked,
           scope="No formal NPC CSV present; no NPC content coverage claimed" if not checked else "Formal four attributes checked in 0..5; feasibility fixtures are a separate technical model")


def check_simulation_catalogs() -> None:
    errors: list[str] = []
    rows = required("npc_behaviors", {"id", "attribute", "base_score", "attribute_weight", "need_bonus", "cooldown_turns", "eligibility", "effect", "effect_base", "effect_divisor", "sanity_cost", "target_loyalty_delta", "source_kind", "repeat_policy"})
    attributes = {"will", "insight", "influence", "adaptation"}
    if {row["attribute"] for row in rows} != attributes:
        errors.append("formal behaviors must cover all four named attributes")
    allowed = {
        "strained_self": ("restore_self_sanity", "will", "strain", "repeat_until_threshold"),
        "known_local_exposure": ("gather_evidence", "insight", "exposure", "once_per_actor_source"),
        "related_harmed_follower": ("restore_target_sanity", "influence", "harm", "once_per_actor_source_target"),
        "personally_witnessed_miracle": ("increase_self_loyalty", "adaptation", "miracle", "once_per_actor_source"),
    }
    for row in rows:
        identity = row["id"]
        if allowed.get(row["eligibility"]) != (row["effect"], row["attribute"], row["source_kind"], row["repeat_policy"]):
            errors.append(f"{identity}: unsupported formal behavior/effect/source combination")
        for field in ("base_score", "attribute_weight", "need_bonus", "cooldown_turns", "effect_base", "sanity_cost", "target_loyalty_delta"):
            number(row[field], f"{identity}.{field}", errors, lower=0, integer=True)
        number(row["effect_divisor"], f"{identity}.effect_divisor", errors, lower=1, integer=True)
    actions = required("civilization_actions", {"id", "institution_role", "evidence_requirement", "target_kind", "effect", "followers_loss_ratio", "cohesion_delta", "barrier_delta", "pollution_delta", "wounds_delta"})
    if {row["id"] for row in actions} != {row["id"] for row in TABLES.get("resistance_plans", [])}:
        errors.append("civilization action effects must map one-to-one to resistance plans")
    effect_grammar = {
        "confirm_evidence": ("order", "exposed", "npc|relic"),
        "purge_cult": ("order", "confirmed_npc", "cult"),
        "seize_relic": ("order", "confirmed_relic", "relic"),
        "repair_barrier": ("order", "breach", "civilization"),
        "destroy_anchor": ("order", "confirmed_anchor", "anchor"),
        "rewrite_reality": ("interpretation", "confirmed_exception", "record"),
    }
    for row in actions:
        if effect_grammar.get(row["effect"]) != (row["institution_role"], row["evidence_requirement"], row["target_kind"]):
            errors.append(f"{row['id']}: unsupported institution/evidence/target/effect combination")
        number(row["followers_loss_ratio"], f"{row['id']}.followers_loss_ratio", errors, lower=0, upper=1)
        for field in ("cohesion_delta", "barrier_delta", "pollution_delta", "wounds_delta"):
            number(row[field], f"{row['id']}.{field}", errors, integer=True)
    record("Formal autonomous behaviors and civilization effects", errors, behaviors=len(rows), actions=len(actions),
           scope="Static executable catalog shape and references; runtime and balance require separate Godot evidence")


def check_inline_ids() -> None:
    known: set[str] = set()
    for rows in TABLES.values():
        known.update(row["id"] for row in rows if "id" in row)
    errors: list[str] = []
    references = 0
    token = re.compile(r"\b(?:EVENT|PRAYER|RELIC|POWER|CIV)_[A-Z0-9_]+\b")
    for name, rows in TABLES.items():
        if name.startswith("feasibility_"):
            continue
        for index, row in enumerate(rows, 2):
            for field, value in row.items():
                for identity in token.findall(value):
                    references += 1
                    if identity not in known:
                        errors.append(f"data/{name}.csv:{index}:{field}: unknown ID {identity}")
    record("Explicit catalog IDs inside authored text", errors, references=references)


def document_paths() -> list[Path]:
    paths = [ROOT / "docs" / name for name in ("vision.md", "world.md", "gdd-core.md", "architecture.md")]
    for directory in ("specs", "content", "progress", "qa", "ori", "implementation", "tasks"):
        paths.extend((ROOT / "docs" / directory).glob("*.md"))
    return sorted(path for path in set(paths) if path.exists() and not path.name.startswith("_template") and path.name != "backlog-issues.md")


def check_documents() -> None:
    docs = document_paths()
    errors: list[str] = []
    dependencies = 0
    for path in docs:
        SOURCES.add(path)
        if path.parent.name != "specs":
            continue
        text = path.read_text(encoding="utf-8")
        match = re.match(r"\A---\s*\n(.*?)\n---", text, re.S)
        if not match:
            errors.append(f"{path.relative_to(ROOT)}: missing frontmatter")
            continue
        front = match.group(1)
        for field in ("status", "interfaces-with", "exposes", "last-modified-date"):
            if not re.search(rf"^{field}:", front, re.M):
                errors.append(f"{path.relative_to(ROOT)}: missing frontmatter {field}")
        inline = re.search(r"^interfaces-with:\s*\[([^\]]*)\]", front, re.M)
        if not inline:
            errors.append(f"{path.relative_to(ROOT)}: unsupported interfaces-with format; expected inline list")
            continue
        for dependency in inline.group(1).split(","):
            dependency = dependency.strip().strip("'\"")
            if not dependency:
                continue
            target = path.parent / (dependency if dependency.endswith(".md") else dependency + ".md")
            dependencies += 1
            if not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: missing dependency {dependency}")
    record("System/UI spec dependencies and metadata", errors, documents=len(docs), declared_dependencies=dependencies)
    errors = []
    checked = 0
    # Links can use Chinese labels, spaces inside <...>, URL escapes and optional headings.
    link_pattern = re.compile(r"!?\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))(?:\s+\"[^\"]*\")?\s*\)")
    for path in docs:
        text = re.sub(r"```.*?```", "", path.read_text(encoding="utf-8"), flags=re.S)
        for match in link_pattern.finditer(text):
            raw = match.group(1) or match.group(2)
            if raw.startswith("#") or urlsplit(raw).scheme:
                continue
            target_text = unquote(raw.split("#", 1)[0].split("?", 1)[0])
            if not target_text:
                continue
            target_text = re.sub(r":\d+$", "", target_text)
            target = Path(target_text) if target_text.startswith("/") else path.parent / target_text
            checked += 1
            if not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: broken local link {raw}")
    record("Authored Markdown local-link targets", errors, links=checked, documents=len(docs),
           scope="File/directory existence only; remote URLs and heading fragments are not fetched or validated; framework/templates excluded")


def arithmetic(run: dict[str, Decimal], civilizations: dict[str, Decimal]) -> None:
    errors: list[str] = []
    needed = {"check_probability_min", "check_probability_max", "check_critical_divisor"}
    if not needed <= run.keys():
        record("d100 four-result partition", [f"missing parameters {sorted(needed - run.keys())}"])
    else:
        for key in needed:
            if run[key] != run[key].to_integral_value():
                errors.append(f"{key}: integer required for d100 partition")
        lower, upper, divisor = (int(run[key]) for key in ("check_probability_min", "check_probability_max", "check_critical_divisor"))
        if not (0 < lower <= upper < 100 and divisor > 0):
            errors.append("invalid probability range or critical divisor")
        else:
            for probability in range(lower, upper + 1):
                critical = probability // divisor
                disaster_width = (100 - probability + divisor - 1) // divisor
                buckets = {"deep": set(range(1, critical + 1)), "success": set(range(critical + 1, probability + 1)),
                           "failure": set(range(probability + 1, 101 - disaster_width)), "disaster": set(range(101 - disaster_width, 101))}
                if set().union(*buckets.values()) != set(range(1, 101)) or sum(map(len, buckets.values())) != 100:
                    errors.append(f"P={probability}: gaps or overlaps in four results")
                if len(buckets["deep"] | buckets["success"]) != probability:
                    errors.append(f"P={probability}: success outcome count differs from P")
        record("d100 four-result partition", errors, probability_min=lower, probability_max=upper,
               scope="Exhaustive arithmetic over integer P, mirrors documented intervals; no gameplay implementation is exercised")
    needed = {"initial_awakening", "insight_cap", "awakening_before_final_cap", "manifest_requirement", "anchor_planet_contribution", "anchor_system_contribution", "anchor_cosmic_contribution", "anchor_planet_upkeep", "anchor_system_upkeep", "anchor_cosmic_upkeep"}
    world_needed = {"planet_domains", "system_domains", "cosmic_domains", "institutions_per_domain", "domains_total"}
    errors = []
    if not needed <= run.keys() or not world_needed <= civilizations.keys():
        record("Terminal prerequisite arithmetic", [f"missing run={sorted(needed - run.keys())}; world={sorted(world_needed - civilizations.keys())}"])
        return
    if sum(civilizations[f"{tier}_domains"] for tier in ("planet", "system", "cosmic")) != civilizations["domains_total"]:
        errors.append("civilization tier counts do not sum to domains_total")
    capacities = [int(civilizations[f"{tier}_domains"] * civilizations["institutions_per_domain"]) for tier in ("planet", "system", "cosmic")]
    feasible: list[dict] = []
    for p, s, c in itertools.product(*(range(capacity + 1) for capacity in capacities)):
        if s < 1 or c < 1:
            continue
        score = run["initial_awakening"] + run["insight_cap"] + p * run["anchor_planet_contribution"] + s * run["anchor_system_contribution"] + c * run["anchor_cosmic_contribution"]
        if min(score, run["awakening_before_final_cap"]) >= run["manifest_requirement"]:
            upkeep = p * run["anchor_planet_upkeep"] + s * run["anchor_system_upkeep"] + c * run["anchor_cosmic_upkeep"]
            feasible.append({"planet_anchors": p, "system_anchors": s, "cosmic_anchors": c, "anchor_count": p + s + c,
                             "awakening_before_cap": int(score), "upkeep_per_turn": int(upkeep)})
    if not feasible:
        errors.append("even zero-wound/max-insight states cannot satisfy manifest threshold within world capacity")
    feasible.sort(key=lambda value: (value["anchor_count"], value["upkeep_per_turn"], value["awakening_before_cap"]))
    record("Terminal prerequisite arithmetic", errors, candidate_states=len(feasible), minimum_anchor_example=feasible[0] if feasible else None,
           assumptions="All required institutions/persons/relics available, insight at cap, zero wounds, costs ignored when acquiring; one active system and cosmic anchor required",
           scope="Numerical non-impossibility only; does not prove a legal acquisition route, affordability, survival, win rate, or absence of a dominant strategy")


def main() -> int:
    load_tables()
    run = parameters("run_parameters")
    civilizations = parameters("civilization_parameters")
    parameters("event_parameters")
    parameters("simulation_parameters")
    check_civilizations()
    check_narrative()
    check_powers_relics(run)
    check_prayer_facts_and_resistance()
    check_npcs()
    check_simulation_catalogs()
    check_inline_ids()
    check_documents()
    arithmetic(run, civilizations)
    failures = sum(check["status"] == "FAIL" for check in CHECKS)
    SOURCES.add(Path(__file__).resolve())
    report = {
        "generated_at": datetime.now(ZoneInfo("Asia/Shanghai")).isoformat(),
        "status": "FAIL" if failures else "PASS", "total_checks": len(CHECKS), "failed_checks": failures,
        "command": "python3 tools/planning-check/check.py", "checks": CHECKS,
        "scope": "Static formal planning/catalog integrity; separate from Godot technical fixture evidence; no full game, balance, prose-quality, UI, or playability proof.",
        "source_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(SOURCES)},
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"REPORT {REPORT.relative_to(ROOT)}: {len(CHECKS)} checks, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
