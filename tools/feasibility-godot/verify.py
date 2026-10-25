#!/usr/bin/env python3
"""Run the actual Godot suite and fail on script errors or a stale result file.

Godot may exit zero after a script parse error, so exit status alone is insufficient.
This wrapper has no third-party dependencies and never changes authored content.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent
    root = project.parent.parent
    report_path = root / "docs/qa/technical-feasibility-results.json"
    previous_mtime = report_path.stat().st_mtime_ns if report_path.exists() else -1
    completed = subprocess.run(
        [args.godot, "--headless", "--path", str(project), "--script", "run.gd"],
        capture_output=True, text=True, check=False,
    )
    log = completed.stdout + completed.stderr
    output_dir = project / "outputs"
    output_dir.mkdir(exist_ok=True)
    (output_dir / "run.log").write_text(log, encoding="utf-8")
    print(log, end="")
    if completed.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log:
        return 1
    if not report_path.exists() or report_path.stat().st_mtime_ns == previous_mtime:
        print("FAIL missing/freshness check for machine report", file=sys.stderr)
        return 1
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("status") != "PASS" or report.get("failed_checks") != 0:
        return 1
    sources = sorted(project.glob("*.gd")) + [project / "project.godot", Path(__file__).resolve()]
    sources += sorted((root / "data").glob("feasibility_*.csv"))
    report["source_sha256"] = {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sources
    }
    report["wrapper_verified_fresh_report_and_no_godot_errors"] = True
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"VERIFIED {report['total_checks']} checks, no stale report or Godot script errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
