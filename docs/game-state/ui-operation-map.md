# 游戏 UI 操作链路地图

22组功能地图，包含世界／教团牌桌、祈求三态及统一掷骰演出的当前入口。未改路径保留原批核对事实；历史实机、当前源码和定向端到端验证分别注明，不等于全游戏体验验收。

日期：2026-11-14 · 分支：cthulhu-wakeup · 基准：当前工作树；原功能基准 a64712d + 7a76bfa

[打开离线阅览版](ui-operation-map.html) · [源数据](ui-operation-map.json)

编号仅作定位索引，不表示制作或整改优先级。共 6 组、22 项功能。

**范围与证据边界**

- 四区牌桌取代当地联系；原接入证据见 docs/tasks/worldplay-integration.md。2026-11-14 掷骰增量与六条定向 Production 路径的验证边界见 docs/tasks/dice-presentation.md；未重跑的旧截图只证明原批状态。
- 原地图批次补走9张实机记录，并复用当时同提交上一轮审查截图；不把进入页面等同于走完提交、结算和返回。后续自动探针与人工实机分别标注。
- 原地图遍历时 macOS ScreenCaptureKit 连续报错（-3812/-3811），后半段只做源码核对。该历史限制不代表本批新证据；本页仍不声称完整实机遍历通过。
- 只枚举正常UI可达路径，不把开发探针、演示入口或底层未暴露能力算作玩家功能；未穷举随机内容、所有世界组合和每一种异常文案。
- 参考为当前提交的正式UI与业务选择器；没有以旧全貌索引、历史美术规范或已废弃样板推定当前行为。

**阅读方式**

- 先选功能编号看主链，再展开子链与实际界面；编号顺序不代表整改顺序。
- “实机观察”只覆盖写出的步骤；“源码核对、未实走”是尚欠运行证据的范围，不是失败结论。
- 12项权能和16项持续活动在对应功能内逐项列出；共用准备结构不代表各字段与结果相同。
- 同一功能可能有主页面、关联速览、候选、确认和结果等多个承载面；后续打磨应以整条功能链为单位，同时保留原来的返回位置。
- 共用键盘与Esc顺序见F21；成员速览、权能全览等特殊回退已单独列入对应功能。
- 需要投骰的提交共用 F18 的演出与回执链，唯一交互合同为 docs/specs/ui-interaction.md#dice-resolution-contract，美术为 ui-art-standard.md#dice-art-contract；确定性操作不播放骰子。

## 功能索引

