"""Run real Session + rendered Godot GUI checks, then bind a current parent run."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("endings_wrapper", ROOT / "tools/endings/verify.py")
endings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(endings)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hashes():
    result = endings.hashes()
    for pattern in ["src/presentation/*", "tools/ui/*.gd", "tools/ui/*.py", "tools/ui/*.md", "tools/ui/development/*.gd"]:
        for path in ROOT.glob(pattern):
            if path.is_file():
                result[path.relative_to(ROOT).as_posix()] = sha(path)
    for name in ["docs/specs/ui-interaction.md", "docs/tasks/slice-12.md"]:
        result[name] = sha(ROOT / name)
    return dict(sorted(result.items()))


def execute(command, log):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    output = result.stdout + result.stderr
    log.write_text(output, encoding="utf-8", newline="\n")
    print(output[-2500:], flush=True)
    if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
        raise RuntimeError(f"Godot check failed; see {log.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()
    before = hashes()
    with tempfile.TemporaryDirectory(prefix="ui-", dir=ROOT / ".godot") as temporary:
        scratch = Path(temporary)
        capture_directory = scratch / "screenshots"
        reports = []
        for script, headless in [("run.gd", True), ("input_cases.gd", False)]:
            target = scratch / (script + ".json")
            command = [args.godot]
            if headless:
                command.append("--headless")
            command += ["--path", str(ROOT), "--log-file", str(scratch / (script + ".log")), "--script", "res://tools/ui/" + script, "--", str(target)]
            if not headless:
                command.append(str(capture_directory))
            execute(command, ROOT / "tools/ui" / ("session.log" if headless else "input.log"))
            reports.append(json.loads(target.read_text(encoding="utf-8")))
        checks = [item for report in reports for item in report["checks"]]
        ids = {item["id"] for item in checks}
        expected = {"UI-SESSION-001", "UI-PURE-001", "UI-KNOWLEDGE-001", "UI-EVENT-001", "UI-TURN-001", "UI-PURE-002", "UI-PRAYER-001", "UI-SAVE-001", "UI-SAVE-002", "UI-SOURCE-001", "UI-TERMINAL-001", "UI-REST-001", "UI-ZERO-001", "UI-LAYOUT-001", "UI-THEME-001", *{f"UI-INPUT-{i:03d}" for i in range(1, 9)}}
        if ids != expected or len(ids) != len(checks) or any(item["status"] != "pass" for item in checks):
            raise RuntimeError("UI check identities or results differ from the registered checks")
        if before != hashes():
            raise RuntimeError("Sources changed during UI execution")
        if args.smoke:
            print(f"SMOKE {len(checks)} UI checks; no formal evidence written")
            return
        parent_path = ROOT / "docs/qa/endings-results.json"
        parent = json.loads(parent_path.read_text(encoding="utf-8"))
        if parent["status"] != "pass" or any(item["status"] != "pass" for item in parent["checks"]):
            raise RuntimeError("No passing endings parent report")
        if parent["sourceHashes"] != endings.hashes():
            raise RuntimeError("Parent source fingerprints are stale; actually rerun tools/endings/verify.py")
        screens = {}
        destination = ROOT / "tools/ui/screenshots"
        destination.mkdir(exist_ok=True)
        for image in sorted(capture_directory.glob("*.png")):
            copied = destination / image.name
            shutil.copyfile(image, copied)
            screens[copied.relative_to(ROOT).as_posix()] = sha(copied)
        report = {"status":"pass", "generatedAt":datetime.now(timezone.utc).isoformat(), "kind":"automated-rendered-gui", "checks":checks, "sourceHashes":before,
                  "environment":{"engine":reports[0]["engine"], "sessionHeadless":True, "guiHeadless":False, "logicalResolution":[1280,720]},
                  "screenshots":screens, "regressions":{"report":"docs/qa/endings-results.json", "sha256":sha(parent_path), "endingsChecks":len(parent["checks"]), "independentParentChecks":sum(v for k,v in parent["regressions"].items() if k.endswith("Checks"))},
                  "limitations":["实际Godot GUI输入分派与渲染，未通过原生OS输入；不是作者试玩或审美认可。", "新局7919的零事件为合法边界；真实事件分支由独立旧链验证，不冒称该新局执行事件。", "敛息与零资源使用首回执前的明确资源初态；完整高阶权能/圣物由原正式系统回归覆盖，UI没有从新局建立全套中局。", "有限新局探针证明祭仪能实际转化信众，尚未找到首团完成路径；难度和策略可达率由TASK-BALANCE继续验证。", "ACC-UI与ACC-ACCESS保持人工待验；本报告仅为实现和回归证据。"],
                  "wrapperVerified":{"sourcesUnchangedDuringRun":True,"uniqueStableIds":True,"noGodotErrors":True,"parentFingerprintsCurrent":True}}
        (ROOT / "docs/qa/ui-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8", newline="\n")
        lines = ["# 基本界面自动回归", "", f"实际执行：{report['generatedAt']}；23项检查通过。", "", "报告来源与截图指纹见 [机器结果](ui-results.json)，静态范围见 [定向审阅](ui-review.md)，画面人工检查见 [实景检查](ui-inspection.md)。", ""]
        lines += [f"- `{item['id']}`：{item['status']}。" for item in checks]
        lines += ["", "关联旧终局及完整独立父链报告经当前指纹校验绑定，本包装器不改写旧报告。", ""] + ["- "+item for item in report["limitations"]]
        (ROOT / "docs/qa/ui.md").write_text("\n".join(lines)+"\n", encoding="utf-8", newline="\n")
        print(f"VERIFIED {len(checks)} UI checks and current independently executed endings chain")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
