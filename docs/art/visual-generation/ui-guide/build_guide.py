#!/usr/bin/env python3
"""Build documentation figures and the offline reader from the current standard.

No game art is repainted. Source screenshots/video remain unchanged.
Requires Python 3, Pillow and markdown-it-py. Native specimen PNGs are produced
separately by specimens.gd, directly from the accepted Godot components.
"""
from __future__ import annotations

import hashlib
import html
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from markdown_it import MarkdownIt
from markdown_it.token import Token

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ART = HERE.parent
IMAGES = HERE / 'images'
STANDARD = ART / 'ui-art-standard.md'
BASELINE = ART / 'ui-approved-baseline.json'
FONT = ART / 'ui-study/type/LXGWWenKaiScreen.ttf'
PAPER = '#eeede7'
INK = '#222e2c'
MUTED = '#56635d'
ANNOTATION = '#965339'


def face(size: int):
    return ImageFont.truetype(str(FONT), size)


def sheet(title: str, sub: str, height=1160):
    canvas = Image.new('RGB', (1600, height), PAPER)
    d = ImageDraw.Draw(canvas)
    d.text((48, 26), title, font=face(38), fill=INK)
    d.text((49, 80), sub, font=face(22), fill=MUTED)
    return canvas, d


def marker(d, x, y, number):
    d.ellipse((x-19, y-19, x+19, y+19), fill=ANNOTATION, outline=PAPER, width=2)
    d.text((x, y-1), str(number), font=face(24), fill='white', anchor='mm')


def verify_baseline():
    base = json.loads(BASELINE.read_text())
    for item in base['artifacts']:
        p = ROOT / item['path']
        assert hashlib.sha256(p.read_bytes()).hexdigest() == item['sha256'], p


def context_figure():
    canvas, d = sheet('01 / 获准母版：先读客体与决定，再察觉窥视',
                      '实际 Godot 截图 · 文档仅加编号，不改画面 · 棕色标记不属于游戏界面', 1160)
    shot = Image.open(ART/'ui-study/evidence/02-twelve-worlds.png').convert('RGB')
    canvas.paste(shot.resize((1440,810), Image.Resampling.LANCZOS), (80,122))
    points=[(120,68),(1240,172),(1110,738),(1750,990),(32,490),(196,365)]
    for i,(x,y) in enumerate(points,1):marker(d,80+x*.75,122+y*.75,i)
    items=[('轮次与菜单', '游戏内不常驻标题；原菜单仍保留。'),
           ('大尺度暗纹','主体遮住大眼形，避免成为完整徽标。'),
           ('焦点画牌','完整图文；邻卡不露零碎指标。'),
           ('实际操作','颜料块分轻重，文字与命中区稳定。'),
           ('窗口边界','雾、暗膜与带眼卷形成为同一环境。'),
           ('阅读暗场','背景退后，字形完整，不以颗粒侵蚀。')]
    for i,(title,body) in enumerate(items):
        col=i%3; row=i//3; x=80+col*490; y=955+row*88
        d.text((x,y),f'{i+1:02}  {title}',font=face(25),fill=INK)
        d.text((x,y+34),body,font=face(21),fill=MUTED)
    canvas.save(IMAGES/'overview-annotated.png')


def reading_figure():
    canvas,d=sheet('02 / 图层与阅读边界',
                    '左：获准实机上的区域标注　右：合成顺序示意；不是新页面布局',1080)
    shot=Image.open(ART/'ui-study/evidence/02-twelve-worlds.png').convert('RGB')
    display=shot.resize((1024,576),Image.Resampling.LANCZOS)
    canvas.paste(display,(48,150))
    # Draw the actual shader quiet boxes, transformed from logical coordinates.
    boxes=[(30,25,320,112),(1020,24,1250,110),(30,638,425,687),(1050,638,1250,687)]
    for a,b,c,e in boxes:
        d.rectangle((48+a*.8,150+b*.8,48+c*.8,150+e*.8),outline='#dfbd85',width=3)
    # Occupied reading area is a conceptual exclusion, not an existing shader mask.
    d.rectangle((48+318*.8,150+126*.8,48+1238*.8,150+576*.8),outline='#879d9a',width=2)
    rows=[('上层 / 实际交互','文字、卡牌、控件、弹层'),
          ('前雾','同时掩住卷形与附着眼'),
          ('卷形与附着眼','固定曲面 UV，一起弯曲'),
          ('后雾与暗膜','膜上两眼同边界函数起伏'),
          ('底层 / 绘画背景','远雾、中景色带、近景暗幕')]
    for i,(title,body) in enumerate(rows):
        y=154+i*115
        d.rectangle((1110,y,1550,y+93),fill=['#d7ddd7','#dce0db','#d4dbd4','#cbd3ce','#bfcac5'][i])
        d.text((1127,y+13),title,font=face(25),fill=INK)
        d.text((1127,y+51),body,font=face(21),fill=MUTED)
    d.text((50,756),'金色框 = 母版四角静默区　/　灰绿框 = 实际交互内容范围',font=face(24),fill=INK)
    notes=[
        '前雾只比暗膜／卷形更靠前，整组仍位于卡片与文字下面。',
        '母版静默区是固定坐标；推广到中央长文、弹层时必须按真实占用区适配。',
        '不能把右侧图层示意当作新视觉素材；纹理、颜色与形状从原生组件复用。',
        '阅读优先不是把雾全部删掉，而是让低频环境运动退到决定之外。']
    for i,line in enumerate(notes):d.text((50,810+i*51),line,font=face(25),fill=MUTED)
    canvas.save(IMAGES/'layers-reading.png')


