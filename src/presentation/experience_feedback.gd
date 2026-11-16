extends RefCounted
## A receipt reads only public projections and the action's known facts. Requested
## deltas and preview promises are never reported as actual changes.
const Semantics = preload("res://src/presentation/experience_semantics.gd")
const COLLECTIONS: Array[String] = ["people", "relics", "cults", "anchors", "institutions", "domains"]
const ATTRIBUTES: Dictionary = {"sanity": "理智", "loyalty": "忠诚", "will": "意志", "insight": "洞见", "influence": "影响", "adaptation": "适应", "cohesion": "凝聚", "followers": "信众", "alert": "察觉", "pollution": "污染", "barrier": "屏障", "stability": "稳定"}
const STATES: Dictionary = {"active": "活跃", "dead": "死亡", "detained": "被拘禁", "missing": "失踪", "dormant": "休眠", "destroyed": "毁灭", "carried": "携带中", "controlled": "当地保管", "stored": "当地保管", "ground": "留在当地", "bound": "绑定中", "seized": "被扣押", "sealed": "封存中", "consumed": "已消耗"}
const FACT_RESULTS: Dictionary = {
	"condition_cured": "已脱离此次病危", "contract_fulfilled": "已完成本次契约义务",
	"memory_preserved": "保留了这段记忆的见证资格", "memory_qualification_lost": "失去了这段记忆的见证资格",
	"escape_route": "已取得此次逃离路线", "relic_recovery_opportunity": "出现了限时争夺机会",
	"pursuit_clue_withdrawn": "此次追查线索已撤销", "pursuit_relation_withdrawn": "此次追查关系已切断",
	"pursuit_scene_withdrawn": "此次追查已结束", "support_withdrawn": "已失去求告者的支持",
	"testimony_learned": "已获知这份证言", "record_learned": "已获知同一异常事实",
	"contract_learned": "已获知此次契约", "relation_learned": "已获知原有关系事实",
	"relic_holder_learned": "已获知圣物的实际持有机构", "exception_learned": "已取得法则例外的知识",
	"ordinary_life": "恢复普通生活，本次未变异", "mutated": "已发生变异",
	"private_records": "暂不公开证词", "contract_released": "此次神迹履约依赖已解除", "mutation_revealed": "异变已经公开",
	"prophet_allowed": "已获准继续以先知身份活动", "custody_retained": "证据仍在原处",
	"institution_hostile": "已成为敌对机构", "departed": "已离去",
	"memory_dispute_closed": "此次记忆争议已结束", "cooperation_opportunity_closed": "此次合作机会已结束",
	"recovery_opportunity_closed": "此次争夺机会已结束", "request_closed": "此次请求已结束",
}

