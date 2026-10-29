# TASK-SOCIAL-GRAPH-INITIALIZATION — Social Graph Generation and Initialization Integration

本轮把有限具名人物的初始关系网接入了程序，并通过初始化范围的行为验收。原来的相邻支持环已替换：人物可以有不同数量的联系人，出现互相相识的小圈子与跨机构联系；初始关系区分亲属、支持、合作和竞争。这里只生成少量具名人物的背景联系，没有模拟全人口交际、传播渠道或逐人招募。

原TASK-SOCIAL-GRAPH — Finite Named Social Graph Implementation在开工评估后按原1–3小时标准拆为两个子任务，父任务保留四项原验收。本轮完成初始化子任务；完整关系生命周期与深入存档审计仍交下一批，不能将本轮当作整个父任务完成。

实际接入及检查：

- 正式两张CSV的22项参数、六种关系类型及内容版本进入Catalog；原ROOT_INITIAL_TIES归属不匹配的拒载已通过正式接入修复。所有原CSV字节不变，没有调权重或降低门槛。
- World初始生成与真正首次关注共用同一生成程序。已有bootstrap等具名人物不会被塞进后来新人的初态关系；已经展开过的域撤关注后再关注，也不补造过去交情。原规则允许提名的新人仍可产生，人口与原预算照常结算。
- 当前关系和历史记录分开。重复处理同一关系返回原来源，不增加新的关系事实。新增图只让关系两端知道自己的关系，不让他们自动共享记录、识别邪神或向玩家公开整域。
- 当前格式的World局部保存可以往返；缺少关系头、指向不存在来源及缺图的旧格式，在正确checksum下仍拒绝，保留当前局。没有静默迁移旧关系环。

固定128个六人控制样本全部参与统计，没有剔除失败或空样本：128个都有联系人数量差异、跨机构联系和至少三名联系人的人物；117个有互相相识的三人小圈。四种允许初始类型均出现。统计调用的是正式生成内核，但输入是指定控制样本，不能称为128次自然新局。

另有8份按正式profile选择的World生成样本（四个种子分别运行全详细和混合模式），并实际经过Turn的关注入口检查首次展开、旧人排除、重复关注和空批次。与图无关的阶段使用明确的测试支架；经营故障用受控预览提供意图，再执行真实Turn/Attention/World/Transaction。这些组件检查不证明完整Session、完整经济或自然祈求生成已通过。关系写入的两次业务来源由实际Prayers适配函数和事务产生；没有注入目标关系，但也没有把它称为一次自然PR10请求或完整回应。

本轮修了两个实际问题：一是关系查询误把来源ID当关系数据读取；二是首次展开在经营计划中失败后，可能被旧逻辑当成普通容量不足继续提交。后者现在回滚整笔事务，错误标记不入存档，并验证回滚后可用新请求ID重新提交同一操作；真正的容量不足仍按原规则转为守持。

首轮正式检查失败，日志和当时输入全部保留。测试本身遗漏的参数归属、事务上下文和成员准入前提也已修正。另用独立本机诊断确认沙箱无法读取Windows证书库；第二轮在获准的本机环境执行，仍严格要求无引擎ERROR，没有忽略错误或修改证书库。

最终50项行为检查与5项运行门槛全部通过。报告绑定89份来源和78份当次运行产物，独立QA已逐一核对。首轮失败、三次加载检查及证书权限诊断另行保留，不重跑或改签任何旧项目报告。

尚未验收：精确终止关系和重建新episode、全部旧消费者的完整语义、随历史规模增长的性能、完整历史联合篡改审计、完整Session/CULT兼容、自然来源、平衡及真人体验。原两个issue继续开放。下一项为 **TASK-SOCIAL-GRAPH-LIFECYCLE — Social Graph Lifecycle and Restore Audit**。

当前共88项任务，已验收12项，**未完成76项**：待开始40项、进行中2项、已实现但待验收或复验34项。原父新增两个实施子任务，本轮完成其中一个，因此未完成数量比上轮净增1项。

相对路径：

- 运行证据：tools/social-graph-initialization/results.json
- 本轮范围复核：docs/qa/social-graph-initialization-results.json
- 八设计前置新复核：docs/qa/social-initialization-prerequisites-20261029-results.json
- 首轮失败：tools/social-graph-initialization/runs/formal-20261029T072635Z-0047374b/results.json
- 最终通过：tools/social-graph-initialization/runs/formal-20261029T072954Z-e5b34c67/results.json
- 证书权限诊断：[certificate-permission-diagnostic.log](../../tools/social-graph-initialization/runs/certificate-permission-diagnostic.log)
- 工作台：http://127.0.0.1:8765；离线docs/game-state/terminal.html
