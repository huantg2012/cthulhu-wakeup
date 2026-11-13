# 世界玩法牌桌正式接入

日期：2026-11-12。分支：`codex/worldplay-integration`。制作人已通过 `a64712d` 的四区牌桌与整叠翻牌，并授权接入。此分支从该 UI 提交合并 `cthulhu-wakeup@7a76bfa`；原工作树未切分支、未覆盖。当前为**正式运行接入完成，制作人复审待进行**。

## 运行

双击本工作树根目录的 `正式UI体验.command`。标题 → 新局／继续／存档管理 → 诸界 → 世界卡 → 世界玩法。正式存档仍在 `user://production-ui-campaigns`，不是样板的临时复制目录。已有五世界测试档可通过菜单导入副本；生产入口不会自动替换或载入它。旧 `世界玩法探索.command` 继续复制隔离夹具，只作复现。

## 实际接入范围

- 世界／教团四区桌、完整叠牌、行为按动词归并、上桌直接配置与回执，进入正式 OverlayRoot。
- 常驻底栏的权能、圣物、人物进入同构只读图鉴，退出恢复原世界、教团、分类、寻牌、焦点和执行草稿。
- 菜单／档案打开教团也进入牌桌，并以所选教团的真实世界作为上下文。
- 新局和换档清空旧草稿。实际提交后重新读取公开对象与动作；过期目标清除。模态窗口、轮初事件不允许通过底栏或手牌绕过；卡片的绘制顺序限制在牌堆内部。
- 正式场景不包含复制夹具或自动开局逻辑。独立样板仅保留加载夹具与截图的适配，复用同一生产组件。

主逻辑包含 `8d2e73a` 的祈求后果和 `5a4e5bd` 的组合生成、能力改变、保存及正式执行。新回应从 Session 动态取得，展示实际类型、名称、公开提示、费用和持续供奉，提交时校验处境版本与报价。新局 seed 1 的一声祈求实际出现「施恩 · 应允所求」「交易 · 先许愿，再还债」「曲解 · 愿望归他，解释归你」；不是固定浅触／深应，也不保证每声祈求六种齐全。旧冻结请求原义保留，不为旧档补造回应。

合并同时保留 UI 线的开局处境优先、旧请求最低供给、跨世界槽位与注意力准入修正。`Prayers` 统一计算配额，`PrayerSpace.freeze(world, new_limit)` 使用新生成器；没有恢复旧 50 例故事池。继续旧档时暴露的 `Anchors._prayer_record` 空 tag 查询已补默认空串，非祈求公开材料仍被正确拒绝，不改变材料资格。

## 实机证据

下面均为正式 `project.godot` 主场景的 Godot viewport，1920×1080；新局和旧档测试使用隔离目录，不写玩家原存档。

![正式新局：按处境生成回应](../art/visual-generation/production-evidence/worldplay/new-game-prayer-choices.png)

[选择后的费用与检定](../art/visual-generation/production-evidence/worldplay/new-game-prayer-preview.png) · [实际提交回执](../art/visual-generation/production-evidence/worldplay/new-game-prayer-receipt.png)

![旧五世界存档：41张牌全部在桌](../art/visual-generation/production-evidence/worldplay/saved-world-table.png)

![教团：固定主卡与实际指令登记](../art/visual-generation/production-evidence/worldplay/saved-cult-table.png)

[自然轮初事件与禁用的底栏](../art/visual-generation/production-evidence/worldplay/event-boundary.png) · [独立 PCK 的现场出图](../art/visual-generation/production-evidence/worldplay/packed-world-table.png)

## 有限验证

日志统一在[证据目录](../art/visual-generation/production-evidence/worldplay/verification.txt)。