func build(host, result: Dictionary, before: Dictionary, after: Dictionary, action_title: String, include_effects := true) -> Array[String]:
	var lines: Array[String] = []
	if not result.get("ok", false): return ["未执行：" + str(result.get("error", "当前条件不满足"))]
	var old: Dictionary = _index(before)
	var current: Dictionary = _index(after)
	var facts: Array = result.get("facts", [])
	var reported: Dictionary = {}
	var effect_fields := {}
	for effect: Dictionary in result.get("action_effects", {}).get("deltas", []):
		if not effect_fields.has(effect.subject): effect_fields[effect.subject] = {}
		effect_fields[effect.subject][effect.field] = true
	for fact: Dictionary in facts:
		if fact.get("kind") != "npc_miracle_response": continue
		if not reported.has(fact.actor): reported[fact.actor] = {}
		for field: String in fact.changes.actual_deltas:
			reported[fact.actor][field] = int(reported[fact.actor].get(field, 0)) + int(fact.changes.actual_deltas[field])
	var outcome: String = ""
	for check: Dictionary in result.get("result", {}).get("checks", []):
		outcome = {"deep": "深刻成功", "success": "成功", "failure": "失败", "disaster": "灾变"}.get(str(check.get("outcome", "")), outcome)
	for fact: Dictionary in facts:
		if fact.get("kind") == "prayer_space_result" and fact.get("changes", {}).get("disclosure") == "unknown" and fact.changes.get("outcome") in ["deep", "success"]: outcome = "已显现"
	if not action_title.is_empty(): lines.append(action_title + (" · " + outcome if not outcome.is_empty() else " · 已执行"))
	if include_effects:
		for row: Dictionary in effect_rows(host, result, before, after): lines.append(str(row.caption) + "：" + str(row.value))
	# Status and ownership changes outrank bookkeeping and newly learned objects.
	var changes: Array[String] = []
	lines.append_array(cult_settlement_lines(host, result.get("cult_settlement", [])))
	var learned: Array[String] = []
	for id: String in current:
		var item: Dictionary = current[id]
		var prior: Dictionary = old.get(id, {})
		var name_value: String = _title(host, id, old, current)
		if prior.is_empty():
			learned.append("现已知晓：" + name_value)
			continue
		var entity_changes: Array[String] = []
		for field: String in ["status", "state", "placement"]:
			if prior.has(field) and item.has(field) and prior[field] != item[field] and STATES.has(str(item[field])):
				entity_changes.append(str(STATES[item[field]]))
		if prior.has("bound_member") and item.has("bound_member") and prior.bound_member != item.bound_member:
			entity_changes.append("已成为正式成员" if item.bound_member else "已解除成员身份")
		for field: String in ["holder", "leader", "guardian", "representative"]:
			if prior.has(field) and item.has(field) and prior[field] != item[field] and not str(item[field]).is_empty():
				entity_changes.append({"holder": "交由", "leader": "领袖变为", "guardian": "守护者变为", "representative": "代表变为"}[field] + _title(host, str(item[field]), old, current))
		if not entity_changes.is_empty(): _append(changes, name_value + "：" + "；".join(entity_changes))
		var numbers: Array[String] = []
		var revealed: Array[String] = []
		for field: String in ATTRIBUTES:
			# Committed deltas take precedence over stale world snapshots and
			# member-only attribute totals. Never double count a bound actor.
			if effect_fields.get(id, {}).has(field): continue
			if field == "followers" and effect_fields.get(str(item.get("domain","")),{}).has(field): continue
			if not _numeric(item.get(field)): continue
			if not _numeric(prior.get(field)):
				if not field in ["alert", "pollution", "barrier", "stability"]: revealed.append(str(ATTRIBUTES[field]) + " " + str(item[field]))
			elif reported.get(id, {}).has(field):
				var remaining: int = int(item[field]) - int(prior[field]) - int(reported[id][field])
				if remaining != 0: numbers.append("%s %+d（其余变化）" % [ATTRIBUTES[field], remaining])
			elif prior[field] != item[field]: numbers.append("%s %s → %s" % [ATTRIBUTES[field], prior[field], item[field]])
		if not numbers.is_empty(): _append(changes, name_value + "：" + "；".join(numbers))
		if not revealed.is_empty(): learned.append(name_value + " · 现可知：" + "、".join(revealed))
	# Concrete facts supply effects that are not scalar fields, such as a cure,
	# fulfilled obligation or material reception. No generic kind/ID dump.
	var fact_lines: Array[String] = []
	for fact: Dictionary in facts:
		if fact.get("kind") == "population_transfer" and fact.changes.get("mode") in ["convert","leave"] and effect_fields.get(str(fact.domain),{}).has("followers"): continue
		var text: String = _fact_line(host, fact, old, current)
		if not text.is_empty(): _append(fact_lines, text)
	for line: String in fact_lines: _append(lines, line)
	for line: String in changes: _append(lines, line)
	if learned.size() <= 3:
		for line: String in learned: _append(lines, line)
	elif not learned.is_empty():
		lines.append("同时新增或补全了 %d 项已知资料，可在相关世界、人物或物件中查看。" % learned.size())
	var resources := resource_summary(before, after)
	if not resources.is_empty(): lines.append(resources)
	if lines.is_empty(): lines.append("行动已执行。")
	return lines

## Explicit field/value rows for both the tabletop and the dice reveal. Legacy
## receipts can still use build(); no UI has to parse punctuation out of prose.
func presentation_rows(host, result: Dictionary, before: Dictionary, after: Dictionary) -> Array:
	var rows: Array = effect_rows(host, result, before, after)
	for line: String in build(host, result, before, after, "", false):
		if line != "行动已执行。": rows.append(line)
	return rows

