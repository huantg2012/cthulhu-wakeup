---
status: PROPOSED
created-by: director
last-modified-by: design
last-modified-date: 2026-10-29
interface-changed: true
interfaces-with: [system-turn-economy, system-powers-cults, system-progression, system-civilizations]
exposes: [轻量契约继任选定目标合同, 事故指定知情与独立原危机实施合同, PR03深成功精确关系撤销回执, 记忆登记实践与契约实际履约路线目标合同, 当前私祷与首团组织及记录祭仪路线目标合同, 五项有源路线操作与同异常独立观察目标合同, 关键机会共享等待与实际服务目标合同, 跨机构争议与共同见闻目标合同, 正式十二事件与二十四分支, 原计划到期事件交接, 锚前遗物处置, 到期概率身份仲裁, 祈求候选, 可执行回应, 事件队列, 已发生事实, 因果编年史, 对象失效处理, 多前因事实与知情范围, 唯一结果消费键, 固定候选与主体预留, 背景生成来源与危机期限, 正式祈求情境与回应效果, 请求窗口与原危机分离, 可选秘密合作渠道, schema2实际依托机会消费, 两类求告与有源身份知晓, 有限原根生产及单一候选职责]
---

TL;DR：祈求来自有身份和处境的具体人物，事件从现有状态与历史中筛选，可有整轮没有事件。所有回应与事件后果先改变真实世界，再由受约束的叙事表达呈现，随机文本不能另造事实。

**祈求设计修订（TASK-PRAYER-DESIGN，2026-10-28）：** 两类求告、人物身份知晓、有限原根与详细/后台调度的目标合同见事件规则第14节；新增CSV已接入Catalog有限装载；人物知晓与本次意向已接入代码，实际验收见本项报告；身份知晓、正式两模式调度及四类既有原根已分别限定交付；四格与最小玩家知情由当前INTEGRATION接续，五族新原根、完整Session/跨模块存档和自然可达仍待验。旧实施记录不替代本轮当前证据。新增取舍供制作人审阅，不冒充作者逐项终审。

**设计修订／运行时未兼容（TASK-CULT-DIRECTION，2026-10-27）：** 密教schema2规则和CSV已按本节修订，新增取舍仍供制作人审阅，非体验终审。当前src仍消费旧机构许可/事件证明；TASK-PRAYER-KNOWLEDGE已接入Catalog对新表、空event条件、新selector及open_route的有限语法校验；这不代表相应密教消费者已支持。现有游戏不能被当作本修订已实现或可继续运行；后续由CULT-SPREAD／ANCHOR-ROUTES／ANCHOR-LIFECYCLE／CULT-SAVE-COMPAT接入，其他祈求生产沿PRAYER链。下文既有实施记录仅说明旧规则范围，不能覆盖本次差异。

**实施边界（TASK-EVENTS）：** 分层基础、正式教团、权能/圣物、祈求及八蓝本锚点已有各自专项。本任务接入原12事件/24选项、真实来源筛选/固定/调度/默认、原抵抗计划到期交接、EVENT_12B当轮窗口及锚前机会处置。完成范围以唯一追踪登记和实际证据为准；完整抵抗扩展、终局、内容扩量与游戏界面继续原下游任务。

**跨机构设计交付（TASK-SOCIAL-GRAPH-DESIGN，2026-10-28）：** §14.9冻结记录争议、共同读取与机构内见证登记的有限合同，PR02到期改为沿原立场结案；其效果及事实CSV已同步。此处是设计交付，当前代码未接新根schema、作用范围和EVENT06/09来源语义，不能据CSV变化声明游戏行为已修复。图初始化归SOCIAL-GRAPH，争议/记忆生产与消费分别归SOURCE-LOCAL-CONFLICT/MEMORY；完整保存及自然链仍由原下游验收。


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

第14节新规则的正式生产者还必须提供原`call`，不能走外部旧消费夹具的legacy豁免。PR04可另含内部`record_knowledge:String`：人物当时实际知道的发布包装证明，规范解回同一个`facts.record`。该证明随call basis的descriptor、situation、固定card及request descriptor保存，核当时知情、有效性与快照截止；不调用learn补原父事实，不把包装或证明加入规范发生键形成第二次机会。它不是新增异常、独立见证或玩家可见情报。

`subjects.petitioner`必填；其他subject按12型规定。institution只放顶层，不在subjects设同义别名。除明确到期/失效处理外，参与人物须在本域active，非祈求人不因是配角而免身份/容量校验。少于深分支所需人物或机构时，仅禁用深分支；仍合法的浅触不被整体删除。actors固化所有已存在、可能被开放分支使用的真实人物；不为凑深分支临时制造亲友或旧见证。

crisis为空字典或 `{source,due}`。有值时source为下述原危机事实，due严格等于该事实changes.due；请求窗口不能修改它。普通来源固化后最早下一轮可见，开局bootstrap可在第一轮可见；无独立危机时请求due=visible_turn+prayers.lifetime-1，有危机时请求due取该值与原crisis.due的较小者，且固定前须通过第14节实际行动窗检查。同一source只固化一次，重开须另有引用旧来源的明确授权，不重写原危机。失败回应将请求记已回应，原危机及必要holds继续保留到原due；成功解除对应处境才取消该具体危机后果。请求窗口结束与危机到期是不同操作，不能因窗口提前结束而提前杀人，也不能到期再叠一笔通用未回应罚。

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
| memory_at_risk | memory,holders,due；新根另固定schema,institution,registrations | memory为真实shared_observation；holders仅为该机构实际收到本次见闻登记的原参加者，registrations逐人指向同一观察中的登记项。到期只撤该机构/该根的未保持见证资格；详见§14.9，不撤私人知识或其他机构资格 |
| faction_conflict | parties,institution,default_stance,due；新根另固定schema,kind | parties为真实双方；kind仅record_interpretation。default_stance为双方及处理机构实际获知的institution_stance；本次处理机构独立于双方归属。默认只沿这份立场结案，不任职或转籍；详见§14.9 |
| barrier_contact | subject,institution,barrier_source | 本域活人和本域实际机构往来/通行处境，barrier_source等于当前域来源，屏障仍大于零 |
| devotion_contact | subject,institution | 活人当下的真实求告/献身意愿，尚未bound_member；不直接授予忠诚或成员 |
| ritual_context | subject,institution,turn | 当下祭仪处境；institution实际有仪式职责（其真实在职代表或在该机构的参与者有ritual_keeper身份），不能因机构存在就当有仪式 |

真实关系源不造历史：PRAYER_01要求亲属类型关系；PRAYER_02要求已存在rival/敌对关系；PRAYER_07要求真实社会关系。支持关系不能无说明升级成血亲，对手也不能在抽中卡后临时编造。

### 11.3 十二型的subjects/facts固定键

| 祈求 | subjects（均另含petitioner） | facts固定键 | 分支资格与当前态复核 |
| --- | --- | --- | --- |
| PRAYER_01 | relative | condition,relation | condition为dying_condition且patient=relative；relation为祈求人与该人的真实当前亲属来源 |
| PRAYER_02 | rival | relation,conflict | 当前真实对手关系与涉及双方的记录争议；双方可属不同机构，institution为本次实际立场/处理机构，不等于双方归属。到期沿原default_stance结案，不改变代表、岗位或归属；失效不换人 |
| PRAYER_03 | pursuer | pursuit | pursuit_condition.subject=petitioner、pursuer吻合；clue与relation当前有效，普通追查与既定抵抗分开 |
| PRAYER_04 | second（可缺） | record | 祈求人确实知晓的未解释异常/暴露事实；深分支second须另一同域active人物，浅分支不要求第二人 |
| PRAYER_05 | 无额外人物 | ritual | ritual_context指向本次人物/机构与当前仪式职责 |
| PRAYER_06 | counterparty | contract | contract_obligation.obligor=petitioner、counterparty吻合，当前本次义务未履行 |
| PRAYER_07 | memory_people数组 | memory,relations数组 | memory指memory_at_risk；relations逐人与petitioner当前关系对应；人物必须实际参与原共同读取并在该审查机构有本次见闻登记。浅触固定第一关系人，深分支须三名不同且非petitioner的存活关系人；不要求他们同机构 |
| PRAYER_08 | 无额外人物 | contact | devotion_contact或既有BG_CONTACT固化根；真实当前献身意愿，未绑定。回应前两支均预留N；忠诚增长不自动跳过成员转换 |
| PRAYER_09 | 无额外人物 | contact | barrier_contact或既有BG_ESCAPE根；实际当前屏障及机构往来，不把背景生成许可当作回应已成功 |
| PRAYER_10 | opponent、relation_other | conflict,relation | faction_conflict双方吻合；relation_other只能是原争议记录的真实祭仪发起人，relation为其与opponent之间、祈求人尚未知的已有关系；default_stance.relation另保留争议双方资格边。三个原人物固定、无知识增量不生成，详见§14.9 |
| PRAYER_11 | relic | claim | 实际seized实例且captor=顶层institution；claim为真实message事实，changes.relic=该实例且targets含petitioner与relic，证明人物与物件关联 |
| PRAYER_12 | other_institution（可缺） | exception,observation | 有效宇宙域exception与祈求人本次真实law_observation；observation的observer/institution吻合当前求告者/顶层机构，且指同一稳定exception。第二节点可沿§14.10真实复核产生自己的观察/求告；深分支另一同域active机构且双方实际links连通，不要求额外自由communication布尔字段。原未接触玩家的域仍可无向求告；不以玩家已知域作世界生产前提 |

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
| settle_dispute | PRAYER_02与PRAYER_10到期均只按该原faction_conflict.default_stance写dispute_settled并关闭同次争议；不投骰、不变更岗位/归属、不另发资源或敌意。真实岗位继任继续由EVENT03的空缺/授权专线负责，PR02不再发行institution_succession_authorized |
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
| 05 contract_ends | obligor、counterparty，可选successor | contract、dependency、witnesses，可选inheritance/relation、callback：真实PR06深履行及本契约依赖，两端见证是事实ID；原义务人仍活着则沿原人，已死亡时按§14.13从已有真实关系选合格继任者；不要求生前文书，不能拿普通机构继任替代 |
| 06 shared_memory | 原witnesses | memory、qualifications、callback，新合同另固定review：真实PR07同源记忆及review所指memory_at_risk同机构范围内的逐人见证资格；浅成功可能只保持首人，不补三份资格、不收其他审查根的资格。见§14.9 |
| 07 prophet_dispute | prophet，可选successor | prophet，可选will/succession、callback：真实PR08公开先知源。死亡遗言分支必须有原人物死亡前已写、实际知情的遗言和原已固定有效继任者，两者确指同一先知/标签/教团，不复活、不随机换人；否则只记录结束 |
| 08 exposed_medium | relic及原实际携带人（若有） | exposure、investigation：仅World真实RESIST_TRACE且实际目标是同一媒介。普通PR09逃离路线不自动生成圣物，SEIZE不作为本事件来源 |
| 09 faction_conflict | cooperator、opponent、cooperating_institution；A另固定recipient | conflict、relation、callback，新合同另固定disclosure/cooperation_context；relation取原stance的双方资格边，disclosure取PR10实际披露边。A另固定material/contact_path：真实PR10结果与未结束争端。顶层institution仍为原处理机构，cooperating_institution固定合作者在事件固化时真实所属结构，不复制原处理机构；原归属依据进入cooperation_context，A还须该结构真实能提供所选材料。recipient从满足本次目标缺口和合法接收条件的已有本团成员中选择（先筛合格者，再领袖优先及稳定ID）；无已有合法供给端点才开放A，预算/名额不足不算新端点。实际递交仍遵守§13.2，不伪造过去友情/机构授权 |
| 10 seized_relic | relic | claim、custody、callback：真实PR11深结果relic_recovery_opportunity，固定原实例/captor/status_source/原earliest与due，持有机构变化则结束，不改成另一件物 |
| 11 original_rewrite | 无新人物 | plan、record：仅World真实pending RESIST_REWRITE的started_fact与原target，机构/原due及预告参数固定；PR12成功只提供证据输入，不凭空造计划 |
| 12 expired_request | petitioner及原descriptor实际依赖 | registration、expiry、situation，可选closed：来自真实未回应prayer_window_due及原prayer_registered，不从失败回答或任意旧认识制造没有回应事件 |

**契约接续不补造过去。** 05按§14.13在义务人已死亡、确需接续时，从已有真实关系选合格现存者并记录本次选定；不强制生前文书，也不把本次选择写成过去已有的安排。实际B结果才产生继任效果，选定本身不授神迹依赖。07先知遗言不是本次简化范围，仍使用已有kind=message，changes严格`{rule:prophet_will,prophet,successor,prophet_source,relation,cult,binding}`，actor为原先知，targets含原/继任者，parents含该案真实public_prophet源、实际双方关系与原cult_member_joined binding。文书发生在原死亡事实之前（同轮按实际事实顺序，不强加早一轮），已实际写出并由相关原人/接收者或机构知晓，不在候选收集时编写。继任者当前active同域、仍是该原cult的正式成员，真实关系仍匹配；消费遗言的有源继承结果不能冒充普通机构岗位任命。没有遗言/固定继任就按死亡失效归档。明确的初始文书/契约继承历史可作为初始场景准备，但测试必须披露，不能用此替代后续生产效果或自由true授权。

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
- preserve_memory保留原实际分歧并递交本次review.institution，数量不足不生成见证；drop_memory仅撤本事件绑定且在该机构审查范围内的一份有效见证资格，预览/输入的selection.qualification只能选择本固定包的一份当前有效原资格ID；未显式选择时按固定顺序取首份，预览必须显示该实际选择，不另投骰。实际result持久保存selection并重查，不能整组清空。无合法资格时按§14.9结束事件且不执行数值结算；历史记忆仍存在，不能把删除当前资格写成忘掉全部人生。
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

本节只修密教传播、实际依托及其具体事件交接；两类祈求频率、知晓、候选调度及有限自然原根由下文TASK-PRAYER-DESIGN第14节定义；当前K/A/B限定交付及C实施边界见该节，五族新原根仍待后续实施。已列十二型消费合同不代表其全部原始处境已被正式生产。

### 13.1 单一后果与退役分支的消费者

EVENT04只有B启用。原祭仪处境仍合法时按原来源时钟和默认B执行一次实际世界后果，真实heretic存在才转化原4信众，否则只记正统态度；它不是要玩家支付或纠结的选择。其结果照旧可见并进入回顾。规则准备返回active_choices而非固定A/B；retired A的预览/执行拒绝且不扣费用/随机。只有一个不含新主动费用/对象选择的默认后果时，Turn/Events按默认结算，Session/ActionCatalog只消费已结回执/报告，不向玩家提供空付费选项。两条真实合法选择的事件仍走原选择；04不增加原major_event_limit或吞掉既有到期工作。此处只规定结算/交接，不改界面视觉；实施若触及UI结构/样式须按原in-game-ux流程处理。

### 13.2 09A的实际用途与共同材料接收

cooperative_material_endpoint只在固定真实材料端点有增量时成立：sender=原cooperator实际知道且可提供material，材料符合文明第9节有限族且当前有效；receiver为固定已有active本团成员，目标结构须与其本次真实接收/归属一致；增量按原material、该receiver和目标结构的实际材料/保管缺口判定，不以教团别处有人持有该材料直接否决。若已有合法递交能向该接收者提供同一端点，09A不另收费解锁；存在当前真实机构links/同域社会接触途径。一次合作可以建立本次真实接触，不能回填旧交情。没有目标接收增量、指定接收者已有所需有效材料/资格、已有合法递交端点、源已撤或接收人失效时，A不可选；临时缺资源/行动名额不把旧端点变成新端点，B保留原零成本退出。正式提交再次重查，先原子准入，再付原4信仰；按原表制造另一方敌对并增加3察觉。

实际接收的最小合同为 `material_received`，changes固定{issuer,version,sender,recipient,source,channel}，parents含实际原material、同一合作结果/真实既有联系、channel和发送者实际知情依据；recipient只取得该材料族允许的指定知识/合法保管内容，不因learn自动取得实践/原见证资格；具体矩阵由MATERIAL-TRANSFER-DESIGN冻结。不得获得其parents、其他材料或全机构情报。sender知道的原知识必须来自原结果/真实告知，不从新回执自证。接收前不存在的事实/关系/通路、不知道的发送者、不在场/不可达的接收者均拒绝且事务不扣费；同一结果/材料/接收者只执行一次，故障与读档不重复。09A顺序固定为暂存真实合作结果→暂存cult_contact_route（只指原结果/实际材料/接收者，不指未来回执）→material_received引用该route→派生qualification/basis同时检查两者→整笔原子发布；内部递交使用其真实既有联系和实际递交来源，不伪造09A合作结果；对应暂存顺序/版本由设计批冻结。失败全部回滚，没有循环父因果或半条可用渠道。

TASK-MATERIAL-TRANSFER提供受管理的实际人物接收与知识回执；09A及原Prayers.learn等已有真实告知共用该语义，同团跨机构的指定材料转交须有明确受管理入口，不依赖09A；入口/费用/人物机会、材料族的知识与保管/实践语义由TASK-MATERIAL-TRANSFER-DESIGN先定义并落CSV，不开放任意无源通信或自动全图共享。原见证者本来就真实持有自己的材料，分布式carrier能直接成立；这些不必先触发09A，也不强求为了新字段额外制造接收回执。新回执只是另一条实际递交路径，不能用它复制独立见证根、原见证身份、记忆资格、圣物实例或人数。递交成功后发送者死亡/渠道关闭只阻止后续传递，不自动撤回接收者已经得到的真实知识；实际材料失效或当前持有者失格仍按本身规则处理。

