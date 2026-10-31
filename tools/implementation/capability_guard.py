#!/usr/bin/env python3
"""Fast, bounded checks of the actual candidate-generation production wiring.

This is deliberately a small source-shape check, not a GDScript parser or a
semantic proof. capability_guard.gd exercises the same runtime binding validator;
short behavior probes must establish whether the bound implementations work.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import time

ROOT = Path(__file__).resolve().parents[2]
INPUTS = [
    "data/simulation_responsibilities.csv", "src/simulation/abstract_sim.gd",
    "src/simulation/world.gd", "src/game/turn.gd", "src/game/events.gd",
    "src/game/prayer_dispatch.gd", "src/game/prayer_producers.gd",
    "src/game/prayer_sources.gd",
    "data/prayer_root_rules.csv",
]


def body(source: str, name: str) -> str:
    found = re.search(rf"^(?:static )?func {re.escape(name)}\([^\n]*\n(?P<body>(?:(?:\t[^\n]*|)\n)*)", source, re.M)
    return found.group("body") if found else ""


def inspect(sources: dict[str, str]) -> list[str]:
    errors = []
    rows = list(csv.DictReader(io.StringIO(sources[INPUTS[0]])))
    duties = [row for row in rows if row["id"] == "candidate_generation"]
    if len(duties) != 1:
        return ["candidate_generation must have one authored responsibility"]
    duty = duties[0]
    if duty["commit_owner"] != "events" or duty["focused"] == duty["background"] or "4" not in duty["phase"].split("|"):
        errors.append("candidate_generation has an unsupported owner/mode/phase")
    events = sources["src/game/events.gd"]
    initial = body(events, "_init")
    bindings = re.findall(r'"([^"]+)": Callable\(self, "([^"]+)"\)', initial)
    for mode in (duty["focused"], duty["background"]):
        if bindings.count((mode, mode)) != 1 or not body(events, mode):
            errors.append("Missing or wrong callable declaration: " + mode)
    for method in ("_origin_candidate", "_rescue_candidate", "_identity_notice"):
        if not body(events, method): errors.append("Missing root method: " + method)
    if 'for root: String in Producers.ROOTS: candidate_handlers[root] = Callable(self, "_origin_candidate")' not in initial:
        errors.append("Formal origin bindings are disconnected from Producers.ROOTS")
    if 'for root: String in Sources.ROOTS: candidate_handlers[root] = Callable(self, "_rescue_candidate")' not in body(events, "install_rescue_sources"):
        errors.append("Formal scene bindings are disconnected from Sources.ROOTS")
    root_rows = list(csv.DictReader(io.StringIO(sources["data/prayer_root_rules.csv"])))
    declarations = {row["id"] for row in root_rows if row["id"] not in {"ROOT_INITIAL_TIES", "ROOT_SHARED_OBSERVATION"}}
    roots = {"ROOT_IDENTITY_NOTICE"}
    for path in ("src/game/prayer_producers.gd", "src/game/prayer_sources.gd"):
        declaration = re.search(r'^const ROOTS:[^\n]+', sources[path], re.M)
        text = declaration.group(0) if declaration else ""
        roots.update(re.findall(r'"(ROOT_[A-Z_]+)"', text))
        if "[ROOT," in text:
            root = re.search(r'^const ROOT: String = "([^"]+)"', sources[path], re.M)
            if root: roots.add(root.group(1))
    if declarations != roots:
        errors.append("Declared CSV roots disagree with formal producer roots: " + str(sorted(declarations ^ roots)))
    owners = []
    for path, source in sources.items():
        if not path.startswith("src/"): continue
        for registration in re.findall(r'\.register_participant\([^\n]+', source):
            if '"candidate_generation"' in registration: owners.append(path)
    if owners != ["src/game/events.gd"]:
        errors.append("candidate_generation requires one formal registration: " + str(owners))
    world = body(sources["src/simulation/world.gd"], "evolve")
    dispatch = sources["src/game/prayer_dispatch.gd"]
    for call in (".prepare_generation(self, view, owner)", ".commit_generation(self, generation, owner)"):
        if call not in world: errors.append("World.evolve disconnected: " + call)
    for name in ("prepare", "commit"):
        if "_managed(world, coordinator, owner)" not in body(dispatch, name):
            errors.append("Dispatch bypasses binding guard: " + name)
    for name in ("prepare", "commit"):
        if "coordinator.generation_binding_errors(world, owner)" not in body(dispatch, name):
            errors.append("Formal Dispatch does not consume actual binding validation: " + name)
    if "world.abstract_sim.responsibilities.candidate_generation" not in body(dispatch, "prepare") or "coordinator.mode_handlers[mode].call(" not in body(dispatch, "prepare"):
        errors.append("Dispatch does not use authored duty and actual mode bindings")
    if "coordinator.candidate_handlers[" not in body(dispatch, "commit"):
        errors.append("Dispatch does not use actual root bindings")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    started = time.perf_counter()
    sources = {path: (ROOT / path).read_text(encoding="utf-8-sig") for path in INPUTS}
    checks = [{"id": "CG-STATIC-WIRING", "errors": inspect(sources)}]
    mutations = [
        ("CG-STATIC-MISSING", "src/game/events.gd", "func detailed_candidates(", "func removed_detailed_candidates("),
        ("CG-STATIC-WRONG", "src/game/events.gd", '"detailed_candidates": Callable(self, "detailed_candidates")', '"detailed_candidates": Callable(self, "abstract_candidates_due")'),
        ("CG-STATIC-DUPLICATE", INPUTS[0], "candidate_generation,detailed_candidates,abstract_candidates_due,events,bootstrap|4", "candidate_generation,detailed_candidates,abstract_candidates_due,events,bootstrap|4\ncandidate_generation,detailed_candidates,abstract_candidates_due,world,4"),
        ("CG-STATIC-DISCONNECTED", "src/simulation/world.gd", ".prepare_generation(self, view, owner)", ".removed_generation(self, view, owner)"),
        ("CG-STATIC-DECLARED-ROOT", "src/game/prayer_producers.gd", '"ROOT_KNOWN_RECORD": "PRAYER_04", ', ""),
    ]
    for check_id, path, before, after in mutations:
        mutated = dict(sources)
        changed = before in mutated[path]
        mutated[path] = mutated[path].replace(before, after, 1)
        detected = inspect(mutated) if changed else []
        checks.append({"id": check_id, "errors": [] if changed and detected else ["Negative control was not detected"], "detected": detected})
    for check in checks: check["status"] = "pass" if not check["errors"] else "fail"
    report = {"status": "pass" if all(c["status"] == "pass" for c in checks) else "fail", "seconds": round(time.perf_counter() - started, 4), "scope": "candidate_generation_source_wiring", "checks": checks,
              "sourceHashes": {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in INPUTS + ["tools/implementation/capability_guard.py", "tools/implementation/capability_guard.gd"]},
              "limitations": ["Finite source-shape checks; equivalent source refactors may require updating this checker.", "No semantic output or natural-session guarantee; lawful empty generation is permitted."]}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
