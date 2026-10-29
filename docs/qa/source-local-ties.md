# TASK-SOURCE-LOCAL-TIES — Current Incident and Kinship Prayer Sources

状态：本族限定验收完成，2026-10-30。不是完整新局通过。

## 做成了什么

PR01现在通过少量条件下的抽签产生亲属求援情境。一次固定祈求人、受助者和期限；玩家回应或放任到期后，实际处理本次受助者。没有既有family边也能生成本次亲属背景，不先模拟职业活动、事故、伤害或传话。背景只用于本次求援，不另建永久亲属边，不覆写已有身份与死亡。

复用原Events抽签、名额准入、Prayers回应及费用。新增CSV参数：本族相对权重1、冷却3轮；总体ambient抽中概率和原费用不改。下一轮展示卡位不足、主体名额不足或对象不可用时不承诺新致死情境。

实际状态：prayer_sources(schema=2)保存open情境及域cooldowns；一条dying_condition记录rule=kinship_rescue_scene、patient、petitioner、relationship、due、snapshot、version。没有既有亲属边时condition与relation指向同一情境，已有合法关系可沿原来源。该标签不使其他人自动获知，也不授予邪神身份知识。救治或期限关闭该情境一次，事实保留在原历史中。

## 实际检查

最终冻结代码短批次：3.70秒、退出码0、3/3通过。正式CSV加载包含在该运行中。

| 检查 | 实际结果 |
| --- | --- |
| SLT-EXPIRY | 没有family边仍经正式抽签、候选固定并于下一轮展示；Turn保存恢复对象/期限一致；到期受助者死亡一次、情境关闭一次。 |
| SLT-RESCUE | 沿正式浅回应检定成功救治；超过原期限后受助者仍存活，死亡0次、关闭1次。 |
| SLT-CAPACITY | 展示名额满时抽中本族仍被阻断，新致死情境0条。 |

命令：

```powershell
& 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --log-file D:/code/cthulhu-wakeup/tools/prayer-producers/local-ties-engine.log --script res://tools/prayer-producers/local-ties.gd -- D:/code/cthulhu-wakeup/tools/prayer-producers/local-ties-results.json
```

另做根工程两帧加载冒烟，退出0；它不是完整Session可玩验收。启动仍报Windows证书存储环境ERROR，最终没有GDScript错误，不能称零引擎错误。第一次行为运行发现typed Array运行分支不兼容及容量夹具时序错误，修正后重跑上述短例；首批失败输出另存，不算通过。

证据：`docs/qa/source-local-ties-results.json`绑定规则、CSV、执行源码、测试依赖和实际输出；原始结果、执行命令、首批失败分别见同目录source-local-ties-runtime-results.json、source-local-ties-execution.json、source-local-ties-first-failed-results.json。旧精细事故失败报告及工具保留，未用作本次通过证据。

## 设计和实现复核

本次执行现有事件规则§14.5/DEC-026，覆盖旧PR01通用family边及微观前因门槛；未新增独立系统或修改已确认核心玩法。检查了正式Events/Dispatch选源与Prayers消费接线、容量预检、关系背景不持久扩张、原期限、关闭一次及保存引用。未发现需要制作人新增裁决的路线问题。

测试复用Support.CompatibleWorld与既有Turn帮助入口，普通World校验保持启用、拒绝开关关闭。只控制生成和回应的随机输入；容量例用其他知识请求作前提，不注入目标求援/呼求/结果。没有运行旧完整矩阵或搜索数百个完整世界种子。

## 未交付边界与后续

其他来源族、必要机会调度、首个教团平衡、完整Session兼容与自然新局继续原任务。本族Turn保存检查不代表完整Session兼容通过；自然发生率、深回应所有分支和玩家体验不由本次3例证明。原两个实际阻塞保持。

下一项：TASK-SOURCE-LOCAL-CONFLICT — Current Dispute, Investigation, and Seizure Notice Sources。

TASK-ART — Production Visual and Audio Asset Integration、TASK-RELEASE — Release Reliability继续锁定。
