# 正式事件池与到期调度验收

实际执行：2026-10-27T05:50:22.986740+00:00；Godot 4.7.2-stable (official)；Windows-10-10.0.19045-SP0。

真实generate_hybrid/Turn/Economy/Cults/Powers/Relics/Prayers/Anchors/Events，正式CSV、原对象与当前来源。执行协议见[tools/events](../../tools/events/README.md)。

- `EVENT/EVENT_01/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_01A（pass）。
- `EVENT/EVENT_01/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_01B（pass）。
- `EVENT/EVENT_02/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_02A（pass）。
- `EVENT/EVENT_02/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_02B（pass）。
- `EVENT/EVENT_03/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_03A（pass）。
- `EVENT/EVENT_03/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_03B（pass）。
- `EVENT/EVENT_04/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_04A（pass）。
- `EVENT/EVENT_04/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_04B（pass）。
- `EVENT/EVENT_05/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_05A（pass）。
- `EVENT/EVENT_05/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_05B（pass）。
- `EVENT/EVENT_06/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_06A（pass）。
- `EVENT/EVENT_06/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_06B（pass）。
- `EVENT/EVENT_07/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_07A（pass）。
- `EVENT/EVENT_07/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_07B（pass）。
- `EVENT/EVENT_08/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_08A（pass）。
- `EVENT/EVENT_08/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_08B（pass）。
- `EVENT/EVENT_09/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_09A（pass）。
- `EVENT/EVENT_09/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_09B（pass）。
- `EVENT/EVENT_10/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_10A（pass）。
- `EVENT/EVENT_10/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_10B（pass）。
- `EVENT/EVENT_11/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_11A（pass）。
- `EVENT/EVENT_11/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_11B（pass）。
- `EVENT/EVENT_12/A`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_12A（pass）。
- `EVENT/EVENT_12/B`：真实来源/固定对象/确定性选项/精确费用/因果后果 EVENT_12B（pass）。
- `EVENT-BLUEPRINT/CIV_01`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_01（pass）。
- `EVENT-BLUEPRINT/CIV_02`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_02（pass）。
- `EVENT-BLUEPRINT/CIV_03`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_03（pass）。
- `EVENT-BLUEPRINT/CIV_04`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_04（pass）。
- `EVENT-BLUEPRINT/CIV_05`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_05（pass）。
- `EVENT-BLUEPRINT/CIV_06`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_06（pass）。
- `EVENT-BLUEPRINT/CIV_07`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_07（pass）。
- `EVENT-BLUEPRINT/CIV_08`：八蓝本真实祈求到事件证明、唯一机会回收和实付锚定 CIV_08（pass）。
- `EVT-REVIEW-009`：同为窗口内第三层，较高原priority先于更近due；不能仅按due压掉人物机构事件（pass）。
- `EVT-REVIEW-007`：明示既有传播资格合同：实际07B仅传教时加一察觉，07A无该加成（pass）。
- `EVT-REVIEW-008`：真实09A许可进入经济预览/计划与实际传播，原许可保留直接因果父项（pass）。
- `EVT-REVIEW-006`：06B纯预览明确选择非首份原资格，陌生ID拒绝且只撤所选一份（pass）。
- `EVT-REVIEW-005`：真实回收改变原持有版本，旧10A/B均失格并结案、不换媒介或发放重复收益（pass）。
- `EVT-REVIEW-003`：原处境真实rival且岗位合法的既存对手在03B实际继任（pass）。
- `EVT-REVIEW-004`：04B原关系里的合法传播合作者被固化并实际接收四名信众（pass）。
- `EVT-REVIEW-001`：不完整首次仪式不能承认；原否认保留历史，跨轮完整同basis04A有源恢复（pass）。
- `EVT-REVIEW-002`：原三人仅一存活仍可保存记忆分歧，不以不足完整蓝本伪造制度承认（pass）。
- `EVT-POOL-005`：旧真实梦境超过回调窗口仍可与新证词组合；冷索引存档恢复且不伪造第二见证（pass）。
- `EVT-POOL-004`：三个真实调查同due仅占两主要位，第三原期限默认一次；同档独立events流存档复现（pass）。
- `EVT-POOL-001`：真实混合无重大来源允许零事件，不消耗events流或凭空补卡，未知请求原子拒绝（pass）。
- `EVT-POOL-002`：回调原幸存者在可见前死亡后不换人、不生成替代结果（pass）。
- `EVT-POOL-003`：同一已固化事件不重复选择，跨阶段请求不重付费或重放后果（pass）。
- `EVT-OPPORTUNITY/public`：实际首次承认机会：public精确资源、唯一产物与互斥（pass）。
- `EVT-OPPORTUNITY/wait`：实际首次承认机会：wait精确资源、唯一产物与互斥（pass）。
- `EVT-OPPORTUNITY/recover`：实际首次承认机会：recover精确资源、唯一产物与互斥（pass）。
- `EVT-OPPORTUNITY/expiry`：等待不刷新原due，到期无重复媒介和资源收益（pass）。
- `EVT-LIFE-001`：正式到期检定真实四档身份分支 deep（pass）。
- `EVT-LIFE-002`：正式到期检定真实四档身份分支 success（pass）。
- `EVT-LIFE-003`：正式到期检定真实四档身份分支 failure（pass）。
- `EVT-LIFE-004`：正式到期检定真实四档身份分支 disaster（pass）。
- `EVT-LIFE-005`：实际选中死亡优先、检查保留、整项非死亡费用/收益取消（独立job）（pass）。
- `EVT-LIFE-006`：实际选中死亡优先、检查保留、整项非死亡费用/收益取消（同job）（pass）。
- `EVT-LIFE-007`：未选死亡分支不抢优先且实际非致死分支正常执行（pass）。
- `EVT-LIFE-008`：同批后续故障完整回滚检定RNG/身份/费用/完成键，重试仅发生一次（pass）。
- `EVT-LIFE-009`：原危机同对象原due当轮重开并真实回应（pass）。
- `EVT-LIFE-010`：满三请求不挤旧且保留当轮可见候选（pass）。
- `EVT-LIFE-011`：真实分页存档恢复待到期检查并保持相同RNG/身份/因果结果（pass）。
- `EVT-LIFE-012`：重开存档恢复、重复事件不可复用、重算checksum的伪造授权仍拒绝（pass）。

关联576项检查实际重跑；来源与父报告SHA见[机器证据](events-results.json)。

- 使用真实generate_hybrid与正式CSV、Prayers/Events/Anchors/World/Relics/Economy；特殊初始人物关系/既存处境为明确来源前提，不预置事件结果。
- 本项实现原12事件24分支及有限机会处置；首发条目扩量和叙事体验、完整抵抗/终局/UI/平衡/视听/发行仍归原任务。
- 到期概率身份的额外分支使用明确受限调度合同验证共同仲裁；原24事件选项确定性，不为它们增加额外骰。
- 不宣称本项是恒定成本、发行性能或完整游戏体验通过。
