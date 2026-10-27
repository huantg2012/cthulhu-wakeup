# TASK-ANCHORS · 定向规则与接口复核

状态：本次唯一的定向静态复核通过。作者：design（cult_rules），2026-10-27。八蓝本与共享接点实际读取完毕；本次两项具体偏差修复后已重新读取对应差异。本报告没有独立运行Godot，不替代主会话的源码绑定专项、生命周期、恢复或回归证据。

## 实际范围

依据原civilization_conditions、机构/进度/经济/权能及叙事共同语义，实际读取anchor_conditions机器表、Anchors模块与Powers/Economy/World/Turn接点，定向读取Catalog、HistoryIndex、StateView及最终架构/Slice 08。未触框架、UI或测试脚本，没有第二轮全仓探索。最终sourceHashes只绑定实际检查的稳定源，不包含尚在补写的tools/anchors。

## 本次两项发现

| 编号 | 具体规则偏差 | 实际重读的最终收口 |
| --- | --- | --- |
| RV-ANC-01 | 同机构任何事件或抵抗都可充当blocked/denied原因，正面04A亦可反向造成否认 | 已解决：valid_restriction仅消费anchor_restrictions的原03B/04B→denied；Catalog校验有限原映射并单独绑定扩展。正面04A及任意预告/抵抗不能凭名字产生blocked/denied |
| RV-ANC-02 | 结果先存在、合法迟到递交才补齐机构知识时没有observe，锚前机会要等bind才出现 | 已解决：valid_recheck核当前同机构已知result、严格历史合同及source属于basis和直接parents；World真实递交与记录已知分支均同事务只observe该result，机会once不重骰，不扫描H |

## 已读规则的通过范围

八行机器条件保留原不同人物、不同回合、两机构/两契约端、记忆资格及原参数。存活见证按非dead，不能统一要求active；现任祭司/代表仍须active、同域、当前岗位与ritual_keeper职责。CIV04同一真实public_ritual可以兼作仪式和公开，不附加独立两源门槛。

CIV03/08按固定事件proof逐原三名人物与真实memory_preserved资格审计，不能把死人替换成新名字；CIV03需原三名当前合格，CIV08只计原集合至少两名存活且资格有效。成功解除memory_at_risk不会抹去已有见证，原历史保留；当前见证资格被撤仍会影响条件。CIV06原已履行contract身份允许保留，dependency与两端真实见证另查当前来源，普通履行不误当解除神迹依赖。合法继任须固定同契约、真实关系、死亡前已固化的继承记录，不能用普通岗位继任或死后临时补人绕过。

Powers建立/修复预览和执行、Economy供奉、World失效刷新共享同一当前机构判定；正式Anchors安装后旧issuer/allowed不替代proof，未安装的旧限定合同保持原范围。锚定仍真实付费/投骰、固定原机构ID/序号/origin与唯一人/物绑定，成功先休眠；实付供奉且最终条件成立才贡献。仅改拒付计划不提前撤旧贡献，真实失效立即停贡献；临时状态恢复不免费重建或恢复供奉。本轮低语不随回合内贡献重领，后台维护不新增F。

share_record只传实际发送者确知且可达机构的一个source，不从parents推全知。机构结果必须有具体选项、原机构、真实成功Prayers/Powers来源、实际知情和当前条件；发行方版本不是true通行证。完整EVENTS上游结果当前仍明确作为合同夹具，测试从真实业务事实接续，不宣称完整事件已制作完毕。

首次机构承认固定一次recognition与锚前有界遗物机会，类型来自原蓝本池、期限来自原参数，失承认/恢复、换任、拆建不重抽重发。只生产/到期该机会；回收、公开、等待的实际消费者及完整事件池/回调仍归TASK-EVENTS。ENDINGS保留断联、优先级、封存与重开；其他表现/内容/平衡/发行保持原任务。

## 证据限制与兼容性

静态复核不证明所有运行分支、坏档原子拒绝、长期性能或玩家体验。恢复全审与普通事务当前头/新增尾部的分工、当前proof/限制头/机会的有界保存和冷结果索引已定向读取；历史H、活身份K与真实负载仍以实际运行证据为准。原预算和数值表未重新设计，Catalog基础摘要与独立新扩展保持分离。

同次补查实际重读恢复审计最后差异：recognition与binding保存原事件合同快照，和原result及真实成功attempt逐项核对；_result_contract只核历史shape、issuer/版本、事件/选项及固定parents。当前死亡、撤销和岗位变化允许合法休眠，不被误作篡改历史；休眠也不能绕过历史语义审核。该静态结构不代替主会话坏档/恢复实际场景。

旧fidelity-rules/powers/prayers人工报告本轮只追加实际重读变化源的兼容历史，逐项确认其余既有指纹未变。没有修改任何runtime报告哈希。

## 最终静态结论

本次实际范围内两项偏差已解决，没有剩余阻断性规则偏差。ANCHORS-RULE-REVIEW的pass仅指本报告列明的规则、两项收口及同次恢复合同补查；不宣布TASK完成，不声称63项或其他运行验收已正式通过。完整Godot结果、生命周期、存档续跑、旧版本/旧档差分与回归由主会话最终绑定的运行链提供。

## TASK-EVENTS定向兼容性复核（2026-10-27）

