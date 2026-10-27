# QA Report: TASK-RESISTANCE 定向规则静态审阅

日期：2026-10-27。基线：`7a44ad86f8cd9fa7afe4001bdb9b4420428f645d` 加本任务工作区变更。

## 范围与证据边界

这是本任务一次定向规则审阅及发现项修复重读，不是完整游戏验收。基准为 `docs/specs/system-civilizations.md` 第 7–10 节、`docs/tasks/slice-10.md`、原 `data/resistance_plans.csv` / `data/civilization_actions.csv` 及架构冷历史约束。源码范围为新增 `src/game/resistance.gd`，`src/simulation/world.gd`、`src/game/turn.gd`、`src/simulation/state_view.gd` 本次差异及其直接调用的计划结算、Events 08/11 承接、HistoryIndex 证据索引。

本审阅没有运行构建、Godot 专项、负载或浏览器试玩；执行与断言证据由 `tools/resistance/` 专项及主任务实际回归报告承担。以下“已修复”仅表示修复代码已重读，不冒充实跑通过。没有改生产代码、测试或设计。

## 发现的问题

| ID | 类型 / 严重度 | 事实与影响 | 位置 / 依据 | 状态 |
| --- | --- | --- | --- | --- |
| RES-REV-01 | Bug / Medium | 多个确认主体指向同一教团或锚点时，后遍历主体直接覆盖该目标的依据；较旧证据可以替换较新证据，影响候选排序及固定主体。 | `world.gd::choose_plan`；第 8 节“同优先级按证据最近发生回合、稳定对象身份排序”。 | 已修复并静态重读：`_prefer_plan_basis` 比较真实确认回合，同轮保留稳定排序首主体。 |
| RES-REV-02 | Bug / High | 新规则允许旧确认失效后重新 TRACE，但原结算只在 confirmations 集合为空时追加确认。非空的失效历史会阻止新确认入账，导致调查结算后仍无有效确认；普通 TRACE 和 EVENT_08 B 路径均存在。 | `world.gd::_resolve_plans`、`_finish_event_trace`；第 8 节 TRACE 到期确认指定证据。 | 已修复并静态重读：正式能力路径追加唯一新 outcome，保留旧历史。 |
| RES-REV-03 | 架构偏差 / Medium | `usable_confirmations` 对完整冷 confirmations 执行 `History.values` 并逐条读取事实与父因果；每轮候选及到期复核调用。撤销/重新确认会累积旧 H，活对象不增加也会增加热路径工作。未做性能实测，不声称具体帧耗时。 | `resistance.gd::usable_confirmations` / `basis_valid`；架构“普通候选不展开全历史”，本任务“普通检查只审当前计划和有效来源”。 | 已修复并静态重读：HistoryIndex 增量维护有效确认桶和撤销反向依赖，普通选择取有效头；到期只查固定 parents；恢复重建索引。需专项冷 H 反例实跑。 |
| RES-REV-04 | 既存规则缺口 / Medium | REPAIR 新计划资格仅比较 barrier <= first_breach_threshold (30)，未表达已打开破口持续到 breach_close_threshold (45) 才关闭的状态。曾降至 30 后恢复到 31–44 的域应仍有破口，而当前资格拒绝。 | `world.gd::choose_plan`；第 6 节进入迟滞与第 8 节 breach；`civilization_parameters.csv` 原 30/45。 | 根确认纳入本任务；已修复并静态重读：能力保存各域 breaches，原 30/45 更新，生产屏障变化的 power_effect / prayer_delta / event_delta / natural_evolution 记录时同步，最终锚点刷新同步 REPAIR。需专项迟滞与保存实跑。 |

## 静态核查符合的部分

- 正式能力先要求 Events、仅开局无回执安装；Turn 参与者能力及内容版本随存档核验，StateView 传递能力副本。
- 机构和人物候选共用演化快照；所有域选择计划，不依赖后台日常是否到期；同域已有主要计划时不再启动。
- 开始事实固定执行机构、目标、证据主体、parents、due 及原 CSV default_effect；当前计划与开始事实及原表在审计时互校。只读 preview 返回深副本且不推进随机或世界。
- 到期 `_plan_valid` 不重新要求察觉阈值；固定来源失效取消而非换目标。取消和结算均写历史并记录 turn + cooldown，候选以 >= current.turn 禁止，在下一轮起计满冷却。
- PURGE 资格和复核绑定实际成员所属教团；执行原比例向上取整，只减少本域无名信众及一次死亡人口并减凝聚。SEIZE 改同一物件归属并刷新锚点；ERASE 只破坏固定锚点结构。
- REPAIR 数字取原动作表。Events 开启时，World 不再次执行圣物 TRACE / REWRITE 的结果；Events 原承接后清除原计划并记冷却，REWRITE 数字损害只来自事件操作。
- 本次没有新增世界传播入口、免费玩家指令或根据历史 parents 自动授予知情的逻辑。跨域目标准入的实际有路/无路行为由专项运行验证，不据静态无新增代码宣称通过。

## 结论

RES-REV-01–04 均已完成本次定向修复重读。修复闭环额外核查 `history_index.gd` 的新增有效证据索引与撤销更新，以及 Powers / Prayers / Events 屏障写入先于对应事实记录的顺序，未扩为第二轮全量审阅。该范围未留已确认未修复项；最近证据、重建确认、冷 H、30→40→45 迟滞四组反例均已交专项执行者。最终通过与否须合并实际测试、保存续跑及失败回滚证据；本报告不能称为 resistance 全部验收通过，更不能称为游戏体验或性能通过。

同次迟滞修复补查：当前布尔同时绑定最近 `resistance_breach` 来源，跨阈值事实引用真实屏障变化和 previous；World 先写实际 delta 再派生 crossing。HistoryIndex 保留最近 head，增量审计只读当前头，完整恢复才检查历史最新来源，可拒绝灰区单改布尔或回退旧 source。此项是 RES-REV-04 的保存审计闭环，不新增整轮审阅；运行结果仍由专项提供。历史 events / fidelity 人工报告仅追加已实际重读变更的静态兼容说明并更新对应人工指纹，未变绑定保留，未修改运行证据。
