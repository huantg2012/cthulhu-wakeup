# 正式经济验证

参与者接收受限当前投影，经济资格只按当前资格键读取对应来源事实，不扫描完整历史。测试初始条件在首次提交前布置，已发布事实不可原地修改；共同事务及改造前差分证据另见 `tools/incremental-tx/README.md`。

仓库根运行：

```sh
python3 tools/economy/verify.py
python3 tools/turn-cycle/verify.py
python3 tools/formal-simulation/verify.py
```

需 Godot 4.7；默认使用 `/Applications/Godot.app/Contents/MacOS/Godot`，可传 `--godot`。包装器执行真实引擎，生成 `docs/qa/economy-results.json` 和可读的 `economy.md`，拒绝旧报告、脚本错误、失败/重复检查和运行期间来源变更。先冻结生产代码、规则和测试，再运行最终证据；仅更新指纹不能让过期证据恢复有效。

`run.gd` 负责集成、完整 50 轮实测，`qa_cases.gd` 负责独立反例。数值来自正式 Catalog 和 CSV，实际经营和供奉由 `src/game/economy.gd` 计算。其他业务通过明确声明的测试参与器提供已有对象与来源事实；本套不验证完整建团、全部文明传播证明、锚点创建、随机事件或最终仪式。

## 生产接入与读取

`Economy.new(catalog, accepted_issuers)` 声明可接受的上游资格能力及版本。`install(turn)` 仅在开局前注册，独占 `round_start / prepay / evolution / income` 槽。它使用同一 World 的人口、信仰与历史，不另建可独立增长的人口或资源副本。已有世界准备可在接管前使用 `initialize(world)`；合法资格必须绑定实际对象、来源与发行能力版本，不能仅传无来源的真值。

- 阶段一登记旧信众的当轮收入资格，再执行到期人口变化。资格是实际无名信众的子集；轮内新增、迁入或改信不补资格，提名/流失/死亡/迁出同步扣减。
- 阶段三通过 `Turn.submit()` 提交 `op:"set_plan", participant:"economy", payload:计划`，同时带当前 `id / turn / phase` 请求凭据。计划字段为 `strategies`（教团 ID → `expand / conceal / hold`）、`anchor_priority` 和 `refuse_anchors`。提交即校验，坏计划保留之前有效计划；结束行动后锁定。
- `preview(world.state, plan)` 返回只读成本、实际可招募量、流失及余量、收入基数、容量、支付顺序和不能运作的原因。上游资格缺失明确失败，明确不合格属于正常局势。收入与最终锚点有效性仍依赖后续共同演化，不能预支预览收入。
- 阶段四先按稳定顺序真实预付，再与 NPC／文明读取共同快照，延迟合并招募、流失和察觉变化。待恢复锚点实际支付后仍须通过批次后的复核。
- 阶段五按仍合格的旧信众和真实凝聚计算收入，最后一次取整，记录入库与容量散失；随后期限变化不追扣此前合法收入。

人口流水、收入资格、自然流失小数余量、有效策略、支付记录和计划均进入统一保存/回滚边界。失败不能只退信仰而留下人口、余量或随机流变化；重复请求和中途续存不能重复扣款或收入。

精确规则以 `docs/specs/system-turn-economy.md` §11 为准，跨系统责任见 `docs/implementation/traceability.json`。本轮支持的是已有对象的正式经济结算；上游完整生命周期继续由 `TASK-CULTS / TASK-ANCHORS` 等任务负责。

## 证据边界

报告分别记录 50 个完整六阶段回合及各阶段耗时、真实人物更新/自主行为/抵抗、每 10 轮经济活动、历史增长与保存成本。这 50 轮准备 12 个已有教团、0 个锚点；锚点付款/拒付/恢复由独立规则场景验证，不将此测量冒称多锚点长期负载。没有性能预算，因此这些数值是观测结果，不是性能达标声明；长期策略优劣、叙事和玩家界面理解仍需后续完整系统的证据。没有新增短体验前置阶段。
