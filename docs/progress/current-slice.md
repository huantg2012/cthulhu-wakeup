# Current Work: TASK-SOCIAL-GRAPH-RELATIONS — Social Graph Relation Lifecycle Integration

更新：2026-10-29。本批关系生命周期限定验收完成，Graph/B父保持进行中；下一项TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit。当前状态以traceability为准。

作者授权的密教方向纠偏已完成原spec/CSV修订，独立QA两轮和code接口审查通过。**密教规则仍为设计交付；PRAYER-KNOWLEDGE已接入Catalog的新表语法，密教消费者尚未兼容，完整游戏尚未按新规则运行。**

普通密教招募的目标设计按教团成立与领袖/成员状态判断资格，再从本域无名非信众池按公式聚合转化；没有多种社会渠道或逐人传播网络模拟。强化播种另查文明媒介。八文明按实际神迹依托扎根，官方认可、在任代表或指定事件不再是普遍许可证。04A空付费选项在机器表退役，04B为真实默认后果；09A只有能带来当前不可接触的真实材料时才开放。分布见证无须先购买合作，材料递交有精确知情回执，不全域授证。

密教设计：[docs/qa/cult-direction.md](../qa/cult-direction.md)。规则在原系统spec，参数仍由CSV单源；新增两张渠道/强化条件表，首团参数和原费用概率未调。具体取舍可供制作人审阅，不冒充作者已逐项体验终审。

本次TASK-CLAIM-ACCURACY已纠正能力描述并落实DEC-021，通过限定文案/规则独立复核；不增加社会网络机制。TASK-PRAYER-DESIGN的规则/接口审查已完成，ORIGINS拆批实施，三批已限定交付且父ORIGINS已逐项汇总，下一项为TASK-SOCIAL-GRAPH-DESIGN。旧报告保留，勘误见docs/qa/claim-accuracy.md。

本次祈求设计：[docs/qa/prayer-design.md](../qa/prayer-design.md)。不认识邪神者可无指向求援，身份知晓与本次定向意愿分别记录；撤关注不遗忘。新增四张规则表和PR08中性标题，原数值未调。新处境保持每域四轮一次，既存原根改为每轮有限检查；无实际行动窗口不固定。同一争议先择一种诉求，不能换包装重复出卡。五项原根实施任务均为待实施；有限事件规则不等于完整过程模拟。具体取样方式与初始关系分配属于可审阅设计提案。

## 当前任务与下游

任务状态唯一来源为docs/implementation/traceability.json。设计先行，数值/经济单线迭代；每项预算1–3小时，超预算开工前拆批。