可否证例：目标结构的实际持有者只有记录X，外部合作者有另一位见证不同回合产生的独立记录Y且目标接收者尚无已有合法递交可取得Y；09A真实递交Y给目标结构已有接收者后，可补足该结构双记录依托。09B后Y仍不能被当成本结构已持有。同团跨机构正例：A结构成员持X，B结构同团成员持独立Y；A接收者确实缺Y且B能合法提供时，走已有关系/通路的实际内部递交给A，不能因教团已有Y拒绝；A真实取得可保管材料后才重判A结构basis。反例：指定接收者已具备所需Y，或已有合法递交可以提供相同端点时，09A不得付费重复“解锁”；两记录本来由本结构两位真实见证分别持有时也可直接成立，不需要09A。公开材料递交按实际公开效果给接收方知情，秘密递交不自动让秩序机构获知。

### 13.2补充：接收增量与内部递交（DEC-024，待设计实施）

“知道记录”“实际保管材料”“原见证者身份”“祭仪/记忆/契约资格”分别判断。设计任务列有限材料族的可递交内容、实际接收方式、知识/保管/实践条件及不可转移资格；转发不能增加独立根、见证人、记忆人数、契约身份、祭仪能力或圣物实例。指定接收人/目标结构已满足哪一层须明确，不能一律用learn视为取得全部资格。

TASK-MATERIAL-TRANSFER-DESIGN先明确内部递交的玩家/世界入口、实际关系/通路、知情与可提供条件、接收时目标结构、费用/人物机会/版本及必要玩家知情；原material_received字段是否扩展须在该批明定，不能从收件人后来归属反推当时目标。原结果/09A/内部递交复用MATERIAL-TRANSFER的一次实际交付和回执语义；CULT-SPREAD仅负责09A原事件费用/敌意/察觉编排，不能调用共同内核后再收一遍内部行动费或重复发回执。预览纯读，提交重查并原子发布。

接收者迁出/换机构、材料被撤、原见证失效时分别重判知识、当前实际承载和蓝本资格；已经得到的历史知识不因渠道关闭自动删除，原材料或原独立见证失效也不能被转交洗成有效。具体矩阵与参数仍待设计，本轮源码/CSV及旧报告不变。

## 14. 两类求告与有限原始处境（TASK-PRAYER-DESIGN）

本节是2026-10-28的**可审阅设计提案**，替换前文把后台抽样当作唯一自然入口、把“接触”与认识邪神混用的部分。新增CSV已接入Catalog有限装载；World、Prayers、Powers的知晓与意向已接入代码，实际验收见本项报告；正式两模式调度与04/05/08/09既有原根已按A/B限定交付，四格/最小知情由当前C接续；五族新原根、完整Session及跨模块存档仍待验。下列责任中未验部分继续是实施要求，不能由模块登记推定已有生产证据。它只定义有限规则生成、指定事实知情及候选调度，不模拟居民生活、疾病发展、社会网络传播或宇宙物理求解。原回应效果、费用、检定、F/N/P上限和展示数不改。

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

当前四类正式来源的card.source_mode由原situation.call与call.need派生：04已知记录为known_history，05/08/09当前来源为current_background；固定及候选审计共用此派生，不接受仅放行枚举或从direction推断。无call的旧typed消费合同保留known_history，该兼容值不代表已通过新生产规则。

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

**时钟。** 外部root在T发布，T+1快照最早call并fix，通常T+2展示。请求的常规窗口上限为实际visible+原prayers.lifetime-1；存在独立危机时，request.due取该值与原crisis.due的较小者。新自然病危/争议/义务/记忆风险的crisis.due出生时就定为`T+2+对应prayers.lifetime-1`：这是让上述两段交接后保留原响应窗口的推导，不另设疾病/社会进程数值。它不随容量等待、实际固化或展示重算。已有旧根due原样保留；固定前比较最早可响应位置(visible,阶段三)与原危机实际到期位置(due,原执行阶段)，必须确实留有一次合法行动机会，不能只比较轮号。若旧根在同轮阶段一已到期，阶段三不可回应，记录no_action_window，不固定一张出生即过期的卡，也不延危机以制造机会。本节新自然危机明确在阶段五到期，因此due==当前轮仍可在行动阶段处理；既存危机按原真实执行阶段，不能被统一改到阶段五。

PR09的barrier_contact、PR08的contact和仪式本身无独立致命危机，不加一个“根due”替代请求的两/三轮窗口；原屏障/人物条件消失则当前资格失效。无独立危机的当前contact可直接从冻结快照中已有的人口/机构与当下求告生成call并fix，不需要先伪造认识邪神或一段外部危机。其他新外部根不能借此例外同批反灌。

**开局例外。** 世界初始化和合法机构/人口提交后，取一个独立bootstrap快照，固定无独立危机的当前无向PR08接触，visible=首轮，按原三轮窗口。从现有无名非信众提名一个当下愿向可能回应者献身的人，实际扣人口、预留P及PR08两支所需N；不继承群体旧知识/关系/见证。须实际验证浅触可执行及原费用足够；没有人口、容量或合法机构时整局初始化失败并说明原因，不以随机抽中PR09/12或伪造身份知识顶替起点。它保证一个合法尝试，不保证成功或首团。

实施接口由World先提交合法初态（deferred bootstrap），在所需正式能力安装成功后由`Turn.bootstrap_prayers()`进行0轮/0正式回执的独立事务；浅触准入以脱离的首轮行动视图调用原Prayers准备与Attention同一谓词，不支付、不投骰、不提前生成正式回执。成功事实`prayer_bootstrap`保存`{candidate,source,petitioner,faith,whispers}`，由`applied_authorizations[prayer/bootstrap]`唯一引用；首正式receipt仍从sequence=1开始，其fact_before在初始化事实之后。安装其他能力失败不通过这一步替换当前Session。

须预留未来成员的正式固定card保存内部`admission_token`，引用原Attention持久预留：owner=prayers、claim_key=prayer-candidate/<cardID>、source为原situation、people为固定actors、members为原政策nominees、persistent=true，focus和identities为空。预留按既有ID并集计数，不重复占同人名额；请求关闭时释放，成员转换仍沿原正式入口。完整及增量审计核card与预留，不允许删除token后把已承诺N当成空闲，也不能在关闭后残留令牌。本字段只为准入证明，玩家最小投影由INTEGRATION明确隐藏，与record_knowledge同属内部信息。

### 14.5 十二类的原根责任与合法空结果

机读单源为`prayer_origin_rules.csv`及`prayer_root_rules.csv`；rule是下表有限业务枚举，不解析中文、不允许自由脚本。每条允许两种求告模式，定向另查实际知识/本次意向。四模板的旧background_fixed仍可按§11规范，但新内容版本的call/采样证明不可省略。原回应成功产物可成为**后续**另一处境的输入，不充作其自身最初生产；不是每个新局、每个域都保证十二型齐全。

| 祈求 | 输入、当前规则及产物 | 明确不发生的反例 |
| --- | --- | --- |
| 01 rescue | ROOT_INITIAL_TIES先有真实初始family关系；ROOT_INJURY从当前祭仪/往来职责活动选择一名现存active参与者，发生本轮有限事故，写harm及绑定该patient/due的dying_condition；其已有活亲属才可求告 | 只有strain、没有当下事故或实际亲属，不生成救亲属请求；不能把support改称亲属或抽卡后补人 |
| 02 recognition | ROOT_DISPUTE选择已有rival/hostile关系且双方实际知道同一有效记录的现存人物；按§14.9在本次可运作解释机构发生record_interpretation争议，双方实际收到institution_stance后形成faction_conflict。人物可属不同机构，默认只沿该立场结案 | 只因稳定低、同域、同机构或普通support边，不造对手/历史压迫；对手死亡不换人；记录争议不自动授职位 |
| 03 concealment | ROOT_PURSUIT只据现存有效暴露：已具名order人物实际知道该记录且目标为同域活人，已有追查/敌对关系；本轮开始普通追查，绑定clue、relation及due | 高察觉、任意异常、未知目标或无关系，不造追捕；不替代六类既定抵抗计划 |
| 04 knowledge | ROOT_KNOWN_RECORD只读取该人物确实知道、仍未解释且有效的异常/暴露记录（record_source_view只是选择器，规范根始终是原记录）；可以来自本轮前的实际神迹/查证/例外观测，不另造一份初始神迹 | 全局存在记录但本人未知不出请求；知道记录不等于认识邪神；缺second仅禁深分支 |
| 05 belonging | ROOT_CURRENT_RITUAL：现存active的ritual_keeper在其有仪式能力的实际机构本轮发起当下祭仪，写ritual_context；将该次活动记录实际交回发起人，承续旧职责，不预置成功见证或信众。新知情接口由SOURCE-MEMORY接入，不能以原root写入推定索引已知 | 只有机构槽、匿名代表或无仪式范式/职责，不补祭司/旧祭日；同源不以successor重抽 |
| 06 obligation | ROOT_CURRENT_PACT：实际同域support/cooperation双方、一个他们均知且有效的现存记录、一处可达实际保管机构；双方本轮约定在该机构保留这份具体记录，写current_agreement及绑定obligor/counterparty/due的contract_obligation | 缺任一方、真实关系、既存记录或实际约定，不生成；不声称旧债、未写条款、全社会契约网络或已经履约 |
| 07 memory | ROOT_SHARED_OBSERVATION按§14.9产生现存关系人的本轮共同读取和逐人见闻登记，允许跨机构参加；ROOT_MEMORY_REVIEW只沿该处理机构实际收到的登记预告本次资格归并，写固定institution/registrations/holders的memory_at_risk。浅/深对象按原参加、关系和本次受审登记确定 | 无既存可读取记录、实际参与/登记、关系或当下通路不生成；不足三名非petitioner关系人关闭深分支；不回填往事，不撤远端私人记忆 |
| 08 devotion | ROOT_CURRENT_APPEAL只表达当前未绑定活人愿向可能回应者献身；无向标题/台词为“让我的声音被听见／若有谁回应，我愿替它发声”，有身份知晓且抽中directed才可称“你的口舌” | 当前献身意向不是已认识、已信仰或已入团；旧contact早于实际离团不能拿来重新入团 |
| 09 escape | ROOT_CURRENT_PASSAGE：现存本域活人正在同实际传播机构往来，或从当前非信众合法提名一个本轮通行者；本域屏障>0且有实际机构links/时空通路，写barrier_contact指当前barrier_source | 无通路、屏障已零、人物不在本域或拿另一人的接触，不生成；不自动给F/破屏障 |
| 10 judgment | ROOT_DISPUTE的同一实际争议；按§14.9固定原祭仪记录的真实发起人为relation_other，只揭示其与opponent之间、先已存在且祈求人未知的真实关系。争议资格边和待披露边分开；同一争议同一求告者只选其当前need的一型 | 揭示后才补关系、已知关系重复收益、无关第三人/无作者证明、任意人知道全机构秘密、没有实际争议都不成立；02/10不能为同一need复制卡 |
| 11 recovery | ROOT_ACTUAL_SEIZURE在真实Relics/抵抗夺取已存在实例后，向实际原活持有人发一份指该relic/当前captor的message；只读取原归属历史和本次实际扣押，并登记本人收到通知 | 世界里恰有seized圣物而此人无原持有关系，不造失主；无真实实例/扣押生产不能靠message自证物件存在 |
| 12 exception | ROOT_COSMIC_OBSERVATION在实际cosmic域、具名active记录者及可运作解释机构下作本轮有限“同位读数”观测；初次只产原exception与原观测者知情，不先给双节点证据。ROOT_COSMIC_RECHECK按§14.10对同一例外作另一节点的真实观察 | 玩家还未知该域不取消无向可能；无cosmic蓝本、无人/无职责或没有本次观测不出例外；只有真实成功回应/试验才产保留材料，定位传阅本身不是独立根 |

**根规则的具体输入边界。** ROOT_INITIAL_TIES唯一归TASK-SOCIAL-GRAPH，初始/首次展开的有限图算法、关系方向、预算和正式CSV唯一见文明规则§4.1及人物规则的对应合同。原固定support环与Catalog旧关系数量/责任校验已由初始化子批替换；正式两入口、控制样本与实际原profile结果分别验收，初始化自身不代验生命周期或自然源；当前图/恢复合同见文明§4.1及各本轮报告。图与祈求抽样分离，已有身份不重抽，匿名提名不继承群体关系。LOCAL-TIES只处理当下事故及已有亲属求告，不另写关系生成器。

current_duty_accident只生成本轮一个有限“仪式或通行中的受伤”事件，不模拟疾病传播/伤势数值；输入为冻结快照中现存active的ritual_keeper及其实际仪式机构，或messenger及其实际往来通路。这个handler在同一个新处境抽样中先声明本轮current_activity，再声明本次事故；活动不是另一次抽样，也不读取同批另一handler刚造出的ritual_context/barrier_contact。current_activity保存{subject,institution,type,route}，type仅ritual/transit，仪式route为空，通行route必须实际存在；harm引用该活动并保存`{patient,cause,activity}`，cause仅ritual_accident/transit_accident，随后dying_condition引用该harm，沿原病危到期/救治消费者。没有这一次当前活动不以低理智代替事故。current_interpretation_dispute的本次活动、固定字段和结案效果唯一见§14.9。current_specific_record_pact的current_agreement保存`{obligor,counterparty,institution,record,relation,term}`，term仅preserve_record；双方确实参与当前约定并各获该事实，contract_obligation父因果含它。以上都是有限事件规则，不声称模拟社会协商过程。

**事故的指定知情与无卡期限（五族实施合同，尚待接入）。** 事故资格只取上述当前活动，不先筛“有亲属的人”来制造求告。无活亲属或当下合法接触时，事故和病危仍真实发生，但不生成PR01；任务验收中“缺亲属时不生成”指PR01，不表示事故需要亲属许可。患者实际取得本次activity、harm、dying_condition知情。其余人物不因family边、targets或父因果存在便自动获知。

本次事故处理者只向一名现存同域active亲属实际发送指定通知：读取当前有源mutual family边，并复用§14.9的contact_context核本轮接触；按亲属人物ID、关系来源ID稳定取首个合法者，不补人补路、不遍历传播到整图。若有接收者，同事故事务在病危之后写`message`，actor为患者、targets含该接收者，changes固定`{rule,patient,recipient,activity,harm,condition,relation,contact}`，rule仅`current_injury_notice`；contact保留实际接触证明，直接父因果含本次活动/伤害/病危、原亲属关系及实际通路来源。处理者实际交付本次activity/harm/condition及通知本身给这名亲属；不交付这些事实的其他parents、其他关系或邪神身份。原源头保存实际通知及接收者，PR01须核本次病危已被该求告者实际取得，不能仅靠family成立。无接收者就没有通知/该求告头；不另消费一次B机会，不预置call、卡或成功。求告最早在下一冻结快照按A处理，同一原病危/人物/need仍为同一发生身份。

新五族的有期限危机在**原根出生时**由受管理来源内核登记独立到期，不等先形成call、固定卡或展示。Prayers拥有阶段五的到期执行；World来源内核拥有有源出生、当前头和原due登记，沿同一Turn事务交接。当前求告头、候选窗口、独立危机是不同状态：换头、分页、容量阻挡、撤F或请求过期均不删除/暂停旧危机。新阶段四根出生于T时，due固定为`T+2+对应prayers.lifetime-1`（PR01当前为T+4），不是从后来实际固定/展示轮重新计算。无卡病危仍在原due的阶段五按原kill_if_dying结算一次；due轮阶段三真实PR01救治可精确关闭这份condition并阻止其死亡，不关闭另一份独立condition。已死亡/实际解除的原危机幂等结束，不重扣人口。不得造dummy card、祈求人或descriptor来冒充独立到期登记。

这份独立登记须保存原root、类型、直接对象、原due、真实出生来源/事务位置及关闭结果；普通结算只读有限当前头和到期索引，完整恢复按原根/出生与实际到期或解决结果核等值。源索引清理不删除历史或未结due；异常回滚同时恢复根、知识、登记、随机位置及消费。追查、争议、义务和记忆风险分别由原源族接它们既定的到期后果，未接某类型时不得登记一个空成功处理者。已有旧根的真实到期语义不借本合同重写；完整Session与自然频率仍需对应任务验收。

shared_observation与current_witness_review的字段、实际参加及逐人登记/审查范围唯一见§14.9。共同读取仅是本轮普通见闻，不增加神迹独立根或记忆锚材；PR07真实成功后才沿原效果生产memory_preserved。记录白名单仍为此前已有ritual_context、有效暴露/异常记录、真实成功梦境记录或law_observation，不取prayer_call、future_callback、memory_at_risk自身或空message。

