"""Focused integrity checks for the producer tool, not gameplay validation."""
import copy
import http.client
import json
from pathlib import Path
import shutil
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from server import ATLAS, ROOT, DELIVERY_GROUPS, FeedbackStore, load_model, load_delivery, delivery_sources, make_handler, targets_for, project_path
from build import render_snapshot


def note(target='MECH-ANCHORS'):
    return dict(id='DISC-TEST', target=target, title='测试议题', body='仅用于隔离测试。', kind='question', status='open', createdAt='2026-10-25T00:00:00Z', updatedAt='2026-10-25T00:00:00Z', sourceRevision='test-source')


class ModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = load_model()

    def test_graph_and_paths_refer_to_real_capabilities(self):
        m = self.model
        ids = {f['id'] for f in m['features']}
        self.assertEqual(len(ids), len(m['features']))
        graph = {f['id'] for f in m['features'] if f['producer']['graph']}
        cells = [(f['producer']['column'], f['producer']['row']) for f in m['features'] if f['producer']['graph']]
        self.assertEqual(len(cells), len(set(cells)))
        links = {(r['from'], r['to']) for r in m['relations']}
        for start, end in links:
            self.assertIn(start, graph); self.assertIn(end, graph)
        for path in m['paths']:
            self.assertEqual(len(path['steps']), len(path['nodes']))
            for pair in zip(path['nodes'], path['nodes'][1:]): self.assertIn(pair, links)
        for phase in m['phases']:
            for n in phase['nodes']: self.assertIn('MECH-'+n, ids)

    def test_catalog_rows_have_unique_durable_targets(self):
        m = self.model
        expected = len(m['features']) + len(m['relations']) + len(m['tables']) + sum(len(t['rows']) for t in m['tables'].values())
        expected += sum(len(m.get('delivery', {}).get(group, [])) for group in DELIVERY_GROUPS)
        self.assertEqual(len(targets_for(m)), expected)
        self.assertFalse(m['meta']['unowned'])
        self.assertIn('DATA-powers/POWER_LISTEN', targets_for(m))

    def test_trace_targets_are_durable_discussion_targets(self):
        model = copy.deepcopy(self.model)
        model['delivery'] = {group: [{'id': prefix + '-TEST', 'title': '追踪对象'}]
                             for group, prefix in zip(DELIVERY_GROUPS, ['REQ', 'SET', 'TASK', 'ACC'])}
        targets = targets_for(model)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'feedback.json'
            path.write_text('{"schemaVersion":1,"revision":0,"items":[]}')
            items = [{**note(prefix + '-TEST'), 'id': 'DISC-' + prefix} for prefix in ['REQ', 'SET', 'TASK', 'ACC']]
            result = FeedbackStore(path).save(0, items, targets)
            self.assertEqual(result['items'], items)
        self.assertEqual(model['delivery']['tasks'][0], {'id': 'TASK-TEST', 'title': '追踪对象'})

    def test_missing_tracking_is_visible_without_claiming_coverage(self):
        with tempfile.TemporaryDirectory() as folder:
            delivery = load_delivery(Path(folder))
            self.assertTrue(delivery['warnings'])
            self.assertEqual(delivery['requirements'], [])
            self.assertEqual(delivery['summary'], {})

    def test_trace_sources_and_evidence_are_packaged_for_offline_reading(self):
        delivery = {'requirements': [{'sources':['docs/specs/example.md']}],
                    'scenarios': [{'sources':[], 'evidence':[{'report':'docs/qa/result.json','check':'SIM-TEST'}]}],
                    'reports': [{'path':'docs/qa/result.json'}]}
        self.assertEqual(delivery_sources(delivery), {'docs/implementation/traceability.json','docs/specs/example.md','docs/qa/result.json'})
        model = copy.deepcopy(self.model)
        model['delivery'] = delivery
        model['documents']['docs/qa/result.json'] = '{"checks":[{"id":"SIM-TEST","status":"pass"}]}'
        output = render_snapshot(model)
        self.assertIn('实施追踪', output)
        self.assertIn('SIM-TEST', output)
        self.assertIn('docs/qa/result.json', output)

    def test_offline_snapshot_contains_no_external_dependency(self):
        model = copy.deepcopy(self.model)
        model['documents']['test'] = '</script><script>bad()</script>'
        output = render_snapshot(model)
        self.assertNotIn('<script>bad()', output)
        self.assertNotIn('src="/app.js"', output)
        self.assertNotIn('href="/style.css"', output)
        self.assertNotIn("from './logic.mjs'", output)
        self.assertIn('\\u003c/script>', output)

    def test_source_paths_cannot_escape_the_project(self):
        for path in ['../outside.md', '/etc/passwd']:
            with self.assertRaises(ValueError): project_path(ROOT, path)
        self.assertEqual(project_path(ROOT, 'docs/gdd-core.md'), ROOT / 'docs/gdd-core.md')

    def test_source_change_is_flagged_without_mutating_baseline(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            # Only the known read-only source set is needed in this isolated tree.
            paths = {s['path'] for f in self.model['features'] for s in f['sources']}
            paths |= delivery_sources(self.model.get('delivery', {}))
            paths |= {str(ATLAS / p) for p in ['atlas.json','features/core.json','evidence.json','relationships.json','paths.json','phases.json','snapshot.json']}
            for rel in paths:
                if not (ROOT / rel).exists(): continue
                dest = root / rel; dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / rel, dest)
            before = load_model(root)
            file = root / 'data/run_parameters.csv'
            file.write_text(file.read_text().replace('initial_faith,start,18,','initial_faith,start,19,'))
            after = load_model(root)
            self.assertIn('data/run_parameters.csv', after['meta']['changed'])
            self.assertNotEqual(before['meta']['revision'], after['meta']['revision'])
            row = next(r for r in after['tables']['run_parameters']['rows'] if r['id'] == 'initial_faith')
            self.assertEqual(row['value'], '19')


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / 'feedback.json'
        self.path.write_text(json.dumps({'schemaVersion':1,'revision':0,'items':[]}))
        self.store = FeedbackStore(self.path)

    def tearDown(self): self.tmp.cleanup()

    def test_atomic_save_and_reload(self):
        result = self.store.save(0, [note()], {'MECH-ANCHORS'})
        self.assertEqual(FeedbackStore(self.path).read(), result)
        self.assertEqual(result['revision'], 1)
        self.assertEqual(list(self.path.parent.glob('*.tmp')), [])

    def test_stale_writer_cannot_overwrite(self):
        self.store.save(0, [note()], {'MECH-ANCHORS'})
        with self.assertRaises(RuntimeError): self.store.save(0, [], {'MECH-ANCHORS'})
        self.assertEqual(len(self.store.read()['items']), 1)

    def test_invalid_schema_and_duplicate_ids_leave_file_unchanged(self):
        original = self.path.read_bytes()
        for bad in [[note('UNKNOWN')], [note(), note()], [{**note(), 'body':3}], [{**note(), 'status':'adopted'}], [{**note(), 'execute':'bad'}]]:
            with self.assertRaises(ValueError): self.store.save(0, bad, {'MECH-ANCHORS'})
            self.assertEqual(self.path.read_bytes(), original)


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        folder = self.root / ATLAS; folder.mkdir(parents=True)
        (folder / 'feedback.json').write_text('{"schemaVersion":1,"revision":0,"items":[]}')
        self.server = ThreadingHTTPServer(('127.0.0.1',0),make_handler(self.root,'test-token'))
        self.thread = threading.Thread(target=self.server.serve_forever,daemon=True); self.thread.start()

    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join(); self.tmp.cleanup()

    def call(self, method, path, body=None, headers=None):
        connection=http.client.HTTPConnection('127.0.0.1',self.server.server_port)
        connection.request(method,path,body,headers or {})
        response=connection.getresponse(); result=(response.status,response.read()); connection.close(); return result

    def test_page_and_module_are_available_but_project_files_are_not(self):
        self.assertEqual(self.call('GET','/')[0],200)
        self.assertEqual(self.call('GET','/logic.mjs')[0],200)
        self.assertEqual(self.call('GET','/../../CLAUDE.md')[0],404)

    def test_live_model_endpoint_includes_read_only_tracking(self):
        self.server.RequestHandlerClass = make_handler(ROOT, 'test-token')
        status, body = self.call('GET', '/api/model')
        self.assertEqual(status, 200)
        model = json.loads(body)
        self.assertIn('delivery', model)
        self.assertEqual(model['delivery']['schemaVersion'], 1)
        self.assertTrue(all(group in model['delivery'] for group in DELIVERY_GROUPS))

    def test_cross_origin_and_rebinding_are_rejected(self):
        self.assertEqual(self.call('GET','/api/feedback',headers={'Host':'attacker.invalid'})[0],403)
        self.assertEqual(self.call('POST','/api/feedback','{}',{'Origin':'https://attacker.invalid'})[0],403)

    def test_malformed_json_body_does_not_crash_handler(self):
        headers={'Origin':f'http://127.0.0.1:{self.server.server_port}','X-Workbench-Token':'test-token','Content-Type':'application/json'}
        self.assertEqual(self.call('POST','/api/feedback','[]',headers)[0],400)


if __name__ == '__main__': unittest.main(verbosity=2)
