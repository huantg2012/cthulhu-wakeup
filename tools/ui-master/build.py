"""Render-source builder for Echoes UI design boards. No production mutations.

Rule names and costs come from CSV; mature identities/counts are explicit layout
fixtures, not natural-game evidence. HTML is an internal PNG render source.
"""
from pathlib import Path
import csv
import html
import json
from iconography import icon as sigil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/echoes-ui'
OUT.mkdir(parents=True, exist_ok=True)
def table(name):
    with (ROOT / 'data' / (name + '.csv')).open(encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))
def esc(text): return html.escape(str(text))
POWERS = table('powers')
PRAYERS = {r['id']: r for r in table('prayers')}
PARAMS = {r['id']: r['value'] for r in table('run_parameters')}
REAL_PREVIEW = json.loads((OUT/'runtime/prayer-preview.json').read_text())

TOKENS = {
    'version': '0.2-review', 'canvas': [1600, 900],
    'colors': {'void':'#071217','surface':'#0d1b20','raised':'#182d30','text':'#e5dfd0','secondary':'#a6b2b0','accent':'#dfbe7e','title':'#f1dca9','link':'#8fc5cc','line':'#7f6942','risk':'#ed9380','divine':'#c1abd8'},
    'type': {'task_title':[32,44], 'body':[20,30], 'secondary':[18,26], 'title':[28,36], 'number':[22,30]},
    'geometry': {'top':[0,0,1600,56], 'index':[16,76,208,668], 'main':[248,76,1336,668], 'chronicle':[16,760,1568,32], 'dock':[16,804,1568,84]},
    'status':'Design proposal, not runtime configuration; colors pending producer review',
}
(OUT/'tokens.json').write_text(json.dumps(TOKENS,ensure_ascii=False,indent=2)+'\n')

POWER_SYMBOLS={
    'POWER_LISTEN':'listen', 'POWER_DREAM':'dream', 'POWER_ORACLE':'oracle',
    'POWER_BESTOW':'bestow', 'POWER_APPOINT':'appoint', 'POWER_SACRIFICE':'sacrifice',
    'POWER_BREACH':'breach', 'POWER_SEED':'seed', 'POWER_ANCHOR':'anchor',
    'POWER_VEIL':'veil', 'POWER_TRANSFER':'transfer', 'POWER_MANIFEST':'manifest',
}
def symbol(name,text='',tone='gold',size=28,extra=''):
    return f'<span class="symbol-label {extra}" data-symbol-role="{name}">{sigil(name,size,tone)}{text}</span>'
def seal(name,size=40,tone='gold',large=False):
    return f'<span class="sigil-medallion {"large" if large else ""}">{sigil(name,size,tone)}</span>'
def relic_sprite(index):
    return f'<span class="relic-sprite" data-relic-image="{index}"><img src="assets/relic-icons.png" style="left:{-100*index}%" alt=""></span>'

