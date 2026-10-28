# 本轮调度诊断与最终证据

原始失败与编写期输出保留。每份结果的源码指纹只对应该次运行；不得把早期行为通过、包装失败或缺日志的诊断当作正式验收。

最终采用：`dispatch-20261028T091129Z-c187353f/results.json`（55行为+5包装），以及 `../../prayer-knowledge/runs/knowledge-20261028T091042Z-4c911956/results.json`（72+5）。源码/产物在收尾均核对，无ERROR。

| 本轮调度目录 | 实际整体结果 | 检查数 |
| --- | --- | --- |
| [dispatch-20261028T084640Z-37fa5c13](dispatch-20261028T084640Z-37fa5c13/results.json) | fail | 24 |
| [dispatch-20261028T085221Z-95b7c56b](dispatch-20261028T085221Z-95b7c56b/results.json) | fail | 29 |
| [dispatch-20261028T085247Z-2ce35ce8](dispatch-20261028T085247Z-2ce35ce8/results.json) | fail | 32 |
| [dispatch-20261028T085721Z-3a72bc73](dispatch-20261028T085721Z-3a72bc73/results.json) | fail | 32 |
| [dispatch-20261028T090037Z-6cd7dfb0](dispatch-20261028T090037Z-6cd7dfb0/results.json) | fail | 57 |
| [dispatch-20261028T090634Z-ea643042](dispatch-20261028T090634Z-ea643042/results.json) | pass | 60 |
| [dispatch-20261028T091129Z-c187353f](dispatch-20261028T091129Z-c187353f/results.json) | pass | 60 |

`code-direct-20261028T0847Z/raw-misrouted.json`为早期命令参数误用产生的原始输出，无完整包装/日志，不作验收。

四次知晓重跑的原始档案保存在`tools/prayer-knowledge/runs/knowledge-20261028T09*`。090038与090444为development诊断；090543为架构状态句更正前的正式回归；091042为最终同源正式回归。旧原结果不覆写。

`fixture-cleanup.json`记录本轮在.godot内精确清理的可重建坏表副本，不含raw/log/已哈希产物。

本批修复调度与首名成员消费；原根到新call、bootstrap完整准入、四格/行动窗/最小投影、完整Session和自然发展未通过。
