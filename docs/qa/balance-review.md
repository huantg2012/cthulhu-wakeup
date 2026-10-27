# QA Report: TASK-BALANCE 独立审阅

日期：2026-10-27。基准代码：`ec8d2aa60b68b4624710678bfbc2c83554f89400`。本报告先记录静态审阅，正式运行器与轨迹证据完成后追加复核；静态推导不计入首轮策略结果。

依据：`docs/tasks/slice-13.md`、`system-turn-economy.md`、`system-powers-cults.md`、`system-progression.md`、`system-civilizations.md`、`system-events.md` 及对应 CSV。仅负责此报告，不修改生产代码、设计数据或规格。

## 静态发现

| ID | 类型 | 严重度 | 事实与影响 | 定位与依据 |
| -- | -- | -- | -- | -- |
| BAL-QA-01 | 生产覆盖缺口 | High | 真实新局没有生成 `exception`、`memory_at_risk`、`contract_obligation`、`faction_conflict` 等根事实的现有内容生产调用。两种宇宙蓝本的锚点分别需要法则例外或共享记忆链；现有后台 PR08/09/04/05 不能制造这些前提。合同夹具可以验证下游规则，但不能证明新局能到达宇宙锚点与降临。 | `data/background_templates.csv`；`src/game/prayers.gd:137–205`；`src/game/anchors.gd:257–330`；`src/simulation/world.gd:24` 的受管理事实能力只是合同入口。进度规格 §3/7、文明规格 §9。 |
| BAL-QA-02 | 生产覆盖缺口 | High | 传播资格唯一生产调用来自 EVENT09 的 `permit` 操作，依赖原派系冲突；自动来源模块只包装已有许可。新成立教团没有该凭据时，申请 expand 会得到 `Missing upstream qualification` 的接入错误，而不是实际传教。真实新局的策略比较必须披露未获得此能力，不能以计划名替代实际执行。 | `src/game/events.gd:629–637`、`data/event_operations.csv`、`src/game/economy.gd:125/335–337`、`src/game/player_sources.gd:106–110`。经济规格 §11.1 对“明确不成立”与“能力缺失”作区分。 |
| BAL-QA-03 | 实现/集成缺口 | High | 职责表声明 focused 域执行 `detailed_candidates`，后台执行 `abstract_candidates_due`。现实现只有后台候选生产；focused 域到期仅推进游标，不存在与之对应的详细候选生产者。跳过后台机会本身正确，缺少已声明的详细生产职责才是偏差。一直关注开局域时，除开局 bootstrap 外不会继续抽到自然 PR05/PR08/PR09。释放关注等待后台机会可作现有能力诊断，但不是此缺口已修复的证据。 | `data/simulation_responsibilities.csv:9`；`src/simulation/world.gd:1054/1117–1122/1837–1842`；`src/simulation/abstract_sim.gd:108–132`。文明规格 §10、经济规格 §12、职责表。 |

代码行号对应上述基准提交；修复或重构后须按符号重新定位。

### 根事实生产闭包复核

检查范围包括 `src/game/**` 与 `src/simulation/**` 的全部 `_record` / `introduce_fact` 调用、Turn 的泛型 `fact` 效果分派、正式 Session 所安装参与者及 CSV 效果操作；不只按字符串查找消费者。

- 开局 `World._generate` 确实生成 `initial_relationship`，但具体为 `changes.kind = support` 的邻接关系。PR10 需要另一个 `kind = faction_conflict`、匹配机构及 parties 的有效根；`Prayers._situation` 没有把普通支持关系转换为冲突的分支。现有关系只能满足其中“既有关系”部分，不能满足冲突根。
- `World.introduce_fact(kind, ...)` 与 `Turn._apply_effect` 的泛型 `fact` 可写受管理种类，但只是带能力和因果校验的集成入口；当前正式 Session 所安装模块没有以其生成上述缺失根的效果。外部合同测试可注入不代表真实新局已生产。
- 其他带变量的写入也已检查：`Prayers._write` 固定写 `prayer_fact`，`Events._write` 固定写 `event_fact`；CSV 的 `record` / `memory` 操作写标签或 `memory_preserved`，不写 `memory_at_risk` / `exception` 根；`World._close_background` 和 Relics 的变种 kind 分别限定 `background_*`、`relic_*`。Powers 的效果分派只写其有限既有类型，不按内容字段任意生成根。
- 因而 BAL-QA-01/02 是当前实现的生产覆盖缺口；并非说规格禁止这些根存在，也不把有限策略跑不出来当作全局不可达证明。此结论限于当前源码和内容的上述生产闭包，新增合法生产者后应重新审阅。