current_single_value_anomaly只在cosmic蓝本运行一个脚本化当前现象：实际记录者在本机构同一个本轮probe中取得互不相容的present/absent登记。目标law_observation保存`{institution,observer,probe,axiom_key,reading_a,reading_b,exception}`；axiom_key仅single_valued_archive，probe为本次稳定现象ID，reading_a=present、reading_b=absent。初次观察的exception为空串，随后exception保存`{institution,observer,observation,axiom_key}`并引用实际观测；复核观察的exception指既存原例外，probe沿用其现象ID，观察事实ID及实际观测行为另生。规则明确生成这次当下异常，不谎称引擎计算了宇宙法则。只有实际observer/本次所属机构取得该观测知情；他因此知道不一致，不自动认识邪神。这一原观察不是anchor_conditions接收的exception_record/exception_learned，不是双节点独立见证。PR12成功的原记录须绑定本次observation；深分支传播该记录不另添独立观察。第二节点自然复核及玩家试验的完整合同见§14.10；两个reading不能充两个锚材。

PR04的record_source_view白名单只取有效exposure、exception；prayer_fact仅取真实成功结果的anomaly_record/public_anomaly标签；miracle仅取真实成功POWER_DREAM且明确指向该原人物的梦境；law_observation仅取上述本次实际观测。future_callback、失败/到期、普通message、ritual_context或任意同名标签不冒充PR04异常。旧消费者接受范围须由ORIGINS同步，不靠通用prayer_fact放行。知晓与当前“未解释”资格均须成立，明确解释/撤销来源后不再以旧记录提案；规范发生键解到原独立根。

同一争议的recognition/judgment采用origin_rules.exclusive_group=conflict_petitioner：先以(规范conflict,petitioner)在当时真正合格need中作版本化稳定择一，持久登记selected_need再构造occurrence。两型都可时不同时生成；容量失败、身份知识更新、关切改变或换包装不为原争议重选第二型。原条件失效则结束该次资格，真实重开仍引用原need/call。

所有新处境规则用原4轮一次新机会预算，来源时窗只引用prayers.lifetime及原event_parameters/fidelity_parameters；没有新增概率、伤害量、费用或人口。规则行增多会改变合格内容池组成，**不等于已证明原节奏/抽到各型的概率不变**，首团/自然可达与完整平衡仍须下游实测。依DEC-022，不要求每局十二型齐全；但必要进展的机会不能长期纯随机缺失。旧“不能为凑锚点保证PR07/12必出”的限制撤回，后续以TASK-PROGRESSION-ROUTES的多路径与合法等待合同、TASK-OPPORTUNITY-SCHEDULER的概率修正/兜底实现为准；本轮仅规划，当前代码尚无该保证。

### 14.6 容量、可见性、版本与验收归属

正常空结果须区分`no_precondition`（没有合法当前条件）、`already_consumed`、`no_action_window`、`capacity_blocked`（分别标固定池/P/N/活身份/人口）、`not_sample_due`、`not_selected`；不存在已登记处理者/未接生产调用是`missing_producer`接入失败，不能写成合法静默。回执只记录规则、发生键、当前原因与原时钟，不占固定候选ID、不产生额外人物或奖励。容量满不抹掉世界原危机；失败不扣费、不挤旧候选、不延due、不换人/重抽意向，后续还有真实窗口才能再尝试固定。

神侧承接与展示分开：未固定的无向求告可以存在，但不向Session投影其后台世界全貌或人物名单。成功固定后，仅把该card必需的域身份线索、原祈求人、方向、已知诉求/可见危机交给玩家；未知域据此获得一个指定请求的有限线索，不自动揭示蓝本/机构网络/全量状态或取得F。ActionCatalog/Session消费相同固定descriptor，现有discover/knowledge接口须支持这一最小投影，不能为了列表显示宣布全域已知。若原响应需要目标域F，玩家仍须完成原合法发现/关注准入；无F只是该分支当前不可执行，不表示求告不存在。不新增UI表面；若现有界面不能表达方向/缺条件，列为UI下游，必须另走UI流程。

本次内容/能力版本新增持有者包括：Catalog四张新表/有限语法；World原根/求告当前索引、人物知晓取得与共享游标；Prayers的call/方向/采样证明、固定/回应/重开/危机；Powers明确身份信号与当前联系判定；Events指定告知/材料递交及后继；Turn同快照/默认期限/回执；Session/ActionCatalog有限投影；保存头、所有事实/候选/回执及续存游标。CULT-SAVE-COMPAT统一拒绝旧语义版本，不重算checksum把旧成功/旧contact洗成身份知晓。当前版本往返保存须保留人物、原call、方向、knowledge取得位置、发生键、源due、可见轮、消费/容量状态和独立随机流；切F/打开页面/保存继续均不重抽。

实施依赖：PRAYER-KNOWLEDGE接四类知晓、当下求告与方向历史；PRAYER-ORIGINS接两处理者、同源池/固定/容量及既有04/05/08/09；五个实施批次按`TASK-SOURCE-LOCAL-TIES`、`TASK-SOURCE-LOCAL-CONFLICT`、`TASK-SOURCE-CONTRACT`、`TASK-SOURCE-MEMORY`、`TASK-SOURCE-EXCEPTION`分别实现，SOURCE-CLOSURE只在各批完成后集成。具体源与消费的独立验收、下游接口和未实现清单见[本次设计报告](../qa/prayer-design.md)。PRODUCERS已将正式Events选源接到四类既有来源；其代码接入、限定行为验收与自然新局可达仍是三个不同结论，实际结果另见本批报告。


### 14.7 TASK-PRAYER-KNOWLEDGE的当前接线边界

prayer_knowledge模块接实际成功结果的辨认、受管理指定告知处理、稳定call语义及局部保存审计。Powers/Prayers实际提交写来源，World事务发布并维护有限当前投影；StateView按当前人物投影和指定ID查询，不展开历史知情者清单。Turn回执自schema2引入事务序号和事实半开范围，恢复据此核取得/采样位置；本轮RESTORE在当前Turn3扩充出生/首次展开核验，旧回执语义不自动升级。具体实跑及限制见[本项报告](../qa/prayer-knowledge.md)。

旧四BG来源在无Events的独立工具兼容路径中仍须明确标为legacy_source，该路径不证明已走本节call生产。DISPATCH接正式两模式调度和指定告知自动选取，PRODUCERS本轮接04/05/08/09原根到call、固定及展示/窗口，INTEGRATION接四格与最小玩家知情。重开只保留原call/方向和原期限，缺call的旧来源不得借重开伪装为新版本请求。本项不生成五族原根，也不为密教schema2消费者宣称可运行。

### 14.8 关键机会的多路径与等待保障（DEC-022，共通设计／尚未实施）

本节只冻结共享的目标身份、补偿、公平及实际供给合同。数值来源是 [opportunity_parameters.csv](../../data/opportunity_parameters.csv)；[progression_opportunity_goals.csv](../../data/progression_opportunity_goals.csv)只列十种目标及后续设计分工，全部为`design_only`，不是可执行路线。当前代码没有本节的状态、强制服务或完整管线证明；Catalog也尚未装载两张新表。三组具体路线设计仍须交付每目标至少两条不同触发/玩家行为的完整路径、其中的主动促成方式、实际输入输出/成本/风险/知情及唯一实现任务。仅改人物/卡名、复制同一独立根、重抽call均不算替代；本批不设计这些尚未交付的路线或新玩家操作。

#### 目标、缺口与准入

目标完成指真实里程碑，定义唯一见进度§12；出现一张卡不能完成“建立教团”或“锚点有效”。运行时目标键使用规范JSON数组：全局目标为`[goal_id,"run"]`，锚点目标为`[goal_id,domain_id,institution_slot_id]`。profile必须匹配目标行，每个真实机构槽只对应一种文明目标，替代机构继承原槽身份；不能因换护持者、重建、换路线或切关注生成第二个目标。

每个目标同时至多一个待供给的`step`。step是后续路线CSV声明的具体缺口，例如“获得下一份尚缺的真实材料机会”，必须关联目标当前缺失条件及真实来源；不能用无关浅触代替。`episode`是该step的一次供给周期，不是祈求call：只在原周期已实际服务/结束且生产者提供新的合法发生或原规则允许的重入时递增；既有call、intention、对象、occurrence和原due沿原来源固定。成功完成一个step只关闭该缺口，下一缺口依据真实状态另开周期；不将整个目标标完成。

登记active目标前，路线必须已冻结正式数据、实现生产者与入口，并提交一个共享纯查询返回的`delivery_contract`：`goal_key,step_id,route_id,producer_task,host_domain,occurrence_key,source_ids,subjects,nomination_plan,entry_id,mode,condition_versions,minimum_window,delivery_bound,proof_kind`。这些是合同字段，不是本轮已有的运行时对象。mode只允许`direct_action|bounded_pipeline`；entry_id在登记时可解析到已安装的ActionCatalog/Session处理者、入口类型及生成后绑定实例的规则，不要求待产card实例此时已存在/可见；实际服务时必须已绑定真实实例并出现在授权投影。proof明确哪一个合法分支能改变指定缺口、阶段/原期限/知情、真实费用与低语/回应/人物机会/F/N/P需求。未来才可能获得的收入、知识和随机成功不能算已具备。

**资格从真实生产输入齐备开始，不要求待保障的root/call/card已经抽到。** source_ids引用现存的生产输入及其来源，不得强制引用尚未生产的目标root；在合法生成前`occurrence_key`为空字符串，生成时按原规则绑定真实occurrence/call，随后的A/fix/服务全部沿用它，不能为等待器预写未来历史。已有具名参与者的subjects固定真实ID；若该正式生产者本来允许从无名池合法提名，生成前subjects可为空，但nomination_plan须给出当前真实人口组、profile、机构、原提名资格及F/N/P/身份容量证明。出生时由原提名事务实际扣人口并绑定身份/发生，等待器不预填未出生人物、不再扣一次人口。生产者不支持提名时不能用此分支补人。因随机未抽中PR12而没有exception/root，或合法匿名08尚未出生，均不能伪装成no_precondition来推迟启动债务；只有它们真正的生产输入缺失才属于世界/容量阻塞。

未实现生产者、未定义完整路线、entry不存在或没有管线证明是`missing_delivery_contract`接入失败，不能记成世界缺前提后无限等待。目标行本身不启动计时、生产人物或赋予材料。父TASK-PROGRESSION-ROUTES汇总验收必须覆盖全部十目标；未注册只是准确披露缺口，不能据此宣称保障已完成。

合法无指向/定向 × 重点/后台四格共享同一目标与债务合同。认识邪神或已获F都不是全部目标的共同资格；只有具体原入口要求的身份知晓/F/N/P才逐项检查。强制服务不改写或重抽call/intention、不自动授予身份知晓或关注；模式切换只改变实际可用入口与成本，不清等待。

#### 服务的唯一含义

`opportunity_served`只由Turn**真正进入actions**的受管理边界触发共享协调者写入。该边界在事件阶段结算之后，以当前状态调用与Session相同的授权投影、正式prepare和Attention/费用/行动机会谓词，必须同时证明：

1. Session当前确实暴露该固定请求或直接行动入口；玩家知情来自原合法来源，不能以内部存在代替可见。旧事件阶段、阶段四预测或阶段一冻结名单均不足以证明此时仍合法。
2. 至少一个明确分支在本时点能支付实际费用/低语，尚有回应及所需人物执行机会，并满足当前F/N/P和原对象/材料资格。不同可选机会可竞争同一预算，服务不承诺玩家能在同轮执行全部选择；每条都须以真实当前余额独立通过，不能先假定未来获得资金或释放名额。
3. 从本次进入actions到正常结束该actions阶段，原due及固定资格覆盖至少`minimum_action_windows=1`个完整窗口，且系统不会按更早阶段在窗口内收走它。之后玩家自行花掉资源、改变计划、移动对象或选择别的回应不追溯撤销已经给过的机会；必须留下该选择的真实结果，不能伪称未供给。自动世界变更若发生在进入actions之前，必须重新核验。

所有展示/preview都是纯读，不能顺便清等待、抽call或写服务事实。bootstrap的0轮独立事务及投影预检只证明原08已固定并通过预检，不产生正式回执，也不是本合同服务回执；第一个真实actions边界仍需重查。当前合法直接行动可以在该边界立即服务，不为“获得保底”再制造一张B事件。已经实际执行并提交成功的合法入口亦可由同事务写服务回执，但仅限actions阶段经Turn授权的实际提交，非actions后台调用不得使用此例外；它必须真实改变对应step或完成其已声明的尝试，不能靠预览调用数充数。

服务回执固定`goal_key,step_id,episode,route_id,entry_id,source_ids,occurrence_key,branch,turn,transaction_sequence,projection_version,eligibility_digest`及费用/窗口核验摘要。它表示一次可以采取行动的机会，**不保证回应成功、材料必得、锚点成立或最终胜利**。完成里程碑必须另读其真实结果来源。

#### 两段有限界限，不能把抽中当交付

共享队列不新增原槽位。B仍使用每域`background_tick_interval`（当前4轮）的一次新机会预算；A仍按§14.4每域一次已有合法根、原due等既定顺序处理。原固定池8、展示3、每轮回应1及F/N/P均不扩大，不挤掉已承诺候选，也不延长原危机。两个全局目标的当前step各只绑定一个host_domain，不能同时占多域B；锚点step绑定实际目标域。实际阶段若需更换host，须有真实路由变更来源、保留墙钟与漏选债，并作为新到达者排入新域队尾；不能靠在两域间切换插队或复制供给。

实例上界由既有有限世界推导，而非新增容量：`G ≤ domains_total*institutions_per_domain+2 = 12*3+2 = 38`；不是8种文明各再乘36。每域B队列至多`Q = institutions_per_domain+2 = 5`个当前目标step。尚未满足注册条件的表行不占队列；同一目标的多条路线先合为一个竞争项，不能凭路线数更多获得更多份权重。

普通阶段保留原新机会35% gate，正好沿原dispatch随机流使用一次；命中后，目标项权重为`base_goal_weight + missed_due_slots*missed_slot_weight_step`，基线为`1+missed_due_slots`，其余正常根族及身份告知各保留一份原基础竞争项。目标组与其所代表原根不得重复列入。选中目标后从其已冻结的合法路线中按路线合同选择；本批不填尚不存在的路线权重。落空、抽到其他目标/普通根/身份告知、未轮到查询页、可合法生成但未被选择，均保留该step并累计漏选，不能记作暂停。随机gate未中也消耗本次原B槽，不额外补一次普通抽样。

连续累计`forced_after_missed_slots=M=2`个合格但未供给的到期B槽后进入强制队列。强制项存在时，下一B槽先取最早入队且当前合法的项，不再经过随机gate；强制选择只绕过随机落空，不绕过任何物理/资源/生产/管线资格。入队序号单调增加，相同序号不允许，稳定目标键只作审计排序。**B派发票和服务债务分开：一次已提交的B派发消耗该queue_seq票，并写opportunity_dispatched；它不清债，也不算served。** 管线中的step不再占B；如其自身真实条件变化使管线失败，合法重试时领新的队尾票，保留started_turn、累计漏选/墙钟及原真实发生约束。后到者、已服务后的新episode、未服务但已消费过一次B票的重试者都不得插回旧位置。真正事务失败整体回滚时，原票/随机/来源一并恢复，不算已消费B。

`opportunity_dispatched`的`changes`最小结构固定为`{schema,goal_key,cycle,step_id,episode,host_domain,route_id,consumed_queue_seq,occurrence_key,pipeline_source,result_kind,result_sources,turn,transaction_sequence}`：schema为整数1；cycle/episode/consumed_queue_seq/turn/transaction_sequence为非负整数，其余除result_sources为事实ID字符串数组外均为字符串。goal_key为规范JSON目标键字符串；cycle/step_id/episode/host_domain/route_id须逐项等于本次派发对象。consumed_queue_seq记录实际消耗的正整数强制票；普通阶段尚无强制票时为0，不能用0消掉别的排队票。turn须等于外层事实turn，transaction_sequence须指向本次已提交Turn事务，且该事实落在对应正式回执的事实范围内。

result_kind只允许`source_produced|pipeline_admitted`。source_produced必须在result_sources列出本次真实生产的来源；pipeline_admitted必须由pipeline_source引用真实已提交的管线准入事实，可以尚无发生/人物/card。occurrence_key仅在原规则已固定真实发生时填写，否则为空字符串；pipeline_source没有对应事实时亦为空，不能填预计将生成的ID。无名提名或call/card尚未产生时按实际提交结果记录，不强制伪造已出生人物或已产卡；单纯抽中、预览或未提交的提议不产生消票证明。`causal_parents`去重引用本次真实生产输入、适用的原发生来源，以及本回执引用的实际生产/管线准入事实；所有父事实必须已存在，不引用本回执自身或未来来源。恢复审计沿这些绑定核对真实B槽、生产/准入结果及票唯一消费，拒绝跨目标、跨cycle/旧episode、错host/route或无源回执；last_dispatch_source不能只凭fact.kind同名就被接受。

**提交前失格不消耗整次可服务B槽。** 本例外仅用于本节强制FIFO的资格重查；§14.4普通随机失败不补抽保持不变，每次跳过不得再掷35%或推进随机流。A后继实际提交后，强制队列必须基于当前状态再次核验，不能照旧快照盲调一次handler就推进游标。本次B只扫描开始扫描时的至多Q张当前票，每票至多检查一次，按FIFO依次尝试当前合法项；若某项提交前返回正常`source_changed`且没有生产、准入或其他写入，则保留其票/债、记录跳过原因及输入版本，在同一槽继续下一项。不得为候补重抽call/intention；只在最终合法项的原子提交中产生本次来源与锁存。一次B最多提交一笔真实生产或管线准入，已有真实结果的handler不能再当“无结果失格”继续尝试。全部票当前失格时才按原空机会推进并记完整跳过审计，不造第三种派发结果/消票证明。任何异常、部分写入后失败或提交完整性不符须整体回滚该事务；正常失格返回必须无副作用。固定反例：X在查询时合法但每次提交前失格，持续合法Y仍须在同次有界扫描被检查，X不能用旧票反复占掉所有B槽突破Y的Q界；审计同时确认每槽仍至多一次真实生产。

