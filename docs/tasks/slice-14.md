# Slice 14 — Lightweight Simulation and Correction Tasks

更新：2026-10-30，制作人DEC-026。当前任务状态与依赖唯一见 `docs/implementation/traceability.json`。

## 本轮交付：TASK-ANCHOR-PRODUCTION-CLOSURE — Eight Civilization Material Production and Active Anchor Closure（2026-10-30）

原TASK-SOURCE-CLOSURE预检超过单批预算，新增一个完整业务子项，承接原ACC-ANCHOR-ROUTE-CLOSURE六断言不改。目标是16条已有路线各由真实材料生产，经过原承载/必要递交、当前依据、首次圣物、建立/修复及实付供奉达到active；各文明另一条独有生产/材料实际受阻时仍成立，不能只是不使用另一条。calendar_keeping与dissent_practice必须实际跑。初始合法人物/职责/教团/资源、成功RNG可控并明示，不注入待证明的目标产物。原材料独立性、人数/亲历/知识/跨轮/契约两腿及当前载体不降低。

Code仅做必要整链修错及六组有限业务工具；复用现有11模块和共同尾段，不新建背景/凭据系统、不调数值或改UI。每个短组按实际成本限制，反例并入相应组，只有直接受影响回归，不跑笛卡尔矩阵。两连续非预期机器失败停原实现者，保失败并独立接手；运行输入与事后文档绑定分开，主QA冻结后实际证据绑定，独立QA最后核。Design管规则/追踪/工作台；Code管源码/工具/实际JSON和技术架构说明；QA独立出当前适用性报告。

repair-04最终16条原路线、六业务组（记忆/异议拆成四次短调用）、解析/启动通过，274.933秒、112运行输入无漂移，无引擎错误。三处必要修复：历史材料装载遗漏、各人必要持有项被最小覆盖省略、契约对端见证覆盖本人索引。互惠工具改走已有付费EVENT_12/B以合法重开一次窗口，不补成员/材料或改费用；原五次非预期失败及一次预期诊断保留，未扩测试矩阵。报告docs/qa/anchor-production-closure.md；独立当前复核及正式验收状态以traceability为准。

原父TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure仍planned，保其余来源、首团/终局恢复与联系窗口；本轮为十一模块Turn/Service受控整链，不冒自然整局、完整Session保存或人工体验。验收登记后总80、已验收35、未完成45：待开始8、进行中1（TASK-BALANCE）、已实现待复验36，锁定2。新增1项并完成1项，未完成净数仍45；父项未完成。本轮不自动开下一项，不推送。

## 本轮交付：TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler（2026-10-30）

原task内完成，无新增子项。真实最多11个B来源族按[domain,root]补偿/FIFO，notice同等；原A记录及20 direct不重复占B权重。保原族权重、漏选增权1、阈值2、成功后隔一槽；无写失格保票同槽继续，唯一真实产出即停。原tick/schema2/version4回放核实际源/票/随机状态，七Sources原scene_rule/need绑定补齐；B生产不清direct服务债。当前I4/M2/Q≤11仅有条件B提交52轮界，不宣称不存在的行动管线L或胜利保证。原费用、材料、期限、人口、固定池及展示均保留。

repair-01四核心、原Service四组单一影响回归、解析/启动与隔离FIFO负控19.559秒通过；113输入无漂移，无引擎错误。真实Session当前契约→PR06固定→第三轮actions原浅回应查询合法，未实际回应；11族最坏界为纯政策受控对照，失格X/真实Y的提名为回滚事务前提。两次原失败与独立接手修复保留；独立34ACC/110断言当前适用性另列，旧33不重跑/重签。报告docs/qa/opportunity-scheduler.md；最终验收状态以traceability为准。

验收登记后总79、已验收34、未完成45：待开始8、进行中1（TASK-BALANCE）、已实现待复验36，含锁定2。本轮只完成1项、没有新增task。下一项TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure；完整自然/全部路线实付active、成熟Session保存及首团节奏仍原后继，两原整链issue保持。本轮不自动开下一项，不推送。