STYLE = '''
*{box-sizing:border-box}html,body{margin:0;padding:0;background:#080e12;color:#d9d8cd;font-family:"PingFang SC","Noto Sans CJK SC",sans-serif;font-size:20px;line-height:1.5}button,input{font:inherit}button{cursor:default}h1,h2,h3,p{margin:0}h1,h2,.serif{font-family:"Songti SC","Noto Serif CJK SC",serif}h1{font-size:32px;line-height:44px;font-weight:500}h2{font-size:28px;line-height:36px;font-weight:500}h3{font-size:22px;line-height:30px;font-weight:500}.muted,.small{color:#a6afaa}.small{font-size:18px;line-height:26px}.risk{color:#d88a7a}.accent{color:#c7ba96}.divine{color:#a99abb}.num{font-size:22px;font-variant-numeric:tabular-nums}.glyph{width:30px;height:30px;flex-shrink:0;color:#bcb49b}.btn{min-height:44px;padding:6px 18px;color:#d9d8cd;background:#182227;border:1px solid #43504f;text-align:center;border-radius:1px;white-space:nowrap}.btn.primary{background:#c7ba96;border-color:#d5c9a6;color:#10191d;font-weight:600}.btn.quiet{background:transparent;border-color:transparent;color:#a6afaa}.btn.danger{border-color:#8b514b;color:#e8a99b}.btn.disabled{background:#11191c;color:#a6afaa;border-style:dashed}.btn.hover{background:#263036;border-color:#c7ba96}.btn.focus{outline:2px solid #b9cacc;outline-offset:3px}.btn.pressed{background:#080e12;border-color:#c7ba96}.row{display:flex;align-items:center;gap:16px}.between{justify-content:space-between}.rule{height:1px;background:#43504f;margin:16px 0;opacity:.65}.plate{background:#10191df5;border-top:1px solid #59615c;border-bottom:1px solid #293735;box-shadow:inset 0 1px #ffffff03}.surface{background:#10191ded;border:1px solid #303e3e;padding:24px}.tag{font-size:18px;line-height:26px;border-left:2px solid #68736b;padding-left:10px;color:#a6afaa}.tag.risk{border-color:#b37566;color:#d88a7a}.screen{position:relative;width:1600px;height:900px;overflow:hidden;background:radial-gradient(ellipse at 55% 57%,#1b282c80,transparent 54%),radial-gradient(ellipse at 80% -25%,#000 30%,transparent 72%),#080e12}.screen:before{content:"";position:absolute;inset:56px 0 96px;pointer-events:none;box-shadow:inset 0 90px 100px #020508aa,inset 70px 0 150px #02050877}.ambient{position:absolute;left:330px;top:140px;width:1100px;height:520px;border:1px solid #67747112;border-radius:50%;transform:rotate(-12deg);box-shadow:0 0 0 80px #71857a03,0 0 0 180px #71857a02}.top{position:absolute;inset:0 0 auto;height:56px;display:flex;align-items:center;padding:0 24px;gap:28px;background:#0b1115;border-bottom:1px solid #394440}.top .phase{font-size:18px;color:#a6afaa;margin-left:8px}.top .global{display:flex;align-items:center;gap:26px}.top nav{margin-left:auto;display:flex;align-items:center;gap:20px;font-size:18px}.top nav span{white-space:nowrap}.index{position:absolute;left:16px;top:76px;width:208px;height:668px;padding:18px 12px;background:#0b1216d9;border-right:1px solid #35423e}.index h2{font-size:24px}.search{margin-top:16px;height:42px;border-bottom:1px solid #43504f;display:flex;align-items:center;gap:10px;color:#a6afaa;font-size:18px}.index .entry{height:71px;padding:10px 8px;border-bottom:1px solid #283431;display:flex;align-items:center;gap:12px;font-size:20px}.index .entry .glyph{width:24px}.index .entry.selected{background:#242d2c;border-left:3px solid #c7ba96;padding-left:5px;color:#e1d8bd}.index .entry small{display:block;font-size:18px;line-height:24px;color:#a6afaa}.index .foot{position:absolute;bottom:20px;left:20px;right:20px;color:#a6afaa;font-size:18px}.main{position:absolute;left:248px;top:76px;width:1336px;height:668px}.main-head{height:56px;display:flex;align-items:center;justify-content:space-between;gap:20px}.head-tools{display:flex;align-items:center;gap:18px;font-size:18px}.chronicle{position:absolute;left:16px;top:760px;height:32px;width:1568px;display:flex;align-items:center;gap:28px;font-size:18px;color:#a6afaa;border-top:1px solid #293936}.chronicle .end{margin-left:auto;color:#d9d8cd;white-space:nowrap}.dock{position:absolute;left:16px;top:804px;width:1568px;height:84px;display:flex;align-items:center;background:#0b1217;border-top:1px solid #59615c;border-bottom:1px solid #293735;padding:8px 12px;gap:16px}.dock-label{font-size:18px;color:#a6afaa;width:46px}.powers{display:grid;grid-template-columns:repeat(12,70px);gap:4px}.power{height:64px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;position:relative;font-size:18px}.power.locked{color:#a6afaa}.power.locked .glyph{color:#737e77}.power.locked:after{content:"◇";position:absolute;right:0;top:2px;font-size:15px}.relics{height:64px;display:flex;align-items:center;gap:8px;border-left:1px solid #43504f;padding-left:18px;flex:1}.relic{display:flex;gap:10px;align-items:center;flex:1;min-width:0}.relic .small{font-size:18px;line-height:22px}.relic .glyph{width:28px}.prayer-intro{text-align:center;padding-top:26px}.prayer-intro h1{letter-spacing:5px}.prayer-intro p{margin-top:8px}.prayer-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin:28px 40px 0}.prayer{position:relative;height:442px;padding:22px 24px;background:linear-gradient(180deg,#1a2428,#0e171be8);border-top:2px solid #6b7163;border-bottom:1px solid #303e3e}.prayer h2{margin:21px 0 10px;font-size:28px;white-space:nowrap}.prayer .identity{font-size:18px;color:#a6afaa}.prayer .quote{font-size:20px;line-height:30px;height:96px;padding-top:20px;color:#d9d8cd}.prayer .context{font-size:18px;color:#a6afaa;height:60px;line-height:26px;margin-top:14px}.prayer .choices{display:flex;gap:10px;margin-top:12px}.prayer .choices .btn{flex:1;padding:6px 8px}.prayer .choices small{display:block;font-size:18px;line-height:24px;font-weight:400}.prayer .source{font-size:18px;margin-top:14px;color:#a6afaa}.world-strip{display:flex;align-items:center;gap:20px;font-size:18px;line-height:26px;padding:12px 20px;margin-top:12px;background:#0c1519;border-left:2px solid #68736b;min-height:64px}.world-strip .label{color:#a6afaa}.focus-grid{display:grid;grid-template-columns:400px 1fr;gap:24px;margin-top:16px;height:500px}.focus-story{padding:20px 24px}.focus-story .votive{height:150px;display:flex;align-items:center;justify-content:center}.votive .glyph{width:74px;height:74px;color:#87958a}.focus-story p{margin-top:14px}.focus-choice{padding:20px 24px;position:relative}.choice-pair{display:flex;gap:12px;margin-top:18px}.choice-pair .btn{flex:1}.effect-row{display:grid;grid-template-columns:94px 1fr;gap:12px;margin-top:14px;font-size:20px;line-height:30px}.effect-row .label{color:#a6afaa}.submit{position:absolute;bottom:0;left:0;right:0;height:76px;padding:14px 24px;display:flex;align-items:center;justify-content:space-between;border-top:1px solid #43504f;background:#10191d}.submit .btn{min-width:210px}.summary-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-top:16px}.metric{background:#10191d;padding:16px 20px;border-bottom:1px solid #43504f}.metric .value{font-size:30px;line-height:44px;font-variant-numeric:tabular-nums}.metric .small{margin-top:4px}.warning{margin-top:16px;padding:16px 20px;background:#231b1d;border-left:3px solid #b77768}.body-grid{display:grid;grid-template-columns:1.1fr 1fr;gap:24px;margin-top:20px}.section-title{display:flex;justify-content:space-between;align-items:center;padding-bottom:12px;border-bottom:1px solid #43504f}.data-row{display:flex;gap:18px;align-items:center;justify-content:space-between;min-height:52px;border-bottom:1px solid #293735}.world-body{height:308px}.scene-slot{position:relative;height:310px;background:radial-gradient(ellipse at 50% 67%,#293a39,transparent 58%),#0a1216;overflow:hidden;display:flex;align-items:flex-end;padding:24px}.scene-slot:before{content:"";position:absolute;left:30%;top:18%;width:40%;height:52%;border:1px solid #62757044;transform:perspective(200px) rotateX(45deg) rotateZ(-30deg);box-shadow:0 0 0 35px #53655e08,0 0 0 80px #53655e04}.scene-slot .slot-note{z-index:1;font-size:18px;color:#a6afaa}.strategy{display:flex;gap:10px;margin:18px 0}.strategy .btn{flex:1}.mini-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}.mini-grid div{border-left:1px solid #43504f;padding-left:14px}.mini-grid strong{display:block;font-size:28px;font-weight:400}.summary-banner{margin-top:18px;padding:12px 18px;background:#111b1f;border-left:2px solid #c7ba96}.sheet{width:1600px;min-height:1120px;padding:48px;background:#0c1317}.sheet-header{border-bottom:1px solid #43504f;padding-bottom:24px}.sheet-header h1{font-size:34px;letter-spacing:2px}.sheet-header p{margin-top:10px;color:#a6afaa}.sheet-grid{display:grid;grid-template-columns:1fr 1fr;gap:32px;margin-top:32px}.sample-block{padding:24px;background:#10191d}.sample-block h2{margin-bottom:20px;font-size:25px}.sample-block p{margin-top:12px}.states{display:flex;gap:16px;flex-wrap:wrap}.swatches{display:flex;gap:18px;margin-top:16px}.swatch{width:56px;height:48px;border:1px solid #69716c}.sheet-foot{margin-top:32px;color:#a6afaa;font-size:18px}.annotated{position:absolute;border:1px dashed #a99abb;background:#a99abb07;color:#e2d9ed;pointer-events:none}.annotated span{font-size:18px;background:#24202d;padding:4px 10px;position:absolute;top:2px;left:2px;white-space:nowrap}.board-caption{width:1600px;height:76px;padding:16px 24px;background:#141b20;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #43504f}.board-caption strong{font-size:24px;font-weight:500}.board-caption span{font-size:18px;color:#a6afaa}.board-footer{height:48px;padding:10px 24px;font-size:18px;color:#a6afaa;background:#141b20}.compact p{margin:8px 0}.long-row{display:flex;align-items:center;gap:12px;min-height:52px;border-bottom:1px solid #43504f}.long-row .long{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;min-width:0}.empty{padding:24px;border-left:1px solid #43504f;color:#a6afaa}.stacks{display:flex;flex-direction:column;gap:16px}.modal-demo{padding:24px;border:1px solid #68736b;background:#182227}.modal-demo .row{justify-content:flex-end;margin-top:18px}
'''

