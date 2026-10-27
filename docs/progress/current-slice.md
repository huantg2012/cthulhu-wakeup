# 当前工作 · Slice 14整改已规划，游戏修复尚未开始

更新：2026-10-27。作者已确定密教方向及两类祈求原则，并要求先把工作按既有流程规划为task、同步制作人Web。本轮完成这项规划；状态唯一来源为 docs/implementation/traceability.json。

目前有三类不同的问题：通用机构许可偏离密教方向；重点域没有接替后台的祈求生产流程，且缺少定向/无指向来源模型；首次建团的预算与节奏需要在这些修复后校准。旧“先补许可来源”的提案已撤回，不再等待作者选择。

## 已编入开发计划

| 任务 | 责任与目的 | 前置 |
| --- | --- | --- |
| TASK-REPAIR-PLAN | director：本轮规划、经验与展示同步 | 无 |
| TASK-CULT-DIRECTION | design：密教传播与实际神迹扎根规则 | REPAIR-PLAN |
| TASK-PRAYER-DESIGN | design：两类祈求、知晓与关注的边界 | CULT-DIRECTION |
| TASK-CULT-SPREAD | code/qa：秘密扩张与传播权能 | CULT-DIRECTION |
| TASK-ANCHOR-ROUTES | code/qa：八文明扎根条件 | CULT-DIRECTION |
| TASK-ANCHOR-LIFECYCLE | code/qa：圣物、维持、抵抗、终局衔接 | ANCHOR-ROUTES、CULT-SPREAD |
| TASK-PRAYER-KNOWLEDGE | code/qa：具体人物的知晓与求告来源 | PRAYER-DESIGN |
| TASK-PRAYER-ORIGINS | code/qa：详细候选生产与模式交接 | PRAYER-KNOWLEDGE |
| TASK-SOURCE-CLOSURE | code/qa：关键自然处境生产闭合 | PRAYER-ORIGINS、ANCHOR-LIFECYCLE |
| TASK-STARTUP-BALANCE | design/code/qa：首团预算与节奏校准 | SOURCE-CLOSURE、CAPABILITY-PROBES |
| TASK-NATURAL-VERIFY | qa：真实新局发展与跨系统独立验收 | SOURCE-CLOSURE、CAPABILITY-PROBES、STARTUP-BALANCE |
| TASK-CAPABILITY-GUARD | code/qa：声明职责与正式执行绑定，先覆盖候选生成 | REPAIR-PLAN |
| TASK-CAPABILITY-PROBES | code/qa：短行为探针抓空实现、漏调用、丢产物 | CAPABILITY-GUARD、PRAYER-ORIGINS |
| TASK-CAPABILITY-AUDIT | qa：既有关键生产职责首批盘点，剩余明确排期 | CAPABILITY-PROBES |
| TASK-FRAMEWORK-LESSONS | director：通用经验在master独立回流 | CAPABILITY-AUDIT |

每项1–3小时单批预算、明确验收和停止条件。具体范围见 [任务书](../tasks/slice-14.md)；原则、纠偏依据及低成本防漏办法见 [整改计划](../implementation/correction-plan.md)。下一项游戏工作是 TASK-CULT-DIRECTION；候选生产防漏的最小接线检查可独立先做。设计后实现、独立QA、需要的人审仍按既有流程；本轮未改游戏spec、CSV或源码。

## 平衡与原证据保留的边界

TASK-BALANCE仍in-progress，旧14条轨迹共840轮均截尾存续、无首团；有限样本不能证明全局不可能。失败、环境问题、保存成本和工具限制保留在[原报告](../qa/balance.md)，未篡改旧游戏证据。自然来源缺口与密教方向错误仍实际阻塞完整平衡，已分别登记问题和承接task；规划完毕不等于问题解决。

首团数值已由作者委托协作者校准，不再逐项请作者决定价格。生产缺口修复后明确新样本和最多三轮预算，不把旧探索次数静默清零或重写为成功。TASK-NATURAL-VERIFY完成后回原TASK-BALANCE做完整策略复测；TASK-CONTENT继续内容扩量与叙事理解，系统纠错不再塞入内容任务。

TASK-UI保持implemented，ACC-UI/ACC-ACCESS仍待作者体验；完整视听、目标平台可靠性及高阶负载仍按原任务。通用框架只做后续排期，本轮不混改master或agent定义。规划检查、Web同步及必要制作工具回归完成后，按DEC-018独立本地提交，不推送。
