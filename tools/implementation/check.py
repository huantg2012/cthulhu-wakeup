#!/usr/bin/env python3
"""Check traceability or print the context needed for a feature/task/source change."""
import argparse
import json
from pathlib import Path
from tracking import impact, load_tracking

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--impact", help="REQ/TASK/SET/ACC/MECH/REL/DEC 编号或仓库相对路径")
    parser.add_argument("--task", help="任务开工/收尾检查：前置未通过返回 2")
    parser.add_argument("--strict", action="store_true", help="任何未验收场景或未分配任务也返回 2")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    data = load_tracking(args.root)
    if args.impact or args.task:
        result = impact(data, args.impact or args.task)
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            print(f"变更上下文：{result['target']}")
            for group in ("requirements", "contracts", "tasks", "scenarios"):
                print(f"\n{group}:")
                for row in result[group]:
                    print(f"- {row['id']} · {row['title']}")
            print("\n应读来源：\n" + "\n".join(result["sources"]))
            print("\n前置：" + ", ".join(result["prerequisites"]))
            print("下游需复核：" + ", ".join(result["downstreamTasks"]))
        if not result["found"]:
            return 1
    elif args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(data["summary"], ensure_ascii=False))
        for message in data["errors"]:
            print("ERROR: " + message)
        for message in data["warnings"]:
            print("WARNING: " + message)
        print("结构可追踪不等于游戏已实现；未验收项保留为明确缺口。")
    if data["errors"]:
        return 1
    if args.task:
        task = next((row for row in data["tasks"] if row["id"] == args.task), None)
        if not task or not task["readiness"]["ready"]:
            print("前置未验收，不能把本任务验收视作已完成。")
            return 2
    if args.strict and any(data["summary"].get(key, 0) for key in ("unassigned", "unverified", "stale", "failed")):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
