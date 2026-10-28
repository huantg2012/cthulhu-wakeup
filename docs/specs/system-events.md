---
status: PROPOSED
created-by: director
last-modified-by: design
last-modified-date: 2026-10-28
interface-changed: true
interfaces-with: [system-turn-economy, system-powers-cults, system-progression, system-civilizations]
exposes: [正式十二事件与二十四分支, 原计划到期事件交接, 锚前遗物处置, 到期概率身份仲裁, 祈求候选, 可执行回应, 事件队列, 已发生事实, 因果编年史, 对象失效处理, 多前因事实与知情范围, 唯一结果消费键, 固定候选与主体预留, 背景生成来源与危机期限, 正式祈求情境与回应效果, 请求窗口与原危机分离, 可选秘密合作渠道, schema2实际依托机会消费, 两类求告与有源身份知晓, 有限原根生产及单一候选职责]
---

TL;DR：祈求来自有身份和处境的具体人物，事件从现有状态与历史中筛选，可有整轮没有事件。所有回应与事件后果先改变真实世界，再由受约束的叙事表达呈现，随机文本不能另造事实。

**祈求设计修订（TASK-PRAYER-DESIGN，2026-10-28）：** 两类求告、人物身份知晓、有限原根与详细/后台调度的目标合同见事件规则第14节；新增CSV已接入Catalog有限装载；人物知晓与本次意向已接入代码，实际验收见本项报告；完整事实/候选调度尚未适配或验收，旧实施记录不证明本轮生产或自然可达。新增取舍供制作人审阅，不冒充作者逐项终审。

**设计修订／运行时未兼容（TASK-CULT-DIRECTION，2026-10-27）：** 密教schema2规则和CSV已按本节修订，新增取舍仍供制作人审阅，非体验终审。当前src仍消费旧机构许可/事件证明；TASK-PRAYER-KNOWLEDGE已接入Catalog对新表、空event条件、新selector及open_route的有限语法校验；这不代表相应密教消费者已支持。现有游戏不能被当作本修订已实现或可继续运行；后续由CULT-SPREAD／ANCHOR-ROUTES／ANCHOR-LIFECYCLE／CULT-SAVE-COMPAT接入，其他祈求生产沿PRAYER链。下文既有实施记录仅说明旧规则范围，不能覆盖本次差异。

**实施边界（TASK-EVENTS）：** 分层基础、正式教团、权能/圣物、祈求及八蓝本锚点已有各自专项。本任务接入原12事件/24选项、真实来源筛选/固定/调度/默认、原抵抗计划到期交接、EVENT_12B当轮窗口及锚前机会处置。完成范围以唯一追踪登记和实际证据为准；完整抵抗扩展、终局、内容扩量与游戏界面继续原下游任务。


# 祈求、事件与因果叙事

## 1. 两类卡牌承担不同职责

祈求是玩家选择干预谁的机会；事件是世界对既有行动和当前局势的反应。祈求可以暂缓或不回应，已发生的事件必须选分支或接受默认后果。没有事件时不补一张“随机小事”填空。

所有与玩家互动的 NPC 均使用同一套身份、属性和状态。未信仰玩家者可以祈求；接受祈求不保证其立即成为信徒。事件人物可以是信徒、敌对者、亲属或机构代表。

## 2. 祈求的产生与生命周期

每轮展示至多三张有效祈求，最多回应其中一张。候选少于上限时不伪造人物补齐；没有候选时可以使用合法权能、改变教团策略或结束回合。

生成顺序是“存在的人物与处境 → 可成立的诉求 → 可执行的回应”，不是抽一句台词再凭空创造所需的家庭、圣物或冲突。首次出现但尚无名字的合法群体成员可以被提升为具名人物，随后保持身份。

普通祈求有可见到期时间，基线三轮，紧急内容可以更短。进入候选列表的回合算第一轮；轮末将剩余轮数减一，归零时到期。窗口内暂缓不会每轮扣款；到期才处理一次后果。已回应、已过期、祈求人死亡或诉求已经解决的卡不能再次出现。

请求卡的可回应期限与原处境的危机时钟是不同事实。失败回应会消费卡和当轮回应机会，却不会解除病危、追捕等已有危机；该危机仍按原预告期限执行一次，到期不再附加第二笔“未回应惩罚”。成功解决危机才取消其后果。重新建立请求窗口只提供再次干预的机会，不延长原危机时钟；原危机已结束则不能重新生成该请求。

到期代价由具体处境决定：现有信徒可能降低忠诚，陌生人可能向其他势力求助，疾病或追捕继续发生。不能保证玩家不干预时整个世界静止等候；也不能给每张未选卡都加固定重罚，让“三选一”变成无论如何都失败。

参数在 [event_parameters.csv](../../data/event_parameters.csv)；十二个诉求标杆在 [prayers.csv](../../data/prayers.csv)，诉求成败与到期的真实事实变化在 [prayer_facts.csv](../../data/prayer_facts.csv)。它们的目标资格及收益/代价是策划内容，不是已实现的全量发行内容。

## 3. 回应方式

祈求的操作骨架统一：看见诉求与关联对象 → 选择浅触或深度干预 → 选择合法媒介/见证者 → 查看全部成本、资格与风险 → 执行并结算一次检定。用户可以放弃本轮回应，不需要虚构一个“拒绝牌”。

- **浅触**：以最低阶合法权能或原生回应处理诉求。至少保留一种低语一、信仰零的普通浅触路径；其收益有限并可能失败、增加察觉或留下未解决的问题。不是无限免费产钱按钮。
- **深度干预**：需要更高支出、媒介或条件，改变更大范围的事实，产生更强见证及更高暴露。具体费用由权能与经济系统规定。
- **扭曲的实现**：不是另一个固定按钮，而是某些回应或检定后果的语义；满足字面愿望却改变了人物、机构或社会关系。预览必须提示后果类别，不能事后随意宣称玩家承担未提示的不可逆代价。

一般成功产生该选项标注的基础收益与明确代价；深成、失败、灾变的统一收益系数、最低损耗与灾变规则由 [权能规则](system-powers-cults.md)管理。数字化增益可缩放，人物关系、存活、记忆、证据等事实不能复制来表示深成。已提示的资源/理智/察觉等始终代价在失败时也执行；需要某个成功事实才有意义的后果（如公开见证者失去匿名）仅在该事实成立后执行，逐条语义见 prayer_facts。若某条内容有专属四档结果，必须完整列出并替代通则，不能只重写有利的一档。

一张卡支付与结算后立即成为事实。不能先付一部分、重新选择对象再保留上一结果；取消预览不消耗资源也不推进随机序列。身份不合格时拒绝操作而不付费。

## 4. 事件来自什么

事件候选有四类来源：

1. **状态机会**：某种合法局势，如教团分裂、圣物易主、机构冲突。满足条件只是候选，不必每轮发生。
2. **历史回调**：一个具体旧事实满足年龄、对象和后果条件，例如曾接受神迹的见证者被调查。
3. **文明行动**：已经有动机、证据、能力和目标的抵抗计划。玩家看见预告后，其到期不再是无理由随机抽奖。
4. **人物主动性**：具名人物根据处境与关系产生行为，如先知自行解释神意。行为依据来自人物状态，不凭文案随意推翻玩家。

一项候选必须满足对象存活或合法遗产分支、所在世界存在、前置事实有效、冷却结束、没有互斥冲突、未消费唯一奖励。随机只在合格候选中选择。

## 5. 调度与公平

轮初先失效清理，再处理到期事实，然后展示最多两张主要事件。允许零张。随机环境事件的基础出现概率来自参数表；没有合格候选时不投空骰，也不自造候选。

优先顺序：正在到期的重大后果 → 即将失去有效性的历史回调 → 人物与机构事件 → 普通环境机会。同优先级用稳定顺序与独立事件随机流裁决，不受卡片渲染顺序影响。

同一对象、同一互斥组在同轮最多一个主事件。被互斥压下的候选重新检查期限，不能因进入队列就永久锁住其他内容。唯一事件按来源事实和对象标识一次性消费，不按标题识别。

**容量不暂停因果。** 已提前预告的抵抗或祈求期限照常到期；若本轮主要事件位不足，在结算摘要中按已展示的默认后果处理，不能无限排队让世界停止。尚未让玩家见到的重大新危机不得当轮直接执行毁灭性后果，应先进入预告或合并到已有危机。

每张必须处理的事件至少有一个不需要现有资源的“承受/放弃”分支。该分支可以很糟，甚至导致寂灭，但不能因无法支付而无法继续。

一个事件结算产生的新事实，最早进入下一轮事件筛选。一次回合不递归即时弹出子事件；长链通过后续回合推进，避免无限触发和无法退出。

这条限制针对再次筛选和弹出的主事件，不延迟已经结算获得的物件与可用状态。机构槽首次真实神迹依托产生的遗物机会是行动区的可处置对象，可在本轮后续行动阶段回收，不占主事件位、不递归弹窗；若其后还要引发一次调查，该调查最早下轮筛选。

## 6. 内容的后果必须可计算

事件只允许操作受管理的状态：资源变化、人物状态/关系/所在位置、机构资格、文明主状态、锚点状态、物件归属、待到期计划、已发生事实。文本不获得任意修改整个存档的权限。

每条正式事件需要明确：谁适用、为什么现在发生、给玩家什么信息、每个选项的资格/成本/效果、默认后果、对象消失怎么办、能否重复及与哪条历史相连。

本轮十二条事件是关联链的标杆，调度与默认分支见 [events.csv](../../data/events.csv)，二十四个选项的资格、确切成本和状态变化唯一见 [event_effects.csv](../../data/event_effects.csv)。这些事件选项是当前局势提供的专用行动，本版按表确定结算、不额外投骰、不占每轮唯一祈求回应；仍须支付列明信仰。祈求与权能继续使用统一检定。

- 事件只改变其声明的公开、合作、职位或具体材料；八蓝本实际依托由文明规则独立检查，不要求先选某个事件分支，也不凭事件选项替代证据。
- 已有追查、冲突、职位空缺、圣物争夺均只修改绑定的那一条关系或物件，不能泛指“全局清空风险”。
- 支持机构继任者、事件内回收圣物和销毁修正记录是表中专用行动，不偷换成只能管理教团职位的“任命”权能。
- 高阶抵抗使用其预告时已经确定的计划，不再临时抽取更高强度的伤害。
- 默认分支必须资源成本为零；资格失效则用模板的失效策略，不强制非法选项。

发行前的批量条目须保持同样完整的专属效果。当前标杆与正式全量内容的差额列入内容计划，不能据十二条标杆声称完整内容已经制作。

## 7. 因果记忆与编年史

每个事实记录发生回合、参与者、地点、来源行动、前因事实、直接后果及玩家当时的知情范围。例如“回应祈求 → 孩子存活并成为见证者 → 见证者被收录 → 调查机构追查 → 原锚点被破坏”。

回调必须使用这条链上的真实对象与事实，而不能把另一个随机人物换名拼进来。人物死亡后，保留其墓碑身份、亲属关系和历史；活跃角色资格被撤销。持有人死亡先按归属规则转移圣物，然后再重新判断后续事件资格。

已失效候选允许三种明确处理：取消并记原因；使用模板中写明的遗产分支；依据当前状态重新选一个合法目标并重新预告。禁止静默把死者换成随机活人继承所有历史。

编年史面向玩家展示关键事实和“源于哪次行动”，深层日志可展开，但不可泄露未知文明的全知视角。结局保留本局记录，便于理解成功或寂灭的形成过程。

历史可以压缩叙述，不能删除仍被未结事件、人物或锚点引用的因果节点。长局处理采用“活跃事实索引 + 归档事实 + 终局摘要”，压缩可读文本不等于改写事实。

<a id="causal-evidence"></a>
### 可执行因果约定

