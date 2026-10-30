# TASK-OPPORTUNITY-ELIGIBILITY — Shared Opportunity Eligibility and Player Knowledge Projection

2026-10-30：四组限定核心、解析与实际启动通过，独立当前适用性复核另列。

## 交付目的与拆批原因

TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler的预检发现：当前Session知情/已知选项与回合实际prepare/Attention需要共享纯查询，完整知情抽取、十目标next-step规划、服务/等待/B公平合批超过1–3小时。新增一个明确前置先完成原判断的共享复用；原调度器保持待开始，不能把本项说成必要机会已获保障。

本轮不改变玩家原动作、费用或可见边界。共享投影仍从真实已发生事实/回执及原knowledge账本得出已知数据；共享资格查询只验证给定入口和选择，用原prepare/Attention判断当前阶段、费用与机会。StateView只读不是玩家可见证明，不复制新账本、授权层或各模块规则，也不枚举20路线组合。

## 已锁定合同

具体规则见ui-interaction末节。正式Session/Catalog实际委托共享纯模块；未来调度器可从read-view调用，不依赖Session副作用或拒绝事务内执行的public preview。纯查询不修改state、RNG、knowledge输入、费用、候选或FNP，不发行服务事实。原请求未可见前不授线索、实际回应结果才揭示必要对象，未知前因不递归公开。

知识仍沿原Session账本形状保存，不在本项加入权威Turn知情存储或新凭据链。Scheduler随后负责受管理快照、十目标精确缺口、真正actions服务与B补偿/FIFO；28只B选源界，不是实际行动/胜利界，原direct路线不强塞假管线。完整保存继续SAVE，普通背景浅模拟/ART和RELEASE锁定保持。

## 验证边界

计划四个小型核心代表：正式Session/当前合法入口一致；最小投影与隐藏输入；资源/本人机会/阶段拒绝及纯读；实际回应的知识推进与重复/组件账本延续。默认快速批次≤60秒，解析/core/实际启动扫描ERROR，连续两次失败停止原实现者交独立T1。只重查受影响代表，不跑旧31套完整矩阵；独立当前适用性复核最后另列，不重签旧报告。

初始控制人物/资源/随机数与实际生产/知识结果须分别写明；组件账本一致性不等于成熟Session完整保存继续或真人键鼠/审美。此前置验收不代表Scheduler、自然全路线或概率修正已验收。

## 数量说明

本轮新增一个真实前置，再按实际验收完成此前置；新增1与完成1分别计数，原Scheduler仍未完成，不能虚报减少两项。验收登记后总78、已验收32、未完成46；未完成净数与上轮相同的原因是本轮新增1再完成1，当前正式状态以任务台/实施追踪为准。


## 失败记录

formal-01在解析阶段失败，core/dev未运行。Godot虽退出0，但日志包含player_knowledge.gd中PlayerKnowledgeProjection类名不可识别及依赖编译错误，整批正确判失败。原始目录为tools/opportunity-eligibility/runs/formal-01/；原实现者修复同类自引用后仅有第二次机会，如再失败停止写入/重跑并交独立T1。未据一次旧Session解析或退出0宣称行为通过。


formal-02解析通过、四组原断言通过，但隐私夹具触发Nil到Dictionary的引擎错误，整批仍失败且dev未运行。两次失败后原Code与QA停止写入/重跑，按项目规则交独立T1。独立核实：夹具对world.state做deep duplicate会解封归档历史根，使Store.entry把历史编码当普通字典读取；修复改为保留封存根的顶层浅副本，只复制本次需改变的prayer_system/offered。生产reducer没有吞Nil或跳事实。原断言保留，并补cursor达到next_fact，防止函数中断却伪通过。

独立repair-01先前批通过（6.236秒、87运行输入）；最终只读复核发现原unknownMaterial用例实际先被人物门槛拒绝，按相同隐私组做单一正确输入控制和准确字段命名后再冻结补验。它不构成新的生产Bug，也不借此增加材料/别名全矩阵；最终结果见后文。


## 最终实际结果

最终命令：`python tools/opportunity-eligibility/verify.py --godot "E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe" --output tools/opportunity-eligibility/runs/finish-02`。parse 1.762秒、四组core 2.593秒、dev 1.854秒，总6.235秒；三进程均退出0、无引擎ERROR/SCRIPT ERROR，87个实际执行输入运行前后与当前冻结一致。运行汇总为opportunity-eligibility-results.json，独立当前适用性复核为opportunity-eligibility-current-review-results.json，旧报告不改不重跑。

- OE-CURRENT：实际十一模块Session.start_new、原可见PR08的共享查询/公开预览/规范命令及原费用/Attention一致，从正式read-view调用，不依赖Session实例或受事务限制的public preview；重复查询保持纯读。
- OE-PRIVACY：未知人物/实际未展示请求/内部offer但无玩家clue不能通行，错误不泄漏私有ID；未知来源用POWER_LISTEN在“资格来源·聆听痕迹”字段精确拒绝，不再把先卡人物说成材料检查。该组只证明代表来源门槛，不是内部材料转交全类型验收。只读控制不改变真实世界状态或产生隐藏请求。
- OE-REDUCER：实际PR08成功回应后已知事实3→15，原账本纯reducer与Session一致；重复和原保存形状组件重建不重复知识/结果；正常回合至T2/actions。DREAM/PR06别名仅静态映射，rest查询与原“无创伤”拒绝一致，plan为命令分类/原校验；未逐项执行所有权能或经营分支，也未恢复成熟完整Session。
- OE-REJECTIONS：实际Record Practice占用原人物机会后，共享与公开查询一致拒绝再行；低预算/错误阶段为只读输入对照，不冒称世界实际扣款/改阶段。重复拒绝也不推进随机、费用、候选、FNP或输入账本。

初始真实生成世界/模块、bootstrap与成功PR08骰子是受控输入，不代表自然成功率；主要知识增长、原回应和回合/人物实际结果由正式入口产生。封存历史夹具修复和未知来源断言修正均未削弱生产规则；修复后87运行指纹包含改过工具，repair-01先前成功与formal-01/02失败都保留。

## 实现及后继边界

四个共享模块为player_knowledge、entry_selectors、opportunity_eligibility、action_admission。Session/Catalog实际委托，Turn/World原预算及人物判据、Sources/World的prayer成员需求各归同一实现；纯查询不产生服务、等待、提名或状态变更。原knowledge账本/schema不另开新存储，当前Session信封记录eligibility版本匹配；版本登记不是完整继续/坏档保护已验。

TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler仍负责十目标精确缺口、可信受管理快照、真正actions服务、B补偿/FIFO及其审计，原20direct路线不为测试变假管线。TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility验成熟完整保存；自然整链、长期平衡、玩家完整键鼠/字体/审美及ART/RELEASE不由本项代验。本轮新增1个真实前置后只完成此前置，原Scheduler不算完成。


格式收尾先删除action_catalog.gd多出的一个LF，finish-01（6.229秒）通过；暂存后包含新增文件的空白检查又发现player_knowledge.gd末尾多一个CRLF空行。仅删除该2字节后，相同四组快速批次finish-02通过，保证最终提交字节有实际运行指纹；两处均未改逻辑或新增测试。finish-01、presentation-01（7.158秒）及repair-01均保留为此前成功，不混记formal-01/02两次行为/解析失败。最终原始产物82项、实际运行输入87项，文档合同绑定与执行输入分开。