## 本轮交付：TASK-OPPORTUNITY-SERVICE — Critical Goal Planning and Action Opportunity Service（2026-10-30）

共享查询之后只新增一个真实缺口/direct服务子项。十目标按原进度/basis/共同尾段接已安装入口，Turn管理同一本原knowledge，Session只读；真实完整actions窗口/实际合法提交才服务明确step，不把prepare/fix/offer当下游结果。18操作implemented、10goal/20route coordinated；只读policy/window，B四参数未生效、数值未变。无新玩家动作/布局或背景过程。

formal-03四新核心、四原eligibility代表、解析/实际启动及隔离单guard行为负控通过，18.738秒/112输入无漂移/无引擎ERROR。正式Session真实PR08与同id重放/正常至T2/actions；实际组织缺口、跨轮basis、首观察/同异常第二节点消费者、互惠首腿后第二腿规划分开登记。终局仅纯摘要对照，不当完整胜利。formal-01真实planner/旧头索引失败及明确知识夹具限度保留；formal-02先前成功，最终因terminal完成投影遗漏做最小修复后补验03。独立33ACC当前适用性另列，不重签旧实际报告或跑旧大矩阵。

报告docs/qa/opportunity-service.md；当前验收状态以traceability为准。新增1与完成1分别计数，登记后总79/已验收33/未完成46，原父TASK-OPPORTUNITY-SCHEDULER仍planned且负责实际B概率补偿/FIFO；SourceClosure/完整Save/自然/人工体验继续原后继。本轮不自动开下一项。

以下为历史交付与当时数量。

## 当前实施：TASK-OPPORTUNITY-ELIGIBILITY — Shared Opportunity Eligibility and Player Knowledge Projection（2026-10-30）

Scheduler预检的完整共享知情/十目标step/B公平合批超1–3h，新增一个真实前置先抽取原Session/Catalog知情/选项/资格与原Turn准入。PlayerKnowledge保原账本，EntrySelectors只解析当前有限选项，OpportunityEligibility规范给定入口并用原handle/prepare+Attention，ActionAdmission由真实Turn支付/World人物标记与入口查询共用；不复制业务规则、世界知情或授权层。无新动作/布局/风格。

最终finish-02四组核心、Godot解析/启动6.235秒通过，87运行输入无漂移且无引擎ERROR。正式11模块新局、实际PR08回应、正常至T2/actions与原Record Practice的当前人物机会拒绝有代表结果；空账本/未展示请求、未知人物/来源、纯读、账本重复/原保存形状重建分别核验。DREAM/PR06别名仅静态解析复核，rest为与原无创伤拒绝一致、plan为原命令分类/校验，不冒称全部分支各自执行。

两原失败保留；第二次是夹具deepcopy解封历史根，独立T1保封存根最小修复而不让生产吞Nil，补cursor完成防伪通过。repair-01先前PASS保留，未知来源先被人物拒绝的覆盖局限经同组准确来源字段控制后补验，未扩矩阵。独立32ACC当前适用性另列docs/qa/opportunity-eligibility-current-review-results.json，正式状态以traceability为准。

本轮新增一个前置，原TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler仍planned。等待补偿/十目标next-step/真实actions服务/FIFO/管线L没有由本项实现；完整SessionSave/自然路线/人工UI继续原任务。新增与完成分别登记，不把拆批当原Scheduler完成。报告docs/qa/opportunity-eligibility.md。

以下为历史交付与当时数量。

## 当前实施：TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration（2026-10-30）

十八ID仅约六类共用处理/原能力别名；正式十一模块Session接当前上下文入口。无团集会/祭仪按原六人八支出成团；观察/跨轮实践、原学徒后续施行、PR07/PR06一次准备后原回应、互惠两腿的材料生产与selector/共享资格同批接入。Private Devotion和Endings沿同一prepare/Attention核已有存活人物，不以成员/当前F预筛。

