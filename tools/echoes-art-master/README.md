# 幽界群像 · echoes-home 原生还原样板

本轮已完成原稿拆解、代表组件实测、整屏组合与布局调整；制作人认可方向有进步，但指出融合、交互和素材问题，样板尚不能交付后续流程，待修复。唯一还原标的是 `docs/game-state/presentation-refinement-2026-11-03/echoes-home.png`；项目约束见[对齐基线](../../docs/art/echoes-ui/visual-system.md)。前版 `01`–`09`、22 项检查及旧 HTML 参数不作为本版依据。

## 启动、对照与编辑

双击根目录 [美术打版.command](../../美术打版.command)，或运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/echoes-art-master/scene.tscn
```

- 默认：中央祈求、112px 权能/圣物底栏。八项一页、两页可访问全部十二权能；四件圣物摘要保留图像、名称和状态。
- **F2**：同一原生场景切换到原稿的祈求/底栏位置，再按返回调整布局。用于观察调整影响，不是另一套获批设计。
- **F1**：分别开关海面、场所、远雾、前雾、远处联系与界面；关闭窗口或 Escape 返回。
- **Esc**：关闭预览，恢复打开前的控件焦点。

`scene.tscn` 保存主要层；`scene.gd` 在层内实例化真实 Button、Label、TextureRect、LineEdit、ScrollContainer。在 Godot Remote 树可逐项检查。根节点 Inspector 暴露祈求、底栏、近况与场所矩形，细部控件由具名构造函数编辑。它是代码构建的原生 UI，未将整屏截图加热点作为场景。

## 图层与素材职责

- `World/Background`：贯通1672×941的浪雾底图；只移除物体和UI，不更换原稿色彩方向。
- `World/Sanctuary`：原稿中不含UI的场所片段，按原位置/尺度独立放置；保留局部环境，以GPU羽化融合。不是前版重新生成的宽低建筑。
- `World/DistantFragments`：四处同源、低显露现实联系，各自独立纹理区域。
- `World/Atmosphere`：额外远雾、前雾；文字位于其上。底图已有绘画雾，关闭额外雾不代表清除全部雾。
- `Interface`：局部阅读暗面、外缘装饰、顶部、索引、世界信息、中央祈求、世界对照/近况、底栏。
- `PreviewLayer`：祈求、权能、圣物与范围说明，原生文字和滚动内容。
- `FeedbackLayer`：仅用于制作检查的图层开关。

`restoration_skin.gd` 管理同源材质家族与图集区域：暗石普通项、象牙选中项、暗心亮边操作、浅实体主动作、低亮查询边、危险红边、区域框分别处理。文字不烘焙进材质；图标按语义键、权能固定ID绑定。干净源图边缘通过九宫格只画边、不画原稿中心文字。

完整来源、尺寸、哈希、生成提示与源图区域见[资产清单](../../docs/art/echoes-ui/round-start-master/restoration-assets/manifest.json)和[制作拆解](../../docs/art/echoes-ui/round-start-master/restoration-breakdown.md)。海面与三种无字皮肤为补制素材；首八权能、资源、四维、祈求、圣物与装饰从标的独立取区。后四权能沿已有补充图集，不宣称它们在 home 原稿中有对应局部。

## 字体与可复用规范

本机 Godot 4.7.2 将 SystemFont 的 Songti SC 错选为 Black，FontVariation 的 face6 在实测中仍渲染 Black。`restoration_font.gd` 在内存中将系统 TTC 的首 face 指针指向现有 SC Regular，验证实际字重后使用；不修改系统字体，不把商业字体复制或嵌入项目。无此系统字体时走字体 fallback，其他机器需重新确认字体观感。字体对照见 `evidence/restoration-font-comparison.png`。

当前字级：标题26–30，对象/资源20–26，正文19–20，辅助及密集对照16–19。金色用于标题/标签和部分行动，暖白用于阅读，青色标世界，红色配具体风险文字，灰色辅助；四维保留原稿各自图标色族。选中面为浅色深字；焦点独立于选中，不执行动作。具体颜色/尺寸属于本次实物参数，尚未获制作人全局定版；跨场景功能合同仍见 `component-map.md` 与 `prototype-coverage.md`。

## 已验证的运行范围

`restoration_probe.gd` 使用真实鼠标/键盘事件，35项检查通过、7张截图。覆盖：两页十二权能、降临可见锁定原因、四维与锚点说明不串世界、浅深费用及分段后果、Esc与焦点、18件圣物滚动、F2不缩移场所、F1独立图层、夹具不变。最后的截图和结果以 `evidence/restoration-probe-results.json` 为准。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/restoration_probe.gd --rendering-method gl_compatibility
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/restoration_capture.gd --rendering-method gl_compatibility
```

这是人工 T46 的单场景美术与交互路径样板，**没有接入 Session**。名称、费用、门槛和效果读正式 CSV / `experience_semantics.gd`；人数、世界观察和关联关系为展示夹具。点击不支付、不推进回合、不写存档。事件先行、真实祈求供给、回应结算后释放中央、其他文化场所与完整业务页面仍属正式接入范围，不能据本探针宣布已完成。

教团切换仅展示已配置的镜证04/盐梦02数据，其他教团显示未知；不假装同步更换文化场所。全局导航及下一回合只打开范围说明。运行通过与还原质量分别判断，后者仍由制作人审阅。
