# 游戏全貌索引与制作人工作台

这是现有策划的导航层，用稳定编号建立共同语言。完整规则仍以 [GDD](../gdd-core.md)、各系统 spec 和 `data/*.csv` 为准；索引摘要不能取代它们。

## 文件职责

- `atlas.json`：覆盖域、已确认的方向、索引文件与扫描范围。
- `features/core.json`：游戏能力的编号、摘要、状态、来源、依赖、证据及制作人应留意的取舍。`producer` 字段只用于阅读，不是运行规则。
- `relationships.json`：有方向、有解释、有来源的策划关系。不是程序调用图；也不同于 `dependsOn` 的真正能力依赖。
- `paths.json`：沿真实关系组织的阅读路线。每步有对应机制；不得标成已验证的游玩结果。
- `phases.json`：回合 spec 的分阶段阅读摘要。
- `evidence.json`：既有证据的版本、范围与限制，不因新图发布而升格。
- `feedback.json`：生产者与协作者的讨论记录；归档保留，不混入正式规则。
- `snapshot.json`：来源指纹基线，不含“好玩/已实现”的认定。
- `INDEX.md`：生成的低成本文本入口，供后续 AI 会话阅读。
- `terminal.html`：可丢弃的完整离线工作台快照，不手工编辑。
- `atlas.html`：文本索引默认链接的兼容入口，转到同一份 `terminal.html`。
- `../implementation/traceability.json`：关键行为、结算约定、开发任务和验收场景的单一登记源。运行证据由追踪器按当前文件哈希计算适用性，不能手工写一个绿色状态替代。

## 稳定定位

`MECH-*` 指能力，`REL-*` 指一条作用关系，`DATA-表名/行编号` 指 CSV 定义，`DISC-*` 指讨论。改标题不改编号；拆分或退役保留旧编号的去向。永久删除对象前必须迁移相关讨论，不能让已有沟通无声失去目标。

`REQ-* / SET-* / TASK-* / ACC-*` 分别定位关键行为、结算约定、开发任务和验收。它们同样支持讨论与深链接；来源绑定、影响分析、任务前置和缺口规则见 [实施保障](../implementation/README.md)。

例：讨论“绑定的圣物被扣押后发生什么”，可以引用 `REL-035`、`MECH-RELICS`、`MECH-ANCHORS`，而不必靠某份文档的页码。

## 后续每轮维护

1. 开工先检查是否漂移，读 `INDEX.md` 和本次机制的权威来源；再读相关讨论。此次工作台搭建未改变框架路由。
   同时运行 `python3 tools/implementation/check.py --impact MECH-…`，取得具体要求、下游回归与前置来源；任务状态和实际证据分别核对。
2. 新增或修改方案必须当轮同步开发计划（DEC-017），即使该轮只做设计：更新 REQ／SET／TASK／ACC、前置与下游、任务书和当前路线，并完成 `planBindings` 的版本与影响复核。改规则仍原地改对应 spec/CSV，对照关系图检查输入、输出、失败后果、时序和关联能力；同步受到影响的索引摘要，数值不在索引复制一套。
3. 新增内容表或能力时登记来源与稳定编号。实现状态与证据分别更新；只有真实接入和运行证据才能支持相应结论。
4. 核对完成后建立基线、运行检查，再刷新文本和离线页。基线仅表示已复核这些文件，不能消除仍存在的未知。

本机的 `game-state` 工具命令：

```sh
node /Users/yilungao/.codex/skills/game-state/scripts/game-state.mjs check --root .
node /Users/yilungao/.codex/skills/game-state/scripts/game-state.mjs impact --root . --feature MECH-ANCHORS
# 只有语义复核完成后才执行以下三步：
node /Users/yilungao/.codex/skills/game-state/scripts/game-state.mjs baseline --root . --reviewed
node /Users/yilungao/.codex/skills/game-state/scripts/game-state.mjs render --root . --index-only
python3 tools/producer-console/build.py
```

工具路径属于本机环境；迁移设备时使用该设备安装的 `game-state` skill 路径。工作台本身只需要项目文件与 Python，日常阅读和保存讨论不依赖这个外部路径。

本地版在打开或“更新来源”时读取文件，不运行后台监控。基线之后变化的来源、索引或新出现未登记的 CSV 会显示待复核。离线版只反映生成时刻，应连同版本一起引用。指纹相同只证明文件没变，不证明语义正确。

运行与协作方式见 [工作台说明](../../tools/producer-console/README.md)。