def motion_figure():
    canvas,d=sheet('03 / 眼睛是表面的一部分，雾穿过整个表面',
                    '取自获准无损 WebP · 固定屏幕裁切范围 · 2× 最近邻放大仅为看清附着关系',950)
    anim=Image.open(ART/'ui-study/evidence/peripheral-motion.webp')
    for col,t in enumerate([0,6,12,18]):
        anim.seek(t*60)
        frame=anim.convert('RGB')
        top=frame.crop((430,0,610,115)).resize((360,230),Image.Resampling.NEAREST)
        left=frame.crop((0,290,105,420)).resize((210,260),Image.Resampling.NEAREST)
        x=48+col*390
        d.text((x,137),f'{t:02} 秒',font=face(28),fill=INK)
        canvas.paste(top,(x,184))
        d.text((x,434),'顶部卷形与眼',font=face(23),fill=MUTED)
        canvas.paste(left,(x,485))
        d.text((x,764),'左侧卷形与眼',font=face(23),fill=MUTED)
    d.text((48,830),'观察眼心、组织边缘和卷形的相对位置；雾同时遮住它们，不能像贴纸各自漂移。',font=face(26),fill=INK)
    d.text((48,877),'静帧用于说明附着；连续性请看旁边 24 秒、60 fps 的原始动态，不能只凭四帧判断。',font=face(23),fill=MUTED)
    canvas.save(IMAGES/'motion-attachment.png')


def material_figure():
    canvas,d=sheet('04 / 色值是端点，画面要保留颜料组织',
                    '色块：当前源码 sRGB 参数　/　下方：获准实机原像素局部，最近邻放大',1000)
    values=[('墨底','#101719'),('主文字','#d9d7be'),('次文字','#b4bdaa'),('焦点短边','#b1c09b'),('卡身暗部','#19282a'),('说明底板','#26362f')]
    for i,(name,color) in enumerate(values):
        x=48+i*253
        d.rectangle((x,155,x+226,265),fill=color,outline='#b6bdb3',width=1)
        d.text((x,280),name,font=face(26),fill=INK)
        d.text((x,319),color,font=face(23),fill=MUTED)
    shot=Image.open(ART/'ui-study/evidence/02-twelve-worlds.png').convert('RGB')
    examples=[((974,660,999,820),(48,440),'不连续卡边','局部干笔，长边安静。'),
              ((995,727,1345,815),(320,440),'文字与暗压纹','字形完整，纹样退入底材。'),
              ((1718,960,1860,1018),(1110,440),'主操作色块','保留文字与命中区。')]
    for crop,pos,title,note in examples:
        part=shot.crop(crop);part=part.resize((part.width*2,part.height*2),Image.Resampling.NEAREST)
        canvas.paste(part,pos)
        d.text((pos[0],805),title,font=face(27),fill=INK)
        d.text((pos[0],850),note,font=face(22),fill=MUTED)
    d.text((48,932),'禁止用上排纯色色块替代下排材质；最高光与强色继续留给世界、教团、人物立绘。',font=face(25),fill=INK)
    canvas.save(IMAGES/'palette-material.png')


def slug(text):
    return re.sub(r'[^\w\-\u4e00-\u9fff ]','',text.lower()).strip().replace(' ','-')


