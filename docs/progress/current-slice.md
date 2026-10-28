# 当前工作 · INTEGRATION与父ORIGINS限定交付

更新：2026-10-28。作者授权的密教方向纠偏已完成原spec/CSV修订，独立QA两轮和code接口审查通过。**密教规则仍为设计交付；PRAYER-KNOWLEDGE已接入Catalog的新表语法，密教消费者尚未兼容，完整游戏尚未按新规则运行。**

普通密教招募的目标设计按教团成立与领袖/成员状态判断资格，再从本域无名非信众池按公式聚合转化；没有多种社会渠道或逐人传播网络模拟。强化播种另查文明媒介。八文明按实际神迹依托扎根，官方认可、在任代表或指定事件不再是普遍许可证。04A空付费选项在机器表退役，04B为真实默认后果；09A只有能带来当前不可接触的真实材料时才开放。分布见证无须先购买合作，材料递交有精确知情回执，不全域授证。

密教设计：[docs/qa/cult-direction.md](../qa/cult-direction.md)。规则在原系统spec，参数仍由CSV单源；新增两张渠道/强化条件表，首团参数和原费用概率未调。具体取舍可供制作人审阅，不冒充作者已逐项体验终审。

本次TASK-CLAIM-ACCURACY已纠正能力描述并落实DEC-021，通过限定文案/规则独立复核；不增加社会网络机制。TASK-PRAYER-DESIGN的规则/接口审查已完成，ORIGINS拆批实施，三批已限定交付且父ORIGINS已逐项汇总，下一项为TASK-SOURCE-LOCAL-TIES。旧报告保留，勘误见docs/qa/claim-accuracy.md。

本次祈求设计：[docs/qa/prayer-design.md](../qa/prayer-design.md)。不认识邪神者可无指向求援，身份知晓与本次定向意愿分别记录；撤关注不遗忘。新增四张规则表和PR08中性标题，原数值未调。新处境保持每域四轮一次，既存原根改为每轮有限检查；无实际行动窗口不固定。同一争议先择一种诉求，不能换包装重复出卡。五项原根实施任务均为待实施；有限事件规则不等于完整过程模拟。具体取样方式与初始关系分配属于可审阅设计提案。

## 当前任务与下游

任务状态唯一来源为docs/implementation/traceability.json。设计先行，数值/经济单线迭代；每项预算1–3小时，超预算开工前拆批。

| 任务 | 内容 | 当前登记 | 前置 |
| --- | --- | --- | --- |
| TASK-REPAIR-PLAN | 整改规划与展示台同步 | 规划已完成 | 无 |
| TASK-CULT-DIRECTION | 密教传播与扎根规则纠偏 | 设计审查通过 | REPAIR-PLAN |
| TASK-CLAIM-ACCURACY | 能力表述纠错与执行约束 | 本次文案复核通过 | CULT-DIRECTION |
| TASK-PRAYER-DESIGN | 两类祈求与知晓关系 | 设计交付，实施沿下列任务 | CULT-DIRECTION |
| TASK-CULT-SPREAD | 秘密扩张与传播权能接入 | 待实施 | CULT-DIRECTION、ANCHOR-ROUTES、MATERIAL-TRANSFER |
| TASK-ANCHOR-ROUTES | 八文明扎根条件实现 | 待实施 | CULT-DIRECTION |
| TASK-ANCHOR-LIFECYCLE | 圣物、维持、抵抗与终局衔接 | 待实施 | ANCHOR-ROUTES、CULT-SPREAD |
| TASK-PRAYER-KNOWLEDGE | 知晓、联系与求告来源接入 | 限定验收通过 | PRAYER-DESIGN |
| TASK-PRAYER-ORIGINS | 详细候选生产与模式交接 | 三批当前证据汇总通过 | PRAYER-KNOWLEDGE、PRAYER-INTEGRATION |
| TASK-PRAYER-DISPATCH | 正式调度、共享机会与指定告知 | 限定验收通过 | PRAYER-KNOWLEDGE |
| TASK-PRAYER-PRODUCERS | 既有原根转换与开局准入 | 限定验收通过 | PRAYER-DISPATCH |
| TASK-PRAYER-INTEGRATION | 四格与最小玩家知情集成 | 限定验收通过 | PRAYER-PRODUCERS |
| TASK-SOURCE-LOCAL-TIES | 初始亲属与当下事故来源 | 待实施 | PRAYER-ORIGINS |
| TASK-SOURCE-LOCAL-CONFLICT | 当前争议、追查与扣押通知 | 待实施 | PRAYER-ORIGINS |
| TASK-SOURCE-CONTRACT | 当前约定与义务来源 | 待实施 | PRAYER-ORIGINS |
| TASK-SOURCE-MEMORY | 共同见闻与记忆风险来源 | 待实施 | PRAYER-ORIGINS |
| TASK-SOURCE-EXCEPTION | 当前异常观测来源 | 待实施 | PRAYER-ORIGINS |
| TASK-SOURCE-CLOSURE | 自然处境与关键发展链闭合 | 待实施 | 五项SOURCE根族任务、ANCHOR-LIFECYCLE |
| TASK-STARTUP-BALANCE | 首次建团的资源与节奏校准 | 待实施 | SOURCE-CLOSURE、CAPABILITY-PROBES |
| TASK-NATURAL-VERIFY | 修复链独立验证 | 待实施 | SOURCE-CLOSURE、CAPABILITY-PROBES、STARTUP-BALANCE、CULT-SAVE-COMPAT |
| TASK-CAPABILITY-GUARD | 声明职责与正式执行接线检查 | 待实施 | REPAIR-PLAN |
| TASK-CAPABILITY-PROBES | 短行为探针与失效负例 | 待实施 | CAPABILITY-GUARD、PRAYER-ORIGINS |
| TASK-CAPABILITY-AUDIT | 已完成职责的首批防漏复核 | 待实施 | CAPABILITY-PROBES |
| TASK-FRAMEWORK-LESSONS | 通用经验回流 | 待实施 | CAPABILITY-AUDIT |
| TASK-SAVE-NEGATIVE-CONTROLS | 旧坏档重签控制与拒绝层核查 | 待实施 | PRAYER-KNOWLEDGE |
| TASK-CULT-SAVE-COMPAT | 本次规则版本的存档边界 | 待实施 | CULT-SPREAD、ANCHOR-LIFECYCLE、PRAYER-KNOWLEDGE、SOURCE-CLOSURE、SAVE-NEGATIVE-CONTROLS |
| TASK-MATERIAL-TRANSFER | 实际材料递交与知情回执 | 待实施 | ANCHOR-ROUTES |

