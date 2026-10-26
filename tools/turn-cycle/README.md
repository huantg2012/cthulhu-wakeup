# 统一六阶段回合验证

仓库根运行：

```sh
python3 tools/turn-cycle/verify.py
python3 tools/formal-simulation/verify.py
```

需 Godot 4.7；默认使用 `/Applications/Godot.app/Contents/MacOS/Godot`，可传 `--godot`。包装器运行真实 Godot，拒绝脚本错误、旧报告和运行期间来源变化，生成 `docs/qa/turn-cycle.md` 与 `turn-cycle-results.json`。全套包含真实 12 域 72 人的 50 轮完整回合成本实测；没有性能预算，不把时间观测伪装成性能通过阈值。

`run.gd` 负责集成与成本测量，`qa_cases.gd` 为独立 QA 的坏输入、失败回滚和续跑反例。测试中支付／事件／期限／终局参与器明确是合约适配，真实 NPC 与文明调用 `src/simulation/world.gd`；不代替完整业务内容。

## 生产入口

`Turn.new(world)` 接管已生成且尚未开轮的正式 World；拒绝接管已经推演过的旧验证会话。World 使用弱引用持有协调器，协调器保留参与器 Callable 目标，避免释放循环或已销毁的参与者。接管后必须从 `Turn.submit()` 走回合；World 的公开写入与时钟入口拒绝旁路。

- `register_participant(id, version, slots, allowed_effects, handler, plan_validator)`（最后一项可选） 仅在开局前登记，槽位唯一 owner；必需槽位为 `events/prepay/income/deadlines/ending`，可选为 `actions/start/round_start/evolution`。`round_start` 在本轮到期人口变化之前锁收入资格；`evolution` 在预付后与正式NPC/CIV读同状态，只提交批次声明，全部候选选完才合并。
- `preview_plan(participant, payload)` 纯读调用参与者的可选计划校验器；`set_plan` 复用同一校验，非法正式经济计划不会等锁定后才报错。
- `capabilities()` 返回稳定身份、版本、槽位、声明效果；未接入能力显式缺失，不能装成空集合。
- `submit({id, turn, phase, op, ...})` 返回 `{ok, turn, phase, result}` 或 `{ok:false,error}`。同 ID 同内容重试返回原结果；同 ID 换内容拒绝。`turn/phase` 是调用前的游标。合法游戏失败同样提交费用与结果。
- `snapshot()` / `restore(serialized)` 保存与整体校验世界、随机流、游标、阶段凭据、请求回执、冻结事件、队列、锁定计划与版本。恢复到任何已提交边界继续，不重新执行阶段四。

阶段游标依次是 `between → events → actions → evolution → settlement → ending → between/ended`。操作为 `advance`（自动阶段）、`resolve_event`（event/action）、`finish_events`（处理剩余默认）、`act`（participant/action/payload）、`set_plan`（participant/payload）、`end_actions`。事件期间必须明确结束事件；行动期间必须明确结束行动，不能用 advance 跳过。

## 参与器合同

回调 `(view, input)` 只收到受限当前投影的安全副本，`view` 含 `world`、`turn`、`slot` 与自身 `participant_state`，`input.slot` 为当前能力槽。完整事实、知识/成长历史、旧回执与阶段日志不向参与器整表开放；经济只附当前资格引用所需事实。按需来源查询使用本次回调的 `view.reader.fact / entity / history_query`；历史查询页长来自正式 CSV，`complete=false` 必须续查或使用足够的聚合结果，游标绑定版本与来源实例。reader 在回调后失效，不能缓存到下一次回调。参与器不接收可写 World。持久游戏状态只通过返回 `state` 保存，不能藏在实例私有字段；参与器不持有协调器反向引用。

首次提交完整审计并冻结已发布根，之后事务只复制写入集合，失败丢弃候选，发布后旧引用保持不可写。测试初始条件在接管/首次提交前布置；不得在已发布对象上直接修改字段来模拟正常游戏写入。完整导出/读档仍全量审计，普通操作的专用差分与隔离证据见 `tools/incremental-tx/README.md`。

每次返回必须有 `ok:bool`、`empty:bool`、`effects:Array`、`state:Dictionary`。`empty:true` 必须 effects 为空。events/gather 还须返回 `events` 数组；每项包含 `id/default_action/payload/source`。名单冻结后不能用任何其他调用重筛。各动作和事件选择还需 `meta`：非负整数 `faith_cost/whispers_cost/min_awakening`，字符串 `actor/source/outcome`，布尔 `responds/used_power/used_relic`。事件不能声明 responds；默认分支必须零信仰零低语，效果及所有检定分支也不能藏支出。

授权效果文法为 `world_command/fact/resource/wounds/schedule/check/end/economy`。除 schedule 的来源在 job 外，效果均要求存在的 `source` 事实，可加多前因 `parents`；检定的实际 turn_check 事实也成为选中后果的父因。效果文法在抽骰前校验所有分支。输入、返回不合规或中途失败会回滚整笔状态、随机、队列和费用。

`resource` 只声明 faith 增减；prepay 禁止正增、income 禁止负支出，收入还需所属 cult、eligible 与 rule 依据，实际入库与溢出分别记录。业务公式由对应正式规则参与器负责。`check` 指定 npc、attribute、domain、mode、preparation 及 deep/success/failure/disaster 四个效果数组；不支持嵌套检定。`end` 仅允许 ending 槽声明 extinction/awakened。

`schedule` 的 job 含 `id/due/phase/action/payload/source`；登记者必须拥有其 start/deadlines 槽。start 仅未来轮；deadlines 在阶段五尚未开始时可登记当轮期限，阶段五处理中生成的新后继必须未来轮。同批到期先预校验全部声明，再仲裁不可逆死亡，失效恢复／迁移整项取消（含全部费用及配套效果），留下取消原因及真实前因，消费一次；坏文法仍整阶段拒绝。到期身份能力目前只支持确定性仲裁：身份效果与检定混合（含分支内身份）、同项死亡与普通恢复／迁移混合均在 RNG 消耗前明确拒绝；概率身份冲突留给未来正式能力扩展。完整未接入业务的资格判断不由协调器臆造。

尚无正式随机事件抽样；后续 TASK-EVENTS 应接入受管理的 events 随机流，不能把当前确定性验证参与器当作完整事件池。这里的受限接口是受信任业务代码的集成合同，不是第三方恶意代码沙箱。

`economy` 效果只允许已安装的生产 Economy 实例，通过 round_start/prepay/evolution/income 受管理时点执行；不是外部填写金额的通用奖励。正式公式与人口账本的独立验证见 `tools/economy/README.md` 及 `docs/qa/economy.md`，本套仍保留原编排合同适配与29项断言。
