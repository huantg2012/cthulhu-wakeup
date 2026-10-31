# Slice 01 · 实施保障与正式推演

## 本轮交付：TASK-CATALOG当前复验

2026-10-31：TASK-CATALOG — Formal Simulation Content Loading and World Generation当前版本复验完成。现有生产实现未改；本轮恢复原内容装载、合法世界生成和有界失败三项验收，不声称新增游戏功能或整体模拟/平衡通过。

当前正式42表装载及原十表完整；三份临时CSV覆盖坏字段、未知引用、非法取值，实际拒绝且原目录/版本保留。两固定seed200/201的世界核人物/机构/引用/可达通路、岗位资格与具名/无名人口守恒。不满足cosmic蓝本时明确有限失败，保原世界与随机状态，不放宽条件或无限重试。原3ACC断言未改；28个工具细断言与44项/142条索引断言分开，不冒全套重跑。

formal-01在Godot编辑器全仓CSV导入阶段原生崩溃，尚未进入核心，原失败/包装器字节及SHA保留，根因未在本轮查明，不能记导入已通过。改用项目既有定向check-only真实解析门后，formal-02解析/核心/启动6.362秒通过，无引擎错误/输入漂移。三坏例执行时错误非空断言通过，但诊断数组随后被重装清空，raw没有具体理由文本；该工具日志限制如实披露，不为它重跑业务。

旧41项仅文档差分：原39通过保持，Natural2项仍partial；新3项有实际独立运行，不批量恢复其他旧专项。无src/data/spec/architecture改动，无新背景模拟、数值调整或长程测试。整体平衡长期，视听/发布继续锁定。

本轮无新增task、完成1项当前复验；总81、已验收40、未完成41：待开始5、进行中1、已实现待复验35。TASK-NATURAL-VERIFY原未完成部分继续保留，不因本项通过就闭合自然整链。下一候选为TASK-IDENTITY（当前前置已具备），本轮不自动启动或推送。详见[当前装载与生成报告](../qa/catalog-current.md)。

## 以下为此前计划与历史

## 当前执行：TASK-CATALOG

2026-10-31：开始TASK-CATALOG — Formal Simulation Content Loading and World Generation当前版本复验。该项无前置，旧实现已在，但正式装载/合法世界/有界失败证据随规则变化过期；本轮恢复基础能力验收，不扩展模拟或整体平衡。原3ACC各1条given/when/then保持。

先锁最小检查：当前完整Catalog及原十表齐全；三份临时CSV分别覆盖坏字段、未知引用、非法取值，须明确拒绝且保原目录/版本。原seed200/201两份世界核人数/机构/可达通路/全部引用、岗位资格、具名与无名人口守恒。原不可满足cosmic蓝本副本须有限明确失败且原世界/随机/目录不变，不删除条件或无限重试。参数仍来自CSV，少量样本不证明完整分布。

只读预检已由Code和独立QA确认。工具窄审后一次Godot解析/核心/启动共享60秒上限，首次实际失败停止、保输入SHA与raw，无ERROR/漂移才通过。无src/data/spec/architecture改动计划；若发现真实bug先回具体实现，不降低原断言。旧41项仅本轮文档差分，保Natural2项partial，不重跑/重签旧实际报告。无新task，整体平衡长期、视听/发布继续锁定。

当前总81、已验收39、未完成42：待开始5、进行中2、已实现待复验35。

## 以下为此前记录

本轮直接建立正式机制与持续验收，不设置短体验前置阶段。任务的唯一状态与验收绑定保存在 [追踪登记](../implementation/traceability.json)，本页是任务职责阅读入口。

## 本轮责任

本轮覆盖 TASK-TRACKING、TASK-WORKBENCH 及正式数据/人物/文明/因果/保存/负载任务。后续完整回合、经济、权能、锚点与终局仍保留明确任务；不把基础推演通过等同于完整游戏通过。

### TASK-TRACKING · 关键行为追踪与证据门槛

建立本游戏的要求、结算归属、任务、验收和影响分析；不改通用框架

前置：无；从当前规则与正式数据开始。
涉及能力：MECH-DELIVERY。
验收：ACC-GUARDS；完整 given/when/then 与报告检查编号在追踪登记中。
交付：tools/implementation/tracking.py、tools/implementation/check.py、docs/implementation/traceability.json。
范围外：不替代其他任务的验收。

