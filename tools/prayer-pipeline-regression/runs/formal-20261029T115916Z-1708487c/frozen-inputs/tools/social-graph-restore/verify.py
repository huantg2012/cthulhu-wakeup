"""Fresh real-Godot evidence for Social Graph Birth Provenance and Strong Restore Audit."""
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
TASK = "TASK-SOCIAL-GRAPH-RESTORE"
TITLE = "Social Graph Birth Provenance and Strong Restore Audit"
CATALOG_NEGATIVES = (
    "duplicate_parameter", "zero_denominator", "negative_weight", "invalid_percent",
    "missing_type", "wrong_direction", "unknown_need", "duplicate_need",
    "asymmetric_coexistence", "wrong_duplicate_policy", "wrong_root_owner",
    "negative_legacy_count", "fractional_legacy_count",
    "no_contact_type",
)
EXPECTED = {
    "SGI-CATALOG", "SGI-CATALOG/ALTERNATE", "SGI-CATALOG/TRANSACTIONAL",
    "SGI-CATALOG/ZERO-TYPES", "SGI-CATALOG/LEGACY-IGNORED",
    "SGI-CONTROL/SEEDS-128", "SGI-CONTROL/METRICS", "SGI-CONTROL/TYPES",
    "SGI-CONTROL/DETERMINISM", "SGI-CONTROL/HASH-GRAMMAR",
    "SGI-CONTROL/EMPTY-SINGLE", "SGI-CONTROL/INVALID-INPUTS",
    "SGI-WORLD/ACTUAL-GENERATE", "SGI-WORLD/ACTUAL-FIRST-FOCUS",
    "SGI-WORLD/OLD-BOOTSTRAP-EXCLUDED", "SGI-WORLD/REPEATED-FOCUS",
    "SGI-WORLD/NOMINATION-NO-GRAPH", "SGI-WORLD/CAPACITY-POPULATION",
    "SGI-WORLD/EMPTY-FIRST-FOCUS",
    "SGI-WORLD/SOURCE-CLOSURE", "SGI-RELATION/DIRECTION-HEADS",
    "SGI-RELATION/IDEMPOTENCE", "SGI-RELATION/DETACHED-READS",
    "SGI-RELATION/LOCAL-PAGE", "SGI-RELATION/LEGACY-ADAPTER",
    "SGI-RELATION/MANAGED-WRITER", "SGI-RELATION/WRITER-REJECT-SOURCE",
    "SGI-PRIVACY/ONLY-ENDS", "SGI-PRIVACY/NO-DATA-SPREAD",
    "SGI-SAVE/CURRENT-ROUNDTRIP", "SGI-SAVE/REJECT-MISSING-HEAD",
    "SGI-SAVE/REJECT-ORPHAN", "SGI-SAVE/REJECT-OLD-SCHEMA",
    "SGI-ATOMIC/GENERATION-FAULT",
    "SGI-ATOMIC/PLAN-RESERVE", "SGI-ATOMIC/CAPACITY-HOLD",
} | {"SGI-CATALOG/" + name for name in CATALOG_NEGATIVES}