def top(early=False):
    state=REAL_PREVIEW['projection'] if early else {'turn':46,'whispers':5,'faith':18,'capacity':125,'awakening':65}
    resources=symbol('whispers',f'低语 <span class="num">{state["whispers"]}</span>','cyan',30,'whisper')+symbol('faith',f'信仰 <span class="num">{state["faith"]}</span> / {state["capacity"]}','gold',30,'faith')+symbol('awakening',f'苏醒 <span class="num">{state["awakening"]}</span>','violet',30,'awakening')
    nav=''.join(symbol(n,t,'gold',23) for n,t in [('world',f'世界 {1 if early else 12}'),('person','人物'),('maintenance','收支'),('cult','关注与名额'),('awakening','本体')])+'<span>暂停</span>'
    return f'<header class="top"><div>第 {state["turn"]} 回合<span class="phase">· 神意行动</span></div><div class="global">{resources}</div><nav>{nav}</nav></header>'
def index(selected=False):
    names=['镜证议会 · 01','盐梦诸邦 · 02','千面公社 · 03','镜证议会 · 04','盐梦诸邦 · 05','千面公社 · 06']
    entries=''.join(f'<div class="entry {"selected" if selected and i==3 else ""}" data-subject-id="display-cult-{i+1:02}">{sigil("cult",33)}<div class="entry-label">{n}<small>{"祈求将到期" if i==5 else "教团 · " + ("守持" if i%2 else "传教")}</small></div></div>' for i,n in enumerate(names))
    return f'<aside class="index"><div class="row between"><h2>{symbol("cult","教团",size=30)}</h2><span class="num">12</span></div><div class="search">{sigil("search",22,"muted")} <span>查找名称</span></div>{entries}<div class="foot"><div class="row between"><span>‹</span><span>1–6 / 12</span><span>›</span></div><div class="rule"></div>{symbol("prayer","待处理 3 →",size=24)}</div></aside>'