对**同一host持续具有已验证可服务合同、无真实阻塞且不被玩家更改的step**，最坏到期槽等待是M次普通漏选加至多Q次强制竞争。因此从首次就绪的任意轮时点到B选中，保守上界为`B_bound = I*(M+Q) = 4*(2+5) = 28轮`，包含等到首个B槽的相位偏差。其前方每个peer至多消费一次B票，即使peer随后管线失败再恢复，也须排在它后方；不需要假设所有peer都稳定成功。动态新来者亦不得插队。28是按现容量得出的保守合同上界，既不是首团建议节奏，也不是实际供给已经达到的测量值；后续STARTUP-BALANCE仍需检验。

**实际服务上界必须另加被证明的管线界L：`service_bound ≤ B_bound + L`。** L不是填一个CSV正数就成立。bounded_pipeline须证明从选源到A固化、固定池/人物准入、可见/展示和真实actions的整个路径，在所有既存承诺及声明的并发负载下都能在L内完成。证据须列原A排序前驱/期限、固定/展示占用与确定释放、实际可行动窗口，及新到达者不会无限插前的规则；若使用预约，必须有独立受管理准入和保存合同，且不能覆盖原A优先、挤掉固定卡或偷增容量。该改动由路线组指派明确实现task；不默认为现有管线已经支持。

当前08/09同事务contact→call→fix通常下一轮可见，外部root通常T产生、T+1经A固化、T+2可见；这些只是最早时点。当前A可被其他更早due根占用，池8/展示3也可能阻挡，故不能把上述1或2直接当L。不能证明有限L的路线不得注册`bounded_pipeline`，必须由后续路线任务提供确实可行动的direct替代或明确改造管线。direct_action在完整actions边界已合法时不经过B，其供给界是下一次真实actions边界；若当前阶段已actions且入口仅此时新增，则实际执行可计服务，否则等待下个完整窗口，不能缩短原due迁就它。

数学静态检查只验证公式、实例计数和FIFO不插队；例如假设一个已经另行证明的L=2可算出30轮，但**该假设不是当前游戏有2轮管线保证的证据，也不是新的策划参数**。未来正式测试必须使用真实已实现路由，不以演算例或手工发卡替代。

#### 墙钟、阻塞、拒绝与再次发生

从一个合法step首次登记起保存`started_turn`及墙钟等待，所有未服务真实回合都累计；另外保留可服务计时、漏选B槽和精确阻塞区间。切重点/后台、切页、读档、失败重试和rollback都不重置它们。允许暂停可服务计时的只有下面可验证的真实阻塞，墙钟仍增长且恢复后保留已有债务：

| 结果/原因 | 计时与处理 |
| --- | --- |
| `blocked_capacity` | 指明真实池/展示承诺、F/N/P或其他已占用名额及其来源；没有已确定释放时点就不报无条件日历截止。原卡不挤出、不延期，恢复后继续原债务。仅“调度没选我”不是容量证据 |
| `blocked_resource` | 所有可用路线均缺当下费用/低语/回应或人物机会；列实际缺项，不预测未来收入。确定的轮初低语/回应恢复可用于下一窗证明，任意未来资金不可用 |
| `blocked_world` | 原主体失能/迁出、真实通路或材料失效等使所有合法路线均不可实施；保留精确来源。其他路线或合法促成入口仍可用时不准把整个目标暂停 |
| `missing_delivery_contract` / `delivery_contract_violation` | 缺生产/入口/管线，或注册的L/公平界失守，是接入/实现失败；测试必须失败并回归责任task，不能当游戏内缺前提无限挂起 |
| `not_selected` / `gate_miss` / `notice_competition` / `query_not_reached` / `a_not_selected` | 都不是暂停理由。已有证书的管线仍须在L内交付；A或分页长久轮不到表明证书错误，不能反复改成blocked规避上界 |
| `window_expired` | 仍结算原due，不重开或换人抽call；未服务债务不清零。合法另源/直接替代仍可用则继续，若原管线承诺已失守须报违约；真正对象资格损失才按blocked_world记录 |

全局固定池、展示位或玩家资源可能永不释放。此时没有无条件有限的墙钟上界；记录具体阻塞和累计墙钟，不能只展示“已暂停0轮”掩盖等待。相反，单纯源选择落空、A队列轮不到和分页策略不能利用这个例外。管线证明须将跨域共享8池/3展示的竞争一起纳入，不能只证明域内B公平。

实际服务后，旧episode记`served`并保留回执，漏选债归零。玩家明确拒绝用真实选择结果标`declined`；完整可行动窗口给过但未使用，在原窗口关闭后记`unused`，不伪称玩家点过拒绝。实际回应失败/灾变记`attempt_failed`，不撤销曾服务的事实，也不把失败结果改成功。后续周期至少经过`retry_cooldown_due_slots=1`个原host到期B槽，并且有新真实发生或原正式重入授权，才可重新排队；冷却不暂停任何已存在请求的期限。没有新发生时保持`await_new_occurrence`，不得由等待器制造新的献身意愿、过去关系或重试call。未服务前的短时失格不是新episode，恢复继续原债；玩家改选路线也不自动清债。

完成真正里程碑才记`satisfied`并关闭当前缺口。首次教团是历史一次目标；锚点后来真实失效仍用原目标键，以新实际失效来源开启恢复周期，不复制机构或重领首次奖励。终局一经结束停止全部供给。等待记录/强制队列/一个future due均不是有效接触：三轮断联只认进度§8已有的真实、确定有源接触计划，不能靠“正在等保底”续命。

#### 唯一状态、版本与验收承接

目标状态为`state.opportunities={schema,policy_version,data_versions,next_queue_seq,goals}`，schema=1；goals按上述稳定键保存。目标项保存`goal_id,domain,institution,cycle,status,completion_source,step`。当前step保存`id,episode,host_domain,route_id,occurrence_key,source_ids,started_turn,last_observed_turn,wall_wait_turns,serviceable_wait_turns,missed_due_slots,queue_seq,last_dispatch_source,block,pipeline,service_source,outcome_source`；queue_seq=0表示无在排票，已消耗票保存在last_dispatch_source所指的opportunity_dispatched事实中，不再参与FIFO；block只存当前原因/来源/起点，区间历史写不可变事实，不逐轮复制整个历史数组。pipeline保存真实证明/准入身份及原固定窗口，不能只放一个自报deadline。数值计数为非负整数，字符串引用须解析到实际对象；尚未生成的occurrence、未发生的回执允许明确空串，不得填未来事实ID。版本/字段/来源不匹配拒绝恢复，不能以默认0洗债。

`SET-OPPORTUNITY`由TASK-OPPORTUNITY-SCHEDULER的共享协调者通过World/Turn受管理事务唯一写入：B协调钩子记漏选/强制序号，真实进入actions钩子记服务，已提交结果钩子记完成/拒绝/失败。生产者只提交其真实来源与只读可服务证明，不直接改等待；Session/ActionCatalog只读与服务核验相同的授权投影。无需每轮倒扫所有事实：至多38个当前目标、每目标一个step，固定引用和当前索引读取；历史审计/保存恢复另行重建，不能把分页漏读当不合格。

新policy与两表、实际路线清单和handler版本一并进入Session内容版本。当前dispatch保存审计会复演原35%/均匀选源；实施必须同时迁移其tick事实、validate_state、随机流/游标、World/Turn事务与完整Session保存，不能只改prepare。旧档无本能力或版本不符须正式迁移或拒载，不静默添空债务。重试同事务/同服务键幂等；回滚恢复所有计数、排队/证明、随机位置和回执。导出与最小玩家投影不披露内部未知人物/材料；具体呈现/新主动入口由对应路线及UI任务承接，本批不改布局。

首团案例只说明：bootstrap08被固定不等于教团已成立，零信仰浅触仍要低语/回应及实际成员准入，尝试可能失败；后续路线须解决有源替代及合法断联窗口。CIV07案例只说明：第一节点记录出现不能服务“第二节点独立复核”的step，复制/转交同一根不能完成它；当前缺实际第二生产链时是missing_delivery_contract，不能靠提高权重或反复登记原记录解决。两例都不是本轮已完成的两条路线。

本批静态验收覆盖6项参数、10目标唯一分工、38/5实例界、28轮B公式、FIFO后到不插队、上述状态转换及证明义务；不执行第二份生产调度器。固定反例必须包括：Y持续合法，排在其前的X已获B后反复失格/恢复；X每次新派发须领队尾票，不能保留旧序号令Y超过Q槽，同时X的服务债不能清零。还须覆盖四格共债、未产root的合格生产输入、已消耗B票与rollback差别、锚点恢复沿稳定实例。后续三组路线设计负责完整条件/有限L或direct证明，父ROUTES逐目标汇总，不遗漏原ACC。SCHEDULER实施须正常对照先过，再隔离去掉补偿/强制机制、伪造服务/暂停/清债或管线短界，使预定**行为**断言失败；编译/加载失败不是该负例。SOURCE-CLOSURE核实际来源到交付，CULT-SAVE-COMPAT核完整Session续存，NATURAL-VERIFY区分自然样本与受控最坏抽样，STARTUP-BALANCE/BALANCE再评价实际节奏与拖延利用。任何未接入路线、容量阻塞和证书失效均须单列，不能从静态公式推称游戏已有供给保障。

### 14.9 具名关系网与跨机构互动（DEC-023，设计合同／尚待实施）

本节冻结SOURCE-LOCAL-CONFLICT/MEMORY的生产与消费合同，不改变既有费用、人数、求告意向、期限或一次回应规则。图的生成、关系类型和当前查询唯一见文明规则§4.1及人物规则；记录争议不再承担任职。World图初始化、关系生命周期与严格恢复已按文明§4.1接入，实际限定验收见整支新报告；原根生产、PR02旧succeed执行、EVENT06/09新路线语义及相应恢复审计仍由各归属任务完成，图分支不代这些下游。

#### 共同的关系、接触与记录边界

`relation_between(a,b,types)`只读取当前有源关系，尊重类型的方向/互惠，不把同机构当关系。`contact_context(a,b)`复用图合同：双方active、同域，机构存在、可运作且仍是各自实际归属，且同机构或当前两机构相互links连通；返回`kind,institutions,channel_sources`。关系不替代这个接触条件，初始social_contact不证明本轮已经会面。下述handler实际执行一次已声明的当前共同活动，才产生当次参与/接收事实；候选预览和只读查询不生产它。涉及的关系、原记录、人物status_source及channel_sources列入原根直接父因果，固定双方当时机构；提交前重查本批死亡/迁出/通路撤除，正常失格不补人补路。

参与者的当前机构、处理机构和材料所在结构是三件不同的事。祈求descriptor.institution只标本次处理/审查机构，不能通用要求petitioner.institution与其相等。仍须核同域、机构本次职责及真实知识；不会因为取消同机构限制而跨域施法。原人实际获得指定本次事实，不自动获得其parents、其他成员知识或邪神身份。

#### 记录争议 → PR02/PR10 → EVENT09

`ROOT_DISPUTE/current_interpretation_dispute`只生成`record_interpretation`：两名现存active人物有当前rival或hostile关系、均实际知道同一有效具体记录，且contact_context成立。资格接受rival的mutual边，或hostile的a→b/b→a任一真实方向；一方敌意足以作为本次对立背景，但不推定另一方也敌视，不回写互惠边。处理机构取双方真实所属机构中可运作、实际知道该记录的interpretation机构；没有则本次无来源，不新建审批机关。两者均合格时按稳定机构ID选一；参与人物身份不改变。双方就这份记录在本轮发生立场冲突，处理机构采用其本地参加者的解释作为本次默认立场；同机构双方均是本地人时按稳定人物ID选一。`favored`固定该实际参加者，不另投骰，不授予未来职位、资源或普遍判断权。

- `institution_stance.changes`固定`{schema,kind,institution,record,parties,favored,relation,contact}`，schema=`cross_institution_v1`，kind=`record_interpretation`，parties是两名不同原人物；contact保存原contact_context值，institutions与parties顺序对应。世界在同一受管理事务中把该stance明确交给双方与处理机构；不是仅因targets或父事实存在而推定已知。
- `faction_conflict.changes`固定`{schema,kind,parties,institution,default_stance,due}`，default_stance指上述实际stance，父因果含它、原记录及关系/通路依据。双方实际获知后才发布此根；求告选择及02/10互斥继续用原conflict/petitioner一次键。一个原conflict不能因为换institution包装再出一次。
- PR02/PR10仍以`facts.relation,conflict`绑定原事实，不新增自由资格布尔。PR02的rival、PR10的opponent均为原另一方；PR02的facts.relation是default_stance.relation资格边。PR10额外固定`subjects.relation_other`为本次争议记录的真实祭仪发起人：本版只接受`record.kind=ritual_context`且`record.actor=record.changes.subject=relation_other`，不把任意record.actor推称为作者，不扩展到无保管证明的“持有人”。此人须是与争议双方不同的现存同域active人物。披露用facts.relation则是opponent与relation_other之间、本轮争议前已存在且仍有效的relationship/initial_relationship事实，尊重原方向，且祈求人尚未知。候选先筛这些真实边，再按稳定来源ID固定一份；三人actors固定为petitioner、opponent、relation_other，计入既有上限4及真实P/N准入，不创建第三人或关系、不删除已有知识来凑候选。无合格披露边时只可进入PR02；同一conflict/petitioner仍只消费原一次键。
- PR10浅触的收益是把该固定relation交给祈求人。生成、固定及执行前均核祈求人尚未知；固定后经别的合法通路已知时，该回应不再可执行，不换新秘密、不收费，原争议仍按原期限处理。深分支沿同一固定披露对象公开，不能以同源已公开包装重复取益。`knows_disclosure`必须是对手实际获悉本次披露；知道原关系本身不等于知道它被揭示给祈求人。私下learn不自动通知对手，深分支也只让有实际接收来源者获悉，不因public标签全域广播。原CSV的learn/record/condition词汇不变，SOURCE-LOCAL-CONFLICT同步实际资格、消费语义和来源审计。
- 两型到期均只按原default_stance写`dispute_settled`并失效该conflict。PR02成功沿既有规则解决该次争议；PR10成功后的争议仍按原到期/事件状态处理。没有任命、自动转籍或新增数值效果。真实职位空缺/继任保留EVENT03专线，本条不调用World.succeed_institution；死亡/迁出也不换另一人继承本次诉求。
- EVENT09的顶层institution继续指原处理机构，cooperator仍是原petitioner、opponent仍是原对手；`facts.relation`固定原stance.relation的争议双方资格边，另增`facts.disclosure`保存原PR10确实披露的关系事实。不能把opponent与relation_other的关系当成cooperator与opponent的合作/敌对资格。原PR10 descriptor完整保留三人和披露对象；relation_other仅作为历史披露来源，不自动成为EVENT09的现行参与者或材料提供者。`cooperating_institution`固定原cooperator在事件固化时真实所属结构，可不同于处理机构。新增`facts.cooperation_context`引用原PR10结果之后、事件固化事务中的受管理`event_cooperation_context`事实，changes固定`{schema,cooperator,institution,status_source,institution_source,affiliation_source}`，schema=`cross_institution_v1`；institution_source为该真实结构来源，affiliation_source为原人物最近一次有源提名/真实继任等实际归属依据，不能拿机构存在或人物仍active代替其归属证明。父因果含原callback、relation、disclosure及三项来源。该事实只证明固化时身份/结构，不颁发材料或关系资格。09A还须按§13.2由该结构实际供给固定material、recipient及contact_path；没有材料增量只留合法B。提交时重查合作者仍在原结构、原材料与接收途径，失格不把固定结构改成另一个。恢复历史只核固化时事实及原来源，不用合作者今天的归属倒写历史；当前可执行性另查。

PR10不以先有PR10/09才能产出的敌意自举。一个正式来源链是：允许祭仪的域内，A为order的NPC_PROFILE_05（有judgment），B为interpretation的NPC_PROFILE_01，C为同一interpretation的NPC_PROFILE_02；机构实际相互连通。初始图中A与B沿共同knowledge关切形成rival，祭仪者C分别与A、B有support。C的真实ROOT_CURRENT_RITUAL产生原ritual_context并同事务交回C，C主持下述共同读取，A、B和承办解释机构实际收到这份记录。A与B随后发生本次记录争议，C与B的已有关系仅其两端知晓，A尚未知；A真实选择judgment时，故可绑定C为relation_other而揭示这份边。共同读取只交付指定记录，不连带告知C的其他关系。此为有限规则的可达正例，不保证每局具备该三角/职责/通路；SOURCE-LOCAL-CONFLICT须用实际图、祭仪、共同读取来源跑通一次首次PR10，并验证缺一项拒绝，NATURAL再验新局发生。该链的共同读取生产归SOURCE-MEMORY，不能用注入一条“未知关系”替代。

EVENT09的affiliation_source沿文明§4.1区分身份来源：初始人物使用真实world_origin及该人物初态机构归属快照，后提名人物使用真实nomination及其机构字段，后续归属变化引用实际变更来源。不能要求所有人都有nomination，也不能单靠人物active或机构存在代替归属；固化时来源与当前执行重查分开。

