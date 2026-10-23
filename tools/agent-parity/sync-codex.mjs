#!/usr/bin/env node
// Generate Codex's native TOML agents from the shared Markdown definitions.
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const source = join(root, '.claude/agents');
const target = join(root, '.codex/agents');
const mode = process.argv.slice(2);
if (mode.length !== 1 || !['--write', '--check'].includes(mode[0])) {
  console.error('Usage: node tools/agent-parity/sync-codex.mjs --write|--check');
  process.exit(2);
}
const writing = mode[0] === '--write';
const files = (await readdir(source)).filter(f => f.endsWith('.md')).sort();
if (!files.length) throw new Error('No source agents found');
if (writing) await mkdir(target, { recursive: true });
const expected = new Set();
const errors = [];
for (const file of files) {
  const text = (await readFile(join(source, file), 'utf8')).replace(/\r\n/g, '\n');
  const match = /^---\n([\s\S]*?)\n---\n?/.exec(text);
  if (!match) throw new Error(`${file}: missing frontmatter`);
  const name = /^name: ([a-z][a-z0-9-]*)$/m.exec(match[1])?.[1];
  const descriptionLine = /^description: (".*")$/m.exec(match[1])?.[1];
  if (!name || !descriptionLine || file !== `${name}.md`) {
    throw new Error(`${file}: unsupported name/description format`);
  }
  const description = JSON.parse(descriptionLine);
  const body = text.slice(match[0].length);
  if (body.includes("'''")) throw new Error(`${file}: literal TOML delimiter in body`);
  const filename = `${name}.toml`;
  expected.add(filename);
  const output = `# Generated from .claude/agents/${file}; do not edit directly.\n`
    + '# Regenerate: node tools/agent-parity/sync-codex.mjs --write\n'
    + '# Model and permissions follow the parent/runtime defaults.\n'
    + `name = ${JSON.stringify(name)}\ndescription = ${JSON.stringify(description)}\n`
    + `developer_instructions = '''\n${body}'''\n`;
  if (writing) await writeFile(join(target, filename), output);
  else if (await readFile(join(target, filename), 'utf8').catch(() => null) !== output) {
    errors.push(`${filename}: missing or stale; run sync-codex.mjs --write`);
  }
}
for (const file of await readdir(target).catch(() => [])) {
  if (file.endsWith('.toml') && !expected.has(file)) errors.push(`${file}: unexpected agent (remove or migrate explicitly)`);
}
if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log(`Codex agents ${writing ? 'generated' : 'verified'} (${expected.size})`);
