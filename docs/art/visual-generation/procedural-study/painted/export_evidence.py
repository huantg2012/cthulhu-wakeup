#!/usr/bin/env python3
"""Archive actual runtime outputs and make an offline comparison page.
This page is evidence only. The runtime never loads or selects these PNGs.
"""
import json
import shutil
import html
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = HERE / 'evidence'
rows = json.loads((OUT / 'manifest.json').read_text())
METHOD = '2D pigment and continuous drawing slope fields -> unchanged original common.style_shade -> unchanged original bloom/post; no sphere-surface equivalence'
for row in rows:
    q = row['request']
    row['style']['method'] = METHOD
    row['snapshotUrls'] = {}
    for kind, url in row['urls'].items():
        suffix = f"-p{q['personSeed']}" if kind == 'person' else ''
        name = f"{kind}-{q['template']}-w{q['seed']}-sid{q['style']}-pal{q['palette']}{suffix}.png"
        source = ROOT / url.lstrip('/')
        assert source.is_file(), source
        shutil.copy2(source, OUT / name)
        row['snapshotUrls'][kind] = name
(OUT / 'manifest.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
def fig(r, kind):
    q, i, f = r['request'], r['identity'], r['features']
    label = {'world': i['world_name'], 'cult': '候选教团 · ' + i['cult_name'], 'person': f"候选人物 · {q['personSeed']}"}[kind]
    detail = {'world': '原作真实生成', 'cult': f['cult']['construction'], 'person': f['person']['pose'] + ' · ' + f['person']['head'] + ' · ' + f['person']['robe']}[kind]
    params = f"原型 {i['archetype']} · sid {q['style']} / 表索引 {r['world']['params']['style']} · 色板 {q['palette']} {r['palette']['name']} · 世界种子 {q['seed']} · 人物种子 {q['personSeed']}"
    return f'<figure><a href="{r["snapshotUrls"][kind]}"><img src="{r["snapshotUrls"][kind]}" alt="{html.escape(label)}"></a><figcaption><b>{html.escape(label)}</b><span>{html.escape(detail)}</span><span>{html.escape(params)}</span></figcaption></figure>'
def triple(r):
    return '<section class="triple">' + ''.join(fig(r, k) for k in ('world','cult','person')) + '</section>'
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>二维生成小样 · 实际输出</title><link rel="stylesheet" href="../style.css"><header><small>2026-11-10 / 实际运行生成的归档证据</small><h1>两种世界，四位求告者</h1><p>结论：方法探索未达到制作人要求。人物仍有假人感，场景仍显规则；不认为已超越所给旧版。</p><nav><a href="http://127.0.0.1:8951/painted/">打开运行时生成器</a><a href="manifest.json">完整参数</a><a href="checks.json">必要检查结果</a><a href="user-relative-positive.png">用户的相对正面案例（仍不合格）</a></nav></header><main>'''
page += '<h2>溺亡之海 / 原作厚涂 sid 0</h2>' + triple(rows[0])
page += '<h2>黄衣王城 / 原作厚涂 sid 0</h2>' + triple(rows[1])
page += '<h2>固定溺亡之海 / 四种人物姿态</h2><p>种子按姿态分支取样：1003、1004、1009、1020。世界与教团完全相同，未通过随机挑选成品图片生成。</p><section class="people">' + ''.join(fig(r,'person') for r in rows[2:6]) + '</section>'
page += '<h2>同一王城 / 原作铜版画 sid 2</h2>' + triple(rows[6])
page += '<p>当前只实现原型 0、7。原作六个 sid 均接通；本轮实际生成检查仅 sid 0、2。其余九原型只有转译设计，尚未实现。本页是输出快照，生成器每次由代码和参数绘制新内容。</p></main></html>'
(OUT / 'review.html').write_text(page)
print('Archived 7 sample records; offline page:', OUT / 'review.html')