## 首团与经营的可核查推导

- 首团成立是同一域：忠诚至少 40 且可准入的 active 人物、累计实际信仰支出至少 8、无名信众至少 6；已有绑定成员本身不替代无名信众。`Cults._end/_choose` 与 CSV 门槛一致。
- PR05 深干预成功增加 5 名信众，深成增加 `floor(5 × 1.5) = 7`。单次一般成功不足 6 人门槛；另一轮仪式或 EVENT04B 的合法异端传播可补足。不能只测试一次转换就宣布首团路径完成。
- PR08 成功建立具名成员身份，不增加无名信众；人物忠诚增长与无名人口转换不能混算。
- 初始信仰 18，PR05 深干预每次 4、入梦每次 2，且成立前没有教团收入。失败也会花费，首团可达性应记录资金耗尽与机会稀缺，而非只挑成功骰种。
- 凝聚 60、6 名合资格信众时正常毛收入为 `floor(sqrt(6) × 0.6) = 1`；敛藏为 0。传教（若有真实许可）预付 2，影响 0–5 时招募 2–4 人并增加察觉。小团敛藏可能无收入，扩张可能暂时净流出；这些是公式结果，不据此声称支配或失衡。
- 流失按无名信众、凝聚和持久余量计算；不存在教团时不自动流失。新招募和成立当轮不领取收入，故首团前的纯等待不能凭空补钱。

## 待运行证据复核

- 固定种子 19/42/7919，激进/隐蔽/扩张/不干预四策略，各最多 60 轮；到限仍存续为 censored。
- 逐条确认选行动只读玩家知情来源；权威观察指标不参与决策。
- 首团从真实 Session 新局建立，含同域支出/信众/领袖准入的完整轨迹与重放。
- 比较实际生效策略、拒绝/降级原因、进度与风险；分开统计既存中局夹具。
- 重复请求、拒绝命令、零资源结束、有限动作循环、保存恢复及正式负载增长。

TASK-UI 的 ACC-UI/ACC-ACCESS 人工体验仍待作者验收；本报告不代替该验收，也不判断“好不好玩”。

## 冻结运行器独立复核

复核对象：`tools/balance/run.gd`、`policy.gd`、`verify.py`、`README.md`；首轮正在执行时只读，未改动来源、重跑矩阵或筛选种子。以下是对工具能力与口径的审阅，不是 TASK-BALANCE 通过判定。

### 玩家知情边界

- `Policy` 不持有 Session、World 或 Turn；决策输入为 `Session.project()`、`action_catalog()` 和 `current_sources()` 中同时通过 `is_known_source()` 的事实。
- 运行器确实直接读取权威状态来写观察指标，但 `observe()` 的结果没有传回 Policy。没有使用隐藏信众数、同域支出、风险值、未来随机数或未来候选来排序动作。
- 原始已知事实未经 `_public` 裁剪即传入 Policy，但现行策略只读取 proof 的 `kind`、`changes.rule`、`changes.actor`、`id`、`domain`；没有借其 parent/issuer 追溯未知事实。该边界依赖已冻结策略实现，并不保证未来任意 Policy 都安全。
- 所有行动仍通过 Session 预览与执行；准备、关注和回应均支付原规则成本、使用原随机流。ORACLE 准备可能实际无法被随后 DREAM 消费，但它的费用是正常机会成本，不是注入成立支出。

