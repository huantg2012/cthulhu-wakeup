# 当前整改计划：轻量生成、重要后果与玩法闭合

更新：2026-10-30，依制作人DEC-026及本轮依赖澄清收口。规则在原系统spec，任务状态在traceability.json，本页不作为另一份实现声明。

## 已锁定

玩家发展密教；公开许可不是通用门槛。未知邪神者可以无指向求援，已知晓者可以定向；关注、信仰、身份知识与玩家情报仍分开。重要进展必须有不同触发/玩家促成路径，必要机会须概率修正和有限等待保障。

模拟默认采用少量条件下的情境抽签。抽出的事故/亲属求援/争议/共同见闻/约定是新的游戏事实，不要求职业日程、事故经过、传话、签署或共同阅读先逐步演化。关系网仍是网，普通情境不把已存在的family/rival及接触证明作为通用来源门槛。已有身份/死亡/重要关系/玩家行为不被抽签冲掉。

重要人物、资源、材料、期限、次数与实际结果要一致；背景过程不另开系统。独立第二观察可以直接抽出新观察结果，复制/转交原记录仍不算第二份材料。随机背景不默认偷偷启动无人可见的致死钟。完整目标见事件§14.5和项目实施入口的模拟粒度约束。

## 立即改变的执行计划

1. 停止未验收精细事故实现的继续扩建与旧矩阵修复。代码/失败/诊断记录保留，后续LOCAL-TIES按轻量情境替换；新方向尚未接入运行时。
2. 13个来源实施子任务合回五个SOURCE父任务；不计完成。五族共享条件抽签/固定/结算流程，避免逐族重复造微观内核。
3. 尚未实施的Core、七业务操作和三组UI设计/接线共14个细分任务合回 `TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration`。保关键目标/替代路线与主动促成，不默认开发18个独立活动。原design_only数据由父任务先收口再启用。
4. 保存负例任务合回CULT-SAVE-COMPAT，以重要状态/已抽结果/期限/一次消费及代表性合法/坏档为边界。已有基础系统不整体重写。
5. 密教传播、材料转交、八文明锚点与生命周期仍是实质玩法，沿原任务继续；不得因抽象化取消资源代价、材料独立性或后果。

完整合并映射见 `docs/tasks/slice-14.md`。减少的是实现粒度与重复验收，不是把未完成能力说成已经完成。

## 验证与成本

制作人补充明确要求后续测试从简，抓核心系统/能力。小型共享核心检查只守回合、资源/名额、生成→回应→结果、期限/一次结算与保存；每任务默认2–4个直接相关代表用例，快速批次目标≤60秒。复用工具，不逐任务新建运行器/授权账本，不铺全人物/文明组合或规模审计；扩大回归必须对应共享边界变化、实际疑点或发布风险。

每组先写2–4项玩家可观察结论，以可控随机输入验证正式生成、实际结算、关键阻断和必要保存。控制抽签不等于注入目标结果；功能通过不等于自然发生率合理。默认只跑受影响短检查，不逐切片重复390项回归，不反向搜索数百种子，不为普通背景构建多层回执/联合伪造审计。

消费者通过仍不证明生产者存在，但抽签生成器就是合法生产者，无需再生产一条微观历史。声明、实现、运行与自然证据仍分别说清。失败先区分设计/实现缺陷、输入过期和数值问题；旧细则已由制作人替换的断言不继续作为玩法要求。

## 开工顺序与边界

五族轻量来源和三项能力检查已有各自限定证据，下一功能链按以下顺序实施：

`TASK-ANCHOR-ROUTES → TASK-MATERIAL-TRANSFER → TASK-CULT-SPREAD → TASK-ANCHOR-LIFECYCLE → TASK-PROGRESSION-OPERATIONS → TASK-OPPORTUNITY-ELIGIBILITY → TASK-OPPORTUNITY-SCHEDULER → TASK-SOURCE-CLOSURE → TASK-CULT-SAVE-COMPAT`。

完整英文任务名、逐项交付及验收移交见[Slice 14当前执行顺序](../tasks/slice-14.md)。ANCHOR先实现共享只读条件及依据，OPERATIONS后生产轻量替代材料；原八文明逐路受阻后另一条实际走到active的义务保留在SOURCE-CLOSURE的ACC-ANCHOR-ROUTE-CLOSURE，不能把判定器通过当路线通过。材料先提供个人接收核，互惠两腿后来调用它；现有教团扩张与首团前组织分开。新Private Devotion与Endings实际联系判断由OPERATIONS补接，避免LIFECYCLE反依赖未实现的入口。

原依赖澄清定位的新局拒启在PlayerSources未消费schema2秘密传播来源；本轮TASK-CULT-SPREAD实际接入后的当前运行与验收状态见docs/qa/cult-spread.md，不继续把旧拒启当作现状。正式全模块启动与有限推进不能代首团发展、自然链或整局保存；完整存档继续/拒旧保护仍由TASK-CULT-SAVE-COMPAT验收，SOURCE-CLOSURE只承接其原范围。不得跳模块或用占位能力放行。

原依赖澄清那一轮未新增任务、未实施功能或改变玩法参数；后续实施状态以各task当前证据为准。首团数值和平衡、自然新局、审美/真人体验不因依赖澄清被标通过。每项完成后同步工作台和本地提交；不自动推送。框架经验回流仍在独立FRAMEWORK-LESSONS任务处理，本轮不改master或框架。