# Current relation checks, distinct from the 50 initialization regressions.
EXPECTED |= {
    'SGR-BUSINESS/PRAYER_10/WRITE',
    'SGR-BUSINESS/PRAYER_10/IDEMPOTENT',
    'SGR-BUSINESS/PRAYER_10/REJECT-SOURCE',
    'SGR-BUSINESS/PRAYER_10/REJECT-DIRECTION',
    'SGR-BUSINESS/PRAYER_10/REPLAY',
    'SGR-BUSINESS/EVENT_03/WRITE',
    'SGR-BUSINESS/EVENT_03/IDEMPOTENT',
    'SGR-BUSINESS/EVENT_03/REJECT-SOURCE',
    'SGR-BUSINESS/EVENT_03/REJECT-DIRECTION',
    'SGR-BUSINESS/EVENT_03/REPLAY',
    'SGR-BUSINESS/EVENT_09/WRITE',
    'SGR-BUSINESS/EVENT_09/IDEMPOTENT',
    'SGR-BUSINESS/EVENT_09/REJECT-SOURCE',
    'SGR-BUSINESS/EVENT_09/REJECT-DIRECTION',
    'SGR-BUSINESS/EVENT_09/REPLAY',
    'SGR-BUSINESS/PRAYER_10/UNKNOWN-DISCLOSURE',
    'SGR-RELATION/MULTI-TYPE',
    'SGR-RELATION/REVERSE-DIRECTED',
    'SGR-RELATION/MUTUAL',
    'SGR-RETIRE/EXACT',
    'SGR-RETIRE/HEAD-INDEX',
    'SGR-RETIRE/REPEAT',
    'SGR-RETIRE/OLD-PROOF',
    'SGR-RETIRE/NEW-EPISODE',
    'SGR-RETIRE/OLD-RECEIPT',
    'SGR-RETIRE/REJECT-REBIND',
    'SGR-RETIRE/UNAUTHORIZED-INVALIDATION',
    'SGR-RETIRE/REJECT-ORIGIN',
    'SGR-RETIRE/REJECT-HEAD',
    'SGR-RETIRE/FAILED-CHECK',
    'SGR-RETIRE/ATOMIC',
    'SGR-RETIRE/REJECT-DELETE-ALIAS',
    'SGR-RETIRE/MISSING-ALIAS-BINDING',
    'SGR-INDEX/DETACHED-SOURCE',
    'SGR-INDEX/PAGINATION',
    'SGR-INDEX/CLOSED-VIEW',
    'SGR-INDEX/COLD-HISTORY',
    'SGR-SAVE/CURRENT-AND-RESIGNED',
    'SGR-SAVE/MISSING-PROOF',
    'SGR-SAVE/MISSING-ALIAS',
    'SGR-SAVE/REBOUND-PROOF',
    'SGR-SAVE/INVALID-RETIREMENT',
    'SGR-SAVE/INCOMPLETE-RESULT',
    'SGR-SAVE/OLD-WORLD-2',
    'SGR-STATE/MISSING',
    'SGR-STATE/DETAINED',
    'SGR-STATE/RESTORED',
    'SGR-STATE/MIGRATION',
    'SGR-STATE/DEATH',
    'SGR-STATE/INSTITUTION',
    'SGR-STATE/CHANNEL',
}

