extends RefCounted
## Read-only player-facing conditions. Counts are actual public progress, never
## selector lengths, raw fact counts or projected future successes.
const Anchors = preload("res://src/game/anchors.gd")
const Routes = preload("res://src/game/anchor_routes.gd")
const Powers = preload("res://src/game/powers.gd")
const Cults = preload("res://src/game/cults.gd")
const Store = preload("res://src/simulation/archive_store.gd")

static func quantity(id: String, title: String, current: int, required: int, hint := "") -> Dictionary:
	return {"id":id, "title":title, "current":current, "required":required, "state":"met" if current >= required else "missing", "hint":hint}

static func condition(id: String, title: String, state: String, value: String, hint := "") -> Dictionary:
	return {"id":id, "title":title, "state":state, "value":value, "hint":hint}

static func group(title: String, items: Array) -> Dictionary:
	return {"title":title, "items":items}

static func action(session, public: Dictionary, row: Dictionary, selection: Dictionary, readable: Callable = Callable()) -> Array:
	var result: Array = []
	var key: String = str(row.get("key", ""))
	if key == "POWER_ANCHOR":
		result.append_array(anchor(session, public, selection))

	if key == "cults/transfer_material" and not str(selection.get("target_institution", "")).is_empty():
		var target: Array = anchor(session, public, {"institution":selection.target_institution})
		result.append_array(target)
	if key.begins_with("opportunity/"):
		var source: String = key.get_slice("/", 1)
		if session.is_known_source(source):
			var fact: Dictionary = Store.entry(session.world.state.facts, source, {})
			var due: int = int(fact.get("changes", {}).get("due", -1))
			if due >= 0: result.append(group("机会期限", [condition("opportunity_due", "到期轮次", "met" if int(public.turn) <= due else "missing", "第 %d 轮" % due, "等待不会延长期限。")]))
		if key.ends_with("/recover") and not row.get("preview", {}).get("ok", false): result.append(group("回收消耗 · 持有 / 所需", [quantity("cost_faith", "信仰", int(public.get("faith", 0)), session.catalog.integer("relic_recovery_faith"))]))
	var progress: Array = activity(row.get("details", {}), readable) if key == "route/context" else []
	if key.begins_with("POWER_MANIFEST"):
		var manifest: Dictionary = public.get("manifest", {})
		progress.append(quantity("manifest_paid", "仪式实付轮次", int(manifest.get("progress", 0)), session.catalog.integer("manifest_duration"), "仅实际付款增加进度；中止会失去已付轮次。"))
		if not manifest.is_empty():
			progress.append(condition("manifest_turn", "本轮续付", "met" if int(manifest.paid_turn) == int(public.turn) else "missing", "已付" if int(manifest.paid_turn) == int(public.turn) else "待付"))
			progress.append(condition("manifest_last", "最近实付", "info", "第 %s 轮" % manifest.paid_turn))
	if not progress.is_empty():
		for item: Dictionary in progress: item["progress"] = item.state != "info"
		result.append(group("实际进展", progress))
	var power: Dictionary = session.catalog.tables.powers.get(key, {})
	if not power.is_empty() and int(public.get("awakening", 0)) < int(power.unlock_awakening): result.append(group("权能解锁", [quantity("awakening", "苏醒", int(public.get("awakening", 0)), int(power.unlock_awakening))]))
	var prepared: Dictionary = row.get("preview", {})
	var costs: Dictionary = prepared.get("preview", {})
	# Powers charge authored fixed costs, even if another prerequisite is
	# missing. Appointment is delegated to Cults and must use its own preview.
	if not prepared.get("ok", false) and key != "POWER_APPOINT":
		if not power.is_empty(): costs = {"faith":int(power.faith), "whispers":int(power.whispers)}
		elif key == "POWER_MANIFEST_CONTINUE": costs = {"faith":session.catalog.integer("manifest_continue_faith"), "whispers":session.catalog.integer("manifest_continue_whispers")}
	if not costs.is_empty():
		var resources: Array = []
		for field: String in ["whispers", "faith"]:
			var needed: int = int(costs.get(field, costs.get("faith_cost", 0) if field == "faith" else 0))
			if needed > 0: resources.append(quantity("cost_" + field, "低语" if field == "whispers" else "信仰", int(public.get(field, 0)), needed, "当前持有 / 本次所需；执行后才会扣除。"))
		if not resources.is_empty(): result.append(group("本次消耗 · 持有 / 所需", resources))
	var missing: bool = row.get("fields", []).any(func(field: Dictionary) -> bool: return not field.get("optional", false) and _empty(selection.get(field.key)))
	var ready: bool = prepared.get("ok", false) and not missing
	var hint: String = "选定必需对象后显示本次行动的可用性。" if missing else session.explain_error(str(prepared.get("error", "")))
	result.append(group("本次行动", [condition("action_ready", "执行条件", "met" if ready else ("unknown" if missing else "missing"), "可执行" if ready else ("待配置" if missing else "不可执行"), hint)]))
	return result

