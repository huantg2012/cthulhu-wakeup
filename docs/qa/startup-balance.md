# 首团资源与节奏：限定验收

2026-10-31，TASK-STARTUP-BALANCE — First Cult Resource and Pacing Balance。

同日后续核查更正：此前将自动档误写为core最终观察时点。当前正文已区分T8/between自动档与T9/actions观察；旧raw、actual与当时签名保留原字节，后续实际推进及独立更正见[natural核查](natural-verify.md)。六样本原八窗成团/截尾结论不因此改变。

本轮保留初始 **18 信仰、每轮 3 低语及全部行动费用与成功率**，仅将机会参数 `forced_after_missed_slots` 从 2 改为 1。Design 接受本阶段限定通过，不开启第三轮数值试验。一次合法漏选后进入原公平 FIFO，改善恢复来源的供给时机；不保证每个样本在八个行动窗口内获得展示、成功回应或成团。

两个验收汇总为 `STB-RESOURCE-PACING`、`STB-OPPORTUNITY-WAIT`。完整绑定见 [实际结果](startup-balance-results.json)。原 TASK-PROGRESSION-OPERATIONS 的来源遗漏修复单独列证，不新增任务、不把受控功能例计入自然结果。旧 38 项验收只作当前差分复核；本报告不重跑或重签它们，当前 39 项 / 130 条断言索引由独立 current review 核对。

## 数值依据与实际结果

两种组织行动原价都是 4 信仰 / 2 低语，成功至多增加 3 名信众；原首团条件是 6 人及本域累计实际支出 8。免费 PR08 入团成功后，18 信仰可负担两次组织成功及两次普通失败，共 16，留下 2。失败照常付费、占人物行动机会及跨轮间隔。无教团时没有基础被动信仰收入，等待不能当作自动回钱。

备用 Dream / private devotion 路线仍按原实际知情、忠诚与费用执行。三次普通成功 Dream 的最低预算为 6，再加两次组织成功 8 和一次失败 4，合计 18；这是最低预算算式，额外失败会继续消耗资源，不保证每个自然轨迹都能在此预算内完成。两轮均没有真正资金截尾，因此没有依据提高初始信仰或降低价格。

固定样本为 seed 1–4 聚会优先、5–6 祭仪优先；缺合法已知祭仪操作者时允许原策略回退聚会并记录等待。两轮使用同六个种子与相同策略作配对观察，不能当成十二个独立样本。每条从真实新 Session 开始，最多观察八个真实 actions 窗口；自然 RNG 不覆盖、不重筛种子。工具保留默认事件结果和正常生产、期限、抵抗。下表“余信仰 / 信众”是样本结束值；实际采样窗口为 T1–T8，core 最终观察推进到 T9/actions；保留的自动档实际为 T8/between（成团样本为 T3/between，core 观察为 T4/actions），不能混称同一时点。

| seed | 第一轮 M2：结果，余信仰 / 信众 | 第二轮 M1：结果，余信仰 / 信众 | 实际解释 |
| --- | --- | --- | --- |
| 1 | 八窗截尾，12 / 0 | 八窗截尾，14 / 0 | 第二轮 T6 已产生新 PR08，但 T7–T8 没有第二个可回应的已展示联系；不是资金截尾。 |
| 2 | 成团，6 / 6 | 成团，6 / 6 | 聚会两次成功（含 deep）及一次失败，实付 12。 |
| 3 | 八窗截尾，18 / 0 | 八窗截尾，18 / 0 | 第二轮 T6 实际回应恢复 PR08，roll 100 为灾变。 |
| 4 | 八窗截尾，18 / 0 | 八窗截尾，10 / 3 | 第二轮 T7 恢复 PR08 的 roll 98 为灾变；随后实际祭仪 T7 成功、T8 失败，实付 8，未成团。 |
| 5 | 成团，6 / 6 | 成团，6 / 6 | 祭仪优先但缺合法操作者，回退聚会：两次成功、一次失败。 |
| 6 | 成团，6 / 6 | 成团，6 / 6 | 同样回退聚会：两次成功、一次失败。 |

两轮的 seed 2、5、6 均在 T3 建立教团，于下一次 T4/actions 被样本确认。当时余 6 信仰；hold 收入预览为下一轮条件性毛收入 1，尚未到账，不可提前支付。每轮都是 3 条成团、3 条八窗截尾、0 条资金截尾。这只是六条固定轨迹的描述，不能当作总体成功率、分位数或“平衡已收敛”。第二轮有真实祭仪结果，但没有自然祭仪成团证据。

## 恢复等待：供给与展示分开

第一轮的三个截尾样本在观察窗内各只有两个合法 Appeal B 槽。M2 在第二次漏选后才入队，截尾时下一次 due 分别为 T10、T9、T10，均未在原八窗执行。这不是 FIFO 违规。原保存的只读分析见 [基线机会审计](../../tools/startup-balance/opportunity-audit.json)。

第二轮只将 M2 改为 M1，原四回合 cadence、冷却、展示容量、固定池、回应和人物名额均保持。seed 3 / 4 分别在 T6 / T7 实际回应新的 PR08，随后灾变；恢复机会与结果成功是两回事。

