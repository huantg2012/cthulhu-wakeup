# TASK-PRAYERS · 定向规则与接口复核

状态：定向静态复核通过，2026-10-27。作者：design（cult_rules）。这是本任务同一次规则复核及六项发现的定向收口；代码方通知冻结后重新读取修复及最终spec/architecture。没有独立运行Godot，也不以主会话转述代替实际运行证据。本报告不宣布任务验收完成。

## 范围与依据

实际对照原prayers/prayer_facts、叙事内容手册的共同语义及回应通则，检查103行prayer_effects机器映射、12型来源/对象/当前条件、浅深效果、请求与原危机、固定候选及重开授权。定向读取Prayers/PrayerRules，以及Turn、World、Cults、Powers、Economy、StateView、AbstractSim、HistoryIndex、Catalog接点和Slice 07；没有展开第二次全仓探索。sourceHashes仅绑定实际检查文件，不包含正在收尾的tools/prayers或其他运行测试。

## 六项发现与最终收口

| 编号 | 发现的业务偏差 | 实际重读的最终修复 |
| --- | --- | --- |
| RV-PRY-01 | 原生回应检查并消费人物六类执行任务机会 | prepare不再以acted_turn拒绝原生回应，meta.actor为空；实际检定actor仍固定，meta.responds独立执行每轮一次，费用、代理与Attention依赖保留 |
| RV-PRY-02 | 公开见证/先知等只有prayer_fact标签，未进入真实公开与机构知情 | 表列公开结果由有源exposure进入共享World，指定真实机构取得知情，公共事实与当轮暴露记号可被风险索引消费；秘密结果不因此全域公开 |
| RV-PRY-03 | 深隐匿被写成missing，造成全面失联并可能取消已预告抵抗 | 使用有源有限hidden，不改生命/行动状态；只过滤新known_local_exposure与新exposed追查，不进入通用subject/plan有效性，不撤pending_plan。到期只移标记，不复活、复职或免费恢复供奉 |
| RV-PRY-04 | 浅隐匿的本轮传播限制遗漏NPC公开解释 | 候选阶段只排除受限人物的公共personally_witnessed_miracle解释；正式SEED和经济expand也读取同一限制。其他行为及私人解释保留，既有计划继续 |
| RV-PRY-05 | 固化后仅深分支的第二证人、后两名记忆关系人或另一机构失效，使整张请求连浅触一起失效 | 固定身份仍保存；PR04/07/12仅深条件记deep_error，仍合法浅触保留。浅分支声明实际需要人物，不用失效深对象替代或补人；死亡人物的旧holds准确移除 |
| RV-PRY-06 | subjects/facts多余键可改变occurrence摘要，复制同处境绕过严格重开授权 | 来源根字段、12型subjects/facts及crisis均采用固定键白名单；occurrence按规范对象绑定。新source不能以无业务nonce伪造第二处境；重开仍须原关闭/回应事实、有版本授权、同原对象/危机、一次性消费且不延原due |

六项在本次实际检查范围内均已解决，没有剩余阻断性规则偏差；这是静态合同结论，不是所有分支、坏档或性能的运行证明。

## 已核对的合同边界

机器表沿原CSV及既有参数，不增加玩法数字。always、success、disaster、expiry分开；灾变理智作用实际actor，条目自身petitioner/relative/首位memory_people成本不随代理转移。深成仅缩放直接数量收益（含公共污染与屏障削弱幅度），不复制人物/证据，不放大阈值、身份或成本。数量裁界、具名人口、正式入团均交原World/Cults/Attention归属。

普通prayer_situation必须有实际人物、关系/机构/知情/物件状态及具体父因果，issuer/version不能代替当前条件。World是唯一固化入口，使用原simulation.candidates/holds及最大分支预留；回应前收费/骰前再次核验，不重新提名。每轮冻结最多3张、回应最多1次；原生回应不占六类执行任务。PR08两支成功走真实成员转换，PR09浅分支仍需原F；本任务未改F/N/P/L预算或准入CSV。

请求due保持visible+lifetime-1，原crisis.due独立；失败消费请求而不消除原处境，也不再叠未回应罚。原BG已承诺的unanswered_request默认与普通12型各自expiry区分；同源危机默认一次，窗口结束不能提前杀人，重开不能延命。保存完整审计与常规有限当前头/新增尾部校验分工保持；本静态阅读不替代恢复坏档、事务故障或旧版本差分的实跑。

神谕准备沿原Powers来源/量值/下一轮期限；PRAYER/固定ID/分支必须匹配原petitioner及开放请求，一次消费且审计实际consumer。没有圣物适用项时无额外准备。公开结果只让真实指定机构/见证者知情；争议、风险、调查资格、回调与PR11 EVENT_10原min_age/max_age争夺窗口保持有源对象和期限，不当场执行未定义伤害、回收或完整事件。

Catalog原十表摘要保持隔离，新prayers/prayer_facts/prayer_effects/events各扩展指纹；本次新增有限语法校验不改变原权能/圣物数值或其效果表。无Prayers的旧路径读取空限制，已有权能/经济权限仍须原资格；常规来源查询使用当前索引，完整H只在恢复/明确档案接口审计。本报告未测量H、K或详细活动规模的成本。

## 下游与未覆盖

下一正式TASK-ANCHORS负责八蓝本完整制度证明、结构/绑定维护及原整体验收；TASK-EVENTS随后负责完整事件池、选择、实际回调/争夺窗口消费及EVENT_12B当轮生产。受限重开授权校验不等于完整事件重开已完成。TASK-ENDINGS保留断联、终局优先、完成消费/封存与重开；UI、CONTENT、BALANCE、RELEASE保持各原任务。

PRAYERS-RULE-REVIEW的pass只覆盖上述实际重读的六项修复、数据同源与接口归属。正式Godot12×浅深四档、生命周期/恢复/故障、真实混合开局及受影响回归由主会话最终源码绑定的运行报告证明。旧fidelity-rules与powers人工报告只追加本次定向兼容历史；未改写任何旧runtime证据哈希。

## TASK-ANCHORS定向兼容性复核（2026-10-27）

TASK-ANCHORS同次定向复核实际重读八蓝本机器条件、正式Powers/Economy/World资格接点、精确share_record、Catalog独立扩展、当前限制索引及最终spec/architecture。两项限制语义/迟到知识机会偏差收口，历史合同快照与休眠语义补查完成。原F/N/P/L及参数/权能/祈求效果数值未改；旧未安装合同保留限定范围，正式Anchors不以issuer/allowed替代当前proof。EVENTS完整生产/机会处置、RESISTANCE扩展和ENDINGS仍原任务。此为静态兼容历史，不重做旧完整审查或刷新runtime证据。

本次实际重读的变化源：`src/game/powers.gd`、`src/game/economy.gd`、`src/game/turn.gd`、`src/simulation/world.gd`、`src/simulation/catalog.gd`、`src/simulation/history_index.gd`、`src/simulation/state_view.gd`、`docs/specs/system-powers-cults.md`、`docs/architecture.md`。其余既有绑定逐项SHA确认未变；本报告新增文字自身重新绑定。当前人工复核见[锚点静态报告](anchors-review.md)，运行结论仍由主会话提供。
