# 分层规则静态验收

`python3 tools/fidelity-rules/verify.py` 校验正式参数、全入口分类、默认后果容量、生产责任，并执行针对坏配置的反例。生成 `docs/qa/fidelity-rules-results.json`，绑定实际读取的 CSV、五系统 spec、架构、任务书及检查工具 SHA-256。

这是 TASK-FIDELITY-RULES 的配置证据，**没有运行分层模拟**。规则语义审查另在 `docs/qa/fidelity-rules-review.md` 逐项记载；其结论与自动配置检查分别绑定到验收。N/P 双满的离团、模式切换、随机预留和恢复必须由 TASK-ATTENTION 等任务实际运行，静态通过不能代勾。

修改范围或预算时先改所属 CSV/spec，同轮更新任务与验收。检查器的枚举定义协议合法形状，不保存第二份数值。新增权能/祈求/事件未登记分类会失败；未来 Godot loader 接入时沿相同约束另验实际拒绝和原子性，不能把 Python 检查当运行时已经拒绝。
