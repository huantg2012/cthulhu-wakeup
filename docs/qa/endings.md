# 正式终局与封存验收

实际执行：2026-10-27T10:42:11.377869+00:00；Godot 4.7.2-stable (official)；Windows-10-10.0.19045-SP0。

执行边界与初始夹具说明见 [tools/endings](../../tools/endings/README.md)。

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
- `END-CONTACT-001`：活人及既有历史不永久续命，连续断联第三轮结束而前两轮仍可操作（pass）。
- `END-SAVE-001`：已结束世界快照与分页存档恢复仍为回顾，原身份历史与摘要一致（pass）。
- `END-SAVE-004`：重算checksum的封存/计数/时间及有效联系kind/subject伪造拒绝且不半覆盖（pass）。
- `END-CONTACT-002`：第二轮后实际合法零信仰线索恢复清零，真实聆听消费后历史不续命但历史评估仍可读档（pass）。
- `END-CONTACT-003`：未观察后台的真实固化祈求有对象与期限可续联，主体死亡立即失效（pass）。
- `END-CONTACT-004`：真实既存拘禁期限须覆盖同一祈求窗口，晚释放或身份source不符不得虚假续联（pass）。
- `END-LIFE-001`：世界到期伤害使当前苏醒归零，统一轮末终局而不提前截断输入（pass）。
- `END-LIFE-002`：主动自弃独立结束，已结束世界拒绝全部普通操作且回顾纯读（pass）。
- `END-LIFE-003`：包括turn0在内六个未结束阶段自弃都可保存/重放，不多推进收入或随机（pass）。
- `END-MANIFEST/deep`：真实连续三轮支付，前两轮无终骰，第三轮唯一锁定检定与正式结局 deep（pass）。
- `END-MANIFEST/success`：真实连续三轮支付，前两轮无终骰，第三轮唯一锁定检定与正式结局 success（pass）。
- `END-MANIFEST/failure`：真实连续三轮支付，前两轮无终骰，第三轮唯一锁定检定与正式结局 failure（pass）。
- `END-MANIFEST/disaster`：真实连续三轮支付，前两轮无终骰，第三轮唯一锁定检定与正式结局 disaster（pass）。
- `END-PRIORITY/death`：第三轮已付后真实到期或供奉death优先于终局骰且不退款（pass）。
- `END-PRIORITY/anchor`：第三轮已付后真实到期或供奉anchor优先于终局骰且不退款（pass）。
- `END-PRIORITY/zero`：第三轮已付后真实到期或供奉zero优先于终局骰且不退款（pass）。
- `END-PRIORITY/upkeep`：第三轮已付后真实到期或供奉upkeep优先于终局骰且不退款（pass）。
- `END-MANIFEST-LOCK`：跨轮两域F不能免费撤回，第三轮概率预览纯读并在唯一终骰使用原值（pass）。
- `END-MANIFEST-CANCEL`：真实仪式主动取消不退款且无终骰和附赠创伤（pass）。
- `END-MANIFEST-UNPAID`：真实仪式漏付第二轮中断且无终骰和附赠创伤（pass）。
- `END-SAVE-002`：第三轮活动仪式存档重放同一终局，重算checksum篡改主体/概率/进度/预留仍拒绝（pass）。
- `END-SAVE-003`：真实第六阶段故障整批回滚不留半终局，重试只投一次骰并封存（pass）。

本项新增 22 项；完整Endings安装下继承复跑 22 项抵抗。独立父链另实际重跑 660 项（不把继承复跑计为新增）。来源与父报告 SHA 见 [机器证据](endings-results.json)。

- 机会接收人资格与满N退休释放N→P仅静态复核，本专项未独立端到端覆盖；拘禁窗口反例验证初态实际来源和纯读预览，不冒称完整后续释放链。
- 合法中局机构证明、既存教团与明确初始处境是夹具；三轮仪式、费用、原随机流、终局和存档结果由生产系统实际执行。
- 旧22项抵抗专项在完整Endings安装下重复执行；父链另由真实独立包装器重跑，不手动刷新旧结果。
- 断联检验当前可执行入口与有期限的真实计划，不预测所有未来解法。
- 无游戏内UI，不证明叙事、策略平衡、终局可达率或发行性能通过。
- 当前CSV在第三轮要求A≥90，失败伤害10、灾变20加所选宇宙锚10损失，因此同笔终骰后直接寂灭不可达；实跑失败后复算并继续，未改表造假场景。
- 有效仪式锚要求教团，而活跃/休眠教团排除彻底断联；同轮第三次断联与仍完整仪式资格不可并存。独立实跑断联三轮和第三轮死亡/失锚/归零优先。
