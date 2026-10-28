"""Run the bounded real-module dispatch suite; preserve failures and raw bytes."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes() -> dict:
    paths = {ROOT / "project.godot", ROOT / "docs/architecture.md", ROOT / "docs/tasks/slice-14.md"}
    for pattern in ("src/**/*.gd", "data/*.csv", "tools/**/*.gd", "tools/prayer-dispatch/*.py", "tools/prayer-dispatch/*.md", "docs/specs/system-*.md"):
        paths.update(ROOT.glob(pattern))
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}


def expected_ids(probe: bool) -> set:
    result = {"PD-CATALOG", "PD-CADENCE-SWITCH", "PD-INDEPENDENT-SAME-PETITIONER", "PD-PAGE-CONTINUATION", "PD-SAVE-ROUNDTRIP", "PD-SAVE-RESIGN-CONTROL", "PD-SESSION-CULT-BOUNDARY"}
    result.update("PD-COORDINATOR/" + name for name in ("focused_handler", "background_handler", "coordinator_owner"))
    for mode in ("focused", "background"):
        result.add("PD-INSTALL/" + mode)
        result.update("PD-EXISTING/" + name + "/" + mode for name in ("FIRST", "EVERY-TURN", "UNIQUE"))
    result.update("PD-DUE-PRIORITY/" + name for name in ("blocked_retry", "new_earlier"))
    result.update("PD-NOTICE/" + name for name in ("focused", "background", "unidentified", "anomaly_only", "no_relation", "wrong_relation", "no_route", "dead", "detained", "missing", "cross_domain", "same_institution", "ROLLBACK"))
    result.update(f"PD-FIRST-DEVOTION/{variant}/{outcome}" for variant in ("shallow", "deep") for outcome in ("deep", "success", "failure", "disaster"))
    result.update("PD-FIRST-DEVOTION-REJECT/" + name for name in ("wrong_membership", "wrong_person", "missing_devotion_cause", "different_commit_same_turn"))
    result.update("PD-SAVE-REJECT/" + name for name in ("schema", "version", "installed", "last", "head_omission", "position", "rng_joint", "position_joint", "snapshot_commit", "snapshot_cutoff"))
    return result


def evaluate(raw: dict, expected: set, process_exit, errors: list, unchanged: bool) -> list:
    checks = raw.get("checks", [])
    valid = isinstance(checks, list) and all(isinstance(c, dict) and isinstance(c.get("id"), str) and c.get("status") in ("pass", "fail") for c in checks)
    actual = [c["id"] for c in checks] if valid else []
    return [
        {"id": "PD-WRAPPER-REPORT", "status": "pass" if valid and raw.get("status") == "pass" and all(c["status"] == "pass" for c in checks) else "fail", "details": {"rawStatus": raw.get("status"), "validChecks": valid}},
        {"id": "PD-WRAPPER-COVERAGE", "status": "pass" if valid and set(actual) == expected and len(actual) == len(expected) else "fail", "details": {"expected": len(expected), "actual": len(actual), "missing": sorted(expected - set(actual)), "extra": sorted(set(actual) - expected), "duplicateIds": len(actual) != len(set(actual))}},
        {"id": "PD-WRAPPER-PROCESS", "status": "pass" if process_exit == 0 and not errors else "fail", "details": {"exitCode": process_exit, "godotErrors": errors}},
        {"id": "PD-WRAPPER-FROZEN", "status": "pass" if unchanged else "fail", "details": {"sourcesUnchangedDuringRun": unchanged}},
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--probe", action="store_true", help="Reserved diagnostic flag; no acceptance")
    parser.add_argument("--development", action="store_true", help="Keep this diagnostic run separate; never replace formal results.json")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if not 1 <= args.timeout <= 600:
        parser.error("timeout must be 1..600 seconds")
    before = hashes()
    directory = HERE / "runs" / (("probe-" if args.probe else "dispatch-") + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8])
    directory.mkdir(parents=True)
    target = directory / "raw.json"
    script = "run.gd"
    command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(directory / "godot.log"), "--script", "res://tools/prayer-dispatch/" + script, "--", str(target)]
    env = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
    issue = ""
    try:
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=args.timeout)
        log = completed.stdout + completed.stderr
        process_exit = completed.returncode
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
        log = decode(error.stdout) + decode(error.stderr)
        process_exit = None
        issue = "Godot execution timed out; partial raw/log artifacts preserved."
    except OSError as error:
        log = str(error)
        process_exit = None
        issue = "Godot could not start."
    (directory / "process.log").write_text(log, encoding="utf-8", newline="\n")
    raw = {}
    if target.exists():
        try:
            raw = json.loads(target.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                raw = {}
                issue = "Raw report is not an object."
        except (ValueError, OSError) as error:
            issue = "Cannot parse fresh raw report: " + str(error)
    else:
        issue = issue or "Godot did not create a fresh raw report."
    engine_path = directory / "godot.log"
    engine_log = engine_path.read_text(encoding="utf-8", errors="replace") if engine_path.exists() else ""
    errors = list(dict.fromkeys(line for line in (log + "\n" + engine_log).splitlines() if "SCRIPT ERROR:" in line or line.lstrip().startswith("ERROR:")))
    wrapper_checks = evaluate(raw, expected_ids(args.probe), process_exit, errors, before == hashes())
    if not args.probe:
        menu_command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(directory / "menu-godot.log"), "--quit-after", "2"]
        try:
            menu = subprocess.run(menu_command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=30)
            menu_log = menu.stdout + menu.stderr
            menu_exit = menu.returncode
        except (subprocess.TimeoutExpired, OSError) as error:
            menu_log = str(error)
            menu_exit = None
        (directory / "menu-process.log").write_text(menu_log, encoding="utf-8", newline="\n")
        menu_engine_path = directory / "menu-godot.log"
        menu_engine_log = menu_engine_path.read_text(encoding="utf-8", errors="replace") if menu_engine_path.exists() else ""
        menu_errors = list(dict.fromkeys(line for line in (menu_log + "\n" + menu_engine_log).splitlines() if "SCRIPT ERROR:" in line or line.lstrip().startswith("ERROR:")))
        wrapper_checks.append({"id": "PD-WRAPPER-MENU", "status": "pass" if menu_exit == 0 and not menu_errors else "fail", "details": {"exitCode": menu_exit, "godotErrors": menu_errors, "scope": "Two-frame root-project parse/menu smoke only; no playable new game claim"}})
        if before != hashes():
            wrapper_checks[3]["status"] = "fail"
            wrapper_checks[3]["details"]["sourcesUnchangedDuringRun"] = False
    if issue:
        wrapper_checks.append({"id": "PD-WRAPPER-EXECUTION", "status": "fail", "details": {"error": issue}})
    passed = all(c["status"] == "pass" for c in wrapper_checks)
    artifacts = {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(directory.iterdir()) if p.is_file()}
    report_checks = raw.get("checks", []) if isinstance(raw.get("checks"), list) else []
    scope = "environment_probe_only" if args.probe else ("development_diagnostic_only" if args.development else "bounded_prayer_dispatch_modules")
    report = {"status": "pass" if passed else "fail", "executionStatus": "complete" if raw else "incomplete", "generatedAt": datetime.now(timezone.utc).isoformat(), "acceptanceScope": scope, "command": command, "raw": raw, "checks": report_checks + wrapper_checks, "wrapperChecks": wrapper_checks, "sourceHashes": before, "artifactHashes": artifacts, "environment": {"engine": raw.get("engine"), "platform": platform.platform(), "python": platform.python_version(), "headless": True}, "limitations": ["Published situation prerequisites may be explicit fixtures; all dispatch behavior must use production World.evolve.", "No new raw-root/call production, four-cell direction/mode, atomic bootstrap, action-window, minimal projection, full Session restore, balance or natural new-game acceptance.", "All original ERROR lines remain process failures, separate from behavior assertion failures.", "A probe or development run does not constitute TASK-PRAYER-DISPATCH acceptance."]}
    destination = directory / "results.json"
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    if not args.probe and not args.development:
        temporary = HERE / "results.pending.json"
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        temporary.replace(HERE / "results.json")
    print(log[-2000:])
    print(f"{report['status'].upper()} raw_checks={len(raw.get('checks', []))} wrapper_checks={len(wrapper_checks)} report={destination.relative_to(ROOT)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