两次原实现失败后已按规则独立T1修复，最终presentation-02四组核心/解析/启动38.368秒通过，101输入无漂移且无ERROR；学生实际后续施行、互惠两腿与实际Session到T3/actions有结果。完整路线/目标协调/source索引仍design_only；calendar_keeping/dissent_practice仅静态共享映射复核，未逐臂运行。原详情现显示实践/互惠条款与进度，并给具体中文拒绝原因，未换布局风格。独立当前适用性复核另列于docs/qa/progression-operations-current-review-results.json，旧报告不重签；最终任务状态以traceability.json为准。

机会保障、八文明逐路线实付active/自然整链、完整Session续存继续既定Scheduler/SourceClosure/Save任务；未新增task或解锁ART/RELEASE。详细控制前提、原始失败及实际结果见docs/qa/progression-operations.md。

## 当前交付：TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration（2026-10-30）

代表性正式双梦境/实际递交→依据→首次机会/圣物→建立/实付active已限定验收；机会永久唯一、类型/期限与消费来源固定，供奉、失能/恢复、解绑与原序号修复分开核。抵抗不因秘密basis补知识，原真实联系/当前降临消费者保持；未来新入口不装占位。完整Session续存与全部八文明生产到active仍原后继。

生产代码仅修Anchors首次发现/机会恢复、Relics教团库藏与Events回收容量预览；维护和契约关闭的既有语义未改。4本轮+4秘密传播回归+解析/启动18.519秒，99输入无漂移、无引擎ERROR；2次夹具失败保留，按规则独立T1接管后通过。独立30项当前复核与原始结果见docs/qa/anchor-lifecycle.md，不重签旧报告或扩旧大矩阵。

总77、已验收30、未完成47（待开始10、进行中1、已实现待复验36，含锁定2）；本轮仅完成1项。下一项TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration，沿制作人浅模拟与少量测试约束；当前不自动开工。以下为上轮交付与原依赖安排。

## 上轮交付：TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration（2026-10-30）

复用材料共同核与八文明共享消费者，完成已有教团聚合秘密招募/强化传播、04A退役与04B默认、09A固定新增端点的原费用/敌意/察觉及实际接收→依据刷新。PlayerSources实际消费schema2渠道和材料；正式十模块Session安装/bootstrap、真实浅回应、GameRoot及正常完整一轮已验证。原人物、人口、资源规则不变，不新增社会传播过程。

最终四组本轮、四材料、四锚点及原17来源核心、解析/菜单均通过；97运行输入无漂移、35.314秒、无引擎ERROR。五次失败保留，修复事实和夹具分开记录；旧28项当前适用性另独立复核，不重签旧结果。报告docs/qa/cult-spread.md。总77、已验收29、未完成48（待开始11、进行中1、已实现待复验36，含锁定2），本轮只完成1项。

下一项TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration。首团入口、替代路线、机会保障、整链与完整Session续存仍由原后继验收；有限启动和推进不能代验。以下为当时的历史交付与依赖规划。

## 上轮交付：TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts（2026-10-30）

按事件§13.2实现已有同团联系上的单份转交及共同接收核，固定原材料、两人、目标机构和取得层次；沿0信仰/1低语基线与已有Attention/Turn事务，不模拟通信过程。保原独立见证/实践/契约身份；未来路线材料缺生产者仍拒绝。既有经营页接原选择/预览/执行控件，完整Session新局、09A整笔编排与完整续存仍归后继。

限定验收完成：8类现有材料解析、12类未来路线明确未实现、4类对象拒绝普通转交；09A只登记core_only。合法包装告知统一原记录身份并保留原包装的准确知情；不复制见证或保管资格。材料4组、锚点4组及原17来源核心、解析/菜单通过，107执行输入运行期间未变，共28.784秒且无引擎ERROR。原实现者2次界面夹具失败后停止，独立接管的1次事务夹具失败与最终成功均保留。关系网5项按原证据及当前差异复核，不重跑大矩阵；组件夹具不称完整新局。报告docs/qa/material-transfer.md。当前总77、已验收28、未完成49（待开始12、进行中1、已实现待复验36，含锁定2）；55→49=本项1+旧关系网前置复核5。下一项TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration，实际接秘密来源、09A及正式Session新局。

