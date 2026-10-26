# 事务差分与对抗验证

运行 `python3 tools/incremental-tx/verify.py`。需要 Godot 4.7.2 和本地 Git 对象 `bdc31eb56c5551333db364da9fd654c9fae746b7`，可用 `--godot` 指定可执行文件。

包装器从 Git 导出固定旧版本到临时目录，将**同一份** `replay.gd` 分别运行在旧版与当前生产代码；逐请求比较全部世界字段、随机、统计、上下文与响应。测试不会维护第二份世界实现，也不会把新代码自重放当作旧新等价。报告保存驱动、Git archive、两条轨迹和当前来源的 SHA-256。

`run.gd` 独立构造合并后违法、失败回滚、读视图隔离、预览、读档全量审计等反例。场景适配器不是正式权能/事件内容。测试的受限参与者只读当前投影和明确来源，不能据此要求生产接口重新开放全部历史。

报告位于 `docs/qa/incremental-tx-results.json` 与 `incremental-tx.md`。源文件执行期间变化、Godot 错误、重复检查编号、缺少新报告或任一失败均使包装器退出非零。历史索引另见 `tools/history-index/README.md`；剩余原生历史根浅复制/身份核对与完整保存成本归 TASK-ARCHIVE-SAVE。
