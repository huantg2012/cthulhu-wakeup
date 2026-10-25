#!/usr/bin/env python3
"""Run the production Godot economy suite and bind its evidence to current sources."""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/qa/economy-results.json"


def source_paths() -> list[Path]:
    # Include transitive production dependencies. A World change must invalidate
    # this result even when the top-level economy file itself did not change.
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", Path(__file__).resolve(),
                   *ROOT.glob("src/**/*.gd"), *ROOT.glob("tools/economy/*.gd"),
                   *ROOT.glob("docs/specs/system-*.md"), *ROOT.glob("data/*.csv")})


def hashes() -> dict[str, str]:
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in source_paths()}


def validate_report(report: dict) -> None:
    if report.get("schemaVersion") != 1 or report.get("suite") != "economy":
        raise ValueError("Unexpected economy report schema or suite")
    checks = report.get("checks")
    if report.get("status") != "pass" or not isinstance(checks, list) or not checks:
        raise ValueError("No passing economy checks")
    ids: set[str] = set()
    for check in checks:
        check_id = check.get("id", "")
        if not isinstance(check_id, str) or not check_id.startswith("ECON-") or check_id in ids:
            raise ValueError("Invalid or duplicate economy check ID")
        if check.get("status") != "pass" or not check.get("name") or not isinstance(check.get("details"), dict):
            raise ValueError(f"Failed or malformed check: {check_id}")
        ids.add(check_id)
    measured = report["metrics"]
    if measured["turns"] != 50 or measured["domains"] != 12 or measured["named_people"] != 72:
        raise ValueError("Expected a measured 50-turn session with 12 domains and 72 named people")
    if not measured["driver"] or not measured["history"]:
        raise ValueError("Missing load driver or history windows")
    if [window["turn"] for window in measured["history"]] != [10, 20, 30, 40, 50]:
        raise ValueError("Expected all five actual 10-turn history windows")
    for key in ("income_in_10_turns", "paid_in_10_turns", "recruited_in_10_turns", "attrition_in_10_turns"):
        for window in measured["history"]:
            value = window[key]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise ValueError(f"Invalid economic activity window: {key}")
    if measured["npc_updates"] != measured["turns"] * measured["named_people"]:
        raise ValueError("Incomplete actual NPC update count")
    for key in ("npc_actions", "plans_resolved", "save_bytes", "save_ms"):
        value = measured[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            raise ValueError(f"Invalid load measurement: {key}")
    if set(measured["stage_ms"]) != {"1", "2", "3", "4", "5", "6"}:
        raise ValueError("All six stage measurements are required")
    for timing in [measured["complete_turn_ms"], *measured["stage_ms"].values()]:
        values = [timing[key] for key in ("p50", "p95", "max")]
        if any(isinstance(value, bool) or not isinstance(value, (int, float)) or
               not math.isfinite(value) or value < 0 for value in values) or values != sorted(values):
            raise ValueError("Invalid measured timing distribution")
    if not isinstance(report.get("scope"), list) or not isinstance(report.get("limitations"), list):
        raise ValueError("Missing declared scope or limitations")


def write_readable_report(report: dict) -> None:
    measured = report["metrics"]
    timing = measured["complete_turn_ms"]
    date = datetime.fromisoformat(report["generatedAt"].replace("Z", "+00:00")).astimezone(
        timezone(timedelta(hours=8))).date()
    lines = [
        "**本次执行范围：全详细参考基线。** 当前 src 尚未接入 F/N/P、后台低频模拟与分段档案；本次实际重跑只验证既有共同规则和参考模式，不为新分层条款提供运行时证据。", "",
        "# 正式经济与完整回合实测", "",
        f"日期：{date}（Asia/Shanghai）。实际 Godot 执行，{len(report['checks'])} 项检查通过；"
        f"来源指纹绑定 {len(report['sourceHashes'])} 个文件。", "",
        "正式经济已接入六阶段回合：既有教团的经营、供奉、招募和自然流失使用正式规则与人口记录。"
        "本报告验证结算行为，不据此宣布完整建团、所有锚点资格、长期平衡或玩家体验完成。", "",
        "## 复现与证据", "",
        "仓库根运行 `python3 tools/economy/verify.py`，可传 `--godot`。"
        "执行生产 `src/game/economy.gd`、统一回合与正式人物／文明核心；数值来自 Catalog 加载的正式 CSV。"
        "测试适配位于 `tools/economy/run.gd`，独立反例位于 `qa_cases.gd`。", "",
        "[机器报告](economy-results.json)保存稳定 ECON 检查编号、实际断言、执行环境、负载与来源 SHA-256。"
        "包装器拒绝旧报告、脚本错误、失败或重复检查、测量结构缺失和运行期间来源变化。"
        "绑定覆盖生产源码、测试、规则、架构与 CSV；更新指纹不能代替重新运行。", "",
        "原有 [29 项回合检查](turn-cycle.md)与 [32 项正式推演检查](formal-simulation.md)单独回归，"
        "其结果不重复计入本套的新检查数。", "",
        "## 实际范围", "",
    ]
    lines.extend(f"- {item.rstrip('。')}。" for item in report["scope"])
    lines += ["", "已有对象、合法成立事实、传播许可和机构条件是明确披露的上游前置。"
              "测试准备这些条件不等于已实现玩家建团、全部传播证明或锚点创建；"
              "实际费用、资格扣减、招募、流失、收入与人口变化由生产代码计算，不能由测试直接填写结果。", "",
              "## 检查结果", ""]
    lines.extend(f"- `{check['id']}`：{check['name']}。" for check in report["checks"])
    lines += ["", "## 完整回合成本", "", measured["driver"], "",
        f"实际运行 {measured['turns']} 轮，{measured['domains']} 域、{measured['named_people']} 名具名人物；"
        f"{measured['npc_updates']} 次人物更新、{measured['npc_actions']} 次自主行为、"
        f"{measured['plans_resolved']} 次抵抗结算。计时覆盖计划及六阶段提交的暂存、校验、"
        "正式经济与 NPC／文明演化，不是单独调用 evolve 的耗时。", "",
        f"完整一轮：p50 {timing['p50']:.3f} ms，p95 {timing['p95']:.3f} ms，最大 {timing['max']:.3f} ms。", ""]
    if measured.get("anchor_count") == 0:
        lines += ["这 50 轮没有既有锚点，覆盖教团经济与人物／文明活动；锚点付款、拒付与恢复时点"
                  "由独立规则场景验证。本项不能证明多锚点维护的长期成本。", ""]
    labels = {"1": "收入资格登记、轮初与事件", "2": "事件关闭", "3": "行动关闭与计划锁定",
              "4": "经营预付及共同演化", "5": "正式收入与期限", "6": "终局读取"}
    for phase in sorted(measured["stage_ms"]):
        value = measured["stage_ms"][phase]
        lines.append(f"- 阶段 {phase}（{labels[phase]}）：p50 {value['p50']:.3f} ms，"
                     f"p95 {value['p95']:.3f} ms，最大 {value['max']:.3f} ms。")
    lines.append("")
    for window in measured["history"]:
        lines.append(f"- 第 {window['turn']} 轮：历史事实 {window['facts']} 条，"
                     f"近 10 轮自主行为 {window['actions_in_10_turns']} 次，"
                     f"该轮完整耗时 {window['last_turn_ms']:.3f} ms。")
        lines.append(f"  近 10 轮实际收入 {window['income_in_10_turns']}，预付 {window['paid_in_10_turns']}，"
                     f"招募 {window['recruited_in_10_turns']} 人，自然流失 {window['attrition_in_10_turns']} 人。")
    for key, label in (("total_income", "累计实际收入"), ("total_paid", "累计实际预付"),
                       ("total_recruited", "累计实际招募"), ("total_attrition", "累计自然流失")):
        if key in measured:
            lines.append(f"- {label}：{measured[key]}。")
    lines += ["", f"最终会话保存 {measured['save_bytes']} 字节，序列化 {measured['save_ms']:.3f} ms。"
        "耗时只代表本机、该局势与这 50 轮。没有性能预算，不把测量完成视为流畅度通过；"
        "完整历史、增量事务中的历史索引根复制与保存成本仍须持续观察，不能由有限窗口推断长战役成本有界。", "",
        "## 限制", ""]
    lines.extend(f"- {item.rstrip('。')}。" for item in report["limitations"])
    lines += ["", "不新增短体验前置阶段。后续依任务关系继续接入教团生命周期、其他玩法与游戏界面；"
              "本轮机器检查不替代制作人的玩法与体验判断。", ""]
    (ROOT / "docs/qa/economy.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    old_time = REPORT.stat().st_mtime_ns if REPORT.exists() else -1
    before = hashes()
    try:
        process = subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--script",
                                  "res://tools/economy/run.gd"], capture_output=True, text=True,
                                 check=False, timeout=300)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: unable to complete Godot economy run: {error}", file=sys.stderr)
        return 1
    log = process.stdout + process.stderr
    (Path(__file__).resolve().parent / "run.log").write_text(log, encoding="utf-8")
    print(log, end="")
    if process.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log:
        return 1
    if not REPORT.exists() or REPORT.stat().st_mtime_ns == old_time:
        print("FAIL: Godot produced no fresh economy report", file=sys.stderr)
        return 1
    after = hashes()
    if before != after:
        print("FAIL: sources changed during execution; economy evidence is not bound", file=sys.stderr)
        return 1
    try:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        validate_report(report)
        report["sourceHashes"] = after
        report["executionProfile"] = {"mode": "all-detailed-reference", "hybridImplemented": False,
            "scope": "Existing common invariants and legacy detailed behavior only; TASK-FIDELITY-* runtime checks remain separate."}
        report["wrapperVerified"] = {"freshReport": True, "noGodotErrors": True,
                                     "sourcesUnchangedDuringRun": True, "uniqueCheckIds": True,
                                     "measuredLoadPresent": True}
        write_readable_report(report)
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        print(f"FAIL: invalid economy report: {error}", file=sys.stderr)
        return 1
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"VERIFIED {len(report['checks'])} economy checks; {len(after)} source hashes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