TASK-EVENTS同次定向终审实际重读原12/24与真实源/公开知情、04范围、05独立issuer、原due交接、同轮严格重开及同批实际死亡仲裁；九项具体发现收口与07受限经济来源接点已精确复核。F/N/P/L预算、原费用和既有玩法数值未改，Catalog旧摘要与新扩展隔离。原EVENTS承接范围现按本项正式合同落实；RESISTANCE扩量、ENDINGS及内容/表现仍原任务。这是静态兼容历史，不冒称重做旧完整审查或运行验收，不刷新runtime指纹。

本次实际重读的变动绑定：`src/game/anchors.gd`、`src/game/economy.gd`、`src/game/turn.gd`、`src/simulation/world.gd`、`src/simulation/catalog.gd`、`src/simulation/history_index.gd`、`src/simulation/state_view.gd`、`docs/specs/system-civilizations.md`、`docs/architecture.md`。其余既有绑定逐项SHA确认未变；本报告新增文字自身重新绑定。九项收口和证据限制见[事件静态报告](events-review.md)，运行结论仍由主会话提供。

## EVENT_04范围限制恢复校验补查（同次运行发现）

同次正式运行链发现EVENT_04范围限制缓存的恢复校验不一致：refresh按当前proof basis投影，expected_heads原先只查global。已实际重读anchors.gd本次最短修复，运行刷新与恢复校验共用纯_restriction_heads；同机构当前proof的global/原祭司/仪式/恢复截止查询一致。proof_id、changes、basis及rituals均先按Variant检查类型，坏结构不在投影阶段抛类型错，后续原_result_contract仍严格拒绝；没有放宽来源合同、清无关限制或新增H扫描。此为同次运行发现的定向补查，无独立Godot或旧运行链通过结论。

仅重新绑定实际重读的`src/game/anchors.gd`与本报告新增正文；其余既有sourceHashes逐项确认未变。运行专项和旧Anchors链由主会话真实重跑，不刷新其运行报告。

## TASK-ENDINGS 定向兼容性复核（2026-10-27）

逐项核对原 sourceHashes，实际变化且已重读的绑定为：src/game/powers.gd、src/game/turn.gd、src/simulation/world.gd、src/simulation/history_index.gd、src/simulation/state_view.gd、docs/specs/system-civilizations.md、docs/specs/system-progression.md、docs/architecture.md；其余 14 项原绑定未变。追加本段后仅本报告正文自身重新绑定。

本次实际定向重读正式 Endings 接管与相邻生产接线：阶段五后果及阶段六教团结算先完成，断联/零苏醒先于 Powers 唯一终骰；固定三轮、原费用/概率/双域预约及四档效果不另造一套。查询只读当前教团、浅层祈求、零信仰 LISTEN、可接收的制度圣物机会及匹配当前拘禁来源的确定释放+原固定祈求窗口；DREAM不免费、祈求不额外要求零信仰、不预测收入或随机。Attention生产与查询共用确定轮初预算投影。消费/失效更新当前聆听索引；完整恢复核历史接触合同，普通审计只查当前头。自弃在所有未结束阶段原子封存，成功回执可重读，新输入拒绝。

本报告此前尚未绑定的 RESISTANCE 相关累计差异也按已实际执行的同次审阅记录核对：World 固定抵抗依据、有效确认头/撤销更新及原30/45有源迟滞，08/11仍唯一结算；不借历史指纹更新重做原完整系统审查。原 CSV 数值、F/N/P/L预算、锚点制度资格及祈求/事件来源合同不改。EN-REV-01–03 已修复定向重读，详见 [endings 静态报告](endings-review.md)。

这只更新人工静态兼容历史与实际重读来源，保留原 scope 和 reviewHistory，不宣称重新执行旧完整人工审查或任何运行验收，不刷新 runtime 报告。原值下最终失败/灾变后的最低苏醒为80/60，第三轮资格完整与断联3也不能自然并存，不把不可达交叉条件冒充实跑。高阶既存合法来源初态与真实三轮执行须分开披露；UI/BALANCE的理解与紧张感继续真人验证。


## TASK-UI 定向静态兼容复核（2026-10-27）

逐项比较原 sourceHashes：已变且本轮实际重读的七项为 src/game/powers.gd、src/game/economy.gd、src/game/turn.gd、src/simulation/world.gd、src/simulation/state_view.gd、docs/specs/system-powers-cults.md、docs/architecture.md；其余 15 项原绑定未变。追加本段后重新绑定本报告自身。

TASK-UI同次定向静态兼容补记：已读旧八蓝本/当前资格/真实知情/首次机会scope，并实际核对本轮七项已变绑定。Powers新增PlayerSources消费时重验，不取代Anchors.qualify及当前机构proof；StateView只加脱离的来源账本；World增量/全审接入新资格，BG_RITUAL固定现存仪式主体和当轮真实情境，仍不等于自动机构承认。Economy敛息及Turn正式到期所有权不改变锚点供奉、结算顺序、唯一媒介机会或原费用。原建立/维护数值与八蓝本源码未变。architecture/spec将来源生产和会话知情分开；UI两发现修复限于ui-review.md静态闭环。保留原scope与审查历史，不重做旧完整审阅，不声明独立运行或真人UI验收。

本报告不绑定tools/events/run.gd；主任务调整真实PR05优先级夹具与其运行结果不冒充本人工审阅者的执行证据。未修改任何runtime报告。
