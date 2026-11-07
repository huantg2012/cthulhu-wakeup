extends RefCounted
## Player-facing history and action evidence. Only the supplied public fact,
## public identities and content names are read. Never follows a parent chain.
const Feedback = preload("res://src/presentation/experience_feedback.gd")
const Semantics = preload("res://src/presentation/experience_semantics.gd")
const OUTCOMES := {"deep":"深刻成功", "success":"成功", "failure":"失败", "disaster":"灾变", "deterministic":"已完成", "attempted":"已尝试"}
const METRICS := {"faith":"信仰", "whispers":"低语", "awakening":"苏醒", "insight":"洞见", "wounds":"创伤", "sanity":"理智", "loyalty":"忠诚", "will":"意志", "influence":"影响", "adaptation":"适应", "cohesion":"凝聚", "followers":"信众", "alert":"察觉", "pollution":"污染", "barrier":"屏障", "stability":"稳定"}
const BASIS := {
	"dual_testimony":"神迹证言或神迹记录研习已形成当地依托。", "calendar_ritual":"祭仪与推算祭日已形成当地依托。", "orthodox_witness":"祭仪见证及其承接已形成当地依托。", "network_evidence":"不同节点对神迹记录的持有与使用已形成当地依托。", "collective_dissent":"共同记忆中的分歧与见证已形成当地依托。",
	"independent_records":"彼此独立的神迹记录已形成当地依托。", "record_testimonies":"不同见证者留下的神迹证言已形成当地依托。",
	"record_practice":"持续使用神迹记录的实践已形成当地依托。", "ritual_calendar":"祭仪与历法的持续使用已形成当地依托。",
	"calendar_dependency":"推算祭日已开始依赖神迹。", "calendar_keeping":"推算祭日已开始依赖神迹。", "ritual_transmission":"传授祭仪与实际使用已形成当地依托。",
	"shared_memory":"共同记忆及其见证已形成当地依托。", "memory_circle":"共同记忆及其见证已形成当地依托。", "memory_practice":"跨轮共同回忆的实践已形成当地依托。",
	"contract_dependency":"实际履行的契约已开始依赖神迹。", "pact_agreement":"保管约定及其履行已形成当地依托。", "reciprocal_covenant":"双方实际履行的互惠约定已形成当地依托。",
	"distributed_records":"不同节点持有的独立神迹记录已形成当地依托。", "network_independent":"不同节点持有的独立神迹记录已形成当地依托。", "network_exchange":"双方交换与使用记录的经历已形成当地依托。",
	"public_prophet":"先知与公开神迹的经历已形成当地依托。", "axiom_exception":"法则例外的观察与使用已形成当地依托。", "axiom_nodes":"不同节点对同一法则例外的观察已形成当地依托。", "axiom_archive":"跨轮使用同一法则例外的经历已形成当地依托。",
	"dissent_memory":"对同一记忆的异议与见证已形成当地依托。", "dissent_circle":"对同一记忆的异议与见证已形成当地依托。", "dissent_practice":"共同经历并陈述分歧的实践已形成当地依托。",
}
const MATERIALS := {
	"axiom_record":"保存了这次法则例外的观察记录。", "axiom_dependency":"跨轮使用法则例外的实践形成了持续依赖。", "network_endpoint_use":"实际使用了交换而来的记录。", "network_dependency":"双方交换并使用记录，形成了持续依赖。", "calendar_pulse":"开始记录神迹历法的使用。", "calendar_use":"实际使用了这份神迹历法。",
	"practice_session":"参加者共同开始了围绕原有记忆的实践。", "practice_registration":"参加者保留了自己对原有记忆的陈述。", "reciprocal_covenant":"双方约定相互交付各自持有的记录。", "reciprocal_leg":"完成了互惠约定中的一次记录交付。",
	"record_series":"形成了连续保存的异常档案。", "record_use":"实际使用了这份异常记录。", "record_dependency":"当地实践开始依赖这份记录。",
	"dual_testimony":"两位参加者留下了各自的证言。", "performed_rite":"完成了一次祭仪。", "practiced_rite":"完成了一次祭仪实践。", "calendar_dependency":"推算祭日开始依赖神迹。",
	"ritual_lesson":"完成了一次传授祭仪。", "ritual_practice":"实际运用了学得的祭仪。", "ritual_dependency":"祭仪的使用形成了持续依赖。",
	"memory_session":"参加者共同回忆了原有经历。", "memory_registration":"保留了参加者自己的记忆陈述。", "memory_use":"再次使用了这份共同记忆。", "memory_dependency":"共同回忆的实践形成了持续依赖。",
	"dissent_session":"参加者共同经历了记忆分歧。", "dissent_registration":"参加者陈述了各自的记忆分歧。", "dissent_use":"再次实践了不同的记忆解释。", "dissent_dependency":"保留分歧形成了持续依赖。",
	"route_contract_dependency":"履行约定形成了对神迹的依赖。", "reciprocal_dependency":"双方履行互惠约定形成了持续依赖。", "network_exchange":"双方实际交换并使用了记录。",
	"law_observation":"记录了一次法则例外的观察。", "axiom_use":"实际使用了这项法则例外。", "private_devotion":"完成了私祷。", "joint_work":"完成了一次结伴协作。", "covert_gathering":"完成了一次秘密集会。",
}
const SIMPLE := {
	"member_dedication":["献身意愿", "表达了献身意愿。"], "member_enrolled":["接纳成员", "成为正式成员。"], "member_left":["成员离团", "解除了正式成员身份。"], "cult_member_joined":["加入教团", "加入了当地教团。"],
	"cult_established":["教团建立", "当地教团已经建立。"], "cult_destroyed":["教团覆灭", "当地教团已经覆灭。"], "cult_dormancy":["教团休眠", "教团当前缺少可履职的领袖。"], "cult_dormancy_reset":["教团恢复", "教团恢复了领袖主持。"], "cult_succeeded":["教团继任", "接任了教团领袖。"],
	"institution_succeeded":["机构继任", "接任了当地机构的代表。"], "institution_hostile":["机构敌对", "当地机构转为敌对。"],
	"shared_observation":["共同见闻", "参加者共同经历了这件事。"], "memory_at_risk":["记忆面临威胁", "这段共同记忆的见证可能丧失。"], "contract_obligation":["待履行的契约", "约定尚待履行。"],
	"devotion_contact":["求告的联系", "留下了可回应的求告联系。"], "exception":["法则例外", "出现了现有法则无法解释的异常。"], "public_anomaly":["公开异常", "异常已经公开，可能引起当地注意。"],
	"material_received":["记录传递", ""], "event_publication":["证据公开", "证据已被公开收录。"], "cult_contact_route":["传教联系", "教团已建立一条实际可用的传播联系。"],
	"focus_acquired":["关注世界", "开始持续关注这个世界。"], "focus_released":["结束关注", "结束了对这个世界的持续关注。"], "nomination":["认识人物", "成为可辨认的当地人物。"],
	"manifest_completed":["降临完成", "降临仪式已经完成。"], "manifest_interrupted":["降临中断", "降临仪式已经中断。"],
	"world_origin":["初识世界", "这份记录保留了最初接触这个世界的来历。"], "ending_sealed":["旅程封存", "本局已经封存。"],
}

