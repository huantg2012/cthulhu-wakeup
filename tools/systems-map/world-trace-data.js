(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.WorldTraceData = api;
})(typeof globalThis === 'object' ? globalThis : this, function () {
  'use strict';

  const types = [
    { id: 'config', name: '世界的生成条件', life: '整局保存', meaning: '种子、内容版本、文明与人物蓝本、规模和容量。它们是输入，不是已经发生的故事。' },
    { id: 'wallet', name: '邪神资源与进度', life: '当前账＋来源历史', meaning: '信仰、低语、洞见、创伤、苏醒与历史峰值；低语预算与当前余额分开。' },
    { id: 'domain', name: '域与域间通路', life: '持续身份与当前值', meaning: '星球／星系／宇宙层级、文明蓝本、四项状态、四范式、传播结构、权力组织、现实矛盾及相邻通路。' },
    { id: 'population', name: '人口的三个口径', life: '当前账＋转移流水', meaning: '无名非信众、无名信众、具名活人。提名不是出生；迁入增加当地人口但不增加全世界人口。' },
    { id: 'institution', name: '机构与岗位', life: '持续身份与当前值', meaning: '解释、传播、秩序三个机构；匿名在任、已有代表、空缺和失能不同。各自知道什么也不同。' },
    { id: 'person', name: '具名人物', life: '身份长期保留', meaning: '意志、洞察、影响、适应、理智、忠诚、职责、关切、状态、成员资格、行动占用、冷却与成长来源。' },
    { id: 'relation', name: '人际关系', life: '当前关系＋来源历史', meaning: '谁与谁有什么方向的关系、由什么事实产生。关系不自动授予知晓或材料。初始化与生命周期已接入，完整 Session 与自然来源未验。' },
    { id: 'knowledge', name: '人物／机构／玩家知情', life: '取得历史＋当前投影', meaning: '三份不同的知识账。知道结果不等于知道原因；认出邪神也不等于愿意向它求告。' },
    { id: 'cult', name: '教团', life: '持续身份与当前值', meaning: '成立、领袖、凝聚、策略、休眠和覆灭；首名成员不是已经成立的教团。' },
    { id: 'relic', name: '圣物与所在位置', life: '持续身份与归属历史', meaning: '类型、原始来源、所在地、持有人、绑定锚点、扣押方。转后台不会让这些消失。' },
    { id: 'anchor', name: '锚点与实际依托', life: '固定序号＋当前资格', meaning: '机构、教团、护持者、圣物、材料、污染门槛、供奉与状态。序号门槛与域层级贡献是两套量。' },
    { id: 'source', name: '已发生的处境／材料', life: '原事实保留，资格可失效', meaning: '病危、当下求告、契约义务、记忆风险、异常记录等。有事实才谈得上后继，不先抽台词再补人生。' },
    { id: 'call', name: '人物本次求告', life: '意向与采样依据保存', meaning: '谁、为何、向谁求告，当时知道什么。已提交求告受容量阻挡时可以保留；不因此自动取得详细名额。' },
    { id: 'prayer', name: '固定祈求与行动窗口', life: '窗口关闭，历史仍在', meaning: '固定主体、来源、开放分支、可见轮、到期轮、独立危机、名额预留。固定由系统执行，不是玩家按钮。' },
    { id: 'event', name: '本轮事件与选择', life: '本轮名单＋结果历史', meaning: '主要事件名单、原前因、可选分支、默认后果与选择结果。不是每次打开界面重新抽。' },
    { id: 'evidence', name: '机构证据与确认', life: '查证历史＋当前效力', meaning: '特定机构针对特定目标积累的独立查证、强度和确认；别的机构不能偷用。' },
    { id: 'plan', name: '危机／抵抗／跨轮计划', life: '执行或失效前持续有效', meaning: '执行者、目标、原依据、到期轮和阶段、预告、默认后果、冷却。后台不会推迟原期限。' },
    { id: 'economy', name: '经营与收入资格账', life: '本轮资格＋持久余量', meaning: '策略意向与实际执行、付款排序、轮初收入资格、当轮扣减、流失小数余量、入库和溢出。' },
    { id: 'attention', name: '注意力与人物覆盖', life: '分配与承诺保存', meaning: '重点域 F、成员 N、临时主体 P、本地辅助 L、未来预留、本轮已用与待释放。覆盖不等于本轮必有行动。' },
    { id: 'clock', name: '域的日常／机会时钟', life: '游标与随机位置保存', meaning: '后台日常的到期位置、每域新机会预算、旧处境后继检查、域独立抽样位置。不是所有工作都四轮一次。' },
    { id: 'fact', name: '已经发生的事实', life: '追加历史，不覆写旧事实', meaning: '发生轮次、行为、参与者、地点、前因、实际变化、知情者与一次性消费。下列教学事实不是引擎原始日志。' },
    { id: 'control', name: '回合／结果／存档位置', life: '检查点可续存', meaning: '轮次阶段、回应与行动占用、请求回执、断联、仪式、结束标记、随机流和版本。保存不是额外一轮。' },
    { id: 'projection', name: '当前有效视图', life: '可重新计算', meaning: '详细人物集合、当前苏醒、有效材料／风险与知情索引。即使物化保存，也不是另一套可独立改写的真相。' },
    { id: 'planned', name: '范围受限或仍待复验的状态', life: '不伪装为运行中对象', meaning: '12 类未来材料路线、8 条替代路线的正式生产、整体平衡，以及旧规则基线套件的复验。关系图生命周期与恢复已验收，已移出此类。' }
  ];

  const labels = {
    seed: '种子', contentVersion: '内容基线', viewVersion: '展示记录版本', scale: '域规模', inputKind: '输入性质', selection: '选择方式', boundaries: '范围边界',
    faith: '信仰', whispers: '可用低语', whisperBudget: '本轮低语总预算', insight: '邪神洞见', wounds: '创伤', awakening: '当前苏醒', peak: '历史峰值', capacity: '容量',
    tier: '层级', profile: '文明蓝本', exampleRole: '教学代称（非游戏规则）', paradigms: '四范式权重', communication: '传播结构', authority: '组织方式', weakness: '现实矛盾／文明缺口', barrier: '屏障', pollution: '污染', alert: '察觉', stability: '稳定', focus: '是否重点域', neighbors: '相邻通路',
    total: '当地活人口', nonfollowers: '无名非信众', followers: '无名信众', named: '具名活人', birthplace: '人口口径',
    role: '职责', status: '当前状态', occupancy: '岗位状态', representative: '具名代表', links: '机构往来', source: '依据',
    will: '意志', npcInsight: '人物洞察', influence: '影响', adaptation: '适应', sanity: '理智', loyalty: '忠诚', roles: '职责标签', needs: '当前关切', member: '已绑定成员', cult: '教团归属', institution: '所属机构', identified: '是否认出邪神', acted: '本轮行动', cooldown: '冷却截止', growth: '成长来源',
    from: '关系起点', to: '关系终点', kind: '类型', direction: '方向', knownBy: '谁知道', known: '已知内容', owner: '知情者／拥有者',
    leader: '领袖', cohesion: '凝聚', strategy: '本轮策略', founded: '成立轮', dormant: '休眠轮数',
    holder: '持有人', placement: '所在状态', anchor: '绑定锚点', relic: '绑定圣物', captor: '扣押方', origin: '原始来源', guardian: '护持者', ordinal: '永久序号', contribution: '有效时贡献', upkeep: '每轮供奉', paid: '本轮是否已付', materials: '实际材料', requires: '条件',
    petitioner: '求告者', need: '诉求', root: '原始处境', addressing: '本次方向', sampledKnowledge: '采样时的知情', snapshot: '采样时点', actors: '固定主体', visible: '最早可见轮', due: '原到期轮', crisis: '独立危机', variant: '回应方式', outcome: '结果',
    options: '合法分支', choice: '本次选择', target: '固定目标', issuer: '执行者', strength: '证据强度', confirmed: '是否确认', contributions: '独立贡献来源', defaultResult: '默认后果', announced: '是否已预告',
    incomeEligible: '本轮收入资格', attritionRemainder: '流失余量（人）', localSpend: '本域累计实付信仰', payment: '本轮供奉支出', income: '本轮实际入库', overflow: '本轮散失',
    focused: 'F 重点域', members: 'N 当前成员', temporary: 'P 临时主体', locals: 'L 本地辅助', reservedMembers: '未来成员结果预留', used: '本轮已用待释放', release: '释放条件／时点',
    nextSlot: '本域下一次到期轮（B＋后台日常）', nextDaily: '已并入 nextSlot（旧记录字段兼容）', nextOpportunity: '已并入 nextSlot（旧记录字段兼容）', aResult: 'A 旧事后继：本轮检查结果', bResult: 'B 新处境：本轮尝试结果', rng: '随机位置',
    turn: '轮次', phase: '阶段', summary: '事实内容', parents: '实际前因', changes: '本次留下的变化', replies: '本轮已回应次数', disconnected: '连续断联轮数', ending: '本局结局', ritual: '降临进程', receipts: '回执',
    coverage: '覆盖范围', missing: '未采集部分', value: '当前内容', detail: '说明', writer: '谁产生', when: '生效时机', retained: '留存方式', tasks: '实施任务'
  };

  const weaknesses = [
    { id: 'unexplained_evidence', name: '未解释证据', profile: '镜证议会', meaning: '现有解释容纳不了的异常记录。', opportunity: '进入＝回应真实求证或让合格人物当下受梦并读写反常记录；关键是独立记录真实留存，不要求机构公开认可。' },
    { id: 'ritual_dispute', name: '祭仪争议', profile: '盐梦诸邦', meaning: '不同地方祭仪并存，主持者与记录者对仪式含义和解释权存在争议。', opportunity: '进入＝由真实祭仪者主持或让记录者使用超常节拍；沿同结构两轮真实祭仪或历法持续使用；扎根保留原祭仪者两轮仪式或原记录者两轮历法依赖，无需正统认可。' },
    { id: 'attention_crisis', name: '注意力危机', profile: '千面公社', meaning: '围绕共同记忆与关注：发起者可能从有人响应变成无人理会。', opportunity: '进入＝回应真实记忆风险或促成当前共同见闻再现；传播保留三人登记资格或两位原参加者跨轮再现；扎根由原三见证或原两位持续实践者承载真实神迹记忆。这里的关注不是玩家的 F/P/L 名额。' },
    { id: 'doctrinal_split', name: '教义分裂', profile: '焚星圣统', meaning: '正统与异端对教义、神迹和祭仪的解释不一致。', opportunity: '可通过秘密支系建立联系。正统敌视不等于神迹依赖失效，仍须有真实祭仪与承续者。' },
    { id: 'shared_channel', name: '共享通道', profile: '群机同梦', meaning: '共同协议连接多个节点，可传递尚未解释的异常读数。', opportunity: '进入＝让两个连通节点分别受梦或实际往返异常读数；沿两独立原记录或两端实际使用的共同依赖传播；扎根须保持当前通信与两端真实承载。不模拟社会传播渠道。' },
    { id: 'contract_conflict', name: '契约冲突', profile: '万誓商盟', meaning: '现实中有无法履行的誓约或义务，订约各方无法靠现有手段解决。', opportunity: '对无法履约者的回应可成为联系来源；后续要有实际履约与依赖，不是有契约标签就自动扎根。' },
    { id: 'axiom_exception', name: '法则例外', profile: '自证天穹', meaning: '原本自洽的法则秩序中出现了无法消解的例外，现有解释与实际观察对不上。', opportunity: '可保留、复核并使用真实例外记录；独立观察和跨轮使用不能用复制同一记录代替。' },
    { id: 'collective_dissent', name: '集体异议', profile: '归一众声', meaning: '整体意识试图统一成员，却仍有未被同化的个体，以及无法合并的记忆。', opportunity: '可与这些个体联系，让实际持有的神迹记忆继续存在；不是给集体贴一个异议标签就完成。' }
  ];

  const attentionRoles = [
    { key: 'temporary', code: 'P', name: '临时主体', capacity: '全局最多12名不同人物', why: '为了处理一个已经固定的祈求、事件或未结承诺，必须暂时逐人跟踪的当事人。', example: '某域不是重点，但那里有人已经成了祈求者：为完成这次互动，他仍可由P覆盖。', exit: '只解除这项互动的引用；若没有其它N/P覆盖，也不属于重点域L，才停止普通逐人行为。已用占位到下轮轮初处理，不删人。' },
    { key: 'locals', code: 'L', name: '本地辅助', capacity: '每个重点域最多6名，排除已在N/P的人', why: '让正在重点推演的文明不只有祈求者和信徒：从当地已具名者中补入少量机构代表及其它合格人物。', example: '你关注一个域，其中的记录者、使者或机构代表可能进入L，即使这时没人向你祈求。', exit: '该域退出重点后，不再靠L获得逐人覆盖；有N/P的人仍继续。L不是免费替代固定互动所需P的名额。' },
    { key: 'members', code: 'N', name: '绑定成员', capacity: '全局最多12名', why: '持续跟踪已经绑定的信徒，以及规则要求保留的退役引用。所在域不是重点也可继续逐人处理。', example: '开局祈求者由P覆盖，成功成为绑定成员后转由N覆盖；先落实N，再解除该人的P。', exit: '成员身份、行动权限和占位释放分别判断，不能混成一个开关。' },
    { key: 'focused', code: 'F', name: '重点域', capacity: '最多3个域，开局1个', why: '控制哪些域执行逐轮详细日常，并提供其本地L人物集合。它管域，不是第四种人物身份。', example: '后台的N/P人物依然可以逐人行动；不能用“没有F”推断该域所有人都停算。', exit: '发现或切换界面不等于取得F；撤关注按原轮初释放约定处理。' }
  ];

  const clockExample = [
    ['n轮阶段四', '假定后台域到期且有合格祭仪主持者，B出现门通过，发布一次新祭仪处境。后台日常也按条件算一次。', '下一次域级到期排到n＋4；此时还没有把未来祈求写成已展示。'],
    ['n＋1轮阶段四', 'B没有到期，但A仍检查旧事；假定这次选中上轮祭仪、人物和名额均合法，完成求告与固定。', '固定请求保存原人物、方向、最早可见轮和期限。'],
    ['n＋2轮', '假定展示位置充足、人物仍合法，请求开始可见，玩家这时才有机会回应。', '此例PR05的3轮窗口为n＋2、n＋3、n＋4。'],
    ['n＋4轮', '域级B再次到期；如果请求还没关闭，它的窗口也在本例这轮结束。', '两个时间在此例恰好相遇；请求期限不是B时钟，也不会因B失败而延期。']
  ];

  const sources = {
    generation: { title: '生成、身份与混合初态', scope: '已修复原 ROOT_INITIAL_TIES 归属不匹配导致的拒载；当前 42 表装载通过。示例初态仍是教学选值，不是本轮新局实测', tasks: ['TASK-CATALOG', 'TASK-IDENTITY', 'TASK-ATTENTION'], rule: 'docs/specs/system-civilizations.md', section: '§2–4、§10', report: 'docs/qa/catalog-current.md', supplement: 'docs/qa/attention.md' },
    social: { title: '有限具名关系网', scope: '初始化已接入程序并验收；生命周期与恢复也已验收。示例边是教学取样', tasks: ['TASK-SOCIAL-GRAPH', 'TASK-SOCIAL-GRAPH-DESIGN'], rule: 'docs/specs/system-civilizations.md', section: '§4.1', report: 'docs/qa/social-graph-initialization.md' },
    prayer: { title: 'PR08 与来源／请求整合', scope: '五族来源已限定验收完成；报告未声称 12 类原始处境已全部自然生产', tasks: ['TASK-PRAYER-PRODUCERS', 'TASK-PRAYER-INTEGRATION', 'TASK-PRAYER-ORIGINS', 'TASK-SOURCE-CLOSURE'], rule: 'docs/specs/system-events.md', section: '§11、§14', report: 'docs/qa/prayer-integration.md', supplement: 'docs/qa/source-closure.md' },
    startup: { title: '首团机会与整体平衡', scope: '首团机会已限定校准：6 样本中 3 个在第 3 轮成团、无资金截尾；整体平衡保留为长期任务，840 轮无首团的旧证据保留原范围', tasks: ['TASK-STARTUP-BALANCE', 'TASK-BALANCE'], rule: 'docs/specs/system-turn-economy.md', section: '§11', report: 'docs/qa/startup-balance.md', supplement: 'docs/qa/natural-verify.md' },
    turn: { title: '六阶段与提交边界', scope: '全详细参考基线套件（不启用 F/N/P）；阶段与检查点未变；需在新规则下复验', tasks: ['TASK-TURN', 'TASK-INCREMENTAL-TX'], rule: 'docs/specs/system-turn-economy.md', section: '§3、§10–12', report: 'docs/qa/turn-cycle.md' },
    economy: { title: '人口资格、流失、供奉', scope: '数值来自正式表；下列算例是指定条件下的演算', tasks: ['TASK-ECONOMY'], rule: 'docs/specs/system-turn-economy.md', section: '§11', report: 'docs/qa/economy.md' },
    npc: { title: '四种有限自主行为', scope: '行为选择不是人生模拟；资格不成立就不行动', tasks: ['TASK-NPC-ACTIONS'], rule: 'docs/specs/system-powers-cults.md', section: '§2、§10', report: 'docs/qa/formal-simulation.md', supplement: 'data/npc_behaviors.csv' },
    fidelity: { title: 'N／P／L 与分层职责', scope: '关注域与详细人物集合不是同一个开关', tasks: ['TASK-ATTENTION', 'TASK-PRAYER-DISPATCH'], rule: 'docs/specs/system-civilizations.md', section: '§10–11', report: 'docs/qa/prayer-dispatch.md', supplement: 'docs/qa/fidelity.md' },
    events: { title: '事件、期限、因果留存', scope: '新事件与既定到期工作分开，不递归即时弹卡；§14 已改为轻量情境抽签与来源责任', tasks: ['TASK-EVENTS', 'TASK-HISTORY-INDEX'], rule: 'docs/specs/system-events.md', section: '§5–7、§12–14', report: 'docs/qa/events.md' },
    anchors: { title: '锚点实际材料与持续维护', scope: '实际神迹依托主链已代码化；共享消费已接、替代路线生产待实施；成熟锚恢复链已有限定验收', tasks: ['TASK-ANCHORS', 'TASK-ANCHOR-ROUTES', 'TASK-ANCHOR-LIFECYCLE', 'TASK-MATURE-ANCHOR-NETWORK', 'TASK-CULT-SPREAD'], rule: 'docs/specs/system-progression.md', section: '§3–4、§11', report: 'docs/qa/anchor-routes.md', supplement: 'docs/qa/cult-spread.md' },
    material: { title: '材料递交与接收回执', scope: '个人转交已限定验收；20 族已绑定（8 原材料＋12 路线），4 类不受支持；自然生产仍待验', tasks: ['TASK-MATERIAL-TRANSFER'], rule: 'docs/specs/system-events.md', section: '§13.2', report: 'docs/qa/material-transfer.md' },
    resistance: { title: '有对象、有证据的抵抗', scope: '历史限定报告；到期不会因后台日常未到而延期', tasks: ['TASK-RESISTANCE'], rule: 'docs/specs/system-civilizations.md', section: '§8', report: 'docs/qa/resistance.md' },
    ending: { title: '降临、断联与封存', scope: '终局报告使用合法高阶初态，不证明从自然开局抵达', tasks: ['TASK-ENDINGS'], rule: 'docs/specs/system-progression.md', section: '§7–11', report: 'docs/qa/endings.md', supplement: 'data/powers.csv' },
    opportunity: { title: '主动路线与机会服务', scope: '已限定验收：路线为直接行动，原 B 族有 FIFO 强制票与权重补偿（报告早于 M=1 与 48 轮调整）；给予可行动机会，不直接给予成功', tasks: ['TASK-PROGRESSION-ROUTES', 'TASK-OPPORTUNITY-SCHEDULER', 'TASK-PROGRESSION-OPERATIONS'], rule: 'docs/specs/system-events.md', section: '§14.8–14.13', report: 'docs/qa/opportunity-scheduler.md' },
    guard: { title: '防漏检查与审计', scope: '三项均已限定验收；审计完成不等于缺口已修复，09A 缺处理分支另归密教传播', tasks: ['TASK-CAPABILITY-GUARD', 'TASK-CAPABILITY-PROBES', 'TASK-CAPABILITY-AUDIT'], rule: 'docs/specs/system-events.md', section: '§14', report: 'docs/qa/capability-guard.md', supplement: 'docs/qa/capability-audit.md' }
  };

  const phaseRules = [
    { phase: 0, name: '初始化', read: '内容、种子、域配额、相容性与名额', decide: '先产生合法世界，再建立有限人物与第一份可回应联系。', writes: ['域／机构／通路／人口', '有限人物、初态关系及来源', '独立开局接触、求告、固定卡和名额', '玩家最小知情、版本与随机位置'], keep: '身份、起源事实、版本和初态保存；未选生成候选不成为世界居民。', source: 'generation' },
    { phase: 1, name: '轮初整理', read: '上轮末状态、原定到期项、名额、人口', decide: '先记收入资格，再应用到期的身份与物件变化，最后按此刻苏醒发低语。', writes: ['收入资格（人口变化前）', '死亡／迁移／任职／归属与继任', '既定风险结果、冷却、释放与绑定重查', '本轮低语预算、回应额度与可见请求'], keep: '到期结果进历史；本轮额度更新也进入可恢复检查点。', source: 'turn' },
    { phase: 2, name: '事件处理', read: '当前合法对象、既有前因、事件窗口、互斥和冷却', decide: '冻结本轮 0–2 张主要事件；选分支时重查原对象，不换人、不反复重抽。', writes: ['事件名单、分支选择、费用和结果', '材料递交／证据／关系／物件等条目效果', '后续事件机会与原期限', '只有默认后果时直接结清，不制造空选择'], keep: '展示名单和选择回执保存；新前因最早供下一轮事件筛选。', source: 'events' },
    { phase: 3, name: '玩家行动', read: '当前事实与知情、有效请求、来源、余额与名额', decide: '每次提交先核资格和最大分支名额，再支付、检定、写结果；预览不改变世界。', writes: ['祈求浅／深回应及危机变化', '聆听、入梦、谕言、赐予、任命等权能', '献祭／播种／穿隙／锚定／迁引／掩迹／降临', '圣物去向、策略与供奉计划、敛息', '规划中的主动记录／祭仪／网络试验'], keep: '已执行结果不可因不利而撤回；单纯预览与临时比较不留下新世界事实。', source: 'turn' },
    { phase: 4, name: '锁定与演化', read: '计划与当前资金；预付后冻结的同一份世界视图', decide: '各职责只算一次。先各自决定，再合并；本批新证据不能回喂本批计划选择。', writes: ['先传教、后按优先序供奉；不足转守持／休眠', 'N∪P∪各重点域L中合格人物的有限行为', '重点域逐轮／到期后台域一次的自然恢复', '所有域风险选择、经营与人口变动', '旧处境后继 A（两模式每域每轮查）；到期新机会 B（仅共享游标到期才查）；指定身份告知占同一 B 预算', '证据确认、候选、当前依据与锚点最终重查'], keep: '暂存意图不是历史。提交后保存实际结果、时钟与名额；临时共同视图可丢弃。', source: 'fidelity' },
    { phase: 5, name: '收入与期限', read: '阶段四末教团、剩余轮初收入资格、容量和原到期项', decide: '先收入，再执行指定轮末后果；新信众不在本轮立即产钱。', writes: ['每团应收、入库、溢出与来源', '祈求窗口／独立危机／圣物机会的到期', '到期回执与失效资格归档；预留与名额的释放按各规则原属时点，不在本阶段统一补办'], keep: '收入已经合法入库，不因随后损害倒扣；原危机不随请求关闭而凭空消失。', source: 'economy' },
    { phase: 6, name: '轮末与终局', read: '期限后的世界、教团成立条件、当前锚点／联系／仪式', decide: '完成轮末业务，重算进度与断联；先寂灭，再判仍合格的最后轮降临。', writes: ['满足实际人口／支出／领袖条件才建立教团', '当前苏醒、峰值、下一轮能力资格', '断联计数、仪式推进或中断／最终检定', '结束标记或进入下一轮、封存回顾'], keep: '结束只停止新的普通操作，不删除历史；未结束才进入下一轮。', source: 'ending' }
  ];

  const clone = value => JSON.parse(JSON.stringify(value));
  function entity(id, type, label, domain, fields, refs, source) {
    return { id, type, label, domain: domain || '', fields, refs: refs || [], source: source || 'turn' };
  }
  function baseRecord(id, title, turn, description) {
    return { schemaVersion: 1, id, title, anchorTurn: turn, kind: 'rule-walkthrough', description,
      provenance: { label: '条件演算 · 非实机录像', date: '2026-10-30', basis: '游戏规则基线 763eaa4；本页是独立解释视图', coverage: '业务状态类别全量列出；示例只展开相关记录，不伪造完整引擎事件日志、随机种子结果或自然可达率。', missing: ['引擎真实 RNG 状态和完整历史正文未采集', '中期初态是给定条件，不由开局样本自动长成', '待实施的新关系、材料和机会合同不冒充现有运行能力'] },
      sources: clone(sources), initial: [], steps: [] };
  }
  function builder(record) {
    const state = new Map(record.initial.map(e => [e.id, clone(e)]));
    let changes = [];
    const writer = {
      add(e, reason) { if (state.has(e.id)) throw new Error('重复对象 ' + e.id); state.set(e.id, clone(e)); changes.push({ op: 'create', entity: clone(e), reason }); },
      set(id, field, value, reason) { const e = state.get(id); if (!e || !(field in e.fields)) throw new Error('不存在的字段 ' + id + '/' + field); const before = clone(e.fields[field]); e.fields[field] = clone(value); if (JSON.stringify(before) !== JSON.stringify(value)) changes.push({ op: 'set', id, field, before, after: clone(value), reason }); },
      get(id, field) { return state.get(id).fields[field]; },
      all(type) { return Array.from(state.values()).filter(e => e.type === type); }
    };
    return { record, state, step(meta, write) { changes = []; if (write) write(writer); record.steps.push(Object.assign({ turn: record.anchorTurn, phase: 0, scope: 'shared', source: 'turn', read: [], skipped: [], transient: [], changes: clone(changes) }, meta)); return record.steps.length - 1; } };
  }
  function fact(id, domain, turn, phase, summary, parents, refs, source) {
    return entity(id, 'fact', summary, domain, { turn, phase, summary, parents: parents || [], knownBy: '按实际接收者分别记账，不向所有机构广播', retained: '教学事实摘要；真实日志还含检查点和授权记录' }, refs, source);
  }
  function configEntities() {
    return [entity('DEMO-CONFIG', 'config', '演示规则输入', '', { seed: null, inputKind: '人为选定的合法教学条件，不声称来自某次 seed 输出', contentVersion: '763eaa4', viewVersion: 1, scale: '6 星球＋4 星系＋2 宇宙；每域3机构', boundaries: '示例中的1000是聚合人口口径，不是宇宙设定的真实人口' }, [], 'generation')];
  }
  const profiles = [
    ['镜证议会', '星球', 75, 70, '60 / 0 / 20 / 20', '广播', '议会', '未解释证据'],
    ['盐梦诸邦', '星球', 50, 55, '0 / 50 / 30 / 20', '祭仪', '分散', '祭仪争议'],
    ['千面公社', '星球', 35, 40, '30 / 0 / 20 / 50', '网络', '分散', '注意力危机'],
    ['焚星圣统', '星系', 65, 80, '30 / 10 / 60 / 0', '广播', '层级', '教义分裂'],
    ['群机同梦', '星系', 80, 65, '50 / 20 / 0 / 30', '网络', '议会', '共享通道'],
    ['万誓商盟', '星系', 60, 60, '20 / 30 / 40 / 10', '祭仪', '分散', '契约冲突'],
    ['自证天穹', '宇宙', 95, 95, '60 / 40 / 0 / 0', '网络', '统一', '法则例外'],
    ['归一众声', '宇宙', 90, 90, '10 / 10 / 40 / 40', '网络', '统一', '集体异议']
  ];
  const domainProfiles = [0, 1, 2, 0, 1, 2, 3, 4, 5, 3, 6, 7];
  const domainId = index => 'DEMO-D' + String(index).padStart(2, '0');
  const roleNames = ['解释', '传播', '秩序'];
  function buildWorld(w, turn, mid) {
    domainProfiles.forEach((p, index) => {
      const n = index + 1, id = domainId(n), profile = profiles[p];
      const neighborIds = [n > 1 ? domainId(n - 1) : null, n < 12 ? domainId(n + 1) : null].filter(Boolean);
      w.add(entity(id, 'domain', '域' + String(n).padStart(2, '0') + ' · ' + profile[0], id,
        { tier: profile[1], profile: profile[0], exampleRole: n === 1 ? '甲域：讲解中的主要观察对象' : n === 7 ? '乙域：中期讲解中的后台对照对象' : '未单独指定教学代称', paradigms: '技术／奥秘／信仰／模因 = ' + profile[4], communication: profile[5], authority: profile[6], weakness: profile[7], barrier: profile[2], pollution: 0, alert: 0, stability: profile[3], focus: n === 1, neighbors: neighborIds }, neighborIds.map(target => ({ target, label: '相邻域' })), 'generation'), '域号识别本局对象，文明名表示蓝本；甲／乙只是教学代称，不是游戏中的等级或阵营');
      w.add(entity(id + '-POP', 'population', '域' + n + '人口账', id, { total: 1000, nonfollowers: 1000, followers: 0, named: 0, capacity: 1200, birthplace: '无自然生育／时间增长规则；变化来自转化、迁移、死亡' }, [{ target: id, label: '所属域' }], 'generation'), '初始化聚合人口，不为每一个无名居民建人生');
      roleNames.forEach((role, r) => w.add(entity(id + '-I' + r, 'institution', '域' + n + '·' + role + '机构', id, { role, status: '可运作', occupancy: '匿名在任', representative: '', known: [id + '-ORIGIN'], links: roleNames.map((_, k) => id + '-I' + k).filter(x => x !== id + '-I' + r), source: id + '-ORIGIN' }, [{ target: id, label: '所属域' }], 'generation'), '岗位有人不等于已建立一个隐形具名 NPC'));
      const due = mid ? turn + 2 : n === 1 ? 4 : 1 + ((n - 2) % 4);
      w.add(entity(id + '-CLOCK', 'clock', '域' + String(n).padStart(2, '0') + '工作时钟', id, { nextSlot: due, aResult: '本轮尚未检查', bResult: '本轮尚未检查', rng: null, detail: '一个域级到期轮：新机会B与后台日常共同读取；重点日常每轮执行，旧处境A每轮另查。本例到期位置是教学选值，不是实机相位。' }, [{ target: id, label: '调度对象' }], 'fidelity'), '每域一份到期安排，切重点或页面都不重置；不会自动制造人口或保证出卡');
      w.add(fact(id + '-ORIGIN', id, 0, 0, '域' + n + '的本局起源', [], [{ target: id, label: '产生的域' }], 'generation'), '起源作为以后状态变更的来源，不制造过去事件');
    });
    w.add(entity('DEMO-WALLET', 'wallet', '邪神账本', '', { faith: mid ? 10 : 18, whispers: 3, whisperBudget: 3, insight: 0, wounds: 0, awakening: mid ? 21 : 10, peak: mid ? 21 : 10, capacity: mid ? 81 : 70 }, [], 'economy'), '资源与进度不是某个域的私有库存');
    w.add(entity('DEMO-ATT', 'attention', '全局注意力分配', '', { focused: [domainId(1)], members: [], temporary: [], locals: [], reservedMembers: [], used: [], release: '关闭本请求不释放其他引用；已用名额到下轮轮初处理' }, [], 'fidelity'), '分别登记域关注与人物名额');
    w.add(entity('DEMO-CONTROL', 'control', '回合与结束位置', '', { turn, phase: '初始化', replies: 0, disconnected: 0, ending: '进行中', ritual: '未启动', receipts: '教学步骤记录；引擎逐条回执未采集', rng: null }, [], 'turn'), '版本和位置可保存，不能把未采集随机数写成0');
    w.add(entity('DEMO-PLAYER', 'knowledge', '玩家最小知情', '', { owner: '玩家', known: [domainId(1)], detail: '这里的世界全貌是制作人观察视图，不是玩家能够全知的HUD' }, [{ target: domainId(1), label: '起点已知域' }], 'events'), '玩家只得起点情报，不自动获知全部12域和人物');
    w.add(entity('DEMO-PLANNED', 'planned', '范围受限或仍待复验的世界状态', '', { value: ['关系图生命周期与恢复', '12 类未来材料路线（仍为设计）', '8 条替代路线尚无正式业务生产者', '整体平衡（长期任务）与旧基线复验'], writer: '各相关任务，已接入部分不再列入；本页不补造', tasks: ['TASK-SOCIAL-GRAPH', 'TASK-MATERIAL-TRANSFER', 'TASK-ANCHOR-ROUTES', 'TASK-BALANCE'] }, [], 'opportunity'), '明确区别没有发生、尚未实现和没有采集');
  }
  function person(id, label, domain, institution, attrs, source) {
    return entity(id, 'person', label, domain, { will: attrs[0], npcInsight: attrs[1], influence: attrs[2], adaptation: attrs[3], sanity: attrs[4], loyalty: attrs[5], roles: attrs[6], needs: attrs[7], status: 'active', member: false, cult: '', institution, identified: false, acted: '本轮未行动', cooldown: '无', growth: [], known: [source] }, [{ target: institution, label: '实际机构' }], 'npc');
  }
  function addLocalSix(w) {
    const id = domainId(1);
    const templates = [[2, 3, 1, 2, 75, 15, '记录者', '求知／认可'], [2, 2, 4, 1, 80, 10, '往来使者', '义务／逃离'], [3, 4, 2, 2, 70, 0, '审查者', '判断／求知']];
    for (let n = 1; n <= 6; n++) {
      const inst = id + '-I' + ((n - 1) % 3), pid = 'DEMO-P' + n;
      w.add(person(pid, ['记录者', '使者', '审查者'][(n - 1) % 3] + n, id, inst, templates[(n - 1) % 3], id + '-ORIGIN'), '为本地岗位建立个体记录；属性取正式原型，原型选择为教学条件');
      if (n <= 3) { w.set(inst, 'occupancy', '具名代表', '岗位从匿名转为可指认人物'); w.set(inst, 'representative', pid, '绑定代表身份'); }
    }
    w.set(id + '-POP', 'nonfollowers', 994, '从原1000人中分出6个具名者'); w.set(id + '-POP', 'named', 6, '总人口仍1000');
    w.set('DEMO-ATT', 'locals', ['DEMO-P1', 'DEMO-P2', 'DEMO-P3', 'DEMO-P4', 'DEMO-P5', 'DEMO-P6'], '重点域本地辅助L，不等于教团成员');
    [[1, 2], [1, 3], [4, 5], [4, 6], [2, 6], [5, 3], [2, 5]].forEach((pair, i) => w.add(entity('DEMO-REL' + i, 'relation', '初态接触关系 ' + (i + 1), id, { from: 'DEMO-P' + pair[0], to: 'DEMO-P' + pair[1], kind: '支持', direction: '双向', source: '教学选定的当前初始接触，不是过去见闻', knownBy: pair.map(n => 'DEMO-P' + n), detail: '新有限关系网为设计；本例选择7对合法初态关系，不声称旧运行时已生成此网' }, pair.map(n => ({ target: 'DEMO-P' + n, label: '关系端点' })), 'social'), '同机构/机构往来只提供接触背景，不把所有合法对自动连满'));
  }
  function opening() {
    const record = baseRecord('opening', '开局 → 第一轮', 1, '先看没有具名者的域如何产生机构与人口，再跟随第一位祈求者。普通成功是选定分支，不是实机骰子。');
    record.initial = configEntities(); const b = builder(record);
    b.step({ turn: 0, phase: 0, title: '起点：只有规则输入，还没有本局对象', lead: '此时有蓝本、容量和生成约束，但还没有属于这一局的人、机构或故事。右侧“空集合”有明确含义：尚未生成。', source: 'generation', read: ['DEMO-CONFIG'], skipped: ['未虚构一个随机种子；示例初态由人选定。'] });
    b.step({ turn: 0, phase: 0, title: '建立12个域、36个机构与人口账', lead: '世界骨架先形成。后台域有宏观状态和有人任职的岗位，但没有为每位居民创建人物记录。', source: 'generation', read: ['DEMO-CONFIG'] }, w => buildWorld(w, 0, false));
    b.step({ turn: 0, phase: 0, title: '展开甲域的6名人物与有限关系', lead: '同样1000人：甲域变为994无名＋6具名；其余域仍是聚合人口。关系告诉系统谁可能接触，不凭空生成共同经历。', source: 'social', scope: 'detailed', read: ['DEMO-D01', 'DEMO-D01-POP'], skipped: ['这份7对关系是目标设计的教学取样；旧初始化固定支持环并不等于新网已实现。'] }, addLocalSix);
    b.step({ turn: 0, phase: 0, title: '独立建立第一份无向献身请求', lead: '从甲域原有无名人口中辨认出一位“困惑的记录者”。有P名额和未来成员分支预留，才把人、求告和请求一起固定。不是新出生一人。', source: 'prayer', read: ['DEMO-D01-POP', 'DEMO-D01-I0', 'DEMO-ATT'], skipped: ['未预授忠诚40或成员身份；没有教团、圣物、锚点。'] }, w => {
      w.add(person('DEMO-P7', '第一位祈求者', 'DEMO-D01', 'DEMO-D01-I0', [2, 3, 1, 2, 75, 15, '记录者', '求知／认可'], 'DEMO-D01-ORIGIN'), 'PR08开局模板选择NPC_PROFILE_01');
      w.set('DEMO-D01-POP', 'nonfollowers', 993, '提名扣一名无名非信众'); w.set('DEMO-D01-POP', 'named', 7, '同一人改用具名方式记录，总人口不变');
      w.add(entity('DEMO-ROOT08', 'source', '当下愿向未知回应者献身', 'DEMO-D01', { petitioner: 'DEMO-P7', kind: '当下献身处境', due: '无独立致命危机', status: '当前成立', source: 'DEMO-D01-ORIGIN' }, [{ target: 'DEMO-P7', label: '处境本人' }], 'prayer'), '只写现在的意愿，不制造旧朋友或旧见证');
      w.add(entity('DEMO-CALL08', 'call', '第一次无向求告', 'DEMO-D01', { petitioner: 'DEMO-P7', root: 'DEMO-ROOT08', addressing: '无向', sampledKnowledge: '尚不认识邪神', snapshot: '轮0·独立开局提交', status: '已提交' }, [{ target: 'DEMO-ROOT08', label: '真实处境' }], 'prayer'), '意向与知识在此次采样时锁定');
      w.add(entity('DEMO-PR08', 'prayer', '让我的声音被听见', 'DEMO-D01', { petitioner: 'DEMO-P7', root: 'DEMO-ROOT08', addressing: '无向', actors: ['DEMO-P7'], visible: 1, due: 3, crisis: '无独立危机', status: '已固定，首轮可见', variant: '未选择', outcome: '未回应' }, [{ target: 'DEMO-P7', label: '实际主体' }, { target: 'DEMO-CALL08', label: '本次求告' }], 'prayer'), '由系统固定，预览/玩家未按任何fix按钮');
      w.set('DEMO-ATT', 'temporary', ['DEMO-P7'], 'P临时主体覆盖其有效互动'); w.set('DEMO-ATT', 'reservedMembers', ['DEMO-P7'], '为成功成为成员的分支预留N；预留不等于已入成员');
      w.add(fact('DEMO-F-NOMINATE', 'DEMO-D01', 0, 0, '提名与请求固定', ['DEMO-D01-ORIGIN'], [{ target: 'DEMO-PR08', label: '固定请求' }], 'prayer'), '身份、方向、窗口和名额的本次承诺被保存');
    });
    b.step({ phase: 1, title: '第一轮开始：请求可见，预算发放', lead: '先记轮初收入资格，再清理到期项。没有到期伤害；低语确定为3。你看到这位请求者，不因此看到所有人的私密信息。', source: 'turn', read: ['DEMO-CONTROL', 'DEMO-WALLET', 'DEMO-PR08'], skipped: ['收入资格0：不是没有人口，而是还没有无名信众。'] }, w => {
      w.set('DEMO-CONTROL', 'turn', 1, '推进本轮'); w.set('DEMO-CONTROL', 'phase', '轮初整理完成', '阶段位置也可续存');
      w.set('DEMO-PR08', 'status', '可见且可回应', '开局专例不需再等T+2'); w.set('DEMO-PLAYER', 'known', ['DEMO-D01', 'DEMO-P7', 'DEMO-PR08'], '给予请求所需最小线索');
      w.add(entity('DEMO-ECO-A', 'economy', '甲域本轮经营账', 'DEMO-D01', { incomeEligible: 0, attritionRemainder: 0, localSpend: 0, payment: 0, income: 0, overflow: 0, strategy: '尚无教团' }, [], 'economy'), '本轮人口资格与钱分别记账');
    });
    b.step({ phase: 2, title: '事件阶段：本例没有合格主要事件', lead: '筛选不是凭空抽剧情。此例尚无可触发主要事件的历史、危机或合法前因，所以是0张。PR08是祈求，不占这里的事件名单。', source: 'events', read: ['DEMO-PR08'], skipped: ['0张是“检查后没有”，不是漏执行。无临时意图被伪装成持久事件。'] }, w => w.set('DEMO-CONTROL', 'phase', '事件处理完成', '阶段可无业务增量但位置继续'));
    b.step({ phase: 3, title: '浅触普通成功：同一个人变为绑定信徒', lead: '假定这次落入普通成功档。你花1低语、0信仰；他忠诚15→40、理智75→72，甲域污染0→2。无名信众仍是0，教团仍未成立。', source: 'prayer', scope: 'shared', read: ['DEMO-P7', 'DEMO-PR08', 'DEMO-WALLET', 'DEMO-ATT'], skipped: ['这个分支没有察觉+10，也没有额外无名信众；不得把深应效果套到浅触。', '认出邪神是成功后取得；原无向请求不改成定向。'] }, w => {
      w.set('DEMO-CONTROL', 'phase', '玩家行动已提交', '实际结果保存'); w.set('DEMO-CONTROL', 'replies', 1, '消耗当轮唯一回应'); w.set('DEMO-WALLET', 'whispers', 2, '3−1，浅触无信仰费用');
      w.set('DEMO-P7', 'sanity', 72, 'PR08浅触始终成本−3'); w.set('DEMO-P7', 'loyalty', 40, '成功把忠诚至少提高到40'); w.set('DEMO-P7', 'member', true, '同一身份正式绑定，不是另造一个人'); w.set('DEMO-P7', 'identified', true, '本人感知本次成功献身并取得身份知晓'); w.set('DEMO-D01', 'pollution', 2, '浅触成功的公共污染');
      w.set('DEMO-ATT', 'members', ['DEMO-P7'], '由N继续覆盖'); w.set('DEMO-ATT', 'temporary', [], '解除本请求持有，不影响N覆盖'); w.set('DEMO-ATT', 'reservedMembers', [], '预留转为实际成员'); w.set('DEMO-ATT', 'used', ['DEMO-P7'], '本轮使用标记到轮初清理，与是否成员分开');
      w.set('DEMO-PR08', 'status', '已回应并关闭', '本次窗口不可再消费'); w.set('DEMO-PR08', 'variant', '浅触', '记录选择'); w.set('DEMO-PR08', 'outcome', '条件示例：普通成功', '未采集真实骰值，不伪造RNG');
      w.add(fact('DEMO-F-REPLY', 'DEMO-D01', 1, 3, '成功献身、成员绑定与辨认', ['DEMO-F-NOMINATE'], [{ target: 'DEMO-P7', label: '发生在这个人身上' }], 'prayer'), '实际回应、支付、成员与识别在引擎中各有记录，此处为教学摘要');
      w.add(fact('DEMO-F-MIRACLE', 'DEMO-D01', 1, 3, '祈求者亲历的私密神迹', ['DEMO-F-REPLY'], [{ target: 'DEMO-P7', label: '实际见证人' }], 'prayer'), '是此刻发生的新见闻，不是提名时继承的历史'); w.set('DEMO-P7', 'known', ['DEMO-D01-ORIGIN', 'DEMO-F-REPLY', 'DEMO-F-MIRACLE'], '只给实际接收者知识');
    });
    b.step({ phase: 4, title: '演化：人、日常、风险、来源分别处理', lead: '祈求者因N仍在详细集合，能依据亲历的私密神迹“解释神迹”：忠诚+4、理智−2。甲域本轮成功干预，所以不补屏障、不自然减污染。后台到期域只算一次日常，不乘4。', source: 'fidelity', scope: 'mixed', read: ['DEMO-ATT', 'DEMO-P7', 'DEMO-F-MIRACLE', 'DEMO-D01', 'DEMO-D02-CLOCK'], transient: ['各人的候选动作与评分先在共同视图中比较；没有合法来源的人不行动。', '甲域新神迹发生在本轮；旧记录后继筛选要求原事实轮早于本轮，所以留待下一轮检查。'], skipped: ['其他6人：无已知伤害／暴露／亲历神迹可用，本例不动作。', '私密解释不等于公开暴露，不给察觉+1。', '其余域无旧原根；本例给定所有到期新机会B都未命中，不能把这个分支说成每局都没新卡。'] }, w => {
      w.set('DEMO-CONTROL', 'phase', '阶段四业务片段', '子步骤不是一个新回合'); w.set('DEMO-P7', 'loyalty', 44, '2＋适应2＝4'); w.set('DEMO-P7', 'sanity', 70, '自主解释的理智成本2'); w.set('DEMO-P7', 'acted', '解释自己亲历的私密神迹', '按资格与评分选择，不掷行为骰'); w.set('DEMO-P7', 'cooldown', '解释类到轮2结束', '下一个完整回合不能重复同类'); w.set('DEMO-P7', 'growth', ['DEMO-F-MIRACLE'], '一条不同来源，不立即升属性');
      w.add(fact('DEMO-F-NPC', 'DEMO-D01', 1, 4, '祈求者自行解释私密见闻', ['DEMO-F-MIRACLE'], [{ target: 'DEMO-P7', label: '行为者' }], 'npc'), '保存行为、成本和成长来源');
      w.all('clock').forEach(clock => {
        if (clock.fields.nextSlot > 1) { w.set(clock.id, 'bResult', '未到期，没有尝试新处境', 'A仍逐轮检查；未到期不掷B出现骰'); return; }
        const d = clock.domain;
        w.set(d, 'barrier', Math.min(100, w.get(d, 'barrier') + 1), '该后台域本例到期，秩序运作且无新干预／持续公开异常');
        w.set(clock.id, 'bResult', '本例条件：有合法当前接触可尝试，但此次35%出现门未中', '教学选定的未命中分支，不是实测骰值；后台日常仍照常执行');
        w.set(clock.id, 'nextSlot', 5, '先用旧到期轮判断两项职责，再统一推进到本轮1＋4；只改一份域时钟');
      });
      w.all('clock').forEach(clock => w.set(clock.id, 'aResult', clock.domain === 'DEMO-D01' ? '本轮新神迹尚不作为旧根固定；下轮再核' : '没有已发布的合格旧根', 'A每轮检查，不随B的4轮时钟一起跳过'));
      w.add(entity('DEMO-A-SCAN', 'projection', '下一轮要继续检查的见闻', 'DEMO-D01', { value: '第一位祈求者已经知道本轮私密神迹，下一轮可进入求知来源检查', detail: '现在只是来源，尚未固定PR04，不占一张新卡，也不是保证未来成功' }, [{ target: 'DEMO-F-MIRACLE', label: '等待后继的原事实' }], 'fidelity'), '真实来源留下来，未发生的求告不先写成已发生');
    });
    b.step({ phase: 5, title: '收入：没有教团，本轮仍不产供奉', lead: '绑定一个人物不会自动增加无名信众，也未产生8信仰本域实付。教团条件不齐，供奉为0。已经关闭的PR08不再追加一次未回应惩罚。', source: 'economy', read: ['DEMO-ECO-A', 'DEMO-D01-POP', 'DEMO-P7'], skipped: ['本例没有另一个已到期危机；关闭PR08不等于删除它的身份与结果。'] }, w => w.set('DEMO-CONTROL', 'phase', '收入与期限完成', '实际零收入与零到期结果仍是一个明确结算结果'));
    b.step({ phase: 6, title: '轮末：有成员，仍要检查下一次可执行联系', lead: '人口守恒、一个绑定信徒、污染2、信仰18。本分支没有教团、未关闭的固定请求或可用媒介；新的见闻尚未固定成下次机会，因此断联0→1，还不到3轮寂灭。这不是让人物消失，也不是抹掉他对邪神的认识。', source: 'ending', read: ['DEMO-WALLET', 'DEMO-PR08', 'DEMO-P7', 'DEMO-A-SCAN'], skipped: ['成员身份不是永久续命许可；下轮出现实际可执行联系时才清零计数。', '中期实例是另一份给定初态，不冒充从这一轮自然跑出的录像。'] }, w => { w.set('DEMO-CONTROL', 'phase', '轮1末', '下一轮继续这些对象与来源，不重新造人'); w.set('DEMO-CONTROL', 'disconnected', 1, '本例没有下一次已成立可执行联系；只是待检查的新见闻不算'); });
    return record;
  }

  function middle(turn) {
    const n = turn || 40;
    const record = baseRecord('middle', '中期 · 通用回合 n', n, '给定一份已有两个教团与锚点的中期状态。n只是时间坐标；修改n会平移原期限，不运行或重抽游戏。');
    record.initial = configEntities(); const start = builder(record);
    start.step({}, w => {
      buildWorld(w, n - 1, true);
      const a = 'DEMO-D01', z = 'DEMO-D07';
      [a, z].forEach((d, k) => {
        const pid = k === 0 ? 'DEMO-A-GUARD' : 'DEMO-B-GUARD', cult = d + '-CULT', relic = d + '-RELIC', anchor = d + '-ANCHOR';
        w.set(d, 'barrier', 50, '给定中期状态'); w.set(d, 'pollution', 30, '两处均满足第一锚维持20'); w.set(d, 'alert', 70, '给定风险强度，不代表自动发动攻击');
        w.set(d + '-POP', 'nonfollowers', 974, '25无名信众＋1具名＋974无名非信众'); w.set(d + '-POP', 'followers', 25, '给定早于本轮的教团基础'); w.set(d + '-POP', 'named', 1, '身份不在后台时消失');
        const p = person(pid, k === 0 ? '甲域领袖兼护持者' : '乙域领袖兼护持者', d, d + '-I0', [3, 3, 2, 2, k === 0 ? 70 : 50, 80, '教团领袖／护持者', '照料／逃离'], d + '-ORIGIN');
        p.fields.member = true; p.fields.cult = cult; p.fields.identified = true; w.add(p, '中期输入已给定的绑定成员，不是这一步新招');
        w.add(entity(cult, 'cult', k === 0 ? '甲教团' : '乙教团', d, { leader: pid, cohesion: 80, status: '活跃', strategy: '守持', founded: n - 10, dormant: 0 }, [{ target: pid, label: '领袖' }, { target: d, label: '经营域' }], 'economy'), '已有成立来源（教学假定），不冒充从第一轮的自然到达');
        w.add(entity(relic, 'relic', k === 0 ? '甲域见证透镜' : '乙域根钉', d, { kind: k === 0 ? '见证透镜' : '根钉', placement: '绑定锚点', holder: pid, anchor, captor: '', origin: d + '-MATERIAL' }, [{ target: anchor, label: '所撑锚点' }, { target: pid, label: '控制者' }], 'anchors'), '中期输入含真实控制与唯一归属前提');
        w.add(entity(d + '-MATERIAL', 'source', k === 0 ? '甲域独立记录包' : '乙域实际祭仪承续', d, { kind: k === 0 ? '两名原见证者、两根、不同回合的实际独立记录' : '真实祭仪及其实际承续者', status: '教学前提：有效', materials: '本示例摘要给定；原材料全文、见证人的完整过去未采集', knownBy: [pid], detail: '实际锚依据新语义仍待接线，不能把此卡当自然可达证明' }, [{ target: d + '-I0', label: '承载结构' }], 'anchors'), '不以官方态度替代材料');
        w.add(entity(anchor, 'anchor', k === 0 ? '甲域第一锚' : '乙域第一锚', d, { institution: d + '-I0', ordinal: 1, guardian: pid, cult, relic, status: '有效（延续上轮）', contribution: k === 0 ? 4 : 7, upkeep: k === 0 ? 1 : 2, paid: false, materials: [d + '-MATERIAL'], requires: '第一序号建立25／维持20；无名信众≥12，凝聚≥40，原护持者与圣物有效' }, [{ target: pid, label: '护持者' }, { target: relic, label: '媒介' }, { target: d + '-MATERIAL', label: '实际依托' }], 'anchors'), '25/20按序号；4/1与7/2按域层级，不能混为一列');
        w.add(entity(d + '-ECO', 'economy', k === 0 ? '甲域经营账' : '乙域经营账', d, { incomeEligible: 0, attritionRemainder: 0.9, localSpend: 8, payment: 0, income: 0, overflow: 0, strategy: '守持' }, [{ target: cult, label: '结算教团' }], 'economy'), '本轮收入资格尚待轮初捕获，余量从过去保留');
      });
      w.set('DEMO-ATT', 'members', ['DEMO-A-GUARD', 'DEMO-B-GUARD'], 'N覆盖两名护持者，乙域不重点也逐人处理');
      [1, 2].forEach(i => {
        const pid = 'DEMO-A-WITNESS' + i, rid = 'DEMO-A-RECORD' + i;
        const p = person(pid, '甲域原见证者' + i, a, a + '-I0', [2, 3, 1, 2, 75, 15, '记录者', '求知'], a + '-ORIGIN');
        p.fields.known = [rid]; p.fields.cooldown = '相关旧请求已结，原来源不重复求告'; w.add(p, '实际独立见证者，不能在材料包里只写两个人却不保存其身份');
        w.add(entity(rid, 'source', '独立秘密记录' + i, a, { kind: '独立证言', turn: n - 5 + i, owner: pid, status: '材料有效，原请求已结', source: a + '-ORIGIN', knownBy: [pid, 'DEMO-A-GUARD'], detail: '中期输入给定实际见闻与合法材料保管；原始完整经过未采集' }, [{ target: pid, label: '原见证者' }, { target: a + '-I0', label: '保存结构' }], 'anchors'), '不同人、不同轮、不同根，不是复制同一记录');
      });
      w.set(a + '-POP', 'named', 3, '甲域输入为护持者＋两名原见证者'); w.set(a + '-POP', 'nonfollowers', 972, '25信众＋3具名＋972非信众＝1000');
      w.set('DEMO-ATT', 'locals', ['DEMO-A-WITNESS1', 'DEMO-A-WITNESS2'], '有资格的本地辅助仍单列，不与N重复');
      w.set(a + '-MATERIAL', 'materials', ['DEMO-A-RECORD1', 'DEMO-A-RECORD2'], '实际包引用两条独立记录；不再只用一句“材料齐全”');
      w.add(fact('DEMO-B-HARM', z, n - 2, 4, '乙域护持者已知的伤害', [z + '-ORIGIN'], [{ target: 'DEMO-B-GUARD', label: '受伤者' }], 'npc'), '真实伤害作为整顿来源；非现场补一个标签'); w.set('DEMO-B-GUARD', 'known', [z + '-ORIGIN', 'DEMO-B-HARM'], '有本人已知的strain/harm，才有整顿资格');
      w.add(entity('DEMO-B-CONFIRM', 'evidence', '乙域秩序机构对教团成员的已确认线索', z, { owner: z + '-I2', target: 'DEMO-B-GUARD', strength: 3, confirmed: true, contributions: '独立查证来源束作为中期前提；原始逐条日志未采集', source: '过去实际暴露与确认' }, [{ target: 'DEMO-B-GUARD', label: '固定目标' }], 'resistance'), '有证据的旧风险，不用察觉70凭空指定目标');
      w.add(entity('DEMO-B-PURGE', 'plan', '乙域已预告的教团清洗', z, { issuer: z + '-I2', target: 'DEMO-B-GUARD', source: 'DEMO-B-CONFIRM', due: n + 1, phase: '轮初', status: '已预告，等待到期', announced: true, defaultResult: '到期当前无名信众×20%向上取整；凝聚−10', cooldown: '执行或取消后才开始完整冷却' }, [{ target: 'DEMO-B-CONFIRM', label: '实际证据' }, { target: z + '-CULT', label: '关联教团' }], 'resistance'), '期限在n+1，不因后台日常n+2而改期');
      w.set('DEMO-PLAYER', 'known', [a, z, 'DEMO-A-GUARD', 'DEMO-B-GUARD', 'DEMO-B-PURGE'], '假定玩家已获得两域与预告，非全知所有域');
      w.all('clock').forEach(c => { w.set(c.id, 'nextSlot', n + 2, '本域四轮槽尚未到期：B不尝试、后台不做日常；A、经济和风险照常'); w.set(c.id, 'bResult', '本轮四轮槽未到期，B尚不尝试', '不是抽样失败，更不是欠一张卡'); });
    });
    record.initial = Array.from(start.state.values()).map(clone); record.steps = []; const b = builder(record);
    b.step({ phase: 1, title: 'n轮起点：两个域完整摊在同一世界里', lead: '甲域重点，乙域后台；两个教团均25无名信众、凝聚80、流失余量0.9，各有一个有效第一锚。全球信仰10，苏醒10＋4＋7＝21。原定清洗在n+1轮初，后台日常到n+2。', source: 'generation', read: ['DEMO-D01', 'DEMO-D07', 'DEMO-WALLET', 'DEMO-B-PURGE'], skipped: ['其余10域仍在世界对象清单；本例给定它们无教团、无计划、无本轮到期。', '材料与旧证据以有源摘要作为输入；完整历史未采集，不能据此证明中期可自然到达。'] });
    b.step({ phase: 1, title: '轮初：记下各25人的收入资格', lead: '两域还未发生本轮人口变化，资格各25。暂无到期伤害。低语按苏醒21定为3；并不是后台域只得四分之一预算。', source: 'economy', read: ['DEMO-D01-POP', 'DEMO-D07-POP', 'DEMO-ATT'] }, w => { w.set('DEMO-CONTROL', 'turn', n, '开始n轮'); w.set('DEMO-CONTROL', 'phase', '轮初整理完成', '阶段位置推进'); ['DEMO-D01-ECO', 'DEMO-D07-ECO'].forEach(id => w.set(id, 'incomeEligible', 25, '先捕获旧信众，再处理本轮变化')); });
    b.step({ phase: 2, title: '事件阶段：旧记录引出“第二份证词”', lead: '甲域的两份秘密记录都有效，来源位于事件的2–6轮触发窗口；假定冷却已结束、无互斥且有名额，选入“第二份证词”。本分支选择A保密：记录继续由实际持有人保存，不增加一份独立材料，也不公开给所有机构。', source: 'events', read: ['DEMO-A-RECORD1', 'DEMO-A-RECORD2', 'DEMO-D01-MATERIAL', 'DEMO-B-PURGE'], skipped: ['A为0信仰、不投骰、不占唯一祈求回应。', 'B公开才会新增公开知情与察觉+6；未选B不能把它的效果也算进来。', '乙域未到期清洗不在这里重发或改目标，原n+1期限保留。'] }, w => {
      w.set('DEMO-CONTROL', 'phase', '事件处理完成', '事件选择和结果是持久记录');
      w.add(entity('DEMO-M-EVENT02', 'event', '第二份证词 · 已选保密', 'DEMO-D01', { kind: 'EVENT_02', source: 'DEMO-A-RECORD1', actors: ['DEMO-A-WITNESS1', 'DEMO-A-WITNESS2'], due: n + 2, options: ['A保密：0费用', 'B公开：0费用，新增公开知情、察觉+6'], choice: 'A保密', status: '已结算', outcome: '原记录继续秘密保管；无新增独立材料' }, [{ target: 'DEMO-D01-MATERIAL', label: '绑定的实际记录包' }], 'events'), '由过去来源筛出来的事件，不先抽台词再补两个证人');
      w.add(fact('DEMO-M-PRIVATE', 'DEMO-D01', n, 2, '本次选择继续保密', ['DEMO-A-RECORD1', 'DEMO-A-RECORD2'], [{ target: 'DEMO-M-EVENT02', label: '对应事件选择' }], 'events'), '保存private_records选择结果；它不是第三份独立见证');
    });
    b.step({ phase: 3, title: '玩家：两团守持，供奉按甲→乙排序', lead: '本分支不回应、不用权能，只保留经营与供奉计划。计划本身不扣钱，也不提前让锚点休眠。其它合法行动见下面的阶段覆盖清单。', source: 'turn', read: ['DEMO-WALLET', 'DEMO-D01-ANCHOR', 'DEMO-D07-ANCHOR'] }, w => w.set('DEMO-CONTROL', 'phase', '行动结束，计划已锁定', '这一刻后本轮不再改经营计划'));
    b.step({ phase: 4, title: '演化① 先付费：10 → 7信仰', lead: '两团守持没有传教费。甲星球锚扣1、乙星系锚扣2，共3；然后才冻结共同视图。不是先拿本轮预计收入来付款。', source: 'economy', read: ['DEMO-WALLET', 'DEMO-D01-ECO', 'DEMO-D07-ECO'], transient: ['各职责读取同一份预付后状态，尚未把人物的新结果当作输入。'] }, w => {
      w.set('DEMO-WALLET', 'faith', 7, '10−1−2＝7'); ['DEMO-D01', 'DEMO-D07'].forEach((d, i) => { w.set(d + '-ANCHOR', 'paid', true, '真实本轮供奉已扣；仍须最终条件复核'); w.set(d + '-ECO', 'payment', i + 1, '分别按星球1、星系2'); });
      w.add(fact('DEMO-M-PAY', '', n, 4, '两处锚点实付供奉', [], [{ target: 'DEMO-D01-ANCHOR', label: '甲' }, { target: 'DEMO-D07-ANCHOR', label: '乙' }], 'economy'), '实际支付留痕，不靠改计划提前失效');
    });
    b.step({ phase: 4, title: '演化② 后台的成员仍然自行整顿', lead: '乙护持者因N在详细集合：有已知伤害、理智50＜60、没有占用／冷却，选择自我整顿。意志3，所以恢复2＋⌊3/2⌋＝3：50→53。甲护持者没有合格来源，不为了“每人一次”硬做一件事。', source: 'npc', scope: 'detailed', read: ['DEMO-ATT', 'DEMO-B-GUARD', 'DEMO-B-HARM'], skipped: ['后台域≠里面所有人都不逐人算。', '这轮只有一个已满足条件的动作，不代表所有回合都是1次。'] }, w => {
      w.set('DEMO-B-GUARD', 'sanity', 53, '自我整顿2＋⌊意志3/2⌋；不掷行为骰'); w.set('DEMO-B-GUARD', 'acted', '自我整顿', '只处理资格与分数选中的那一项'); w.set('DEMO-B-GUARD', 'cooldown', '至轮' + (n + 1) + '结束', '下一整轮该类行为冷却');
      w.add(fact('DEMO-M-RECOVER', 'DEMO-D07', n, 4, '乙域成员在后台仍自行恢复', ['DEMO-B-HARM'], [{ target: 'DEMO-B-GUARD', label: '实际行动者' }], 'npc'), '原伤害与本次恢复同时在历史中，恢复不删除伤害');
    });
    b.step({ phase: 4, title: '演化③ 日常一边更新；经济与风险两边照算', lead: '甲域补屏障50→51、察觉70→66；乙域日常尚未到期，这两值不动。两处有效锚都阻止自然污染衰退。两团各流失1个无名信众：25×0.02×(1−0.8)＋0.9＝1；这只是脱教，不是死亡。', source: 'fidelity', scope: 'mixed', read: ['DEMO-D01', 'DEMO-D07', 'DEMO-D01-ECO', 'DEMO-D07-ECO', 'DEMO-B-PURGE'], transient: ['人物、自然变化、风险、经济与候选各自产生意图后合并。', '两模式旧根A都检查；本例没有合格未结原根。B未到期，不投出现骰。'], skipped: ['没有逐人模拟25名无名信众为何脱教；人数按公式聚合变化。', '乙的既有清洗不因后台或日常未到而撤回；不另选第二个主计划。'] }, w => {
      w.set('DEMO-D01', 'barrier', 51, '重点域本轮可恢复；机构运转且无成功污染干预／公开异常'); w.set('DEMO-D01', 'alert', 66, '无新暴露及持续公开异常，减4不是遗忘事实');
      ['DEMO-D01', 'DEMO-D07'].forEach(d => { w.set(d + '-POP', 'followers', 24, '流失恰好1人'); w.set(d + '-POP', 'nonfollowers', w.get(d + '-POP', 'nonfollowers') + 1, '转回本地非信众，总活人口仍1000'); w.set(d + '-ECO', 'incomeEligible', 24, '先扣旧资格；不能晚点用min(轮初,轮末)猜回来'); w.set(d + '-ECO', 'attritionRemainder', 0, '0.9＋0.1后扣去整1人'); w.set(d + '-ANCHOR', 'status', '有效（本轮复核后）', '人数24≥12、凝聚80≥40、污染30≥20、绑定及供奉仍有效'); });
      w.all('clock').forEach(c => w.set(c.id, 'aResult', '本例检查后无合格旧处境；不补抽', '检查与实际产出不是一个数量'));
      w.add(fact('DEMO-M-EVOLVE', '', n, 4, '共同视图的实际合并结果', ['DEMO-M-PAY'], [{ target: 'DEMO-D01', label: '重点日常' }, { target: 'DEMO-D07', label: '后台经济与风险' }], 'fidelity'), '没有第二份后台人口账或后台信仰收入');
    });
    b.step({ phase: 5, title: '收入：各入库3，信仰7 → 13', lead: '收入按剩余旧资格24人与凝聚80计算：⌊min(8,√24)×0.8⌋＝3。两域都本轮结算，不等后台第4轮。清洗原期限尚未到，本轮不执行。', source: 'economy', read: ['DEMO-D01-ECO', 'DEMO-D07-ECO', 'DEMO-B-PURGE'] }, w => { w.set('DEMO-WALLET', 'faith', 13, '7＋3＋3＝13，未触容量81'); ['DEMO-D01-ECO', 'DEMO-D07-ECO'].forEach(id => w.set(id, 'income', 3, '按本轮实际资格和凝聚算一次')); w.set('DEMO-CONTROL', 'phase', '收入与期限完成', '已合法入库，后来的伤害不追扣'); w.add(fact('DEMO-M-INCOME', '', n, 5, '两团本轮供奉各3', ['DEMO-M-EVOLVE'], [], 'economy'), '应收／入库／溢出可各自追因'); });
    b.step({ phase: 6, title: 'n轮末：这一份世界成为下一轮输入', lead: '两个锚仍贡献4＋7，苏醒仍21；有活跃教团，断联0。人物、余量、原计划和历史都留下来，不会在下一轮重造。', source: 'ending', read: ['DEMO-WALLET', 'DEMO-D01-ANCHOR', 'DEMO-D07-ANCHOR', 'DEMO-B-PURGE'] }, w => w.set('DEMO-CONTROL', 'phase', '轮末，等待下一轮', '只有六阶段，无独立“检查点阶段”'));
    b.step({ turn: n + 1, phase: 1, title: 'n＋1：后台未到日常更新，清洗已经到期', lead: '仍检查原机构、目标和证据。若都有效且承受预告后果：乙域损失⌈24×20%⌉＝5名无名信众、凝聚80→70，总活人口1000→995。护持者本人不因此被误杀。', source: 'resistance', read: ['DEMO-B-PURGE', 'DEMO-B-CONFIRM', 'DEMO-D07-POP', 'DEMO-B-GUARD'], skipped: ['这不是后台日常：日常仍在n+2。', '只毁哪种对象由实际效果决定；PURGE不能顺便杀具名者或销毁圣物。'] }, w => { w.set('DEMO-CONTROL', 'turn', n + 1, '下轮开始'); w.set('DEMO-CONTROL', 'phase', '轮初到期清洗完成', '不是等到后台日常才结算'); w.set('DEMO-D07-POP', 'followers', 19, '24−5；损失只来自该团无名信众'); w.set('DEMO-D07-POP', 'total', 995, '死亡一次，人口减少5'); w.set('DEMO-D07-CULT', 'cohesion', 70, '实际清洗凝聚−10'); w.set('DEMO-D07-ECO', 'incomeEligible', 19, '先捕获24再扣5'); w.set('DEMO-B-PURGE', 'status', '已执行', '留下原计划与结果，不循环重打'); w.set('DEMO-B-PURGE', 'cooldown', '从轮' + (n + 2) + '开始计4个完整回合', '执行后下一轮起算'); w.add(fact('DEMO-M-PURGE', 'DEMO-D07', n + 1, 1, '预告中的清洗如期落地', ['DEMO-B-CONFIRM'], [{ target: 'DEMO-D07-CULT', label: '受损教团' }], 'resistance'), '反作用成为后来人物、关系、事件的真实来源'); });
    return record;
  }

  const compare = [
    ['一个域的日常', '每轮检查一次自然恢复', '本轮跳过日常；不是把当前状态重置', '本轮算一次，不乘以4', '屏障／污染／察觉按各自前提；稳定不自动漂移'],
    ['这个域里一个N／P人物', '按个人资格参加详细推演', '仍参加；不因所在域后台而退出', '仍参加', '决定因素是人的覆盖与资格，不是域颜色'],
    ['这个域的L辅助人物', '本地最多6名，按资格行动', '不再由L覆盖；若无N/P则暂停自主行为', '不为全体居民补演过去四轮', '退出详细不删 ID、不清游标，也不删除人物；圣物归属是否保留未单独写明'],
    ['教团经营与锚点供奉', '按原规则逐轮', '同样逐轮', '同样逐轮，不额外补发', '只有一个经济结算入口；无名人口按聚合口径'],
    ['新风险与原计划到期', '每轮检查，原阶段到期', '同样检查，绝不等四轮', '同样检查，不执行两遍', '知情与证据保留，察觉下降不抹历史'],
    ['已出现处境的后继 A', '每域每轮至多一个合法提案', '也逐轮检查，不再投出现率', '也逐轮检查', 'call已提交但固定受阻≠一张可见祈求'],
    ['新处境机会 B', '到原4轮游标才尝试一次', '同一游标未到就不尝试', '到期尝试一次，有合法项才过出现门', '重点也不每轮多抽，切F不重置游标'],
    ['事件窗口与人物／物件归属', '按当前规则精确处理', '仍精确处理', '仍精确处理', '不是“只有详细才投骰”或“后台物件不存在”']
  ];

  const lifecycle = [
    { title: '生成骨架', input: '规则、配额、蓝本、种子', transition: '域与机构先存在；无名人口记总量，有限具名者另建记录。', output: '持久ID、属性、关系与起源事实', note: '不是为12000个个体模拟完整人生。', source: 'generation' },
    { title: '从处境到接触', input: '现在的人、已有事实或合法当前接触', transition: '普通背景由条件加权抽签概括，只持久保存影响选择的事实；再由处境→本次求告→校验窗口与名额→固定→展示，玩家最后选择回应。', output: '请求、临时覆盖、回应与真实后果', note: '固定不是玩家操作；未提交提案不是已经发生的历史。空结果会标明是没有合法条件、已消费、无行动窗口、容量受阻、未到抽样或未选中；缺少生产者是接入失败，不能写成合法静默。', source: 'prayer' },
    { title: '成员不等于教团', input: '实际信徒、无名信众与本域实付', transition: '轮末忠诚≥40的合法领袖、无名信众≥6、累计实付≥8同时齐备，才成团。', output: '教团身份、领袖、初始凝聚60；下轮才产供奉', note: '首团、孤立人物、记录、祭仪等路线已按保留目标、简化过程限定接入；没有用两次成功保证自然两轮成团。', source: 'opportunity' },
    { title: '关键机会：等待票与真正服务', input: '合格到期却漏选的来源、强制票与当前合法票', transition: '累计1次合格到期漏选取得唯一强制票；有强制票时按先进先出扫描至多Q张票（Q为已安装族数，当前至多11），每票最多检查一次，跳过随机门；同槽内失格保票看下一票，至多一笔真实生产。', output: '一个真实可行动机会：可见、现在付得起、有完整窗口', note: '给予机会不等于给予成功；派发不是服务，预览、固定或后台都不算已服务。', source: 'opportunity' },
    { title: '材料递交补足依托', input: '目标结构实际持有、外部独立记录与接收者现状', transition: '目标结构只有记录X、外部合作者有独立记录Y且接收者尚无合法途径取得Y时，才由真实递交补足；同团跨机构走已有关系与通路的内部递交。', output: '接收回执与重判后的实际依托', note: '接收者已具备材料或已有合法递交可提供同一端点时不得付费重复解锁；公开递交按实际效果给接收方知情，秘密递交不自动让秩序机构获知。未来路线材料仍为设计、部分材料不受支持。', source: 'material' },
    { title: '从教团到立足点', input: '实际材料、污染、护持者、圣物、信众与凝聚', transition: '成功锚定先待供奉；实付且全部维持条件仍成立才有效。', output: '固定序号、绑定、贡献与持续费用', note: '门槛25/50/75按序号，贡献4/7/10按层级。8条替代路线尚无正式生产者；共享消费见 anchor-routes.md，规格未单独写明。', source: 'anchors' },
    { title: '成熟锚恢复链', input: '成熟局的有效锚点、断供或创伤后的残存绑定', transition: '来源闭合后按新联系窗口、复供恢复与创伤恢复重判；规则与数值不变。', output: '恢复后的有效贡献与可继续的终局路径', note: '来源闭合报告记录成熟局受控前提下的进展（九锚、第40/44轮结束与苏醒）；这不等于自然新局全链验证。', source: 'anchors' },
    { title: '跨轮增长与反作用', input: '前一轮完整世界、玩家行动及未结计划', transition: '每轮将原状态逐阶段变换；事实留史，当前资格可变，物件和人不因切档重生。', output: '新的状态＋未来承诺＋历史', note: '中期n轮样本演示这种变换，但不声称已从开局自然到达。', source: 'fidelity' },
    { title: '降临或寂灭', input: '当前苏醒、真实联系、有效锚点、仪式与到期损失', transition: '降临开始轮5低语/20信仰；后两轮各3/8，原供奉另付。末轮仍合法才投骰。A≤0或断联满3轮优先寂灭。', output: '终局封存；身份、因果、种子、回顾保留', note: '失败创伤+10；灾变+20且所选宇宙锚休眠。规则明确的双重后果都发生，禁止的是额外重复扣同义伤害。', source: 'ending' }
  ];

  function safeValue(value, depth) {
    if ((depth || 0) > 12) return false;
    if (value === null || typeof value === 'boolean') return true;
    if (typeof value === 'number') return Number.isFinite(value);
    if (typeof value === 'string') return value.length <= 50000;
    if (Array.isArray(value)) return value.length <= 5000 && value.every(v => safeValue(v, (depth || 0) + 1));
    if (value && typeof value === 'object') return Object.keys(value).length <= 500 && Object.entries(value).every(([k, v]) => !['__proto__', 'prototype', 'constructor'].includes(k) && safeValue(v, (depth || 0) + 1));
    return false;
  }
  function validate(record) {
    const errors = [], knownTypes = new Set(types.map(t => t.id));
    if (!record || !safeValue(record, 0) || record.schemaVersion !== 1) return ['不是可识别的世界轨迹v1记录，或数据过深／过大。'];
    if (!['rule-walkthrough', 'runtime-observation'].includes(record.kind)) errors.push('记录必须标明教学演算或实机采集。');
    if (typeof record.title !== 'string' || typeof record.description !== 'string' || !Number.isSafeInteger(record.anchorTurn) || record.anchorTurn < 0) errors.push('缺少标题、说明或合法轮次。');
    if (!record.provenance || typeof record.provenance.label !== 'string' || typeof record.provenance.coverage !== 'string' || !Array.isArray(record.provenance.missing) || !record.provenance.missing.every(x => typeof x === 'string')) errors.push('缺少来源与覆盖范围，不能当作完整世界。');
    if (!Array.isArray(record.initial) || !Array.isArray(record.steps) || record.steps.length < 1 || record.steps.length > 200 || record.initial.length > 2000) return errors.concat('需要初态与1–200个有序阶段记录，每片段初态最多2000个对象。');
    if (record.initial.length * record.steps.length > 100000) errors.push('片段过大，请按回合拆分再查看。');
    const state = new Map();
    function add(e) { if (!e || typeof e.id !== 'string' || !e.id || state.has(e.id) || !knownTypes.has(e.type) || typeof e.label !== 'string' || typeof e.domain !== 'string' || !e.fields || Array.isArray(e.fields) || typeof e.fields !== 'object' || !Array.isArray(e.refs)) { errors.push('对象缺字段、类型不明或ID重复。'); return; } state.set(e.id, clone(e)); }
    record.initial.forEach(add);
    let previousTurn = -1, previousPhase = -1;
    for (const [index, step] of record.steps.entries()) {
      if (!step || typeof step !== 'object') { errors.push('阶段记录不可为空。'); continue; }
      if (!Number.isSafeInteger(step.turn) || step.turn < 0 || !Number.isInteger(step.phase) || step.phase < 0 || step.phase > 6 || step.turn < previousTurn || (step.turn === previousTurn && step.phase < previousPhase)) errors.push('第' + (index + 1) + '步时序非法。');
      if (typeof step.title !== 'string' || typeof step.lead !== 'string' || !Array.isArray(step.read) || !Array.isArray(step.skipped) || !Array.isArray(step.transient) || !Array.isArray(step.changes) || !step.read.concat(step.skipped, step.transient).every(x => typeof x === 'string')) { errors.push('阶段说明缺失或类型错误。'); continue; }
      previousTurn = step.turn; previousPhase = step.phase;
      for (const c of step.changes) {
        if (!c || typeof c.reason !== 'string') { errors.push('变化缺少原因。'); continue; }
        if (c.op === 'create') add(c.entity);
        else if (c.op === 'set') {
          const e = state.get(c.id);
          if (!e || typeof c.field !== 'string' || !Object.prototype.hasOwnProperty.call(e.fields, c.field) || !Object.prototype.hasOwnProperty.call(c, 'before') || !Object.prototype.hasOwnProperty.call(c, 'after') || JSON.stringify(e.fields[c.field]) !== JSON.stringify(c.before)) errors.push('字段缺失或前值不一致：' + c.id + '/' + c.field);
          else e.fields[c.field] = clone(c.after);
        } else errors.push('未知变化操作；不能默默跳过。');
      }
    }
    if (state.size > 2000 || state.size * record.steps.length > 100000) errors.push('片段展开后过大，请按回合拆分再查看。');
    for (const e of state.values()) for (const ref of e.refs) if (!ref || typeof ref.target !== 'string' || !state.has(ref.target) || typeof ref.label !== 'string') errors.push('悬空对象引用：' + e.id);
    return Array.from(new Set(errors));
  }
  function snapshots(record) {
    const errors = validate(record); if (errors.length) throw new Error(errors.join('\n'));
    const state = new Map(record.initial.map(e => [e.id, clone(e)]));
    return record.steps.map(step => {
      const before = Array.from(state.values()).map(clone);
      step.changes.forEach(c => { if (c.op === 'create') state.set(c.entity.id, clone(c.entity)); else state.get(c.id).fields[c.field] = clone(c.after); });
      return { before, after: Array.from(state.values()).map(clone) };
    });
  }
  return { types, labels, weaknesses, attentionRoles, clockExample, sources, phaseRules, compare, lifecycle, opening, middle, validate, snapshots };
});