| 任务 | 内容 | 当前登记 | 前置 |
| --- | --- | --- | --- |
| TASK-SOCIAL-GRAPH-PLAN | 关系网/跨机构规划同步 | 历史规划交付／本轮新静态复核见报告 | 无 |
| TASK-SOCIAL-GRAPH-DESIGN | 有限关系网及跨机构合同 | 历史设计交付／本轮新静态复核见报告 | SOCIAL-GRAPH-PLAN |
| TASK-SOCIAL-GRAPH | Finite Named Social Graph Implementation | 进行中，保留父原4ACC | INITIALIZATION、LIFECYCLE |
| TASK-SOCIAL-GRAPH-INITIALIZATION | Social Graph Generation and Initialization Integration | 本批限定验收完成 | SOCIAL-GRAPH-DESIGN |
| TASK-SOCIAL-GRAPH-LIFECYCLE | Social Graph Lifecycle and Restore Audit | 进行中，原验收保留 | INITIALIZATION、RELATIONS、RESTORE |
| TASK-SOCIAL-GRAPH-RELATIONS | Social Graph Relation Lifecycle Integration | 本批限定验收完成 | INITIALIZATION |
| TASK-SOCIAL-GRAPH-RESTORE | Social Graph Birth Provenance and Strong Restore Audit | 待实施 | RELATIONS |
| TASK-OPPORTUNITY-PLAN | 多路径与机会保障规划同步 | 原规划保留／本轮新静态复核见报告 | 无 |
| TASK-PROGRESSION-ROUTES | Critical Progression Routes and Opportunity Guarantees | 设计汇总已验收／原五项ACC保留 | 原前置及四子批 |
| TASK-OPPORTUNITY-CONTRACT-DESIGN | 共通等待、补偿、实际交付与保存 | 设计交付／本轮新静态复核见报告 | OPPORTUNITY-PLAN |
| TASK-AXIOM-NETWORK-ROUTES | Axiom, Network, and Manifestation Routes | 设计已复核／本轮新静态报告 | 共通合同、SOCIAL-GRAPH-DESIGN |
| TASK-FOUNDATION-ROUTES-DESIGN | First Cult, Isolated Character, Record, and Ritual Route Design | 设计已复核／本轮新静态报告 | 共通合同、SOCIAL-GRAPH-DESIGN |
| TASK-MEMORY-CONTRACT-ROUTES | Memory and Contract Civilization Route Design | 本组设计交付／限定静态验收见报告 | 共通合同、SOCIAL-GRAPH-DESIGN |
| TASK-OPPORTUNITY-SCHEDULER | Critical Opportunity Compensation and Bounded Dispatch Scheduler | 待实施 | PROGRESSION-ROUTES、SOURCE-LOCAL-TIES、SOURCE-LOCAL-CONFLICT、SOURCE-CONTRACT、SOURCE-MEMORY、SOURCE-EXCEPTION、ANCHOR-LIFECYCLE |
| TASK-REPAIR-PLAN | 整改规划与展示台同步 | 规划已交付／证据过期待复核 | 无 |
| TASK-CULT-DIRECTION | 密教传播与扎根规则纠偏 | 设计已交付／证据过期待复核 | REPAIR-PLAN |
| TASK-CLAIM-ACCURACY | 能力表述纠错与执行约束 | 文案已交付／证据过期待复核 | CULT-DIRECTION |
| TASK-PRAYER-DESIGN | 两类祈求与知晓关系 | 设计已交付／证据过期待复核 | CULT-DIRECTION |
| TASK-CULT-SPREAD | Secret Cult Expansion and Propagation Power Integration | 待实施 | CULT-DIRECTION、ANCHOR-ROUTES、MATERIAL-TRANSFER |
| TASK-ANCHOR-ROUTES | Eight Civilization Anchor Route Implementation | 待实施 | CULT-DIRECTION、PROGRESSION-ROUTES、MATERIAL-TRANSFER-DESIGN |
| TASK-ANCHOR-LIFECYCLE | Relic, Anchor Maintenance, Resistance, and Ending Integration | 待实施 | ANCHOR-ROUTES、CULT-SPREAD |
| TASK-PRAYER-KNOWLEDGE | 知晓、联系与求告来源接入 | 已接入／证据过期待复验 | PRAYER-DESIGN |
| TASK-PRAYER-ORIGINS | 详细候选生产与模式交接 | 已接入／证据过期待复验 | PRAYER-KNOWLEDGE、PRAYER-INTEGRATION |
| TASK-PRAYER-DISPATCH | 正式候选调度与模式交接 | 已接入／证据过期待复验 | PRAYER-KNOWLEDGE |
| TASK-PRAYER-PRODUCERS | 既有原根转换与开局准入 | 已接入／证据过期待复验 | PRAYER-DISPATCH |
| TASK-PRAYER-INTEGRATION | 两类求告四格与最小知情集成 | 已接入／证据过期待复验 | PRAYER-PRODUCERS |
| TASK-SOURCE-LOCAL-TIES | Current Incident and Existing Kinship Prayer Sources | 待实施 | PRAYER-ORIGINS、PROGRESSION-ROUTES、SOCIAL-GRAPH |
| TASK-SOURCE-LOCAL-CONFLICT | Current Dispute, Investigation, and Seizure Notice Sources | 待实施 | PRAYER-ORIGINS、PROGRESSION-ROUTES、SOCIAL-GRAPH |
| TASK-SOURCE-CONTRACT | Current Agreement and Obligation Sources | 待实施 | PRAYER-ORIGINS、PROGRESSION-ROUTES、SOCIAL-GRAPH |
| TASK-SOURCE-MEMORY | Shared Experience and Memory Risk Sources | 待实施 | PRAYER-ORIGINS、PROGRESSION-ROUTES、SOCIAL-GRAPH |
| TASK-SOURCE-EXCEPTION | Current Anomaly Observation Sources | 待实施 | PRAYER-ORIGINS、PROGRESSION-ROUTES |
| TASK-SOURCE-CLOSURE | Natural Situation and Critical Progression Source Closure | 待实施 | SOURCE-LOCAL-TIES、SOURCE-LOCAL-CONFLICT、SOURCE-CONTRACT、SOURCE-MEMORY、SOURCE-EXCEPTION、ANCHOR-LIFECYCLE、OPPORTUNITY-SCHEDULER |
| TASK-STARTUP-BALANCE | First Cult Resource and Pacing Balance | 待实施 | SOURCE-CLOSURE、CAPABILITY-PROBES |
| TASK-NATURAL-VERIFY | Correction Chain Independent Verification | 待实施 | SOURCE-CLOSURE、CAPABILITY-PROBES、STARTUP-BALANCE、CULT-SAVE-COMPAT |
| TASK-CAPABILITY-GUARD | Declared Responsibility and Production Wiring Checks | 待实施 | REPAIR-PLAN |
| TASK-CAPABILITY-PROBES | Short Behavioral Probes and Failure Controls | 待实施 | CAPABILITY-GUARD、PRAYER-ORIGINS |
| TASK-CAPABILITY-AUDIT | Completed Responsibility Omission Audit | 待实施 | CAPABILITY-PROBES |
| TASK-FRAMEWORK-LESSONS | General Framework Lessons Integration | 待实施 | CAPABILITY-AUDIT |
| TASK-SAVE-NEGATIVE-CONTROLS | Existing Invalid Save Resigning Controls and Rejection Layer Audit | 待实施 | PRAYER-KNOWLEDGE |
| TASK-CULT-SAVE-COMPAT | Current Rule Version Save Compatibility | 待实施 | CULT-SPREAD、ANCHOR-LIFECYCLE、PRAYER-KNOWLEDGE、SOURCE-CLOSURE、SAVE-NEGATIVE-CONTROLS |
| TASK-MATERIAL-SCOPE-PLAN | 材料目标口径规划同步 | 本轮规划交付 | 无 |
| TASK-MATERIAL-TRANSFER-DESIGN | Material Recipient Scope and Finite Transfer Contract Design | 待设计 | SOCIAL-GRAPH-DESIGN、MATERIAL-SCOPE-PLAN |
| TASK-MATERIAL-TRANSFER | Actual Material Delivery and Recipient Knowledge Receipts | 待实施 | ANCHOR-ROUTES、MATERIAL-TRANSFER-DESIGN、SOCIAL-GRAPH |

