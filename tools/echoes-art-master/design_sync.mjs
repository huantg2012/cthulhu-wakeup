#!/usr/bin/env node
/** Track the reviewed relationship between this sample and its living design docs.
 * Hash agreement proves a recorded update, never aesthetic approval or semantic correctness.
 * Usage: node tools/echoes-art-master/design_sync.mjs [--check]
 *        node tools/echoes-art-master/design_sync.mjs --init|--record --note 'why' --sections 'V1,C06'
 */
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, readdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEFAULT_MANIFEST = 'docs/art/echoes-ui/design-sync.json';
const DEFAULT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const digest = value => createHash('sha256').update(value).digest('hex');
const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => a.localeCompare(b)));
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? sorted(Object.fromEntries(Object.entries(value).map(([key, item]) => [key, canonical(item)]))) : value;
const hashObject = value => digest(JSON.stringify(canonical(value)));

function relativePath(value, label = 'path') {
  if (typeof value !== 'string' || !value || value.includes('\\') || value.includes('\0') || path.posix.isAbsolute(value) || value.split('/').some(part => !part || part === '.' || part === '..') || /^[A-Za-z]:/.test(value)) {
    throw new Error(`${label} must be a normalized repository-relative path: ${String(value)}`);
  }
  return value;
}

function safePath(root, relative) {
  relativePath(relative);
  const parts = relative.split('/');
  let current = root;
  for (const part of parts) {
    current = path.join(current, part);
    if (!existsSync(current)) throw new Error(`Required path is missing: ${relative}`);
    if (lstatSync(current).isSymbolicLink()) throw new Error(`Symlinks are not allowed in managed paths: ${relative}`);
  }
  return current;
}

