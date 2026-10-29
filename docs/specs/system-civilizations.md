---
status: PROPOSED
created-by: director
last-modified-date: 2026-10-29
last-modified-by: design
interface-changed: true
interfaces-with: [system-turn-economy, system-powers-cults, system-progression, system-events]
exposes: [真实出生配方与严格关系历史恢复, 精确关系撤销与业务来源一次消费, CIV03与CIV06与CIV08记忆契约可替代依托, CIV01与CIV02与CIV04可替代实际依托分支, CIV05与CIV07可替代实际依托分支, 有限具名关系网目标合同, 八蓝本实际神迹依托判定, schema2锚点依据与秘密承载者, 聚合招募资格与强化传播条件, 首次实际依托遗物机会, 文明档案, 机构与通路, 屏障破口, 污染与锚点状态, 察觉与抵抗计划, 情报可见范围, 机构证据与确认, 同快照文明演化, 文明详细/概略模式, 后台日常游标与持续风险摘要, 两类求告与有源身份知晓, 有限原根生产及单一候选职责]
---

TL;DR：文明由有约束的规则组合生成，机构承担传播、扎根与抵抗，持久人物承载因果。生成改变玩家需要完成的条件与行动顺序；重点域详细推演、后台域概略演化，共享准确的身份、风险和结算。

**DEC-026模拟粒度修订（目标待接入）**：保文明材料、人数/次数、通信与依赖差异；普通背景/观察/共同见闻由情境抽签概括。§9.6–9.8的旧逐环节事实/schema不再作为必须实现的过程清单，按事件§14.5及进度§12收口。当前正式数据/消费者尚未完成轻量迁移，不据本文称已支持。


**祈求设计修订（TASK-PRAYER-DESIGN，2026-10-28）：** 两类求告、人物身份知晓、有限原根与详细/后台调度的目标合同见事件规则第14节；新增CSV已接入Catalog有限装载；人物知晓与本次意向已接入代码，实际验收见本项报告；身份知晓、正式两模式调度及四类既有原根已分别限定交付；四格与最小玩家知情由当前INTEGRATION接续，五族新原根、完整Session/跨模块存档和自然可达仍待验。旧实施记录不替代本轮当前证据。新增取舍供制作人审阅，不冒充作者逐项终审。

**设计修订／运行时未兼容（TASK-CULT-DIRECTION，2026-10-27）：** 密教schema2规则和CSV已按本节修订，新增取舍仍供制作人审阅，非体验终审。当前src仍消费旧机构许可/事件证明；TASK-PRAYER-KNOWLEDGE已接入Catalog对新表、空event条件、新selector及open_route的有限语法校验；这不代表相应密教消费者已支持。现有游戏不能被当作本修订已实现或可继续运行；后续由CULT-SPREAD／ANCHOR-ROUTES／ANCHOR-LIFECYCLE／CULT-SAVE-COMPAT接入，其他祈求生产沿PRAYER链。下文既有实施记录仅说明旧规则范围，不能覆盖本次差异。

**用语校正（TASK-CLAIM-ACCURACY，2026-10-28）：** cell是基于教团、领袖和成员状态的招募资格记录，普通招募从本域无名非信众池按原公式聚合结算；cooperation是指定材料递交的来源记录。当前设计及旧运行时均不包含按多种社会网络计算逐人传播、接触过程或招募目标覆盖的模型。对象/事实引用存在及当前资格检查不能证明这些社会过程已被模拟。本次仅校正文案，玩法、CSV、schema、稳定ID与数值不变；schema2目标接口仍未接入旧运行时。

