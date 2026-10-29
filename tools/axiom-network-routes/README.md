# Axiom, Network, and Manifestation Routes — static checker

```powershell
python tools/axiom-network-routes/verify.py
```

本工具只读本批三张正式路线表及其正式参数、目标、蓝本、权能、spec、任务书和结构化追踪。只写同目录 `results.json`；UTF-8，显式 LF。输入与工具/本说明全部 SHA256 记录为 `sourceHashes`，结果本身不作为来源；结束时再核输入冻结。失败退出 1，成功退出 0，不修改旧报告。可选 `--tables-only` 只跑表及引用，不得当完整静态结果。

检查六条有限 route、五个操作、一个自然复核声明的精确 CSV schema/唯一 ID/封闭枚举；目标与蓝本匹配；每目标两条索引、每路入口/材料规则/生产及消费任务引用；原 DREAM 与深干预费用参数；全部 design_only。Builtin `SESSION_REST`、`SESSION_SET_ECONOMY_PLAN` 和 `POWER_MANIFEST_CONTINUE` 对应设计登记的 Session 接口，登记只表示引用，不能证明处理者安装。新操作和自然源仍待真实实现。

任务引用必须命中 traceability 中唯一实际任务对象，核 owner/scope/deliverables/ACC；ACC 必须命中真实 given/when/then 场景。任务书名称核对仅是交接引用，不能替代上述结构化对象或业务审查。Progression Route Operations 的子批归属也需真实存在。Critical Progression Routes and Opportunity Guarantees 父任务保持未完成。三目标各两条的**真实因果差异**、禁一路后完整可达与知识/材料语义仍由独立人工 QA 判断；本工具不靠出现某字符串冒充这些结论。

代数见证使用进度§12.1的最终静态示例及正式参数：初生 10、洞见上限 20、当前贡献 `2×cosmic10 + 5×system7 + 2×planet4=63`，故潜在 B=93；真实创伤 6，当前 A=87。额外一座真实停供但结构材料绑定仍合法的星球锚，实际付费并重判有效后增加 4，单独到 A=91；另一支明确拒付它，只以真实 REST 恢复 3，单独到 A=90。域/机构槽分配为 cosmic `[2]`、system `[3,2]`、planet `[3]`（含额外休眠锚），十位护持者不超原 N，仪式两域不超原 F。示例的数量/创伤是受控代数输入，不是新增runtime参数。不补人物或材料；这是必要预算检查，不是已构造的合法存档。

现金见证从正式供奉/REST/仪式起始费用计算当前库存最低需要，不使用预计收入：九座active供奉20、REST6、下一行动窗start20，共46。明确假设所有cult策略为hold且策略费0，没有额外扩张或其他优先支出；并非任何经营计划有46就足够。它不保证后续世界、供奉或三轮仪式持续条件。保存计划不给贡献；付款行 `paid_pending_final_check` 也不表示恢复已完成。没有独立 `anchor_reactivated` 事实的旧代码不能被本演算伪造为已发回执。阈值提高、没有真创伤、仅保存计划的负项是代数反例/后续行为义务，不是实际 handler fault injection。

每路设计的 `direct_action,0` 仅属于实施后当前合格单步的直接入口合同；不证明当前游戏可执行，不表示整路零轮或成功。实际 B/A/fix/offer/actions 管线 L 与完整路线界输出 null。此工具不运行游戏、不模拟第二套调度器、不生产知识/材料/支付事实，也不验证真实事务、回滚、保存或自然新局可达。正式源冻结后才执行最终运行；源变化后不得重签旧证据冒充重跑。
