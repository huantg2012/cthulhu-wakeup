## QA Report: TASK-CATALOG — Formal Simulation Content Loading and World Generation
日期：2026-10-31
Spec：system-civilizations.md §2–4；system-powers-cults.md 人物生成与人口口径。
代码：机器报告 sourceHashes；原 3 ACC 的 given/when/then 逐字保留。

结论：本次限定范围 3 ACC 通过。真实执行 formal-02 共 6.362 秒，定向解析、核心 28 条断言、短 headless 启动均通过。完整编辑器导入未通过。

### 发现的问题

| ID | 类型 | 严重度 | 描述 | 位置 | Spec 依据 |
| -- | ---- | ------ | ---- | ---- | --------- |
| CAT-IMPORT | 环境/工具失败 | Medium | formal-01 编辑器全仓 CSV 导入以 0xC0000374 崩溃，未执行核心；保留原 raw。仅修正为定向解析后 formal-02 通过，不能称全项目编辑器构建通过。 | outputs/formal-01/execution.json | 构建验证 |
| CAT-DIAGNOSTIC-ALIAS | 工具证据限制 | Low | 坏目录 errors 数组被后续重装清空，最终 payload 不保留具体错误文本；执行时明确非空、非 Missing CSV、原子不变断言均通过。没有为补诊断再跑。 | tools/catalog-current/run.gd `_bad_catalog` | ACC-CATALOG 明确拒绝 |

### 通过的检查

- CAT-CATALOG：当前完整 42 表目录装载，原十表齐全；字段缺失、坏引用、零除数三副本均拒绝，tables/parameters/version/extension_versions 不变，修复副本重装一致。
- CAT-WORLD：种子 200/201 各 12 域、72 人、36 机构，6/4/2 配额，合法人物岗位，双向通路可达及引用校验；具名不增加总人口。保留无灾难/听众不能凭空授职的两项反证。
- CAT-BOUND：脱离目录移除 cosmic 蓝本，一次 generate 明确返回 No authored civilization for tier cosmic；旧 snapshot（含 RNG）与约束目录不变。实际失败调用及快照核对约 46ms；源码 recipe 为固定有限枚举，无无限重试。
- 独立复核全部本次 source/artifact 哈希、执行前后无漂移，scenario 快照与原登记逐字一致。

### 建议与范围

保留编辑器导入失败供后续环境排查；下次涉及工具再深复制错误诊断。此次没有修改 src/data/spec，没有运行历史 32 seed、全矩阵、长跑或完整游戏。原 39 已验收及自然链 2 partial 保留原结论；适用性差分另见 catalog-current-review-results.json。

机器证据：[catalog-current-results.json](catalog-current-results.json)。原始执行：[execution.json](../../tools/catalog-current/outputs/formal-02/execution.json)。
