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
	"private_records": "继续秘密保管原记录", "contract_released": "此次神迹履约依赖已解除",
	"prophet_allowed": "已获准继续以先知身份活动", "custody_retained": "维持原保管状态",
	"institution_hostile": "已成为敌对机构", "departed": "已离去",
	"memory_dispute_closed": "此次记忆争议已结束", "cooperation_opportunity_closed": "此次合作机会已结束",
	"recovery_opportunity_closed": "此次争夺机会已结束", "request_closed": "此次请求已结束",
}

func build(host, result: Dictionary, before: Dictionary, after: Dictionary, action_title: String) -> Array[String]:
	var lines: Array[String] = []
	if not result.get("ok", false): return ["未执行：" + str(result.get("error", "当前条件不满足"))]
	var old: Dictionary = _index(before)
	var current: Dictionary = _index(after)
	var facts: Array = result.get("facts", [])
	var outcome: String = ""
	for check: Dictionary in result.get("result", {}).get("checks", []):
		outcome = {"deep": "深刻成功", "success": "成功", "failure": "失败", "disaster": "灾变"}.get(str(check.get("outcome", "")), outcome)
	for fact: Dictionary in facts:
		if fact.get("kind") == "prayer_space_result" and fact.get("changes", {}).get("disclosure") == "unknown" and fact.changes.get("outcome") in ["deep", "success"]: outcome = "已显现"
	if not action_title.is_empty(): lines.append(action_title + (" · " + outcome if not outcome.is_empty() else " · 已执行"))
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
			if not _numeric(item.get(field)): continue
			if not _numeric(prior.get(field)):
				if not field in ["alert", "pollution", "barrier", "stability"]: revealed.append(str(ATTRIBUTES[field]) + " " + str(item[field]))
			elif prior[field] != item[field]: numbers.append("%s %s → %s" % [ATTRIBUTES[field], prior[field], item[field]])
		if not numbers.is_empty(): _append(changes, name_value + "：" + "；".join(numbers))
		if not revealed.is_empty(): learned.append(name_value + " · 现可知：" + "、".join(revealed))
	# Concrete facts supply effects that are not scalar fields, such as a cure,
	# fulfilled obligation or material reception. No generic kind/ID dump.
	var fact_lines: Array[String] = []
	for fact: Dictionary in facts:
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
	return lines

func resource_summary(before: Dictionary, after: Dictionary) -> String:
	var resources: Array[String] = []
	for field: String in ["faith", "whispers", "awakening", "insight", "wounds"]:
		if not _numeric(before.get(field)) or not _numeric(after.get(field)) or before[field] == after[field]: continue
		var label_value: String = {"faith": "信仰", "whispers": "低语", "awakening": "苏醒", "insight": "洞见", "wounds": "创伤"}[field]
		resources.append("%s %s → %s" % [label_value, before[field], after[field]])
	return " · ".join(resources)

func _fact_line(host, fact: Dictionary, old: Dictionary, current: Dictionary) -> String:
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
			if not str(data.get("tradeoff", "")).is_empty(): summary += "\n" + str(data.tradeoff)
			if int(data.get("maintenance_remaining", 0)) > 0: summary += "\n约定 · 还需 %d 轮" % int(data.maintenance_remaining)
			return summary
		return ""
	if kind == "prayer_space_closed": return "已不再回应这项祈求；原处境按已有期限继续。"
	if kind == "prayer_result" and data.get("outcome") in ["failure", "disaster"]:
		return _title(host, str(data.get("actor", fact.get("actor", ""))), old, current) + "：此次回应未能解决原诉求。"
	if kind == "member_enrolled" and not subject.is_empty(): return subject + "：已成为正式成员"
	if kind == "member_left" and not subject.is_empty(): return subject + "：已解除成员身份"
	if kind == "cult_member_joined" and not subject.is_empty(): return subject + "：已加入当地教团"
	if kind == "manifest_interrupted": return "本次降临已终止；已付 %s 轮进度不保留。" % data.get("progress", 0)
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
