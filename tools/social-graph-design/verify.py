"""Static CSV checks and a finite budget witness; does not generate a game world."""
import argparse
import csv
import hashlib
import itertools
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ["data/social_graph_parameters.csv", "data/social_relation_types.csv",
           "data/prayer_root_rules.csv", "data/prayer_effects.csv",
           "data/simulation_parameters.csv", "data/npc_profiles.csv",
           "data/civilization_parameters.csv", "data/fidelity_parameters.csv",
           "tools/social-graph-design/verify.py"]


def rows(root, path):
    with (root / path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        result = list(reader)
        if not result or any(None in row or None in row.values() for row in result):
            raise ValueError(f"Malformed/empty CSV: {path}")
        keys = [row[reader.fieldnames[0]] for row in result]
        if len(keys) != len(set(keys)):
            raise ValueError(f"Duplicate key: {path}")
        return result


def collect(root):
    checks = []
    def check(key, assertion, details):
        checks.append({"id": key, "status": "pass" if assertion else "fail",
                       "kind": "static-data", "details": details})
    tables = {p: rows(root, p) for p in SOURCES if p.endswith(".csv")}
    raw = tables[SOURCES[0]]
    expected = {"id", "value", "unit", "rationale"}
    check("SGD-CSV-SHAPE", all(set(row) == expected and row["unit"] and row["rationale"] for row in raw),
          "Parameter rows have unique IDs, numeric values, units and reasons; all CSV rows retain their columns.")
    parameters = {row["id"]: int(row["value"]) for row in raw}
    check("SGD-CSV-BOUNDS", all(v >= 0 for v in parameters.values()) and
          parameters["initial_edge_denominator"] > 0 and parameters["initial_degree_influence_divisor"] > 0 and
          parameters["model_version"] >= 1 and parameters["contact_weight_base"] > 0 and
          parameters["initial_degree_base"] <= parameters["initial_degree_max"] and
          parameters["validation_seed_count"] > 0 and
          all(0 <= v <= 100 for k, v in parameters.items() if k.endswith("_percent")),
          "Budgets/divisors/seed count and proposed statistical thresholds have legal finite ranges; thresholds are not measured outcomes.")
    types = {row["id"]: row for row in tables[SOURCES[1]]}
    expected_types = {"family", "support", "cooperation", "rival", "hostile", "favor_owed"}
    type_fields = {"id", "direction", "initial_weight", "initial_rule", "initial_need_tags", "coexists_with", "duplicate_policy", "retirement_rule", "knowledge_rule"}
    authored_needs = {tag for row in tables[SOURCES[5]] for tag in row["need_tags"].split(";")}
    check("SGD-TYPES", set(types) == expected_types and all(
        set(row) == type_fields and row["direction"] in {"mutual", "directed"} and int(row["initial_weight"]) >= 0 and
        (set(row["initial_need_tags"].split("|")) - {""}) <= authored_needs and
        bool(row["initial_need_tags"]) == (row["initial_rule"] == "cohort_competing_need") and
        row["initial_rule"] and row["retirement_rule"] and row["knowledge_rule"] and
        row["duplicate_policy"] == ("same_pair_type_idempotent" if row["direction"] == "mutual" else "same_ordered_pair_type_idempotent")
        for row in types.values()), "Six types have explicit direction, idempotency, origin, retirement and knowledge rules.")
    check("SGD-COEXISTENCE", all(
        set(row["coexists_with"].split("|")) <= set(types) and all(
            key in types[other]["coexists_with"].split("|") for other in row["coexists_with"].split("|"))
        for key, row in types.items()), "Type coexistence references are valid and symmetric; contacts are counted by person pair.")
    root_rule = next(row for row in tables[SOURCES[2]] if row["id"] == "ROOT_INITIAL_TIES")
    check("SGD-ROOT-OWNER", root_rule["producer_task"] == "TASK-SOCIAL-GRAPH" and
          set(root_rule["product_kind"].split("|")) == {"social_graph_generation", "social_contact", "initial_relationship"},
          "Initial-ties design data names the unique graph task and all three products. Current Catalog hardcoded grammar still requires migration; no load success claimed.")
    expiry = [row for row in tables[SOURCES[3]] if row["prayer_id"] == "PRAYER_02" and row["stage"] == "expiry"]
    check("SGD-PR02-EXPIRY", len(expiry) == 1 and expiry[0]["operation"] == "settle_dispute" and
          expiry[0]["subject"] == "institution" and expiry[0]["field"] == "default_stance" and expiry[0]["condition"] == "all",
          "PR02 design effect settles the original record dispute rather than appointing its rival.")
    legacy = next(row for row in tables[SOURCES[4]] if row["id"] == "initial_generic_relation_count")
    check("SGD-LEGACY", legacy["value"] == "1" and "兼容" in legacy["rationale"],
          "Old count remains 1 with an explicit legacy note; it is not a second target budget source.")

    # An existence proof only: no weighted graph generation or seed statistics here.
    profiles = {row["id"]: row for row in tables[SOURCES[5]]}
    chosen = ["NPC_PROFILE_01", "NPC_PROFILE_02", "NPC_PROFILE_03",
              "NPC_PROFILE_03", "NPC_PROFILE_05", "NPC_PROFILE_05"]
    institutions = ["interpretation", "interpretation", "propagation", "propagation", "order", "order"]
    n = len(chosen)
    population = {row["id"]: int(row["value"]) for row in tables[SOURCES[6]]}
    fidelity = {row["id"]: int(row["value"]) for row in tables[SOURCES[7]]}
    target = min(n * (n - 1) // 2, n * parameters["initial_edge_numerator"] // parameters["initial_edge_denominator"])
    caps = [min(n - 1, parameters["initial_degree_max"], parameters["initial_degree_base"] +
                int(profiles[key]["influence"]) // parameters["initial_degree_influence_divisor"]) for key in chosen]
    witness = None
    # The existing three institution links permit these contact pairs. This is a
    # labelled design example, not a generated roster, attendance or knowledge fact.
    for edges in itertools.combinations(list(itertools.combinations(range(n), 2)), target):
        neighbors = [set() for _ in range(n)]
        for a, b in edges:
            neighbors[a].add(b); neighbors[b].add(a)
        degrees = [len(group) for group in neighbors]
        if any(degree > cap for degree, cap in zip(degrees, caps)):
            continue
        if min(degrees) < parameters["initial_coverage_degree"] or max(degrees) < 3 or len(set(degrees)) < 2:
            continue
        if not any(neighbors[a] & neighbors[b] for a, b in edges):
            continue
        centers = [i for i in range(n) if institutions[i] == "interpretation" and len(neighbors[i]) >= 3 and
                   any(institutions[j] != institutions[i] for j in neighbors[i])]
        if centers:
            witness = {"profiles": chosen, "institutions": institutions, "degreeCaps": caps,
                       "edges": [list(pair) for pair in edges], "degrees": degrees,
                       "fourPersonCenter": centers[0], "targetEdges": target,
                       "possiblePositiveType": "family"}
            break
    check("SGD-SIX-PERSON-WITNESS", n <= population["initial_named_per_domain"] and
          len(set(institutions)) <= population["institutions_per_domain"] and
          n <= fidelity["local_actor_limit"] and fidelity["candidate_actor_limit"] >= 4 and
          all(institution in profiles[key]["institution_roles"].split("|") for key, institution in zip(chosen, institutions)) and
          witness is not None and types["family"]["direction"] == "mutual" and
          int(types["family"]["initial_weight"]) > 0 and types["family"]["initial_rule"] == "cohort_contact",
          "Finite enumeration permits a six-person topology with an interpretation-institution center, three contacts eligible for mutual family typing, triangle, cross-institution contact and degree differences. It does not prove these types are generated, a meeting happens or a memory request occurs.")
    return checks, witness


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--report", default="tools/social-graph-design/results.json")
    args = parser.parse_args()
    try:
        checks, witness = collect(args.root)
    except (OSError, ValueError, KeyError, StopIteration) as exc:
        print(f"Static input rejected: {exc}")
        return 1
    report = {"schemaVersion": 1, "suite": "social-graph-design-static-data", "kind": "static-data-analysis",
              "generatedAt": datetime.now(timezone.utc).isoformat(), "checks": checks,
              "sourceHashes": {p: hashlib.sha256((args.root / p).read_bytes()).hexdigest() for p in SOURCES},
              "abstractBudgetWitness": witness,
              "limitations": ["No game initialization, weighted algorithm, fixed-seed statistics, prayer production or save behavior ran.",
                              "New data is not yet consumed by Catalog/World; current root grammar migration and CULT compatibility are pending."]}
    destination = args.root / args.report
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    passed = sum(c["status"] == "pass" for c in checks)
    print(f"Static design data: {passed}/{len(checks)} checks pass; abstract budget witness={witness is not None}. No gameplay execution.")
    return 0 if passed == len(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