seed 1 的 [只读审计](../../tools/startup-balance/calibration-opportunity-audit.json) 显示：T2 普通选源产生 Pact，Appeal 取得 queue 8；T6 它是 FIFO 首位，实际形成 call `FACT-00000326`、来源 `FACT-00000327` 和 fixed `FACT-00000328`，请求 `BACKGROUND-00000008`，visible T7 / due T9，原债已清。原 T8/between 自动档中它仍 open，三张 offered 是 `BACKGROUND-00000003/4/5`，旧牌占位而本样本策略未处理这些牌。T7–T8 没有第二个合法 offeredContact，不能把这条在原八窗内记作已可行动恢复，也不能再称来源缺失或 FIFO 饿死。后续TASK-NATURAL-VERIFY实际从该自动档推进，在T9/actions观察到BACKGROUND-00000008进入展示列表；固定最旧牌策略选择其他请求，目标未回应到期。此补验未单独预览/回应目标，也不构成一般等待上界证明。

本次小型核心使用生产 SourcePolicy 和 11 个给定消费者选项。真实 CSV 的 I=4、M=1、Q≤11 推导出 **I×(M+Q)≤48 回合**；核权重、有限 FIFO、冷却、强制分支不多抽 RNG、非到期不变及未知根拒绝。它只验证冷却已结束且持续合法前提下的来源选取条件界，选项不是完整世界生产者，48 不代表展示回应截止、首团节奏或胜率。

原两条验收允许保留失败及截尾并解释原因，不要求每个样本在八窗内完成。Design / QA 以此接受限定通过；没有为了通过而挤入第四张牌、降低骰子或补钱。更广自然策略与展示交接体验继续由原 `TASK-NATURAL-VERIFY`、`TASK-UI` 承接，真人体验未代验。

## 原来源遗漏的独立修复证据

原 private devotion 先要求旧 `member_dedication`，而旧事实的唯一 writer 为成功 PR08，错误堵住了原设计的 Dream 知情后当次献身路线。现由同一正式 prepare 核实际已知、存活、未绑定、忠诚至少 40 的人物，使用真实身份来源，在本次 route attempt 下写献身事实，再走原 membership / Attention；不全局放宽 Cults。已绑定人物保留原行为，不受新增申请人的忠诚门槛误伤。Endings 使用相同 prepare，并保留合法跨域身份来源及历史检查。

独立初始祈求事务还漏掉了原 PlayerSources.refresh，现于 fixed 之后、knowledge 之前处理本事务真实新 fact 范围，保留原验证和回滚。未改 selector 的授权或知情门槛。

`baseline-02/core.json` 的 `STARTUP-PRIVATE-SOURCE` 独立功能例不先成功回应 PR08：真实两次 deep Dream，各付 2 信仰，实际取得资格后由公开 selector / preview / command 完成当次私祷献身及原入团，再执行原 4 信仰聚会并产生 3 信众。该例明确控制结果，不计自然成功率，未注入人口、资源或成员身份。后来仅补已绑定低忠诚兼容分支；原六自然路径没有进入该分支，不能声称旧自然样本以最后源码执行。该差异有 `bound-compat-01` 当前解析 / 原生启动证据及静态分支复核，最终 M1 六自然使用当前三份生产源码。

## 运行账本与版本边界

| 原批次 | 真实状态 / 墙时 | 证据范围 |
| --- | --- | --- |
| baseline-01 | **失败**，8.741 秒 | 功能前提失败：`Actual dreams did not create an eligible unbound known person`。暴露 bootstrap 漏刷新；无自然样本执行。 |
| baseline-02 | 通过，36.259 秒 | 解析、独立受控来源功能例、六条 M2 自然路径、原生启动；无引擎 ERROR / 输入漂移。 |
| bound-compat-01 | 通过，3.951 秒 | 已绑定兼容修正后的解析 / 原生启动，未重跑六条自然路径。 |
| calibration-02 | **整批失败**，35.703 秒 | M1 六自然核心实际通过，32.054 秒；随后 FIFO wrapper 误从 Catalog 读 cadence，虽 exit 0 仍有 SCRIPT ERROR，driver 正确判失败并未执行 startup。 |
| fifo-finish-01 | 通过，3.832 秒 | 新接管实现仅修 wrapper 读取生产 AbstractSim 参数；FIFO 解析 0.846、核心 0.932、原生启动 2.044 秒，60 秒批次上限，无 ERROR / 漂移。未重六自然或功能例。 |

前实现者累计两次机器失败后停止，交独立接管者完成；所有原失败 raw 与 execution 状态保留，未以 exit 0 或 passing core 改写整批失败。本 Godot 项目没有 npm / TypeScript / lint 流水线，本任务使用原生 GDScript 解析、有限既有核心及实际启动；Python driver 语法与改动空白检查通过。没有旧矩阵、成熟整局或 UI 重跑。

各批次 `input-sha256.json` 固定其实际运行输入。`executed-source/baseline-02` 与 `executed-data/baseline-02` 保存基线旧源码 / wrapper / M2 参数；该轮 96 输入与当前的四处差异都能对应原字节。`executed-source/calibration-02` 保存修 FIFO 前的八份关键输入，该轮 97 输入与当前仅 fifo / verify 两差异，均匹配原归档。`fifo-finish-01` 的 97 输入与当前一致。最终 actual 分别绑定这些 manifest、raw、样本保存及归档，不将历史执行哈希覆盖成当前。

**旧 M2 存档（包括先前成熟世界快照）不能直接继续当前 M1。** 现有 Catalog 参数内容摘要参与 Dispatch / Opportunities 版本，World / Turn / Session 的原兼容检查拒绝数值版本不匹配；本项没有迁移或保存矩阵。旧完整续存 / source-closure 报告仅按原历史范围复用，不改原报告或暗示旧快照今天可直接续玩。当前适用性差分由独立 QA 另签。
