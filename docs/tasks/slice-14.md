# Slice 14 — Lightweight Simulation and Correction Tasks

更新：2026-10-29，制作人DEC-026。当前任务状态与依赖唯一见 `docs/implementation/traceability.json`。

## 当前批次：Core Capability Checks（2026-10-30）

按制作人本轮授权顺序完成三项，分别验收、更新工作台及本地提交：

1. TASK-CAPABILITY-GUARD — Declared Responsibility and Production Wiring Checks：首批仅候选生成职责。核正式调度共用的阶段、唯一所有者、两模式及原根处理者绑定；缺失、错指向、重复归属明确拒绝。合法无候选是正常结果，不要求每轮产生祈求。
2. TASK-CAPABILITY-PROBES — Short Behavioral Probes and Failure Controls：复用原组件夹具，2–4组短行为核正式生成、可回应与实际结果，以及缺处理者、空实现和模式交接。目标不超过60秒，不另建测试框架。
3. TASK-CAPABILITY-AUDIT — Core Capability Omission Audit：限定对照候选生产/调度/回应及已知09A缺口，逐项记录接线、结果证据或实际修复责任，不扩大为全项目能力证明。

旧验收把 detailed_candidates 写作“当前缺失”已过时：Events已有正式模式/原根绑定，World阶段四和Dispatch实际使用它们。本批验收改为人为删除或错接时必须识别，空实现由行为探针识别。

工具必须能够检查尚未完成的功能。PROBES的执行前置为GUARD及轻量策略；ORIGINS保留为实际接口/历史证据来源，原全范围验收仍由原任务负责，不要求整条旧功能链先变绿才允许建立探针。实际组件装配失败仍须报告，不得安装虚假能力或绕过完整Session的CULT拒启。

原整改规划只复核方向/责任/依赖与历史交付边界，不将当时“源码不变、修复待实施”误套为永久禁止后续实施。09A的open_route修复继续归TASK-CULT-SPREAD；本批发现缺口不代替该修复。

前述材料设计、轻量来源与关系网设计规则保持其各自范围。若共享代码增加检查，复用已有17组来源核心作一次受影响复验；后续仅新增工具时不重复跑，也不把该结果作为完整Session/自然新局通过。

## 当前交付：TASK-SIMULATION-STRATEGY — Lightweight Simulation Strategy and Scope Revision

- 目标：把普通背景改为少量条件下的加权抽签，持续状态只保留玩家决策和后续结果需要的部分。
- 责任：Design更新原规则与计划，Code仅同步架构目标；不做游戏代码/数值/界面修改，不继续旧精细测试。
- 必读：`docs/world.md`、`docs/specs/system-events.md` §14.5、`docs/implementation/README.md`、DEC-026。
- 验收：来源/后果区别明确；撤销过细拆分并接回真实父任务；工作台显示新状态；不把设计或合并任务记成运行完成。

## 下一组：五个来源任务

开工前置为本轮轻量策略。已有基础代码的必要调度/知识/准入接口由各父任务按实际需要短验，不要求先让旧全量矩阵重新变绿，也不把这些短验当成旧任务全范围通过。

| Task | 最小范围 | 主要验收 |
| --- | --- | --- |
| TASK-SOURCE-LOCAL-TIES — Current Incident and Kinship Prayer Sources | 抽出求援情境，接PR01回应/期限；替换未验收事故WIP | 正式生成可回应请求；后果/保存/一次消费；无职业→事故→通知链 |
| TASK-SOURCE-LOCAL-CONFLICT — Current Dispute, Investigation, and Seizure Notice Sources | 抽出争议、追查、秘密；圣物索回沿实际实例 | 原争议去重、实际后果与已有事实不冲突 |
| TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources | 一次绑定共同见闻、人数与本次资格 | 浅深资格差异、不全域删记忆、实际材料 |
| TASK-SOURCE-EXCEPTION — Current Anomaly Observation Sources | 抽出发现/独立第二观察 | 同异常独立记录与复制明确区分 |
| TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources | 一次确定约定/条款，接履约/依赖/轻量继任 | 实际履约/解除、原期限、非文书模拟 |

共同流程：正式读取少量条件→抽取情境→检查矛盾/容量/窗口→固定一次→回应或到期。共用已有生成/结算入口，字段/规则/内容CSV随父任务同步；旧CSV枚举不是继续实现微观链的理由。每族先列2–4个可观察结论，再做最小实现与受影响短检查；只有共享接口风险需要才跑完整回归。可控制随机数检验正式生产，不搜索数百种子作为日常开发方式。

测试只保小型共享核心集与本次改动的2–4个代表用例，普通批次目标≤60秒。重点是回合/资源、正式生成与回应、期限/一次结果和保存继续；不逐族铺组合矩阵、联合重签/历史规模测试，不新建专用运行器或授权账本。实际Bug补最小回归例，罕见事件控制抽签验证。

