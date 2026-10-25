"""Repository-local implementation traceability, impact analysis and evidence checks.

Design lives in specs/CSV. This module indexes claims and checks evidence; it never
promotes a task or edits a rule. Python 3.9+, standard library only.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

LEDGER = "docs/implementation/traceability.json"
GROUPS = ("requirements", "contracts", "tasks", "scenarios")
PREFIXES = {"requirements": "REQ-", "contracts": "SET-", "tasks": "TASK-", "scenarios": "ACC-"}
TASK_STATES = {"planned", "in-progress", "implemented", "verified"}
# Live design sources only: reports, historical drafts, task briefs and generated
# views have different lifecycle rules. Templates belong to the shared framework.
PLAN_PATTERNS = ("docs/vision.md", "docs/world.md", "docs/gdd-core.md", "docs/architecture.md",
                 "docs/specs/**/*.md", "docs/content/**/*.md", "docs/implementation/*.md")


def plan_source_paths(root: Path) -> set[str]:
    """Inventory live proposals independently of their optional ledger bindings."""
    root = Path(root).resolve()
    return {path.relative_to(root).as_posix() for pattern in PLAN_PATTERNS for path in root.glob(pattern)
            if path.is_file() and not path.name.startswith("_template")
            and path.relative_to(root).as_posix() != "docs/implementation/README.md"}


def project_file(root, relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError("来源必须是仓库内相对路径")
    root = Path(root).resolve()
    path = (root / relative).resolve()
    if not path.is_relative_to(root):
        raise ValueError("来源越出仓库")
    return path


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(root, path):
    return json.loads(project_file(root, path).read_text(encoding="utf-8"))


def _status(statuses):
    if "failed" in statuses:
        return "failed"
    if "stale" in statuses:
        return "stale"
    if statuses and all(value == "passed" for value in statuses):
        return "passed"
    return "partial" if "passed" in statuses else "unverified"


def _cycle(nodes, field):
    done, stack = set(), []
    def visit(key):
        if key in stack:
            return stack[stack.index(key):] + [key]
        if key in done or key not in nodes:
            return []
        stack.append(key)
        for dependency in nodes[key].get(field, []):
            cycle = visit(dependency)
            if cycle:
                return cycle
        stack.pop()
        done.add(key)
        return []
    for key in nodes:
        cycle = visit(key)
        if cycle:
            return cycle
    return []


def _check_plan_bindings(root, data, indexes, errors):
    """Check revision acknowledgement and actual REQ/TASK/ACC connections.

    A matching digest only identifies the reviewed revision; it cannot establish
    semantic completeness. Never repair it automatically when loading the ledger.
    """
    inventory = plan_source_paths(root)
    bindings = data.get("planBindings", [])
    if not isinstance(bindings, list):
        errors.append("planBindings 必须为列表")
        bindings = []
    data["planBindings"] = []
    registered = set()
    for number, row in enumerate(bindings):
        label = f"planBindings[{number}]"
        if not isinstance(row, dict):
            errors.append(f"{label} 必须为方案绑定对象")
            continue
        data["planBindings"].append(row)
        source = row.get("source")
        try:
            path = project_file(root, source)
            if path.relative_to(root).as_posix() != source:
                raise ValueError("方案来源必须使用规范仓库相对路径")
        except ValueError as exc:
            errors.append(f"{label} {exc}")
            continue
        label = f"方案 {source}"
        if source in registered:
            errors.append(f"{label} 重复绑定")
        registered.add(source)
        if not path.is_file():
            errors.append(f"{label} 来源不存在")
        elif source not in inventory:
            errors.append(f"{label} 不在正式方案扫描范围")
        recorded = row.get("sourceHash")
        valid_hash = isinstance(recorded, str) and len(recorded) == 64 and all(c in "0123456789abcdef" for c in recorded)
        if not valid_hash:
            errors.append(f"{label}.sourceHash 必须为 SHA-256 小写十六进制值")
        elif path.is_file():
            try:
                if digest(path) != recorded:
                    errors.append(f"{label} 已变更，尚未同步开发计划（sourceHash 不匹配）")
            except OSError as exc:
                errors.append(f"{label} 无法读取：{exc}")
        if not isinstance(row.get("reviewNote"), str) or not row["reviewNote"].strip():
            errors.append(f"{label} 缺少计划同步说明 reviewNote")
        for field in ("requirements", "tasks"):
            values = row.get(field)
            if not isinstance(values, list) or not values or any(not isinstance(value, str) or not value.strip() for value in values):
                errors.append(f"{label}.{field} 必须为非空编号列表")
                row[field] = []
            elif len(values) != len(set(values)):
                errors.append(f"{label}.{field} 存在重复编号")
            for key in row[field]:
                target = indexes[field].get(key)
                if target is None:
                    errors.append(f"{label} 的 {field} 引用不存在：{key}")
                elif source not in target.get("sources", []):
                    errors.append(f"{label} 未进入 {key} 的来源")
        requirements = [indexes["requirements"][key] for key in row["requirements"] if key in indexes["requirements"]]
        tasks = [indexes["tasks"][key] for key in row["tasks"] if key in indexes["tasks"]]

        def connected(requirement, task):
            return task["id"] in requirement.get("tasks", []) and bool(
                set(requirement.get("acceptance", [])) & set(task.get("acceptance", [])) & indexes["scenarios"].keys())

        for task in tasks:
            if not any(connected(requirement, task) for requirement in requirements):
                errors.append(f"{label} 的 {task['id']} 未与绑定要求共享真实验收")
        for requirement in requirements:
            if not any(connected(requirement, task) for task in tasks):
                errors.append(f"{label} 的 {requirement['id']} 未连接绑定任务及真实验收")
    for source in sorted(inventory - registered):
        errors.append(f"方案未编入开发计划：{source}")
    return len(inventory)


def load_tracking(root):
    """Return a presentation model; missing/invalid evidence cannot become PASS."""
    root = Path(root).resolve()
    errors, warnings = [], []
    try:
        data = _json(root, LEDGER)
    except (OSError, ValueError) as exc:
        return {"schemaVersion": 1, **{key: [] for key in GROUPS}, "summary": {},
                "reports": [], "errors": [f"追踪源不可读：{exc}"], "warnings": []}
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        return {"schemaVersion": 1, **{key: [] for key in GROUPS}, "summary": {},
                "reports": [], "errors": ["不支持的追踪 schema"], "warnings": []}
    data = copy.deepcopy(data)
    bindings = data.get("planBindings", [])
    bound_task_ids = {key for binding in bindings if isinstance(binding, dict)
                      for key in (binding.get("tasks") if isinstance(binding.get("tasks"), list) else [])
                      if isinstance(key, str)} if isinstance(bindings, list) else set()
    indexes = {}
    for group in GROUPS:
        rows = data.get(group, [])
        if not isinstance(rows, list):
            errors.append(f"{group} 必须为列表")
            rows = []
        indexes[group] = {}
        data[group] = []
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get("id"), str):
                errors.append(f"{group} 存在非法条目")
                continue
            key = row["id"]
            if not key.startswith(PREFIXES[group]) or key in indexes[group]:
                errors.append(f"非法或重复编号：{key}")
            indexes[group][key] = row
            data[group].append(row)
            if group == "tasks" and key in bound_task_ids:
                # Validate scheduling fields before list normalization: a missing
                # dependency declaration must not be mistaken for an explicit [].
                if not isinstance(row.get("owner"), str) or not row["owner"].strip():
                    errors.append(f"{key}.owner 必须为非空负责人（方案绑定任务）")
                if type(row.get("stage")) is not int or row["stage"] < 0:
                    errors.append(f"{key}.stage 必须为非负整数（方案绑定任务）")
                dependencies = row.get("dependsOn")
                if "dependsOn" not in row or not isinstance(dependencies, list) or any(
                        not isinstance(item, str) or not item.strip() for item in dependencies):
                    errors.append(f"{key}.dependsOn 必须显式声明合法编号列表；首任务允许空列表（方案绑定任务）")
            for field in ("sources", "features", "relations", "decisions", "tasks", "contracts", "acceptance", "dependsOn", "reads", "writes", "preconditions", "resolution", "invariants", "deliverables", "risks", "outOfScope", "then"):
                if field not in row:
                    continue
                value = row[field]
                if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
                    errors.append(f"{key}.{field} 必须为非空字符串的列表")
                    row[field] = []
            if "evidence" in row:
                value = row["evidence"]
                if not isinstance(value, list) or any(not isinstance(item, dict) or not isinstance(item.get("report"), str) or not isinstance(item.get("check"), str) for item in value):
                    errors.append(f"{key}.evidence 必须为报告路径与检查编号对象列表")
                    row["evidence"] = []
            if not row.get("title") or not row.get("sources"):
                errors.append(f"{key} 缺少标题或权威来源")
            for source in row.get("sources", []):
                try:
                    if not project_file(root, source).is_file():
                        errors.append(f"{key} 来源不存在：{source}")
                except ValueError as exc:
                    errors.append(f"{key} {exc}")
    # Stable feature, relation and author-decision references are real, not free text.
    try:
        atlas = _json(root, "docs/game-state/atlas.json")
        features_data = _json(root, "docs/game-state/features/core.json")
        features = features_data if isinstance(features_data, list) else features_data.get("features", [])
        feature_ids = {row["id"] for row in features}
        relation_data = _json(root, "docs/game-state/relationships.json")
        relations = relation_data if isinstance(relation_data, list) else relation_data.get("relationships", [])
        relation_ids = {row["id"] for row in relations}
        decisions = {row["id"] for row in atlas.get("constraints", [])}
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"全貌索引不可读：{exc}")
        features, feature_ids, relation_ids, decisions = [], set(), set(), set()
    for group in GROUPS:
        for row in data[group]:
            for field, allowed in (("features", feature_ids), ("relations", relation_ids), ("decisions", decisions)):
                for target in row.get(field, []):
                    if target not in allowed:
                        errors.append(f"{row['id']} 的 {field} 引用不存在：{target}")
            for field, target_group in (("tasks", "tasks"), ("contracts", "contracts"), ("acceptance", "scenarios"), ("dependsOn", "tasks")):
                for target in row.get(field, []):
                    if target not in indexes[target_group]:
                        errors.append(f"{row['id']} 的 {field} 引用不存在：{target}")
    for requirement in data["requirements"]:
        if not requirement.get("rule") or not requirement.get("features") or not requirement.get("acceptance"):
            errors.append(f"{requirement['id']} 缺少规则摘要、能力或可观察验收")
        if not requirement.get("tasks"):
            warnings.append(f"未分配开发任务：{requirement['id']}")
            if requirement.get("criticality") == "critical":
                errors.append(f"关键行为没有开发责任：{requirement['id']}")
    for feature in features:
        if not any(feature["id"] in row.get("features", []) for row in data["requirements"]):
            errors.append(f"能力没有关键行为登记：{feature['id']}")
    for task in data["tasks"]:
        if task.get("status") not in TASK_STATES:
            errors.append(f"{task['id']} 非法任务状态")
        if not task.get("acceptance") or not task.get("scope") or not task.get("deliverables"):
            errors.append(f"{task['id']} 缺少范围、交付物或验收")
        if not any(task["id"] in row.get("tasks", []) for row in data["requirements"]):
            errors.append(f"{task['id']} 没有需求归属")
    plan_sources_count = _check_plan_bindings(root, data, indexes, errors)
    cycle = _cycle(indexes["tasks"], "dependsOn")
    if cycle:
        errors.append("开发依赖成环：" + " → ".join(cycle))
    writers = {}
    for contract in data["contracts"]:
        for field in ("owner", "phase", "reads", "writes", "resolution", "invariants", "acceptance"):
            if not contract.get(field):
                errors.append(f"{contract['id']} 结算约定缺少 {field}")
        for fact in contract.get("writes", []):
            if fact in writers:
                errors.append(f"共享事实有多个写入归属：{fact} ({writers[fact]}, {contract['id']})")
            writers[fact] = contract["id"]
    used_scenarios = {key for group in ("requirements", "tasks", "contracts") for row in data[group] for key in row.get("acceptance", [])}
    report_cache, reports = {}, []
    def report_state(path):
        if path in report_cache:
            return report_cache[path]
        result = {"data": None, "changed": [], "valid": False, "error": ""}
        try:
            report = _json(root, path)
            if not isinstance(report, dict) or not isinstance(report.get("checks"), list) or not isinstance(report.get("sourceHashes"), dict) or not report["sourceHashes"]:
                raise ValueError("报告缺少 checks 或非空 sourceHashes")
            check_ids = [item.get("id") for item in report["checks"]]
            if any(not isinstance(key, str) for key in check_ids) or len(check_ids) != len(set(check_ids)):
                raise ValueError("报告检查编号缺失或重复")
            for source, recorded in report["sourceHashes"].items():
                source_path = project_file(root, source)
                if not source_path.is_file() or digest(source_path) != recorded:
                    result["changed"].append(source)
            result["data"], result["valid"] = report, True
            reports.append({"path": path, "title": report.get("suite", path), "generatedAt": report.get("generatedAt", ""),
                            "metrics": report.get("metrics", {}), "scope": report.get("scope", []),
                            "limitations": report.get("limitations", []), "current": not result["changed"],
                            "changed": result["changed"]})
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            result["error"] = str(exc)
        report_cache[path] = result
        return result
    for scenario in data["scenarios"]:
        key = scenario["id"]
        if not scenario.get("given") or not scenario.get("when") or not scenario.get("then"):
            errors.append(f"{key} 缺少可观察的给定/操作/结果")
        if key not in used_scenarios:
            errors.append(f"{key} 没有需求、任务或约定消费")
        claims = []
        for reference in scenario.get("evidence", []):
            path, check_id = reference.get("report", ""), reference.get("check", "")
            observed = report_state(path)
            claim = {"report": path, "check": check_id, "status": "unverified", "changed": observed["changed"], "generatedAt": "", "reason": observed["error"]}
            report = observed["data"]
            if observed["valid"]:
                claim["generatedAt"] = report.get("generatedAt", "")
                check = next((item for item in report["checks"] if item["id"] == check_id), None)
                missing_sources = [source for source in scenario.get("sources", []) if source not in report["sourceHashes"]]
                if not check:
                    claim["reason"] = "报告不存在此检查编号"
                elif missing_sources:
                    claim["reason"] = "报告未绑定场景来源：" + "、".join(missing_sources)
                elif observed["changed"]:
                    claim["status"], claim["reason"] = "stale", "证据所绑定的规则、数据或实现已变化"
                elif check.get("status") in ("fail", "failed"):
                    claim["status"] = "failed"
                elif check.get("status") in ("pass", "passed"):
                    claim["status"] = "passed"
                else:
                    claim["reason"] = "检查没有明确通过或失败结果"
            claims.append(claim)
        status = _status([claim["status"] for claim in claims])
        if status == "partial":
            status = "unverified"  # All declared evidence parts are required.
        scenario["verification"] = {"status": status, "evidence": claims}
    # A verified declaration must have current passing evidence and real delivery files.
    for task in data["tasks"]:
        checks = [indexes["scenarios"][key]["verification"]["status"] for key in task.get("acceptance", []) if key in indexes["scenarios"]]
        task["verification"] = _status(checks)
        if task.get("status") in ("implemented", "verified"):
            for path in task.get("deliverables", []):
                try:
                    if not project_file(root, path).exists():
                        errors.append(f"{task['id']} 声称接入但交付物不存在：{path}")
                except ValueError as exc:
                    errors.append(f"{task['id']} {exc}")
        if task.get("status") == "verified" and task["verification"] != "passed":
            errors.append(f"{task['id']} 声称验收通过但证据为 {task['verification']}")
    def blockers(key, visiting=None):
        visiting = set() if visiting is None else visiting
        if key in visiting:
            return {key}
        visiting = visiting | {key}
        blocked = set()
        for dependency in indexes["tasks"].get(key, {}).get("dependsOn", []):
            previous = indexes["tasks"].get(dependency)
            if not previous or previous.get("status") != "verified" or previous.get("verification") != "passed":
                blocked.add(dependency)
            nested = blockers(dependency, visiting)
            if nested:
                blocked.add(dependency)
                blocked.update(nested)
        return blocked
    for task in data["tasks"]:
        blocked = sorted(blockers(task["id"]))
        task["readiness"] = {"ready": not blocked, "blockedBy": blocked}
        if task.get("status") == "verified" and blocked:
            errors.append(f"{task['id']} 前置任务未验收：{', '.join(blocked)}")
    for row in data["requirements"]:
        tasks = [indexes["tasks"][key] for key in row.get("tasks", []) if key in indexes["tasks"]]
        states = [indexes["scenarios"][key]["verification"]["status"] for key in row.get("acceptance", []) if key in indexes["scenarios"]]
        missing = []
        if not tasks:
            missing.append("未分配开发任务")
        if not tasks or any(task.get("status") not in ("implemented", "verified") for task in tasks):
            missing.append("开发尚未全部接入")
        for key in row.get("acceptance", []):
            scenario = indexes["scenarios"].get(key)
            if scenario and scenario["verification"]["status"] != "passed":
                missing.append(f"{key}：{scenario['verification']['status']}")
        row["coverage"] = {"assigned": bool(tasks), "implemented": bool(tasks) and all(task.get("status") in ("implemented", "verified") for task in tasks), "verification": _status(states), "missing": missing}
    data["summary"] = {**{key: len(data[key]) for key in GROUPS},
                       "planSources": plan_sources_count, "planBindings": len(data["planBindings"]),
                       "unassigned": sum(not row["coverage"]["assigned"] for row in data["requirements"]),
                       "unverified": sum(row["verification"]["status"] == "unverified" for row in data["scenarios"]),
                       "stale": sum(row["verification"]["status"] == "stale" for row in data["scenarios"]),
                       "failed": sum(row["verification"]["status"] == "failed" for row in data["scenarios"]),
                       "verified": sum(row["verification"]["status"] == "passed" for row in data["scenarios"])}
    data["errors"], data["warnings"], data["reports"] = errors, warnings, reports
    return data


def impact(data, target):
    """Build a bounded task context, including reverse dependencies and rule owners."""
    selected = {group: set() for group in GROUPS}
    features = set()
    for group in GROUPS:
        for row in data[group]:
            if target == row["id"] or target in row.get("features", []) or target in row.get("sources", []) or target in row.get("relations", []) or target in row.get("decisions", []) or target in row.get("deliverables", []):
                selected[group].add(row["id"])
                features.update(row.get("features", []))
    # Requirements directly touching selected tasks/contracts/scenarios belong in the brief.
    for row in data["requirements"]:
        if selected["tasks"].intersection(row.get("tasks", [])) or selected["contracts"].intersection(row.get("contracts", [])) or selected["scenarios"].intersection(row.get("acceptance", [])):
            selected["requirements"].add(row["id"])
    for row in data["requirements"]:
        if row["id"] in selected["requirements"]:
            selected["tasks"].update(row.get("tasks", []))
            selected["contracts"].update(row.get("contracts", []))
            selected["scenarios"].update(row.get("acceptance", []))
    # Shared requirements add useful related work, but do not turn co-owners
    # into prerequisites or broaden an explicit task's dependency direction.
    target_tasks = {row["id"] for row in data["tasks"] if row["id"] == target}
    direct_tasks = target_tasks or set(selected["tasks"])
    downstream = set()
    changed = True
    while changed:
        before = len(downstream)
        for row in data["tasks"]:
            if set(row.get("dependsOn", [])).intersection(direct_tasks | downstream):
                downstream.add(row["id"])
        changed = before != len(downstream)
    selected["tasks"].update(downstream)
    prerequisites = set()
    frontier = list(direct_tasks)
    tasks = {row["id"]: row for row in data["tasks"]}
    while frontier:
        key = frontier.pop()
        for dependency in tasks.get(key, {}).get("dependsOn", []):
            if dependency not in prerequisites:
                prerequisites.add(dependency)
                frontier.append(dependency)
    prerequisites.difference_update(direct_tasks)
    selected["tasks"].update(prerequisites)
    # Prerequisites are not just IDs: their rules and contracts are necessary
    # context to implement a dependent task without inventing a second contract.
    for row in data["requirements"]:
        if prerequisites.intersection(row.get("tasks", [])):
            selected["requirements"].add(row["id"])
            selected["contracts"].update(row.get("contracts", []))
            selected["scenarios"].update(row.get("acceptance", []))
    for row in data["tasks"] + data["contracts"]:
        if row["id"] in selected["tasks"] | selected["contracts"]:
            selected["scenarios"].update(row.get("acceptance", []))
    rows = {group: [row for row in data[group] if row["id"] in selected[group]] for group in GROUPS}
    sources = sorted({source for group in GROUPS for row in rows[group] for source in row.get("sources", [])})
    relations = sorted({key for row in rows["requirements"] for key in row.get("relations", [])})
    return {"target": target, "found": any(selected.values()), "features": sorted(features), "relations": relations,
            "sources": sources, "prerequisites": sorted(prerequisites), "downstreamTasks": sorted(downstream - direct_tasks), **rows}
