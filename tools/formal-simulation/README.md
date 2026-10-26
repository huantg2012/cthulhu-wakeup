# 正式 NPC／文明规则验证

本入口运行 `src/simulation/` 中的正式纯数据规则核心，读取项目正式 CSV；不读取 `feasibility_*.csv`，不替换此前的 28 项底层技术报告。它是正式实施和规则验收的一部分，不设置短体验前置阶段。

在仓库根运行：

```sh
python3 tools/formal-simulation/verify.py
```

默认引擎为 `/Applications/Godot.app/Contents/MacOS/Godot`；其他位置用 `--godot`。Python 只使用标准库。包装器检查实际 Godot 退出、脚本错误、报告新鲜度及执行期间来源未变，之后写入逐文件 SHA-256。结果在 `docs/qa/formal-simulation-results.json`；日志在本目录忽略的 `outputs/run.log`。

可单独检查 GDScript 编译：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script tools/formal-simulation/run.gd
```

本项目没有 npm 工程；Godot 编译、真实无界面执行、边界和回放测试是对应的机器检查。未执行 Web 游戏 tsc／npm dev，也不把它们列为通过。

## 模块边界

- `catalog.gd`：事务式读取正式人物、行为、文明蓝本、文明条件、抵抗与参数表；非法字段、参数或引用不替换旧目录。
- `world.gd`：生成持久身份与合法岗位；统一四属性检定；四种人物自主行为；已知证据驱动的六种抵抗资格及结构化效果；人口、生命周期、因果与保存。
- `run.gd`：使用可控起点检查边界与单变量对照，用多种子跑自然及持续活动负载。测试场景的指定状态不是新的默认游戏数据。

独立核心验证使用 `begin_turn()` 处理轮初到期事实和继任后刷新低语；上游正式行动成功后调用 `mark_player_task()`；`evolve()` 处理本轮自主演化。`advance()` 是独立验证中没有玩家行动时的便捷组合。正式统一回合由 `src/game/turn.gd` 接管，接管后不能直接调用这些方法绕过阶段；六阶段接线、事务和阶段续存另由 `tools/turn-cycle/` 验证。

`submit()` 的死亡、拘禁、迁移等是已经获准的规则效果入口。`introduce_fact()`、`succeed_institution()`、`confirm_exception()` 用于接收其他系统已合法结算的事实与显式授权。它们不提供免费玩家按钮，不替代祈求、权能、EVENT_04／EVENT_11 的费用与全部资格实现。身份与机构的授权来源只能应用一次。

历史事实只追加，不回写。演化复制当前可变对象与计划；知情、成长和消费来源等冷集合共享不可变持久树，通过 HistoryIndex.has/size 和有限查询读取。显式完整检查使用 HistoryIndex.values 或 World.snapshot 展开，避免把内部历史引用误当原生 Array。行为全部在批次落地前选完，新事实不能进入当前批次候选。程序适配层不得绕过规则入口直接修改世界；测试用明确起点构造异常和临界场景。

## 证据边界

机器报告逐项给出稳定 SIM 编号、结果和来源哈希，供项目追踪清单引用。单元场景中的六种抵抗效果通过，不表示完整事件交互、全部权能、教团经济、锚点创建维护或终局已经接入。

自然运行不注入玩家行为，允许平稳与静默。活动运行的外部事实驱动保持真实状态更新与持续候选，不治疗或复活人物；它不代表合法玩家策略或平衡实验。报告单列每 50 轮行为/更新计数，防止以后把后半段空转当负载结果。

性能只有当前机器、引擎版本、内容和所测范围的意义。完整历史仍增长，保存仍全量；没有声称跨平台重放、断电恢复、版本迁移或无限战役已经完成。详见 [实测记录](../../docs/qa/formal-simulation.md)。
