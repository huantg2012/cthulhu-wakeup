"""Evidence handling must fail closed; no fabricated campaign is published."""
import gzip
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("balance_report", Path(__file__).with_name("report.py"))
report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(report)


class EvidenceTests(unittest.TestCase):
    def test_partial_execution_cannot_publish(self):
        with self.assertRaisesRegex(ValueError, "partial"):
            report.analyse({"executionStatus": "running"})

    def test_changed_execution_source_cannot_publish(self):
        sources = report.execution_hashes()
        sources[next(iter(sources))] = "0" * 64
        with self.assertRaisesRegex(ValueError, "stale"):
            report.analyse({"executionStatus": "complete", "sourceHashes": sources})

    def test_missing_campaign_cannot_publish(self):
        with self.assertRaisesRegex(ValueError, "campaign identities"):
            report.analyse({"executionStatus": "complete", "sourceHashes": report.execution_hashes(), "campaigns": []})

    def test_missing_source_cannot_publish(self):
        with self.assertRaisesRegex(ValueError, "source inventory"):
            report.analyse({"executionStatus": "complete", "sourceHashes": {}})

    def test_metadata_cannot_override_original_observation_or_fail(self):
        original = {"status": "censored", "first_cult_turn": -1,
                    "final": {"faith": 18}, "checks": [{"id": "X", "status": "fail"}]}
        report.validate_campaign_metadata(original, original)
        for field, value in (("first_cult_turn", 7), ("final", {"faith": 100}),
                             ("checks", [{"id": "X", "status": "pass"}])):
            altered = copy.deepcopy(original)
            altered[field] = value
            with self.assertRaisesRegex(ValueError, "differs from raw"):
                report.validate_campaign_metadata(altered, original)

    def test_bad_input_does_not_overwrite_durable_baseline(self):
        scratch_root = (report.ROOT / ".godot").resolve()
        with tempfile.TemporaryDirectory(prefix="balance-baseline-", dir=scratch_root) as temporary:
            scratch = Path(temporary).resolve()
            self.assertTrue(scratch.is_relative_to(scratch_root))
            previous = scratch / "baseline.json"
            previous.write_bytes(b"durable previous evidence")
            incoming = scratch / "incoming.json"
            incoming.write_text('{"executionStatus":"running"}', encoding="utf-8")
            with patch.object(report, "BASELINE", previous), patch("sys.argv", ["report", "--input", str(incoming)]):
                with self.assertRaisesRegex(ValueError, "partial"):
                    report.main()
            self.assertEqual(previous.read_bytes(), b"durable previous evidence")

    def test_archive_roundtrip_and_tampering(self):
        scratch_root = (report.ROOT / ".godot").resolve()
        with tempfile.TemporaryDirectory(prefix="balance-evidence-", dir=scratch_root) as temporary:
            scratch = Path(temporary).resolve()
            self.assertTrue(scratch.is_relative_to(scratch_root))
            original = scratch / "trace.jsonl"
            raw = b'{"type":"start"}\n'
            original.write_bytes(raw)
            relative = original.relative_to(report.ROOT).as_posix()
            with patch.object(report, "ARCHIVES", scratch):
                observed, artifact = report.archived_bytes(relative, report.sha(raw), "sample")
                self.assertEqual(raw, observed)
                original.unlink()
                self.assertEqual(raw, report.archived_bytes(relative, report.sha(raw), "sample")[0])
                (report.ROOT / artifact["path"]).write_bytes(gzip.compress(b"different", mtime=0))
                with self.assertRaisesRegex(ValueError, "Corrupt"):
                    report.archived_bytes(relative, report.sha(raw), "sample")

    def test_unsafe_source_rejected(self):
        with self.assertRaisesRegex(ValueError, "unsafe"):
            report.project_file("../../Windows/System32/cmd.exe")

    def test_unsafe_artifact_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsafe artifact"):
            report.archived_bytes("../../outside.txt", "0" * 64, "sample")


if __name__ == "__main__":
    unittest.main()
