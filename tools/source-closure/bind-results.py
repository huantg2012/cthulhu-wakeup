"""Bind the eight original acceptance assertions after Root freezes their documents."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = "docs/qa/source-closure-results.json"


def read(name: str) -> dict:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def sha(name: str) -> str:
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def reference(name: str, checks: list[str] | None = None) -> dict:
    result = {"report": name, "sha256": sha(name)}
    if checks:
        report = read(name)
        actual = {row["id"]: row for row in report["checks"]}
        assert all(actual[check]["status"] == "pass" for check in checks), name
        result["checks"] = checks
        result["originalReportStatus"] = report.get("status")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contracts-frozen", action="store_true", required=True)
    args = parser.parse_args()
    assert args.contracts_frozen
    anchor_path = "tools/source-closure/runs/finish-05/anchor.json"
    wounds_path = "tools/source-closure/runs/finish-05-wounds/wounds.json"
    anchor_execution_path = "tools/source-closure/runs/finish-05/execution.json"
    wounds_execution_path = "tools/source-closure/runs/finish-05-wounds/execution.json"
    anchor = read(anchor_path)
    wounds = read(wounds_path)
    executions = [read(anchor_execution_path), read(wounds_execution_path)]
    assert anchor["status"] == wounds["status"] == "pass"
    assert all(row["status"] == "pass" and not row["changedInputs"] and all(run["passed"] and not run["engineErrors"] for run in row["runs"]) for row in executions)
    assert executions[0]["sourceHashes"] == executions[1]["sourceHashes"]
    runtime_hashes = executions[1]["sourceHashes"]
    assert all(sha(name) == value for name, value in runtime_hashes.items()), "Runtime inputs changed after execution"

    mature_path = "docs/qa/mature-anchor-network-results.json"
    mature = read(mature_path)
    continuation = mature["retainedContinuation"]
    assert continuation["successfulGameplayInvocations"] == 144 and continuation["originalRestores"] == 143
    ready_path = "tools/source-closure/runs/formal-01/mature-ready.json"
    ready = read(ready_path)
    assert ready["status"] == "pass" and ready["state"]["awakening"] == 93 and ready["state"]["phase"] == "actions"
    assert ready["snapshotSha256"] == "814a8ae5463770e18165b5172dfbcf3e60189c5eff449d8bed716731f2716b90"
    assert hashlib.sha256(Path(ready["snapshot"]).read_bytes()).hexdigest() == ready["snapshotSha256"]
    prepare_path = "tools/source-closure/runs/finish-03/anchor.json"
    prepare = next(row for row in read(prepare_path)["checks"] if row["id"] == "SC-MATURE-PREPARE")
    assert prepare["status"] == "pass"

    families = reference("tools/implementation/capability-guard-frozen-core-results.json", ["SLT-EXPIRY", "SLT-RESCUE", "SLT-CAPACITY", "SLC-PRAYER_02", "SLC-PRAYER_10", "SLC-PRAYER_03", "SLC-PRAYER_11", "SC-SHALLOW", "SC-DEEP", "SC-EXPIRY", "SC-SUCCESSION", "SM-SHALLOW", "SM-DEEP", "SM-EXPIRY", "SE-FIRST", "SE-INDEPENDENCE", "SE-CAPACITY"])
    scheduler = reference("docs/qa/opportunity-scheduler-results.json", ["OQ-POLICY", "OQ-CALLBACKS", "OQ-SESSION", "OQ-COMPONENTS"])
    service = reference("tools/opportunity-scheduler/runs/repair-01/direct-service.json", ["OS-BOUNDARY", "OS-STAGES", "OS-AUTHORITY", "OS-COMPONENTS"])
    material = reference("docs/qa/material-transfer-results.json", ["MT-SOURCES", "MT-ENDPOINT", "MT-CURRENT", "MT-ATOMIC", "MT-EXECUTION"])
    material_raw = reference("tools/material-transfer/runs/presentation-copy-20261030T073700Z/materials.json")
    routes = reference("docs/qa/anchor-production-closure-results.json", ["APC-CONTRACT", "APC-NETWORK", "APC-RECORDS-CALENDAR", "APC-RITUAL", "APC-AXIOM", "APC-MEMORY-DISSENT"])
    first_cults = reference("docs/qa/progression-operations-results.json", ["PO-CONTACT", "PO-MATERIAL"])
    first_cults_raw = reference("tools/progression-operations/runs/presentation-02/core.json", ["PO-CONTACT", "PO-MATERIAL"])
    contact = reference("tools/source-closure/runs/formal-01/contact.json", ["SC-NEXT-CONTACT"])
    anchor_ref = reference(anchor_path, ["SC-ANCHOR-RECOVERY"])
    wounds_ref = reference(wounds_path, ["SC-WOUND-RECOVERY"])
    terminal = reference("tools/source-closure/runs/finish-04/terminal.json", ["SC-TERMINAL-CORE"])
    index = reference("tools/source-closure/runs/finish-01/anchor.json", ["SC-INDEX-EQUIVALENCE"])
    reception = reference("tools/source-closure/runs/finish-01/material.json", ["SC-NEW-RECEPTION-INDEX"])
    validation = reference("tools/source-closure/runs/finish-02/anchor.json", ["SC-VALIDATOR-INDEX"])

    checks = [
        {"id": "MATURE-NETWORK-FINAL-TARGET", "status": "pass", "name": "One actual nine-anchor world reaches the original manifestation threshold", "evidence": [reference(mature_path, ["MATURE-NETWORK-FINAL-TARGET"]), reference(continuation["lastReport"]["path"]), reference(ready_path)], "details": {"retainedPaidActiveAnchors": 9, "retainedAwakening": 93, "sameWorld": True, "targetInjection": False}},
        {"id": "MATURE-NETWORK-CONTINUATION-COMPLETE", "status": "pass", "name": "Original component continuation preserves identities, sources, payment and exact checkpoints", "evidence": [reference(mature_path, ["MATURE-NETWORK-CONTINUATION-COMPLETE"]), reference(ready_path), anchor_ref, wounds_ref, terminal], "details": {"retainedOriginalSnapshotInvocations": 144, "retainedOriginalRestores": 143, "newAnchorRestoreExact": anchor["parent"]["originalRestoreExact"], "newWoundsRestoreExact": wounds["parent"]["originalRestoreExact"], "scope": "Actual component continuation; no complete Session-save acceptance or old matrix replay. Snapshot process invocations and in-process Turn.submit counts are separate units and are not added."}},
        {"id": "MATURE-NETWORK-MANIFEST-PREPARE", "status": "pass", "name": "Current pure shared manifestation entry consumes the produced mature world", "evidence": [reference(ready_path), reference(prepare_path, ["SC-MATURE-PREPARE"]), anchor_ref, wounds_ref], "details": {"originalSharedReadySnapshotSha256": ready["snapshotSha256"], "originalFinalChecks": prepare["details"]["actualOriginalFinalChecks"], "bothParentBranchesUseRetainedOriginalWorld": True}},
        {"id": "SOURCE-CLOSURE-GENERATION", "status": "pass", "name": "Five source families retain actual production and necessary consequences", "evidence": [families], "details": {"method": "Reuse seventeen original actual cores and independent current semantic-delta review; no family rerun or new background simulation."}},
        {"id": "SOURCE-CLOSURE-ALTERNATIVES", "status": "pass", "name": "Different actual alternative routes and bounded opportunity service remain available", "evidence": [routes, scheduler, service], "details": {"actualRoutes": 16, "method": "Retained individually blocked alternative-route actual reports plus original B waiting/FIFO and real actions service. No twenty direct B pipelines or natural win-rate claim."}},
        {"id": "SOURCE-CLOSURE-INDEPENDENCE", "status": "pass", "name": "Material independence and original resources, people, deadlines and cross-institution carriers remain authoritative", "evidence": [routes, material, families], "details": {"method": "Current delta reuse of actual production and ownership/participant checks, preserving original controlled fixtures and limitations."}},
        {"id": "SOURCE-CLOSURE-DELIVERY", "status": "pass", "name": "Actual material reception, original component retry and current proof consumers remain consistent", "evidence": [material, material_raw, reception, index, validation], "details": {"completeProofEqualityCount": 43, "oldFallbackSeconds": 30.087, "indexedSeconds": 0.270, "componentOnly": True, "fullSessionSave": False}},
        {"id": "SOURCE-CLOSURE-PLAYABLE-CHAINS", "status": "pass", "name": "Both first-cult organizations, all active-anchor routes, both ending recoveries and real next-window contact have actual evidence", "evidence": [routes, first_cults, first_cults_raw, anchor_ref, wounds_ref, contact], "details": {"firstCultEvidenceLimit": "PO-CONTACT records original T3/T4 gathering fees and asserts six followers, at least eight spending and a unique cult_established; PO-MATERIAL records T3/T4 rite successes and asserts two rites/one cult through the original six-person/eight-fee gate. The rite report does not print every final follower/payment/fact field.", "newContact": "The actual Endings prayer source is answered at its real next actions window. Separate later Private Devotion is not presented as the predicted contact.", "controlledFinalChecks": "Only original final-check RNG selects ordinary failure and later success; no wounds, anchor, completion or snapshot edit."}},
    ]

    traceability = read("docs/implementation/traceability.json")
    relevant_ids = {"ACC-SOURCE-CLOSURE", "ACC-MATURE-ANCHOR-NETWORK", "ACC-ANCHOR-ROUTE-CLOSURE"}
    contract_paths = {name for row in traceability["scenarios"] if row["id"] in relevant_ids for name in row["sources"]}
    contract_paths.update({"docs/qa/source-closure.md", "docs/progress/current-slice.md", "docs/progress/roadmap.md", "tools/source-closure/README.md", "tools/source-closure/bind-results.py"})
    excluded_parts = ("current-review", "traceability", "residual", "workbench")
    contract_paths = {name for name in contract_paths if name != TARGET and not any(part in name for part in excluded_parts)}
    contract_hashes = {name: sha(name) for name in sorted(contract_paths)}
    source_hashes = dict(runtime_hashes)
    source_hashes.update(contract_hashes)
    artifacts = {}
    for directory in (ROOT / "tools/source-closure/runs").iterdir():
        if directory.is_file():
            name = directory.relative_to(ROOT).as_posix()
            artifacts[name] = sha(name)
            continue
        if not directory.is_dir():
            continue
        for path in directory.iterdir():
            if path.is_file():
                name = path.relative_to(ROOT).as_posix()
                artifacts[name] = sha(name)
    references = [ref for check in checks for ref in check["evidence"]]
    reused_hashes = {ref["report"]: ref["sha256"] for ref in references}
    report = {
        "schemaVersion": 1, "suite": "source-closure", "status": "pass", "generatedAt": datetime.now(timezone.utc).isoformat(),
        "tasks": ["TASK-MATURE-ANCHOR-NETWORK", "TASK-SOURCE-CLOSURE"], "acceptances": ["ACC-MATURE-ANCHOR-NETWORK", "ACC-SOURCE-CLOSURE"],
        "scope": "Eight original acceptance assertions assembled from actual finite continuation and current reuse; not eight newly executed suites.",
        "checks": checks, "runtimeExecutions": [reference(anchor_execution_path), reference(wounds_execution_path)], "runtimeInputHashes": runtime_hashes,
        "postRunContractHashes": contract_hashes, "sourceHashes": dict(sorted(source_hashes.items())), "reusedEvidenceHashes": dict(sorted(reused_hashes.items())), "artifactHashes": dict(sorted(artifacts.items())),
        "actualRecovery": {"anchor": anchor["checks"][0]["details"], "wounds": wounds["checks"][0]["details"]},
        "continuationCounts": {"retainedMatureSnapshotInvocations": 144, "retainedMatureOriginalRestores": 143, "retainedPaidRecoveryPrefixSubmissions": len(anchor["checks"][0]["details"]["reusedRecovery"]["actualSuccessfulPrefix"]), "resumedAnchorGroup": {"originalRestores": 1, "inProcessSubmissions": len(anchor["steps"]), "parent": anchor["parent"]}, "woundsGroup": {"originalRestores": 1, "inProcessSubmissions": len(wounds["steps"]), "parent": wounds["parent"]}, "countingRule": "These are different units and branches; no summed stage count or obsolete 149-stage target is asserted."},
        "timing": {"anchorBatchSeconds": executions[0]["totalElapsedSeconds"], "woundsTailSeconds": executions[1]["totalElapsedSeconds"], "woundsFixedBudgetSeconds": executions[1]["fixedBatchBudgetSeconds"], "woundsEstimate": executions[1]["woundsEstimate"], "originalBudgetUnchanged": executions[1]["originalBudgetsUnchanged"], "separateAuthorizedWoundsTail": True},
        "gates": {"godotParse": executions[0]["runs"][0], "nativeStartup": executions[1]["runs"][-1], "terminalCore": terminal, "newMaterialReception": reception, "fullProofEquivalence": index, "validationPurityAndRejection": validation, "runtimeInputDrift": [], "typescriptNpmLint": "Not applicable to the approved Godot/GDScript project, which has no package.json, TypeScript or npm/lint configuration. Native Godot parsing, Python AST, whitespace review and directly relevant actual runtime/startup checks are recorded."},
        "failureAccounting": {"priorMature": mature["failureAccounting"], "priorReaderImplementation": "tools/source-closure/runs/repair-01-escalation.json", "priorContinuationImplementation": "tools/source-closure/runs/finish-03/escalation.json", "currentUnexpectedFailures": 1, "currentFailure": "tools/source-closure/runs/finish-04/failure.json", "currentFinalAttemptsPassed": True, "retainedFailuresNotRewritten": True, "controlledBudgetStopsAreNotBusinessFailures": ["formal-01", "finish-01"]},
        "controlledPrerequisites": mature["controlledPrerequisites"],
        "limitations": ["Original complete Catalog, production, resistance, deadlines, original payments and capacities remain enabled; source setup and final-check RNG are explicitly controlled.", "The old 144-stage mature trajectory and sixteen active-anchor routes are reused unchanged. No campaign rebuild, natural rate/balance, human experience, visual/audio or release acceptance is claimed.", "Original material component saves/retries and Turn snapshots do not prove complete mature Session saving.", "The current report supplies new evidence bindings without rewriting old actual/current reports. Independent current review and task status registration are separate."]
    }
    (ROOT / TARGET).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": "pass", "report": TARGET, "checks": len(checks), "sourceHashes": len(source_hashes), "sha256": sha(TARGET)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
