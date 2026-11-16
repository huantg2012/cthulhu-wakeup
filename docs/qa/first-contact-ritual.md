# 初识人物与祭仪整改：逐项核验

2026-11-16，`cthulhu-wakeup`，Godot 4.7.2，正式 `production/game_root.tscn`。对应[唯一计划](../tasks/first-contact-and-ritual-refinement.md)。本报告记录实际执行范围，不替代原系统规则，不代表制作人体验验收。

## 1. 结果与玩家收益

### O01 / A01–A03：祈求优先承载

结果：首识求告者当轮不出独立人物手牌；处理完祈求也不补发，次轮恢复人物手牌且不播第二次新知。老联系人再次求告不被隐藏，同名不同 ID 不合并，多项请求仍各自存在。

收益：减少开局重复信息，人物关系和可执行目标不丢失。

核验：真实种子 1341549068，新局两位求告者、回响两张祈求、零张新知人物；实际拒绝、保存恢复、正式阶段推进至第二轮通过。原生世界手牌、空人物分类、寻牌、人物图鉴通过。多请求同一人／老联系人／同名不同人／中途初识后的次轮演出采用独立展示夹具，未向游戏注入奖励。

### O02 / A04：可解释的人物公开

结果：`prayer_space_*` 来源只直接披露 actor 求告者，后台角色不再从 targets 批量变成已知人物。已知事件与实际公开行动仍能引入人物；资料、回响使用公开发现经过。

收益：人物有可理解的来历，玩家不会被未介绍的人物牌塞满。

核验：制作人截图种子重新开局，已知人物从原先五人变为两位实际求告者；真实求告资料显示对应求告名，与祈求牌姓名／立绘一致。原截图旧档恢复仍保留五名历史已公开人物。公开入口另审阅 `_event`、`_request_clues`、`_learn`、实际权能结果，未删除独立合法知情通路。

### O03 / A05：有真实介入关系的浸染祭仪

结果：三路共用 CSV 资格——本人开放求告、本人成功入梦、仍忠诚的正式信徒。名字是「浸染祭仪」，不要求先有教团。

收益：玩家理解邪神如何影响凡人，并保留首团前积累信众的路径。

核验：种子 2 无教团直接通过真实求告准备和执行；另一个独立新局真实入梦掷 45、上限 60 成功，关闭求告后仍保留该梦境介入，原求告来源失效。世界初识、其他人物的梦境、失效记录拒绝。忠诚信徒／退出／低忠诚三分支用脱离运行时的规则夹具核验，明确不称为自然成团证据。

### O04 / A06–A07：先固定活动，再选择合格者

结果：祭仪候选不含信使，唯一合格人自动填入；行动机会耗尽能明确提示，既有开放牌不隐藏。网络交换恢复正式成员条件，不额外套秘密集会忠诚门槛。

收益：减少选错人后才被拒绝的试错，也不会因临时缺钱而失去功能牌。

核验：真实祭仪预览／提交一致，重复安排被拒，已开放记录仍在。既有功能牌 69 项回归覆盖全部 28 条首次开放、保存及无 RNG／状态写入。16 项活动在两条真实 Session 上全部查询，12 权能同样只读查询；逐项规则与字段审计见 §3。这是首次结构条件／具体配置审计，不是全目录所有组合可用性的穷举求解。

### O05 / A08：去掉无意义的内部来源选择

结果：内部 source 自动选取并再次校验；牌桌和保留工作台都不显示该槽。实际 record／second_record／other／target／stage 等选择保留，实际记录候选按原根去重，具体对象标题不再被通用 FACT 标题覆盖。

收益：不再面对“初识世界／两个入梦依据”猜选项，留下真正需要决策的材料和对象。

核验：原生准备页无来源槽、无依据卡组，唯一人物直接进入可投骰状态。改用无关来源的真实提交被拒、快照不变；关闭求告不能继续使用原来源。材料／阶段字段经选择器分支与原正式材料校验代码审计，未删除或放宽材料持有／原根条件；未将所有记忆与互惠长链逐条自然打通。

### O06 / A09、A12：准确而精简的准备页

结果：费用只有一处，成功条件为实际 `D100 ≤ n`；收益明确是普通居民归信。CIV_02 展示跨轮祭仪见证，CIV_03 不显示虚假的“两次成功锚定”；CIV_04 单次见证按规则分支处理。

收益：投骰前知道要影响谁、获得什么、承担什么，而非替程序填内部字段。