2026-10-30执行前检：Scheduler完整原范围超单批1–3h，新增TASK-OPPORTUNITY-ELIGIBILITY — Shared Opportunity Eligibility and Player Knowledge Projection作为共享查询前置；不新增背景过程。它只把已有Session知情/选项和原prepare/Attention接成可复用纯查询，不代表十目标等待、B公平、服务回执或完整管线已交付。原Scheduler继续这些责任，完整保存继续SAVE。当前20路线为direct/0，不能为FIFO测试注册假bounded_pipeline；真实B对象映射和有限服务界须另在Scheduler定版。新增1项后执行此前置，完成前后数量分别明确，不把拆任务当完工。


2026-10-30：共享查询已验收后，完整Scheduler预检仍超过单批1–3h。只新增一个实际子任务TASK-OPPORTUNITY-SERVICE — Critical Goal Planning and Action Opportunity Service，先接同一本受管理玩家知情、十目标当前缺口与真实actions服务；不新增背景流程、不制造B管线。原Scheduler依赖它后负责实际B目标/概率补偿/公平派发，未实施部分继续如实保留。总79项，当前已验收32；新增1项开工不计完成，收尾后另报净数。


2026-10-30原TASK-OPPORTUNITY-SCHEDULER本轮收口：不再新增子任务。已有20 direct与服务协议之上，概率修正作用于实际至多11个B来源族，miss增权、M2后FIFO跳gate、无写失格同槽跳过与唯一真实产出；原tick/version/保存审计同改。旧38目标B注册/管线证书/Q5与28轮演算不作运行承诺，当前只证I*(M+Q)≤52的条件B提交，不承诺不存在L。已实现direct关键路径与真实actions服务保留；原危机/due/人口/材料/池/展示不改，完整来源与自然/成熟Save仍既有后继。总79，无新增task；完成时未完成46→45。

2026-10-30预算前检：原SOURCE-CLOSURE的16条材料到实付active与高阶终局成熟局合批超预算，新增TASK-ANCHOR-PRODUCTION-CLOSURE — Eight Civilization Material Production and Active Anchor Closure承接原ACC-ANCHOR-ROUTE-CLOSURE六断言。父项依赖它且仍保留其余整链/首团/终局恢复责任；不是把未验收义务删掉。生产入口已有不等于路线已通，实际结果待子项运行。总80；新增1后未完成46，子项完成后回45，原父不提前完成。

2026-10-30 SOURCE-CLOSURE接续只读预检：16条active复用52a077c不重跑，旧Endings夹具手写成熟锚点，当前没有合格真实成熟状态；余项约3–5h。新增TASK-MATURE-ANCHOR-NETWORK — Mature Anchor Network Production and Continuation（90–150min目标）一次正式生产同一world成熟锚网并原组件续接，父项仍in-progress并保五条原ACC及其余来源/首团/终局两恢复。初始资源/洞见等受控不冒自然培养，不扩模拟/改规则。总81，新增后未完成46；子项完成后回45，父项未完成。

2026-10-31成熟前提本轮收束：TASK-MATURE-ANCHOR-NETWORK仍in-progress（85合法段/七实付锚A73，九锚/最终prepare未验）。阻塞是验证脚本漏关键救援对象及错误读取/关闭链假设，实际原PR01治愈/费用有输出，未发现需改游戏救援规则的证据。各实现者达到2次失败上限后停止，先修原resolved关闭链验收再续接，不直接重跑旧大矩阵。新增1项尚未验收，总81/已验收35/未完成46，父SOURCE-CLOSURE仍进行中。

### 2026-10-31核心修复收口

TASK-MATURE-ANCHOR-NETWORK — Mature Anchor Network Production and Continuation的验收工具错误已实际修复，救援23项检查/两离线反例通过，同world九实付active/A93及144段/143原restore已有当前原件。按制作人最新要求停止余下完整流程；子项implemented待验收，最终prepare、完整Session和父来源/首团/终局恢复不冒称完成。原三/五/六断言不降低；后续沿已得真实成熟快照复用，不重复构建或铺旧矩阵。视听/发布继续锁定，不新增task或自动推送。

### 2026-10-31：父子正式核心闭合

2026-10-31：TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure与TASK-MATURE-ANCHOR-NETWORK — Mature Anchor Network Production and Continuation核心执行全部通过。本轮完成两项、没有新增task；总81项、已验收37、未完成44：待开始7、进行中1（TASK-BALANCE）、已实现待复验36，含锁定视听/发布2项。正式登记由最终实际报告及独立当前复核绑定。

复用五族来源、机会补偿、实际材料转交、两种首团组织和八文明16条active路线；不重跑旧矩阵或原成熟构建。九锚/A93及真实共享降临prepare通过；停供A93→89且拒降临，实付恢复A93后原三轮进入ended/awakened、A100。另一分支原三轮普通失败产生10创伤，三次原REST使10→7→4→1、A83→86→89→92，再原三轮正式胜利/A100，九锚均有效。真实联系预测到下一actions的同source入口与浅回应、另窗私祷通过。

仅修必要实现：来源查询和全量证明校验接现有完整StateView/历史索引；终局封存后停止普通锚点尾部写入、允许原owner事务完成既有机会终局投影，保World默认权限；空审计不覆盖真实拒绝原因。工具读历史付款、遵原数字规范化，原失败/升级/受控停止保留。无CSV/数值/世界观/UI改动，无新背景模拟。

原144份成熟分段调用/143恢复与本轮同process的原Turn.submit数量分开统计，不混成总段数。供奉胜利续接19次submit；伤路59次submit/一次恢复6.850秒，业务组778.092秒、含启动整批781.123秒，低于固定1440秒，输入无漂移、无引擎错误。两条原三轮结果均真实提交，不用临时检定或加载通过代替。

完整Session续存、自然频率/首团节奏、整体平衡、人类体验仍由原后继验收；本轮不自动开下一项或推送。下一候选为TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility，尚未启动。报告docs/qa/source-closure.md。