### 策略区别与覆盖边界

| 策略 | 实际固定行为 |
| -- | -- |
| baseline | 不执行祈求、权能、事件主动选项或注意力操作；事件默认结算；存在教团时拟守持。 |
| aggressive | 深应优先、允许梦境/穿隙/播种/掩迹/聆听；偏事件 B；拟传教。 |
| conceal | 浅触有限诉求、不使用权能；偏事件 A，付费 A 会降排序；拟敛藏并释放关注。 |
| expansion | 同域 PR08 成员与 PR05 深应优先，未有团时保留祭仪资金；仅有限梦境/播种/聆听；偏事件 A；拟传教。 |

以上是四种**完整新局启发式策略**，不是已经隔离变量的纯经营三策略实验。激进与扩张都拟传教但祈求/权能选择不同；没有团或真实许可时尚未执行经营，不能凭策略名字推断已比较传教收益。

| ID | 类型 | 严重度 | 已确认的工具限制 | 报告处理 |
| -- | -- | -- | -- | -- |
| BAL-QA-04 | 策略覆盖限制 | Medium | 每个事件阶段只执行第一个成功的主动选项，随后 `progress()` 一次默认处理剩余事件。因而“偏 A/B”不代表逐张主动选择；第二张可能默认走另一分支。 | 分布可以保留为此固定启发式的结果；须披露，不能声称全部事件均按该策略选择。 |
| BAL-QA-05 | 验收覆盖缺口 | Medium | 稳定 checks 覆盖开局、首个成功动作的同 ID 重试、一个未知对象、一份未知教团计划、最终完整保存/恢复与有界退出；没有自动探测牺牲/圣物等有限动作的盈利环，也没有实际重新执行整条轨迹作语义重放。 | 引用已验证上游不变量时分开说明；工具全部完成不等于已证明无套利、无支配，保留完整轨迹也不等于已实际重放。 |
| BAL-QA-06 | 观察口径限制 | Low | `observe().temporary` 读取不存在的 `attention.temporary`，所以恒为 0；`round.turn` 是本轮之前的游标。公开 attention 的 `identities` 是预留身份占用，不能当全局活身份 K。 | P 取 `decision_view.public.attention.people`，N 取 members；全局活身份取 `observe().living`；实际轮号用 `round.after.turn` / `final.turn`。 |

在已审阅来源及两份轨迹中，未发现隐藏状态参与决策、改骰/改人口/免费收益、把达到 60 轮记为失败或混入诊断种子的行为；上述限制不要求抛弃当前固定矩阵，但限制可得结论。

### 统计与性能口径

- `verify.py` 固定三个种子 × 四种策略，单线各最多 60 轮；`--explore` 使用独立目录和结果。正式覆盖 checks 只接受 `ended/censored`，`censored` 不是失败局。首团聚合是单独的 BAL-FIRST-CULT-001，不能被其他技术检查覆盖。
- `phaseTimingsMs` 按进度调用前的阶段分组，是 `Session.progress()` 的墙钟耗时，包含该次自动保存；它不是引擎内部纯规则阶段耗时。`roundTimingsMs` 还包含公开投影、枚举、预览和审计快照等开销。
- `act()` 在计时开始前创建 `before` 完整快照，拒绝后的 atomic 快照和成功重试也在动作计时之外；故 `action.elapsed_ms` 不能解释成全部审计成本。逐轮数据可看总体增长，不能把工具快照的 H 成本全归给游戏回合逻辑。
- 最终保存与恢复另计；保存 bytes 是存档文件大小，`static_memory_bytes` 是引擎进程静态内存观测，非单局纯净内存，也不是目标发行平台 FPS/首屏预算。
- 最终恢复断言比较完整 `Turn.snapshot()` 和已知事实 ID 集合；没有逐个比较所有 Session 表现状态或实际操作系统断电恢复。保存成功不构成发行可靠性验收。
- 来源哈希在矩阵前及每局后核对；原始 result/trace/process.log 有 artifact hash。当前工具宣称的确定性复演机制具备固定策略/种子/来源，但“确实重复执行并一致”仍需独立证据。

