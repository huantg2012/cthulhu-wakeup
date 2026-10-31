# TASK-CULT-SPREAD — Secret Cult Expansion and Propagation Power Integration

2026-10-30：本轮四组核心运行与直接受影响检查全部通过；独立复核及最终登记见当前适用性报告和任务台。

## 本轮处理什么

已有教团按当前领袖、成员、凝聚与本域无名人口判断普通秘密招募，沿原公式结算人口和费用，不再普遍要求机构许可。这里的渠道是资格记录，不模拟逐人接触或消息传播。

POWER_SEED 另查文明要求的神迹材料。传播与扎根各用自己的条件：满足传播条件的同轮独立材料，不因尚未达到扎根的跨轮要求而被统一拒绝。当前资格与已经发生的付费结果分别核验，失效不能让新行动继续，也不能抹掉过去已发生的行动。

EVENT_04A 退役且不收费，EVENT_04B 承担原默认后果。EVENT_09A 只为指定目标补一份实际缺少、现有合法转交不能提供的材料；保留原信仰费用、对手敌意和察觉后果。暂时缺资源或行动名额不是新材料缺口；目标已有分散持有者足够时不要求再集中。事件与内部转交共用接收核，不能多扣内部递交费用或重复给回执。

本轮也承担 PlayerSources 对 schema2 秘密传播来源的实际消费，以及正式 Session 的启动与一轮推进。不能用删除保护、跳过模块或空处理者替代这一接入。

## 验证与失败记录

采用四组核心场景：普通招募、强化传播、04/09事件、正式会话；只补直接受影响的短回归。使用隔离存档，不改作者已有局。

原实现者连续两次闸门失败后停止，按 CLAUDE.md 逃逸规则移交升档 Code Agent。第一次为新测试缺少局部辅助函数，未进入行为验证；第二次为强化传播的凭据校验失败，以及事件测试沿用不再合法的旧关系前置。原始输出保存在 tools/cult-spread/runs/core-01 和 core-02；不得删除或记作通过。

接管复核确认：历史传播校验重建承载者时漏掉原见证人；Session 把自动派生的渠道/资格也要求事先披露，隐藏了具备已知原材料的合法选源；事件固定描述丢失接收端字段，并误引用关系而非实际告知结果。这些是实现问题，不是密教方向或数值调整。接管首轮验证又发现只读预览的历史访问接口错误和事件卡测试前置错误，失败原始记录保留在 tools/cult-spread/runs/repair-01。

repair-02 与独立接管的 finish-01 均保留失败输出，未记作整组通过。最后定位到另一处实现问题：仪式参与人查询直接遍历人物集合，在事务使用打包存储后漏掉非机构代表的祭司，导致外部预览合法、事务内固定祈求却拒绝。现已改用现有存储/只读查询接口，保留原参与人条件，没有改成只有机构代表才能参加。

最终命令：`python tools/cult-spread/verify.py --godot "E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe" --output tools/cult-spread/runs/finish-02 --regressions`。

四组本轮、四材料、四锚点和17项原来源核心，以及解析/正式菜单冒烟均通过，共35.314秒、退出0，无引擎ERROR；97个冻结执行输入运行期间及最终复核时均无漂移。原始报告和日志在`tools/cult-spread/runs/finish-02/`，汇总为`docs/qa/cult-spread-results.json`。独立QA另核当前代码、原始输出与旧28项验收适用性，不把旧大矩阵记成本轮重跑。

合作正例的两份独立梦境由正式权能先后产生；目标收到第二份后实际生成当前依据。实际PR05固定和回应进入04B自动默认，04A被拒且未付款。正式新局组使用seed1的十个正式模块与实际提供的PR08浅回应，挂载GameRoot并正常推进至第二轮行动窗口。已有教团/成员、事件组的资金与抽签结果仍是受控前提，不冒充自然发展证据。

实现修复没有调整原数值。五次失败均保留：原Code两次停止后交升档Code；接管两次停止后再由独立T1接手，先定位事务差异，保留finish-01后完成最终一次运行。没有删除断言、忽略引擎ERROR或将失败改名为通过。

## 任务与后继

本轮只完成本项。总77，已验收29，未完成48：待开始11、进行中1（TASK-BALANCE）、已实现待复验36，含锁定视听/发布2项。两个原整链issue仍开放，已解除的PlayerSources有限启动阻塞不再沿用为现状。下一项TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration；本轮不自动开始。

## 不代表什么

受控前提下的已有教团、指定材料和事件交易，不证明自然首团发展已经贯通。正式新局与一轮推进也不证明完整存档继续、所有文明发展路线、生命周期、终局、长期平衡或真人界面体验。

首次遗物和维护接续 TASK-ANCHOR-LIFECYCLE — Relic, Anchor Maintenance, Resistance, and Ending Integration；轻量替代路线接续 TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration；完整路线与来源检查归 TASK-SOURCE-CLOSURE — Natural Situation and Critical Progression Source Closure；完整保存归 TASK-CULT-SAVE-COMPAT — Current Rule Version Save Compatibility。视听和发布仍锁定。