新增MATERIAL-TRANSFER和CULT-SAVE-COMPAT各承接材料回执及本次存档版本边界；SPREAD复用ROUTES的共享判定，不能各写一套文明规则。ROOTS同时适配ActionCatalog选源/Session合法知情；退役选项及默认世界后果也须实际接入调度。任务书见[Slice14](../tasks/slice-14.md)。

历史A交付（2026-10-28，当时范围）：ORIGINS开工按实际代码核查后拆成DISPATCH→PRODUCERS→INTEGRATION三批，父任务依赖最后一批并保留全部原验收。DISPATCH已独立通过55行为+5运行检查，原KNOWLEDGE72+5正式回归通过；修复独立来源覆盖、原期限排序、联合审计及无现成教团的首名成员识别。旧BG仍过渡，未代验两类新来源、四格或bootstrap生产。密教实现链仍未完成，完整Session仍拒启。报告：docs/qa/prayer-dispatch.md。本轮B已替换正式四类来源并以新报告重跑A/K，原报告不改。

## 旧证据与实际阻塞

23项已交付旧接线任务回到implemented，保留全部历史报告但其受影响证据标stale；这不等于代码被删除，也不等于新设计已实现。旧UI仍implemented、人工ACC-UI/ACCESS待验。旧840轮策略失败/截尾仍属旧规则，不能重签成新通过。

原ISSUE-CULT-DIRECTION和ISSUE-BALANCE-NATURAL-SOURCES继续阻塞完整平衡。前者设计已纠正、代码仍待修；后者由当前祈求设计明确两类求告、知晓、有限当前原根及生产责任，再由五项根族任务与PRAYER-ORIGINS接入。设计完成也不关闭此阻塞。