- **认识与进入世界**：[F01 诸界与世界玩法](#F01) · [F02 世界档案与情报](#F02)
- **人物与教团经营**：[F04 人物档案与人物关联](#F04) · [F05 教团牌桌与关联资料](#F05) · [F06 教团指令](#F06) · [F07 教团成员](#F07) · [F19 对象对照](#F19)
- **回应与介入**：[F03 祈求：动态回应与旧冻结请求](#F03) · [F08 十二权能：图鉴与施行](#F08) · [F09 赐予](#F09) · [F10 锚定与维系](#F10) · [F11 持续活动](#F11) · [F12 圣物与限时机会](#F12)
- **责任与长期目标**：[F13 供奉与收支](#F13) · [F14 关注与成员名额](#F14) · [F15 本体、降临与敛息](#F15)
- **回合、事件与结果**：[F16 轮初事件与处理复核](#F16) · [F17 回合责任与轮次推进](#F17) · [F18 掷骰、实际回执与编年史](#F18)
- **开局、系统与终局**：[F20 开局、继续与存档管理](#F20) · [F21 暂停、保存与显示设置](#F21) · [F22 封存与终局回顾](#F22)

## 认识与进入世界

<a id="F01"></a>

### F01 · 诸界与世界玩法

浏览已知世界，选择查看范围，并从当地联系进入事务。

**主链：** 新局／继续 → 诸界态势 → 浏览并确认世界卡 → 世界玩法四区牌桌 → 诸界

**实机已观察**

- 本轮从导入副本进入诸界；上一轮同提交实机进入当地并返回。
- 2026-11-13：五世界存档副本中祈求摘要标出两个世界并循环定位；独立初始破口夹具经正式计划器产生反制，已实走拖放查阅与到期移除。详见本批接入记录。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 原批未覆盖四张以上世界；本批已验五世界压叠中的双世界定位，空世界及所有其他组合仍未穷举。

**现场图证**

- [诸界总览 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/01-overview.png)
- [当地联系 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/02-local.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 左侧世界主卡与四维始终保留
2. 右下只收纳已解锁牌，分类／寻牌／整叠翻动，点牌聚焦，拖到执行区上桌
3. 右上查看对象或配置行为，空槽与已填槽各有印记，收回不提交

**摘要定位与反制预告**

1. 点击诸界锚点／祈求／反制预告摘要，同时标出关联世界；重复点击逐个定位
2. 确认世界卡进入牌桌，祈求之后的独立「预告」分类收纳当前计划
3. 拖出预告牌只读来源世界、执行机构、触发倒计时和定性预计影响；到期仍由原规则结算，结束后移除卡牌

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 选卡与切换世界只改变查看范围，不关注、不支付、不刷新知识；各事务另行准备与提交

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/interaction\_stage.gd](../../src/presentation/production/interaction_stage.gd) — overview:50；\_world\_fan:66；local:183；\_intelligence:222；\_crumb:255
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — \_build\_worlds:312；\_inspect\_world:328；\_select\_world:334；\_open\_campaign:1042；Esc:1141
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — \_enter\_local:326

**相关功能：** [F02 世界档案与情报](#F02) · [F04 人物档案与人物关联](#F04) · [F05 教团牌桌与关联资料](#F05)

<a id="F02"></a>

### F02 · 世界档案与情报

检索全部已知世界、理解当地情况，或在行动中借阅世界资料。

**主链：** 世界档案→搜索／范围→选择世界→详情与关联事务→返回原行／入口

**实机已观察**

- 当时从诸界的「展开全部已知世界」进入，选择灰海、查看档案详情并进入教团管理。当前已移除该入口。

**源码已核对 · 实机未覆盖**

- 搜索与范围筛选、当地情报、行动中的世界关联速览、各分支返回未逐一实走。

**现场图证**

- [世界档案详情 · 本轮实机](../qa/ui-operation-map-2026-11-12/04-world-archive.png)

**正常入口**

- 暂停菜单“世界档案”
- 当地四维任一项或“情报与反制”
- 行动已选世界“查阅资料”、中央世界联系、赐予世界查阅
- 关注页的已关注世界条目

**世界档案**

1. 搜索世界名／编号，可清除
2. 切换全部／已关注／未关注
3. 选行打开详情
4. 读层级、四维、反制
5. 进入当地，或查锚点、人物、机构、活动、圣物、历史、管理教团
6. 关注／释放关注另进正式准备

**当地情报**

1. 从指标进入时先读对应指标含义
2. 读四维、文明背景、机构与反制
3. 聆听当地已知记录→聆听准备→实际回执／返回情报

**借阅世界资料**

1. 任务／关注页点击世界资料
2. 读共享世界速览中的四维与反制
3. 可查情报来源、教团成员、人物、圣物、锚点、机构、历史
4. 机构资料可查代表人物、已有锚点，或进入锚定／活动准备

**前提与分支**

- 档案无匹配、原行被筛除、仅请求线索分别显示
- 当地情报的机构／代表是文字；共享世界资料的机构才可打开详情
- 借阅世界资料不是档案或当地情报：仍有“情报来源→事情经过”，且没有“进入当地”
- 无反制、无机构、背景未掌握及不同指标精度／时点均有状态

**何时写入／支付**

- 查询、选择、资料及来源阅读均不提交；关注／释放、聆听、锚定和活动另走正式准备与提交

**结果与返回**

- 档案详情→总览原行；总览→诸界或原暂停菜单
- 档案关联事务→原世界详情、滚动和焦点
- 当地情报→当地；聆听准备退出→原情报
- 共享世界资料返回原行动／资料，保留有效草稿；连续关联共用一个原点

**界面构成**

- 档案总览
- 档案列表＋详情
- 搜索／范围／空态
- 当地四维情报与文明机构正文
- 世界关联速览
- 机构资料
- 情报来源阅读

**代码依据**

- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — open\_archive:65；open\_intelligence:83；\_show\_intelligence:94；\_listen\_local:119；\_show\_archive:208；\_world\_details:296；关联返回:331–342；back:647
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_world:615；\_institutions:658；\_institution:667；\_attention:899
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — show\_subject:465；open\_subject:489；back:767
- [src/presentation/production/action\_workbench.gd](../../src/presentation/production/action_workbench.gd) — 已选对象查阅:79–85
- [src/presentation/production/bestow\_view.gd](../../src/presentation/production/bestow_view.gd) — 世界／人物查阅:56

**相关功能：** [F01 诸界与世界玩法](#F01) · [F04 人物档案与人物关联](#F04) · [F05 教团牌桌与关联资料](#F05)

## 人物与教团经营

<a id="F04"></a>

### F04 · 人物档案与人物关联

按人物查身份、能力、携带物和经历，并从其当前关系安排活动或介入。

**主链：** 底栏人物档案或当地人物牌 → 只读对象上桌 → 查看身份、职责及公开变化 → 返回

**实机已观察**

- 上一轮同提交打开人物目录；本轮从成员速览进入独立人物资料，阅读适用活动并进入结伴协作。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 目录五页签全遍历、搜索筛选、各类关联入口、接纳/离团/任命/入梦未实走。

**现场图证**

- [人物目录 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/06-people.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 底栏图鉴跨已知世界汇集，返回恢复原执行草稿
2. 当地人物牌区分信徒／其他已知联系，不赋予支配权
3. 任命、活动等由行为牌发起；旧菜单关联速览保留

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 人物查阅不提交；活动、入梦、任命、接纳／离团由共享正式准备预览与执行；活动带人物适用范围
- 从行动借阅转去另一项通用行动，先确认任务切换；锚定／材料汇集先分流到机构目标，不经过同一通用确认

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — open\_action:118；run\_action:400；人物入口分流:539–546；open\_person\_activity:506；\_render\_people:587；页签:618；back:767
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_person:378；\_activities:425；\_person\_list:495；人物交叉入口:677、708、763、1054
- [src/presentation/production/prayer\_view.gd](../../src/presentation/production/prayer_view.gd) — 公共人物链接:189；\_people\_links:388；\_show\_person:404；back\_to\_detail:436
- [src/presentation/production/action\_workbench.gd](../../src/presentation/production/action_workbench.gd) — 查阅资料:81；锚定候选查阅:179；多选查阅:318

**相关功能：** [F02 世界档案与情报](#F02) · [F05 教团牌桌与关联资料](#F05) · [F07 教团成员](#F07) · [F19 对象对照](#F19)

<a id="F05"></a>

### F05 · 教团牌桌与关联资料

找到组织，了解现状，并进入指令、成员、供奉和本团活动。

**主链：** 世界玩法 → 教团对象牌 → 进入教团 → 同构四区牌桌 → 返回世界

**实机已观察**

- 本轮由世界档案进入教团；上一轮同提交从当地进入沉钟密会，并从菜单目录跨世界进入守灯密会、返回目录。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 关联教团资料、任务切换确认、教团至供奉/活动/责任的全部往返未逐一实走。

**现场图证**

- [当地进入教团 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/03-cult.png)
- [菜单目录跨世界进入教团 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/12-cult-archive-context.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 左侧固定教团场所图、信众、凝聚、领袖和安排
2. 右下收纳本团成员、相关物件、指令和活动
3. 菜单／档案进入教团时同步切换其所属世界

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 阅读与导航不提交；供奉、指令和活动分别进入负责功能，不把预计收入直接入账

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — open\_cult:75；档案进入:357；\_show\_cult:366；\_cult\_subject:401；返回:647–677
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — 目录:565；\_open\_cult:691；manage\_cult:695；供奉教团入口:843–845；活动:501
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — 人物所属:386；\_cult:444；世界教团:645
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 回合责任组织计划:733；暂停教团:877

**相关功能：** [F02 世界档案与情报](#F02) · [F04 人物档案与人物关联](#F04) · [F06 教团指令](#F06) · [F07 教团成员](#F07)

<a id="F06"></a>

### F06 · 教团指令

比较本轮组织行动，核对收支和供奉影响，登记轮末安排。

**主链：** 教团牌桌 → 传教／敛藏／守持行为牌 → 查看预测 → 登记 → 轮末结算

**实机已观察**

- 本轮选传教→查看草稿预览→登记成功，留在指令页；信仰仍为63，未立即支付。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 另两指令、拒绝/只读态与轮末经营结果未实际推进。

**现场图证**

- [传教草稿与预览 · 本轮实机](../qa/ui-operation-map-2026-11-12/05-cult-order-draft.png)
- [登记成功 · 本轮实机](../qa/ui-operation-map-2026-11-12/06-cult-order-registered.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 登记使用 Session.set\_plan，当前不结算收益
2. 回执留在桌面，可收回卡牌后重新登记

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 选择选项只改界面草稿；登记成功改变本轮计划，不立即支付或获得收入；实际经营在轮末结算

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — \_show\_orders:404；\_plan\_details:412；\_submit\_plan:476；back:656；record\_settlement:679

**相关功能：** [F05 教团牌桌与关联资料](#F05) · [F07 教团成员](#F07)

<a id="F07"></a>

### F07 · 教团成员

从组织名册查看成员职责、能力与随身物件，再进入人物或圣物处置。

**主链：** 教团牌桌 → 人物类别 → 成员对象牌上桌 → 查阅

**实机已观察**

- 本轮打开三列名册→艾达·马什→职责/携带物→人物行动与活动；该成员携带物为空。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 有圣物时的速览与来历、Esc与收起按钮不同回退路径、空名册未实走。

**现场图证**

- [成员职责速览 · 本轮实机](../qa/ui-operation-map-2026-11-12/07-member-peek.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 成员卡只读；任命或活动必须打出对应行为牌
2. 通过既有名额／成员管理入口处理其余正式资格事务

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 名册、成员及圣物来历查阅均不提交；人物行动、任命、圣物处置另走正式准备

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — \_open\_roster:500；\_member\_details:537；\_restore\_member:567；\_read\_relic:577；\_read\_source:600；back:647
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — 正式成员范围:285；\_members:479；\_person\_list:495

**相关功能：** [F04 人物档案与人物关联](#F04) · [F05 教团牌桌与关联资料](#F05) · [F06 教团指令](#F06)

<a id="F19"></a>

### F19 · 对象对照

保留至多两个已知对象，并排核对当前公开资料。

**主链：** 人物／圣物／锚点资料→留作对照→一项对照→另一对象留作对照→两项对照→返回原资料

**实机已观察**

- 本轮从成员关联人物资料留作对照，查看单对象对照并返回。

**源码已核对 · 实机未覆盖**

- 双对象、第三项替换、不同对象组合及不可用对象未实走。

**现场图证**

- [单对象对照 · 本轮实机](../qa/ui-operation-map-2026-11-12/08-object-comparison.png)

**正常入口**

- 通用人物、圣物、锚点资料的“留作对照”
- 已有对照时同类对象页的“查看对照”

**建立与查看对照**

1. 对象页留作对照
2. 去重后加入；满两项则替换最早对象
3. 立即进入一项或两项对照
4. 阅读公开属性、状态及关系
5. 返回原资料／最初借阅入口

**前提与分支**

- 人物目录本身没有留作对照；行动借阅资料也不提供
- 正式入口仅人物、圣物、锚点；底层另有世界／教团／机构对照渲染，但没有正常入槽按钮，不计玩家功能
- 对象当前无公开资料显示缺资料；新局／加载重置时清空
- 没有独立移除或清空按钮

**何时写入／支付**

- 只改变界面中的对照对象列表，不改变游戏状态、不支付

**结果与返回**

- 沿共享关联返回原资料或最初借阅入口；对照不建立新的无限层级返回栈

**界面构成**

- 单对象对照
- 双对象对照
- 对象资料不可用态
- 留作／查看对照入口

**代码依据**

- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — 入口条件:571–573；\_pin\_comparison:810；back:767；reset:66–75
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — render\_comparison:160

**相关功能：** [F04 人物档案与人物关联](#F04)

## 回应与介入

<a id="F03"></a>

### F03 · 祈求：动态回应与旧冻结请求

理解求告处境，选择并执行回应，或保留、关闭请求。

**主链：** 世界玩法 → 事件分类 → 拖入祈求 → 读处境并选回应 → 费用／成功条件 → 提交 → 需检定则掷骰并显现真实后果 → 让回响散去

**实机已观察**

- 上一轮同提交实机打开旧冻结祈求并切换回应；种子1新局打开新情境祈求，核对焦点与实际选择。
- 新五世界档实机对照组合请求原话和三个回应，选择后实际提交并取得回执。
- 2026-11-14：隔离新局 seed=1、5 实走当前组合祈求浏览、辅助展开、Esc 返回不提交、正式回应及实际骰点；51/50 失败、7/64 深刻成功。不再回应经确认关闭且未掷骰、不占回应机会；图鉴往返保留回执、结果退出不重放。

**源码已核对 · 实机未覆盖**

- 旧冻结回应及保留的新祈求覆盖层已在本批 Production 定向探针提交并验证骰点／返回；尚未在本批逐条人工实走。其他生成回应、全部可选组合与资格变化未穷举。
- 此前三态精修只覆盖正式世界／教团牌桌；本批共用掷骰演出已覆盖保留的新旧覆盖层，不表示这些覆盖层的准备布局同步重做。

**现场图证**

- [旧冻结祈求 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/05-prayer.png)
- [新情境回应选中 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/15-prayer-selected.png)
- [祈求浏览](../art/visual-generation/production-evidence/prayer-flow/browse.png)
- [回应准备](../art/visual-generation/production-evidence/prayer-flow/prepare.png)
- [实掷 7／上限 64](../art/visual-generation/production-evidence/prayer-flow/success.png)
- [实掷 51／上限 50](../art/visual-generation/production-evidence/prayer-flow/failure.png)
- [不再回应](../art/visual-generation/production-evidence/prayer-flow/dismiss.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 按请求 ID 读取公开原话、求告者、期限及实际回应；不重复当前世界为来源
2. 回应方式按该处境实际供给；选择后只展示回应、必要槽／可选辅助、影响提示、一份费用及“骰点 ≤ n”成功条件
3. 准备态按 Esc 返回同一祈求的回应选择，不收回祈求牌、不执行；不可逆确认仍保留
4. 正式提交后，有骰回应进入 F18 共用演出，依次看见骰子运动、真实点数／成功上限和实际影响；无骰回应直接看结果；完成后直接返回来源，不再关闭第二张结果页
5. 旧冻结请求保留原合同；全局祈求列表仍可进入原覆盖层

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 正式回应提交重查资格，实际支付并占用本轮回应机会；不可逆项确认前不执行
- 不再回应确认后永久关闭请求，免费且不占回应次数
- 选择、准备、查阅、暂缓与取消不提交；草稿保留至本轮结束

**结果与返回**

- 准备态 Esc 清掉此次回应选择，回同一祈求浏览；浏览态 Esc 收回草稿。
- 有骰回应的 Esc 先加速到停点，再次确认才继续／退出；“让回响散去”结束结果查阅并回来源。请求是否消失由正式状态决定，不再次提交。无骰回应保留直接结束查阅。
- 只读图鉴返回恢复原草稿或已提交回执；原关联覆盖层保留原返回规则。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [src/presentation/production/worldplay/prayer\_receipt.gd](../../src/presentation/production/worldplay/prayer_receipt.gd) — 本次公开回执、真实检定及前后公开资源变化，不使用预览模拟结果。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/prayer\_view.gd](../../src/presentation/production/prayer_view.gd) — 48–96 列表与当地入口；130–190 详情；238–311 旧回应；359–386 准备；388–458 速览与返回；460–505 旧提交
- [src/presentation/production/prayer\_space\_view.gd](../../src/presentation/production/prayer_space_view.gd) — 23–93 新回应选择；101–183 提交与回执；185–218 永久关闭
- [src/presentation/production/interaction\_stage.gd](../../src/presentation/production/interaction_stage.gd) — 50–62 诸界入口
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F17 回合责任与轮次推进](#F17) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F08"></a>

### F08 · 十二权能：图鉴与施行

浏览权能并完成真实目标、依据和准备选择。

**主链：** 底栏十二权能只读；执行从世界玩法 → 权能行为牌 → 必需对象槽 → 预览 → 施行 → 有骰则演出并查实际后果（F18）

**实机已观察**

- 上一轮同提交打开十二权能→聆听→世界候选→选世界→准备。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 其他权能的完整字段链、费用与结果、二次确认、执行与回执未逐项实走。
- 本批 Production 定向探针实走 TaskView 入梦，检查真实骰点、输入阻断及一次回源；其余权能仍未逐项实走，不以共用接线代替覆盖。

**现场图证**

- [十二权能 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/07-powers.png)
- [世界候选 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/08-selector-bleed.png)
- [聆听准备 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/09-preparation.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 已知世界自动带入，唯一必需候选自动填入
2. 只读图鉴不能执行，返回恢复配置草稿
3. 其他旧任务入口保留原准备界面
4. 实际提交需检定时转共用掷骰演出，确定性权能直接显示回执；演出不再执行或支付一次

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。
- 聆听、任命无骰；带概率的即时权能使用真实 D100。降临只在满足条件的第三轮末作最终检定，见 F15／F17。

**何时写入／支付**

- 提交时重新校验。献祭、降临开始/继续/中止进入二次确认；其他权能正常直接执行。
- 锚定虽有专属确认布局，现行资格标记未启用该确认路径。

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

<details>
<summary>十二权能逐项操作（12 项）</summary>

**聆听**

1. 世界
2. 聆听痕迹
3. 直接执行确定结果

**入梦**

1. 世界
2. 人物
3. 梦境联系（等价来源可固定）
4. 可选准备
5. 执行

**谕言**

1. 世界
2. 人物
3. 真实来源
4. 要准备的权能或祈求检定
5. 可选准备
6. 执行

**赐予**

1. 世界
2. 人物
3. 四属性之一
4. 依据及可选准备
5. 专用页施行

**任命**

1. 世界
2. 人物
3. 来源
4. 教团
5. 领袖/护持者
6. 护持者另选锚点
7. 提交登记，下轮生效

**献祭**

1. 世界
2. 人物
3. 入团经历
4. 信仰/洞见/愈合
5. 独特见证及真实经历多选
6. 可选准备
7. 二次确认

**穿隙**

1. 世界
2. 执行人物
3. 屏障弱点
4. 可选准备
5. 执行并消耗一次性弱点

**播种**

1. 世界
2. 执行人物
3. 传播媒介
4. 可选准备
5. 执行

**锚定**

1. 机构目标
2. 补齐材料
3. 固定机构的准备
4. 护持者
5. 绑定圣物
6. 执行

**掩迹**

1. 世界
2. 执行人物
3. 传播证据
4. 可选准备
5. 执行并销毁证据

**迁引**

1. 出发世界
2. 人物
3. 来源
4. 接收世界
5. 随行信众数量→确认数量
6. 可选准备
7. 执行迁引

**降临**

1. 本体与苏醒
2. 查看降临条件
3. 人物与两级锚点
4. 可选准备
5. 二次确认

</details>

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/power\_stage.gd](../../src/presentation/production/power_stage.gd) — open/\_prepare，15–80行：全览、规则及锚定/降临分流
- [src/game/entry\_selectors.gd](../../src/game/entry_selectors.gd) — \_power\_fields，147–210行：十二权能及续付字段
- [src/presentation/production/action\_workbench.gd](../../src/presentation/production/action_workbench.gd) — render/\_choose/\_number，8–320行：共用准备与选择器
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — open\_action/run\_action/back，118、400、767行：草稿、提交、返回
- [src/game/opportunity\_eligibility.gd](../../src/game/opportunity_eligibility.gd) — query，48–84行：实际二次确认标记
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 444 准备页权能全览出口；1110–1166 键盘与Esc顺序
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F09 赐予](#F09) · [F10 锚定与维系](#F10) · [F11 持续活动](#F11) · [F12 圣物与限时机会](#F12) · [F14 关注与成员名额](#F14) · [F15 本体、降临与敛息](#F15) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F09"></a>

### F09 · 赐予

选择人物与永久增强的属性，核对一次性受赐资格及代价。

**主链：** 世界玩法 → 赐予行为牌 → 选择真实所需对象 → 预览／施行 → 共用掷骰 → 实际结果（F18）

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 赐予专用页、属性与依据选择、限制及执行结果均为源码核对。

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 条件、费用与不可逆性由 Session 决定
2. 施行后的实际检定与影响由 F18 共用演出呈现，真实点数和成功上限均来自已提交回执
3. 未逐条重测赐予的所有可选组合

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 施行前重查；当前正常赐予不进入额外二次确认。

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/bestow\_view.gd](../../src/presentation/production/bestow_view.gd) — render/\_options，4–115、186–241行：专用类别、选择与提交
- [src/presentation/experience\_actions.gd](../../src/presentation/experience_actions.gd) — render，56–58行：分派赐予专用页
- [src/game/powers.gd](../../src/game/powers.gd) — prepare，193–194行：终生一次成功及属性上限
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F12 圣物与限时机会](#F12) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F10"></a>

### F10 · 锚定与维系

补齐目标机构的材料、护持和媒介，建立或修复锚点。

**主链：** 世界玩法 → 锚定／维系行为牌 → 选择机构或既有锚点 → 配置／登记

**实机已观察**

- 上一轮同提交从当地锚点与护持进入记忆馆详情。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 汇集记录、条件/风险子页、护持者/圣物比较、施展/修复与回执未实走。

**现场图证**

- [记忆馆详情 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/04-anchor-bleed.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 锚定直接选择护持者、媒介及实际必要依据；不按机构重复出牌
2. 锚定实际提交后展示 F18 共用骰子过程与后果；维系预算登记不因此掷骰
3. 维系集中选择锚点、继续供奉／停供／优先安排，登记后轮末结算

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 汇集按钮直接提交，方案改变先返回重看。
- 施展最终重查；当前锚定正常路径没有额外二次确认。

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — open\_anchor\_goal/\_render\_anchor\_goal/\_prepare\_anchor/\_gather\_anchor\_material，1050–1211行
- [src/presentation/anchor\_preparation.gd](../../src/presentation/anchor_preparation.gd) — plan，20–64行：仅提供有改善的真实汇集方案
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_anchors/\_anchor，722–769行：目录、详情、任命与历史
- [src/presentation/production/action\_workbench.gd](../../src/presentation/production/action_workbench.gd) — \_anchor\_candidates，151–181行：并排选择及查阅
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F11 持续活动](#F11) · [F12 圣物与限时机会](#F12) · [F15 本体、降临与敛息](#F15) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F11"></a>

### F11 · 持续活动

组织合作、见证、实践与交付，推进教团、祈求和锚定材料。

**主链：** 世界／教团牌桌 → 活动类别 → 具体活动牌 → 选择发起者与必要对象 → 施行 → 需检定则共用掷骰与后果（F18）

**实机已观察**

- 本轮人物适用活动→结伴协作准备；世界及执行者随入口带入，另一参加者尚未选择。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 其余15项活动、单/多选材料、跨轮进度、执行及回执未实走。

**现场图证**

- [人物进入结伴协作准备 · 本轮实机](../qa/ui-operation-map-2026-11-12/09-activity-preparation.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 按动词构造活动牌，教团范围按真实成员过滤
2. 完整草稿由正式预览确认；全目录可用性汇总待办仍未关闭
3. 正式提交带概率的活动时显示骰子、真实点数／上限及进展；确定性准备直接显示结果，跨轮保留进度不自动新增一枚骰子

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。
- 判定以实际回执 checks 为准。活动 route\_attempt 属内部事实，即使公开事实无该记录，已有的公开真实骰点仍必须展示；不能读取隐藏材料来补故事。

**何时写入／支付**

- 点击执行时重查并结算本次活动，当前活动不进入通用二次确认。
- 共同见证、订立保管契约只建立情境，后续回对应祈求回应。

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

<details>
<summary>持续活动逐项操作（16 项）</summary>

**秘密祈祷**

1. 一名已知自愿者
2. 建立私人信仰联系

**结伴协作**

1. 执行者
2. 另一参加者
3. 建立合作联系

**秘密集会**

1. 教团成员执行者
2. 发展当地信众

**举行祭仪**

1. 适用祭仪角色
2. 发展信众并累计祭仪进展

**研习神迹记录**

1. 记录者
2. 跨轮使用同组档案
3. 查看成功次数

**推算祭日**

1. 记录者
2. 跨轮沿用异常节拍
3. 查看成功次数

**传授祭仪**

1. 老师及另一参加者；或原学徒选择已教祭仪
2. 教习后另一回合独自施行
3. 分别显示教习/实践进度

**共同见证**

1. 主执行者
2. 实际记录
3. 三位见闻参加者多选
4. 建立情境后转相应祈求

**重温共同记忆**

1. 原两名参加者
2. 可选实际记录
3. 跨轮成功计数

**保留分歧**

1. 原两名参加者
2. 可选实际记录
3. 跨轮成功计数

**订立保管契约**

1. 两名参加者
2. 有保管依据的实际记录
3. 建立约定后转履约祈求

**互换记录**

1. 两名参加者
2. 实际记录及另一端记录
3. 固定两项约定/履行下一项交付
4. 查看两条款及交付进度

**交换观测记录**

1. 两名参加者
2. 核查真实通信与机构联系
3. 完成共同使用

**调查异常**

1. 适用宇宙世界
2. 执行者
3. 留下异常记录

**独立复核**

1. 另一观察者
2. 同一实际例外
3. 取得独立见证

**运用异常**

1. 执行者
2. 同一实际例外
3. 跨轮累计使用进展

</details>

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — open\_activities/open\_person\_activity，501–507行；run\_action，453–456行：原事项返回
- [src/game/entry\_selectors.gd](../../src/game/entry_selectors.gd) — \_route\_fields，213–263行：16项、角色过滤、人数、材料、履行阶段
- [src/presentation/action\_catalog.gd](../../src/presentation/action_catalog.gd) — \_route\_details，224–285行：实际进度及后续祈求
- [data/player\_text.csv](../../data/player_text.csv) — 104–137行：当前玩家事项名称；入梦/履行契约不在活动选择器16项中
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。
- [src/game/progression\_routes.gd](../../src/game/progression_routes.gd) — commit 的实际检定加入 result.checks；确定性准备和带概率的履行区分处理。

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F10 锚定与维系](#F10) · [F14 关注与成员名额](#F14) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F12"></a>

### F12 · 圣物与限时机会

查阅持有与绑定状态，取得、分配或消耗圣物。

**主链：** 底栏圣物只读；世界玩法 → 圣物行为牌 → 选择具体圣物或机会 → 预览 → 施行

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 圣物目录、各放置状态的处置、限时机会三分支与确认均为源码核对。

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 携带、卸下、解绑、回收、分解、公开、等待按实际目录归并
2. 同一动词的多个目标不分别占用手牌；对象牌只展示当前关系

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 解绑、分解须二次确认；其余直接提交。
- 机会公开永久放弃物件，当前无额外二次确认；等待也须执行，不延长期限。

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — \_render\_relic\_comparison，627–650行：目录及机会
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_relic/\_opportunities，699–720、774–826行：状态动作、期限与三分支
- [src/game/entry\_selectors.gd](../../src/game/entry_selectors.gd) — fields，327–337行：处置及机会选择字段
- [src/game/opportunity\_eligibility.gd](../../src/game/opportunity_eligibility.gd) — query，69–76行：只有解绑/分解标记二次确认

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F10 锚定与维系](#F10)

## 责任与长期目标

<a id="F13"></a>

### F13 · 供奉与收支

查看当前储备与轮末责任，安排锚点供奉顺序及本轮停供。

**主链：** 底栏供奉与收支 → 原预算界面；世界玩法维系牌 → 目标锚点 → 登记安排

**实机已观察**

- 上一轮同提交打开供奉与收支，阅读成熟存档的预算和锚点列表。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 调整顺序、停供/恢复、登记确认、确认取消和轮末实际结算未执行。

**现场图证**

- [供奉与收支 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/10-budget.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 预算界面保留全局职责；当地维系使用同一计划接口
2. 持续供奉仍按正式轮末结算

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 编辑只改界面草稿；确认登记才写本轮计划，此时不扣信仰
- 结束本轮后按锁定安排实际先付，演化后再结算收入

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — 489–499 外部入口与草稿；826–943 收支、编辑及登记
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 238 信仰入口；281 底栏；730–731 责任入口
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — 395、401–402 教团借阅
- [src/presentation/experience\_actions.gd](../../src/presentation/experience_actions.gd) — 604 行动费用入口
- [src/game/turn.gd](../../src/game/turn.gd) — 316–329 计划登记与锁定；367–399 支付及结算

**相关功能：** [F17 回合责任与轮次推进](#F17) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F14"></a>

### F14 · 关注与成员名额

安排关注世界、成员身份及未使用的活动预留。

**主链：** 暂停菜单/对象资料 → 关注或成员动作 → 选对象与来源 → 核对条件 → 执行 → 回执 → 原入口

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 关注容量、世界关注/释放、活动预留释放、成员接纳/离团均为源码核对。

**正常入口**

- 暂停菜单「本局资料→关注与成员名额」
- 世界档案关注/释放关注
- 人物适用行动接纳/离团

**关注和预留**

1. 看关注世界、正式成员、临时人物占用/上限
2. 选择世界进行关注或安排下轮释放
3. 或进入释放未用活动预留，选择持有的预留
4. 核对条件并执行

**成员身份**

1. 人物适用行动选择接纳或离团
2. 核对人物及真实献身/离团授权来源
3. 执行后查看实际回执

**前提与分支**

- 已安排释放显示最早轮次；仍承担责任时延后，不提前腾出本轮名额。
- 接纳核对存活、可达、忠诚、真实献身及容量。
- 预留选择器排除祈求所有者；无有效授权不能离团。

**何时写入／支付**

- 查看不占关注，执行才写入安排。
- 上述动作直接提交；「确认离团」名称不代表另有二次确认页。

**结果与返回**

- 回执返回关注页或原世界/人物资料；关联阅读返回原入口。

**界面构成**

- 关注与成员名额总览
- 世界关注准备
- 释放关注准备
- 未用预留选择
- 接纳/离团准备
- 通用回执

**代码依据**

- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_attention，899–914行；\_person，404–413行
- [src/game/entry\_selectors.gd](../../src/game/entry_selectors.gd) — fields，360–367行：世界、预留、身份来源
- [src/game/opportunity\_eligibility.gd](../../src/game/opportunity_eligibility.gd) — attention，135–174行：实际资格
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — \_pause\_menu，878行：暂停入口

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F11 持续活动](#F11) · [F15 本体、降临与敛息](#F15)

<a id="F15"></a>

### F15 · 本体、降临与敛息

查看苏醒依托，开始/维持/中止降临，或付费恢复创伤并结束本轮。

**主链：** 苏醒与降临 → 本体 → 降临条件/续付/中止或敛息 → 准备与确认 → 回执或轮次交接

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 本批 Production 定向探针从合法降临存档完成最后一次实际支付并结束本轮：成功上限15、真实骰点52、失败后进入下一轮事件；原开局／前两次续付／中止／敛息和成功终局尚未逐项实走。

**正常入口**

- 底栏「苏醒与降临」
- 十二权能→降临

**降临开始与续付**

1. 本体查看苏醒、来源及仪式状态
2. 未开始则选择人物、来源、宇宙锚点和星系锚点
3. 进行中则保留原主体及两锚点，查看实付进度，选可用准备
4. 核对费用后确认付款
5. 第三轮末条件仍满足时显示锁定上限的终极掷骰；看清实际点数与后果后，再接下一轮或正式终局

**中止与敛息**

1. 中止降临查看已付轮次丢失及费用不退，再确认
2. 敛息先查花费和恢复量，确认后结束本轮并进入下轮

**前提与分支**

- 降临需有效两级锚点及原宇宙护持者；续付复核持续条件。
- 前两次付款只推进进度；第三次有最终预览，判定在第三轮轮末。
- 漏付或条件失效会中断。敛息需有创伤、足够信仰且本轮未回应/使用权能或圣物。

**何时写入／支付**

- 降临开始、续付、中止均二次确认；中止不退费。
- 敛息使用专门确认，实际付费恢复后立即交接轮次。

**结果与返回**

- 取消确认返回准备或本体。
- 开始／续付的无骰回执回本体；轮末终检按 F18 完成演出，再由真实结算进入下一轮或终局。敛息按实际检查交接，不额外造骰。

**界面构成**

- 本体与苏醒
- 尚未降临
- 进行中降临
- 开始/续付准备
- 中止降临确认
- 敛息确认
- 实际回执
- 轮次交接

**代码依据**

- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — \_render\_progress，652–666行；request\_rest，1017–1033行
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — \_self，1037–1058行：开始/继续/中止入口
- [src/presentation/action\_catalog.gd](../../src/presentation/action_catalog.gd) — \_prepare，205–212行：前两次付款隐藏最终概率
- [src/game/powers.gd](../../src/game/powers.gd) — manifest\_configuration\_valid，133–142行；finish\_manifest，448–461行
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — \_advance，753–788行：敛息结算与交接
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F08 十二权能：图鉴与施行](#F08) · [F10 锚定与维系](#F10) · [F14 关注与成员名额](#F14) · [F18 掷骰、实际回执与编年史](#F18)

## 回合、事件与结果

<a id="F16"></a>

### F16 · 轮初事件与处理复核

逐项处理轮初待决事件，在知悉费用、依据和后果后确认。

**主链：** 进入事件阶段 → 拖入待处理事件牌 → 选择处理方式 → 复核与确认 → 余下事件牌或自由行动

**实机已观察**

- 真实回合推进到两张事件牌，拖入后一张，Esc 返回，再拖入并完成实际确认。

**源码已核对 · 实机未覆盖**

- 关联态势与需要选择额外依据的事件未在本批重测。
- 本批 Production 定向探针完成自然第9轮事件，确认无骰且仍正常返回／交接；新增带检定事件没有现行内容，未冒充已实走。

**正常入口**

- 新局、继续或下一轮出现事件时进入事件专桌

**处理事件**

1. 拖入任一待处理事件牌，读事件与并列处理方式
2. 选择方式进入同场景复核
3. 有依据字段时选择，唯一固定依据自动填入
4. 核对信仰费用、确定后果及不可逆代价
5. 确认后当前确定性事件直接回余下事件牌堆；若未来实际回执含检定则先完成 F18 共用演出，队列清空再进入行动

**关联态势**

1. 事件页 → 查看当前态势
2. 只读已知世界四维与反制
3. 返回轮初事件

**前提与分支**

- 缺依据或资格不符时显示原因并禁提交
- 无事件队列直接进入行动
- 事件页 Esc 回事件牌堆，普通行动和底栏继续锁定
- 当前12类正式事件／24分支没有 D100 指令；已接统一检定回执并不意味着每张事件必掷骰。

**何时写入／支付**

- 仅最终确认通过 Session 重查并提交处理、支付费用；选择、复核和查阅不支付
- 当前确定性结果更新最新回执，不强制单开骰子演出；只在成功提交实际产出 checks 时演出。

**结果与返回**

- 事件页可返回事件牌堆
- 复核取消／Esc 回事件选项与原滚动
- 关联态势返回／Esc 回事件并恢复查看态势入口
- 处理完毕按真实阶段交接

**界面构成**

- 轮初事件专桌
- 轮初事件
- 处理方式选中／复核
- 依据选择／缺失
- 当前已知态势速览
- 受限处理反馈

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 事件专桌、原生拖放与返回牌堆
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 553–610 事件与选项；612–628 关联态势；630–717 复核提交；790–797 阶段入口；1123–1125 Esc
- [src/presentation/session.gd](../../src/presentation/session.gd) — 317–329 行动重查及提交
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F17 回合责任与轮次推进](#F17) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F17"></a>

### F17 · 回合责任与轮次推进

回看尚未处理的责任，确认本轮结束并交接下一轮。

**主链：** 回合责任 → 收支与待办摘要 → 按需借阅 → 结束本轮 → 自动结算 → 依次展示真实检定（若有） → 下一轮事件／行动或终局

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 本批 Production 定向探针已覆盖轮末合法降临失败、逐阶段骰点汇集和延后轮初回响；责任摘要三类借阅及其他轮末组合尚未逐项实走。

**正常入口**

- 行动阶段底栏 → 回合责任
- 内部交接未完成时阶段按钮 → 继续轮次

**结束本轮**

1. 查看正式预算预览与未回应数量
2. 按需进入锚点与供奉、本轮祈求、组织计划
3. 返回责任页
4. 留在本轮或确认结束
5. 自动完成先付、演化、收入、期限和终局检查；各阶段真实检定按顺序加入 F18 演出，全部查阅后再交接下一轮或终局

**前提与分支**

- 三项借阅分别复用供奉页、祈求列表、教团目录
- 未回应祈求给到期提示，不强制回应
- 正式预览不合法时结束按钮禁用；交接未完成显示可重试错误
- 下一轮有事件进入事件专桌供玩家处理；满足终局条件进入回顾。已发生的掷骰演出先完成，轮初回响、立绘过渡及终局不能抢走结果。

**何时写入／支付**

- 打开责任只取确认预览；确认结束才锁定计划并推进真实支付及结算
- 进入轮间或终局时自动保存；结算产生最新实际回执与教团经营记录

**结果与返回**

- 借阅资料回责任页原按钮
- 留在本轮／Esc 回原场景
- 确认后不回旧责任页；若有骰，先查看全部实际检定及后果，再进入新轮或终局。

**界面构成**

- 回合责任
- 借阅供奉／祈求／教团
- 结束不可用反馈
- 结算后阶段与资源
- 交接失败提示

**代码依据**

- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 360–368 阶段按钮；719–799 责任、自动结算与边界
- [src/presentation/session.gd](../../src/presentation/session.gd) — 253–257 自动保存；264–272 推进预览和确认
- [src/game/turn.gd](../../src/game/turn.gd) — 324–329 锁计划；367–399 各结算阶段
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F03 祈求：动态回应与旧冻结请求](#F03) · [F13 供奉与收支](#F13) · [F16 轮初事件与处理复核](#F16) · [F18 掷骰、实际回执与编年史](#F18) · [F22 封存与终局回顾](#F22)

<a id="F18"></a>

### F18 · 掷骰、实际回执与编年史

看清正式检定的过程、实际骰点、成功上限及后果，或检索已知历史；不重复执行行动。

**主链：** 正式提交 → 有骰则刻骨 D100 演出／无骰则原回执 → 实际点数与后果 → 返回来源；底栏编年史 → 历史查阅 → 返回牌桌

**实机已观察**

- 上一轮同提交打开编年史基础列表。

**源码已核对 · 实机未覆盖**

- 本批 Production 六条定向路径共101断言通过：牌桌新祈求、保留新祈求覆盖层、旧冻结祈求、TaskView入梦、轮末降临失败进入下一轮、确定性事件无骰；这些是自动端到端证据，不代替全路径人工体验。
- 结果值与已提交回执一致、重复执行／推进阻断、动画不改快照／RNG及一次回源已定向验证；成功降临终局、全部活动及内容组合未逐项实走。
- 编年史搜索翻页与来由展开仍沿此前源码核对范围，本批未重测。

**现场图证**

- [编年史 · 同提交上一轮实机](../qa/ui-art-review-2026-11-12/11-history.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**需要掷骰的统一执行链**

1. 正式操作只提交一次；Session 的新成功回执含 checks 时打开演出，拒绝、无骰及同持久请求重放不播
2. 保留来源卡、主卡和全部冻结手牌，两枚刻骨 D10 合成 D100；骰子停点等于真实回执，00 与 0 合为100
3. 按原顺序逐个展示检定，停点后显示真实点数／成功上限、档位、实际影响与一次费用；未知曲解成功称已显现
4. 运动中 Esc 只加速到停点；结果确认后继续下一检定，可回看已揭示的结果而不重掷
5. 全部完成后直接返回来源；轮间先让已发生检定结束，再接轮初回响或终局，不再显示第二次收卡回执

**无骰回执与历史**

1. 确定性行为继续使用实际公开回执，不为气氛伪造投骰
2. 底栏编年史检索本局公开记录及来由，返回原场景；查历史不重播骰子、不改变结算

**前提与分支**

- 全局共用合同见代码依据中的 ui-interaction.md#dice-resolution-contract；具体功能保留原费用、条件、不可逆确认及返回来源。
- 结果只读本次公开 checks 与后果：相同点数不是同一次检定，不能数值去重；隐藏主体保持未知，事实中重复的骰点不增投。

**何时写入／支付**

- 支付与规则只发生在原 Session 提交；演出、加速、回看和关闭都不投骰、不再支付、不改变 RNG 或存档。

**结果与返回**

- 有骰结果结束直接回原牌桌／任务来源；自动阶段待全部已发生检定完成再交接。
- 无骰与编年史沿原返回规则；演出不是第二次执行确认。

**界面构成**

- 同牌桌的来源卡、冻结整叠手牌、刻骨骰与结果区
- 原确定性回执、编年史覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 283–284 底栏；801–824 回执变体
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — 945–1015 历史列表、搜索、详情与返回
- [src/presentation/experience\_views.gd](../../src/presentation/experience_views.gd) — 414–423 人物；653 世界；720 圣物；769 锚点；934–1019 公开历史与来由
- [src/presentation/production/world\_management.gd](../../src/presentation/production/world_management.gd) — 319 当地编年史
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 唯一掷骰交互合同：#dice-resolution-contract。
- [docs/art/visual-generation/ui-art-standard.md](../art/visual-generation/ui-art-standard.md) — 美术 A17：#dice-art-contract；素材与演出不另立第二份规范。
- [src/presentation/session.gd](../../src/presentation/session.gd) — \_submit 发出新成功公开 checks\_committed，durable 重放不重复发出。
- [src/presentation/production/dice/result\_model.gd](../../src/presentation/production/dice/result_model.gd) — 真实有序 checks、可靠公开关联、实际后果和独立费用。
- [src/presentation/production/dice/presentation.gd](../../src/presentation/production/dice/presentation.gd) — CanvasLayer30 同桌演出、冻结手牌、批次与输入阻断、结果后一次回源。
- [src/presentation/production/dice/dice\_pair.gd](../../src/presentation/production/dice/dice_pair.gd) — 两枚刻骨 D10 的运动和 D100 真实落点。
- [docs/tasks/dice-presentation.md](../tasks/dice-presentation.md) — 七处规则产生点、无骰范围及当前验证边界。
- [docs/art/visual-generation/production-evidence/dice-resolution/integration-checks.txt](../art/visual-generation/production-evidence/dice-resolution/integration-checks.txt) — 六条真实Production定向接线日志，DICE\_INTEGRATION\_OK101；不是人工完整遍历或美术验收。

**相关功能：** [F03 祈求：动态回应与旧冻结请求](#F03) · [F13 供奉与收支](#F13) · [F16 轮初事件与处理复核](#F16) · [F17 回合责任与轮次推进](#F17) · [F22 封存与终局回顾](#F22)

## 开局、系统与终局

<a id="F20"></a>

### F20 · 开局、继续与存档管理

建立或恢复正式会话，管理已有存档与导入副本。

**主链：** 标题／暂停 → 新局或存档管理 → 设置／选档／导入 → 活动局切换确认 → 正式会话与阶段入口

**实机已观察**

- 本轮标题→存档管理→原生文件选择→导入ongoing.json副本成功；上一轮同提交从菜单建立种子1新局。

**源码已核对 · 实机未覆盖**

- 直接继续、切换取消、无存档/非法种子/错误导入等异常分支未实走。

**现场图证**

- [标题 · 本轮实机](../qa/ui-operation-map-2026-11-12/01-title.png)
- [存档管理 · 本轮实机](../qa/ui-operation-map-2026-11-12/03-saves.png)

**正常入口**

- 启动后的标题菜单：继续游戏、开始新局、存档管理
- 暂停菜单：开始新局、存档管理
- 存档管理中的最近存档、命名存档及导入副本

**新局**

1. 输入可选整数种子；留空随机
2. 开始新局；已有活动局先确认切换
3. 建立新会话并自动保存
4. 进入诸界并按真实阶段打开事件或行动

**继续／选档**

1. 标题继续最近存档，或在管理页选档
2. 活动局先确认切换
3. 验证恢复后清界面草稿并进入该局阶段

**导入副本**

1. 存档管理 → 导入存档副本
2. 活动局先确认切换
3. 原生系统对话框选择JSON
4. 复制至正式目录并验证副本
5. 成功恢复；后续保存写副本

**标题退出**

1. 标题菜单“退出游戏”→直接关闭程序；没有额外确认

**前提与分支**

- 有最近指针才显示标题继续；否则优先新局
- 非法种子原页提示；无存档显示空态
- 复制或校验失败回菜单报错，失败的新副本会删除
- 正式UI没有导出按钮或另存文件对话框；底层带路径保存不等于玩家导出功能

**何时写入／支付**

- 开始成功才创建新局并自动保存；导入选完文件后创建副本
- 载入只恢复会话，不支付资源；手动保存写当前存档及最近存档指针

**结果与返回**

- 新局切换取消恢复种子；选档切换取消恢复原行与滚动
- 系统文件选择取消回原存档入口；管理页返回标题或暂停菜单

**界面构成**

- 标题菜单
- 新局种子设置
- 非法种子反馈
- 切换确认
- 存档管理／空态
- 系统导入对话框
- 载入错误提示

**代码依据**

- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 834–849 标题；905–937 新局与切换；966–1059 导入、选档和会话进入
- [src/presentation/session.gd](../../src/presentation/session.gd) — 181–199 新局与首存；740–766 存档及列表；786–876 验证恢复
- [src/presentation/production/prayer\_view.gd](../../src/presentation/production/prayer_view.gd) — 42–46 begin\_turn只更新草稿，不自动弹祈求列表

**相关功能：** [F16 轮初事件与处理复核](#F16) · [F21 暂停、保存与显示设置](#F21) · [F22 封存与终局回顾](#F22)

<a id="F21"></a>

### F21 · 暂停、保存与显示设置

管理当前游戏，保存进度，并调整显示。

**主链：** 菜单／F5 使用正式会话；牌桌 Esc 按当前深度返回

**实机已观察**

- 本轮标题显示设置→返回；上一轮同提交打开暂停并从教团目录返回。

**源码已核对 · 实机未覆盖**

- 当前牌桌接线已核对；下列原批实机记录不自动代验所有新卡片与可选组合。
- 未实际更改文字/全屏设置，未执行手动保存、F5、保存退出或保存失败分支。

**现场图证**

- [显示设置 · 本轮实机](../qa/ui-operation-map-2026-11-12/02-settings.png)

**正常入口**

- 当前主入口见本节主链；未替换的全局菜单／关联覆盖层继续保留。

**当前牌桌链路**

1. 掷骰演出期间底层菜单／动作／推进被阻断；Esc 优先加速落点，结果状态再次确认才继续，详见 F18
2. 有对象／行为上桌时先收回草稿，其次退出图鉴或教团，再回诸界
3. 图鉴关闭恢复原世界、教团、分类、寻牌、焦点与草稿
4. 事件和确认窗口拦截普通手牌／底栏输入；新局或换档清空旧草稿

**前提与分支**

- 分类、寻找和选牌只改变查看状态；具体执行资格以 Session 当前预览为准。

**何时写入／支付**

- 菜单保存与F5共用同一保存入口，写当前存档及最近存档指针
- 设置点下即应用并写独立显示配置，不扣游戏资源

**结果与返回**

- 依四区交互合同返回；覆盖层返回恢复原牌桌，底栏图鉴恢复完整草稿。

**界面构成**

- 世界／教团四区牌桌或同构只读图鉴
- 仍保留的原功能覆盖层

**代码依据**

- [src/presentation/production/worldplay/view.gd](../../src/presentation/production/worldplay/view.gd) — 当前正式接入；下列旧源码行号仅供定位历史接口，不定义新牌桌布局。
- [docs/tasks/worldplay-integration.md](../tasks/worldplay-integration.md) — 本次实际运行证据及未验范围
- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 104–128 设置；851–886 暂停分组；1061–1099 保存反馈；1113–1166 Esc、模态输入与F5
- [src/presentation/session.gd](../../src/presentation/session.gd) — 740–751 当前slot与最近指针保存
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F20 开局、继续与存档管理](#F20) · [F22 封存与终局回顾](#F22) · [F18 掷骰、实际回执与编年史](#F18)

<a id="F22"></a>

### F22 · 封存与终局回顾

主动结束当前局，或回顾自然终局后的最终状态。

**主链：** 主动封存确认／轮末终局／载入终局档 → 封存回顾 → 编年史或已知资料 → 菜单另开新局

**实机已观察**

- 尚无本会话实机记录。

**源码已核对 · 实机未覆盖**

- 主动封存确认、自然终局、终局只读回顾与重新开局均为源码核对。
- 终局前让位骰子队列的接线已核对；成功降临触发终局尚未在本批实走，不能以失败后进入下一轮的探针代验。

**正常入口**

- 暂停菜单 → 主动封存本局（仅未终局）
- 轮末达到终局条件自动进入
- 载入终局档自动进入
- 终局阶段按钮 → 回顾本局

**主动封存**

1. 阅读封存后仅能回顾的说明
2. 返回菜单或确认封存
3. 进入共用终局页

**终局回顾**

1. 本次终局若由实际掷骰触发，先完成 F18 的真实检定与后果；没有检定则直接进入回顾，载入终局档不重投历史骰
2. 阅读结局、原因、轮次与最终苏醒
3. 回顾编年史或退出到已知场景查阅资料
4. 返回菜单保存、选档或开始新局

**前提与分支**

- 主动封存正式记录为消亡，原因主动封存
- 自然结局涵盖苏醒归零、断联、降临成功；降临失败只在实际结算耗尽苏醒等终局条件成立时结束，否则仍可进入下一轮。
- 终局只读，仍能查看资料和保存，不能解除封存或执行行动

**何时写入／支付**

- 仅确认封存才执行主动结束，中断进行中的降临、写终局事实并自动保存
- 自然终局由轮末检查写入；回顾与查阅无支付

**结果与返回**

- 封存取消／Esc回暂停菜单封存入口
- 编年史返回终局来处；终局可返回当前场景或游戏菜单

**界面构成**

- 主动封存确认
- 共用终局回顾
- 只读已知场景与资料
- 终局菜单

**代码依据**

- [src/presentation/production/round\_view.gd](../../src/presentation/production/round_view.gd) — 364–367 回顾入口；790–797 自动终局入口；939–957 封存确认执行
- [src/presentation/production/task\_view.gd](../../src/presentation/production/task_view.gd) — 553–563 终局信息与后续入口
- [src/game/endings.gd](../../src/game/endings.gd) — 132–166 自然终局、主动封存与正式原因
- [src/presentation/session.gd](../../src/presentation/session.gd) — 253–257 终局自动保存；287–288 abandon确认
- [docs/specs/ui-interaction.md](../specs/ui-interaction.md) — 掷骰唯一交互合同：#dice-resolution-contract；共用链路集中见 F18，不改变本功能的资格、费用或随机规则。

**相关功能：** [F17 回合责任与轮次推进](#F17) · [F18 掷骰、实际回执与编年史](#F18) · [F20 开局、继续与存档管理](#F20) · [F21 暂停、保存与显示设置](#F21)

---

由 ui-operation-map.json 生成。代码接线、已观察状态与仍未覆盖的状态分别记录；此索引不代表美术验收结论。
