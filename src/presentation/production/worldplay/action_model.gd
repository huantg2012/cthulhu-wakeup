extends RefCounted
## Builds a public target/verb catalog. Concrete eligibility is checked by Session.
const Store = preload("res://src/simulation/archive_store.gd")
const Requirements = preload("res://src/presentation/gameplay_requirements.gd")
const Management = preload("res://src/presentation/production/world_management.gd")
const POWER_ORDER := ["POWER_LISTEN", "POWER_DREAM", "POWER_ORACLE", "POWER_BESTOW", "POWER_APPOINT", "POWER_SACRIFICE", "POWER_BREACH", "POWER_SEED", "POWER_VEIL", "POWER_TRANSFER", "POWER_MANIFEST"]
const RELIC_ACTIONS := {
	"controlled": ["equip", "disassemble"], "carried": ["unequip", "disassemble"],
	"bound": ["unbind"], "ground": ["recover"], "seized": ["recover"]
}
const RELIC_NAMES := {"equip": "携带", "unequip": "卸下", "unbind": "解绑", "recover": "回收", "disassemble": "分解"}
const ORDER_NAMES := {"expand": "传教", "conceal": "敛藏", "hold": "守持"}
var rows: Array = []
var _session: RefCounted
var _projection: Dictionary
var _world := ""
var _cult := ""
var _actors: Array = []

func build(session: RefCounted, projection: Dictionary, world_id: String, cult_id := "") -> Array:
	rows.clear()
	_session = session
	_projection = projection
	_world = world_id
	_cult = cult_id
	_actors = []
	if not _cult.is_empty():
		for person: Dictionary in projection.get("people", []):
			if person.get("cult_id", "") == _cult: _actors.append(person.id)
		if _actors.is_empty(): _actors = ["__none__"]
	if _cult.is_empty(): _prayers()
	else: _orders()
	_powers()
	_activities()
	_anchors()
	_relics()
	return rows

func _row(id: String, title: String, group: String, entry: String, selection: Dictionary, kind := "action", subject_id := "") -> Dictionary:
	var row := {"id": id, "title": title, "group": group, "entry": entry,
		"selection": selection, "status": "核对中", "requirement": "选择对象后核对条件",
		"cost": "配置后核算", "effect": "", "kind": kind, "subject_id": subject_id,
		"available": false, "reason": ""}
	rows.append(row)
	return row

func _check(row: Dictionary, _actors_unused: Array = []) -> void:
	row.status = ""

func _price(faith: int, whispers: int) -> String:
	var parts := PackedStringArray()
	if whispers > 0: parts.append("%s 低语" % whispers)
	if faith > 0: parts.append("%s 信仰" % faith)
	return " · ".join(parts) if not parts.is_empty() else "无资源费用"

func _prayers() -> void:
	for prayer: Dictionary in _projection.get("prayers", []):
		if prayer.get("status") != "open": continue
		var descriptor: Dictionary = prayer.get("descriptor", {})
		var card: Dictionary = prayer.get("card", {})
		if descriptor.get("domain", card.get("domain", "")) != _world: continue
		var row := _row("prayer/" + str(prayer.id), str(prayer.title), "prayer", "", {}, "prayer", str(prayer.id))
		row.status = "本轮已用" if _projection.get("prayer_response_spent", false) else "待回应"
		row.cost = "随回应核算"
		row.requirement = "第 %s 轮到期" % card.due_turn if card.has("due_turn") else "查看求告处境与回应条件"
		row["petitioner"] = str(descriptor.get("subjects", {}).get("petitioner", ""))
		row["space"] = bool(descriptor.get("space", false))
		row.effect = _session.prayer_appeal(descriptor, card)
		row.reason = "本轮回应机会已用，仍可查阅。" if _projection.get("prayer_response_spent", false) else "比较实际回应后，再决定如何介入。"

func _powers() -> void:
	for key: String in POWER_ORDER:
		if not _cult.is_empty() and key != "POWER_APPOINT": continue
		var power: Dictionary = _session.catalog.display_tables.powers.get(key, {})
		if power.is_empty(): continue
		var selection: Dictionary = {"domain": _world}
		if not _cult.is_empty(): selection["cult"] = _cult
		var row := _row(key, str(power.name), "power", key, selection)
		row.cost = _price(int(power.faith), int(power.whispers))
		if key == "POWER_APPOINT": row.cost = "配置岗位后核算"
		row.requirement = str(power.target_requirement)
		row.effect = "成功时 · " + str(power.success)
		row["risk"] = str(power.always_cost)
		if key == "POWER_MANIFEST":
			row.title = "降临 · 跨世界"
			row.selection = {}
		_check(row)

