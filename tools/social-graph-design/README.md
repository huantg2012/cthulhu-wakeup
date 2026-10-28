# 关系图设计数据检查

运行 `python tools/social-graph-design/verify.py`。

检查正式CSV的形状、参数界限、类型引用/方向与幂等、初始关系归属、PR02到期效果和旧参数兼容标记。另枚举六节点的有限组合，检查预算是否容许分支、三角、跨机构联系与不同度数同时成立；结果中的人物是标明蓝本的设计符号，不是正式初始化、已参加共同读取或取得知识的游戏事实。

它不复刻World生成算法，不测试权重、固定种子统计、来源/回应/回调或存档，也不证明自然出现概率。固定种子指标由TASK-SOCIAL-GRAPH在正式实现后实测。新CSV当前未装载，根归属更改还需Catalog grammar适配；完整Session另有CULT兼容阻塞。设计语义由独立静态审查负责，报告在 `docs/qa/social-graph-design.md`。