## 上轮交付：TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation（2026-10-30）

共享只读资格、当前basis与合法知情选源限定验收完成；16分支消费规则、8原材料raw适配，8替代生产/raw适配仍缺失并明确missing_producer。正式事务发布前重判，传播可用材料不必先形成锚定basis。原实际05B继任、外层/底层当前性、跨机构原持有者及CIV08历史3/锚定活2/传播活3边界已纠正。未改数值，不扩社会过程。

4组定向行为+原17来源核心、窄解析和菜单共23.973秒；独立QA核86执行输入指纹与原始结果通过。7旧设计前置按当前合同另复核，不重签旧运行报告。完整active路线仍归原ACC-ANCHOR-ROUTE-CLOSURE；首次遗物、供奉、替代生产、完整Session及自然体验未由本项代验。报告docs/qa/anchor-routes.md。

当前77任务，已验收22、未完成55（待开始13/进行中1/已实现待复验41，含锁定2）。本轮减少8=本项交付1+旧设计复核7。下一项TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts；本轮不自动启动。

## 当前执行顺序：材料、传播与扎根依赖澄清（2026-10-30）

本节是2026-10-30上一轮依赖规划，当时只调整计划；后续实施状态见下方当前交付与traceability，不将模块检查计成整条路线通过。下方既有交付段落是其当时范围；本节与traceability记录当前后继顺序。

| 顺序与Task | 本项交付边界 | 后续验收归属 |
| --- | --- | --- |
| 1. TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation | 八文明共享只读资格、当前basis、原承载/实践身份、创建/修复的条件与已知来源投影；提供材料变化后重判入口 | 只读规则的合法输入用例不证明材料已经生产。全路线生成到实付active交SOURCE-CLOSURE |
| 2. TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts | 内部单份转交、共同接收核、知识/保管区别、原子费用与basis刷新；不复制原见证/实践资格 | 09A实际事件费用与后果由CULT-SPREAD验；新增路线材料解析器由OPERATIONS接实际生产者时补齐并复验共同核 |
| 3. TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration | 已有教团普通秘密扩张、共享资格下的强化传播、04/09A编排、PlayerSources新来源接线；正式Session安装、bootstrap及首个行动窗口 | 首团前的组织路线由OPERATIONS生产；启动通过不等于首团或自然发展已通过 |
| 4. TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration | 新依据对应的首次遗物、建立/修复尾段、供奉/失效/恢复、抵抗知情与终局通用读取 | 新Private Devotion等入口尚不存在时不冒充可联系；OPERATIONS接入同一实际prepare并补验，SOURCE-CLOSURE验整链 |
| 5. TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration | 按DEC-026收口轻量数据并实际生产十目标的替代路径；互惠两腿调用已完成的材料核；首团入口在无既有教团时可用 | 同步新增材料selector与共享资格消费；保留全路线的独立整合验收，不用新活动名称或空handler充数 |
| 6. TASK-OPPORTUNITY-ELIGIBILITY — Shared Opportunity Eligibility and Player Knowledge Projection | 原知情/选项与当前给定入口的共享纯查询，真实Session/Catalog与Turn准入单实现 | 不包含等待/队列/服务；给后续协调者复用原知情与prepare/Attention |
| 7. TASK-OPPORTUNITY-SERVICE — Critical Goal Planning and Action Opportunity Service | 同一本受管理玩家知情、十目标当前缺口与真实direct行动窗服务、必要等待/幂等/组件恢复 | 不制造B卡；B概率补偿/FIFO仍父任务，完整路线与成熟Save分开验 |
| 8. TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler | 对已安装的实际生产/行动入口提供补偿、有限等待及可行动服务回执 | 缺生产者报安装/接线缺口；不以概率兜底代造材料或成功 |
| 9. TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure | 五族来源、首团、八文明两路与终局恢复的正式整链；承接ACC-ANCHOR-ROUTE-CLOSURE | 组件保存只证明本模块状态；完整Session存档继续归SAVE，发生率/平衡/自然体验归既有后继 |
| 10. TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility | 完整当前Session保存继续、机会等待/材料/期限/一次结果、拒旧及保护原文件 | 不再承担第一次解除新局安装阻塞；后续NATURAL-VERIFY等待本项及原首团平衡等前置 |