func _activities() -> void:
	var choices: Dictionary = _session.action_choices("route/context", {"domain": _world})
	var operations: Array = []
	for field: Dictionary in choices.get("fields", []):
		if field.key == "operation": operations = field.options
	for option: Dictionary in operations:
		var definition: Dictionary = _session.catalog.display_tables.progression_route_operations.get(option.id, {})
		var row := _row(str(option.id), str(option.label), "activity", "route/context", {"domain": _world, "operation": option.id})
		row.effect = str(definition.get("description", ""))
		row.requirement = _activity_requirements(row.selection)
		_check(row, _actors)

func _activity_requirements(selection: Dictionary) -> String:
	var choices: Dictionary = _session.action_choices("route/context", selection)
	var labels := PackedStringArray()
	for field: Dictionary in choices.get("fields", []):
		if field.key in ["domain", "operation"] or field.get("optional", false): continue
		var label: String = "本团发起者" if field.key == "npc" and not _cult.is_empty() else str(field.label)
		if field.get("multiple", false) and field.has("count"):
			label += " ×%s" % field.count
		labels.append(label)
	return "需要 · " + "、".join(labels) if not labels.is_empty() else "选定参加者后核对具体条件"

func _anchors() -> void:
	for office: Dictionary in _projection.get("institutions", []):
		if office.get("domain") != _world or office.has("已知范围"): continue
		var anchor: Dictionary = {}
		for known: Dictionary in _projection.get("anchors", []):
			if known.get("institution") == office.id: anchor = known; break
		if not _cult.is_empty() and anchor.get("cult", "") != _cult: continue
		var established: bool = anchor.get("state") in ["active", "dormant"] and not anchor.get("needs_rebind", false)
		var caption := "锚定 · " + str(office.title)
		if not anchor.is_empty(): caption = ("维系 · " if established else "修复 · ") + str(office.title)
		var initial := {"domain": _world, "institution": office.id}
		var row := _row("anchor/" + str(office.id), caption, "anchor", "POWER_ANCHOR", initial, "anchor", str(office.id))
		var power: Dictionary = _session.catalog.display_tables.powers.POWER_ANCHOR
		row.cost = "维系供奉另列" if established else _price(int(power.faith), int(power.whispers))
		row.effect = "护持与实际供奉维系锚点，贡献苏醒。" if established else "成功时建立或修复锚点；绑定媒介，当轮供奉另列。"
		var conditions: Array = Requirements.anchor(_session, _projection, initial)
		row["conditions"] = conditions
		var summaries := PackedStringArray()
		for section: Dictionary in conditions:
			for item: Dictionary in section.items:
				if item.id in ["anchor_material", "guardian", "medium"]:
					var value: String = str(item.get("value", "%s/%s" % [item.get("current", 0), item.get("required", 0)]))
					summaries.append(str(item.title) + " " + value)
		row.requirement = " · ".join(summaries)
		if established:
			row.status = "维系不足" if anchor.get("state") == "dormant" else "已建立"
			row.reason = "查看护持、媒介及持续供奉条件。"
		elif int(_projection.get("awakening", 0)) < int(power.unlock_awakening):
			row.status = "未解锁"
			row.reason = "苏醒 %s / %s" % [_projection.get("awakening", 0), power.unlock_awakening]
		else:
			_check(row)

func _relics() -> void:
	for relic: Dictionary in _projection.get("relics", []):
		if relic.get("domain") != _world: continue
		if not _cult.is_empty() and not _cult_relic(relic): continue
		var definition: Dictionary = _session.catalog.display_tables.relics.get(str(relic.get("type", "")), {})
		for operation: String in RELIC_ACTIONS.get(str(relic.get("placement", "")), []):
			var title: String = str(RELIC_NAMES[operation]) + " · " + _session.object_title(str(relic.id))
			var row := _row("relic/" + str(relic.id) + "/" + operation, title, "relic", "relic/" + operation, {"domain": _world, "relic": relic.id}, "action", str(relic.id))
			row.requirement = "核对圣物状态、来源与处置条件"
			row.effect = str(definition.get("carry_effect", "")) if operation == "equip" else "查看此次处置的实际收益与损失。"
			_check(row)
	if not _cult.is_empty(): return
	var sources := {}
	for entry: Dictionary in _session.action_entries("opportunity/"):
		var source: String = str(entry.key).get_slice("/", 1)
		if sources.has(source): continue
		sources[source] = true
		if not _session.is_known_source(source): continue
		var fact: Dictionary = Store.entry(_session.world.state.facts, source, {})
		if fact.get("domain") != _world: continue
		if not _session.preview_action("opportunity/" + source + "/wait").get("ok", false): continue
		var detail: Dictionary = fact.get("changes", {})
		var definition: Dictionary = _session.catalog.display_tables.relics.get(str(detail.get("relic_type", "")), {})
		for mode: String in ["recover", "public", "wait"]:
			var key := "opportunity/" + source + "/" + mode
			var verb: String = {"recover": "回收", "public": "公开", "wait": "等待"}[mode]
			var row := _row(key, verb + " · " + str(definition.get("name", "机构媒介")), "relic", key, {}, "action", source)
			row.requirement = "第 %s 轮到期" % detail.due if detail.has("due") else "限时圣物机会"
			var office: Dictionary = Requirements.find(_projection, "institutions", str(detail.get("institution", "")))
			if not office.is_empty(): row.requirement = str(office.title) + " · " + row.requirement
			row.effect = {"recover": "取得圣物供携带或锚定。", "public": "永久放弃物件换取信仰，并增加察觉。", "wait": "暂时等待；期限不会延长。"}[mode]
			_check(row)

