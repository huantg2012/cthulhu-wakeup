"""Read retained M1 natural Sessions; do not generate or mutate game state."""
from __future__ import annotations

import hashlib
import itertools
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(seed: int, core: dict) -> dict:
    directory = ROOT / f"tools/startup-balance/runs/calibration-02/natural-{seed}"
    paths = sorted(p for p in directory.glob("*.json") if p.name != "latest.json")
    assert len(paths) == 1, "Expected the one retained original Session, not a selected winner"
    path = paths[0]
    before = digest(path)
    session = json.loads(path.read_text(encoding="utf-8"))["body"]
    turn = json.loads(session["snapshot"])["body"]
    state = json.loads(turn["world"])["body"]["state"]
    context = turn["context"]
    # The retained autosave precedes the final public observation. Compare
    # the two saved cursors with each other, never with a later observation.
    assert (state["turn"], state["phase"]) == (context["turn"], context["phase"])
    assert state["phase"] == "between" and core["final"]["phase"] == "actions"
    assert core["final"]["turn"] == state["turn"] + 1
    knowledge = context["player_knowledge"]
    assert session["knowledge"]["cursor"] == knowledge["cursor"]
    for public, internal in [("facts", "known_facts"), ("people", "known_people"), ("domains", "known_domains")]:
        assert set(session["knowledge"][public]) == set(knowledge[internal])
    people = state["npcs"]
    facts = state["facts"]
    for fact_id, fact in facts.items():
        assert fact_id == fact["id"] and fact["turn"] <= state["turn"]
        assert all(parent in facts for parent in fact["causal_parents"])
    cohorts = []
    for cohort_id, cohort in state["social_graph"]["cohorts"].items():
        members = cohort["member_ids"]
        if not members:
            continue
        edges = set()
        for source in state["social_graph"]["edge_heads"].values():
            change = facts[source]["changes"]
            a, b = change["a"], change["b"]
            if a in members and b in members:
                edges.add(tuple(sorted((a, b))))
        degrees = {p: sum(p in edge for edge in edges) for p in members}
        unseen = set(members)
        components = []
        while unseen:
            component = {min(unseen)}
            frontier = list(component)
            unseen.difference_update(component)
            while frontier:
                person = frontier.pop()
                neighbors = {b if a == person else a for a, b in edges if person in (a, b)}
                new = neighbors & unseen
                unseen.difference_update(new)
                component.update(new)
                frontier.extend(sorted(new))
            components.append(sorted(component))
        triangles = sum(
            all(tuple(sorted(edge)) in edges for edge in itertools.combinations(triple, 2))
            for triple in itertools.combinations(members, 3)
        )
        cohorts.append({
            "cohort": cohort_id, "members": len(members), "distinctAdjacencies": len(edges),
            "degrees": degrees, "triangles": triangles,
            "components": components,
            "density": 2 * len(edges) / (len(members) * (len(members) - 1)) if len(members) > 1 else 0,
            "crossInstitutionAdjacencies": sum(people[a]["institution"] != people[b]["institution"] for a, b in edges),
        })
    calls = []
    scenes = []
    for fact in facts.values():
        change = fact["changes"]
        if fact["kind"] == "prayer_call":
            knowledge = change.get("knowledge", "")
            assert change["source"] in facts
            if knowledge:
                assert knowledge in facts and facts[knowledge]["kind"] == "deity_identified"
                assert facts[knowledge]["changes"]["person"] == change["petitioner"]
            calls.append({"fact": fact["id"], "turn": fact["turn"],
                          "addressing": change["addressing"], "petitioner": change["petitioner"],
                          "source": change["source"], "sourceExists": change["source"] in facts,
                          "knowledge": knowledge, "knowledgeExists": knowledge in facts if knowledge else False})
        if fact["kind"] == "conflict_scene_fixed":
            participants = [p for p in fact["targets"] if p in people]
            scenes.append({"fact": fact["id"], "turn": fact["turn"], "rootKind": change.get("kind"),
                           "content": change.get("content"), "participants": participants,
                           "currentInstitutions": sorted({people[p]["institution"] for p in participants}),
                           "crossInstitutionAtSnapshot": len({people[p]["institution"] for p in participants}) > 1})
    kinds = Counter(f["kind"] for f in facts.values())
    materials = [f for f in facts.values() if f["kind"] == "route_material"]
    endpoint_facts = [f for f in facts.values() if f["kind"] == "cult_contact_route"]
    event09a = [f for f in facts.values() if f["kind"] == "event_result"
                and f["changes"].get("content_id") == "EVENT_09" and f["changes"].get("option") == "A"]
    identification = [f for f in facts.values() if f["kind"] == "deity_identified"]
    for person, head in state["prayer_knowledge"]["heads"].items():
        assert person in people and head["source"] in facts
        assert facts[head["source"]]["kind"] == "deity_identified"
        assert facts[head["source"]]["changes"]["person"] == person
    assert digest(path) == before, "Retained Session bytes changed during audit"
    return {
        "seed": seed, "snapshot": path.relative_to(ROOT).as_posix(), "snapshotSha256": before,
        "saved": {"world": {"turn": state["turn"], "phase": state["phase"]},
                  "context": {"turn": context["turn"], "phase": context["phase"]},
                  "terminal": state["ending_system"]["terminal"]},
        "finalObserved": core["final"], "sampleStatus": core["sampleStatus"], "observedCult": core["cult"],
        "graph": cohorts, "calls": calls, "callModes": dict(Counter(c["addressing"] for c in calls)),
        "sceneFixations": scenes, "factKindCounts": dict(sorted(kinds.items())),
        "crossInstitutionSources": [f for f in facts.values() if f["kind"] == "social_contact"
                                    and len(set(f["changes"].get("institutions", []))) > 1],
        "routeMaterials": materials,
        "materialHoldings": [{"material": f["id"], "originals": f["changes"]["originals"],
                              "peopleKnowing": sorted(p for p, npc in people.items() if f["id"] in npc["known_facts"]),
                              "institutionsKnowing": sorted(i for i, institution in state["institutions"].items()
                                                             if f["id"] in institution.get("known_facts", [])),
                              "invalidated": f["id"] in state["invalid_records"]} for f in materials],
        "materialReceipts": [f["id"] for f in facts.values() if f["kind"] == "material_received"],
        "identityKnowledge": {"facts": identification, "heads": state["prayer_knowledge"]["heads"]},
        "contactRouteEndpoints": endpoint_facts,
        "executedEvent09A": event09a,
        "savedMilestones": {"cultEstablishments": [f for f in facts.values() if f["kind"] == "cult_established"],
                            "cults": state["cults"], "anchors": state["anchors"],
                            "terminal": state["ending_system"]["terminal"]},
        "endpointFacts": [f["id"] for f in facts.values() if f["kind"] in ["cult_contact_route", "cult_spread", "cult_expansion", "anchor_created", "anchor_paid"]],
        "offered": state["prayer_system"]["offered"],
        "scope": "All fact, graph, knowledge, material, offered-card and saved-milestone fields describe the saved between-phase state, NOT finalObserved. Graph uses original cohort members and saved heads; current institutions are not historical scene institutions. social_contact institutions are source-time values. Material known_facts holdings do not prove full current route eligibility. No generation, restore execution, or eligibility proof is inferred from JSON decoding.",
    }


