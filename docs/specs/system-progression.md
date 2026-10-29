---
status: PROPOSED
created-by: design
last-modified-date: 2026-10-29
last-modified-by: design
interface-changed: true
interfaces-with: [system-turn-economy, system-powers-cults, system-civilizations, system-events]
exposes: [十类关键进展二十路线与唯一实施接口责任, 当前苏醒与历史峰值, 锚点贡献, 创伤与洞见, 权能可用资格, 持续降临, 结局与编年史封存, 后台锚点与断联资格, 降临跨域关注预留, schema2实际依托的存续与恢复]
---

TL;DR：苏醒由仍有效的文明锚点、有限洞见与可累积创伤共同决定。玩家必须让自己留在现实中并承担高阶文明反制，进度可大幅回退；寂灭和终极苏醒都会结束本局，但保留回顾记录。

**设计修订／运行时未兼容（TASK-CULT-DIRECTION，2026-10-27）：** 密教schema2规则和CSV已按本节修订，新增取舍仍供制作人审阅，非体验终审。当前src仍消费旧机构许可/事件证明；TASK-PRAYER-KNOWLEDGE已接入Catalog对新表、空event条件、新selector及open_route的有限语法校验；这不代表相应密教消费者已支持。现有游戏不能被当作本修订已实现或可继续运行；后续由CULT-SPREAD／ANCHOR-ROUTES／ANCHOR-LIFECYCLE／CULT-SAVE-COMPAT接入，其他祈求生产沿PRAYER链。下文既有实施记录仅说明旧规则范围，不能覆盖本次差异。