func _orders() -> void:
	if _cult.is_empty(): return
	var cult: Dictionary = Requirements.find(_projection, "cults", _cult)
	if cult.is_empty(): return
	var current: String = str(_projection.get("economy_plan", {}).get("strategies", {}).get(_cult, cult.get("strategy", "hold")))
	for strategy: String in ORDER_NAMES:
		var row := _row("order/" + _cult + "/" + strategy, str(ORDER_NAMES[strategy]), "cult", "SESSION_SET_ECONOMY_PLAN", {"cult": _cult, "strategy": strategy}, "order", _cult)
		row.requirement = "登记本轮指令；轮末正式执行"
		row.cost = "轮末结算"
		row.effect = str(Management.STRATEGY_INTENT[strategy])
		row.status = "已登记" if strategy == current else "可比较"
		if _projection.get("phase") != "actions" or cult.get("status") == "destroyed":
			row.status = "只读"
			row.reason = "当前只能查阅本轮指令。"

func _cult_relic(relic: Dictionary) -> bool:
	return cult_relic(_projection, relic, _cult)

## This describes the visible relationship, not permission to use the item.
## Controlled stock is stored by domain, including a destroyed cult's historical
## inventory; the formal relic query decides whether control has been restored.
static func cult_relic(projection: Dictionary, relic: Dictionary, cult_id: String) -> bool:
	var cult: Dictionary = Requirements.find(projection, "cults", cult_id)
	if cult.is_empty() or relic.get("domain") != cult.get("domain"): return false
	if relic.get("placement") == "controlled": return true
	var holder: Dictionary = Requirements.find(projection, "people", str(relic.get("holder", "")))
	if not holder.is_empty() and holder.get("cult_id", "") == cult_id: return true
	var anchor: Dictionary = Requirements.find(projection, "anchors", str(relic.get("anchor", "")))
	return not anchor.is_empty() and anchor.get("cult", "") == cult_id

func cards(session: RefCounted, projection: Dictionary, world_id: String, cult_id := "") -> Array:
	var result: Array = []
	var rows: Array = build(session,projection,world_id,cult_id)
	var grouped := {}
	for row: Dictionary in rows:
		if row.group in ["anchor","relic"]:
			var action_id: String
			var caption: String
			if row.group == "anchor":
				action_id = "maintain" if row.status in ["已建立","维系不足"] else "bind"
				caption = "维系" if action_id=="maintain" else "锚定"
			else:
				action_id = str(row.entry).get_slice("/",2) if str(row.entry).begins_with("opportunity/") else str(row.entry).get_slice("/",1)
				caption = {"equip":"携带","unequip":"卸下","unbind":"解绑","recover":"回收","disassemble":"分解","public":"公开","wait":"等待"}.get(action_id,action_id)
			var key: String = str(row.group)+"/"+action_id
			if not grouped.has(key):
				var card := row.duplicate(true)
				card.merge({"id":key,"title":caption,"type":"action","targets":[]},true)
				grouped[key] = card
				result.append(card)
			grouped[key].targets.append(row.duplicate(true))
		else:
			var card := row.duplicate(true)
			card.type = "action"
			result.append(card)
	# The verb remains discoverable when every existing anchor is established.
	if not grouped.has("anchor/bind"):
		var power: Dictionary = session.catalog.display_tables.powers.POWER_ANCHOR
		result.append({"id":"anchor/bind","title":"锚定","type":"action","group":"anchor","kind":"action","entry":"POWER_ANCHOR","selection":{"domain":world_id},"targets":[],"cost":_price(int(power.faith),int(power.whispers)),"effect":str(power.success),"requirement":str(power.target_requirement),"risk":str(power.always_cost)})

	return result.filter(func(card: Dictionary) -> bool: return unlocked(card, session.catalog, projection))

static func unlocked(card: Dictionary, catalog: RefCounted, projection: Dictionary) -> bool:
	if card.get("status") == "未解锁": return false
	var power_id := ""
	if card.get("group") == "power":
		power_id = str(card.subject.id) if card.type == "object" else str(card.entry)
	elif card.id == "anchor/bind":
		power_id = "POWER_ANCHOR"
	return power_id.is_empty() or int(projection.get("awakening", 0)) >= int(catalog.display_tables.powers[power_id].unlock_awakening)
