---
status: ACTIVE
purpose: 轻量 issue 收集——playtest 反馈中产生的临时待办、发现的 bug、未即时修复的体验问题。
rule: Director 在每次 playtest 反馈处理后，将未即时修复的项追加到此文件。每个 Slice 规划时消费此列表。
---

# Backlog Issues

> 下方原有条目保留 2026 年 8 月的历史记录；本作当前新增待办见文末“邪神苏醒 · Slice 03 后续项”。

> 格式：`- [ ] 描述 (来源/日期)`。完成后打勾。每 Slice 规划时 review 此列表决定纳入哪些。

## 待处理

（当前无未处理 issue——Slice 3 的 playtest 反馈已全部即时修复或登记到 roadmap Slice 3.5）

## 已处理/已归档

- [x] 薪柴溢出——经济模型必然崩溃 (Slice 2 playtest / 2026-08-08) → DEC-026, Slice 3 重设计
- [x] 地图室内感太强 (Slice 1 playtest / 2026-08-07) → 室外地图重设计
- [x] 无法找到撤离点 (Slice 1 playtest / 2026-08-07) → trail + landmarks + minimap + glow
- [x] 冲击面板时机不对 (Slice 3 playtest / 2026-08-09) → 改为返回时显示
- [x] 净化点 HUD 不可见 (Slice 3 playtest / 2026-08-10) → DOM overlay 替代
- [x] Continue 触发冲击 (Slice 3 playtest / 2026-08-10) → 仅从裂隙返回时触发

## 邪神苏醒 · Slice 03 后续项（2026-10-25）

任务状态和验收以 `docs/implementation/traceability.json` 为准。规划后续 Slice 时复核这些问题，不以更新文档代替修复或真实测量。

- [ ] **ISSUE-TURN-HISTORY：完整回合成本随历史增长。** 统一回合与正式经济的 50 轮实测均观察到耗时增长，包含事务快照、事实历史、参与器视图与完整校验；接入经济后的结果见 [经济报告](../qa/economy.md)。按 DEC-016／017，基础整改已排入 [Slice 04](../tasks/slice-04.md)：`TASK-INCREMENTAL-TX / TASK-HISTORY-INDEX / TASK-ARCHIVE-SAVE` 处理历史热路径，`TASK-ABSTRACT-SIM / TASK-ATTENTION` 控制活动规模，`TASK-FIDELITY-VERIFY` 负责集成与负载验收，前置规则由 `TASK-FIDELITY-RULES` 收口。`TASK-BALANCE` 及 `TASK-RELEASE` 继续负责完整机制与目标平台复核。人口资格、因果、RNG、回滚、重复请求和阶段续存反例必须保留；TASK-INCREMENTAL-TX 已实现事务基础并取得专项差分/原子性证据；TASK-HISTORY-INDEX进一步完成有效投影、持久知识/消费/成长/关系与异常索引；TASK-ARCHIVE-SAVE已消除普通操作native旧根复制/身份遍历并接入增量分段保存，ABSTRACT-SIM进一步接入受控后台生产/候选及准确风险；实际F/N/P与本地展开已由ATTENTION接入，最终活动规模/历史长度独立负载由FIDELITY-VERIFY继续验收，完整导出/读档审计、真实K来源、磁盘增长和最终混合负载仍需后续验证，不提前关闭本问题，也不以省略规则／校验掩盖成本。（来源：Slice 02／03 测量与 DEC-017 计划调整，2026-10-25）
- [ ] **ISSUE-ECONOMY-UX：玩家能否准确理解预付、收入资格与供奉风险。** 本轮仅验证纯数据预览。转交 `TASK-UI`，用实际游戏界面检查玩家能否区分当前可用信仰、条件性预计收入和锚点恢复条件；若不能明确表达，回修经济预览合同和同一 UI spec。机器正确性不等于界面理解通过。（来源：Slice 03 的已声明下游验证范围，2026-10-25）

## 未决事项登记入口

2026-10-27 TASK-BALANCE 新增实际阻塞 `ISSUE-BALANCE-NATURAL-SOURCES`：详细候选职责及争议/记忆/宇宙例外根缺生产，传教许可与宇宙锚自然发展链尚不完整。修复归 TASK-CONTENT / ACC-NATURAL-SOURCES，完成后重跑 BALANCE；具体触发见待作者选择的 [最小提案](../qa/balance-repair-proposal.md)。本条是实际阻塞，不等同普通内容扩量，也不关闭原历史成本/人工理解问题。

作者本次明确：已有后续计划承接的事项符合预期；只有未规划、需要作者决策或实际阻塞的事项进入真正未决统计。唯一台账为 [residuals.json](../implementation/residuals.json)，收尾规则见 [实施保障](../implementation/README.md#真正未决事项与-task-收尾作者本次要求)。

上列 ISSUE-TURN-HISTORY 与 ISSUE-ECONOMY-UX 已分别绑定基础改造/负载任务和 TASK-UI，属于已规划工作，保留在这里追踪问题是否实际解决，但不混入“无计划/待决策/阻塞”统计。历史 8 月其他项目条目不属于本作当前未决。每次 task 完成必须复核并登记后续承接或真正未决，不能仅把限制写在验收报告里。
