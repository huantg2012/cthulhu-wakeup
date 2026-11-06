#!/usr/bin/env python3
"""Build the offline design reader from the authored CSVs; including authored unknown outcomes for optional designer reading."""
import csv
import html
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'docs/content/prayer-space.html'


def read(name):
    with (ROOT / f'data/prayer_space_{name}.csv').open(newline='', encoding='utf-8') as source:
        rows = list(csv.DictReader(source))
    assert rows and all(None not in row and None not in row.values() for row in rows), name
    assert len({r['id'] for r in rows}) == len(rows), name
    return rows


def inline(text):
    text = html.escape(text)
    text = re.sub(r'\[([^]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', text)


def render_spec(text):
    blocks = []
    in_list = False
    for line in text.splitlines():
        line = line.strip()
        is_item = line.startswith('- ')
        if in_list and not is_item:
            blocks.append('</ul>')
            in_list = False
        if not line:
            continue
        if is_item:
            if not in_list:
                blocks.append('<ul>')
                in_list = True
            blocks.append(f'<li>{inline(line[2:])}</li>')
        elif line.startswith('### '):
            blocks.append(f'<h3>{inline(line[4:])}</h3>')
        elif line.startswith('## '):
            blocks.append(f'<h2>{inline(line[3:])}</h2>')
        else:
            blocks.append(f'<p>{inline(line)}</p>')
    if in_list:
        blocks.append('</ul>')
    return ''.join(blocks)


cases = read('cases')
frames = {r['id']: r for r in read('frames')}
operators = {r['id']: r for r in read('operators')}
costs = {r['id']: r for r in read('costs')}
scenes = {r['id']: r for r in read('scenes')}
read('parameters')
contracts = {(r['case_id'], r['choice']): r for r in read('response_contracts')}
assert len(cases) == 50
assert len({r['title'] for r in cases}) == 50
count = 0
for case in cases:
    assert case['frame'] in frames and case['scene'] in scenes
    assert int(case['deadline']) > 0
    choices = []
    for key in ('choice_a', 'choice_b', 'choice_c', 'choice_d', 'choice_e'):
        raw = case.pop(key)
        if not raw:
            continue
        parts = raw.split('|')
        assert len(parts) == 5 and all(parts), (case['id'], key)
        label, operator, cost, effect, tradeoff = parts
        assert operator in operators and cost in costs, (case['id'], key)
        contract = contracts[(case['id'], key)]
        choices.append(dict(label=label, operator=operator, cost=cost, effect=effect, tradeoff=tradeoff, approach=contract['approach'], disclosure=contract['disclosure'], omen=contract['omen'], outcomes=json.loads(contract['outcomes'])))
    assert 2 <= len(choices) <= 5
    case['choices'] = choices
    count += len(choices)
