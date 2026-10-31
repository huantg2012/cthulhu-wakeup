# TASK-CONTENT — Formal Content and Causal Comprehension: Discovery and Directions

2026-10-31。仅需求调查与候选方向，不制作内容、不改游戏规则/CSV/界面，不代表本任务通过。方向待制作人选择，task保持planned；总81、已验收40、未完成41。

## 调查结论

原任务混合三类工作：已有内容的因果可理解性、文明行动差异的表达，以及内容/生成缺口。验收ACC-NARRATIVE为人工：不能凭空补背景或复活死者；文明差异要影响行动，人要理解故事；范式变异及灾难/听众背景须有合法来源和实际证据。当前任务前置仍未全部通过，但不阻止本次只读需求调查；不据此提前验收或自动开启制作。

当前CSV静态计数：文明8、祈求12、事件12、权能12、圣物类型6、人物模板6。条目数不等于整局只有这些不同情境，也不证明重复率足够低。narrative-catalog的12–16文明/48–72祈求/60–90事件是旧首发规模提案，未获本次扩量授权，不作为当前目标。

### 已确认的差距

1. 因果记录已有技术入口：Session.history_page仅投影已知事实并隐藏未知前因，GameRoot的编年史提供前因跳转；正文主要通过describe递归输出字段。ActionCatalog也已有祈求人、关联人物、求告方向、期限。不能说完全没有叙事，也不能说这些字段展示已经让人理解故事；尚需生产人可读文本与人工体验核验。
2. 文明已有实质差异：当前civilization_profiles/conditions含证言、祭仪、记忆、节点、契约和法则等路线，专项有受控接入证据。需要检查差异是否在当前请求、选择和后果里可感知，而不是默认再造八套新机制。
3. 范式随机偏移尚无接线：world_initialization.plan选择蓝本；World.generate直接复制蓝本的tech/occult/faith/meme及barrier/stability。本次搜索src未找到paradigm_shift_max或initial_state_jitter的消费者。表与手册有声明，不等于随机变异已实现。这是生成能力待办，不是整体数值平衡问题，也不使上一项合法生成/坏数据/有界失败的有限验收失效。
4. 听众背景有明确资格缺口：WorldInitialization.profile_legal与EventRules的相关检查均直接拒绝requires_listener。初始profiles调用固定crisis_count=0，所以需要灾难的模板也不会在初始生成中出现；后续危机可另有来源，不据此声称所有灾难玩法均缺失。应明确是否需要这些模板、何时抽出合法当下背景，不添加社会传播或事故过程模拟。
5. 内容手册有过时状态说明：例如gameplay-catalog仍写旧关系环、路线表design_only，后续专项已有有限接入/运行证据。应按真实证据范围纠正，而非全部统一改成已完成。

这些是静态代码/资料调查，没有本轮真人体验、重复率测量或引擎测试。

## 可选方向（未选定）

### A. 先让已有故事读得懂

围绕现有诉求、浅/深选择、实际结果、已知后续原因，先做2–3条代表链的本地文本样稿。由制作人选定表达后，再接原有展示入口。只引用当前已知且真实发生的事实；不补过去、不用文本声称未实现能力。不增加祈求类型或模拟步骤。

交付里程碑：制作人面对这几条实际例子，能说明是谁在求什么、选择牺牲什么、结果因何发生。成本相对低；若样稿需要更换界面结构，转TASK-UI的既有UX流程，不能以内容任务绕开。此方向不会补齐原任务全部生成要求，原缺口仍待办。

### B. 先让不同文明有不同味道

先选两种规则确实不同的文明作对照，例如镜证议会与盐梦诸邦：相近诉求在证据/仪式文明里的表达、可选行动及后果各自清楚。复用现有两套路线，不新造机制；先有少量完整内容组合，再决定是否扩至八文明。

交付里程碑：制作人能从具体请求与可执行选项中辨认两文明的差异，不只是名称不同。成本相对中；需要更多上下文文本与分支核对，仍无法替代因果可读性和生成缺口补齐。

### C. 先补内容生成的欠账

先逐项确定范式偏移、灾难与听众背景的必要性，再用CSV限定的少量合法变体/当前情境抽签接入。凡不值得当前实现的旧声明，明确推迟，不留虚假能力承诺。禁止发展人物日程、完整灾难史或逐人传播。

交付里程碑：选定的变体与人物模板确实可生成且有合法背景；少量正反例即可。三方向中工程成本最高，涉及初始化/资格/保存版本边界，实施前需核其接口与原验收归属。它提升生成覆盖，未必立即改善制作人的阅读体验。

A/B/C是先做哪一块的选择，可以分阶段组合；不是三套并行数值方案，当前均未制作。无预估小时数或总体效果保证。整体平衡、视听、发布及在线LLM不在本轮范围。

## 后续落地

选择后在原TASK-CONTENT中锁定本次小批交付与可否证验收，并把涉及的真实机制/界面修改交相应既有任务与spec维护。原ACC-NARRATIVE不修改，不因某个方向交付就把整个任务标为完成；文学品质与故事理解由制作人体验判断。

## 本次调查来源

- docs/vision.md；docs/world.md；docs/content/narrative-catalog.md；docs/content/gameplay-catalog.md。
- docs/implementation/traceability.json中TASK-CONTENT、ACC-NARRATIVE；docs/progress/stage-priorities.md。
- data/civilization_profiles.csv、civilization_parameters.csv、npc_profiles.csv、prayers.csv、events.csv、powers.csv、relics.csv。
- src/simulation/world_initialization.gd：profile_legal、profiles、plan；src/simulation/world.gd：generate。
- src/game/event_rules.gd的requires_listener资格；src/presentation/session.gd：history_page、prayer_title。
- src/presentation/game_root.gd：_render_history、describe；src/presentation/action_catalog.gd：_context。
