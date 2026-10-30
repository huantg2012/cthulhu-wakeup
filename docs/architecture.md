---
status: PROPOSED_WITH_PARTIAL_TECHNICAL_EVIDENCE
created-by: code agent
last-modified-date: 2026-10-30
changed-this-slice: true
---

# 技术边界与可实施性

本文件解释策划需要知道的技术选择和风险，不是逐类 API 或开发任务书。Godot 由作者指定；下列组织方式是工作方案。实测范围见 [技术验证报告](qa/technical-feasibility.md)，不能把验证工具的存在等同于正式游戏已实现。

**2026-10-30 密教方向修订边界：** [文明规则第9节](specs/system-civilizations.md#9-密教渠道与八蓝本实际神迹依托task-cult-direction)及关联五系统spec/CSV采用schema2设计。TASK-ANCHOR-ROUTES已实现共享材料判定、当前`anchor_basis`维护、POWER_ANCHOR创建/修复选源及最小知情投影；TASK-CULT-SPREAD现接入聚合秘密扩张、强化传播、04/09及PlayerSources正式来源，具体当前证据见下方实施节。TASK-ANCHOR-LIFECYCLE已完成代表性首次遗物、建立/修复、实付维护与失效/恢复，以及当前抵抗/终局消费者的有限验证，见[专项报告](qa/anchor-lifecycle.md)；全部替代路线、进展玩法生产、自然首团及完整Session续存仍由后继验收，不将局部运行扩大为整局闭合。TASK-CULT-DIRECTION本身只交付设计与实施安排。

## 当前目标：轻量情境生成（DEC-026）

**TASK-PROGRESSION-OPERATIONS 技术接线（待本批运行验证）：** `src/game/progression_routes.gd` 是单一版本化 Turn action 参与者，按正式操作 CSV 分派联系、组织、跨轮实践、祭仪教习、两端交换、记忆/契约情境和实际互惠履行；稳定操作 ID 是参数行或既有权能/祈求入口的别名。Session 在原十模块之后安装它，Turn 的受管理 action/effect 列表、StateView 和 World 完整/增量审计共同注册；不另建时钟、人口或调度器。操作表 `minimum_turn_gap=1` 表示下一轮最早可继续，原 Powers cooldown 语义不变。当前使用与成功产物以原人物、真实费用及不可变结果记录恢复，材料当前性继续由共享消费者重查。

新 `route_material` 同步进入 Anchors 归一化与 MaterialTransfer 的正式 selector；共享实践只保原参加者、材料系列、两次实际成功使用和依赖。互惠每腿经同一 `World.receive_material` 核，专用 reciprocal channel 必须指向真实付费成功尝试；普通转交不制造履约。记忆/单向契约准备沿原 Sources 情境固定与原祈求回应：真实 actions 快照标记 `route_action`，仅两种受管理付费准备可用；请求下一轮可见，原 due、容量及一次消费不变。私祷的同一纯 prepare 接 Endings 下一行动窗口及当前预算。界面只扩原 ActionCatalog 的情境选择/详情，保原 GameRoot/OverlayRoot 与样式。本批不据模块安装宣称所有替代路线 active、自然首团、调度等待界或完整 Session 保存已验收。

**TASK-OPPORTUNITY-ELIGIBILITY 技术接线（2026-10-30）：** `src/game/player_knowledge.gd`把原Session知情规则抽成脱离输入账本的纯reducer、单源揭示、命令结果根和原保存形状重建。本段记录ELIGIBILITY交付时Session持有原knowledge账本的历史阶段；本轮SERVICE已将同一账本迁入Turn受管理context，Session只读其副本（见下方接线）；请求最小线索、已知实体、实际结果、公开事实、当前派生资格及锚点依据沿同一规则输出，不新增世界知情状态或递归公开前因。`knowledge_snapshot()`仅给出原账本副本，不赋予授权。

`src/game/entry_selectors.gd`承接原有限已知选项，`src/game/opportunity_eligibility.gd`只解析给定entry与选择，先核同一选择器，再规范原DREAM/PR06别名、rest或经营命令，调用现有正式handle/prepare及Attention。Catalog保留原标签、详情和公开预览白名单，Session的经营/rest与来源选择委托共享查询；当前既有材料递交选择沿原有限已知材料/人物枚举，完整输入只重查该端点，不枚举二十路线或全菜单组合。查询接受Turn正式read-view、实际账本和已安装模块，不接收UI自报allowed，不调用拒绝事务内使用的public preview；prepare的本地缓存只落在脱离副本。`src/game/action_admission.gd`抽取原Turn费用/回应/非空actor及付款域判据，Turn实际支付和World人物执行标记共用；事件仍保原空actor语义。原Sources固定请求容量检查和PlayerSources当前proof查询仅增加同一state/read-view适配，业务规则没有第二实现。

Turn的read-view附原Catalog/Attention只读规则实例。查询不扣资源、不预约F/N/P、不推进随机或写服务，实际输入仍由Turn原子重查。Session现行保存信封增加eligibility版本匹配，旧版本拒载而非静默重建；本项只验证账本组件一致性，完整Session恢复仍归TASK-CULT-SAVE-COMPAT。目标planner、补偿/FIFO、供给回执与服务界均留TASK-OPPORTUNITY-SCHEDULER，本项不接这些状态。

**TASK-CAPABILITY-GUARD — Declared Responsibility and Production Wiring Checks（2026-10-30）：** AbstractSim保留并递归冻结实际装载且通过既有grammar校验的职责行；Dispatch正式prepare从该行选择focused/background处理者，仍调用Events原有mode_handlers/candidate_handlers。Events.generation_binding_errors只读检查Turn唯一candidate_generation归属、实际Events实例、两模式Callable目标/方法及当前已装载Producers.ROOTS、Sources.ROOTS和身份告知绑定；直接root集合独立对照Catalog实际装载的prayer_root_rules及producer_task归属，避免从ROOTS删除一项时连同校验预期一起消失；prepare返回具体错误，commit用同一检查拒绝不合法绑定。没有第二份自报能力registry、不动态加载表中脚本、不更改候选资格或随机数。ROOT_INITIAL_TIES与ROOT_SHARED_OBSERVATION不是独立候选handler，不纳入这12项直接绑定。tools/implementation/capability_guard.py做有限源码形状/CSV及内存负例检查，capability_guard.gd复用已安装组件核实际绑定与缺失/错指向/重复归属；检查不把合法空结果视为缺能力，候选与后果语义另由TASK-CAPABILITY-PROBES验收。此工具不证明全部能力、自然概率或完整Session。

**后续普通背景共享“条件加权抽签＋必要重要状态”的轻量生成。** 不要求活动→事故→伤害→通知、送达或逐人读写等过程证明；一次抽签可确定必要背景与后果，表述须准确说明它是情境生成。人物身份与死亡、玩家行为及资源、独立材料、原期限、一次性结算和当前版本保存一致性仍须明确维护。

下文旧未实现目标中的细过程要求由DEC-026替换。13个Source实施子任务合回五个SOURCE父任务；路线Core、七业务操作及三组UI设计/接线合回**TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration**，由父任务收口必要玩家玩法，不默认实现十八个独立按钮或后台活动。十八操作表为implemented；十目标与二十路线为coordinated协调索引，未装载的来源索引仍为design_only。未验收Sources/Incident代码仅是冻结WIP，待TASK-SOURCE-LOCAL-TIES替换；本次文档更新不表示轻量生成已实现。

## 采用什么

**TASK-OPPORTUNITY-SERVICE 接线（2026-10-30限定验证）：** `src/game/opportunity_planner.gd`从协调索引、当前progress与共享Anchors消费者解释十目标的当前缺口；原Eligibility/prepare/Attention仍唯一判定实际输入。`src/game/opportunity_service.gd`只在Turn真正进入actions或提交已匹配的实际行动时记录服务及其结果，`state.opportunities`进入World完整/增量审计、Turn回执来源校验与原事务回滚。终局停供保留已完成里程碑，GOAL_MANIFEST只投影Powers原真实completion来源；有限摘要消费者对照不冒称完整终局轨迹。直接路线没有B票或pipeline；原Dispatch随机与审计保持原语义。两张路线/目标表的coordinated仅代表协调索引已装载，不代表整链active验收。

**TASK-OPPORTUNITY-SCHEDULER 接线（2026-10-30）：** `src/game/source_fairness.gd`是原B派发和原tick回放共用的纯权重/FIFO/冷却reducer；实际提案及提交仍只由Events注册的Producers、Sources、notice原handler负责。Sources原CSV权重在唯一source_weight入口供生成与审计共用。`prayer_dispatch` schema2/version4在原分域账本增加十一族债、冷却、最近真实来源及全局单调票号；同一`prayer_dispatch_tick`保每次call紧邻写边界、实际source、选择与账本前后，不增加派发凭据层。正常无写失格保票同槽继续，任何真实source立即停槽，异常沿原Turn事务回滚。完整/增量恢复重演相同reducer并核原来源事实、票序、权重与版本。七个Sources族还从原prayer_situation.facts回查其原scene_rule或救援rule及need，防止同类真实情境替另一族消费票；既有Producers的call/contact提案跨核仍沿原验证。该B债不修改Service的goal/step账本；mode切换仍共用原到期游标。条件界只到B真实生产，不引入direct后台管线或行动/胜利时限。

**TASK-ANCHOR-PRODUCTION-CLOSURE 接线（2026-10-30，十六条受控正式路线有限通过）：** 不新增生产系统。PlayerSources原历史传播资格核验同时读取冻结profile_rule顶层与carriers.sources的有限精确材料ID，使原网络端点和互惠原记录进入同一共享路线判定；每项仍须属于原basis.sources、早于资格事实，并保原参加者、保管和取得时序检查。不扫描历史或补缺材料。其规则版本升为3/frozen-carrier-materials。共享Anchors沿原personal_sources合并机制保留网络双端各自exchange、双人实践各自registration/uses/dependency及互惠双方各自dependency；这些均在原held判据通过后才登记到原carrier，不增加实际知识，也不让最小材料覆盖吞掉本来必须由各人持有的项。Anchors版本段升为lifecycle1/route-materials1/personal-holdings1，旧消费者版本不能继续。tools/anchor-production-closure复用当前十一模块Turn及Service，按十六真实材料分支核原依据、首遗物、route/proof绑定和实际供奉active；受控初态/Catalog停用变体与自然完整Catalog、成熟Session续存分开记录。 repair-04六业务组十六条真实生产至实付active、Godot解析及启动冒烟合计274.933秒通过，112份执行输入无漂移且无引擎错误；每次调用小于58秒。互惠路线对原护持者实际选择既有EVENT12/B并支付原费用重开一次请求，未补写成员或期限。运行与保留失败见[专项主QA报告](qa/anchor-production-closure.md)，完整Session保存、自然频率及整局终局不由本批代验。


Turn.context保存版本化PlayerKnowledge账本，bootstrap/实际focus/命令结果根在原事务内调用同一reducer。Session缓存仅作该账本的副本，保存外壳必须与Turn账本一致且版本匹配；服务内部事实不进入玩家知情。Powers的仪式配置谓词与Economy的苏醒值计算抽为原业务和planner共用，未增加终局规则。当前工具覆盖四组代表能力与受影响共享查询、组件续存和一个隔离行为负例；完整Session兼容、自然路线和B公平仍归原后继。

- Godot 4 + GDScript。当前实测固定为本机 `4.7.2.stable.official.ed1daf0bf`，开发与重放应固定同一版本，不能默认为升级后随机序列仍一致。
- 桌面单人离线是工作基线；不需要服务端、账号、联网模型或多线程才能推进一局。发行平台与各平台导出尚未验证。
- 前期只做能表达规则的基本交互。后续美术可以替换卡面、字体、材质、场景、动画与音频，不以换皮为理由改写经济和文明状态。
- 内容初始来源为 `data/*.csv`。运行时装载/构建期整理均可，禁止维护一份代码硬编码的第二套策划真相。

## 六个职责边界

1. **内容目录**保存文明组合元件、人物原型、权能、祈求和事件模板。加载前验证字段、范围、引用和相容性；表达文字与可执行效果分开。
2. **世界状态**保存文明、NPC、教团、圣物、进度与历史。对象通过持久 ID 关联，不把 Godot 节点路径当作人物身份。
3. **规则结算**接收已校验的玩家命令，先核对象资格与支付条件，再一次性结算费用、判定与结果。界面不能自行扣资源；失败命令不能只扣一半费用。
4. **事件调度**根据状态与因果记录筛选候选，处理有效对象、冷却、互斥、优先级与过期。后继效果进入后续轮次，禁止递归消费直到队列为空。
5. **表现适配**将当前可知事实转为卡牌、列表、日志与提示，并将输入转回命令。观察世界、重建面板、播放动画不能消耗模拟随机数或推动回合。
6. **存档与复现**保存数据版本、世界状态、排队后果、历史骨架、随机流状态与命令位置。读入先完整校验，再整体替换当前会话。

这些边界是后续 AI 分工边界：一个任务修改规则时，不得顺手把规则复制到卡牌脚本；修改卡牌表现时，不得改变结算时点。

## 密教schema2的目标接口与实施边界

普通聚合招募、强化传播与实际扎根采用不同业务条件。目标接口中，Cults根据成团事实、当前成员/领袖及信众状态派生cell招募资格记录；Economy从本域无名非信众池按原招募公式和余量聚合结算。Events的cooperation只提供指定材料递交来源，不增加招募量或人口池覆盖；普通招募的资格仍保留原cell/合作来源至少一条当前有效的备用规则，不改为强制cell与合作同时成立；POWER_SEED另查蓝本神迹媒介。它们不依赖未来祈求的邪神知晓字段，也不要求官方代表、普遍赞同或EVENT09A。机器规则分别由`cult_spread_routes.csv`、`cult_spread_conditions.csv`和`anchor_conditions.csv`定义，数量引用正式参数；不解析中文条件或在消费者复制蓝本规则。

**抽象范围（TASK-CLAIM-ACCURACY，2026-10-28）：** cell、route、channel等稳定ID/字段名不代表已模拟社会渠道。当前设计和运行时代码都没有多种社会网络、逐人接触/传播过程或招募目标覆盖模型；有限人物关系、机构links、指定事实/材料的引用检查只证明已记录对象与前提符合条件。普通招募的人数仍来自同一个本域无名非信众池，不按传播网络切分人群。这里没有“网络已经存在、只是尚未细化”的隐含能力声明；已接schema2资格/递交接口也不改变这一抽象边界。

TASK-ANCHOR-ROUTES拥有八蓝本传播/扎根的共享只读判定、材料归一化、实际承载者检查与当前依据维护。查询返回缺口或候选依据副本，不写事实、消费随机或制造机会；正式世界变化暂存并核验后、对外发布前才派生当前依据，与原变化原子发布。本批材料不倒灌本批候选。归一化必须保留独立根，公开包装、复制和递交不新增见证；当前判定始终重查材料、身份、真实知情和所需通路。

正式依据kind为`anchor_basis`，changes固定为`{issuer,version,institution,profile,rule,basis}`，由内容版本绑定的`civilization_dependency/schema2/routes3`能力发行。basis按蓝本有限键保存原材料，`carriers`记录实际结构、人物及其持有的来源；材料可由原见证者分布持有，不强迫汇总到每机构一人。所有引用来源进入直接父因果。机构ID是稳定现实槽位；官方敌意、无关代表换任或`institution.active=false`本身不能代替材料/载体毁损。旧`institution_event_result`、`denied`与自由`allowed=true`不授予新资格。

TASK-MATERIAL-TRANSFER只负责本轮所需的精确人际材料递交：原发送人实际确知并能提供指定材料，已有接收者、实际关系/通路和当前源成立，才发布`material_received`知情回执。09A的同事务顺序为真实合作结果→固定route→引用route的接收回执→同时核route/receipt的当前资格→原子发布，route不反向引用未来回执。它与既有真实递交共用受管理语义，不建设第二套通用通信系统，不传递未指定的父事实，也不让全机构知晓。DEC-024将09A增量改为固定接收者/真实目标结构的实际缺口：原合作者能提供指定有效材料，且已有合法递交无法提供该端点时才开放；教团别处持有不直接否决，临时预算/名额不足不算新端点。目标内合格接收者先筛选再按既有稳定顺序固定，已有可用端点不重复收费。内部同团跨机构递交无需09A，MATERIAL-TRANSFER拥有共同递交/回执内核，CULT-SPREAD只编排原事件费用及后果，不双收费或双发回执；材料族、Cults内部行动、World共同接收核、成本、目标时点和schema2回执合同已由MATERIAL-TRANSFER-DESIGN在事件§13.2及material_transfer_families/parameters/rules三表完成设计；三表已装载有限接收合同，个人内部转交由TASK-MATERIAL-TRANSFER接入；现有share_record仍只给机构指定知识；09A的open_route及原事件编排现由TASK-CULT-SPREAD接入，实际证据按下方当前实施节限定。原持有者可独立承载，没有09A也可成立依据；成功接收后发送者死亡或渠道关闭不抹掉已取得知识，材料本身与当前持有资格仍重查。

TASK-CULT-SPREAD复用共享判定，接入`cult_contact_route`、当前`economy_qualification`与PlayerSources的`covert_spread_basis`，消费时即时重判。这些资格与材料来源记录由各归属生产者按已记录状态变化派生，预览不补发；同团来源记录仍按原稳定顺序检查有效性，一条合作材料来源失效不能误撤仍有效的cell招募资格，也不全扫历史H。这是记录/资格管理，不是选择或模拟多种社会网络覆盖。`SOURCE_SPREAD_PERMIT`可保留稳定行ID，但不再代表官方许可。EVENT04A按机器status退役，提交明确拒绝；04B是保留的唯一合法默认世界后果，缺异端对象不造信众。调度、选择器和默认处理须同步，不能仅隐藏按钮。

TASK-ANCHOR-LIFECYCLE接入同一实际依据的首次遗物与下游生命周期。Anchors在事务内完成当前basis刷新后，沿原机构永久唯一键固定institution_recognized及institution_relic_opportunity；recognition/proof字段保存schema2真实basis，类型只抽一次，材料丧失/恢复不重发或续期。schema2恢复检查原依据合同、稳定机构、类型池、原期限、唯一处置及消费指向；规则版本增加lifecycle1。Events保原recover/public/wait及费用，回收预览与Relics一致拒绝已占用携带者。Relics的controlled创建按真实本域教团库存核控制，不再依赖官方active；实际携带、绑定及唯一实例仍按原合同。Events/Relics分别升级模块能力版本。创建/修复、Economy供奉及World即时休眠继续消费共享maintenance；材料恢复仅恢复资格，实际供奉才恢复贡献，需要重绑仍用原POWER_ANCHOR。Resistance不因秘密basis获得知识；Endings保原active/dormant教团及真实Prayers/Powers/Events prepare查询，降临保当前active检查，不新增Private Devotion占位或未来收入推断。tools/anchor-lifecycle复用既有夹具与输入指纹收集核四组有限实际链及少量只读消费者控制，不代表全部替代路线、完整Session续存或真人体验。

TASK-ANCHOR-ROUTES同时更新ActionCatalog锚定选源及Session合法知情投影；不能只生产新依据却让玩家仍只可选旧事件结果，也不能借来源选择泄露未知人物/材料。Catalog有限语法、World/StateView/历史当前索引、各发行方接受版本、Turn/Session安装与所有恢复校验必须同步。内容指纹覆盖新表与实际消费数据；版本持有者仍各自审计职责范围，不能只改总checksum。

TASK-CULT-SAVE-COMPAT有界处理本次内容/能力版本的拒旧和当前版本续存：旧许可/旧承认会话明确拒绝，保留原文件及当前局，不通过重签名、删除字段或重算checksum迁移。领域schema2不要求更改独立的ArchiveStore格式2；若未来实施真正旧局迁移，须另立任务逐材料重判并保留原身份、序号、绑定、消费及RNG。保存负例检查合回本任务，仅核当前版本与关键拒绝/保留原局边界，不另做全仓库联合重签审计。详细/后台祈求生产与知晓模型仍归PRAYER-DESIGN及其实施链，本节不把渠道记录当作该模型已经完成。

## TASK-ANCHOR-ROUTES的当前实施（2026-10-30）

`src/game/anchor_routes.gd`是八文明十六分支唯一的只读材料消费者。`anchor_route_rules.csv`保存profile/rule、精确basis字段、有限selector及原计数/存活/跨轮参数引用；Catalog装载并校验16行。`foundation_route_parameters.csv`和`memory_contract_route_parameters.csv`本次只为现有消费者提供人数/跨轮阈值并进入内容指纹，不装载原18项活动。`progression_route_operations/sources/routes`仍design_only，表存在不注册生产能力。材料转交三表及实际递交仍由后继实现。

Anchors保留真实Prayers/Powers成功结果的解析，归一为只读材料视图：`{id,kind,root,turn,institution,originals,owners,knowledge,current,data,causes}`。originals表示原参加/见证身份，owners表示当前可保管者，knowledge是原能力明确授予的指定知识；三者不相互推导。包装沿有限原链归回独立root，包装和原成功材料均须current；普通关闭obligation/review只结束危机，不通用撤销已经实际履行/保留的依赖。每路只核其必要根，不遍历所有parents来推知知识或判失效。实际carrier用本次有限材料的最小覆盖，稳定按机构/人物ID选定；不要求官方代表、支持或institution.active标志。

当前raw适配可识别8条原分支的真实材料：record_testimonies、calendar_rites、memory_circle、ritual_keeper、network_independent、contract_performance、axiom_nodes、dissent_circle。其余8条替代分支的有限消费逻辑可用归一输入检验，但没有正式业务生产者/raw适配；`discover`明确返回missing_producer。测试的归一输入入口不授予发行权、不向World注入成功产物、不证明路线可达。后继OPERATIONS实现实际生产时，必须增加对应受管理成功结果适配并复验共享消费者；不能只把kind字符串加入白名单或安装空handler。

未来生产技术合同只需记录实际成功结果、原参加者和将被后续消费的必要进度/材料：`route_result`绑定schema/issuer/version、operation、institution、participants和原正式成功检定；use/dependency/lesson/leg等必要材料引用该结果及原来源。其data仅保留本分支需要的series/session、operator/participant、原观察、实际use回合、两端或两腿、canonical record roots及实际term。不得恢复旧读数、日程、送达、逐人读写链；任何teacher资格等归一布尔值必须由真实生产者的当时身份核验得出，不能接受玩家自由声明。当前版本不接受这些尚未安装的raw事实。

TASK-ANCHOR-ROUTES交付时的发行者为`civilization_dependency/schema2/routes3`；当前生命周期版本扩展见上方TASK-ANCHOR-LIFECYCLE登记。anchor_system/schema2保存`version,issuers,proofs,routes,bindings,restrictions,opportunities`。routes是每槽每route的当前source，proofs是按绑定分支优先/route ID稳定选择的兼容首选头；两者是现有状态的有限投影。新anchor_basis仍严格为`{issuer,version,institution,profile,rule,basis}`，直接parents包括原必要材料，targets包括实际原参加者及carrier。Turn在受管理实际变化结束、事务验证/发布之前调用`Anchors.refresh_basis`；它不倒灌当批祈求候选。`refresh_basis(world,owner,exact_sources)`同时提供后继实际迟到递交重判入口，exact_sources只读解析已真实存在的指定材料，不制造知识或事实。

History对原结果按有限人物/材料族维护当前发现头，日常查询不扫全部facts；已有所选basis直接重查，不因历史年龄消失。PR06契约见证头只登记原结果的实际targets，不将每条结果的petitioner另加为见证所有者；同请求的对端知情/敌意见证因此不会覆盖求告者自己的履约头。实际知情、保管及两端原见证仍由Anchors.material和原资格核验证，不由索引补授。原材料束的派生索引保留其最初basis ID，相同实际bundle失去再恢复不重复发行。页面/预览只调用evaluate/qualify/discover。spread查询从同一真实材料发现与谓词取得只读候选，因此CIV01同轮双独立材料可强化传播但不能锚定；它不为了传播伪发可锚basis。CULT-SPREAD以这些真实sources发行自己的来源记录。旧circle允许原holder在各自当前机构自持个人资格，目标槽须有本地原holder持共同memory；双人实践与网络分支仍核其明文当前links。实际05B只让真实heir承接原dependency/auth，不授死者旧witness或原参加身份。

Powers创建/修复准备消费所选新basis并重查当前材料，成功沿原费用/检定绑定route；切route仍需真实POWER_ANCHOR修复。同分支当前材料束刷新由该共同谓词处理；维护不从另一分支自动救活已绑定分支。Powers能力版本为`3/anchor-routes1`前缀，Economy注册版本为`2/anchor-routes1`前缀，均绑定当前Anchors内容版本。新ledger/current heads与真实paid-success绑定恢复审计同步，schema1旧事件批准不升级为新依据。TASK-ANCHOR-ROUTES当时未发行首次遗物，且明确拒绝非空opportunities；这是该任务的历史交付边界。当前首次遗物生产、机会恢复及代表性供奉/终局消费者已由TASK-ANCHOR-LIFECYCLE接入并有限验证，见[专项报告](qa/anchor-lifecycle.md)；完整Session恢复仍归TASK-CULT-SAVE-COMPAT。

Session只在必要材料与人物已分别知晓后，向现有权能来源选择投影当前basis；读取它本身不补未知人物/材料。ActionCatalog按已选目标机构只列当前合法来源，失效历史保留历史用途。沿既有功能载体与OverlayRoot，仅改选源语义和文字，不新增布局、样式或视觉语言。原PlayerSources密教来源拒启现由下方CULT-SPREAD实际消费接线替换。

## TASK-MATERIAL-TRANSFER的当前实施（2026-10-30）

`src/simulation/material_transfer.gd`是World内部的有限材料接收实现；World提供`preview_material_transfer`、`material_endpoint_available`及仅事务内可写的`receive_material`。没有新增参与者、通信循环或第二套权威账本。Catalog装载三张`material_transfer_*`表并校验有限schema、原参数和调用合同，内容版本进入World接收回执、Cults/Events/Anchors能力及Session保存头。runtime_status按能力分层：八个当前材料族为implemented；十二个后继route/route_basis族为design_only，解析明确拒绝unsupported_material；四个非普通转交对象为unsupported_material。Catalog逐族核有限ID及相应状态，解析器仅接受implemented族，不自动安装未来selector。INTERNAL_TRANSFER为implemented；COOPERATION_09A由CULT-SPREAD实际事件接入后改为implemented；ORIGINAL_RESULT为implemented，仅覆盖现有真实learn适配，不代表所有既有告知已验收。

当前解析复用Anchors的真实Prayers/Powers成功材料，支持证言、梦境、祭仪、异常记录、记忆资格/分歧、契约依赖/见证八族。后继route/route_basis族没有实际生产者时明确`unsupported_material`。归一增加`canonical`成功材料ID用于端点去重，保留原独立root、原参加者、原发生回合。schema2 `material_received`事实与原个人known_facts为权威；History只维护canonical材料的派生接收索引。custody回执可增加实际保管者，普通knowledge不增加保管；两者均不改原见证、实践、契约责任或独立性。

Cults阶段三的`transfer_material`固定原材料、双方、目标及层次，按原同一连续教团/当下机构接触条件执行。Attention以正式`CULT_TRANSFER_MATERIAL` policy申报双方，费用读表，不占回应/执行人任务，不使用随机。Turn将本次唯一`turn_action`付款引用交给共同核；费用事实固定canonical端点，schema2回执引用本次付款、发送者原持有及已有channel。接收、限定知情和迟到basis在同一既有事务内发布，失败沿原机制回滚。原Prayers个人learn仅在已安装材料且实际发送者先持有时复用knowledge接收；普通原根/机构告知和PR10直接揭示保留原能力语义。

Session/ActionCatalog从分别已知的人物与有限当前材料列合法选择，复用原durable request重试；GameRoot经营原列表加入交予记录并保留轮末经营计划，沿原详情/预览/动作控件和OverlayRoot，不新增样式/布局。当时材料组件接线未解除PlayerSources拒启；当前安装和09A原费用/敌意/察觉编排由下方CULT-SPREAD接入，完整Session保存继续仍归TASK-CULT-SAVE-COMPAT。本项不生产互惠两腿、不创建锚点或首次圣物。

## TASK-CULT-SPREAD的当前实施（2026-10-30）

`src/game/cult-spread.gd`归Cults拥有，维护当前有源招募资格，不增加Turn参与者、人口池或社会传播过程。`cult_system/schema2`保存`spread_version`和逐团有限`spread_routes`头；Cults由实际成团、当前领袖/成员及信众状态发行COVERT_CELL，Events只由实际09A结果发行ALLIED_CHANNEL。共同选择重查源、当前对象和必要接收回执；合作失效仍可回退有效cell。`economy_qualification`保存原成团/领袖、所选channel/receipt的来源，Economy仍以原参数对本域无名非信众聚合结算，无源或无余量转守持且不付传教费。

PlayerSources当前版本消费`covert_spread_basis`并复用Anchors的同一只读spread判定；来源固定真实channel、实际材料和actor，不以可锚basis替代传播自身条件。Powers在预览及正式支付前重判。历史证明重建原人物/独立材料身份，当前死亡、材料撤销或渠道变化不改写历史；当前使用另查存活与材料。Turn在实际变化发布前刷新Cults、Anchors和PlayerSources当前头。StateView的授权查询使用`{ok,used,source}`合同。

Events按CSV的active分支选择；04A退役，合法04B按原时钟自动默认，缺合法heretic只发布本次解释被否认而不增加信众。09A固定原合作者、材料、目标和已有接收者，调用共同新端点检查，原子发布事件结果→route→schema2接收回执→当前依据，沿原4信仰、0低语、原双方hostile和3察觉，不叠内部转交费。材料接收后同时重判basis；已有合法内部递交、已足够的分布材料或临时预算短缺均不成为付费新端点。

Session现正常安装全部10个模块，再运行正式bootstrap；来源选择只对分别已知的必要材料与人物公开，不为了自动派生来源泄露隐含origin或未知对象。原控件/OverlayRoot及视觉语言保持；本项不增加UI结构。Prayers对祭仪者改用reader/history的当前域活人物索引，避免事务ArchiveStore打包后漏掉非代表祭司，纯读取与事务内复验采用同一资格。

本项机器入口为`tools/cult-spread/verify.py`：四组少量实际行为、材料4组、锚点4组、原来源核心17组及Godot解析/正式启动冒烟；没有npm/TypeScript/lint工程，类型与语法由同一Godot解析检查，行为和启动由实际引擎验证。执行输入指纹及原始失败/成功结果保存在`tools/cult-spread/runs/`；最终当前复验见`docs/qa/cult-spread.md`，不能以代码登记替代通过记录。显式已有教团、初始资金/洞见、既有情境及控制检定是夹具；材料、支付、事件、回执和正式新局首窗是实际生产结果。TASK-CULT-SPREAD当时未验锚点生命周期；当前代表性生命周期及终局消费者的有限证据见[专项报告](qa/anchor-lifecycle.md)。自然首团、未来材料生产、全部替代路线、整局Session存取和体验仍归后继。

## 两类求告的目标接口（TASK-PRAYER-DESIGN）

本节定义目标接口，实施分批状态须与报告分别读取。整改前代码只有NPC的`known_facts`、指定祈求效果的`learn`和玩家Session账本；World仅向非重点到期域调用AbstractSim，重点域消耗游标却无接替生产。KNOWLEDGE已接入身份认知及本次意向；DISPATCH已在安装Events的正式阶段四接入两模式协调、共享新机会、已发布situation的每轮有限检查和指定身份告知。PRODUCERS已将正式选源接到04/05/08/09的原根、call及bootstrap，代码接入与限定验收须分别读取；四格及最小知情由INTEGRATION接续。无Events的旧独立模拟工具保留旧路径。`simulation_responsibilities.csv`名称比对仍不证明生产，当前接线及消费也不证明十二类原根或自然新局均可生成。

目标只保存有限人物的邪神识别取得来源、指定告知和具体求告意愿，不模拟社会传播网络。NPC知道一条事实、承受回应或收到指定材料，不自动代表已识别邪神；失败、无感知影响和与身份无关的告知尤其不能据此授予识别。知晓不等于信仰、忠诚、机构察觉或当下愿意定向求告；知情者也可无向求告。无向PR08表达愿向回应者献身，不能伪称已认识邪神。玩家发现文明、观察人物及取得/撤去F都不改人物认知。

TASK-PRAYER-KNOWLEDGE负责版本化的有限认知取得/指定传递及意愿来源；`deity_identified`记录直接辨认，`deity_identity_received`记录具体发送者、接收人、原知晓及关系/通路。本局identity从世界种子、schema及初始world_origin规范身份稳定派生并保存，不取墙钟、路径或Session临时campaign键，不额外推进随机流。只有新规则明确的成功梦境、谕言辨认、PR08接受献身和指定身份告知能生产，旧成功事实不能自动升级。普通事实知识继续沿World与HistoryIndex的已有入口，Session知识仍仅是玩家可见账本。识别、意愿和当前可执行联系分别核验；暂时失能、失去处境或撤销指定来源可影响当前资格，不从撤关注推断遗忘。新记录须保留具体对象、取得/告知依据及历史切点，不能在完整恢复时拿当前known集合倒推旧卡采样时已知或未知。

TASK-PRAYER-ORIGINS负责正式生产调用与模式交接。新处境沿两种模式共用的每域到期游标、四轮一次/每次一次尝试预算采样；已发布原根则进入有限due/待求告索引，两模式每轮在原一次尝试预算内检查并提案/固定，不运行后台居民agency。这改变了旧后台既存根的检查频率；它不是继续让所有来源每四轮才检查。详细与后台分派实际调用受管理生产者，同一次机会只能消费一次，不因换F或切页面补抽。原根、知识和意愿使用本次既定快照；本批新根/新取得不反灌本批采样。普通原根T发布，最早T+1据它求告并固定，T+2可见；没有独立危机的contact可据既有人口/机构快照当次求告，具体bootstrap边界由事件规则规定。固定直接使用当次T+1可见规则，不能再拖到下一轮freeze后重算。

唯一正式接线为Turn阶段四的World.evolve调用Events注册的candidate_generation协调者；模式处理者和root_id→handler使用同一张正式执行绑定，CAPABILITY-GUARD核这一绑定，不另造自报注册表。World拥有自然root/当前知晓投影的受管理写入，Powers/Prayers拥有其实际行为导致的身份取得，Prayers拥有call/situation的规范语义与发生键；物理变化经World/Turn同一事务校验、仲裁、发布，固定统一调用World.fix_prayer_source。ROOT_ACTUAL_SEIZURE由真实归属变更的授权事务在发布前写原失主通知，不在after_commit补写；KNOWN_RECORD的record_source_view只是只读选择器，规范根/call/facts.record解回原记录，不能添一份异常或独立见证。

既存原根按原due、发生键稳定排序，每域每轮最多`background_candidate_trials`个确定性检查，不再投ambient概率或重抽原根/人物。方向对同一发生键只选择一次，采用版本化稳定种子并记录求告；发生键不含方向，知识/意愿更新、容量失败、模式切换都不重抽。当前索引按`subject/need`维护有限当前head及必要原根束，到期/已消费退出；历史原事实仍可审计，分页遵守`decision_query_page_limit`并续游标，不通过另建无限待固定池掩盖候选上限。

**实际行动窗先于固定预算。** PRODUCERS在预留/固定前计算最早展示、实际行动阶段与原due，并区分轮初阶段一和行动后的阶段五到期：原根T发布→T+1固定→T+2展示，原危机必须在至少一次合法行动机会之后才到期。例如due为T+2且在该轮行动之后的阶段五执行时，仍保留最后行动机会；due更晚按原窗口处理。轮初已到期或没有合法行动窗的旧根不固定、不占holds，按原期限结束；不能延危机等展示。代码接线与本轮行为检查结论分别登记。新病危/义务/记忆风险/争议的自然根由后续根族任务在出生时按两阶段管线与该PR原lifetime固定due，不因实际固化推迟再算；旧根due保持原值。PR09的barrier_contact没有独立crisis，不借其两轮请求lifetime制造一个新危机due；请求due仍由visible加原lifetime减一，与原危机时钟分开。

根、求告、提案与固定卡是不同产物：有限根生产者形成具体处境，`prayer_call`固定本次addressing、意愿规则、采样knowledge与`snapshot={turn,phase,commit_seq,fact_cutoff}`；采样仅接受已在该快照提交且事实位置不晚于截止的取得来源，不能只比acquired_turn。`prayer_situation`及descriptor的`call`引用它。addressing不挪用旧source_mode字段，后者仍区分current_background/known_history来历。提案不占持久身份，固定仍进入唯一`simulation.candidates`及共享holds。同源键取规范原根束、求告者、need及实际发生身份，不因方向、包装factID、F或重试改变；固定后不升级方向、不换主体、不续原due。F只管理回应/主动干预及详细预算，不作为求告存在与否的认知开关；固定时仍按原P/N/L去重、全局活身份及候选容量核验，不能用无F伪造名额，也不能为持续认知永久保留无限详细人物。

同一conflict/person先按`origin_rules.exclusive_group=conflict_petitioner`在当时合格need中稳定择一，持久保存selected_need再构发生键；不能借recognition/judgment两个need为同一争议各得一张。容量失败、关切/知识更新及换包装不另选第二型，重开保留原need/call。此前事故逐环节handler是冻结WIP；TASK-SOURCE-LOCAL-TIES按DEC-026改为轻量情境生成，不再要求该活动/事故/通知链。

人物提名占全局活身份K；互动承诺的P/N及既有L去重是另一项检查，认知历史不永久占P。已有具名人物及合法原根的完整call与selected_need是可提交的世界意图；正常capacity_blocked只撤回fix子尝试的预留/候选写入，保留同一个完整call、方向、采样证明与原时钟并记录原因，不产生固定卡、holds、费用或延期。它只占原当前根头，不另建call池，也不授详细互动权限；下次容量检查不重抽方向、不重发收益。真正World/Turn事务异常则连同本笔新call整体回滚，未成功提交的求告不冒充历史第一次。

匿名contact/bootstrap先核人口、活身份及完整P/N/固定池容量，通过后才原子完成提名扣人口→call→situation→fix。容量不足时不产生人物、call或模式选择，只记尚未承诺的原因；以后有容量属于新的合法提名尝试，不能保留指向未出生身份的call或给群体继承个人知识。bootstrap在初始化世界/人物根已提交后的独立快照取得无向PR08起点，验证实际浅触与成员准入容量；不预授认识，不改用高阶模板兜底，无合法起点则整个开局明确失败。

有限语法的设计单源是`prayer_addressing_modes.csv`、`prayer_knowledge_rules.csv`、`prayer_origin_rules.csv`和`prayer_root_rules.csv`。它们分别声明方向条件、识别取得/指定传递、十二祈求的根/主体映射、原根生产阶段及期限规则；不能把CSV行存在当作已注册运行处理者。未实现原根拆为SOURCE-LOCAL-TIES、SOURCE-LOCAL-CONFLICT、SOURCE-CONTRACT、SOURCE-MEMORY、SOURCE-EXCEPTION有界批次，由SOURCE-CLOSURE链追踪生产闭合及剩余接线。初始化当前只有world_origin、support关系及低理智strain，没有可直接当作病危、契约或宇宙例外的通用根。包装为`prayer_situation`或给定合法contract只证明可消费，不证明根生产。每族须分别登记原始前提、正式调用、产物、消费者与缺前提负例；详细/后台×定向/无向四格由ORIGINS检查，跨根自然发展另由NATURAL-VERIFY验证。

新增CSV语法、认知/意愿记录、当前来源索引、游标/RNG和固定卡字段必须进入World/HistoryIndex/StateView、Prayers/AbstractSim及Turn/Session对应版本审计。当前源只按索引和明确对象读取，不逐轮展开历史H或枚举无名人口的人生；完整恢复重建派生索引并核固定时的原始证据。Session只呈现已固定可见祈求及必要线索，不向玩家提供隐藏知情者清单或底层全部无向来源。旧内容/能力版本拒绝与当前版本续存沿TASK-CULT-SAVE-COMPAT，不能靠重算checksum补造认知历史；生产接线、短行为探针和自然新局证据继续分开。

## 文明生成和状态演化的选择

采用“受约束的有限元件组合 → 完整性检查 → 有限重试或明确失败”，不让模型每回合自由发明规则。文明规模对应抽象范围，不枚举实际星球人口；无名信众聚合计算，只有少数具名人物逐个演化。

范式可以混合；机构和传播方式必须满足前置，例如某传播方式需要其知识范式支持。规则检查的是已编码的相容性，不能自动证明文学和社会学上的自洽；这些需要内容编辑。

按同步回合结算，保持可复现、可调试，不预先引入线程池或复杂 ECS。增量事务、索引与分段保存已排入当前 Slice 04，先在全详细参考模式保持结果等价；详细/概略混合是有明确预算的新规则，不要求未被观察的日常细节与旧模式一致。折叠界面不改变模式，后台风险、经济与承诺不冻结。

## 因果叙事与 AI 内容

AI 首先用于制作时生成候选；候选经人工编辑和机器校验进入 CSV。运行时依据事实选择与填充模板，不调用大模型决定状态。模型写出“某人死了”不能直接改人物状态，反过来模板也不能把已死人物当活人。

因果历史至少保留发生回合、参与者、所涉文明、原因 ID 和结果类型。玩家编年史是历史的可知部分；调试历史和玩家已知情报不能混用。

验证工具保留完整 ID 与父因果骨架，只丢弃旧显示细节，因而不会因压缩而断掉仍被引用的父节点。其存储仍随行动量增长，千回合压力测试已测量保存开销；不承诺无限生成或无限长度战役。

本次未调用外部生成服务，也未验证 AI 文本的重复率、叙事品质、语义自洽、模型成本或人工编辑吞吐。若以后加入运行时生成，必须另行定义不可写状态的权限、超时回退、缓存和成本；不应成为当前方案的隐藏依赖。

## 随机与存档的硬边界

- 生成、判定、事件分别使用随机流。美术表现另用独立随机流，音效变化不会改变未来抵抗事件。
- 随机 `seed` 和 `state` 按十进制字符串存入 JSON，避免大整数被浮点化损坏；恢复时先 seed 后 state。
- 本次验证的是同一 Godot 版本、同一内容指纹、同一命令序列的复现。引擎官方不承诺底层随机算法跨版本不变；跨平台逐位一致也尚未实测。
- 存档携带 schema、内容指纹和引擎版本。未知版本、坏校验和、断引用、会复用的 ID 序号必须拒绝；不得为了“能读”而静默修补。迁移器在有真实旧版本时单独实现和验证。
- 玩家死亡/苏醒结束一局不等于删除物理存档。结局回顾需要保留历史；自动保存、轮换备份、断电恢复、云存档与跨版本迁移属于正式实现的任务，本次仅验证读写与拒绝能力。
- 校验和用于发现损坏，不是防作弊签名。

## 美术后置但结构先留好

正式呈现根建议为 `GameRoot/Presentation/CanvasLayer/OverlayRoot`，固定逻辑分辨率基线为 1280×720，等比缩放与留边只处理显示，不设置响应式断点。任何屏幕空间读数都挂在这个根下，规则结算不访问它。当前无正式UI工程配置；后续实现与本段同步，不在多个文档维护不同分辨率。

卡牌用统一视图接收“对象 ID、当前可见信息、可执行命令”；具体卡面与动画不决定目标有效性。样式集中到 Godot Theme 和资源目录，动画与声音订阅已发生的结算结果。表现可跳过、加速、重新构建；跳过动画不能跳过或重复结算。

对外部卡图的引用用稳定资源键，不写入人物本体；存档不保存纹理对象、节点实例或即时动画进度。未来由占位列表切换成桌面、神域或其他表现载体，应保持同一规则入口。该替换能力目前是架构约束，尚未用正式双视图做实测。

## TASK-PRAYER-KNOWLEDGE的实施边界

`src/game/prayer_knowledge.gd`集中管理稳定神祇身份、有源取得/指定告知、人物当前投影及本次求告意向；World仍拥有持久事实和事务，Powers/Prayers在实际结果提交时调用取得处理，StateView提供隔离读取。它不是第二套世界，也不代管根族生成或候选池。Turn回执以sequence/fact_before/fact_after标记实际提交及[next_fact_before,next_fact_after)半开事实范围，完整恢复核连续边界；Knowledge按这些真实范围核采样与取得位置，不能让call自报cutoff作为唯一证明。恢复时另将神祇身份所用seed与存档实际generation RNG seed绑定，不能只在知晓记录内部自证。取得、call与消费状态参与World/Turn快照审计；DISPATCH补指定身份告知的自动选源/四轮共享机会及同事务授权接收，并核调度采样位置。首名信徒以本次实际member_enrolled/binding_source取得识别，不要求已有教团；仍核原献身、请求及同笔回执。PRODUCERS补04/05/08/09转换、固定及bootstrap，玩家最小知情仍待INTEGRATION；各批实际限定结果分别见报告。当前实现与限定验证分别见报告，不能由模块登记推定自然新局已通过。

Catalog已装载四张祈求规则表、两张密教来源表及player_source_rules并绑定扩展指纹，校验有限语法与引用。PlayerSources现由CULT-SPREAD实际消费covert_spread_basis，完整Session在全部正式能力安装成功后启动；能力与引用校验继续保留，目录装载本身仍不代替实际行为证据。

## 已存在与拟建模块

TASK-PRAYER-ORIGINS按单批预算拆分。`src/game/prayer_dispatch.gd`维护已发布合法situation的当前head/分页位置，并与Producers当前原根头协调每轮的一次合法提案；Events注册的candidate_generation拥有唯一正式分派，World在阶段四使用同一冻结快照。指定身份告知及04/05/08/09新处境共用每域新机会，既存原根的转换也经同一root handler表。索引/游标由World事务和恢复审计覆盖。INTEGRATION仍须验四格及最小玩家知情，不能把本批模块和短行为证据当作父ORIGINS或完整新局完成。

TASK-PRAYER-PRODUCERS本轮实施`src/game/prayer_producers.gd`：由正式Events协调，只维护有限人物/诉求的当前原根头、知情记录分页位置与增量dirty标记，不将全部历史已知记录复制为新候选池。04的`facts.record`解回规范原记录；可选内部`record_knowledge`保存人物实际知道的那份发布包装证明，随situation、call basis descriptor、固定card与request descriptor保存并核采样截止，不授予原父事实知识，也不进入规范发生键制造第二次机会。此字段不得作为玩家公开信息，最小投影由INTEGRATION接续。

本批开局接口为：World先提交合法初态，再在正式能力安装成功后由`Turn.bootstrap_prayers()`进行0轮/0正式回执的独立初始化事务，取独立快照并核人口、活身份、P/N、固定池及实际浅触费用；成功发布无向08，失败保留原局，不随机借高阶请求兜底。Session只在全部服务安装成功后接这一步；CULT-SPREAD已接当前全部能力安装与正式首窗。本段保留PRODUCERS的实现合同，其五类新原根、四格/最小知情的验收由各批QA登记；当前完整新局的有限运行证据见CULT-SPREAD当前实施节。新增状态/规则能力采用明确新版本并审计当前续存，不通过重签名迁移旧语义。

首个无向08以`prayer_bootstrap{candidate,source,petitioner,faith,whispers}`事实及唯一授权键绑定，首正式回执仍为sequence1。需要原政策成员准入的正式card持久引用`admission_token`；其原P/N预留与card对应，按同人ID并集计数，关闭时释放并由World增量/完整审计核验。它和record_knowledge均为内部证明，INTEGRATION须在请求、结果、历史及续存投影中隐藏。具体字段与准入规则唯一见事件§11/§14，本节只登记模块交接。

本批对经`World.fix_prayer_source`固定的有危机情境，将请求due限制为常规窗口与原危机due的较小者；AbstractSim的候选能力版本改为`abstract-v2-prayer-window`，旧BG独立参考路径保留其原协议。正式card的`source_mode`与求告方向分开，由原call.need派生：04知情记录为known_history，其余当前来源为current_background；无call的旧typed消费合同保留known_history，固定与审计共用同一派生函数。知情记录分页由HistoryIndex按实际取得回执的追加位置索引，恢复按采样cutoff核连续页，而非只让ledger与metadata相互印证；该索引不把全部知情记录变成待固定候选。

已存在的独立验证模块位于 `tools/feasibility-godot/`：`catalog.gd`、`simulation.gd`、`run.gd`、`verify.py`。它们只消费 `data/feasibility_*.csv` 技术夹具。Godot 工程可无界面运行，机器报告会标记当前源文件指纹。

`src/simulation/` 是消费正式 CSV 的人物与文明纯数据规则核心，由 `tools/formal-simulation/` 无界面驱动并生成独立报告。根 `project.godot` 是正式规则的 Godot 入口，没有游戏内 UI。该核心与旧夹具分开，接口与运行范围以 [正式推演报告](qa/formal-simulation.md)为准；正式经济由下述 `src/game/economy.gd` 接入，全部权能、祈求/终局与表现仍分别追踪，不因基础联动通过自动完成。

模块职责：`catalog.gd` 读取并检查正式定义；`world.gd` 管持久对象、正式属性、合法命令、有限自主行为、机构证据与推演、事实因果和版本化快照；测试器只构造明确场景、调用规则入口并记录证据，不成为另一份游戏数值来源。旧夹具保留为历史技术验证，不供正式核心装载。

## 统一回合的接入边界

`src/game/turn.gd` 负责六阶段唯一游标、阶段合法输入、持久请求凭据、锁定计划和待执行后果；它包住同一个 `world.gd`，不复制第二个世界。NPC 与文明共同快照仍由正式核心在阶段四执行。核心独立验证使用的 `begin_turn / evolve / advance` 不是另一个玩家回合入口；协调器接管后的阶段推进须由它授权。

`src/game/endings.gd` 是正式终局参与能力，消费上述同一世界与 Powers 仪式，不拥有第二套仪式或进度数据。它只在正式安装后接管终局顺序、自弃、当前断联审计和分页回顾；未安装能力的既有有限测试合同保留原验证边界。

事件处理、玩家操作、预支付、收入、期限与终局由已登记的规则参与能力提供。参与者接收数据视图并返回受限效果声明，不能获得任意状态写权限，也不能自行推进回合或消费模拟随机流。资格、来源、费用和效果先检查，再经归属入口提交；合法失败保留费用与结果，接口失败回滚本笔事务。参与者需要持久保存的信息进入协调器的纯数据状态，不能藏在不受回滚或存档管理的对象私有字段中。

到期工作按完整批次处理身份冲突：死亡优先，因主体死亡而失效的普通恢复或迁移留下取消原因，不能由工作编号排序决定是否复活或卡住回合。已预告的当轮轮末期限可以在阶段五开始前合法入队；到期处理中产生的同类后继不得递归在本阶段继续执行。

协调器快照必须同时包含世界/RNG、阶段位置、冻结事件、计划/期限、回应与执行机会、请求回执及参与能力版本。先完整验证后替换；阶段四结束不是新一轮开始，读档不能重跑演化或预支付。整合测试在 `tools/turn-cycle/` 运行；正式核心回归仍由 `tools/formal-simulation/` 独立执行。

回合编排套件的证据必须区分真实 NPC／文明调用与其他系统的验证参与者。验证参与者可证明扣费、收入、期限和终局读取的顺序及事务原子性，不能证明完整经营、全事件/权能或最终胜负规则已接入。正式经济另由 `TASK-ECONOMY` 的生产规则与专用套件验证；`TASK-EVENTS / TASK-POWERS / TASK-ENDINGS` 等继续独立追踪。缺少当前局势必需能力时明确拒绝，不能以空回调补齐“六阶段完成”。

当前参与能力的检定由协调器管理判定随机流；完整事件候选抽样尚需在 `TASK-EVENTS` 接入受管理的事件随机流与状态回滚，不能在参与者内部调用全局随机数或以检定流替代。完整回合成本单独由整合报告测量，不能把单独人物／文明演化的耗时当作完整回合耗时。

## 正式经济的接入边界

`src/game/economy.gd` 在 `TASK-ECONOMY` 中承担已有教团的生产经济规则，消费正式 CSV 的费用、收入、招募和自然流失参数；它不创建第二份世界人口或信仰。轮初收入资格在本轮到期人口变化之前锁定，提名、迁移、死亡与流失同步扣减这份资格，新增与迁入不补当轮资格。资格、流失小数余量、计划与已结算账目都属于可恢复的会话，不能藏在参与者私有字段。流失余量使用固定整数单位保存，避免临界整数人数被浮点误差拖后一轮；收入事实还须关联改变人口资格的真实前因。

统一回合通过受管理的轮初记账与共同演化接点连接经济：前置支付落地后，经济、人物与文明从同一快照决定本批变化，待所有候选确定后再合并。招募或敛藏不能先改世界让同批文明重新选一次行动，察觉等共享数值在合并后裁界。阶段五收入读取此时存续的合资格人口与教团；其后的期限后果照原顺序影响后续状态与终局，不追扣已合法收入。

经济预览与正式提交使用同一规则计算，预览只返回支付顺序、可用资源和失败原因，不扣款、不生成事实、不消耗随机流。结束行动锁定计划，实际结算仍重查当前资格。已有锚点的费用与拒付时点接入经济。TASK-CULT-SPREAD已按上节聚合招募资格接口替换普通扩张对EVENT09A许可的依赖，维持仍由TASK-ANCHOR-LIFECYCLE接入实际依据。上游资格必须有明确来源，缺必需能力和明确不合格分别报告，不能用默认布尔值代替已有对象的真实资格检查。

经济验证位于 `tools/economy/`，与原回合和正式推演套件分别保留。正式收入不能再由测试参与者填一个任意奖励量代替；报告必须披露已有教团、锚点和上游资格事实如何准备。加入经济后的完整回合成本需重新测量，保留历史增长和全量事务快照的风险；任何性能优化都须保留原子性、因果与续存反例。

## 实施约定与证据入口

[实施保障](implementation/README.md)及 `traceability.json` 将关键要求关联到唯一 spec、结算归属、任务前置和实际检查。运行 `python3 tools/implementation/check.py --impact MECH-PEOPLE` 可得到本次改动需读与回归的上下文。框架 agent 定义和流程不在本轮修改。

世界状态只有归属结算入口可写；具体阶段和冲突规则由 [回合规则](specs/system-turn-economy.md#9-跨系统结算约定与责任)及原系统 spec 定义。追踪器检查归属登记是否重复，运行场景检查实际结果；静态登记不证明代码没有绕过入口。对同快照打乱遍历、多因果、重复事实、保存继续等行为需实际验证。

正式推演报告必须带规则、CSV、实现和测试器的内容哈希；检查记录发生变化时，工作台将旧通过标为过期。报告未覆盖的来源、没有对应检查编号或只有报告文件存在都不能支持验收。来源基线、报告新鲜度、实际通过与游戏体验是分开的状态。

## 技术资料

- [Godot 命令行](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)：支持 headless 与脚本执行，便于自动验证。
- [RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)：同 seed 的序列、state 恢复和底层算法不保证的边界。
- [存档](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)：持久对象与序列化能力；本项目采用纯数据快照而不是把节点作为人物存档。
- [场景组织](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)：职责聚焦、低耦合与父层提供依赖的组织依据。

## 分层推演的正式接口与迁移边界

本节由 TASK-FIDELITY-RULES 定义；TASK-INCREMENTAL-TX 已接入受限读取与事务边界，其验收状态以追踪源和 [专项报告](qa/incremental-tx.md) 为准。有效历史索引已接入，实际验收见 [索引专项报告](qa/history-index.md)；分段档案已接入；概略生产者在受控分配中接入，实际玩家注意力已在hybrid模式接入，完整混合负载由下一项验收。这是架构中的单一接入约定，不是新建第二份世界；规则函数保持全详细参考语义。

### 规则归属与内容入口

- 文明模式、按需生成、后台日常及风险资格：`system-civilizations.md` 第 10 节。
- 人物集合、身份与绑定成员转换：`system-powers-cults.md` 第 10 节。
- 固定候选、主体持有及历史冷热边界：`system-events.md` 第 10 节。
- 容量准入、阶段时点及唯一生产职责：`system-turn-economy.md` 第 12 节。
- 锚点/终局/持续工程在后台的资格：`system-progression.md` 第 11 节。

`data/fidelity_parameters.csv` 保存新数值（id/value/unit/activation/rationale），activation 区分 hybrid、indexed、segmented，不代替运行时实现标志。`data/intervention_policies.csv` 以 family/content_id/variant 唯一对应正式入口；focus_scope 为 none/target/source_and_target/ritual_domains，person_scope 为 none/participants/fixed，member_scope 为 none/nominees。participants 取当前分支全体需持续详细的实际主体；fixed 只用已经固化的主体，不授权提名新人。nominees 为本次可能加入的不同人物集合；已绑定者去重。需求集合由分支效果图推导并取所有可能结果的最大值，CSV 不通过固定整数掩盖多人/双域分支。事件调用权能时取两者需求并集；无法静态确定上界的内容拒绝装载。

`data/simulation_responsibilities.csv` 是制作/校验用的职责矩阵：focused/background 声明生产方，commit_owner 指原权威写入责任，phase 明确阶段。它不允许按 CSV 动态加载任意脚本。分类与职责枚举在实现中是有限协议，效果量仍从所属内容表读取。新参数不得复制 event_parameters 的展示数、civilization_parameters 的持久身份上限或 run_parameters 的成本。`catalog.gd` 保持原十表的玩法内容指纹；HistoryIndex 独立装载并校验已启用的 indexed 查询策略，读取 decision_query_page_limit，并持有自己的策略指纹。segmented参数由ArchiveStore读取；AbstractSim装载hybrid参数/职责/背景模板并持有独立指纹，入口表与实际玩家准入已由ATTENTION接入；静态检查不冒充这些运行时已启用。

### 接口及责任

1. `src/simulation/state_view.gd`（INCREMENTAL-TX）：按版本提供不可变实体/当前投影读取和声明式查询。调用者只拿可安全复制的有限结果，不拿整个权威 Dictionary 或嵌套引用；无整世界 serialize 或 history.values 访问能力。接口拒绝未知读取范围，运行时记录读取对象/页数供验证。
2. `src/simulation/transaction.gd`（INCREMENTAL-TX）：`stage → qualify → arbitrate → merge → refresh → validate → publish`。暂存本笔对象与反向依赖、ID/RNG、阶段游标、预留、事实和索引变更；最终合并后的候选状态验证守恒、唯一归属和预算，再一次发布 commit_sequence。失败撤销本笔，已提交旧请求保持。不能靠每一步各自合法代替合并校验。
3. `src/simulation/history_index.gd`（HISTORY-INDEX）：当前风险/知识/成长消费/按域活动/期限/请求键索引，事务内增量维护。按稳定键访问旧来源；计数投影须支持来源删除与去重。查询返回 items、cursor、complete 和来源版本；分页大小取 CSV，消费者不许把 complete=false 当作无其他合法候选。决策优先使用充分投影，否则有限分页查询须登记预算与失败行为，不能默默遗漏。
4. `src/simulation/archive_store.gd`（ARCHIVE-SAVE）：不可变事实、父因果、知识来源、消费键、旧回执与阶段日志按 CSV 粒度分段。热根仅保留当前指针/索引。manifest 发布最后完整 commit_sequence；checkpoint、段、提交记录同版本、校验和及内容指纹。未发布尾部忽略，已发布损坏拒绝，绝不回滚到更早版本谎称成功。恢复到临时会话全量语义验证后整体替换；不把完整读档审计伪装成廉价增量保存。
5. `src/simulation/abstract_sim.gd`（ABSTRACT-SIM）：`propose(summary, domain_ids_due, responsibility, bootstrap)` 只读当前摘要，返回下一游标与带 snapshot_version/producer/object/duty/source_ids/once_key 的未承诺候选。自然日常仍由world的同一公式按唯一到期分配执行，不复制第二个结算器。共用风险选择按所有域当前投影逐轮运行，既有经济保持唯一生产方。候选生产成功不等于完整祈求/事件已接入。
6. `src/game/attention.gd`（ATTENTION）：`preview_needs(command, view)` 和 `reserve(needs, transaction)` 使用同一谓词；返回 F/N/P/活身份需求、现占/待释放/预留及拒绝原因。候选固化持有引用、入团转换、撤关注及跨轮工程均纳入存档/回滚。阶段四按冻结职责生成唯一分配；ABSTRACT-SIM 可先使用受控已分配场景验证协议，但不能让正式游戏入口绕过此模块。

世界身份/人口/证据仍归 `world.gd`，资源/收入仍归 `economy.gd`，六阶段及玩家入口仍归 `turn.gd`；上列辅助模块不是第二套数值结算器。完整事件候选与祈求后续沿自己的参与能力接入，共享同一 world/transaction。

### 增量事务的实施粒度与校验覆盖

事务使用集合级首次写入与保守反向依赖闭包：普通计划/阶段游标变化不必暂存全部人物；会修改人物、人口或证据的效果先取得相应集合写权限；人物/证据集合只复制活对象、当前有效对象和本笔明确变化的记录，冷字段共享不可变树，旧墓碑分享原记录。集合根的浅复制及身份检查成本仍单列。此阶段不声称实现逐字段的最小写集。首次接管与显式重新采用外部状态执行完整审计；已发布记录递归只读，后续仅冻结新写集和新历史记录。公开 `world.state` / 回合上下文用于检查，正式参与者不能直接写入。测试夹具在接管前布置；需要中途构造特殊世界时，显式复制并重新采用，承担完整审计成本。

参与者与预览取得 `current+economy` 默认投影和只在本次回调内有效的 `reader` 查询服务；完整事实、旧回执、阶段日志、历史关系及完整知识树不进入默认投影，仅附经济资格当前引用的事实。StateView 提供按 ID 的 entity/fact、有限当前实体查询和 history_query，拒绝未知范围并记录读取计数；回调结束关闭 reader，缓存旧 reader 不能跟随候选后来变化。没有逐参与者配置读取权限的注册表；未来业务沿同一查询边界接入。页长上界统一取 decision_query_page_limit。捕获协调器对象的回调还需检查当前投影和随机状态是否被越权修改；旧嵌套引用由已发布记录的只读性保护。这是受控规则插件的接口约束，不把同进程任意 GDScript 当成安全沙箱。

校验覆盖保持在权威归属方，不能只看参与者自报成功：

- 世界当前身份、人物状态/关系/成长来源、机构代表、域邻接与人口守恒，连同圣物持有和锚点派生状态一起验证。人物变化会沿教团、媒介、锚点和收入资格反向检查；本阶段采用保守当前集合闭包，避免漏掉依赖。
- 新事实检查 ID、回合、目标结构与父因果先后；既有事实只读且首次审计通过，因此普通事务不重新验证其全部正文。所有当前引用仍须查证存在，身份/事实序号不能复用。
- 经济校验合并后的资源、存续收入资格及其真实来源、教团域唯一性、锚点位置唯一性、供奉/收入凭据、流失余量和资格证明，保持原正式算法。
- 回合校验当前阶段、执行机会、计划锁定、事件和待办，检查新增阶段记录、完成工作与请求回执，连同世界时钟和经济时点一致后发布。已经审计且不可变的旧回执/日志不逐笔重验；读档仍检查完整链。
- ID、随机流、统计、世界写集和回合上下文属于同一候选事务。失败丢弃候选；成功只增加一次提交序号，重复请求不增加。提交序号存入 schema 1 快照；旧 schema 1 未带此字段时，从完整审计后的回执数量确定，带字段时必须与回执数一致，不通过删除历史兼容。外部对象的私有可变字段不属于存档/回滚状态，参与者持久数据必须通过正式声明提交。

**实际成本边界**：TASK-ARCHIVE-SAVE 已将 facts、receipts 等增长型容器改为不可变持久根，普通事务仅核对写集与共享根身份，保存仅编码新路径/变化对象；完整导出/读档审计仍随历史增长。知识、成长、消费和墓碑关系改用下节持久树与有效索引，普通候选不展开全历史。真实有效来源 K/待办 Q 增加时必要工作仍会增加。差分与原子性通过不能替代 `TASK-FIDELITY-VERIFY` 的最终混合负载验收，更不能证明长局帧耗时或玩家体验达标。

### 历史索引的投影与内存表示

TASK-HISTORY-INDEX 将历史检索和当前决策分开，沿用同一权威世界。`history_index.gd` 管不可变持久有序树与派生索引：人物/机构知情、来源消费、成长来源、证据来源与未解除公开异常映射等长集合在热状态中使用明确的历史引用；关系墓碑使用保序 sequence，支持关系投影保持原数组后项覆盖的父因果语义。单次插入/删除只复制受影响路径，不在每笔人物集合副本中重新展开完整列表。完整 canonical/snapshot 导出展开成原 schema 1 的事实 ID 列表、关系数组与键值记录，保留旧语义；普通规则通过索引 API 读取。表示变化不授权删除回忆或重抽来源，陌生根、初次接管和读档仍须完整审计后重建可信索引。来源集合显式要求唯一且有序；正常旧输出满足此条件，重复/乱序的外来 JSON 拒绝，不能转换时静默去重或重排。关系数组按原顺序保留。索引及查询游标是运行时派生缓存，schema 1 保存完整逻辑历史；读档重建新索引实例，旧游标明确失效。

分页上限唯一读取 `fidelity_parameters.csv` 的 `decision_query_page_limit`，查询策略独立校验并保留自身指纹；未启用的 hybrid 数值不会因此激活。游标绑定来源版本与查询范围，返回 `items / cursor / complete`；不同版本不能继续旧游标，`complete=false` 必须续查或使用能证明足够的聚合投影。默认参与者只取得有效当前对象；已死身份和完整知识树通过明确 ID/范围查询，不随默认面板或计划预览展开。旧回执和完成工作复用协调器已校验的按 ID 字典索引；普通提交只审计本笔新增尾部，不另造第二套回执或奖励资格。持有历史引用不授予写权限。`HistoryIndex.has / size` 用于按键和计数；`values` 是明确展开接口，完整输出与回顾才使用。内部 marker 的保留字段在请求/效果/JSON 输入边界拒绝，不把同进程任意 GDScript 当成安全沙箱；原生 JSON.stringify(raw state) 不是保存入口。

有效性与来源责任保持原规则：

- **人物行为**：人物/事实种类/目标索引记录真实知情。自我整顿取本人可知、指向本人的最新 strain/harm；查证、安抚、解释仍按既定行为/目标/来源排序选择最早合法未消费来源。理智、忠诚、冷却、机构和目标资格在当前共同快照重查，不能统一改成“取最新”。
- **消费与成长**：消费键按原行为规则区分人物/行为/来源/目标，永久可查；成长使用不同来源的 membership 和 count。真正增长时的事实仍列出该属性全部学习来源与本次结果，不改成只引用最近几次。
- **机构风险**：机构知情与代表个人知情分开；按机构/目标汇总实际暴露来源、最近回合和已确认对象。暴露调查及证据确认保留全部实际有效父因果；不同对象不合并强度。继任保持机构档案，不把档案赠给新代表个人。全详细差分阶段保留原先对同目标多证据的稳定覆盖顺序，不擅自合并成新规则。
- **失效与恢复**：人物状态/所在地、机构 active/代表、圣物位置/资格、教团及锚点状态、例外 invalid_records 的变化更新当前投影。迁出、暂时失能、媒介暂时失效可撤销资格，但原来源仍可在恢复后重新适用；公开异常按域/载体建立来源索引，未解除但载体失效的旧映射不进入普通全表扫描；暂失能只撤销当前资格，解除则原子撤销指定来源映射并保留原事实。明确解除的异常不能因载体恢复自动重开。
- **活动对象和待办**：按域/状态读取活人物和合法继任者；死亡人物与无当前引用的已消耗圣物墓碑从默认枚举退出，拘禁/失踪/休眠对象仍可按 ID 准确查到。圣物索引区分行为目标资格和公开异常载体资格，保持 sealed/seized 的原有差异；迁移、失主、扣押及后续正式圣物入口须刷新同一索引。期限按回合/阶段索引，已承诺事项完整结清；旧请求、完成工作和授权保持永久唯一键。
- **事务和可信边界**：索引根、当前世界、随机、阶段、来源消费及新增回执在同一事务版本提交，失败恢复原索引；参与者和预览使用只读查询，不能更新缓存后影响下一次决定。已有可信树共享不会逐轮重验全部历史，新节点/引用仍须校验；完整导出与读档审计成本单列。

仍有效来源数量 K 和未结事项 Q 可以增加。实际生成完整多父因果或分页回顾时允许与 K/输出量相应的成本；不把这种必要输出隐藏成 O(1)，也不通过丢弃旧合法来源缩短。历史容器根分段、写集身份检查及增量保存已由 TASK-ARCHIVE-SAVE 接入；此项不是最终混合负载验收。

### 有限热状态和完整冷历史

热态包含当前人物/机构/人口、宏观摘要、F/N/P 分配及引用计数、退役保护占用、本轮已用占用、当前工程/危机/固定候选、有效来源投影、按键可查的冷档案位置和随机游标。冷态保存已结束内容及完整事实骨架；已消费来源和旧请求的唯一性仍可通过索引查证，绝不因为“太旧”允许重复使用。旧回执按 request_id 与内容摘要找原结果，不把整个旧回执集合放进每笔事务副本。

无关旧历史 H 的增长不应增加普通命令全档案遍历/复制；但有效活来源、实体和待办增加可以增加必要工作量。整轮成本按 D（域）、F/N/P/L（详细规模）、有效风险/期限/候选、变更对象数和本次冷查询计量；冷存储总量与完整导出/审计依然随 H 增长。阶段四即使候选池满也必须结清现有危机，不用时间预算丢任务。最终性能阈值由真实负载任务确定，当前数字只定义可接纳的工作范围。

后台抽样使用版本化稳定种子派生（局种子、域 ID、流名、派生版本），独立于表现和检定流。保存每域 state/next_background_turn，失败事务恢复；换页面、升降级不重播，不用系统时钟或 Godot Dictionary 哈希决定相位。整数随机状态仍以十进制字符串持久化。全详细差分基线保留原随机流位置，不提前为尚未启用的后台流消耗随机。

### 当前实现到目标规则的迁移

**现有参考配置**：`world.gd` 仍为所有域创建 `initial_named_per_domain` 人并逐轮演化；未分 F/N/P，旧人物岗位/忠诚资格按现有规则运行。它是 TASK-INCREMENTAL-TX／HISTORY-INDEX／ARCHIVE-SAVE 的差分参照，不能据此宣布混合模式支持。公共人口、身份、事实、费用、阶段与存取档拒绝性质继续有效。旧套件重新运行绑定新文档时，报告必须明确只检查这个参考配置和已有共同性质。

**语义保持阶段**：前三个底层任务在相同引擎/数据/种子/命令下比较规范化状态、事实、支付、RNG、回执；旧全量审计保留在读档和显式审计路径。不得把减少断言或少生成事实作为提速。

**混合接入阶段**：ABSTRACT-SIM 改用当前宏观输入和低频日常；ATTENTION 接入活动预算、成员字段、固定候选与新准入。`initial_named_per_domain` 不再控制混合开局，`local_actor_limit` 约束本地按需生成。后台具名非成员停止逐轮自主行为，忠诚达标不自动成员，传教/破屏障/深回应准入改变；这些是刻意的新规则，分别有 ACC-ABSTRACT-*、ACC-ATTENTION-* 和各正式业务验收，不能要求与旧匿名人生等价，也不能标为原测试全覆盖。

新存档/内容版本必须显式识别模式与分层 schema。没有迁移器的旧快照明确拒绝；转换超过容量的旧存档不得随机删人、释放承诺或重抽开局。全详细参考路径仅供回归/审计，不是可用来绕过注意力的玩家难度选项。启用混合模式前，完整集成和负载由 TASK-FIDELITY-VERIFY 负责；既有下游依赖不变。

### 分段存档实施边界（TASK-ARCHIVE-SAVE）

增长型集合（事实、人物、证据、圣物、授权/失效键、请求、完成工作及阶段日志）使用不可变持久根；候选只含本笔写入覆盖层，验证当前依赖与写集后封存路径并发布，不复制或比对整份旧根。原 schema 1 完整 JSON 导出保留为诊断/兼容入口，普通保存使用独立 schema 2 档案格式。

档案将不可变树节点和记录按 archive_page_records 分段，以内容校验和引用对象；增量保存复用已落盘节点，只编码新路径/变化对象。每次持久提交保存当前世界、随机、统计、阶段、回执根及索引重建版本，链接上一次持久提交；最后原子发布的固定大小 manifest 决定恢复版本。未发布尾部忽略，已发布对象损坏拒绝，不回退掩盖成功提交。恢复先完整验证并重建派生索引，再一次接管当前会话。

实际故障注入和成本证据由本任务报告提供；物理断电、不同文件系统及发行平台持久性归 TASK-RELEASE，不能由 flush/rename 的存在推定已验证。历史磁盘空间与完整审计仍增长。

`ArchiveStore.entry/has/keys/values` 是增长型根的读取边界；`put/erase` 写入本笔覆盖层，发布时路径封存。有限文明/机构/教团/锚点继续为当前态字典。首次接管旧字典与陌生状态需全量校验；正常事务以可信根指针及写集验证，不重新检查全部键。节点身份和不可变值身份分别缓存，避免重编旧子树与冷记录。只读视图仍不暴露可写权威记录。

协调器提供 `save_archive(path)` / `load_archive(path)`。格式2检查点同时记录世界状态、RNG、统计、context、commit/index_sequence、引擎/内容与参与者版本；索引本体是派生数据，恢复时重建，不保存旧游标。节点与payload有不可变身份，哈希覆盖内容；恢复同时验证AVL有序/平衡、序列键从0连续、语义及版本。写入检查返回值、错误码、字节长度并回读新文件；成功后才发布清单。原schema1快照由原restore入口完整审计后使用，不自动将未知格式猜成旧版本。

这是单写者目录协议：保存前与发布前校验当前清单，已发现的过时实例拒绝；没有跨进程锁。历史提交与未发布尾部可能占磁盘，当前不自动清理或压缩。物理断电后的持久性、目标平台原子替换及真实版本迁移按TASK-RELEASE/ACC-RELEASE实际验证；本机故障注入不替代该项。具体实测见[分段档案报告](qa/archive-save.md)。

### 概略生产者接入（TASK-ABSTRACT-SIM）

`abstract_sim.gd` 装载并校验fidelity参数、职责矩阵与 `background_templates.csv`（候选合法条件和人口来源），持有独立策略指纹。世界的可选 `simulation` schema1保存受控分配、每域独立RNG/日常游标、固定候选、主体引用及序号。缺少该字段保留全详细参考模式；本项通过 `configure_assigned_simulation` 在未开局场景中指定重点域和必要详细主体，不提供玩家切换或绕过后续attention的入口。既有人物保持原ID和历史；匿名开局/本地按需展开及成员转换仍由TASK-ATTENTION实施。

共同阶段四先冻结预付后的同一版本，详细人物行为、所有域风险选择、详细或到期概略日常、唯一经济生产者和概略候选均从该版本决定。候选建议私有；提交前重查主体、来源、容量及人口，命中既成身份失效时取消固化。失败跟随同一事务回滚。当前背景模板覆盖当下求告/屏障接触及已有知情暴露回调；它们是候选协议的正式数据，不是完整祈求/事件内容池。

固化者在 `world.gd` 中负责提名扣人口、来源根事实、固定ID/危机ID/最早展示轮/期限/默认后果与共享主体引用；没有容量则不承诺。阶段二只读取既定候选；阶段五依固定期限执行零资源默认结果。候选消费者可读固定记录，不在此实现祈求回应或主要事件呈现。受控bootstrap使用同一固化接口，失败整体撤回；确定性后继接口沿原主体/来源并用一次性授权键，不抽新后台机会。实际准入模块接入和完整消费者分别由ATTENTION、PRAYERS、EVENTS负责，保持既有依赖。

已启用模式以world快照的simulation_policy与state.simulation.policy双向匹配，格式未知或字段缺失拒绝；分段检查点同时携带该标识。默认参考快照没有该字段，保持旧语义。事件责任参与者才可通过显式background_successor_authorized事实触发后继，固化及授权键共同回滚；当前只接下一轮展示，当轮重开特例交TASK-EVENTS。StateView.background_candidates返回本轮冻结名单的脱离副本，reader关闭后拒绝访问。候选固定池、期限、来源及共享主体引用均在当前态/恢复时校验，完整旧记录仍归冷档案。

### 注意力接入边界（TASK-ATTENTION）

`src/game/attention.gd` 是hybrid模式的唯一准入谓词与预留/转换归属，读取既有fidelity参数及intervention_policies。`state.attention` schema1保存本轮使用记号、未结预留/工程、撤关注申请、成员退役保护和有限本地L；`state.simulation` hybrid/schema2继续保存既有游标/候选/主体引用，assigned/schema1保留为回归配置。实际混合开局不先生成全部居民再删除；后台机构匿名在任，重点域按本地预算提名，原身份永不重抽。

玩家关注/撤关注、合法成员申请及预览通过turn的attention入口；正式参与者主动分支须声明CSV分类，结合实际效果树推导最大F/N/P/新身份并在费用/骰之前原子预留。未知分类拒绝；完整业务消费者后续复用此边界，当前合约夹具不等于权能/祈求已实现。持续工程持有预留直到显式结束；候选固化、P→N、退役N→P和同轮延迟释放沿同一预算计算。死亡与默认离团不可因容量不足卡住。

阶段一先结清既有身份/期限与候选失效，再处理上轮释放、退役转换和本地集合；阶段三按稳定教团ID先决定传教F，满额转守持，随后才锁定/预付。后台日常及风险职责不随界面变化；切换不重置游标、冷却、候选或RNG。人物明细仍留在同一世界；当前验证可对所有合法活身份K做保守依赖校验，最终工作量与历史长度的独立负载由TASK-FIDELITY-VERIFY验收。

`generate_hybrid(seed)` 是混合游戏建局入口；旧generate/assigned配置仅作回归，不能作为绕过注意力的玩家选项。hybrid携带simulation/schema2和attention/schema1及双策略标识；快照与分段检查点分别校验字段存在、版本、成员索引、活身份投影、预留身份键、本轮标记及引用。未知格式拒绝，不把旧72人场景静默转换成混合开局。

正式主动分支在meta.attention声明family/content_id/variant，参与者效果语法仍先校验；preview_needs按实际所有分支、未来载荷中的身份及显式调用图求并集，reserve先于扣费/检定。未知分类和错误依赖拒绝。新身份以new:键占活身份及P上界，名额不足不发布；领取键后写入追加式唯一授权索引，不能循环复用。参照输入是责任参与者已验证的业务效果图，准入不替代完整权能/祈求资格与数值验证。模块不在运行时执行CSV脚本。

turn的attention操作提供focus/release_focus/enroll/leave/release_project及纯preview_attention。成员变化是声明式membership效果，不授予额外忠诚；完整消费者仍需执行自己的来源与结果规则。跨轮结果用persistent预留，定时任务携带所属令牌，实际到期效果必须属于原预留；同批不可逆身份优先，失效任务整项取消。所有共享任务结清后再释放所属工程令牌。成员索引、活身份投影、本地集合和带轮次的使用记号在候选事务中更新，任何失败一起丢弃。

当前普通提交保持对合法活身份K的保守依赖闭包；Attention的元数据遍历受F/N/P及未结预留约束，不对累计历史H重新取全量NPC/事实。首次审计/恢复仍可遍历完整历史。生产者的详细自主行为取N/P/L去重集合，未因关系边递归展开。TASK-FIDELITY-VERIFY继续验证完整混合负载和故障组合；完整CULTS/POWERS/PRAYERS/EVENTS需从实际业务入口消费本接口，不能以合约夹具证明已完成。

纯准入预览返回budgets，按同一集合算法列出现占、预留、上限及待释放身份，不让UI再推导一套容量。persistent工程的claim_key由已登记职责/分支和主要对象规范化生成；同键未结工程拒绝重复发布，实际消费者继续持原令牌。不同职责的独立引用不互相覆盖。持久化校验同时拒绝重复工程键及重复未知身份键；最终Q规模与实际内容入口的去重覆盖继续在FIDELITY-VERIFY及对应业务任务测量。


### 正式教团接入（TASK-CULTS）

`src/game/cults.gd` 是受管理的无私有持久状态规则参与者，`install(turn)` 在开局注册 actions/start/cult_start/cult_end；Cults安装后接管正式生命周期，未安装会话继续兼容既有参考路径。回合保存同时校验参与者能力版本与世界 `cult_system/schema1`，不能跨缺失参与者静默读入。Catalog在同一读取器中装载powers扩展并独立取指纹；Cults版本绑定该扩展，原参考会话的base内容版本保持兼容，不能通过修改旧档或放弃版本核验续跑。

`cult_system` 只存本域实付 `{amount,source}` 和逐团休眠投影；每笔已支付的 `turn_action`、经济传教/供奉事实在同一事务增量更新，完整因果保留在共享档案，不每轮扫全部H。动作目标由明确 `meta.target` 或已注册准入的 target声明，不能由事后猜测对象归属。零费用不计，拒绝/回滚不发布，收入和资源转入不计实际支付。

成员身份仍由统一membership效果与Attention处理；Cults仅核实正式任职与cult归属，不复制容量算法。主动任命返回POWER_APPOINT准入和固定下一轮start工作，持原人物/成立版本/绑定来源及persistent令牌。轮初身份优先处理，失效任命取消且不换人；有效任命随后才更新岗位。自动继任在注意力轮初回收后按可准入候选排序，不抢F、不替匿名机构生成具名者。阶段五期限完成后、阶段六终局前调用cult_end，计一次连续休眠、覆灭及自然成立；零人口/凝聚的失效在收入前即时重查。

已有锚点护持任命只更换合法持续主体，不提供结构重建/修复，不免费恢复供奉贡献。正式Powers/Relics与Prayers现已接入；事件池、八蓝本完整制度证明及表现分别仍由原下游任务接续；新增消费者应调用同一身份/支付/结算入口。


### 正式权能与圣物接入（TASK-POWERS）

`src/game/powers.gd`与`relics.gd`为无私有存档的受管理参与者，开局安装于已装Cults的同一Turn。共享actions仅开放给受管理规则模块，普通插件不得占用他人的槽；任命直接复用Cults，未来工作仍由原模块持有。显现使用powers_start/powers_end，封存到期使用relic_start。所有动作先验证同一资格/费用/Attention最大分支需求，再于候选事务支付并执行；失败不发布资源、随机、事实、索引或未来令牌。预览返回脱离的计划，不能从产品输入指定骰、任意加成或执行脚本。

Catalog独立装载powers/relics/power_effects/relic_effects扩展，版本绑定于实际能力；旧十张基础表的内容摘要不变。机器效果表仅规范原powers/relics文本结果，运行时使用有限操作语法及正式参数，不解析自然语言。`power_system/schema1`持有有源冷却、未消费准备、临时拘禁及至多三轮仪式步骤；`relic_system/schema1`绑定能力与受信发行方。两个模块未知版本/能力不匹配的存档明确拒绝。正常事务校验当前有限头与写集，首次接管和恢复完整核验付款、骰、授权消费及步骤因果；不让普通动作随累计H重复审计。

`power_qualification`引用实际当前对象、机构、联系/证据/入团事实及发行版本。来源生产仍由PRAYERS/EVENTS/ANCHORS负责；当前验收的上游来源是显式合同夹具，不能直接提供权能结果。圣物创建授权生成唯一RELIC/source，非创建授权固定当前status_source，失效旧授权不能跨后来归属改变继续用。所有归属转换沿Relics和World共享写入/活动索引；历史原始来源及消费键永久保留。携带/绑定/扣押/封存/消耗互斥，受控存放不因教团覆灭自动删除，实际再次使用仍重查控制资格。

锚定真实建立或修复原机构固定序号的休眠结构并绑定媒介，供奉独立由Economy维护；完整八蓝本制度条件及整体验收由TASK-ANCHORS补齐。显现固定宇宙护持者、宇宙与星系锚点和原持久容量令牌，连续三轮实付；第三轮动作锁概率，轮末重查资格后唯一正式检定。成功形成有源完成事实并令苏醒100，后续普通权能等待终局消费；断联/终局优先级/封存仍由TASK-ENDINGS完成。公开仪式载体只在持续期间生效，解除保留事实和其他独立异常。


### 事故来源：冻结WIP（TASK-SOURCE-LOCAL-TIES）

`src/game/prayer_sources.gd`及Incident接线未通过完整验收，现按DEC-026冻结，等待TASK-SOURCE-LOCAL-TIES父任务替换。原activity/harm/notice链、细粒度交付证明和对应子任务不再是后续实施要求；保留代码及失败记录不表示该能力已完成，也不表示新轻量方向已经接入。重要人物后果、原due、一次性结算、回滚及保存一致性仍归替换实现负责。

### 正式祈求与原危机（TASK-PRAYERS）

本节描述原schema1消费与四模板接线；两类求告、身份知晓及新原根生产仍待上文TASK-PRAYER-DESIGN目标接口实施，不由旧消费专项通过推定完成。

`src/game/prayers.gd`为受管理的规则参与者，安装于同一Turn，独立prayer_freeze/prayer_deadlines边界及共享actions，不占主要事件events槽。`prayer_rules.gd`只提供受限传播/任命及已声明祈求准备的当前资格查询，实际规则与来源归Prayers。冻结展示来自统一simulation.candidates，不建第二个后台池；普通typed prayer_situation经World.fix_prayer_source验证真实主体/处境/前因及版本发行方后，按原容量协议固定ID、展示轮、期限、原危机和holds。开局仍从真实hybrid bootstrap进入，已有BG候选转换不再次提名或扣人口。

`prayer_system/schema1`只保留未结请求、原危机、当轮offered和仍有效的有限限制/隐匿标记；闭合事实与唯一消费键归共享追加档案。请求窗口与原处境期限分开，失败消费请求与当轮回应但不解决危机；重开不得改原due。请求主体死亡、迁移、来源/物件版本或处境失格按固定对象取消，不临时换人；仅深分支对象失效不取消仍合法的原浅分支。必要危机引用继续持有原人物，默认结果不新增F/N/P；Prayers接管的候选不再被旧World默认处理器重复结算。普通条目按自身到期效果，旧BG来源保留其已承诺的未回应默认，失败后不叠加第二笔未回应罚。

`data/prayer_effects.csv`规范原prayers/prayer_facts的有限语法、数量与始终/成功/到期条件。费用、公共污染、深成倍率和灾变沿原run_parameters；数字量可缩放，人物/物件/关系/证据不复制。预览与执行同资格/概率，所需固定人物、代理和所有结果可能入团者在费用/骰之前由Attention统一预留。隐匿保留人物实际生命/行动状态，只过滤新普通追查，不撤既定抵抗；期满不免费复职。回应不占六类执行任务机会，登记meta.responds，经Turn保障每轮一次及非法/回滚不消费；身份、人口、状态、证据和机构知情继续由共享World及索引写入。

神谕可声明固定请求/分支键，准备仍属原Powers ledger及有效期；Prayers仅消费匹配原请求/人/分支的一次性来源，不接受任意数值。圣物没有表中适用规则时不添加加成。保存能力与内容版本核对独立扩展指纹，恢复完整审计请求、危机原due、来源、冻结展示、消费、费用/骰、限制与主体引用；常规事务只校验当前有限头和写集，不逐笔重扫全部历史H。

完整事件池/回调调度、八蓝本制度证明、终局优先级/封存以及游戏UI与体验继续由原下游任务处理。Prayers产生的有源回调/争夺机会只提供明确对象与时窗，不能以marker宣称EVENTS已完成。运行范围与当前sourceHashes见本任务验收报告。


### 正式机构锚点资格（TASK-ANCHORS）

**以下是schema1旧运行时的实际接线，待TASK-ANCHOR-ROUTES／ANCHOR-LIFECYCLE替换，不是新设计要求。** schema2目标见上文“密教schema2的目标接口与实施边界”及文明规则第9节；其中通用事件证明、机构接收知识、代表在任、否认/恢复链不能沿用为新普遍门槛。

`src/game/anchors.gd`安装在已接Economy/Cults/Powers/Relics的同一Turn，`anchor_system`独立绑定机器条件及接受的具体事件发行方。`data/anchor_conditions.csv`按原civilization_conditions规范八蓝本有限语法，数量只引用原参数。Powers正式锚定预览/执行直接调用同一`Anchors.qualify`，成功后以`bind`登记机构proof及实际锚定来源；不另做一次随机检定，不用legacy allowed=true替代制度事实。Economy供奉和World进度失效重查同一`maintenance`与物理条件。未安装的旧合约基线保留其原限定范围；安装后缺正式proof的旧锚只可休眠，不猜测已有制度承认，重建沿原ID/序号/origin。

`institution_event_result`引用具体事件/选项、原人物/机构/真实已成功Prayers或Powers事实及其当前资格。`share_record`是受管理上游的精确递交边界：实际持有人须当前确知指定记录并可达接收机构，只向该机构递交这一ID，记录真实传递来源并幂等；不是从因果父项推断全域知识或玩家免费编辑入口。机构限制、记忆资格与契约/例外原对象逐源校验，成功解决原危机不等于撤销已经形成的见证。

首次合格具体结果在已接收知识后`observe`，固定同机构一次的`institution_relic_opportunity`及原表池类型/有限期限；只处理这一来源，不每轮扫描全部历史寻找认可。常规当前机构proof/绑定/机会头有界；历史事件结果可在冷索引中保留，直接ID或显式分页读取，完整恢复才全量审计。机会的回收/公开/等待实际消费者及完整事件池继续由TASK-EVENTS接入，不在本项伪造免费物件或收入。

新建/修复仍由原Powers产生休眠结构，原Relics保持唯一绑定，原Economy供奉后最终重查才贡献；旧有效锚只修改拒付计划不提前撤回。来源/代表/人物/媒体变化沿同一当前投影即时停贡献，临时状态恢复不免供奉或免费重建。本轮低语只由原轮初位置锁定，阶段四真实新增贡献可供后续收入容量使用。正式能力与内容版本、原proof/消费/机会、实际支付及固定身份在接管/完整恢复审核；普通事务检查当前有限头与新增写集。

机构承认的迟到知识采用定向重检：上游在`share_record`携带精确`result`时，只接受接收机构已知的同机构事件结果，所递交记录必须确属该结果的basis和直接parents；递交后同一事务重检该结果，已有记录的幂等分支也允许重检。不携带result的普通分享只传知识。不得扫描历史结果或从父项传播知识。当前制度否认来源仅由`anchor_restrictions.csv`映射原EVENT_03/B、EVENT_04/B；现有六种抵抗不凭名字获得新的封锁/否认效果，未来实际效果由原TASK-EVENTS/TASK-RESISTANCE扩充同源映射。


### 正式事件与原期限交接（TASK-EVENTS）

`src/game/events.gd`在同一Turn开局安装并声明真实发行方能力；Prayers/Anchors/Relics/Economy接受版本在首笔receipt之前显式配置。`event_rules.gd`纯查询来源与当前资格，`event_operations.csv`翻译原12事件24选项，`event_sources.csv`限定实际Prayers回调、成功梦境、窗口到期和World原调查/修正计划。自由true处境与自由event_result不构成生产来源。handler只返回受管理events效果；事务commit独占选择、资源、身份、事实和events RNG。

共享simulation.candidates固定原ID、主体/原因、visible/due及holds，事件不另建后台池；聚合证据后才固化，选项保留原对象并即时重查。新增事实进入有限pending头；持久证据按机构/人物/类别和不同轮次的冷索引查当前头，回调窗口不等于证据有效期。常规工作仍含活身份K与当前规则的保守成本，冷历史H不每轮展开；完整恢复和冷档案本身仍随H增长。

事件池按原due、优先级和互斥选最多两张；同档竞争才消费独立events流，无真实候选允许零张。选项按原表确定性执行，不另加骰、不消费唯一祈求回应或六类任务机会。普通后继最早下轮；原已预告relic TRACE与REWRITE在原due交给08/11，同目标计划不先由World重复执行。主要位或固化容量不足时仍按原due执行已公布B摘要，不暂停原风险；SEIZE及其他抵抗仍归World/后续RESISTANCE。

**schema1旧运行时：** 具体02/04/05/06/11成功结果在原记录、人物、通信与机构知情满足旧条件时生产机构证明；精确递交走share_record。04B限制本次证明，04A写恢复截止，首次承认产生唯一遗物机会。**schema2替换目标：** 事件不颁发anchor_basis；04A机器退役，04B保留真实世界后果，09A只递交新增实际材料端点；05/06内部不能暗中调用旧认可生产。公开包装仍指回原根，不充当第二个独立证词。首次实际依据机会继续沿原RELIC_RECOVER/RELIC_PUBLIC处置，保留类型、原due和唯一消费，库藏/携带人按当前真实控制与容量检查。

请求窗口到期即产生一次真实未回应事实，原独立crisis不被延长或重复处罚。12B从这个expiry及实际event_result授权原处境当轮一次重开，原主体/事实/危机due不重抽；展示满三时只保留当前可见候选，不挤旧或造第四张。PRAYER10揭示关系不自动消除原派系争端，09不得为了出现而延迟危机。

安装正式Events后，到期check先从同一批前世界锁定实际概率/结果，再让实际选中death先执行；可能但未选death没有优先权。某job普通身份目标被本批杀死时，保留真实检查与死亡，取消该job全部非death效果（包括检查树外费用/奖励），取消引用原job/check/death。故障整体回滚RNG/资源/身份/完成键；旧未安装能力的限定调度合同保持兼容，不能用旧拒绝冒充正式验收。

世界、回合与完整/分页存档分别审计能力版本、固定来源、语义结果、知情、消费键和当前投影；重算checksum不能掩盖伪造授权。正式抵抗整合由下节TASK-RESISTANCE承接，终局、叙事扩量、UI/平衡/视听/发行继续原任务，本模块不包含游戏内界面。

### 正式抵抗整合（TASK-RESISTANCE）

`src/game/resistance.gd`在正式Events已安装的同一Turn开局绑定独立能力版本，提供原计划的只读预告与固定身份/期限/效果审计。六类计划仍由World从共同快照选择并唯一写入；原CSV规定资格、优先、预告、冷却与效果，抵抗模块不复制第二套伤害或世界。原TRACE圣物与REWRITE仍按原due交由EVENT_08/11结算一次；其他计划沿原世界入口。

正式计划固定证据主体、执行机构、目标、原依据及原表默认效果。清洗须关联真实当前成员所属教团，到期复查原依据与原对象；降察觉不会撤既定计划，失效也不替换对象。取消/结算保留历史并开始原完整冷却。只读预告不推进回合、不消耗随机或支付；玩家可以沿原回合接受既定后果。持久能力、开始事实、当前计划与原表必须一致，完整恢复拒绝语义伪造；普通检查只审当前计划和有效来源，不全扫描冷历史。

HistoryIndex按新增确认及来源撤销写集维护有效确认与反向依赖，候选取当前确认头，固定计划只核原parents；旧确认保留冷历史，重新调查可以产生有效新确认。破口按原开启/闭合阈值保存每域迟滞状态，屏障写入产生有源跨阈值事实及当前头；灰区恢复核对真实最后转换，不能只翻一个布尔值绕过资格。

跨域整合复用已有Powers迁引与真实通路、目标域资格/屏障/察觉、Attention准入；知识仍只能经已授权的明确来源入口流动，不因邻接或持有因果parents自动获知。规则没有通用自动跨域污染扩散，本任务不增设这一效果。后台风险保持每轮准确推进，观察/折叠不改变模拟模式或期限。运行范围与初始夹具边界由tools/resistance专项及关联回归报告说明，终局与玩家理解继续下游验收。

### 正式终局、断联与封存（TASK-ENDINGS）

Endings在首笔回执前安装，要求正式Powers／Prayers／Events／Resistance，并独占ending槽。阶段五既定后果和阶段六教团结算完成后，重算锚点与苏醒、记录本轮有源断联评估，优先判零苏醒或断联期限；仅存续世界才调用Powers唯一的末轮仪式结算。Powers仍负责固定三轮、费用、双域F／成员、锁概率及表内四档后果，Endings随后复算并封存结果。未安装Endings的历史套件保持原powers_end合同，不把该合同计为正式终局验收。

断联查询复用当前教团、固定祈求、有效未消费聆听资格和媒介机会；准备与准入沿原生产方法。当前代码的机会读取仍绑定旧承认证明，TASK-ANCHOR-LIFECYCLE须连同Relics/Events消费及恢复改读schema2实际依据，不能在终局查询留下隐式许可。下一行动机会在只读副本投影确定的低语／回应重置、轮初注意力释放和有源到期释放，不能猜测未来收入、随机提案或新资格。索引维护当前聆听来源及失效／消费依赖；普通判断不遍历冷历史，完整恢复仍可审计原事实链。来源、对象、原visible／due与当前准入必须一起成立。

断联计数、评估头和终局头进入versioned ending_system，原事实保存前一评估、当前接触及结局原因。World／Turn完整或增量审计按归属检查，恢复拒绝不匹配的版本、计数、来源或封存；常规终局读当前头，旧历史不重新作为资格。自弃为任意未结束阶段的原子会话操作，终止仪式后立即封存，不结算未来阶段。结束后新输入和世界写入拒绝，原请求仍可幂等读回；分页回顾保留种子、身份与因果，重开由新会话承载。专项与运行边界见tools/endings，游戏内终局呈现和真人理解继续TASK-UI。

### 正式玩家入口与会话边界（TASK-UI）

TASK-PRAYER-INTEGRATION的最小知情接口将完整域/人物账本与请求线索分开：`known_domains()/known_people()`仍表示完整已知对象，`focus_domains()`只为显式关注选择合并实际已可见请求的指定域线索。进入这个选择器不取得F，也不揭示蓝本、层级、机构网络或其他人物；关注仍走原Turn准入，选择深应时原准入也可在空位足够时同时取得F，容量不足才拒绝。Session投影只给线索对象中性标题及必要身份，既有完整信息保持原粒度。角色仅按本次类型真正作用的subjects授有限线索，不按actors/facts展开；原PR11扣押者与PR10待揭示关系不能在回应前兑现为已知。

实际绑定成员可公开其自身身份/成员属性，但不因此公开所在整域；显式合法关注产生的world_origin仍可成为原完整域发现入口。请求结果、关闭及EVENT12嵌套请求保持同一信息粒度。Endings内部未来contact预测不公开，ending_assessed只投影实际断联计数/苏醒及已知前因，不提前暴露未visible卡。公开card/descriptor按允许字段构造，call/knowledge/record_knowledge/admission_token、采样/发生键/身份与授权内部事实不进入project、选项、预览、结果或历史；原准入及因果记录仍完整保存在权威世界。内部`prayer_entry/event_entry`供可信呈现适配查询，不是向控件直接交付raw对象的公开数据接口。

Session保存外壳采用schema2以区分旧扩权账本语义；保存完整知情列表和实际见过的事实，重建先恢复实际可见请求的有限身份，再重学结果，不因事实遍历顺序升级整域。当前局部投影/恢复检验与完整continue_game分开：后者仍需全部正式模块安装、世界/Turn/知识校验成功才替换原局；CULT-SPREAD解除当前新局安装阻塞，不代替完整continue_game验收。整链存档与旧档边界仍由CULT-SAVE-COMPAT验收，不用本段实现登记代替实际运行证据。

project.godot 以 `src/presentation/game_root.tscn` 为入口；固定 1280×720、等比缩放留边。屏幕控件仅挂 `GameRoot/Presentation/CanvasLayer/OverlayRoot`。共享 basic_theme 只承载 DEC-011 的可替换最简功能表达，不宣称最终美术已获认可。

Session 安装全部正式规则，从真实混合新局进入首笔回执。ActionCatalog 构造有限已知对象字段，所有支付、资格、概率和持续结果交原模块预览与 Turn.submit。画面读取 Session.project 的脱离副本与已知事实分页，不直接读取 World.state。已知账本不遍历因果父链，未知指标和未知前因保留未知；当前来源头与类型索引避免逐权能遍历冷历史。确认前仅纯读，取消不提交；幂等输入身份保存后仍对照正式回执。

会话外壳将 Turn 完整版本化快照、玩家已知账本与输入凭据一起校验，临时构建并通过全部规则恢复后才替换当前局；同目录临时文件和备份轮换保存，轮间与封存自动保存。每局独立文件，测试可注入隔离目录。终局封存只读，重开不覆盖原局。

正式新局期限由 Prayers／Events 的真实专用处理共同覆盖，不再依赖测试 deadlines 空回调。敛息沿 Economy 原成本减伤并由 Turn 锁定结束行动。PlayerSources 在首回执前安装，按 player_source_rules.csv 的真实新增／当前事实生产有限资格头；消费时重验原事实和当前条件，版本与依赖进入完整／增量审计。背景 BG_RITUAL 仅使用已有仪式职能机构和真实 ritual_keeper，固定当轮 PRAYER05 情境，沿原候选采样、人口预算与祈求转换，不免费增加信众。

### 背景来源与既有关系的边界（DEC-026）

已实现的有限关系图按下文实际接线范围保留。TASK-SOURCE-LOCAL-TIES、TASK-SOURCE-MEMORY、TASK-SOURCE-LOCAL-CONFLICT、TASK-SOURCE-CONTRACT、TASK-SOURCE-EXCEPTION五父任务已限定接入共享轻量情境生成及必要的原祈求、事件消费者；少量受控运行验证正式生成、实际后果、期限和组件保存，不代表完整Session、自然新局或新进展路线已通过。旧共同读取、逐人登记、通知送达及社会协商过程不作为实施前提。必要人物、独立材料、请求主体和重要后果仍须明确；SOURCE-CLOSURE继续核闭合范围，完整会话续存归TASK-CULT-SAVE-COMPAT，旧证据保持历史。

### 关键机会合同：设计交接与当前差距（2026-10-29）

TASK-OPPORTUNITY-CONTRACT-DESIGN只定义共享协议和十目标设计清单；必要路由/玩家入口合由TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration收口，不再按三个独立操作/UI组强制扩建。新表尚未装载，没有运行时保障。原Catalog有限根语法及CULT启动阻塞已分别由来源实施和CULT-SPREAD接入；本节未来操作仍不因这些接线获得运行能力，不能省略内容或能力校验。

现有Events/Dispatch的每域四轮B仍有环境概率和root竞争，A每轮有限提案；固定池8、冻结展示3和回应1也会挡住后续。SCHEDULER必须接完整源→A/fix→offer→actions链，不能仅改出现权重。原Dispatch审计会复演旧抽样，新政策须联合更新tick事实/schema/version及随机语义。新目标清单design_only不是实际处理者；缺生产者/有界交付合同是安装或接入失败，不能当作无前提静默。

实际服务回执在Turn进入actions的受管理边界核验；该阶段经Turn授权的实际行动提交也可按事件§14.8在同事务证明服务。核验使用真实当前Prayers.prepare、Attention和支付/回应预算，以及与Session一致的最小可见投影；Session/project/preview不能写等待或清债。B选中、call、fix、冻结及阶段四预测均不能代替这个事实。目标/队列/等待状态由同一协议唯一写入；具体schema、阶段和界限以事件§14.8为准，不在架构再造一份规则。

最终纳入实施的必要路线须提供真实可用的请求/回应管线或当前可行动玩法，不能仅凭CSV的正整数L称已交付；旧表全部路线不再构成逐项实施清单。原due、固定身份/call、既有容量及已承诺候选保持。源闭合与自然验收分别记录B时间与实际服务时间。完整Session续存由CULT-SAVE-COMPAT核当前状态/回执/版本，债务不自动续三轮断联；不改变Endings真实接触计划谓词。

### 路线玩法整合目标（TASK-PROGRESSION-OPERATIONS）

**本节旧Core/业务/UI分批目标由DEC-026替换。** TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration统一收口必要玩家玩法、共享结算及Session/ActionCatalog/Turn接线；不预定独立操作数量、每项新按钮或后台活动。Source背景由五父任务的轻量生成提供；涉及玩家实际行动、费用、重要人物、独立材料、期限和一次性结果时仍沿现有受管理写者结算，不复制World/Knowledge/Attention/Cults等基础系统。

既有路线/操作表及字段模型仍为design_only，不是运行能力或逐项实施承诺。界面需要变更时沿原in-game-ux及art流程，由同一父任务组织；按钮存在、内部查询或表中的direct_action/0均不证明当前可执行。当前版本完整续存由TASK-CULT-SAVE-COMPAT验收，来源闭合与自然发生率证据分别记录。

Eight Civilization Anchor Route Implementation接CIV05/CIV07判别basis/当前carrier，Relic, Anchor Maintenance, Resistance, and Ending Integration接材料失效、绑定分支/正式改绑与首次遗物/原期限。额外停供锚的恢复须原经济预付、finalize当前资格及实际贡献重算；set_plan或paid_pending_final_check不是恢复事实，也没有现成anchor_reactivated事实。REST仍占整轮；两类真实促成结果之后最早下一actions按当前条件走原降临。完整仪式/两锚/A/成本/三轮/终局优先规则不变。

### 基础接触、记录与仪式路线：设计候选（DEC-026）

原八路线/七活动及参数保留为design_only候选，实施与必要界面统一归TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration，不再预设独立Core或三业务/两UI任务。背景过程可由轻量情境直接确定；真正玩家行动仍核当下人物资格、身份知晓、资源/容量和执行机会，不从未来收入造准入。现有关系图、人口与成员等写者保持。

Endings仍以当前合法可执行的联系判断断联，三轮断联、原固定卡期限及DREAM冷却保持；不能因旧成员或历史事实就永久视为可联系。完整会话保存归TASK-CULT-SAVE-COMPAT。

### 记忆与契约路线：设计候选（DEC-026）

旧六路线/六活动及参数仍为design_only，不再要求共同读取、逐人审查、签署或递送过程逐步运行。TASK-SOURCE-MEMORY与TASK-SOURCE-CONTRACT负责共享轻量情境及必要背景状态；必要玩家玩法、材料消费和界面统一归TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration。保留独立材料区别、重要人物后果、原due和一次性结果，不以表中标签冒充已实施能力。

契约继任按事件§14.13由TASK-SOURCE-CONTRACT限定接入：死亡且需要接续时从已有合格关系人固定当前选择，实际EVENT05B才接续原依赖并交给继任者指定契约和依赖材料；无合格者仍可解除或结束。选定、组件保存及实际结果已短验，不补人物或过去关系、不改原due或重复结算，不要求死亡前文书。旧六路及互惠两腿操作仍属下游设计候选，完整Session与自然发生尚未验收。

### TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees: aggregate target contract (2026-10-29)

原十目标/二十路线/十八操作等数据保留为design_only候选，数量与旧schema模型不构成实现承诺。TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration按DEC-026选择并接通必要玩法；五Source父任务提供共享轻量背景，Scheduler承担必要机会保障，不默认逐项搭建后台活动。

玩家资源、重要人物、材料独立性、原due、一次性消费和三轮断联保持；完整保存、必要源闭合与自然验证按各自父任务验收，不扩大为全仓库联合重签审计。当前安装阻塞与原issue不由设计声明关闭。

### TASK-SOCIAL-GRAPH-INITIALIZATION — Social Graph Generation and Initialization Integration: installed initialization scope (2026-10-29)

Catalog装载social_graph_parameters/social_relation_types并校验有限grammar及独立版本；npc_profiles仍进原全局内容摘要并另有图出生版本。World的正式world_start和真正first_focus共用SocialGraph.plan；原人口/F/N/P/K及提名保持。generation输入记录expanded_at_creation，已初始展开的域refocus不补初态关系，旧bootstrap不进入后来新cohort。social_graph.cohorts及精确edge_heads属于World唯一受管理状态，npc.relations保历史；新图只通知关系两端，不传播记录/神祇识别/玩家情报。此前“没有社会网络”的文段描述TASK-CLAIM-ACCURACY时点；当前新增的是此有限具名初态图，仍无全人口传播/渠道覆盖模拟。

本子批将最低方向/当前查询/幂等、原三关系后果必要兼容及当前格式局部保存/拒旧一并接线；精确终止/新episode、全量旧消费者语义、规模局部性能和强历史坏档归TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit。旧固定环不能默默补图迁移。原ArchiveStore格式不据此换代，完整Session保存仍归TASK-CULT-SAVE-COMPAT；原CULT兼容安装拒绝保留。128控制统计不证明自然祈求、路线或完整新局。

### TASK-SOCIAL-GRAPH-RELATIONS — Social Graph Relation Lifecycle Integration: relation lifecycle implementation contract (2026-10-29)

本批沿文明§4.1和事件PR03交接接入精确关系撤销与一次业务proof；验收结果见本批新报告，不能由接口登记推断已通过。World快照schema由2升3，明确拒绝旧World2，不补造过去proof或撤销回执。Graph schema/model仍1，原初态算法、两CSV及全部原数值不变，ArchiveStore外壳不据此改变。已有applied_authorizations中的social/relation/proof/<实际proof ID>绑定原episode；新合法proof即使命中当前head也需绑定，旧proof不能在退休后生产新episode。

World唯一受管理retire_relation(head,receipt,owner)只接受原PR03/deep真实成功追查关系回执；实时核已存在attempt/check，提交/恢复补核最终result.produced包含receipt及同一因果链，无未来父事实。重复撤销仅返回原历史效果，不碰后来新head。World/StateView/HistoryIndex.relation_source(source)仅回当前精确head的脱离副本，退休返回空；历史仍由relation(owner,target,source)读取。状态与位置改变只重判当前接触资格，不重抽关系或传播知识。

本批保存检查只承接proof/精确退休必要一致性；出生profile/机构/初次展开来源、全历史投影双向等值与联合篡改审计归TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit。两个父任务原ACC保持，不能在本批提前关闭。CULT/完整Session和原Source/Save/Natural责任不变。

### TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit: implementation boundary (2026-10-29)

本批实现World4、Turn3与Graph持久schema2，旧版本明确拒绝；initial_relationship/relationship/generation事实schema1、图model1、原CSV和选边数值保持。新增`src/simulation/world_initialization.gd`是正式生成与完整恢复共用的纯初始化配方：文明候选沿原CSV插入序，人物原型沿原ID序，保留singleton抽样、代表/额外人物的顺序与原generation RNG调用次数。world_origin记录这次实际配方槽位；恢复从保存的generation seed重算，核每域蓝本、实际出生ID/profile/机构、初始展开标志和机构源结构，再核generation的输入与图结果；不是拿两份自报出生快照互证。普通提交不执行全局配方重放。

nomination.birth记录真实writer当次选择及位置，区分standalone、bootstrap和turn。原World.submit的独立提名仍合法，但不能发行first_focus或冒充Turn提交。正式bootstrap沿原首个初始展开域、BG_CONTACT作者化profile/岗位、非信众人口提名、contact_selected→devotion_contact→call→situation→fixed→prayer_bootstrap闭合，且位于首次普通receipt之前；不会因有一个同actor最终标记便承认出生。真正first_focus仅接原取得F路径本次新增人物，原bootstrap及后来的refocus不补初态边。

Attention真实reserve在新增F时先发行`attention_admitted`，记录原source、规范化焦点集合、提交位置及当次manual/action/strategy调用；仍按原needs.focus顺序实际展开，不因记录排序改变人物ID顺序。World新增`expand_admitted_domain`只以瞬时准入源包住原单参数虚入口`expand_focused_domain`，返回后清理；失败仍由原hard_failure锁住整个事务并回滚。focus_acquired直接引用该实际准入源。动作在后续真实turn_action绑定准入，经营锁定在预留之后记录实际采用的策略（含当时默认值）；不使用未来事实作父，不把这些记录变成可免费重用的许可。

World独立恢复只有状态与RNG头，核确定性初生配方、图/投影等值及首次展开的局部源链，不声称核过Turn提交范围。Turn3额外按真实context.receipts的request/sequence、入口阶段/轮数和事实半开区间核出生及准入：manual必须是该域attention.focus；动作必须匹配原participant/slot/input、原Attention策略域集合和实际支付，祈求/权能/事件另核其真实attempt/result；经营必须是end_actions或rest下实际expand预留和随后完成的锁定。set_plan、release_focus或相同位置字段的伪来源不能替代真正取得F。World组件保存与完整Turn保存的证据分别报告，仍不代表完整Session可启动。

完整恢复由实际关系事实重建期望heads与每端历史投影，拒缺行、重复、反向、多余行及出生/cohort联合篡改。普通增量只读新增事实、改变的NPC关系尾项与有关冷源：旧事实和cohort不可改，新事实应有的每端投影与真实写集严格等值，不拿派生索引中的exists冒充持久投影；不逐回合扫历史。HistoryIndex/StateView沿现有精确源、当前head及分页访问；死亡、迁移、离团不删除历史或重新抽边。原关系proof/退休来源检查保留。本批机器行为证据由新专项另列；父TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit及TASK-SOCIAL-GRAPH — Finite Named Social Graph Implementation须分别完成原ACC组合验收。本段当时的CULT安装阻塞现由CULT-SPREAD解除；Source、完整保存集成和自然新局的其余边界仍按各自任务与实际报告限定。