各实施task实际跑受影响原专项；TASK-NATURAL-VERIFY汇总当前证据并补缺口，按ACC-DIRECTION-REGRESSIONS恢复原任务，不用自然轨迹替代细项反例。生产闭合后校准首团，再做自然新局及原TASK-BALANCE完整策略。TASK-CONTENT保持内容扩量和叙事理解；视听/发行/真人判断不代勾。

历史B交付：04/05/08/09来源、独立无向08初始化、容量/窗口/保存审计及包装记录事件重开通过56行为+5运行检查，A55+5和K72+5按当前实现回归通过；主会话执行，QA独立只读复核证据。该批后续INTEGRATION已在本轮完成四格与最小投影限定验收，见下方当前C记录。五项新原根、完整新局、自然发展和平衡仍由下游验收。框架与master未改。收尾完成必要追踪/数据/展示一致性检查，按DEC-018创建独立本地提交，不推送。


历史KNOWLEDGE交付（当时范围）：[docs/qa/prayer-knowledge.md](../qa/prayer-knowledge.md)。三类取得由真实行为结果产生，指定告知处理者使用受管理选中前提，call在重试和后来取得知识后保持原意向。Turn schema2保存真实事实范围并核采样/取得位置与实际生成seed；重签负例先有未修改成功对照，拒绝发生在语义审计层。旧BG显式legacy_source，完整候选、自动选源及自然新局仍待ORIGINS。新TASK-SAVE-NEGATIVE-CONTROLS承接旧helper核查，CULT-SAVE-COMPAT依赖该任务；原两个阻塞不关闭。

历史B报告：docs/qa/prayer-producers.md；最终证据为docs/qa/prayer-producers-final-results.json、docs/qa/prayer-producers-knowledge-final-results.json和docs/qa/prayer-producers-dispatch-final-results.json。六种子模块开局的实际浅触可形成一名信徒，不等于成立教团。PR09稳定屏障正例不证明自然频率，冻结来源同批改变会放弃，本项风险由INTEGRATION/NATURAL-VERIFY/STARTUP-BALANCE承接。原两阻塞保留。

当前C：本批41行为+5运行检查，原K72+5/A55+5/B56+5当前正式回归通过，主会话执行、QA独立只读复核。请求线索与完整知情分离，必要关联对象保留有限身份，成员不扩整域；内部证明/终局未来预测隐藏；真实回应/重放、逆序知识重建及外壳schema2边界有证据。原F可在实际深应准入时按空位取得，纯预览和请求本身不授F。报告docs/qa/prayer-integration.md；父任务逐项当前汇总docs/qa/prayer-origins.md及docs/qa/prayer-origins-results.json。五族新原根及密教兼容/整链存档/自然/数值仍后续，两个原阻塞不关闭；下一项TASK-SOCIAL-GRAPH-DESIGN。

## 上轮规划：DEC-022，功能仍待实施

制作人要求关键事件有替代触发，并对必要机会设置概率修正与有限等待兜底。TASK-OPPORTUNITY-PLAN本轮只交付规划；新增TASK-PROGRESSION-ROUTES（设计）→各来源/锚点任务落实路线→TASK-OPPORTUNITY-SCHEDULER（实现）→SOURCE-CLOSURE/NATURAL-VERIFY。DEC-022当时安排ROUTES先锁定关键目标、不同路径和计时/容量/复位合同，CIV07为必验案例；具体路线与数字尚未设计完毕，当前代码没有新保证。

源文档与任务书发生变化，原K/A/B/C及有关设计报告保持历史通过，追踪器按指纹显示过期；相关任务回到implemented，按原任务实际复验后再恢复verified。原两阻塞、五族、整链存档、自然/平衡和真人待验均保留。当前登记以traceability为准，上文C记录描述上轮限定交付。

## 当前优先更新：DEC-023规划

本轮TASK-SOCIAL-GRAPH-PLAN只完成关系网/跨机构修正规划。下一项TASK-SOCIAL-GRAPH-DESIGN先明确有社会依据的有限模型、参数/指标和跨机构消费合同；再接PROGRESSION-ROUTES及SOCIAL-GRAPH实现。旧LOCAL-TIES拆出初始关系责任，仅保留事故/已有亲属源；CONFLICT/MEMORY/CONTRACT接同一图，不再用同机构作为通用前提。完整存档、集成及自然验收均有承接。具体算法/CSV仍待设计，当前代码仍为原关系环，未宣称新功能已运行。上轮OPPORTUNITY-PLAN报告因本轮源文档变化过期，保持历史/implemented；各规划静态复核与行为实际重跑分别恢复。

