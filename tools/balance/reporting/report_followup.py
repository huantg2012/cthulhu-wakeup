"""Keep the one strategy revision separate from the fixed 12-run distribution."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path

from report import ROOT, QA, ARCHIVES, sha, project_file, archived_bytes, validate_campaign_metadata, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iteration", type=int, choices=(2, 3), default=2)
    parser.add_argument("--archive-only", action="store_true")
    args = parser.parse_args()
    number = args.iteration
    folder = "followup" if number == 2 else "last_probe"
    stem = "balance-followup" if number == 2 else "balance-iteration3"
    durable = QA / (stem + "-baseline.json")
    incoming = ROOT / f"tools/balance/{folder}/results.json"
    source = incoming if incoming.is_file() and not args.archive_only else durable
    raw_bytes = source.read_bytes()
    result = json.loads(raw_bytes)
    if result.get("executionStatus") != "complete" or result.get("iteration") != number:
        raise ValueError("Diagnostic iteration did not complete")
    spec = importlib.util.spec_from_file_location("balance_followup_execution", ROOT / f"tools/balance/{folder}/verify.py")
    wrapper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(wrapper)
    if result["sourceHashes"] != wrapper.hashes():
        raise ValueError("Iteration two execution sources are incomplete or stale")
    if sha(project_file("docs/qa/balance-baseline.json").read_bytes()) != result["baseline"]["sha256"]:
        raise ValueError("Iteration two was not based on the archived first distribution")
    ARCHIVES.mkdir(exist_ok=True)
    sources = dict(result["sourceHashes"])
    artifacts, observations = {}, {}
    prefix = f"iteration{number}-19-expansion"
    required = {f"tools/balance/{folder}/runs/19-expansion/{name}" for name in ("result.json", "trace.jsonl", "process.log")}
    if not required <= set(result["artifactHashes"]):
        raise ValueError("Iteration two is missing execution artifacts")
    for relative, recorded in result["artifactHashes"].items():
        raw, artifact = archived_bytes(relative, recorded, prefix, args.archive_only)
        artifacts[relative] = artifact
        sources[artifact["path"]] = artifact["sha256"]
        observations[Path(relative).name] = raw
    original = json.loads(observations["result.json"])
    validate_campaign_metadata(result["campaign"], original)
    if (original["seed"], original["strategy"], original["limit"]) != (19, "expansion", 60):
        raise ValueError("Iteration two identity differs from its registered scope")
    lines = [json.loads(line) for line in observations["trace.jsonl"].decode("utf-8").splitlines()]
    rounds = [line for line in lines if line["type"] == "round"]
    turns = [line["after"]["turn"] for line in rounds]
    if turns != list(range(1, original["rounds"] + 1)) or (original["status"] == "censored" and len(rounds) != 60):
        raise ValueError("Iteration two has missing/repeated actual rounds")
    first_cult = next((line["after"]["turn"] for line in rounds if line["after"]["cults"]), -1)
    if first_cult != original["first_cult_turn"]:
        raise ValueError("Iteration two first cult is not in the actual trajectory")
    expected_artifacts = required | ({f"tools/balance/{folder}/runs/19-expansion/first-cult.json"} if first_cult >= 0 else set())
    if set(result["artifactHashes"]) != expected_artifacts:
        raise ValueError("Diagnostic artifact inventory contains unexpected entries")
    if result["checks"][:len(original["checks"])] != original["checks"]:
        raise ValueError("Iteration two dropped or changed a raw result check")
    if len(result["checks"]) != len(original["checks"]) + 2:
        raise ValueError("Unexpected iteration two check inventory")
    process, cult_check = result["checks"][-2:]
    errors = [line for line in observations["process.log"].decode("utf-8").splitlines()
              if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
    if process != {"id": f"BAL-ITERATION{number}-PROCESS-001", "status": "pass" if process["evidence"]["exit"] == 0 and not errors else "fail",
                   "evidence": {"exit": process["evidence"]["exit"], "errors": errors}}:
        raise ValueError("Iteration two process check differs from its log")
    if cult_check != {"id": f"BAL-ITERATION{number}-FIRST-CULT-001", "status": "pass" if first_cult >= 0 else "fail", "evidence": {"first_cult_turn": first_cult}}:
        raise ValueError("Iteration two cult check differs from actual rounds")
    if result["status"] != ("pass" if all(c["status"] == "pass" for c in result["checks"]) else "fail"):
        raise ValueError("Iteration two aggregate contradicts raw checks")
    sources[durable.relative_to(ROOT).as_posix()] = sha(raw_bytes)
    sources["docs/qa/balance-baseline.json"] = result["baseline"]["sha256"]
    if number == 3:
        previous = project_file("docs/qa/balance-followup-baseline.json")
        if sha(previous.read_bytes()) != result["previousIteration"]["sha256"]:
            raise ValueError("Final iteration is not bound to the actual second iteration")
        sources[previous.relative_to(ROOT).as_posix()] = result["previousIteration"]["sha256"]
    sources[Path(__file__).relative_to(ROOT).as_posix()] = sha(Path(__file__).read_bytes())
    sources[Path(__file__).with_name("report.py").relative_to(ROOT).as_posix()] = sha(Path(__file__).with_name("report.py").read_bytes())
    published = {"suite": f"BALANCE iteration {number} / first-cult diagnostic", "generatedAt": datetime.now(timezone.utc).isoformat(),
                 "status": result["status"], "executionStatus": "complete", "sourceHashes": sources,
                 "checks": result["checks"], "campaign": result["campaign"], "artifacts": artifacts,
                 "limitations": result["limitations"] + ["A diagnostic pass establishes only its listed checks, never full TASK-BALANCE acceptance.", "First iteration statistics remain unchanged; this is one deliberately revised strategy on one seed."]}
    if source.resolve() != durable.resolve():
        temporary = durable.with_suffix(".json.tmp")
        temporary.write_bytes(raw_bytes)
        temporary.replace(durable)
    write_json(QA / (stem + "-results.json"), published)
    print(json.dumps({"status": published["status"], "rounds": original["rounds"], "firstCultTurn": first_cult}))
    return 0 if published["status"] == "pass" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(f"Followup evidence not published: {error}")