事实使用不可变的持久 ID，保存 `kind`、发生回合、行为者、明确对象、文明/机构、`causal_parents`、已知者/公开范围、规则 ID 与实际效果。`causal_parents` 是本次资格检查实际使用的前因集合，可以有多个；它不是“最近发生的事件”，不按文明最后一条记录自动填写。父事实必须已存在、时间不晚于子事实且不能形成环；可读文本只引用其中真实对象。

世界初始状态、明确的自然演化规则可没有历史前因，但必须记录“初始设定”或具体自然规则与资格快照；这不授权其他事件省略必需的证据。直接行为保留命令或来源事实；后继事件保存真正触发它的行为事实。多个证言共同导致一次确认时，全部参与证明的证言都是前因，不能只挑最新一条。关系行为同时引用关系来源和处境来源，避免“认识他”被错误当作“知道他遭遇了什么”。

持续公开异常是明确的现时资格，普通暴露是已经发生的历史；二者的建立、载体失效和解除规则唯一见 [文明演化](system-civilizations.md#civilization-simulation)。记录或保存历史本身不会延长异常，也不会持续收费。解除事实必须引用原异常与导致解除的实际依据，不删除原记录。

**历史成立与当前资格分开。** 一个事实曾经真实发生，不会因目标死亡而被删去；它支持的“当前可对该人行动”资格可能失效。待决项单独保存目标和前置证据，执行时重查当前状态，取消时产生说明其失效原因的记录。死亡事实、搬迁事实与目标旧处境可共同解释取消；不将目标替换后继续沿用旧人的历史。

**知情不由因果连线反推。** 玩家或 NPC 知道一个结果，不代表知道全部前因。事实保存的公开范围与传递记录控制可见性；调试日志可以显示完整关联，玩家编年史仅显示已知部分并允许“尚未知晓原因”。不得为方便解释而泄露隐藏文明、人物或未公开证据。

跨系统效果授权是已经结算的事件事实，而非可由玩家自由构造的请求。机构继任或例外确认只接受绑定对应机构与对象、引用真实前因的授权；同一授权结果至多应用一次。原事件选择、资格与费用仍由本系统负责，推演核心只消费其结果。历史事实不可被原地改写为“从未发生”；记录被销毁或异常被解除时增加新的失效事实及当前资格索引，使后续行动失效而保留可解释历史。

**幂等与存档。** 同一来源产生同一唯一结果须有稳定消费键，重复命令、加载重播和同一事件多次提交不能生成第二个证人、第二件圣物或第二份成长。存档必须保留待决目标、所有前因、知情范围、消费键与随机流；存档损坏、父节点缺失或存在循环应整体拒绝，不把断链悄悄指向最近一条事实。

## 8. 非线性叙事的承诺边界

随机生成产生不同处境，规则产生后果，文本呈现后果。第一版不承诺任意自然语言输入、全世界自由对话、运行时无限新规则或媲美人类主持人的即兴能力。

同一事实可以在不同人物关系与机构背景下产生不同候选；每条分支必须有条件，不靠大模型随意解释。内容池耗尽时使用合法的基础事件或保持静默，不伪装为无限独特剧情。

## 9. 验证要求

- 未回应祈求只在到期时执行一次到期效果。
- 无合格事件时可正常进入行动，不固定每轮弹卡。
- 目标死亡/转移/圣物易主后旧候选不再按旧事实执行。
- 冷却、唯一、互斥、到期同时存在时调度可解释，不饿死已预告危机。
- 结算子事件最早下一轮出现；一次输入不会无限递归。
- 保存读取后，待到期计划、随机流、因果关联和对象归属一致。
- 回放能还原同一条因果链；不同外观和打开卡片次数不改变模拟结果。
- 多因确认保留全部实际证言；插入一条无关事件不改变它的前因，隐藏前因不被玩家日志泄露。
- 原因缺失、循环引用、未知目标或重复唯一结果必须被检查发现；保存重载不能修补成貌似完整的新历史。
- 机器校验只能证明条件与引用合法；故事是否动人、是否重复疲劳保留为后续人审。

## 10. 后台候选、固化与临时主体

后台机会从当前宏观处境及有限模板生成，不遍历居民人生。只能使用真实当前条件和已索引的有效来源：已有亲属、契约、证言、神迹、被扣圣物必须真实存在；未知关系不得因抽中模板而回填为多年以前的事实。允许从真实无名人口提名一个此刻提出请求的人，生成当前属性/诉求并记录本轮根事实；没有合法处境就不生成。候选的性质须标为“当前背景生成”或“已知历史回调”，不能混写。

两段生命周期明确区分：`proposal` 只是本次阶段四的未承诺建议，不对外可读；`fixed` 才有持久候选 ID、主体 IDs、真实来源、内容版本、唯一发生键、抽样位置、首次可展示轮、到期轮、默认后果、独立危机 ID 和所需预留。阶段四产生的 fixed 最早下一轮展示，其请求期限从该可展示轮计算。阶段二从轮前既定候选和已有到期事项冻结名单，不重新抽取。仅开局 bootstrap 可在第一轮之前用同一容量协议生成并固化初始接触，可展示轮为第一轮；合法生成失败时不能交出没有起点的半成局。阶段二/三已授权分支可以固化确定性后继（例如 EVENT_12B 只允许一次的重开），沿用原主体/来源并检查固定候选空间，不再抽后台随机机会；除明确重开当前诉求外，新主事件仍最早下一轮展示。展示次数、页面开合与保存继续均不改变这些字段。

固化在同一事务中完成主体容量预留、必要提名扣人口、候选登记及随机位置提交。涉及的人物按 [intervention_policies.csv](../../data/intervention_policies.csv) 和模板实际依赖图计算，单候选人数不得超过 fidelity_parameters 的声明上限；PRAYER_07 深分支需要三名**已存在**关系人，不能为凑上限临时补造亲属。已绑定成员不重复占 P；其余需要保持详细的主体均占 P（即便此前属于 L），多个候选共享同一个人只占一次、持有多条引用。容量不够则 proposal 不固化、无支付无承诺，禁止挤掉旧候选腾名额。

固定候选总数有 CSV 上限，祈求展示/回应数及主要事件展示数仍只从原 event_parameters 读取。不同限制不可互换。已发布的危机、到期计划不属于可丢弃随机候选池，始终按 due 索引准确推进。候选未被选中或没挤进主要事件名单，期限也不暂停；到期默认后果必须零资源且无新增 F/N/P 需求，所需身份早已固定或可由准确宏观状态处理。目标已死亡等情况按显式失效结果结束，不能临时换个活人或续一遍期限。EVENT_01 的幸存者和 EVENT_05 的继承者仅可使用固化时已声明、真实存在且已预留的备选主体；这不是失效后重新抽人。EVENT_11 原计划目标失效即结案，新目标只能由后续独立计划重新预告。

所有浅触／深干预分支在准入表逐项登记，**不是浅触一律免关注**：PRAYER_09 浅触也直接破屏障，须取得 F；其他白名单浅触仅执行原表固定的有限影响，不能借它追加工程。所有深干预取得目标域 F。PRAYER_08 两支额外预留成员资格；其他忠诚上升不自动入团。背景来源不意味着回应可以跳过正式人物、费用、检定或现有机构事实要求。

事件分支中被标为主动改写的选择先取 F，零成本默认承受分支不取 F，不新增主体。涉及一项实际权能时，还要合并该权能的准入需求，不能用事件外壳绕过。`fixed` 主体不足以覆盖某新主动分支时，须补预留成功才能把分支变为可执行。后续真正追加一种分支/权能/策略须同步 CSV 分类，未登记入口默认拒绝。

成员身份解除时若仍被未结互动引用，依人物规则保留原 N 退役保护占用，不要求默认分支临时申请 P。互动结束只释放其持有的 P 引用；仍有危机、回应后果、未来见证或其他互动引用时，不可回收。能由当前身份与明确期限完整表达的事项可以转为准确宏观待办；不能安全转写的继续占 P。后台告警、祈求失约、人物失能等不会通过“摘要压缩”变成无后果文本。

### 历史冷热边界

完整事实、父因果、知情来源、成长消费与旧回执进入追加式冷档案。热态只保存当前可行动资格、风险/知识/成长的有效投影、待办、固定候选和索引。按 ID 查询旧来源或分页回顾允许读冷档案；普通决策不得传入整本编年史。分页上限来自 fidelity_parameters，但不能取前一页就当所有有效证据已处理：完整性由足够的聚合投影或可续游标证明，不以“只留最近若干条”丢弃仍有效的旧来源。

本节只定义协议。候选生产与固化由 TASK-ABSTRACT-SIM 验证，统一准入由 TASK-ATTENTION 验证，完整祈求/事件仍归 TASK-PRAYERS／TASK-EVENTS；历史检索、归档与中断恢复各有前置任务。仅本规则和 CSV 检查通过不表示这些游戏入口已存在。

### 当前候选协议的正式接入范围

`background_templates.csv` 当前提供当下接触（PRAYER_08）、真实屏障接触（PRAYER_09）、已有知情暴露（PRAYER_04）与当前仪式求告（PRAYER_05）四种背景候选。前两者提名当前人口中的合法人物，记录本轮根事实，不编造旧关系；第三种只使用当前代表实际知晓、目标仍有效的暴露来源。候选人数、固定池与共享引用均按原预算检查；默认未回应后果仍读取event_parameters的request_unanswered_trust_loss（只作用于原有信徒）及request_unanswered_alert，并留下当下求援暴露事实。失效主体明确取消，不替换活人。

固定候选最早下一轮可见，期限从该轮计；本轮冻结读取不会重新抽样。阶段五先正式收入，再结算候选默认后果及其他期限职责；默认后果失败随整个阶段撤回。明确的确定性后继只能由事件责任参与者授权，引用原固化事实、原主体和真实授权，按授权一次性消费，不抽后台流。当前协议支持下一轮展示的后继；EVENT_12B等完整内容特例的当轮重开仍由TASK-EVENTS接入并验证。

上述为生产/固化协议接入，未实现完整祈求回应、主要事件呈现或内容池。后续消费者必须使用本轮冻结的只读候选与同一主体持有，不重新造ID或延长期限。


## 11. 正式祈求来源与回应合同（TASK-PRAYERS）

### 11.1 情境来源的唯一形状

普通情境事实 kind 为 `prayer_situation`，fact.domain 是目标域，changes 必填 `{issuer,version,need,domain,institution,actors,subjects,facts,crisis}`。首次普通来源不带reopen；符合下述严格重开合同时仅可另带可选 `reopen:authID`。issuer/version 由Prayers显式登记接受；domain须等于fact.domain；need来自prayers表并唯一映射祈求ID，不接受调用者任填结果或allowed。institution为一个真实本域机构；actors是固定人物依赖的去重数组；subjects和facts为下表固定键，facts值只能是实际事实ID或ID数组，其全部来源都进入父因果。所有主体必须实际存在，人物关系还须匹配当前npcs.relations，已知事实还须匹配实际知识索引，不能以一张true授权替代。

`subjects.petitioner`必填；其他subject按12型规定。institution只放顶层，不在subjects设同义别名。除明确到期/失效处理外，参与人物须在本域active，非祈求人不因是配角而免身份/容量校验。少于深分支所需人物或机构时，仅禁用深分支；仍合法的浅触不被整体删除。actors固化所有已存在、可能被开放分支使用的真实人物；不为凑深分支临时制造亲友或旧见证。

crisis为空字典或 `{source,due}`。有值时source为下述原危机事实，due严格等于该事实changes.due；请求窗口不能修改它。普通来源固化后最早下一轮可见，开局bootstrap可在第一轮可见；请求due=visible_turn+prayers.lifetime-1，且不能在原处境已经结束之后继续开放。同一source只固化一次，重开须另有引用旧来源的明确授权，不重写原危机。失败回应将请求记已回应，原危机及必要holds继续保留到原due；成功解除对应处境才取消该具体危机后果。请求窗口结束与危机到期是不同操作，不能因窗口提前结束而提前杀人，也不能到期再叠一笔通用未回应罚。

**同处境重开的最短授权合同。** 同一实际处境不能通过复制一份新的situation事实绕过已回应/已关闭请求。新prayer_situation若重开，必须以reopen引用事实 `prayer_reopen_authorized`，该授权changes严格为 `{issuer,version,parent}`；parent是原situation事实ID或原background_fixed事实ID。发行方与版本须在Prayers接受清单内，授权父因果必须含parent及准确绑定原已固化候选的一条真实关闭/回应事实；由本项正式EVENT_12B触发时也可为该原请求真实未回应窗口到期事实，不能拿另一请求的结案/到期充数。

重开前从原已固化descriptor取得规范对象，逐项核对新来源的need、domain、institution、actors、subjects、facts及crisis完全相同；BG只可规范原descriptor已有信息，不补人物/条件或替换原危机。原来源有独立危机时，它必须仍未解决，新visible_turn不得晚于原crisis.due，危机来源与due均不可更换；原来源crisis={}则只重查该原处境当前仍合法，不凭空新增危机时钟。已经解决、死亡或当前资格失效的原处境仍拒绝，不因授权存在跳过重查。首次普通来源不含reopen；同处境重复来源缺少合法授权即拒绝。

同一auth只能在固化事务中消费一次；失败不消费，成功后的source和auth消费键持久保留，读档不重用。World.fix_prayer_source仍是唯一固化入口，重开只生成新的可干预请求窗口，不重置人物机会/准备/冷却、不重发原始收益，不延长或复制原危机。该接口最初只验证受限授权消费；本项TASK-EVENTS以第12节接入真实EVENT_12B及当轮生产，不能把任意发行方same_turn布尔当作该专例。

### 11.2 当前处境事实的固定字段

下列事实是世界中已经存在的具体状态，不是祈求结果。其域、targets、parents必须与实际对象一致，当前有效性由未撤销的原事实及现存对象共同决定；解决或失效通过有源invalid_records及后继事实表达，不删除历史。

| kind | changes固定字段 | 必须核验的真实状态 |
| --- | --- | --- |
| dying_condition | patient,due | patient活着；父因果含指向该人的真实harm或crisis，非仅need标签。成功救治撤该病危根；原due仍有效才死亡一次 |
| pursuit_condition | subject,pursuer,institution,clue,relation,due | 普通clue为现存暴露/追查事实，relation为追查者与被追者当前关系来源，机构真实同域；不得冒充已预告抵抗计划 |
| contract_obligation | obligor,counterparty,institution,due | 双方真实活人、具体本次义务尚未履行且根未撤销；履约结果固定该根，不泛指所有未来契约 |
| memory_at_risk | memory,holders,due | memory为真实已发生事实；holders为实际知晓该事实的人物数组；到期只撤尚未保持的本次见证资格 |
| faction_conflict | parties,institution,default_stance,due | parties为真实双方人物数组；default_stance是该机构已经知晓且与双方有关的真实立场事实ID，不是调用者填入的资源奖励 |
| barrier_contact | subject,institution,barrier_source | 本域活人和本域实际机构往来/通行处境，barrier_source等于当前域来源，屏障仍大于零 |
| devotion_contact | subject,institution | 活人当下的真实求告/献身意愿，尚未bound_member；不直接授予忠诚或成员 |
| ritual_context | subject,institution,turn | 当下祭仪处境；institution实际有仪式职责（其真实在职代表或在该机构的参与者有ritual_keeper身份），不能因机构存在就当有仪式 |

真实关系源不造历史：PRAYER_01要求亲属类型关系；PRAYER_02要求已存在rival/敌对关系；PRAYER_07要求真实社会关系。支持关系不能无说明升级成血亲，对手也不能在抽中卡后临时编造。

### 11.3 十二型的subjects/facts固定键

| 祈求 | subjects（均另含petitioner） | facts固定键 | 分支资格与当前态复核 |
| --- | --- | --- | --- |
| PRAYER_01 | relative | condition,relation | condition为dying_condition且patient=relative；relation为祈求人与该人的真实当前亲属来源 |
| PRAYER_02 | rival | relation,conflict | 当前对手关系与同机构faction_conflict；到期对手任机构代表仍须本域岗位适配、active等正式继任资格，失效不换人 |
| PRAYER_03 | pursuer | pursuit | pursuit_condition.subject=petitioner、pursuer吻合；clue与relation当前有效，普通追查与既定抵抗分开 |
| PRAYER_04 | second（可缺） | record | 祈求人确实知晓的未解释异常/暴露事实；深分支second须另一同域active人物，浅分支不要求第二人 |
| PRAYER_05 | 无额外人物 | ritual | ritual_context指向本次人物/机构与当前仪式职责 |
| PRAYER_06 | counterparty | contract | contract_obligation.obligor=petitioner、counterparty吻合，当前本次义务未履行 |
| PRAYER_07 | memory_people数组 | memory,relations数组 | memory指memory_at_risk；relations逐人与petitioner当前关系对应；浅触固定第一关系人，深分支须三名不同且非petitioner的存活关系人 |
| PRAYER_08 | 无额外人物 | contact | devotion_contact或既有BG_CONTACT固化根；真实当前献身意愿，未绑定。回应前两支均预留N；忠诚增长不自动跳过成员转换 |
| PRAYER_09 | 无额外人物 | contact | barrier_contact或既有BG_ESCAPE根；实际当前屏障及机构往来，不把背景生成许可当作回应已成功 |
| PRAYER_10 | opponent | conflict,relation | faction_conflict双方吻合；relation为待揭示的真实关系事实，不能揭示后才造出该事实 |
| PRAYER_11 | relic | claim | 实际seized实例且captor=顶层institution；claim为真实message事实，changes.relic=该实例且targets含petitioner与relic，证明人物与物件关联 |
| PRAYER_12 | other_institution（可缺） | exception | 已接触宇宙域的有效exception，原机构实际知晓；深分支另一同域active机构且双方实际links连通，不要求额外自由communication布尔字段 |

既有BG_CONTACT/ESCAPE/RECORD/RITUAL从原候选fact、actors、source_ids和当前人物/机构规范为本合同；不再提名、不重抽、不改due。BG_RECORD仍须实际代表确实知晓原暴露，deep追加人物仅在原固化范围或先完成合法追加准入后开放；不能悄悄向原候选塞人。

### 11.4 结构化回应效果与共同结算

`prayer_effects.csv`唯一规范原prayers/prayer_facts的结果语义，字段为 `id,prayer_id,variant,stage,operation,subject,field,value,parameter,condition,scale`。prayer_id为12个正式ID或共通`*`；variant为shallow/deep/both；stage为always/success/disaster/expiry。value与parameter互斥，parameter只引用run_parameters或event_parameters的已有键，不再硬写第二份公共费用/污染/灾变/隐匿时长。无数量的专属操作可均空；recovery的value=EVENT_10是原事件行引用，不是自由脚本。

condition只有all、subject_alive、knows_disclosure：后两者分别用于存活受益者的始终理智成本及一方确实获知披露之后的敌意。success行仅深成/成功执行；always行每次正式回应都执行；disaster行在always之外执行；expiry行在其原来源到期执行一次，不因先前失败回应再加未回应罚。未回应不投骰、不消费回应机会；非法输入不付费不消耗次数。

效果表的actor指实际检定主体：有合法代理时为该代理，否则为原petitioner；共通灾变理智损失只作用actor，不能误扣petitioner。条目自身明确的petitioner/relative/memory_people代价不随代理换人。默认主体是原祈求人或预先声明的合法代理，所有现有条目未另行声明社会检定，故使用适应/超常通则；不能因为“契约/审判”的文案临时选更有利属性。浅触/深干预费用与一次回应机会、四档概率及准备上限沿原权能/经济规则。准备只来自实际、未消费、未过期且固定该主体/目标的来源，不能从payload填写数值；神谕可声明 `PRAYER/<BACKGROUND-id>/<shallow|deep>`：只绑定同一固定候选的原petitioner与尚开放请求，沿原本至下一轮行动结束的有效期及一次性消费，不允许换请求、换人或变更原危机期限。圣物只对其表列明的权能提供准备，不把随身任意物件当作全部祈求的加成。

scale为none/count。count只允许成功的直接数量收益：追随者、忠诚增加、公共污染与屏障削弱幅度；深成按原prayer_deep_success_multiplier放大幅度并向下取整，原正收益最少一，再按方向应用并裁界。屏障的负号表示有利削弱，不应误作成本而拒绝缩放。公共污染也是基础数量收益，深成遵守同一规则；条目已有专属污染时替代公共值、不重复相加。set_min忠诚40/70、存活、成员、记忆、事实、制度资格、callback和所有成本均不缩放。失败/灾变不执行任何success行。

有限操作不允许写任意字段：

| operation | 具体执行合同 |
| --- | --- |
| delta | actor仅作共通灾变sanity_loss主体；petitioner/relative/memory_people理智与忠诚，domain察觉/污染/屏障/稳定/信众；sanity_loss为正数损失字段。信众来自现存非信众，不能复制具名人口；实际正污染/暴露更新当轮共同记号并保留来源 |
| set_min / enroll | 仅PRAYER_08忠诚下限与正式成员转换；回应前两支全结果最大N需求先预留，成功原子P→N，失败不入团，已用名额不当轮循环释放 |
| cure / kill_if_dying | 针对facts.condition同一病危根；成功救治失效该根，原危机到期仍病危才死亡一次；普通失败不当场杀人 |
| record / learn | 写当次真实证言、异常、仪式、公开先知、候选资格及明确知情；只传给条目指定主体/机构，不使全域全知，不复制事实凑深成 |
| withdraw | 撤指定普通追查线索/关系或成功隐匿后的机构支持；编年史不删，已预告抵抗不被撤回 |
| restrict | PRAYER_03浅触本轮不能传播；PRAYER_06浅触未来完整一轮不能任命。只限制对应行为，不统一拘禁或吞掉其他执行机会 |
| conceal / vacate | PRAYER_03深成功登记既有concealment_duration完整轮的有源有限隐匿标记，并切断指定追查关系；隐匿不等价missing，人物保持实际生命/行动状态。原职位单独vacate、机构失去这份支持；不删除人物、不迁移或复活 |
| fulfill / close_cooperation | 成功履行facts.contract指向的本次义务并记录见证，深度建立该契约依赖；到期只失本次合作资格，不永久封禁该人或捏造未来债务 |
| memory / drop_memory | shallow仅固定memory_people首人（其理智成本也只此人），deep才三名不同关系人；按原记忆根为每人保存当前见证资格，到期仅撤未保持部分，历史不变 |
| route | PRAYER_09成功写原人物本次逃离路线资格，不实际迁人；失踪只记录未来候选风险，不能当场随机判失踪或死亡 |
| recovery | PRAYER_11深成功引用EVENT_10原min_age/max_age，存原relic/captor/status_source/source及earliest/due有界争夺机会；不直接回收圣物、不套实际依托遗物时长或产生免费物件 |
| succeed / settle_dispute | PRAYER_02到期合法对手任同一机构代表；PRAYER_10按原default_stance结束同次争议。死亡/迁出/岗位不适配不强行任职或偷偷换人，其他机构不受影响 |
| close / callback | close只结束指定请求/机会，不附赠资源损失。callback只登记原event ID、当前真实结果/人物/来源和最早未来资格；不在此选择主事件或执行事件选项 |

有限隐匿的资格边界沿[叙事内容手册](../content/narrative-catalog.md)“祈求的共同语义”：只让新普通追查不能直接选中该人。正式接点为人物known_local_exposure查证候选与新exposed调查计划；不放入通用生命/物件有效性谓词，不过滤其他已确认目标的抵抗类别，不使已预告pending_plan失效。原公共事实与已知证据继续保留。到期只移除该隐匿标记，不把人从missing强行恢复active，也不免费恢复职位/护持/供奉。

PRAYER_01深始终理智损失仅作用仍活着的relative；不是把代价偷移给祈求人。PRAYER_02对手获悉只在秘密证言确实成立后，失去匿名只在公开成功后；PRAYER_04第二人真正见证后才有对应调查候选。PRAYER_05正统质疑、PRAYER_06敌对见证、PRAYER_07记忆冲突、PRAYER_09失踪风险及PRAYER_12宇宙反制资格均依赖实际成功事实，不直接调度或造成未定义伤害。PRAYER_10浅敌意仅在指定一方实际获悉披露后写入，不能将私密揭示等同全域公开。

### 11.5 原候选、危机与下游事件边界

既有后台fixed.default_result=unanswered_request的卡，未回应到期仍只执行原background协议的条件忠诚损失与察觉修正一次；12型普通typed情境则执行prayer_effects各专属expiry，不把后台默认统一套给12条。原有信徒/陌生人的区别、原演员和source消费键都保留。失败回应已经消费请求，既有background默认不得再附加“未回应”罚；其独立危机按原due和专属效果继续。成功解决的是哪个condition/contract/memory必须逐根记录，不能把一次成功理解为该域全部危机结束。

普通与背景请求都从同一simulation候选/holds及冻结名单消费，source唯一、对象固定、期限不重抽。本轮至多prayer_offer_limit张；未展示的既有危机仍到期，不能以UI/候选位不足暂停世界。PRAYER_08的成员准入、PRAYER_09浅触破屏障F、所有深分支F与全部分支人物依赖均使用原intervention_policies；后台请求不成为绕过分类的入口。默认后果不新申请F/N/P，必要主体早已持有，能准确宏观表示才可安全释放。 PRAYER_08回应时仍须重查当前献身：若原联系人后来已正式离团，早于该离团的旧contact/旧请求不能作为新献身来源，沿成员规则要求真实更新的意愿。

本项必须实际改变病危、义务、隐匿/职务、关系/知情、记忆资格、成员、人口与文明数值，不能只写一个“已实现祈求”文本。回调只产有源未来资格：PRAYERS不重开完整EVENTS调度，不直接回收/派发圣物或发动更高阶反制；实际神迹材料提交后由正式依托生产者重判，不等事件颁证。EVENTS后续消费同一结果来源、对象与有界机会；ANCHORS/ENDINGS/UI等继续原验收。成功回应的真实神迹/见证绑定所选原机构和实际知情者，不自动让其他机构共享证言。


## 12. 正式事件来源、操作与调度（TASK-EVENTS）

### 12.1 两张机读表与唯一业务入口

`event_sources.csv`一事件一行，字段为event_id,producer,source_kind,source_tag,object_schema,eligibility_a,eligibility_b,invalid_policy。producer/source_kind/source_tag中的竖线只表达本节有限枚举并集，不是可执行表达式。producer为prayer_callback、record_callback、resistance_plan或prayer_expiry；source_tag的evidence_or_public指真实祈求证言/异常/公开记录类，dream指真实成功POWER_DREAM的miracle，unanswered指真实窗口到期answered=false，均由生产事实字段匹配，不能自由写同名tag制造资格。真实来源负责触发，原年龄/优先/默认与冷却仍唯一读取events.csv。

`event_effects.csv`新增status列，仅active/retired；保留24条稳定选项身份与原费用供历史审计，EVENT04A为retired，其余active。退役项没有可执行operation，不参与生成/预览/支付；不能根据旧A/B按钮假定每事件都有两条有效选择。

`event_operations.csv`字段为id,event_id,option,operation,subject,field,value,parameter,condition，一行一个有限操作；按id稳定顺序执行。费用唯一来自event_effects.faith_cost，不在代码或新表复制第二份；value只规范原选项数字，parameter如有只引用原参数。事件选择按原表确定结算，不增加检定、不套祈求深成倍率、不占唯一回应或六类人物执行机会。未知事件、操作/主体/field组合、来源或选择拒绝且不扣费、不耗随机。

操作枚举为delta、record、publish、succeed、release_contract、retain_dependency、preserve_memory、drop_memory、prophet、move_medium、evidence、open_route、relation、recover_relic、close、erase_record、cancel_plan、resolve_plan、leave、reopen；主体为survivor/institution/domain/cult/cooperator/opponent/priest/heretic/obligor/witnesses/prophet/relic/plan/petitioner/global/opportunity。condition只有all、heretic_exists、opponent_exists、was_member；其他分支资格由source表有限eligibility词汇和下述当前对象规则判定，不执行任意CSV脚本。

Events是Turn的正式受管理事件参与者，EventRules只计算真实来源/资格；Powers、Cults、Relics、Economy、Prayers和World仍各自拥有原状态/费用/成员/归属/知情/危机规则。不能用自由event_situation、allowed=true或调用者自填eventID直接生成故事。正式结果有版本issuer并产真实选项和全部实际前因，Anchors依然重查本机构完整basis。

### 12.2 从真实生产事实固定原对象

真实successful Prayers的future_callback须沿turn_check、prayer_attempt、prayer_result.produced核对，失败或仅同名文本不通行。描述器固定content_id/domain/institution/actors/subjects/facts/source/source_ids/visible_turn/due_turn/once_key/mutex/priority/default_action；所有实际选源ID进入source_ids和固化父因果，内容/策略版本持久保存。原祈求descriptor需要保留时作为不可改写的prayer_descriptor。没有合法对象不提名新亲友/继任者/媒介，不补不存在的历史。

| 事件 / object_schema | subjects固定角色 | facts固定来源与真实生产 |
| --- | --- | --- |
| 01 survivor | survivor，可选fallbacks | miracle、callback：真实PR01救治/神迹结果中的原幸存者；备选只从本神迹原有真实幸存见证中在固化时明确并预留，死后不临时抽人 |
| 02 evidence_bundle | witnesses，可选other_institution | records、callback：真实PR02/04等证言/记录/公开后果，或真实POWER_DREAM。取原机构当前有效记录与实际知情见证，按实际可公开/保密的记录组成有限固定包；不以完整锚点资格作为公开选择的前置 |
| 03 vacant_office | former，可选cooperator/opponent | vacancy、relations、callback：真实PR03隐匿成功导致的原职位空缺，former为原petitioner；合作/对手必须是World合法岗位继任者，并有当前真实合作/对手关系来源。职位已有人即结束旧案 |
| 04 ritual_authority | priest，可选heretic | rituals、可选public/relation/knowledge、callback：真实PR05仪式；祭司为本机构仍能实际实践的原仪式见证者，不强制官方代表职位。异端接收者只能从已有实际职责、神迹知情及合作传播联系中固定，缺对象只记录正统态度，不能补造支系人物或因态度直接剥夺秘密依托 |
| 05 contract_ends | obligor、counterparty，可选successor | contract、dependency、witnesses，可选inheritance/relation、callback：真实PR06深履行及本契约依赖，两端见证是事实ID；原义务人与已固化合法契约继承人沿文明第9节严格合同，不能拿普通机构继任替代 |
| 06 shared_memory | 原witnesses | memory、qualifications、callback：真实PR07的同源记忆和逐原人见证资格；浅成功可能只保持首人，不能凭此补全三份资格 |
| 07 prophet_dispute | prophet，可选successor | prophet，可选will/succession、callback：真实PR08公开先知源。死亡遗言分支必须有原人物死亡前已写、实际知情的遗言和原已固定有效继任者，两者确指同一先知/标签/教团，不复活、不随机换人；否则只记录结束 |
| 08 exposed_medium | relic及原实际携带人（若有） | exposure、investigation：仅World真实RESIST_TRACE且实际目标是同一媒介。普通PR09逃离路线不自动生成圣物，SEIZE不作为本事件来源 |
| 09 faction_conflict | cooperator、opponent、cooperating_institution；A另固定recipient | conflict、relation、callback；A另固定material/contact_path：真实PR10结果与未结束争端。合作方须实际知道并能提供material，recipient为已有本团实际成员（优先当前领袖，再按稳定成员ID）；cell当前不能接触这份材料，双方已有真实物理通路。本次合作结果可建立新的真实人际接触，不伪造过去友情/机构授权 |
| 10 seized_relic | relic | claim、custody、callback：真实PR11深结果relic_recovery_opportunity，固定原实例/captor/status_source/原earliest与due，持有机构变化则结束，不改成另一件物 |
| 11 original_rewrite | 无新人物 | plan、record：仅World真实pending RESIST_REWRITE的started_fact与原target，机构/原due及预告参数固定；PR12成功只提供证据输入，不凭空造计划 |
| 12 expired_request | petitioner及原descriptor实际依赖 | registration、expiry、situation，可选closed：来自真实未回应prayer_window_due及原prayer_registered，不从失败回答或任意旧认识制造没有回应事件 |

**遗产不是事后发明。** 05只消费既存contract_inheritance_fixed及文明第9节所规定的原contract/关系/死亡前固化依据；收集时可沿contract冷索引读取，不在义务人死后新写“本来有个继承人”。07的遗言使用已有kind=message，changes严格`{rule:prophet_will,prophet,successor,prophet_source,relation,cult,binding}`，actor为原先知，targets含原/继任者，parents含该案真实public_prophet源、实际双方关系与原cult_member_joined binding。文书发生在原死亡事实之前（同轮按实际事实顺序，不强加早一轮），已实际写出并由相关原人/接收者或机构知晓，不在候选收集时编写。继任者当前active同域、仍是该原cult的正式成员，真实关系仍匹配；消费遗言的有源继承结果不能冒充普通机构岗位任命。没有遗言/固定继任就按死亡失效归档。明确的初始文书/契约继承历史可作为初始场景准备，但测试必须披露，不能用此替代后续生产效果或自由true授权。

04的可选facts.relation固定祭司与原传播对象之间实际support/cooperation关系来源；facts.knowledge只固定一个真实PR05 prayer_result ID：须等于prayer/response/该request的一次结果，实际成功且produced确含本卡rituals中的原仪式。传播对象本人或其实际所属propagation机构必须已确知这个结果；跨机构知情沿World.share_record实际递交该ID，递交遵守原可达条件，传播职责按当前对象重查。祭司可能只知道本次prayer_result而未独知每条ritualFact，因此不能要求凭空知道全部produced；反之知道结果也不反推其parents/其他produced全知，不授传播对象原神迹见证身份。relation与knowledge均进入固定source_ids和父因果，不能只写布尔知情。

可选角色在候选固化前就必须真实存在、有具体前因并取得必要P/N引用。后续只用原固定角色和明确遗产策略，不能向旧包添加新证人。组合记录在固化时固定，后续新记录可触发另案，不改写旧记录包。

**触发窗口不等于证据寿命。** max_age只限制这个源能否继续触发新的事件，不使仍有效旧证据/仪式/记忆资格过期。新记录可以配本机构仍有效的旧来源形成不同人/不同轮证明；查询使用当前有效索引与充分聚合或可续分页，不用最近几条代替完整性，也不逐轮扫描全部H。完整冷事实保留，候选固定后持有原sources。冷记录按解包后原事实轮聚合，公开包装不能用新包装轮挤掉不同原轮的证明；原来源撤销时定向移除其包装的当前索引资格，不让失效包装遮住更早有效源。查询可以包含当前K的保守成本，但最终固定的记录/人物只取原蓝本所需的充分有限包，不把全部查询结果固化成超额主体。

### 12.3 操作的实际后果与分支资格

- delta只操作表列字段并沿既有范围裁界；信众从现存非信众转化，不复制人口。faith收入受共同容量约束，实际正察觉/污染留当轮记号与来源。cult凝聚只作用原本实际存在的本域教团，不造教团、复活覆灭组织或把无对象收益记为实收；预览必须报实际变化。
- record写真实变异、日常保留、人情、异端、敌对见证、保管保留或离开等具体来源。01A“本次不变异”只阻止本事件变异，不抹掉其他历史变异；01B实际改变表列理智/信仰/察觉并公开同次神迹，不额外加属性或判死。人情事实同时指原former与cooperator，不只写无债务人的标题。
- publish实际递交原记录并形成绑定原见证/机构的公开知情、暴露或可调查资格；秘密02A必须仍有实际秘密记录，不把已公开包重新写成秘密；真实公开历史不因撤销包装而变回秘密。02A不误写公开，也不让全域机构全知。事件不得从parents反推知情；所需share_record必须由实际知情且可达的原发送者逐ID递交。
- 实际依托不由事件颁发：02B只做真实公开；04A已退役；05B保留原契约依赖，06A保留原记忆；对应操作不能写通用institution_event_result或allowed=true。事件可以在材料未达到锚点条件时发生，其原具体资格仍需成立；当前basis由文明规则独立重查，缺材料不收费伪造认可。
- succeed使用World真实机构岗位继任，原合作/对手失格则按原失效策略，不变成Cults任命或临时换人。03B换任/空缺只实际影响其原职位；若真正损失所需承载者会影响依托，无关代表变化不统一使锚休眠。04B的4信众仍需合法固定heretic及真实来源，没有对象时新增人口为零；interpretation_rejected只记正统态度，不产生通用denied门槛。
- 04A已在event_effects.status标retired且无operation；不执行旧“撤否认再恢复资格”链，也不保留无实际收益的付费支持。正式schema2无通用denied映射；真实材料受损/原祭仪者失能按当前依托规则判断，不能以支持记录复活死者、恢复毁掉的记录、免费修复结构或免供奉。
- release_contract只解除本contract的神迹依赖、当前资格及相应锚维持，不删除已履行历史、不永久禁止后续契约。retain_dependency保存原依赖，按表给当前原义务人或合法继任者敌对见证与察觉，不复活旧义务人。
- preserve_memory保留原实际分歧并递交本机构，数量不足不生成见证；drop_memory仅撤本事件绑定的一份有效见证资格，预览/输入的selection.qualification只能选择本固定包的一份当前有效原资格ID；未显式选择时按固定顺序取首份，预览必须显示该实际选择，不另投骰。实际result持久保存selection并重查，不能整组清空。历史记忆仍存在，不能把删除当前资格写成忘掉全部人生。
- prophet纠正/允许只作用本事件原公开先知标签。07B的额外1察觉只在本域实际执行传教策略时一次生效，不随同源/多个标签叠加；纠正、原人失位或失去实际绑定资格后停止。遗言分支只沿原固定存活继任者，不把原死者当活人扣忠诚。
- move_medium仅把原bound/carried、确实可移动的同一媒介经Relics入合法本域库藏；already controlled不能靠不动位置免费取消调查。该操作解除原护持/绑定，相关锚立即休眠；evidence实际给原调查机构取得同目标证据，08B保持媒介本次位置/效用，不能附赠扣押。recover_relic沿真实授权将原被夺实例入本域教团库藏，原对象/位置版本逐项重查；表列敌对关系有实际双方与来源。
- open_route只给原合作者实际可支配的秘密渠道：生产cult_contact_route，固定原合作结果、同一人/关系、所属实际结构及已有通信通路，读文明规则第9.1节和cult_spread_routes.csv。经济仍检查渠道现时可用及普通招募条件；强化播种另查蓝本媒介。另一方敌对不等于全域封锁，没有EVENT09A也不剥夺已有cell。close只结束本次合作/请求/争议或物件机会，不删除独立秘密路线或原物件。
- erase_record销毁本计划绑定的一份记录当前资格，取消该计划；不清空其他异常，不额外销毁圣物/人物。resolve_plan仅消费原计划、登记既有冷却/结案，不重复操作表已施加的创伤8及污染-10。11B两笔就是原计划全部伤害，不再另扣同义苏醒。
- leave经共同成员入口解除原成员资格并保留人物历史；12A不杀人、不迁出世界或强制删除NPC。reopen只买同一原诉求的新窗口，不直接发回应收益，费用与-5忠诚照表，详见12.6。

### 12.4 资格、固定池、优先与默认

事件最早可见=max(来源轮+原min_age,来源轮+1)，普通机会due=来源轮+max_age。源在此之前只是有源未承诺建议，首次达到最早可发生轮时才按当时已有真实记录/人物固化分支包；不能超过min_age故意等待未来证据凑条件。该轮只按具体事件所需实际材料/角色判断；02B公开一份有效记录、04B的具体世界后果不要求先凑齐两轮仪式或完整锚点依据，零资源默认仍可处理；缺容量不承诺，原时钟仍走。PR11争夺与原计划有已承诺due时保留原值，不从重新入队重算。新主事件不当轮递归；12B当轮重开的是请求而非新主事件。每轮最多major_event_limit张，固定/展示只读当轮边界，不因打开、保存或选择第一张重抽第二张。

按已到期的预告重大后果、即将失效的历史回调、人物/机构事件、普通环境机会四层处理：第一层为08/11且原due<=当前轮；第二层为其余有源历史回调且due<=当前轮，即最后可选择轮，不新增“快到期”阈值；第三层为仍在窗口的本12类具体人物/机构/物件来源；第四层只留给真正环境机会，本12类不属于ambient。先按层，再按events.priority降序、due升序、source/id稳定排序；只有同层、同priority、同due确需裁决时使用独立events流，不污染check流。ambient_event_chance仅用于真正环境机会，本12源都是有具体因果来源的候选，不给每个回调统一强加35%检定，也不投空骰补故事。

同一scope/主对象互斥组同轮最多一张；冷却按原事件族/主对象持久记录，唯一消费按事件/固定来源及实际对象，不按文案标题。被互斥/冷却压住仍检查原due，不延长历史。尚未展示的普通机会越窗则取消留档，不偷执行其严重分支；已提前预告的08调查/11反制在原due没挤进卡位也须按已知零资源默认摘要结清，不能卡位暂停世界。

已冻结卡必须选择或用原default_result；所有默认不需要资源，失去必要对象则按原invalid_policy结束，04B缺异端只否认。非法付费分支不扣费、不消耗事件；正常选项失败于当前资格也不临时替人。全分支依赖按原intervention_policies共同预留，再收费/发布结果；默认不申请新F/N/P。中途实现错误整笔回滚，合法确定后果不重跑。

### 12.5 原抵抗与具体例外查证的闭环

Events安装后，原RESIST_REWRITE和已被正式08候选固定的原媒介RESIST_TRACE，其到期选择交到同一原due的阶段二；阶段一仍先处理身份失效和原目标有效性，其他抵抗（含SEIZE）保留原阶段一行为。08/11实际选择或溢出默认消费同started_fact/target/institution/due，不延后、不换目标；World不得随后再结第二次同计划。08A移原媒介让该次调查失目标，08B一次真实查证与+6察觉；11A毁指定记录取消原计划，11B一次8/-10。已失效原目标立即结束旧案，新目标必须另案预告。无正式Events的旧限定参考路径不改变。

CIV07的前置查证不依赖已经完成11：真实PR12浅/深在两个可通信实际机构分别留下同一有效exception的独立记录，机构实际知晓其记录；Events源生产者只据这些具体事实，向可运作的interpretation机构形成一次exception_confirmation_authorized，再调用World.confirm_exception。解释机构必须实际知晓exception；缺知情先经合法share_record，不从parents推知。授权targets含解释机构与原exception，parents含exception、双记录及实际递交/知情来源，按机构/exception/原记录束幂等，不新增数值或额外骰，不提前或替代授予锚点实际依据。之后World仍按真实察觉、机构职责、证据、优先级与冷却选择真实REWRITE；11只消费这条真实pending_plan，不造resistance_started。发生11时只按其实际材料变化重查CIV07实际依托，双节点实际依托不要求先经历修正；真实调查及修正也不能要求先有锚点。

### 12.6 未回应窗口、当轮重开与原危机

Prayers在窗口真正到期时写一次prayer_window_due（含原registration、descriptor、request、due及answered）；即便独立crisis还未到期，也只发该窗口事实，不提前关闭/解决危机。12源仅取answered=false的真实到期，失败回答已消费请求，不冒充没有回应。原对象死亡只历史归档，不重开。

12B产生真实选项事实后，按11.1严格prayer_reopen_authorized引用原situation/background_fixed和原关闭/到期事实，继承原完整descriptor与一次消费键；同来源不能已有另一开放请求。有独立危机时source/due原样，须仍未解决且当前visible<=原due；无独立危机时保持crisis={}并复核原处境，不造危机也不无限复制授权。

这一个由真实12B证明的专例可在本轮固定visible=当前轮，due=visible+原prayer.lifetime-1；普通来源仍下一轮。原request占当轮offer时可原位替换，有空位则追加；满3时B仍可购买重入候选，固定本轮可见但本轮不展示，不挤旧卡、不加第四张。预览明确will_offer及满位原因，不承诺付费一定获得本轮展示。后续窗口照真实时间流逝，不延长以等槽位，也不重置本轮已用回应/准备/执行机会。

PR10成功仅揭示/公开关系，不自动终结faction_conflict；原due与默认立场仍保留，供真实09追索。如果原due早于09最早可见，争端照原时钟结束，09取消，不延长/复活危机为了制造事件。此更正只针对原未声明“解决争端”的PR10，不把其他成功解除病危/义务变成无效。

### 12.7 锚前遗物机会的三个真实消费者

Events消费Anchors已有唯一institution_relic_opportunity，不新抽类型、不改schema2实际basis/created_turn/due；旧recognition/proof键如保留只承载新版本事实；操作是行动区机会，不占主事件位，不递归弹主事件。recover付原relic_recovery_faith，经Relics真实create唯一实例，再入合法本域库藏或原合格信徒携带；没有库藏/合法携带人及容量时付费前拒绝。public按原relic_public_faith/relic_public_alert给一次资源/暴露并永久放弃该物，不又创建可领取实例。wait不收费/不抽类型，只保留到原due，过期由原协议一次结清；无接收对象仍可wait/public。

recover/public和到期按原机会一次消费键互斥，重复请求/读档不重复给钱、物件或暴露。实际F/N/P依赖沿原RELIC_RECOVER/RELIC_PUBLIC分类，未知策略拒绝；公开后原来源不能另由Relics自由create兑回。完整其他圣物内容扩量继续TASK-CONTENT，本项不声称六类型之外的全部叙事规模完成。

### 12.8 到期概率效果与同批身份仲裁

仅安装正式Events的执行配置启用本节到期效果扩展，旧参考合同保持其原范围。轮前同一共同状态先冻结所有到期job的概率、实际roll及选中分支；这是已发生的仲裁检定，保留check随机推进与turn_check，不因之后被取消而退骰。未选分支中的可能死亡不能影响别人。

一个到期job的实际选中效果树（含分支外共通费用/收益）为一个普通效果组。先执行/保留同批实际选中死亡；若该job任一恢复/迁移的原目标被同批实际死亡，取消该job全部非death效果，含分支内外配套cost/bonus，只保留death与check。其他独立job照常。取消事实引用原job、实际check与死亡来源，不只写无因“取消”。因此同组[-2资源,death A,restore A,+5资源]保留death/check、其余取消；不收取消恢复的共通费，不按队列ID或遍历顺序决定生死。不增加新数值，原普通身份/归属/人口/事务规则继续适用。

### 12.9 验收与未覆盖

必须真实执行12/24的费用/状态/人口/记录/知情/成员/归属/资格后果，验证合法空轮、冻结/优先/窗口/冷却/互斥、卡位溢出原计划默认、父因果唯一消费、当轮重开与不续危机、机会互斥、到期check死亡仲裁、恢复及回滚。机器表及实际源生产不能由自由true夹具代替；测试可明确准备真实初始亲属/契约/遗言/媒体及历史，但后续业务从实际Prayers/Powers/World执行接续。

本项实现原12事件与24分支，不代表全文内容扩量、文学品质/乐趣或UI已完成。完整抵抗扩展、终局断联/封存与发布仍沿原任务；人工静态复核与Godot运行证据分开，本轮只做一次最终定向规则审阅，不能手动刷新旧runtime哈希冒充实跑。

### 当前仪式的背景生产

BG_RITUAL 沿原后台候选采样频率、随机流、当轮一次键和 PRAYER_05 原期限。只有本域现存、活跃且隶属有效解释或传播机构的实际 ritual_keeper 才能提出；不提名新祭司、不新增祭日历法、不预置回应结果或信众。固定时记录本轮 ritual_context，绑定原人物、机构、发生轮及实际状态前因，候选引用它。原 P/F 与候选预留照常检查；同域已有未结仪式候选不重复生成，旧源不能用 successor 续造祭日。

回应复查原人物、仪式职责、机构及固定情境；深层成功只使用原 PRAYER_05 CSV 的信众转换，仍需支付并接受原随机检定。后续另一次仪式必须经新的当前背景采样和独立当轮情境。此入口补齐零信众新局获取首团人数的既有祈求路径，不保证每个种子必定出现、成功或达成结局。

## 13. 密教方向修订的事件边界（TASK-CULT-DIRECTION）

事件ID、仍启用分支的原数字成本/效果与来源时窗保留；04A只保留历史费用定义不再收费；event_operations删除02B的recognize和04A全部操作，把03B/04B的否认改为实际职位/态度record；09A改为open_route及下述真实材料接收，不造新物理通路、独立根或额外招募。操作和selector新枚举已接入Catalog校验，运行消费者仍待后续接入。05/06/11仍按原条目改变实际依赖、见证或材料，不能复活旧通用许可。保留旧kind/字段作历史读取不等于允许其发行新资格。

首次遗物机会消费读取schema2 anchor_basis及机构原唯一机会键；旧recognition物理字段可由代码选择保留，但它必须指向新版本真实依据。Events/Relics/Endings三种读取者与恢复校验同步，不能只有创建者改了。公开、回收、到期、重试、错误请求不重复收入/物件，秘密依据本身不使秩序机构全知。旧版本会话由TASK-CULT-SAVE-COMPAT拒绝继续，不能重算checksum升级语义。

本节只修密教传播、实际依托及其具体事件交接；两类祈求频率、知晓、候选调度及有限自然原根由下文TASK-PRAYER-DESIGN第14节定义，仍待后续实施。已列十二型消费合同不代表其全部原始处境已被正式生产。

### 13.1 单一后果与退役分支的消费者

EVENT04只有B启用。原祭仪处境仍合法时按原来源时钟和默认B执行一次实际世界后果，真实heretic存在才转化原4信众，否则只记正统态度；它不是要玩家支付或纠结的选择。其结果照旧可见并进入回顾。规则准备返回active_choices而非固定A/B；retired A的预览/执行拒绝且不扣费用/随机。只有一个不含新主动费用/对象选择的默认后果时，Turn/Events按默认结算，Session/ActionCatalog只消费已结回执/报告，不向玩家提供空付费选项。两条真实合法选择的事件仍走原选择；04不增加原major_event_limit或吞掉既有到期工作。此处只规定结算/交接，不改界面视觉；实施若触及UI结构/样式须按原in-game-ux流程处理。

### 13.2 09A的实际用途与共同材料接收

cooperative_material_endpoint只在固定真实材料端点有增量时成立：sender=原cooperator实际知道且可提供material，材料符合文明第9节有限族且当前有效；本团cell没有已可接触的持有者能提供它，receiver为固定已有active本团成员；存在当前真实机构links/同域社会接触途径。一次合作可以建立本次真实接触，不能回填旧交情。没有增量材料、已有可用端点、源已撤或接收人失效时，A不可选，B保留原零成本退出。正式提交再次重查，先原子准入，再付原4信仰；按原表制造另一方敌对并增加3察觉。

实际接收的最小合同为 `material_received`，changes固定{issuer,version,sender,recipient,source,channel}，parents含实际原material、同一合作结果/真实既有联系、channel和发送者实际知情依据；recipient只获得source指定的一个既存事实及实际保管资格，不获得其parents、其他材料或全机构情报。sender知道的原知识必须来自原结果/真实告知，不从新回执自证。接收前不存在的事实/关系/通路、不知道的发送者、不在场/不可达的接收者均拒绝且事务不扣费；同一结果/材料/接收者只执行一次，故障与读档不重复。顺序固定为暂存真实合作结果→暂存cult_contact_route（只指原结果/实际材料/接收者，不指未来回执）→material_received引用该route→派生qualification/basis同时检查两者→整笔原子发布；失败全部回滚，没有循环父因果或半条可用渠道。

TASK-MATERIAL-TRANSFER提供受管理的实际人物接收与知识回执；09A及原Prayers.learn等已有真实告知共用该语义，不新增免费任意通信按钮或自动全图共享。原见证者本来就真实持有自己的材料，分布式carrier能直接成立；这些不必先触发09A，也不强求为了新字段额外制造接收回执。新回执只是另一条实际递交路径，不能用它复制独立见证根、原见证身份、记忆资格、圣物实例或人数。递交成功后发送者死亡/渠道关闭只阻止后续传递，不自动撤回接收者已经得到的真实知识；实际材料失效或当前持有者失格仍按本身规则处理。

可否证例：目标结构的实际持有者只有记录X，外部合作者有另一位见证不同回合产生的独立记录Y且cell接触不到Y；09A真实递交Y给目标结构已有接收者后，可补足该结构双记录依托。09B后Y仍不能被当成本结构已持有。反例：cell原成员早已持有Y时09A不得付费重复“解锁”；两记录本来由本结构两位真实见证分别持有时也可直接成立，不需要09A。公开材料递交按实际公开效果给接收方知情，秘密递交不自动让秩序机构获知。

## 14. 两类求告与有限原始处境（TASK-PRAYER-DESIGN）

本节是2026-10-28的**可审阅设计提案**，替换前文把后台抽样当作唯一自然入口、把“接触”与认识邪神混用的部分。新增CSV已接入Catalog有限装载；World、Prayers、Powers的知晓与意向已接入代码，实际验收见本项报告；完整候选调度及跨模块存档尚未适配或验收；下列生产责任是实施要求，不是已有生产证据。它只定义有限规则生成、指定事实知情及候选调度，不模拟居民生活、疾病发展、社会网络传播或宇宙物理求解。原回应效果、费用、检定、F/N/P上限和展示数不改。

### 14.1 六件分开的事

1. **处境**：世界中的当前对象与事实，例如一名现存亲属的本次病危；它不是已经发生的求告，也不是祈求成功效果。
2. **身份知晓**：具体人物能识别本局邪神这个指定对象；不是知道任意异常、相信邪神、忠诚达标或加入教团。
3. **本次求告**：人物在这个处境下作出当前愿望。本次可以向任何可能的回应者求援（undirected），也可以明确向已识别的邪神求援（directed）。知情者可以采用任一种；不知情者只能无指向。敌对或零忠诚不妨碍定向求告，但其他原角色条件仍须成立。
4. **可固定的候选**：求告已被承接，还须通过源、人物、候选位和必要P/N预留，才能成为可展示/回应的固定对象。
5. **玩家情报**：玩家从固定请求收到该请求必要的有限信息；不等于掌握整个域，更不使世界中的人反向获知邪神。
6. **主动干预**：回应及权能沿原intervention_policies检查F、人物、成员、成本和媒介。无向可被底层联系承接，不能因此绕过深干预/PR09浅触的F要求。

F只分配主动工程和详细模拟预算。本提案中新处境机会的每域抽样频率不由F改变；重点域有详细人物行为，后台仅处理有限当前索引与低频宏观规则。未知域也可产生两类中的合法求告；“未知域”是玩家信息状态，不意味着其中每个人都不认识邪神。没有该域人物身份知晓证据的请求只能无向。

### 14.2 人物知晓：只接受四种有限生产

机读单源为`prayer_knowledge_rules.csv`。直接取得事实kind=`deity_identified`，changes固定为`{issuer,version,person,identity,source,recognition,acquired_turn}`；指定告知kind=`deity_identity_received`，changes为`{issuer,version,sender,person,identity,source,relation,route,acquired_turn}`。identity指本局唯一稳定邪神身份键，随会话保存；不能以某个机构、祈求标题或任意字符串代替。父因果包括实际原source和本次所用关系/通路；取得轮等于实际提交轮。当前投影按(person,identity)保存取得事实ID及最早取得位置，不从今天的known_facts倒推过去何时认识。

| 机读rule | 精确生产条件与后果 | 不成立的反例 |
| --- | --- | --- |
| successful_identified_dream | 实际POWER_DREAM成功/深成，原接收人确实经历其梦境，结果明确登记同一邪神身份信号及该接收人的辨认；Powers写direct事实。它可以仍是非信徒 | 失败、仅扣理智、围观、知道别人入梦或只知道一个miracle标签，不产生身份知晓 |
| successful_identified_oracle | 实际POWER_ORACLE成功/深成向原接收人传达明确身份的谕言，结果登记辨认；仍需原接收与权能资格 | 看见准备数值、取消预览、他人收到谕言不授知晓 |
| successful_accepted_devotion | 实际PR08成功执行原成员转换，原求告者明确感知本次献身被同一回应者接受；Prayers写direct事实 | 无向PR08产生时、尚未回应、失败或成员准入被拒，不预先认识邪神 |
| current_specific_identity_notice | 一个已具有上述有源身份知晓的现存active人物，在本轮有限原根抽样中向一个已有、同域active且有support/cooperation关系的具体人物告知同一身份；双方有实际机构links或同一机构内当下会面。World记录本次指定告知，接收者只得到指定身份及该告知事实 | 无真实关系/当前通路、发送者只知道异常、匿名群体、仅同域或高察觉，都不能传播身份；知晓某材料不等于识别其神祇 |

梦/谕言身份信号是本提案明确添加的有限结果语义，须由Powers生产受管理回执；不能把旧结果的“成功”自动重解释为已经存在的辨认。其他十一种祈求的成功不自动授身份知晓。事实知情仍由原known_facts管理；material_received只交付指定材料，除非它就是合法身份告知的明确内容，否则不授神祇知晓。这里不新增任意通信按钮，也不逐轮扩散整张关系图；指定告知占用本域原有一次新处境抽样机会。

死亡保留取得历史但无活跃求告资格；拘禁/失踪保留知识，暂停本版要求active的求告/传递；归来不免费恢复旧请求。迁移保留同一人物知识，新的处境/通路在新域检查。离团、低忠诚、教团覆灭、撤F、失去玩家情报都不删除知晓。没有本版明确的失忆规则，不因记忆见证资格被删除而顺便抹掉身份认知。接收者取得后，发送者死亡/关系断裂不追溯撤回知识。

### 14.3 一次求告、两种意向、一个发生键

`prayer_addressing_modes.csv`只定义undirected和directed两个模式及有限资格，不改原source_mode=current_background/known_history；后者仍表示处境来历。新增事实kind=`prayer_call`，changes固定为`{issuer,version,occurrence,source,petitioner,need,addressing,identity,knowledge,intent_rule,snapshot}`。source指本次规范处境根；snapshot指选源时已冻结的演化位置。无向identity/knowledge为空；定向identity为本局邪神键，knowledge为采样前已取得且属于该人的上述取得事实；intent_rule取本模式表，记录这一次向谁求告。人物知道邪神不自动写directed意愿。

identity由本局稳定世界身份派生（世界种子、世界schema及初始world_origin的规范身份），不取墙钟、文件路径或Session临时campaign键，不额外推进check/events随机流；同配置回放相同，随会话保存。snapshot为固定结构`{turn,phase,commit_seq,fact_cutoff}`，phase=4或bootstrap，commit_seq为世界已提交事务位置，fact_cutoff为该快照末尾追加式事实位置；取得事实的实际提交/事实位置必须不晚于此截止。acquired_turn不能独自证明先后，同轮新知识若在截止之后也不合格；恢复须审计位置/来源且拒绝伪造采样切点。具体事实索引物理存储由code选择，但不得放宽这个可核查的先后不变量。

PR08的无向/定向标题和本次求告文字唯一读取prayer_addressing_modes的devotion_title/devotion_text；prayers.title保留中性目录标题，不从“你的口舌”倒灌认识。

第一版意向不是完整人物决策：对同一occurrence以世界种子、内容版本、发生键和固定用途键作版本化稳定选择，在其合格模式行中选一次；未知者只有无向行，已知者两行均可。它不使用渲染顺序、运行时hash、F或忠诚作选择，不重新投ambient概率。选中directed的这一次求告才明确向该实体提出；这是一项供制作人审阅的有限取样提案，不声称知识等于意愿或模拟了心理过程。模式表变化属于内容版本变化，旧档不重算选择。

occurrence由`(domain,root_rule,规范原根束,petitioner,need,本次实际发生身份)`构成，**不含direction、F或包装factID**。同一处境复制situation、给原根换ID、换成公开包装、在两种模式间重试，均不能再得一张卡。新自然事故/仪式可以是新发生，但必须由其规则真的产生，不能靠重签原事实。已有当前未结处境不再生成同kind/主对象的并行自然根。同一call最多固化一次；重开仍只用§11.1/12.6的真实授权，并保持原call/addressing/knowledge，不重新抽意向。

`prayer_situation`及固定descriptor新增`call`引用；它须匹配原need、人物、域和规范根束。固定候选保存addressing、call、采样knowledge及内容/能力版本。固定无向卡后人物认识邪神，不升级这张卡、不续due，也不按“现在已知”取消它；固定定向卡按采样时的取得事实证明原认识，不能用后来才获得的事实补证。人物当下的生命、所在地、处境和回应资格仍照常重查。已识别者下一次独立处境可以抽到另一个意向，不改写旧诉求。

### 14.4 两模式唯一职责、抽样与三个时钟

**正式写入归属。** Turn阶段四的World.evolve正式调用Events注册的candidate_generation参与者；它按模式绑定处理者，并通过同一个有限root_id→handler表调用规则，CAPABILITY-GUARD检查的就是这张正式执行绑定，不另建只供报告看的注册表。World拥有root/当前知晓投影和自然规则事实的受管理写入；Powers/Prayers拥有其实际行为导致的身份取得，World提供统一受管理接收语义；Prayers拥有prayer_call/prayer_situation及其规范发生键。Events协调候选并调用现有World.fix_prayer_source唯一固定入口，固定池/P/N预留由原准入协议处理。phase4全部意图取同一快照，经World/Turn同一事务校验、仲裁并原子发布；ROOT_ACTUAL_SEIZURE则由真实Relics/抵抗归属变更的授权事务在发布前生产通知，绝不在已发布后补写。CSV的producer_task是实施责任，不是runtime已注册证明。root handlers的固定owner及输入/输出见下表：

| handler组 | 正式owner / 受调用位置 | 唯一产物归属 |
| --- | --- | --- |
| ROOT_INITIAL_TIES | World / 人物初始化事务 | 实际初始关系；已展开身份不重做 |
| INJURY、DISPUTE、PURSUIT、CURRENT_RITUAL、CURRENT_PACT、SHARED_OBSERVATION、MEMORY_REVIEW、COSMIC_OBSERVATION | World / Events协调的阶段四新处境预算 | 有源当下root，依各行有限schema写入 |
| KNOWN_RECORD | Events / 原根索引选源，只读 | record_source_view不是事实kind；call/facts.record解回原记录，不生成包装事实、独立见证或新的发生身份 |
| CURRENT_APPEAL、CURRENT_PASSAGE | Prayers / Events协调当前求告 | 由已有当前人口/机构快照及真实提名产生本次contact与call；不预置成功 |
| ACTUAL_SEIZURE | Relics/World / 真实归属变更授权事务 | 原失主指定通知；进入下一快照后方能求告 |
| IDENTITY_NOTICE | World / 新处境预算 | 指定知晓接收事实；下一快照才参与定向资格 |

阶段四同一冻结快照调用Events的唯一candidate_generation协调者。focused绑定detailed_candidates；background绑定abstract_candidates_due。二者都要处理下列A；只有本域共享新处境游标到期才执行B。职责CSV的名字必须绑定到实际可执行处理者，不能只在白名单中声明存在。后台不因没有逐人agency而跳过A，重点不因游标推进而跳过全部来源生产。

**A 已发布原根的确定后继。** 两模式每轮读取当前有界原根/求告索引，按原due、规范发生键排序，至多检查并提案原background_candidate_trials=1个当前合法来源；不抽新根、不换人物、不再投出现概率。纯过期/已消费项先清理，不占一次合法提案。当前合法但容量不足者记原因，不顺便补抽另一个请求。已存在call则沿用；没有call才按该快照产生一次call→situation→同事务固定。方向选择不是第二张候选或额外尝试。

原根索引不是另一个候选池：每个(subject,need)保留当前原根头，原根束只包含本条规则必需的有限对象，另以due/发生键可续查仍有效的待求告项；每页不超过原decision_query_page_limit，持久游标保证继续，不把第一页当完整结果。自然生产者不对同一主对象/同kind建立多个并行当前根；已固化/已消费/原根到期项从待求告索引移出。只引用当前实际人物/机构与现存状态，不扫完整历史H。原root事实留冷档案；独立危机仍由Turn的due索引全部结算，更新求告head绝不能取消被覆盖旧危机或丢唯一消费。

**B 新当前处境。** 每域仍以fidelity_parameters的background_tick_interval=4、background_candidate_trials=1共用一个游标作一次有限规则抽样。重点/后台都用这一机会预算；改变F不重置相位、不补领、不在两边各抽一次。只在本节有限root行的合法当前输入中取一次，不能失败补抽。指定身份告知也在这一预算中。既有后台四模板沿相应root行接入，不再由AbstractSim独立再生产同一来源。新root/新知识不能反过来供本批A取用，最早下一个阶段四快照参与；call→situation→fix是对旧根的合法同批派生，不需要再等一轮才固定。公开提交前重查本批死亡/迁出/永久失效；真正事务故障整笔回滚，不留下半个call、半个人口扣除或已消费随机位置；正常容量阻挡不是事务故障，按下段保留完整世界求告意图而不固定候选。

**世界求告与固定的提交边界。** 已有具名人物及其原根当前合法时，完整call（含本次模式、采样knowledge/snapshot）和需要的selected_need是可独立提交的世界意图；固定池/P/N容量不足时，提交这一个完整call与capacity_blocked回执，fix子尝试的预留/候选写入撤回，不扣费、不产生半固定卡。它不占候选位，不新增人物，不取得详细互动权限；只由原有当前根头保存同一call，直到原处境/窗口消失或已固定消费，不能反复累积call池。下次释放容量仍用原call的方向和采样证明，即使人物后来认识邪神也不重抽。真正World/Turn事务故障则包括call一起回滚，只有已成功提交的call才构成历史上的第一次求告。

需要从无名人口提名的当前contact/bootstrap没有先存person：先核人口、活身份及本次fix完整P/N/固定池容量，然后在同一事务完成提名扣人口→完整call→situation→fix。容量不足时无人物、无call、无模式选择，只记未承诺原因；不得保留指向未出生身份的call，群体也不保留或继承个人知识。未来有容量时是新的合法提名尝试，不是假装更换一个先前已固定的人。因而“容量失败不重抽”约束已有完整call；未产生合法个人的匿名建议不获得这项历史身份。

**时钟。** 外部root在T发布，T+1快照最早call并fix，通常T+2展示。request.due仍为实际visible+原prayers.lifetime-1。新自然病危/争议/义务/记忆风险的crisis.due出生时就定为`T+2+对应prayers.lifetime-1`：这是让上述两段交接后保留原响应窗口的推导，不另设疾病/社会进程数值。它不随容量等待、实际固化或展示重算。已有旧根due原样保留；固定前比较最早可响应位置(visible,阶段三)与原危机实际到期位置(due,原执行阶段)，必须确实留有一次合法行动机会，不能只比较轮号；窗口上限取两者较早者。若旧根在同轮阶段一已到期，阶段三不可回应，记录no_action_window，不固定一张出生即过期的卡，也不延危机以制造机会。本节新自然危机明确在阶段五到期，因此due==当前轮仍可在行动阶段处理；既存危机按原真实执行阶段，不能被统一改到阶段五。

PR09的barrier_contact、PR08的contact和仪式本身无独立致命危机，不加一个“根due”替代请求的两/三轮窗口；原屏障/人物条件消失则当前资格失效。无独立危机的当前contact可直接从冻结快照中已有的人口/机构与当下求告生成call并fix，不需要先伪造认识邪神或一段外部危机。其他新外部根不能借此例外同批反灌。

**开局例外。** 世界初始化和合法机构/人口提交后，取一个独立bootstrap快照，固定无独立危机的当前无向PR08接触，visible=首轮，按原三轮窗口。从现有无名非信众提名一个当下愿向可能回应者献身的人，实际扣人口、预留P及PR08两支所需N；不继承群体旧知识/关系/见证。须实际验证浅触可执行及原费用足够；没有人口、容量或合法机构时整局初始化失败并说明原因，不以随机抽中PR09/12或伪造身份知识顶替起点。它保证一个合法尝试，不保证成功或首团。

### 14.5 十二类的原根责任与合法空结果

机读单源为`prayer_origin_rules.csv`及`prayer_root_rules.csv`；rule是下表有限业务枚举，不解析中文、不允许自由脚本。每条允许两种求告模式，定向另查实际知识/本次意向。四模板的旧background_fixed仍可按§11规范，但新内容版本的call/采样证明不可省略。原回应成功产物可成为**后续**另一处境的输入，不充作其自身最初生产；不是每个新局、每个域都保证十二型齐全。

| 祈求 | 输入、当前规则及产物 | 明确不发生的反例 |
| --- | --- | --- |
| 01 rescue | ROOT_INITIAL_TIES先有真实初始family关系；ROOT_INJURY从当前祭仪/往来职责活动选择一名现存active参与者，发生本轮有限事故，写harm及绑定该patient/due的dying_condition；其已有活亲属才可求告 | 只有strain、没有当下事故或实际亲属，不生成救亲属请求；不能把support改称亲属或抽卡后补人 |
| 02 recognition | ROOT_DISPUTE选择同机构已有rival/hostile双方及已有具体支持/解释记录：其中一方是现任代表，另一方当前关切含recognition/judgment；本轮机构对该记录作出偏向原代表的institution_stance，双方实际获知，产生本次faction_conflict | 只因稳定低、两人同域或普通support边，不造对手/历史压迫；对手死亡不换新人 |
| 03 concealment | ROOT_PURSUIT只据现存有效暴露：已具名order人物实际知道该记录且目标为同域活人，已有追查/敌对关系；本轮开始普通追查，绑定clue、relation及due | 高察觉、任意异常、未知目标或无关系，不造追捕；不替代六类既定抵抗计划 |
| 04 knowledge | ROOT_KNOWN_RECORD只读取该人物确实知道、仍未解释且有效的异常/暴露记录（record_source_view只是选择器，规范根始终是原记录）；可以来自本轮前的实际神迹/查证/例外观测，不另造一份初始神迹 | 全局存在记录但本人未知不出请求；知道记录不等于认识邪神；缺second仅禁深分支 |
| 05 belonging | ROOT_CURRENT_RITUAL：现存active的ritual_keeper在其有仪式能力的实际机构本轮发起当下祭仪，写ritual_context；承续旧职责，不预置成功见证或信众 | 只有机构槽、匿名代表或无仪式范式/职责，不补祭司/旧祭日；同源不以successor重抽 |
| 06 obligation | ROOT_CURRENT_PACT：实际同域support/cooperation双方、一个他们均知且有效的现存记录、一处可达实际保管机构；双方本轮约定在该机构保留这份具体记录，写current_agreement及绑定obligor/counterparty/due的contract_obligation | 缺任一方、真实关系、既存记录或实际约定，不生成；不声称旧债、未写条款、全社会契约网络或已经履约 |
| 07 memory | ROOT_SHARED_OBSERVATION先使同机构一组已有、实际有关系的active人物在本轮共同读取一个已有普通记录，写本次shared_observation并给实际参加者该事实知情；后续ROOT_MEMORY_REVIEW对同一见闻作出本机构当前归并审查预告，写memory_at_risk及原holders/due；只按真实关系确定浅/深对象 | 无既存记录、参加/知情事实、真实关系人不生成；不足三名非petitioner关系人深分支关闭；不回填共同童年/古老群体记忆 |
| 08 devotion | ROOT_CURRENT_APPEAL只表达当前未绑定活人愿向可能回应者献身；无向标题/台词为“让我的声音被听见／若有谁回应，我愿替它发声”，有身份知晓且抽中directed才可称“你的口舌” | 当前献身意向不是已认识、已信仰或已入团；旧contact早于实际离团不能拿来重新入团 |
| 09 escape | ROOT_CURRENT_PASSAGE：现存本域活人正在同实际传播机构往来，或从当前非信众合法提名一个本轮通行者；本域屏障>0且有实际机构links/时空通路，写barrier_contact指当前barrier_source | 无通路、屏障已零、人物不在本域或拿另一人的接触，不生成；不自动给F/破屏障 |
| 10 judgment | ROOT_DISPUTE的同一实际争议与双方当前关系记录：待揭示relation必须在求告前已存在且属于双方/其真实支持对象；同一争议同一求告者只选其当前need的一型 | 揭示后才补关系、任意人知道全机构秘密、没有实际争议都不成立；02/10不能为同一need复制卡 |
| 11 recovery | ROOT_ACTUAL_SEIZURE在真实Relics/抵抗夺取已存在实例后，向实际原活持有人发一份指该relic/当前captor的message；只读取原归属历史和本次实际扣押，并登记本人收到通知 | 世界里恰有seized圣物而此人无原持有关系，不造失主；无真实实例/扣押生产不能靠message自证物件存在 |
| 12 exception | ROOT_COSMIC_OBSERVATION在实际cosmic域、具名active记录者及可运作解释机构下作本轮有限“同位读数”观测，详见下段；只产原exception与原观测者知情，不先给双节点神迹证据 | 玩家还未知该域不取消无向可能；无cosmic蓝本、无人/无职责或没有本次观测不出例外；未有PR12成功不预写保留记录/反制/锚材 |

**根规则的具体输入边界。** ROOT_INITIAL_TIES不是事后发亲友：在世界/重点域首次人物初始化时，以原initial_generic_relation_count规定的稀疏边数，从已经生成且同域存活的两端分配有限family/support/rival/cooperation关系类型；family只陈述本局初态亲属，不编造年龄、婚姻、灾难或旧互动。关系是初始构成事实，和抽中了什么祈求无关。已有身份展开不重抽关系；匿名岗位/新接触提名者不继承群体关系。没有满足关系的现存人物就保持空，不补一张“有关系”授权。改变初始关系类型分布是本提案新增的实际取舍，须由对应有界任务实现和独立检查，不宣称旧support初始化已覆盖。

current_duty_accident只生成本轮一个有限“仪式或通行中的受伤”事件，不模拟疾病传播/伤势数值；输入为冻结快照中现存active的ritual_keeper及其实际仪式机构，或messenger及其实际往来通路。这个handler在同一个新处境抽样中先声明本轮current_activity，再声明本次事故；活动不是另一次抽样，也不读取同批另一handler刚造出的ritual_context/barrier_contact。current_activity保存{subject,institution,type,route}，type仅ritual/transit，仪式route为空，通行route必须实际存在；harm引用该活动并保存`{patient,cause,activity}`，cause仅ritual_accident/transit_accident，随后dying_condition引用该harm，沿原病危到期/救治消费者。没有这一次当前活动不以低理智代替事故。current_interpretation_dispute仅产生针对一个现存记录的当下立场冲突，institution_stance保存`{institution,record,parties,favored}`；双方收到该立场才生成原faction_conflict.default_stance。current_specific_record_pact的current_agreement保存`{obligor,counterparty,institution,record,relation,term}`，term仅preserve_record；双方确实参与当前约定并各获该事实，contract_obligation父因果含它。以上都是有限事件规则，不声称模拟社会协商过程。

shared_observation保存`{institution,record,participants}`，participants只取本次同机构实际参加的已有活人，且全部为原petitioner或与其具有实际关系的人；人数受原candidate_actor_limit约束，不为满足深分支补人。它是现在共同看到的普通记录，不是祈求神迹、独立异常见证或新一份锚材。本次共同读取的record仅取此前已存在的ritual_context、暴露/异常记录、真实成功梦境记录或law_observation，不取prayer_call、future_callback、该memory_at_risk自身或任意空message；所有实际参加者本轮确知shared_observation，不能从parents全知。current_witness_review只适用于实际communication=network的机构，输入为仍有效的shared_observation、原知情者和同机构当前解释职责，登记“该见闻的个人见证将被机构归并”的明确预告；到期仅沿原memory_at_risk撤本次未保留的见证资格，不抹历史/身份知晓。PR07成功才生产其原memory_preserved材料。

current_single_value_anomaly只在cosmic蓝本运行一个脚本化当前现象：实际记录者在本机构同一个本轮probe中取得互不相容的present/absent登记，law_observation保存`{institution,observer,probe,axiom_key,reading_a,reading_b}`；axiom_key仅single_valued_archive，probe为本次稳定现象ID，reading_a=present、reading_b=absent。规则明确生成这次当下异常，不谎称引擎计算了宇宙法则。随后exception保存`{institution,observer,observation,axiom_key}`并引用实际观测，只有实际observer/本次所属机构取得该观测知情；他因此知道不一致，不自动认识邪神。这一原观察不是anchor_conditions接收的exception_record/exception_learned，不是双节点独立见证。PR12浅/深成功后才按原效果产生保留记录和真实跨机构材料；当前根不能凭其两种reading直接充两个锚材。

PR04的record_source_view白名单只取有效exposure、exception；prayer_fact仅取真实成功结果的anomaly_record/public_anomaly标签；miracle仅取真实成功POWER_DREAM且明确指向该原人物的梦境；law_observation仅取上述本次实际观测。future_callback、失败/到期、普通message、ritual_context或任意同名标签不冒充PR04异常。旧消费者接受范围须由ORIGINS同步，不靠通用prayer_fact放行。知晓与当前“未解释”资格均须成立，明确解释/撤销来源后不再以旧记录提案；规范发生键解到原独立根。

同一争议的recognition/judgment采用origin_rules.exclusive_group=conflict_petitioner：先以(规范conflict,petitioner)在当时真正合格need中作版本化稳定择一，持久登记selected_need再构造occurrence。两型都可时不同时生成；容量失败、身份知识更新、关切改变或换包装不为原争议重选第二型。原条件失效则结束该次资格，真实重开仍引用原need/call。

所有新处境规则用原4轮一次新机会预算，来源时窗只引用prayers.lifetime及原event_parameters/fidelity_parameters；没有新增概率、伤害量、费用或人口。规则行增多会改变合格内容池组成，**不等于已证明原节奏/抽到各型的概率不变**，首团/自然可达与完整平衡仍须下游实测。不能为凑锚点保证PR07/12必出。

### 14.6 容量、可见性、版本与验收归属

正常空结果须区分`no_precondition`（没有合法当前条件）、`already_consumed`、`no_action_window`、`capacity_blocked`（分别标固定池/P/N/活身份/人口）、`not_sample_due`、`not_selected`；不存在已登记处理者/未接生产调用是`missing_producer`接入失败，不能写成合法静默。回执只记录规则、发生键、当前原因与原时钟，不占固定候选ID、不产生额外人物或奖励。容量满不抹掉世界原危机；失败不扣费、不挤旧候选、不延due、不换人/重抽意向，后续还有真实窗口才能再尝试固定。

神侧承接与展示分开：未固定的无向求告可以存在，但不向Session投影其后台世界全貌或人物名单。成功固定后，仅把该card必需的域身份线索、原祈求人、方向、已知诉求/可见危机交给玩家；未知域据此获得一个指定请求的有限线索，不自动揭示蓝本/机构网络/全量状态或取得F。ActionCatalog/Session消费相同固定descriptor，现有discover/knowledge接口须支持这一最小投影，不能为了列表显示宣布全域已知。若原响应需要目标域F，玩家仍须完成原合法发现/关注准入；无F只是该分支当前不可执行，不表示求告不存在。不新增UI表面；若现有界面不能表达方向/缺条件，列为UI下游，必须另走UI流程。

本次内容/能力版本新增持有者包括：Catalog四张新表/有限语法；World原根/求告当前索引、人物知晓取得与共享游标；Prayers的call/方向/采样证明、固定/回应/重开/危机；Powers明确身份信号与当前联系判定；Events指定告知/材料递交及后继；Turn同快照/默认期限/回执；Session/ActionCatalog有限投影；保存头、所有事实/候选/回执及续存游标。CULT-SAVE-COMPAT统一拒绝旧语义版本，不重算checksum把旧成功/旧contact洗成身份知晓。当前版本往返保存须保留人物、原call、方向、knowledge取得位置、发生键、源due、可见轮、消费/容量状态和独立随机流；切F/打开页面/保存继续均不重抽。

实施依赖：PRAYER-KNOWLEDGE接四类知晓、当下求告与方向历史；PRAYER-ORIGINS接两处理者、同源池/固定/容量及既有04/05/08/09；五个实施批次按`TASK-SOURCE-LOCAL-TIES`、`TASK-SOURCE-LOCAL-CONFLICT`、`TASK-SOURCE-CONTRACT`、`TASK-SOURCE-MEMORY`、`TASK-SOURCE-EXCEPTION`分别实现，SOURCE-CLOSURE只在各批完成后集成。具体源与消费的独立验收、下游接口和未实现清单见[本次设计报告](../qa/prayer-design.md)。上文“当前候选协议已接入”只说明旧版四模板，不证明本节生产或新局可达。


### 14.7 TASK-PRAYER-KNOWLEDGE的当前接线边界

prayer_knowledge模块接实际成功结果的辨认、受管理指定告知处理、稳定call语义及局部保存审计。Powers/Prayers实际提交写来源，World事务发布并维护有限当前投影；StateView按当前人物投影和指定ID查询，不展开历史知情者清单。Turn schema2回执保存事务序号和事实半开范围，恢复据此核取得/采样位置，旧回执语义不自动升级。具体实跑及限制见[本项报告](../qa/prayer-knowledge.md)。

旧四BG来源在过渡代码中须明确标为legacy_source；该兼容路径不证明已走本节call生产。ORIGINS负责正式两模式调度、替换过渡来源、固定与展示/窗口，以及告知机会的真实自动选取。重开只保留原call/方向和原期限，缺call的旧来源不得借重开伪装为新版本请求。本项不生成五族原根，也不为密教schema2消费者宣称可运行。
