const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const D = require('./world-trace-data.js');
const copy = value => JSON.parse(JSON.stringify(value));
const find = (snapshot, id) => snapshot.find(e => e.id === id);

for (const [name, record] of [['opening', D.opening()], ['middle40', D.middle(40)], ['middle120', D.middle(120)]]) {
  test(name + ': record is serializable, ordered and references existing objects', () => {
    assert.deepEqual(D.validate(record), []);
    assert.deepEqual(D.validate(copy(record)), []);
    assert.equal(D.snapshots(record).length, record.steps.length);
  });
  test(name + ': population stays conserved in every observation point', () => {
    D.snapshots(record).forEach(({ after }, index) => {
      after.filter(e => e.type === 'population').forEach(e => {
        const f = e.fields;
        assert.equal(f.total, f.nonfollowers + f.followers + f.named, index + ': ' + e.id);
        assert.equal(after.filter(p => p.type === 'person' && p.domain === e.domain && p.fields.status !== 'dead').length, f.named, index + ': named ' + e.id);
      });
    });
  });
  test(name + ': moving through the record never mutates its initial snapshot', () => {
    const before = copy(record);
    const states = D.snapshots(record);
    states[0].after[0].fields.seed = 'unrelated inspection';
    assert.deepEqual(record, before);
    assert.notEqual(D.snapshots(record)[0].after[0].fields.seed, 'unrelated inspection');
  });
}

test('opening: bootstrap nominates, it does not add to population', () => {
  const states = D.snapshots(D.opening());
  assert.equal(find(states[2].after, 'DEMO-D01-POP').fields.named, 6);
  assert.equal(find(states[3].after, 'DEMO-D01-POP').fields.named, 7);
  assert.equal(find(states[3].after, 'DEMO-D01-POP').fields.nonfollowers, 993);
  assert.equal(find(states[3].after, 'DEMO-P7').fields.member, false);
  assert.equal(find(states[3].after, 'DEMO-P7').fields.identified, false);
});

test('opening: PR08 shallow ordinary success matches authored effects', () => {
  const state = D.snapshots(D.opening())[6].after;
  const person = find(state, 'DEMO-P7').fields;
  assert.equal(person.sanity, 72);
  assert.equal(person.loyalty, 40);
  assert.equal(person.member, true);
  assert.equal(person.identified, true);
  assert.equal(find(state, 'DEMO-WALLET').fields.faith, 18);
  assert.equal(find(state, 'DEMO-WALLET').fields.whispers, 2);
  assert.equal(find(state, 'DEMO-D01').fields.pollution, 2);
  assert.equal(find(state, 'DEMO-D01').fields.alert, 0);
  assert.equal(find(state, 'DEMO-D01-POP').fields.followers, 0);
  assert.equal(state.filter(e => e.type === 'cult').length, 0);
});

test('opening: member, knowledge and next executable contact are not conflated', () => {
  const state = D.snapshots(D.opening()).at(-1).after;
  assert.equal(find(state, 'DEMO-P7').fields.loyalty, 44);
  assert.equal(find(state, 'DEMO-P7').fields.sanity, 70);
  assert.equal(find(state, 'DEMO-CONTROL').fields.disconnected, 1);
  assert.equal(find(state, 'DEMO-CONTROL').fields.ending, '进行中');
  assert.equal(find(state, 'DEMO-PR08').fields.status, '已回应并关闭');
});

test('middle: private event records a choice without applying public branch effects', () => {
  const states = D.snapshots(D.middle(40));
  const before = states[2].before, after = states[2].after;
  assert.equal(find(after, 'DEMO-M-EVENT02').fields.choice, 'A保密');
  assert.equal(find(after, 'DEMO-M-PRIVATE').type, 'fact');
  assert.equal(find(after, 'DEMO-WALLET').fields.faith, find(before, 'DEMO-WALLET').fields.faith);
  assert.equal(find(after, 'DEMO-D01').fields.alert, 70);
  assert.equal(find(after, 'DEMO-CONTROL').fields.replies, 0);
});

test('middle: background member still acts while background daily is skipped', () => {
  const states = D.snapshots(D.middle(40));
  const after = states[6].after;
  assert.equal(find(after, 'DEMO-D07').fields.focus, false);
  assert.equal(find(after, 'DEMO-B-GUARD').fields.sanity, 53);
  assert.equal(find(after, 'DEMO-D07').fields.barrier, 50);
  assert.equal(find(after, 'DEMO-D07').fields.alert, 70);
  assert.equal(find(after, 'DEMO-D01').fields.barrier, 51);
  assert.equal(find(after, 'DEMO-D01').fields.alert, 66);
});

test('middle: both domains settle upkeep, attrition and income once', () => {
  const states = D.snapshots(D.middle(40));
  assert.equal(find(states[4].after, 'DEMO-WALLET').fields.faith, 7);
  assert.equal(find(states[7].after, 'DEMO-WALLET').fields.faith, 13);
  for (const id of ['DEMO-D01', 'DEMO-D07']) {
    assert.equal(find(states[6].after, id + '-POP').fields.followers, 24);
    assert.equal(find(states[6].after, id + '-ECO').fields.incomeEligible, 24);
    assert.equal(find(states[6].after, id + '-ECO').fields.attritionRemainder, 0);
    assert.equal(find(states[7].after, id + '-ECO').fields.income, Math.floor(Math.sqrt(24) * 0.8));
  }
});