实施硬依赖为前述链；原设计、社会图和五族来源的必要前置继续保留。OPERATIONS明确新增MATERIAL-TRANSFER、CULT-SPREAD和ANCHOR-LIFECYCLE前置；不把它反向加到ANCHOR-ROUTES形成循环。已有设计证据过期时先做当前范围复核，不通过批量改状态或重签旧运行报告放行，也不默认重跑全部历史任务。

**验收保留及移交**：原ACC-ANCHOR-ROUTES中CIV05/07、CIV01/02/04、CIV03/06/08“禁用一路独有生产后，另一条仍可实际建立active锚点”的要求，逐字保留在新ACC-ANCHOR-ROUTE-CLOSURE，由既有SOURCE-CLOSURE承担。路径必须经过正式生产→实际承载/必要转交→当前依据→首次遗物→建立/修复→实付后active；不能手填其中待证明的产物。ANCHOR前段继续验各蓝本判定正反例、预览纯读、材料独立性、当前人物/保管与分支差异，但不得称八文明玩法路线全通。

**三处容易反依赖的边界**：普通内部转交不制造互惠履行；首团前组织入口不以已有cult/cell为前提，最终成团仍走原Cults规则；新联系入口实现时由OPERATIONS补接Endings，成员身份/机会债不替代实际下一行动窗口。

**原规划定位与当前解除**：PlayerSources曾明确拒绝尚未消费的schema2来源，并非已证明Cults.install失败。TASK-CULT-SPREAD已通过实际来源消费、完整模块安装/bootstrap及一轮推进解除该有限启动缺口；未删校验、跳模块或装空handler。完整发展和保存仍以各后继任务实际验证为准。

每项复用少量直接相关检查；整合验收按真实玩法分支组织有限用例，不铺人物/机构/存档组合矩阵。规划没有恢复旧18活动或28个已撤销细分，也不解锁视听/发布。

## 当前批次：Core Capability Checks（2026-10-30）

按制作人本轮授权顺序完成三项，分别验收、更新工作台及本地提交：

1. TASK-CAPABILITY-GUARD — Declared Responsibility and Production Wiring Checks：首批仅候选生成职责。核正式调度共用的阶段、唯一所有者、两模式及原根处理者绑定；缺失、错指向、重复归属明确拒绝。合法无候选是正常结果，不要求每轮产生祈求。
2. TASK-CAPABILITY-PROBES — Short Behavioral Probes and Failure Controls：复用原组件夹具，2–4组短行为核正式生成、可回应与实际结果，以及缺处理者、空实现和模式交接。目标不超过60秒，不另建测试框架。
3. TASK-CAPABILITY-AUDIT — Core Capability Omission Audit：限定对照候选生产/调度/回应及已知09A缺口，逐项记录接线、结果证据或实际修复责任，不扩大为全项目能力证明。

旧验收把 detailed_candidates 写作“当前缺失”已过时：Events已有正式模式/原根绑定，World阶段四和Dispatch实际使用它们。本批验收改为人为删除或错接时必须识别，空实现由行为探针识别。

工具必须能够检查尚未完成的功能。PROBES的执行前置为GUARD及轻量策略；ORIGINS保留为实际接口/历史证据来源，原全范围验收仍由原任务负责，不要求整条旧功能链先变绿才允许建立探针。实际组件装配失败仍须报告，不得安装虚假能力或绕过完整Session的CULT拒启。

原整改规划只复核方向/责任/依赖与历史交付边界，不将当时“源码不变、修复待实施”误套为永久禁止后续实施。09A的open_route修复继续归TASK-CULT-SPREAD；本批发现缺口不代替该修复。

