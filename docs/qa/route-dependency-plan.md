# Anchor, Material, and Cult Dependency Plan Review

2026-10-30。仅规划交付；未实现或运行新功能，未新增任务。完整任务名及执行表在 `docs/tasks/slice-14.md` 顶部。

原问题是开发责任和最终玩法验收混在一起。ANCHOR-ROUTES需要读取替代材料，却被要求在材料生产者尚未实现时证明每条路线都能建成有效锚点；把OPERATIONS直接加为其前置，又会与材料、传播及生命周期形成实际反依赖。

现在按共享资格→材料接收→秘密传播→生命周期→替代路线生产→机会保障→整链验收→完整保存推进。前四项提供实际共用能力，OPERATIONS调用这些能力生产新材料；未来材料的适配器在生产者接入时一并完成。缺生产者仍明确拒绝，不能用空处理者或虚构材料放行。

## 保留下来的验收

- ANCHOR-ROUTES：八蓝本共享资格正反例、十六分支的材料/身份语义、纯预览、当前basis与最小知情投影。只读输入用例的结论仅限消费者。
- SOURCE-CLOSURE / ACC-ANCHOR-ROUTE-CLOSURE：原三组逐文明“禁一路后另一条实际可走”的要求逐字移入；真实生产、承载/转交、依据、首次遗物、建立/修复和实付active都必须发生。没有将这些要求删除或记成完成。
- MATERIAL负责内部转交/共同接收及一次费用；CULT-SPREAD负责09A的真实事件费用/后果，不让前一项先实现后一项。
- OPERATIONS负责首团前组织、互惠两腿和新联系入口；首团不要求先有教团，普通转交不等于互惠履行。新prepare与Endings的接线在此补验。
- 每个模块完成自己的必要持久字段/版本/恢复校验；SOURCE-CLOSURE只使用组件保存结论，完整Session续存由SAVE随后验，NATURAL-VERIFY等待其原前置。

## 当前启动缺口的准确位置

`src/game/player_sources.gd:14–16` 在已装载cult_spread_routes时明确拒绝尚未实现的schema2秘密传播来源；`src/presentation/session.gd:120–124` 装齐模块后才bootstrap。`tools/prayer-integration/run.gd:121–122` 的既有组件装配包含Cults，不能据泛称“CULT兼容”断言Cults.install失败。

当前版本的正式安装、bootstrap及首个行动窗口明确归CULT-SPREAD。必须真正实现新来源，不能删除保护、跳模块或装空handler。此处只据源码/既有记录定位，未新跑Session；其他潜在运行错误不被本分析排除。

## 本轮检查与限制

Code具名角色只读核对实际入口、互惠/首团及Endings交接；Director独立核对依赖顺序并更新roadmap。主会话检查正式任务图无环、八项顺序可达、原三组整链要求逐字保留且新ACC有唯一责任任务、所有task数量/状态未改，随后同步工作台。

本轮不运行引擎，不新建测试框架，不改src、data、system spec或历史QA/tools。共享任务书和计划改变后，以新报告记录旧限定证据的适用性：逐项核对原验收语义及未改实现/规则输入，保留原运行报告与时间；这不是重新运行，更不验证本轮八项待实现能力。验证记录见 `docs/qa/route-dependency-plan-results.json`。

当前总77任务、未完成63项（待开始14、进行中1、已实现待复验48），锁定2项；两个实际阻塞继续开放。任务分析的落地不计作新的游戏能力完成。通用框架、视听及发布任务未启动。
