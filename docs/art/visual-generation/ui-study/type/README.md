# 当前字体分工：粗印标题与连续笔形正文

2026-11-12：制作人认可粗印画牌的方向，但指出文本略难读。本轮保留 Fusion Pixel 作为大标题／牌名的粗印尝试，新增 **霞鹜文楷屏幕阅读版 LXGW WenKai Screen Regular** 供正文、按钮和数字使用；它具有连续完整笔形，不依赖系统字体，不给小字添加随机缺墨。

## 正文字体来源与许可

- 文件：`LXGWWenKaiScreen.ttf`
- 官方项目：[lxgw/LxgwWenKai-Screen](https://github.com/lxgw/LxgwWenKai-Screen)
- 固定发行版：[v1.530](https://github.com/lxgw/LxgwWenKai-Screen/releases/tag/v1.530)
- 原始文件：[LXGWWenKaiScreen.ttf](https://github.com/lxgw/LxgwWenKai-Screen/releases/download/v1.530/LXGWWenKaiScreen.ttf)
- 完整许可证：`LXGWWenKaiScreen-OFL.txt`，取自[同版官方 OFL](https://github.com/lxgw/LxgwWenKai-Screen/blob/v1.530/OFL.txt)。许可证包含 LXGW、文楷／文楷 GB、Klee Project 的版权与保留名称声明。
- 官方原始字体，未修改、未子集化；26,095,590 字节。
- SHA-256：`abd13364163e3cd84372b333f2fdcee9efb848634668f1c0ce5788dcd059ee61`

SIL Open Font License 1.1 允许随软件捆绑、嵌入和分发，需保留版权及完整许可证；字体不能单独销售，字体许可不因项目代码许可改变。此目录保留完整上游文件，没有改动保留字体名称或字形。

## Godot 接入建议与最小核对

正文从逻辑 14px 起看，宽松文字区可用 16px；在 1280→1920 画幅中分别为屏幕 21px／24px。既有窄按钮须按实际宽度检查，不能为了更大字号把原按钮挤宽。Godot 4.7.2 实测「供奉与收支」在 12／14／16px 下分别为 60／70／80 逻辑像素。

设置 `FontFile.antialiasing = TextServer.FONT_ANTIALIASING_GRAY`、`hinting = TextServer.HINTING_LIGHT`；关闭 MSDF，保持普通字体光栅化，控件用线性纹理过滤。不做描边、粗体模拟或噪声侵蚀。用字形、墨色和相邻粗绘材质保留书写感，不通过破坏笔画追求粗糙。

已做一次直接加载：字体名 `LXGW WenKai Screen`，样式 `Regular`；小样常用字「邪神苏醒、诸界态势、屏障、污染、察觉、稳定、信仰、供奉收支、祈求、已知锚点、听潮密会、裁判者」及数字无缺字。12／14／16px 字体高度为 15／17／19px。仅核对载入与小样字形，实际清晰度由最终游戏截图确认。

# 标题字体：Fusion Pixel 12px

本目录包含 **缝合像素 / Fusion Pixel 12px，比例模式、简体中文版本**。它是实际随项目携带的字体文件，不依赖用户安装系统字体。本轮用其有限的字形网格试验粗粒度游戏印字；不表示整套插图必须改成像素画，也不代表字体方向已经获制作人确认。

- 文件：`fusion-pixel-12px-proportional-zh_hans.ttf`
- 作者：TakWolf 及所附许可证中的上游字形作者
- 官方项目：https://github.com/TakWolf/fusion-pixel-font
- 固定发行版：https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.11.10
- 原始下载包：https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.11.10/fusion-pixel-font-12px-proportional-ttf-v2026.11.10.zip
- 取自官方包，未修改、未子集化；7,316,996 字节。
- SHA-256：`7e93fedda2c55bb37badb2262aaf43b08e3cb5976a0e3de2d90986ce59fe902e`

字体以 SIL Open Font License 1.1 发布。完整主许可证在 `OFL.txt`，官方包所附 Ark Pixel、Cubic 11、Galmuri 的完整许可证保存在 `LICENSES/`。分发时保留这些文件；字体本身沿用原许可，项目代码许可不替代字体许可。

## 上一轮点阵方案的使用记录

先按屏幕实际 24px 的正文/控件与 36px 的标题试读，都是原始 12px 字形网格的整数倍。若逻辑 1280×720 放到 1920×1080，逻辑字号 16/24 对应屏幕 24/36；最终以 Godot 实际截图的笔画粗细检查为准。不要加描边、强制粗体或用破损遮罩切断小字。正文保持完整，粗粝感由字形、底材、墨色共同承担。

可从 `FontFile.antialiasing = TextServer.FONT_ANTIALIASING_NONE`、关闭 MSDF 开始；避免通过非整数节点缩放让单个字的笔画忽粗忽细。若需要自由尺寸或倾斜，不宜一味关闭过滤，应查看实际画面。标题可单独做轻微印色错位，但正文与数字不做随机扰动。

Godot 4.7.2 已成功直接加载该 TTF，字体名为 `Fusion Pixel 12px Prop zh-Hans`；对「邪神苏醒、诸界态势、塔穆什、听潮密会、静海、远灯、信仰、祈求、教团、人物、世界、供奉、收藏、十二权能」的字形抽查没有缺字。这是小样所用字形核对，不是整个游戏文本覆盖证明。
