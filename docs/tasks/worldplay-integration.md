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
