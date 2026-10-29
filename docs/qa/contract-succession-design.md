# TASK-CONTRACT-SUCCESSION-DESIGN — Contract Succession Resolution Design

制作人已要求弱化继任前提。本次交付是规则与任务更新，运行实现仍由 TASK-SOURCE-CONTRACT-SUCCESSION — Contract Succession Selection and Consumption 承担。

原设计要求义务人生前留下继任文书，但文书没有可靠的取得路径；继续补签署、传递和知情模拟会扩大系统。现改为：义务人实际死亡、原契约仍有需要接续的依赖时，从已有关系人里选择能履行原条款的存活者。没有合格者就走原有解除或结束分支。不增加玩家按钮。

选择继任者不等于完成继任。事件固定后保留这个人，实际执行 EVENT05B 才接续原依赖；若他失格，不临时换人。保留原契约、期限和一次性结果，不能凭空补人、补过去关系，或重开已经履行、到期的义务。先知遗言的规则不在本次调整范围内。

已同步原事件规则§14.13、文明材料规则、文明条件表的说明、架构接口说明与任务验收。EVENT05 的运行标签、Catalog 校验、实际消费及存档拒绝逻辑尚待上述实施任务接入。旧测试中“必须生前固定继任”的断言由制作人明确撤换；旧报告保留为历史证据，不宣称它们验证过新规则。

本次由独立角色复核本设计与上游规则；本设计当前静态范围及限制见 [新静态报告](contract-succession-design-results.json)。上游接口涉及正在实施的来源代码，当前保留待复验状态，随实现证据提交后再恢复验收。规则审查不能证明游戏运行、自然新局、继任频率或玩家体验已经通过。

五族来源工作已拆为十三个实施子任务，登记在 `docs/tasks/slice-14.md` 和任务台。当前仍在推进 TASK-SOURCE-LOCAL-TIES-INCIDENT — Current Incident Production and Independent Crisis Lifecycle；本设计交付不代替任何来源子任务的运行验收。