def specimen_details(item):
    sources=''.join(
        f'<li><a href="../../../../{html.escape(p)}">{html.escape(p)}</a></li>'
        for p in item['sources'])
    return f'''<details class="specimen-source">
<summary>{html.escape(item['id'])} · {html.escape(item['status'])} · {html.escape(item['rules'])} · 来源与尺寸</summary>
<p>{html.escape(item['provenance'])}</p><p>不适用：{html.escape(item['not_for'])}</p><ul>{sources}</ul>
</details>
'''


def render_reader(raw, manifest):
    """Render one illustrated body; manifest metadata enriches its existing figures."""
    raw=re.sub(r'^---\n.*?\n---\n','',raw,flags=re.S)
    md=MarkdownIt('commonmark',{'html':True})
    tokens=md.parse(raw)
    exhibits={'ui-guide/'+item['image']:item for item in manifest['exhibits']}
    toc=[];seen={};images={};insert_after={}
    for i,t in enumerate(tokens):
        if t.type=='heading_open':
            title=tokens[i+1].content; anchor=slug(title)
            count=seen.get(anchor,0);seen[anchor]=count+1
            if count:anchor+='-'+str(count)
            t.attrSet('id',anchor)
            if t.tag=='h2':toc.append((anchor,title))
        if t.type in ('html_block','html_inline'):
            t.content=re.sub(r'(src|href|poster)="(?![a-z]+:|/|#)([^"]+)"',r'\1="../\2"',t.content)
        # Standard paths are relative to visual-generation/, reader lives a level down.
        for ch in t.children or []:
            attr='src' if ch.type=='image' else ('href' if ch.type=='link_open' else '')
            if not attr:continue
            val=ch.attrGet(attr)
            if ch.type=='image':
                images[val]=images.get(val,0)+1
                ch.attrSet('loading','lazy')
                if val in exhibits:
                    item=exhibits[val]
                    if tokens[i-1].type!='paragraph_open' or tokens[i+1].type!='paragraph_close':
                        raise ValueError(f"Specimen must occupy its own paragraph: {val}")
                    tokens[i-1].attrSet('id','ex-'+item['id'])
                    tokens[i-1].attrSet('class','illustration')
                    # Keep the author's caption next to the picture, then append provenance.
                    close=i+1
                    if (i+4<len(tokens) and tokens[i+2].type=='paragraph_open'
                            and tokens[i+3].type=='inline' and tokens[i+4].type=='paragraph_close'
                            and tokens[i+3].children and tokens[i+3].children[0].type=='em_open'):
                        close=i+4
                        tokens[i+2].attrSet('class','figure-caption')
                    extra=Token('html_block','',0);extra.content=specimen_details(item)
                    insert_after.setdefault(close,[]).append(extra)
            if val and not re.match(r'(?:[a-z]+:|#|/)',val):ch.attrSet(attr,'../'+val)
    duplicate=[p for p,count in images.items() if count!=1]
    missing=[p for p in exhibits if images.get(p)!=1]
    if duplicate or missing:
        raise ValueError(f"Each figure must appear once in the standard. Duplicates: {duplicate}; missing: {missing}")
    decorated=[]
    for i,t in enumerate(tokens):
        decorated.append(t);decorated.extend(insert_after.get(i,[]))
    native_image=md.renderer.rules['image']
    def enlarged_image(tokens,index,options,env):
        src=html.escape(tokens[index].attrGet('src') or '',quote=True)
        return f'<a class="enlarge" href="{src}" target="_blank" rel="noopener" title="打开原尺寸">'+native_image(tokens,index,options,env)+'</a>'
    md.renderer.rules['image']=enlarged_image
    body=md.renderer.render(decorated,md.options,{})
    navigation=''.join(f'<a href="#{html.escape(a)}">{html.escape(b)}</a>' for a,b in toc)
    quick=[]
    for prefix,label in [('1.','母版'),('4.','卡片与控件'),('5.','动态'),('9.','实施与反馈')]:
        target=next((a for a,title in toc if title.startswith(prefix)),None)
        if target:quick.append(f'<a href="#{html.escape(target)}">{label}</a>')
    quick.append('<a href="#references">引用范围</a>')
    refs=''.join(f'''<details class="reference"><summary>{html.escape(x['id'])} · {html.escape(x['title'])} <span class="muted">{html.escape(x['status'])}</span></summary><p>允许：{html.escape(x['allowed'])}</p><p>排除：{html.escape(x['excluded'])}</p><a href="../../../../{html.escape(x['path'])}">查看来源</a></details>''' for x in manifest['references'])
    out='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>邪神苏醒 · 图文美术规范</title><style>