前述材料设计、轻量来源与关系网设计规则保持其各自范围。若共享代码增加检查，复用已有17组来源核心作一次受影响复验；后续仅新增工具时不重复跑，也不把该结果作为完整Session/自然新局通过。

## 当前交付：TASK-SIMULATION-STRATEGY — Lightweight Simulation Strategy and Scope Revision

- 目标：把普通背景改为少量条件下的加权抽签，持续状态只保留玩家决策和后续结果需要的部分。
- 责任：Design更新原规则与计划，Code仅同步架构目标；不做游戏代码/数值/界面修改，不继续旧精细测试。
- 必读：`docs/world.md`、`docs/specs/system-events.md` §14.5、`docs/implementation/README.md`、DEC-026。
- 验收：来源/后果区别明确；撤销过细拆分并接回真实父任务；工作台显示新状态；不把设计或合并任务记成运行完成。

## 下一组：五个来源任务

开工前置为本轮轻量策略。已有基础代码的必要调度/知识/准入接口由各父任务按实际需要短验，不要求先让旧全量矩阵重新变绿，也不把这些短验当成旧任务全范围通过。

| Task | 最小范围 | 主要验收 |
| --- | --- | --- |
| TASK-SOURCE-LOCAL-TIES — Current Incident and Kinship Prayer Sources | 抽出求援情境，接PR01回应/期限；替换未验收事故WIP | 正式生成可回应请求；后果/保存/一次消费；无职业→事故→通知链 |
| TASK-SOURCE-LOCAL-CONFLICT — Current Dispute, Investigation, and Seizure Notice Sources | 抽出争议、追查、秘密；圣物索回沿实际实例 | 原争议去重、实际后果与已有事实不冲突 |
| TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources | 一次绑定共同见闻、人数与本次资格 | 浅深资格差异、不全域删记忆、实际材料 |
| TASK-SOURCE-EXCEPTION — Current Anomaly Observation Sources | 抽出发现/独立第二观察 | 同异常独立记录与复制明确区分 |
| TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources | 一次确定约定/条款，接履约/依赖/轻量继任 | 实际履约/解除、原期限、非文书模拟 |

共同流程：正式读取少量条件→抽取情境→检查矛盾/容量/窗口→固定一次→回应或到期。共用已有生成/结算入口，字段/规则/内容CSV随父任务同步；旧CSV枚举不是继续实现微观链的理由。每族先列2–4个可观察结论，再做最小实现与受影响短检查；只有共享接口风险需要才跑完整回归。可控制随机数检验正式生产，不搜索数百种子作为日常开发方式。

测试只保小型共享核心集与本次改动的2–4个代表用例，普通批次目标≤60秒。重点是回合/资源、正式生成与回应、期限/一次结果和保存继续；不逐族铺组合矩阵、联合重签/历史规模测试，不新建专用运行器或授权账本。实际Bug补最小回归例，罕见事件控制抽签验证。

## 当前后继：TASK-MATERIAL-TRANSFER-DESIGN — Material Recipient Scope and Finite Transfer Contract Design

五族轻量来源各自短例完成后，本项先冻结目标接收设计，再接原材料/锚点实现。原三个规划/设计前置按DEC-026当前口径做限定复核，不把旧作者/共同读取等微观流程恢复为前提，不把设计复核冒充图或新局运行。

设计交付归事件§13.2，文明§9只读消费，既有ui-interaction只补结构；三张material_transfer表全design_only。内部转交由现有Cults action调用World共同核，一次一份/两人，不设通信系统；09A只在新端点增量时付原费，不叠内部成本。24行矩阵分别定义知识/保管与不可转移原资格，schema2保存当时目标和取得层次。

- TASK-MATERIAL-TRANSFER — Actual Material Delivery and Recipient Knowledge Receipts：装载有限表、个人递交/预览/准入/唯一支付回执/迟到basis及保存，接既有Session/ActionCatalog最小已知入口。
- TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration：修当前缺失的open_route处理分支，按固定材料/接收者/目标增量接09A及原费用后果。
- TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation：消费同一矩阵的当前真实carrier及原参加者条件；副本不代替观察/实践或互惠两腿。
- 新路线业务归PROGRESSION-OPERATIONS；当前Session安装/新局首窗归CULT-SPREAD，完整Session保存继续归CULT-SAVE-COMPAT；准确顺序及整链验收见本文件顶部，不以本设计算实现。

