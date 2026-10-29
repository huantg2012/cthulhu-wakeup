# Slice 14 — Lightweight Simulation and Correction Tasks

更新：2026-10-29，制作人DEC-026。当前任务状态与依赖唯一见 `docs/implementation/traceability.json`。

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
