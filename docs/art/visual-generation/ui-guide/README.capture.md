# 原生控件规格图的重建

本目录图板是当前美术规范的可再生实物说明，使用实际 Godot 控件、母版画法和随包字体；不接 Session，不写存档，不修改获准母版或正式场景。

在项目根目录运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script docs/art/visual-generation/ui-guide/specimens.gd
```

逻辑画布 1280×720，输出 1920×1080。脚本运行后自动关闭自己的捕获窗口；不会关闭其他 Godot 进程。图片输出到本目录 `images/`。

只更新某一张时在命令末尾加 `-- --only=cards-approved`（可替换为下列其他文件名，不带 `.png`），避免覆盖无改动的图。

- `controls-approved.png`（C01）：三种按钮角色 × 五种状态。原生 `Button` 先经当前 `production/locked_controls.gd` 构建，再直接调用母版 `Paint.style_buttons()`。常态／hover 为母版常用外观；focus／pressed／disabled 为现有实现的状态复现，不声称逐态获得制作人验收。
- `controls-extension.png`（X03）：同样三角色 × 五状态的同源补齐目标，待审。保留同一底材与原生状态，显式将常态／focus／pressed 文字统一为 `#d9d7be`，hover 为 `#eee8cc`，disabled 为不透明 `#b4bdaa`，并配通用禁用原因。是待审提议，不升级为已批准 token，不修改生产主题。
- `type-approved.png`（T01）：母版字体实物，36／24 标题、20 资源数值、14 正文与 12 窄按钮；均由随包字体实际渲染。
- `cards-approved.png`（K01）：直接实例化 `painted_card.gd`，同一种子材质的未聚焦／聚焦，旁置原图和卡底局部。使用 `native-evidence/tide/world.png`，原型 0、sid 0、色板 0、世界种子 1339。是独立原生样本，未映射 Session 世界。
- `fields-extension.png`（X01）：输入框、单选／多选、列表选择的同源衍生设计，待审。颜料和字体复用母版，选择边／标记和输入状态为本次设计；不声称已有正式组件。
- `fields-feedback.png`（X02）：警告、错误、锁定、空态的同源衍生设计，待审。两种暖色是提议，图中文字为状态样例，不建立真实规则或游戏事实。

## C01 状态的精确复现边界

每只 `Button` 放在独立 `SubViewport` 中。hover 通过 `Control.NOTIFICATION_MOUSE_ENTER` 切入原生绘制模式；pressed 以无信号的 pressed 状态复现同一绘制分支；focus 使用实际 `grab_focus()`。逐只完成原生渲染后冻结 viewport，避免后续焦点转移使前一张标本失焦。输出日志核对 draw mode：normal/focus=0、hover=2、pressed=1、disabled=3；focus 另核 `has_focus=true`。

焦点是 normal 底材加 focus StyleBox 叠层，不是把 focus 当作替换 normal 的单张底图。建立状态后重新调用母版皮肤，防止生产构建器的 `focus_entered` 回调在母版外额外换回其默认焦点框。因此本图用于展示当前母版样式本身，不是证明游戏内焦点回调已完成正式化。

母版只覆盖 normal/hover 字色，pressed/focus/disabled 仍继承当前生产构建器的文字色。图板忠实显示这些残留：按下／主操作焦点有暖色，disabled 较暗。这些残留不是新主题的规范色，也不因出现在图册而获得审美批准；实施时应按正文明确语义角色统一处理。

## 本次检查

Godot check-only 通过；实际生成五张 PNG，均为 1920×1080。已逐张目视复看并修正图窗最小尺寸导致的原图溢出、状态注入时机和多 viewport 的焦点保留。没有重跑游戏功能测试。文件名中的 `approved` 表示母版来源，不表示所有展开状态均已单独获准。

随后仅单独捕获 X03 `controls-extension.png` 并目视核对，其他五图保持；用于使 C01 暴露的问题有明确可审阅的补齐目标。