## These are bookkeeping companions, not additional player events. Keep their
## facts available for validation; filtering a history list does not alter them.
static func is_history_entry(fact: Dictionary) -> bool:
	if fact.get("kind") == "miracle": return not fact.changes.get("bundled", false)
	if str(fact.get("kind", "")).begins_with("prayer_space_"):
		return fact.kind in ["prayer_space_result", "prayer_space_closed", "prayer_space_expired", "prayer_space_maintenance", "prayer_space_progress"]
	return not str(fact.get("kind", "")) in ["social_graph_generation", "member_leave_authorized", "institution_succession_authorized", "cult_establishment_authorized", "attention_admitted", "economy_income_cohort", "cult_local_payment"]

static func summarize(host, fact: Dictionary) -> Dictionary:
	var d: Dictionary = fact.get("changes", {}) if fact.get("changes", {}) is Dictionary else {}
	var kind: String = str(fact.get("kind", ""))
	var domain: String = str(fact.get("domain", ""))
	var who: String = entity_name(host, str(fact.get("actor", "")), domain)
	var targets: String = _people(host, fact.get("targets", []), domain)
	var subject: String = targets if not targets.is_empty() else who
	var result := {"title":"当地经历", "summary":"", "lines":[]}
	var lines: Array[String] = []
	if SIMPLE.has(kind):
		result.title = SIMPLE[kind][0]
		result.summary = (subject + "：" if not subject.is_empty() else "") + str(SIMPLE[kind][1])
	match kind:
		"miracle":
			result.title = "亲历异象"
			result.summary = who + "亲历了一次异常。" if not who.is_empty() else "当地发生了一次已知的异常。"
		"npc_miracle_response":
			var reaction := Feedback.miracle_reaction(fact, who)
			result.title = reaction.title
			result.summary = reaction.numbers
			if not reaction.cause.is_empty(): _add(lines, "亲历 · " + reaction.cause)
		"prayer_space_result":
			result.title = str(d.get("title", "回应结果"))
			result.summary = str(d.get("choice_label", ""))
			_add(lines, "回应已显现" if d.get("disclosure") == "unknown" and d.get("outcome") in ["success", "deep"] else "此次回应：" + str(OUTCOMES.get(str(d.get("outcome", "")), "已结算")))
			if d.get("outcome") in ["failure", "disaster"]:
				_add(lines, "本次介入未成功，原处境继续。")
			else:
				for change: Variant in d.get("state_changes", []):
					if change is String: _add(lines, change)
					elif change is Dictionary and change.get("text") is String: _add(lines, str(change.text))
				if lines.size() <= 1: _add(lines, str(d.get("effect", "")))
				_add(lines, str(d.get("tradeoff", "")))
			if int(d.get("roll", -1)) > 0: _add(lines, "骰点 %s · 成功点数 1–%s" % [d.roll, d.get("success_target", d.get("probability", 0))])
			var numbers: Array[String] = []
			for field: String in d.get("actual_deltas", {}):
				if METRICS.has(field) and int(d.actual_deltas[field]) != 0: numbers.append(str(METRICS[field]) + " " + _signed(d.actual_deltas[field]))
			if not numbers.is_empty(): _add(lines, " · ".join(numbers))
			if int(d.get("maintenance_remaining", 0)) > 0: _add(lines, "约定 · 还需 %d 轮" % int(d.maintenance_remaining))
			_costs(lines, d)
		"prayer_space_closed", "prayer_space_expired", "prayer_space_maintenance", "prayer_space_progress":
			result.title = str(d.get("title", "祈求后续"))
			if d.get("concrete_followup", false):
				result.summary = str(d.get("effect", ""))
			else:
				result.summary = str(d.get("summary", ""))
				_add(lines, str(d.get("effect", "")))
		"prayer_registered", "prayer_fixed", "background_fixed", "prayer_attempt", "prayer_result", "prayer_closed", "prayer_window_due":
			var descriptor: Dictionary = d.get("descriptor", d.get("candidate", {}))
			var content: String = str(d.get("prayer", descriptor.get("content_id", "")))
			var name: String = _catalog_name(host, "prayers", content, "这项祈求")
			result.title = {"prayer_registered":"收到祈求", "prayer_fixed":"求告处境", "background_fixed":"求告处境", "prayer_attempt":"回应祈求", "prayer_result":"回应结果", "prayer_closed":"祈求结束", "prayer_window_due":"祈求到期"}[kind]
			result.summary = (who + " · " if not who.is_empty() else "") + name
			if kind == "prayer_result":
				var outcome: String = str(d.get("outcome", ""))
				_add(lines, "此次回应：" + str(OUTCOMES[outcome]) if OUTCOMES.has(outcome) else "")
				if outcome in ["failure", "disaster"]: _add(lines, "本次回应未能解决原诉求。")
			if d.get("variant") in ["shallow", "deep"]: _add(lines, "回应方式：" + ("浅触" if d.variant == "shallow" else "深应"))
			_deadline(lines, d.get("due", descriptor.get("due_turn")))
			_costs(lines, d)
		"power_attempt", "power_result", "power_effect":
			var name: String = _catalog_name(host, "powers", str(d.get("power", "")), "权能")
			result.title = name + ("结果" if kind == "power_result" else ("影响" if kind == "power_effect" else "施展"))
			result.summary = (who + " · " if not who.is_empty() else "") + name
			if OUTCOMES.has(str(d.get("outcome", ""))): _add(lines, "结果：" + str(OUTCOMES[d.outcome]))
			if kind == "power_effect" and METRICS.has(str(d.get("field", ""))) and _numeric(d.get("actual")): _add(lines, str(METRICS[d.field]) + " " + _signed(d.actual))
			_costs(lines, d)
		"turn_check":
			result.title = "行动判定"
			result.summary = (who + " · " if not who.is_empty() else "") + str(OUTCOMES.get(str(d.get("outcome", "")), "检定已进行"))
			if _numeric(d.get("probability")): _add(lines, "当时成功率 %s%%" % d.probability)
		"prayer_fact", "event_fact":
			var tag: String = str(d.get("tag", ""))
			var effect: String = str(Feedback.FACT_RESULTS.get(tag, Semantics.RECORDS.get(tag, "")))
			result.title = "祈求带来的变化" if kind == "prayer_fact" else "事件带来的变化"
			result.summary = (subject + "：" if not subject.is_empty() else "") + effect.trim_prefix("的")
			if effect.is_empty(): result.summary = "这次" + ("回应" if kind == "prayer_fact" else "事件") + "留下了与相关人物有关的经历。"
			if tag == "concealed": result.summary = subject + "处于隐匿中。"
			if tag == "propagation_restricted": result.summary = subject + "暂时不能参与传播。"
			if tag == "appointment_restricted": result.summary = subject + "暂时不能被任命。"
			if _numeric(d.get("until")): _add(lines, "持续至第 %s 轮结束" % d.until)
		"event_result", "event_cancelled":
			result.title = _catalog_name(host, "events", str(d.get("content_id", "")), "当地事件")
			result.summary = "该事件已取消。" if kind == "event_cancelled" else "已处理这次事件。"
			var option: String = _event_option(host, str(d.get("content_id", "")), str(d.get("option", "")))
			if not option.is_empty(): result.summary = "已选择：" + option
			if d.get("default", false): _add(lines, "按事件的默认后果处理。")
		"anchor_basis", "institution_recognized":
			var contract: Dictionary = d.get("contract", d)
			result.title = "形成扎根依托"
			result.summary = str(BASIS.get(str(contract.get("rule", "")), "已有神迹经历与当地实践形成了扎根依托。"))
			var institution: String = entity_name(host, str(d.get("institution", contract.get("institution", ""))), domain)
			if not institution.is_empty(): _add(lines, "依托地点：" + institution)
			_add(lines, "这是形成时的依据；建立或修复锚点时仍须满足当前条件。")
		"anchor_institution_bound":
			result.title = "锚点扎根"
			result.summary = "锚点已与当地的神迹依托绑定。"
			_named(lines, "依托地点", entity_name(host, str(d.get("institution", "")), domain))
			_named(lines, "护持者", who)
		"institution_relic_opportunity":
			var relic: String = _catalog_name(host, "relics", str(d.get("relic_type", "")), "圣物")
			result.title = "发现圣物 · " + relic
			result.summary = "当地神迹依托形成后，出现了取得这件圣物的机会。"
			_named(lines, "发现地点", entity_name(host, str(d.get("institution", "")), domain))
			_deadline(lines, d.get("due"))
			_add(lines, "可以回收取得物件，或公开换取信仰并放弃物件；等待不会延长期限。")
		"institution_relic_recover", "institution_relic_public", "institution_relic_wait", "institution_relic_expired":
			result.title = {"institution_relic_recover":"取得圣物", "institution_relic_public":"公开圣物", "institution_relic_wait":"暂缓取得圣物", "institution_relic_expired":"圣物机会到期"}[kind]
			result.summary = {"institution_relic_recover":"圣物已经回收。", "institution_relic_public":"已公开这次发现，放弃物件并换取即时信仰，同时留下公开暴露。", "institution_relic_wait":"暂未处置，原有期限保持不变。", "institution_relic_expired":"未在期限内取得这件圣物。"}[kind]
		"route_attempt", "route_progress", "route_material", "law_observation":
			var operation: String = str(d.get("operation", ""))
			var action: String = _operation(host, operation)
			result.title = action if not action.is_empty() else ("活动所得" if kind == "route_material" else "活动进展")
			result.summary = (who + " · " if not who.is_empty() else "") + action
			if kind == "route_attempt": _add(lines, "结果：" + str(OUTCOMES.get(str(d.get("outcome", "")), "已执行")))
			if kind == "route_material": result.summary = str(MATERIALS.get(str(d.get("tag", "")), "这次活动留下了参与者实际经历的材料。"))
			if kind == "law_observation": result.summary = "记录了一次法则例外的观察。"
			var progress: Dictionary = d.get("progress", {})
			for key: String in ["count", "uses", "completed"]:
				if _numeric(progress.get(key)): _add(lines, "已完成 %s 次" % progress[key]); break
			if kind == "route_material": _named(lines, "参加者", _people(host, d.get("originals", []), domain))
		"power_qualification":
			var ability: String = {"dream":"入梦", "oracle":"谕言", "bestow":"赐予", "appoint":"任命", "sacrifice":"献祭", "transfer":"迁引", "anchor":"锚定", "breach":"穿透", "seed":"播种", "manifest":"降临", "listen":"聆听", "spread":"传教"}.get(str(d.get("rule", "")), "相关行动")
			result.title = ability + "的联系依据"
			result.summary = (who if not who.is_empty() else "此对象") + "的已有联系可作为" + ability + "的依据。"
			_add(lines, "是否能现在执行，仍取决于人物状态、所需资源与本轮机会。")
		"economy_income":
			result.title = "教团收入"
			result.summary = "实际入账 %s 信仰" % d.actual if _numeric(d.get("actual")) else "教团本轮收入已结算。"
			if _numeric(d.get("overflow")) and d.overflow > 0: _add(lines, "容量不足，%s 信仰未能储存。" % d.overflow)
		"economy_strategy_payment":
			result.title = "执行教团指令"
			result.summary = "实际执行：" + str({"expand":"传教", "conceal":"敛藏", "hold":"守持"}.get(str(d.get("effective", "")), "本轮安排"))
			if _numeric(d.get("fee")): _add(lines, "支出 %s 信仰" % d.fee)
			if d.get("reason") == "insufficient_faith": _add(lines, "信仰不足，原计划未能完整执行。")
		"economy_anchor_payment":
			result.title = "锚点供奉"
			result.summary = "已支付本轮供奉，轮末仍需复核锚点条件。" if d.get("expected") == "paid_pending_final_check" else "本轮未支付该锚点的供奉。"
			if _numeric(d.get("fee")): _add(lines, "供奉 %s 信仰" % d.fee)
			if d.get("reason") == "explicit_refusal": _add(lines, "按本轮计划停供。")
			elif d.get("reason") == "insufficient_faith": _add(lines, "当前信仰不足。")
		"economy_work":
			result.title = "教团本轮经营"
			result.summary = "本轮传教与信众流失已结算。"
			for key: String in ["growth", "loss"]:
				if _numeric(d.get(key)): _add(lines, ("新增信众 " if key == "growth" else "流失信众 ") + str(d[key]))
		"cult_dormancy":
			result.title = "教团履职记录"
			result.summary = "连续缺少可履职领袖 %s 轮。" % d.turns if _numeric(d.get("turns")) and d.turns > 0 else "本轮没有累计领袖缺位时间。"
		"economy_rest":
			result.title = "敛息休养"
			result.summary = "本轮已选择敛息休养。"
			if _numeric(d.get("recovered")): _add(lines, "恢复创伤 %s" % d.recovered)
			_costs(lines, d)
		"economy_prepay":
			result.title = "轮末支出结算"
			result.summary = "本轮经营与供奉费用已结算。"
			if _numeric(d.get("faith_after")): _add(lines, "支出后信仰 %s" % d.faith_after)
		"economy_qualification":
			result.title = "传教条件" if d.get("rule") == "propagation" else "锚点供奉条件"
			result.summary = "当时已满足相应条件。" if d.get("allowed", false) else "当时未能满足相应条件。"
		"ending_assessed":
			result.title = "与现实的联系"
			result.summary = "仍与现实保持联系。" if d.get("count", 0) == 0 else "与现实的联系已经中断 %s 轮。" % d.count
		"natural_evolution":
			result.title = "世界自然变化"
			result.summary = "世界在本轮发生了自然变化。"
			for field: String in ["barrier", "pollution", "alert", "stability"]:
				if _numeric(d.get(field + "_delta")): _add(lines, str(METRICS[field]) + " " + _signed(d[field + "_delta"]))
		"turn_action", "cult_local_payment":
			result.title = "行动支出"
			result.summary = "已支付这次行动的费用。"
			_costs(lines, d)
			if kind == "cult_local_payment" and _numeric(d.get("amount")): _add(lines, "计入当地投入 %s 信仰（为同一次付款，不重复扣费）。" % d.amount)
		"population_transfer":
			result.title = "信众与人口变化"
			var verb: String = {"convert":"转为信众", "leave":"离开信仰", "migrate":"迁往其他世界", "death":"死亡"}.get(str(d.get("mode", "")), "发生变化")
			result.summary = "%s 人%s。" % [d.amount, verb] if _numeric(d.get("amount")) else "当地人口发生了变化。"
			if d.get("mode") == "migrate": _named(lines, "迁往", entity_name(host, str(d.get("target", ""))))
		"migration":
			result.title = "跨域迁移"
			result.summary = who + "迁往" + entity_name(host, str(d.get("to", ""))) + "。"
			_named(lines, "原世界", entity_name(host, str(d.get("from", ""))))
		"status_change":
			result.title = "人物处境变化"
			result.summary = who + "：" + str(Feedback.STATES.get(str(d.get("to", "")), "处境发生变化"))
		"material_received":
			var sender: String = entity_name(host, str(d.get("sender", "")), domain)
			var recipient: String = entity_name(host, str(d.get("recipient", "")), domain)
			result.summary = (recipient if not recipient.is_empty() else "接收者") + "从" + (sender if not sender.is_empty() else "原持有人") + ("取得记录副本并获知其内容。" if d.get("grant") == "custody" else "获知了记录内容。")
		"initial_relationship", "social_contact":
			result.title = "人物联系"
			var a: String = entity_name(host, str(d.get("a", "")), domain)
			var b: String = entity_name(host, str(d.get("b", "")), domain)
			var relation: String = {"support":"支持", "hostile":"敌对", "favor_owed":"人情债", "family":"亲属", "cooperation":"合作", "rival":"竞争"}.get(str(d.get("kind", "")), "接触")
			if a.is_empty(): a = "一位尚未辨明身份的人物"
			if b.is_empty(): b = "另一位尚未辨明身份的人物"
			result.summary = a + "与" + b + "存在" + relation + "关系。"
		"member_leave_authorized":
			result.title = "成员身份依据"
			result.summary = "这份依据允许处理该成员的离团，不表示已经离团。"
		"institution_succession_authorized":
			result.title = "机构继任依据"
			result.summary = "这份依据允许处理当地机构的继任，不表示任命已经完成。"
		"cult_establishment_authorized":
			result.title = "教团成立依据"
			result.summary = "这份依据允许建立当地教团；成立结果由后续实际行动决定。"
		"attention_admitted":
			result.title = "行动名额"
			result.summary = "本次行动已取得所需的关注或人物名额。"
		"social_graph_generation":
			result.title = "当地人物关系"
			result.summary = "当地已有的人物关系来自共同生活背景。"
		"economy_income_cohort":
			result.title = "本轮信众收入基础"
			result.summary = "%s 名信众计入本轮的收入基础。" % d.eligible if _numeric(d.get("eligible")) else "本轮可计入收入的信众范围已经确定。"
		"cult_appointed":
			result.title = "教团任命"
			result.summary = who + "被任命为" + str({"leader":"领袖", "guardian":"护持者", "preacher":"传教者", "priest":"祭司"}.get(str(d.get("role", "")), "教团职务承担者")) + "。"
		"world_observation":
			result.title = "世界态势记录"
			result.summary = "当时观测到的世界状态；不代表当前实时状态。"
			for field: String in ["barrier", "pollution", "alert", "stability"]:
				if d.get("metrics", {}).get(field) is int: _add(lines, str(METRICS[field]) + " " + str(d.metrics[field]))
		"message":
			result.title = "收到线索"
			result.summary = "留下了与当地世界有关的线索。"
			if d.get("observation_version") == "world-observation/1":
				result.title = "世界态势线索"
				result.summary = "这份线索记录了当时的世界态势估计；可用聆听查明原记录。"
		"manifest_interrupted":
			if _numeric(d.get("progress")): _add(lines, "此前已付 %s 轮，进度不再保留。" % d.progress)
		_:
			if kind.begins_with("relic_"): _relic(host, fact, result, lines)
			elif kind.begins_with("resistance_"):
				result.title = "当地反制"
				result.summary = ("屏障已打开。" if d.get("open", false) else "屏障当前闭合。") if kind == "resistance_breach" else "当地文明留下了一次反制活动的记录。"
				_deadline(lines, d.get("due"))
			elif kind.begins_with("prayer_crisis_"):
				result.title = "祈求危机"
				result.summary = {"prayer_crisis_due":"原危机已经到期。", "prayer_crisis_resolved":"原危机已经解除。", "prayer_crisis_expired":"原危机已经到期。"}.get(kind, "原祈求的危机状态发生了变化。")
	# Unknown records never expose storage keys or turn hidden IDs into facts.
	if str(result.summary).is_empty():
		result.summary = (subject + "的相关经历。" if not subject.is_empty() else "这份经历保留在当地历史中。")
		_add(lines, "目前没有更多可说明其具体后果的已知内容。")
	if SIMPLE.has(kind): _deadline(lines, d.get("due"))
	result.lines = lines
	return result

