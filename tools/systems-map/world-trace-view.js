(function () {
  'use strict';
  const D = window.WorldTraceData;
  const host = document.getElementById('world-trace');
  if (!D || !host) return;
  const esc = value => String(value == null ? '' : value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const records = { opening: D.opening(), middle: D.middle(40) };
  const sections = [['trace', '观察点推演'], ['lifecycle', '从开局走向终局'], ['general', '任意回合与接入']];
  const views = [['step', '逐阶段推演'], ['state', '此刻世界全貌'], ['compare', '重点／后台对照']];
  let active = 'opening', frame = 0, section = 'trace', view = 'step', query = '', domain = '', type = '', inspectorReturn = null;
  let snapshots = D.snapshots(records.opening);
  let imported = null;
  const saved = (() => { try { return JSON.parse(localStorage.getItem('world-trace-view-v1') || 'null'); } catch (_) { return null; } })();
  if (saved && ['opening', 'middle'].includes(saved.active)) {
    active = saved.active; frame = Number.isInteger(saved.frame) ? saved.frame : 0;
    if (views.some(v => v[0] === saved.view)) view = saved.view;
    if (sections.some(s => s[0] === saved.section)) section = saved.section;
    else if (['lifecycle', 'general'].includes(saved.view)) section = saved.view;
    if (Number.isInteger(saved.n) && saved.n >= 12 && saved.n <= 999999) records.middle = D.middle(saved.n);
    snapshots = D.snapshots(records[active]); frame = Math.max(0, Math.min(frame, snapshots.length - 1));
  }
  function record() { return active === 'imported' ? imported : records[active]; }
  function step() { return record().steps[frame]; }
  function state() { return snapshots[frame].after; }
  function find(id, list) { return (list || state()).find(e => e.id === id); }
  function typeInfo(id) { return D.types.find(t => t.id === id); }
  function name(id) { const e = find(id) || find(id, snapshots[frame].before); return e ? e.label : id; }
  function value(v) {
    if (v === null) return '<span class="wt-unknown">未采集／未计算</span>';
    if (typeof v === 'boolean') return v ? '是' : '否';
    if (Array.isArray(v)) return v.length ? v.map(x => typeof x === 'string' ? esc(name(x)) : esc(JSON.stringify(x))).join('、') : '<span class="wt-muted">明确为空</span>';
    if (v && typeof v === 'object') return esc(JSON.stringify(v));
    return v === '' ? '<span class="wt-muted">无</span>' : esc(typeof v === 'string' ? name(v) : v);
  }
  function inspectButton(id, label) { return '<button type="button" class="wt-link" data-inspect="' + esc(id) + '">' + esc(label || name(id)) + '</button>'; }
  function sourceHTML(id, globalReference) {
    const s = globalReference ? D.sources[id] : record().sources && record().sources[id] || D.sources[id];
    if (!s) return '<p class="wt-muted">这份记录未附该项来源；不据此推定机制已实现。</p>';
    const safePath = path => typeof path === 'string' && /^(docs|data)\/(?:[A-Za-z0-9_-]+\/)*[A-Za-z0-9_.-]+$/.test(path) && !path.includes('..');
    const links = [['规则位置', s.rule], ['参考报告', s.report], ['补充材料', s.supplement]].filter(x => safePath(x[1])).map(x => '<a href="' + esc(x[1]) + '" target="_blank" rel="noopener">' + x[0] + '</a>').join(' · ');
    return '<div class="wt-source"><b>' + esc(s.title) + '</b><p>' + esc(s.scope || '来源范围未提供') + '</p><div>' + links + ' <span>' + esc(s.section || '') + '</span></div>' + (Array.isArray(s.tasks) ? '<p class="wt-code">' + s.tasks.map(esc).join(' · ') + '</p>' : '') + '</div>';
  }
  function persist() { try { localStorage.setItem('world-trace-view-v1', JSON.stringify({ active, frame, section, view, n: records.middle.anchorTurn })); } catch (_) {} }
  function closeInspector(restore) {
    const panel = document.getElementById('wt-inspector');
    if (!panel || panel.hidden) return;
    panel.hidden = true;
    if (restore && inspectorReturn && document.contains(inspectorReturn)) inspectorReturn.focus();
  }
  function selectRecord(id) {
    closeInspector(false); active = id; snapshots = D.snapshots(record()); frame = 0; domain = ''; query = ''; type = ''; render();
  }
  function navigate(index) { closeInspector(false); frame = Math.max(0, Math.min(index, record().steps.length - 1)); render(); }
  function button(label, attr, selected) { return '<button type="button" class="wt-button' + (selected ? ' is-selected' : '') + '" ' + attr + '>' + esc(label) + '</button>'; }
  function summaryChanges() {
    const c = step().changes;
    return '<span>新增 <b>' + c.filter(x => x.op === 'create').length + '</b> 条记录</span><span>更新 <b>' + c.filter(x => x.op === 'set').length + '</b> 个字段</span><span>当前可查看 <b>' + state().length + '</b> 条教学／采集记录</span>';
  }
  function renderToolbar() {
    const r = record(), s = step();
    return '<header class="wt-toolbar"><div class="wt-controls"><div class="wt-example-picker" role="group" aria-label="选择世界轨迹">' + button('开局 → 第一轮', 'data-record="opening" aria-pressed="' + (active === 'opening') + '"', active === 'opening') + button('中期回合 n', 'data-record="middle" aria-pressed="' + (active === 'middle') + '"', active === 'middle') + (imported ? button('已导入记录', 'data-record="imported"', active === 'imported') : '') + '</div>' + (active === 'middle' ? '<label class="wt-turn-input">n = <input id="wt-n" type="number" min="12" max="999999" value="' + r.anchorTurn + '" aria-label="中期示例轮次" /><span>仅平移示例时点，不推进游戏</span></label>' : '') + '</div>' +
      '<div class="wt-step-control"><button type="button" class="wt-button" data-move="-1"' + (frame === 0 ? ' disabled' : '') + '>上一步</button><label class="wt-range"><span>第 ' + (frame + 1) + ' / ' + r.steps.length + ' 个观察点 · 轮 ' + s.turn + ' · ' + (s.phase ? '阶段' + s.phase : '初始化') + '</span><input type="range" min="0" max="' + (r.steps.length - 1) + '" value="' + frame + '" id="wt-position" aria-label="选择阶段观察点" /></label><button type="button" class="wt-button" data-move="1"' + (frame === r.steps.length - 1 ? ' disabled' : '') + '>下一步</button></div>' +
      '<nav class="wt-phase-nav" aria-label="轨迹阶段">' + r.steps.map((p, i) => '<button type="button" data-frame="' + i + '" class="wt-phase' + (i === frame ? ' current' : '') + '" title="' + esc(p.title) + '"' + (i === frame ? ' aria-current="step"' : '') + '><small>' + (p.phase ? p.turn + '·' + p.phase : '生成') + '</small><span>' + esc(p.title.split('：')[0].slice(0, 14)) + '</span></button>').join('') + '</nav></header>';
  }
  function renderWallet() {
    const e = state().find(x => x.type === 'wallet');
    if (!e) return '<p class="wt-muted">尚未生成本局账本。规则输入存在，不等于世界对象已经存在。</p>';
    return '<div class="wt-wallet">' + ['faith', 'whispers', 'awakening', 'insight', 'wounds'].map(k => '<div><span>' + esc(D.labels[k]) + '</span><b>' + value(e.fields[k]) + '</b></div>').join('') + '</div>';
  }
  function renderWorldMini() {
    const entities = state(), domains = entities.filter(e => e.type === 'domain');
    return '<section class="wt-world-mini"><h3>把世界留在眼前</h3>' + renderWallet() + (domains.length ? '<div class="wt-domain-map" aria-label="12域状态缩略">' + domains.map(e => '<button type="button" class="wt-domain' + (e.fields.focus ? ' focused' : '') + '" data-inspect="' + esc(e.id) + '"><b>' + esc(e.label) + '</b><small>' + esc(e.fields.tier) + ' · ' + (e.fields.focus ? '重点' : '后台') + '</small><span>屏障 ' + value(e.fields.barrier) + ' · 污染 ' + value(e.fields.pollution) + '</span></button>').join('') + '</div>' : '') +
      '<div class="wt-type-counts">' + D.types.map(t => { const count = entities.filter(e => e.type === t.id).length; return '<button type="button" data-type-jump="' + t.id + '"><span>' + esc(t.name) + '</span><b>' + count + '</b></button>'; }).join('') + '</div><p class="wt-muted">数字是这份记录中的对象数，不是引擎工作量。点类别展开字段，点对象查看来路。</p></section>';
  }
  function renderChanges() {
    const changes = step().changes, sets = changes.filter(c => c.op === 'set'), created = changes.filter(c => c.op === 'create');
    let html = '<section class="wt-change-list"><h3>这一阶段写进世界的差分</h3><p class="wt-muted">对比的是本观察点前后；顺序执行，不把同一字段的跨阶段修改当成可交换加法。</p>';
    if (sets.length) html += '<div class="wt-table-scroll"><table><thead><tr><th>对象／字段</th><th>之前</th><th>之后</th><th>为什么改变／留存</th></tr></thead><tbody>' + sets.map(c => { const e = find(c.id); return '<tr><td>' + inspectButton(c.id) + '<small>' + esc(D.labels[c.field] || c.field) + '</small></td><td>' + value(c.before) + '</td><td class="wt-changed">' + value(c.after) + '</td><td>' + esc(c.reason) + '<small>' + esc(typeInfo(e.type).life) + '</small></td></tr>'; }).join('') + '</tbody></table></div>';
    if (created.length) html += D.types.map(t => { const group = created.filter(c => c.entity.type === t.id); if (!group.length) return ''; return '<details class="wt-created"' + (group.length <= 3 ? ' open' : '') + '><summary>新增' + esc(t.name) + ' · ' + group.length + '条 <span>' + esc(t.life) + '</span></summary>' + group.map(c => '<div>' + inspectButton(c.entity.id) + '<p>' + esc(c.reason) + '</p></div>').join('') + '</details>'; }).join('');
    if (!sets.length && !created.length) html += '<p class="wt-no-change">本观察点没有新增业务状态。请看下面的跳过原因；“检查后无结果”和“根本没有执行／未采集”不是一回事。</p>';
    return html + '</section>';
  }
  function renderStep() {
    const s = step(), rule = D.phaseRules.find(p => p.phase === s.phase);
    const scopeName = { shared: '共同精确处理', detailed: '具体人物／详细处理', abstract: '到期后台日常', mixed: '多职责合并，不是一档全包' }[s.scope] || '来源未标明';
    return '<div class="wt-reading-layout"><article><div class="wt-kicker">轮 ' + s.turn + ' · ' + (s.phase ? '阶段' + s.phase : '生成过程') + ' <span class="wt-scope ' + esc(s.scope) + '">' + esc(scopeName) + '</span></div><h3 class="wt-step-title">' + esc(s.title) + '</h3><p class="wt-lead">' + esc(s.lead) + '</p><div class="wt-change-summary">' + summaryChanges() + '</div>' +
      (s.read.length ? '<div class="wt-read"><b>这一步从哪里取依据</b><div>' + s.read.map(id => inspectButton(id)).join('') + '</div></div>' : '') + renderChanges() +
      (s.skipped.length ? '<section class="wt-skipped"><h3>这一次没有发生什么／为什么</h3><ul>' + s.skipped.map(x => '<li>' + esc(x) + '</li>').join('') + '</ul></section>' : '') +
      (s.transient.length ? '<details class="wt-details"><summary>计算中经过、但不当成既成世界的东西</summary><ul>' + s.transient.map(x => '<li>' + esc(x) + '</li>').join('') + '</ul></details>' : '') +
      '<details class="wt-details"><summary>不只这一例：此阶段完整的业务覆盖</summary><p><b>读取：</b>' + esc(rule.read) + '</p><p><b>判定：</b>' + esc(rule.decide) + '</p><ul>' + rule.writes.map(x => '<li>' + esc(x) + '</li>').join('') + '</ul><p><b>留存：</b>' + esc(rule.keep) + '</p><p class="wt-muted">这张清单说明还可能发生什么，不宣称本次每条都发生。</p></details>' +
      '<details class="wt-details"><summary>规则、任务与证据范围</summary>' + sourceHTML(s.source) + '</details></article>' + renderWorldMini() + '</div>';
  }
  function filteredEntities() {
    const q = query.trim().toLowerCase();
    return state().filter(e => (!domain || e.domain === domain || e.domain === '') && (!type || e.type === type) && (!q || (e.label + ' ' + e.id + ' ' + typeInfo(e.type).name + ' ' + Object.keys(e.fields).map(k => D.labels[k] || k).join(' ') + ' ' + JSON.stringify(e.fields)).toLowerCase().includes(q)));
  }
  function renderInventory() {
    const all = state(), found = filteredEntities(), changed = new Set(step().changes.map(c => c.op === 'create' ? c.entity.id : c.id));
    return '<section><h3>此刻整个模拟世界由什么组成</h3><p>每类都列在这里：空集合是“尚未出现”，<span class="wt-unknown">未采集</span>是资料缺口，<b>规划项</b>不冒充已经运行的实体。点击任一记录可看全部字段、引用对象和每个变化的来源。</p>' +
      '<div class="wt-state-filters"><label>范围 <select id="wt-domain"><option value="">全部12域＋全局</option>' + all.filter(e => e.type === 'domain').map(e => '<option value="' + esc(e.id) + '"' + (domain === e.id ? ' selected' : '') + '>' + esc(e.label) + '</option>').join('') + '</select></label><label>对象 <select id="wt-type"><option value="">全部类别</option>' + D.types.map(t => '<option value="' + t.id + '"' + (type === t.id ? ' selected' : '') + '>' + esc(t.name) + '</option>').join('') + '</select></label><label>搜索 <input id="wt-search" type="search" value="' + esc(query) + '" placeholder="例如：第一位祈求者、余量、圣物" /></label>' + button('清除筛选', 'data-clear="true"') + '</div><p id="wt-filter-count" class="wt-muted">当前筛选 ' + found.length + ' / 本观察点 ' + all.length + ' 条。作用范围是这份记录，不等于世界所有内容都已被实机采集。</p>' +
      '<div id="wt-inventory">' + D.types.filter(t => !type || t.id === type).map(t => {
        const group = found.filter(e => e.type === t.id);
        if (!group.length && query) return '';
        return '<details class="wt-inventory-group"' + (type || query || ['person', 'wallet'].includes(t.id) ? ' open' : '') + '><summary><b>' + esc(t.name) + '</b><span>' + group.length + '条 · ' + esc(t.life) + '</span></summary><p class="wt-muted">' + esc(t.meaning) + '</p>' + (group.length ? '<div class="wt-entity-list">' + group.map(e => '<button type="button" class="wt-entity' + (changed.has(e.id) ? ' changed' : '') + '" data-inspect="' + esc(e.id) + '"><b>' + esc(e.label) + '</b><span>' + (e.domain ? esc(name(e.domain)) : '全局') + '</span><small>' + Object.keys(e.fields).length + '个字段' + (changed.has(e.id) ? ' · 本步改变' : ' · 本步未变') + '</small></button>').join('') + '</div>' : '<p>这份初态／片段中没有该类实例。类别本身仍保留，后续阶段可能创建；上方声明的未采集范围不被自动视为零。</p>') + '</details>';
      }).join('') + (!found.length && query ? '<p role="status">没有匹配的记录，请更换关键词或清除筛选。</p>' : '') + '</div></section>';
  }
  function renderComparison() {
    return '<section><h3>同一个域，哪些事情因“重点／后台”而变化</h3><p class="wt-lead">不是两套世界。域的日常更新可以降频，但人的详细覆盖、经济、既定后果各有自己的判断。</p><p class="wt-muted">这是保持其余条件相同的规则对照，不是三条已经运行的反事实录像。右侧实际状态仍来自当前选中的轨迹。</p><div class="wt-table-scroll"><table class="wt-comparison"><thead><tr><th>职责</th><th>重点域</th><th>后台 · 日常未到期</th><th>后台 · 本轮到期</th><th>必须保留的界线</th></tr></thead><tbody>' + D.compare.map(r => '<tr>' + r.map(x => '<td>' + esc(x) + '</td>').join('') + '</tr>').join('') + '</tbody></table></div>' +
      '<div class="wt-reading-layout"><article><h3>看一个真实差异，而不是看图例颜色</h3><p>在中期实例的“演化②”，乙域并不重点，但护持者属于N成员，仍从理智50恢复到53；在“演化③”，乙域日常尚未到期，所以屏障与察觉不更新。两个结论同时成立。</p>' + button('去中期演化②', 'data-jump-middle="5"') + '<h3>同一轮的新结果不能回过头决定本轮</h3><p>例如：机构选择风险时尚无确认，不能选择需要确认的清洗；同批NPC查证后来凑到强度3，也不能把已经选定的计划升级。新确认留到下一次选择，届时还要再查计划位、冷却和目标。</p>' + sourceHTML('fidelity') + '</article>' + renderWorldMini() + '</div></section>';
  }
  function renderLifecycle() {
    return '<section><h3>从开始到结束：什么数据让下一步成为可能</h3><p class="wt-lead">这不是一条保证成功的流水线。每一站只有输入条件真实齐备才会进入下一站；无法衔接的地方保留为缺口，而不是偷偷塞入剧情。</p><ol class="wt-life">' + D.lifecycle.map((p, i) => '<li><span class="wt-life-number">' + (i + 1) + '</span><div><h3>' + esc(p.title) + '</h3><div class="wt-life-flow"><div><small>已有</small>' + esc(p.input) + '</div><span aria-hidden="true">→</span><div><small>怎么变</small>' + esc(p.transition) + '</div><span aria-hidden="true">→</span><div><small>留下</small>' + esc(p.output) + '</div></div><p class="wt-caution">' + esc(p.note) + '</p><details class="wt-details"><summary>来源与实施边界</summary>' + sourceHTML(p.source, true) + '</details></div></li>').join('') + '</ol><h3>终局后的世界不是空了</h3><p>停止的是新的普通行动。人物身份、已发生因果、牺牲与锚点轨迹、种子和结果仍供回顾。读档到结束局进入回顾；重开是一份新的世界，不继承战力。</p></section>';
  }
  function renderGeneral() {
    return '<section><h3>把示例换成任意回合 n，阅读方法不变</h3><p class="wt-lead">一个观察点由“当时世界＋这一步输入＋按序变化＋来源”组成。轮号只是坐标，不是生成状态的公式。</p><div class="wt-equation">W(n,0) → 轮初 → 事件 → 玩家行动 → 预付／共同演化 → 收入／期限 → 轮末 → W(n+1,0)</div><p>每一步都取上一步的结果，逐项新增、改值、撤销资格。不能把跨阶段差分无序相加；死亡、付款、恢复或到期有先后。提交与保存是这些步骤的检查点，不是额外的第七阶段。</p>' +
      '<h3>任意一轮的完整转移约定</h3><div class="wt-table-scroll"><table><thead><tr><th>阶段</th><th>读取与判定</th><th>可能新增／改变</th><th>哪些留到以后</th></tr></thead><tbody>' + D.phaseRules.filter(p => p.phase > 0).map(p => '<tr><td>' + p.phase + ' · ' + esc(p.name) + '</td><td>' + esc(p.read) + '<p>' + esc(p.decide) + '</p></td><td><ul>' + p.writes.map(x => '<li>' + esc(x) + '</li>').join('') + '</ul></td><td>' + esc(p.keep) + '</td></tr>').join('') + '</tbody></table></div>' +
      '<h3>为未来状态跟踪器保留的接入口</h3><p>目前读的是有来源的教学记录；尚未连接Godot，也不会自动推进游戏。展示器接收同一版本的初态与有序变化，实际记录可以有任意轮号、任意数量的阶段内提交。</p><ul><li>每条记录必须声明：规则演算或实机采集、版本、来源、覆盖范围与未采集部分。</li><li>每个对象保留稳定ID、所属域、业务字段和关联对象；不同回合不会因显示顺序重新编号。</li><li>每次变更必须附之前／之后及原因；导入会核对前值与时序，缺省不能自动当成零。</li><li>导入仅为本地只读展示，不执行JSON中的内容、不发送网络请求、不修改游戏存档。</li></ul><div class="wt-controls">' + button('导出当前教学／采集记录', 'data-export="true"') + '<label class="wt-button wt-file">导入状态轨迹 JSON<input type="file" id="wt-file" accept=".json,application/json" /></label></div><p class="wt-muted">支持此展示格式v1（≤2 MiB），不声称直接兼容原始Godot存档。实时化仍需要游戏侧采集适配器与真实集成验证。</p><div id="wt-import-result" role="status"></div><details class="wt-details"><summary>查看这份记录的采集／演算范围</summary><p>' + esc(record().provenance.coverage) + '</p><ul>' + (record().provenance.missing || []).map(x => '<li>' + esc(x) + '</li>').join('') + '</ul></details></section>';
  }
  function renderObservation() {
    return view === 'step' ? renderStep() : view === 'state' ? renderInventory() : renderComparison();
  }
  function render() {
    persist();
    const observing = section === 'trace';
    const heading = '<div class="wt-heading"><div><span class="wt-kicker">世界循环 · 先区分具体状态与全局说明</span><h2>世界如何生成，又如何走完一轮</h2></div><span class="wt-badge">' + esc(observing ? record().provenance.label : '全局说明 · 不随观察点变化') + '</span></div>';
    const navigation = '<nav class="wt-section-nav" aria-label="世界循环阅读范围">' + sections.map(s => button(s[1], 'data-section="' + s[0] + '" aria-pressed="' + (section === s[0]) + '"', section === s[0])).join('') + '</nav>';
    if (!observing) {
      host.innerHTML = heading + navigation + '<p class="wt-muted">这是整局规则或展示接口的说明，不是某个观察点发生的新变化。返回“观察点推演”会保留刚才的步骤与筛选。</p><div id="wt-content">' + (section === 'lifecycle' ? renderLifecycle() : renderGeneral()) + '</div>';
      return;
    }
    host.innerHTML = heading + navigation + '<p class="wt-intro">' + esc(record().description) + '</p><p class="wt-caution">下面的时间轴与状态跟随所选记录；教学演算不是实机录像，未采集部分不补零。域01在讲解中简称甲域，域07简称乙域；它们不是特殊域类型。</p>' + renderToolbar() + '<nav class="wt-view-nav" aria-label="当前观察点的阅读视角">' + views.map(v => button(v[1], 'data-view="' + v[0] + '" aria-pressed="' + (view === v[0]) + '"', view === v[0])).join('') + '</nav><div id="wt-content">' + renderObservation() + '</div>';
  }
  const inspector = document.createElement('aside');
  inspector.id = 'wt-inspector'; inspector.className = 'wt-inspector'; inspector.hidden = true; inspector.setAttribute('role', 'dialog'); inspector.setAttribute('aria-label', '世界对象详情'); inspector.tabIndex = -1;
  document.body.appendChild(inspector);
  function renderEntityGuide(e) {
    if (e.type === 'domain') {
      const w = D.weaknesses.find(item => item.name === e.fields.weakness || item.id === e.fields.weakness);
      const current = w ? '<h3>现实矛盾：' + esc(w.name) + '</h3><p>' + esc(w.meaning) + '</p><p><b>它为什么与邪神有关：</b>' + esc(w.opportunity) + '</p>' : '';
      return '<section class="wt-entity-guide"><p><b>先分清名字：</b>域号识别本局里的一个域，后半段是文明蓝本。同一蓝本可以出现在不同域。甲／乙只是教学简称，不代表等级、阵营或模拟精度。</p>' + current + '<p class="wt-caution">现实矛盾是蓝本中“现有秩序哪里可能出现解释或维系缺口”的设计标签，不是强度，也不是自动触发器。仍要有具体人物、处境和合法来源，才可能产生祈求、材料或行动。</p><details class="wt-details"><summary>对照八种文明缺口的含义</summary><table><thead><tr><th>类型／蓝本</th><th>哪里存在张力</th><th>相关的设计机会</th></tr></thead><tbody>' + D.weaknesses.map(item => '<tr><td><b>' + esc(item.name) + '</b><small>' + esc(item.profile) + '</small></td><td>' + esc(item.meaning) + '</td><td>' + esc(item.opportunity) + '</td></tr>').join('') + '</tbody></table><p class="wt-muted">释义归纳自文明规格§3和八蓝本的进入／传播／扎根路线，不是新增机制。“共享通道”不是此前误写的“共同协议”这一缺口名。</p></details></section>';
    }
    if (e.type === 'attention') {
      return '<section class="wt-entity-guide"><h3>P和L是“为什么本轮要具体跟踪这个人”</h3><p>不是两个物种、职业或人物等级。N、P和重点域L合在一起、按身份去重后，形成详细人物集合；进入集合也不保证有合法动作。</p><div class="wt-role-guide">' + D.attentionRoles.map(r => '<div><b>' + esc(r.code + ' · ' + r.name) + '</b><small>' + esc(r.capacity) + '</small><p>' + esc(r.why) + '</p><p class="wt-muted">例如：' + esc(r.example) + '</p><details class="wt-details"><summary>何时不再靠这份名单覆盖</summary><p>' + esc(r.exit) + '</p></details></div>').join('') + '</div><p class="wt-caution">P满了只会阻挡需要新增P人物的承诺，不会让所有旧请求或候选都停下；已有N/P的人可以被合法复用，仍须检查其它容量。下面的名单不是“剩余空位”：已预留和本轮已用也要计入。</p><p>开局第4个观察点里，第一位祈求者已由P覆盖，同时预留未来N位置；这不等于已经入团。原来6位本地人物来自L，不能把他们和新祈求者都叫同一种“临时人”。</p></section>';
    }
    if (e.type === 'clock') {
      const f = e.fields;
      const next = Number.isSafeInteger(f.nextSlot) ? f.nextSlot : Number.isSafeInteger(f.nextDaily) && f.nextDaily === f.nextOpportunity ? f.nextDaily : null;
      return '<section class="wt-entity-guide"><h3>这是工作日程，不是“发卡倒计时”</h3><p>此刻是第' + step().turn + '轮；记录中的下次四轮槽为 <b>' + value(next) + '</b>。到期只表示可以尝试新处境，不表示必定有卡，更不表示人口会增长。</p><p>当前实现中，每个域保存一份到期轮。<b>新处境B和后台日常共用它</b>；不同域的相位可以不同。旧版页面把它拆成两个字段是展示失真。</p><table><thead><tr><th>工作</th><th>何时做、会得到什么</th></tr></thead><tbody><tr><td>A · 旧事后继</td><td>重点与后台每轮都查，从有限当前来源中至多提出一个合法后继；不再投出现概率。它另有续查位置，不等四轮。</td></tr><tr><td>B · 新当前处境</td><td>原到期轮到了，先找合法输入；有输入才过一次35%出现门，再选一项。可能产新处境或告知，并非直接保证固定、展示和成功回应。</td></tr><tr><td>漏选补偿与强制票</td><td>合格到期却漏选累计 1 次后取得单调唯一排队号；有强制票时按先进先出扫描至多 Q 张票（Q 为实际已安装 B 族数，当前至多 11），每票最多检查一次并跳过随机门；同槽内正常失格则保票并看下一票；至多一笔真实生产或身份告知。</td></tr><tr><td>文明日常</td><td>重点域每轮；后台到同一四轮槽才按条件算一次。B没中不妨碍日常处理，也不乘4补算。</td></tr></tbody></table><p><b>一次正常到期处理后：</b>安排下一次为“本轮＋4”。无合法输入时不掷出现骰；门未中不补抽；后续容量不足也不改抽别的人。风险、经济和原危机期限另按每轮处理。</p><details class="wt-details" open><summary>跟一场祭仪走四个时点（条件例子）</summary><p class="wt-muted">假定本例各步均合法、容量与展示位置充足；n是任意到期轮，不是声称当前记录已发生这些事。</p><ol class="wt-clock-example">' + D.clockExample.map(row => '<li><b>' + esc(row[0]) + '</b><p>' + esc(row[1]) + '</p><small>留下：' + esc(row[2]) + '</small></li>').join('') + '</ol></details><p class="wt-caution">PR08／09当下接触可直接产生求告并固定，开局引导首轮可见，不强塞进这场祭仪的n→n＋2路径。有独立危机时还要比较原期限，不为展示延长危机。机会保障已作为直接行动服务与来源补偿接入，但只给可行动机会：派发不等于已服务；只有真实来源提交或身份告知回执才消费等待票；机会等待也不是断联所需的真实接触计划。</p></section>';
    }
    if (e.type === 'source') {
      return '<section class="wt-entity-guide"><h3>材料与处境：什么时候才算“有依据”</h3>' +
        '<p>这类记录保存<b>已经成立的事实与材料</b>，不是“可能有机会”的提示。它要成为依托，通常需要具体人物、实际持有与合法途径。</p>' +
        '<table><thead><tr><th>情形</th><th>会发生什么</th></tr></thead><tbody>' +
        '<tr><td>目标结构只有记录X，外部有独立记录Y</td><td>若目标接收者尚无合法途径取得Y，可由真实递交补足；指定接收者的递交由相关操作负责。</td></tr>' +
        '<tr><td>同团跨机构：A成员持X，B成员持独立Y</td><td>A接收者确实缺Y且B能合法提供时，走已有关系／通路的内部递交，不因教团已有Y而拒绝。</td></tr>' +
        '<tr><td>接收者已具备所需Y</td><td>不得付费重复“解锁”；已有合法递交可提供同一端点时同理。</td></tr>' +
        '<tr><td>公开或秘密递交</td><td>公开递交按实际效果给接收方知情；秘密递交不自动让秩序机构获知。</td></tr>' +
        '</tbody></table>' +
        '<p class="wt-caution">20 族已绑定（8 原材料＋12 路线），4 类不受支持；自然生产仍待验。本页不把“有材料类别”当成已经成立的依托。当前仅个人转交已限定验收。</p>' +
        '</section>';
    }
    return '';
  }
  function fieldHelp(e, key) {
    if (e.type === 'attention') {
      const role = D.attentionRoles.find(r => r.key === key);
      if (role) return '<small>' + esc(role.capacity) + '</small>';
      if (key === 'reservedMembers') return '<small>为可能成为成员预留，不授予成员身份；真实人物仍可能由现有覆盖参加推演。</small>';
    }
    return '';
  }
  function openInspector(id, trigger) {
    const e = find(id) || find(id, snapshots[frame].before);
    if (!e) return;
    if (typeof window.closeDrawer === 'function') window.closeDrawer();
    inspectorReturn = trigger || inspectorReturn;
    const info = typeInfo(e.type), relatedChanges = [];
    const guide = renderEntityGuide(e);
    record().steps.slice(0, frame + 1).forEach((p, i) => p.changes.filter(c => c.op === 'create' ? c.entity.id === id : c.id === id).forEach(c => relatedChanges.push({ p, c, i })));
    inspector.innerHTML = '<button type="button" class="wt-button wt-close" data-inspector-close="true">关闭</button><span class="wt-kicker">' + esc(info.name) + ' · ' + esc(info.life) + '</span><h2>' + esc(e.label) + '</h2><p>' + esc(info.meaning) + '</p><p class="wt-muted">本页显示底层观察信息，不等于玩家可知。</p>' + (guide ? '<details class="wt-details wt-guide-toggle" open><summary>先读含义与例子（可收起）</summary>' + guide + '</details>' : '') + '<h3>此刻实际保存的数据</h3><table class="wt-fields"><tbody>' + Object.entries(e.fields).map(([k, v]) => '<tr><th>' + esc(D.labels[k] || k) + fieldHelp(e, k) + '</th><td>' + value(v) + '</td></tr>').join('') + '</tbody></table>' +
      (e.refs.length ? '<h3>它与谁／什么相连</h3><div class="wt-related">' + e.refs.map(ref => '<div>' + esc(ref.label) + ' → ' + inspectButton(ref.target) + '</div>').join('') + '</div>' : '') +
      '<h3>到此刻为止，这个对象怎样变过</h3>' + (relatedChanges.length ? '<ol class="wt-history">' + relatedChanges.map(({ p, c, i }) => '<li><button type="button" class="wt-link" data-history-frame="' + i + '">轮' + p.turn + ' · ' + (p.phase ? '阶段' + p.phase : '生成') + ' · ' + esc(p.title) + '</button><p>' + (c.op === 'create' ? '建立本对象' : esc(D.labels[c.field] || c.field) + '：' + value(c.before) + ' → ' + value(c.after)) + '</p><small>' + esc(c.reason) + '</small></li>').join('') + '</ol>' : '<p>它来自所选片段的初态，本片段尚未改变。更早历史未采集，不伪造“如何自然走到这里”。</p>') +
      '<details class="wt-details"><summary>任务、规则、证据与稳定编号</summary><p class="wt-code">' + esc(e.id) + '</p>' + sourceHTML(e.source) + '</details>';
    inspector.hidden = false; inspector.scrollTop = 0; inspector.focus({ preventScroll: true });
  }
  host.addEventListener('click', event => {
    const b = event.target.closest('button'); if (!b) return;
    if (b.dataset.section && sections.some(s => s[0] === b.dataset.section)) { closeInspector(false); section = b.dataset.section; render(); }
    else if (b.dataset.record) selectRecord(b.dataset.record);
    else if (b.dataset.move) navigate(frame + Number(b.dataset.move));
    else if (b.dataset.frame !== undefined) navigate(Number(b.dataset.frame));
    else if (b.dataset.view) { closeInspector(false); view = b.dataset.view; render(); }
    else if (b.dataset.inspect) openInspector(b.dataset.inspect, b);
    else if (b.dataset.typeJump) { type = b.dataset.typeJump; query = ''; view = 'state'; render(); }
    else if (b.dataset.clear) { type = ''; domain = ''; query = ''; render(); }
    else if (b.dataset.jumpMiddle) { selectRecord('middle'); view = 'step'; navigate(Number(b.dataset.jumpMiddle)); }
    else if (b.dataset.export) {
      const url = URL.createObjectURL(new Blob([JSON.stringify(record(), null, 2)], { type: 'application/json' }));
      const a = document.createElement('a'); a.href = url; a.download = 'world-trace-' + (active === 'middle' ? 'turn-' + record().anchorTurn : active) + '.json'; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  });
  host.addEventListener('input', event => {
    if (event.target.id === 'wt-position') { frame = Number(event.target.value); closeInspector(false); const label = host.querySelector('.wt-range span'); label.textContent = '第 ' + (frame + 1) + ' / ' + record().steps.length + ' 个观察点 · 轮 ' + step().turn + ' · ' + (step().phase ? '阶段' + step().phase : '初始化'); host.querySelectorAll('.wt-phase').forEach((b, i) => { b.classList.toggle('current', i === frame); if (i === frame) b.setAttribute('aria-current', 'step'); else b.removeAttribute('aria-current'); }); host.querySelector('[data-move="-1"]').disabled = frame === 0; host.querySelector('[data-move="1"]').disabled = frame === record().steps.length - 1; document.getElementById('wt-content').innerHTML = renderObservation(); persist(); }
    if (event.target.id === 'wt-search') { query = event.target.value; const el = document.createElement('div'); el.innerHTML = renderInventory(); document.getElementById('wt-inventory').replaceWith(el.querySelector('#wt-inventory')); document.getElementById('wt-filter-count').replaceWith(el.querySelector('#wt-filter-count')); }
  });
  host.addEventListener('change', async event => {
    const target = event.target;
    if (target.id === 'wt-n') {
      const n = Number(target.value);
      if (!Number.isSafeInteger(n) || n < 12 || n > 999999) { target.setCustomValidity('教学中期轮次需在12到999999之间；其它实际轮次可由记录导入。'); target.reportValidity(); return; }
      records.middle = D.middle(n); snapshots = D.snapshots(records.middle); render();
    } else if (target.id === 'wt-domain') { domain = target.value; render(); }
    else if (target.id === 'wt-type') { type = target.value; render(); }
    else if (target.id === 'wt-file' && target.files[0]) {
      const message = document.getElementById('wt-import-result');
      try {
        if (target.files[0].size > 2 * 1024 * 1024) throw new Error('文件超过2 MiB，请导入一个有限回合片段。');
        const parsed = JSON.parse(await target.files[0].text());
        const errors = D.validate(parsed); if (errors.length) throw new Error(errors.join('；'));
        const next = D.snapshots(parsed);
        imported = parsed; active = 'imported'; snapshots = next; frame = 0; section = 'trace'; domain = ''; query = ''; type = ''; view = 'step'; render();
      } catch (error) { message.textContent = '导入未生效，原记录保留：' + error.message; target.value = ''; }
    }
  });
  inspector.addEventListener('click', event => { const b = event.target.closest('button'); if (!b) return; if (b.dataset.inspectorClose) closeInspector(true); else if (b.dataset.inspect) openInspector(b.dataset.inspect); else if (b.dataset.historyFrame !== undefined) { view = 'step'; navigate(Number(b.dataset.historyFrame)); } });
  document.addEventListener('pointerdown', event => { if (!inspector.hidden && !inspector.contains(event.target) && !event.target.closest('[data-inspect]')) closeInspector(false); });
  document.addEventListener('focusin', event => { if (!inspector.hidden && !inspector.contains(event.target) && !event.target.closest('[data-inspect]')) closeInspector(false); });
  window.addEventListener('blur', () => closeInspector(false));
  document.addEventListener('visibilitychange', () => { if (document.hidden) closeInspector(false); });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { closeInspector(true); return; }
    if (section !== 'trace' || !host.closest('.page').classList.contains('on') || !inspector.hidden || event.ctrlKey || event.metaKey || event.altKey || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(event.target.tagName)) return;
    if (event.key === 'ArrowRight') { event.preventDefault(); navigate(frame + 1); }
    else if (event.key === 'ArrowLeft') { event.preventDefault(); navigate(frame - 1); }
  });
  window.addEventListener('systems-map-page-change', event => {
    if (event.detail !== '世界循环') {
      closeInspector(false);
      if (location.hash === '#world-trace') { try { history.replaceState(null, '', location.pathname + location.search); } catch (_) {} }
    }
  });
  function openWorldCycleFromHash() {
    if (location.hash === '#world-trace' && typeof window.goTab === 'function') window.goTab('世界循环');
  }
  window.addEventListener('hashchange', openWorldCycleFromHash);
  render();
  openWorldCycleFromHash();
})();
