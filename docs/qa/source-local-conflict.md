# TASK-SOURCE-LOCAL-CONFLICT — Current Dispute, Investigation, and Seizure Notice Sources

当前回归说明（2026-10-30）：共享记忆来源接入后，本族原四组已真实重跑通过；当前绑定证据为`docs/qa/source-memory-results.json`。下文6.37秒及原报告保留为历史，不重签。

状态：本族限定验收完成，2026-10-30。不是完整新局通过。

## 本次交付

PR02/PR10争议、PR03追查和PR11索回接入已有正式抽签、准入、回应与保存入口。背景一次生成，不先运行社交、取证或传话过程。

- 争议按当前人物诉求与局势固定双方、缘由、默认立场及一种诉求。无需同机构或已有rival边；同次争议不能换一种诉求再次领收益。PR02浅回应实际产生秘密证言并增加忠诚。
- PR10在选择前固定对手与另一真实人物的秘密背景，第三人纳入参与者与容量，不额外建立长期关系边。回应实际揭示该指定秘密，不写成祈求人不知道自己签过的协议。成功关闭本次请求与危机，保留历史根，供后续EVENT09引用。
- PR03只从秩序机构实际知晓、未失效且指向该人物的暴露生成追查。浅回应结束本次追查，原公开暴露不撤销；深回应只有确有对应长期边时才沿原关系入口退役，不把场景标签当关系边。已预告抵抗不由此取消。
- PR11只从实际seized实例及seize事实中的previous_holder产生索回通知。深回应打开原实例的恢复机会，圣物仍处于被夺状态，不直接复制或移回。

复用Sources的展示/主体名额预检。新增本族权重1、冷却3轮，均在CSV；总体ambient概率与原回应费用不改。状态只增加必要的当前情境和已用扣押记录，记录固定对象/期限与一次关闭，不新增调查员生活或法律模拟。

## 核心检查

最终冻结代码运行6.37秒、退出0，4组本族与3组PR01直接回归共7/7通过。

| 检查 | 实际结论 |
| --- | --- |
| SLC-PRAYER_02 | 正式抽签到可回应窗口；秘密证言1条、忠诚按原规则增加；固定状态保存恢复；重复回应被拒、信仰不再扣除。 |
| SLC-PRAYER_10 | 对手与第三人的秘密在选择前固定并实际揭示；历史根可被真实future_callback生成的EVENT09描述引用，选项B合法；重复回应被拒。 |
| SLC-PRAYER_03 | 实际暴露前提下生成追查，浅回应结束本次追查，原exposure仍有效；保存及重复消费控制通过。 |
| SLC-PRAYER_11 | 从真实Relics.seize后的原持有人生成索回，深回应只开该实例的恢复机会；保存及重复消费控制通过。 |
| SLT-EXPIRY / SLT-RESCUE / SLT-CAPACITY | 上轮PR01三组在当前共享源码下真实重跑通过，原期限/一次死亡/救治/名额不足不产生隐藏危机的断言保留。 |

命令：

```powershell
& 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --log-file D:/code/cthulhu-wakeup/tools/prayer-producers/local-conflict-engine.log --script res://tools/prayer-producers/local-conflict.gd -- D:/code/cthulhu-wakeup/tools/prayer-producers/local-conflict-results.json
```

四次REQUEST_REJECTED来自故意重复回应的检查，是预期拒绝。仍有Windows证书存储环境ERROR，无最终GDScript错误，不称零引擎错误。

## 修正与证据边界

首批4.90秒失败源于测试在bootstrap前预测候选人物，而bootstrap会产生额外合法人物；修正为明确的合法输入准备，未注入目标情境或呼求。第二批5.45秒虽7组通过，父审发现PR10成功误撤根会阻断EVENT09；修复后在原PR10组增加真实回调描述/B合法断言，再做上述6.37秒短跑。首批及回调修复前输出分别保留，均不作为当前验收证据。

初始前提：PR02经原人口/准入提名一名记录者；PR10用实际status命令限制初始recognition角色，再通过纯hash预测少量调查者初始提名；PR03准备一条正式暴露并交给秩序机构；PR11准备既有携带实例后走实际seize。它们是受控前提，不证明自然频率。普通World/Turn/Prayers校验保持启用，兼容夹具只处理既有独立提名预算入口，拒绝开关关闭。

权威规则为事件§14.5/§14.9和DEC-026，覆盖旧的同机构/关系证明/传话门槛。本次复核正式生产、消费、隐匿与历史分离、第三人秘密语义、一次消费和相关回调接口。没有新增待制作人裁决的玩法选择。

绑定报告：`docs/qa/source-local-conflict-results.json`；原始输出与执行记录分别为同目录`source-local-conflict-runtime-results.json`、`source-local-conflict-execution.json`。旧PR01报告保留历史，追踪登记换绑本轮实际回归。

## 未交付边界

EVENT09选项A实际材料交付仍由TASK-MATERIAL-TRANSFER负责，本次只证明回调可引用的历史材料和B合法。没有验完所有深浅分支、默认到期组合、完整Session、自然新局或整体平衡；不据此恢复旧全量矩阵。

下一项：TASK-SOURCE-MEMORY — Shared Experience and Memory Risk Sources。TASK-ART和TASK-RELEASE继续锁定，原两个实际阻塞保持。