- `tools/worldplay-integration/probe.gd`：223 条断言（含逐张可达几何检查），正式标题新局 → 世界 → 动态祈求 → 只读图鉴往返 → 实际回应一次 → 保存／重载；再加载五世界旧档，验证 41 张完整叠牌、教团登记、模态隔离和下一轮刷新。只证明这些代表路径，不等于 223 项独立玩法全部验收。
- `event_probe.gd`：正常新局从回合责任确认推进，第 9 轮自然出现事件。Esc 与底栏不能绕过，选择并确认实际事件成功；未注入事件数据。
- `cult_route_probe.gd`：从既有教团入口跨三个世界逐个打开教团，所属世界与主卡身份一致，导航不产生提交。
- 原生输入检查：共享生产牌堆的正面点击、向上原生拖出、横拖不误出牌、底栏及键盘只读图鉴，未增加提交。
- `generator_probe.gd`：34 项新生成器与实际后果检查。该原有探针收窄作者候选并固定成功检定，以覆盖曲解、维护、理智与后续，不能当作自然分布抽样。
- `capability_probe.gd`：原有聚焦生成夹具，CIV_02 的实际能力改变 → 历法实践成功。牌桌人物资料读取同一公开能力／限制文字。
- `export_pack.sh`：隔离制作输入打包，独立目录运行 PCK，正式新局与程序立绘可用；包内没有五世界夹具。许可证和字体由原打包脚本一并纳入。

## 范围边界

`ISSUE-WORLDPLAY-ACTION-AVAILABILITY` 仍未关闭。牌桌使用真实草稿预览，尚未实现整个目录的确定性可用／缺条件汇总；生产目录不带旧超时扫描，更不出现「待选对象」资格终态。

没有逐条重测十二权能、全部持续活动、所有锚定材料与跨世界组合。标准字号有本次证据；大字、低帧率和长文本极值没有新证据。其他全局菜单、事件、回合责任、预算和旧关联任务覆盖层保留既有界面，不宣称它们已完成四区改造。轮初事件截图仍有旧的泛化求告对象文案，属于后续事件场景打磨问题。

## 依据与登记

