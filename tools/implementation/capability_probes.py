#!/usr/bin/env python3
"""Run three short probes and one real, reversible no-output handler control."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "res://tools/implementation/capability_probes.gd"
TARGET = ROOT / "src/game/events.gd"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def input_hashes() -> dict[str, str]:
    """Only the probe's declared preload/extends closure and loaded CSV tables."""
    pending = [ROOT / SCRIPT.removeprefix("res://")]
    paths = {Path(__file__).resolve()}
    while pending:
        path = pending.pop()
        if path in paths: continue
        paths.add(path)
        for dependency in re.findall(r'(?:preload\(|extends )"res://([^"]+\.gd)"', path.read_text(encoding="utf-8-sig")):
            pending.append(ROOT / dependency)
    catalog = (ROOT / "src/simulation/catalog.gd").read_text(encoding="utf-8-sig")
    names = set()
    for constant in ("FILES", "EXTENSIONS"):
        block = re.search(rf"const {constant}:[^=]+?= \[(.*?)\]", catalog, re.S)
        if block: names.update(re.findall(r'"([a-z_]+)"', block.group(1)))
    names.update(["fidelity_parameters", "background_templates", "simulation_responsibilities", "intervention_policies"])
    paths.update(ROOT / "data" / (name + ".csv") for name in names)
    paths.add(ROOT / "project.godot")
    return {path.relative_to(ROOT).as_posix(): digest(path) for path in sorted(paths)}


def run(godot: str, output: Path, label: str) -> dict:
    report_path = output / (label + ".json")
    command = [godot, "--headless", "--path", str(ROOT), "--log-file", str(output / (label + "-engine.log")), "--script", SCRIPT, "--", str(report_path)]
    started = time.perf_counter()
    process = subprocess.run(command, capture_output=True, text=True, timeout=18)
    console = process.stdout + process.stderr
    (output / (label + "-console.log")).write_text(console, encoding="utf-8", newline="\n")
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    result = {"label": label, "command": command, "exit": process.returncode, "seconds": round(time.perf_counter() - started, 3), "engineErrors": "ERROR:" in console or "SCRIPT ERROR:" in console, "report": report}
    print(json.dumps({key: result[key] for key in ("label", "exit", "seconds", "engineErrors")}), flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True, help="A new directory; existing evidence is never overwritten")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = input_hashes()
    original = TARGET.read_bytes()
    text = original.decode("utf-8")
    pattern = re.compile(r"^func _origin_candidate\([^\n]+\n.*?(?=^func )", re.M | re.S)
    found = pattern.search(text)
    if not found: raise RuntimeError("Original handler boundary not found; refusing mutation")
    replacement = 'func _origin_candidate(_world: RefCounted, _choice: Dictionary, _owner: Object) -> Dictionary:\n\treturn {"ok": true, "outcome": "empty"}\n\n'
    if "\r\n" in text: replacement = replacement.replace("\n", "\r\n")
    mutant = (text[:found.start()] + replacement + text[found.end():]).encode("utf-8")
    runs = []
    restoration = False
    try:
        runs.append(run(args.godot, output, "baseline"))
        if runs[-1]["exit"] != 0 or runs[-1]["engineErrors"] or runs[-1]["report"].get("status") != "pass":
            raise RuntimeError("Baseline failed; mutation was not started")
        if TARGET.read_bytes() != original: raise RuntimeError("Source changed before exclusive mutation")
        TARGET.write_bytes(mutant)
        runs.append(run(args.godot, output, "empty-handler"))
    finally:
        current = TARGET.read_bytes()
        if current == mutant: TARGET.write_bytes(original)
        elif current != original: raise RuntimeError("Unexpected concurrent source edit; refusing to overwrite it")
        restoration = TARGET.read_bytes() == original
    runs.append(run(args.godot, output, "restored"))
    after = input_hashes()
    baseline, control, restored = runs
    positive = {row["id"]: row for row in baseline["report"].get("checks", [])}
    negative = {row["id"]: row for row in control["report"].get("checks", [])}
    production = negative.get("CP-PRODUCTION", {})
    details = production.get("details", {})
    controlled = control["exit"] == 1 and not control["engineErrors"] and control["report"].get("status") == "fail" and production.get("status") == "fail" and details.get("bindingAccepted") is True and details.get("turnsAdvanced") is True and details.get("reason") == "missing_call_or_fixed_card" and details.get("callCount") == 0 and details.get("fixedCount") == 0 and negative.get("CP-LEGAL-EMPTY", {}).get("status") == "pass"
    restored_ok = restoration and before == after and restored["exit"] == 0 and not restored["engineErrors"] and restored["report"].get("status") == "pass"
    checks = list(positive.values()) + [{"id": "CP-FAILURE-CONTROL", "status": "pass" if controlled and restored_ok else "fail", "details": {"actualFunctionBodyReplaced": True, "mutantHash": hashlib.sha256(mutant).hexdigest(), "guardAccepted": details.get("bindingAccepted"), "formalTurnsAdvanced": details.get("turnsAdvanced"), "actualProductFailureDetected": controlled, "restoredOriginalBytes": restoration, "originalHash": hashlib.sha256(original).hexdigest(), "unchangedInputs": before == after, "restoredBaselinePassed": restored_ok}}]
    report = {"status": "pass" if len(checks) == 4 and all(row["status"] == "pass" for row in checks) else "fail", "at": datetime.now(timezone.utc).isoformat(), "checks": checks, "runs": runs, "sourceHashes": after, "changedInputs": [path for path in before if before[path] != after[path]], "scope": "three_existing_record_probes_and_real_empty_handler_control", "limitations": ["Only the declared existing-record prerequisites and three bounded cases are covered.", "The control replaces the actual registered origin handler body, not its Callable or resulting report data.", "No whole-project omission guarantee, full Session or natural-campaign acceptance."]}
    (output / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": report["status"], "checks": len(checks), "restored": restoration, "changedInputs": report["changedInputs"]}))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
