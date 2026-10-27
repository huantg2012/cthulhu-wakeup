# TASK-EVENTS · 定向规则与接口复核

状态：本项唯一的定向静态终审通过；九项发现的同次修复已精确重读。作者：design（cult_rules），2026-10-27。本报告是人工静态规则证据；没有独立运行Godot，不替代主会话的专项、生命周期、恢复或回归结果。

## 实际范围

对照原events/event_effects的12事件24选项、event_parameters、原祈求及文明叙事合同，逐行核对event_operations与event_sources。实际读取Events/EventRules全体及Anchors、Turn、World、Prayers/PrayerRules、Economy、HistoryIndex、StateView、AbstractSim、Catalog的本次相关变化。正式任务书和架构的Events段已定向读取；测试脚本不纳入本报告来源绑定。

这是本项唯一一轮定向规则终审。发现具体偏差后，只重读同次修复的相关差异；不展开第二轮全仓探索，不增加玩法、数值或独立运行验收。

## 固定发现清单

| 编号 | 本次发现 | 最终差异复核 |
| --- | --- | --- |
| RV-EVT-01 | 03只固定合作继任者，未提取已有真实对手，03B对手接任分支不可达 | 已解决：候选沿真实relation_head和合法岗位候选固定原cooperator/opponent；执行时重查原关系/岗位，对手失格只保留空缺与否认，不另换人。误落09的继任条件已恢复原传播谓词。 |
| RV-EVT-02 | 04从PR05原actors找异端，实际只有原祭司，合法已有传播对象无法进入 | 已解决：实际传播职责、当前support/cooperation与精确PR05成功prayer_result知情共同固定heretic；原人或所属机构须实际知情，不从因果推全知。缺/失格对象只否认，零新增人口。 |
| RV-EVT-03 | 06B有多份资格时没有原资格选择接口，执行永远删除首份 | 已解决：preview/Turn选择入口仅接受固定当前qualification；默认首份明确在selection，实际result和资格撤销绑定精确ID，恢复审计同查。 |
| RV-EVT-04 | 调度只有due/priority排序，缺少原四层优先 | 已解决：先原due已到预告、最后可选择回调、其余具体来源、ambient四层；层内原priority先于due，稳定source/id及独立events流处理同档。 |
| RV-EVT-05 | 10B不重查原持有方/状态版本，归属变化后旧争夺仍可展示 | 已解决：两支共同核原实例、seized、captor和status_source；A另需合法库藏，持有方变化旧案取消。 |
| RV-EVT-06 | 公开包装按包装轮挤占两轮冷头，撤原记录后包装遮旧有效源；全部查询结果也可能膨胀成超额固定主体 | 已解决：冷索引按原record.turn聚合，实际原源撤销定向移除包装索引；只固定原蓝本所需充分包，保留不同人/不同轮/两机构条件，不按包装年龄或全K固化。 |
| RV-EVT-07 | 06A/05B基础分支允许不完整承认，但递交缺口先返回失败，可能误拒合法保留分歧/依赖 | 已解决：05/06先用真实知识递交投影检验完整承认；不足则保留原基础后果，不制造grant。02B/04A完整门槛仍严格，04A只恢复实际重叠的原否认。 |
| RV-EVT-08 | 02A未要求实际秘密记录，纯公开包也可宣称继续保密 | 已解决：02A必须有实际未公开原记录；公开索引保留真实不可逆公开。无合法A/B结案，已冻结默认失效亦有源取消，不伪造秘密。 |
| RV-EVT-09 | 卡位溢出08/11默认拖至阶段五，与本项原due阶段二交接不一致 | 已解决：_gather同阶段二先结清未入槽的到期原计划默认；已入槽保留选择，阶段五防漏，不延原due、不重复World伤害。 |

## 复核边界

原数值与费用不重新设计，费用唯一取event_effects，确定选项不额外投骰或消费祈求回应/六类任务。实际人物、原来源与当前资格应在承诺/付款前重新核验，完整证据不足不能由issuer、标题、自由true或任意event_situation代替。

02公开包装须保留真实Prayers/POWER_DREAM原根、机构与见证，不成为第二份独立来源；04B只影响原祭司/仪式proof，完整04A只恢复重叠范围，03B和无关否认保留。05继承文书和Events授权各自验证接受的发行方版本，业务字段严格同原契约/原关系，原文书必须早于死亡，不临时补人。

11只接真实World预告REWRITE与原due/target，具体例外查证先沿真实双机构PR12记录和实际知情，再由World选择计划；B的8创伤/-10污染就是全部伤害。08只接真实原媒介TRACE，B保持当前位置/效用，不附赠SEIZE；A真实移库、解除绑定并取消该次调查。其他抵抗保持原路径。

12仅真实未回应窗口触发；当轮重开来自具体12B选项、原descriptor、唯一授权和原危机due。满三offer仍可只固定本轮候选，不挤旧卡、不加第四张，不刷新回应机会。PR10成功揭示关系不自动结束争端，不为09人为延长原due。锚前机会recover/public/wait沿原唯一来源、类型与时限，不重复给物/资源。

