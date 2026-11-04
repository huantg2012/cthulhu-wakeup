import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { check, record, DEFAULT_MANIFEST } from './design_sync.mjs';

function fixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), 'echoes-design-sync-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const put = (file, text) => { mkdirSync(path.dirname(path.join(root, file)), { recursive: true }); writeFileSync(path.join(root, file), text); };
  put('sample/scene.gd', 'initial scene');
  put('sample/scene.tscn', 'initial nodes');
  put('sample/nested/new_component.gd', 'nested production source');
  put('sample/ignored_probe.gd', 'diagnostic');
  put('sample/restoration_capture.gd', 'capture only');
  put('sample/capture.gd', 'capture only');
  put('art/icon.svg', '<svg/>');
  put('docs/visual.md', 'V1 initial design');
  put('docs/components.md', 'C06 initial design');
  put('evidence/world.png', 'image fixture');
  const config = {
    schemaVersion: 1,
    sources: [
      { path: 'sample', include: ['**/*.gd', '**/*.tscn'], exclude: ['**/*_probe.gd', '**/*_capture.gd', '**/capture.gd'] },
      { path: 'art/icon.svg' },
    ],
    documents: ['docs/visual.md', 'docs/components.md'],
    evidence: ['evidence/world.png'],
  };
  put(DEFAULT_MANIFEST, JSON.stringify(config));
  const init = () => record({ root, initialize: true, note: 'Initial current design', sections: 'V1,C06' });
  const update = () => record({ root, note: 'World card design adjustment', sections: 'V1,C06' });
  const manifest = () => JSON.parse(readFileSync(path.join(root, DEFAULT_MANIFEST), 'utf8'));
  return { root, put, init, update, manifest };
}

test('explicit initialization and recorded baseline agree', t => {
  const f = fixture(t);
  assert.equal(check(f.root).initialized, false);
  assert.throws(f.update, /--init/);
  assert.throws(() => record({ root: f.root, initialize: true, sections: 'V1' }), /--note/);
  assert.throws(() => record({ root: f.root, initialize: true, note: 'Initial' }), /--sections/);
  f.init();
  assert.equal(check(f.root).ok, true);
  assert.equal(check(f.root).counts.sources, 4);
  assert.throws(f.init, /Already initialized/);
  assert.throws(f.update, /Nothing changed/);
});

test('source change blocks until design changes and explicit recording', t => {
  const f = fixture(t); f.init();
  f.put('sample/scene.gd', 'modified scene');
  assert.equal(check(f.root).ok, false);
  assert.throws(f.update, /no managed design document changed/);
  f.put('docs/visual.md', 'V1 updated scene design');
  assert.equal(check(f.root).ok, false);
  assert.equal(f.update().revision, 2);
  assert.equal(check(f.root).ok, true);
  assert.deepEqual(f.manifest().snapshot.changed.sources, ['sample/scene.gd']);
  assert.deepEqual(f.manifest().snapshot.changed.documents, ['docs/visual.md']);
  assert.deepEqual(f.manifest().snapshot.sections, ['V1', 'C06']);
  assert.match(f.manifest().snapshot.recordedAt, /^\d{4}-/);
});

test('recursive additions and deletions cannot silently disappear', t => {
  const f = fixture(t); f.init();
  f.put('sample/deep/new/actual_component.gd', 'new source');
  rmSync(path.join(f.root, 'sample/nested/new_component.gd'));
  const result = check(f.root);
  assert.equal(result.ok, false);
  assert.deepEqual(result.changes.sources, ['sample/deep/new/actual_component.gd', 'sample/nested/new_component.gd']);
  assert.throws(f.update, /no managed design document changed/);
  f.put('docs/components.md', 'C06 updated components'); f.update();
  assert.equal(check(f.root).ok, true);
});

test('only explicitly excluded diagnostic patterns are excluded', t => {
  const f = fixture(t); f.init();
  f.put('sample/ignored_probe.gd', 'changed diagnostic');
  f.put('sample/restoration_capture.gd', 'changed capture');
  f.put('sample/capture.gd', 'changed capture');
  assert.equal(check(f.root).ok, true);
  f.put('sample/probe_component.gd', 'real production component');
  f.put('sample/nested/capture_effect.gd', 'real production effect');
  assert.deepEqual(check(f.root).changes.sources, ['sample/nested/capture_effect.gd', 'sample/probe_component.gd']);
});

test('changing managed path configuration also needs a design update', t => {
  const f = fixture(t); f.init();
  const config = f.manifest(); config.sources[0].exclude.push('scene.gd');
  f.put(DEFAULT_MANIFEST, JSON.stringify(config));
  assert.equal(check(f.root).changes.config, true);
  assert.throws(f.update, /no managed design document changed/);
});

test('document-only edits require recording; evidence-only differences are reported', t => {
  const f = fixture(t); f.init();
  f.put('evidence/world.png', 'new rendering');
  assert.equal(check(f.root).ok, true);
  assert.deepEqual(check(f.root).changes.evidence, ['evidence/world.png']);
  f.update(); assert.deepEqual(check(f.root).changes.evidence, []);
  f.put('docs/visual.md', 'V1 clarified design without sample change');
  assert.equal(check(f.root).ok, false); f.update(); assert.equal(check(f.root).ok, true);
});

test('absolute paths, traversal, and symlink escape are rejected', t => {
  const f = fixture(t);
  for (const unsafe of ['../outside.gd', '/tmp/outside.gd', 'sample/../outside.gd', 'sample\\outside.gd']) {
    const config = f.manifest(); config.sources[0].path = unsafe; f.put(DEFAULT_MANIFEST, JSON.stringify(config));
    assert.throws(() => check(f.root), /repository-relative path/);
  }
  const config = f.manifest(); config.sources[0].path = 'sample'; f.put(DEFAULT_MANIFEST, JSON.stringify(config));
  symlinkSync(path.join(f.root, 'docs/visual.md'), path.join(f.root, 'sample/linked.gd'));
  assert.throws(() => check(f.root), /Symlinks/);
});

test('missing required documents, evidence, or empty source groups fail clearly', t => {
  const f = fixture(t);
  rmSync(path.join(f.root, 'docs/visual.md'));
  assert.throws(f.init, /Required path is missing: docs\/visual.md/);
  f.put('docs/visual.md', 'restored');
  rmSync(path.join(f.root, 'evidence/world.png'));
  assert.throws(f.init, /Required path is missing: evidence\/world.png/);
  f.put('evidence/world.png', 'restored');
  const config = f.manifest(); config.sources[0].include = ['**/*.not-a-real-type'];
  f.put(DEFAULT_MANIFEST, JSON.stringify(config));
  assert.throws(f.init, /matches no files/);
});
