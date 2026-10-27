# TASK-UI 定向规则静态审阅

日期：2026-10-27。性质：一次定向静态审阅及发现范围内修复复核；不是运行验收、视觉验收或完整游戏通过声明。

基准：`CLAUDE.md`、QA/Code 角色定义、`ui-interaction.md`、`system-powers-cults.md`、`system-events.md`、`system-turn-economy.md` 相关合同，以及原 CSV。范围限定本次新增 PlayerSources、Session/ActionCatalog 与 Turn/Economy/Powers/Prayers/World/StateView 接线。未修改生产代码、测试、旧人工报告；未运行 Godot、构建或完整回归。视觉由主任务负责，本报告不勾选 U1–U12。

## 发现与状态

| ID | 类型 / 严重度 | 静态证据与影响 | 状态 |
| --- | --- | --- | --- |
| UI-REV-01 | 性能 / Medium | `Session._refresh_knowledge` 每次操作遍历 `Store.values(world.state.npcs)` 找绑定成员；`project` 遍历全部归档遗物。普通交互成本随冷人物/遗物增长，前者已有 attention.members 可定向读取。 | 已修复；同次静态重读闭合 |
| UI-REV-02 | 知情边界 / High | `_refresh_knowledge` 将 own_action 事务内全部新事实 `_learn`，其中包括事务末尾自动派生的 `power_qualification`，绕过随后 origin-known 条件。旧公开证据尚未进入玩家知识时，新接纳当地成员会产生对应 evidence 资格；该资格被直接加入可选源，允许对未知证据使用 VEIL。违反 UI 规范“资格存在不等于内容已公开”。 | 已修复；同次静态重读闭合 |

第二项是根据可执行控制流构造的反例，尚未作为运行结果报告。建议定向用实际旧证据和新接纳成员验证：原证据未知时，新资格也不得进入当前玩家选择器；显式获知原证据后才可出现。

## 已读规则及静态结论

- PlayerSources 从 CSV 选择固定祈求、屏障来源、传播许可、消息、入团经历和真实祈求效果；Powers 在使用时再次验证生产资格，World/StateView 接入审计与读取。资格的规则有效性与玩家知情是两个门槛，后者经本次发现修复后按原事实已知条件公开。
- BG_RITUAL 复用现存 active ritual_keeper 及活跃解释或传播机构，在本轮写入绑定身份/机构/轮次的 ritual_context；没有凭空授职或 nomination。PRAYER05 继续使用原效果：深应成功增加五名无名信众，失败不增加。初始零信众到六名成团阈值仍需至少两次真实成功及既有成团条件；新增模板本身不构成首团已实跑证明。
- rest 检查行动阶段、未回应、未用权能/圣物、有创伤且足额信仰；支付与结束行动阶段在同一正式事务，失败沿原事务回滚。保存回执使用正式 rest 事实校验。专属 Prayers/Events 到期所有权满足时才允许省略 generic deadlines，未移除其实际到期阶段。
- ActionCatalog 阅读覆盖谕言声明与准备、赐福属性、献祭模式/见证/经历、迁移目标与随从、任职岗位、锚点机构资格与媒介、降临开始/继续/中止，以及回应代理字段；提交沿原规则预览/执行，不把选择器当权威资格。
- Session 保存知识账本、请求序号、实际输入和 Turn 快照；恢复先在新建实例验证快照与回执，成功后替换会话。已提交 durable ID 走原回执，冲突输入拒绝。原子写入有临时文件/备份与替换失败恢复。此为代码路径核对，不是故障注入测试结论。

## 验收边界

尚无本报告产生的运行证据。真实首团链、隐藏哨兵、冷档成本、保存失败/幂等、全部操作入口的动态结果应由专项运行报告提供。两项发现已完成静态修复闭环；这仍不构成 TASK-UI 完整验收，动态与视觉证据保持各自范围。

## 同次修复定向重读

UI-REV-01：当前成员改读 attention.members，携带遗物按 holder 索引；已知遗物增量登记，当前选择与投影按 history.ids("relics") 和已知集合过滤。消除了本发现中的全部冷人物/遗物遍历；不据此宣称全局性能达标。

UI-REV-02：_command_knowledge_roots 只取玩家已知的原请求来源，后续仅学习与本次来源相连的新增结果；power_qualification 明确排除于该路径，统一由 origin 已知条件公开。未见原先自动资格旁路继续存在。

关联复合 ID 与关闭卡片修复已读：_public 对字符串任意位置匹配 FACT/NPC/DOMAIN 及 RELIC/ANCHOR/CULT 复合身份，未知身份在字符串替换、在字典键则丢弃；内部授权字段继续剔除。已知固定卡/登记/回应重建本局已知卡缓存，当前请求缺失时提供 closed 祈求历史副本，事件同样使用已知副本；恢复从已保存已知事实重建，不扫描未知历史补卡。

主任务另报告 Session 隔离种子7919实际回应后的 project/catalog/save/load/replay 和脱敏哨兵检查，以及 UI Tab/Enter、鼠标回应确认、Esc取消纯读、PgDown滚动检查无错误。本审阅者没有执行或独立复跑这些检查；它们不能替代真人理解、审美和可玩性判断。