func effect_rows(host, result: Dictionary, before: Dictionary, after: Dictionary) -> Array:
	var rows: Array = []
	var effects: Dictionary = result.get("action_effects", {})
	var old := _index(before)
	var current := _index(after)
	for fact: Dictionary in effects.get("revealed", []):
		# Runtime load avoids RecordText's historical miracle formatter dependency.
		var text = load("res://src/presentation/player_record_text.gd")
		var record: Dictionary = text.summarize(host, fact)
		rows.append({"caption":"聆听所得", "value":"%s · 第 %d 轮 · %s" % [_title(host, str(fact.domain), old, current), int(fact.turn), record.title]})
		rows.append({"caption":"记录内容", "value":str(record.summary) + ("\n" + " · ".join(record.lines) if not record.lines.is_empty() else "")})
	var groups := {}
	for delta: Dictionary in effects.get("deltas", []):
		if not ATTRIBUTES.has(delta.field): continue
		var id := str(delta.subject)
		if not groups.has(id): groups[id] = []
		var amount := int(delta.delta)
		groups[id].append(str(ATTRIBUTES[delta.field]) + (" %+d" % amount if amount != 0 else " 未变化"))
	for collection: String in ["people", "cults", "domains"]:
		for item: Dictionary in after.get(collection, []):
			var id := str(item.id)
			if groups.has(id): rows.append({"caption":{"people":"人物变化", "cults":"教团变化", "domains":"世界变化"}[collection], "value":_title(host, id, old, current) + "\n" + " · ".join(groups[id])})
	for notice: Dictionary in effects.get("developments", []):
		var value := ""
		match str(notice.kind):
			"activity": value = str(notice.text)
			"preparation":
				var action := str(notice.action)
				if host != null and host.session.catalog.display_tables.powers.has(action): action = host.session.catalog.display_tables.powers[action].name
				elif action.begins_with("PRAYER/"): action = "已指定的祈求回应"
				value = "%s获得「%s」准备，成功上限 +%d；至第 %d 轮有效，使用一次后消耗。" % [_title(host, notice.actor, old, current), action, notice.amount, notice.expires]
			"evidence": value = "%d 项追查依据及其关联收益已失效。" % notice.count
			"appointment": value = "%s → %s · %s；第 %d 轮开始时复核并生效，当前尚未就任。" % [_title(host, notice.actor, old, current), _title(host, notice.cult, old, current), {"leader":"领袖", "guardian":"护持者"}.get(notice.role, "职务"), notice.due]
			"manifest": value = "降临进度 %d / %d。%s" % [notice.progress, notice.duration, "本轮结束时复核条件并进行最终检定。" if notice.progress == notice.duration else "下轮仍需继续仪式、支付代价并维持锚点。"]
		if not value.is_empty(): rows.append({"caption":"后续", "value":value})
	return rows

static func miracle_reaction(fact: Dictionary, person: String) -> Dictionary:
	var data: Dictionary = fact.changes
	var changes: Dictionary = data.actual_deltas
	var title := person + ("的信仰加深" if int(changes.get("loyalty", 0)) > 0 else "回想所见的异象")
	var numbers: Array[String] = []
	for field: String in ["loyalty", "sanity", "adaptation"]:
		var amount: int = int(changes.get(field, 0))
		if amount != 0: numbers.append("%s %+d" % [ATTRIBUTES[field], amount])
	var cause := str(data.cause)
	if data.assisted and not numbers.is_empty(): numbers.push_front("本轮合计")
	return {"title": title, "cause": cause, "numbers": " · ".join(numbers)}