def dock(early=False):
    powers=''.join(f'<div class="power {"locked" if int(p["unlock_awakening"])>(10 if early else 65) else ""}" data-power="{p["id"]}">{seal(POWER_SYMBOLS[p["id"]],32)}<span>{esc(p["name"])}</span></div>' for p in POWERS)
    relics=''.join(f'<div class="relic">{relic_sprite(i)}<div><span class="relic-name">{n}</span><div class="small {"bound" if i==0 else ""}">{state}</div></div></div>' for i,n,state in [(0,'根钉','绑定 · 镜证04'),(1,'余响铃','携带 · 伊文'),(2,'空名印','保管 · 盐梦02')])
    if early: relics='<div class="small" style="flex:1">当前圣物 0<br>尚无圣物 · 已知取得机会从关联世界出现</div>'
    return f'<footer class="dock"><div class="dock-label">权能</div><div class="powers">{powers}</div><div class="relics">{relics}<span class="relic-record">{"记录" if early else "圣物18"}<br>全部 ›</span></div></footer>'
def shell(body, selected=False, annotations=False, early=False):
    side=index(selected)
    if early: side=f'<aside class="index"><div class="row between"><h2>{symbol("cult","教团",size=28)}</h2><span class="num">1</span></div><div class="search">⌕ 查找名称</div><div class="entry early-entry" style="height:108px">{sigil("cult",33)}<div class="entry-label"><span>盐梦诸邦</span><span>001 的教团</span><small>活跃 · 守持</small></div></div><div class="foot">待处理祈求　1 →</div></aside>'
    recent='<span>第3轮 · 教团形成</span><span>第4轮 · 收到祈求 · 求告的祭司</span>' if early else '<span>第45轮 · 盐梦02 留下仪式见证</span><span class="risk">梵星10 · 本轮末扣押空名印</span>'
    s=f'<div class="screen"><div class="ambient"></div>{top(early)}{side}<main class="main">{body}</main><div class="chronicle">{symbol("history","编年史 ›",size=24)}{recent}<button class="btn quiet end" style="height:44px">结束回合 →</button></div>{dock(early)}'
    if annotations:
        for key,label in [('top','A  全局状态 / 固定56'),('index','B  主体索引 / 208'),('main','C  当前任务 / 1336 × 668'),('chronicle','D  近期记录 / 32'),('dock','E  权能 + 圣物 / 84')]:
            x,y,w,h=TOKENS['geometry'][key]
            s+=f'<div class="annotated" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><span>{label}</span></div>'
    return s+'</div>'
def cost(variant):
    return f'{PARAMS["prayer_"+variant+"_whispers"]} 低语 · {PARAMS["prayer_"+variant+"_faith"]} 信仰'
def compact_cost(variant):
    return symbol('whispers',PARAMS['prayer_'+variant+'_whispers'],'cyan',18)+symbol('faith',PARAMS['prayer_'+variant+'_faith'],'gold',18)
def round_body():
    cards=[]
    fixtures=[('PRAYER_01','relatives','米拉 · 幸存者','千面06','请求本轮到期','病危者：伊莲 · 米拉的亲属','原病危期限：第47轮末。','原危机与两人的关系 →'),('PRAYER_05','ritual','塞拉 · 祭司','盐梦02','第48轮到期','我已主持祭仪。请在祭日结束前，留下可见的见证。','当地产生了可回应的祭仪联系。','人物、机构与世界态势 →'),('PRAYER_04','evidence','伊文 · 见证者','镜证04','第47轮到期','他保存了无法解释的见闻，希望得到一种证实。','异常记录与现有见证者均可追查。','异常记录与相关人物 →')]
    for i,(pid,emblem,person,world,due,quote,context,source) in enumerate(fixtures):
        cards.append(f'<article class="prayer"><div class="prayer-symbol-row">{seal(emblem,42,large=True)}<div class="metadata"><span class="world-name">{world}</span><span class="tag {"risk" if i==0 else ""}">{due}</span></div></div><h2>{esc(PRAYERS[pid]["title"])}</h2><div class="identity">{sigil("person",23,"bone")}{person}</div><p class="quote">{quote}</p><p class="context">{context}</p><div class="choices"><button class="btn">{symbol("shallow","浅触",size=26)}<small>{compact_cost("shallow")}</small></button><button class="btn">{symbol("deep","深应",size=26)}<small>{compact_cost("deep")}</small></button></div><div class="source">{sigil("history",19,"cyan")} {source}</div></article>')
    return f'<div class="prayer-intro"><h1>{sigil("prayer",42)}有声音向你求告</h1><p class="small">待处理祈求 3　·　本轮可回应 1 次　·　选择回应方式，查看具体后果</p></div><div class="prayer-grid">'+''.join(cards)+'</div><div style="text-align:center;margin-top:24px" class="small">查看人物、世界或使用权能后，仍可回到这里回应。</div>'
