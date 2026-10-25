#!/usr/bin/env python3
"""Run independent guard tests and record their exact source-version evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import unittest

from test_tracking import TrackingTests

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ["docs/implementation/README.md", "tools/implementation/tracking.py", "tools/implementation/check.py",
           "tools/implementation/test_tracking.py", "tools/implementation/verify.py"]


def hashes():
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCES}


class RecordedResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.records = []

    def addSuccess(self, test):
        super().addSuccess(test)
        self.records.append({"id": test._testMethodName, "status": "pass"})

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.records.append({"id": test._testMethodName, "status": "fail", "details": self._exc_info_to_string(err, test)})

    def addError(self, test, err):
        super().addError(test, err)
        self.records.append({"id": test._testMethodName, "status": "fail", "details": self._exc_info_to_string(err, test)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "docs/qa/implementation-check-results.json")
    args = parser.parse_args()
    before = hashes()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TrackingTests)
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordedResult).run(suite)
    unchanged = hashes() == before
    success = result.wasSuccessful() and unchanged
    report = {"schemaVersion": 1, "suite": "implementation-guards", "generatedAt": datetime.now(timezone.utc).isoformat(),
              "checks": [{"id": "GUARD-SUITE", "name": "追踪与证据防误报正负场景", "status": "pass" if success else "fail",
                          "details": {"testsRun": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
                                      "sourcesUnchangedDuringRun": unchanged}}, *result.records],
              "sourceHashes": before,
              "scope": ["临时仓库中的追踪引用、责任归属、任务依赖、证据来源匹配与失效", "正向完整链与有意破坏的负向场景", "影响上下文和 CLI 严格缺口返回码"],
              "limitations": ["这些测试不证明游戏玩法、平衡或人物文明推演正确", "生产追踪清单另由 check.py 检查，不把正在变化的清单哈希纳入工具自身验收", "无法证明自然语言要求已穷尽，也不验证人类体验"]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(args.output)
    print(f"Evidence: {args.output}")
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
