"""Independent acceptance tests for the implementation traceability guard.

All mutations use temporary repositories; production decisions, ledger and
evidence are never rewritten by these cases.
"""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tracking import RESIDUALS, task_review_hash, LEDGER, impact, load_tracking, plan_source_paths

HERE = Path(__file__).resolve().parent


class TrackingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cthulhu-tracking-qa-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("docs/specs/system-a.md", "TL;DR: Test source rule.\n")
        self.write("src/a.gd", "# A real test deliverable.\n")
        self.write_json("docs/game-state/atlas.json", {"constraints": [{"id": "DEC-001"}]})
        self.write_json("docs/game-state/features/core.json", [{"id": "MECH-A"}])
        self.write_json("docs/game-state/relationships.json", [{"id": "REL-001"}])
        common = {"features": ["MECH-A"], "sources": ["docs/specs/system-a.md"]}
        self.ledger = {
            "schemaVersion": 1,
            "requirements": [{**common, "id": "REQ-A", "title": "Required behavior", "rule": "Observed behavior must match source.",
                              "tasks": ["TASK-A"], "contracts": ["SET-A"], "acceptance": ["ACC-A"], "relations": ["REL-001"], "decisions": ["DEC-001"]}],
            "contracts": [{**common, "id": "SET-A", "title": "One authoritative writer", "owner": "identity", "phase": "commit",
                           "reads": ["source.fact"], "writes": ["identity.state"], "resolution": ["death wins"], "invariants": ["one identity"], "acceptance": ["ACC-A"]}],
            "tasks": [{**common, "id": "TASK-A", "title": "Implement A", "status": "verified", "owner": "code", "stage": 0, "dependsOn": [], "scope": "One behavior",
                       "deliverables": ["src/a.gd"], "acceptance": ["ACC-A"]}],
            "scenarios": [{**common, "id": "ACC-A", "title": "Observable consequence", "kind": "automated", "given": "Valid input",
                           "when": "Commit action", "then": ["Expected consequence"], "evidence": [{"report": "docs/qa/run.json", "check": "CHECK-A"}]}],
        }
        self.report = {"schemaVersion": 1, "suite": "fixture", "generatedAt": "2026-10-25T00:00:00Z",
                       "checks": [{"id": "CHECK-A", "status": "pass"}],
                       "sourceHashes": {path: self.hash(path) for path in ["docs/specs/system-a.md", "src/a.gd"]}}
        self.residuals = {"schemaVersion": 1, "items": [], "taskReviews": [self.review(self.ledger["tasks"][0])]}
        self.bind_plan("docs/specs/system-a.md", "REQ-A", "TASK-A")
        self.save()

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def write_json(self, path, value):
        self.write(path, json.dumps(value, ensure_ascii=False))

    def hash(self, path):
        return hashlib.sha256((self.root / path).read_bytes()).hexdigest()

    def review(self, task):
        return {"task": task["id"], "summary": "Explicit closeout review", "reviewedTaskHash": task_review_hash(task), "planned": [], "issues": []}

    def save(self):
        self.write_json(RESIDUALS, self.residuals)
        self.write_json(LEDGER, self.ledger)
        self.write_json("docs/qa/run.json", self.report)

    def load(self):
        self.save()
        return load_tracking(self.root)

    def status(self, data):
        return data["scenarios"][0]["verification"]["status"]

    def bind_plan(self, source, requirement, task):
        self.ledger.setdefault("planBindings", []).append({
            "source": source, "sourceHash": self.hash(source),
            "requirements": [requirement], "tasks": [task],
            "reviewNote": f"This rule is scheduled in {task}, with its existing observable acceptance."})

    def add_task(self, suffix, dependency):
        source = f"docs/specs/system-{suffix.lower()}.md"
        delivery = f"src/{suffix.lower()}.gd"
        self.write(source, f"Rule for {suffix}\n")
        self.write(delivery, f"Implementation for {suffix}\n")
        self.report["sourceHashes"][source] = self.hash(source)
        self.report["sourceHashes"][delivery] = self.hash(delivery)
        common = {"features": ["MECH-A"], "sources": [source]}
        self.ledger["tasks"].append({**common, "id": f"TASK-{suffix}", "title": f"Task {suffix}", "status": "verified", "owner": "code", "stage": 1, "dependsOn": [dependency],
                                     "scope": suffix, "deliverables": [delivery], "acceptance": [f"ACC-{suffix}"]})
        self.ledger["requirements"].append({**common, "id": f"REQ-{suffix}", "title": suffix, "rule": "Required", "tasks": [f"TASK-{suffix}"],
                                           "contracts": [], "acceptance": [f"ACC-{suffix}"]})
        self.ledger["scenarios"].append({**common, "id": f"ACC-{suffix}", "title": suffix, "given": "State", "when": "Action", "then": ["Result"],
                                        "evidence": [{"report": "docs/qa/run.json", "check": f"CHECK-{suffix}"}]})
        self.report["checks"].append({"id": f"CHECK-{suffix}", "status": "pass"})
        self.bind_plan(source, f"REQ-{suffix}", f"TASK-{suffix}")
        self.residuals["taskReviews"].append(self.review(self.ledger["tasks"][-1]))

    def test_001_complete_chain_passes(self):
        data = self.load()
        self.assertEqual([], data["errors"])
        self.assertEqual("passed", self.status(data))
        self.assertTrue(data["requirements"][0]["coverage"]["implemented"])
        self.assertTrue(data["tasks"][0]["readiness"]["ready"])

    def test_002_missing_assignment_remains_visible(self):
        self.ledger["requirements"][0]["tasks"] = []
        data = self.load()
        self.assertEqual(1, data["summary"]["unassigned"])
        self.assertFalse(data["requirements"][0]["coverage"]["assigned"])
        self.assertTrue(any("未分配" in warning for warning in data["warnings"]))

    def test_003_unknown_references_are_errors(self):
        for field, value in [("tasks", "TASK-MISSING"), ("contracts", "SET-MISSING"), ("acceptance", "ACC-MISSING"),
                             ("features", "MECH-MISSING"), ("relations", "REL-MISSING"), ("decisions", "DEC-MISSING")]:
            with self.subTest(field=field):
                original = self.ledger["requirements"][0][field]
                self.ledger["requirements"][0][field] = [value]
                self.assertTrue(any(value in error for error in self.load()["errors"]))
                self.ledger["requirements"][0][field] = original

    def test_004_duplicate_state_writer_is_error(self):
        duplicate = copy.deepcopy(self.ledger["contracts"][0])
        duplicate["id"] = "SET-B"
        self.ledger["contracts"].append(duplicate)
        self.assertTrue(any("多个写入" in error for error in self.load()["errors"]))

    def test_005_dependency_cycle_is_error(self):
        self.add_task("B", "TASK-A")
        self.ledger["tasks"][0]["dependsOn"] = ["TASK-B"]
        self.assertTrue(any("成环" in error for error in self.load()["errors"]))

    def test_006_missing_report_is_unverified(self):
        self.ledger["scenarios"][0]["evidence"][0]["report"] = "docs/qa/not-run.json"
        self.assertEqual("unverified", self.status(self.load()))

    def test_007_missing_check_cannot_borrow_other_pass(self):
        self.ledger["scenarios"][0]["evidence"][0]["check"] = "CHECK-NOT-RUN"
        self.assertEqual("unverified", self.status(self.load()))

    def test_008_source_not_bound_to_report_is_unverified(self):
        del self.report["sourceHashes"]["docs/specs/system-a.md"]
        data = self.load()
        self.assertEqual("unverified", self.status(data))
        self.assertIn("未绑定", data["scenarios"][0]["verification"]["evidence"][0]["reason"])

    def test_009_rule_change_marks_evidence_stale(self):
        self.write("docs/specs/system-a.md", "Changed acceptance rule.\n")
        data = self.load()
        self.assertEqual("stale", self.status(data))
        self.assertEqual(["docs/specs/system-a.md"], data["reports"][0]["changed"])
        self.assertFalse(data["reports"][0]["current"])

    def test_010_code_change_marks_evidence_stale(self):
        self.write("src/a.gd", "# Different implementation.\n")
        self.assertEqual("stale", self.status(self.load()))

    def test_011_failed_check_is_failed(self):
        self.report["checks"][0]["status"] = "fail"
        data = self.load()
        self.assertEqual("failed", self.status(data))
        self.assertEqual("failed", data["requirements"][0]["coverage"]["verification"])

    def test_012_verified_without_evidence_is_error(self):
        self.ledger["scenarios"][0]["evidence"] = []
        self.assertTrue(any("声称验收通过" in error for error in self.load()["errors"]))

    def test_013_unverified_direct_prerequisite_blocks(self):
        self.add_task("B", "TASK-A")
        self.ledger["tasks"][0]["status"] = "planned"
        data = self.load()
        self.assertFalse(data["tasks"][1]["readiness"]["ready"])
        self.assertTrue(any("前置任务未验收" in error for error in data["errors"]))

    def test_014_unverified_transitive_prerequisite_blocks(self):
        self.add_task("B", "TASK-A")
        self.add_task("C", "TASK-B")
        self.ledger["tasks"][0]["status"] = "planned"
        data = self.load()
        self.assertFalse(data["tasks"][2]["readiness"]["ready"], "C cannot be ready while its claimed-verified B has unmet A")

    def test_015_missing_claimed_deliverable_is_error(self):
        (self.root / "src/a.gd").unlink()
        self.assertTrue(any("交付物不存在" in error for error in self.load()["errors"]))

    def test_016_reverse_impact_includes_downstream_acceptance(self):
        self.add_task("B", "TASK-A")
        self.add_task("C", "TASK-B")
        result = impact(self.load(), "TASK-A")
        self.assertEqual({"TASK-B", "TASK-C"}, set(result["downstreamTasks"]))
        self.assertEqual({"ACC-A", "ACC-B", "ACC-C"}, {row["id"] for row in result["scenarios"]})
        self.assertIn("docs/specs/system-c.md", result["sources"])

    def test_017_impact_context_includes_upstream_rule_sources(self):
        self.add_task("B", "TASK-A")
        self.add_task("C", "TASK-B")
        result = impact(self.load(), "TASK-C")
        self.assertEqual({"TASK-A", "TASK-B"}, set(result["prerequisites"]))
        self.assertIn("docs/specs/system-a.md", result["sources"], "A prerequisite's rule must be in the task reading context")
        self.assertIn("docs/specs/system-b.md", result["sources"])

    def test_018_source_path_cannot_escape_root(self):
        self.ledger["requirements"][0]["sources"] = ["../outside.md"]
        self.assertTrue(any("越出" in error for error in self.load()["errors"]))

    def test_019_report_path_cannot_escape_root(self):
        self.ledger["scenarios"][0]["evidence"][0]["report"] = "../outside.json"
        self.assertEqual("unverified", self.status(self.load()))

    def test_020_duplicate_check_ids_do_not_pass(self):
        self.report["checks"].append({"id": "CHECK-A", "status": "fail"})
        self.assertEqual("unverified", self.status(self.load()))

    def test_021_all_declared_evidence_parts_required(self):
        self.ledger["scenarios"][0]["evidence"].append({"report": "docs/qa/run.json", "check": "CHECK-NOT-RUN"})
        self.assertEqual("unverified", self.status(self.load()))

    def test_022_unmapped_feature_is_error(self):
        self.write_json("docs/game-state/features/core.json", [{"id": "MECH-A"}, {"id": "MECH-B"}])
        self.assertTrue(any("MECH-B" in error and "没有" in error for error in self.load()["errors"]))

    def test_023_corrupt_ledger_returns_errors(self):
        self.write(LEDGER, "{bad json")
        data = load_tracking(self.root)
        self.assertTrue(data["errors"])
        self.assertEqual([], data["scenarios"])

    def test_024_null_reference_list_is_reported_not_crashed(self):
        self.ledger["requirements"][0]["acceptance"] = None
        data = self.load()
        self.assertTrue(data["errors"])

    def test_025_unknown_target_is_not_context(self):
        self.assertFalse(impact(self.load(), "TASK-NONEXISTENT")["found"])

    def test_026_cli_strict_exposes_pending_acceptance(self):
        self.ledger["tasks"][0]["status"] = "planned"
        self.ledger["scenarios"][0]["evidence"] = []
        self.save()
        command = [sys.executable, str(HERE / "check.py"), "--root", str(self.root)]
        normal = subprocess.run(command, capture_output=True, text=True, check=False)
        strict = subprocess.run(command + ["--strict"], capture_output=True, text=True, check=False)
        self.assertEqual(0, normal.returncode, normal.stdout + normal.stderr)
        self.assertEqual(2, strict.returncode, strict.stdout + strict.stderr)

    def test_027_critical_requirement_without_owner_fails_normal_check(self):
        critical = copy.deepcopy(self.ledger["requirements"][0])
        critical.update({"id": "REQ-CRITICAL", "title": "Critical unassigned behavior", "criticality": "critical", "tasks": []})
        self.ledger["requirements"].append(critical)
        data = self.load()
        self.assertTrue(any("REQ-CRITICAL" in error for error in data["errors"]))
        self.assertEqual(1, data["summary"]["unassigned"])
        result = subprocess.run([sys.executable, str(HERE / "check.py"), "--root", str(self.root)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        self.assertIn("REQ-CRITICAL", result.stdout)

    def test_028_task_prerequisites_exclude_self_and_downstream(self):
        self.add_task("B", "TASK-A")
        self.add_task("C", "TASK-B")
        data = self.load()
        for target, prerequisites, downstream in [
            ("TASK-A", set(), {"TASK-B", "TASK-C"}),
            ("TASK-B", {"TASK-A"}, {"TASK-C"}),
            ("TASK-C", {"TASK-A", "TASK-B"}, set()),
        ]:
            with self.subTest(target=target):
                context = impact(data, target)
                self.assertEqual(prerequisites, set(context["prerequisites"]))
                self.assertEqual(downstream, set(context["downstreamTasks"]))
                self.assertNotIn(target, context["prerequisites"])

    def test_029_shared_requirement_does_not_create_task_prerequisite(self):
        self.add_task("B", "TASK-A")
        self.add_task("C", "TASK-B")
        shared = copy.deepcopy(self.ledger["requirements"][0])
        shared.update({"id": "REQ-SHARED", "title": "Shared B/C responsibility", "tasks": ["TASK-B", "TASK-C"],
                       "acceptance": ["ACC-B", "ACC-C"], "sources": ["docs/specs/system-b.md", "docs/specs/system-c.md"]})
        self.ledger["requirements"].append(shared)
        context = impact(self.load(), "TASK-B")
        self.assertEqual({"TASK-A"}, set(context["prerequisites"]))
        self.assertEqual({"TASK-C"}, set(context["downstreamTasks"]))
        self.assertIn("ACC-C", {row["id"] for row in context["scenarios"]})

    def test_030_new_proposal_must_be_scheduled_before_cli_passes(self):
        source = "docs/implementation/new-simulation.md"
        self.write(source, "A new proposal with no task assignment.\n")
        data = self.load()
        self.assertTrue(any(source in error and "未编入" in error for error in data["errors"]))
        result = subprocess.run([sys.executable, str(HERE / "check.py"), "--root", str(self.root)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)

    def test_031_planned_source_change_requires_plan_review(self):
        self.ledger["tasks"][0]["status"] = "planned"
        self.ledger["scenarios"][0]["evidence"] = []
        self.write("docs/specs/system-a.md", "Changed design before any implementation.\n")
        data = self.load()
        self.assertTrue(any("尚未同步开发计划" in error for error in data["errors"]))
        self.assertEqual("unverified", self.status(data))

    def test_032_missing_and_malformed_bindings_cannot_disable_gate(self):
        original = copy.deepcopy(self.ledger["planBindings"])
        for value in (None, {}, [], [None], [{"source": []}], [{"source": "docs/specs/system-a.md", "requirements": None, "tasks": {}}]):
            with self.subTest(value=value):
                self.ledger["planBindings"] = value
                self.assertTrue(self.load()["errors"])
        self.ledger.pop("planBindings")
        self.assertTrue(any("未编入" in error for error in self.load()["errors"]))
        self.ledger["planBindings"] = original

    def test_033_duplicate_and_unsafe_plan_sources_are_errors(self):
        original = copy.deepcopy(self.ledger["planBindings"][0])
        self.ledger["planBindings"].append(copy.deepcopy(original))
        self.assertTrue(any("重复绑定" in error for error in self.load()["errors"]))
        self.ledger["planBindings"] = [original]
        for source, fragment in [("../outside.md", "越出"), (str(self.root / "docs/specs/system-a.md"), "相对路径"),
                                 ("docs/specs/../specs/system-a.md", "规范"), ("docs/specs/missing.md", "来源不存在")]:
            with self.subTest(source=source):
                self.ledger["planBindings"][0]["source"] = source
                self.assertTrue(any(fragment in error for error in self.load()["errors"]))

    def test_034_plan_requires_nonempty_known_task_and_requirement(self):
        original = copy.deepcopy(self.ledger["planBindings"][0])
        for field in ("tasks", "requirements"):
            for value in ([], None, [""], ["UNKNOWN"], [original[field][0], original[field][0]]):
                with self.subTest(field=field, value=value):
                    self.ledger["planBindings"][0] = {**original, field: value}
                    self.assertTrue(any("方案" in error for error in self.load()["errors"]))

    def test_035_plan_task_and_requirement_must_share_real_acceptance(self):
        self.add_task("B", "TASK-A")
        self.ledger["tasks"][1]["sources"].append("docs/specs/system-a.md")
        self.ledger["planBindings"][0]["tasks"] = ["TASK-B"]
        self.assertTrue(any("未与绑定要求共享真实验收" in error for error in self.load()["errors"]))
        self.ledger["requirements"][0]["tasks"].append("TASK-B")
        self.assertTrue(any("未与绑定要求共享真实验收" in error for error in self.load()["errors"]))
        self.ledger["requirements"][0]["acceptance"] = ["ACC-NONEXISTENT"]
        self.ledger["tasks"][1]["acceptance"] = ["ACC-NONEXISTENT"]
        self.assertTrue(any("未与绑定要求共享真实验收" in error for error in self.load()["errors"]))

    def test_036_binding_source_must_be_in_both_rule_and_task(self):
        source = "docs/implementation/second-plan.md"
        self.write(source, "A second proposal.\n")
        for group in ("requirements", "tasks"):
            self.ledger[group][0]["sources"] = list(self.ledger[group][0]["sources"])
        self.bind_plan(source, "REQ-A", "TASK-A")
        for group in ("requirements", "tasks"):
            self.assertTrue(any(source in error and "未进入" in error for error in self.load()["errors"]))
            self.ledger[group][0]["sources"].append(source)
        self.assertEqual([], self.load()["errors"])

    def test_037_plan_must_explain_review_and_use_real_sha256(self):
        original = copy.deepcopy(self.ledger["planBindings"][0])
        for field, values in (("reviewNote", (None, "", "   ", [])), ("sourceHash", (None, "", "abc", "z" * 64, []))):
            for value in values:
                with self.subTest(field=field, value=value):
                    self.ledger["planBindings"][0] = {**original, field: value}
                    self.assertTrue(any(field in error for error in self.load()["errors"]))

    def test_038_plan_sync_does_not_imply_implementation_or_evidence(self):
        self.ledger["tasks"][0]["status"] = "planned"
        self.ledger["scenarios"][0]["evidence"] = []
        self.write("docs/specs/system-a.md", "Reworded rule, no behavioral change.\n")
        self.ledger["planBindings"][0].update({
            "sourceHash": self.hash("docs/specs/system-a.md"),
            "reviewNote": "Clarified wording only; TASK-A scope and ACC-A behavior remain unchanged after review."})
        data = self.load()
        self.assertEqual([], data["errors"])
        self.assertEqual("planned", data["tasks"][0]["status"])
        self.assertEqual("unverified", self.status(data))
        self.assertEqual(1, data["summary"]["planSources"])

    def test_039_scan_includes_live_sources_and_excludes_other_lifecycles(self):
        live = {"docs/vision.md", "docs/world.md", "docs/gdd-core.md", "docs/architecture.md",
                "docs/specs/nested/system-b.md", "docs/content/nested/narrative.md", "docs/implementation/proposal.md"}
        excluded = {"docs/specs/_template-system.md", "docs/content/_template-content.md", "docs/implementation/README.md",
                    "docs/qa/report.md", "docs/ori/original.md", "docs/tasks/slice-04.md", "docs/progress/roadmap.md",
                    "docs/game-state/INDEX.md"}
        for source in live | excluded:
            self.write(source, "Source with an explicit lifecycle.\n")
        self.assertEqual(live | {"docs/specs/system-a.md"}, plan_source_paths(self.root))
        errors = self.load()["errors"]
        self.assertTrue(all(any(source in error and "未编入" in error for error in errors) for source in live))
        self.assertFalse(any(any(source in error for source in excluded) for error in errors))

    def test_040_gate_never_rewrites_stale_binding(self):
        self.write("docs/specs/system-a.md", "New rule awaiting plan review.\n")
        self.save()
        before = (self.root / LEDGER).read_bytes()
        data = load_tracking(self.root)
        self.assertEqual(before, (self.root / LEDGER).read_bytes())
        self.assertNotEqual(self.hash("docs/specs/system-a.md"), data["planBindings"][0]["sourceHash"])
        self.assertTrue(any("尚未同步开发计划" in error for error in data["errors"]))

    def test_041_plan_binding_cannot_point_only_to_nonplan_protocol(self):
        source = "docs/implementation/README.md"
        self.write(source, "Operational protocol, not the design proposal.\n")
        self.ledger["requirements"][0]["sources"].append(source)
        self.ledger["tasks"][0]["sources"].append(source)
        self.bind_plan(source, "REQ-A", "TASK-A")
        self.assertTrue(any("不在正式方案扫描范围" in error for error in self.load()["errors"]))

    def test_042_bound_task_requires_explicit_owner(self):
        task = self.ledger["tasks"][0]
        task.pop("owner")
        self.assertTrue(any("TASK-A.owner" in error for error in self.load()["errors"]))
        for owner in (None, "", "   ", [], 1, True):
            with self.subTest(owner=owner):
                task["owner"] = owner
                self.assertTrue(any("TASK-A.owner" in error for error in self.load()["errors"]))
        task["owner"] = "code"
        self.assertEqual([], self.load()["errors"])

    def test_043_bound_task_stage_is_a_nonnegative_integer_not_bool(self):
        task = self.ledger["tasks"][0]
        task.pop("stage")
        self.assertTrue(any("TASK-A.stage" in error for error in self.load()["errors"]))
        for stage in (None, -1, 1.5, "1", [], True, False):
            with self.subTest(stage=stage):
                task["stage"] = stage
                self.assertTrue(any("TASK-A.stage" in error for error in self.load()["errors"]))
        task["stage"] = 0
        self.assertEqual([], self.load()["errors"])

    def test_044_bound_task_dependencies_must_be_explicit_before_normalization(self):
        task = self.ledger["tasks"][0]
        task.pop("dependsOn")
        self.assertTrue(any("TASK-A.dependsOn" in error for error in self.load()["errors"]))
        for dependencies in (None, {}, "TASK-B", [""], ["   "], [True]):
            with self.subTest(dependencies=dependencies):
                task["dependsOn"] = dependencies
                self.assertTrue(any("TASK-A.dependsOn" in error for error in self.load()["errors"]))
        task["dependsOn"] = ["TASK-MISSING"]
        self.assertTrue(any("dependsOn" in error and "TASK-MISSING" in error for error in self.load()["errors"]))
        task["dependsOn"] = []
        self.assertEqual([], self.load()["errors"])



    def issue(self, **changes):
        row = {"id": "ISSUE-A", "title": "Needs resolution", "originTask": "TASK-A", "owner": "director",
               "category": "decision", "status": "open", "description": "Author choice required", "nextAction": "Ask author",
               "blockedTasks": [], "sources": ["docs/specs/system-a.md"], "resolution": ""}
        row.update(changes)
        self.residuals["items"] = [row]
        self.residuals["taskReviews"][0]["issues"] = ["ISSUE-A"]

    def test_residual_missing_review_rejects_completion(self):
        self.residuals["taskReviews"] = []
        self.assertTrue(any("收尾缺少" in e for e in self.load()["errors"]))

    def test_residual_changed_scope_requires_review(self):
        self.ledger["tasks"][0]["risks"] = ["new risk"]
        self.assertTrue(any("未复核遗留" in e for e in self.load()["errors"]))

    def test_residual_planned_handoff_requires_real_acceptance(self):
        self.residuals["taskReviews"][0]["planned"] = [{"description": "Later", "task": "TASK-A", "acceptance": ["ACC-MISSING"]}]
        self.assertTrue(any("引用不存在" in e for e in self.load()["errors"]))

    def test_residual_decision_count_is_separate_from_unverified(self):
        self.issue()
        model = self.load()
        self.assertEqual(model["residuals"]["summary"], {"open": 1, "unplanned": 0, "decision": 1, "blocking": 0})
        self.assertTrue(model["tasks"][0]["readiness"]["ready"])

    def test_residual_blocker_prevents_ready_and_complete(self):
        self.issue(category="blocking", blockedTasks=["TASK-A"])
        model = self.load()
        self.assertFalse(model["tasks"][0]["readiness"]["ready"])
        self.assertIn("ISSUE-A", model["tasks"][0]["readiness"]["blockedBy"])
        self.assertTrue(any("不能宣称完成" in e for e in model["errors"]))

    def test_residual_closed_needs_resolution_evidence(self):
        self.issue(status="resolved")
        self.assertTrue(any("resolution" in e for e in self.load()["errors"]))

    def test_residual_malformed_register_does_not_show_zero(self):
        self.residuals["items"] = None
        self.assertIsNone(self.load()["residuals"]["summary"])

    def test_residual_unplanned_close_requires_handoff(self):
        self.issue(category="unplanned", status="resolved", resolution="Scheduled", resolutionSources=["docs/specs/system-a.md"])
        self.assertTrue(any("计划交接" in e for e in self.load()["errors"]))

    def test_residual_registered_but_omitted_from_closeout_fails(self):
        self.issue()
        self.residuals["taskReviews"][0]["issues"] = []
        self.assertTrue(any("漏记未决" in e for e in self.load()["errors"]))

    def test_residual_blocker_reaches_dependent_task(self):
        self.add_task("B", "TASK-A")
        self.issue(category="blocking", blockedTasks=["TASK-A"])
        model = self.load()
        child = next(t for t in model["tasks"] if t["id"] == "TASK-B")
        self.assertFalse(child["readiness"]["ready"])
        self.assertIn("ISSUE-A", child["readiness"]["blockedBy"])

    def test_residual_resolved_planned_is_not_open(self):
        self.issue(category="unplanned", status="resolved", resolution="Assigned", resolutionSources=["docs/specs/system-a.md"],
                   handoff={"description": "Real assignment", "task": "TASK-A", "acceptance": ["ACC-A"]})
        self.assertEqual(self.load()["residuals"]["summary"]["open"], 0)

    def test_residual_malformed_origin_does_not_crash(self):
        self.issue(originTask=[])
        model = self.load()
        self.assertIsNone(model["residuals"]["summary"])
        self.assertTrue(model["errors"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