**实施边界（TASK-ENDINGS）：** 分层推演、正式经济、教团、权能、祈求、机构锚点、事件与抵抗已按各自范围验收。本项接入正式轮末终局、当前断联资格与结束封存；接入状态与运行证据由本项验收登记，不以既有上游合同测试声明终局完成。玩家理解、三轮紧张感与长期平衡继续由 UI／BALANCE 等任务验证，发现规则失配时回退本 spec。迁移顺序与接口见 [架构](../architecture.md#分层推演的正式接口与迁移边界)。


# 苏醒、锚点与终局

## 1. 进度不能只等于银行余额

本版将污染与苏醒分成两个阶段。污染使文明逐步容纳异质影响；具体机构形成对这种影响的依赖，并由人物与圣物持续维持后，才构成锚点。锚点的现存贡献使苏醒增长，机构或媒介丢失则贡献可以失去。

世界状态不是永久兑换券。高污染不会每轮自动发放苏醒，屏障重复开闭、污染反复跨阈值与锚点拆建也不会重复领取永久进度。

公共参数唯一来源是 [run_parameters.csv](../../data/run_parameters.csv)，机构成立条件属于 [文明规则](system-civilizations.md)。

## 2. 苏醒公式与信息

当前苏醒为：

`A = clamp(初生自我 + 有限洞见 + 所有有效锚点贡献之和 − 创伤, 0, 终局前上限)`。

初生自我使用开局苏醒参数；洞见是本局从不可重复的牺牲与圣物来源提取的有限个人理解；创伤承接文明对邪神本体的直接伤害。只有锚点贡献是持续依赖世界局势的部分。玩家应能展开这四项来源，而不是只看一个无法解释的总条。

当前基线初生自我十、洞见上限二十、终局前上限九十九。创伤最低为零，不设置会吞掉额外伤害的任意上限。所有损失必须指向来源事件；减少苏醒的效果应选择“破坏某锚点”或“增加创伤”，不能同一后果无说明地双扣同义伤害。

每次相关事实变更后立即重算当前苏醒，并同步刷新历史峰值、信仰容量与可施放权能资格；批次演化在整批落地后刷新一次。阶段四新锚激活后提升的容量可用于阶段五收入，不先按旧容量丢弃再增加容量。历史最高值只用于保留已见权能说明与信仰容量，不让玩家在低谷继续无条件使用全部高阶能力。回合内归零暂不截断输入，轮末统一判寂灭，给玩家本轮使用已有合法手段的机会，但不生成额外救援。

## 3. 机构锚点与顺序

每域默认三个机构，各最多一个锚点身份。首次成功锚定时，为该机构分配该域尚未使用的最低序号；序号随后永久不变。前三个序号的建立污染门槛基线为二十五、五十、七十五，维持门槛为二十、四十五、七十。

如果第一锚点被毁，第三锚点仍按第三门槛维持，不能通过拆前锚把全部锚点洗成低要求。重建原机构沿用原序号；新机构若替代被彻底抹除的机构，必须继承该机构位置与来源，不能无限添加新的低序号插槽。

建立还要求机构蓝本的具体条件成立、教团人数与凝聚达标、一个可护持的具名信徒和一件可绑定圣物。一个人或一件圣物只能服务一个锚点。机构条件取真实记录/祭仪/记忆/契约/例外的持续依托，不取官方是否赞同。八蓝本schema2判定唯一见文明规则第9节；建立、修复、供奉共用同一当前判定，首次实际依托遗物机会在锚定前产生。敌对却仍被神迹依赖的结构可成立，口头认可而无材料则不能。

首次锚定直接把所选合法且未绑定的信徒委任为护持者，无须先对尚不存在的锚点使用任命。已建锚点更换护持者则需使用任命，下轮任职生效后再完成一次修复锚定；不能用普通任命跳过机构与媒介条件。保留同一护持者与圣物、仅暂停供奉或暂时低污染的锚点，无须重做任命。

锚定权能即时判定本次建立或修复是否成功。成功后保留机构、护持者、圣物和来源事实，先进入“休眠：待本轮供奉”状态。本轮结算实际支付供奉且所有维持条件仍成立，才进入有效状态并提供贡献。失败支付的成本不返还；灾变按权能表处理。

## 4. 锚点状态与供奉

使用四个明确状态：

- **未建立（absent）**：无成功建成历史，不提供贡献。
- **有效（active）**：机构条件、污染门槛、教团、护持者、圣物与本轮供奉全部成立，提供当前苏醒。
- **休眠（dormant）**：成功建立的结构仍存在，但暂失一种或多种维持条件，例如停供、污染回退、失去护持者、媒介被扣押、教团休眠。贡献为零，历史保留。
- **被毁（destroyed）**：必要机构或媒介被永久摧毁，需重新满足其建立条件并使用锚定权能修复。来源和序号不重置，不增加一次性奖励。

休眠原因需分别列出。仅因停供、污染暂低或原护持者临时失能，且机构结构及原绑定均完整的锚点，在全部条件恢复并实际付费后可直接恢复有效；绑定对象更换、结构失效或被毁必须重新使用锚定，不能通过自动付款凭空换一个人或物。

每个有效锚点的贡献与供奉按文明层级决定：星球贡献四且每轮付一；星系贡献七且每轮付二；宇宙贡献十且每轮付四。这是按风险与维持负担组织的初始曲线，尚未平衡。

玩家可以逐个拒付并安排优先序；零资金时所有未付锚点休眠，不欠债，也不虚构随机保底维护。上一轮已有效的锚点维持贡献直到本轮供奉结算，只改变拒付计划不会提前撤回它；实际拒付才休眠。这允许玩家在放弃某处立足点前完成一次仍合法的行动。刚建立的锚点尚无上轮有效状态，必须付清当轮供奉才开始贡献。折叠或不查看文明不会暂停维护。

护持者死亡、离开或被献祭，立即撤销其锚点贡献；圣物失去控制时同理。只有条目明确使媒介永久毁灭时才转被毁，否则通常休眠。被破坏的是哪一个锚点，应与暴露来源和抵抗目标一致。

拘禁、失踪等临时失能立即停止护持贡献，但保留原名义绑定；释放或归来不自动换护持者，也不立即免供奉激活。其与死亡/迁移的区别见 [人物生命周期](system-powers-cults.md#npc-lifecycle)。

**schema2恢复边界。** 材料或实际保管/实践者恢复只重建当前资格，不免费把休眠锚激活；原结构及原护持/圣物绑定完整时，仍待下一次实际供奉后恢复。结构被毁或需要换护持者/圣物时须原POWER_ANCHOR修复。无关官方代表换任、态度由支持变敌视、旧EVENT03B/04B否认都不独立休眠锚点；实际材料、绑定或所需载体丧失才按具体原因失效。降临仍查当前有效锚点，不能借旧认可、历史峰值或新schema声明忽略已失去的贡献。新增公开只来自实际降临等既有公开效果，秘密依据本身不替敌方补证。

## 5. 洞见与创伤

洞见只能来自有来源身份的一次性转化。献祭见证者和解离圣物都记录已消费来源，不能读档时重新授予、不能改名字再领，也不能把重建教团伪装成新见证。

洞见上限使永久成长不能替代世界立足点；达到上限后执行相关消耗会预览实际收益为零，不自动销毁玩家的对象。

创伤可由文明本体反制、仪式灾变等增加。恢复方式包括献祭的愈合模式，以及整轮敛息。敛息支付六信仰并放弃本轮全部祈求回应、权能与圣物操作，减少三创伤；其资格和时机见经济规则。没有创伤时不可为刷经历而执行敛息，资源不足时不可执行。恢复不是保证，世界仍演化，可能在恢复本体时失去外部锚点。

## 6. 成长节奏与目标转换

起步关注建立联系、理解一个文明的进入条件，并形成能供奉的教团。锚定早期即可见，但必须完成真实前置工作，不能点击空按钮直接攒进度。

当玩家取得低阶立足点，问题转为如何分配注意力：发展本地、修复受损机构、向其他时空传播，还是承受高阶文明的发现。新权能提供新行动方式，不以无限增加每轮次数取消选择。

成熟期的核心问题是把有限的收入与行动预算分给哪些机构。某些世界可能被主动放弃；保存人物与圣物不等于保住所有进度。失败后的重开主要继承玩家知识与已阅读的回顾，不设永久战力升级树来抵消湮灭主题。

六十至一百二十轮只是内容与节奏预算的起始估计，不是强制倒计时，也不是已验证时长。没有“达到某轮自动输”规则；持续世界压力来自实际状态、计划与维护。玩家可以主动结束无望的一局，记录为自弃寂灭而非隐藏胜利。

## 7. 终极降临

降临是三轮连续仪式，不是用库存信仰直接购买胜利。开始时须当前苏醒达到终极门槛，至少有一个有效宇宙锚点、一个有效星系锚点，并指定其中宇宙锚点的护持者为仪式主体。起始费用来自权能表。

开始轮算第一轮。该轮行动阶段登记仪式并立即向关联文明产生“正在降临”的公开事实；这使合法抵抗更容易取得资格，但不凭空跳过预告程序。第一、第二轮不提前投终局骰，不展示伪造的成功结局。

后续每轮行动阶段，玩家可支付持续费用并占用仪式主体的执行机会，使本轮继续；当前基线每轮低语三、信仰八。未支付、主动取消、主体无效或缺少所需有效锚点时中断，已付成本不返还。中断不自动增加创伤，除非具体攻击或失败条目明确声明。

每轮末再次核验当前苏醒与锚点资格。若在行动后被文明打断或因供奉不足失去资格，该轮不能推进计数。第三轮支付持续费用时，先按当时主体、准备与文明状态展示并锁定最终四档概率；此后新增准备不追加入已经提交的仪式，文明变化也不暗改已展示概率。到该轮末仍满足持续条件，才按锁定概率进行一次检定；条件失效则按中断处理而不投终局骰。行动预览明确列出“概率已锁定，已预告攻击或供奉不足仍可中断”这两个不同风险。

深成或成功均完成苏醒并设为一百，进入归于混沌的结局。失败中断并增加创伤；灾变增加更大创伤并使所选宇宙锚点休眠。失败可以仍有机会重整，也可能直接触发寂灭；没有强制保命和无限重试豁免。

## 8. 寂灭与结算优先级

轮末先完成世界、收入与到期后果，再重新计算锚点、苏醒与断联状态。优先级为：

1. 当前苏醒不大于零，或彻底断联达到期限：寂灭，取消尚未完成的降临。
2. 仍存续且第三轮降临条件完整：执行终极检定；成功进入混沌，失败应用创伤与锚点损失后再检查寂灭。
3. 两者均未发生：保存当前状态，进入下一轮。

彻底断联的定义是同时没有活跃或休眠教团、没有有效人物联系、没有可达有效祈求，也没有可用媒介线索。这里“有效人物联系”要求存在合格的祈求候选、能执行的零信仰接触，或有明确对象和到期时间、届时会提供合法接触机会的真实计划；仅在档案中认识一个仍活着的人，不自动算有效联系。媒介线索同样须尚未消费且其下一步资格成立，不把不可达或已经失效的历史条目当作永久续命条件。

连续彻底断联达到参数表期限后寂灭；基线三轮。每轮显示断联计数及仍缺什么，不自动捏造祈求救活存档。任何合法接触恢复就清零；只有历史中存在的死者或不可达线索不算恢复。这是当前资格与有界计划检查，不求解全状态空间，也不等同于预测玩家还能否获胜。

正式查询复用现有生产资格：合格且可达的浅层祈求、原表零信仰的聆听与其尚未消费的具体线索、已固化且仍有效的祈求时窗、当前可用的实际依托圣物机会，以及能证明未来接触对象与原期限的已排定生产计划。祈求自身不额外要求零信仰；其费用与注意力仍须满足原浅层入口。入梦按原表支付信仰，不能被断联查询擅自改为免费接触。只有泛用标记、一个未来 due 或未固化随机提案，不构成真实接触计划。

本项有限未来计划包括上述固定祈求时窗，以及 Powers 已登记、仍匹配人物当前拘禁来源的确定释放；后者还须有同一固定祈求，其原时窗覆盖释放后可执行时点，并在该时点通过原对象与注意力资格。死亡、过期请求或没有真实释放来源不能靠预测归来续命。不递归解释任意 Turn 排程效果；新增接触生产者必须显式扩展索引、来源合同与验收。

轮末查询使用确定的下一行动机会预算：按原参数恢复低语和回应次数，保留真实 F／N／P 持久占用，仅承认按现有规则确定会在轮初释放的名额。不能因为本轮已用完回应或低语而误记断联，也不预测尚未产生的收入、随机提案或玩家未来能争取到的名额。查询副本不实际推进时钟、不扣费、不改变关注或随机。

这条规则防止基础自我让完全空的世界无限跳轮。它不保证所有经济困境都有出口。还有活跃文明、人物和事件的困难局面可以继续，由玩家决定是否放弃。

## 9. 结局、存档和重开

寂灭与完全苏醒都将本局标记为结束，不允许在同一局继续执行普通操作。结局保留种子、编年史、关键人物、死亡/牺牲/锚点轨迹以及最终因果摘要，供回顾。

“死档”指本局不可继续，不等于删除磁盘上的历史文件。默认不把真实存档销毁当叙事机关。读取已结束的存档进入回顾，重开创建新局，不覆盖旧历史。

自弃是所有未结束阶段可提交的独立会话操作，按事务中断未完成仪式、记录自弃寂灭并立即封存；不消耗普通行动次数或注意力，也不继续结算尚未发生的阶段。已成功提交的结果可按原回执重读；封存后新普通操作拒绝。回顾只读且可分页，种子、身份和原始因果历史留在本局，重开使用新会话。

重新读盘不重抽已执行结果，随机流和待结计划保持一致。保存读取的可靠性与版本迁移由架构承担；它不能重新发洞见、圣物或首次奖励。

## 10. 验证要求与重要假设

- 锚点顺序、机构身份与一次性来源在破坏/修复/读档后保持一致。
- 移除贡献会真实降低苏醒并改变资格，不用“历史解锁”掩盖进度回退。
- 新建锚点未付供奉时不借出进度；原有效锚点失去媒介时立即停贡献。
- 降临最后一轮不能越过同轮已确定的死亡、断联或锚点失效；结束后不会继续发普通收入。
- 一切数量与计数边界可检查，但不能据此宣称湮灭率、终局到达率或长期乐趣已经达标。
- 当前重点待验证：有限洞见是否足以保留成长感而不稀释失败；高阶维护是否迫使有意义的收缩而非单纯缴费；降临三轮是否形成紧张窗口。它们属于完整策划的待验证假设，不恢复短体验前置阶段。

## 11. 后台进度与持续工程

后台锚点仍按原机构/护持者/圣物/污染/供奉条件提供或失去贡献，收入与费用不降频。正式护持者属于持续详细的绑定成员集合，不能把世界改为后台就把护持者降成无名人口。锚点休眠、结构破坏、护持者死亡、洞见消费、创伤与峰值沿共同精确账本即时刷新；概略生产者无权凭“文明完成污染”发放苏醒或重置创伤。

建立/修复锚点是目标域主动干预，须取得 F 并在可能绑定新护持者时先预留 N。已有效锚点的普通维护不强制占 F，允许玩家把注意力移向新域，同时承担后台实际风险。撤关注不能恢复被毁锚点或取消已知攻击。

降临开始和每轮继续都须保留绑定的宇宙/星系两域 F 与仪式成员；这些跨轮需求在开始扣费前一起预留。不可通过轮流关注两域满足同轮资格，不可自动换一个后台锚点代替已被摧毁的仪式对象。中断仍按第 7 节规则，释放按下轮轮初处理，已付代价不返还。

断联判断只查当前可执行接触索引与有期限的真实接触计划。后台世界、尚未固化的随机 proposal、被归档的旧认识都不自动续命；合法已固化祈求即使其域不重点，仍按其零信仰分支、临时主体和注意力需求判断可达。不能把必须等待释放名额但无真实到期路径的空想当作有效联系。寂灭和苏醒仍按原优先级，没有后台安全保护。

## 12. 关键进展的机会供给（DEC-022，共通设计／尚未实施）

首次教团、八蓝本扎根及终极降临共十种目标，其清单唯一见 [progression_opportunity_goals.csv](../../data/progression_opportunity_goals.csv)。本表目前全部`design_only`，只冻结目标口径和责任，不是已实现生产者、可执行路线或自动求救清单。共享等待/补偿/实际服务与版本合同唯一见事件规则§14.8，数值来自opportunity_parameters.csv；当前Catalog/调度尚未装载新表，游戏未获得本节保证。

| 目标 | 真实完成判定与必须保留的共同条件 | 完整路线设计归属 |
| --- | --- | --- |
| GOAL_FIRST_CULT | `first_cult_established`：本局首次真实cult_established及成员准入完成；仍需原忠诚、实际本域支出、无名信众等条件。献身卡出现或一次浅触不是成团 | TASK-FOUNDATION-ROUTES-DESIGN |
| GOAL_ANCHOR_CIV01 | `current_anchor_active`：指定真实机构槽的锚点当前active且profile匹配CIV_01；保留真实异常记录/见证依托，独立双见证与同人跨轮记录依赖按文明§9.7区分 | TASK-FOUNDATION-ROUTES-DESIGN |
| GOAL_ANCHOR_CIV02 | 同上，profile=CIV_02；保留真实祭仪及可承续者，现行calendar_ritual的跨回合条件不能用同轮复制充数 | TASK-FOUNDATION-ROUTES-DESIGN |
| GOAL_ANCHOR_CIV03 | 同上，profile=CIV_03；保留真实共同记忆/持有者及逐人资格，不能靠同名新人物补见闻 | TASK-MEMORY-CONTRACT-ROUTES |
| GOAL_ANCHOR_CIV04 | 同上，profile=CIV_04；保留实际祭仪依托，不恢复官方传教许可或普遍赞同 | TASK-FOUNDATION-ROUTES-DESIGN |
| GOAL_ANCHOR_CIV05 | 同上，profile=CIV_05；文明§9.6给出独立梦境/证据与真实往返应答依赖两路。后者不冒充独立根，两路均保持实际网络与两端承载 | TASK-AXIOM-NETWORK-ROUTES |
| GOAL_ANCHOR_CIV06 | 同上，profile=CIV_06；保留真实契约神迹依赖、两端及原义务/继任身份，不能凭补偿伪造履约 | TASK-MEMORY-CONTRACT-ROUTES |
| GOAL_ANCHOR_CIV07 | 同上，profile=CIV_07；文明§9.6给出同异常双节点独立复核与单节点跨轮档案依赖两路，事件§14.10定义实际生产。双节点不再是共同硬门槛 | TASK-AXIOM-NETWORK-ROUTES，首个完整示范 |
| GOAL_ANCHOR_CIV08 | 同上，profile=CIV_08；保留真实不可合并记忆、原见证与有效存活资格，不替换原身份凑数 | TASK-MEMORY-CONTRACT-ROUTES |
| GOAL_MANIFEST | `manifest_complete`：原持续仪式实际成功并进入终极苏醒；当前A、宇宙/星系锚点、同轮F/成员、费用、三轮持续与最终检定仍成立。能看到或开始仪式不是胜利 | TASK-AXIOM-NETWORK-ROUTES |

锚点目标instance_scope为institution，按真实domain/profile及机构槽登记；每槽只匹配一行。完成仍须共同的教团、污染、护持者、可控圣物、成功锚定和当轮供奉，不因满足材料便直接激活。当前依托rule见文明§9；上表没有将所有现有细项升格成不可替代的作者定案，也未提前放宽它们。后续路线若调整现行依托必须原地更新其原spec/CSV、消费者和反例，不能只在路线说明中暗开旁门。

所有目标均须至少两条触发原因或玩家行为不同的完整路径，包含玩家可促成方式；移除一路后，另一路不能仍依赖同一独占事件/人物/随机结果。真正共同的世界观条件与可替代环节分开。已有合法的直接行动可以是机会入口，例如终极降临条件已满足时直接走原入口，不必先造随机事件；这不等于终局取得各前提的替代路线已经交付。

每个目标内部的step只对应当下真实缺口。一次浅触、同源材料包装或无关卡片不完成整个目标；成功尝试也只有形成真实里程碑才改变completion_rule。首次成团是历史一次目标；指定锚点后来失效用同一目标键开启有源恢复周期；终局结束后不再排机会。等待债务不是接触计划，不能冲掉第8节三轮断联；缺物理前提、容量永不释放或玩家造成不可逆失败时，记录真实原因，不虚构补救。

共享等待合同唯一见事件§14.8；三组完整路线分别见§12.1–12.3，父TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees的十目标/二十路线统一索引、物理前提、成本风险及实施责任见§12.4。该父汇总保留全部原ACC；子任务当前静态证据由独立QA复核，不因旧报告存在或路线数量齐备自动通过。设计合同与当前游戏是否已安装、实际行为及自然可达分开记录。

### 12.1 Axiom, Network, and Manifestation Routes：六条路径及机会终点（设计待实施）

[progression_routes.csv](../../data/progression_routes.csv)中本组的六条route ID与[progression_route_operations.csv](../../data/progression_route_operations.csv)中本组的五个操作及参数，由本节解释；全表二十路线/十八操作见§12.4。两表均design_only。`delivery_bound=0`仅表示安装后**当前输入齐备的某一步**无需排随机/展示队列即可实际执行，证明与准入唯一见事件§14.10.1；不能读成新局零轮形成依托或成功保底。自然PR12/PR04等仍可贡献真实材料，但其B/A链没有在本批取得有限L证明，不能据其有概率出现代替正式主动路线。

路线CSV的producer_task指定真实世界来源责任：Axiom/Network操作由各自任务实现；终局供奉恢复由ANCHOR-LIFECYCLE接入当前basis后的原Economy/World实际支付和贡献更新，敛息由TASK-ECONOMY已有正式REST API产生，不新写第二份经济。coordination_task六行统一OPPORTUNITY-SCHEDULER，只负责Goal/step与已有或新入口的登记、机会服务和受控接线复验，不支付供奉、不改创伤或制造材料。consumer_task为材料判定/终局结果原归属，ENDINGS继续消费实际终局成功；联合路径复验归SOURCE-CLOSURE，完整保存联合验证归CULT-SAVE-COMPAT。复用原经济API不修改或重签TASK-ECONOMY的历史验收。操作父任务须等共享核心、两组动作及正式界面接线全部完成，下游不得把仅安装数值表算作可服务。

终局入口采用封闭的能力映射：`POWER_MANIFEST`及`POWER_MANIFEST_CONTINUE`是实际ActionCatalog权能键，继续入口不能错用Attention policy的`MANIFEST_CONTINUE`字符串。`SESSION_REST`是本路线注册表对现有`Session.rest(confirmed)`/Turn `rest`内建操作的明确别名，业务payload为空，confirmed仅是原展示确认参数；`SESSION_SET_ECONOMY_PLAN`是对`Session.set_plan(plan)`/Turn `set_plan`且participant固定economy的内建别名。它们不是powers.csv新增行，也不是现有ActionCatalog已经具有同名key的声明，安装路线适配器前不能注册active。路线适配器的plan必须完整提供且仅提供`strategies,anchor_priority,refuse_anchors`；strategies为真实cult ID到原经济合法策略枚举的字典，两数组为无重复的真实anchor ID，未知字段/别名/伪ID在提交前拒绝，真实内容再复用原Economy.validate_plan。适配器保留当前未修改项，不因只调整一个锚丢掉其他维护计划。各内建操作仍走原Session/Turn信封、阶段、重试及保存协议，不能改用新的无回执旁路。

| route | 本路输入、实际步骤与输出 | 差异成本/风险及移除另一路的见证 |
| --- | --- | --- |
| ROUTE_CIV07_NODES | CIV07目标槽已有实际成员；ROUTE_AXIOM_PROBE在本槽作当下观察并尝试保留。另一真实连通槽的不同成员与来源提供者实际参加ROUTE_AXIOM_RECHECK，独立观察同一exception并保留。当前两端依据合法后，回收原首次依托遗物或使用已有合法圣物，按原POWER_ANCHOR建立及实付供奉，真实active才完成目标 | 两次成功试验/两节点材料；每次按操作表支付且可能失败，复核需要两人实际执行机会，持续暴露与通信/两位原观察者风险。关闭单节点REPEAT后仍可独立完成，不依赖EVENT11或特定随机PR12卡 |
| ROUTE_CIV07_ARCHIVE | 同目标槽一名成员作真实probe；对同一例外在两个不同回合实际执行ROUTE_AXIOM_REPEAT，成功形成axiom_dependency。沿同一原遗物/锚定/供奉链达成当前active | 无需第二节点、links、另一个观察者；代价是更多付费试验、跨回合等待/冷却和单一实际操作者风险。关闭RECHECK、移除另一机构通信仍可从合法单节点前提完成；不是双节点记录改名 |
| ROUTE_CIV05_DREAMS | CIV05两个连通槽各有不同真实成员，各自ROUTE_GUIDED_DREAM成功，形成各自独立miracle；原合法POWER_DREAM也可贡献。两端真实保管构成network_independent，接原遗物/锚定/供奉链 | 两次原入梦成本、两次独立检定及各自理智/忠诚后果，通信与原见证者必须存续。关闭NETWORK_EXCHANGE后仍完整；不等待唯一集体梦境事件 |
| ROUTE_CIV05_EXCHANGE | CIV05两个连通槽的不同真实成员实际参加一次ROUTE_NETWORK_EXCHANGE，成功形成两端使用和同一network_dependency；接原遗物/锚定/供奉链 | 一次深干预级成本与检定，两人都付理智/执行机会且不加忠诚，明确暴露较大。关闭全部梦境材料仍可完成；端点是实际工作结果而非复制记录，通信仍是共同物理前提 |
| ROUTE_MANIFEST_ANCHOR | 当前A不足但两座仪式候选宇宙/星系锚均真实active；另有一座**非仪式**锚仅因真实停供休眠，材料/绑定/维持条件已完整。玩家通过SESSION_SET_ECONOMY_PLAN恢复其实际供奉，原经济结算核实已付及资格后恢复贡献；下一actions再核A与原降临条件，执行POWER_MANIFEST及持续链 | 付真实维护费并恢复以后维护负担，世界仍可打断材料/供奉；保存计划或预付pending均不是恢复。移除REST仍可靠这座额外锚的真实贡献取得仪式机会 |
| ROUTE_MANIFEST_WOUNDS | 当前A不足、有真实创伤，当前两座仪式锚及其他有效贡献本可在恢复创伤后达到门槛；先合法整轮REST，再在新的actions当前重查原POWER_MANIFEST与持续链 | 敛息付原信仰且放弃整轮干预，世界仍演化；额外休眠锚在见证中保持显式拒付，不以其偷偷恢复代替敛息贡献。移除额外锚恢复入口后，真实减创伤仍能促成同一终局机会 |

四条锚点路线的共同前提是已有真实信徒与相应文明/机构，不保证无信徒高阶域直接开工。实例key仍为目标机构，例外/材料/操作者不是无限新目标；step依实际缺口依次为`material_start,material_followup,relic_access,anchor_attempt,upkeep`，已满足的真实步骤跳过，不以跳过重发奖励。选择路线时记录route_id及现存来源；同节点材料失败后仍按原episode/outcome规则保留失败事实，真正下一次活动遵守冷却与实际输入；旧PR12失败卡不会因换路线重开。更换材料路线保持同goal/cycle，不能洗债；成功锚定绑定分支及改绑费用见文明§9.6。`upkeep`只在当轮实际结算后完成，未支付时是未完成目标，不用“材料已齐”记胜利。

终局两路**共用同一物理终点与检定，但各自有非空的进展取得行为**：ANCHOR恢复真实锚点贡献，WOUNDS减少真实创伤。已经合格时原POWER_MANIFEST仍可直接开始，不强制先受伤或停供，但这个共同便捷入口不计作另一条路线。两路都保留原A门槛、当前有效宇宙/星系锚、固定护持者、两域F、人物机会、开始/持续费用、三轮公开暴露、维护及最终检定；无事件邀请或独占仪式人物门槛。

ANCHOR的当前输入是原绑定完整、因实际停供而dormant的额外非仪式锚及真实停供来源；两座拟用于降临的宇宙/星系锚须已active。若额外锚是材料丢失、换护持者/圣物或被毁，本条恢复供奉路径不能代替POWER_ANCHOR修复。正式入口绑定现有`Session.set_plan(plan) -> Turn set_plan(participant=economy,payload)`，稳定entry_id记为`SESSION_SET_ECONOMY_PLAN`，payload为原`{strategies,anchor_priority,refuse_anchors}`，不是新免费激活操作。玩家只撤去目标额外锚的拒付，保留其他真实计划与两仪式锚的维护，必要时显式安排优先级；省略anchor_priority中的锚不会拒付，因为原预览会补齐所有锚。

该step的纯预览须读**完整经济结果中的目标行**：目标真实eligibility成立、`reason==""`、实际fee可支付，且两仪式锚的维护行也可实付；不能只读`preview.ok=true`，它可能包含insufficient_faith行。仅按当前faith及当前完整计划推导，不预借阶段五收入。当前计划已经打算支付的额外锚不再提供一份“改计划”空动作，等待其本次实际结算；玩家改变计划/花掉资金属于真实后续选择，不能保证付款。Session保存计划只改变plans，end_actions后原T演化预付生成economy_anchor_payment时的`paid_pending_final_check`也不是恢复证明。须等同轮Economy.finalize核实际已付与真实eligibility设active、World随后刷新A；付款事实、finalize后的实际状态及该轮事务回执联合核验后才算这步进展。最早T+1 actions经历due/events再次重查后可开始降临，不在T保存计划时借出未来贡献。

WOUNDS的每步起点可计算：令`B=初生自我+当前洞见+当前有效锚点贡献`，`W=当前真实创伤`，`G=原manifest_requirement`。仅在当前A<G、W>0且`min(B,awakening_before_final_cap)>=G`时登记`recover_wounds`缺口；若真实锚点不足导致B<G，不伪称“继续敛息总会成功”。每次REST仍检查原可执行条件与原信仰费用；由确定恢复量推导所需完整轮数`ceil(max(0,W-(B-G))/rest_wound_recovery)`仅是锚点/创伤不再变化且持续支付时的操作次数，不保证世界停表。REST实际写economy_rest并结束actions；下一轮经过due/events重查后，真实A达标才进入manifest_start。空等、没有创伤、提前用于其他行动的一轮均不能记一次恢复。

**同一起点的移除路线见证。** 静态取当前A=87、真实W=6、未减创伤前B=93，两仪式锚已active；另有一座非仪式星球锚因真实拒付休眠，当前材料与绑定均合格。B可由原初生10、洞见20、真实有效贡献63组成；63的类型预算见证为2座宇宙、5座星系、2座星球锚，另1座休眠星球锚，共10个护持身份，未超过原N=12。具体实现测试仍必须建立各自合法材料/绑定/来源，不能只写这些数值。原CSV的planet贡献4、rest恢复3、G=90使两条不同因果链成立：保留额外锚显式在refuse_anchors、真正REST一次，A从87到90；或完全不REST、只撤该锚拒付并实际供奉恢复4贡献，A从87到91。两见证均维护原两仪式锚、保留其他计划，初始真实资金足够各项实际支出，且最早下一actions重新满足原开始费用/两域F/人物资格。不是换初态，也不是把计划当事实；关闭任一独有动作/来源后另一链仍可达。运行样本可能遭遇真实世界中断，这属于风险测试，不可在验收时偷偷清除后果。

GOAL_MANIFEST的steps为`restore_upkeep`（仅ANCHOR）或`recover_wounds`（仅WOUNDS），之后共用`manifest_start,manifest_continue`。已合格局面直接从共同start开始，不增加route计数或领取两次机会。恢复来源真实成立后，当前缺口变化沿同goal/cycle记录；持续step绑定现有仪式source/固定两锚与主体，三轮中断不重抽目标。一次恢复、start或continue服务只解决该次可行动机会，不完成GOAL_MANIFEST；完成唯一消费实际终局成功。每轮成本、既有攻击、锚点供奉及寂灭优先仍按§7–8；不能按上轮好状态无视本轮失效。失败若保留现实前提可沿原规则再次争取，不可逆损失则记录当前不足，没有保胜利路线。
下游必须用正式Turn/Session证明六条路径的实际入口、代价与服务，并在每目标关闭一条独有路径后保留另一条的合法完整流程。固定成功种子仅可用于确定性行为检查，必须另测失败/灾变、中途材料/人物/通信失效、存读档、队列/池已满与F容量不足；不得用直接注入axiom_record、network_dependency、创伤清零或锚点active通过。来源闭合验收仍保留全部原十二类自然生产职责，主动替代不能掩盖未实现的自然来源。新增玩家入口/依据分支的视觉与交互验收由各实施任务按原in-game-ux流程完成；本批不修改界面。

### 12.2 TASK-FOUNDATION-ROUTES-DESIGN — First Cult, Isolated Character, Record, and Ritual Route Design：八条完整因果链（设计待实施）

事件§14.11及文明§9.7定义下面八路。formal CSV的`delivery_bound=0`只给已经满足真实输入、已安装且在当前actions可执行的下一步，不给整个目标承诺零等待/成功。所有七新操作仍未实现；既有六路/五操作不变。首领、实际角色/知晓、匿名人口、实际槽/通路、F/N/P和资源是具体物理前提，清单不生成它们。独立材料与连续实践分开，不能为凑路线把同一次成功换名计两次。

| route | 真实起点、顺序与完成 | 移除另一独有来源后为何仍可达 |
| --- | --- | --- |
| ROUTE_FIRST_CULT_GATHERING | 首领候选真实active且知晓、忠诚≥40，经PR08已bound，或经当前实际私祷完成自愿N准入；其机构真实存在。本人组织秘密集会，每次当前原池最多三人、真实支付4，成功累积实际无名信众。直到原六人/八本域实付/合格领袖同时满足，原Cults轮末真实cult_established才完成。 | 无ritual_keeper、无PR05/新祭仪也可组织；不用已有cult/cell或旧亲属。缺少六名真实人口则不能声明有路。 |
| ROUTE_FIRST_CULT_RITES | 真实ritual_keeper及有仪式能力的本地结构；该人同样必须真实知晓、忠诚≥40并合法自愿绑定。实际主持新Calendar Rite，不先等PR05成功；每次支付4并最多转化三位真实参加者。两次标准成功、六名原非信众与八实际支出后由原Cults成立；已有真实PR05收益可补缺，但不是这条主动链的前提。 | 禁止Covert Gathering/所有cell招募仍可从实际祭仪参加者凝聚。普通bootstrap记录者没有祭司资格，不能因此被改职业；无实际祭仪者时本路物理条件不在。 |
| ROUTE_CIV01_TESTIMONIES | 两名不同真实成员分别在不同实际回合通过原Guided Dream受梦成功，或既有合法不同异常原证据；其真实机构/最小carrier符合record_testimonies。产生实际basis→原一次遗物机会及合法回收/已有媒介→原POWER_ANCHOR成功与供奉。 | 不使用Record Practice或同人依赖；两人同一梦的转述不够。 |
| ROUTE_CIV01_PRACTICE | 一位真实record_keeper成员实际Record Practice首次成功产生series/use，再按原冷却于后来回合重新实际读写成功；同一series的两轮use形成record_dependency。其后走同一共同锚定尾段。 | 不需要第二人物/第二机构/PR04或两独立证言；不能把这两轮使用冒充两个原见证。 |
| ROUTE_CIV02_RITES | 真实祭仪者同一结构两个不同回合实际Calendar Rite成功；原PR05真实成功可按同一发生核参与，包装不多算。形成calendar_rites后走共同尾段。 | 没有record_keeper/Calendar Keeping仍有真实祭仪路。不是两次对同一旧祭日应答。 |
| ROUTE_CIV02_KEEPING | 有当前仪式/历法能力的结构及真实record_keeper成员；其实际Calendar Keeping两次成功、不同回合使用同一超常节拍完成周期活动，得到calendar_dependency后走共同尾段。 | 不需要PR05或ritual_keeper主持；普通日历记录不带神迹，不能用它绕过实际两次超常结果。 |
| ROUTE_CIV04_KEEPER | 真实祭仪者在实际结构一次Calendar Rite成功（或原合格PR05），仍实际承续其performed_rite；ritual_keeper分支后走共同尾段。 | 无教师/学徒/教习事实仍可由原实际祭仪者主持，不需官方许可。 |
| ROUTE_CIV04_PRACTICE | bound学徒与真实老师有当前support/cooperation；若孤立，可先实际Joint Work取得边。老师当下teach成功，后来回合学徒亲自perform成功，新的practiced_rite形成ritual_practice；老师无需有此前成功PR05。其后走共同尾段。 | 禁止PR05及Calendar Rite依然可真实教习并由学徒得到新的超常实践。已有普通lesson但未亲自perform不算；复制旧祭仪和换carrier不算。 |

**共同尾段与物理前提。** 三种文明的每条路线都须真实教团、污染序号、十二信众、凝聚四十、真实护持者/媒介及POWER_ANCHOR的原费用/检定；不足污染/人数仍只能通过已经合法的现有实际活动继续争取，不赠资源。六材料链本身不要求先有锚点/圣物，因此可以先形成basis产生原一次遗物机会，合法回收后再锚定；机会已消费/媒介已丢失则按实际剩余媒介处理，不能重抽。成功建锚后当轮真实维护才使目标active；否则只是结构/休眠，不完成目标。自然源和主动操作的材料都经同一分支判定，不另发第二份资格或遗物。

首领取得不是首团目标的完成事件。两个组织分支的共同领袖资格不绑定于一次bootstrap：原PR08真实接受与“合法固定联系内真实Dream达到忠诚/知晓→本次自愿私祷”都可取得；后者仍受Dream原当下联系、T+1冷却及原due。bootstrap忠诚15，两次普通成功只到35，不够私祷；T1/T3例只有至少一次深成或另有真实忠诚来源才达40。缺当前联系/知晓/意愿时，不得用本表调用Dream或私祷，等待债务也不续命。

同一合法局面的移除验证应先通过真实流程取得一个知晓且合格的记录者与一个合格祭仪者、原池至少六人和足够当前资金；禁用集会时只用祭仪形成首团，禁用祭仪时只用集会形成同一个真实目标。不是每局强配这两角色。三种锚材分别在同一合法测试世界关闭一项独有操作/生产者验证另一条，不能通过注入dependency/ritual、伪造老师职业/知晓或清除原抵抗过关。独立行为测试需要真实失败/灾变、途中死亡/迁移、人口不足、池满、F/N满和保存恢复反例；静态推导不代替这些行为证据。

机会缺口steps：首团为`leader_contact,voluntary_membership,form_followers,local_spend,cult_settlement`中当前仍缺者（实际操作可能同时解决人数/实付，但不会记两次服务）；各锚材为`current_social_contact`（仅需要时）、`material_first,material_repeat_or_perform,basis,medium,anchor_build,anchor_upkeep`。没有先决角色/通路时必须显式报当前物理缺口，不注册假可服务step。每次服务只对应实际可执行的当前动作，不能把一次私祷、教习、use或遗物提示标为成团/锚点已active。已选择的series/lesson/人物绑定step和episode，失败不换人/旧源重抽；按当前资格与真实发生开始新episode，仍保留同目标等待史。

孤立bootstrap人物的合法入口只改变现在：真实Joint Work以双方真实共同need及同机构或实际双向机构通路约束会面，真实成功后才生成cooperation。它不要求先有教团，也不把初态cohort重跑到这个旧人物身上；未认识邪神的peer不会因此自动识别。私祷的有限自愿规则见事件§14.11，bound者可每次在当前真实条件满足时实际再祈求，每次耗低语/机会并产生新的当前活动。Endings只复用下一窗口当前合法prepare；旧已消费祷告和member标记本身不是联系。非零信仰的材料/组织动作也不能假装零信仰，三轮断联继续真实可发生。

实现责任由本批五个已登记子任务、原Core、原锚点消费者/生命周期、调度与保存共同承担。UI设计/集成尚未发生；无正式玩家入口时不可注册active路线。本组八路与§12.1、§12.3合成的十目标二十路由父`TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees`在§12.4独立汇总；本组范围不扩大为其他组的实施或行为证据。

### 12.3 TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design：六条因果链（设计待实施）

本批只完成CIV03/06/08的路线合同；完整生产、受控行为、自然新局及父任务全表汇总未由本批完成。新增入口/参数/材料以事件§14.12、文明§9.8和原路线CSV追加行为准；原14路/12操作/1源不改。L=0仍是当前缺口已安装且当前可行动的直接入口，绝不是零资源/零轮完成锚点或保证成功。新操作不等B/A/固定卡分页，也不取消原PR06/07的自然来源职责。

| route | 从真实输入到材料的完整行动链 | 移除另一独有路径后的独立性 |
| --- | --- | --- |
| ROUTE_CIV03_CIRCLE | 已知真实record的解释机构host及三名当前实际关系人；MEMORY_CIRCLE/convene实际读取/逐人登记/机构受理本次审查并固定due→后来原窗口内preserve成功→三人真实资格及memory_circle basis。原合格PR07结果也可沿同一分支消费。 | 不用两人跨轮recollection_dependency；没有Memory Practice仍可通过真实登记/审查保护三人。四个总参加者恰为原人数上限，不偷减成三人总数。 |
| ROUTE_CIV03_PRACTICE | 真实两人、接触/结构与一份host确知的record；Memory Practice第一实际成功形成本次共同见闻/逐人实践登记和回声→原冷却后两人亲自再次使共同回忆出现→两轮recollection_dependency及memory_practice basis。 | 不用三位非host关系人、不等PR07/审查窗口，也不借一个人抄三份材料；它有自己的两活人和持续实践条件。 |
| ROUTE_CIV06_PERFORMANCE | 两真实当事人及actor确知的record/当前接触；Pact Agreement实际宣读/约定在固定结构保管该记录，写原due→后来期限内Pact Performance真实神迹保管/履约、两端见证/知情→contract_performance basis。原PR06深成功可沿此分支；浅履约不够。新依赖只收preserve_record，不接受互惠deliver_record任一单腿。 | 不要求两个结构互换两份记录、互惠另一腿或Reciprocal Covenant。不存在约定就不能跳到履约。 |
| ROUTE_CIV06_RECIPROCAL | 两真实成员各有不同记录、不同双向连通结构、当前真实接触及对方结构确缺该记录保管端点；Reciprocal/agree固定两腿/原due→两端在之后不同回合各实际交付并以神迹履约→两腿均有保管/依赖/见证后形成reciprocal_dependency及contract_reciprocal basis。 | 不用Pact Agreement/Performance或PR06的单向preserve_record链；本路两份deliver_record有各自真实效果，不是给一份旧契约换名或复制一个依赖。 |
| ROUTE_CIV08_CIRCLE | 同CIRCLE真实前置/本次审查、后来成功保护三份原个人资格并产生实际冲突来源→保留三名历史见证、锚当前至少两活的dissent_circle basis。强化仍需原三活，不能借锚阈值放低。 | 不用新的双视角实践，原三人记忆路径仍完整；无第三人时本路确实不具备物理输入。 |
| ROUTE_CIV08_PRACTICE | 两真实有接触的人在结构内当下共同经历同一印记的相斥视角，各陈述/登记→原冷却后两人亲自让各自原视角再出现→完整dissent_dependency及dissent_practice basis。 | 不要求第三人、PR07或原review；两人当前都须活且资格在，任失一人即失效，不能伪装旧三人历史/两人生存例外。 |

每条材料链后仍有同一真实锚点尾段：实际basis→原每槽一次遗物机会或已有合法媒介→真实回收/携带/绑定资格→原POWER_ANCHOR成功→当轮实际维护使锚点active。共同教团、污染序号、十二信众、凝聚四十、护持者、圣物和成本/检定不变；材料不足不会用数字补偿创建，材料形成也不直接活化锚点。六路不先要求物理锚点或圣物，因此没有先锚后材循环。遗物机会已消费且没有其他真实媒介时仍是当前缺口，不重领一次机会。

有限时间/成本演算：CIRCLE在T convene实付1，T+1仍合法时preserve实付4，原due=T+3不改；成本合计5仅是一次前置加一次成功尝试，不保证成功。双人实践两次深干预成本8且cooldown1，最快T/T+2真实两轮，期间私人知识不自动获另一轮use。单向契约T agree实付1，T+1履约实付4；互惠T agree实付1，T+1一腿（此时单向和互惠两个分支都未成立）和T+2另一腿各实付4，总9，均在原T+3期限内；两次使用同一人的机会不能压成同一轮。资金、低语、F/N/P、真实人物/角色/源都须每次当前满足；延期、收入预测或假定必成功不能用来证明这些演算可行。

目标steps按实际当前缺口划分：记忆`current_contact,convene_or_first_practice,preserve_or_repeat,basis,medium,anchor_build,anchor_upkeep`；契约`current_contact,agreement,perform_or_first_leg,second_leg`（仅互惠）、共同锚定尾段。不需某一步时直接从真实当前缺口开始，未约定不能把后继履约标可执行；登记/一腿/use只服务它本次step，不完成GOAL_ANCHOR。后继episode锁同review/series/covenant/人物/原due，失败后不改人重抽，不丢同目标等待债；已不可能在原due内完成的本次合同明确结束/承受后果，新约定须以后真的再次达成。

同一合法测试世界分别禁用一项独有生产/操作后，另一条应能通过真实正式流程取得本目标；不得用注入memory_preserved、私改registration、预造fulfilled/dependency或重写原due替代。跨机构参与、未参加/未登记反例、记忆资格与私人知识分开、根关闭与解除依赖分开、单腿失败/到期和材料丢失都必须覆盖。自然B当前缺失的记忆/约定生产仍由原来源任务完成；新增主动路径不能让缺失的声明特性被掩盖。

四个新实施/接口任务和原Core/来源内核/锚点/调度/保存分别承接；当前尚无新正式按钮或行为证据。原继承生产缺口由`TASK-CONTRACT-SUCCESSION-DESIGN — Contract Succession Resolution Design`与来源实现承接，本六路没有使用一位尚未合法产生的继承者。父`TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees`在§12.4独立汇总二十路、八蓝本说明一致性及实施接口；本组六路不自动证明父ACC、全表实际安装或自然供给保障。

### 12.4 TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees：十目标二十路线统一合同（设计待实施）

本节汇总§12.1–12.3，不新增路线、操作、参数或成功保证。目标注册表为十行、路线注册表为二十行、操作注册表为十八行、自然来源扩展为一行；均保留`design_only`。各自精确payload、真实发生与事实schema、知情/资格、冷却及失效仍唯一由事件§14.10–14.12和文明§9.6–9.8定义。`civilization_conditions.csv`八行说明与禁令、`civilization_profiles.csv`的entry_route/spread_route/anchor_route描述列已与这些分支同步；这不替代机器规则，也不改变蓝本属性、机构类型、身份、反制、原费用或数值阈值。旧组报告因来源变化须当前独立复核，不能直接沿用旧通过标记。

#### 共同物理条件、路线差异与终点

首次教团只在原Cults真实结算`cult_established`时完成：合格具名领袖忠诚至少40、实际本域支出至少8、至少6无名信众及原成员准入。成员不是教团，人数来自原非信众池，实际支付不是计划或虚构献祭。两路线共用这些条件，独有行为分别是秘密集会和真实祭仪；祭仪者不是普通bootstrap记录者自动取得的职业。

八蓝本目标各绑定真实机构槽、当前profile与原rule。材料分支可替代，真实教团、机构序号对应污染门槛、12无名信众、凝聚40、护持者、合法圣物、当前实际承载、原锚定检定及实付供奉是共同条件。下表“锚定尾段”统一指：本分支材料形成真实basis→原每槽一次遗物机会及实际回收或已有合法媒介→`POWER_ANCHOR`真实成功→当轮实际维护使锚点active。材料生产不先要求圣物/物理锚点；机会已消费且无剩余媒介时是实际缺口，不重发。每次锚定尝试原费3低语/12信仰，当轮维护另计；锚定失败/灾变与后续破坏可能阻止完成。换分支不是免费修复，身份、序号和一次遗物消费不重置。

终局仍是原三轮降临及最终检定真实成功。两路线只在同一类合法A不足局面中提供不同取得行为：恢复额外非仪式锚的真实贡献，或实际敛息降低创伤。已达标直接开始是共同入口，不算第三路，也不要求玩家故意受伤/停供。原开始5低语/20信仰、其后两轮各3低语/8信仰、两座仪式锚及两域F、固定主体、实际维护、公开暴露、最终失败/灾变不变；36信仰仅是一次未中断仪式的原行动费，不包含恢复与各轮供奉。

所有新活动均按各操作真实前提核F/N/P、当前资源、人物机会及实际知识；新多人活动逐人预留/标记机会，旧祈求响应仍按原response/Attention语义，不宣称已经自动逐人标记。无需“所有人都认识邪神”或“机构批准邪神”共同门槛；各操作有自己的成员、实际知晓或亲历要求。正向关系不赋知识，材料递交不授原见证/作者/使用者/实践者身份。共同世界前提被删除不属于“禁用一路”的测试。

#### 二十条完整路线索引

“材料行动费”仅累计表列最少成功流程的原低语/信仰支出；失败重试、共同接触、成员取得、锚定尾段、维护另计，不是平均预算或必胜报价。风险索引A/N/C/R/T/M/K及业务/UI责任见随后两表。每行的`direct_action / 0`都只适用于**已安装且当前输入齐备的下一步**；从当前actions授权投影到实际入口无额外随机队列，整条跨轮路线、成功结果及目标完成没有0轮保证。

| 目标 / route ID | 本路真实输入与独有行为 | 输出与共同尾段 | 材料行动费与责任索引 |
| --- | --- | --- | --- |
| GOAL_FIRST_CULT / ROUTE_FIRST_CULT_GATHERING | 真实知晓且忠诚40的成员；实际组织Covert Gathering；原非信众池合计至少6人 | 两次标准成功各转实际至多3人、实付累计8；原Cults成团 | 4低语/8信仰；需要时Private Devotion另1低语/0信仰；C |
| GOAL_FIRST_CULT / ROUTE_FIRST_CULT_RITES | 真实合格ritual_keeper和仪式结构；实际Calendar Rite不先要PR05 | 两次标准成功各转实际至多3人、实付累计8；原Cults成团 | 4低语/8信仰；私祷如需另计；T |
| GOAL_ANCHOR_CIV01 / ROUTE_CIV01_TESTIMONIES | 两不同实际成员分别在不同回合真实Guided Dream；不需Record Practice | 两独立原神迹及原见证/实际carrier→record_testimonies→锚定尾段 | 2低语/4信仰；N |
| GOAL_ANCHOR_CIV01 / ROUTE_CIV01_PRACTICE | 一位真实record_keeper在两不同成功回合读写同一反常series；不需第二人 | record_dependency及原实际操作者→锚定尾段 | 4低语/8信仰；cooldown=1；R |
| GOAL_ANCHOR_CIV02 / ROUTE_CIV02_RITES | 同一真实祭仪者在同结构两个不同回合主持Calendar Rite；不需记录者 | 两原祭仪及实际承续者→calendar_rites→锚定尾段 | 4低语/8信仰；T |
| GOAL_ANCHOR_CIV02 / ROUTE_CIV02_KEEPING | 仪式/历法结构的真实record_keeper两轮实际使用超常节拍；不需PR05/祭司 | calendar_dependency及原操作者→锚定尾段 | 4低语/8信仰；cooldown=1；T |
| GOAL_ANCHOR_CIV03 / ROUTE_CIV03_CIRCLE | 确知真实record的解释机构host及3位实际关系人；convene实际读取登记并受理审查→原due内后来preserve | 同一见闻/review的3位原参加者当前有效资格→memory_circle→锚定尾段 | 3低语/5信仰；共4人；M |
| GOAL_ANCHOR_CIV03 / ROUTE_CIV03_PRACTICE | 两实际参加者、当前接触和一份真实record；两轮亲自再现共同回忆；不需第3人/审查 | 两人实际登记/使用及recollection_dependency→memory_practice→锚定尾段 | 4低语/8信仰；cooldown=1；M |
| GOAL_ANCHOR_CIV04 / ROUTE_CIV04_KEEPER | 真实ritual_keeper当下成功主持Calendar Rite；不需学徒/教习 | performed_rite及原祭仪者→ritual_keeper→锚定尾段 | 2低语/4信仰；T |
| GOAL_ANCHOR_CIV04 / ROUTE_CIV04_PRACTICE | 当前有support/cooperation的真实老师和学徒；实际teach后另一回合perform；不需既存成功祭仪 | lesson后原学徒亲自获得practiced_rite→ritual_practice→锚定尾段 | 4低语/8信仰；如需Joint Work另1低语/1信仰；T+C |
| GOAL_ANCHOR_CIV05 / ROUTE_CIV05_DREAMS | 两连通槽不同真实成员分别受梦；不需Network Exchange | 两独立miracle、两原见证及当前通信→network_independent→锚定尾段 | 2低语/4信仰；N |
| GOAL_ANCHOR_CIV05 / ROUTE_CIV05_EXCHANGE | 两连通槽真实成员当下发送、接收、回送异常读数；不需梦境 | 两真实endpoint使用及同一network_dependency→network_exchange→锚定尾段；不算两独立根 | 2低语/4信仰；两人实际机会/理智；N |
| GOAL_ANCHOR_CIV06 / ROUTE_CIV06_PERFORMANCE | 真实两端/记录/接触；Pact Agreement固定preserve_record义务→后来原due内实际神迹保管履约 | 原contract_obligation对应完整单向依赖及两端见证→contract_performance→锚定尾段；原合格PR06深结果可沿原支 | 3低语/5信仰；K |
| GOAL_ANCHOR_CIV06 / ROUTE_CIV06_RECIPROCAL | 不同结构的两成员各确知不同canonical原根记录；固定两deliver_record条款→两端分轮实际交付 | 两腿真实custody/依赖/见证齐备→contract_reciprocal→锚定尾段；任何单腿不能借单向分支 | 5低语/9信仰；K |
| GOAL_ANCHOR_CIV07 / ROUTE_CIV07_NODES | 本槽真实Probe；另一连通槽的不同人对同一稳定exception/probe实际Recheck；不需REPEAT | 不同真实observation支持两独立记录→axiom_nodes→锚定尾段；自然独立求告另沿真实观察绑定 | 4低语/8信仰；A |
| GOAL_ANCHOR_CIV07 / ROUTE_CIV07_ARCHIVE | 本槽真实Probe；同一例外两个不同回合实际Repeat；不需另一槽/通信/观察者 | 同一真实操作者两use形成axiom_dependency→axiom_archive→锚定尾段 | 6低语/12信仰；Repeat cooldown=1；A |
| GOAL_ANCHOR_CIV08 / ROUTE_CIV08_CIRCLE | 同CIRCLE真实读取/登记/审查，保护三份资格并形成冲突 | 原3人历史、锚点至少原2人当前活且合格→dissent_circle→锚定尾段；强化仍3活 | 3低语/5信仰；共4人；M |
| GOAL_ANCHOR_CIV08 / ROUTE_CIV08_PRACTICE | 两真实参加者经历相斥视角，后来各自使原视角再次出现；不需第三人/PR07/review | 两人登记和两轮dissent_dependency→dissent_practice→锚定尾段；两人均须当前合格 | 4低语/8信仰；cooldown=1；M |
| GOAL_MANIFEST / ROUTE_MANIFEST_ANCHOR | 两仪式锚已active；额外非仪式锚只因停供休眠且贡献足以补A缺口；真实改供奉计划并实付 | finalize与World实际贡献恢复；下一actions重查→原开始/持续/终局成功 | 目标及其他维护行实际费；后续仪式另计；E |
| GOAL_MANIFEST / ROUTE_MANIFEST_WOUNDS | 两仪式锚已active；有真实创伤且去掉创伤后现有贡献足以达到原门槛；真实REST | 每次恢复原3创伤并结束actions；下一actions重查→原开始/持续/终局成功 | 每次原REST 6信仰及整个行动窗口；后续仪式另计；E |

自然PR04/05/06/07/12的合格结果仍可贡献各自原材料；它们不增加本表路线数，也不取代必须实现的自然原根职责。PR12深传、公开/私下包装和材料递交均不能产生第二次实际观察。单节点CIV07的两轮实际使用是另一种依托，不宣称它满足双节点独立性。CIV01双见证强化传播仍沿原规则不另要求不同回合；只有锚定双见证及各两轮实践分支要求其明示轮次。所有分支原人数、亲历、有效知识与当前carrier分别核，不取全表最宽门槛。

#### 费用风险与唯一实施、界面责任

以下风险读原操作CSV，不新增调参：A的三试验与N的Exchange每次成功污染+2、每次始终察觉+5及每位参加者理智−2；Guided Dream完全用原POWER_DREAM四档结果。C的私祷确定性且不增污染/察觉/理智损失，共同工作按社会检定且不产神迹，集会成功污染+1、始终察觉+2。R的Record Practice及T的Calendar Keeping每次成功污染+2、始终察觉+2、每位理智−2；T的Rite/Transmission改为始终察觉+4，其他同原表。M的Circle保留阶段、Memory Practice、Dissent Practice分别始终察觉+8/+4/+6及每位理智−3/−2/−3，超常成功均污染+2；Circle准备阶段不收这些超常结果费用。K的准备阶段确定性且无超常污染/理智费，实际履约每次成功污染+2、始终察觉+4、每位理智−2。随机失败付实际成本且不产成功材料，灾变附加仍沿原规则对主体及本域一次结算。E另有世界演化、供奉失败、中断与原终局创伤/休眠风险。费用齐备不证明检定成功。

| 责任索引 / 操作范围 | 唯一业务实现或既有结算责任 | 正式界面设计 → 接线责任 |
| --- | --- | --- |
| A / Probe、Recheck、Repeat | TASK-AXIOM-OPERATIONS — Axiom Trial Operations；观测/例外内核由TASK-SOURCE-EXCEPTION — Current Anomaly Observation Sources独占 | TASK-PROGRESSION-INTERFACE-DESIGN — Progression Route Operation Interface Design → TASK-PROGRESSION-OPERATION-UI — Progression Route Operation Interface Integration |
| N / Guided Dream、Network Exchange | TASK-NETWORK-OPERATIONS — Network Trial Operations；Dream结果仍调用原Powers | 同上两项Progression接口任务；复用到CIV01时不造第二套Dream入口 |
| C / Private Devotion、Joint Work、Covert Gathering | TASK-FOUNDATION-CONTACT-OPERATIONS — Present Contact and First Cult Gathering Operations；分别调用原Cults、World关系/人口及Endings共同prepare | TASK-FOUNDATION-INTERFACE-DESIGN — Foundation Route Operation Interface Design → TASK-FOUNDATION-OPERATION-UI — Foundation Route Operation Interface Integration |
| R / Record Practice | TASK-FOUNDATION-RECORD-OPERATIONS — Record Practice Operations | 同上两项Foundation接口任务 |
| T / Calendar Rite、Calendar Keeping、Ritual Transmission | TASK-FOUNDATION-RITUAL-OPERATIONS — Calendar and Ritual Practice Operations | 同上两项Foundation接口任务 |
| M / Memory Circle、Memory Practice、Dissent Practice | TASK-MEMORY-OPERATIONS — Shared Memory and Dissent Operations；读取/登记/审查内核由TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources独占 | TASK-MEMORY-CONTRACT-INTERFACE-DESIGN — Memory and Contract Route Interface Design → TASK-MEMORY-CONTRACT-OPERATION-UI — Memory and Contract Route Interface Integration |
| K / Pact Agreement、Pact Performance、Reciprocal Covenant | TASK-CONTRACT-OPERATIONS — Agreement and Contract Practice Operations；约定/义务/实际保管履行内核由TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources独占 | 同上两项Memory and Contract接口任务 |
| E / 供奉恢复、REST、降临开始与持续 | 复用原Economy/Turn的实际计划、支付、敛息（TASK-ECONOMY既有业务）及Powers/Endings（TASK-ENDINGS既有业务）；TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration接当前basis和实际锚贡献刷新。调度只登记机会，不能生产供奉或创伤结果 | 复用正式Session内建入口；两项Progression接口任务负责路线适配/授权投影，既有功能不重复实现 |

共享协议唯一归`TASK-PROGRESSION-OPERATION-CORE — Progression Route Operation Core`；十八业务操作不能各建支付/随机/知识/关系writer。观测来源扩展表由其来源任务先安装，Core加载路线/操作/对应参数，读取来源内核，不形成Source反依Core的安装环。完整业务与正式Session入口汇总归`TASK-PROGRESSION-OPERATIONS — Progression Route Operations`，缺任何当前必需处理者须拒绝注册，不能用空成功handler通过。

八蓝本材料与强化传播共用判定归`TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation`，真实首团完成归`TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration`的原Cults结算，生命周期归上述唯一任务。材料递交边界先由`TASK-MATERIAL-TRANSFER-DESIGN — Material Recipient Scope and Finite Transfer Contract Design`冻结矩阵，再由`TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts`实现；本表不用尚未落实的转交来替代原参加者持有，因此不等待一位虚构carrier。继承生产仍由已登记继承设计与来源任务补齐，本表六条记忆契约路线没有借用未生产的继承人。

#### 当前一步的实际交付界与原等待合同

二十行均采用直接入口。当前步骤的真实生产输入齐备、处理者/事务/授权投影已安装后，Turn在事件结算完毕实际进入actions时与Session共用同一纯prepare，给出明确可执行入口及至少一个覆盖完整行动窗的合法分支，故**本步额外队列界L=0**。它不等待B抽中、A固化、8请求池或3卡分页；界面必须按当前目标/成员提供实际入口，不能藏在前三条随机推荐后。当前actions中途新增条件只可在真实授权提交时记录服务，或等下一完整窗口；未安装、不可见、支付或机会检查不同步是`missing_delivery_contract`，不是世界缺前提。服务回执不由预览写入。

跨轮间隔仍真实存在：cooldown1最早T+2再用，教习/保护/履约必须后来实际回合；review/约定原due=T+3不延。实际支付恢复锚点和REST都最早下一actions重新检查降临，保存计划或paid_pending_final_check不是完成。一个成功use、首腿、教习、一次私祷、遗物提示或仪式开始不完成整个goal；step/episode/同一机构目标键及后续恢复周期沿事件§14.8。玩家明确拒绝、未使用、实际失败和短时失格分别记录；换路、模式切换或保存不能洗债或重抽原call。

共享B合同继续独立存在：实例上界38、单域竞争上界5、原4轮槽、2次漏选后FIFO，使持续合法且有真实交付证书的step在最坏随机序列中至多28轮获一次B派发；实际服务须再加其已证明的L。权重增长本身不是保证。前方票实际派发后消耗，失败重试领队尾票且保留服务债；提交前正常失格按≤Q有界扫描跳过而不追加随机、不占掉唯一真实生产槽。A轮不到、分页漏读、告知竞争不是暂停理由。该B公式**不转换为本二十直接路线的28轮完成承诺**，也不声明自然PR管线已有有限L；自然B/A/固定池/展示后的保障须实际安装其证明或提供本表适用的直接替代。

资源/容量/世界条件确缺时记录具体来源、墙钟和未服务债；有其他合法路径/促成步骤时不得把整个目标暂停。没有确定释放时点的永久容量占用没有无条件日历保证，供给资格不能要求待产卡/根已经出现来藏随机缺失。断联仍按原三轮：只读真实下一窗合法私祷/原接触或有源确定计划，不按目标待办、已知人、旧祷告或等待债续命。成功、世界保持不变、整局获胜及节奏好玩均未被承诺。

#### 父任务五项断言与后续证据

| 原ACC断言 | 本次设计汇总的可核对落点 | 正式实施后必须保留的可否证检查 |
| --- | --- | --- |
| 每目标两路、独有输入不同且有玩家促成 | 上表20行与注册表逐ID一致，费用/责任逐行可追溯；各子节保留禁一路见证 | 同一合法世界逐目标关闭独有操作/来源，另一路经正式入口到真实目标；不得删共同物理条件或注入目标材料 |
| CIV07真实第二复核及替代 | 事件§14.10.2的稳定exception/probe和独立observation/call；单节点两轮实际档案使用 | 复制、递交、PR12深传不得冒充第二观察；禁RECHECK仍可单槽使用，禁REPEAT仍可真实双节点 |
| 等待/容量/公平/复位与CSV理由 | 事件§14.8和本节直接入口边界；全部数值仍来自原正式CSV及其理由 | 实际Session可见可行动；恶劣抽样/票失败/提交前失格/分页/满池/原due/保存；缺安装或L违约必须失败 |
| 孤立人物有当前合法促成 | 事件§14.11的Joint Work及C责任；真实共同need、无当前敌对、同机构或双向links、原支付/机会 | 未bound actor、无共同need/通路时拒绝；成功才新增当前cooperation；不补旧亲属/知识/职业；私祷与三轮断联一致 |
| 八蓝本说明与原分支一致且前置新核 | 两描述CSV及文明§9.6–9.8；能力统一progression_routes/3和civilization_dependency/schema2/routes3 | 逐分支人数/存活/不同轮/原作者/当前carrier/单腿禁令；旧描述不作运行规则；过期子报告须独立重核，不改历史签名 |

当前state总schema为3，但各事实schema、社会图、机会policy和观测来源版本保持其各自正式值，不能一律改3。版本/能力/内容、合法原来源与当前头必须整体接线，旧档不猜route或补过去。`TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility`验完整Session；`TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure`验真实生产到目标及禁一路替代；`TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler`唯一写等待/服务而不代造业务；`TASK-NATURAL-VERIFY — Correction Chain Independent Verification`分别报告自然新局与受控最坏序列。原十二类自然来源、真实继承生产缺口、游戏UI设计/实现与自然节奏仍有各自任务，本父设计汇总不将其关闭。
