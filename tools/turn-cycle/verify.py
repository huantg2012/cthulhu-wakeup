#!/usr/bin/env python3
"""Run the real Godot turn suite and bind reviewable evidence to source SHA-256."""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/qa/turn-cycle-results.json"


def source_paths() -> list[Path]:
    tables = ["npc_profiles", "civilization_profiles", "civilization_conditions", "civilization_parameters",
              "run_parameters", "npc_behaviors", "simulation_parameters", "civilization_actions",
              "resistance_plans", "event_parameters", "fidelity_parameters"]
    return sorted({ROOT / "project.godot", ROOT / "docs/architecture.md", Path(__file__).resolve(),
                   *ROOT.glob("src/game/*.gd"), *ROOT.glob("src/simulation/*.gd"),
                   *ROOT.glob("tools/turn-cycle/*.gd"), *ROOT.glob("docs/specs/system-*.md"),
                   *(ROOT / "data" / f"{name}.csv" for name in tables)})


def hashes() -> dict[str, str]:
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in source_paths()}


def write_readable_report(report: dict) -> None:
    measured = report["metrics"]
    timing = measured["complete_turn_ms"]
    date = datetime.fromisoformat(report["generatedAt"].replace("Z", "+00:00")).astimezone(
        timezone(timedelta(hours=8))).date()
    lines = [
        "**本次执行范围：全详细参考基线。** 本套件不启用 F/N/P 或后台低频模拟；混合入口另见 attention 与 abstract-sim 报告，分段档案另见 archive-save 报告；本次实际重跑只验证既有共同规则和参考模式，不为新分层条款提供运行时证据。", "",
        "# 完整六阶段回合编排实测", "",
        f"日期：{date}（Asia/Shanghai）。实际 Godot 运行，{len(report['checks'])} 组检查通过；"
        f"SHA-256 绑定 {len(report['sourceHashes'])} 份来源。", "",
        "统一回合协调器已经执行六阶段、真实 NPC／文明推演、事务回滚和阶段续存。"
        "这不是整款游戏完成：本套仍使用经济验证参与器，生产经济的独立证据另见 [正式经济实测](economy.md)；完整事件、权能、教团形成、锚点创建与完整资格、终局仍在后续任务。", "",
        "## 复现与证据", "",
        "运行 `python3 tools/turn-cycle/verify.py`（可传 `--godot`）。"
        "使用 `src/game/turn.gd`、正式 `src/simulation/` 与十份正式 CSV；"
        "测试参与器位于 `tools/turn-cycle/run.gd`，独立反例位于 `qa_cases.gd`。", "",
        "[机器报告](turn-cycle-results.json)保存稳定 TURN 编号、实际细节、执行环境和来源指纹。"
        "包装器拒绝旧报告、Godot 脚本错误、失败检查、重复编号和运行期间来源变更。"
        "[原有正式推演报告](formal-simulation.md)的 32 项检查单独运行并继续保留；"
        "本报告不把这些旧检查重新计入新检查数。", "",
        "## 实际接入与验证适配", "",
        "- 正式代码：唯一六阶段游标，轮初身份到期／抵抗／继任／预算刷新，"
        "玩家执行机会与祈求回应计数，阶段四正式 NPC 与文明共同快照演化，"
        "当前苏醒资格刷新，请求回执与全会话保存恢复。",
        "- 合约验证参与器：明确构造事件 strain 事实及其后续正式人物行为，"
        "玩家付费／检定、阶段四预付、阶段五指定教团收入及期限死亡，"
        "阶段六读取最新状态并声明结束。这些实际写入世界、保留父因，"
        "但不是正式完整事件池、十二权能、经营收入公式或最终仪式。",
        "- 必需参与能力缺失会拒绝开轮；明确注册的合法空集合可以推进。"
        "现阶段不能直接启动一套完整内容的玩家战役，不能用验证参与器代替未来内容验收。", "",
        "## 检查结果", "",
    ]
    for check in report["checks"]:
        lines.append(f"- `{check['id']}`：{check['name']}。")
    lines += ["", "## 完整回合成本：有限实测", "",
        measured["driver"], "",
        f"实际 {measured['turns']} 轮，{measured['npc_updates']} 次人物更新、"
        f"{measured['npc_actions']} 次自主行为、{measured['plans_resolved']} 次抵抗结算。"
        "下列耗时包含六次事务暂存与提交、参与者隔离检查、真实演化与最终候选校验，"
        "不是旧报告中单独 evolve 的耗时。没有性能预算，因此不能由本项通过推导流畅度达标。", "",
        f"完整一轮：p50 {timing['p50']:.3f} ms，p95 {timing['p95']:.3f} ms，"
        f"最大 {timing['max']:.3f} ms。", "",
    ]
    labels = {"1": "轮初及冻结事件", "2": "事件关闭", "3": "行动关闭与计划锁定",
              "4": "预付及正式演化", "5": "收入与期限", "6": "终局读取"}
    for phase, value in measured["stage_ms"].items():
        lines.append(f"- 阶段 {phase}（{labels[phase]}）：p50 {value['p50']:.3f} ms，"
                     f"p95 {value['p95']:.3f} ms，最大 {value['max']:.3f} ms。")
    lines.append("")
    for window in measured["history"]:
        lines.append(f"- 第 {window['turn']} 轮：历史事实 {window['facts']} 条，"
                     f"这 10 轮自主行为 {window['actions_in_10_turns']} 次，"
                     f"该轮完整耗时 {window['last_turn_ms']:.3f} ms。")
    lines += ["", f"最终会话保存 {measured['save_bytes']} 字节，"
        f"序列化 {measured['save_ms']:.3f} ms。完整历史、请求回执与全量序列化随轮数增长；"
        "历史索引与增长型根的增量路径已接入，分段保存证据另见archive-save专项，"
        "同时保留原子性、因果和恢复反例。50 轮测量不能证明长战役成本有界。", "",
        "## 限制", "",
    ]
    lines.extend(f"- {limitation}。" for limitation in report["limitations"])
    lines += ["- 参与器是受信任代码合同，不是恶意脚本安全沙箱；只读副本、"
              "效果声明、显式版本与原子提交约束规则集成。参与器的持久游戏状态必须放入可保存的 context，"
              "不能藏在实例私有字段。", "",
              "未新增短体验前置阶段。后续沿已登记依赖推进业务能力与游戏界面。", ""]
    (ROOT / "docs/qa/turn-cycle.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    old_time = REPORT.stat().st_mtime_ns if REPORT.exists() else -1
    before = hashes()
    process = subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--script",
                              "res://tools/turn-cycle/run.gd"], capture_output=True, text=True,
                             check=False, timeout=180)
    log = process.stdout + process.stderr
    (Path(__file__).resolve().parent / "run.log").write_text(log, encoding="utf-8")
    print(log, end="")
    if process.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log:
        return 1
    if not REPORT.exists() or REPORT.stat().st_mtime_ns == old_time:
        print("FAIL: Godot produced no fresh report", file=sys.stderr)
        return 1
    after = hashes()
    if before != after:
        print("FAIL: sources changed during execution; evidence is not bound", file=sys.stderr)
        return 1
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    checks = report.get("checks", [])
    if report.get("status") != "pass" or not checks or any(c.get("status") != "pass" for c in checks):
        return 1
    ids = [check["id"] for check in checks]
    if len(ids) != len(set(ids)) or not all(value.startswith("TURN-") for value in ids):
        print("FAIL: invalid or duplicate check IDs", file=sys.stderr)
        return 1
    report["sourceHashes"] = after
    report["executionProfile"] = {"mode": "all-detailed-reference", "hybridImplemented": False,
        "scope": "Existing common invariants and legacy detailed behavior only; TASK-FIDELITY-* runtime checks remain separate."}
    report["wrapperVerified"] = {"freshReport": True, "noGodotErrors": True,
                                 "sourcesUnchangedDuringRun": True, "uniqueCheckIds": True}
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_readable_report(report)
    print(f"VERIFIED {len(checks)} turn checks; {len(after)} source hashes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