新增MATERIAL-TRANSFER和CULT-SAVE-COMPAT各承接材料回执及本次存档版本边界；SPREAD复用ROUTES的共享判定，不能各写一套文明规则。ROOTS同时适配ActionCatalog选源/Session合法知情；退役选项及默认世界后果也须实际接入调度。任务书见[Slice14](../tasks/slice-14.md)。

历史A交付（2026-10-28，当时范围）：ORIGINS开工按实际代码核查后拆成DISPATCH→PRODUCERS→INTEGRATION三批，父任务依赖最后一批并保留全部原验收。DISPATCH已独立通过55行为+5运行检查，原KNOWLEDGE72+5正式回归通过；修复独立来源覆盖、原期限排序、联合审计及无现成教团的首名成员识别。旧BG仍过渡，未代验两类新来源、四格或bootstrap生产。密教实现链仍未完成，完整Session仍拒启。报告：docs/qa/prayer-dispatch.md。本轮B已替换正式四类来源并以新报告重跑A/K，原报告不改。

## 旧证据与实际阻塞

23项已交付旧接线任务回到implemented，保留全部历史报告但其受影响证据标stale；这不等于代码被删除，也不等于新设计已实现。旧UI仍implemented、人工ACC-UI/ACCESS待验。旧840轮策略失败/截尾仍属旧规则，不能重签成新通过。

原ISSUE-CULT-DIRECTION和ISSUE-BALANCE-NATURAL-SOURCES继续阻塞完整平衡。前者设计已纠正、代码仍待修；后者由当前祈求设计明确两类求告、知晓、有限当前原根及生产责任，再由五项根族任务与PRAYER-ORIGINS接入。设计完成也不关闭此阻塞。

各实施task实际跑受影响原专项；TASK-NATURAL-VERIFY汇总当前证据并补缺口，按ACC-DIRECTION-REGRESSIONS恢复原任务，不用自然轨迹替代细项反例。生产闭合后校准首团，再做自然新局及原TASK-BALANCE完整策略。TASK-CONTENT保持内容扩量和叙事理解；视听/发行/真人判断不代勾。

历史B交付：04/05/08/09来源、独立无向08初始化、容量/窗口/保存审计及包装记录事件重开通过56行为+5运行检查，A55+5和K72+5按当前实现回归通过；主会话执行，QA独立只读复核证据。该批后续INTEGRATION已在本轮完成四格与最小投影限定验收，见下方当前C记录。五项新原根、完整新局、自然发展和平衡仍由下游验收。框架与master未改。收尾完成必要追踪/数据/展示一致性检查，按DEC-018创建独立本地提交，不推送。


历史KNOWLEDGE交付（当时范围）：[docs/qa/prayer-knowledge.md](../qa/prayer-knowledge.md)。三类取得由真实行为结果产生，指定告知处理者使用受管理选中前提，call在重试和后来取得知识后保持原意向。Turn schema2保存真实事实范围并核采样/取得位置与实际生成seed；重签负例先有未修改成功对照，拒绝发生在语义审计层。旧BG显式legacy_source，完整候选、自动选源及自然新局仍待ORIGINS。新TASK-SAVE-NEGATIVE-CONTROLS承接旧helper核查，CULT-SAVE-COMPAT依赖该任务；原两个阻塞不关闭。

历史B报告：docs/qa/prayer-producers.md；最终证据为docs/qa/prayer-producers-final-results.json、docs/qa/prayer-producers-knowledge-final-results.json和docs/qa/prayer-producers-dispatch-final-results.json。六种子模块开局的实际浅触可形成一名信徒，不等于成立教团。PR09稳定屏障正例不证明自然频率，冻结来源同批改变会放弃，本项风险由INTEGRATION/NATURAL-VERIFY/STARTUP-BALANCE承接。原两阻塞保留。

当前C：本批41行为+5运行检查，原K72+5/A55+5/B56+5当前正式回归通过，主会话执行、QA独立只读复核。请求线索与完整知情分离，必要关联对象保留有限身份，成员不扩整域；内部证明/终局未来预测隐藏；真实回应/重放、逆序知识重建及外壳schema2边界有证据。原F可在实际深应准入时按空位取得，纯预览和请求本身不授F。报告docs/qa/prayer-integration.md；父任务逐项当前汇总docs/qa/prayer-origins.md及docs/qa/prayer-origins-results.json。五族新原根及密教兼容/整链存档/自然/数值仍后续，两个原阻塞不关闭；下一项TASK-SOURCE-LOCAL-TIES。