assert count == len(contracts)
spec = (ROOT / 'docs/specs/system-events.md').read_text()
section = '## 16.' + spec.split('## 16.', 1)[1]
# Links in this section resolve from the same parent depth as the spec.
section = section.replace('(../content/prayer-space.html)', '(prayer-space.html)')
research = '## 15.1 ' + spec.split('### 15.1 ', 1)[1].split('### 15.2 ', 1)[0]
payload = json.dumps(dict(cases=cases, frames=frames, operators=operators, costs=costs), ensure_ascii=False).replace('<', '\\u003c')
page = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>祈求 · 生成系统与五十则求告</title>
<style>
:root{color-scheme:light;--ink:#252b2b;--muted:#626c69;--paper:#f6f4ee;--line:#d9ddd5;--accent:#276553;--warm:#895839}*{box-sizing:border-box}body{margin:0;color:var(--ink);background:var(--paper);font-family:system-ui,-apple-system,"PingFang SC",sans-serif;font-size:16px;line-height:1.75}a{color:var(--accent)}button,input,select{font:inherit}button{cursor:pointer}header{background:var(--paper);padding:24px 34px 16px;border-bottom:1px solid var(--line)}.eyebrow{color:var(--accent);font-size:13px;letter-spacing:.15em}h1{font-family:"Songti SC",serif;font-weight:600;font-size:30px;margin:5px 0 2px}header p{margin:0;color:var(--muted);font-size:14px}.tabs{display:flex;gap:8px;margin-top:16px}.tabs button{background:transparent;border:1px solid var(--line);padding:7px 18px;border-radius:4px;color:var(--ink)}.tabs button[aria-pressed=true]{background:var(--accent);border-color:var(--accent);color:white}.workspace{display:grid;grid-template-columns:290px minmax(0,1fr);height:calc(100dvh - 199px);min-height:400px}.sidebar{display:flex;min-height:0;flex-direction:column;border-right:1px solid var(--line);background:#eef0e9}.filters{padding:18px 18px 12px;border-bottom:1px solid var(--line)}.filters input,.filters select{width:100%;background:#fffefa;border:1px solid #bbc4ba;padding:8px 10px;border-radius:4px;margin:0 0 10px}.filters label{display:block;font-size:13px;color:var(--muted)}#count{font-size:13px;color:var(--muted)}nav{overflow-y:auto;padding:8px 12px 20px}nav a{display:block;text-decoration:none;color:var(--ink);padding:9px 9px;border-bottom:1px solid var(--line);font-size:14px}nav a:hover{background:#e1e7dc}nav small{display:block;font-size:12px;color:var(--muted)}main{overflow-y:auto;padding:28px 42px 60px;scroll-behavior:smooth}.prayer{max-width:1080px;margin:auto;padding:0 0 40px;border-bottom:1px solid #bdc7bc;scroll-margin-top:22px}.prayer+.prayer{padding-top:36px}.meta{display:flex;gap:14px;flex-wrap:wrap;font-size:13px;color:var(--muted)}h2{font-family:"Songti SC",serif;font-size:26px;line-height:1.5;margin:8px 0 12px}blockquote{margin:20px 0;padding:8px 0 8px 18px;border-left:3px solid var(--accent);font-family:"Songti SC",serif;font-size:21px;color:#254c40}.context{margin:10px 0;color:#4c5852}.goal{font-size:14px;margin-bottom:22px}.goal strong{color:var(--accent)}.choices{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px 24px}.choice{border-top:2px solid var(--line);padding-top:12px}.choice h3{margin:0 0 6px;font-size:18px}.price{font-size:13px;color:var(--accent);margin-bottom:12px}.choice p{font-size:15px;line-height:1.8;margin:7px 0}.choice .tradeoff{color:var(--warm)}.caption{font-size:12px;color:var(--muted);margin-right:8px}.choice details{font-size:13px;color:var(--muted);margin-top:10px}.choice summary{cursor:pointer}.expiry{font-size:13px;color:var(--muted);padding-top:22px;margin:0}.empty{padding:30px;color:var(--muted)}.document{max-width:950px;margin:auto;padding:26px 36px 70px}.document h2{margin-top:30px}.document h3{font-size:20px;margin-top:30px}.document p,.document li{line-height:1.95}.document li{margin-bottom:12px}.document code{font-size:13px;overflow-wrap:anywhere}.guide{padding:12px 16px;background:#e9eee4;font-size:14px;max-width:1080px;margin:0 auto 28px}.hidden{display:none!important}:focus-visible{outline:3px solid #9b6e36;outline-offset:3px}
@media(max-width:850px){header{padding:18px}h1{font-size:25px}.workspace{grid-template-columns:210px minmax(0,1fr);height:calc(100dvh - 190px)}main{padding:20px}.choices{grid-template-columns:1fr}h2{font-size:24px}}@media(max-width:580px){.workspace{display:block;height:auto}.sidebar{border-right:0}.filters{display:grid;grid-template-columns:1fr 1fr;gap:8px}.filters label:first-child{grid-column:1/-1}.filters input,.filters select{margin:0}nav{max-height:155px}.choices{grid-template-columns:1fr}main{overflow:visible}.document{padding:20px}}
@media print{header,.sidebar,.guide,.tabs{display:none!important}.workspace{display:block;height:auto}main{overflow:visible;padding:0}.prayer{break-before:page;border:0}.prayer:first-child{break-before:auto}.choices{grid-template-columns:1fr 1fr}.choice{break-inside:avoid}.choice details{display:none}body{background:white;font-size:12px}h2{font-size:22px}blockquote{font-size:17px}}
</style></head><body>
<header><div class="eyebrow">邪神苏醒 · 祈求设计</div><h1>五十则求告，一套生成规则</h1><p>50 条祈求 · __COUNT__ 个回应 · 已接入有限情境运行与具体回应。所有案例共用暂缓与不再回应控制。</p><div class="tabs" aria-label="阅读内容"><button id="cases-tab" aria-pressed="true">祈求目录</button><button id="system-tab" aria-pressed="false">系统设计</button><button id="sources-tab" aria-pressed="false">研究来源</button></div></header>
<section id="cases-panel" class="workspace"><aside class="sidebar"><div class="filters"><label>搜索内容<input id="query" type="search" placeholder="标题、人物、愿望、回应…"></label><label>生活背景<select id="frame"><option value="">全部背景</option></select></label><label>介入方式<select id="method"><option value="">全部方式</option></select></label><div id="count" aria-live="polite"></div></div><nav id="directory" aria-label="祈求目录"></nav></aside><main id="reading"><div class="guide">每项回应有它自己的尺度。曲解只显示预兆，具体结局收在默认关闭的作者栏。费用为设计初值；游戏中的概率由局势计算。</div><div id="entries"></div></main></section>
<section id="system-panel" class="document hidden">__SYSTEM__</section><section id="sources-panel" class="document hidden">__SOURCES__</section>
<script id="design-data" type="application/json">__DATA__</script>
<script>
'use strict';
const {cases,frames,operators,costs}=JSON.parse(document.getElementById('design-data').textContent);
const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const attrs={insight:'洞察',adaptation:'适应',will:'意志',influence:'影响',none:'无'};
const usedFrames=new Set(cases.map(c=>c.frame)),usedOps=new Set(cases.flatMap(c=>c.choices.map(x=>x.operator)));
for(const [id,item] of Object.entries(frames))if(usedFrames.has(id))$('frame').add(new Option(item.name,id));
for(const [id,item] of Object.entries(operators))if(usedOps.has(id))$('method').add(new Option(item.name,id));
const approachNames={mercy:'施恩',bargain:'交易',horror:'亵变',twist:'曲解',reveal:'启示',coerce:'支配'};
function choice(c){const price=costs[c.cost],op=operators[c.operator],unknown=c.disclosure==='unknown';const endings=unknown?`<details><summary>作者查看结局（剧透）</summary>${c.outcomes.map(o=>`<p>${esc(o.effect)}</p><p class="tradeoff">${esc(o.tradeoff)}</p>`).join('')}</details>`:'';return `<section class="choice"><div class="meta">${esc(approachNames[c.approach]||c.approach)}${unknown?' · 后果未知':''}</div><h3>${esc(c.label)}</h3><div class="price">低语 ${esc(price.whispers)} · 信仰 ${esc(price.faith)}<br>成功后：当地污染 +${esc(price.pollution)} · 察觉 +${esc(price.alert)}</div><p>${esc(c.effect)}</p>${unknown?`<p>${esc(c.omen)}</p>`:''}<p class="tradeoff">${esc(c.tradeoff)}</p>${endings}<details><summary>规则与费用</summary><p>${price.check_kind==='deterministic'?'条件满足后结算，不作成败检定。':`一次超常检定 · 主属性：${esc(attrs[price.attribute])}。失败仍支付费用，原处境继续。灾变：${esc(price.disaster)}。`}</p></details></section>`;}

function prayer(c){return `<article class="prayer" id="prayer-${esc(c.id)}"><div class="meta"><span>${esc(frames[c.frame].name)}</span><span>${esc(c.concern)}</span><span>请求窗口 ${esc(c.deadline)} 轮</span></div><h2>${esc(c.title)}</h2><div class="meta">求告者 · ${esc(c.petitioner)}</div><p class="context">${esc(c.context)}</p><blockquote>“${esc(c.appeal)}”</blockquote><p class="goal"><strong>所求</strong>　${esc(c.goal)}</p><div class="choices">${c.choices.map(choice).join('')}</div><p class="expiry">请求到期　${esc(c.expiry)}。原危机与请求窗口分别推进，不重复追加惩罚。</p></article>`;}
const searchable=c=>[c.title,c.petitioner,c.context,c.appeal,c.goal,c.concern,...c.choices.flatMap(x=>[x.label,x.effect,x.tradeoff])].join(' ').toLocaleLowerCase();
function render(){const q=$('query').value.trim().toLocaleLowerCase(),f=$('frame').value,m=$('method').value;const matches=cases.filter(c=>(!f||c.frame===f)&&(!m||c.choices.some(x=>x.operator===m))&&(!q||searchable(c).includes(q)));$('count').textContent=`显示 ${matches.length} / ${cases.length} 条祈求`;$('directory').innerHTML=matches.map(c=>`<a href="#prayer-${esc(c.id)}">${esc(c.title)}<small>${esc(c.petitioner)}</small></a>`).join('');$('entries').innerHTML=matches.length?matches.map(prayer).join(''):'<p class="empty">没有匹配的祈求。可清空搜索或切换筛选。</p>';$('reading').scrollTop=0;}
for(const id of ['query','frame','method'])$(id).addEventListener(id==='query'?'input':'change',render);
for(const name of ['cases','system','sources'])$(name+'-tab').addEventListener('click',()=>{for(const other of ['cases','system','sources']){$(other+'-panel').classList.toggle('hidden',other!==name);$(other+'-tab').setAttribute('aria-pressed',String(other===name));}});
render();
</script></body></html>'''
page = page.replace('__COUNT__', str(count)).replace('__SYSTEM__', render_spec(section)).replace('__SOURCES__', render_spec(research)).replace('__DATA__', payload)
OUTPUT.write_text(page, encoding='utf-8')
print(f'{len(cases)} prayers / {count} responses; references valid; {OUTPUT}')
print('Backgrounds:', dict(Counter(frames[c['frame']]['name'] for c in cases)))
