# TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration

2026-10-30：限定四组核心、解析与实际启动通过；独立当前适用性复核另列，旧报告不重签。

## 本轮目标

玩家能主动促成首团和文明依托所需的材料，不只能等同一种随机祈求出现。不同路线保留人数、实际代价和跨回合进度；普通共同见闻、约定、观察与合作用一次情境/行动概括，不模拟日程、逐人阅读、签署或传话。

旧十八操作ID只保作共用处理参数或既有入口别名。首团组织不用先有教团，原六人和本地八信仰实际支出仍由Cults核定。互惠必须分别完成两个真实交付，普通转交不能算整约履行。

## 前检确认的接线缺口

- POWER_DREAM已有实际能力，但尚缺通用当前绑定成员的入梦资格，不能把已有按钮称为主动成员路线已通。
- PR06/07情境创建只允许bootstrap/evolution；行动入口要显式扩展正式事务授权，不能假扮演化阶段。
- 新实践材料的生产、有限选择器、Anchors归一化和当前资格必须同步接入；只有判定器不等于有材料来源。
- 新Private Devotion须和Endings共用实际prepare，按下一行动窗口的当前人物/预算判定，不能以成员、目标或等待债务替代可行动联系。
- 新共用处理须注册真实Session/Turn及World校验，不能用少装模块的夹具冒充正式启动。

## 已锁定的简化

规则及费用见system-progression§12.4、system-events§14.10–14.12和正式CSV。联系、组织/仪式、观察/跨轮实践、教习、共同记忆/保管、互惠共用有限处理。记忆与单向保管准备各1低语1信仰，再复用原PR07/06实际回应；互惠准备后两腿各用原费用和共同接收核。原自然合格材料仍可直接使用，不强制重走别名链。

界面沿既有朴素选择、详情、预览和执行，显示当前人物/材料、代价、进度、期限和真实缺口；不铺十八项活动管理屏。结构增量在ui-interaction末节，视觉与真人键鼠验收仍由原任务承担。

## 验证计划与边界

限四组核心行为：联系/无团组织/断联读取；跨轮材料到共享消费者；记忆/保管与互惠两腿；正式Session/Catalog、拒绝不扣费、once及必要组件延续。Godot解析与实际启动独立检查，扫描引擎ERROR，不因退出0忽略错误。普通快速批次目标不超过60秒，不跑旧全组合矩阵。

实际运行及控制前提见下节；受控前提与正式生产结果分别登记。自然机会概率/等待归TASK-OPPORTUNITY-SCHEDULER，八文明逐路线到实付active、首团/终局恢复整链归TASK-SOURCE-CLOSURE，完整Session保存继续归TASK-CULT-SAVE-COMPAT；本项不代验这些后继。


## 失败记录（保留原始结果）

首批formal-01失败，9.478秒。parse通过，core发生引擎错误并退出1，dev未运行；输入无漂移。已确认阶段int/String比较、Cults意愿查询的空字典默认值、归档overlay人物直接索引等实现问题，以及夹具PackedStringArray调用错误。PR07情境已生成，但后续call审计未通过；正式十一模块Session安装及PR08浅回应成功不抵销整批失败。原始目录为tools/progression-operations/runs/formal-01/。原实现者仅有第二次机会，若再失败停止并独立T1接管，不能用退出0或局部断言掩盖错误。


formal-02第二批失败，28.272秒，parse通过且无引擎ERROR/输入漂移；仅PO-CONTACT组通过。教习错读contact_context并不存在的ok字段；Endings的已评估联系白名单未接受新private_devotion，阻断正式轮末和互惠首腿后的下一轮。这是实现接线缺陷，不是数值或世界观路线问题。实际PR07保全、PR06履约、互惠准备/首腿与两节点独立观察已产生，但学生施行、互惠第二腿、完整Session推进和dev未通过，不能用前半段结果标整体完成。原目录为tools/progression-operations/runs/formal-02/。

两次失败后原Code与QA已停止写入/重跑，按CLAUDE.md交独立T1 Code接管。修复守同一四组核心、原费用及浅模拟范围，失败原始结果保留；修复结果见下节。