### 已完成两局的原始轨迹抽查

仅针对 `runs/19-baseline` 与 `runs/19-aggressive`；不先据两局宣布总体分布。直接解析 JSONL，未修改原始输出。

| 指标 | 19 / baseline | 19 / aggressive |
| -- | -- | -- |
| 实际结束轮号 / 状态 | 60 / censored | 60 / censored |
| 首团 / 锚点 | 均无 | 均无 |
| 最终信仰 / 苏醒 | 18 / 10 | 0 / 10 |
| 事实数：初始观察 → 最终 | 47 → 1857 | 47 → 1960 |
| action 行 | 0 | 305；其中接受 46，拒绝 259 |
| 成员数峰值 | 0 | 0 |
| 公开 P 占用峰值 | 6 | 7 |
| 已采样行动预览/拒绝原子性偏差 | 无行动，未覆盖 | 305 条均未出现 |
| 最终保存/恢复快照 | 相同 | 相同 |

19/aggressive 的实际祈求检定为 PR08 两次失败、一次灾变，PR09 一次失败；另一次入梦被接受。资金在早期耗尽，55 条轮末观察为零信仰，仍能继续结算。大量后续祈求/权能被费用或成员资格拒绝，不能把这些尝试计作有效干预。19/baseline 的无行动不能作为“行动幂等通过”样本；它只验证原始开局边界重试。

两个真实运行都到限存续，不是两场寂灭。19/baseline 在没有成员/团体/锚点下仍持续获得后台请求，断联计数没有连续达到三；这与当前“真实请求可恢复接触”的定义相容，属于需记录的停滞状态，不能冒称已发现无限盈利。

## 派生统计与压缩归档审阅（首版）

对象为新增 `tools/balance/reporting/report.py`、`test_report.py` 和 README；这些分析源码不参与首轮游戏行为。独立执行六项 unittest，均通过：不完整运行、过期已列来源、缺样本、压缩往返及损坏、来源越界、工件越界。

`archived_bytes()` 在本地原始文件缺失时确实回退 gzip，并将解压后原始 bytes 与执行登记摘要比对；压缩档的路径、压缩摘要和 raw 摘要也进入派生报告。来源存在且摘要不符会拒绝，不会静默改用压缩档。此机制支持脱离 `runs` 的复算，但首轮矩阵尚在运行，不能将单个压缩往返测试当作完整 12 局归档复算已执行。

首版发现以下门禁缺口；修复版已独立复核关闭，见下文：

| ID | 类型 | 严重度 | 事实 | 应有边界 |
| -- | -- | -- | -- | -- |
| BAL-QA-07 | 证据绑定缺口 | High | 虽验证 `artifactHashes` 的 raw bytes，却不解析各局原始 `result.json` 并与 baseline.campaign 元数据对应。最终信仰、首团轮号、保存耗时、checks 等直接取 baseline，修改这些元数据仍可能通过原工件校验。 | 对照受摘要保护的原始结果派生/验证元数据，不能只验证工件存在。 |
| BAL-QA-08 | 来源完整性缺口 | High | 对 `sourceHashes` 只检查已列项目，允许空集合或遗漏来源；六项测试只证明已列的过期来源会失败。 | 验证冻结执行来源集合完整，并明确实际来源与静态审阅来源的责任范围。 |
| BAL-QA-09 | 失败发布副作用 | Medium | `main()` 在 `analyse()` 之前写 `BASELINE`；坏输入可能先覆盖耐用基线，再被验证拒绝。 | 验证完成前不替换耐用基线；负面验收结果应可发布，但结构/指纹错误不能覆盖旧证据。 |

当前派生代码确实保留 `baseline.checks` 的 fail，不把执行完成改成验收通过；`status` 根据全部 checks 汇总。上述绑定缺口修复后须再复核，不能以六项现有测试通过宣称门禁完整。

