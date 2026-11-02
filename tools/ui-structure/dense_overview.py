"""One original, data-sized UI study. Not a runtime state or gameplay content.

Names, costs and order come from CSV. The explicit illustrative state below
exists only to check presentation at 12 cults / 12 members / 12 relic instances.
Render the emitted vector primitives with render_dense_overview.ps1.
"""
from pathlib import Path
import csv
import json
import math
import html

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/game-state'
def table(name):
    with (ROOT / 'data' / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

powers = table('powers.csv')
relic_types = table('relics.csv')
profiles = table('civilization_profiles.csv')
E = []
C = dict(bg='#10191d', panel='#182429', alt='#1b292e', ink='#edf0e9', muted='#a4b6b5',
         dim='#849a9a', rule='#35494e', gold='#d9bc7e', teal='#85ccbd', red='#f6a38c',
         redbg='#432f2b', select='#2a4143', blue='#9ec6db')

def rect(x,y,w,h,fill,stroke='none'):
    E.append(dict(type='rect',x=x,y=y,w=w,h=h,fill=C.get(fill,fill),stroke=C.get(stroke,stroke)))
def line(x1,y1,x2,y2,color='rule',width=1):
    E.append(dict(type='line',x1=x1,y1=y1,x2=x2,y2=y2,stroke=C.get(color,color),strokeWidth=width))
def text(x,y,s,size=17,color='ink',weight=400,anchor='start'):
    E.append(dict(type='text',x=x,y=y,text=str(s),size=size,fill=C.get(color,color),weight=weight,anchor=anchor))
def button(x,y,w,h,label,active=False,color=None,size=16):
    rect(x,y,w,h,'select' if active else 'panel',color or ('gold' if active else 'rule'))
    text(x+w/2,y+h/2+6,label,size,color or ('gold' if active else 'ink'),600 if active else 400,'middle')
def section(x,y,title,right='',width=420):
    text(x,y,title,20,'gold',600)
    if right: text(x+width-24,y,right,14,'muted',anchor='end')
    line(x,y+12,x+width-24,y+12)

# Illustrative state: 6 planets, 4 systems, 2 cosmic worlds, one cult each.
profile_ix = [0,1,2,0,1,2,3,4,5,3,6,7]
counts = [49,36,25,64,16,9,81,64,49,36,100,25]
cohesion = [80,75,64,70,60,52,80,76,70,64,85,60]
orders = ['传教','传教','守持','传教','敛藏','守持','守持','敛藏','守持','守持','守持','敛藏']
leaders = ['记录者','祭司','使者','记录者','祭司','幸存者','祭司','记录者','使者','祭司','记录者','听众寻求者']
focused = {1,2,4}
anchors = {1:1,2:1,4:1,7:2,8:2,9:2,11:4}
income = [math.floor(min(8,math.sqrt(n))*c/100*(.5 if o=='敛藏' else 1)) for n,c,o in zip(counts,cohesion,orders)]
relic_counts = [2,1,1,1,1,0,1,1,1,1,1,1]
worlds = [f"{profiles[p]['name']} · {i:02}" for i,p in enumerate(profile_ix,1)]
intelligence = [('32','22'),('41','37'),('？','？'),('29','61'),('？','？'),('18','？'),('53','48'),('？','？'),('36','？'),('？','72'),('47','？'),('？','？')]
notices = ['传教预计 +2 信众','传教预计 +3 信众','—','供奉缺 1 · 苏醒将 −4','敛藏 · 察觉 −2','祈求到期 · 余 1 轮','—','敛藏 · 察觉 −2','—','圣物将在本轮末被扣押','—','敛藏 · 察觉 −2']
assert len(worlds)==12 and len(powers)==12 and len(relic_types)==6
assert sum(anchors.values())==13 and len(anchors)==7
assert 10+12+3*4+3*7+10==65 and 18-3*2==12
assert all(counts[i-1]>=12 and cohesion[i-1]>=40 for i in anchors)
assert sum(income)==42 and sum(relic_counts)==12

# The screen uses continuous overview + a detail depth, not category navigation.
rect(0,0,1920,1080,'bg')
rect(0,0,1920,68,'panel')
line(20,66,1900,66,'gold')
text(28,34,'第 46 回合',24,'gold',600)
text(29,56,'自由行动',15,'muted')
stats=[(205,'低语','4 / 5'),(365,'信仰','18 / 125'),(570,'苏醒','65'),(710,'洞见','12'),(818,'创伤','0')]
for x,k,v in stats:
    text(x,25,k,14,'muted');text(x,53,v,25,'ink',600)
text(960,25,'关注世界',14,'muted');text(960,53,'3 / 3',23,'teal',600)
text(1100,25,'正式成员',14,'muted');text(1100,53,'12 / 12',23,'gold',600)
text(1250,25,'临时互动人物',14,'muted');text(1250,53,'3 / 12',23)
text(1442,25,'苏醒来源',14,'muted')
text(1442,51,'初生 10 + 洞见 12 + 锚点 43',16)
button(1798,18,100,35,'暂停 Ⅱ')

# Expense order is visible, not collapsed to a misleading positive net income.
rect(20,78,1880,48,'redbg')
text(36,108,'本轮支出',18,'gold',600)
text(144,108,'信仰 18  →  三团传教 −6  →  余 12 支付锚点，需 13',19)
text(755,108,'缺 1',21,'red',600)
line(840,88,840,115,'rule')
text(860,108,'按现状预计收入 +42',18,'teal',600)
text(1068,108,'演化后结算，不能先用',16,'muted')
text(1380,108,'按当前安排：1 处锚点停供',17,'red')
text(1670,108,'苏醒 65 → 61',20,'red',600)

text(28,151,'祈求  已回应 1/1',18,'muted',600)
text(228,151,'其余 2 项只读 ›',16,'muted')
text(435,151,'「不要让她死去」余 1 轮 · 千面公社 06',17,'red')
text(925,151,'事件  本轮已处理',17,'muted')
text(1240,151,'人物 15 · 含 3 名祈求人  ›',16,'blue')
button(1660,135,240,28,'世界档案 · 12 个世界  ›',size=16)

# Main overview. Rows are cults, with their world and connected subjects.
rect(20,174,1230,564,'panel','rule')
text(36,204,'教团  12',23,'gold',600)
text(176,203,'● 关注中 3',15,'teal')
text(326,203,'世界读数为上次所知；？= 尚未掌握',15,'muted')
text(777,203,'全部 12 · 临近后果 2 · 供奉不足 1',15,'muted')
text(1228,203,'筛选 / 排序',15,'blue',anchor='end')
cols=[(45,'所在世界 / 教团'),(237,'领袖'),(363,'无名信众'),(445,'凝聚'),(512,'污染'),(580,'察觉'),(648,'本轮指令'),(755,'收入'),(835,'锚点 / 供奉'),(958,'圣物'),(1019,'当前变化与危机')]
for x,s in cols: text(x,234,s,14,'muted')
line(36,244,1234,244)
for j in range(12):
    i=j+1;y=245+j*39
    if i==4:rect(22,y,1226,39,'select');rect(22,y,4,39,'gold')
    elif j%2==1:rect(22,y,1226,39,'alt')
    if i in focused:text(34,y+25,'●',12,'teal')
    text(54,y+25,worlds[j],17,'gold' if i==4 else 'ink',600 if i==4 else 400)
    label=leaders[j] if len(leaders[j])<=3 else '寻听者'
    text(237,y+25,f'{label} N{i:02}',16)
    text(397,y+25,counts[j],18,anchor='middle')
    text(462,y+25,cohesion[j],18,'teal' if cohesion[j]>=70 else 'ink',anchor='middle')
    for x,val in zip([530,598],intelligence[j]):text(x,y+25,val,16,'dim' if val=='？' else 'muted',anchor='middle')
    text(648,y+25,orders[j]+' ▾',17,'teal' if orders[j]=='传教' else 'ink')
    if orders[j]=='传教':text(720,y+25,'−2',14,'gold')
    text(773,y+25,f'+{income[j]}',18,'teal',anchor='middle')
    text(839,y+25,f'1 处 / {anchors[i]}' if i in anchors else '—',16,'red' if i==4 else 'ink')
    text(974,y+25,relic_counts[j],17,anchor='middle')
    text(1019,y+25,notices[j],15,'red' if i in (4,6,10) else 'muted')
    line(36,y+39,1234,y+39)
text(36,731,'12 / 12 教团均在运行；查看不改变关注。指令沿用到改动，费用在结束回合后支付。',14,'muted')

# Persistent inventory: instances, locations and bindings, rather than 6 type icons.
rect(20,750,1230,224,'panel','rule')
text(36,778,'圣物  12 件',22,'gold',600)
text(210,777,'7 件绑定锚点 · 5 件由人物携带',15,'muted')
text(1228,777,'锚点绑定在前  /  筛选  ›',15,'blue',anchor='end')
line(36,790,1234,790)
# type index, serial, world, relation. R03 is the selected cult's bound relic.
items=[(0,'R01',1,'绑定解释机构 · N01 护持'),(4,'R02',2,'绑定解释机构 · N02 护持'),
       (4,'R03',4,'绑定解释机构 · N04 护持'),(3,'R04',7,'绑定解释机构 · N07 护持'),
       (1,'R05',8,'绑定解释机构 · N08 护持'),(2,'R06',9,'绑定解释机构 · N09 护持'),
       (5,'R07',11,'绑定解释机构 · N11 护持'),(0,'R08',1,'N01 携带 · 入梦准备 +10'),
       (1,'R09',3,'N03 携带 · 穿隙准备 +10'),(3,'R10',5,'N05 携带 · 播种准备 +10'),
       (2,'R11',10,'N10 携带 · 本轮末扣押'),(5,'R12',12,'N12 携带 · 献祭/降临 +10')]
for k,(ti,rid,w,relation) in enumerate(items):
    x=36+(k//6)*607;y=812+(k%6)*28
    if rid=='R03':rect(x-5,y-20,595,27,'select')
    text(x,y,relic_types[ti]['name'],17,'gold' if rid=='R03' else 'ink',600 if rid=='R03' else 400)
    text(x+94,y,rid,14,'dim')
    text(x+148,y,f'世界 {w:02}',15,'muted')
    text(x+235,y,relation,15,'red' if rid=='R11' else 'teal' if k>=7 else 'muted')
line(633,801,633,962)

# The inspector is a second information depth; the 12-cult overview stays visible.
rect(1266,174,432,800,'panel','rule')
text(1284,204,'镜证议会 · 04 的教团',22,'gold',600)
text(1680,203,'已关注',14,'teal',anchor='end')
line(1284,218,1680,218)
text(1284,243,'星球文明 · 技术主导 · 议会制',17)
text(1284,268,'屏障 75   稳定 70   污染 29   察觉 61',16)
text(1284,291,'各项情报的来源与获知时间 ›',14,'blue')
text(1284,315,'解释机构：锚点有效   传播机构：运作中',15,'muted')
text(1284,339,'秩序机构：运作中',15,'muted')
text(1680,339,'世界资料 ›',15,'blue',anchor='end')

section(1284,373,'记录者 N04','人物详情 ›',420)
text(1284,411,'领袖 / 锚点护持者    忠诚 76 · 理智 52',16)
text(1284,437,'意志 2   洞察 3   影响 1   适应 2',16,'muted')
text(1284,463,'在场 · 本轮执行机会未用 · 无随身圣物',15,'teal')
text(1284,489,'秘密集会 ›  2 低语 · 4 信仰',16,'blue')

section(1284,525,'本轮指令','已有可用招募渠道',420)
button(1284,549,120,34,'传教',True)
button(1416,549,120,34,'敛藏')
button(1548,549,132,34,'守持')
text(1284,608,'传教：−2 信仰 / +2 信众 / 察觉 +2',17)
text(1284,635,'改为守持可省 2，供奉将足额；信众不增长。',15,'muted')

section(1284,673,'锚点供奉','调整顺序 / 停供 ›',420)
text(1284,711,'当前有效 7 处 · 需 13 · 可支付 12',17)
text(1284,738,'支付顺序（世界编号 / 信仰）',14,'muted')
for j,(w,cost) in enumerate([(11,4),(7,2),(8,2),(9,2),(1,1),(2,1),(4,1)]):
    x=1284+j*57
    button(x,750,51,33,f'{w:02}/{cost}',j==6,'red' if j==6 else None,14)
text(1284,807,'最后：世界 04 缺 1 → 结算时休眠，苏醒 −4',15,'red')

section(1284,845,'根钉 R03','圣物详情 ›',420)
text(1284,881,'世界 04 · 解释机构锚点 ← N04 护持',16)
text(1284,908,'已绑定，不能同时用于权能准备。',15,'muted')
text(1284,934,'解绑会立即失去该锚点的 4 点苏醒。',15,'red')
text(1284,960,'查看解绑后果 ›',15,'blue')

# All twelve powers, in source order. Unlock is not full target eligibility.
rect(1714,174,186,800,'panel','rule')
text(1730,205,'权能',23,'gold',600)
text(1885,205,'12',17,'muted',anchor='end')
text(1730,230,'选择后检查目标与条件',13,'muted')
for i,p in enumerate(powers):
    y=247+i*55
    line(1728,y-5,1886,y-5)
    locked=int(p['unlock_awakening'])>65
    text(1730,y+16,p['name'],20,'dim' if locked else 'ink',600)
    text(1879,y+15,f'{i+1:02}',13,'dim',anchor='end')
    detail=f"需苏醒 {p['unlock_awakening']}" if locked else f"{p['whispers']} 低语 · {p['faith']} 信仰"
    text(1730,y+39,detail,14,'dim' if locked else 'muted')
text(1730,931,'本轮已回应',15,'muted')
text(1730,953,'敛息不可用',15,'dim')

# Chronicle stays exposed; current threats do not depend on opening it.
rect(20,987,1668,69,'panel','rule')
text(36,1012,'编年史',18,'gold',600)
text(151,1012,'第 46 回合 · 已回应一项祈求；低语 5 → 4。',16)
text(151,1040,'第 45 回合 · 焚星圣统 10 预告扣押空名印 R11；将在本轮结束时执行。',16,'muted')
text(1668,1013,'展开全部 ›',15,'blue',anchor='end')
button(1706,987,194,69,'结束回合  ›',True,size=23)
text(24,1075,'结构示意 · 12 世界 / 12 教团 / 12 正式成员 / 12 圣物实例 · 祈求处理后的自由行动 · 数值为规则一致的构造局面，非实机截图',13,'dim')

model=dict(width=1920,height=1080,elements=E,scenario=dict(worlds=worlds,followers=counts,
    cohesion=cohesion,orders=orders,income=income,focused=sorted(focused),anchor_upkeep=anchors,
    relic_instances=[dict(type=relic_types[t]['id'],id=r,world=w,relation=s) for t,r,w,s in items],
    current_faith=18,expansion_cost=6,anchor_cost=13,expected_income_before_evolution=42,
    current_awakening=65,after_shortfall_awakening=61,source='illustrative, not a runtime save'))
(OUT/'ui-density-overview.json').write_text(json.dumps(model,ensure_ascii=False,indent=2),encoding='utf-8')
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">',
     '<style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif}</style>']
for e in E:
    typ=e['type']
    if typ=='text':
        svg.append(f'<text x="{e["x"]}" y="{e["y"]}" font-size="{e["size"]}" font-weight="{e["weight"]}" fill="{e["fill"]}" text-anchor="{e["anchor"]}">{html.escape(e["text"])}</text>')
    elif typ=='rect':
        svg.append(f'<rect x="{e["x"]}" y="{e["y"]}" width="{e["w"]}" height="{e["h"]}" fill="{e["fill"]}" stroke="{e["stroke"]}"/>')
    elif typ=='line':
        svg.append(f'<line x1="{e["x1"]}" y1="{e["y1"]}" x2="{e["x2"]}" y2="{e["y2"]}" stroke="{e["stroke"]}" stroke-width="{e["strokeWidth"]}"/>')
svg.append('</svg>')
(OUT/'ui-density-overview.svg').write_text('\n'.join(svg),encoding='utf-8')
print(f'1 view; {len(E)} primitives; 12 cults; 12 relic instances; 12 powers; income {sum(income)}; upkeep 13; shortfall 1')