#### 共同读取与登记 → PR07 → EVENT06

`ROOT_SHARED_OBSERVATION/current_joint_record_reading`的活动明确为本轮共同读取并向承办机构递交本次见闻登记。发起人petitioner必须active，真实属于可运作的interpretation机构并实际知道指定白名单记录；在本活动事务内先按现有合法share_record条件向该机构递交此指定record，已知则幂等，不以机构全知跳过递交来源。其余参加者从现存同域active、与发起人有当前family/support/cooperation关系且contact_context成立者选取，保持候选人数上限；host本人加至多三名真实关系人。family/cooperation只接受mutual，support接受host→person或person→host任一真实方向作为本次邀请的关系背景，不把它解释为双向承诺；实际参加仍由本handler记录。负向关系不自动当作共同读取邀请。选择及人数沿有限图/来源规则，不因深分支缺人补边或补人物。

`shared_observation.changes`固定`{schema,institution,record,petitioner,participants,relations,contacts,registrations}`，schema=`cross_institution_v1`。participants按petitioner在首、其余稳定人物ID排列；relations与contacts各按其余参加者逐项保存`{person,source}`和`{person,context}`，context为该人与petitioner的实际接触证明。registrations逐人保存`{person,institution}`，只记本次确实提交见闻登记的participants，不能从现存成员/机构知情反推。该handler的当前活动包含上述实际登记，不建立自动递交日常职责；原知情发起人向实际参加者交付这一个可读record，参加者获得该record与shared_observation本次知情，实际接收登记的institution获得该观察知情。交付只含该record，不递送其parents、发起人的关系或其他知识；不增加原神迹独立见证、记忆资格或人物身份。

`ROOT_MEMORY_REVIEW/current_witness_review`只在本域communication=network、原institution仍可运作且有interpretation职责、实际知道该shared_observation时处理其现有登记。`memory_at_risk.changes`固定`{schema,memory,institution,holders,registrations,due}`：memory指原shared_observation，holders是本次受审的实际登记人；registrations保存原观察中的对应`{person,institution}`项，不另创授权。其直接父因果含原观察及该机构实际接收/当前职责来源；实际给holders和原petitioner本次预告知情。未登记者、其他机构自己的登记、私人知识不在此机构的作用范围。人数不足时只允许原浅分支；没有合法非petitioner关系人则不生成PR07，不以机构全知补齐。

PR07的`facts.memory,relations`、subjects与人物顺序保持原合同。memory_people只能从原holders中取实际参加、仍满足关系/当前资格的非petitioner人物；浅触固定首人，深分支三名，不受他们是否归属同机构限制。回应产生的每份memory_preserved继续绑定`original=原memory_at_risk`、`memory=原shared_observation`、原人物及descriptor.institution；这个institution是该份本地见证登记的处理范围，不表示人物转籍。知识、原观察、登记和该份见证资格分开保存，递交不能复制原参加或三人资格。

到期按原根逐人写memory_qualification_lost，仅影响该`risk/person`的本次未保持登记资格；不删除known_facts、关系、身份知晓，不撤同一人在另一根/另一机构的独立资格。原代码已经保留私人知识，本批要补的是跨机构登记/审查范围核验，不宣称修复了一项“删除私人记忆”的旧行为。迁出或换机构不把原登记转交新机构；原机构可结清它已掌握的这份登记，不能因此作用于人物后来获得的材料。死亡只使原人不再提供活见证，不补人。

EVENT06新增`facts.review=原memory_at_risk`，顶层institution固定review.institution。witnesses保留原PR07的固定memory_people；qualifications仅取该次真实PR07已产生、仍沿同review、同memory、同人物登记的memory_preserved。浅成功只有首人资格，不收集其他请求/机构的材料来凑数。A只维持这些已有本地资格，不能给缺席者发资格或另做全局机构认可；B只选择并撤一份本次机构有权处理、当前仍有效的固定qualification，按原表结算一次。没有合法资格时结束该事件，不执行其数值收益/代价，不换远端资格；故不会用空审查领取B的稳定收益。实际选中资格、review及来源进入结果/撤销父因果，默认亦按同一合法固定集合选择，不扩大范围。

#### 固定、保存及独立验收

新字段优先放具体原根changes，PR02/07/10的prayer descriptor facts白名单不变；PR10的subjects白名单新增必需relation_other，actors及原始登记/重开/调用绑定必须包含该原第三人。EVENT06新增review、EVENT09新增disclosure/cooperation_context，必须同步事件schema、roots/source_ids、固定/结果/恢复校验及内容/能力版本；未更新的调用者拒绝，不能默默丢字段或从当前人物归属重建原处理范围。新原根的schema、参与机构/接触来源、登记人、review、原due、call与selected_need都随同一事务保存；既有老夹具可保留为显式历史测试，但不作为新合同的合法生产者。图当前/历史来源、祈求发生键、卡片/令牌与期限维持原一次性语义。

SOURCE-LOCAL-CONFLICT须改生产、Prayers当前检查与expiry、EVENT09固定/执行和历史等值审计；不能仅删除生成端同机构判断，也不能让通用person.institution==descriptor.institution过滤处理机构。SOURCE-MEMORY须接共同读取/指定记录交付/登记、review的逐人范围、PR07浅深与到期、EVENT06资格筛选/默认及恢复，并补ROOT_CURRENT_RITUAL把自身当次活动记录实际交回发起人的知情接口；当前只写root的旧生产不算完成该接口。首次PR10的完整生产验收以前者实际交付为前置，不以注入知识替代。ANCHOR-ROUTES仍按材料合同核实际carrier，不因审查机构拥有登记就把全机构或其他人物变成见证者。必要玩家投影只表达本请求的处理机构与固定对象，不展开社会图；PR10回应前只可说明涉及原祭仪发起人，不能因新增subject/actors提前展示那条待揭示关系、类型或第三人的完整资料。新增可见字段须沿既有UI流程接入，SOURCE-LOCAL-CONFLICT与最小知情投影一并验收。

独立验收至少包含：不同机构的有源对手双方真实获知记录与立场后可进入PR02，PR02到期任何岗位/归属不变；PR10仅沿原祭仪记录的真实发起人及其与opponent之间、先已存在且祈求人未知的关系，浅触产生知识增量，重复已知/资格边/无关第三人不合格；固定后已知则不收费不换事实，知道原关系不触发“获悉本次披露”敌意。首次PR10按上述既有初边与本轮记录交付链取得来源，不借PR10自身闭环；原三人、关系方向和披露不在预览中提前兑现。原处理机构与EVENT09合作结构不同仍准确固定，合作者迁移后旧事件不改结构。四名跨机构关系人实际共同读取/登记后可进入PR07深分支与EVENT06，浅成功只保留首人；未参加、未登记、无关系、无通路、未知记录、过期/失效来源均不生成或按原范围结束。撤本地资格不影响另一机构独立资格及私人知识；无合法06资格不发数值收益；完整保存/重试/回滚与F切换不重写身份、登记、方向、原due或重复消费。原SGPLAN只证明规划时方向与责任已登记；本批设计/CSV是新交付，运行行为和自然可达分别留给实施与下游验收。

#### PR03精确关系撤销的实现交接（TASK-SOCIAL-GRAPH-RELATIONS，本批实施合同）

PR03深干预成功只终止原追查实际引用的精确关系episode，先由实际_apply_rows发行`pursuit_relation_withdrawn`回执，再经World唯一writer核本笔attempt/check/原pursuit。最终prayer_result在后续同事务闭合，不能反向作为尚未出现的父。重复回执不能撤后来新head；普通来源无退休权限。原追查关闭、线索浅触、任职与机构支持作用范围不改。原PR10/EVENT03/EVENT09各自真实业务proof一次绑定关系episode，命中既存head也消费，旧结果不能在退休后再建边。精确schema与消费键唯一见文明§4.1；不据此称自然来源或完整Session已接通。

### 14.10 Axiom, Network, and Manifestation Routes：有限主动试验与独立复核（设计合同，尚未实施）

本节与文明§9.6、进度§12.1共同定义本批六条路线。[progression_routes.csv](../../data/progression_routes.csv)是路线索引，[progression_route_operations.csv](../../data/progression_route_operations.csv)是五个新增操作的数据源。自然复核另在[progression_route_sources.csv](../../data/progression_route_sources.csv)登记唯一ROOT_COSMIC_RECHECK。三表均为`design_only`，当前Catalog/Turn/Session尚未读取，不能因表内`direct_action,0`声称游戏已经有这些操作。这里不新增通用社会模拟、随机救援、宇宙物理求解或机构许可。自然来源仍由原SOURCE任务实现；新增主动操作须由单一`TASK-PROGRESSION-OPERATIONS`实现后才可注册，未安装处理者属于§14.8的`missing_delivery_contract`。

#### 14.10.1 共同执行边界与直接交付证明

**封闭命令schema。** Turn入口为`act(participant="progression_routes",payload)`，对应ActionCatalog的entry_id等于操作CSV的id；本节是目标接线，不声称现有Turn已注册这个participant。payload共同必填`operation,domain,institution,actor`，均为非空实际ID字符串，operation须等于本次entry_id。仅可选`preparations`，为去重的真实准备事实ID字符串数组，缺省为空；不可传费用/概率/结果/当前资格/observer/participant列表替代真实计算。request_id、expected_revision等事务字段沿原Turn外层信封，不混入业务payload。每行仅再允许下列字段，所有未知/多余/同义字段、null、错误类型、重复ID、跨域对象均在支付前拒绝。

| operation | 除共同字段外的必填字段 | 对象绑定及禁止猜测 |
| --- | --- | --- |
| ROUTE_GUIDED_DREAM | 无 | institution=actor当前所属槽；本次联系由真实活动产生，不接受自带contact或任意梦境源 |
| ROUTE_AXIOM_PROBE | 无 | institution=actor当前所属CIV07槽；真实观测内核选择该槽当前例外头或创建本次例外，不接受caller指定另一例外/旧probe |
| ROUTE_AXIOM_RECHECK | exception,source_person,other_institution | institution=复核者actor的槽，other_institution=来源提供者source_person的不同槽；两人不同、真实双向links；source_person实际知道exception，actor在同一原probe作自己的观察。不可将source_person别名为peer或把接收机构反填为来源槽 |
| ROUTE_AXIOM_REPEAT | exception | institution=actor当前所属槽；actor确知此例外；所选历史use只由当前有效头确定，不接受caller自己给uses/turn/count |
| ROUTE_NETWORK_EXCHANGE | other_institution,peer | institution=actor槽、other_institution=peer的不同槽；同域不同人物与真实双向links，signal/trial/endpoints均由实际事务生成，不接受预制成功回执 |

字段exception/source_person/other_institution/peer均为非空实际ID字符串。玩家可选择的来源只取其已有授权投影；人物是自己的信徒不表示玩家自动读取其全部known_facts。PROBE无需提前选择隐藏例外，只有执行后的真实取得才开放相应来源。所有描述符同时固定原机构/人物，正式提交时若迁出/换籍/源失效则拒绝，不自动改成新所在地。四个新试验的准备目标由共享核心使用规范JSON数组`[operation,domain,institution,actor,exception_or_empty,other_institution_or_empty,partner_or_empty]`生成，其中partner为source_person或peer；PROBE的exception_or_empty固定空串，不因执行中形成新例外换key。GUIDED_DREAM例外：只沿原POWER_DREAM的目标与原准备合同，不使用新数组别名。准备只接受已明确绑定对应目标的原谕言来源；缺省不带准备，不由参数填写任意加成。

玩家只能在actions通过受管理Turn入口执行。共同输入为真实本域active、已bound_member且忠诚达到原`loyalty_follower_threshold`的实际参与者，其本轮执行机会未用；每人的institution须为真实本域槽。成员绑定提供当下可以下达有限活动指示的现实联系，不使玩家全知该机构，也不把这条新活动联系追认为过去的POWER_DREAM资格。操作对象必须是玩家已知的这些成员及其所属槽；旧固定祈求可继续走原入梦，不被本入口替换。

同域操作均取得该域F；所有实际参加者按原N/P去重声明，在输入齐备的正式成员场景无需新增P/N，不创造人物、不扣无名人口、不占固定池、不借回应次数。每名实际参加者都占用本轮人物执行机会；不同操作也不能让同一人重复工作。先共享纯预览核当前身份、知识、关系/links、冷却、成本与Attention需求，再由Turn按最新版本重查、原子预留/支付/检定/落事实；无资格不收费不耗随机，事务异常整体回滚。失败与灾变支付成本及人物机会，不生产成功材料，不替换对象。

五个操作在完成上述安装及Session授权投影接线后，当前真实输入齐备就能通过稳定`entry_id`直接查询和执行；动作不等待B新根、A固化、3张祈求展示或8固定池。Session必须按目标/成员直接提供该entry，不得把它藏在前三条随机推荐后，也不得用页面查询写服务状态。Turn进入actions的共同授权投影据此登记实际机会；本轮中才取得新材料而出现下一步骤，只在实际授权执行时记同事务服务，或留到下轮完整actions窗口，不以一次瞬时预览冲债。故**每一当前合格步骤的额外交付L=0**来自没有中间队列和真实可执行入口；不是保证整条路线零轮完成，亦不是保证检定成功。物理输入、资源、F或成员机会不足按§14.8记真实阻塞，下一轮只可确定性恢复原行动预算，不预测收入、招募或随机材料。

`ROUTE_GUIDED_DREAM`完整调用原POWER_DREAM结算：费用、原冷却、四档概率、效果、准备及明确辨认邪神的知识生产均复用原表和正式处理者；不得同时执行一份新数值。唯一区别是执行时先由该实际信徒参与一次当下受梦活动，获得仅供本次嵌套入梦使用的`guided_dream_contact`，与付款/入梦一同提交。该来源不发祈求卡，不授权以后免费联系，不是新神祇知识，失败仍保留本次真实活动历史。普通入梦入口的旧联系规则保持原义。

其余四操作`cost_rule=prayer_deep`精确复用原深干预低语/信仰成本，`check_rule=occult_adaptation`使用原适应属性/超常检定、层级难度、屏障、察觉、准备上限和四档边界；主执行者为输入actor，不能临时换高属性人。准备只接受上表规范目标键的真实未消费谕言，扩展POWER_ORACLE目标白名单、prepare/授予、消费、内容版本与恢复文法由共享核心负责；不从payload填加成。GUIDED_DREAM将同一个合法准备来源交原POWER_DREAM执行一次，不能在外层和嵌套层重复领取或消费。始终每名参加者扣CSV的理智并按CSV增加本域察觉；成功/深成按CSV加污染并产生下述一份有限结果，深成不倍增事实/独立性；失败无成功材料。灾变在始终成本之外，对主执行者追加原`prayer_disaster_sanity_loss`并追加原`prayer_disaster_alert`，不随机杀人。四操作给每位实际参加者分别登记`(operation,person,scope)`冷却：probe的scope为该机构，repeat为该机构/例外，recheck为例外/稳定排序机构对，exchange为稳定排序机构对。scope用规范JSON数组编码；原“1”表示下一完整回合不可重做。首次probe从无exception到新ID不换冷却键；互换actor/peer、改请求ID或来源包装不让原参加者提前重复。没有下一步所需对象时不会授予临时豁免。

#### 14.10.2 CIV07：真实第二观察与单节点持续使用

稳定异常以原exception事实ID标识，`probe`沿原观察指向同一当下现象。初次生产仍是本轮有限的present/absent矛盾观测，非旧事回填。`ROUTE_AXIOM_PROBE`只在CIV_07的成员实际所属槽执行；该槽/axiom已有有效exception时沿原ID并作本次新的实际law_observation，不反复生新异常规避后果；即使actor此前不知道，也只能在本次真正观测后取得知情，预览不泄漏该隐藏来源。没有时，在付款后同一事务由受管理观测内核生成本次law_observation及exception。失败可留下这次已经发生的异常，但没有保留材料；第二次试验必须沿它继续。成功增加绑定本次观察的`axiom_record`，observer是实际actor，只该人及其实际槽获本次观测/记录知情。该有限异常内核允许自然SOURCE-EXCEPTION与主动入口调用，事实写入仍只有一个拥有者；主动试验不占或推进B游标。

双节点路线的`ROUTE_AXIOM_RECHECK`固定`source_person,actor,exception`。source_person是实际知晓例外的本域合格成员，actor为另一真实机构的合格成员，两人不同且两槽实际双向links连通。source_person当下提供定位信息，actor在自己槽对**同一probe**重新执行观察；这次读取产生自己的law_observation ID，之后成功才形成自己的axiom_record。两人均真实参加并消耗执行机会；source_person可以保管原记录，但不因帮助复核多得一份独立记录。复核者先取得本次有限定位信息，成功取得自己的记录，不继承前一人的整本知识/关系或神祇知晓。两节点的材料必须由不同观察者的不同实际观察支撑；仅PR12深传播、材料递交或两个标签包装仍是一根。

