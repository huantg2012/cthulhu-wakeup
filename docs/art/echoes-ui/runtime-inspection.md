# 原生 UI 原型有限运行观察

日期：2026-11-03。用途：为“幽界群像”布局母版与组件规范提供现有功能和真实内容依据；不构成新视觉方案验收，也不把旧原型几何锁为目标布局。

## 执行与范围

本机 Godot `4.7.2.stable.official.ed1daf0bf`，与项目架构记录一致。使用正式 `experience_root.tscn`、Session 和 CSV，在独立目录 `res://.godot/echoes-ui-inspection-20261103` 新建 seed 1 会话；执行一次真实浅触回应，随后通过原生 `load_save` 的先复制再恢复路径读取真实首团样本。没有修改 `src`、`data`、现有工具或旧 QA 输出。

本批观察驱动 [inspect.gd](runtime/inspect.gd) 一次运行退出 0，3.739 秒，原始日志无引擎 ERROR。输出 10 张 1600×900 PNG；[执行记录](runtime/execution.json)、[原始日志](runtime/run-output.txt)、[控件文本与状态](runtime/inspection.json) 保留。脚本调用真实 UI 方法与按钮信号，未进行人工键鼠试玩、完整整局或成熟路线测试。

单独运行 [export-semantics.gd](runtime/export-semantics.gd)，只加载正式 Catalog 并调用 `experience_semantics.prayer`，输出 PRAYER_05 两种回应的 [语义样本](runtime/semantic-sample.json)。这不是构造 T46 局势或概率的证据。

## 实际观察

1. [开始菜单](runtime/01-start-menu.png)：新局种子、开始新局、真实首团副本和继续保存的入口由现有菜单提供；截图为独立目录首次运行，尚无可继续存档。
2. [新局默认页](runtime/02-new-game-default.png)：T1/actions，1 世界、1 人、1 祈求，无教团/圣物，低语 3、信仰 18/70、苏醒 10。当前默认主体为 home；顶部祈求摘要与中央总览祈求条目并存，尚未实现用户本轮要求的“待处理祈求默认居中成为主要任务”。左侧无教团、右侧无圣物也占有整列。
3. [浅触](runtime/03-prayer-shallow.png)与[深应](runtime/04-prayer-deep.png)：打开祈求即建立浅触草稿，可切深应；需要并置求告者、世界、原诉求、请求期限、必付代价、条件后果与唯一回应机会。真实 PRAYER_08 浅触将理智损耗与成功忠诚收益分开，执行区固定在滚动内容之外。图中较长后果需要独立滚动，规范不能靠缩小字级消化所有信息。
4. [查看世界时保留草稿](runtime/05-worlds-with-draft.png)：切换主体至 worlds 后，draft 仍为同一祈求 deep。普通关联查看不能覆写行动目标或消耗机会。
5. [实际浅触失败](runtime/06-prayer-result.png)：低语 3→2，顶部改为“本轮已回应”，祈求仍有 1 项可查；草稿清空，当前主体显示结果。请求条目存在不代表仍可回应。此次实际失败结果不代表所有祈求或成熟局结果。
6. [未解锁降临](runtime/07-unavailable-power.png)：仍可浏览权能、先显示解锁理由；不能制造可执行假表单。
7. [真实首团](runtime/08-first-cult.png)：旧 T3 保存恢复至 T4/actions；1 团、2 位已知人物、6 位无名信众、凝聚 60、无圣物。教团三策略可比较，当前指令在轮末执行，预计收入不能拿来支付本轮费用。世界四维显示“未掌握”，不能用示例中统一数字填补未知。
8. [全员](runtime/09-people.png)：人物列表需搜索、范围与机会过滤、已知身份/机会状态；已知人物总量与教团具名成员数量不同。
9. [收支](runtime/10-budget.png)：现有信仰、本轮支出、支出后剩余、预计收入各自有语义。此局无锚点，因此只观察到教团支出与收入；锚点供奉调整和停供仅从代码确认入口，未在本批真实成熟局操作。

## 对母版与规范的直接约束

- 轮初必须保留 events 的真实优先级。进入合法 actions 且未回应时，可按本轮新设计将祈求居中；当前代码并未因此改变。一次回应后应有明确只读/机会已用状态，而非继续展示多个有效提交。
- 中央信息至少有“比较待办”“具体对象＋当前行动”“无行动的完整主体”三种组织状态。固定两列会在无草稿时浪费空间。
- 十二权能全部可浏览；未知/锁定/资源不足/缺少对象是不同理由。底栏压缩须保留名字、图标及可访问的理由，不把微缩文字作为唯一说明。
- 长内容主要来自真实代价和条件后果。对象身份、主要风险、支付和提交必须保持可定位；详细概率/后果可展开，展开不能把提交推出屏幕。
- 历史来源与四维估计、未知应独立表达；例图不能宣称实时全知。当前原型在 Mac 截图中个别中文字形出现异常，正式字体样板需实际验证字库覆盖，不能只检查源字符串。
- 本轮没有实测多教团、多圣物、成熟锚点、有效降临和终局；这些场景需通过结构/控件需求映射覆盖，并明确使用展示夹具时的证据边界。

## 源码定位与复现

- `experience_root.gd:234`：祈求摘要、事件阶段和已回应状态。
- `experience_root.gd:360`：普通主体查看与祈求草稿打开。
- `experience_root.gd:548`：自动跨过内部结算阶段、重置到 home，并在 events 打开必要事件。
- `experience_root.gd:598`：新局默认 home；`610`：加载外部档先复制再恢复。
- `experience_root.gd:679`：菜单与真实首团入口。
- `experience_actions.gd:13`：缺条件/不可用提示、必付/后果与固定提交；`80`：浅触/深应切换。

复现命令（在项目根执行；独立存档仍使用上方固定隔离目录）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://docs/art/echoes-ui/runtime/inspect.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://docs/art/echoes-ui/runtime/export-semantics.gd
```

复跑会覆盖本批 runtime 输出，需另存目录才能保留本次原件。此记录不要求例行重跑，不替代已有系统验收。

## 补充：真实 T4 祭日祈求预览取数

为母版使用准确概率，在隔离副本中按原恢复流程将 T3/between 合法衔接到 T4/actions，再进行浅触与深应只读预览；未回应、未继续下一轮。一次运行退出 0，见 [执行记录](runtime/preview-execution.json) 与 [输出](runtime/preview-export-output.txt)。源副本 SHA 前后相同，预览前后 world/context canonical 值相同。

[prayer-preview.json](runtime/prayer-preview.json) 保存真实投影、请求身份、当前可知世界/人物、ActionCatalog 行及 Session.preview_action 结果。求告者为“求告的祭司 · 00000001”，世界“盐梦诸邦 · 001”，T4出现、请求至T6。两种回应的四档概率均为深刻成功12%、成功48%、失败32%、灾变8%；聚合成功60%包含深刻成功。浅触付1低语/0信仰，深应付2低语/4信仰；当前可用3低语/6信仰、苏醒10。

ActionCatalog 中旧“始终代价”文字仍合并了部分成功条件后果；母版应继续采用正式 experience_semantics 分阶段输出，不能因此把正统质疑写作深应必付。世界四维未掌握，不按已知本次变化量补出当前总值。此取数仅代表该真实T4，不是此前人工T46成熟夹具的概率。
