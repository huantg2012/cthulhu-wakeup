# 邪神苏醒 · 制作工作台 · 当前状态索引

按正式JSON登记与实际复核来源生成。证据有效性由实施检查器判定，来源基线不改变验收状态。

生成：2026-10-28T07:06:50.852453+00:00。复核起点：a47f309（本次设计提交前工作区）。

实施摘要：`{"requirements": 54, "contracts": 19, "tasks": 54, "scenarios": 115, "residualOpen": 2, "planSources": 15, "planBindings": 15, "unassigned": 0, "unverified": 25, "stale": 80, "failed": 0, "verified": 10}`。

TASK-CULT-DIRECTION设计及接口独立审查已交付；schema2新表与旧Catalog/代码不兼容，尚无新机制运行证据。祈求设计已交付，下一项TASK-PRAYER-KNOWLEDGE。23旧接线任务保留implemented，旧证据stale；原840轮失败/截尾与UI人工待验不改。新增材料递交和本次存档边界任务，完整依赖见追踪源。

TASK-CLAIM-ACCURACY已校正文案并落实DEC-021：cell只是资格记录，人口池聚合，无逐人或多网络模拟。独立复核及56项追踪测试另存，旧QA JSON不变；不代表自动语言审计或schema2游戏已运行。详见[纠错记录](../qa/claim-accuracy.md)。

TASK-PRAYER-DESIGN：两类求告、有源身份知晓、有限原根及两模式调度完成设计审查；新增四张CSV、PR08中性标题和五项SOURCE实施任务。未改游戏代码、未调原数值、未取得新机制运行证据。[设计交付](../qa/prayer-design.md)。

[制作工作台](terminal.html) · [当前工作](../progress/current-slice.md) · [密教设计交付](../qa/cult-direction.md) · [整改计划](../implementation/correction-plan.md) · [Slice14任务书](../tasks/slice-14.md)

## 已登记能力

| 功能 | 范围 | 接入 / 工作 |
|---|---|---|
| [MECH-PRAYERS · 祈求与回应](features/core.json) | 在有限请求中选择一个，以浅触或深度干预改变具体人的处境。 | dev / active |
| [MECH-POWERS · 权能与检定](features/core.json) | 用对象、媒介与条件组织一次干预；不确定行动以统一四档检定结算。 | dev / active |
| [MECH-PEOPLE · 具名人物](features/core.json) | 人物拥有持续身份、四项属性、理智、忠诚、关系和经历；死亡保留历史。 | dev / active |
| [MECH-CULTS · 教团经营](features/core.json) | 达到条件后自发形成教团，以领袖、信众和凝聚维持收入与传播。 | dev / active |
| [MECH-RELICS · 圣物与媒介](features/core.json) | 圣物有唯一实例和来源，可携带准备、绑定锚点或永久转化。 | dev / active |
| [MECH-ECONOMY · 信仰与低语](features/core.json) | 低语限定本轮行动，信仰承接跨轮收入、准备、扩张与维护。 | dev / active |
| [MECH-CIVILIZATIONS · 文明与机构](features/core.json) | 混合范式、社会组织、传播结构和真实矛盾共同构成不同的进入与扎根条件。 | dev / active |
| [MECH-BARRIERS · 屏障与破口](features/core.json) | 屏障影响干预的效率和风险；破口扩大机会，但不等于已经污染或征服。 | dev / active |
| [MECH-POLLUTION · 污染与传播](features/core.json) | 神迹、组织与媒介让污染扩散；没有持续支撑时它会回落。 | dev / active |
| [MECH-ANCHORS · 机构锚点](features/core.json) | 满足机构条件后，以护持者、圣物和供奉维系一个现实中的立足点。 | dev / active |
| [MECH-EVENTS · 状态事件](features/core.json) | 事件从当下状态和历史中筛选，受资格、冷却、互斥、期限与优先级约束。 | dev / active |
| [MECH-HISTORY · 因果与编年史](features/core.json) | 持续保存谁、在何时、因为什么发生了什么，并让后续叙事引用真实对象。 | dev / active |
| [MECH-RESISTANCE · 察觉与抵抗](features/core.json) | 察觉提高风险；机构沿真实证据启动有目标、有预告的抵抗计划。 | dev / active |
| [MECH-AWAKENING · 苏醒与终局](features/core.json) | 有效锚点、有限洞见与创伤共同决定当前苏醒；最终完成持续降临，或寂灭。 | dev / active |
| [MECH-KNOWLEDGE · 感知与情报](features/core.json) | 通过祈求、人物经历和圣物线索认识文明；未知信息不变成假精确值。 | design / active |
| [MECH-TURN · 回合与结算](features/core.json) | 明确轮初、事件、自由行动、演化、收入与终局的顺序。 | dev / active |
| [MECH-INTERFACE · 基本交互](features/core.json) | 正式最简Godot交互、真实费用/概率、对象/回顾与保存已接入；人工体验待验。 | dev / active |
| [MECH-ART · 美术与声音](features/core.json) | 风格与最终表现后置；制作工作台不是游戏内界面。 | design / active |
| [MECH-SAVE · 存档与恢复](features/core.json) | 保存身份、排队后果和随机状态，让继续游戏保持同一条历史。 | dev / active |
| [MECH-ACCESS · 设置与可访问性](features/core.json) | 键鼠焦点、可滚动中文、18—28文字大小与非颜色状态已实现；人工体验待验。 | dev / active |
| [MECH-DELIVERY · 制作与验证](features/core.json) | 按正式任务与依赖实施；方案新增或修改必须当轮同步计划、验收和工作台，设计/实现/证据状态分开。 | dev / active |

完整来源、前置、证据与下游验收保存在工作台；登记数量不是游戏完成比例。
