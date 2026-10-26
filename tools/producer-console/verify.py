#!/usr/bin/env python3
"""Run workbench checks and record version-bound evidence for automated checks only.

Browser interaction is deliberately recorded separately by the reviewing agent.
The evolving task ledger is an input, not a source hash of this tool's own proof.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent


def source_hashes():
    sources = [path for path in TOOL.rglob('*')
               if path.is_file() and '__pycache__' not in path.parts
               and path.suffix in {'.py', '.js', '.mjs', '.html', '.css', '.md'}]
    sources += [ROOT / 'docs/specs/tool-producer-console.md',
                ROOT / 'tools/implementation/tracking.py']
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(set(sources))}


def run_check(name, command, expected_tests=None, node=False):
    try:
        process = subprocess.run(command, cwd=ROOT, text=True, capture_output=True,
                                 check=False, timeout=120)
        log = process.stdout + process.stderr
        count = None
        if expected_tests is not None:
            pattern = r'# tests (\d+)' if node else r'Ran (\d+) tests?'
            matched = re.search(pattern, log)
            count = int(matched.group(1)) if matched else 0
        passed = process.returncode == 0 and (expected_tests is None or count == expected_tests)
        print(log, end='' if log.endswith('\n') or not log else '\n')
        print(f'{name}: {"PASS" if passed else "FAIL"}')
        return {'name': name, 'command': command, 'status': 'pass' if passed else 'fail',
                'testsRun': count, 'expectedTests': expected_tests,
                'exitCode': process.returncode, 'output': log}
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f'{name}: FAIL {error}', file=sys.stderr)
        return {'name': name, 'command': command, 'status': 'fail', 'error': str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'docs/qa/implementation-workbench-results.json')
    args = parser.parse_args()
    before = source_hashes()
    node = shutil.which('node') or 'node'
    checks = [
        run_check('Python 服务、来源与持久化', [sys.executable, str(TOOL / 'test_server.py')], 15),
        run_check('JavaScript 公式、追踪与讨论逻辑', [node, '--test', str(TOOL / 'test_logic.mjs')], 11, node=True),
        run_check('界面脚本语法', [node, '--check', str(TOOL / 'web/app.js')]),
        run_check('公共逻辑语法', [node, '--check', str(TOOL / 'web/logic.mjs')]),
        run_check('Python 源码编译', [sys.executable, '-m', 'py_compile',
                                    *[str(path) for path in sorted(TOOL.glob('*.py'))]]),
    ]
    unchanged = before == source_hashes()
    success = unchanged and all(check['status'] == 'pass' for check in checks)
    report = {
        'schemaVersion': 1,
        'suite': 'implementation-workbench',
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'checks': [{
            'id': 'WORKBENCH-SUITE',
            'name': '制作工作台自动检查',
            'status': 'pass' if success else 'fail',
            'details': {
                'scope': '仅自动测试和语法/编译检查；不包含浏览器视觉与交互验收。',
                'pythonTests': checks[0].get('testsRun', 0),
                'javascriptTests': checks[1].get('testsRun', 0),
                'sourcesUnchangedDuringRun': unchanged,
                'commands': checks,
            },
        }],
        'sourceHashes': before,
        'metrics': {'pythonTests': checks[0].get('testsRun', 0),
                    'javascriptTests': checks[1].get('testsRun', 0)},
        'scope': [
            '本地 HTTP 模型读取、来源路径边界、同源写入、讨论原子保存与版本冲突',
            '四类稳定追踪对象、正反向关联、缺口筛选与讨论状态不改变正式状态',
            '离线封装包含追踪与报告、脚本转义、CSV 公式边界与讨论合并',
        ],
        'limitations': [
            '浏览器实际点击、宽窄布局、视觉可读性及原生剪贴板/文件对话框由主线程另外验收',
            '运行时读取当前项目数据，不将可变追踪清单或生成报告自身纳入工具自身证据哈希',
            '不证明关键游戏行为已经穷尽、正式游戏全部接入、玩法平衡或体验通过',
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + '.tmp')
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.output)
    print(f'Evidence: {args.output}')
    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())