验收只列四组设计正反例/静态合同检查；后续实现也按四组代表行为守核心，不铺24族乘人物/文明矩阵。新表未接入Catalog，旧运行输入保持；原17组仅作历史基线，兼容复核须明确未重跑，不能替代新递交运行。

## 关键进展、保存与后续

`TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration`统一承接原Core、七业务操作及三组UI设计/接线：保十目标的不同触发/主动促成路线，优先用现有权能、策略及情境抽签，不默认开发十八套新活动或三套复杂界面。需要界面变化时仍须先执行in-game-ux skill、载体/具名参考及必要Art检查。原操作表仍design_only，须先收口数据再安装。

`TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler`保必要机会的概率修正与实际可行动窗口。随机未命中与没有生产者分开，不能恢复微观背景门槛后让流程永远卡住。

`TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility`合并原保存负例任务，只保重要状态、已抽结果、期限、一次消费和代表性版本/损坏控制，不做全仓库联合重签审计。

材料、密教、锚点、能力防漏、首团平衡及自然验证按原真实父任务继续，并受DEC-026约束。原两个实际阻塞保留。完整新局/玩家体验未因此通过。

## 撤销细分，合回父任务（不是完成）

下列28个实施切片从活跃任务清单移除，其必要玩法仍由实际父任务承接。其旧代码/报告/失败与诊断记录保留；不再以旧微观验收为必须实现的目标。没有把这些任务标为verified。

| Retired Task ID | Active Parent |
| --- | --- |
| TASK-SOURCE-LOCAL-TIES-INCIDENT | TASK-SOURCE-LOCAL-TIES |
| TASK-SOURCE-LOCAL-TIES-PRAYER | TASK-SOURCE-LOCAL-TIES |
| TASK-SOURCE-MEMORY-READING | TASK-SOURCE-MEMORY |
| TASK-SOURCE-MEMORY-REVIEW | TASK-SOURCE-MEMORY |
| TASK-SOURCE-MEMORY-CONSUMERS | TASK-SOURCE-MEMORY |
| TASK-SOURCE-LOCAL-CONFLICT-DISPUTE | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-LOCAL-CONFLICT-DISCLOSURE | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-LOCAL-CONFLICT-PURSUIT | TASK-SOURCE-LOCAL-CONFLICT |
| TASK-SOURCE-EXCEPTION-OBSERVATION | TASK-SOURCE-EXCEPTION |
| TASK-SOURCE-EXCEPTION-PRAYER | TASK-SOURCE-EXCEPTION |
| TASK-SOURCE-CONTRACT-AGREEMENT | TASK-SOURCE-CONTRACT |
| TASK-SOURCE-CONTRACT-PERFORMANCE | TASK-SOURCE-CONTRACT |
| TASK-SOURCE-CONTRACT-SUCCESSION | TASK-SOURCE-CONTRACT |
| TASK-PROGRESSION-OPERATION-CORE | TASK-PROGRESSION-OPERATIONS |
| TASK-AXIOM-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-NETWORK-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-PROGRESSION-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-PROGRESSION-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-CONTACT-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-RECORD-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-RITUAL-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-FOUNDATION-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-CONTRACT-OPERATIONS | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-CONTRACT-INTERFACE-DESIGN | TASK-PROGRESSION-OPERATIONS |
| TASK-MEMORY-CONTRACT-OPERATION-UI | TASK-PROGRESSION-OPERATIONS |
| TASK-SAVE-NEGATIVE-CONTROLS | TASK-CULT-SAVE-COMPAT |

原细化方案的完整历史由Git保留（上一规划提交 `0b79cb3`）。当前未验收事故代码暂存于工作区，等待轻量替换；原执行者两次失败停止与新owner首轮诊断都保留，剩余执行预算已撤销。