### TASK-WORKBENCH · 制作工作台实施视图

在既有工作台阅读追踪、缺口、约定与证据并持续讨论

前置：TASK-TRACKING。
涉及能力：MECH-DELIVERY。
验收：ACC-WORKBENCH、ACC-WORKBENCH-BROWSER；完整 given/when/then 与报告检查编号在追踪登记中。
交付：tools/producer-console/web/app.js。
范围外：不替代其他任务的验收。

### TASK-CATALOG · 正式推演内容入口与生成

读取正式人物/文明/行为参数并生成有限合法世界

前置：无；从当前规则与正式数据开始。
涉及能力：MECH-DELIVERY、MECH-CIVILIZATIONS。
验收：ACC-CATALOG、ACC-WORLD、ACC-GENERATION-BOUND；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/catalog.gd、src/simulation/world.gd。
范围外：完整祈求、权能与事件效果解释器。

### TASK-IDENTITY · 人物身份、人口与生命周期

实现持续身份、提名、迁移、拘禁失踪死亡和已存在对象失效

前置：TASK-CATALOG。
涉及能力：MECH-PEOPLE、MECH-CULTS、MECH-RELICS、MECH-ANCHORS。
验收：ACC-DEATH、ACC-MIGRATION、ACC-STATUS、ACC-NOMINATION、ACC-INSTITUTION-SUCCESSION；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/world.gd。
范围外：完整教团经营、锚点建立和终局。

### TASK-NPC-ACTIONS · 正式属性与自主行为

四属性检定、基于需要与证据的有限行为及独特成长

前置：TASK-IDENTITY。
涉及能力：MECH-PEOPLE、MECH-POWERS。
验收：ACC-ATTRIBUTES、ACC-ELIGIBILITY、ACC-BEHAVIOR、ACC-GROWTH；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/world.gd。
范围外：任意人生模拟、在线LLM、替玩家消费信仰。

### TASK-CAUSAL · 真实事实与多来源因果

显式事实、知情归属、真实触发来源与去重

前置：TASK-IDENTITY。
涉及能力：MECH-HISTORY、MECH-EVENTS、MECH-KNOWLEDGE。
验收：ACC-IDEMPOTENCY、ACC-CAUSES、ACC-TESTIMONIES、ACC-ACTUAL-DELTA；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/world.gd。
范围外：全部正式事件模板和叙事品质。

### TASK-CIV-EVOLUTION · 文明机构与人物双向推演

同快照推进恢复、机构行为、人物反馈与证据权限

前置：TASK-NPC-ACTIONS、TASK-CAUSAL。
涉及能力：MECH-CIVILIZATIONS、MECH-BARRIERS、MECH-POLLUTION、MECH-RESISTANCE。
验收：ACC-KNOWLEDGE、ACC-FEEDBACK、ACC-ORDER、ACC-EMPTY-EVENTS、ACC-TARGET-CANCEL、ACC-RESISTANCE-EFFECTS、ACC-PUBLIC-ANOMALY；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/world.gd。
范围外：完整跨域玩家权能、全部正式抵抗后果。

### TASK-REPLAY · 正式推演保存与复现

同版本随机隔离、原子命令、存档校验与继续

前置：TASK-CIV-EVOLUTION。
涉及能力：MECH-SAVE、MECH-TURN。
验收：ACC-REPLAY、ACC-SAVE、ACC-BAD-SAVE、ACC-ATOMIC；完整 given/when/then 与报告检查编号在追踪登记中。
交付：src/simulation/world.gd。
范围外：跨版本迁移、断电恢复、全平台逐位重放。

### TASK-LOAD · 正式规模长程演化验证

分别测自然演化与持续活动驱动，检查不变量及真实成本

前置：TASK-REPLAY。
涉及能力：MECH-DELIVERY、MECH-HISTORY、MECH-SAVE。
验收：ACC-NATURAL-RUN、ACC-LOAD；完整 given/when/then 与报告检查编号在追踪登记中。
交付：tools/formal-simulation/run.gd、tools/formal-simulation/verify.py、docs/qa/formal-simulation-results.json。
范围外：正式完整游戏平衡、无限战役。