DEC-024材料口径规划（本轮仅规划）：新增TASK-MATERIAL-TRANSFER-DESIGN，原MATERIAL-TRANSFER按指定接收者/目标结构实现同团跨机构合法转交；不以教团别处持有材料直接拒绝。09A只在真实新端点成立时开放，不能因资源/名额不足重复收费。锚点只读判定、事件编排、完整存档及来源/自然验收分别承接。当前算法/参数/代码未新增，下一项仍SOCIAL-GRAPH-DESIGN；规划过期按各自静态验收复核，旧运行报告不重签。

## 本轮：TASK-SOCIAL-GRAPH-DESIGN（设计与静态验收）

有限关系网和跨机构合同已写入文明§4.1、事件§14.9及两张social CSV；World图生成仍未实现。六人目标7对邻接，按接触背景/职责关切/共同联系人加权，个人上限有差别；参数是本游戏取舍，不是现实社会学拟合。类型/方向、多类型共存、cohort与稳定来源、当前head/历史、局部读取与版本有唯一结算归属。

PR02记录争议到期改为沿原立场结案，不任命或转籍；PR07/EVENT06只作用实际登记且该机构有权处理的本次资格。PR10限定一条此前存在、祈求人未知、对手与争议记录真实作者的关系，防止重复告知旧信息；第三人、EVENT09资格关系/披露与合作结构分别固定。原source任务承接生成/预览/消费/回调/保存/最小线索，非仅删生成端比较。

静态CSV及预算存在性检查不证明正式初始化、固定种子统计、共同读取、祈求出现或自然新局。当前新表未装载，ROOT_INITIAL_TIES改归属使旧Catalog grammar拒载，另有原CULT兼容拒启。图初始化/首次展开和CSV装载归SOCIAL-GRAPH；LOCAL-CONFLICT/MEMORY接完整消费者。完整Session、源闭合和自然验证仍由原任务落实，两个原阻塞保留，旧报告不重签。

下一项：按原静态范围复核过期OPPORTUNITY-PLAN，再做PROGRESSION-ROUTES，定义重要进展的不同触发路径、主动促成与有界等待；特别覆盖既有bootstrap具名者孤立/缺正向关系。图实现可按自身前置接续。材料规划因共享文档变化保持过期，开工材料设计前须新静态复核。

报告：docs/qa/social-graph-design.md。状态唯一来源traceability.json；此段交付状态以独立静态终审与最终任务登记为准。

## 2026-10-29：共享机会合同首批

TASK-OPPORTUNITY-CONTRACT-DESIGN交付事件§14.8、进度§12、两张目标/参数CSV及静态合同分析；不改游戏源码或旧CSV/旧QA。原十目标/至少二十路线父任务超单批，拆成共享合同和三个路线组，父仍in-progress；原代码任务继续等待父完整交付。下一项AXIOM-NETWORK-ROUTES优先CIV07第二节点独立记录，连CIV05/07/终局至少六路线；另两组分别首团/CIV01/02/04及CIV03/06/08。

补偿只解决随机等不到；实际输入/资格、资源、原期限和容量仍有效。FIFO消耗一次派发票，失败保留等待但重试排尾；真正服务须实际可见可行动。38/5/28是有限模型的实例/竞争/B派发界，实际服务L尚须具体路线证明。新两表未装载，既有Catalog根grammar及CULT兼容拒启保留，完整游戏没有新增保证。OPPLAN本轮只新静态复核责任与原历史边界，旧报告不重签；SOCIAL两报告随共享来源变化保持stale。原两个阻塞开放。

报告：docs/qa/opportunity-contract.md。当前状态以traceability为准；本批不推送。

## Axiom, Network, and Manifestation Routes (2026-10-29)

本组设计六条路线：CIV07真实双节点独立复核/单节点不同轮实际档案使用；CIV05两份独立受梦/双端真实应答依赖；终局两实际促成因果为额外非仪式停供锚的实付恢复、或真实创伤REST恢复。已经合格直接开始只是共同入口，不凑第二路线。原三轮/当前两锚/A/费用/检定不变。同一静态A87起点分别可到91/90，不是游戏新局或合法存档运行证据。

