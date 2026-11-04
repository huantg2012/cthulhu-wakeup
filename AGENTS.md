# Codex / Cursor / 通用 Agent 入口

**项目执行标准的唯一正文是 `CLAUDE.md`。** 本文件是 Cursor 侧钩子，不复制那份全文。开工先读 `CLAUDE.md`（阶段、硬约束、路由），细节按 L1/L2 再读 spec。

自定义 agent 定义：`.cursor/agents/`（与 `.claude/agents/` 正文逐字一致，仅 `model` 可不同）。Codex 原生定义在 `.codex/agents/*.toml`，由 Claude 正文生成；模型继承父会话/运行时默认配置。人的操作入口：`START-HERE.md`。

## 硬约束（不读 CLAUDE.md 也必须遵守）

1. **双层不混**：改框架（agents / guides / CLAUDE.md）与做游戏（`docs/**` / `src/**`）是两块独立工作。框架改动先上 `master`，再合并到游戏分支。
2. **游戏 UI 必走开工路由。** 设计、样板打磨、正式功能接入、修改或审查时，先按 [CLAUDE.md 的 UI 开工路由](CLAUDE.md#ui-task-routing) 查当前分支 `docs/progress/stage-priorities.md` 的「游戏 UI 执行路由」及持续禁令。父 agent 传递适用规范和验收，接手 agent 读取同一正文。
3. **策划数据 CSV → code**（`data/*.csv`），禁止在代码里手写物品/敌人/技能数据再反向导出。系统常量除外。
4. **一个逻辑系统 = 一个 spec，原地更新。** Git 管历史。
5. **探索策略按"一次评估要多久"选，不按任务重不重要**（宽抽窄迭）。抽卡（并行低保真候选 + 人挑）破框；迭代守方向。**写不出可否证的验收句 = 还在找方向 = 该抽，不该进正式迭代**（唯一转折判据）。先验偏斜维度（in-game UI 首当其冲）必须先钉具名参考 + 禁令再采样，否则得到同一个错答案的 N 份副本。数值/经济/系统组合禁止开并行候选。有效结果当场落成耐用件（数值+推导 / 禁令 / 参考锚点），否则这轮作废。**禁止 agent 自评"抽中了 / 已收敛"**；无判据的维度不许用 loop 假装验证过。
6. **框架内路由不用 Cursor Auto**；按具名 agent 派发。模型档位见 `CLAUDE.md`。
7. 改 agent 定义后先跑 `node tools/agent-parity/sync-codex.mjs --write`，再跑 `node tools/agent-parity/check.mjs`（含 Codex 同步校验）。

游戏分支的进度以该分支 `CLAUDE.md`「当前阶段」和 `docs/progress/roadmap.md` 为准。