static func entity_name(host, id: String, domain := "") -> String:
	if id.is_empty() or id == "尚未知晓": return ""
	for collection: String in ["people", "institutions", "relics", "cults", "anchors", "domains"]:
		for item: Dictionary in host.projection.get(collection, []):
			if item.get("id") != id: continue
			var title: String = str(host.title(id))
			if collection == "people" and title != id:
				var base: String = _person_name(title, id)
				var same_name := 0
				for other: Dictionary in host.projection.get("people", []):
					var other_id: String = str(other.get("id", ""))
					if _person_name(str(host.title(other_id)), other_id) == base: same_name += 1
				title = base
				var number: String = id.trim_prefix("NPC-")
				if same_name > 1:
					var place: String = str(item.get("domain", ""))
					if not place.is_empty(): title += " · " + str(host.title(place))
			if collection == "institutions" and not domain.is_empty() and item.get("domain") == domain:
				var cut: int = title.find(" · ")
				if cut > 0: title = title.substr(0, cut)
			return title if title != id and not title.contains("FACT-") else "已知" + {"people":"人物", "institutions":"机构", "relics":"圣物", "cults":"教团", "anchors":"锚点", "domains":"世界"}[collection]
	return ""

static func _person_name(title: String, id: String) -> String:
	# Remove only the generated identity suffix, not numbers inside a real name.
	if id.begins_with("NPC-"):
		return title.trim_suffix(" · " + id.trim_prefix("NPC-"))
	return title

