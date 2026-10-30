# TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources

状态：本族限定验收完成，2026-10-30。五族轻量来源均已完成各自短例；完整Session、自然新局和关键进展全链仍未通过。

## 做成了什么

现有来源抽签能一次固定两个当前可用人物、普通约定、原期限和PR06。没有签署、递送、法律或逐人文书知情过程，也没有增加祈求模板。当前条款是简单义务，不涉及必须先找到某份记录的保管任务；不把它说成已实现物件交付或互惠路线。

浅成功登记履约和见证、保留原任命限制，不产生深依赖；深成功产生原神迹依赖及两端见证/指定知情。原义务完成后关闭，依赖继续存在；实际EVENT05A才解除该依赖。未回应按原due关闭本次合作，不生成神迹材料，不靠新请求重开已结束的义务。

原义务人已死亡且需要接续时，从已有family/support/cooperation关系中选择active同域者，排除原义务人及对方，不补人、不补过去关系、不要求同机构或生前文书。固定后失格不临时换人；实际EVENT05B才接续，让选定者取得原contract、dependency及接续结果，不递归传播parents或邪神身份。无合格者仍可解除或结束。原contract/due不重写，原义务不重开。

继任效果先于可选文明资格检查：完整扎根条件不满足，不应使已合法执行的继任消失。是否能扎根仍由完整材料、载体及原路线判定。

## 实际接口

ROOT_CURRENT_PACT使用CSV规则current_simple_obligation，直接生成contract_obligation；固定obligor/counterparty/institution/term/due及本次scene_rule/snapshot，复用Sources.situations/cooldowns。contract_scene_weight=1、contract_scene_cooldown=3；总体概率、费用、人数/容量和回应成功率不改。

EVENT05有限标签改为obligor_or_current_successor及selected_successor_or_release。contract_inheritance_fixed现在表示死亡后的当前选定；只有实际B产生contract_successor_authorized。Rules/Anchors共同撤生前文书判断，核原关系、死亡/选定顺序及实际B结果。历史targets可保留死者，但Events._write不向死者新增知识。

## 实际核心检查

最终冻结代码14.25秒，退出0，gateStatus=pass；4组本族加原13组直接回归，共17/17。另一次当前规则/计划人工复核独立记录为SC-STRATEGY-REVIEW，不计引擎第18项。

| 检查 | 实际结果 |
| --- | --- |
| SC-SHALLOW | 正式来源固定双方/原due并保存恢复；实际浅履约一份、见证一份、任命限制一份且until=T+1，无深依赖；重复拒绝且不再收费。 |
| SC-DEEP | 实际深履约产生一份依赖及指定对方知情，关闭原义务仍保留依赖；实际EVENT05A撤销准确依赖。 |
| SC-EXPIRY | 未回应按原due关闭合作和情境各一次，无依赖，不改期限。 |
| SC-SUCCESSION | 深成功后实际状态命令导致死亡，已有图选定继任者，读档不换；实际B接续一次并交给指定知识。另一真实无候选例B不可用、A实际解除，死者原知识不变。 |
| SLT/SLC/SM/SE原13组 | 救援、冲突、记忆和异常原短例在本轮共享改动后真实重跑通过。 |

正常继任例的死亡FACT-00000136在T2，当前选定FACT-00000218在T5，继任NPC-00000005；另一NPC-00000006仍可用。“固定者失格但另有人可用仍不能替换”以只读状态反事实核合法性，不称为另一条自然死亡轨迹。死亡/失能是既有期限夹具通过World命令实施的前提，不是本项模拟的社会事故。目标约定、请求、依赖、选定及实际继任结果均走正式生产/结算，没有注入替代。

命令：

```powershell
& 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --log-file D:/code/cthulhu-wakeup/tools/prayer-producers/source-contract-engine.log --script res://tools/prayer-producers/source-contract.gd -- D:/code/cthulhu-wakeup/tools/prayer-producers/source-contract-results.json
```

## 两次失败与根因

第一次13.81秒，前16组通过，继任组在测试深复制归档根后失去只读结构标记，人物查询失败，中断出报告；初报“继任者为空”只是推测，后续已纠正，不据此改生产。只修测试副本。

第二次14.44秒，17项JSON自报通过，但实际无候选A解除时，Events._write按NPC存在就调用World._know，给冷归档死者写新知识，触发只读ERROR/SCRIPT ERROR，整批不能验收。这是实际实现bug，不能拿检查表全绿掩盖。

按两败规则停止，由主会话独立读取_write、_know、mutable_npc和实际路径。只授权修复Events授知分支跳过死者，保留历史targets及私人知识；同例增加死者知识不变与准确依赖撤销检查，再单次14.25秒验证。没有全局解冻死人、删掉负例、放宽原断言或声称实际模型档位已切换。两批原始结果与执行记录保留。最终仅有Windows证书环境ERROR，无脚本或只读写入ERROR。

## 边界与后续

没有验证完整Session/CULT兼容、自然频率、所有关系组合、完整CIV06锚点或互惠两腿操作；后者仍由TASK-PROGRESSION-OPERATIONS — Critical Progression Route Integration及TASK-ANCHOR-ROUTES — Eight Civilization Anchor Route Implementation承接。单向义务不填互惠任何一腿，同根复制不增加材料。必要机会有限等待和完整来源/进展闭合仍是原任务；原两个实际阻塞未关闭，视听与发布保持锁定。

本轮只更新事件spec/架构的实施状态和已接接口，当前策略/28项归并/责任做新人工复核，不重签旧策略或旧来源报告。追踪绑定本轮实际回归；历史报告保留。

证据：docs/qa/source-contract-results.json；原始source-contract-runtime-results.json，执行source-contract-execution.json；两败对应source-contract-first-failed-*及source-contract-second-failed-*。任务台未完成71项，含锁定2项。
