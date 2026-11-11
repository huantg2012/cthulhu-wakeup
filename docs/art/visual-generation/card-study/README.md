# 立绘与 UI 承托探索

状态：ImageGen 静态母版路线已被制作人明确否决，仅留痕。当前入口为 ../procedural-study/。首轮像素平涂被评 10/100，不再是当前候选。

## 打开

双击仓库根目录 `立绘卡探索.command`，或打开本目录 `index.html`。可直接 file:// 使用。

首屏为塔穆什（CIV_02）—听潮密会—守历人·伊弥。世界名来自正式展示目录；教团、人物为明确标注的候选视觉设定，非正式 Session 对象。首屏展示画风、原型、色板、种子和构图；完整参数可展开。「原作基准对照」并排显示同参数原作与样板PNG，并可打开原尺寸。1/2/3 切 UI 承托。

交互预览仍为原有设计夹具，机制文字与身份不等于本组候选的正式接入。该预览只看材质与画面占比。

## 图像来源与当前边界

- `assets/v2-world.png`：原作 Godot 工程直接输出，960×960；与独立运行的同参数基准逐字节、逐像素一致。原工程无改动。
- `assets/v2-cult.png`、`assets/v2-person.png`：内置 ImageGen 以该原作PNG为参照直接生成的二维绘画母版，各经历一次独立检查后的定向修改；没有新增3D建模。它们不是基于seed的程序生成器，不能据此承诺世界模板量产或稳定身份变体。
- `assets/v2-*-draft.png`：本轮修改前图；最终修改的准确提示词和输入见 `generation-prompts.json`。
- 首轮 `pixel-*`、`draw_family.py` 仅作失败留痕。`rejected-3d/` 为此前被退回的建模路线，不进入当前主画面。

## 重建与核查

元数据单源 `study-manifest.csv`，世界展示名来自 `data/player_text.csv`；原作参数必须匹配已记录证据。

```sh
python3 build_manifest.py
python3 verify_reference.py
PLAYWRIGHT_MODULE=/absolute/path/to/playwright node verify_display.cjs
```

`verify_reference.py` 核对原工程指纹、参考PNG、样板PNG和像素一致；原作完整取图命令在 `reference-check/fidelity.json`。
`verify_display.cjs` 只核本轮：三图加载、不被容器裁切、无滤镜/透明度/遮罩、身份与参数可见、对照几何一致。输出 `reference-check/display-check.json` 和两张证据图，不跑整局回归。

原样板HTML需更新时运行 `build_ui.py`；该脚本保留原连续交互底稿，叠加本目录的展示代码。

## 视觉自查与保留差距

首轮失败：三档蓝灰平涂无法承接原作的连续体积、强轮廓光、材料和多尺度纹理。名字还与海洋祭仪造型脱节。

本轮首次母版仍有教团微细纹处处锐利、右下处处高亮，以及人物衣褶均匀描亮的问题。定向修改保留建筑/潮池/钟架与人物持书手势，合并屋瓦和岩壁碎纹、压暗右下，减少袖袍微亮线；原作星球保持原图。

仍待人审：二维母版的笔触较有方向性，原作是程序纹理；人物皮肤/历书仍较具象。当前仅一个世界语汇与一个人物姿态，未验证其他世界、画风和量产。技术检查不等于审美通过。