核验：标准与大字正式场景均实际拖牌、自动选人、执行、查看结果，关键费用、成功条件与祭仪结果可读。CIV_02／CIV_03 由真实新局核验；CIV_04 的单次用途为目录／分支审计。锁定卡壳、肩签、顶底栏、窥视背景未重做。

### O07 / A10：真实骰子和后果闭环

结果：原始检定回执驱动动画，同一次实际提交驱动人物／世界变化和实践，费用不重复扣。

收益：成功与失败都有具体、可判断的后果，不必离开结果页找变化。

- 种子 2：45 ≤ 60，成功；普通信众 +3、污染 +2、察觉 +4、祭仪者理智 −2，CIV_02 实践 1/2。信仰 18→14、低语 3→1。
- 种子 7：85 > 62，失败；不转化信众、不积累成功实践，察觉 +4、理智 −2。信仰 18→14、低语 3→1。

两条均为真实 Session 自然骰流，未控制点数。检查无新增具名 NPC、结果后状态刷新、无第二次奖励。当地转化上限沿原 `min(实际非信众, 表定人数)` 代码，回执比较实际转化量；人口耗尽属于原规则代码审计，不伪称本批新局自然遇到该边界。只输出行动造成的变化，不披露未知四维或人物实时总值。

### O08 / A11–A12：保存、跨入口与身份一致性

结果：公开认知、展示承载、动作资格分别负责；可选 `person_discovery` 保存经过与承载回合，旧档缺字段可恢复基线。图鉴和候选使用完整公开人物，去重仅作用于当轮手牌。

收益：关游戏、换场景、回看回响不会重复发人物；隐藏手牌的人仍能查阅和参与合法行动。

核验：同轮保存恢复、实际跨轮、缺字段旧档、原截图旧档均通过，原事实／资源／提交序号不变。祈求关联资料与底部人物图鉴均只读，真实拖放与返回保留原祈求和草稿。世界／教团共用 `_known_objects` 的去重路径另以只读投影夹具验证，换世界不残留前一世界人物；未为本批篡改真实教团存档。正式场景在预热结束后截图，世界、求告者和资料均有完整原生立绘。

## 2. 可复跑核验与实机证据

命令均在项目根目录，用 `/Applications/Godot.app/Contents/MacOS/Godot` 执行：

```sh
godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
"$godot_bin" --headless --path . --script tools/first-contact-ritual/logic_probe.gd
"$godot_bin" --headless --path . --script tools/first-contact-ritual/edge_probe.gd
"$godot_bin" --headless --path . --script tools/worldplay-integration/card_unlocks_probe.gd
"$godot_bin" --path . --script tools/first-contact-ritual/native_probe.gd
"$godot_bin" --path . --script tools/first-contact-ritual/native_probe.gd -- --large
"$godot_bin" --path . --script tools/first-contact-ritual/native_probe.gd -- --failure
```

本轮运行结果：规则闭环 **114** 项，边界 **23** 项，既有开放回归 **69** 项；三个正式场景各 **46** 项原生交互／状态检查。日志归档：[规则](../art/visual-generation/production-evidence/first-contact-ritual/logic.log)、[边界](../art/visual-generation/production-evidence/first-contact-ritual/edges.log)、[开放回归](../art/visual-generation/production-evidence/first-contact-ritual/unlocks.log)、[标准](../art/visual-generation/production-evidence/first-contact-ritual/native.log)、[大字](../art/visual-generation/production-evidence/first-contact-ritual/native-large.log)、[失败](../art/visual-generation/production-evidence/first-contact-ritual/native-failure.log)。边界探针的原截图存档测试使用 `/tmp/cthulhu-ritual-audit/input.json`；复跑须先放入同一只读副本，不从生产目录自动覆盖或制造这个历史样本。

实机图：

- [首轮回响](../art/visual-generation/production-evidence/first-contact-ritual/standard/arrival.png) · [精简后的手牌](../art/visual-generation/production-evidence/first-contact-ritual/standard/world-hand.png) · [求告者来历](../art/visual-generation/production-evidence/first-contact-ritual/standard/petitioner-record.png)。
- [标准准备页](../art/visual-generation/production-evidence/first-contact-ritual/standard/ritual-preparation.png) · [成功结果](../art/visual-generation/production-evidence/first-contact-ritual/standard/ritual-result.png)。
- [失败准备页](../art/visual-generation/production-evidence/first-contact-ritual/failure/ritual-preparation.png) · [失败结果](../art/visual-generation/production-evidence/first-contact-ritual/failure/ritual-result.png)。
- [大字准备页](../art/visual-generation/production-evidence/first-contact-ritual/large/ritual-preparation.png) · [大字结果](../art/visual-generation/production-evidence/first-contact-ritual/large/ritual-result.png)。