## 最终实际结果

最终presentation-02的四组核心、Godot解析和实际启动全部通过，总38.368秒。全部进程退出0、无引擎ERROR/SCRIPT ERROR，101个冻结执行输入在运行期间和当前复核均一致。命令为`python tools/progression-operations/verify.py --godot "E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe" --output tools/progression-operations/runs/presentation-02`。运行汇总见progression-operations-results.json，独立当前复核见progression-operations-current-review-results.json。

- PO-CONTACT：实际知晓/愿意的未绑定人物通过私祷实际准入，无既有教团时两次秘密集会的真实转化/支出由原Cults成团。无身份拒绝、纯预览，以及未重点/F满的下一窗口只读消费者对照分别记录；后两项不是实际迁移或自然发生率证据。
- PO-MATERIAL：正式记录跨两轮、双人记忆实践、两次祭仪、网络共用结果及同异常两节点独立观察形成实际材料/归一；教师先经实际共同活动建立合作，再教习，下一轮由原学徒施行，老师当轮机会不被占用。初次不提前产完整依赖，同轮重复拒绝且不扣费。calendar_keeping和dissent_practice沿共享参数映射静态复核，没有逐臂行为实测；不写成全部操作各自跑过。
- PO-MEMORY-CONTRACT：一次准备生成原PR07/PR06可回应处境，后续实际深回应保全三份记忆资格/完成原保管履约；互惠固定两端两条款后，T8/T9两腿均通过共同MATERIAL接收核，完整依赖在两腿齐备后才成立。普通转交不代履约。
- PO-SESSION：真实十一模块Session.start_new、PR08浅回应、一个当前上下文Catalog入口及实际Record Practice执行，正常回合推进到T3/actions；非法输入原子拒绝、组件保存/持久请求重读限次分别通过。组件保存不代表成熟整局Session继续已验。

初始已有生成的人物/职责、原联系、自愿献身与准入前提、80信仰及10洞见，以及成功骰子是明确受控输入；宇宙域经原Attention准入/展开。实际目标材料、转化/首团、祈求准备/回应和交付由正式入口产生，未注入目标结果。不得据此报告自然首团难度、所有文明替代路线active、调度等待界、完整campaign恢复或真人键鼠/视觉通过。

最终修复：教习按实际非空接触及support/cooperation关系读取；共享扎根消费者同根contact_context误读一并最小修正；Endings接受并核private_devotion的原献身事实与原人物身份，历史审计不因后来人物状态倒推重写。前三类类型/空值/归档读取问题已修，失败目录未删；没有调整费用、人数、独立性或世界观方向。

本项仅交付上述入口/生产/共享消费及有限组件证据。完整路线索引二十项、机会目标十项和未装载的来源声明表仍design_only；十八操作项为代码绑定（二项沿原能力），材料二十族implemented/四对象unsupported不等于二十族均逐项运行。剩余TASK-OPPORTUNITY-SCHEDULER — Critical Opportunity Compensation and Bounded Dispatch Scheduler、TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure、TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility继续原责任，两个整链issue保持开放。


## 最终功能呈现补验

最终只读复核发现原详情没有持续进度/互惠条款、部分拒绝只有泛化提示，按已锁定合同在原控件补齐：正式Session实际Record Practice后显示1/2与当前同轮不可再用的具体原因；基于本轮已实际完成两腿的组件呈现显示2/2、原两条款，隐藏未知材料，纯预览不改状态。后者明确是受控presenter对照，不冒称正式CIV01菜单自然生成互惠路线。人物迁机构后不沿operation/npc首个匹配项显示旧进度，而按当前prepare一致的机构key读取，原显式lesson target保留。

repair-01（37.907秒）与presentation-01是先前成功运行，均保留。因补上述实际UI合同及机构key错配，最终重新冻结presentation-02；它们不是额外失败，不混写原formal-01/02两次失败。未增加布局/样式/按键或新场景矩阵；中文错误映射、可读进度投影与实际自动断言不等于真人键鼠、中文字体可读性或审美验收。