function pattern(value) {
  if (typeof value !== 'string' || !value || value.includes('\\') || value.startsWith('/') || value.split('/').some(part => part === '..' || part === '.' || !part)) {
    throw new Error(`Invalid include/exclude glob: ${String(value)}`);
  }
  let regex = '^';
  for (let i = 0; i < value.length; i++) {
    const ch = value[i];
    if (ch === '*' && value[i + 1] === '*') {
      i++;
      if (value[i + 1] === '/') { regex += '(?:.*/)?'; i++; }
      else regex += '.*';
    } else if (ch === '*') regex += '[^/]*';
    else if (ch === '?') regex += '[^/]';
    else regex += ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(regex + '$');
}

function listFiles(root, relative) {
  const absolute = safePath(root, relative);
  if (lstatSync(absolute).isFile()) return [relative];
  if (!lstatSync(absolute).isDirectory()) throw new Error(`Managed path is neither file nor directory: ${relative}`);
  const files = [];
  for (const entry of readdirSync(absolute, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    if (entry.isSymbolicLink()) throw new Error(`Symlinks are not allowed in managed paths: ${relative}/${entry.name}`);
    if (entry.isDirectory()) files.push(...listFiles(root, `${relative}/${entry.name}`));
    else if (entry.isFile()) files.push(`${relative}/${entry.name}`);
  }
  return files;
}

function fileHashes(root, files) {
  return sorted(Object.fromEntries(files.map(file => {
    const absolute = safePath(root, file);
    if (!lstatSync(absolute).isFile()) throw new Error(`Expected a file: ${file}`);
    return [file, digest(readFileSync(absolute))];
  })));
}

function configuration(manifest) {
  if (manifest.schemaVersion !== 1) throw new Error('Expected schemaVersion: 1');
  if (!Array.isArray(manifest.sources) || !manifest.sources.length) throw new Error('sources must contain explicit managed paths');
  if (!Array.isArray(manifest.documents) || !manifest.documents.length) throw new Error('documents must contain the living design documents');
  if (!Array.isArray(manifest.evidence)) throw new Error('evidence must be an array of explicit file paths');
  for (const file of [...manifest.documents, ...manifest.evidence]) relativePath(file);
  if (new Set(manifest.documents).size !== manifest.documents.length || new Set(manifest.evidence).size !== manifest.evidence.length) throw new Error('Duplicate document/evidence paths');
  for (const source of manifest.sources) {
    relativePath(source.path, 'sources.path');
    for (const field of ['include', 'exclude']) {
      if (source[field] !== undefined && (!Array.isArray(source[field]) || (field === 'include' && !source[field].length))) throw new Error(`${field} must be a ${field === 'include' ? 'non-empty ' : ''}array`);
      for (const glob of source[field] ?? []) pattern(glob);
    }
  }
  return { schemaVersion: 1, sources: manifest.sources, documents: manifest.documents, evidence: manifest.evidence };
}

export function collect(root, manifest) {
  root = realpathSync(root);
  const config = configuration(manifest);
  const sourceFiles = new Set();
  for (const group of config.sources) {
    const absolute = safePath(root, group.path);
    const isFile = lstatSync(absolute).isFile();
    const includes = (group.include ?? ['**/*']).map(pattern);
    const excludes = (group.exclude ?? []).map(pattern);
    let count = 0;
    for (const file of listFiles(root, group.path)) {
      const local = isFile ? path.posix.basename(file) : file.slice(group.path.length + 1);
      if (includes.some(glob => glob.test(local)) && !excludes.some(glob => glob.test(local))) { sourceFiles.add(file); count++; }
    }
    if (!count) throw new Error(`Managed source group matches no files: ${group.path}`);
  }
  return { configHash: hashObject(config), sources: fileHashes(root, [...sourceFiles]), documents: fileHashes(root, config.documents), evidence: fileHashes(root, config.evidence) };
}

export function changedPaths(previous = {}, current = {}) {
  return [...new Set([...Object.keys(previous), ...Object.keys(current)])].sort().filter(file => previous[file] !== current[file]);
}

function load(root, manifestPath) {
  root = realpathSync(root);
  const absolute = safePath(root, manifestPath);
  const manifest = JSON.parse(readFileSync(absolute, 'utf8'));
  const current = collect(root, manifest);
  const snapshot = manifest.snapshot;
  if (snapshot && (!Number.isInteger(snapshot.revision) || snapshot.revision < 1 || !snapshot.sources || !snapshot.documents || !snapshot.evidence || !snapshot.configHash)) throw new Error('Invalid existing snapshot; do not discard it to bypass reconciliation');
  const changes = {
    config: !!snapshot && snapshot.configHash !== current.configHash,
    sources: changedPaths(snapshot?.sources, current.sources),
    documents: changedPaths(snapshot?.documents, current.documents),
    evidence: changedPaths(snapshot?.evidence, current.evidence),
  };
  return { root, absolute, manifest, current, snapshot, changes };
}

export function check(root = DEFAULT_ROOT, manifestPath = DEFAULT_MANIFEST) {
  const state = load(root, manifestPath);
  const { snapshot, changes } = state;
  return { ok: !!snapshot && !changes.config && !changes.sources.length && !changes.documents.length, initialized: !!snapshot, revision: snapshot?.revision ?? 0, changes, counts: { sources: Object.keys(state.current.sources).length, documents: Object.keys(state.current.documents).length, evidence: Object.keys(state.current.evidence).length } };
}

export function record({ root = DEFAULT_ROOT, manifestPath = DEFAULT_MANIFEST, initialize = false, note, sections }) {
  if (typeof note !== 'string' || !note.trim()) throw new Error('--note is required and must describe this update');
  const sectionList = typeof sections === 'string' ? sections.split(',').map(item => item.trim()).filter(Boolean) : [];
  if (!sectionList.length) throw new Error('--sections is required (e.g. V1,C06)');
  const state = load(root, manifestPath);
  const { snapshot, changes } = state;
  if (initialize && snapshot) throw new Error('Already initialized; use --record after updating the relevant design sections');
  if (!initialize && !snapshot) throw new Error('No snapshot exists; use --init for the first reviewed baseline');
  if (!initialize && (changes.config || changes.sources.length) && !changes.documents.length) throw new Error('Sample/configuration changed, but no managed design document changed. Update the corresponding design sections before --record.');
  if (!initialize && !changes.config && !changes.sources.length && !changes.documents.length && !changes.evidence.length) throw new Error('Nothing changed; no new record was written');
  const next = {
    revision: (snapshot?.revision ?? 0) + 1,
    recordedAt: new Date().toISOString(),
    note: note.trim(),
    sections: [...new Set(sectionList)],
    ...state.current,
    changed: changes,
  };
  const output = JSON.stringify({ ...state.manifest, snapshot: next }, null, 2) + '\n';
  const temporary = `${state.absolute}.tmp-${process.pid}`;
  writeFileSync(temporary, output, { flag: 'wx' });
  renameSync(temporary, state.absolute);
  return { revision: next.revision, changes, counts: { sources: Object.keys(next.sources).length, documents: Object.keys(next.documents).length, evidence: Object.keys(next.evidence).length } };
}

function printChanges(changes) {
  if (changes.config) console.log('Managed path configuration changed.');
  for (const kind of ['sources', 'documents', 'evidence']) {
    if (changes[kind].length) console.log(`${kind}${kind === 'evidence' ? ' (reported; evidence-only changes do not block launch)' : ''}:\n${changes[kind].map(file => '  ' + file).join('\n')}`);
  }
}

function main(args) {
  let action = 'check';
  let modeSpecified = false;
  const options = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (['--check', '--record', '--init'].includes(arg)) {
      if (modeSpecified) throw new Error('Choose one of --check, --record or --init');
      action = arg.slice(2); modeSpecified = true;
    } else if (['--note', '--sections', '--root', '--manifest'].includes(arg)) {
      if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`Missing value for ${arg}`);
      options[{ '--note': 'note', '--sections': 'sections', '--root': 'root', '--manifest': 'manifestPath' }[arg]] = args[++i];
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  if (action === 'check') {
    if (options.note || options.sections) throw new Error('--note/--sections are only used with --init or --record');
    const result = check(options.root, options.manifestPath);
    if (result.ok) console.log(`DESIGN_SYNC_OK revision ${result.revision}: ${result.counts.sources} sources, ${result.counts.documents} design docs. Recorded agreement is not visual approval.`);
    else console.error(result.initialized ? 'DESIGN_SYNC_STALE: update the affected design sections, then explicitly --record with --note and --sections.' : 'DESIGN_SYNC_UNINITIALIZED: complete the design baseline, then explicitly --init with --note and --sections.');
    printChanges(result.changes);
    process.exitCode = result.ok ? 0 : 1;
  } else {
    const result = record({ ...options, initialize: action === 'init' });
    console.log(`DESIGN_SYNC_RECORDED revision ${result.revision}. This records a documentation update, not visual approval.`);
    printChanges(result.changes);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`DESIGN_SYNC_ERROR: ${error.message}`); process.exitCode = 1; }
}