def strip():
    return '<div class="world-strip"><span class="accent">盐梦02 ›</span><span><span class="label">屏障</span> 50 · 45轮确知</span><span><span class="label">污染</span> 25–49</span><span><span class="label">察觉</span> 25–49</span><span><span class="label">稳定</span> 75–100</span><span class="small">其余为45轮估计 · 来源 ›</span></div>'
def prayer_body():
    outcomes=REAL_PREVIEW['variants']['shallow']['session_preview']['preview']['outcomes']
    probs=''.join(f'<span class="{tone}">{name} {outcomes[key]}%</span>' for key,name,tone in [('deep','深刻成功','favour'),('success','成功','favour'),('failure','失败','loss'),('disaster','灾变','catastrophe')])
    return f'''<div class="main-head"><div class="row"><button class="btn quiet">‹ 总览</button><h2>{esc(PRAYERS['PRAYER_05']['title'])}</h2></div><span class="tag">待处理祈求 1 · 本轮可回应 1 次</span></div><div class="world-strip">{symbol("world","盐梦诸邦 · 001 ›","cyan",28,"world-name")}{symbol("barrier",'屏障 <span class="unknown">未掌握</span>',"cyan",26,"metric-inline")}{symbol("pollution",'污染 <span class="unknown">未掌握</span>',"gold",26,"metric-inline")}{symbol("alert",'察觉 <span class="unknown">未掌握</span>',"gold",26,"metric-inline")}{symbol("stability",'稳定 <span class="unknown">未掌握</span>',"bone",26,"metric-inline")}<span class="small">暂无已知反制</span></div><div class="focus-grid"><section class="focus-story plate"><div class="row between"><h3>{symbol("person","求告的祭司","gold",28)}</h3><span class="small deadline">第6轮到期</span></div><p>请回应我们的祭日。</p><div class="votive">{seal("person",80)}</div><div class="small">相关机构与祭仪记录 ›<br>查看求告者的已知经历 ›</div></section><section class="focus-choice plate"><div class="row between"><h3>{symbol("prayer","回应这次祈求",size=28)}</h3><button class="btn quiet">关闭行动 ×</button></div><div class="small">求告的祭司 · 盐梦诸邦 · 001</div><div class="choice-pair" style="margin-top:12px"><button class="btn selected">{symbol("shallow","✓ 浅触",size=26)}　{cost('shallow')}</button><button class="btn">{symbol("deep","深应",size=26)}　{cost('deep')}</button></div><div class="probabilities">{probs}</div><div class="effect-row"><span class="label">必付</span><span>当地察觉 +2</span></div><div class="effect-row"><span class="label">成功</span><span>本机构留下仪式见证；污染 +2，深刻成功时 +3。</span></div><div class="effect-row"><span class="label">失败</span><span>本次仪式没有成为神迹见证。</span></div><div class="effect-row"><span class="risk">灾变额外</span><span>回应者理智 −5；当地察觉 +3。</span></div><div class="small" style="margin-top:12px">更多准备与逐项后果 ›　　执行后供奉安排 ›</div><div class="submit"><div class="cost-summary"><span>{cost('shallow')}</span><div class="small">消耗本轮唯一回应机会</div></div><button class="btn primary">{symbol("shallow","以浅触回应",size=26)}</button></div></section></div>'''
