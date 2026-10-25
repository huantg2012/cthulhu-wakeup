# Godot 技术可行性验证

这是独立的无界面验证工程，验证文明生成、状态演化、因果事件、随机复现和存档边界。它不是正式游戏，也不是被作者跳过的短体验阶段。没有正式经济、完整权能、胜负、卡牌界面或美术资产。

## 运行

在仓库根目录执行：

```sh
python3 tools/feasibility-godot/verify.py
```

默认使用本机 `/Applications/Godot.app/Contents/MacOS/Godot`；其他位置用 `--godot /absolute/path/to/godot`。依赖 Python 3 标准库和 Godot 4.7.2，本次没有安装额外包。直接底层命令为：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path tools/feasibility-godot --script run.gd
```

交付检查使用 `verify.py`：它额外排除 Godot 脚本报错却退出 0 的情况，检查报告是否本次新生成，并写入源文件 SHA-256。任何实际测试失败都会退出非零。

## 数据和证据

- `data/feasibility_*.csv` 是本工具的策划夹具来源，与正式策划数据分开命名，不能作为正式平衡参数使用。
- `catalog.gd` 检查列、类型、范围、引用、维度完整性、事件后继循环和效果白名单；不执行内容中的任意代码。
- `simulation.gd` 负责持久 ID、纯数据状态、三个随机流、调度与精确存档。
- `run.gd` 执行固定坏输入、生成、因果、死亡、存档续跑和压力场景。
- 原始结果：`docs/qa/technical-feasibility-results.json`；解释及范围：`docs/qa/technical-feasibility.md`。
- 本机运行日志和一次磁盘存档在 `outputs/`（已忽略）；Godot 导入缓存也忽略。

## 证据边界

压测驱动自动选择干预或遮蔽，让人物在千回合内存活并持续产生事件，避免以全部人口死亡后的空转低估负载。该驱动是技术负载，不是已证明的通关策略。生成的 604 等组合数量也不是叙事品质或正式内容量的证明，以最新报告为准。

每回合检查资源与四个文明指标范围，每 50 回合及最终状态执行完整引用检查。保存全量因果骨架，旧显示细节可压缩；这不等于无限时长常量内存。跨平台/引擎版本重放、正式导出、完整性能、美术替换和玩家乐趣均未在本工具中验收。