def main() -> None:
    core_path = ROOT / "tools/startup-balance/runs/calibration-02/core.json"
    protected = [core_path]
    protected.extend(ROOT / f"tools/natural-verify/audit-0{i}-failure.json" for i in (1, 2))
    for seed in range(1, 7):
        protected.extend((core_path.parent / f"natural-{seed}").glob("*.json"))
    hashes = {p: digest(p) for p in protected}
    core = json.loads(core_path.read_text(encoding="utf-8"))
    rows = [inspect(row["seed"], row) for row in core["checks"]]
    assert [row["seed"] for row in rows] == list(range(1, 7))
    output = {
        "schemaVersion": 2, "status": "pass", "runtimeExecution": False,
        "scope": "Read-only audit of the six already executed M1 natural Sessions, not six new trajectories or a successful whole calibration batch.",
        "corePath": core_path.relative_to(ROOT).as_posix(), "coreSha256": digest(core_path),
        "auditSourceSha256": digest(Path(__file__)), "samples": rows,
        "summary": {
            "samples": len(rows), "observedSampleStatuses": dict(Counter(r["sampleStatus"] for r in rows)),
            "savedCultSamples": sum(bool(r["savedMilestones"]["cults"]) for r in rows),
            "savedAnchorSamples": sum(bool(r["savedMilestones"]["anchors"]) for r in rows),
            "savedTerminalSamples": sum(bool(r["savedMilestones"]["terminal"]) for r in rows),
            "observedTerminalSamples": sum(bool(r["finalObserved"]["terminal"]) for r in rows),
            "routeMaterials": sum(len(r["routeMaterials"]) for r in rows),
            "materialReceipts": sum(len(r["materialReceipts"]) for r in rows),
            "identityFacts": sum(len(r["identityKnowledge"]["facts"]) for r in rows),
            "contactRouteEndpoints": sum(len(r["contactRouteEndpoints"]) for r in rows),
            "executedEvent09A": sum(len(r["executedEvent09A"]) for r in rows),
            "callModes": dict(sum((Counter(r["callModes"]) for r in rows), Counter())),
        },
        "unchangedInputs": {p.relative_to(ROOT).as_posix(): sha for p, sha in hashes.items()},
        "limits": ["No natural spread, active-anchor, or ending is inferred from source availability.",
                   "Saved autosaves and final public observations are different timepoints; between-phase offered arrays do not prove what was displayed at the next actions phase.",
                   "Graph structure does not prove dispute/memory production.",
                   "A cult_contact_route is the establishment endpoint, not an executed EVENT09/A transaction.",
                   "Zero observations do not prove a missing producer or zero future probability."]}
    assert all(digest(p) == sha for p, sha in hashes.items()), "Original evidence bytes changed"
    destination = ROOT / "tools/natural-verify/readonly-audit.json"
    destination.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"samples": len(rows), "calls": sum(len(r["calls"]) for r in rows),
                      "callModes": dict(sum((Counter(r["callModes"]) for r in rows), Counter())),
                      "path": destination.relative_to(ROOT).as_posix()}))


if __name__ == "__main__":
    main()