正式Events配置的到期check先冻结同批原世界中的实际概率、roll与分支；实际选中death优先。冲突job保留真实death/check，取消其全部非death效果和树外配套费/收益；未选中的潜在death不参与仲裁。旧未安装能力的限定路径保持原范围。

## 限制与下游

本报告不证明所有运行分支、坏档/故障原子性、长期H/K/详细活动规模性能或玩家体验。主会话负责源码绑定的实际Godot专项与旧回归；本报告不绑定tools/events，不修改任何runtime哈希。完整抵抗扩量、ENDINGS断联/优先/封存、CONTENT扩量、UI、平衡、视听与发行继续原任务。旧四份人工报告本轮只追加受影响源的实际兼容性重读，保留历史并核实未变绑定，不冒称重做旧完整人工审查。


## 同次最终收口与兼容性

九项修复差异和正式spec定稿已经逐项重读；最后07标签经济接点亦已定向读取：受限view透传reader给qualification、propagation_sources及propagation_bonus，真实来源的额外察觉与经济事实父因果一致，不因稀疏事实投影而丢掉或凭缺投影假定许可。03修复中误替换09的条件已回到原机构传播合同，不把派系同盟当岗位继任。此补查仍属于原发现修复及共享接口一致性，不是另一轮独立QA。

Catalog保持旧基础摘要与新增扩展指纹分离，有限源/操作grammar和零费默认覆盖原12/24；原费用、F/N/P/L总量与其他玩法CSV没有改值。当前查询保留活身份K与实际组合规模成本，冷证据保留完整来源；撤销时的精确依赖更新与恢复全审也不是无成本。本静态结论不把这些结构说明当成H/K负载实测。

旧fidelity-rules、powers、prayers、anchors人工报告的本次compat仅实际重读其变动绑定，并逐项确认其他旧SHA未变；保存此前时间/指纹快照。它们原“未来由EVENTS承接”的历史说明按本次正式执行合同获得当前接点，不改写当时已验范围，不声称重跑旧完整人工审查。没有刷新任何运行报告。

EVENTS-RULE-REVIEW的pass仅覆盖原12/24规则映射、九项精确收口及报告列明的当前接口。正式任务完成、53项或后续专项/回归是否通过，均由主会话实际运行链和其当前源码绑定决定；本报告没有独立Godot结论。

## EVENT_04范围限制恢复校验补查（同次运行发现）

同次正式运行链发现EVENT_04范围限制缓存的恢复校验不一致：refresh按当前proof basis投影，expected_heads原先只查global。已实际重读anchors.gd本次最短修复，运行刷新与恢复校验共用纯_restriction_heads；同机构当前proof的global/原祭司/仪式/恢复截止查询一致。proof_id、changes、basis及rituals均先按Variant检查类型，坏结构不在投影阶段抛类型错，后续原_result_contract仍严格拒绝；没有放宽来源合同、清无关限制或新增H扫描。此为同次运行发现的定向补查，无独立Godot或旧运行链通过结论。

仅重新绑定实际重读的`src/game/anchors.gd`与本报告新增正文；其余既有sourceHashes逐项确认未变。运行专项和旧Anchors链由主会话真实重跑，不刷新其运行报告。

## TASK-RESISTANCE 定向兼容性复核（2026-10-27）

同一次 resistance 规则审阅的兼容性收尾，逐项 SHA 比较原绑定：实际变动为 `src/game/turn.gd`、`src/simulation/history_index.gd`、`src/simulation/state_view.gd`、`src/simulation/world.gd`、`docs/specs/system-civilizations.md`、`docs/architecture.md`；这六项本次差异均已重读，其余 17 项原绑定未变，保留原哈希。追加本段后只再绑定本报告正文。

Turn 新增正式能力轮初槽与保存能力匹配，StateView 传递脱离能力副本，不改变事件轮次与选择槽。World 仍唯一生产六类计划，圣物 TRACE / REWRITE 仍由 EVENT_08/11 在原期限承接一次；正式 TRACE 追加新有效确认而保留失效历史。固定证据主体、实际所属教团、最近有效证据排序及默认后果审计收紧来源，不新增事件伤害、费用或免费行动。HistoryIndex 的有效确认桶与撤销反向依赖只更新当前资格，不传播父因果知情；冷历史保留。原 30/45 破口迟滞保存当前布尔及最近有源 transition，真实 domain delta 先记录，随后派生 crossing；普通审计查当前 head，完整恢复才核完整历史。正式 CSV 与 Events/Rules 源码均未变。

本段只确认上述变更与原事件合同的静态兼容，沿用原审查历史，不重做原完整人工审查，不宣称独立运行、回滚或性能验收通过，不刷新 runtime 指纹。四项发现及修复重读见 [resistance 定向报告](resistance-review.md)；本任务实际运行由专项和关联回归报告提供。终局、内容与表现仍由原下游承担。