RESTORE_EXPECTED = {
    "SGS-BIRTH/ORIGINAL-PROFILES", "SGS-BIRTH/VERSIONS", "SGS-BIRTH/RECIPE-INDEPENDENT",
    "SGS-BIRTH/JOINT-PROFILE", "SGS-BIRTH/JOINT-INSTITUTION",
    "SGS-BIRTH/JOINT-REPRESENTATIVE", "SGS-BIRTH/JOINT-EXPANDED",
    "SGS-BIRTH/INSTITUTION-SNAPSHOT", "SGS-BIRTH/JOINT-IDENTITY",
    "SGS-BIRTH/OLD-WORLD-2", "SGS-BIRTH/OLD-WORLD-3", "SGS-BIRTH/OLD-GRAPH",
    "SGS-BIRTH/MISSING-COHORTS",
    "SGS-PROJECTION/ROUNDTRIP", "SGS-PROJECTION/MISSING-OWNER",
    "SGS-PROJECTION/DUPLICATE", "SGS-PROJECTION/EXTRA-OWNER",
    "SGS-PROJECTION/REVERSE-DIRECTED", "SGS-PROJECTION/WRONG-TARGET",
    "SGS-PROJECTION/WRONG-TYPE", "SGS-PROJECTION/MISSING-SOURCE",
    "SGS-PROJECTION/NONRELATION-SOURCE", "SGS-PROJECTION/MISSING-RETIRED",
    "SGS-PROJECTION/EXTRA-FIELD", "SGS-PROJECTION/MUTUAL-MISSING-SECOND",
    "SGS-PROJECTION/JOINT-PROJECTION",
    "SGS-NORMAL/DUPLICATE-NEW-SUFFIX", "SGS-NORMAL/MISSING-NEW-PROJECTION",
    "SGS-NORMAL/DUPLICATE-OLD-SOURCE", "SGS-NORMAL/REMOVE-HISTORY",
    "SGS-NORMAL/REWRITE-OLD-SOURCE", "SGS-NORMAL/REPLACE-SOURCE-ROOT",
    "SGS-NORMAL/REWRITE-OLD-COHORT", "SGS-NORMAL/LEGAL-AFTER-ROLLBACK",
    "SGS-NORMAL/RETIRED-HISTORY-SCALING", "SGS-NORMAL/BIRTH-IDENTITY",
    "SGS-FOCUS/ROUNDTRIP", "SGS-FOCUS/JOINT-PROFILE", "SGS-FOCUS/JOINT-INSTITUTION",
    "SGS-FOCUS/WRONG-FOCUS", "SGS-FOCUS/JOINT-SEQUENCE", "SGS-FOCUS/JOINT-PHASE",
    "SGS-FOCUS/JOINT-RANGE", "SGS-FOCUS/MISSING-FOCUS-PARENT", "SGS-FOCUS/OLD-TURN",
    "SGS-FOCUS/MISSING-ADMISSION", "SGS-FOCUS/WRONG-ADMISSION",
    "SGS-FOCUS/UNAUTHORIZED-SET_PLAN", "SGS-FOCUS/UNAUTHORIZED-RELEASE_FOCUS",
    "SGS-FOCUS/REFOCUS-ROUNDTRIP", "SGS-FOCUS/REFOCUS-UNKNOWN-DOMAIN",
    "SGS-BOOTSTRAP/OUTER-BOUNDARY", "SGS-BOOTSTRAP/WORLD-CHAIN",
    "SGS-BOOTSTRAP/SELECTED-NOMINATION", "SGS-BOOTSTRAP/CONTACT-SELECTED",
    "SGS-BOOTSTRAP/CONTACT-NOMINATION", "SGS-BOOTSTRAP/CALL", "SGS-BOOTSTRAP/FIXED",
    "SGS-BOOTSTRAP/FINAL-ONCE", "SGS-BOOTSTRAP/BOOTSTRAP-POSITION",
    "SGS-COMBINED/TURN-CONTINUITY", "SGS-COMBINED/RESTORE-REFOCUS-MIGRATION",
    "SGS-ADMISSION/MULTI-TRANSFER", "SGS-ADMISSION/MULTI-RITUAL",
    "SGS-ADMISSION/DEFAULT-STRATEGY-HISTORY",
}
EXPECTED |= RESTORE_EXPECTED


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes() -> dict[str, str]:
    paths = {ROOT / "project.godot", ROOT / "CLAUDE.md", ROOT / "docs/architecture.md",
             ROOT / "docs/tasks/slice-14.md", HERE / ".gitattributes"}
    for pattern in ("src/**/*.gd", "data/*.csv", "docs/specs/system-*.md",
                    "tools/social-graph-restore/*.gd",
                    "tools/social-graph-restore/*.py",
                    "tools/social-graph-restore/*.md",
                    "tools/social-graph-initialization/run.gd",
                    "tools/social-graph-relations/run.gd",
                    "tools/social-graph-initialization/runs/formal-20261029T072954Z-e5b34c67/actual-world-initializations.json"):
        paths.update(ROOT.glob(pattern))
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}


def execute(command: list[str], timeout: int) -> tuple[int | None, str]:
    env = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
    try:
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                             encoding="utf-8", errors="replace", timeout=timeout, env=env)
        return run.returncode, run.stdout + run.stderr
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""
        return None, decode(error.stdout) + decode(error.stderr) + "\nRUNNER TIMEOUT\n"
    except OSError as error:
        return None, str(error)