## 3. 十六项活动的资格／字段审计

以下全部执行了只读选择器查询，并与首次开放及正式 `prepare` 分支对照。只有本报告明确列出的祭仪／入梦／跨轮是自然执行证据；其余不冒充完整自然路线通关。

1. `ROUTE_PRIVATE_DEVOTION`：当前实际知晓邪神及自愿归信门槛，自动关联对应知晓事实；不要求已有教团。
2. `ROUTE_JOINT_WORK`：两位真实人物有共同需求，跨机构通路成立；对方选择保留。
3. `ROUTE_COVERT_GATHERING`：忠诚正式成员及真实非信众；不能把普通联系当成员。
4. `ROUTE_CALENDAR_RITE`：祭仪者及三种实际介入通路，单人自动填；正式成功／失败见上。
5. `ROUTE_RECORD_PRACTICE`：记录者或已获记录能力；原材料及同操作者跨轮要求保留。
6. `ROUTE_CALENDAR_KEEPING`：对应记录／历法能力及文明；原超常节拍实践继续消费。
7. `ROUTE_RITUAL_TRANSMISSION`：真实教师与已接触、合作的学生，或原学徒继续自己的未完成教习；阶段不替换为泛用来源。
8. `ROUTE_MEMORY_CIRCLE`：解释机构发起者、原有记录、三名其他参加者；人数和实际记录槽保留。
9. `ROUTE_MEMORY_PRACTICE`：真实两人和原记录／同根知识；跨轮实践不自动完成。
10. `ROUTE_DISSENT_PRACTICE`：真实两人和原相斥视角材料；不通过自动来源伪造见证。
11. `ROUTE_PACT_AGREEMENT`：两人、实际保管记录；保管材料仍由玩家选择。
12. `ROUTE_RECIPROCAL_COVENANT`：不同机构两人、两份实际材料及履行阶段；second_record／stage 不删除。
13. `ROUTE_NETWORK_EXCHANGE`：不同真实节点的正式成员；移除选择器额外忠诚门槛，与正式执行一致。
14. `ROUTE_AXIOM_PROBE`：宇宙世界内的实际人物；无谓内部来源自动关联。
15. `ROUTE_AXIOM_RECHECK`：原实际例外目标保留，不用泛用来源代替另一节点观察。
16. `ROUTE_AXIOM_REPEAT`：同一实际例外和原实践者的跨轮使用；不把重复记录当新目标。

`ROUTE_GUIDED_DREAM`、`ROUTE_PACT_PERFORMANCE` 仍是原权能／祈求通路的别名，不新增两张独立活动牌。全部十二权能通过既有开放回归和本轮只读候选查询；人物手牌抑制不从权能目标集中删除求告者。

## 4. 剩余范围与数据保护

本计划八项已实施，未扩做长期平衡、所有文明的自然成团和锚定长链。`ISSUE-WORLDPLAY-ACTION-AVAILABILITY` 的全目录确定性组合求解仍 open；本批不是以“待选对象”代替那项工作。标准／大字视觉已自行检查，仍待制作人体验复审。

验证均用隔离新局、临时存档及原档副本。核验以本次提交的代码快照为准。此前未提交的美术草稿留在工作区。正式启动入口仍为仓库根目录 `正式UI体验.command`。

## 5. 提交范围与正式画面一致性（2026-11-16）

提交以当前正式入口的完整工作区状态为基线，包含最新裂隙 HUD、上下栏承载与居中贴边布局、主区域路径、下一回合按钮、手牌及文本精修、正式固化立绘和本计划修复。不能将已接入的 UI／资源当作美术草稿排除。此前只含部分修复的暂存快照漏掉最新 HUD，该快照的截图不作为本次提交证据。

正式启动器、工程配置及全部已跟踪运行代码／数据／资源，与重建的暂存副本逐文件核对一致。运行时仅加载已保存的 71 幅非生成卡纹理；未接入的构形稿、废案与本地临时产物不纳入提交。制作工具重建所需的构形源稿按制作人要求留在本机，运行游戏不依赖这些文件。最新 HUD 核验见[当前上下栏](../art/visual-generation/hud-study/README.md)。

最终暂存副本复验通过：规则 114 项、边界 23 项、开放回归 69 项；标准／大字／失败三条实机路径各 46 项；正式 HUD 的分区、贴边、中线、入口、取消及实际下一轮检查通过。64 条目与 8 支持图的语义映射检查通过。本文及 HUD 当前截图已替换为该完整暂存副本的实机结果，运行日志无脚本或渲染错误。
