#!/usr/bin/env node
/** Render the read-only player operation inventory as offline HTML and Markdown. */
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const directory = path.join(root, 'docs/game-state');
const inputPath = path.join(directory, 'ui-operation-map.json');
const data = JSON.parse(await readFile(inputPath, 'utf8'));
const functions = data.functions;
const groups = data.groups;
if (!data.meta || !Array.isArray(functions) || !Array.isArray(groups)) {
  throw new Error('Expected meta, groups and functions in ui-operation-map.json');
}
const byId = new Map(functions.map(item => [item.id, item]));
if (byId.size !== functions.length) throw new Error('Function IDs must be unique');
const groupedIds = groups.flatMap(group => group.functions);
if (groupedIds.length !== functions.length || new Set(groupedIds).size !== functions.length || groupedIds.some(id => !byId.has(id))) {
  throw new Error('Every function must belong to exactly one navigation group');
}
for (const item of functions) {
  if (!/^F\d+$/.test(item.id)) throw new Error(`Invalid function ID: ${item.id}`);
  for (const id of item.related ?? []) {
    if (!byId.has(id)) throw new Error(`${item.id} references unknown related function ${id}`);
  }
}

const array = value => Array.isArray(value) ? value : [];
const escape = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const markdown = value => String(value ?? '').replace(/([\\`*_[\]<>])/g, '\\$1').replace(/\r?\n/g, ' ');
const linkPath = value => {
  const target = path.resolve(root, String(value));
  const relativeRoot = path.relative(root, target);
  if (relativeRoot.startsWith('..' + path.sep) || relativeRoot === '..' || path.isAbsolute(relativeRoot)) {
    throw new Error(`Document link escapes project root: ${value}`);
  }
  return path.relative(directory, target).split(path.sep).map(encodeURIComponent).join('/');
};
const list = values => array(values).length ? `<ul>${values.map(value => `<li>${escape(value)}</li>`).join('')}</ul>` : '<p class="empty">未单列。</p>';
const mdList = values => array(values).length ? values.map(value => `- ${markdown(value)}`).join('\n') : '- 未单列。';
const coverage = item => ({ observed: array(item.coverage?.observed), sourceOnly: array(item.coverage?.sourceOnly) });
const observedCount = functions.filter(item => coverage(item).observed.length).length;
const sourceOnlyCount = functions.filter(item => coverage(item).observed.length === 0).length;
const section = (title, values) => array(values).length ? `<section class="detail-section"><h4>${title}</h4>${list(values)}</section>` : '';
const chainHtml = chains => array(chains).map(chain => `<section class="chain"><h4>${escape(chain.name)}</h4><ol>${array(chain.steps).map(step => `<li>${escape(step)}</li>`).join('')}</ol></section>`).join('');
const appendixHtml = (title, items) => array(items).length ? `<details class="appendix"><summary>${title}<span>${items.length} 项</span></summary><div class="appendix-grid">${chainHtml(items)}</div></details>` : '';
const evidenceHtml = item => array(item.evidence).length ? `<section class="evidence"><h3>现场图证</h3><div class="evidence-grid">${item.evidence.map(evidence => {
  const href = linkPath(evidence.path);
  const label = evidence.label || evidence.path;
  const isImage = /\.(png|jpe?g|webp|gif|svg)$/i.test(evidence.path);
  return `<figure><a href="${escape(href)}" target="_blank" rel="noopener">${isImage ? `<img loading="lazy" src="${escape(href)}" alt="${escape(label)}">` : '<span class="file-preview">打开证据文件 ↗</span>'}<figcaption>${escape(label)} <span aria-hidden="true">↗</span></figcaption></a></figure>`;
}).join('')}</div><p class="caption">缩略图对应所注明的现场状态；点击可打开原文件。图证不代替完整流程覆盖。</p></section>` : '';
const functionHtml = item => {
  const state = coverage(item);
  const route = String(item.summary ?? '').split(/\s*→\s*/).filter(Boolean);
  return `<article class="function" id="${item.id}" data-function="${item.id}" tabindex="-1">
    <header class="function-heading"><span class="function-id">${item.id}</span><div><h2>${escape(item.title)}</h2><p class="goal">${escape(item.goal)}</p></div><a class="permalink" href="#${item.id}" aria-label="定位${escape(item.title)}">#</a></header>
    <div class="route" aria-label="主要操作链">${route.map((step, index) => `${index ? '<span class="arrow" aria-hidden="true">→</span>' : ''}<span>${escape(step)}</span>`).join('')}</div>
    <section class="coverage" aria-label="核对覆盖"><div class="observed"><h3>实机已观察 <span>${state.observed.length}</span></h3>${state.observed.length ? list(state.observed) : '<p class="empty">尚无本会话实机记录。</p>'}</div><div class="source-only"><h3>源码已核对 · 实机未覆盖 <span>${state.sourceOnly.length}</span></h3>${state.sourceOnly.length ? list(state.sourceOnly) : '<p class="empty">未单列其他实机待覆盖项；不表示全功能通过。</p>'}</div></section>
    ${evidenceHtml(item)}
    <details class="fold"><summary>入口与具体操作<span>${array(item.entries).length} 个入口 · ${array(item.chains).length} 条链路</span></summary><div class="detail-content">${section('正常入口', item.entries)}${chainHtml(item.chains)}</div></details>
    <details class="fold"><summary>前提、分支与提交返回<span>支付时机与共用界面</span></summary><div class="detail-grid">${section('前提与分支', item.branches)}${section('何时写入／支付', item.commit)}${section('结果与返回', item.returns)}${section('界面构成', item.surfaces)}</div></details>
    ${appendixHtml('十二权能逐项操作', item.powers)}${appendixHtml('持续活动逐项操作', item.activities)}
    <details class="fold sources"><summary>代码依据<span>${array(item.sources).length} 处</span></summary><ul>${array(item.sources).map(source => `<li><a href="${escape(linkPath(source.path))}">${escape(source.path)}</a><p>${escape(source.note)}</p></li>`).join('')}</ul></details>
    ${array(item.related).length ? `<nav class="related" aria-label="相关功能"><span>相关功能</span>${item.related.map(id => `<a href="#${id}" data-related="${id}">${id} ${escape(byId.get(id).title)}</a>`).join('')}</nav>` : ''}
  </article>`;
};

const embedded = JSON.stringify(data).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(data.meta.title)}</title>
<style>
:root{color-scheme:light;--ink:#202b38;--muted:#65707d;--line:#dbe1e8;--paper:#fff;--wash:#f3f5f8;--accent:#315c91;--observed:#edf5ee;--pending:#fff6e8}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:var(--wash);color:var(--ink);font:15px/1.65 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}button,input,select{font:inherit}button,a,input,select,summary{outline-offset:4px}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:2px solid var(--accent)}.skip{position:fixed;top:-60px;left:16px;z-index:3;background:white;padding:10px}.skip:focus{top:10px}.sidebar{position:fixed;inset:0 auto 0 0;width:296px;background:#fff;border-right:1px solid var(--line);overflow:auto;padding:28px 20px}.brand{font-size:17px;font-weight:700;letter-spacing:.03em}.sidebar .subtle{font-size:12px;margin:6px 0 22px}.search-label{display:block;font-size:13px;font-weight:600;margin-bottom:7px}input[type=search]{width:100%;border:1px solid #bcc7d3;border-radius:7px;padding:10px 11px;background:#fff}.filter{width:100%;padding:7px 9px;border:1px solid var(--line);border-radius:6px;background:#fff;margin-top:8px;color:var(--muted)}.nav-summary{font-size:12px;color:var(--muted);margin:10px 0 18px}.nav-group{margin:18px 0}.nav-group h2{font-size:12px;font-weight:650;letter-spacing:.04em;color:var(--muted);margin:0 0 5px}.nav-group a{display:flex;gap:10px;align-items:baseline;padding:8px 10px;margin:2px -4px;color:var(--ink);font-size:13px;border-radius:5px;line-height:1.45}.nav-group a:hover{background:var(--wash);text-decoration:none}.nav-group a[aria-current=true]{background:#eaf0f8;color:#244f83;font-weight:650}.nav-id{font:11px/1.6 ui-monospace,monospace;color:var(--muted);min-width:27px}.side-links{border-top:1px solid var(--line);padding-top:15px;font-size:12px;display:flex;gap:14px}main{margin-left:296px;padding:40px clamp(24px,4vw,68px) 100px;max-width:1550px}.page-header{margin-bottom:32px}.eyebrow{text-transform:uppercase;font-size:12px;font-weight:650;letter-spacing:.09em;color:var(--muted)}h1{font-size:clamp(27px,3vw,39px);line-height:1.25;margin:10px 0 14px;letter-spacing:-.03em}.scope{max-width:940px;font-size:16px;line-height:1.8}.meta{display:flex;flex-wrap:wrap;gap:7px 20px;font-size:12px;color:var(--muted);margin:15px 0}.stats{display:flex;gap:12px;flex-wrap:wrap;margin:22px 0}.stat{border:1px solid var(--line);background:white;padding:10px 16px;border-radius:8px;font-size:12px;color:var(--muted)}.stat strong{font-size:23px;color:var(--ink);margin-right:8px;font-weight:600}.notice{border-left:3px solid #b98a48;background:#fffaf1;padding:16px 20px;margin:18px 0;border-radius:0 7px 7px 0}.notice h2,.reading h2{font-size:14px;margin:0 0 7px}.notice ul,.reading ul{margin:0;padding-left:20px;font-size:13px}.reading{font-size:13px;color:var(--muted)}.toolbar{display:flex;gap:10px;align-items:center;margin:25px 0 8px}.toolbar button{background:#fff;border:1px solid #c5cdd7;border-radius:6px;padding:7px 12px;color:var(--ink);cursor:pointer;font-size:13px}.toolbar span{color:var(--muted);font-size:12px}.group-heading{font-size:18px;margin:42px 0 15px;display:flex;align-items:center;gap:12px}.group-heading:after{content:"";height:1px;background:var(--line);flex:1}.function{background:white;border:1px solid var(--line);border-radius:12px;padding:26px 30px;margin:0 0 24px;scroll-margin-top:24px}.function-heading{display:flex;align-items:flex-start;gap:14px}.function-id{font:12px/1 ui-monospace,monospace;color:var(--accent);background:#edf2f8;border-radius:5px;padding:7px;margin-top:3px;flex-shrink:0}h2{font-size:22px;line-height:1.45;margin:0 0 8px}h3{font-size:13px;margin:0 0 8px}h4{font-size:14px;margin:0 0 7px}.goal{margin:0;color:var(--muted);font-size:14px}.permalink{margin-left:auto;font-size:19px;color:#8a96a3}.route{display:flex;flex-wrap:wrap;align-items:center;gap:6px 9px;margin:23px 0 20px;padding:16px 18px;border-radius:7px;background:#eef3f9;color:#244d7b;font-size:14px;font-weight:600;line-height:1.8}.arrow{color:#8c9fb3;font-weight:400}.coverage{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:20px}.coverage>div{border-radius:7px;padding:14px 16px}.observed{background:var(--observed)}.source-only{background:var(--pending)}.coverage h3{display:flex;gap:8px;align-items:baseline}.coverage h3 span{font-weight:400;color:var(--muted)}ul,ol{padding-left:21px;margin:7px 0 0}li{padding-left:2px;margin:5px 0}.coverage ul{font-size:13px;line-height:1.7}.empty{font-size:13px;color:var(--muted);margin:0}.fold,.appendix{border-top:1px solid var(--line);padding:12px 0}.fold summary,.appendix summary{cursor:pointer;font-size:14px;font-weight:600;list-style:none;display:flex;align-items:baseline;gap:8px}.fold summary:before,.appendix summary:before{content:"›";font-size:18px;line-height:1;color:var(--muted);display:inline-block;transition:transform .15s}.fold[open]>summary:before,.appendix[open]>summary:before{transform:rotate(90deg)}summary::-webkit-details-marker{display:none}summary span{font-size:12px;font-weight:400;color:var(--muted);margin-left:auto}.detail-content,.detail-grid,.appendix-grid{margin:17px 0 4px 20px;font-size:13px}.detail-grid,.appendix-grid{display:grid;grid-template-columns:1fr 1fr;gap:22px}.detail-section,.chain{margin:0 0 20px}.detail-section:last-child,.chain:last-child{margin-bottom:0}.chain ol{border-left:2px solid #e2e8ef;list-style-position:outside;margin-left:6px;padding-left:23px}.chain li{padding:2px 0 2px 4px}.sources ul{margin-left:18px;font-size:12px}.sources a{overflow-wrap:anywhere}.sources p{color:var(--muted);margin:2px 0 10px}.related{border-top:1px solid var(--line);padding-top:14px;display:flex;gap:7px 12px;flex-wrap:wrap;font-size:12px}.related>span{color:var(--muted)}.evidence{margin:18px 0 22px}.evidence-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;max-width:100%}figure{margin:0;min-width:0;border:1px solid var(--line);border-radius:7px;overflow:hidden;background:#f8fafc}figure>a{display:block}figure img{display:block;width:100%;max-height:250px;object-fit:contain;background:#e7ebef;aspect-ratio:16/9}figcaption{padding:8px 10px;font-size:12px;line-height:1.5}.file-preview{display:flex;align-items:center;justify-content:center;min-height:80px;color:var(--muted);font-size:13px}.caption{font-size:11px;color:var(--muted);margin:8px 0 0}.no-results{padding:36px;border:1px dashed #bdc8d5;border-radius:8px;color:var(--muted);background:white}.footer{color:var(--muted);font-size:12px;border-top:1px solid var(--line);padding-top:18px;margin-top:36px}[hidden]{display:none!important}@media(max-width:1000px){.sidebar{width:242px;padding:22px 16px}main{margin-left:242px;padding:30px 25px 70px}.function{padding:22px}.coverage,.detail-grid,.appendix-grid{grid-template-columns:1fr}}@media(max-width:700px){.sidebar{position:relative;width:auto;border-right:0;border-bottom:1px solid var(--line);max-height:370px}.nav-groups{display:grid;grid-template-columns:1fr 1fr;gap:0 16px}.nav-group{margin:10px 0}.side-links{margin-top:10px}main{margin-left:0;padding:26px 15px 60px}.function{padding:20px 17px}h2{font-size:19px}.function-heading{gap:10px}.route{padding:13px}.stats{gap:7px}.stat{padding:8px 10px}summary span{display:none}.evidence-grid{grid-template-columns:1fr}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.fold summary:before,.appendix summary:before{transition:none}}@media print{.sidebar,.toolbar,.permalink,.skip{display:none}main{margin:0;padding:0;max-width:none}body{background:#fff;font-size:11px}.function{break-inside:avoid;border-radius:0;box-shadow:none;padding:15px}h1{font-size:26px}.coverage,.detail-grid{grid-template-columns:1fr 1fr}.group-heading{break-after:avoid}details{display:block}details>*{display:block}a{color:inherit}.evidence-grid img{max-height:150px}}
</style></head><body>
<a class="skip" href="#main">跳到正文</a>
<aside class="sidebar" aria-label="功能导航"><a href="#top" class="brand">游戏操作链路</a><p class="subtle">${groups.length} 组 · ${functions.length} 项功能 · 编号仅作索引</p><label class="search-label" for="search">查找功能、入口或状态</label><input id="search" type="search" placeholder="例如：祈求、停供、存档" autocomplete="off"><select class="filter" id="coverage-filter" aria-label="按核对覆盖筛选"><option value="all">全部功能</option><option value="observed">含实机已观察状态</option><option value="source-only">仅源码核对</option></select><p class="nav-summary" id="nav-summary" aria-live="polite">显示 ${functions.length} / ${functions.length} 项功能</p><nav class="nav-groups">${groups.map((group, index) => `<section class="nav-group" data-nav-group="${index}"><h2>${escape(group.title)}</h2>${group.functions.map(id => `<a href="#${id}" data-nav="${id}"><span class="nav-id">${id}</span><span>${escape(byId.get(id).title)}</span></a>`).join('')}</section>`).join('')}</nav><div class="side-links"><a href="ui-operation-map.md">Markdown</a><a href="ui-operation-map.json">源数据</a><a href="#top">回到顶部</a></div></aside>
<main id="main"><header id="top" class="page-header"><div class="eyebrow">玩家功能 · 现行入口 · 操作链路</div><h1>${escape(data.meta.title)}</h1><p class="scope">${escape(data.meta.scope)}</p><div class="meta"><span>${escape(data.meta.date)}</span><span>分支 ${escape(data.meta.branch)}</span><span>基准 ${escape(data.meta.commit)}</span></div><div class="stats"><div class="stat"><strong>${functions.length}</strong>玩家功能</div><div class="stat"><strong>${groups.length}</strong>导航分组</div><div class="stat"><strong>${observedCount}</strong>实机已观察</div><div class="stat"><strong>${sourceOnlyCount}</strong>仅源码核对</div></div>${array(data.meta.limitations).length ? `<section class="notice"><h2>范围与证据边界</h2>${list(data.meta.limitations)}</section>` : ''}<section class="reading"><h2>阅读方式</h2>${list(data.meta.reading)}</section><div class="toolbar"><button id="toggle-details" type="button" aria-expanded="false">展开操作细节</button><button id="reset-search" type="button">重置筛选</button><span>离线可用 · 无需服务器</span></div></header>
<p id="no-results" class="no-results" hidden>没有匹配的功能。尝试另一关键词，或重置筛选。</p>
${groups.map((group, index) => `<section class="content-group" data-content-group="${index}"><h2 class="group-heading">${escape(group.title)}</h2>${group.functions.map(id => functionHtml(byId.get(id))).join('')}</section>`).join('')}
<footer class="footer">由 ui-operation-map.json 生成。代码接线、已观察状态与仍未覆盖的状态分别记录；此索引不代表美术验收结论。</footer></main>
<script id="operation-data" type="application/json">${embedded}</script>
<script>
(() => {
  const data = JSON.parse(document.getElementById('operation-data').textContent);
  const search = document.getElementById('search');
  const filter = document.getElementById('coverage-filter');
  const articles = new Map(data.functions.map(item => [item.id, document.getElementById(item.id)]));
  const index = new Map(data.functions.map(item => [item.id, JSON.stringify(item).toLocaleLowerCase()]));
  const nav = new Map(Array.from(document.querySelectorAll('[data-nav]'), item => [item.dataset.nav, item]));
  function update() {
    const tokens = search.value.trim().toLocaleLowerCase().split(/\\s+/).filter(Boolean);
    let count = 0;
    for (const item of data.functions) {
      const coverage = item.coverage || {};
      const matchesCoverage = filter.value === 'all' || (filter.value === 'observed' ? (coverage.observed || []).length > 0 : (coverage.observed || []).length === 0);
      const visible = !!matchesCoverage && tokens.every(token => index.get(item.id).includes(token));
      articles.get(item.id).hidden = !visible;
      nav.get(item.id).hidden = !visible;
      if (visible) count++;
    }
    data.groups.forEach((group, position) => {
      const hidden = group.functions.every(id => articles.get(id).hidden);
      document.querySelector('[data-content-group="' + position + '"]').hidden = hidden;
      document.querySelector('[data-nav-group="' + position + '"]').hidden = hidden;
    });
    document.getElementById('nav-summary').textContent = '显示 ' + count + ' / ' + data.functions.length + ' 项功能';
    document.getElementById('no-results').hidden = count !== 0;
  }
  function reset() { search.value = ''; filter.value = 'all'; update(); }
  function active(id) {
    for (const [key, link] of nav) {
      if (key === id) link.setAttribute('aria-current', 'true');
      else link.removeAttribute('aria-current');
    }
  }
  function followHash() {
    const id = location.hash.slice(1);
    if (!articles.has(id)) return;
    if (articles.get(id).hidden) reset();
    active(id);
    requestAnimationFrame(() => { articles.get(id).scrollIntoView(); articles.get(id).focus({ preventScroll: true }); });
  }
  search.addEventListener('input', update);
  filter.addEventListener('change', update);
  document.getElementById('reset-search').addEventListener('click', () => { reset(); search.focus(); });
  document.getElementById('toggle-details').addEventListener('click', event => {
    const open = event.currentTarget.getAttribute('aria-expanded') !== 'true';
    document.querySelectorAll('.function:not([hidden]) details').forEach(detail => { detail.open = open; });
    event.currentTarget.setAttribute('aria-expanded', String(open));
    event.currentTarget.textContent = open ? '收起操作细节' : '展开操作细节';
  });
  document.querySelectorAll('[data-related]').forEach(link => link.addEventListener('click', () => {
    if (articles.get(link.dataset.related).hidden) reset();
    if (location.hash === link.hash) followHash();
  }));
  window.addEventListener('hashchange', followHash);
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      const visible = entries.filter(entry => entry.isIntersecting && !entry.target.hidden).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
      if (visible.length) active(visible[0].target.id);
    }, { rootMargin: '-8% 0px -65% 0px', threshold: 0 });
    articles.forEach(article => observer.observe(article));
  }
  update(); followHash();
})();
</script></body></html>`;

const markdownChains = chains => array(chains).map(chain => `**${markdown(chain.name)}**\n\n${array(chain.steps).map((step, index) => `${index + 1}. ${markdown(step)}`).join('\n')}`).join('\n\n');
const markdownSection = (title, values) => array(values).length ? `**${title}**\n\n${mdList(values)}\n\n` : '';
const functionMarkdown = item => {
  const state = coverage(item);
  let result = `<a id="${item.id}"></a>\n\n### ${item.id} · ${markdown(item.title)}\n\n${markdown(item.goal)}\n\n**主链：** ${markdown(item.summary)}\n\n`;
  result += `**实机已观察**\n\n${state.observed.length ? mdList(state.observed) : '- 尚无本会话实机记录。'}\n\n`;
  result += `**源码已核对 · 实机未覆盖**\n\n${state.sourceOnly.length ? mdList(state.sourceOnly) : '- 未单列其他实机待覆盖项；不表示全功能通过。'}\n\n`;
  if (array(item.evidence).length) result += `**现场图证**\n\n${item.evidence.map(evidence => `- [${markdown(evidence.label || evidence.path)}](${linkPath(evidence.path)})`).join('\n')}\n\n`;
  result += markdownSection('正常入口', item.entries);
  if (array(item.chains).length) result += `${markdownChains(item.chains)}\n\n`;
  for (const [title, key] of [['前提与分支', 'branches'], ['何时写入／支付', 'commit'], ['结果与返回', 'returns'], ['界面构成', 'surfaces']]) result += markdownSection(title, item[key]);
  for (const [title, key] of [['十二权能逐项操作', 'powers'], ['持续活动逐项操作', 'activities']]) {
    if (array(item[key]).length) result += `<details>\n<summary>${title}（${item[key].length} 项）</summary>\n\n${markdownChains(item[key])}\n\n</details>\n\n`;
  }
  result += `**代码依据**\n\n${array(item.sources).map(source => `- [${markdown(source.path)}](${linkPath(source.path)}) — ${markdown(source.note)}`).join('\n')}\n\n`;
  if (array(item.related).length) result += `**相关功能：** ${item.related.map(id => `[${id} ${markdown(byId.get(id).title)}](#${id})`).join(' · ')}\n\n`;
  return result;
};
let md = `# ${markdown(data.meta.title)}\n\n${markdown(data.meta.scope)}\n\n日期：${markdown(data.meta.date)} · 分支：${markdown(data.meta.branch)} · 基准：${markdown(data.meta.commit)}\n\n[打开离线阅览版](ui-operation-map.html) · [源数据](ui-operation-map.json)\n\n编号仅作定位索引，不表示制作或整改优先级。共 ${groups.length} 组、${functions.length} 项功能。\n\n`;
md += markdownSection('范围与证据边界', data.meta.limitations) + markdownSection('阅读方式', data.meta.reading);
md += `## 功能索引\n\n${groups.map(group => `- **${markdown(group.title)}**：${group.functions.map(id => `[${id} ${markdown(byId.get(id).title)}](#${id})`).join(' · ')}`).join('\n')}\n\n`;
for (const group of groups) md += `## ${markdown(group.title)}\n\n${group.functions.map(id => functionMarkdown(byId.get(id))).join('')}`;
md += '---\n\n由 ui-operation-map.json 生成。代码接线、已观察状态与仍未覆盖的状态分别记录；此索引不代表美术验收结论。\n';

await mkdir(directory, { recursive: true });
await writeFile(path.join(directory, 'ui-operation-map.html'), html.replace(/[ \t]+$/gm, ''));
await writeFile(path.join(directory, 'ui-operation-map.md'), md);
console.log(`Rendered ${functions.length} functions in ${groups.length} groups: docs/game-state/ui-operation-map.{html,md}`);
