# 人际关系网与跨机构处境：规划交付

制作人DEC-023：人际关系要按社会联系构成网络；争议与共同记忆要求同一机构不合理，必须更正。本轮完成规则方向/任务/验收与展示同步，模型参数、CSV及代码尚待实施。

## 有什么变化

- 新增TASK-SOCIAL-GRAPH-DESIGN：把接触背景/共同职责关切的联系偏好、小群聚/共同联系人、跨机构桥接和不同联系人数量落成有预算的模型、CSV参数及检验指标。关系类型的方向/互惠、多类型共存、来源和失效需明确；不是随便加几条随机线就宣称符合社会学。
- 新增TASK-SOCIAL-GRAPH：替换初始化的固定相邻关系环，并为重点域首次展开接入同一关系网规则，统一写稳定来源和当前图，处理Catalog旧关系数量只能为1的校验。沿原人口与F/N/P预算，模式/再展开/保存不能重抽；死亡保留历史，图不自动传递记录或揭示玩家未知情报。
- 原LOCAL-TIES拆出初始关系，只保留当下事故与已有亲属求告。CONFLICT、MEMORY、CONTRACT读取同一图。图设计交付时先迁移ROOT_INITIAL_TIES正式CSV责任；本轮CSV仍旧，未冒充接线完成。
- 争议可发生在不同机构的人之间，依赖真实对立关系、具体记录和实际立场/双方获知；共同见闻允许跨机构真实关系人实际共同接触记录。原机构竞争仍可作为一种情况，不再是唯一前提。

取消同机构要求不等于自动拥有职位或全知。PR02任职后果仍查真实目标岗位资格，其他争议的默认后果先由设计写效果CSV；PR10/EVENT09一并复核。记忆审查只影响机构实际掌握且有权处理的本次见证资格，不能抹掉远端私人记忆或身份知晓，PR07/EVENT06逐人核查。

## 怎样验收

图设计给出固定种子集、指标与CSV界限，检查局部分支/群聚/跨机构桥接/联系人差异及预算；六人预算内的跨机构四人共同见闻有合法组合，不要求每局固定生成。正式初始化/展开产生关系后，由原来源任务验证跨机构争议和多人见闻的实际生产/回应/回调；同机构无关系或未参加、跨机构无通路/未知记录均为负例。人数不足沿浅分支/DEC-022替代路径，不补人补过去。

CULT-SAVE-COMPAT核完整会话图来源/当前索引及跨机构权限续存，SOURCE-CLOSURE与NATURAL-VERIFY分别核整链和自然到达。每批1–3小时，超预算先拆真实task。

## 参考与能力边界

模型特征参考同质性研究及社会网络模型，是本游戏的有限抽象，不是已验证现实社会模拟。参考：McPherson等2001 https://www.annualreviews.org/content/journals/10.1146/annurev.soc.27.1.415 ；Granovetter 1973 https://inequality.stanford.edu/sites/default/files/media/_media/pdf/Reference%20Media/Granovetter_1973_Social%20Networks.pdf ；Watts与Strogatz 1998 https://doi.org/10.1038/30918 。小样本图不强行拟合幂律；具体算法和权重尚未设计完毕。具名关系图不会自动把无名人口聚合招募变为逐人传播。

独立只读规划复核通过：64项任务无环，数据迁移/初始与事故归属/跨机构消费/完整存档均有承接，模型和当前代码边界准确。普通制作追踪检查退出0，Web按本地/HTTP/离线数据一致性实核。

本轮未运行游戏；源码、CSV和开工226份文件保持字节不变。上轮OPPORTUNITY-PLAN报告因共同文档变化过期，保持历史/implemented，不重签。原两个阻塞及完整Session拒启仍保留。当前下一项为TASK-SOCIAL-GRAPH-DESIGN。

相对路径：docs/tasks/slice-14.md；docs/implementation/correction-plan.md；docs/progress/current-slice.md；展示台docs/game-state/terminal.html。

当前复核（2026-10-30）：原方向/有限图及目标接收责任按DEC-026复核，旧微观首次读取链不恢复为前提；当前设计证据见docs/qa/material-transfer-design-results.json。原JSON和历史范围保留，不重签，不代表新材料转交或完整新局运行。
