# 正式界面美术接入

基线：`dcaf037`（`origin/codex/visual-generation-exploration`）。依据[现行路由](../progress/stage-priorities.md#game-ui-routing)、[美术规范](../art/visual-generation/ui-art-standard.md)与[交互合同](../specs/ui-interaction.md#locked-interaction-production)。实施在独立 `codex/ui-art-production`，规范问题按 [UIA 台账](../art/visual-generation/ui-art-feedback.md)交原维护会话，派发者负责转交。

## B01 · 共享材料与生命周期

- S01 诸界与常驻外框：正式入口 → 新局／继续 → 诸界；核对顶栏数值、底栏入口、责任入口与键鼠切换，打开／关闭菜单观察外围时钟。
- 依据 A04–A06、A09、A11–A12、A15–A16，验 V01/V02/V04/V06/V08；对照 G01、C01、T01、G07 及完整视频。X03 的状态色按衍生方案实施，待制作人复审。
- 开工证据：母版是独立 Godot 样板，不是正式 Session。B01 留原世界占位与原排布，B02 接真实世界身份和卡扇；当地、其他正式场景需按后续批次逐页核对。

## B02 · 正式图像身份与诸界卡

- S01 诸界：新局 / 继续 → 按公开世界选卡 → 当地 → 返回到原卡。一次用自然新局检查少量世界和真实生成；多世界仅用可由正式存档入口加载的既有 Session。
- 依据 A07–A08、A13–A16，核对 V03/V04/V05/V07/V08。初始缺口：两条文明模板映射、占位图、无生产调度；需保持世界资料入口及未识别状态。

## B03 · 当地、世界档案、教团

- S01 当地：在诸界确认世界 → 当地 → 情报与反制／原四维 → 返回。保留现有主体、当地入口和近邻位置。
- S02：诸界 → ⋯ → 世界档案 → 搜索／清除 → 打开一项详情；核对只读、同源缩图和原返回。
- S01／S02 入口精简：移除诸界「展开全部已知世界」，反制摘要仍打开世界档案。现有 InteractionStage／WorldManagement 分工照旧，RoundView 返回时优先聚焦可操作的世界牌堆，缺少牌堆时回菜单。交互合同与操作地图已同步。用五世界存档副本实机核对入口消失、五张牌完整、进出世界后焦点回牌堆、菜单档案及反制摘要均可进入、档案关闭返回原菜单项，且 Session 快照相同（V04／V05／V07）。本批实走的是无反制计划状态；有计划的文案与规则按源码核对。
- S03：既有真实存档 → 当地已知教团 → 当前安排／成员。核对指令选中与底部阅读；现状需实机判断组织场所图是否有合规槽。
- A07–A09/A12–A14；V01/V02/V03/V04/V07。尚无本批正式证据；B02 图像接口可直接复用。

## B04 · 人物与祈求

- S09 人物档案：底栏 → 人物档案 → 选择人物／页签 → 返回。统一已有 32×32 名单、主体、相关速览及 S03 名册槽。
- S04：诸界／当地 → 祈求列表 → 已识别求告者与回应 → 比较／暂缓／不再回应确认。检查身份相同和公开范围不变。
- A07–A09/A12–A14；V01–V05/V07–V08。既有情境配方含情境专属动作和道具，正式图像用 CSV 提供中性人物装束依据，不把工作台情境当作人物经历。

## B05 · 十二权能与准备
- S06/S07：十二权能 → 未解锁要求 / 聆听或入梦准备 → 当前联系／候选 → 返回；不改资格与执行。
- A09/A10/A12，V01/V02/V04/V07；缺口为旧符印笔触、候选头像与专用赐予槽。

## B06 · 锚定与持续活动
- S08/S07：当地 → 锚点与护持／持续活动 → 机构条件或候选／费用 → 返回。
- A09/A10/A12–A14，V01/V02/V04/V07；机构使用现有语义印记，不绘制新的建筑事实。

## B07 · 圣物、供奉、关注、本体与降临
- S10a 从圣物与当地机会进入；S10b 从供奉与收支进入并查关注；S10c 从苏醒与降临进入准备、持续、续付或敛息确认。
- A09/A10/A12，V01/V02/V04/V07。每个分支保留原可用状态、价款及返回，独立核对。

## B08 · 轮初与责任
- S05 通过有事件的轮初进入；S11 由底栏回合责任进入，读条件后返回／推进到真实结果。
- A09/A10/A12，V01/V02/V04/V07。没有主体的事件去掉会被理解成该事件事实的通用建筑。

## B09 · 编年史、终局和对照
- S11/S09：编年史检索与回看；人物详情留作对照；封存局从已存档入口进入只读回顾。
- A09/A10/A12–A14，V01/V02/V04/V07；资料沿原分栏与局部滚动。

## B10 · 系统菜单
- S12：标题 → 存档／设置／新局；局内暂停 → 返回／封存确认。保持原生系统导入面板。
- A05/A09/A12，V01/V02/V04/V07/V08；检查普通、放大文字与打包入口。

## 实机证据与剩余范围

以下截图均来自 `project.godot` 的正式主场景，逻辑 1280×720、图证 1920×1080。新局为种子 1；成熟状态通过标题的存档管理载入隔离复制的 [ongoing.json](../qa/ui-manifest/saves/ongoing.json)，轮初使用 [ready.json](../qa/ui-manifest/saves/ready.json) 真实推进。程序只操作原生控件并读取屏幕，未向投影注入对象、编辑存档或预设结算。视觉状态为**实机核对代表路径·待制作人复审**；缺证或受阻项单列。

- **B01 / S01 外框** · [初次接入](../art/visual-generation/production-evidence/b01/overview.png) 保留首批占位，[放大文字](../art/visual-generation/production-evidence/b01/overview-large.png) 为接卡后的同入口。新局 → 回合责任 → Esc 恢复焦点 → 当地 → Esc；两位数资源可读。正式 [24 秒动态](../art/visual-generation/production-evidence/b01/peripheral-motion.mp4) 在 1280×720 / 30 fps 捕获，中途开关菜单；首尾时钟相位一致。对应 V01/V02/V04/V06/V08。焦点、禁用及按下使用 A09 衍生方案，待复审。
- **B02 / S01 诸界** · [新局一世界](../art/visual-generation/production-evidence/b02/overview.png)、[成熟三世界](../art/visual-generation/production-evidence/b02/saved-worlds.png)。进入当地再回到原卡，检查同图键／真实数量／知情与规则快照不变。冷暖高亮来自同一 Godot 接口。V03/V04/V05/V07/V08。三世界实际拖动松手未误入。叠放沿获准算法；手边可载入存档最多公开三世界，四张以上的正式实机叠放尚缺证。
- **B03 / S01 当地、S02、S03** · [当地](../art/visual-generation/production-evidence/b03/local.png)、[原四维进入情报](../art/visual-generation/production-evidence/b03/intelligence.png)、[档案](../art/visual-generation/production-evidence/b03/archive.png)、[教团指令](../art/visual-generation/production-evidence/b03/cult-orders.png)。高亮底图保持完整，原联系坐标与命中保留；档案缩图、无匹配／清除、只读返回已查。教团下部底材、指令与成员槽已接；完整经营主场所图受 [UIA-001](../art/visual-generation/ui-art-feedback.md#uia-001--教团当前安排的完整场所图没有独立槽) 阻塞。未遍历成员失效或不同教团结果。V01/V02/V03/V04/V07。
- **B04 / S09 人物、S04** · [人物档案](../art/visual-generation/production-evidence/b04/people.png)、[冻结旧祈求](../art/visual-generation/production-evidence/b04/prayer.png)、[新情境祈求](../art/visual-generation/production-evidence/b04/generated-prayer.png)。切经历页仍为同一身份；祈求的已知主体与相关查阅核对图键；[不再回应确认](../art/visual-generation/production-evidence/b04/dismiss-confirmation.png) 及取消保持快照。长姓名完整性与所有回应结算未逐条测。V01–V05/V07–V08。
- **B05 / S06、S07 通用准备** · [十二符印](../art/visual-generation/production-evidence/b05/powers.png)、[权能查阅](../art/visual-generation/production-evidence/b05/power-rules.png)、[聆听准备](../art/visual-generation/production-evidence/b05/preparation.png)。十二项可选，读未解锁条目后回聆听，进入世界候选和费用；保留赐予专用构图并接同一图槽。未逐一执行十二权能或赐予全部字段。V01/V02/V04/V07。
- **B06 / S08、S07 活动材料** · [锚定目标](../art/visual-generation/production-evidence/b06/anchor.png)、[条件速览](../art/visual-generation/production-evidence/b06/anchor-conditions.png)、[当地持续活动](../art/visual-generation/production-evidence/b06/activities.png)。同一实际机构查条件、返回，再开活动；本批未重新支付材料或施展锚定。V01/V02/V04/V07。
- **B07 / S10a** · [圣物](../art/visual-generation/production-evidence/b07/relics.png)。实际已知圣物与机会入口仍在。未遍历各获取期限／失效。
- **B07 / S10b** · [停供草稿](../art/visual-generation/production-evidence/b07/budget-draft.png)、[关注](../art/visual-generation/production-evidence/b07/attention.png)。选择已知锚点停供、打开登记并取消；从暂停菜单看关注名额后返回；快照无支付。未重新测轮末真实扣款。
- **B07 / S10c** · [进行中](../art/visual-generation/production-evidence/b07/manifest.png)、[续付准备](../art/visual-generation/production-evidence/b07/manifest-renewal.png)。来自实际降临存档，进入续付准备后返回。未提交续付／中止；本档未产生可敛息恢复的条件。S10 合计 V01/V02/V04/V07。
- **B08 / S05、S11 轮末与回执** · [回合责任](../art/visual-generation/production-evidence/b08/responsibility.png)、[实际轮初事件](../art/visual-generation/production-evidence/b08/event.png)、[复核](../art/visual-generation/production-evidence/b08/event-review.png)、[实际回执](../art/visual-generation/production-evidence/b08/receipt.png)。从第 1 轮推进至第 4 轮，验证阻断、关联、取消与确认；没有重验全部事件或各类长回执。V01/V02/V04/V07。
- **B09 / S11 编年史与终局、S09 对照** · [记录](../art/visual-generation/production-evidence/b09/history.png)、[只读终局](../art/visual-generation/production-evidence/b09/ending.png)、[人物对照](../art/visual-generation/production-evidence/b09/comparison.png)。在隔离局实际封存，回顾不解封；从已有成员进入人物对照。空史与两个对象并列的全部组合未验。V01/V02/V04/V07。
- **B10 / S12** · [标题](../art/visual-generation/production-evidence/b10/title.png)、[暂停](../art/visual-generation/production-evidence/b10/pause.png)、[大字设置](../art/visual-generation/production-evidence/b10/settings.png)、[存档](../art/visual-generation/production-evidence/b10/saves.png)、[非法种子反馈](../art/visual-generation/production-evidence/b10/invalid-seed.png)、[封存取消](../art/visual-generation/production-evidence/b10/seal-confirmation.png)。实际设置保存在隔离目录。系统文件选择器及磁盘写入故障本批未重测。V01/V02/V04/V07/V08。

架构登记见[正式呈现](../architecture.md#正式界面美术接入2026-11-12)；图像身份合同已原地更新，现有[交互合同](../specs/ui-interaction.md#locked-interaction-production)未改，规则、资格和存档格式仍由原 Session 管理。材料、字色与按钮状态为同一生产主题；批准快照不覆盖，运行对照使用 `dcaf037`。S03 其余接入不依赖 UIA-001 的答复。

验证脚本在 `tools/ui-art-production/`。可通过正常入口 `正式UI体验.command` 审阅；自动路径可传 `--save=res://docs/qa/ui-manifest/saves/ongoing.json` 给 `scene_probe.gd`。PCK 通过 `tools/ui-art-production/export_pack.sh /absolute/game.pck` 打包并从空目录启动，核对两款字体、许可证与种子 907 的真实新局从 PCK 现场出图。此验证覆盖游戏包，未导出签名 macOS 应用。
