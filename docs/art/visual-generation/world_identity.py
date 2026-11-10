#!/usr/bin/env python3
"""世界身份 → 原作生成参数（草案 / 最先验证用）。

输入只有策划数据 data/civilization_profiles.csv 与本局 seed，不查表写死八个世界。
输出：world_identity.csv（可审阅的推导过程）+ 调用 godot-base 的 --shots 出图。

三层身份：
  ① 蓝本语法（CSV 固定字段）：层级 / 四范式 / 传播 / 组织 / 稳定 —— 决定画面结构
  ② 实例相位（world_id + 本局 seed 独立随机流）：决定噪声相位，不消耗规则 RNG
  ③ 当前状态（污染 / 察觉 / 反制）：本轮验证固定为开局干净态，留待下游接入

判据（可否证）：
  A 八个蓝本并排，不看名字能否分辨出「不是同一个地方」，且靠的是结构不是色差
  B 同一蓝本两个实例，能否既认出同一类文明又区分是两地
  C 同 seed 重出，逐像素一致
  D 改 CSV 一个字段，画面相应那一层跟着变（证明不是「换个 seed」）
"""
import csv, os, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]          # worktree 根
PROFILES = ROOT / 'data/civilization_profiles.csv'
VG = ROOT / 'docs/art/visual-generation'
GEN = VG / 'godot-base'
OUT = VG / 'godot-baseline' / 'worlds'
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
BASE_SEED = 1337

# 主导范式 → 地表语法（原作 ARCH）。避开凝视之眼(1)：制作人要求剔除眼睛母题。
ARCH = {
    'tech':   [5, 10, 7],    # 冷原 / 骸骨之月 / 黄衣王城：规则、结构、城
    'occult': [9, 6, 8],     # 古神之茧 / 星之彩 / 混沌核心：符文、异彩、流动
    'faith':  [7, 4, 0],     # 黄衣王城 / 炎狱之星 / 溺亡之海：殿堂、光、夜灯
    'meme':   [3, 8, 2],     # 菌蚀冥星 / 混沌核心 / 血肉之星：斑块、扩散、重复
}
# 传播方式 → 痕迹拓扑
COMM = {
    'broadcast': dict(count=1, rings=0, glyphs=0.15),   # 单一中心向外辐射
    'ritual':    dict(count=2, rings=1, glyphs=0.65),   # 同心环 + 符文
    'network':   dict(count=5, rings=0, glyphs=0.35),   # 多节点分散
}
# 组织 → 构图秩序
AUTH = {
    'hierarchy':     (1, 0.05),   # 居中、强对称、低疯狂
    'unified':       (1, 0.10),
    'council':       (2, 0.15),   # 三分
    'decentralized': (4, 0.25),   # 远景多主体
}
# 层级 → 画面尺度（composition 覆写优先级低于 organization 时保留结构差异）
TIER_COMP = {'planet': None, 'system': 5, 'cosmic': 3}   # 系统=日蚀逆光 / 宇宙=巨构地平线


def derive(row: dict, idx: int, instance: int = 0) -> dict:
    p = {k: int(row[k]) for k in ('tech', 'occult', 'faith', 'meme', 'barrier', 'stability')}
    paradigm = max(('tech', 'occult', 'faith', 'meme'), key=lambda k: p[k])
    # 主导范式定地表；次主导范式在族内选第二个，使同类范式也有细分
    order = sorted(('tech', 'occult', 'faith', 'meme'), key=lambda k: -p[k])
    arch_pool = ARCH[paradigm]
    # 实例只改噪声相位，不改蓝本语法：narrative-catalog 明确「层级/矛盾固定，防止随机生成抹掉身份」
    arch = arch_pool[0]
    cm = COMM[row['communication']]
    comp, mad0 = AUTH[row['authority']]
    if TIER_COMP[row['tier']] is not None and row['authority'] in ('unified', 'hierarchy'):
        comp = TIER_COMP[row['tier']]
    # 稳定性反向驱动疯狂；屏障驱动环阴影的存在与否
    madness = round(min(0.55, mad0 + (100 - p['stability']) / 400.0), 3)
    # 独立随机流：与项目 world_names 的私有流同理，不进入规则 RNG
    seed = BASE_SEED * 7919 + idx * 104729 + instance * 15485863 + 17
    return dict(
        world_id=row['id'], name=row['name'], tier=row['tier'],
        paradigm=paradigm, second=order[1], communication=row['communication'],
        authority=row['authority'], weakness=row['weakness'],
        barrier=p['barrier'], stability=p['stability'],
        scene=0, style=0, seed=seed, archetype=arch, palette=-1,
        composition=comp, star_type=-1, wonder=-1,
        count=cm['count'], rings=cm['rings'],
        tentacles=0, eyes=0,                       # 制作人要求剔除
        glyphs=cm['glyphs'] + p[order[1]] / 500.0,
        corruption=0.0,                          # 本轮固定为开局干净态
        madness=madness, nebula={'planet': 0.35, 'system': 0.60, 'cosmic': 0.85}[row['tier']],
        aspect=0, quality=1, animate=0,
        show_title=1, show_labels=1, show_frame=1, show_swatch=0,
    )


def num(v):
    f = float(v)
    return int(f) if f.is_integer() else round(f, 3)


def cfg(d: dict) -> str:
    keys = ['scene', 'style', 'seed', 'archetype', 'palette', 'composition', 'star_type',
            'wonder', 'count', 'rings', 'tentacles', 'eyes', 'glyphs', 'corruption',
            'madness', 'nebula', 'aspect', 'quality', 'animate',
            'show_title', 'show_labels', 'show_frame', 'show_swatch']
    return '--cfg=' + ','.join(f'{k}:{num(d[k])}' for k in keys)


def main():
    rows = list(csv.DictReader(open(PROFILES, encoding='utf-8')))
    derived = []
    for i, r in enumerate(rows):
        derived.append(derive(r, i, 0))
    # 判据 B：同蓝本第二个实例（CIV_01）
    derived.append(derive(rows[0], 0, 1))
    # 判据 D：改一个 CSV 字段（把 CIV_03 的 communication 由 network 改为 ritual）
    probe = dict(rows[2]); probe['communication'] = 'ritual'
    probe['id'] = rows[2]['id'] + '_PROBE'; derived.append(derive(probe, 2, 0))

    OUT.mkdir(parents=True, exist_ok=True)
    with open(VG / 'world_identity.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(derived[0].keys()))
        w.writeheader()
        for d in derived:
            w.writerow(d)

    cmd = [GODOT, '--path', str(GEN), '--', '--shots=' + str(OUT)] + [cfg(d) for d in derived]
    print('出图数:', len(derived))
    print('参数样例:', cfg(derived[0]))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    print('Godot rc=', r.returncode)
    if r.stderr.strip():
        print('stderr:', r.stderr.strip()[-600:])
    print('产物:')
    for p in sorted(OUT.glob('*.png')):
        print(' ', p.name, p.stat().st_size)
    return r.returncode


if __name__ == '__main__':
    sys.exit(main())