事件§14.10、文明§9.6、进度§12.1与三新CSV定义有限活动、费用/失败、封闭对象/准备、知识/carrier/独立性、唯一观测与操作writer/当前头/版本；均design_only。每当前合法单步的direct_action/0是未来安装后的目标合同，不代表全路零轮、自然有界或成功。原ROOT_COSMIC_RECHECK的自然生产也有明确任务，主动替代不掩盖十二类源缺失。

Progression Route Operations拆共享Core、Axiom、Network、Interface Design、Interface Integration五批，全部待实施，原源/锚点/生命周期/调度/完整保存/源闭合/自然各自承接。Critical Progression Routes and Opportunity Guarantees父仍in-progress，另外两组未交付，原代码任务继续等待父完整设计。后续任务名统一英文全称，稳定ID不变。

独立静态设计审查与七项表/任务/条件代数检查见docs/qa/axiom-network-routes.md及对应results。240份既有src/data/历史QA保持；四前置仅以本轮新报告复核当前设计/责任及原提交边界，原报告不重签。Catalog根grammar及CULT安装阻塞、两个原issue保持，未运行正式游戏。

下一项First Cult, Isolated Character, Record, and Ritual Route Design。状态唯一来源traceability.json；最终指纹/展示一致检查后作本地提交，不推送。

## TASK-FOUNDATION-ROUTES-DESIGN — First Cult, Isolated Character, Record, and Ritual Route Design (2026-10-29)

本组八路线设计交付：首团秘密集会/当前祭仪，CIV01独立证言/跨轮记录使用，CIV02不同轮祭仪/超常历法依赖，CIV04原祭仪者承续/实际教习后学徒后来亲自实践。首名成员不等于真实教团；保留六无名信众/八本域实付与实际领袖。新增私祷/共同工作只改变现在，不补旧朋友、职业、身份知晓或材料。

事件§14.11、文明§9.7、进度§12.2及原CSV追加行/新参数共同定义七活动；总路线十四、操作十二、源扩展仍一，全部design_only。两次各成功转三人/付四信仰仅为条件预算，不代表平均两轮成团。私祷为零信仰、一低语且占本人机会，未bound者仍需实际自愿及N/交接；下一真实窗同一prepare用于Endings，旧member/事实不永久续命，原due/冷却/三轮断联不变。bootstrap十五加两普通DREAM仅三十五，不以未来结果凑四十。

新增五待实施任务：TASK-FOUNDATION-CONTACT-OPERATIONS — Present Contact and First Cult Gathering Operations；TASK-FOUNDATION-RECORD-OPERATIONS — Record Practice Operations；TASK-FOUNDATION-RITUAL-OPERATIONS — Calendar and Ritual Practice Operations；TASK-FOUNDATION-INTERFACE-DESIGN — Foundation Route Operation Interface Design；TASK-FOUNDATION-OPERATION-UI — Foundation Route Operation Interface Integration。共享Core按操作准入/新参数/头，原父汇总十二操作；真实材料、关系、人口、知晓、锚点、调度、完整保存/闭合/自然各原writer/task负责。界面设计/接线仍待执行in-game-ux及必要art/U项，未接按钮不算直接交付。

独立设计审查与十项静态数据/实际任务/必要预算检查见docs/qa/foundation-routes.md及新results，不运行游戏。243份既有src/data/历史QA保持；共用CSV只追加，四前置以本轮新静态报告重核当前合同，原报告不改。上一组Axiom设计报告因共享源追加保留过期/implemented，不自动复签运行证据。原Catalog根grammar和CULT安装拒绝、两个原issue保持。

TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees父仍in-progress，保留十目标至少二十路径原验收。下一项TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design。最终核当前来源/展示台在线离线一致后本地提交，不推送。

## TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design (2026-10-29)

本组交付CIV03/06/08六条设计路线：三见证记忆/双人跨轮共同再现；单向具体履约/互惠两腿；原三历史异议/双人视角返回。原分支3资格与CIV08锚至少2活、强化3活分开保留，新双人依赖不冒称PR07资格。原PR06/07是response与容量，新活动逐人机会须显式实现。记录/资格/当前保管、实际履约/危机关闭/依赖解除分别核。