## 后续实施责任

下列任务的前置、交付、场景与缺口已在工作台登记，实施时按单次会话可独立完成的责任继续细分；不得因为尚未接入而删除验收。

- **TASK-TURN · 完整游戏回合编排**：前置 TASK-REPLAY；本任务已进入 [Slice 02 任务书](slice-02.md)，范围和验收在该页及追踪登记维护。
- **TASK-ECONOMY · 正式经济与收入**：前置支付、人口口径、收入容量、招募与自然流失。前置：TASK-TURN。
- **TASK-CULTS · 教团形成、任职与继任**：正式教团生命周期与玩家任命。前置：TASK-IDENTITY、TASK-ECONOMY、TASK-FIDELITY-VERIFY；经济后先完成 [Slice 04 分层模拟任务链](slice-04.md)，成员接纳必须接入注意力预留与身份转换。
- **TASK-POWERS · 完整权能与圣物操作**：全部正式权能、资格预览、四档结果与圣物完整生命周期。前置：TASK-NPC-ACTIONS、TASK-CULTS。
- **TASK-PRAYERS · 正式祈求与危机生命周期**：候选、回应次数、失败后危机与未选期限。前置：TASK-POWERS、TASK-CAUSAL。
- **TASK-ANCHORS · 完整锚点建立与维护**：正式机构资格、固定序号、建立修复和供奉；既存失效基础来自IDENTITY。前置：TASK-POWERS、TASK-CIV-EVOLUTION、TASK-ECONOMY。
- **TASK-EVENTS · 正式事件池与到期调度**：正式12事件/24分支及后续内容的完整效果执行。前置：TASK-PRAYERS、TASK-CAUSAL、TASK-TURN。
- **TASK-RESISTANCE · 正式抵抗与跨域传播整合**：六类计划正式后果、预告、失效、通路传播与未观察世界。前置：TASK-EVENTS、TASK-ANCHORS。
- **TASK-ENDINGS · 完整苏醒仪式与寂灭**：持续仪式、断联、终局优先级和结局封存。前置：TASK-RESISTANCE。
- **TASK-UI · 基本可交互与可访问性**：最简规则操作、概率/条件可见、完整键鼠与长内容。前置：TASK-POWERS、TASK-PRAYERS、TASK-ENDINGS。
- **TASK-BALANCE · 完整机制策略与失败分布**：多局多策略寻找支配、套利、卡死和不合理节奏。前置：TASK-ENDINGS、TASK-UI。
- **TASK-CONTENT · 正式内容与因果可理解性**：内容扩充、语义检查、文明行动差异和真人理解。前置：TASK-ENDINGS、TASK-UI。
- **TASK-ART · 表现替换与正式视听**：确定美术后以同状态与结算替换视图。前置：TASK-UI。
- **TASK-RELEASE · 发行可靠性**：目标平台导出、保存恢复、真实旧版本迁移。前置：TASK-BALANCE、TASK-CONTENT、TASK-ART。

## 并行与交接

设计只写归属 spec 与 CSV；模拟实现拥有 src/simulation 与 formal-simulation 工具；工作台实现拥有 producer-console；主会话维护追踪、结算整合与来源索引；独立 QA 用临时副本检验追踪器。共享状态约定变更必须传播到消费者，不能通过各自硬编码解决分歧。

接续前执行 `python3 tools/implementation/check.py --task TASK-…`。交接报告目标/要求/任务编号、改动、真实验证命令和版本、未决事项，不依赖聊天压缩摘要保留规则。

### 未决复核补充交接

TASK-RESIDUALS 复核旧报告限制后，将两个易散落的实施点明确写回现有计划：TASK-CONTENT 补齐合法文明范式变异、灾难背景和听众关系生成上下文，并以实际生成来源验证；TASK-EVENTS 在正式内容需要概率身份后果时扩展到期仲裁，验证随机、死亡/恢复冲突和原子回滚。当前核心对不支持的组合仍明确拒绝，不因登记后续计划而提前宣称实现。其他完整玩法、美术、UI、平衡与平台工作沿既有任务承接；具体交接见 residuals.json。