static func _people(host, ids: Array, domain: String) -> String:
	var names: Array[String] = []
	for id: Variant in ids:
		if not id is String: continue
		for person: Dictionary in host.projection.get("people", []):
			if person.get("id") == id: _add(names, entity_name(host, id, domain)); break
	return "、".join(names)

static func _catalog_name(host, table: String, id: String, fallback: String) -> String:
	var row: Dictionary = host.session.catalog.display_tables.get(table, {}).get(id, {})
	return str(row.get("title", row.get("name", fallback)))

static func _operation(host, id: String) -> String:
	var definition: Dictionary = host.session.catalog.display_tables.get("progression_route_operations", {}).get(id, {})
	return str(definition.get("name", ""))

static func _event_option(host, content: String, option: String) -> String:
	if not option in ["A", "B"]: return ""
	var row: Dictionary = host.session.catalog.display_tables.get("events", {}).get(content, {})
	return str(row.get("choice_" + option.to_lower(), ""))

static func _relic(host, fact: Dictionary, result: Dictionary, lines: Array[String]) -> void:
	var d: Dictionary = fact.get("changes", {})
	var kind: String = str(fact.get("kind", ""))
	var wording: Array = {
		"relic_create":["取得圣物", "出现了一件有真实来历的圣物。"], "relic_equip":["携带圣物", "圣物已交给所选人物携带。"], "relic_unequip":["卸下圣物", "圣物已从携带者身上卸下。"],
		"relic_bound":["绑定圣物", "圣物已绑定锚点，不能同时用于携带。"], "relic_unbind":["解绑圣物", "圣物已经解绑；原锚点失去这件绑定媒介。"], "relic_disassemble":["解离圣物", "这件圣物已被永久消耗。"],
		"relic_recover":["回收圣物", "圣物已重新取得控制。"], "relic_seized":["圣物被扣押", "圣物已被当地势力扣押。"], "relic_sealed":["圣物封存", "圣物已被封存。"], "relic_seal_expired":["封存结束", "圣物的封存期限已经结束。"],
		"relic_preparation_paid":["使用圣物协助", "圣物的协助效果已用于此次行动。"],
	}.get(kind, ["圣物经历", "这件圣物的处置记录已保留。"])
	result.title = wording[0]; result.summary = wording[1]
	var relic_id: String = str(d.get("relic", ""))
	if relic_id.is_empty():
		for id: Variant in fact.get("targets", []):
			for item: Dictionary in host.projection.get("relics", []):
				if item.get("id") == id: relic_id = id; break
	_named(lines, "圣物", entity_name(host, relic_id, str(fact.get("domain", ""))))
	if _numeric(d.get("until")): _add(lines, "封存至第 %s 轮" % d.until)
	# net_gain is an actual committed result; preview/requested deltas are not.
	if d.get("net_gain") is Dictionary:
		for key: String in d.net_gain:
			if METRICS.has(key) and _numeric(d.net_gain[key]): _add(lines, str(METRICS[key]) + " " + _signed(d.net_gain[key]))

static func _add(lines: Array[String], text: String) -> void:
	if not text.is_empty() and not text in lines: lines.append(text)

static func _named(lines: Array[String], label: String, value: String) -> void:
	if not value.is_empty(): _add(lines, label + "：" + value)

static func _deadline(lines: Array[String], value: Variant) -> void:
	if _numeric(value): _add(lines, "第 %s 轮到期" % value)

static func _costs(lines: Array[String], data: Dictionary) -> void:
	var values: Array[String] = []
	for key: String in ["faith_cost", "whispers_cost"]:
		if _numeric(data.get(key)) and data[key] != 0: values.append("%s %s" % [data[key], "信仰" if key == "faith_cost" else "低语"])
	if not values.is_empty(): _add(lines, "已支付：" + "、".join(values))

static func _numeric(value: Variant) -> bool:
	return value is int or value is float

static func _signed(value: Variant) -> String:
	return ("+" if value > 0 else "") + str(value)