@font-face{font-family:WenKai;src:url('../ui-study/type/LXGWWenKaiScreen.ttf')}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:#efeee8;color:#23312d;font:17px/1.8 WenKai,serif}a{color:#305e55;text-underline-offset:4px}aside{position:fixed;inset:0 auto 0 0;width:246px;padding:28px 22px;background:#e4e7df;border-right:1px solid #c9cfc5;overflow:auto}aside strong{font-size:21px;display:block;margin-bottom:18px}aside a{display:block;text-decoration:none;padding:5px 0;font-size:14px}aside details{padding:10px 0;background:transparent;margin-top:16px}main{margin-left:246px;padding:32px 4.5vw 100px;max-width:1880px}.reader-note{font-size:14px;color:#647066;border-bottom:1px solid #c8cfc3;padding-bottom:14px;margin-bottom:24px}h1{font-size:36px;line-height:1.35;margin:12px 0 22px}h2{font-size:29px;line-height:1.4;border-top:1px solid #bfc9bd;padding-top:35px;margin-top:70px}h3{font-size:23px;line-height:1.55;margin-top:33px}p{max-width:1100px}img{max-width:100%;height:auto;display:block}video{display:block;width:100%;background:#090e12}.enlarge{display:block;cursor:zoom-in}details{background:#e5e8df;padding:12px 17px;font-size:14px}summary{cursor:pointer}details ul{word-break:break-word}code{background:#dfe5da;padding:2px 5px;font:13px/1.7 monospace;overflow-wrap:anywhere}pre{white-space:pre-wrap;background:#e0e5da;padding:18px;font-size:13px}pre code{padding:0}li{margin:8px 0}#rules img{max-height:900px;width:auto;object-fit:contain;margin:24px 0}.figure-caption,.muted{color:#647066;font-size:14px}.specimen-source{margin:12px 0 42px}.reference{margin:12px 0}.reference summary .muted{display:block;margin-left:20px}#rules .guide-video{margin:24px 0}#rules .guide-video video{max-width:1100px}
@media(max-width:900px){aside{position:static;width:auto;border:0;padding:16px 24px}aside strong{font-size:18px;margin-bottom:8px}aside .quick-nav{display:flex;flex-wrap:wrap;gap:6px}aside .quick-nav a{padding:3px 8px}aside details{margin-top:4px}main{margin:0;padding:24px}h1{font-size:29px}}
@media print{aside,.reader-note{display:none}main{margin:0;padding:0}h2{break-before:page}body{background:white}}
</style></head><body><aside><strong>邪神苏醒<br>图文美术规范</strong><nav class="quick-nav">QUICK</nav><details><summary>全部章节</summary><nav>NAV</nav></details></aside><main>
<div class="reader-note">单一图文正文 · 图片可点开原尺寸，来源附于原图下方 · <a href="../ui-art-standard.md">Markdown 源文</a></div>
<article id="rules">BODY</article>
<section id="references"><h2>附录 · 引用有效范围</h2><p>每份来源仅在登记范围内生效。展开查看允许与排除项；指纹及完整记录见 <a href="manifest.json">来源清单</a>。</p>REFERENCES</section>
</main></body></html>'''
    for key,value in [('QUICK',''.join(quick)),('NAV',navigation),('REFERENCES',refs),('BODY',body)]:out=out.replace(key,value)
    return out


def make_reader():
    manifest=json.loads((HERE/'manifest.json').read_text())
    # A changed source needs a scope review; never silently refresh its approval.
    for ref in manifest['references']:
        source=ROOT/ref['path']
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=ref['sha256']:
            raise RuntimeError(f"Reference changed: {ref['id']} {ref['path']}. Review allowed/excluded scope before updating manifest.")
    for item in manifest['exhibits']:
        if not (HERE/item['image']).is_file():raise FileNotFoundError(HERE/item['image'])
    (HERE/'index.html').write_text(render_reader(STANDARD.read_text(),manifest))


if __name__ == '__main__':
    import argparse
    ap=argparse.ArgumentParser();ap.add_argument('--figures-only',action='store_true');ap.add_argument('--reader-only',action='store_true');args=ap.parse_args()
    IMAGES.mkdir(parents=True,exist_ok=True)
    verify_baseline()
    if not args.reader_only:
        context_figure();reading_figure();motion_figure();material_figure()
    if not args.figures_only:make_reader()
    print('Guide built from approved artifacts; original images unchanged.')