func pollution_lines(row: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var estimate: bool = row.get("estimated", true)
	lines.append("教团规模 +%.2f  ·  成员影响 +%.2f" % [float(row.size) / 1000, float(row.named) / 1000])
	var decay: String = "自然消退 %s%.2f" % ["至多 −" if estimate and row.decay > 0 else ("−" if row.decay > 0 else ""), float(row.decay) / 1000]
	var net: String = "净变化待查" if estimate else "净变化 %+.2f" % (float(row.net) / 1000)
	lines.append(decay + "  ·  " + net)
	if row.has("support"):
		lines.append("当前可支撑的污染约 %.1f" % (float(row.support) / 1000))
	return lines

func cult_settlement_lines(host, records: Array, include_name := true) -> Array[String]:
	var lines: Array[String] = []
	for row: Dictionary in records:
		var cult: Dictionary = host._views._find(host, "cults", row.cult)
		if cult.is_empty(): continue
		var prefix: String = host._views._cult_name(host, cult) + " · " if include_name else ""
		if row.kind == "economy_strategy_payment":
			var line: String = prefix + "实际执行 %s · 支出 %s 信仰" % [host._views._strategy_name(row.effective), row.fee]
			if not row.get("reason", "").is_empty():
				line += " · " + host._views._economy_reason(host, row.reason)
			lines.append(line)
		elif row.kind == "economy_income":
			lines.append(prefix + "实际入账 %s 信仰" % row.actual)
		elif row.kind == "cult_pollution_report":
			lines.append(prefix + ("持续污染潜力" if row.estimated else "持续污染结算"))
			lines.append_array(pollution_lines(row))
	return lines

func resource_summary(before: Dictionary, after: Dictionary) -> String:
	var resources: Array[String] = []
	for field: String in ["faith", "whispers", "awakening", "insight", "wounds"]:
		if not _numeric(before.get(field)) or not _numeric(after.get(field)) or before[field] == after[field]: continue
		var label_value: String = {"faith": "信仰", "whispers": "低语", "awakening": "苏醒", "insight": "洞见", "wounds": "创伤"}[field]
		resources.append("%s %s → %s" % [label_value, before[field], after[field]])
	return " · ".join(resources)

func _fact_line(host, fact: Dictionary, old: Dictionary, current: Dictionary) -> String:
	if fact.get("kind") == "prayer_space_recovered":
		return _title(host, fact.actor, old, current) + " · " + str(fact.changes.effect)
	if fact.get("kind") == "npc_miracle_response":
		var row := miracle_reaction(fact, _title(host, fact.actor, old, current))
		var parts: Array[String] = [row.title]
		if not row.cause.is_empty(): parts.append("亲历 · " + row.cause)
		if not row.numbers.is_empty(): parts.append(row.numbers)
		return "\n".join(parts)
	if fact.get("kind") == "prayer_space_progress" and fact.changes.get("concrete_followup", false):
		return str(fact.changes.get("effect", ""))
	var data: Dictionary = fact.get("changes", {})
	var kind: String = str(fact.get("kind", ""))
	var targets: Array = fact.get("targets", [])
	var names: Array[String] = []
	for target: Variant in targets:
		if target is String and (current.has(target) or old.has(target)): _append(names, _title(host, target, old, current))
	var subject: String = "、".join(names)
	if kind in ["prayer_fact", "event_fact"]:
		var tag: String = str(data.get("tag", ""))
		if subject.is_empty(): return ""
		if FACT_RESULTS.has(tag): return subject + "：" + str(FACT_RESULTS[tag])
		if Semantics.RECORDS.has(tag): return subject + "：" + str(Semantics.RECORDS[tag]).trim_prefix("的")
		if tag == "concealed": return subject + "：已隐匿至第 %s 轮结束" % data.get("until", "")
		if tag in ["propagation_restricted", "appointment_restricted"]:
			return subject + ("：不能参与传播" if tag == "propagation_restricted" else "：不能被任命") + "（至第 %s 轮结束）" % data.get("until", "")
	if kind == "material_received":
		var sender: String = _title(host, str(data.get("sender", "")), old, current)
		var recipient: String = _title(host, str(data.get("recipient", "")), old, current)
		var material: String = "这份记录"
		# A retained ID in a public receipt is already known; masked sources
		# remain generic. This lookup only supplies its existing public title.
		var source: String = str(data.get("source", ""))
		if host != null and source.begins_with("FACT-"):
			var public_title: String = str(host.title(source))
			if public_title != source and not public_title.begins_with("已知事实"): material = public_title
		return recipient + "已从" + sender + ("取得「%s」的副本并知晓其内容。" % material if data.get("grant") == "custody" else "获知「%s」的内容。" % material)
	if kind == "prayer_space_result":
		if data.get("outcome") in ["failure", "disaster"]: return "本次介入未成功，原处境继续。"
		var actual: Array[String] = []
		for change: Variant in data.get("state_changes", []):
			if change is String: _append(actual, change)
			elif change is Dictionary and change.get("text") is String: _append(actual, str(change.text))
		if not actual.is_empty(): return "\n".join(actual)
		if data.get("outcome") in ["deep", "success", "deterministic"]:
			var summary: String = str(data.get("effect", ""))
			if int(data.get("maintenance_remaining", 0)) > 0: summary += "\n约定 · 还需 %d 轮" % int(data.maintenance_remaining)
			return summary
		return ""
	if kind == "prayer_space_closed": return "已不再回应这项祈求；原处境按已有期限继续。"
	if kind == "prayer_result" and data.get("outcome") in ["failure", "disaster"]:
		return _title(host, str(data.get("actor", fact.get("actor", ""))), old, current) + "：此次回应未能解决原诉求。"
	if kind == "member_enrolled" and not subject.is_empty(): return subject + "：已成为正式成员"
	if kind == "member_left" and not subject.is_empty(): return subject + "：已解除成员身份"
	if kind == "cult_member_joined" and not subject.is_empty(): return subject + "：已加入当地教团"
	if kind == "manifest_completed": return "降临仪式完成，神意已进入诸界。"
	if kind == "manifest_interrupted": return "" if data.get("reason") == "completed" else "本次降临已终止；已付 %s 轮进度不保留。" % data.get("progress", 0)
	if kind == "population_transfer":
		var place := _title(host, str(fact.domain), old, current)
		match str(data.get("mode", "")):
			"convert": return "%s：%d 名当地居民成为信众。" % [place, data.amount]
			"leave": return "%s：%d 名信众离开信仰。" % [place, data.amount]
			"migrate": return "%d 名信众从%s迁往%s。" % [data.amount, place, _title(host, str(data.target), old, current)]
	if kind == "migration": return "%s已从%s迁往%s。" % [_title(host, str(fact.actor), old, current), _title(host, str(data.from), old, current), _title(host, str(data.to), old, current)]
	if kind == "anchor_institution_bound": return "%s：锚定已建立或修复，圣物已绑定；供奉须另行安排。" % _title(host, str(data.institution), old, current)
	if kind == "cult_appointed": return "%s：已就任%s的%s。" % [_title(host, str(fact.actor), old, current), _title(host, str(data.cult), old, current), {"leader":"领袖", "guardian":"护持者"}.get(data.role,"职务")]
	if kind == "cult_appointment_cancelled": return "%s：任命生效条件已失效，本次任命取消。" % _title(host, str(fact.actor), old, current)
	if kind == "event_publication" and current.has(str(data.get("institution", ""))): return _title(host, str(data.institution), old, current) + "：已公开收录这份证据"
	if kind == "relic_create" and not subject.is_empty(): return "已取得圣物：" + subject
	# prayer_delta/event_delta.amount is requested, not clamped actual; omitted.
	return ""

func _index(projection: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for collection: String in COLLECTIONS:
		for item: Dictionary in projection.get(collection, []):
			if not str(item.get("id", "")).is_empty(): result[item.id] = item
	return result

func _title(host, id: String, old: Dictionary, current: Dictionary) -> String:
	var item: Dictionary = current.get(id, old.get(id, {}))
	if item.is_empty(): return "尚未知晓的对象"
	var text: String = str(item.get("title", item.get("name", "")))
	if item.has("role") and item.has("domain") and not text.is_empty():
		var place: Dictionary = current.get(item.domain, old.get(item.domain, {}))
		if not str(place.get("title", "")).is_empty(): text = str(place.title) + " · " + text
	# Host only resolves identities already present in one public projection.
	if text.is_empty() and host != null: text = str(host.title(id))
	if text.is_empty() or text == id: return "已知对象"
	return text.replace("请求所指时空", "请求所指世界").replace("RELIC/FACT-", "").replace("NPC-", "").replace("DOMAIN-", "").replace("FACT-", "")

func _numeric(value: Variant) -> bool:
	return value is int or value is float

func _append(lines: Array[String], text: String) -> void:
	if not text.is_empty() and not text in lines: lines.append(text)