def manage_body():
    return f'''<div class="main-head"><div class="row"><button class="btn quiet">‹ 总览</button><h2>{sigil("cult",38)}镜证04 · 教团</h2><span class="tag">活跃</span></div><span class="small">查看世界态势 ›</span></div><div class="world-strip" style="display:block"><div class="row">{symbol("world","镜证04 ›","cyan",26,"world-name")}{symbol("barrier","屏障 28 · 确知","cyan",26,"metric-inline")}{symbol("pollution","污染 50–74","gold",26,"metric-inline")}{symbol("alert","察觉 50–74","gold",26,"metric-inline")}{symbol("stability","稳定 50–74","bone",26,"metric-inline")}<span class="small">第45轮 · 其余估计 · 来源 ›</span></div><div class="row" style="margin-top:8px"><span class="risk">{symbol("event","清洗教团 · 第47轮末","red",25)}</span><span>目标：本教团 · 无名信众 −20% · 凝聚 −10</span></div></div><div class="body-grid"><section><div class="scene-slot"><div class="slot-note">文化场景独立制作<br>此处仅标示中央资产可用范围</div></div><div class="summary-banner row between">{symbol("person","领袖 伊文 ›",size=28)}{symbol("cult","具名成员 7 ›",size=28)}{symbol("relatives","信众 64",size=28)}</div><div class="row" style="margin-top:18px"><button class="btn">{symbol("person","成员与职责",size=24)}</button><button class="btn">{symbol("ritual","当前活动",size=24)}</button><button class="btn">{symbol("evidence","材料与圣物",size=24)}</button></div></section><section class="surface"><div class="section-title"><h3>{sigil("cult",32)}经营与持续责任</h3><span class="small">凝聚 70</span></div><div class="strategy"><button class="btn selected">✓ 守持</button><button class="btn">传教</button><button class="btn">敛藏</button></div><p class="small">选择策略先比较影响；实际费用与后果以当前预览为准。</p><div class="data-row"><span>本轮指令</span><span>守持 · 查看比较 ›</span></div><div class="data-row"><span>有效锚点</span><span>1　查看护持与媒介 ›</span></div><div class="data-row"><span class="risk">供奉缺口</span><span class="risk">1　查看支付次序 ›</span></div><div class="data-row"><span>实际收入与支出</span><span>本轮收支 ›</span></div><div class="small" style="margin-top:20px">查看和比较不会提前收费。<br>收入在维护与指令结算后入账。</div></section></div>'''
def world_body():
    metrics=[('barrier','cyan','屏障','28','第45轮 · 确知'),('pollution','gold','污染','50–74','第45轮 · 估计'),('alert','gold','察觉','50–74','第45轮 · 估计'),('stability','bone','稳定','50–74','第45轮 · 估计')]
    m=''.join(f'<div class="metric"><div class="metric-heading">{sigil(name,40,tone)}<span class="small">{a}</span></div><div class="value">{b}</div><div class="small">{c}</div></div>' for name,tone,a,b,c in metrics)
    return f'''<div class="main-head"><div class="row"><button class="btn quiet">‹ 总览</button><h2>{sigil("world",38,"cyan")}镜证议会 · 04</h2></div><span class="small">已知范围 · 保留观察时点</span></div><div class="summary-grid">{m}</div><div class="warning"><div class="row between"><h3 class="risk">{sigil("event",30,"red")}清洗教团 · 第47轮末</h3><span class="small">已公告反制</span></div><p style="margin-top:8px">目标：镜证04的教团　　后果：无名信众 −20% · 凝聚 −10</p></div><div class="body-grid world-body"><section class="surface"><div class="section-title"><h3>{sigil("cult",32)}现实中的依托</h3><span class="small">已知范围</span></div><div class="data-row"><span>当地教团</span><span>1　镜证04教团 ›</span></div><div class="data-row"><span>有效锚点</span><span>1　护持与供奉 ›</span></div><div class="data-row"><span>已知机构</span><span>3　查看机构 ›</span></div><div class="data-row"><span>人物与材料</span><span>查看关联对象 ›</span></div></section><section class="surface"><div class="section-title"><h3>{sigil("world",32,"cyan")}你最后知晓的世界</h3><span class="small">第45轮</span></div><p style="margin-top:20px">观察来自教团供奉所维持的联系。</p><p class="small" style="margin-top:12px">区间描述当时的情况。没有新的观察时，保留原记录与时间。</p><div class="row" style="margin-top:24px"><button class="btn">{symbol("evidence","查看来源","cyan",25)}</button><button class="btn">{symbol("history","已知历史",size=25)}</button></div></section></div>'''