自然第二节点由`TASK-SOURCE-EXCEPTION`新增有限`current_same_exception_recheck`处理者：输入为另一active记录者（实际record_keeper或investigator身份）、另一连通机构和仍有效probe。个人已知exception时须有真实取得来源；若只有本机构实际留存的PR12公开例外材料，则须在本次活动中由实际属于该机构且具有record_keeper/investigator职责的现存人物读取这一份指定记录（不额外要求官方代表职位），写`exception_reference_read`及个人learn回执后才能复核。该读取只给本次exception及定位，不给parents/神祇身份，不以机构已知直接跳过个人取得。普通成员、未实际收到材料的节点及无真实职责者不能借此读取；原PR12只写机构知情时本身不足以让人自动知道。机构公开材料与私人合法递交都是具体输入，不靠空message补齐。它占本域原B一次机会，记录当下复核law_observation，保留同一exception，最早由下一次A对这位观察者生成独立call。PR12的规范发生键改为`(exception,observation,petitioner,institution)`；call/descriptor/basis锁定这个实际观察，知晓邪神只影响本次方向选择。每人/例外只有一个未结当前复核头；已有自己的合格保留记录则不再为了凑独立数生成，同一观察已消费不复制卡。第一次PR12也显式绑定原exception.observation。原PR12浅成功和深成功材料解回这个观察；深传到另一机构仍不是那里进行的观察。ROOT原注册表/词法、原根索引、调用模式、PR12消费及存档审计由该任务一并迁移。本设计不宣称随机B/A链已有有限交付界，正式保底使用上述主动入口。

单节点路线`ROUTE_AXIOM_REPEAT`只要求同一CIV_07槽内一个实际知道该exception的合格actor。每次真正执行一个有限档案使用：用同一probe的互斥两值分别完成本次写入与取回，生成本轮`axiom_use`；失败不能算使用。达到CSV `repeat_turns=2`个不同回合的成功使用后，生成绑定这两次使用的`axiom_dependency`。这表示此处真实保存的成对记录仍依赖该例外才能共同成立；不是整个文明改写了基础物理，也不自动修复屏障。其保管者须实际参加这两次使用、当前仍在该槽active并知道所选使用。可用一人完成两次；不同的人接续须各自具有两次使用的实际保管资格，不能用转交把没参加的人变成操作者。初次probe或一次PR12不是一轮档案使用，复制一条use不凑两轮。此路线不要求other_institution、通信、第二观察者或EVENT11；较多轮次/试验费用和单点承载风险替代第二节点门槛。双节点失败不会自动赠送两次use。

#### 14.10.3 CIV05：独立受梦与实际双向应答

独立受梦路线在两个当前连通槽中，由两个不同实际成员分别执行`ROUTE_GUIDED_DREAM`；两个真实成功POWER_DREAM的miracle各自独立，原见证人各在自己的槽实际保有该梦境。原合法固定祈求联系上的POWER_DREAM也可提供同类材料，不要求先完成本节新增动作。梦境事实只在真实成功后产生；同一人两次入梦、同一梦境转抄或PR04披露不成为第二节点独立受梦。该路线不需要异常往返协议。

`ROUTE_NETWORK_EXCHANGE`则固定两个本域CIV_05不同机构的合格成员`actor,peer`，两槽须当前实际双向links。两人当下发出、接收并回送一组按本次事务唯一标识的异常读数；这是本轮有限脚本活动，不假定之前有集体梦境或往来史。成功时在同一事务形成两个`network_endpoint_use`和一份`network_dependency`：起点确实发出并校验回送，终点确实接收并以该异常读数完成回送。两端各保有自己的使用事实及本次依赖，两个对象及原links作为实际输入固定；这些记录**不标为独立起源**。材料依托是两个节点现在分别保有相互依赖的成对结果，沿当前links仍可对照，不是把同一证言递交两次。失败不形成可用依赖；只有参加者及其各自槽获得自己端点/本次依赖的知情，不使其他机构或NPC获知。与独立入梦相比它不加忠诚、两人均付理智/机会并有更高明确暴露；无论选择哪条，保持通信及两端实际承载是该文明网络机制的共同物理条件。

#### 14.10.4 事实字段、生命周期和实施责任

新facts的外层仍使用原`id,kind,turn,domain,actor,targets,causal_parents,changes`。以下changes全部字段必填；`schema`为整数1，人物/机构/事实/操作ID及probe为字符串，`participants,uses,endpoints`为字符串数组，空串只允许明确无既存例外的law_observation.exception。每个来源必须是真实已提交或本事务更早暂存的事实，不允许自引用/未来引用；一次事务的新观察/记录由引用顺序原子发布。

| kind | changes固定字段 | 父因果和当前意义 |
| --- | --- | --- |
| route_trial | schema,operation,institution,actor,participants,input_sources,outcome | input_sources为事实ID字符串数组；outcome为实际统一四档结果。引用真实成员来源、例外/传播或活动输入。不是材料、知识或成功许可 |
| exception_reference_read | schema,institution,reader,exception,record | reader为该机构本次真实在职记录者；引用本机构先已实际接收的指定公开例外record与职责来源。只证明他本次读了定位信息，不是独立观察/锚材 |
| guided_dream_contact | schema,institution,actor,trial | trial为同事务真实活动来源；仅授权该次嵌套POWER_DREAM，随实际执行消费一次，不留永久梦境资格 |
| axiom_record | schema,institution,observer,exception,observation,trial | 引用同一例外、自己的实际观察及成功trial；记录仅由本次实际observer见证。PR12的旧record包装须规范到其实际observation，不反写成此kind |
| axiom_use | schema,institution,operator,exception,probe,trial | 引用同一例外与本次成功trial；外层turn为本次真实使用轮，不能由旧记录的turn替代 |
| axiom_dependency | schema,institution,exception,operator,uses | uses恰为所需两个不同轮的真实成功use，operator实际参加两次；父因果含两次use/例外，固定当前承载而不改官方态度 |
| network_endpoint_use | schema,institution,operator,peer_institution,peer,trial,leg | leg仅send_return或receive_return；同一trial两端实际参加且方向相反，各父因果指试验及当前通信来源 |
| network_dependency | schema,institution,other_institution,trial,endpoints | endpoints恰为上述两端，父因果引用这两份结果及原试验；不得把两端当不同原神迹 |

`route_trial`先记录实际活动及锁定检定结果，再产生成功材料；guided_dream的trial先是活动事实，结果由原power_result独立记录，其outcome固定为`delegated`而非捏造第五档随机结果。此特例不供其他四操作使用。outer actor为主执行者，targets精确列本次实际人物/机构；除本节明示获得者外，parents和targets不授知识。新操作所发材料获得沿原受管理learn接口记实际回执；原例外知晓不等于认识邪神。

每个机构/axiom最多一个当前exception；同一机构/exception/操作者只保存当前两次有效use头，历史留冷档；若已存在满足本路线的当前dependency，REPEAT拒绝空收益重复，物理材料失效后的恢复须真实新使用。每个无序机构对最多一个当前network_dependency，已有当前有效同端依赖时拒绝刷同结果；失效后实际重做产生新来源，不改历史。观测侧由`TASK-SOURCE-EXCEPTION`独占`state.prayer_sources.axiom_heads`以及law_observation/exception/exception_reference_read的受管理内核；自然B和主动操作均调用它，主动调用不取得另一份写权限。操作侧由`TASK-PROGRESSION-OPERATION-CORE`的唯一writer维护当前`state.progression_routes={schema:3,content_version,cooldowns,use_heads,network_heads,foundation_heads,memory_heads,contract_heads}`、route_trial及受其授权的成功操作材料；各map业务范围分别见本节、§14.11和§14.12；Axiom/Network处理者只提出各自已验证的有限效果，统一提交，不直接改共享头。guided_dream的原miracle/power_result仍由Powers原writer产生。两个writer暂存于同一World/Turn事务，失败一并回滚。SOURCE-EXCEPTION不依赖主动操作，操作父任务依赖已安装的观测内核，不形成依赖环。当前头总量受12域×3机构及有限真实成员数约束，普通查询只读当前头/直接引用，不逐轮重扫历史。

死亡/失能/迁移不删除知识历史，但即时使当前见证、操作者或carrier资格失效；同域转籍需按当前目标槽重查，不能把原发生机构改成新机构。失去links只影响两节点路线，单节点档案不会因此失效。明确修复/撤销原例外会使其所有观察/依赖失效；只销毁一份材料只影响该材料，不能删除整个例外。纯复制和合法递交可产生保管资格，不能产生新观察、使用轮或应答；新材料族的可转移范围须由`TASK-MATERIAL-TRANSFER-DESIGN`在原矩阵中接续，未声明前仅原实际参与者可作carrier，不以“未来支持递交”完成当前路线。

唯一实施分工：`TASK-SOURCE-EXCEPTION`拥有自然初观/复核及PR12原来源、规范发生键、材料根审计；`TASK-PROGRESSION-OPERATIONS`拥有五操作、共享观测内核的主动调用、费用/Attention/结果事实/来源知识/当前头及完整Turn与Session续存；`TASK-ANCHOR-ROUTES`拥有文明§9.6两种材料判定及纯预览；`TASK-ANCHOR-LIFECYCLE`沿实际材料变动重查锚点与首次遗物机会；`TASK-OPPORTUNITY-SCHEDULER`只登记真实step与actions服务，不代产材料；`TASK-CULT-SAVE-COMPAT`联合审计新版本的材料、机会和仪式。`TASK-PROGRESSION-OPERATIONS`仅作父汇总：`TASK-PROGRESSION-OPERATION-CORE`实现装载/协议/writer及续存，`TASK-AXIOM-OPERATIONS`实现三项法则操作，`TASK-NETWORK-OPERATIONS`实现受梦与往返应答。新增操作的玩家可见入口先由`TASK-PROGRESSION-INTERFACE-DESIGN`按原in-game-ux流程设计，再由`TASK-PROGRESSION-OPERATION-UI`完成Session/ActionCatalog/实际入口及集成验证，必须呈现对象、实际缺条件、费用、概率、材料增量和失败风险；本设计不包含屏幕布局/视觉，不把一个未接线按钮视为L=0证明。

§14.10–14.12统一使用当前设计能力目标`progression_routes/3`与`civilization_dependency/schema2/routes3`，观测来源仍为`prayer_sources/route_observation1`。此前操作/依托的routes1/routes2不是可同时接受的运行标准；具体事实的schema仍按各事实表，不随总能力版机械改成3。Catalog分批装载三新表：`TASK-SOURCE-EXCEPTION`先独立装载`progression_route_sources.csv`、迁移其词法及原root registry扩展，自然来源不依赖操作Core；`TASK-PROGRESSION-OPERATION-CORE`随后装载`progression_routes.csv`与`progression_route_operations.csv`并消费已安装的来源内核/版本，父任务汇总三表；各自拒绝未知操作/成本引用/重复ID、错profile及未注册处理者，原数据随所属实施任务同步词法，不在本设计批偷偷修改。完整Session保存/恢复须核事实来源、人物与机构归属、观察的同一exception/probe、真实不同发生、检定与支付、知识回执、冷却、头索引、唯一消费、原due和opportunity step/episode；只改checksum不能把复制件变独立材料。旧能力版本拒绝继续，不自动为旧记录补observation或新carrier。

### 14.11 TASK-FOUNDATION-ROUTES-DESIGN — First Cult, Isolated Character, Record, and Ritual Route Design（设计待实施）

本节向原路线/操作CSV追加八路和七操作，已有六路、五操作及自然复核源行保持原样。新数值源为[foundation_route_parameters.csv](../../data/foundation_route_parameters.csv)，新操作均`design_only`；现有Catalog、Turn、Session、Endings尚未接线。本节不增加自然B源、不扩大三张展示/八请求池、不让预览生成祈求。§14.8共享债务/FIFO合同保持不变。新操作是人物实际执行的有限活动，不是尚未实现的社会传播模拟。

#### 14.11.1 真实当前私祷、孤立人物和共同协议

新七操作复用`Turn.act(participant="progression_routes", payload)`受管理入口；ActionCatalog实际entry_id为各ROUTE操作ID。每项都要求actions阶段、目标域F、真实active具名人物和表定低语/信仰。**§14.10的五操作全体bound限制只适用于那五项；本节按下表逐项准入。**除私祷的本次自愿成员准入外，主actor须是该域现存bound成员且忠诚≥原四十门槛。需要的人物执行机会在提交前一次性预留，参与者也占机会；非成员peer按原P/L/活身份规则进入实际执行集合，不能因为是“老师”而免容量。无提名/出生副作用，人数不足不补NPC。

共同必填payload为`operation,domain,institution,actor`四个非空字符串ID，operation必须等于entry_id；除表中列出的额外字段外不接受其他字段、别名、空值或自填成功/忠诚/资格。七项本批均不接受`preparations`，避免默认为已有Oracle目标文法；旧五项准备合同不改。institution是本次实际活动结构，actor当下确属该结构；所有人物同域。peer结构不同时，必须有双向真实机构links，且本项明确允许跨机构；同域本身不是会面来源。字段有界、重复/错类型/错域/不存在对象在扣费前拒绝。

| operation | 额外payload（封闭） | 实际资格、动作及结果 |
| --- | --- | --- |
| ROUTE_PRIVATE_DEVOTION | 无 | 有限意愿谓词固定为提交前actor active、已有真实本局身份知晓、当前忠诚≥40，且上述三项同时成立；不是额外未来事实/随机选择。它只表示本项可发起的当前自愿活动，不改自然求告的意向采样。确定性实际执行才产生`personal_devotion`，明确directed且引用既存身份知晓。未bound者须先通过原N准入并真实预留，再依据本次`voluntary_membership`完成enroll；若N不足整项拒绝。不提高忠诚/人数/污染，不授材料或旧知识。已有成员不重占N。 |
| ROUTE_JOINT_WORK | `peer`非空人物ID | actor为bound成员；peer为现存active人物，可以尚不信仰邪神。双方必须共享至少一个真实need标签，并同机构或有双向机构links；双方没有当前hostile/rival边。真实共同关切和当下会面是输入，不要求先有友谊，不从同机构编造共同need；多个共同need按原ID字典序固定最小项写shared_need。按actor影响和原社会理智修正检定；成功/深成才产生本次`joint_work`并调用World关系内核建立一条互惠cooperation。失败没有完成的合作/关系，不授任何人身份知晓、信仰或材料。现有有效cooperation同对不重复收费刷边。 |
| ROUTE_COVERT_GATHERING | 无 | 现存bound actor以自己已真实知晓的邪神为对象组织本机构的一次秘密集会，须actor已有身份知晓且本域有无名非信众。实际参加人数为min(表定三人,当前无名非信众)；不是全域人物逐人模拟，也没有暗藏联系人。预留这批真实人数（失败释放、不预先改信），成功/深成恰好将实际参加人数从非信众移入无名信众；失败不改信。使用actor影响/社会理智修正。只有实际支付才计本域spend。无cult仍可执行，不调用cell/expand。 |
| ROUTE_CALENDAR_RITE | 无 | actor须是已有真实ritual_keeper、其结构有原文明仪式能力，并已bound且有身份知晓。本轮实际主持秘密祭仪；成功/深成产生一份新的`performed_rite`，其原实际祭仪者为actor；最多表定三名实际无名非信众参加并改信，零余量仍能完成真实祭仪但不能生人。无cult亦可执行；不先要PR05、旧成功仪式或官方代表身份。 |
| ROUTE_RECORD_PRACTICE | `series`字符串，可为空 | actor须真实record_keeper。空series仅在该人/结构没有当前有效同类系列时开始；成功建立一份本轮写入后实际读取、结果仍违背先后顺序的有限异常记录，并记第一次真实使用。后续须指定同一series、由原actor在该结构另一个实际回合重新写入/读取；累计表定两个成功回合产生`record_dependency`。这是指定记录持续承担实际读写的神迹依赖，不是第二证人或全世界时间物理模拟。 |
| ROUTE_CALENDAR_KEEPING | `series`字符串，可为空 | actor须真实record_keeper，结构有原文明仪式/历法能力。第一成功回合在实际当前周期活动中得到并使用一个固定的超常节拍，记`calendar_pulse`和第一次使用；后续同一人按该节拍真实开始/结束另一回合的本结构周期活动。表定两个不同成功回合才形成`calendar_dependency`。活动及其开合记录实际存在，不以修改日期或复制旧PR05计数；不授ritual_keeper职业。 |
| ROUTE_RITUAL_TRANSMISSION | `stage`仅teach/perform；teach必须另有`teacher`非空ID且不得有`lesson`；perform必须另有`lesson`非空事实ID且不得有`teacher` | teach：actor是bound学徒，teacher是同域active真实ritual_keeper，本结构有仪式能力；双方同结构或有双向links，并已有真实support/cooperation实际会面依据。teacher可非成员，真实参与并耗机会。以actor适应作超常检定，成功记录本次完整教习`ritual_lesson`；不要求先有成功PR05，不授职业或锚材。perform：原学徒必须在后来回合、原接收结构，以同一lesson亲自实施所学的有限祭仪；教师无需继续在场。再次真实成功才产生`practiced_rite`，原学徒为实践者。不能同轮teach/perform；新实践不是旧祭仪转交或教师见证复制。 |

私祷在本次事务内先写真实自愿活动，再调用Cults成员内核；失败整个事务回滚。身份知晓只能引用原真实取得事实；私祷没有未知者先认识邪神的副作用。它可供接受PR08的孤立成员使用，也可供原有效卡联系内成功入梦后已达四十且真实知晓、尚未绑定的人使用。DREAM仍需原当前固定联系且有冷却，私祷不修复过期Dream凭据、不倒填一次PR08回应。实际定向自愿活动不进入自然call随机意向选择，不为同一原occurrence重抽方向，也不产生第二张祈求卡。

