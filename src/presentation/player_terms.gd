extends RefCounted
## Shared labels for game state and historical records.
const WORDS: Dictionary = {
	"faith":"信仰", "whispers":"低语", "awakening":"苏醒", "insight":"洞见", "wounds":"创伤",
	"gain":"所得", "cost":"代价", "always":"必付后果", "deep":"深刻成功", "success":"成功", "failure":"失败", "disaster":"灾变",
	"requirement":"所需条件", "due":"祈求期限", "effect":"选择后果", "faith_cost":"信仰费用", "probability":"综合成功率",
	"will":"意志", "influence":"影响", "adaptation":"适应", "before":"此前", "after":"此后", "delta":"变化",
	"title":"名称", "id":"身份", "domain":"所在时空", "name":"姓名", "state":"状态", "status":"状态", "tier":"层级",
	"barrier":"屏障", "pollution":"污染", "alert":"察觉", "stability":"稳定", "institutions":"机构", "profile":"文明",
	"npc":"人物", "role":"职务", "leader":"领袖", "guardian":"护持者", "cult":"教团", "members":"成员", "strategy":"策略",
	"expand":"传教", "conceal":"敛藏", "hold":"守持", "active":"活跃", "dormant":"休眠", "alive":"生存", "dead":"死亡",
	"faith_before":"当前信仰", "faith_after_prepay":"预付后信仰", "capacity":"信仰容量", "net_gain":"实际净得", "awakening_loss":"苏醒损失",
	"faith_income":"预计收入", "income":"预计收入", "prepay":"预付", "paid":"已付", "refused":"拒付", "costs":"费用", "payment":"支付",
	"turn":"回合", "kind":"记录类型", "actor":"执行者", "targets":"涉及对象", "changes":"实际记载", "causal_parents":"已知前因",
	"focus":"重点时空", "people":"持续人物", "identities":"维持身份", "bound_member":"正式成员", "attributes":"属性",
	"loyalty":"忠诚", "relic":"圣物", "relics":"圣物", "anchors":"锚点", "cults":"教团", "holder":"持有者", "bound_to":"绑定对象",
	"outcome":"结果", "roll":"骰点", "p":"成功率", "progress":"仪式轮次", "paid_turn":"已付回合", "disconnected":"断联轮次",
	"consumes":"必失对象", "needs":"注意力占用", "budgets":"名额", "limit":"上限", "occupied":"已用", "error":"原因",
	"prayer_result":"祈求结果", "prayer_fixed":"固定祈求", "background_fixed":"已展示诉求", "turn_check":"判定", "power_result":"权能结果",
	"world_origin":"初识时空", "power_qualification":"真实资格", "ending":"封存", "source":"来源", "facts":"记载", "manifest":"降临",
	"request":"祈求", "variant":"回应", "shallow":"浅触", "deep_response":"深应", "seed":"种子", "terminal":"封存结果", "candidate":"诉求实例", "template":"处境类型", "content_id":"事由"
	,"reserved":"已预留", "pending_release":"待释放", "intent":"拟用策略", "effective":"有效策略", "reason":"原因", "fee":"本轮预付", "growth":"预计增长", "attrition":"预计流失", "remainder_units":"流失余量", "income_basis_now":"当前收入资格", "income_basis_after_work":"计入已知流失后资格", "income_if_unchanged":"条件性预计收入", "anchor":"锚点", "expected":"预计状态", "known_plan":"已知计划", "conditional":"收入条件", "condition":"条件", "deep_success":"深刻成功", "interpretation":"解释职责", "propagation":"传播职责", "order":"秩序职责", "focused":"当前重点", "neighbors":"已知邻域", "representative":"已知代表", "profile_id":"人物范式", "sanity":"理智", "local_spend":"本地投入", "whispers_cost":"低语费用", "responded":"已回应", "used_power":"已用权能", "used_relic":"已用圣物", "wounds_recovered":"恢复创伤", "ends_actions":"立即结束行动", "explicit_refusal":"已明确拒付", "insufficient_faith":"信仰不足", "no_recruitable_population":"无可转化人口", "attention_focus_capacity":"重点名额不足", "paid_pending_final_check":"已预付，仍待轮末重验", "Income and paid anchor activation still depend on shared evolution and revalidation; future income is unavailable for prepay.":"预计收入和锚点恢复仍取决于本轮演化及轮末重验，未来收入不能支付预付。"
}