test('middle: the announced consequence does not wait for background daily', () => {
  const state = D.snapshots(D.middle(40)).at(-1).after;
  assert.equal(find(state, 'DEMO-D07-POP').fields.total, 995);
  assert.equal(find(state, 'DEMO-D07-POP').fields.followers, 19);
  assert.equal(find(state, 'DEMO-D07-CULT').fields.cohesion, 70);
  assert.equal(find(state, 'DEMO-B-GUARD').fields.status, 'active');
  assert.equal(find(state, 'DEMO-D07-CLOCK').fields.nextSlot, 42);
});

test('arbitrary n rebases deadlines without inventing simulated history', () => {
  const r = D.middle(187);
  assert.equal(r.kind, 'rule-walkthrough');
  assert.equal(r.steps[0].turn, 187);
  const state = D.snapshots(r).at(-1).after;
  assert.equal(find(state, 'DEMO-B-PURGE').fields.due, 188);
  assert.equal(find(state, 'DEMO-D07-CLOCK').fields.nextSlot, 189);
  assert.match(r.description, /不运行或重抽游戏/);
});

test('all rule/task/report links in the teaching data resolve within the repository', () => {
  const root = path.resolve(__dirname, '../..');
  for (const source of Object.values(D.sources)) for (const k of ['rule', 'report', 'supplement']) {
    if (source[k]) assert.ok(fs.existsSync(path.join(root, source[k])), source[k]);
  }
  const tasks = new Set(JSON.parse(fs.readFileSync(path.join(root, 'docs/implementation/traceability.json'), 'utf8')).tasks.map(t => t.id));
  for (const source of Object.values(D.sources)) for (const id of source.tasks) assert.ok(tasks.has(id), id);
});

test('unknown values remain null rather than being silently converted to zero', () => {
  const r = D.opening();
  assert.equal(find(D.snapshots(r)[1].after, 'DEMO-D02-CLOCK').fields.rng, null);
  assert.equal(find(D.snapshots(r)[0].after, 'DEMO-CONFIG').fields.seed, null);
});

test('wrong previous values, missing values and out-of-order phases are rejected', () => {
  let r = D.middle(40); const c = r.steps.flatMap(s => s.changes).find(c => c.op === 'set'); c.before = 'wrong';
  assert.ok(D.validate(r).some(e => /前值/.test(e)));
  r = D.middle(40); delete r.steps.flatMap(s => s.changes).find(c => c.op === 'set').after;
  assert.ok(D.validate(r).some(e => /字段/.test(e)));
  r = D.middle(40); r.steps[8].phase = 1;
  assert.ok(D.validate(r).some(e => /时序/.test(e)));
});

test('malformed and potentially unsafe imported records are rejected without throwing', () => {
  for (const value of [null, {}, { schemaVersion: 1 }, ['bad'], JSON.parse('{"schemaVersion":1,"__proto__":{"polluted":true}}')]) {
    assert.ok(D.validate(value).length);
  }
  let r = D.middle(40); r.steps[2] = null; assert.ok(D.validate(r).length);
  r = D.middle(40); r.provenance.missing = 'not an array'; assert.ok(D.validate(r).length);
  r = D.middle(40); r.initial[0].refs = [{ target: 'missing', label: 'dangling' }]; assert.ok(D.validate(r).length);
  r = D.middle(40); r.initial.push(copy(r.initial[0])); assert.ok(D.validate(r).length);
  assert.equal({}.polluted, undefined);
});

test('renderer and data are local assets in the single systems-map entry', () => {
  const html = fs.readFileSync(path.resolve(__dirname, '../../systems-map.html'), 'utf8');
  for (const asset of ['world-trace-data.js', 'world-trace-view.js', 'world-trace.css']) assert.ok(html.includes('tools/systems-map/' + asset));
  assert.equal((html.match(/id="world-trace"/g) || []).length, 1);
  assert.match(html, /data-page="世界循环">\s*<div id="world-trace"/);
});

test('only overview, turn atlas and world cycle belong to the active document', () => {
  const html = fs.readFileSync(path.resolve(__dirname, '../../systems-map.html'), 'utf8');
  const active = html.replace(/<template\b[^>]*>[\s\S]*?<\/template>/g, '');
  const pages = Array.from(active.matchAll(/<div class="page" data-page="([^"]+)"/g), m => m[1]);
  assert.deepEqual(pages, ['全貌', '整轮运行总图', '世界循环']);
  assert.ok(!active.includes('查看机制深潜'));
  assert.ok(active.includes('查看世界循环'));
  assert.ok(active.includes("if(name === '分层模拟') name = '世界循环'"));
  assert.ok(active.includes('goTab(saved || names[0])'));
});