def engine_errors(text: str) -> list[str]:
    return list(dict.fromkeys(line for line in text.splitlines()
                             if "SCRIPT ERROR:" in line or line.lstrip().startswith("ERROR:")))


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--execution-context", choices=("sandbox", "host-approved"), default="sandbox")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 600:
        parser.error("timeout must be 1..600 seconds")
    gate_file = HERE / "formal-gates.json"
    gate = json.loads(gate_file.read_text(encoding="utf-8")) if gate_file.exists() else {"consecutiveFailures": 0, "attempts": []}
    formal = not args.development and not args.check_only
    if formal and gate["consecutiveFailures"] >= 2:
        print("STOP: two consecutive formal gates failed; hand ownership to the main session.", file=sys.stderr)
        return 2
    before = hashes()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8]
    directory = HERE / "runs" / (("check-" if args.check_only else "development-" if args.development else "formal-") + stamp)
    directory.mkdir(parents=True)
    raw_path = directory / "raw.json"
    command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(directory / "godot.log")]
    if args.check_only:
        command += ["--check-only"]
    command += ["--script", "res://tools/social-graph-restore/run.gd"]
    if not args.check_only:
        command += ["--", str(raw_path)]
    code, log = execute(command, args.timeout)
    (directory / "process.log").write_text(log, encoding="utf-8", newline="\n")
    engine_log = (directory / "godot.log").read_text(encoding="utf-8", errors="replace") if (directory / "godot.log").exists() else ""
    errors = engine_errors(log + "\n" + engine_log)
    raw, raw_issue = {}, ""
    if not args.check_only:
        try:
            raw = json.loads(raw_path.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                raw = {}
                raw_issue = "Raw output must be an object."
        except (ValueError, OSError) as error:
            raw_issue = str(error)
    rows = raw.get("checks", [])
    valid = isinstance(rows, list) and all(isinstance(c, dict) and isinstance(c.get("id"), str)
                                         and c.get("status") in {"pass", "fail"} for c in rows)
    actual = [c["id"] for c in rows] if valid else []
    wrapper = [{"id": "SGS-WRAPPER/PROCESS", "status": "pass" if code == 0 and not errors else "fail",
                "details": {"exitCode": code, "engineErrors": errors}}]
    if not args.check_only:
        wrapper += [
            {"id": "SGS-WRAPPER/RAW", "status": "pass" if valid and raw.get("status") == "pass" and all(c["status"] == "pass" for c in rows) else "fail", "details": {"issue": raw_issue, "rawStatus": raw.get("status")}},
            {"id": "SGS-WRAPPER/EXACT-COVERAGE", "status": "pass" if set(actual) == EXPECTED and len(actual) == len(EXPECTED) else "fail", "details": {"expected": len(EXPECTED), "actual": len(actual), "missing": sorted(EXPECTED - set(actual)), "extra": sorted(set(actual) - EXPECTED), "duplicates": len(actual) != len(set(actual))}},
        ]
        menu_command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(directory / "menu-godot.log"), "--quit-after", "2"]
        menu_code, menu_log = execute(menu_command, 30)
        (directory / "menu-process.log").write_text(menu_log, encoding="utf-8", newline="\n")
        menu_engine = (directory / "menu-godot.log").read_text(encoding="utf-8", errors="replace") if (directory / "menu-godot.log").exists() else ""
        menu_errors = engine_errors(menu_log + "\n" + menu_engine)
        wrapper.append({"id": "SGS-WRAPPER/MENU", "status": "pass" if menu_code == 0 and not menu_errors else "fail", "details": {"exitCode": menu_code, "engineErrors": menu_errors, "scope": "Two-frame root menu parse smoke; no complete Session/new-game claim."}})
    wrapper.append({"id": "SGS-WRAPPER/FROZEN", "status": "pass" if before == hashes() else "fail"})
    passed = all(c["status"] == "pass" for c in wrapper)
    report = {"schemaVersion": 1, "task": TASK, "title": f"{TASK} — {TITLE}",
              "status": "pass" if passed else "fail", "generatedAt": datetime.now(timezone.utc).isoformat(),
              "acceptanceScope": "parse_only" if args.check_only else "development_diagnostic_only" if args.development else "real_social_graph_birth_and_restore_components",
              "command": command, "raw": raw, "checks": ([] if args.check_only or not valid else rows) + wrapper,
              "sourceHashes": before, "artifactHashes": {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(directory.rglob("*")) if p.is_file()},
              "environment": {"engine": raw.get("engine"), "python": platform.python_version(), "platform": platform.platform(), "executionContext": args.execution_context},
              "limitations": ["Controlled A-F graph samples and actual World integration are reported separately; no natural PR-family reachability or complete campaign is accepted.",
                              "World birth provenance and projection auditing are bounded by the stated matrix; complete Session, natural requests and parent aggregation require their own evidence.",
                              "No full Session continuation or visual/experience acceptance. All raw, failure and engine ERROR artifacts remain archived.",
                              "Development and check-only output never replaces formal acceptance."]}
    write(directory / "results.json", report)
    if formal:
        write(HERE / "results.json", report)
        gate["consecutiveFailures"] = 0 if passed else gate["consecutiveFailures"] + 1
        gate["attempts"].append({"archive": directory.relative_to(ROOT).as_posix(), "status": report["status"], "generatedAt": report["generatedAt"]})
        write(gate_file, gate)
    print(log[-1800:])
    print(f"{report['status'].upper()} {len(actual)} behavior checks + {len(wrapper)} wrapper gates; {directory.relative_to(ROOT)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