static func activity(details: Dictionary, readable: Callable = Callable()) -> Array:
	var result: Array = []
	if details.has("所需成功回合"): result.append(quantity("activity_success", "跨轮成功", int(details.get("成功回合", 0)), int(details["所需成功回合"]), "原参加者在不同回合实际成功；失败不增加进度。"))
	if details.has("所需交付"): result.append(quantity("activity_delivery", "约定交付", int(details.get("已完成交付", 0)), int(details["所需交付"]), "固定条款分轮履行；预览不转移记录。"))
	for i: int in details.get("原两项条款", []).size():
		var term: Dictionary = details["原两项条款"][i]
		var done: bool = term.get("状态") == "已完成"
		var record: String = str(term.get("原记录", ""))
		if readable.is_valid(): record = str(readable.call(record))
		result.append(condition("delivery_" + str(i), "第%s项交付" % (i + 1), "met" if done else "missing", "已交付" if done else "待交付", "%s → %s：%s" % [term.get("交予者", ""), term.get("接收者", ""), record]))
	if details.has("教习"):
		result.append(condition("lesson", "教习", "met" if details["教习"] == "已传授" else "missing", str(details["教习"])))
		var done: bool = details.get("学徒施行") == "已完成"
		result.append(condition("practice", "原学徒施行", "met" if done else "missing", "已完成" if done else "待施行", str(details.get("学徒施行", ""))))
	if details.has("约定"): result.append(condition("covenant", "双向条款", "met" if str(details["约定"]).begins_with("已固定") else "missing", "已固定" if str(details["约定"]).begins_with("已固定") else "待约定"))
	if details.has("后续行动"): result.append(condition("followup", "后续回应", "info", "从祈求入口", str(details["后续行动"])))
	for item: Dictionary in result: item["progress"] = item.state != "info"
	return result

static func anchor(session, public: Dictionary, selection: Dictionary) -> Array:
	var institution: String = str(selection.get("institution", ""))
	var office: Dictionary = find(public, "institutions", institution)
	if office.is_empty(): return [group("所需条件", [condition("institution", "扎根机构", "unknown", "待选择")])]
	var domain: String = str(office.domain)
	var world: Dictionary = find(public, "domains", domain)
	var sources: Array = session.anchor_source_options(institution)
	var source: String = str(selection.get("qualification", ""))
	if not sources.any(func(x: Dictionary) -> bool: return x.id == source): source = str(sources[0].id) if not sources.is_empty() else ""
	var materials: Array = []
	if not source.is_empty():
		var fact: Dictionary = Store.entry(session.world.state.facts, source, {})
		var basis: Dictionary = fact.get("changes", {}).get("basis", {})
		var rule: Dictionary = session.catalog.tables.anchor_route_rules.get(str(basis.get("route", "")), {})
		# A valid known basis has already passed the authoritative evaluator.
		# Counts describe that bundle, never every vaguely related record.
		for pair: Array in [["records", "独立见证"], ["witnesses", "原始见证者"], ["uses", "跨轮实践"], ["rituals", "实际祭仪"], ["legs", "约定交付"], ["participants", "原参加者"]]:
			if not basis.get(pair[0]) is Array or (pair[0] == "witnesses" and basis.has("records")): continue
			var required: int = Routes.number(rule, "turn_parameter", "turns", session.catalog) if pair[0] == "uses" else Routes.number(rule, "count_parameter", "count", session.catalog)
			if required > 0: materials.append(quantity("basis_" + pair[0], pair[1], basis[pair[0]].size(), required))
		materials.append(condition("anchor_material", "锚定材料", "met", "已齐备", "这些材料现在可以用于该机构的锚定。"))
	else:
		if world.get("profile") == "CIV_01":
			var required: int = session.catalog.integer("testimony_required_witnesses")
			materials.append(quantity("basis_records", "独立见证", independent_testimonies(session, institution, required), required, "仅计已知、仍有效、原见证者在场且当地实际持有的见证；同一事实、同轮或同一见证者不重复计数。可通过持续档案实践形成另一种锚定材料。"))
		materials.append(condition("anchor_material", "锚定材料", "missing", "未齐备", "须取得一条完整且当前有效的锚定材料路径；记录副本不会增加原始见证或实践次数。"))
	var state: Dictionary = session.world.state
	var guardians: Array = []
	var local_cult: String = ""
	for cult: Dictionary in public.get("cults", []):
		if cult.get("domain") == domain and cult.get("status") == "active": local_cult = cult.id; break
	for known: Dictionary in public.get("people", []):
		if known.get("domain") != domain or known.get("status") != "active": continue
		var person: Dictionary = Store.entry(state.npcs, known.id, {})
		if person.is_empty() or not Cults.eligible(state, person, session.catalog): continue
		if not person.get("bound_member", false) and not session.is_known_source(str(person.get("dedication_source", ""))): continue
		if local_cult.is_empty() or (not str(person.get("cult_id", "")).is_empty() and person.cult_id != local_cult): continue
		if not Powers.anchor_assignment_error(state, institution, known.id).is_empty(): continue
		guardians.append(known.id)
	var media: int = 0
	for relic: Dictionary in public.get("relics", []):
		if relic.get("domain") != domain or not relic.get("placement") in ["controlled", "carried", "bound"]: continue
		if relic.placement == "carried" and not relic.get("holder") in guardians: continue
		if not Powers.anchor_assignment_error(state, institution, "", relic.id).is_empty(): continue
		media += 1
	var people: Array = [quantity("guardian", "可用护持者", guardians.size(), 1, "已知、在场、忠诚且自愿，并未护持其他锚点；已有锚点须使用原护持者或先任命继任者。本轮能否执行另由行动资格检查。"), quantity("medium", "可绑定圣物", media, 1, "只计当地受控、由合格护持者携带或已绑定于本机构的圣物。")]
	var organization: Array = []
	for cult: Dictionary in public.get("cults", []):
		if cult.get("domain") != domain: continue
		organization.append(quantity("followers", "当地信众", int(cult.get("followers", 0)), session.catalog.integer("anchor_followers_min")))
		organization.append(quantity("cohesion", "教团凝聚", int(cult.get("cohesion", 0)), session.catalog.integer("anchor_cohesion_min")))
		break
	if organization.is_empty(): organization.append(condition("cult", "当地教团", "missing", "尚未建立"))
	return [group("锚定材料", materials), group("护持与绑定", people), group("当地组织条件", organization)]