test('day theme and full-width layout are shared by the three retained pages', () => {
  const html = fs.readFileSync(path.resolve(__dirname, '../../systems-map.html'), 'utf8');
  const css = fs.readFileSync(path.resolve(__dirname, 'world-trace.css'), 'utf8');
  assert.match(html, /color-scheme:\s*light/);
  assert.match(html, /\.wrap\{width:100%;max-width:none;/);
  assert.match(html, /--page-gutter:clamp\(12px,1\.25vw,24px\)/);
  assert.ok(!html.includes('color:#0e1117'));
  assert.match(css, /\.wt-inspector\{[^}]*background:var\(--surface\)/);
});

test('rule wording matches reviewed sources instead of earlier page explanations', () => {
  const data = fs.readFileSync(path.resolve(__dirname, 'world-trace-data.js'), 'utf8');
  const view = fs.readFileSync(path.resolve(__dirname, 'world-trace-view.js'), 'utf8');
  assert.ok(!data.includes('新有限关系网仍是设计'));
  assert.ok(!data.includes('生命周期与恢复仍待后继'));
  assert.ok(!data.includes('退出详细不删ID，不清关系、不使圣物无主'));
  assert.match(data, /初始化与生命周期已接入，完整 Session 与自然来源未验/);
  assert.match(data, /20 族已绑定/);
  assert.match(data, /全详细参考基线套件/);
  assert.match(data, /仅共享游标到期才查/);
  assert.match(view, /实际已安装 B 族数/);
  assert.match(view, /真实来源提交或身份告知回执才消费等待票/);
  const planned = D.types.find(t => t.id === 'planned');
  assert.ok(!planned.meaning.includes('关系图的生命周期与恢复'));
  const domain = D.types.find(t => t.id === 'domain');
  assert.ok(domain.meaning.includes('权力组织') && domain.meaning.includes('现实矛盾'));
  const relation = D.types.find(t => t.id === 'relation');
  assert.ok(!relation.meaning.includes('仍是设计'));
});

test('domain names consistently separate instance number, blueprint and teaching alias', () => {
  const domains = D.snapshots(D.opening())[1].after.filter(e => e.type === 'domain');
  assert.equal(domains.length, 12);
  domains.forEach((e, i) => assert.equal(e.label, '域' + String(i + 1).padStart(2, '0') + ' · ' + e.fields.profile));
  assert.match(domains[0].fields.exampleRole, /甲域/);
  assert.match(domains[6].fields.exampleRole, /乙域/);
  assert.equal(domains[0].fields.profile, domains[3].fields.profile);
  assert.notEqual(domains[0].id, domains[3].id);
});

test('all eight civilization weakness explanations correspond to authored CSV identities', () => {
  const csv = fs.readFileSync(path.resolve(__dirname, '../../data/civilization_profiles.csv'), 'utf8').trim().split(/\r?\n/).slice(1);
  assert.equal(D.weaknesses.length, 8);
  for (const row of csv) {
    const columns = row.split(',');
    const item = D.weaknesses.find(w => w.id === columns[9]);
    assert.ok(item, columns[9]);
    assert.equal(item.profile, columns[1]);
    assert.ok(item.meaning && item.opportunity);
  }
  const domains = D.snapshots(D.opening())[1].after.filter(e => e.type === 'domain');
  domains.forEach(e => assert.ok(D.weaknesses.some(w => w.name === e.fields.weakness && w.profile === e.fields.profile)));
  assert.equal(D.weaknesses.find(w => w.id === 'shared_channel').name, '共享通道');
});

test('a due background domain uses one slot for daily work and new opportunities', () => {
  const r = D.opening(), states = D.snapshots(r);
  const before = find(states[1].after, 'DEMO-D02-CLOCK').fields;
  assert.equal(before.nextSlot, 1);
  assert.ok(!('nextDaily' in before) && !('nextOpportunity' in before));
  const after = find(states[7].after, 'DEMO-D02-CLOCK').fields;
  assert.equal(after.nextSlot, 5);
  assert.match(after.bResult, /未中/);
  assert.equal(find(states[7].after, 'DEMO-D02').fields.barrier, 51);
  assert.equal(r.steps[7].changes.filter(c => c.id === 'DEMO-D02-CLOCK' && c.field === 'nextSlot').length, 1);
});

test('P, future N reservation and local L remain distinct in the first fixed prayer', () => {
  const state = D.snapshots(D.opening())[3].after;
  const a = find(state, 'DEMO-ATT').fields;
  assert.deepEqual(a.temporary, ['DEMO-P7']);
  assert.deepEqual(a.reservedMembers, ['DEMO-P7']);
  assert.deepEqual(a.members, []);
  assert.equal(a.locals.length, 6);
  assert.ok(!a.locals.includes('DEMO-P7'));
  assert.match(D.attentionRoles.find(r => r.code === 'P').capacity, /全局最多12/);
  assert.match(D.attentionRoles.find(r => r.code === 'L').capacity, /每个重点域最多6/);
});
