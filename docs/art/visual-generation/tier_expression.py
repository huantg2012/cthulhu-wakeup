#!/usr/bin/env python3
"""验证：世界层级（planet / system / cosmic）能否在天体图上被读出来。

制作人 2026-11-09 纠正：不做城市/机构/记录/灯火/证言/契约这类文明细节，
天体图只承担「层级」这一维。world.md §36：层级表示影响与反制范围，
不是按人口逐层展开的地图 —— 所以三档不是「球 → 更多球 → 最多球」，
而是「边界闭合的单一对象 → 多个对象 + 通路 → 边界消融的场」。

控制变量：seed / archetype / palette / style 全固定，只改 tier 对应参数。
交叉验证：2 个蓝本 × 3 个 tier，看层级是否压过蓝本差异成为主导视觉维度。
不改一行 Godot 代码，只调用 godot-base 的 --shots。
"""
import subprocess, sys
from pathlib import Path

VG = Path(__file__).resolve().parent
GEN = VG / 'godot-base'
OUT = VG / 'godot-baseline' / 'tiers'
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'

# 三档：边界闭合 / 多个对象+通路 / 边界消融
TIER = {
    'planet': dict(scene=0, composition=2, count=1, star_type=-1, nebula=0.30, rings=0),
    'system': dict(scene=1, composition=0, count=5, star_type=0,  nebula=0.55, rings=0),
    'cosmic': dict(scene=0, composition=3, count=0, star_type=-1, nebula=0.90, rings=0),
}
# 两个蓝本只换地表语法与色板，用来检验「层级是否压过身份」
BLUEPRINT = {
    'A_冷原':  dict(archetype=5, palette=4),
    'B_古神茧': dict(archetype=9, palette=3),
}
COMMON = dict(seed=4242, style=0, wonder=-1, tentacles=0, eyes=0,
              glyphs=0.20, corruption=0.0, madness=0.10,
              aspect=0, quality=1, animate=0,
              show_title=1, show_labels=1, show_frame=1, show_swatch=0)
KEYS = ['scene', 'style', 'seed', 'archetype', 'palette', 'composition', 'star_type',
        'wonder', 'count', 'rings', 'tentacles', 'eyes', 'glyphs', 'corruption',
        'madness', 'nebula', 'aspect', 'quality', 'animate',
        'show_title', 'show_labels', 'show_frame', 'show_swatch']


def cfg(d):
    parts = []
    for k in KEYS:
        v = float(d[k])
        parts.append(f'{k}:{int(v) if v.is_integer() else round(v, 3)}')
    return '--cfg=' + ','.join(parts)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    order = []
    for tier, tp in TIER.items():
        for name, bp in BLUEPRINT.items():
            d = {**COMMON, **tp, **bp}
            order.append((tier, name, cfg(d)))
    cmd = [GODOT, '--path', str(GEN), '--', '--shots=' + str(OUT)] + [c for _, _, c in order]
    print('出图数:', len(order))
    for i, (t, n, _) in enumerate(order):
        print(f'  {i:02d}  {t:7s} / {n}')
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    print('Godot rc=', r.returncode)
    if r.stderr.strip():
        print('stderr:', r.stderr.strip()[-500:])
    for p in sorted(OUT.glob('*.png')):
        print(' ', p.name)
    return r.returncode


if __name__ == '__main__':
    sys.exit(main())