## 当前后继：TASK-MATERIAL-TRANSFER-DESIGN — Material Recipient Scope and Finite Transfer Contract Design

五族轻量来源各自短例完成后，本项先冻结目标接收设计，再接原材料/锚点实现。原三个规划/设计前置按DEC-026当前口径做限定复核，不把旧作者/共同读取等微观流程恢复为前提，不把设计复核冒充图或新局运行。

设计交付归事件§13.2，文明§9只读消费，既有ui-interaction只补结构；三张material_transfer表全design_only。内部转交由现有Cults action调用World共同核，一次一份/两人，不设通信系统；09A只在新端点增量时付原费，不叠内部成本。24行矩阵分别定义知识/保管与不可转移原资格，schema2保存当时目标和取得层次。

- TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts：装载有限表、个人递交/预览/准入/唯一支付回执/迟到basis及保存，接既有Session/ActionCatalog最小已知入口。
- TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration：修当前缺失的open_route处理分支，按固定材料/接收者/目标增量接09A及原费用后果。
- TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation：消费同一矩阵的当前真实carrier及原参加者条件；副本不代替观察/实践或互惠两腿。
- 新路线业务和完整Session分别归原PROGRESSION-OPERATIONS与CULT-SAVE-COMPAT，不以本设计算实现。

验收只列四组设计正反例/静态合同检查；后续实现也按四组代表行为守核心，不铺24族乘人物/文明矩阵。新表未接入Catalog，旧运行输入保持；原17组仅作历史基线，兼容复核须明确未重跑，不能替代新递交运行。

## 关键进展、保存与后续

`TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration`统一承接原Core、七业务操作及三组UI设计/接线：保十目标的不同触发/主动促成路线，优先用现有权能、策略及情境抽签，不默认开发十八套新活动或三套复杂界面。需要界面变化时仍须先执行in-game-ux skill、载体/具名参考及必要Art检查。原操作表仍design_only，须先收口数据再安装。

`TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler`保必要机会的概率修正与实际可行动窗口。随机未命中与没有生产者分开，不能恢复微观背景门槛后让流程永远卡住。

`TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility`合并原保存负例任务，只保重要状态、已抽结果、期限、一次消费和代表性版本/损坏控制，不做全仓库联合重签审计。

材料、密教、锚点、能力防漏、首团平衡及自然验证按原真实父任务继续，并受DEC-026约束。原两个实际阻塞保留。完整新局/玩家体验未因此通过。

## 撤销细分，合回父任务（不是完成）

下列28个实施切片从活跃任务清单移除，其必要玩法仍由实际父任务承接。其旧代码/报告/失败与诊断记录保留；不再以旧微观验收为必须实现的目标。没有把这些任务标为verified。

| Retired Task ID | Active Parent |
| --- | --- |
| TASK-SOURCE-LOCAL-TIES-INCIDENT | TASK-SOURCE-LOCAL-TIES |
| TASK-SOURCE-LOCAL-TIES-PRAYER | TASK-SOURCE-LOCAL-TIES |
| TASK-SOURCE-MEMORY-READING | TASK-SOURCE-MEMORY |
| TASK-SOURCE-MEMORY-REVIEW | TASK-SOURCE-MEMORY |
| TASK-SOURCE-MEMORY-CONSUMERS | TASK-SOURCE-MEMORY |
| TASK-SOURCE-LOCAL-CONFLICT-DISPUTE | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-LOCAL-CONFLICT-DISCLOSURE | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-LOCAL-CONFLICT-PURSUIT | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-EXCEPTION-OBSERVATION | TASK-SOURCE-EXCEPTION |
| TASK-SOURCE-EXCEPTION-PRAYER | TASK-SOURCE-EXCEPTION |
| TASK-SOURCE-CONTRACT-AGREEMENT | TASK-SOURCE-CONTRACT |
| TASK-SOURCE-CONTRACT-PERFORMANCE | TASK-SOURCE-CONTRACT |
| TASK-SOURCE-CONTRACT-SUCCESSION | TASK-SOURCE-CONTRACT |
| TASK-PROGRESSION-OPERATION-CORE | TASK-PROGRESSION-OPERATIONS |
| TASK-AXIOM-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-NETWORK-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-PROGRESSION-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-PROGRESSION-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-CONTACT-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-RECORD-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-RITUAL-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-CONTRACT-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-CONTRACT-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-CONTRACT-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-SAVE-NEGATIVE-CONTROLS | TASK-CULT-SAVE-COMPAT |

原细化方案的完整历史由Git保留（上一规划提交 `0b79cb3`）。当前未验收事故代码暂存于工作区，等待轻量替换；原执行者两次失败停止与新owner首轮诊断都保留，剩余执行预算已撤销。
