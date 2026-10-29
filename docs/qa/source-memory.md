# TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources

状态：本族限定验收完成，2026-10-30。没有新增祈求类型，不代表完整新局通过。

## 做成了什么

PR07共同见闻和记忆风险由一次情境抽签生成，固定真实参加者、必要背景和原期限；无需同机构、既有长期关系边或逐人阅读/传话链。仅保存本次重要状态，不增加社会记忆传播系统。

祈求人之外有一名合适参加者即可浅回应，深回应需三名不同参加者：浅情境共两人，深情境共四人。人数或容量不足时可降为一名的浅情境，不能为了深分支把所有浅情境都挡住。普通见闻不是神迹；实际回应成功后才生成memory_preserved资格，浅一份、深三份。审查只撤选定的一份资格，不抹人物私人知识。

实际schema：shared_observation一次记录participants和普通背景；memory_at_risk记录原memory、holders、due、scene_rule及snapshot。场景内relations引用本次risk，不新建永久SocialGraph边。沿既有situations、回应和期限结算；关闭风险仍保留原见闻供EVENT06引用。CSV新增memory_scene_weight=1、memory_scene_cooldown=3，总体概率和费用不改。

## 实际核心检查

最终冻结代码单次定向运行：8.40秒、退出0，3组本族+7组直接回归共10/10通过。

| 检查 | 实际结果 |
| --- | --- |
| SM-SHALLOW | 祈求人之外只有一名参加者时正式生成并可浅回应，深回应不可用；成功产生一份资格，固定状态保存恢复，重复回应拒绝且不重复扣费。 |
| SM-DEEP | 三名参加者实际产生三份资格；真实执行EVENT06 B后，只有选定资格失效，另外两份、原见闻及代表性本地/远端私人知识保留。 |
| SM-EXPIRY | 放任到期只登记本次三名未保参加者的资格丢失，不产生保留资格；原见闻和私人知识仍在。 |
| SLT三组 / SLC四组 | PR01救援及上一任务四类冲突来源，在当前共享代码下实际重跑通过，旧断言保留。 |

三组均走正式抽签、候选与回应/到期，生成时没有资格，也未将普通见闻识别为实际神迹材料。控制的是随机输入及初始前提，没有注入目标见闻、祈求、资格或事件结果。

命令：

```powershell
& 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --log-file D:/code/cthulhu-wakeup/tools/prayer-producers/source-memory-engine.log --script res://tools/prayer-producers/source-memory.gd -- D:/code/cthulhu-wakeup/tools/prayer-producers/source-memory-results.json
```

## 两次失败与独立复核

第一次5.55秒失败：夹具错误假设远端域已有具名人物，改为原人口/准入入口提名一位远端记录者。第二次7.27秒为9/10通过：浅例在bootstrap前预测候选池，开局新增记录者后候选池改变，未抽中记忆情境。

按两败停止规则暂停修改和运行。主会话独立读取初始化、候选选择及浅例前提：只留下judgment角色仍会因第三人加入才形成争议而改变候选池。重做为实际提名/选择recognition记录者与原messenger，其他人实际置detained，使bootstrap前后root类别稳定，活动人数仍不足四人。随后只做一次定向验证，原断言不减、生产代码和概率不改。Codex没有因此宣称实际模型档位切换。

两次失败JSON和执行记录均保留；只有最终8.40秒运行绑定当前代码。启动仍有Windows证书存储环境ERROR，无最终脚本错误。兼容夹具只处理既有独立提名预算入口，普通World/Turn/Prayers校验保持启用。

## 边界与后续

只验证上述代表例，没有穷举所有分支、人数/文明组合或自然频率，不以工具通过证明好玩。目标机构实际取得材料、八文明锚点、完整Session兼容与自然新局仍由原任务实现；人物拥有资格不等于机构已经收到。视听与发布继续锁定，原两个实际阻塞保持。

证据：`docs/qa/source-memory-results.json`；原始输出为`source-memory-runtime-results.json`，执行记录为`source-memory-execution.json`。旧来源报告不重签，当前追踪指向本轮实际回归。

下一项：TASK-SOURCE-EXCEPTION — Current Anomaly Observation Sources。
