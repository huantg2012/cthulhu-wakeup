# 幽界群像 · 单场景 Godot 样板

信息流图示：[七组＋深层路径，共八张可编辑线框](../../docs/art/echoes-ui/flow-wireframes/README.md)。S1／S2 的代表状态已在当前夹具中试作，推荐布局仍待审。

后续打磨与接入共同使用：[深信息呈现方法](../../docs/art/echoes-ui/visual-system.md#information-flow)、[七组信息流](../../docs/art/echoes-ui/component-map.md#flow-g1)、[样板S／正式J验收](../../docs/art/echoes-ui/visual-system.md#flow-delivery)。样板仅提供展示路径，不代表正式接入。

开发依据：[活设计规范](../../docs/art/echoes-ui/visual-system.md)、[功能与组件](../../docs/art/echoes-ui/component-map.md)、[当前参数](../../docs/art/echoes-ui/tokens.json)。标准启动已接规范同步检查；修改后按规范 D2 更新并显式记录。直接用 Godot 指定场景能绕过检查，不作为规范同步证明。

基于 DEC-058 与制作人最新反馈修订，待制作人视觉验收。[对齐基线](../../docs/art/echoes-ui/visual-system.md)；整屏依据 `echoes-home.png`，`ui-overflow-a.png` 和 `ui-overflow-c.png` 分别辅助顶部／警告与世界清单的局部对照，不替代整屏目标。

## 启动和操作

双击项目根目录 [美术打版.command](../../美术打版.command)，或在项目根目录运行：

```sh
./美术打版.command
# 同源控件展示：
./美术打版.command --controls
```

- 启动先展示轮初事件；选择任一处理后展示三张本轮新祈求夹具，点卡进入对应详情。事件选择仅演示，不扣费、结算或写存档；重新启动可再看。
- 左侧“世界”为当前夹具的三个联系对象，支持搜索、滚动和选择；这不是固定上限，也不会修改正式关注状态。只有镜证04、盐梦02配置了展示观察，缺失数据明确标注。
- 默认展示所选世界观察和已知教团；镜证04可进入中央教团管理预览。指令和供奉按钮仅说明接入边界，不执行经营。
- 镜证04的“成员与职责”打开展示名册，可切换成员和同一人物的栏目、查看携带物及来源，并一次返回原成员。成员、职责和持有关系仅为展示夹具；圣物详情为只读。
- 右侧祈求卡按人物、类别、诉求和期限呈现；选择后中央改为人物概念场景及详情，可切换浅触／深应、滚动完整后果、收起，或直接选择其他世界与功能。查看和切换不执行回应。
- 祈求中可查看祈求者资料和未配置的携带记录，期间行动区收起；返回或切换世界后重开同一祈求，恢复本次运行中记住的浅／深选择。
- 底部权能／圣物可横向滚动，近况是编年史展示入口。F1 切换场景图层；Esc 收起祈求或关闭预览。F2 旧版布局比较不再代表这次重组后的参考布局，不作为本轮验收依据。

`scene.tscn`、`scene.gd`、`prayer_stage.gd`、`cult_stage.gd` 与 `dock_content.gd` 使用可编辑的 Godot 节点和脚本，不是整屏截图加热点。场所和远景包含原稿裁片；人物及光照未逐层拆分。

## 共用控件

[唯一规范 V2 / V6](../../docs/art/echoes-ui/visual-system.md#control-catalog) 内包含调色板、控件清单、实际实现入口与未制作状态。`component_catalog.tscn` 直接实例化同一套原生控件；不是局部截图拼板。基础构造在 `ui_components.gd`，世界／祈求／指标／威胁在 `ui_composites.gd`，底栏条目在 `dock_content.gd`。调用方提供显示数据、资产及点击回调；界面不执行 Session 写操作。`scene.gd` 保留原辅助函数作为转发，避免破坏现有流程。

当前 API 仍按样板画幅构造；正式使用需按 V3 / D1 适配既有画幅和真实内容。完整对话框、结果／关系／维护／历史等组合仍有缺口，不能把目录覆盖当作实现覆盖。

## 素材与边界

三张祈求场景为无字生成概念示意，左侧缩略图沿用对应联系情境，不能视为确定的世界文化或人物设定；[素材与提示词记录](../../docs/art/echoes-ui/round-start-master/restoration-assets/prayer-scenes/README.md)。其他来源、裁区和制作差异见[制作记录](../../docs/art/echoes-ui/round-start-master/restoration-breakdown.md)。

人工 T46 单场景未接 Session：名称、费用、门槛和效果从正式 CSV / `experience_semantics.gd` 读取，人数、关系、观察及警告为展示夹具。祈求不支付、不结算、不推进回合、不写存档；实际祈求供给、事件、回应结果和教团经营均未接入。字体依赖本机 Songti SC，其他机器需复核。

复现正文中的两张控件图（图形渲染，执行后自动退出）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/component_catalog_capture.gd --rendering-method gl_compatibility
```

## 验证

本轮新增 `information_flow_probe.gd` 以 Godot 输入检查 S1／S2 并保存关键状态截图。图形窗口初版路径曾完成 25 项，补充 Esc、切换世界和焦点恢复后的图形复测存在输入偶发未送达，完整路径未稳定复验。最终脚本在无窗口模式走通 33 项，不能代替图形操作验收；具体状态与截图见[设计规范 D3](../../docs/art/echoes-ui/visual-system.md)。检查不证明审美通过或正式玩法接入。此前世界／祈求、底栏和视觉状态探针结果为对应旧版本的证据，不能冒充本次新状态验收。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/information_flow_probe.gd --rendering-method gl_compatibility
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/echoes-art-master/information_flow_probe.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/echoes-art-master/button_focus_probe.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/world_prayer_probe.gd --rendering-method gl_compatibility
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/dock_probe.gd --rendering-method gl_compatibility
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/echoes-art-master/visual_state_probe.gd --rendering-method gl_compatibility
```