交互唯一正文：[世界玩法合同](../specs/ui-interaction.md#worldplay-card-study)。美术采用 [A01–A03、A05–A06、A08、A11–A14](../art/visual-generation/ui-art-standard.md) 的灰绿卡纸、随包字体、程序图槽与有机外围；本次没有替换获准画法。运行检查覆盖 V 条目的对象一致性、读数、层级、输入和包内资源，不替代制作人审美验收。

架构、当前路由、当前工作、图文规范、UIA-001 状态和功能地图均已同步。源码入口为 `src/presentation/production/worldplay/view.gd`，原样板证据继续保存，不覆盖已获准母版图与动态。

### 2026-11-13 牌桌细化与新档复验

- 世界与教团手牌以同一顺序分类和排序。未解锁权能的卡面显示门槛，来源和落点均拒绝拖放。已解锁权能上桌后由 Session 核对可执行条件。手牌点击只聚焦，手牌和主卡通过原生拖放上桌。
- 卡身、牌缘与名签采用共享粗印分色。实机检查了长牌堆、祈求小牌及轮初事件牌，分色不改变立绘本身。正式事件专桌以公开事件为牌源，进入既有处理、复核、提交和阶段交接。
- 新档由种子 5 的正式新局通过合法活动、事件处理和关注操作推进到第 9 轮。确认五个完整已知世界、一座教团、11 条已知人物记录。在纳巴希邦联拖入组合生成的「等着供给的抄写员」，核对原话、求告者、期限及三个回应，使用隔离副本实际提交并取得回执。两种响应类型为施恩和交易，三项在交付档中均通过预览。
- 回归覆盖组合生成器、冻结档原话、正式事件拖入与确认、未解锁拒绝、已解锁但缺条件可上桌、点击及键盘不出牌、悬停轻弹。V01–V05、V07 的本批标准字号代表路径已实机核对，分色与动效待制作人复审。大字和全组合不在本批重测范围。

[五世界档的组合祈求](../art/visual-generation/production-evidence/worldplay-details/five-world-prayer.jpg) · [分类牌堆](../art/visual-generation/production-evidence/worldplay-details/hand-groups.jpg) · [轮初事件牌](../art/visual-generation/production-evidence/worldplay-details/event-cards.jpg)

### 2026-11-13 解锁过滤与状态精修

依据交互合同及 A06、A09。当地、教团和权能图鉴均在构造牌堆时排除未解锁牌。图鉴以文字保留未解锁权能的苏醒门槛。卡缘用短段干刷标识选中，诸界世界卡复用轻弹，执行槽以暗凹空印、实色印记和暖色下箭头分别区分空槽、已填槽与当前展开位置。

用第 9 轮五世界档的隔离副本核对。诸界叠放世界牌悬停放大后回稳、移出复位。苏醒 10 时「赐予」「降临」不进入牌堆，「入梦」仍可上桌查看缺条件。拖入「任命」后查看有效人物与空槽，选择岗位后槽位随草稿更新。保留组合祈求真实回应的提交回归。已验 V04、V07 的标准字号代表路径，美术待制作人复审。

[选中牌缘](../art/visual-generation/production-evidence/worldplay-details/selected-edge.jpg) · [任命槽位](../art/visual-generation/production-evidence/worldplay-details/appointment-slots.jpg)

### 2026-11-13 立绘提前准备与翻牌性能

针对点击人物才生成及缓存淘汰后再读图的问题，正式呈现改为在新局、读档和公开投影更新后准备当前可展示身份。按出生世界连续生成、直接复用星球上下文；当前公开对象纹理驻留，牌桌图槽同步取得已就绪纹理。只缺新增图时才打开「诸界流转」准备页，展示公开情报与真实进度，结束后恢复原事件／行动交接。未发现世界、未知身份不提前画出。身份、种子、画风、分辨率、玩法随机与存档格式保持原合同。

纯二维构图、PNG 读解码与写盘移入工作线程；GPU 节点构建按时间片让帧，正式调用只画最终图所需的 lit／NPR，工作台仍输出全部诊断阶段。另查出逐对象生成粗印卡纸造成首次导航停顿，改用初始化准备的四张原诸界卡纸；选中、分类颜色、立绘与轻弹仍沿现行组件。逐个人物拖入实机核对时发现已占用查看区的 ScrollContainer 会拦截下一张牌，已将同一区域的原生拖放转交桌面，连续换牌无需先收回。

**本机实测（M4 Pro，Godot 4.7.2 Compatibility；驱动缓存已热，其他进程未隔离，非跨机器帧率承诺）：**

- 第 9 轮五世界真实存档：5 世界、1 教团、11 人物，共 17 张。空 PNG／纹理缓存准备约 **10.92 秒**；加载期间帧间隔 P95 约 17.6 ms，最慢帧约 473 ms，首次 GPU 编译／回读仍可能在过渡阶段短停，不能称全程恒定 60 FPS。
- 重新创建图像提供者，从 PNG 缓存读取 17 张约 **458 ms**，生成次数为 0。
- 准备后遍历五个世界，并逐个拖入 11 个人物：生成增量 **0**、读盘增量 **0**、已绑定图槽没有空纹理，Session 快照不变。按同一输入探针计时，卡纸修正后最大世界导航耗时 **199 ms**，修正前为 1471 ms；此口径包含按键、帧等待和 UI 重建，不能当成单帧时长。
- 超过原 24 张淘汰阈值后，当前公开立绘仍全部驻留；破坏隔离缓存中的一张 PNG 只重画该张。日志中的 PNG 解码错误来自这项故障注入。
- 隔离存档经正常结束本轮、事件选择与确认从第 9 轮走到第 12 轮。第 10 轮准备两张新增公开立绘后恢复事件专桌，第 11、12 轮没有新增图；阶段和输入边界正常。
- 同参世界、教团、人物代表图与优化前 PNG 的 SHA-256 分别完全一致。正式教团单阶段输出切换回工作台三阶段后，最终像素也一致。没有全量复测全部原型、画风或玩法组合。

可复现入口：`tools/worldplay-integration/portrait_probe.gd` 和 `portrait_round_probe.gd`，参数均为原存档绝对路径与证据目录；探针复制真实 Session，读写独立测试存档及可丢弃缓存。制作人的原五世界存档 SHA-256 仍为 `9c709560d228f836d672cb237d7367b6d4e3fc64986153839ca8d8af295824c4`。

[缺图准备页](../art/visual-generation/production-evidence/portrait-performance/preparation.png) · [就绪的诸界](../art/visual-generation/production-evidence/portrait-performance/ready-worlds.png) · [冷／热缓存与连续查阅日志](../art/visual-generation/production-evidence/portrait-performance/portrait-performance.txt) · [真实换轮日志](../art/visual-generation/production-evidence/portrait-performance/portrait-round.txt)。准备页截图是第 12 轮独立缓存缺失一张后的恢复现场；不将其冒充第 10 轮自然新增时的截图。

依据 A01–A03、A11–A14 与 V03–V05、V07：复用已认可的字体、灰绿分层背景和卡纸；准备页仅使用公开区间情报。源码、图像生成合同、交互合同及架构已同步；准备页为本批性能需求新增表现，待制作人体验复审。

<a id="round-arrival-delivery"></a>

### 2026-11-13 轮初回响：本轮待办与新增内容

依据制作人本轮体验授权，加载完成后先呈现「诸界回响」。全部提示牌按世界事件、祈求、新知人物、新启权能／行为排序，在原灰绿氛围中显影；同一卡纸、分类色、原立绘和随包字体。卡堆与当前大牌轻移归位、雾膜消散，文字随后稳定，不倒计时替玩家翻页。下方保留完整牌堆，类别计数定位其首牌，上方阅读原话、世界、期限或新启内容。进入本轮／Esc 可随时收起；顶部「本轮回响」可回看轮初记录。

**真实来源与边界。** 事件来自公开投影中未决事件，说明来自正式选项名称；祈求使用当前生成器的公开求告原话，保留旧冻结请求合同。按真实求告者 ID 优先去重人物，仅请求线索不作为已识别新人物。权能门槛与行为动词归并抽到 ActionModel 的共同入口，牌堆和提示使用同一准入；它不保证资源／目标条件已满足。只在呈现会话记录轮初已见身份，不扩充存档，不消费随机数。行动期新增于下一轮比较；读档将当前身份和解锁状态作为基线，只展示当前待办，新局则标明“初醒／初始”。回看明确是轮初记录，当前已处理状态以牌桌为准。

**有限实机核对。** `round_arrival_probe.gd` 在真实五世界第 9 轮存档的隔离副本上，通过正常结束本轮到第 10 轮：2 项事件、3 声祈求、1 位新知人物；另一个新人物由祈求呈现，未重复。翻看与回看保持 Session 快照不变，立绘生成／读盘增量为 0。收起仍回事件专桌，按实际默认选项分别确认两个事件后进入行动，未跳过决策，也未重复演出。Esc、分类键盘激活、完整牌堆只读、知情过滤和空图检查均通过。共 80 项针对性断言；新增人物去重、苏醒门槛变化、同轮不重播及资源变化不冒充解锁包含明确的纯投影测试夹具，未安装进 Session，也未作为真实新解锁截图。

新局另核对起始牌（2 祈求、2 新人物、4 项起始权能／行为）、未解锁过滤、进入行动，共 19 项断言。实际第 10 轮没有新启权能，未声称在此真实路径中完成一次新权能解锁。没有逐条回归全部事件、权能、活动或所有分辨率；标准字号、正常窗口与现有固定逻辑画布有本次证据。

适用 A01–A03、A05–A06、A11–A15；V03–V05、V07–V08 的本批对象身份、阅读、输入边界和已有缓存复用已核对。新演出视觉与节奏仍待制作人体验复审。架构、交互合同、A15 图文规范及当前 UI 路由均同步；原批准母版和旧图册指纹未改。

- [事件预告](../art/visual-generation/production-evidence/round-arrival/events.png) · [祈求原话](../art/visual-generation/production-evidence/round-arrival/prayer.png) · [新知人物](../art/visual-generation/production-evidence/round-arrival/person.png) · [新局初醒权能](../art/visual-generation/production-evidence/round-arrival/powers.png)
- [约 4.4 秒原生动态](../art/visual-generation/production-evidence/round-arrival/arrival.webp)：`round_arrival_motion.gd` 通过正常换轮录制。原生 Movie Maker 固定 1280×720、30 FPS，取入场及祈求／人物翻阅段，不是运行帧率测量。保留灰绿外围共享时钟，没有新音频。
- [实机检查日志](../art/visual-generation/production-evidence/round-arrival/checks.txt) · [新局日志](../art/visual-generation/production-evidence/round-arrival/new-game.txt) · [动态录制日志](../art/visual-generation/production-evidence/round-arrival/motion.txt)

<a id="palette-study-delivery"></a>

## 配色与卡面重设计（2026-11-13）

制作人接受配色分层，但已否定随后的规整裁边、图窗纸托和精装感，指出根因是构图／拼接／覆盖。A/B 后续又因凌乱及强烈卡面风格不兼容多样立绘被退回；延迟到达的 B 选择已由最新要求覆盖。当前转为[真实多画风同壳验证](../art/visual-generation/card-design-study/README.md)，尚未正式实施。前轮截图均不作为新母版。

先独立定位三处真实合成问题：半透明牌脊透出上下分色、程序图形越过图窗、缺图底与新纸托尺寸不一致。原生首轮设计样片验证了改法可行及 Session 不变，但画面仍是渐变名片，已内部淘汰、移除启动入口。随后用 ImageGen 内置工具制作完整构图母稿及压叠示意，独立审查后修订 A 的石质浮雕感和 B 的人眼形态。图像明确标为概念，不等同于原图像素、实际叠牌或最终素材。

近白试稿随后被制作人指出太白、方形贴图生硬。当前 Godot 原生构图板改为中间明度连续印面，源码仍为 `tools/card-carrier-study/`，新证据在上述设计目录的 `blended-carrier/`；`neutral-carrier/` 原白底试稿不再作为候选，来源及参数清单仍有效。原图完整加载、不改内部 RGB，通过 alpha 与卡体共轮廓，下缘材质化融入字区；未按亮度抠图。检查涵盖三种画风、完整卡及20张同组件压叠，并修正深／浅交界处的竖名可读性。

适用 A01–A03、A05–A08、A11–A14；交互 spec 无机制变更。当前只供制作人判断图面方向；部分原图及原生字、真实卡体遮挡已在独立样组观察，正式悬停／拖拽／超长动态文案与所有类别仍未接入或验收。架构、当前规范、路由与决定记录已纠正旧结论，两项技能禁令持续，用户存档和生产默认未动。

**类别识别增量（DEC-067）：**制作人已认可上述整体风格，要求补强密叠类别识别。本次提供边脊印签／肩位印签／分段侧墨三套同牌对照，包含九类18张手牌及黑底／白底原图，原下半部材质不变。独立入口 `卡牌类别识别对照.command` 可切换并翻牌；图片、范围及操作集中在[当前设计](../art/visual-generation/card-design-study/README.md#category-identity)。有限原生运行无脚本错误，复审修正对照标题空间；关闭识别增量后两张获准稿逐字节复现，7张原图指纹未变，记录见 `category-identity/checks.json`。未测试玩家识别速度，也未将任一方案定为正式默认。交互合同与生成器无改动，原存档不读写。

<a id="shoulder-hand-delivery"></a>

## 2026-11-13 · 单向牌堆与肩位（DEC-068）

制作人选定方案2并授权重构，采用 A01–A03、A05–A08、A11–A14。正式手牌保持固定右压左顺序；肩签扩大为两字单侧，浏览只抬升，横距/z不变；点击不出牌，上拖锁定按下对象，取消回位。连续印面与肩签正式迁入 `production/painted/card_carrier/`，保留原生成图RGB。四区腾出抬牌带，底栏常驻，轮初回响阅读与手牌互不覆盖。

范围为世界/教团/图鉴/事件的手牌与落牌、回响脸；首页世界壳、左主信息卡、槽位选择按钮未做本母版迁移。无玩法数据/费用/生成器或存档变更。有限实机证据与入口集中在[当前样板](../art/visual-generation/card-design-study/README.md#category-identity)，不再保留活跃的三方案切换。

5/18/48张全牌缘命中、固定横距和层级、点击不出牌、原生上拖落牌已核对；真实五世界第9轮隔离档验证祈求落牌、模态阻断及Session快照不变。样板输入双转发与正式误用旧底纹导致变暗均已据实机证据修正。本批画面及手感仍待制作人复审，未做全游戏再验收。

**卡体薄厚度增量。**制作人认可上述交付后要求增加一点真实卡厚；本批只改共用Card的薄纸芯与贴近阴影，拖影和正式已适配场景自动复用。规范为A06薄厚度条目；交互/Session/生成器合同无变更，未增加功能回归。`finish_preview.gd` 原生捕获5张平铺、48张密叠与完整卡/抬牌，shader正常编译，静态复核未见亮栅栏、双轮廓或文字遮盖；[材质证据](../art/visual-generation/card-design-study/card-thickness/full-and-hand.png)待制作人复审。架构登记在同一Card条目，无独立新系统spec。