**实施边界（TASK-ATTENTION）：** 规则、事务、历史索引、分段保存、概略候选以及混合开局/F-N-P准入/成员转换已接入。SIM／TURN／ECON继续验证全详细参考路径，assigned概略与hybrid注意力各有专项证据；完整混合集成和正式负载归下一项TASK-FIDELITY-VERIFY，完整业务与玩家界面仍由原下游任务接入。迁移顺序与接口见 [架构](../architecture.md#分层推演的正式接口与迁移边界)。


# 文明、污染与抑制

## 1. 设计目的与边界

让玩家面对会维护自身秩序的世界。文明不能只是不同血量的矿点；至少进入手段、传播媒介、扎根条件、反制对象中两项应产生实质差异。

本系统处理文明自身状态和机构条件。权能消耗归 [权能与教团](system-powers-cults.md)，苏醒收益归 [进度](system-progression.md)，事件选择与结算归 [事件](system-events.md)。不在本文件重复这些规则。

## 2. 世界规模与观察范围

策划基线是每局有限的十二个时空域：六个星球级、四个星系级、两个宇宙级。数值单源在 [civilization_parameters.csv](../../data/civilization_parameters.csv)，正式规模可调整，不等于本次已制作十二个完整世界。

开局只知道一个星球级时空域，至少有一个有效祈求人和一种可执行的低阶接触方式。其他时空可经祈求中的异域线索、信徒经历、圣物来源或主动感知逐渐显现。发现不是自动渗透，情报也不直接产生信仰。

最多同时展开六个文明的管理信息是操作复杂度基线，不是冻结其余世界的魔法。折叠、未观察、已撤离的文明仍按规则演化。其无人名群体以聚合方式计算；具名人物、未结事件和锚点始终保留身份。未接触文明不无故知道玩家存在。

文明之间是稀疏通路图。通路表示共同媒介、迁移、通信或规则共鸣。生成需确保从初始域存在可逐步发现的路径到达各层级，但不保证玩家有资源通过或最终获胜。更高文明不是必须等“解锁按钮”才存在；提前引起其注意可能导致失败。

## 3. 文明组成

每域包含以下彼此不同的信息：

- **影响层级**：星球、星系、宇宙。影响反制范围、锚点价值及最终苏醒资格，不直接要求模拟相应天体数量。
- **知识范式**：科技、秘术、信仰、思潮四项权重，总和为百分之百。主导与次级阈值见参数表；混合文明使用同一对象，不能拆成互不关联的四套居民。
- **权力组织**：层级集中、议会、分散或一体化共同体（数据分别为 hierarchy、council、decentralized、unified）。决定谁组织调查与清洗、争夺解释渠道会触及哪些主体；不决定邪神是否被允许秘密发展。
- **传播结构**：广播、网络或仪式。这些蓝本分类对应已列明的媒介条件，例如独立节点记录、不同回合仪式；不表示普通招募已模拟广播覆盖、多种社会网络或逐人接触，也不自动映射为现实技术先进程度。
- **现实矛盾**：一种可被利用的具体缺口，例如解释失败、教义分裂、契约冲突或共同记忆中的例外。它提供进入理由，同时也会被文明尝试修复。
- **机构**：每域默认三个，分别承担解释、传播和秩序维持职责。可以由同一阵营控制，也可以互相竞争；必须分别有持久身份、当前控制方和状态。
- **人口与人物**：无名人口按群体聚合；与玩家互动或承担事件角色者具有持久身份。人物的共用属性和状态由权能与教团规则规定。

初始八个文明蓝本见 [civilization_profiles.csv](../../data/civilization_profiles.csv)。它们是可重组的标杆，不是随机改名的八个数值怪；每个都写明进入、传播、扎根和抵抗方式。蓝本中的初始屏障与稳定性是工作数值，不是平衡结论。

## 4. 生成流程

1. 先配置本局的层级分布和通路，再选合法蓝本。
2. 按 [文明条件](../../data/civilization_conditions.csv)中的允许组织和生成规则改变范式权重、机构与矛盾，保留其清晰可识别的主问题。
3. 先生成有持久 ID 的机构、岗位与宏观处境。混合模式仅为初始重点域与已固化互动按需提名人物；后台岗位可为“有人任职但尚未具名”，不生成全部居民的人生。已有具名代表失能或离任不能退回匿名状态抹掉后果。详细人物与祈求人按下述分层规则取得真实的当前处境或已有关系，不能倒造旧亲属、证言或神迹。全详细参考基线仍按 `initial_named_per_domain` 初始化。
4. 给出屏障、稳定、初始冲突与玩家已知情报。首次接触的起点不得自带正在执行的高阶反制。
5. 校验相容性、通路、身份、可接触起点、合法的传播与扎根途径。通过才纳入本局。
6. 达到有限重试上限仍不合法，返回可解释失败或采用已通过校验的保底蓝本，记录采用原因；不能无限抽取，也不能悄悄删除冲突字段。

相容性不是把复杂文明简化成刻板标签。例如高科技不排除祭祀；真正非法的是“只有仪式传播路线，却完全没有可以承载仪式的机构或对象”，或“所有入侵方式都要求只有侵入后才可能获得的东西”。

新文明不由运行时大模型直接决定规则。AI 参与蓝本、文案和候选故事生产，经过离线校验与编辑后成为版本化内容。运行时的随机性只在批准的规则空间内组合。

### 4.1 有限具名人物关系网（DEC-023，有限图及恢复已接入；自然来源另验）

本模型只为有限具名人物建立有来源的关系，供真实亲属求告、争议、契约和共同读取使用；无名人口仍按人口池计算。初始图包含接触偏好、可重叠的局部群聚、跨机构联系和联系人数量差异。这些是可检验的游戏规则，不宣称完整社会学模拟，不在六人样本上拟合幂律，也不模拟任意人际传播。参数唯一来源为 [social_graph_parameters.csv](../../data/social_graph_parameters.csv)，类型唯一来源为 [social_relation_types.csv](../../data/social_relation_types.csv)。

**当前实施边界。** TASK-SOCIAL-GRAPH-INITIALIZATION — Social Graph Generation and Initialization Integration已将两张CSV、内容指纹/有限grammar及同一cohort生成器接到World初始化和真正首次展开，替换原support环；当前heads、来源、最低一致查询/拒旧及三处旧关系后果的必要兼容一并接入。旧initial_generic_relation_count只保留非负整数兼容形状、允许合法不同值，不再消费为图预算。ROOT_INITIAL_TIES的生产归属/三种product grammar已由Catalog接受；LOCAL-TIES仍只处理当下事故及已有亲属求告。精确终止/重建及局部读取已由TASK-SOCIAL-GRAPH-RELATIONS接入，出生与严格历史恢复按本节RESTORE合同进入World4/Turn3与持久图2；正式当前检查及两层父原ACC逐条汇总见docs/qa/social-graph-restore.md、docs/qa/social-graph-lifecycle.md与docs/qa/social-graph.md。代码接入不代表完整Session或自然新局可运行，组件/完整回合保存的证据分别限定。

ROOT_INITIAL_TIES保留CSV的`phase=bootstrap`，本行专指**每批新人物cohort的初始化**，不作为任意回合可执行的授权。实际子阶段固定写入`social_graph_generation.changes.phase:string`，仅允许`world_start|first_focus`：前者只由原世界初始化事务发行，后者只由正式首次展开事务在原F/N/P及人口准入后发行。GRAPH须同步根grammar的有限子阶段和发行者校验，并审计source phase/cohort phase、实际turn、首次完成标记与调用来源一致；不得因CSV写bootstrap就在turn>0的普通轮末、重复聚焦或后续单人提名中绕过准入重建图。

#### 接触资格与初始背景

`contact_context(a,b)`的唯一判定是：两个不同、现存且active的具名人物在同域，双方所属机构存在、可运作且仍是人物的实际机构；同机构，或两机构当前`links`互相包含对方。返回`{kind,institutions,channel_sources}`，kind为`same_institution|institution_link`，institutions依a/b顺序，channel_sources引用当前机构/通路的原来源。机构初始化的world_origin可作为初态出处；后续通路变化必须保留其实际变更来源。仅同域、共同标签、有亲属关系或存在一条单向link均不足以替代该条件。

同机构或机构往来只给予可能接触的背景，绝不将合法候选全对登记为互识。图生成只为抽中的有限人物对写`social_contact`事实，保存`{cohort,a,b,basis,institutions,channel_sources}`并引用本批social_graph_generation、双方真实identity_source和机构来源。identity_source是事实ID字符串：world_start直接由`_new_npc`初始化的人物使用其真实`world_origin`（当时人口已在初始化账内分配，不存在nomination事实）；first_focus经`_nominate_local`新具名的人物使用实际`nomination`事实，其actor必须匹配该人物。图生成只引用这些已有来源，不能补造提名或再次扣减无名人口。它表示本批人物初态中成立的接触背景，不声称过去某轮开过会、读过某份记录或达成过契约；初始化也不生成这些往事。后来共同活动需重新核验当前contact_context，并由实际执行的handler留下本次参与/交付事实，不能拿初态social_contact代替当轮见闻。

#### 同一套有限选边规则

cohort仅包含本次新创建的具名身份，按稳定ID排序。原`initial_named_per_domain`或混合模式原人物/F/N/P预算仍决定人数，不为关系补人。令人数为n；每对不同人物最多占一个无向邻接，无论以后有几类关系。目标邻接预算为`min(n*(n-1)/2, floor(n*initial_edge_numerator/initial_edge_denominator))`。个人初始邻接上限为`min(n-1, initial_degree_max, initial_degree_base+floor(influence/initial_degree_influence_divisor))`，n不足2时直接为空。影响取该人物真实初态属性；它只决定此有限初态的上限，不代表高影响必然有朋友，也不随以后属性增长自动补边。

| 决策 | CSV基线及推导 | 不承担的保证 |
| --- | --- | --- |
| 初始邻接预算 | 分子5/分母4：六人目标7对，少于全连接15对，并允许三联系人分支与三角 | 不保证每局填满7对或全图连通 |
| 个人差异 | 基础2、每2点影响增加1、上限4；当前profile基线影响1–4使该公式个人上限为2–4 | 不给每人固定2条边，不保证实际度数达到上限 |
| 共同联系人 | 每个加3，最多计2人；已有局部邻接提高闭合三角的权重 | 不先分成互斥小队，不强制补三角 |
| 跨机构联系 | 尚无本cohort邻接连接的机构对加2 | 不新造物理通路，不要求每个机构都有桥 |

一次生成依次执行以下步骤，不重试整个图来追逐理想形状：

1. 枚举本cohort中contact_context合法、两端未达上限且尚未选中的无序人物对。共同职责取人物`role_tags`交集，关切取`need_tags`交集；机构role不冒充人物共有职责。
2. 每对的整数权重为`contact_weight_base + 同机构*same_institution_bonus + 有共同职责*shared_role_bonus + min(共同关切数,shared_need_count_cap)*shared_need_bonus + min(已有共同邻接人数,common_neighbor_count_cap)*common_neighbor_bonus + 尚未连接的跨机构对*institution_bridge_bonus`。基线依次为1、2、2、2、2、3、2、2；共同邻接只计算已选的本cohort初态边，不读全域历史。
3. 先在至少一端度数小于`initial_coverage_degree`（基线1）的合法对中按权重抽取；没有这种对后，转为所有剩余合法对。每次成功选择后更新本地邻接/机构对统计并重算受影响候选，直到达到预算或无合法对。阶段一允许仍有人孤立，不能越过资格或上限补边。
4. 每次抽样采用固定序列化及版本化哈希，候选按无序端点ID升序排列，使用累积整数权重。取`SHA-256(JSON紧凑数组[model_version,world_seed,domain,phase,cohort_id,draw_kind,draw_index])`首8个十六进制字符为无符号整数，对总权重取模。model_version/draw_index为JSON整数；world_seed为原世界种子的规范十进制**字符串**（0写`"0"`，负数仅一个前导负号，无正号、前导零或空白），domain/phase/cohort_id/draw_kind也为JSON字符串；UTF-8、无空白、无BOM。draw_kind区分`edge|type|direction`，draw_index为本cohort从0起的选边序号。同一输入可重放，不消耗事件/检定随机流；ID只保证稳定遍历，不规定相邻关系。
5. 每个选中的人物对先写social_contact，再按下述类型表过滤、按类型ID字典序升序排列后抽一类初态关系。support的指向由单独direction抽样对2取模确定，0为较小ID指向较大ID，1反向。整个cohort与来源在同一受管理事务中提交；中途失败回滚，不留下半张图。

#### 类型、方向与同时存在的关系

| 类型 | 有效方向 | 初态权重/资格 | 语义边界 |
| --- | --- | --- | --- |
| family | mutual，一条来源两端均可读为亲属 | 2；本cohort合法contact | 泛称亲属，不建立年龄/婚姻/父母子女树；不推导朋友的亲属或亲属的亲属 |
| support | directed，a支持b | 4；本cohort合法contact | 不自动推出b支持a，不授予实际援助结果 |
| cooperation | mutual | 3；双方至少一个共同role_tag或need_tag | 当前合作联系，不声称已履行某个契约或交付材料 |
| rival | mutual | 1；双方共享该行initial_need_tags中的至少一个关切，当前为knowledge/recognition/judgment | 求知/认可/判断可产生竞争，但尚未发生具体记录争议；同为受灾者不自动敌对 |
| hostile | directed，a敌视b | 0；只能由真实已声明的关系后果生成 | 不由初始化随机补敌人 |
| favor_owed | directed，a欠b人情 | 0；只能由实际合作结果生成 | 不凭共同标签生成债务或历史履约 |

`initial_rule`分别为`cohort_contact|cohort_shared_role_or_need|cohort_competing_need|actual_result_only|actual_cooperation_result_only`，按本表定义执行，不解析自然语言。initial_need_tags只用于cohort_competing_need，以`|`分隔；其他规则为空。将knowledge纳入竞争关切，使真实可接触的记录者和审查者也可生成跨机构rival；共享knowledge仍可抽中cooperation，不强制竞争，也不授予任何具体记录。合法类型的正整数initial_weight累积抽样；family/support保证合法接触有可选类型。initial_weight=0不得进入初态类型抽样。上述六类均可与其他类型共存：亲属可以竞争，有合作义务者也可能敌视对方；任何新增类型都不能隐式删除其他类型。一个无序邻接只占一次初始图预算，多类型、双向support不能伪装成更多联系人。

mutual的键为`[min(a,b),max(a,b),type,"mutual"]`；directed的键为`[a,b,type,"directed"]`。重复提交同来源幂等；当前已有相同键时返回原head，不追加第二份当前关系，也不制造新的来源。相反方向的directed可独立存在。关系终止须引用该精确head的明确有源结果，当前head移除、历史保留；以后真实事件重新建立同键时产生新episode来源，不能将旧已撤销来源复活。现有hostile/favor_owed后果须通过同一写入口保持该边界，不把本设计变成泛用的结交/断交按钮。

初态关系的外层事实沿用World事实结构：`kind="initial_relationship"`、`id`为新事实ID字符串、`actor=a`、`targets=[b]`、`domain`为本cohort域、`turn`为实际生成轮，`causal_parents=[contact]`。`changes`必须且仅包含下列字段，不接受kind/type两种别名：

| changes字段 | JSON类型 | 固定含义 |
| --- | --- | --- |
| schema | integer | 1 |
| kind | string | 类型表中的family/support/cooperation/rival之一；方向必须与该行一致 |
| a / b | string，各一个非空人物ID | mutual按ID升序；directed按实际a→b，不为排序逆转支持方向 |
| direction | string | mutual或directed |
| cohort | string | 已保存cohort_id，且两端均在该cohort member_ids中 |
| contact | string | 本次选中人物对的social_contact事实ID；该事实cohort相同、无序两端与a/b一致 |

不写`changes.type`、`changes.source`或`changes.episode`。一段关系episode的身份就是外层`fact.id`；关系投影/查询的`source:string`也必须等于该ID，不另发第二个身份或计数。`relation_between`统一从精确head返回由`{source,kind,a,b,direction}`组成的脱离副本数组；消费者不猜字段别名，也不把contact或generation_source当关系来源。显式终止后重建的episode须是新的真实关系事实ID，重复提交仍返回原head。

初态仅将此关系事实通知关系两端（`initial_ends_relation_only`）；不通知整个机构、全域或玩家。后续关系由其生产者明确列出的实际接收者获知（`producer_recipients_only`），targets/parents本身不等于知晓。关系、知晓邪神、信仰、忠诚、所持记录与玩家情报相互独立，图不自动复制任何一项。

#### 生命周期、唯一写入和保存接口

- **world_start**：初始化本域本批新人物后生成一次。**first_focus**：只对该域首次展开时本次新增的人物生成一次；不能把早已具名的人重放进初态cohort，也不能给旧人补过去亲属或旧交情。两阶段已有cohort均不得重跑。后续单人祈求提名不触发图生成、不继承无名群体关系；新旧人物要建立关系只能经另有明确规则的当前事件，本设计不新增自动交际日程。首次展开前已具名的bootstrap人物因此可能仍孤立。TASK-PROGRESSION-ROUTES必须覆盖“既有具名人物孤立/缺合法正向关系”的可主动促成路径，指定真实当前接触/合作的生产者、费用和资格并交给对应SOURCE/ANCHOR-ROUTES任务实现；不能只承诺未来自然会发生，也不能由GRAPH补旧交情。该促成路径已由TASK-PROGRESSION-ROUTES完成设计，实际Joint Work等操作仍待对应业务/界面任务接入；本批图不代做这些活动。
- 首次展开按实际调用历史判定：全详细初态域及初始重点域已经在world_start展开，后来撤F/再关注不产生first_focus初态关系；原expand仍可按已有准入提名新人，但这些新人不补初态边。此前未展开的后台域保存world_start空cohort不代表已展开，旧bootstrap人物也不代表已展开。generation的input_snapshot保存`expanded_at_creation:boolean`：world_start由实际全详细/初始focused调用决定，first_focus为真；读取时结合来源及真正首次调用核验，不由现有人数或自由传入值推断。该标记仅记录实际展开，不改变人口/L/F/N/P/K或提名规则。
- 每个阶段保存完成标记，包括0/1人或无合法对的空结果；再次聚焦、撤关注、存取档都不重新抽样。人数/F/N/P不足保持既有合法结果，由DEC-022路径设计处理可用进展，不为某个祈求补满星状小队。已有关系和稳定ID不因迁移、失踪、拘禁、死亡或机构改变而重抽；这些变化按当前contact_context及具体源规则取消相应行动资格，历史仍在。关系终止和当前不可接触是两个判断。
- 初始边预算和度数上限只限制初态生成。实际已授权事件的强制关系后果不得因为以后度数较高而被丢弃；后续不进行无来源的自动增边。全局仍受已有具名身份预算约束，每个有向/互惠类型键最多一个当前head。这里不承诺关系数永久保持初态7条，也不新增会让已承诺后果失败的终身关系容量。
- `SET-SOCIAL-GRAPH`由World唯一受管理关系结算写入，其他模块提交有源意图；消费者只读。目标状态为`state.social_graph={schema,model_version,data_versions,cohorts,edge_heads}`。schema=2（本批持久图格式，model_version仍1且关系/生成事实schema仍1）；data_versions记录两张新表与本批人物profile数据的内容版本。`cohorts[cohort_id]={domain,phase,turn,member_ids,seed_key,generation_source,completed,empty_reason}`，cohort_id固定为`domain + "/" + phase`。generation_source指向`social_graph_generation`事实，保存model_version/data_versions/seed_key及input_snapshot：各member的profile、influence、role_tags、need_tags、institution、`identity_source:string`（按上文区分初始化world_origin与首次展开的真实nomination），以及本次实际使用的机构状态/links/channel_sources。审计使用此时快照而非多年后人物的当前属性；空结果也有该来源。ROOT_INITIAL_TIES的product_kind列完整登记`social_graph_generation|social_contact|initial_relationship`，不漏掉图批次与接触事实。`edge_heads[规范键]=relation_source`是唯一当前关系投影；既有`npc.relations`保存完整关系历史引用，不作为第二份当前真相。
- HistoryIndex增量维护`current_relations/person`、`pair/type/direction`及`relation_source→head`反向索引。`relation_between(a,b,types)`返回脱离副本及精确source/direction，可包含mutual、a→b、b→a，由调用者声明接受哪种方向；不能为了跨机构来源把有向支持当成双向承诺。联系人查询按不同人物去重并局部分页；source生产仅取具体规则所需的有限候选。新增/终止关系、人物状态、机构及通路变化只更新相关索引/当前资格，不每轮扫描全图或历史。
- 完整保存包括cohort标记、输入版本、来源、精确当前head与历史；恢复先校验来源/方向/端点/幂等及当前投影，再重建派生索引。显式全审计可遍历历史，正常候选读取和轮末不能使用该路径。旧固定环存档不能静默重生成新图：若尚无正式有源迁移，则明确版本不兼容；具体迁移与Session整合归GRAPH及既有SAVE任务，不伪造新的过去。

#### 精确终止与业务来源一次消费（TASK-SOCIAL-GRAPH-RELATIONS，本批实施合同）

这是原`explicit_source_only`的有限技术语义，不新增玩家结交/断交操作。唯一当前许可的终止业务是正式PR03深干预成功分支`withdraw/pursuit_relation`。它只处理原`pursuit_condition.changes.relation`指向的精确当前head；其主体/追索者、原descriptor、机构/原pursuit及原关系端点继续按祈求合同验证，不撤其他关系，也不把原`withdraw/institution/support`扩大成人际支持清除。

World唯一受管理入口`retire_relation(head,receipt,owner)`核：receipt是实际PR03、variant=deep的`prayer_fact`，tag为`pursuit_relation_withdrawn`、`changes.original=head`、facts.pursuit为该实际追查；直接因果含本笔成功或深成的turn_check，沿实际prayer_attempt核对应深干预/原source和请求。普通origin、message、预览或错head不能授权。实时在_apply_rows先发行该撤销回执再终止，不能要求尚未发行的最终prayer_result作父来源；提交及恢复时补核最终result.produced确包含该receipt，最终result沿因果链匹配同一attempt/check，顺序无环。

终止由同一World写入`invalid_records[head]=receipt`，移除精确当前head及对应局部索引，原关系事实/各端历史保留；原pursuit关闭继续原时钟及后果。重复`retire_relation`且同head/同receipt返回原效果，不追加来源、不触碰后来同键的新head；另一个receipt不能借已退休旧head撤后来关系。

建立关系的实际业务proof在`applied_authorizations["social/relation/proof/"+proof_id]`一次绑定原episode ID。合法的新proof命中已有同键head时同样要绑定后返回existing；旧proof再次出现只返回其原episode，包括已退休历史，不能复活或改为后来head。只有随后独立的新真实业务结果才可能建立新episode，仍走原业务条件/类型方向和唯一writer。当前proof只承接原PR10 hostility、EVENT03/A favor_owed、EVENT09/A hostile的实际关系后果，不开放自由发行者或新的自然源。

RELATIONS子只验关系生命周期/当前查询/必要局部恢复；出生配方、真实提名/focus提交绑定、完整历史投影双向等值及联合坏档由下节`TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit`合同承接，当前验收以本轮新报告为准。不能把额外自报快照、checksum或两个互相抄写的manifest称为该出生来源审计。原数据和选边/数值/预算不变；受影响旧格式明确拒绝，不静默生成新过去。

#### 出生来源与严格历史恢复（TASK-SOCIAL-GRAPH-RESTORE，本批实施合同）

出生审计检查实际生产规则，不能仅将generation.input_snapshot与当前NPC或另一份自报manifest互相比较。World正式初始化与完整恢复共用唯一纯初始化配方：输入为该局原generation seed、真实full/hybrid模式及正式CSV，按原文明抽样、合法profile选择、代表和额外人物分配顺序/次数推导初态人物ID、profile、机构/初始代表及初始展开。生产实际消费该配方，审计在独立局部RNG重放，不推进当前局随机流，不调用递归World.generate；原人口/F/N/P/K、预算和有限选边算法不变。另将新结果与旧版留存八份真实开局样本逐值比较，不能仅让两个新helper相互自证。

技术版本为World4、Turn3、持久Graph schema2，有限生成model_version和initial_relationship/relationship/social_graph_generation事实schema保持1。新增WorldInitialization.plan(catalog,seed,hybrid,initial_focused,local_limit)供生产和完整审计共用，返回{ok,domains,rng_state}；domains中每域含{id,profile,named_budget,expanded_at_creation,people}，people含实际{id,profile,institution,representative}，不增加随机消费。world_origin.changes.initialization保存mode/domain_index/births/expanded技术记录并与该配方重放一致。

world_start的真实world_origin出生信息须与该配方一致，cohort快照中的profile、标签、初态影响、机构、identity_source和expanded_at_creation从实际初态核验。审计核历史出生信息，不拿后来迁移、继任或属性变化后的当前值倒推过去；合法后续改变仍可保存恢复。

nomination.changes.birth保存{schema,profile,institution,local_expansion,focus,position}；position.scope区分standalone、bootstrap与turn，turn位置包含sequence、fact_before、entry_phase、entry_turn并绑定真实receipt.request。仅把相同position抄进两个来源不能证明提交，必须经Turn真实receipt范围核对。原Turn.bootstrap_prayers在正式首轮前用Transaction但没有普通Turn receipt，其真实提名使用bootstrap位置（entry_turn=0、entry_phase=between、sequence=0），核现有prayer/bootstrap最终来源及首次receipt之前的事实边界，不冒充standalone或turn；该人物仍不进入后来first_focus cohort。

first_focus必须来自原合法取得F路径中的真实首次展开，涵盖直接关注、回应/权能准入及经营计划；不能只识别手动focus命令。实际nomination来源记录本次出生profile/机构/用途/focus来源和提交位置，generation只接本笔首次focus实际新增的身份。Turn按真实receipt的sequence、阶段及事实半开区间[fact_before,fact_after)核focus→nomination→generation闭合；同时按经济规则§12.5核实际attention_admitted/业务准入与request/op/目标，不能将set_plan或release_focus范围内的联造事实当取得F；不能靠来源自己声明“已提交”或伪造另一份快照作证明。后续refocus/普通单人提名/既有bootstrap不能补初边，0/1人及无合法对仍完成原空批次。原World.submit的standalone合法提名工具入口保持为当前提名，它不冒充Turn提交，也不能发行first_focus cohort。

保存边界分层：World4独立保存只含World状态，没有Turn.context；它可按saved generation seed与共享配方核world_start出生，并核first_focus的局部来源链/顺序/格式，不能单独声称已验证真实Turn提交范围。完整Turn3恢复额外按实际context.receipts的request/sequence/phase及事实半开范围核turn birth、focus与generation；其语义检查不能由birth.position的另一份自报副本代替。

完整恢复从每个真实initial_relationship/relationship事实推导每个人应有的历史投影：directed仅a端一条{target:b,kind,source}；mutual两端各一条，source均为该episode事实ID。与全部NPC.relations严格双向等值，拒绝缺失、多余、重复、反向、错类型/owner/来源；已退休episode的历史同样不得丢失。当前head、proof一次消费和精确退休再按真实历史闭合，不以只检查“存在一条正确记录”替代严格等值。

正常提交只检查新增事实与本次变化的NPC投影/相关来源和持久根，旧事实、旧关系历史及cohort来源不可被改写或删除；不重放整个初始化配方、不重建全部投影。显式完整审计（正式初始化、首次接管/重新采用外部状态、完整恢复）允许全历史遍历；普通已接管事务仍只核增量。正确checksum的联合改出生/快照/图产物，错阶段/提名/focus、缺多历史/当前head/幂等记录都必须在语义层拒绝并保留当前局；原样和未修改重签是必备成功对照。受影响World/Turn格式明确升版拒旧，不补过去，图模型/数值不变。

本批完成后，TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit与TASK-SOCIAL-GRAPH — Finite Named Social Graph Implementation须各按原四条ACC逐条汇总当前证据，另验首次展开→关系后果→精确退休/新episode→当前保存恢复→refocus/迁移的组合。不能只将子PASS拼作父PASS；原组件前提、完整Session/CULT、自然来源与路线/平衡/真人边界保持。

#### 数据校验与可否证验收

两表均禁止重复ID/未知枚举/负权重。参数表22项均为有限整数；分母、影响除数、初态基础权重、种子数为正；百分比0–100；其他数量非负；model_version≥1。类型表必须正好包含上述六种，方向/initial_rule/duplicate_policy/retirement_rule/knowledge_rule按该行语义校验；initial_need_tags不得重复或引用profile表不存在的need_tag，cohort_competing_need非空、其余规则必须为空；coexists_with使用`|`分隔且相容关系对称。不得在代码里再写第二份选边权重或初态预算。

静态设计门禁仅能证明表可解析、契约一致和在预算下**存在**同时含三角、跨机构边、三联系人分支与异质度数的六人图；不运行第二份生产生成器，也不把可行图当作自然新局证据。正式GRAPH实施后另用CSV指定的种子0–127逐个生成并测量，world_seed依次为字符串`"0"`至`"127"`，固定domain=`DOMAIN-001`、phase=`world_start`、cohort_id=`DOMAIN-001/world_start`：六人固定控制样本在三机构各两人、机构互相有links；interpretation使用NPC_PROFILE_01/02，propagation使用NPC_PROFILE_03/03，order使用NPC_PROFILE_05/05，文明采用允许祭仪的CIV_02，人物ID固定为A–F且顺序如上。属性与标签来自正式profile CSV，不能在测试里把所有人改成相同高影响。PR07的network条件另以CIV_08及同样的合法profile/机构预算核对：静态见证须能以解释机构人物B为中心形成三条正向family关系；这只证明图预算容许四人组合，不证明CIV_02可发PR07，也不证明CIV_08已有真实共同读取/登记或自然生成结果。

该控制样本中异质度数的图占比≥90%，含至少一个三角≥50%，含跨机构邻接≥80%，含degree≥3人物≥50%；四种允许初态类型在整个种子集各至少出现一次。分子使用满足条件的实际生成数，分母固定128，失败/空结果不得剔除；门槛全部读取CSV。另验无通路/人数不足、方向差异、多类型不重占邻接、失能与恢复、首次展开不补旧人、重复提名/加载幂等、版本拒载及索引读取范围。正式生产新局还须单列实际profile组合的生成结果和五族原根可达性；控制样本通过不等于正式自然可达。**初始化子批将正式生成器的128种子控制统计与真实World两入口/原profile样本分列，实际结果以新工具报告为准；完整生命周期、规模性能和自然源可达仍未由该子批验收。**

## 5. 状态与情报

文明四项主状态均限定在零至一百：屏障、污染、察觉、稳定。数值代表不同关系，不可相互代替：

- 屏障表示现实排斥异质影响的能力；降低它扩大操作效率与资格。
- 污染表示异质影响覆盖的程度；高污染不自动意味着有稳定教团或可收取苏醒。
- 察觉表示文明对玩家威胁的识别；每域独立，跨域传播情报须经机构或通路。
- 稳定表示既有制度维持一致行动的能力；低稳定可能方便扩散，也可能使信徒失去组织和供奉，不能一概视为对玩家有利。

玩家初见时获知范式线索和状态档位，主动探知后得到更精确的情报。行动前必须展示本次实际成本、已知概率与后果范围；未知信息以“未掌握”标记，不能给出伪精确值。会改变已展示检定概率的隐藏修正不得在支付后偷偷加入。

## 6. 进入、传播和扎根

### 进入

有效祈求或媒介允许玩家在完整屏障下尝试浅层干预。是否有资格由权能规定，屏障影响效果和风险而非一律锁住按钮。

降低屏障达到破口阈值后进入“有破口”；回升到较高的闭合阈值才关闭，避免阈值附近频繁切换。破口是持续状态，不可被反复开关刷奖励。破口关闭不撤销已发生的历史和人物变化。

### 传播

污染增长需要有效回应、权能、教团工作或特定事件，不能靠仅存在一个卡牌对象无限增殖。普通招募依据原cell/合作来源资格和本域无名非信众池聚合计算，不模拟群体接触范围或逐人传播。指定材料递交、强化播种及跨域操作另核其已列明的人物/事实引用、机构links或时空通路；这些有限条件不等于社会网络模拟。合作不颁发所有传教的许可证，也不增加招募量。跨域仍在目标域承受屏障与察觉约束，见第9节及经济规则。

没有扎根支撑的污染会自然衰减，思潮型文明的可变性由传播结构与机构状态体现，不机械规定“思潮必定最弱”。衰减、维护和反制必须分列原因，不能混成一笔“神秘损耗”。

### 扎根

一个锚点是“某机构持续依赖神迹或异质解释”的事实，不是可购买的另一种货币。建立锚点需要污染达到对应机构序号的门槛、该蓝本指定的机构条件成立、有效代理人或媒介，并完成锚定权能。门槛、维护支出与权能结算统一由权能及进度系统规定；文明系统不再设置另一套同义阈值。

机构条件举例：镜证议会需要有不可被单一证人撤销的异常记录；焚星圣统需要实际祭仪持续承载神迹，承载者可以是被正统敌视的秘密支系。两者不能靠同一个“支付信仰”按钮完成。

锚点区分未建立、有效、休眠和被毁。只有有效锚点提供当前苏醒贡献。污染跌出维持条件或停止供奉等情况进入休眠；机构被彻底抹除、必要媒介被献祭等明确后果可使锚点被毁，执行前须说明。恢复与重建沿用原身份，不能重复领取一次性收益。

同一机构只有一个锚点身份；重建沿用来源记录，避免无限拆建。多个锚点的收益、层级限制和重复收益规则由进度系统唯一规定。

## 7. 文明的主动演化

演化按轮末快照计算，统一批次应用，不能让机构遍历顺序决定谁先占便宜。

- 无干预且秩序完整时，屏障缓慢修复。
- 无有效锚点且本轮没有成功的污染干预时，污染按规则衰退；本轮成功新增污染就不再扣这笔自然衰退。被破坏的媒介会额外影响其负责的传播，不能无理由扣除其他域污染。
- 无新增暴露也无持续公开异常时，察觉可降低；低察觉不会删除已完成调查和既存抵抗计划。
- 持续冲突、社会危机和神迹后果可改变稳定；不把随机正负漂移当成全部演化。
- 机构根据自身目标和已知证据推进调查、修复、封锁或争夺。每域同时一项主要抵抗计划是初始复杂度边界；普通社会事件不占该计划位。
- 人物可成长、改变立场、转移、死亡；死亡与离开后先处理职位和圣物归属，再处理尚未触发的关联事件。

文明变化必须有来源：自然恢复、机构行动、人物行为、玩家干预或事件。玩家可按已知范围查看归因，不需要阅读完整后台日志。

没有单独事件或行动效果时，稳定保持原值，不做无来源的随机漂移。多个数值增减先相加再一次裁到合法范围；身份毁灭优先于普通恢复，未绑定的恢复不能复活已死人物。每域的人口初始值与迁入容量分别读取参数表：容量留出余量，但新增信众必须从现有人口转化，不会因为有空位就生成新生命。

<a id="civilization-simulation"></a>
### 正式演化：共同快照、机构知情与人物反馈

文明生成读取正式 civilization_profiles、civilization_conditions、civilization_parameters 和 npc_profiles。按层级配额选合法蓝本、形成稀疏可达图和三个机构，再生成合法岗位与人物；每个初始关系、初始危机及人物低理智都有实际初始事实。范式四项仍总和为一百，波动只在蓝本已有范式中重新分配；机构能力来自范式与职责，不通过生成器任意“补一个万能机构”消除冲突。

每域的机构至少保存持久身份、职责（interpretation / propagation / order）、代表、运作状态和已获得的证据。机构知情与世界全知分开：机构代表直接见证且以其职责记录的事实、或其成员实际提交的查证记录，才进入该机构的证据。看到同一域察觉上升，不等于获知全部人物或圣物位置。其他机构之间也不自动共享证据；跨机构或跨域传递必须引用真实通信通路与传递事实。第一版若未实现某项传递入口，就保持该信息不传播，不用全知兜底。

一次轮末演化依序承担以下职责，仍属于主回合阶段四，不另造一个“文明回合”：

1. 用已锁定的计划与费用状态形成共同快照，记录本轮新增干预、公开异常、人物执行占用和明确对象失效。
2. 各人物按人物章节选择自主意图。各机构按下面的资格从同一快照选择抵抗计划，文明自然恢复也从此快照计算。不能让先遍历的人先改变另一个人的候选。
3. 应用已经到期或本轮明确发生的死亡、永久损毁、迁移、拘禁与失踪，取消失效意图；普通恢复不能覆盖死亡。
4. 合并剩余合法行为的成本与效果，维护人口与物件唯一性，记录真实原因。事实、证据确认及新计划在本批次落地；它们不得反过来让本批次再选择另一项行为或更高一档计划。
5. 按主回合规则重新核验锚点、当前苏醒与资格，收入与终局仍由后续阶段执行。角色成长、忠诚与理智的变化会在下一次候选选择中改变其行为；既有来源不被清空。

**自然恢复。** 屏障修复取文明参数中的 barrier_base_recovery，但仅在秩序机构可运作、本轮没有成功污染干预且没有仍公开的异常时发生。污染按 pollution_base_decay 衰退的条件仍是没有有效锚点且本轮没有成功污染干预；察觉只有本轮无新增暴露且没有持续公开异常才按 alert_quiet_decay 下降。稳定没有独立自动漂移；只有已定义行动或事件改变它。自然变化记录规则 ID、快照条件与实际增量，不把最近一件无关事件当作它的原因。

**新增暴露与持续公开异常分开。** 普通 `exposure`（包括 NPC 公开解释造成的暴露）只标记发生当轮的新增暴露，并保留历史；它不会因为记录仍在编年史中而永久阻止屏障修复或察觉衰减。`public_anomaly` 才是持续公开状态：内容明确说明一种仍在公开显现的异常，并绑定本域真实人物、圣物或机构作为当前载体。载体仍满足当前公开资格、该异常未被明确解除时才算持续异常。不能把普通的“有人曾见过神迹”自动升格为持续显现。

持续异常的资格按载体分别复核：人物须在本域 active；圣物须在本域且未消耗、未封存、未被扣押隔离；机构须仍存在、未被毁灭且可公开维持该异常。人物死亡/失踪/拘禁/迁出、物件失去公开资格、机构失效或一个引用原异常的 `anomaly_resolved` 事实，均会停止其当前公开效力，原始异常与解除原因继续留在历史。没有固定的隐形过期轮数；恢复载体也不自动重开已被明确解除的异常，重新公开必须产生新的合法事实。

**证据的对象与强度。** 一份证据绑定原始暴露事实、明确目标、接收机构、证言提供者、发生/获得回合和确认状态。人物 `NPC_EXAMINE` 的强度由正式行为表计算，同一个人对同一来源不能重复累计。一个机构对同一目标的独立有效查证强度达到 simulation_parameters 的确认门槛，形成新的“证据确认”事实，其所有有效证言 ID 为前因。不同目标的强度不相加；不能把某人的见闻直接当作其全部亲属、整个教团或所有随身圣物均被定位。

未达强度门槛但有实际暴露来源的机构仍可按 RESIST_TRACE 发起有预告的正式调查；到期目标与机构仍合法时确认指定证据。高洞察人物或多名实际见证者可能更早形成确认，但这不取消任何重大抵抗的预告。确认在本批次刚产生时，最早在下一次计划选择中用于重大抵抗。

**双向反馈。** 一次公开神迹让实际见证者获得已知事实；其适应影响解释神迹的投入与代价，洞察影响查证强度，影响决定安抚实际受害关系人的效果，意志影响自身恢复。查证与公开解释可改变机构的证据和文明察觉，机构据此调查、扣押或清洗；这些结果再产生针对真实人物的伤害、失能、立场和关系后果。此闭环只表达表内行为和规则，不承诺模拟任意社会现象。

## 8. 察觉与抵抗

察觉依次进入关注、行动、封锁档位，具体阈值来自参数表；它们是资格阈值，不意味着跨阈值当场必吃一次伤害。

开始抵抗需要有效目标、具备行动能力的机构与可解释证据。优先针对实际暴露来源：先知、传播节点、圣物或锚点。文明不能隔着尚未建立的通路攻击完全未知的另一个域。

本版六种正式抵抗计划见 [resistance_plans.csv](../../data/resistance_plans.csv)，其可执行职责、证据类别与数字效果在 [civilization_actions.csv](../../data/civilization_actions.csv)按同一 ID 一一登记。前表唯一管理察觉、层级、优先级、预告、冷却和失效策略；后表唯一管理执行效果的数字，前表 result 仅为需同步的可读说明，代码不得解析其自然语言或硬编码第二份效果。每轮演化时，在没有正在进行的主要计划且冷却结束的域中，依据察觉、层级、机构能力和目标资格选取可行计划；按表中优先级最高者启动，同优先级按证据最近发生回合、稳定对象身份排序。没有合法计划就不启动，不强制补一次袭击。

达到关注阈值可以先查证异常，查证只产生确认的证据，不直接当作清洗；达到行动阈值且已有确认对象才允许扣押或清洗。重大损害只能指向调查已经连接到的对象，不能把某人一次入梦直接当作全教团和全部圣物均已暴露。具体卡片预告显示这条证据链。

计划冷却从结算或因目标失效取消后的下一轮开始计完整回合，冷却中不重复同族计划；计划表优先级不允许超过一个主计划并行。未达到最高优先计划的条件时，仍可做低阶查证或修复。起始时已明确的到期默认后果保持不变，状态变化只会使计划合法、失效或被玩家中止，不能临时加伤害。

结构化资格与后果按以下有限类别执行：

- `exposed`：运作中的秩序机构拥有指向本域存活人物或在域圣物的真实暴露证据，但该证据未确认。RESIST_TRACE 只确认指定证据并留下可追溯记录，不另外清洗。
- `confirmed_npc`：秩序机构已有确认人物证据，该人物实际属于当前教团。RESIST_PURGE 只损失该团无名信众并降低凝聚；人数损失按当前数乘表内比例向上取整，恰好计为死亡一次，不再次扣具名人物或其他域人口。
- `confirmed_relic`：已确认本域可控制圣物的位置。RESIST_SEIZE 转移同一圣物实例给执行机构，撤销旧携带/保管/绑定资格；相关锚点立即休眠。被移出执行域则按失效规则取消，不追着新域无媒介扣押。
- `breach`：秩序机构可运作且本域有破口。RESIST_REPAIR 的屏障与污染增量读取动作表；该行动以实际破口为依据，不需要伪造一个玩家人物证据。不能把它解释为对未知其他域的打击。
- `confirmed_anchor`：该域有效锚点的真实护持者或媒介已有已确认关联。RESIST_ERASE 只毁指定锚点结构，人物与圣物不附赠死亡或销毁。
- `confirmed_exception`：解释机构拥有已确认的法则例外及其可追溯记录。RESIST_REWRITE 按动作表增加创伤、减少本域污染；与 EVENT_11 是同一次结算，不执行两份相同伤害。

**事件与机构的效果边界。** 法则例外的确认必须来自已执行的正式事件结果，不能由人物普通查证或玩家免费操作直接授予。该结果绑定同域的解释机构和指定例外记录，引用例外原事实及事件实际依据；机构须可运作且已经知道该例外，记录仍有效且有可追溯来源。通过后生成确认事实并使其具备后续 RESIST_REWRITE 的候选资格，仍不跳过察觉、层级、计划位与预告要求。同一授权来源只能生效一次；重复提交既不增加证据、也不生成第二份结果。机构继任同样要求已执行事件明确授权该机构与该候选，不能复用授权把另一个人放入职位。

这个边界允许推演核心接收其他系统已经成立的事实；其可执行与测试不等于 EVENT_11 或机构继任事件的所有选项、费用和交互已完整实现。尚未接入的上游事件应在追踪清单保持缺口，不能在正式游戏里用测试注入入口绕过前置。

开始时绑定执行机构、目标、依据事实、预告期限和默认后果，期间降低察觉不会撤回已启动计划。到期再次核验机构运作能力、目标身份/所在地及仍有效的指定依据；目标取消不自动换人。公开告知的默认后果不因之后随机生成内容而变重；新危机必须重新预告。计划取消或结算均保留历史并开始该计划族的完整冷却。

**正式整合合同（TASK-RESISTANCE）。** `resistance.gd` 在正式 Events 安装后、开局首笔回执前安装版本化能力；`resistance_system/schema1` 绑定原文明/抵抗 CSV 内容版本。World 继续唯一选择和结算六类计划，Events 继续只承接原圣物 TRACE 与 REWRITE，不能叠加第二笔伤害。未安装会话保留原限定回归语义；存档不能跨缺失能力静默恢复。正式预告将原证据对象 `evidence_subject`、原 `parents`、固定 `due` 和动作表的 `default_effect` 一起写入 `resistance_started` 及当前计划；恢复与事务核对二者一致，拒绝修改目标、延期、效果或证据。只读预告返回脱离副本，不消费随机、费用或机会。

正式 PURGE 必须将已确认人物与其当前真实 `cult_id` 对齐，不能把高忠诚当成所有同域教团的定位。已定人物离团、迁出或失能，已定锚点不再关联原媒介/护持者，或指定来源被撤销时，按原失效策略取消，不换新的证据对象。原确认及其直接支持来源必须仍有效，历史确认保留而不再授予当前候选资格；普通隐匿只阻止新追查，不撤已经宣布的原计划。所有域继续从同一快照逐轮选择风险；关注、后台日常游标和管理页状态不改变原预告期限。跨域路径复用现有迁引、实际传播资格、通路及目标域屏障/察觉检查，不新增自动跨域污染或免费跨域情报共享规则。

确认来源由现有 HistoryIndex 保存有效桶与撤销反向索引，普通选择只取最新有效头；固定计划只重查其原父来源，不逐轮展开全部旧确认。新增确认增量入桶，指定依据撤销时定向退出当前资格，完整历史继续保留。正式能力同时保存每域破口状态与最近 `resistance_breach` 来源：初装按原开口阈值建立初态；每笔实际屏障变化即时应用原开口/闭合阈值，灰区保持先前状态。REPAIR 读取该当前破口，不能把回升到开口阈值之上直接当闭合。跨阈值有真实屏障变化前因，当前头与保存状态核对，灰区不能翻转布尔值伪造开闭；恢复重建历史索引，普通结算不倒扫屏障历史。

重大抵抗默认有两轮预告：给出目标、预计到期和已知后果。玩家可移走对象、转移暴露、破坏行动机构、承受损失、撤离或作其他有规则的应对。每条计划必须有不支付资源也能推进结算的“接受后果”路径，不能因贫困卡死回合。

当前基础规则不提供泛用的“摧毁任意机构”按钮。能够中止计划的手段要满足具体条件：移动/隐匿目标、使目标失效、销毁该计划依赖的记录，或使用事件中明确提供的专用行动。降低察觉可阻止后续新计划，不能自动撤销已启动的计划。宇宙修正通过 EVENT_11 承接，其表内伤害就是该计划的全部伤害。

抑制的总影响可由“察觉对概率/效果的修正”与“抵抗计划的实体损害”构成，但同一计划结算不再重复扣一笔同义惩罚。最终行动预览须合并并列出全部修正来源。

允许抵抗摧毁教团、夺走圣物、让锚点失效并降低苏醒。失败可以不可挽回；预告不是保胜承诺。若世界状态已导致无路可走，系统给出寂灭结算，不靠无限恢复机会维持假游戏。

## 9. 边界与验证要求

- 完整屏障下至少一种接触手段合法；破口后仍可能遭遇抵抗。
- 同一文明蓝本可有不同人物与关系；两种蓝本至少有可观察的行动顺序差异。
- 死亡人物不会在没有规则支持时担任新祈求主角；空缺机构职责可按本局继任规则处理。
- 折叠界面不暂停世界，不绕开清洗倒计时。
- 屏障破口/闭合、锚点损毁/重建不重复发放一次性收益。
- 异常生成有上界和失败原因；不合格组合不能进入正式存档。
- 只提高察觉而没有对象证据，不能产生人物/圣物/锚点的定向打击；同一世界中不知情的另一个机构也不能偷用证据。
- 调换人物、机构及文明容器的遍历顺序，选择与合并结果一致；本批次新证据不能跳过下一次计划选择。
- 低洞察查证、高洞察查证、多名独立见证产生可解释的确认时点差异；同一人物重复证言不累计。
- 人物的公开解释可以进入真实调查链，抵抗结果又改变人物后续资格；任何一步都能指出其真实来源。
- 基础技术验证的实测范围见 [技术报告](../qa/technical-feasibility.md)。本规则的全部蓝本和所有正式演化尚未实现，不能据基础测试宣称已平衡或已证明重玩价值。

## 10. 重点文明与后台文明

**模式归属。** 每个域唯一为 `focused` 或 `background`。开局重点数、同时重点上限及后台更新频率只读 [fidelity_parameters.csv](../../data/fidelity_parameters.csv)；管理页展开数继续只管显示。发现、查看、切换页面、达到污染阈值均不自动取得名额。“完成污染”不是永久免疫标志：无主动工程的成熟文明可撤关注，受到新攻击也不会自动抢占玩家名额。

主动处理屏障、定向污染、建立或修复锚点、主动传播等须先取得目标域重点资格；跨域迁引须两端，降临须其绑定的宇宙与星系域。一次性动作也适用。完整入口分类唯一在 [intervention_policies.csv](../../data/intervention_policies.csv)，容量与释放见回合规则第 12 节。当前工程未结束，或仍有无法转为准确宏观待办的细节承诺时，撤关注请求说明阻挡原因，不偷偷删除工程。

**生成与展开。** 后台初始仅保存蓝本、稀疏通路、机构岗位、人口与宏观当前态。匿名在任岗位代表的是群体中的职位占用，不是额外人口、隐形 NPC 或已取得人物证言。转入重点时，在本地辅助人数及全局活身份容量内，为尚未具名的关键岗位提名；从无名人口扣人，生成当下属性和合法原型，记录本轮提名根事实。不声称这名人物此前见证过历史神迹。已具名的代表恢复原 ID、属性、伤病和事实，不重抽。容量不足时可保持没有可用具名代表的机构，不补造新人；准入若明确需要该代表，必须在扣费前拒绝。

机构的 `occupied_abstract / represented / vacant / disabled` 是不同当前态。前两者可有宏观运作资格；后两者不能执行新的机构主动计划。`represented` 还须核对真实代表生存、所在地及失能。已经预告的计划仍按其原目标和失效条件结算。岗位原本匿名在任不等于具名代表死亡后的自动继任；代表死亡或离任沿原机构继任规则处理。

**低频日常。** 后台每域保存 `next_background_turn` 与独立抽样位置；初始化相位由版本化稳定域 ID 派生，不使用 UI 顺序或运行时哈希。到期阶段四只从当前蓝本、屏障/污染/察觉/稳定、有效机构/锚点、少量当前标签和风险摘要计算一次日常更新：按第 7 节既有恢复/衰减条件和原 CSV 数值执行一次，不乘漏过轮数，不补演匿名居民行为。无明确来源不随机漂移稳定。下一时间设为本轮加间隔。升降级不重置游标，不补领重点期间跳过的后台机会。

重点域日常每轮一次，后台日常按间隔一次，二者不能叠加。经济、风险、已知危机及期限仍每轮准确结算；所以这是新的节奏规则，不宣称与全详细模拟逐条等价。候选生成每次到期最多进行 CSV 声明的尝试；没有合法模板或容量就静默，不累积“欠玩家一次事件”。完整背景模板归 TASK-ABSTRACT-SIM／TASK-CONTENT，正式事件与祈求消费者仍各自实施。

### 后台风险不能休眠

所有域每轮执行同一风险选择职责，读取当前有效投影，而不是后台人物的完整见闻。未确认暴露必须保留可调查对象、来源、知情机构和当前可达性，即使尚未宣布抵抗也不能被压缩掉。机构有真实暴露与资格时，仍可按原表发动 `RESIST_TRACE` 并经历预告；不会因没有模拟匿名侦探而安全。确认、后续清洗/扣押/修复/抹除/修正仍使用既有六类计划的资格、优先级、冷却、期限和默认伤害。

详细 NPC 的查证是独立的证据贡献职责，不替机构再运行一次计划选择。后台不能凭察觉分数发明证言、确定某件圣物的位置或自动获得法则例外资格；这些仍需明确来源。持续异常的载体有效性逐次身份变化后更新；掩迹和察觉下降不能撤销已宣布计划。已有 `plan_id / target_id / due_turn / default_effect / source_ids` 原样保留；后台摘要不是把多个危险合成一个无害平均分。

风险当前投影按“域／机构／目标／证据类别”记录有效强度、确认状态和实际支持来源索引；同源证人去重、某来源失效后的扣减必须由索引支持，不只存无法撤销的总数。每域主要计划数仍遵守第 8 节上限；合法新风险被既有计划占用时保留资格，不发无限未预告计划队列。索引与失效反例在 TASK-HISTORY-INDEX 验证，后台持续风险在 TASK-ABSTRACT-SIM 验证。

### 概略生产的当前验证入口

TASK-ABSTRACT-SIM使用开局受控分配验证上述节奏：保留既有身份与历史，重点域和必要详细主体事先指定，后台普通人物暂停自主行为；逐轮风险继续读取有效来源，不能因后台日常未到期而停止查证。匿名在任、具名代表、空缺与失能分别校验，代表死亡/离任转空缺，不能自动冒出匿名继任。实际玩家切换及匿名混合开局在TASK-ATTENTION落实，不能把受控入口当成玩家免费重分配的能力。

### 当前混合展开与恢复

hybrid/schema2与旧assigned/schema1分开识别。默认参考配置用于回归，完整游戏入口使用混合开局。取得关注时，原具名代表和本地人物保留ID、属性、岗位及来源；仅尚匿名在任的岗位可从现有人口提名，空缺/失能不自动冒出匿名继任。容量不足时允许岗位尚未具名，重点域的该岗位不获得具名行动资格；其余准确状态保留。

本地L先取真实在任代表，再按当前合法身份和稳定ID选取，N/P不重复占L。切回后台不会删除这些人物，也不清空游标或补写未模拟人生。成员可独立在后台详细行动，关系引用本身不展开整个域。当前活身份K的保守校验仍在，详细行为集合受N/P/L上界控制；最终负载由FIDELITY-VERIFY分别改变活动规模与历史长度验证。


## 9. 密教渠道与八蓝本实际神迹依托（TASK-CULT-DIRECTION）

本节及CSV是修订后的设计单源，替换旧“事件授予机构承认”资格。它不声明运行时已兼容。`civilization_conditions.csv` 的旧列名 `institution_acceptance` 为减少无谓改名暂留，**值表示实际神迹依托，不表示文明、机构代表或正统赞同**。`anchor_conditions.csv` 保留profile/rule稳定ID与列头，schema2中event_id/event_option均为空：没有通用必选事件。数量、不同回合与存活门槛沿原参数，本项不调首团、锚点费用或贡献。

### 9.1 聚合招募资格与强化传播分开

`cult_spread_routes.csv` 的字段为 `id,kind,producer,source_kind,population_scope,requires_profile_for_seed`。route/channel是保留的技术命名，这张表区分资格及材料来源记录，不定义多种社会传播网络：

- **COVERT_CELL / cell**：目标接口中，由Cults依据同域 `cult_established`、当前领袖的成员/任职来源及现存信众状态派生招募资格记录。它只记录教团是否满足原招募条件，不创建或模拟秘密生活圈、联系人网络、逐人接触或目标覆盖。引用的成立事实必须存在，不能由调用者自填；换领袖、休眠、覆灭及成员失效后按原条件重查。不要求机构代表支持，也不依赖未来祈求知晓字段。
- **ALLIED_CHANNEL / cooperation**：目标接口中，由Events的EVENT09A结果和已记录的合作者、关系及通路派生指定材料递交来源。DEC-024修订“cell尚不能接触”为指定接收者/本次目标结构仍缺的材料端点，而非全教团是否有人知道该材料；真实关系/通路及能否实际提供由当次合同判断，不声称已经计算全社会可达性。发送者须实际持有该既存材料，递交给固定已有接收者；知识/保管回执由TASK-MATERIAL-TRANSFER接入。指定接收者已有所需有效材料/资格，或已有合法转交可以向该目标提供同一端点时，09A不可选。教团其他机构持有材料并不代表目标结构已持有，也不自动赋予递交；同团内部实际转交由MATERIAL-TRANSFER接入，不要求先购买合作。cooperation不增加招募量、人口池范围或独立记录，不代表模拟了新的社会传播渠道。没有此事件，cell仍可支持原聚合招募，原见证者仍可分布持有扎根材料。

普通招募直接以本域现存无名非信众池为聚合口径，每轮人数只按原有限招募公式及人口余量结算；没有另一个按生活圈、联系人或渠道覆盖划分的可接触人口池，也不计算逐个居民如何接触并改信。不表示全域每个人已与邪神联系，不新增无名人口或人际网络状态。跨域不能沿本地cell偷换目标域；迁引、人口、费用、F、成员执行机会及实际有源封锁照旧。察觉档位、官方敌意本身不等于渠道已封锁；现有六类抵抗没有通用“禁止全域招募”效果。

普通传教仍按原cell/合作来源资格（至少一条当前有效）、教团运作状态、本域无名非信众余量和原费用判断；来源记录备用不表示新增社会覆盖或额外招募量。**POWER_SEED是强化传播**，还必须满足 `cult_spread_conditions.csv` 的profile行；它不能只凭普通招募资格大规模改写文明。表字段为 `profile_id,rule,count_parameter,alive_parameter,alive_min`，参数仅引用原event_parameters；代码按下述有限rule判定，不解析中文说明：

| rule | 强化传播的实际媒介 |
| --- | --- |
| dual_witness | §9.7的record_testimonies或record_dependency；双见证仍用原人数且传播不另加不同回合，持续依赖仍须真实两轮使用 |
| calendar_ritual | §9.7的calendar_rites或calendar_dependency，各保留真实两轮及其实际祭仪者/历法操作者 |
| shared_memory | §9.8的memory_circle沿原三位存活合格见证；memory_practice沿真实双人跨轮依赖，不互换人数/材料 |
| ritual_contacts | §9.7的ritual_keeper或ritual_practice，实际承续者与所选执行者须有有效接触；本人用实际成员/实践来源，不造自我关系；不要求公开或官方代表 |
| network_evidence | 两个实际可通信节点中的同类独立梦境/证据，或§9.6明确的实际双向异常应答依赖；转抄本身不增加独立性 |
| contract_dependency | §9.8的contract_performance或contract_reciprocal，分别核完整实际条款履行及两端有效见证/保管 |
| axiom_exception | 同一真实例外的双节点独立记录与当前通信，或§9.6同节点不同回合真实使用形成的持续档案依赖 |
| collective_dissent | §9.8的dissent_circle仍须原三活；dissent_practice须本路两活和两轮实际返回，旧锚点两人生存下限不降低旧传播门槛 |

这些判定只取实际媒介，不附加物理锚点、圣物、污染序号或原承认事件。执行者/保管者不必是官方传播机构代表；可以使用其真实所属机构的记录或仪式载体，跨节点仍查真实links及来源。cell招募资格成立不代表蓝本神迹条件成立，任何口头支持不能替代它们。强化传播的实际媒介可由原见证者分布持有；不强求执行者先通过09A学会全部来源。接收者若希望用外部材料补足某一目标结构实际留存，则须真实递交，不能从“全局存在材料”推成该结构已持有。

### 9.2 八种扎根方式及失效条件

机构ID继续是有限现实结构的稳定锚槽，**不是批准机关**。同一结构内可以有秘密记录、异端祭仪、被迫履行的契约及未获正统承认的见证。下表各条件成立只说明该具体结构真实容纳了相应神迹；锚点本身仍需污染、教团、护持者、圣物和实付供奉。

共同的实际承载规则：basis.carriers固定 `{institution,person,sources}` 项，以覆盖本次有限必要材料的分布式实际持有者为准；同一机构可由多名原见证者各持自己的材料，不强求先汇总给一个人，也不把09A设成统一收集前提。每份被选必要材料至少有一个合法carrier，选择稳定的最小覆盖包，同一对机构/人物合并sources；不夹带无关人物或全部历史。person须在域active、实际属于该结构，并确实保管/实践sources指向的原记录、仪式或依赖；知情只查其真实知识与原结果/递交来源，不能由proof赋予。carrier不要求信仰、忠诚、官方代表职位或对邪神持肯定态度。一个反对邪神却仍保管不可消解异常的记录者可以承载；一句“我支持邪神”没有材料则不行。无关职务空缺、代表换任或 `institution.active=false` 不能直接代替结构损毁判据；机构槽真实存在、载体实际可用，才继续逐项检查。具体当前判据只取slot存在、指定carrier的status/domain/institution与真实知情、材料有效性、所需links仍在；不凭空新增结构状态。已有明确结构/媒介损毁按其实际事实生效；没有独立结构损毁字段/来源时，不从active标志推断建筑被毁，也不增设泛用毁灭机构行动。

| 蓝本 / 稳定rule | 秘密传播与实际扎根条件（basis固定键） | 实际失效，不能替代为官方态度 |
| --- | --- | --- |
| CIV_01 / dual_testimony | 普通招募仍按cell/合作及本域池；强化/锚定可用§9.7独立证言或记录依赖。前者保留原两人、两根且锚定另须不同回合（强化传播不另加轮次）；后者是同人真实跨轮使用，不能冒充双见证。秘密记录不要求EVENT02B公开收录 | 按所选分支的真实材料、原见证/操作者及保管载体检查；公开否认不使材料消失 |
| CIV_02 / calendar_ritual | 普通招募条件不变；强化/锚定可用§9.7原不同回合祭仪或实际历法依赖。前者沿真实PR05/当前祭仪者，后者由真实记录者按同一超常节拍跨轮实际组织周期；不要求EVENT04A | 按所选分支核仪式/历法使用、实际承续者及载体；更换无关代表不失效 |
| CIV_03 / shared_memory | 普通招募不变；强化/锚点按§9.8的memory_circle（原三位合格见证）或memory_practice（真实两人跨轮共同再现）。实际登记、亲历及保管分别检查，不要求EVENT06A | 所选分支的真实资格/材料/活参加者或载体丧失；机构不同意不等于私人知识消失 |
| CIV_04 / orthodox_witness | 稳定rule不表示正统授权。普通招募条件不变；强化/锚定可用§9.7原祭仪者承续或真实教习后的独立实践。后一条不先要PR05成功，也不授学徒职业；两条均无普遍官方许可 | 原路线的真实祭仪/实践、实际承续者或载体丧失才失效；正统敌视不抹掉实际依托 |
| CIV_05 / network_evidence | 普通招募按原cell/合作来源资格与本域池聚合结算；强化及锚点可用§9.6的`network_independent`或`network_exchange`。前者为不同人物两节点同类独立梦境/证据，后者为两端真实收发使用形成的依赖；basis分支键唯一见§9.6，不要求EVENT02B | 两路均须实际通信及两端承载；失去任一必要端点/材料/持有者即失效。应答依赖不冒称两份独立起源 |
| CIV_06 / contract_dependency | 普通招募不变；强化/锚点按§9.8的contract_performance（真实单向神迹保管履约）或contract_reciprocal（两端真实交付并形成相互依赖）。不先等EVENT05B，继任仅按事件§14.13的当前选定及真实接续结果，不要求生前文书 | 真实release、必要人物/见证/保管材料丧失，互惠另核两端及links；义务根关闭不等于解除依赖 |
| CIV_07 / axiom_exception | 普通招募按原cell/合作来源资格与本域池聚合结算；强化及锚点可用§9.6的`axiom_nodes`或`axiom_archive`。前者为同一有效例外的双节点独立实际观察/保留，后者为单节点不同回合真实使用后的档案依赖；不要求先完成EVENT11 | 原例外或本路必要材料/保管者丧失才失效；通信只约束双节点路线。文明承认/否认不制造或消灭例外，EVENT11A只影响实际销毁材料 |
| CIV_08 / collective_dissent | 普通招募不变；强化/锚点按§9.8的dissent_circle（原三历史见证、锚至少两活、传播三活）或dissent_practice（真实两人两轮相斥视角返回、两人均活）。不要求EVENT06A | 所选分支的当前资格/必要活见证/实际载体丧失；不换人、不伪造第三人历史 |

records只接受实际Prayers/Powers成功结果或事件§14.10明确试验成功结果的合格记录。归一映射限定：private_testimony/anomaly_record/public_witness/public_evidence属于证据族；exception_record/exception_learned/public_exception_qualification须解到同一exception与当次真实observation，axiom_record只按其实际观察者/观察核独立性；真实成功POWER_DREAM的原miracle属于梦境族。新axiom_dependency/network_dependency只用于§9.6对应依赖分支，不能塞入records伪装独立证据。包装exposure/公开收录只解包回这些原结果，不新增独立根；future_callback、调查候选、正统质疑、普通message或任意成功后的prayer_fact不自动算材料。ritual_witness/public_ritual只取真实PR05；§9.7另接受performed_rite及限定分支的practiced_rite，不改写它们为PR05，record_dependency/calendar_dependency也不加入独立records族。原记忆分支取memory_preserved，§9.8另接受其明确的受权保留/双人实践材料；原契约分支取同契约实际dependency及两端履约/知情，§9.8另接受route_contract_dependency及完整互惠两腿。不得把这些新分支材料当原三人PR07资格或原深履约的副本。私密/公开是知情传播方式，不是自动高低级证据。实际见证者取原结果的petitioner、目标或明确见证者，不把代理actor或围观者补成独立证人。复制、递交、包装或同人多次描述同一根不增加独立性。记忆资格仍逐人沿 `memory_preserved -> memory_at_risk -> 原memory` 核对；危机成功解除不抹掉被保留的见证。契约仍沿原contract_dependency及真实两端事实；PR06成功履约使contract_obligation危机根关闭/撤销只表示本次义务已履行，原根继续作为历史身份读取，不能被误判成dependency解除。只有明确引用原dependency的release_contract等真实结果撤销神迹依赖。契约继任按事件§14.13在需要时从原有真实关系选定合格现存者，再经真实结果接续；不强制生前文书，不补人补过去关系，原contract/due和一次性语义保持。

### 9.3 schema2实际依据、纯预览及秘密知情

新依据事实kind为 `anchor_basis`，changes严格为 `{issuer,version,institution,profile,rule,basis}`。正式文明/Anchors当前判定生产者拥有 `civilization_dependency/schema2/routes3` 目标能力及内容版本（§9.6至§9.8扩展尚待实施）；不得由任意事件、UI或调用者发行。basis只含本蓝本上表键，所有原材料事实直接列入parents，targets固定涉及的机构/人物，carriers.sources也进入直接父因果。profile/rule来自当前域及CSV，不接受allowed、nonce、自填“知晓”或旧institution_event_result代替材料。

正式规则在相关世界变化暂存并通过资格校验后、事务对外发布前，重判并暂存归一化的当前实际依据，最后与原变化原子发布；本批新材料不倒灌本批候选。相同机构/规则/实际来源束幂等，不按换回合或页面重造。**预览只计算缺口及候选依据副本，不写事实、不消耗随机、不制造首次圣物机会**。正式锚定前、材料/身份变化后与供奉前，重用同一当前判定；已存anchor_basis只是可审计来源，不能永久覆盖失效材料。

结构内秘密载体的知情与秩序机构的调查知情分开。carrier最小生产路径优先取原Prayers/Powers结果明确的真实见证/持有者，并核验该结果实际赋予的知识；换carrier只接受原learn等已有受管理实际告知/材料递交效果，不从机构知道或parents推知。share_record当前只向机构递交，不能借此让任意成员自动知道；若未来为个人另接合法递交，须明确发送者知道该材料、实际接收人/媒介、通路、当前源及接收事实，并由对应任务实现和验收。无合法新持有者时保留缺口，不让当前判定器创造知识。真实人物知道一份记录，不等于本域所有机构知道；`share_record`仍只按实际发送人、接收方、通路和指定source递交，不传播parents，不回填旧见证。已有机构全知不得由新依据生产偷渡；公开EVENT02B或实际调查可产生其原先声明的知情与暴露，秘密依据本身不为敌方补证。抵抗仍以已确认目标及原来源、预告、冷却执行，六类伤害不增加。

旧EVENT03B/04B的“否认”只记录职位、解释与态度；04A已退役，不保留付钱换空支持的按钮。`anchor_restrictions.csv`保留列头但无通用denied映射；不存在先求EVENT04A撤销旧否认才能秘密扎根的步骤。真实载体离职/损毁、材料撤销仍由上述当前条件失效，不以移除否认绕过它们。旧institution_event_result可作历史，但不再授予schema2资格。

### 9.4 首次实际依托与圣物机会

每个稳定机构槽首次真实满足本蓝本实际依托时，以原机构ID及首个有效anchor_basis固定一次 `institution_relic_opportunity`，无需官方态度或物理锚点。原唯一机构机会键保留；失去/恢复材料、换carrier、拆锚、规则升级都不能重发。类型仍仅从原relic_pool沿既有受管理随机流选择并固化，期限和回收/公开数值仍取原event_parameters。实例来历来自本次实际神迹材料；relics.origin是类型来历示例，不允许为套示例伪造亡教团或旧调查。

机会保存schema2、institution、首次basis来源、固定relic_type、created_turn/due及唯一来源。物理键可为兼容保留原recognition命名，但版本和指向的事实kind必须是实际依据，不准借旧键继续消费官方认可。回收/公开/等待/到期仍互斥且持久一次；回收须真实库藏或合法携带者，既有资格/空间不足付费前拒绝，等待不延期。材料之后失效不伪造“从未出现过”或另发机会，处置仍按该已固定机会与现存对象检查。新来源无需新增独立掉落系统，由TASK-ANCHOR-LIFECYCLE重接原生产/消费状态即可。

### 9.5 持有者、恢复审计与边界

以下全部持有者须同步schema2：文明当前依据头与来源失效索引、Powers的建立/修复请求及绑定、Anchors的有效/休眠/被毁状态与原slot序号、Economy预付/维护资格、首次圣物机会及Events/Relics消费登记、Endings当前媒介入口与活动仪式资格、Turn/Session能力版本和存档恢复。无需为名称本身改物理字段；需要更改的是实际来源语义和版本审计。

TASK-CULT-SAVE-COMPAT只接本次内容/能力版本拒旧及当前版本续存；未知或旧规则会话明确拒绝继续，原文件不覆盖，不默认迁移。重算checksum不能让旧event承认变成新basis，也不能洗掉机会已消费、重抽类型或复活绑定；未来若另做真实迁移，须逐材料重判并保留原身份/序号/消费史及RNG，不属于本任务。

本设计仍有待制作人审阅的实质取舍：普通聚合招募与蓝本强化传播分层；秘密保管/实践者可以承载机构槽；CIV04不强制公开/官方职位；不先经历EVENT11也可在真实双节点例外上扎根。作者已明确的“密教无需普遍官方批准”不重复请批。设计可被机器反例检验，不等于体验终审或生产路径已实现。

### 9.6 CIV05/CIV07的两条实际依托路线（Axiom, Network, and Manifestation Routes，设计待实施）

这两种文明的共同机制分别是**真实网络两端相互依存**和**同一仍有效的法则例外成为现实依托**。独立双节点记录是可用路线，不再同时冒充两个文明唯一合法的扎根方式。有限生产、参与者、费用及原始事实唯一见事件§14.10；本节只判材料及存续，不再造一次试验、知识或收益。

`anchor_basis.basis.route`在八蓝本均为必填判别字段：CIV05/07只接受下表枚举，CIV01/02/04见§9.7，CIV03/06/08见§9.8。rule仍分别为原`network_evidence/axiom_exception`，Catalog不从蓝本文案解析分支。整套设计的唯一当前发行能力目标为`civilization_dependency/schema2/routes3`；此前routes1/routes2不是并行有效标准。旧能力或缺route的旧会话不得猜分支继续，交给完整保存兼容任务拒绝。新路线CSV均design_only，当前消费者未支持。

| route | basis精确键（均包含route与carriers） | 当前真实材料条件 | 本路独有失效点 |
| --- | --- | --- | --- |
| network_independent | other_institution,records,witnesses | 目标槽与另一真实槽双向links连通；两不同active人物各有自己真实成功梦境，或原同类独立证据；所选人物分别在相应槽作为真实carrier。records解到两个不同原miracle/证据根，不能一梦两份披露；不要求同一随机事件 | 任一所选独立根或活见证丧失；通信/两端carrier丧失 |
| network_exchange | other_institution,exchange | exchange是同一真实成功ROUTE_NETWORK_EXCHANGE的network_dependency；其两个endpoint各由对应槽的实际operator保管，自己端点与依赖均确知，双向links仍存在。exchange不是独立证据族，不按records两根计算 | 任一端实际使用或原operator/承载失效，或通信断开；没有独立梦境不是失效原因 |
| axiom_nodes | exception,other_institution,records | 同一当前有效例外、两个双向links连通的不同槽；不同人物的不同真实law_observation，各有PR12或ROUTE_AXIOM_PROBE/RECHECK成功保留记录。每份记录的原观察地点与相应节点一致，原观察者仍active并实际保管；规范独立键为(exception,observer,institution)，同一人或仅同一观察的包装不增数 | 例外失效、任一原观察/保留记录/观察者或通信丧失 |
| axiom_archive | exception,dependency,uses,operator | 同一槽的真实axiom_dependency，uses为CSV要求两个不同实际回合的成功使用；operator实际参加两次、仍active在该槽并保有两次use及dependency。依赖始终指同一有效exception；不需要另一个机构、通信或第二人物 | 原例外/任一次use/依赖实际失效，或这个真实operator丧失；别处节点离线不影响它 |

所有键值为实际对象/事实ID字符串，records/uses/witnesses为去重ID数组，carriers仍沿§9.2 `{institution,person,sources}`。每份必要材料都有本路指定的实际保管者；network_exchange的每端carrier.sources含自己的endpoint及exchange，axiom_archive含两次uses及dependency，例外/试验根另直接列父因果。来源列表不授知情，不用机构知情替代这些人。主动路线当前只依赖原参加者承载，尚未设计的转交矩阵不能让新接收者替代原观察/操作者；合法递交只解决已定义的保管端点，不复制独立性或两轮实践。

共同锚点条件不变：实际机构槽、真实教团、序号污染门槛、信众与凝聚、可护持信徒、可绑定圣物、POWER_ANCHOR成本/检定及实付供奉。材料阶段的五操作不要求预先有物理锚点或圣物，因此仍能先形成实际依托，再沿原一次性遗物机会取得媒介；不产生“先有锚点才有材料”的循环。它们需要已有具名信徒，属于首团之后的高阶路径；不宣称替代首团及其他前置文明内容。

新建/修复锚定明确选择本次route和当前合法basis；选择是实际依托的风险取舍，不是改名重领奖励。成功后锚点绑定该route，维持只核该分支。若另一分支后来也成立，可在纯预览看见，但不因页面打开自动换路救活原锚；改绑分支须正常POWER_ANCHOR修复的成本/检定，序号、圣物/护持绑定与首次遗物消费史保持。当前同分支材料/保管资格按原规则刷新，不因文案变化收额外费用。强化传播仍由同一个只读材料判定器取得某一合法分支，不能据普通cell招募资格直接放行，也不另发一份数值收益。

首次遗物机会仍以原稳定机构槽为唯一键，两个route同时满足也只发一次。未绑定槽的当前依据选择按route ID、原来源ID稳定排序；已有绑定槽优先其绑定route，避免普通查询重排来源。必要材料销毁按确切事实失效，不把反对邪神、无官方代表或普通机构active标志当作档案被物理毁坏。

### 9.7 TASK-FOUNDATION-ROUTES-DESIGN — First Cult, Isolated Character, Record, and Ritual Route Design：记录与祭仪依托（设计待实施）

事件§14.11定义实际生产，本节只消费真实材料。CIV01/02/04继续使用原稳定rule，必填`basis.route`区分下列六分支；与§9.6、§9.8统一使用当前能力目标`civilization_dependency/schema2/routes3`。CIV05/07保留§9.6的四分支与字段，CIV03/06/08使用§9.8六分支，不重解释旧材料。新规则需要消费者和完整版本接线，现有anchor_conditions/cult_spread_conditions旧行只是稳定rule入口，不能靠列头未变宣称已支持新分支。

| profile / route | basis除route,carriers外的精确键 | 实际依托、保管与失效 |
| --- | --- | --- |
| CIV01 / record_testimonies | records,witnesses | 恰好原参数要求的两个不同active原见证、不同独立原记录、不同实际发生回合；记录可以是原合格证据，或两人各自真实成功DREAM产生的不同miracle。包装/PR04深披露同一记录不变两根。两份材料实际留存在目标结构的合法carrier，原见证各仍活；缺任一所需原根/见证/保管则失效。 |
| CIV01 / record_dependency | series,uses,dependency,operator | 同一目标结构的真实record_dependency；operator为原record_keeper，自己在两个不同成功回合真实读写同一series并保有两次use/依赖。它是反常记录被持续使用的依托，不声明两个独立目击者。operator须当前active在原结构、仍知晓/承载全部材料；撤销系列、任一use或实际失去操作者/载体即失效。 |
| CIV02 / calendar_rites | rituals,priest | 同结构两个不同实际回合的成功祭仪；合格来源为原PR05 ritual_witness/public_ritual或新performed_rite，解到实际发生而非包装。priest须为两次真实参加/主持且仍active的原ritual_keeper，实际承续并持有所选仪式；不把旁观人或未在场代表补为priest。仪式/原祭仪者/载体丧失才失效。 |
| CIV02 / calendar_dependency | series,uses,dependency,operator | 同一有效calendar_pulse的两次不同成功回合calendar_use及原calendar_dependency，原record_keeper仍active在目标结构、实际执行并持有它们。超常节拍是具体周期活动反复依赖的媒介；仅修改日期、写两行日历、听说旧祭日无效。节拍/任一use/实际操作者或载体丧失即失效；没有PR05不失效。 |
| CIV04 / ritual_keeper | ritual,priest | 一次原PR05真实成功祭仪或新performed_rite；priest为原实际ritual_keeper，active在目标结构且真实保管/承续。公开与否不变资格。原祭仪/原祭仪者/载体丧失即失效。 |
| CIV04 / ritual_practice | lesson,ritual,practitioner | ritual是原学徒于lesson之后另一个实际回合成功亲自完成的practiced_rite；lesson来自真实在场老师当下教习，原学徒当前active在原接收结构并保有两份材料/持续实践资格。教师后来失能/离开不追溯删除已经学会的具体实践，原学徒丧失或lesson/实践真实撤销才失效。不要求原老师先成功PR05，也不要求老师成为同团成员或仍在场。 |

所有对象键为实际ID字符串；records/witnesses/rituals/uses为去重ID数组，carriers沿§9.2原字段。依赖路的operator、实践路的practitioner必须自己实际持有完整必要材料，材料交给别人不复制原使用/学会/亲自实践资格；独立证言仍允许合法分布式保管。物理上已发生的教学历史不因老师后来死亡作废，伪造老师当时已死亡/无仪式职责则整条lesson不合法。这里没有把一般material_received扩成职业或超常实践授予；后续材料转交矩阵不得反过来删掉本路实际亲历要求。

强化传播同样按本蓝本选定的真实媒介分支判断：CIV01双见证沿原传播规则不另要不同回合，但record_dependency仍须两个真实使用回合；CIV02两条均须其实际两轮；CIV04两条均须真实仪式/实践及执行者到实际祭仪承续者之间已有有效接触（执行者本人则用其实际成员/实践来源，不造自我关系）。两条同时合格不会翻倍收益。原普通招募不因此要求新材料。

共同的教团、污染序号、十二无名信众、凝聚四十、可绑定圣物、合格护持者、POWER_ANCHOR费用与检定、实际维护一项不省。成功形成材料只是可取得实际依据，尚未建立物理锚点。原槽一次遗物机会沿§9.4产生/回收，不能由route处理者赠圣物；材料在先、遗物机会在后、锚定在后，无先锚后材料循环。分支绑定、同分支重查、切分支的真实修复、一次机会消费键均复用§9.6；换route不能重发遗物或历史锚点收益。

最小反例：禁止GUIDED_DREAM/第二人物时，真实record_keeper仍可做两轮record_dependency；禁止record practice时，两人不同回合梦境仍有效。禁止PR05/祭仪主持时，有当前历法能力的记录者可实际做calendar keeping；没有记录者时已有祭仪者可连续两轮主持。禁止已有成功PR05/performed_rite时，真实老师可从本次普通教习起步，学徒后来亲自获得新的超常practiced_rite；禁止教习路时原祭仪者自己当前成功主持仍可扎根。普通教学、两个拷贝、一人被改名两次或同轮两份use均不可替代本表所要求的神迹。

### 9.8 TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design：记忆与契约的六分支（设计待实施）

本节只消费事件§14.12及原PR06/07真实结果，不代造人、登记、过去记忆或履约。CIV03/06/08增加必填basis.route，原稳定rule保持，发行能力目标为`civilization_dependency/schema2/routes3`；此前五蓝本分支/字段不变。原三见证路线的人数、活人门槛及强化传播要求保留在原分支；双人替代用自己的当前两人/两轮条件，不把原三人规则全局改成二人。已有普通记忆/文本、同源复制、同人别名或仅付费均不是下表超常材料。

| profile / route | basis除route,carriers以外精确键 | 真实材料及存续条件 |
| --- | --- | --- |
| CIV03 / memory_circle | memory,review,witnesses,qualifications | 同一真实shared_observation及同一review的三位不同非host原参加者/登记人，各有PR07真实memory_preserved或新route_memory_preserved，全部当前active且资格有效；三原资格不能从不同review/机构拼接。新的CIRCLE在实际审查发生后保护，不跳登记/期限。 |
| CIV03 / memory_practice | session,participants,registrations,uses,dependency | 同一recollection_dependency，恰两位真实原参与者、各自当次实践登记、两个不同实际回合的recollection_use；两人均active、各自仍具原亲历资格并实际持有必要记录。目标结构真实保管这段持续使用的共同回忆，普通共同读取本身不够。 |
| CIV06 / contract_performance | contract,dependency,witnesses；可选successor | 原PR06真实深履约，或新PACT_PERFORMANCE中performance.term严格为preserve_record且原义务为contract_obligation的route_contract_dependency；deliver_record互惠腿不得进入此分支。绑定同一已实际履行条款及两端真实见证/知情。原义务人或按事件§14.13经实际B结果接续的合法继任者仍活，只有选定而未实际接续不授原依赖材料、当前实际保管载体在；关闭原obligation不解除dependency。新六路不依赖继承，未实现继承生产不得当可用备用人物。 |
| CIV06 / contract_reciprocal | covenant,legs,dependency,parties,other_institution | 同一reciprocal_dependency及两条不同index/归一原记录根/真实完成回合的腿，两个实际结构仍有双向links，两位原当事人当前active并实际分别保管自己接收的记录/依赖。任一腿未实际交付、仅浅履约或同一腿复制都不足；canonical原根沿原记录族解析并与covenant.record_roots核对，包装/复制改ID不算两记录；不需要先有单向PR06依赖。 |
| CIV08 / dissent_circle | memory,review,witnesses,qualifications,conflicts | 原三位不同实际见证的同一记忆/本次review资格和实际memory_conflict/route_memory_conflict完整历史；锚点至少原alive_min=2位当前active且资格有效，必要保管载体仍在。不能从一人浅触补冲突/三份历史，不以新双人分支降低这里的历史三人要求。 |
| CIV08 / dissent_practice | session,participants,registrations,uses,dependency | 同一dissent_dependency的两位真实原参加者、intact/broken两种本人实际经历并陈述的视角登记、两个不同成功回合的真实返回use；当前两人都active且各自资格有效，目标结构实际保留不可合并的两份陈述。没有第三人的历史，故不冒充原三人路线；任何一位丧失即失效。 |

ID字段均为真实对象/事实字符串，witnesses/participants为稳定人物顺序，qualifications/conflicts/registrations按对应人物对齐；uses按实际turn再源ID，legs按index，不独立重排并行数组。carrier继续为§9.2真实 `{institution,person,sources}`最小覆盖，来源引用不授知识。三见证分支保留原逐人资格/本地登记范围；两人分支的原参与者在真实活动中实际收到必要公开陈述/登记/结果，目标结构须至少有一位当前属于该槽、确实持有覆盖必要材料的原参与者，另一位可以跨机构但仍须当前真实接触/links及本人亲历资格。不能把全局有这份memory当本结构已经保管，也不能凭材料转交把未参加者变原见证/操作者。

两条记忆实践资格来自实际session→逐人registration→每轮真实use→dependency；归档读取/转述不增加个人经历。旧机构审查不得跨出其原review去撤另外的私人实践登记；反过来，若所选新registration/依赖/超常发生确实被合法撤销，保留私人知识也不能继续满足basis。普通关系/通路断裂使当前跨机构共同活动/需要持续联系的双人依托失格，不删除过去记忆。原三人中的死亡只按该分支原活人门槛处理，不换人补历史。

互惠双方的当前保管/两端实际依赖是额外真实条件，不能由一个共同contract ID或关系边替代。双方后来敌视不自动解除已经履行的神迹依赖；明确release其中一腿、必要record/保管者/链接丧失才按该事实使互惠失格。已完成的另一腿留历史，但deliver_record材料不得借contract_performance分支单独授予CIV06依托；互惠不完整也不能倒写所有义务未履行。契约接续按事件§14.13的当前选定及实际继任结果核验，本批路线不依赖继任，也不发行生前文书。

强化传播仍由同一只读材料判定器：CIV03/memory_circle须原三位当前存活合格，memory_practice须本路两位及两轮真实依赖；CIV08/dissent_circle仍须原三位当前存活合格（锚点两人生存下限不反向降低），dissent_practice须本路两位当前合格及完整两轮。CIV06按本路完整实际依赖/见证/保管，单向严格只收preserve_record，deliver_record须完整两腿，不以普通合作代替契约。两条同时成立不叠收益，普通招募不附加本节材料门槛。

共同污染/真实教团/十二信众/凝聚四十/护持者/可绑定媒介、POWER_ANCHOR费用和检定、实际供奉沿原值。六路的材料生产都不先要求物理锚点/圣物，因此可先形成basis，再经原一次性遗物机会及真实回收取得媒介；不赠圣物/免费激活。路由绑定、换路真实修复和每槽一次机会沿§9.6，换分支或重登记不能重发遗物。父汇总已将civilization_conditions的八蓝本说明/禁令和civilization_profiles的三条路线描述与§9.6–9.8同步；这些是说明列，不是可执行条件或新增规则解析器。原参数只作用于各自分支，消费者必须按route核对应schema；改说明不证明游戏已支持分支。十目标/二十路完整索引及责任见进度§12.4。

可否证验收：禁止双节点复核入口后，一位真实本地成员可由同一例外、两个不同轮真实use形成axiom_archive，完全不需要第二机构；禁止REPEAT后，两个实际节点的不同观察可形成axiom_nodes。禁止NETWORK_EXCHANGE后，两份实际独立梦境仍可成立；禁止GUIDED_DREAM及所有梦境材料后，真实双方往返应答仍可成立。任一测试只是去掉本路生产/材料，不删除共同教团、污染、媒介、锚定或网络物理条件。复制PR12深材料、换record ID、同人改籍、同一use改turn、伪造另一端接收、解锁后失去原links均应被对应分支拒绝。上述需要正式实现后从合法输入经入口检验，本批只审查规则与静态数据。

## 11. 两种模式的祈求来源职责（TASK-PRAYER-DESIGN）

本节是尚待实施的调度修订；替换第10节把后台到期机会视为唯一候选入口的解读，不改变文明详细agency/低频恢复/逐轮风险的原分工。Events的candidate_generation协调者从World/Turn阶段四共同快照被实际调用，focused的detailed_candidates与background的abstract_candidates_due均包含“当前已发布原根索引每轮确定后继”；新当前处境则共用每域原4轮、1次预算与持久游标。F切换不能让两个处理者同轮各领一次，不能只推进游标却不生产。正文规则/机读生产映射见事件§14，CAPABILITY-GUARD须验实际处理者和正式调用，不以同名字符串通过。

人物身份知晓不等于机构收到证据。实际梦谕辨认/指定告知仅改变规定接收者；机构仍沿原职责提交/指定材料递交取得其实际记录。高察觉、官方立场、玩家已发现或聚合信众数都不提供某人的身份知晓或具体证据。cell仍是原招募资格记录、本域无名人口聚合，不生产逐人传播、材料历史或全体居民的知识。

有限初始关系、当前事故/争议/约定、共同读取与见证整理风险、cosmic同位冲突读数由prayer_root_rules及事件§14具体定义；它们是有限当前事件生成，不是完整家庭/社会/宇宙模拟。关系在人物初始构成时产生且不因抽中祈求补写；当前例外只给原观察与本次观察者知情，不能直接提供双节点神迹锚材。八文明实际依托仍只消费原成功结果规定的材料，身份知晓本身不授扎根/传播/抵抗资格。若根族尚未接入，保持missing_producer或未覆盖，不让消费夹具顶替自然生产。

### DEC-024目标承载口径（待设计实施）

锚点只读取目标结构当前合法carriers及实际sources，不能以“教团已知”代替，也不能因教团有人持有就阻止目标接收。MATERIAL-TRANSFER-DESIGN先列知识/保管/实践及不可转移见证的材料族矩阵；ANCHOR-ROUTES按同一矩阵只读重查，MATERIAL-TRANSFER实现同团跨机构递交。原carrier分布已满足时无需集中到一人；迁移、换机构或源失效后重判当前承载。新增回执不复制独立性，迟到取得材料后的basis刷新由实际事务触发，预览不发回执。未落实的具体字段/规则由设计任务冻结，本轮不是运行交付。
