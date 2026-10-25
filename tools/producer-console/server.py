#!/usr/bin/env python3
"""Local producer workbench. Design is read-only; discussion records are explicit writes."""
from __future__ import annotations
import argparse
import csv
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import tempfile
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
WEB = Path(__file__).resolve().parent / 'web'
ATLAS = Path('docs/game-state')
LOCK = threading.Lock()
DELIVERY_GROUPS = ('requirements', 'contracts', 'tasks', 'scenarios')


def load_delivery(root):
    """Read the shared tracker; failure stays visible without hiding the atlas."""
    empty = {'schemaVersion': 1, **{name: [] for name in DELIVERY_GROUPS},
             'summary': {}, 'errors': [], 'warnings': []}
    ledger = root / 'docs/implementation/traceability.json'
    loader = ROOT / 'tools/implementation/tracking.py'
    if not ledger.exists() or not loader.exists():
        return {**empty, 'warnings': ['实施追踪尚未载入；现有机制图不代表行为已分配或验收。']}
    try:
        spec = importlib.util.spec_from_file_location('producer_delivery_tracking', loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.load_tracking(root)
    except (OSError, ValueError, TypeError, KeyError) as error:
        return {**empty, 'errors': ['实施追踪读取失败：' + str(error)]}


def delivery_sources(delivery):
    paths = {'docs/implementation/traceability.json'}
    for group in DELIVERY_GROUPS:
        for item in delivery.get(group, []):
            paths.update(item.get('sources', []))
            paths.update(e['report'] for e in item.get('evidence', []) if e.get('report'))
    paths.update(report['path'] for report in delivery.get('reports', []) if report.get('path'))
    return paths


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project_path(root, relative):
    candidate = (root / relative).resolve()
    if Path(relative).is_absolute() or not candidate.is_relative_to(root.resolve()):
        raise ValueError('来源必须位于当前项目内: ' + relative)
    return candidate


def catalog_key(row):
    if 'option' in row:
        return row['event_id'] + '-' + row['option']
    return next(iter(row.values()))


def load_model(root=ROOT):
    base = root / ATLAS
    atlas = read_json(base / 'atlas.json')
    features = [f for rel in atlas['featureFiles'] for f in read_json(base / rel)]
    relations = read_json(base / 'relationships.json')
    paths = read_json(base / 'paths.json')
    phases = read_json(base / 'phases.json')
    delivery = load_delivery(root)
    sources = sorted({s['path'] for f in features for s in f['sources']} |
                     {s['path'] for r in relations for s in r['sources']} |
                     {p for p in delivery_sources(delivery) if (root / p).exists()})
    for source in sources: project_path(root, source)
    snapshot = read_json(base / 'snapshot.json') if (base / 'snapshot.json').exists() else {'files': {}}
    metadata = [str(ATLAS / p) for p in ['atlas.json', *atlas['featureFiles'], atlas['evidenceFile'], 'relationships.json', 'paths.json', 'phases.json']]
    watched = sorted(set(sources + metadata))
    changed = [p for p in watched if not (root / p).exists() or checksum(root / p) != snapshot['files'].get(p)]
    docs = {p: (root / p).read_text(encoding='utf-8') for p in sources if p.endswith(('.md', '.json')) and (root / p).exists()}
    tables = {}
    for p in sorted((root / 'data').glob('*.csv')):
        if p.name.startswith('feasibility_'):
            continue
        with p.open(encoding='utf-8', newline='') as f:
            reader = csv.DictReader(f)
            tables[p.stem] = {'path': str(p.relative_to(root)), 'columns': reader.fieldnames, 'rows': list(reader)}
    official_ids = {f['id'] for f in features}
    relation_ids = set()
    for rel in relations:
        if rel['from'] not in official_ids or rel['to'] not in official_ids:
            raise ValueError('关系引用了未知机制: ' + rel['id'])
        if rel['id'] in relation_ids:
            raise ValueError('关系编号重复: ' + rel['id'])
        relation_ids.add(rel['id'])
    for journey in paths:
        if len(journey['nodes']) != len(journey['steps']) or any(n not in official_ids for n in journey['nodes']):
            raise ValueError('因果路径引用或步骤不正确: ' + journey['id'])
    indexed = {s['path'] for f in features for s in f['sources']}
    unowned = [str(p.relative_to(root)) for p in (root / 'data').glob('*.csv') if str(p.relative_to(root)) not in indexed]
    # Computed evidence freshness can change when a report-bound implementation
    # changes, even if that implementation is not an atlas reading source.
    revision_input = ''.join(p + checksum(root / p) for p in watched if (root / p).exists())
    revision_input += json.dumps(delivery, ensure_ascii=False, sort_keys=True)
    revision = hashlib.sha256(revision_input.encode()).hexdigest()[:12]
    return {'atlas': atlas, 'features': features, 'relations': relations, 'paths': paths,
            'phases': phases, 'evidence': read_json(base / atlas['evidenceFile']), 'tables': tables, 'documents': docs, 'delivery': delivery,
            'meta': {'revision': revision, 'loadedAt': datetime.now(timezone.utc).isoformat(),
                     'baselineAt': snapshot.get('capturedAt'), 'changed': changed, 'unowned': unowned,
                     'mode': 'local', 'sourceCount': len(sources)}}


def targets_for(model):
    targets = {f['id']: f['title'] for f in model['features']}
    targets.update({r['id']: r['label'] for r in model['relations']})
    for group in DELIVERY_GROUPS:
        targets.update({item['id']: item['title'] for item in model.get('delivery', {}).get(group, [])})
    for name, table in model['tables'].items():
        targets['DATA-' + name] = name
        for row in table['rows']:
            targets['DATA-' + name + '/' + catalog_key(row)] = row.get('name') or row.get('title') or catalog_key(row)
    return targets


class FeedbackStore:
    def __init__(self, path):
        self.path = path

    def read(self):
        return read_json(self.path)

    def save(self, expected, items, target_ids):
        if type(expected) is not int or expected < 0 or not isinstance(items, list) or len(items) > 1000:
            raise ValueError('讨论单格式不正确。')
        ids = set()
        for item in items:
            if not isinstance(item, dict) or set(item) - {'id','target','title','body','kind','status','createdAt','updatedAt','sourceRevision'}:
                raise ValueError('讨论项有未知字段。')
            for key, limit in [('id',80),('target',160),('title',160),('body',12000),('createdAt',80),('updatedAt',80),('sourceRevision',80)]:
                if not isinstance(item.get(key), str) or not item[key].strip() or len(item[key]) > limit:
                    raise ValueError('讨论项缺失或过长: ' + key)
            if item['id'] in ids:
                raise ValueError('讨论编号重复。')
            ids.add(item['id'])
            if item['target'] not in target_ids:
                raise ValueError('讨论目标已失效，请先更新索引。')
            if item.get('kind') not in ['question','change','concern'] or item.get('status') not in ['open','answered','planned','archived']:
                raise ValueError('讨论类型或状态不正确。')
        with LOCK:
            previous = self.read()
            if previous['revision'] != expected:
                raise RuntimeError('另一处已经更新讨论单。请刷新后再合并，当前输入仍保留。')
            value = {'schemaVersion': 1, 'revision': expected + 1, 'items': items}
            fd, temporary = tempfile.mkstemp(prefix='.feedback-', suffix='.tmp', dir=self.path.parent)
            try:
                with os.fdopen(fd, 'w', encoding='utf-8') as f:
                    json.dump(value, f, ensure_ascii=False, indent=2)
                    f.write('\n'); f.flush(); os.fsync(f.fileno())
                os.replace(temporary, self.path)
            finally:
                if os.path.exists(temporary): os.unlink(temporary)
            return value


def make_handler(root, token):
    store = FeedbackStore(root / ATLAS / 'feedback.json')
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            if len(args) > 1 and str(args[1]).startswith(('4','5')): super().log_message(fmt, *args)

        def valid_host(self):
            # A loopback-only server should not answer DNS-rebinding hosts.
            return self.headers.get('Host') in {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}

        def reply(self, code, value, content_type='application/json; charset=utf-8'):
            payload = json.dumps(value, ensure_ascii=False).encode() if isinstance(value, (dict,list)) else value
            self.send_response(code)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.end_headers(); self.wfile.write(payload)

        def do_GET(self):
            if not self.valid_host(): return self.reply(403, {'error':'仅允许本机地址。'})
            route = urlparse(self.path).path
            try:
                if route == '/api/model':
                    value = load_model(root); value['token'] = token
                    return self.reply(200, value)
                if route == '/api/feedback': return self.reply(200, store.read())
                names = {'/':'index.html','/index.html':'index.html','/app.js':'app.js','/logic.mjs':'logic.mjs','/style.css':'style.css'}
                if route not in names: return self.reply(404, {'error':'没有这个页面。'})
                filename = WEB / names[route]
                types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8'}
                return self.reply(200, filename.read_bytes(), types[filename.suffix])
            except (ValueError, OSError, KeyError) as e:
                return self.reply(500, {'error':str(e)})

        def do_POST(self):
            if not self.valid_host(): return self.reply(403, {'error':'仅允许本机地址。'})
            expected_origin = 'http://' + self.headers.get('Host','')
            if self.headers.get('Origin') != expected_origin or self.headers.get('X-Workbench-Token') != token:
                return self.reply(403, {'error':'仅接受本地工作台内的明确保存。'})
            if urlparse(self.path).path != '/api/feedback': return self.reply(404, {'error':'没有这个操作。'})
            try:
                size = int(self.headers.get('Content-Length','0'))
                if size <= 0 or size > 2_000_000 or not self.headers.get('Content-Type','').startswith('application/json'):
                    raise ValueError('请求格式或大小不正确。')
                incoming = json.loads(self.rfile.read(size))
                if not isinstance(incoming, dict): raise ValueError('请求必须是讨论单对象。')
                value = store.save(incoming.get('revision'), incoming.get('items'), targets_for(load_model(root)))
                return self.reply(200, value)
            except RuntimeError as e: return self.reply(409, {'error':str(e)})
            except (ValueError, TypeError, KeyError) as e: return self.reply(400, {'error':str(e)})
            except OSError as e: return self.reply(500, {'error':'未能保存：'+str(e)})
    return Handler


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args=parser.parse_args()
    httpd=ThreadingHTTPServer(('127.0.0.1',args.port), make_handler(ROOT,secrets.token_urlsafe(32)))
    print(f'Producer workbench: http://127.0.0.1:{httpd.server_port}', flush=True)
    print('Design sources are read-only. Discussions save to docs/game-state/feedback.json.',flush=True)
    try: httpd.serve_forever()
    except KeyboardInterrupt: pass
    finally: httpd.server_close()