六操作和六参数追加原表，共20路线/18操作/1自然源扩展，全部design_only；原14/12/1字节前缀及259既有src/data/历史QA/四组静态工具保持。十项新静态检查及独立设计审查不执行游戏、真实支付/知识/材料/事务或保存/自然新局，单步direct0不保整路成功/有限完成。

TASK-MEMORY-OPERATIONS — Shared Memory and Dissent Operations、TASK-CONTRACT-OPERATIONS — Agreement and Contract Practice Operations、TASK-MEMORY-CONTRACT-INTERFACE-DESIGN — Memory and Contract Route Interface Design、TASK-MEMORY-CONTRACT-OPERATION-UI — Memory and Contract Route Interface Integration分别接两业务/独立UI设计/接线。Source内核先行不反依Core，Core不借空业务handler称全Session安装，Operations父最终核十八操作全注册。旧继承仅消费无生产另由TASK-CONTRACT-SUCCESSION-DESIGN — Prospective Contract Succession Production Design先冻结合同，SourceContract等设计实际补生产；本组六路不依它。

四前置只以本轮新静态报告复核，旧报告不改；Axiom/Foundation两组设计保留，受共享源改变影响的原证据保持stale/implemented，父汇总再独立复核。旧civilization_conditions.csv描述未涵盖全部新增分支，明确转父逐八蓝本修订，不称当前全表语义同步。原Catalog根grammar/CULT两安装阻塞与两个原issue保持。

下一项TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees独立汇总。父仍in-progress，保留全部原十目标/至少二十路/必要机会原ACC，不能因数量齐备自动完成。报告相对路径docs/qa/memory-contract-routes.md；最终任务台在线/离线一致后本地提交，不推送。

## TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees (2026-10-29)

十目标二十条设计路线完成独立汇总，保留原五ACC。三组当前规则和七前置以新静态报告复核，旧报告/五组旧工具不改；两蓝本CSV只收口八文明的许可描述列，数值/生成/通信/反制不变。三共享表20/18/1全文保持，十八操作均design_only。七新增业务、原终局复用和三组独立UI设计/接线已有实际任务，Core不能靠空成功handler验全安装。

本轮11项新工具静态检查和8项独立设计检查不代表运行或自然新局。direct0只针对未来实际安装后当前合格的一步，B28只到派发，源管线L待实测；不保证输入、全链资金或成功，不延原due/三轮断联。267旧文件保持，原两安装拒绝及两个issue仍开放。

任务共86项：11项已验收，未完成75项（40项待开始、1项进行中、34项已实现但待验收/复验）。下一项TASK-SOCIAL-GRAPH — Finite Named Social Graph Implementation。人读报告docs/qa/progression-routes.md；本轮完成本地提交，不推送。

## TASK-SOCIAL-GRAPH — Finite Named Social Graph Implementation: implementation split (2026-10-29)

开工评估覆盖Catalog、World两入口、唯一关系writer、局部查询及全历史恢复，超1–3小时，按原scope拆两批；父保留四条原ACC，两子过后再独立汇总。本轮执行TASK-SOCIAL-GRAPH-INITIALIZATION — Social Graph Generation and Initialization Integration：正式两CSV/grammar/指纹、同一真实cohort生成与world_start/first_focus、最低一致heads/来源/拒旧，128种子控制样本及实际profile样本分列。现旧关系后果必要窄兼容须保持当前状态一致、去重先于source发行，不能为了留待后续而允许破坏heads。

TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit承接精确终止/新episode、旧消费者完整语义、局部索引/状态通路生命周期、完整出生快照/来源/head语义恢复和正确checksum坏档控制。完整父验收、完整Session保存/自然源仍待后续，不能把控制样本或单子当父完成。原F/N/P/K/人口、事件费用/后果、密教方向及无名聚合招募不改；新图不补旧bootstrap亲友，不自动传播知识/身份/玩家情报。本批无游戏UI变动；可读性/实际祈求自然体验由原SOURCE/NATURAL-VERIFY/相应UI任务验，失败回退图和来源合同核查。

代码由code agent执行、独立QA新工具实跑，主会话整合；正常实现迭代，不开并行数值/经济候选。旧数据与历史报告工具保持，现有八设计以本轮新静态证据复核不重签。工作台开工即同步，收尾本地提交、不推送，并按非verified报告未完成数量。

## TASK-SOCIAL-GRAPH-INITIALIZATION — Social Graph Generation and Initialization Integration (2026-10-29)