共同工作是后续提名人物的当前接触入口：bootstrap记录者没有初态边也能在真实共同knowledge关切下，与现存合格记录者/审查者做当下工作；同机构仍查共同need，跨机构另查上述实际links。成功cooperation只让两端知道这次关系。不会补亲属、过往见闻、全机构知识、第三人身份或当下未参加者；岗位和人口都不变。它不是PR02争议、PR07共同记忆或异常材料；这些系统仍须自己的真实后继活动。没有共同need的记录者与祭司不能仅凭同机构使用此入口，若其本来没有真实接触，传授路线仍明确缺该前提，不能补标签强行配对。

#### 14.11.2 费用、失败与活动窗口

私祷费用读取新参数1低语/0信仰；共同工作1低语/1信仰；秘密集会2低语/4信仰。其余四项读取原prayer_deep的2低语/4信仰，非回应祈求，不消费/再获得本轮response，也不读取PR05直接数值效果。七项全部消耗实际执行者机会；预算、支付与结果在同一事务提交。参数选择让两次成功集会/祭仪恰好达到原六无名信众与八实际支出，保留原成立门槛；不是宣称平均两轮就能成团。实际参加上限三，不按深成复制为四或更多人，深成仍是本次检定结果，但这里人数/唯一材料不倍增。人口少于三按实际人数，人口零时集会拒绝、祭仪仍可做其非招募部分。

成功/深成污染、始终察觉和每位参与者理智成本唯一读取新操作CSV；私祷/共同工作不凭空制造神迹污染。秘密集会社会失败没有招募；其余超常失败不产生仅成功才成立的材料/使用轮。teach的成功只给lesson，不给`practiced_rite`。原灾变附加的主体理智损失与本域察觉沿原prayer灾变参数，每次一次，不对每位peer重复附加。所有始终成本执行；取消或提交前失格不扣费、不投骰。普通失败保留既有series/lesson，不重置已真实完成的早期使用；当前源已实际失效时不得继续以旧series补数。

CSV cooldown=0仍受每人本轮一次实际机会限制；cooldown=1沿旧协议于T+1完整回合不可重复、最早T+2。私祷不通过空操作刷新冷却；教习阶段按(operation,actor,stage,原teacher/lesson)记，perform一次成功后同一lesson不可再生产另一份实践；失效后修复须真实重做新lesson/series而不是改ID。记录/历法系列头固定(domain,institution,actor,type)，每次use真实turn不同。当前已有完整有效dependency时拒绝继续收费刷新use；已有当前有效lesson或practiced_rite时拒绝另开同人同结构教习。新系列和当前同类有效头不能并存；合法明确撤销后可另建，旧事实留存且不解除他人已固定危机。

所有新事实只向实际参加者交付表定知识。共同工作两端只知本次work及cooperation；集会actor知本次活动和实际人数，但不获得每位无名者的人物档案；祭仪者知道自己rite；记录/历法操作者知道自己series/use/dependency；teach两人知道lesson，perform只有实践者取得新的practiced_rite，不让不在场老师自动知道后来成功。秘密行为不向秩序机构自动公开；CSV察觉不是具体对象确认，真实抵抗仍走原证据和预告。

#### 14.11.3 直接交付与三轮断联

八路的`direct_action, delivery_bound=0`只指**当前真实缺口的已安装可行动入口**：Turn进入actions后，以与Session相同的纯prepare核对象、源、F/N/P、人物机会、低语、实际现有信仰及冷却，并呈现至少一条合法分支，才可写step的服务事实。不是宣称首领、角色、人口、材料、成功或最终锚点零轮获得。新入口不经随机B/A/fix/三卡分页；它们是实际主动活动，不能要求先抽中待供给的PR04/05卡。任何一个尚未安装的handler、展示或事务接线都报missing_delivery_contract，不能把表中0当已验证性能。世界真实前提不足则记录该具体缺口，不从目标待办造人/通路/角色；随机失败后原债务、重试episode和实际冷却仍按§14.8处理。

Endings新增的唯一接触资格是**私祷的同一个实际prepare**，不是“有忠诚四十人物”标签，也不是任意四信仰操作。以确定的下一actions预算检查：仅恢复原低语/回应/人物机会，保留真实F/N/P与身份、知晓、现有资源和明确会释放的名额，不预测收入/随机卡；尚未bound者必须当时有可完成本次自愿enroll的N名额。合格时，玩家下一窗口确可执行一次有具体人物、当前自愿事实及原子成本的零信仰接触。预览不写活动、不入教、不清断联；Endings结算按此真实可执行入口判断。私祷实际执行后仍没有永久券，下一轮重查死亡/失能/迁出、忠诚、身份知晓、F/N及执行预算。旧卡失效不延due，三次连续完全无接触的原寂灭规则和优先级不改。

有限正例：T1 bootstrap PR08浅成让真实记录者loyalty40并入教/知晓；T1已用机会不妨碍Endings按确定下一轮恢复后检查私祷。T2/T3各一次秘密集会标准成功，实际支付8并转化6，T3原Cults在Endings之前成立；若失败，私祷只是下一窗口真实可执行的联系，既不补人数也不保证成功。另一初领袖路径只在真实固定联系还有效时做DREAM：两次最早T1/T3，冷却T+1不可缩短；初始忠诚15的两次普通成功仅35，须至少一次深成或其他真实忠诚来源。只在真实结果已达40并知晓时T3轮末可核下一窗私祷，T4才实际自愿绑定。结果不足40、联系早已过期或N/F无法合法取得时，不能凭路线计划续命。无已识别且愿意者的世界仍可能在三轮断联后失败；本设计没有未知世界无限免费探测。

#### 14.11.4 精确事实、唯一writer与续存

本批事实changes均含`schema:1`，IDs为字符串；数组字段为有界去重字符串数组，turn为实际提交整型轮，participants只能列本次实际人物；不收自填事实ID。以下列出除schema以外全部必填字段：

| kind | changes字段 | 直接父因果及后继边界 |
| --- | --- | --- |
| personal_devotion | domain,institution,person,identity,knowledge,addressing,turn,trial | addressing固定directed；knowledge须提交前属于此人的真实身份取得。trial为本次已授权route_trial；本人实际取得该祈求事实。 |
| voluntary_membership | person,devotion,turn | 父源只含本次personal_devotion与提交前已验证的成员准入/实际N预留来源；不引用后续enroll结果。Cults据此调用enroll并唯一写bound/member，不能反过来用bound结果自证原自愿。 |
| joint_work | domain,institution,actor,peer,peer_institution,shared_need,trial | 共同need/实际职责、现存结构/links为提交前输入；只在成功写。World唯一关系内核消费此事实写cooperation，关系父源为本次work。 |
| covert_gathering | domain,institution,organizer,participants_count,converted_count,trial | 两count为非负整数，converted≤participants≤表定上限，原非信众/成员输入和真实支付为来源；失败可记活动但converted=0，不伪造成功。 |
| performed_rite | domain,institution,priest,participants_count,converted_count,trial | priest是实际ritual_keeper；当次实际举行及神迹成功唯一源，不借旧PR05或未发生祭日。 |
| record_series / calendar_pulse | domain,institution,operator,trial | 第一次真实成功活动；首use可同事务产生但不能自引。它是本系列真实超常输入，不以普通文字/改日期代替。 |
| record_use / calendar_use | domain,institution,operator,series,turn,trial | series指前项；真实当下操作，以本次支付/check为独立行动来源。同一series/turn最多一use。 |
| record_dependency / calendar_dependency | domain,institution,operator,series,uses | uses恰为参数要求的不同turn成功use、同人/结构/series。依赖只声明此实际用途，非独立见证。 |
| ritual_lesson | domain,institution,learner,teacher,teacher_institution,contact,trial | contact是当前有效support/cooperation来源；实际老师role/结构能力、双方当下参加为输入，不需先有成功PR05。 |
| practiced_rite | domain,institution,practitioner,lesson,turn,trial | practitioner为原learner，实际turn>lesson实际turn；亲自成功实践才有此事实。老师后续离开只阻止新教习，不取消已经学到的有限实践。 |

route_trial沿§14.10字段；本批private outcome=success且check_rule=deterministic，不伪造随机骰；其余各有一次真实原check。预检→暂存trial→本次活动/教习/系列→实际人口/成员/关系/知识效果→派生依赖及当前依据→整体提交，父因果只能指早于自己的暂存位置/既存事实，无循环和未来来源。个人已有知识不会被遗忘以制造重复收益；人格职业、旧关系与旧发生轮不能改写。

`TASK-PROGRESSION-OPERATION-CORE — Progression Route Operation Core`仍唯一维护操作state及事实提交，`foundation_heads`为有限map，键为domain/institution/actor/type，值为当前series/lesson/use/dependency ID；它与§14.10及§14.12的头共同属于当前`state.progression_routes` schema=3、能力`progression_routes/3`，不另维护schema2状态。子handler只提出已核有限效果。Cults唯一写成员/教团、原人口内核唯一执行非信众→信众、`SET-SOCIAL-GRAPH`的World关系writer唯一写cooperation/edge头；不能由Core直接改三份状态。普通查询只查当前有界头和所选直接来源，相关失效增量更新；完整保存审计可检查全部审计事实，不新增每轮历史重扫。teacher失能、actor迁移、材料撤销等分别影响当前资格；不抹已获知识，也不把教习成功当已实践。

实施归属：`TASK-FOUNDATION-CONTACT-OPERATIONS — Present Contact and First Cult Gathering Operations`负责私祷/共同工作/集会、原Cults/关系/人口调用和Endings共同prepare接入；`TASK-FOUNDATION-RECORD-OPERATIONS — Record Practice Operations`负责记录系列/使用；`TASK-FOUNDATION-RITUAL-OPERATIONS — Calendar and Ritual Practice Operations`负责祭仪/历法/传承。Core装载新参数及追加操作，原自然来源表/§14.10观测内核保持原owner。`TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation`消费文明§9.7材料；生命周期/保存任务沿实际依托和新版本接线。玩家入口由`TASK-FOUNDATION-INTERFACE-DESIGN — Foundation Route Operation Interface Design`先按UX/Art流程设计，再由`TASK-FOUNDATION-OPERATION-UI — Foundation Route Operation Interface Integration`实现Session/ActionCatalog正式入口并验证实际当前投影；本设计没有布局/视觉稿。父`TASK-PROGRESSION-OPERATIONS — Progression Route Operations`汇总安装；缺任一实际必要子能力不得将本路线标active。

新参数、操作/事实内容版、成员/人口/关系效果、参与机会、真实支付、cooldown、教习阶段/实际不同回合、当前head和机会step/episode均纳入完整Session保存恢复；旧能力明确拒绝，不为旧成员补本次私祷、不为旧记录补系列、不为旧关系补教习。控制行为验收须含：未N准入无半个成员；无匿名池无新人口；孤立人物只增当前一边；同轮教习/实践拒绝；复制同use不达两轮；私祷可用与Endings一致且失格后三轮仍可终局；故障全回滚；真实UI安装前的L=0不得服务。自然新局/节奏/体验另由下游验收，静态设计不宣称已运行。

### 14.12 TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design（设计待实施）

本节追加六路、六操作及[memory_contract_route_parameters.csv](../../data/memory_contract_route_parameters.csv)；原14路/12操作/1自然源行不改，新行均design_only。原自然共同读取、登记审查和当前约定目前只有目标合同，不能当已安装的生产者；本节要求共享真实生产内核，并为主动操作另外登记受管理调用。没有新增自然B源，§14.8等待/FIFO、原祈求池/展示数及原PR06/07费用、回应次数、人数口径不变。

#### 14.12.1 共同当前条件与封闭payload

六项均经正式`Turn.act(participant="progression_routes",payload)`，entry_id=operation，要求当前actions、目标域F、active且loyalty≥40的真实bound actor、真实结构归属、成本和执行机会。所有实际参加者同域active，**新操作**由Core显式预留并标记每个人的执行机会；非成员按原P、成员按N去重计容量，最大四人，不提名/入教/加人口。旧PR06/07沿原response与Attention主体容量，不能把这里新增的逐人机会标记反称为旧祈求已有行为。

共同必填`operation,domain,institution,actor`均为非空ID字符串，operation必须等于entry_id。institution是actor当前真实结构。人物数组按稳定人物ID排序后，institutions/records/registrations/qualifications等并行数组随该人物顺序投影，不各自排序；use按实际turn再源ID，legs按固定index，均去重且长度固定。不收preparations、不另开Oracle文法。除下表字段外拒绝多余键、别名、null、错类型/域/角色及虚构source；先纯prepare，再提交前重查、一次原子预留/支付/检定/知识效果。

共同接触只接受真实mutual family/cooperation或任一方向support；对方与actor同机构或双方机构有双向实际links，负关系不替代邀请。没有边时可用§14.11实际Joint Work且仍须其共同need条件，不据待办补关系。记录白名单只取原§14.9真实可读record及本人真实成功DREAM的miracle；本批不以空message、prayer_call、未来效果或任意同名标签充数。参与者尚未知指定记录时，只在本次实际共同读取/协议宣读环节获得该一项记录，不取得其parents、神祇身份或过去的亲历资格；这不是通用材料转交按钮。

| operation | 额外payload（封闭） | 实际过程 |
| --- | --- | --- |
| ROUTE_MEMORY_CIRCLE | stage=convene时必填`record`和恰三人的`peers`，不得有review；stage=preserve时仅必填`review`，不得有record/peers | convene的actor实际属可运作interpretation机构，域communication=network，确知record；三位现存关系人实际参加。SourceMemory执行原共同读取、逐人见闻登记，随后承办机构实际受理这次登记审查，固定原memory_at_risk及due。不是同机构人人自动登记，也不是许可邪神。没有真实审查职责/接收/当前受理不生成。preserve必须在后来实际回合且原due内，由同一host及同三人实际再参加，关系/接触/各自本次登记仍有效；一次超常成功才各获本review的`route_memory_preserved`及冲突记录。不能只拿shared_observation直接发资格，也不补未登记者/别的review。 |
| ROUTE_MEMORY_PRACTICE | 必填`peer`和`series`；series为空时必须有`record`，series非空时不得有record | actor真实属interpretation结构且确知首record，peer有真实当前接触。第一次实际共同读取形成两人的当前见闻和本结构实际实践登记；超常成功后，两人不查看原记录而亲自使本次共同见闻以可感知的回声再现。后来另一实际回合，同一两人再次共同回忆并使同一回声出现；两个成功回合才形成recollection_dependency。它是持续共同回忆实际被使用的依托，不是多发一份PR07资格。 |
| ROUTE_DISSENT_PRACTICE | 必填`peer`和`series`；series为空/非空分别开始/再现，不接受record或自由视角值 | actor真实属interpretation结构，域communication=network；两人有当前真实接触。第一成功回合，两人当下共同观察本次展示的同一有限印记：按稳定人物ID分别真实经历“完整”“破裂”两个相斥视角，并各自当场陈述/登记，形成同一episode的两份个人记忆。后来另一回合，印记不再展示，两人亲自让各自原视角再次出现，保留两种不可合并陈述后形成dissent_dependency。此有限超常活动不求解整个集体意识，不借过去发生/第三人见闻。 |
| ROUTE_PACT_AGREEMENT | 必填`peer,record` | actor确知真实record，peer有当前真实接触；双方实际读取该记录并约定actor在本结构保留这一指定记录。SourceContract先写本次current_agreement（term=preserve_record）及contract_obligation，双方实际获知条款与原due。声明时尚未履行；不授依赖/圣物/继承。 |
| ROUTE_PACT_PERFORMANCE | 仅必填`contract` | actor必须是该原obligor，peer固定为原counterparty，结构/记录/条款由原约定读取，双方实际在场、接触合法、原due尚未过去且义务未履行。真实将指定记录保存在原约定结构，并以本次神迹履行使记录持续保留依赖这次超常结果；成功后才fulfill及contract_dependency、两端履约见证/实际知情。不能用一次普通learn、自填fulfilled或付费本身作依赖。 |
| ROUTE_RECIPROCAL_COVENANT | stage=agree时必填`peer,record,peer_record`且不得有covenant；stage=fulfill时仅必填`covenant`且不得有peer/record/peer_record | agree时双方均为真实bound合格成员，属不同且双向links的结构，各确知自己的不同原记录；prepare按原记录族的受管理来源解析归一到唯一原发生根，两个canonical root相同即拒绝，private/public包装或复制换ID不能凑两项。两人在当前会面中实际读取双方记录，并固定两项互惠条款：A把自己的指定记录交付B结构保留，B把自己的另一记录交付A结构保留。两个真实义务、相同原due、方向/人物/对象一次锁定。fulfill时actor只能履行自己原本一腿，另一方实际接收；两腿须分别在agree之后的不同实际回合，以神迹完成真实递交/保留。两腿都成功并分别形成真实依赖后才产生reciprocal_dependency，不把一腿复制两份。 |