统计用词还需保留采样范围：`maxMembers/maxCults` 是轮末观察峰值，公开 attention 是行动前视图采样峰值，并非逐命令完整峰值；cult 字典长度含 destroyed 历史对象，不能读作活跃教团数。`BAL-ECONOMIC-STRATEGIES` 只检查存储的策略名，附注已说明它不是有效付费传教的充分证据。计时注释已区分 progress 墙钟与仪表化开销、活动/历史混合增长；没有据此宣称 FPS 或发行性能通过。

### 修复版独立复核

重新读取实际修改后的 reporter/test 并独立运行九项 unittest，全部通过。新增缺来源、元数据/原 fail 被改、坏输入不覆盖耐用 baseline 的反例；测试不是重新执行游戏矩阵。

- **BAL-QA-07 已修复**：强制每局三种工件路径；受原始摘要保护的 result 逐字段与 campaign 对照，再核对 trace 的最后状态和首团观测。执行 checks 从原始逐局结果重建，要求与 baseline 完全一致；原 fail 和聚合 status 不得被改写。
- **BAL-QA-08 已修复**：baseline 来源键集合须与实际冻结执行 wrapper 的 `hashes()` 集合相同，再逐文件核摘要。遗漏已不是“未检查就接受”。
- **BAL-QA-09 已修复**：先完成 `analyse()`，再用临时文件替换 baseline；坏输入保留原耐用基线，独立负测已确认。
- 成员峰值已更名 `roundEndMaxMembers`，教团区分历史条目和活跃数量；经营 coverage 改为检查实际 `economy_strategy_payment` 的 effective/reason/fee，单独保留 intent 观测。
- 经营事实统计另有可见性限制：原始 trace 的 Session 回执只带玩家已知 facts，轮末经营支付未必被自动披露。故空支付集合表示**没有在本证据中取得实际经营证明**，不能凭空据此推断所有隐藏结算从未执行。当前无教团样本仍不满足经营覆盖，不形成误报通过。

未发现新的发布阻塞；完整 12 局压缩档脱离 runs 的复算仍待矩阵完成后实测。

## 首轮完整归档独立复算

已实际执行：

```text
python -X utf8 tools/balance/reporting/report.py --input docs/qa/balance-baseline.json --archive-only
```

返回码 **1**，原因是如实保留验收 fail，不是归档读取或结构验证中断。输出 `executionStatus = complete`、12 局、720 个实际完成轮、12 局均 `censored`。已检查 `--archive-only` 分支明确跳过本地原始 runs 文件读取，使用 36 份 gzip 中的原始字节。

另独立逐份校验 36 份压缩字节 sha256、解压后 rawSha256 与 rawBytes；均相符。再次直接调用 archive-only `analyse()`，与刚生成结果比较 metrics、campaigns、checks、artifacts、sourceHashes、status、executionStatus，全部一致。复算不重跑游戏，不混入后续诊断轨迹。

正确计数：

| 层次 | 检查总数 | pass | fail | fail 内容 |
| -- | -- | -- | -- | -- |
| 首轮原始 baseline | 95 | **82** | **13** | 12 项 BAL-PROCESS + 1 项首团覆盖。 |
| 派生与独立静态审阅合并 | 102 | **85** | **17** | 原 13 项原样保留，另实际经营覆盖 1 项、静态生产闭包 3 项。 |

12 份进程日志均有 `ERROR: Failed to read the root certificate store.`，因此严格进程检查均 fail；12 个进程 exit code 均为 0，日志无 `SCRIPT ERROR:`。此项属于本次启动环境错误证据，不能删去或改称通过，也不能与缺少宇宙根、传播许可和详细候选生产者的游戏实现缺口混为同一原因。

首轮没有首团，不能提供该矩阵内的首团完整复演或有效经营比较。后续单列诊断即使发现首团路径，也不改变首轮固定 12 局的 82/13 原始检查计数、720 轮与 12 censored 分布。没有把截尾存续记为寂灭或胜利。

本报告最终审阅已完成；独立审阅指纹应绑定本次最终内容后生成。