static func independent_testimonies(session, institution: String, required: int) -> int:
	var state: Dictionary = session.world.state
	var domain: String = state.institutions[institution].domain
	var materials: Dictionary = {}; var choices: Array = []
	for id: String in session.world.history.anchor_material_heads(domain, session.catalog.integer("collective_required_witnesses")):
		if not session.is_known_source(id): continue
		var item: Dictionary = Anchors.material(state, id, session.catalog, session.world.history)
		if item.is_empty() or not item.get("current", false) or not item.kind in ["evidence", "dream"]: continue
		materials[id] = item
		# Custody must be known as well as real. A hidden holder cannot improve
		# the player's counter. Original witnessing itself is not transferable.
		var holders: Array = item.get("owners", []).filter(func(person: String) -> bool: return session._identity_known(person) and _public_custody(session, item, person) and Routes.held(state, item, person, institution, session.world.history))
		if holders.is_empty(): continue
		for person: String in item.get("originals", []):
			if session._identity_known(person): choices.append({"record":id, "person":person})
	return _independent_count(state, institution, materials, choices, 0, [], [], required, session.world.history)

static func _public_custody(session, item: Dictionary, person: String) -> bool:
	if person in item.get("originals", []): return true
	for id: String in session.world.history.material_receipts(str(item.get("canonical", item.id))):
		if not session.is_known_source(id): continue
		var fact: Dictionary = Store.entry(session.world.state.facts, id, {})
		if fact.get("changes", {}).get("recipient") == person and fact.changes.get("grant") == "custody": return true
	return false

static func _independent_count(state: Dictionary, institution: String, materials: Dictionary, choices: Array, start: int, records: Array, people: Array, required: int, reader) -> int:
	var best: int = records.size()
	if best >= required: return best
	for i: int in range(start, choices.size()):
		var next_records: Array = records + [choices[i].record]
		var next_people: Array = people + [choices[i].person]
		var checked: Dictionary = Routes.independent_records(state, institution, {"records":next_records, "witnesses":next_people}, materials, "testimonies", reader)
		if not checked.allowed: continue
		best = maxi(best, _independent_count(state, institution, materials, choices, i + 1, next_records, next_people, required, reader))
		if best >= required: break
	return best

static func find(public: Dictionary, collection: String, id: String) -> Dictionary:
	for item: Dictionary in public.get(collection, []):
		if item.id == id: return item
	return {}

static func _empty(value: Variant) -> bool:
	return value == null or ((value is String or value is Array) and value.is_empty())

static func changes(before: Array, after: Array) -> Array:
	var prior: Dictionary = {}
	for section: Dictionary in before:
		for item: Dictionary in section.items: prior[item.id] = item
	var result: Array = []
	for section: Dictionary in after:
		var items: Array = []
		for item: Dictionary in section.items:
			if str(item.id).begins_with("cost_") or item.id in ["awakening", "action_ready", "opportunity_due"]: continue
			var updated: Dictionary = item.duplicate(true)
			var old: Dictionary = prior.get(item.id, {})
			if not old.is_empty() and (old.get("current") != item.get("current") or old.get("value") != item.get("value")):
				updated["previous"] = old.get("current", old.get("value", ""))
			items.append(updated)
		if not items.is_empty(): result.append(group(section.title, items))
	return result
