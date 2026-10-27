# 正式抵抗与跨域传播验收

实际执行：2026-10-27T06:38:54.196787+00:00；Godot 4.7.2-stable (official)；Windows-10-10.0.19045-SP0。

真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers/Anchors/Events，正式CSV、原对象与当前来源。执行协议见[tools/resistance](../../tools/resistance/README.md)。

- `RES/RESIST_TRACE/resolve`：真实预告、原对象、到期按表结算与完整冷却（pass）。
- `RES/RESIST_TRACE/cancel`：真实预告、原对象、到期机构死亡取消与完整冷却（pass）。
- `RES/RESIST_PURGE/resolve`：真实预告、原对象、到期按表结算与完整冷却（pass）。
- `RES/RESIST_PURGE/cancel`：真实预告、原对象、到期机构死亡取消与完整冷却（pass）。
- `RES/RESIST_SEIZE/resolve`：真实预告、原对象、到期按表结算与完整冷却（pass）。
- `RES/RESIST_SEIZE/cancel`：真实预告、原对象、到期机构死亡取消与完整冷却（pass）。
- `RES/RESIST_REPAIR/resolve`：真实预告、原对象、到期按表结算与完整冷却（pass）。
- `RES/RESIST_REPAIR/cancel`：真实预告、原对象、到期机构死亡取消与完整冷却（pass）。
- `RES/RESIST_REWRITE/resolve`：正式祈求与例外记录产生修正，EVENT_11仅结算同一伤害一次（pass）。
- `RES/RESIST_ERASE/resolve`：真实制度锚定/供奉/查证链，抹除只毁指定结构或失效取消（pass）。
- `RES/RESIST_ERASE/cancel`：真实制度锚定/供奉/查证链，抹除只毁指定结构或失效取消（pass）。
- `RES-LIFE-001`：活动计划存档保留原目标/证据/期限，到期轮事务故障回滚与重放（pass）。
- `RES-LIFE-002`：初始无信仰仍可接受调查后果并继续完整回合（pass）。
- `RES-LIFE-003`：重算checksum也不能篡改原预告due/后果/对象/证据，坏档不半覆盖（pass）。
- `RES-LIFE-004`：真实撤关注进入后台，低察觉不撤销原预告且原due仍结算（pass）。
- `RES-PROP-001`：真实宇宙锚达到原解锁门槛；有接收教团但无通路仍原子拒绝迁引（pass）。
- `RES-PROP-002`：迁引实际使用目标域屏障与察觉检定，沿合法通路移动同一人物并守恒人口（pass）。
- `RES-PROP-003`：迁移保留个人知识，通路/邻接及因果父项不自动授予目标或未知文明机构全知（pass）。
- `RES-REVIEW-001`：同团多对象先按实际证据最近轮绑定，不被后遍历旧证据覆盖（独立选择合同）（pass）。
- `RES-REVIEW-002`：撤销旧支持后真实TRACE重新确认，保留旧历史并允许后续PURGE（pass）。
- `RES-REVIEW-003`：旧确认从8增到512，热选择不展开冷H、仅允许持久树对数读取（pass）。
- `RES-REVIEW-004`：原30开40保持45闭，有源状态与灰区坏档拒绝（共享增量合同）（pass）。

关联638项检查实际重跑；来源与父报告SHA见[机器证据](resistance-results.json)。

- 既存中局人物/教团/锚点与已确认证据是明确初始夹具；预告、到期、失效、损害和迁引均由生产代码实际运行。
- 修正现实例外通过正式祈求/事件生产；迁引沿现有POWER_TRANSFER，不新增自动跨域污染。
- 不宣称真人策略/叙事/UI/发行性能或平衡通过。
