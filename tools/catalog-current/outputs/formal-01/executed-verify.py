"""Bounded current Catalog evidence; never writes historical or QA reports."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs() -> dict[str, str]:
    paths = [ROOT / "project.godot", ROOT / "docs/architecture.md",
             ROOT / "docs/specs/system-civilizations.md", ROOT / "docs/specs/system-powers-cults.md",
             ROOT / "tools/formal-simulation/run.gd",
             *HERE.glob("*.gd"), *HERE.glob("*.py"), *HERE.glob("*.json"),
             *ROOT.glob("src/**/*.gd"), *ROOT.glob("src/**/*.tscn"),
             *ROOT.glob("data/*.csv")]
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(set(paths))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    if not args.attempt or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789-" for c in args.attempt):
        parser.error("attempt must use lowercase letters, digits and hyphens")
    run = HERE / "outputs" / args.attempt
    run.mkdir(parents=True, exist_ok=False)
    hashes = inputs()
    (run / "input-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    runtime = {"seeds": [200, 201], "mutations": ["field", "reference", "value"],
               "bound": "remove cosmic civilization candidates; one generate(1)", "shared_budget_seconds": 60}
    (run / "runtime-input.json").write_text(json.dumps(runtime, indent=2) + "\n", encoding="utf-8")
    start = time.monotonic()
    stages = []
    error = None
    payload = run / "payload.json"
    commands = [
        ("parse", ["--headless", "--editor", "--quit"]),
        ("core", ["--headless", "--script", "res://tools/catalog-current/run.gd", "--", str(payload)]),
        ("startup", ["--headless", "--quit-after", "2"]),
    ]
    for name, tail in commands:
        command = [args.godot, "--path", str(ROOT), *tail]
        stage_start = time.monotonic()
        remaining = 60 - (stage_start - start)
        stdout, stderr, code = b"", b"", None
        try:
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, 0)
            process = subprocess.run(command, capture_output=True, timeout=remaining, check=False)
            stdout, stderr, code = process.stdout, process.stderr, process.returncode
        except subprocess.TimeoutExpired as exc:
            stdout, stderr = exc.stdout or b"", exc.stderr or b""
            error = f"{name}: shared 60-second deadline exceeded"
        (run / f"{name}.stdout.log").write_bytes(stdout)
        (run / f"{name}.stderr.log").write_bytes(stderr)
        stages.append({"stage": name, "command": command, "returncode": code,
                       "elapsed_seconds": time.monotonic() - stage_start})
        log = (stdout + stderr).decode("utf-8", errors="replace")
        if error is None and (code != 0 or "ERROR:" in log or "SCRIPT ERROR:" in log):
            error = f"{name}: nonzero exit or engine error"
        if name == "core" and error is None:
            if not payload.exists():
                error = "core: missing fresh payload"
            else:
                body = json.loads(payload.read_text(encoding="utf-8"))
                if not body.get("ok") or not body.get("checks") or any(c["status"] != "pass" for c in body["checks"]):
                    error = "core: failed or empty checks"
        if error:
            break
    after = inputs()
    if hashes != after:
        error = error or "execution inputs changed"
    artifacts = {p.relative_to(run).as_posix(): digest(p) for p in sorted(run.rglob("*")) if p.is_file()}
    result = {"ok": error is None, "error": error, "generatedAt": datetime.now(timezone.utc).isoformat(),
              "elapsed_seconds": time.monotonic() - start, "shared_budget_seconds": 60,
              "stages": stages, "sourceHashes": hashes, "sourcesUnchangedDuringRun": hashes == after,
              "afterHashes": after, "artifactHashes": artifacts}
    (run / "execution.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": result["ok"], "error": error, "seconds": result["elapsed_seconds"], "run": str(run)}))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