def components():
    states = [
        ('普通', '', '查看来源', 'history'),
        ('悬停', 'hover', '查看来源', 'history'),
        ('按下', 'pressed', '查看来源', 'history'),
        ('已选中', 'selected', '浅触', 'shallow'),
        ('键盘焦点', 'focus', '查看来源', 'history'),
        ('主要提交', 'primary', '以浅触回应', 'shallow'),
        ('危险确认', 'danger', '确认中止', 'close'),
        ('当前不可用', 'disabled', '降临', 'manifest'),
    ]
    state_samples = ''.join(
        f'<div style="display:flex;align-items:center;justify-content:space-between;gap:12px">'
        f'<span class="small">{label}</span><button class="btn {state}" '
        f'style="min-width:178px">{symbol(glyph, text, "muted" if state == "disabled" else "gold", 24)}</button></div>'
        for label, state, text, glyph in states
    )
    text_samples = ''.join(
        f'<div class="data-row" style="gap:16px;min-height:46px">'
        f'<span class="small" style="width:120px;flex-shrink:0">{role}</span>'
        f'<span style="color:{color};flex:1;text-align:left">{text}</span></div>'
        for role, color, text in [
            ('金色 · 重点', 'var(--gold-hi)', '请回应我们的祭日'),
            ('青色 · 可查对象', 'var(--cyan)', '盐梦诸邦 · 001　›'),
            ('骨色 · 正文', 'var(--paper)', '查看资料不会消耗回应机会。'),
            ('灰色 · 辅助', 'var(--muted)', '第 0 轮观察 · 区间估计'),
            ('红色 · 风险', 'var(--red)', '必付代价：当地察觉 +8'),
            ('紫色 · 神性', 'var(--violet)', '苏醒　10'),
        ]
    )
    graphic_samples = [
        ('资源', symbol('whispers', '', 'cyan', size=34) + symbol('faith', '', size=34) + symbol('awakening', '', 'violet', size=34), '分别保留专属颜色'),
        ('世界', seal('world', 36), '可查的现实联系'),
        ('教团', seal('cult', 36), '组织身份'),
        ('人物', seal('person', 36), '具名个体'),
        ('权能', seal('listen', 36), '稳定的动作符号'),
        ('圣物', relic_sprite(0), '物件像与实例名称'),
        ('状态', sigil('event', 40, 'red'), '图形和文字共同提示'),
    ]
    graphics = ''.join(
        f'<div style="display:flex;align-items:center;gap:14px;min-height:66px;'
        f'border-bottom:1px solid #78674844"><div style="width:116px;flex-shrink:0;'
        f'display:flex;align-items:center;justify-content:center;gap:2px">{image}</div>'
        f'<div><span class="serif" style="font-size:22px;color:var(--gold)">{label}</span>'
        f'<div class="small">{description}</div></div></div>'
        for label, image, description in graphic_samples
    )
    powers = ''.join(
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:10px;'
        f'min-height:98px;justify-content:center">{seal(POWER_SYMBOLS[row["id"]], 40)}'
        f'<span class="serif" style="font-size:20px;color:var(--gold-hi)">{esc(row["name"])}</span></div>'
        for row in POWERS
    )
    metrics = ''.join(
        f'<div class="data-row" style="min-height:56px">'
        f'{symbol(glyph, label, "cyan" if glyph == "barrier" else "gold", 32)}'
        f'<span><span class="num">{value}</span>　<span class="small">第0轮估计</span></span></div>'
        for glyph, label, value in [('barrier', '屏障', '75–100'), ('pollution', '污染', '0–24'), ('alert', '察觉', '0–24'), ('stability', '稳定', '50–74')]
    )
    return f'''<div class="sheet"><header class="sheet-header"><h1 style="font-size:28px;line-height:36px">幽界群像 / 控件与信息规范 0.2</h1><p>旧铜刻印、骨色文字、具象图形与幽暗承字面 · 同一套组件覆盖游戏各场景</p></header><div class="sheet-grid" style="grid-template-columns:repeat(2,minmax(0,1fr));align-items:stretch">
<section class="sample-block"><h2>{sigil('shallow', 36)}01　材质按钮 / 八种状态</h2><div style="display:grid;grid-template-columns:1fr;gap:10px">{state_samples}</div><p class="small">焦点表示键盘所在位置；选中表示当前选择。不可用说明原因：需苏醒 90，当前 65。</p></section>
<section class="sample-block"><h2>{sigil('evidence', 36)}02　文字层级 / 六类语义</h2>{text_samples}<div class="rule"></div><p style="font-size:28px;line-height:36px;color:var(--gold-hi)" class="serif">标题 28 / 36</p><p>正文 20 / 30　身份、选择、代价与后果。</p><p class="small">辅助 18 / 26　来源、观察时点与补充说明。颜色始终配合名称和文字。</p></section>
<section class="sample-block"><h2>{sigil('cult', 36)}03　图形角色 / 七类分工</h2>{graphics}<p class="small">身份、动作与物件分别识别；图标保持含义，不按列表位置换符号。</p></section>
<section class="sample-block"><h2>{sigil('manifest', 36)}04　十二权能 / 完整图标序列</h2><div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px 16px">{powers}</div><div class="rule"></div><p class="small">图形、名称与顺序共同建立识别。未解锁仍可查看；是否可施放由真实条件决定。</p><p class="small">刻印保留实体轮廓、暗槽与高光，尺寸变化沿用同一图形。</p></section>
<section class="sample-block"><h2>{sigil('world', 36)}05　世界四维 / 历史知情</h2><p class="world-name">镜证议会 · 001　<span class="small">真实新局 · 第1轮</span></p>{metrics}<p class="small">四项分别表达；以上均来自第0轮观察，不能据此声称当前实时值。</p><p>“未掌握”不填零；确值、区间和来源分别展示。</p></section>
<section class="sample-block"><h2>{sigil('barrier', 36)}06　旧铜框 / 暗面 / 骨色承载</h2><div class="surface" style="position:relative;margin-top:12px;padding:22px 24px"><div class="row">{seal('prayer', 36)}<div><h3 style="font-size:24px">主体边界 · 旧铜刻框</h3><p class="small">界定当前对象与任务，转角与刻痕保留身份。</p></div></div><div class="rule"></div><p>承字面 · 深青黑哑面</p><p class="small">提供连续阅读底色；场景光照不穿过关键文字。</p></div><div class="row" style="margin-top:22px;flex-wrap:wrap"><button class="btn selected">{symbol('shallow', '已选 · 浅触', size=24)}</button><button class="btn primary">{symbol('shallow', '以浅触回应', size=24)}</button></div><p class="small">选中用暖金面，执行用更亮的浅骨金面；刻框、暗面、图标共用材质关系，各自承担不同层级。</p></section>
<section class="sample-block"><h2>{sigil('search', 36)}07　长名称 / 检索 / 对照</h2><div class="search" style="margin-top:0">{sigil('search', 24, 'bone')}<span>查找名称、人物或关联对象</span></div><div class="long-row" style="min-height:64px">{sigil('evidence', 30)}<span class="long">镜证议会中负责记录异常与主持长期见证仪式的机构</span><span class="link">›</span></div><p class="small">索引可截断长名称；详情与焦点提示显示全文。数值、期限和提交代价保持完整。</p><div class="row" style="margin-top:20px;flex-wrap:wrap"><button class="btn">{symbol('person', '查看人物', size=26)}</button><button class="btn">{symbol('relatives', '留作对照', size=26)}</button></div><p class="small">最多两个对象临时并置，查看后仍保留当前行动草稿。</p><div class="data-row"><span>请求期限</span><span style="color:var(--gold-hi)">第 6 轮</span></div></section>
<section class="sample-block"><h2>{sigil('event', 36)}08　不可逆确认 / 空状态</h2><div class="modal-demo" style="padding:20px 24px"><h3 style="font-size:24px;color:var(--red)">{symbol('manifest', '中止降临', 'red', 30)}</h3><p>已有进度不保留，已支付的费用不会退还。</p><div class="row"><button class="btn">返回</button><button class="btn danger">确认中止</button></div></div><div style="margin-top:24px;display:flex;gap:16px;align-items:flex-start">{sigil('cult', 36, 'muted')}<div><h3 style="font-size:22px;color:var(--paper)">尚无教团</h3><p class="small">从已知人物和祈求查看建立联系的机会。</p></div></div><div style="margin-top:20px;display:flex;gap:16px;align-items:center">{sigil('search', 30, 'muted')}<span class="small">没有匹配的对象</span><button class="btn quiet">清除筛选</button></div><p class="small">未拥有、筛选无匹配和加载失败分别说明；失败时保留原状态并给出具体原因。</p></section>
</div><div class="sheet-foot">组件样板覆盖祈求、权能、教团、人物、圣物、锚点、世界、收支、事件、降临、终局和菜单。图标名称与规则数据来源分开维护；待制作人视觉审阅。</div></div>'''

