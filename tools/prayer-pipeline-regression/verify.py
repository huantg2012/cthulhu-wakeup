"""Fresh, immutable-input prayer/graph regression; never invokes an old runner."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import runpy
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TASK = "TASK-PRAYER-PIPELINE-REGRESSION"
TITLE = "Prayer Pipeline Regression with Source-Backed Social Graph"
ORIGINALS = {
    "knowledge": ("tools/prayer-knowledge/verify.py", 72),
    "dispatch": ("tools/prayer-dispatch/verify.py", 55),
    "producers": ("tools/prayer-producers/verify.py", 56),
    "integration": ("tools/prayer-integration/verify.py", 41),
    "graph": ("tools/social-graph-restore/verify.py", 166),
}
EVIDENCE_CLASSES = {"runtime_component", "detached_predicate", "mixed_runtime_and_predicate", "counterfactual_probe"}
REWORK_REVIEW = "docs/qa/prayer-pipeline-regression-fixture-review.md"
REWORK_AUTH = HERE / "rework-authorization.json"
REWORK_CONSUMPTION = HERE / "rework-consumption.json"
FAILED_RUNS = (
    "tools/prayer-pipeline-regression/runs/formal-20261029T115916Z-1708487c/results.json",
    "tools/prayer-pipeline-regression/runs/formal-20261029T122020Z-4b63abcc/results.json",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8", newline="\n")


def sources(include_authorization: bool = True) -> dict[str, str]:
    paths = {ROOT / "project.godot", ROOT / "CLAUDE.md", ROOT / "docs/world.md",
             ROOT / "docs/architecture.md", ROOT / "docs/tasks/slice-14.md",
             ROOT / "docs/specs/ui-interaction.md", HERE / ".gitattributes",
             HERE / "protected-baseline.json", ROOT / REWORK_REVIEW,
             HERE / "rework-authorization.schema.json"}
    if include_authorization and REWORK_AUTH.exists():
        paths.add(REWORK_AUTH)
    for pattern in ("src/**/*.gd", "data/*.csv", "docs/specs/system-*.md",
                    "tools/**/*.gd", "tools/prayer-pipeline-regression/*.py",
                    "tools/prayer-pipeline-regression/*.md",
                    "tools/prayer-pipeline-regression/adapters/**/*.md",
                    "tools/prayer-pipeline-regression/adapters/**/*.json"):
        paths.update(ROOT.glob(pattern))
    paths.update(ROOT / path for path, _ in ORIGINALS.values())
    # Generated predicate probes belong to artifacts, not newly drifting inputs.
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)
            if not p.is_relative_to(HERE / "runs")}


def rework_authorization(gate: dict, args) -> dict:
    """Validate root-issued approval; this function never creates approval."""
    if REWORK_CONSUMPTION.exists():
        raise ValueError("High-level rework budget already consumed, including interrupted runs")
    value = json.loads(REWORK_AUTH.read_text(encoding="utf-8"))
    if (value.get("schemaVersion") != 1 or value.get("task") != TASK
            or value.get("kind") != "high_level_fixture_rework"
            or value.get("formalRunBudget") != 1
            or not isinstance(value.get("authorizationId"), str)
            or not value["authorizationId"].strip()):
        raise ValueError("Invalid one-use high-level rework authorization")
    if gate.get("consecutiveFailures") != 2 or len(gate.get("attempts", [])) != 2:
        raise ValueError("Rework must preserve the exact two-failure handoff ledger")
    if value.get("priorFailureLedgerSha256") != sha(HERE / "formal-gates.json"):
        raise ValueError("Original failure ledger bytes differ from approval")
    failures = {path: sha(ROOT / path) for path in FAILED_RUNS}
    if value.get("failedResultHashes") != failures:
        raise ValueError("Authorization does not bind both original failed reports")
    for attempt, path in zip(gate["attempts"], FAILED_RUNS):
        if attempt.get("status") != "fail" or attempt.get("archive") != str(Path(path).parent).replace("\\", "/"):
            raise ValueError("Original failure attempts changed")
        if json.loads((ROOT / path).read_text(encoding="utf-8")).get("status") != "fail":
            raise ValueError("Original failure report no longer records FAIL")
    if value.get("review") != {"path": REWORK_REVIEW, "sha256": sha(ROOT / REWORK_REVIEW)}:
        raise ValueError("Rework review bytes do not match approval")
    approvals = value.get("approvals", {})
    for role in ("root", "independentQa", "contractReviewer"):
        entry = approvals.get(role, {})
        if (entry.get("approved") is not True or not isinstance(entry.get("reviewer"), str)
                or not entry["reviewer"].strip() or not isinstance(entry.get("approvedAt"), str)
                or not entry["approvedAt"].strip()):
            raise ValueError("Missing explicit reviewed approval: " + role)
    if approvals["root"]["reviewer"] != "/root":
        raise ValueError("Only the main-session root may issue this authorization")
    if value.get("sourceHashes") != sources(False):
        raise ValueError("Authorization does not bind the complete current reviewed input set")
    if value.get("execution") != {"godot": args.godot, "executionContext": args.execution_context,
                                  "timeoutSeconds": args.timeout} or args.execution_context != "host-approved":
        raise ValueError("Execution parameters differ from root approval")
    return value


def consume_rework(value: dict, archive: Path) -> dict:
    record = {"schemaVersion": 1, "kind": "high_level_fixture_rework",
              "authorizationId": value["authorizationId"], "authorizationSha256": sha(REWORK_AUTH),
              "consumedAt": datetime.now(timezone.utc).isoformat(),
              "archive": archive.relative_to(ROOT).as_posix(), "formalRunBudget": 1,
              "originalConsecutiveFailuresRetained": 2,
              "rule": "Consumed before the first engine process; success, failure, timeout or interruption never renews approval."}
    # Exclusive creation is the cross-process lock and the durable one-use ledger.
    with REWORK_CONSUMPTION.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    return record


def original_ids() -> dict[str, set[str]]:
    result = {}
    for name, (path, expected_count) in ORIGINALS.items():
        # Import functions only. An old runner's main()/write paths never run.
        module = runpy.run_path(str(ROOT / path))
        ids = module["EXPECTED"] if name == "graph" else module["expected_ids"](False)
        if not isinstance(ids, set) or len(ids) != expected_count:
            raise ValueError(f"Protected {name} expectation changed: {len(ids)} != {expected_count}")
        result[name] = ids
    return result


def adapter_manifest(original: dict[str, set[str]]) -> dict:
    path = HERE / "adapters/manifest.json"
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("schemaVersion") != 1 or set(value.get("suites", {})) != set(ORIGINALS):
        raise ValueError("Adapter manifest needs exactly the five original suites")
    for name, row in value["suites"].items():
        ids = row.get("supplementalExpected")
        if (not isinstance(ids, list) or len(ids) != len(set(ids))
                or any(not isinstance(x, str) or not x.startswith("PPR-") for x in ids)
                or set(ids) & original[name]
                or not isinstance(row.get("prerequisiteAdaptations"), list)):
            raise ValueError(f"Invalid supplemental expectation/adaptation manifest for {name}")
        classes = row.get("evidenceClasses", {})
        if (not isinstance(classes, dict) or set(classes) - (original[name] | set(ids))
                or any(v not in EVIDENCE_CLASSES for v in classes.values())
                or any(x not in classes for x in ids)):
            raise ValueError(f"Missing or invalid explicit evidence class for {name}")
    return value


def preservation() -> dict:
    baseline = json.loads((HERE / "protected-baseline.json").read_text(encoding="utf-8"))
    files = baseline.get("files", {})
    if baseline.get("schemaVersion") != 1 or not files:
        raise ValueError("Missing immutable pre-task file baseline")
    changed = [p for p, digest in files.items()
               if not (ROOT / p).is_file() or sha(ROOT / p) != digest]
    return {"baselineCommit": baseline["baselineCommit"], "files": len(files),
            "changed": changed, "unchanged": not changed}


def execute(command: list[str], timeout: int) -> tuple[int | None, str]:
    env = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=timeout, env=env)
        return process.returncode, process.stdout + process.stderr
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""
        return None, decode(error.stdout) + decode(error.stderr) + "\nRUNNER TIMEOUT\n"
    except OSError as error:
        return None, str(error)


def engine_errors(value: str) -> list[str]:
    return list(dict.fromkeys(line for line in value.splitlines()
                             if "SCRIPT ERROR:" in line or line.lstrip().startswith("ERROR:")))


def parsed_raw(path: Path) -> tuple[dict, str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return (value, "") if isinstance(value, dict) else ({}, "Raw output must be an object")
    except (ValueError, OSError) as error:
        return {}, str(error)


def coverage(rows, expected: set[str]) -> dict:
    valid = isinstance(rows, list) and all(isinstance(c, dict) and isinstance(c.get("id"), str)
                                          and c.get("status") in {"pass", "fail"} for c in rows)
    actual = [c["id"] for c in rows] if valid else []
    return {"ok": valid and len(actual) == len(expected) and set(actual) == expected,
            "validRows": valid, "expected": len(expected), "actual": len(actual),
            "missing": sorted(expected - set(actual)), "extra": sorted(set(actual) - expected),
            "duplicateIds": len(actual) != len(set(actual))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--check-only", action="store_true", help="All five syntax checks; no behavior acceptance")
    parser.add_argument("--timeout", type=int, default=240, help="Per-suite timeout, not an unbounded retry")
    parser.add_argument("--execution-context", choices=("sandbox", "host-approved"), required=True)
    parser.add_argument("--high-level-rework", action="store_true", help="Consume one root-issued, hash-bound transferred rework authorization")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 600:
        parser.error("timeout must be 1..600 seconds")
    if args.check_only and args.high_level_rework:
        parser.error("check-only is syntax evidence and cannot consume formal rework approval")
    gate_path = HERE / "formal-gates.json"
    gate = json.loads(gate_path.read_text(encoding="utf-8")) if gate_path.exists() else {"consecutiveFailures": 0, "attempts": []}
    if not args.check_only and gate["consecutiveFailures"] >= 2 and not args.high_level_rework:
        print("STOP: two consecutive formal failures; transfer to the main session.", file=sys.stderr)
        return 2
    try:
        original = original_ids()
        manifest = adapter_manifest(original)
        protected_before = preservation()
        before = sources()
        authorization = rework_authorization(gate, args) if args.high_level_rework else None
        if not protected_before["unchanged"]:
            raise ValueError("Protected historical inputs changed; no engine execution permitted")
    except (ValueError, OSError, KeyError) as error:
        print("Prerequisite metadata unavailable: " + str(error), file=sys.stderr)
        return 2
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8]
    archive = HERE / "runs" / (("check-" if args.check_only else "formal-rework-" if authorization else "formal-") + stamp)
    archive.mkdir(parents=True)
    summaries, combined, processes = {}, [], []
    write(archive / "source-inputs.json", before)
    write(archive / "adapter-manifest.json", manifest)
    rework = None
    if authorization:
        try:
            if before != sources():
                raise ValueError("Reviewed input changed before authorization consumption")
            # Persist exact approval bytes before irrevocably consuming it.
            (archive / "rework-authorization.json").write_bytes(REWORK_AUTH.read_bytes())
            rework = consume_rework(authorization, archive)
            write(archive / "rework-consumption.json", rework)
        except (OSError, ValueError) as error:
            print("STOP before engine execution: " + str(error), file=sys.stderr)
            return 2
    for name in ORIGINALS:
        directory = archive / name
        directory.mkdir()
        raw_path = directory / "raw.json"
        script = f"res://tools/prayer-pipeline-regression/adapters/{name}.gd"
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(directory / "godot.log")]
        if args.check_only:
            command.append("--check-only")
        command += ["--script", script]
        if not args.check_only:
            command += ["--", str(raw_path)]
        print(f"START {name}: {len(original[name])} original requirements", flush=True)
        code, log = execute(command, args.timeout)
        (directory / "process.log").write_text(log, encoding="utf-8", newline="\n")
        native = (directory / "godot.log").read_text(encoding="utf-8", errors="replace") if (directory / "godot.log").exists() else ""
        errors = engine_errors(log + "\n" + native)
        raw, raw_issue = ({}, "") if args.check_only else parsed_raw(raw_path)
        expected = original[name] | set(manifest["suites"][name]["supplementalExpected"])
        exact = coverage(raw.get("checks", []), expected)
        raw_ok = (raw.get("status") == "pass" and isinstance(raw.get("checks"), list)
                  and exact["validRows"] and all(c["status"] == "pass" for c in raw.get("checks", [])))
        child_frozen = before == sources()
        ok = code == 0 and not errors and child_frozen and (args.check_only or (raw_ok and exact["ok"]))
        summary = {"suite": name, "status": "pass" if ok else "fail", "command": command,
                   "originalRequirementCount": len(original[name]),
                   "supplementalRequirementCount": len(expected - original[name]),
                   "processExit": code, "engineErrors": errors, "rawIssue": raw_issue,
                   "sourceInputsUnchanged": child_frozen,
                   "coverage": exact, "raw": raw, "sourceHashes": before,
                   "artifactHashes": {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(directory.rglob("*")) if p.is_file()},
                   "acceptanceScope": "parse_only" if args.check_only else "current_prayer_graph_regression_components"}
        # Original IDs remain directly addressable in each per-suite report.
        summary["checks"] = [] if args.check_only else raw.get("checks", [])
        write(directory / "results.json", summary)
        summaries[name] = {"report": (directory / "results.json").relative_to(ROOT).as_posix(),
                           "status": summary["status"], "processExit": code, "engineErrors": errors,
                           "rawOk": raw_ok, "coverage": exact, "sourceInputsUnchanged": child_frozen}
        processes.append({"suite": name, "exitCode": code, "engineErrors": errors})
        if not args.check_only and exact["validRows"]:
            combined.extend({**row, "id": name + "/" + row["id"], "originalId": row["id"], "suite": name,
                             "evidenceClass": manifest["suites"][name].get("evidenceClasses", {}).get(row["id"], "runtime_component")}
                            for row in raw["checks"])
        print(f"{summary['status'].upper()} {name}: {code}; {len(errors)} engine ERRORs", flush=True)
        if not ok:
            print(log[-2200:], flush=True)
    menu = {"skipped": args.check_only}
    if not args.check_only:
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(archive / "menu-godot.log"), "--quit-after", "2"]
        code, log = execute(command, 30)
        (archive / "menu-process.log").write_text(log, encoding="utf-8", newline="\n")
        native = (archive / "menu-godot.log").read_text(encoding="utf-8", errors="replace") if (archive / "menu-godot.log").exists() else ""
        menu = {"exitCode": code, "engineErrors": engine_errors(log + "\n" + native),
                "scope": "Two-frame root-menu smoke, not a new Session or full campaign"}
    protected_after = preservation()
    frozen = (before == sources() and protected_before["unchanged"] and protected_after["unchanged"]
              and all(x["sourceInputsUnchanged"] for x in summaries.values()))
    wrappers = [{"id": "PPR-WRAPPER/PROCESS", "status": "pass" if all(p["exitCode"] == 0 and not p["engineErrors"] for p in processes) else "fail", "details": processes},
                {"id": "PPR-WRAPPER/FROZEN", "status": "pass" if frozen else "fail", "details": {"sourceInputsUnchanged": before == sources(), "protectedBefore": protected_before, "protectedAfter": protected_after}}]
    if not args.check_only:
        wrappers += [{"id": "PPR-WRAPPER/RAW", "status": "pass" if all(x["rawOk"] for x in summaries.values()) else "fail"},
                     {"id": "PPR-WRAPPER/EXACT-COVERAGE", "status": "pass" if all(x["coverage"]["ok"] for x in summaries.values()) else "fail", "details": {k: v["coverage"] for k, v in summaries.items()}},
                     {"id": "PPR-WRAPPER/MENU", "status": "pass" if menu["exitCode"] == 0 and not menu["engineErrors"] else "fail", "details": menu}]
    passed = all(c["status"] == "pass" for c in wrappers)
    report = {"schemaVersion": 1, "task": TASK, "title": f"{TASK} — {TITLE}",
              "generatedAt": datetime.now(timezone.utc).isoformat(), "status": "pass" if passed else "fail",
              "acceptanceScope": "parse_only" if args.check_only else "current_prayer_graph_regression_components",
              "originalRequirementExecutions": sum(len(x) for x in original.values()),
              "supplementalRequirementExecutions": sum(len(x["supplementalExpected"]) for x in manifest["suites"].values()),
              "evidenceClassCounts": {kind: sum(c["evidenceClass"] == kind for c in combined) for kind in sorted(EVIDENCE_CLASSES)},
              "suites": summaries, "adapterManifest": manifest, "sourceHashes": before,
              "artifactHashes": {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(archive.rglob("*")) if p.is_file()},
              "checks": ([] if args.check_only else combined) + wrappers,
              "environment": {"python": platform.python_version(), "platform": platform.platform(), "executionContext": args.execution_context},
              "runKind": "syntax_only" if args.check_only else "high_level_fixture_rework" if rework else "original_formal",
              "highLevelRework": rework,
              "limitations": ["390 counts original requirement executions across five suites; some inherited checks repeat across suites. It is not a count of independent game features.",
                              "Legal fixture changes and obsolete-input rejection/equivalent controls must be read alongside every original requirement; mixed/predicate/counterfactual checks are not production pipeline execution.",
                              "No new injury/root implementation, natural-campaign reachability, complete CULT/Session, UI or balance acceptance.",
                              "Old reports/tools remain historical bytes. All failure and ERROR archives are retained; two consecutive formal failures transfer ownership."]}
    write(archive / "results.json", report)
    if not args.check_only:
        write(HERE / "results.json", report)
        if not rework:
            gate["consecutiveFailures"] = 0 if passed else gate["consecutiveFailures"] + 1
        attempt = {"archive": archive.relative_to(ROOT).as_posix(), "status": report["status"], "generatedAt": report["generatedAt"]}
        if rework:
            attempt.update({"kind": "high_level_fixture_rework", "authorizationId": rework["authorizationId"],
                            "originalConsecutiveFailuresRetained": 2, "additionalBudgetExhausted": True})
        gate["attempts"].append(attempt)
        write(gate_path, gate)
    print(f"{report['status'].upper()} {len(combined)} behavior executions + {len(wrappers)} gates; {archive.relative_to(ROOT)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
