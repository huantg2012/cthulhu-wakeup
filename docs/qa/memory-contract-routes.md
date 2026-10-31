# TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design

本项为三类文明补充六条**设计路线**，尚未接入游戏。新的操作、阶段和费用写入原系统规则及CSV；完整路线父任务仍需单独汇总，当前安装阻塞与两个原问题保留。

| 目标 | 路线一 | 路线二 |
| --- | --- | --- |
| CIV03共享记忆扎根 | 发起人与三名关系人实际共同读取、逐人登记，随后保护这次审查范围内的记忆资格 | 两位实际参加者跨回合共同再现同一次经历，形成当地持续依赖 |
| CIV06契约扎根 | 双方现在订立具体约定，在原期限内由神迹实际履行 | 先订立两份互惠承诺，再由两端分别实际履行，形成相互依赖 |
| CIV08异议记忆扎根 | 原三名见证留下同源资格，扎根时至少两人仍有效存活 | 两人现在经历不同且不可合并的视角，后来分别使各自记忆再次出现 |

这些替代方式不会把两个人改称三个见证者，也不会把一份契约复制成两端履行。原三人分支保留自己的门槛：CIV03要求三名都有效，CIV08扎根可保留三份历史而至少两人有效存活，其强化传播仍要求三人。双人实践使用不同的材料类型，并承担跨回合的实际行动、费用、理智及暴露风险。

共同读取并不直接产生神迹资格。记忆圈先发生当下读取、逐人登记和真实机构审查，下一回合才可在原期限内保护对应资格；机构只能处理它实际收到的登记，不影响其他机构的资格或私人知识。双人路线也必须有实际共同经历和后来发生的超常结果，普通记账、重复文字或转交材料不能代替它们。

契约同样分步骤：约定先写清对象、具体条款和期限；实际履行成功后，才产生神迹依赖与两端对应的知晓。关闭“尚未履行”的危机不等于解除这份依赖，解除仍须明确作用于原依赖。互惠路线必须完成两腿，首腿不能借尚未发生的末腿结果自证，也不能被单向路线接纳而提前形成扎根依据；同一记录换包装不算两项交付。两路都不靠死后临时找继任人。

代码核查还确认，旧PR06/PR07消耗回应次数、资源和主体容量，并不会自动让所有参与者各消耗一次人物行动。新主动活动的逐人行动预算必须明确实现，不能借旧回应测试声称已经具备。

本项新增六种活动，已登记以下四项实施与界面任务：

- TASK-MEMORY-OPERATIONS — Shared Memory and Dissent Operations
- TASK-CONTRACT-OPERATIONS — Agreement and Contract Practice Operations
- TASK-MEMORY-CONTRACT-INTERFACE-DESIGN — Memory and Contract Route Interface Design
- TASK-MEMORY-CONTRACT-OPERATION-UI — Memory and Contract Route Interface Integration

此外，核查发现旧契约继承文书只有验证和消费逻辑，没有产生文书的流程。新增 **TASK-CONTRACT-SUCCESSION-DESIGN — Prospective Contract Succession Production Design** 冻结死亡前实际文书的生产合同；原 **TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources** 等待该设计并实际落实生产。本组六条路线不将这项缺失能力当作前提。

正式业务仍分别归来源内核、操作核心和原知识／关系／容量处理者。共享核心不靠空处理者宣称完整安装，操作父任务最后核全部正式注册和Session入口。材料、锚点、遗物、保存、源闭合与自然验证都有现存任务承接；保管材料不转移原参加者、个人资格或履约责任。

独立设计审查和新静态工具只覆盖规则、正式数据、任务引用及条件预算，不运行游戏、事务、保存或自然新局。表中直接行动等待值零，只指未来安装后输入齐备的当前步骤，不表示全路线零回合、必成或新局已有保障。原源码、旧数据、旧报告与四组旧静态工具保留，共享路线表仅追加本批行。

旧 `data/civilization_conditions.csv` 的描述尚未涵盖全部新增分支，已由完整路线父任务明确承接逐八蓝本同步；本项不宣称所有旧描述已经一致。下一项为 **TASK-PROGRESSION-ROUTES — Critical Progression Routes and Opportunity Guarantees** 的独立汇总。

规则正文：`docs/specs/system-events.md` §14.12、`docs/specs/system-civilizations.md` §9.8、`docs/specs/system-progression.md` §12.3。静态结果：`tools/memory-contract-routes/results.json`；独立审查：`docs/qa/memory-contract-routes-results.json`。
