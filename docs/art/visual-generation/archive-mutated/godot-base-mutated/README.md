# 旧日星图 · Eldritch Starchart

克苏鲁主题星球 / 星系 / 星际奇景概念立绘生成器（Blender + Godot 4.7，Web 导出）。

- `blender/build_assets.py` — Blender 无头程序化建模（星球、低多边形星球、带吸盘触手、星环、陨石、方尖碑、星门、浮空遗迹），导出 `assets/eldritch_assets.glb`
  `blender -b -P blender/build_assets.py -- assets/eldritch_assets.glb`
- `blender/subset_fonts.py` — 将 Noto CJK 子集化为界面实际用到的字形
- `shaders/` — 星球表面（11 种原型，`ARCH` 宏编译变体）、星云天空、大气、星环、恒星/黑洞、触手、遗迹、裂隙、传送门、后期风格化（8 种美术风格）
- `scripts/generator.gd` — 构图与场景生成；`overlay.gd` — 标题卡/标注/风格边框；`lore.gd` — 克苏鲁命名与设定文案
- 导出：`godot --headless --path project --export-release "Web" ../index.html`（thread_support=false）
- 截图自检：`godot --path project -- --shots=/tmp/out --cfg=scene:0,style:2,seed:42`