boards={
 '01-round-prayers':('01 / 新回合 · 祈求居中',shell(round_body()),'展示局面 · 1–3项居中比较；选择浅触/深应直接准备；每轮只有一次回应机会。'),
 '02-prayer-response':('02 / 具体祈求 · 后果与固定提交',shell(prayer_body(),early=True),'真实T4原型数据的布局重排 · 预览概率与费用来自隔离Session；新UI尚未接入引擎。'),
 '03-cult-management':('03 / 教团管理 · 内容与操作分区',shell(manage_body(),True),'布局样板 · 中央文化场景独立制作；策略预览、成员、活动、材料和供奉沿真实入口。'),
 '04-world-situation':('04 / 世界态势 · 历史知情与当前反制',shell(world_body(),True),'展示局面 · 四维分列，来源与时间常驻；反制的目标、期限、后果独立表达。'),
 '05-layout-measurements':('05 / 固定布局母版 · 1600 × 900',shell(round_body(),annotations=True),'底部功能栏84px + 下缘12px = 96px（10.7%画高）；中央1336 × 668；不修改现行生产分辨率。'),
 '06-components':('06 / 控件与信息规范',components(),''),
}
for name,(title,body,note) in boards.items():
    caption=f'<div class="board-caption"><strong>{title}</strong><span>幽界群像 · UI母版 0.2 / 待制作人审阅</span></div>'
    footer=f'<div class="board-footer">{note}</div>' if note else ''
    (OUT/(name+'.html')).write_text('<!doctype html><meta charset="utf-8"><title>'+title+'</title><style>'+STYLE+(ROOT/'tools/ui-master/skin.css').read_text()+'</style>'+caption+body+footer,encoding='utf-8')
(OUT/'boards.json').write_text(json.dumps({'status':'DESIGN_PROPOSAL_NOT_ENGINE_IMPLEMENTATION','boards':list(boards),'data_sources':['data/powers.csv','data/prayers.csv','data/run_parameters.csv','runtime/prayer-preview.json','runtime/semantic-sample.json'],'fixture':'Boards 01/03/04/05: artificial mature T46 composition; identities/counts are display fixtures, not natural-play evidence. Board 02: actual T4 projection and Session preview from runtime/prayer-preview.json, with effects checked against runtime/semantic-sample.json. Board 06: component studies. No new UI runtime or aesthetic acceptance claim.'},ensure_ascii=False,indent=2)+'\n')
print('Wrote',len(boards),'render sources and shared tokens to',OUT)
