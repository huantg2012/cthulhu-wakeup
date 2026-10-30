# Current Work: Material Recipient Scope and Finite Transfer Contract Design

更新：2026-10-30。TASK-MATERIAL-TRANSFER-DESIGN — Material Recipient Scope and Finite Transfer Contract Design已完成设计，三项过期设计/规划前置已按当前轻量规则复核。24行材料矩阵及个人接收合同未装载，未做新游戏功能运行。

## 制作人阶段锁定（2026-10-29）

- TASK-ART — Production Visual and Audio Asset Integration：锁定，暂不启动。
- TASK-RELEASE — Release Reliability：锁定，暂不启动。

当前优先完成轻量来源、密教与关键路线、完整新局及存档、核心平衡。上述两项保留planned与原依赖，不删除、不记完成，且不进入当前执行队列；即使前置完成也不自动解锁，须制作人明确同意进入对应阶段。当前功能验证所需的最低限度交互和保存继续仍属核心开发，不扩展为视听制作或发布专项。

未完成67项，其中锁定2项；待开始17项、进行中1项、已实现待验收/复验49项；已验收10项。未锁定的待开始项为15项。

## 已锁定

普通背景用少量条件加权抽签，一次确定必要参与者/情境/期限；只持续保存影响玩家选择的状态。不再先跑职业日程、事故、受伤、传话、逐人读取或签署过程。

重要身份/死亡、玩家行为、资源、材料独立性、实际依赖、必要期限与一次结果仍要正确。密教方向、两类求告、多路径和必要机会的概率修正保留。叙事不得把随机概括称为逐步社会模拟。

测试同样从简：小型共享核心集+本次2–4个直接相关例，普通快速批次目标≤60秒；不逐族铺矩阵、搜数百种子、做全仓库重签/历史规模审计或另建运行器。实际Bug补最小回归，正式产物/后果仍要验。

## 任务收口

- TASK-SIMULATION-STRATEGY — Lightweight Simulation Strategy and Scope Revision：上轮策略与任务归并交付，旧报告保留。
- 五个SOURCE父任务承接轻量来源；TASK-SOURCE-LOCAL-TIES、TASK-SOURCE-LOCAL-CONFLICT、TASK-SOURCE-MEMORY、TASK-SOURCE-EXCEPTION及TASK-SOURCE-CONTRACT均已限定通过。13个微观子任务撤销拆分，未记完成。
- TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration：合并14个未开工Core/业务/界面细分，不默认实现18个新活动。
- TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility：合并保存负例，保重要状态及代表性合法/坏档控制。

全部28项合并映射见 `docs/tasks/slice-14.md`。状态/依赖唯一来源为 `docs/implementation/traceability.json`；清单减少来自合并，不是功能通过。

## 当前设计与证据

个人材料设计已冻结在事件§13.2及三张material_transfer表，全部design_only：目标先筛实际缺口和接收资格，再领袖优先/稳定ID；内部一份/两人，0信仰1低语基线；09A只付原费且须有新端点。知识/保管与原见证/实践/责任分开，schema2保接收时目标及一次结果。

当前share_record只给机构知识，个人转交仍未实现；09A的open_route已声明但缺处理分支，其修复明确归TASK-CULT-SPREAD。原两个实际阻塞未关闭。独立Code纠正原结果sender来源歧义；旧能力没有真实sender时不补造人或知识，继续原写者。

本次新四组为设计审查；现有图静态实际8/8。原17组运行未重跑：逐字节比对原实际运行/夹具/已加载CSV闭包90文件未变，仅保留既有Sources未受本纯设计影响的窄结论，不称新递交/09A运行。当前证据docs/qa/material-transfer-design-results.json，报告docs/qa/material-transfer-design.md，旧报告保持。

本次67项来自主设计及3项旧设计/规划前置复核，各任务责任不删除；非新增4项游戏能力。下一项按实际前置复核进入TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation；本轮不自动继续开工。

完整Session仍受CULT兼容及来源/进展未闭合阻塞。自然新局、首团数值、平衡、界面/真人体验保持原任务，视听发布继续锁定。