CIRCLE的convene明确是一项主动登记/审查请求，须真实机构当下受理，不能由UI为赶进度写risk。其SourceMemory核验与自然ROOT_SHARED_OBSERVATION/ROOT_MEMORY_REVIEW共用，但授权调用处为本次人物实际活动；自然B仍沿原快照与预算，不因新内核自动补抽。convene先实际share_record→共同读取/登记→机构受理审查，三个事实位置先后固定；preserve不能在该同轮执行，也不使用之后才认识的人/新登记替换原三人。新route_memory_preserved和原PR07 memory_preserved是不同受权来源，但都必须解到同一个具体review/person/registration。原review到期仅撤本范围未保护资格；新保护结果必须进入相同逐人资格判定，不留一套到期忘记查的旁路。

双人两路使用本次实际`route_memory_session/route_memory_registration`，是指定结构内实践者保留的当次见闻/陈述登记；不是原公共review的授权，也不授PR07身份。第一轮成功只形成真实episode和初次再现，第二轮成功才给各人完整实践资格及依赖。普通读取、登记或写两份文本不算神迹。后续私人陈述经实际共同陈述向两人交付，对方只知道本次陈述/登记/再现，不得到未说出的其他私人记忆。原机构对另一次shared_observation的审查只处理它原登记范围，不因此撤销这两个新episode的亲历实践或抹私人知识；若新的实践登记/原超常结果本身被真实撤销，则该依托失效，不能用“仍记得”绕过材料资格。

#### 14.12.2 阶段、真实履约、原期限和成本

CIRCLE/convene、PACT_AGREEMENT、RECIPROCAL/agree确定性执行，成本读新参数1低语/1信仰；不检定、不授成功污染/记忆或契约依赖，也不应用该操作CSV为超常阶段列出的理智/察觉。其余实际preserve/practice/perform/fulfill阶段一律读原prayer_deep的2低语/4信仰和原适应超常检定，成功污染/始终察觉/每位实际参加者理智代价读追加操作CSV。灾变再按原公共参数作用于主actor与本域一次，不按四个参与者重复加灾变。新数值用两人跨两个真实成功回合的成本/机会代替原三见证的资源结构，未宣称平衡已测。

一次确定性前置不是成功超常材料。检查失败时只保留已真实发生的普通活动/支付/既有源，不生成成功use/资格/依赖；所有始终代价照常。人物刚失格、容量不足或无法实际履行条款时在支付前拒绝，事务异常全回滚。超常成功/深成均只产生一次实际材料/一腿，不倍增人物、登记、腿数或回合数。

新主动审查/契约均在真实convene/agree轮T固定`due=T+event_parameters.prayer_lifetime_default`；后继只能在T之后且不晚于原due的actions执行。到期、失败、保存/切F、另一腿完成均不延期。CIRCLE失败可在仍合法原窗口再尝试；过期后不能重开原review补资格。PACT只有本次指定未履行义务可以履行；RECIPROCAL的两腿各自单次，成功一腿不关闭另一腿的到期工作。到期仍未履行的腿执行原有源close_cooperation，已完成腿/既存依赖不被倒写为未发生；但不完整互惠不能授reciprocal_dependency。浅层PR06仅完成其原单向条款/本方见证，不冒充神迹依赖。本批互惠条款是新的deliver_record有限条款，普通PR06不自动读取它；它只由本次新操作受管理处理，不能靠旧handler任意fulfill字符串跳过真实递交。

单向保管与互惠交付作用不同：前者固定原记录在原结构被神迹维持；后者必须让两个不同结构各实际收到另一方的原记录，之后双方各依赖自己已接收的那一项结果。互惠不会创建新独立证据根/物理圣物副本，知识/记录保管实际递交只引用同一原记录；不转移原目击身份、记忆资格或神祇身份。两腿成本独立实付，不能在一笔检查中宣布双方履约。EVENT05A/release_contract只在它真实所指依赖上生效；撤一腿的依赖会使互惠整体不再合格，不倒删另一腿的真实履行史。原obligation成功关闭是危机结束，不是解除已成立依赖。

两条双人记忆路线的cooldown=1沿原完整下一轮不可重复规则，两个成功use的turn必须不同；有失败则实际再尝试但不捏造中间回合。CIRCLE与契约cooldown=0仍受每位参加者当轮一次新活动机会，故不能同轮convene+preserve、agree+履约两腿。完成的依赖/三资格仍有效时拒绝重复刷同头；未完成的当前series/review/covenant不得以空ID换一个新发生清期限。实际终止/失效后新活动有新真实来源，旧历史、已执行损失和等待债保留。

#### 14.12.3 事实schema、知识与唯一写入

新事实changes均含`schema:1`，以下列其余完整必填字段。ID为字符串、turn/due为实际整型轮，数组有界去重；participants按实际参加者稳定ID排列，receipt集合不被当作无源授权。CIRCLE沿用原shared_observation/memory_at_risk字段和真实位置，单向约定沿current_agreement/contract_obligation；新事实不得修改这两组原历史字段。

| kind | changes字段 | 事实与知识边界 |
| --- | --- | --- |
| route_memory_preserved | person,memory,review,institution,registration,trial | registration为原观察的实际(person,institution)项，以规范对象存储；parents含review/观察/本次试验。只给原三人各一份，主持人不凑第四份。每人实际取得自己的资格；host及三人当场获知本次保留集合，不获彼此其他秘密。 |
| route_memory_conflict | person,qualification,review,trial | 与原实际保护结果对应的个人记忆不可归并来源，不能只给任意memory贴标签。 |
| route_memory_session | domain,institution,host,participants,record,mode,trial | record为memory_practice实际指定记录，dissent为空；mode仅recollection/dissent。session来自本轮真实共同活动，不引用过去不存在的见闻。 |
| route_memory_registration | session,person,institution,view,trial | view为recollection时shared；dissent依稳定人物顺序为intact/broken。每一项来自该人的实际参与/陈述，结构真实接收这项实践记录；不是换机构归属。 |
| recollection_use / dissent_use | session,participants,registrations,turn,trial | 每个use均为本轮同一原二人亲自再现/陈述的成功结果，不由记录转发产生。新陈述按当场实际说出的内容交付两人，含两项本次登记；不共享parents/其他知识。 |
| recollection_dependency / dissent_dependency | session,participants,registrations,uses | uses恰为参数要求的不同成功回合；每一参加者具备自己的原登记及两轮实际实践，双方实际持有此结果和当场披露的必要记录。 |
| reciprocal_agreement | domain,parties,institutions,records,record_roots,relation,due,trial | parties恰两人；institutions/records/record_roots按同序对齐；record_roots由受管理解析器计算而非payload输入，必须不同。raw记录ID保留真实引用，未知/多义原根拒绝；relation为本次真实接触来源。方向固定parties[i]把records[i]交给institutions[1-i]，不由后来的当前归属重建。 |
| reciprocal_obligation | covenant,index,obligor,counterparty,institution,record,term,due | index仅0/1，term固定deliver_record；全部对象及due由原agreement同一index派生。此为独立受权新义务kind，不冒充旧preserve_record根，也不自动送入PR06。 |
| route_record_custody | obligation,record,provider,holder,institution,trial | preserve_record时holder为原obligor、institution为原保管结构；deliver_record时holder为原counterparty及其原接收结构。实际保管落成才有此事实；先前宣读只是知情，不产生本次保管。 |
| route_contract_performance | obligation,term,provider,counterparty,record,institution,custody,trial | term仅preserve_record/deliver_record；custody为本次真实保管回执。之后原子标记该义务已履行，不能以事后fulfilled布尔作该事实父源。 |
| route_contract_dependency | obligation,performance,record,institution,parties,trial | parties固定原obligor/counterparty的稳定人物顺序，performance与custody实际完整且本次超常成功，才有这份神迹持续保管依赖。 |
| route_contract_witness | person,role,obligation,performance,dependency,trial | role仅obligor/counterparty；两位实际参加者各一份，真实当场获知指定履行/依赖；没有到场不补见证。 |
| route_hostile_contract_witness | person,obligation,dependency,trial | 真实counterparty成为此依赖的潜在敌对见证者，不直接写hostile关系，也不授邪神身份。 |
| reciprocal_leg | covenant,index,obligation,provider,recipient,record,record_root,receiving_institution,custody,performance,dependency,witnesses,trial | index仅0/1，record_root必须等于原covenant同index的归一根，保存审计重新核对raw来源且不能按包装ID比较；witnesses为实际两份route_contract_witness事实ID，按当事人顺序。真实已履行义务、实际递交保管和神迹依赖齐备才有本腿；parents包括全部本次条款/履约来源。 |
| reciprocal_dependency | covenant,legs,parties,institutions | legs恰两个不同index、不同真实完成回合，全部实际有效；不是把同一dependency列两次。 |

新PACT_PERFORMANCE/互惠履约的精确顺序为：已核原义务/条款与实际预留支付→trial→route_record_custody→route_contract_performance→义务已履行效果→route_contract_dependency→双方实际知识/route_contract_witness及对方潜在敌对见证→reciprocal_leg（若适用）→第二腿齐备时reciprocal_dependency；全部同事务发布。义务关闭不作为此前performance父源；dependency不引用后出的witness，避免循环。原Prayers的旧contract_dependency保持原schema/结果，不能混写同名prayer_fact。新route_contract_dependency按performance.term与原义务kind分流：preserve_record+contract_obligation只供单向分支，deliver_record+reciprocal_obligation只能经完整reciprocal_dependency两腿供互惠分支，禁止一腿借单向分支绕过第二腿。两个递交目标在agree时须尚缺本次指定记录的实际保管端点，已知道内容不等于已有保管，已具相同合法保管端点则不能假造待交付条款。完整准备与履行受权以新操作能力/原source注册表审计，不能把自由调用World方法视为真实生产。互惠每腿的实际交付仅由合同内核受权给固定双方，不扩成任意人物材料转交。契约继任按作者本次简化改为§14.13的当前选定规则，不再以尚无生产的生前文书为门槛；本批六路仍不依赖继任，接续实现由已登记继承设计与来源任务承接。

`TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources`独占共同读取/登记/审查及新活动输入的受管理内核；`TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources`独占约定、原义务、真实条款履约/递交及依赖的内核。它们可被自然调度或已安装的新主动处理者调用，分别验证调用位置/授权和真实输入，不反依赖Core。原Prayers的PR06/07沿自己的原回应入口调用相同相应内核，保留response语义；新操作不借原PR答复复制第二次结果。World原knowledge、关系和人口仍各自唯一写者，本批不新建影子知情/关系或隐形人。

`TASK-PROGRESSION-OPERATION-CORE — Progression Route Operation Core`唯一维护追加的`state.progression_routes.memory_heads`与`contract_heads`两个map及新试验/实践结果，schema升为3、能力`progression_routes/3`；source内核继续拥有自己的输入/义务和有效索引。每个(actor,institution,family)最多一当前未终结series/review/covenant头；已完成仍有效的同类头不得覆盖刷收益。普通查询只读当前有限头和直接绑定源；保存完整审计可遍历历史，正常每轮不全量扫描。任一参与者失能/死亡/迁出、原关系/通路失效、原记录/登记/必要结果真实撤销均按本路当前条件处理，知识历史不因此删除，真实履行不改写。

#### 14.12.4 实际交付与实施验收

新增路线的direct_action/L=0只在正式安装的当前动作经Turn进入actions后的共同纯prepare可行动、真实Session可见时成立，表示下一缺口的入口，不表示材料/成功/最终active。实际convene/agree前只要求当前真实人/记录/接触/机构与资源，不先要求待生产review/契约；后继step才绑定已真实生成的同一review/series/covenant。无handler/逐人机会接线/真实玩家入口报missing_delivery_contract，不拿未装的表自证保障。人数/结构/角色/容量/资源真的不具备时明确报缺口，不凭等待债造人、记忆或契约；不延原due，亦不改三轮断联。

`TASK-MEMORY-OPERATIONS — Shared Memory and Dissent Operations`承接三个记忆操作；`TASK-CONTRACT-OPERATIONS — Agreement and Contract Practice Operations`承接三个契约操作。`TASK-MEMORY-CONTRACT-INTERFACE-DESIGN — Memory and Contract Route Interface Design`负责随后按UX/Art流程设计入口，`TASK-MEMORY-CONTRACT-OPERATION-UI — Memory and Contract Route Interface Integration`接正式Session/ActionCatalog及实际可见可行动验证。Core装载新参数/操作和阶段协议，来源任务先提供不反依赖主动操作的内核；文明材料、生命周期、调度、保存各沿已登记任务承接，当前不改布局/代码。八蓝本描述CSV及十目标/二十路的父汇总见进度§12.4；说明同步与注册表齐备不构成实际安装、行为或自然新局证据。

实施至少验证：三人资格只能从同次实际review登记保留，PR07浅一人不能补成三人；两人两轮实践不冒充三见证；个体陈述/关系/同机构不自动赋记忆；跨机构实际参加/知情/当前carrier成立；先约定后履行、两腿不同记录/方向/真实回合；零钱/名额不足/提交前失格不造半个源；due到期不延、浅履约不当依赖、release与根关闭区分；已死亡不能被补见闻；保存/切F/重试不换人、改due或洗单次腿；原PR不自动标acted_turn，新多人操作确实逐人耗机会；只有一腿deliver_record时两个CIV06分支都不得成立（不能借新单向schema洗成保管义务）；两条独有路径各禁用一次仍能走另一路的真实完整流程。上述是待执行验收，不是本轮行为证据。

### 14.13 TASK-CONTRACT-SUCCESSION-DESIGN — Contract Succession Resolution Design（作者简化方向，设计待接入）

制作人先选择不新增玩家按钮，随后明确要求弱化约束、无需细致模拟。因此契约接续**不再强制生前文书**，不模拟起草、签署、递送、逐人学习或同意协议；此前Prospective Contract Succession Production Design的这一前提已撤销。本节只处理契约，不放宽EVENT07先知遗言或普通机构任职。

EVENT05的纯候选准备：原obligor仍活着就保留原人；确有其实际死亡事实，且原contract/dependency仍可接续时，从原域现存active人物中筛已有真实family/support/cooperation关系者，排除原义务人和原counterparty。family/cooperation沿mutual，support任一真实方向均可作为接续背景；候选须仍能在原契约保管机构履行原条款（实际同机构或当前可达）。不要求预先知道文书、已学全套契约记录、具有祭司/代表头衔。按稳定人物ID、关系来源ID取首个合法者；不抽新人、不补关系。所用关系必须在原死亡之前已经实际存在，同轮按事实先后即可。无合格者只保留原合法解除/结束分支，不凭空让死者继续履行。

候选收集/预览纯读。实际固化EVENT05时，由契约来源内核在Events授权事务中写`contract_successor_selected`，仅记录本次选定，changes固定`{issuer,version,contract,obligor,successor,relation,death}`；actor为当前被选定者，targets列原义务人/继任者，parents包括原contract、dependency、callback、实际死亡与既存关系。`facts.inheritance`引用这份当前事实，subjects.successor固定该人；选定不是生前安排、不是已经继承，更不产生材料或依赖。没有新增PR类型、B机会、费用或独立文书根；它是现有EVENT05固定流程的有限规则。

原固定事件中的B再次核该人active/同域、原关系仍有效、仍可执行原条款；失格就不可执行B，不收费、不换人。实际B结果才沿原contract/dependency记录`contract_successor_authorized`及本次接续，不恢复死者、不改原due、不新建平行义务或独立锚材。A仍只解除所指依赖。重试/读档沿原选定，不重新选另一人；同一原契约至多一名当前继任者，事件与接续结果按原消费键各一次。本批不扩展成可连续转手的继任链；这不影响原合同的历史结果。

这里接续的是EVENT05所指的当前神迹依赖及保管责任，不重开已经履行或到期的原义务，不要求把已完成的一腿再做一次。保留due表示不复活/续期原危机；不能因其原日期已过去，就把已真实成立且未被release的依赖误判为不可接续。

恢复核本次选定的原契约、原死亡、既存关系、固定对象和真实结果；不把本次选择回填为过去文书。旧contract_inheritance_fixed仅作显式历史来源读取，不是新路径的必需前提；当前版本用能力/内容边界拒绝旧语义档的静默升级。`EventRules.inheritance`、EVENT05固定/执行/恢复与契约材料继任消费必须同步，不能只放宽一种读口。

实施由TASK-SOURCE-CONTRACT-SUCCESSION — Contract Succession Selection and Consumption承担，父TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources保留其余原验收。civilization_conditions.csv的CIV_06行说明已按本次方向同步；这只是设计说明，不代运行时消费。实施时将event_sources.csv的EVENT05标签同步为`eligibility_b=obligor_or_related_successor`、`invalid_policy=related_successor_or_end`，再同步Catalog有限标签及正式消费者；这两项运行标签与代码尚旧，本文不声称已经运行。SOURCE-CLOSURE核真实PR06结果→死亡→选定→EVENT05B；CULT-SAVE-COMPAT和能力探针接真实来源与重试/恢复，不要求不存在的签署链。

旧`tools/anchors/run.gd`的`ANC-SUCCESSOR`把生前fixed及同轮即拒当作必要前提，这两项已由作者本次明确撤换。后续新工具保留旧报告，改用真实旧关系→当前选定→实际EVENT05B验证；错误人物/关系/版本、固定后失格不换人、重复与恢复一致性仍验。不能一边保留旧断言名称，一边宣称旧场景原样通过新规则。

设计验收：无需生前文书但有原关系的合格者可被当下选定；无原关系、死后新建关系、已死/异域/不可履行者不合格；纯预览不写状态；固定后失格不换人；保原contract/due与一次性结果。此处是有限规则设计，不是世界里已模拟法律程序、真实签署或社会认同。
