"""Bind already executed finite evidence after source documents are frozen."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main():
    trace = json.loads((ROOT / "docs/implementation/traceability.json").read_text(encoding="utf-8"))
    scenario = next(s for s in trace["scenarios"] if s["id"] == "ACC-CULT-SAVE-COMPAT")
    task = next(t for t in trace["tasks"] if t["id"] == "TASK-CULT-SAVE-COMPAT")
    folder = ROOT / "tools/cult-save-compat/runs/formal-02"
    core = json.loads((folder / "core.json").read_text(encoding="utf-8"))
    execution = json.loads((folder / "execution.json").read_text(encoding="utf-8"))
    assert core["status"] == execution["status"] == "pass"
    rows = {r["id"]: r for r in core["checks"]}
    assert len(rows) == 5 and all(r["status"] == "pass" for r in rows.values())
    runtime = json.loads((folder / "input-sha256.json").read_text(encoding="utf-8"))
    assert all(digest(p) == h for p, h in runtime.items())
    output = "docs/qa/cult-save-compat-results.json"
    excluded = {output, "docs/implementation/traceability.json", "docs/implementation/residuals.json"}
    paths = set(runtime) | set(scenario["sources"]) | set(task["sources"]) | {"docs/architecture.md", "docs/qa/cult-save-compat.md", "tools/cult-save-compat/README.md", "tools/cult-save-compat/bind-results.py"}
    paths = {p for p in paths if p not in excluded and not p.startswith("docs/game-state/") and "current-review-results.json" not in p}
    assert all((ROOT / p).is_file() for p in paths)
    ids = ["CSC-CURRENT-SAVE", "CSC-REJECT-PROTECTION", "CSC-DECISION-STATE", "CSC-PREREQUISITES"]
    mapping = [["CSC-CURRENT", "CSC-CONTINUE"], ["CSC-OLD", "CSC-BROKEN", "CSC-CACHED-RESULT"], ["CSC-CURRENT"], []]
    checks = [{"id": key, "acceptance": scenario["id"], "assertionIndex": i, "assertion": scenario["then"][i], "status": "pass", "actualChecks": mapping[i]} for i, key in enumerate(ids)]
    saved = rows["CSC-CURRENT"]
    backup = Path(saved["loaded"]["path"] + ".bak")
    assert hashlib.sha256(backup.read_bytes()).hexdigest() == saved["savedSha256"]
    artifacts = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT / "tools/cult-save-compat/runs").rglob("*") if p.is_file()}
    prior = ["docs/qa/source-closure-results.json", "docs/qa/cult-spread-results.json"]
    result = {"task": task["id"], "acceptance": scenario["id"], "status": "pass", "boundAt": datetime.now(timezone.utc).isoformat(), "checks": checks, "execution": "tools/cult-save-compat/runs/formal-02/execution.json", "actualChecks": core["checks"], "runtimeInputHashes": runtime, "postRunContractHashes": {p: digest(p) for p in sorted(paths - set(runtime))}, "sourceHashes": {p: digest(p) for p in sorted(paths)}, "artifactHashes": artifacts, "priorEvidenceHashes": {p: digest(p) for p in prior}, "originalSavedEnvelope": {"path": backup.relative_to(ROOT).as_posix(), "sha256": saved["savedSha256"]}, "scope": "One genuine full Session save/restore/durable replay/next window; three checksum-correct rejection copies; prior startup and production chain evidence reused, not re-executed.", "failureHistory": {"unexpectedFailures": 1, "attempt": "formal-01", "cause": "Added signature association used input instead of original receipt payload, falsely rejecting legal restore", "preserved": "tools/cult-save-compat/runs/formal-01/execution.json"}, "limitations": ["Actual ready/served/waiting opportunity states retained; positive numeric waiting debt is zero in this Session example.", "Material is one actual dream miracle known by its original person; no full mature nine-anchor Session claim.", "Cached authoritative base and known signature correspondence validated; historical display facts/changes and redundant UI selection authentication are not claimed.", "No historical migration, power-loss guarantee, exhaustive re-signing audit, natural frequency, balance or human experience proof."]}
    (ROOT / output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(output, digest(output))


if __name__ == "__main__":
    main()