本批完成有限具名关系初始化接入与限定行为验收：正式两CSV/内容版本/ROOT grammar，同一生产生成器接World初始及真正首次关注；当前heads/方向/查询与三处旧关系后果必要兼容保持一致。128固定控制样本的正式算法统计与真实World/原profile结果分列；不为祈求回填亲属、关系或知识，初始已展开域refocus不补初态边。

TASK-SOCIAL-GRAPH父仍in-progress，原4ACC不削；下一项TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit验精确终止重建/完整旧消费者/规模局部读取和强历史恢复。原CULT兼容及完整Session/自然来源/两原issue保留；图grammar旧拒载由本批正式Catalog接入修正。八设计前置以新静态报告复核，旧报告工具保持。

当前88任务，已验收12；未完成76：待开始40、进行中2、已实现待验收/复验34。新增2个子任务承接超预算原父，所以本轮完成1子后净增1未完成；不把场景数或stale数当任务数。人读报告docs/qa/social-graph-initialization.md；工作台在线/离线同步后本地提交，不推送。

## TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit: second implementation split (2026-10-29)

开工核对发现出生profile/机构/首次focus凭据不足，不能以两份自报快照互证；完整B估计4–5小时超过原1–3小时预算。保留B与Graph全部原四ACC，拆两子：本轮TASK-SOCIAL-GRAPH-RELATIONS — Social Graph Relation Lifecycle Integration；后续TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit。无新玩法/数值，新增的是可实际验收的工作责任。

RELATIONS接原三关系后果(PR10/EVENT03/EVENT09)组件、PR03深成功的精确追索关系撤销、一次proof/episode、状态通路与当前查询局部性；仅真正的新业务结果能重建新episode，旧proof即使后来命中已有head也一次绑定原episode。退休重复只回原效果，不能撤后来的新head。实时核实际attempt/check和已发行撤销回执，最终prayer_result在提交/恢复后核，不作未来父因果。机构支持行不扩大到全人际support，不新增断交/结交按钮。组件前提与完整响应/自然生产分列。

RESTORE接共享真实初始化配方/seed、真实nomination及focus提交范围、全历史投影双向等值与联合正确checksum坏档；normal只审新增写集/旧根不可改，旧格式明确拒，不静默补过去。完整Session/自然Source/Joint Work/UI仍按原下游；真人可读性/体验不由本批自动门替代，不成立时回到对应图/来源合同核查。

新目录tools/social-graph-relations实际复用A测试函数进行当前回归，旧A工具/报告及所有CSV保持。八设计另新静态复核；不能重签旧行为报告，也不能静态刷新A当当前代码已通过。代码由code、独立QA实跑，主会话整合；数值/经济不并行候选。完成后同步在线/离线工作台、按非verified报数量并本地提交，不推送。

## TASK-SOCIAL-GRAPH-RELATIONS — Social Graph Relation Lifecycle Integration: limited acceptance (2026-10-29)

本批现有PR03深成功精确撤销、业务proof一次消费/重复旧效果、原三关系后果与当前局部查询通过限定组件验收。测试明确区分受管理外层来源前提与真正由handler产生的关系/撤销回执；没有宣称完整祈求、完整事件或自然生产。实际失踪/拘禁/迁移/死亡保历史与当前资格；机构/通路检查是当前状态前提，不称新机构行为模拟。

新工具实际重跑初始化50项（48继承、2项writer前提随当前proof合同适配，原断言保留），不修改旧工具或旧报告；八设计另独立静态复核。World格式3拒旧World2，不补过去凭据；Graph1/CSV/数值/算法保持。B1仅必要proof与精确退休保存，完整出生/投影联合坏档由TASK-SOCIAL-GRAPH-RESTORE — Social Graph Birth Provenance and Strong Restore Audit继续。两个父原ACC保持、原两issue与CULT/完整Session/Source/自然/平衡和真人待验不关闭。

当前90任务，已验收13；未完成77：待开始40、进行中3、已实现待验收/复验34。原B超预算新增两子，本轮完成一子，未完成比上轮净增1。报告docs/qa/social-graph-relations.md；工作台在线/离线同步，本地提交不推送。GDD/roadmap由Director在Slice汇总，当前任务状态由本表和traceability/工作台呈现。
