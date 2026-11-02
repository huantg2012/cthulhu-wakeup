extends RefCounted
## Subject-side presentation of the existing player's knowledge projection.
## All mutations go through the host's Session methods; no rule state is created here.

const ActionCatalog = preload("res://src/presentation/action_catalog.gd")
const PLACEMENTS: Dictionary = {"controlled":"当地保管", "ground":"遗落", "carried":"携带", "bound":"绑定", "seized":"扣押", "sealed":"封存", "consumed":"已消耗"}
const STATES: Dictionary = {"active":"在场", "dead":"死亡", "missing":"失踪", "detained":"被拘禁", "imprisoned":"被拘禁", "dormant":"休眠", "destroyed":"已毁", "departed":"已离开"}
var queries: Dictionary = {}
var world_filter: String = "全部"
var history_offsets: Dictionary = {}

func render(host, box: VBoxContainer, kind: String, id: String = "") -> void:
	if not host.projection.get("active", false):
		box.add_child(host.label("邪神苏醒", true))
		box.add_child(host.label("开始新局或载入已有进度，进入你实际获知的联系。"))
		box.add_child(host.button("开启新局", func() -> void: host.start_new(1)))
		return
	match kind:
		"home": _home(host, box)
		"prayers": _prayers(host, box)
		"prayer": _prayer(host, box, id)
		"people": _people(host, box, id)
		"person": _person(host, box, id)
		"cult": _cult(host, box, id)
		"members": _members(host, box, id)
		"worlds": _worlds(host, box)
		"world": _world(host, box, id)
		"relics": _relics(host, box, id)
		"relic": _relic(host, box, id)
		"anchor": _anchor(host, box, id)
		"anchors": _anchors(host, box, id)
		"budget": _budget(host, box)
		"attention": _attention(host, box, id)
		"history": _history(host, box, id)
		"fact": _fact(host, box, id)
		"self": _self(host, box)
		"ending": _ending(host, box)
		"materials": _materials(host, box, id)
		_:
			box.add_child(host.label("从已知对象继续查看", true))
			box.add_child(host.button("回到当前联系", func() -> void: host.show_subject("home")))

func _find(host, collection: String, id: String) -> Dictionary:
	for value: Dictionary in host.projection.get(collection, []):
		if str(value.get("id", "")) == id: return value
	return {}

func _is_action(host) -> bool:
	return host.projection.get("phase") == "actions" and not host.projection.get("terminal", false)

func _heading(host, box: VBoxContainer, text_value: String) -> void:
	box.add_child(host.label(text_value, true))

func _divider(box: VBoxContainer) -> void:
	box.add_child(HSeparator.new())

func _link(host, box: VBoxContainer, text_value: String, kind: String, id: String = "") -> void:
	box.add_child(host.button(text_value, func() -> void: host.show_subject(kind, id)))

func _action(host, box: VBoxContainer, text_value: String, key: String, selection: Dictionary = {}) -> void:
	var control: Button = host.button(text_value, func() -> void: host.open_action(key, selection.duplicate(true)))
	control.disabled = not _is_action(host)
	box.add_child(control)

func _pair(host, box: VBoxContainer, name: String, value: Variant) -> void:
	box.add_child(host.label(name + "　" + ("未掌握" if value == null else host.describe(value))))

func _current_cult(host, id: String) -> Dictionary:
	var found: Dictionary = _find(host, "cults", id)
	if not found.is_empty(): return found
	for c: Dictionary in host.projection.get("cults", []):
		if str(c.get("domain", "")) == id: return c
	return {}

func _cult_name(host, c: Dictionary) -> String:
	return host.title(str(c.get("domain", ""))) + "的教团"

func _members_for(host, c: Dictionary) -> Array:
	var result: Array = []
	for p: Dictionary in host.projection.get("people", []):
		if p.get("bound_member", false) and str(p.get("cult_id", "")) == str(c.get("id", "")): result.append(p)
	return result

func _role(host, p: Dictionary) -> String:
	var roles: PackedStringArray = []
	for c: Dictionary in host.projection.get("cults", []):
		if c.get("leader") == p.id: roles.append("领袖")
	for a: Dictionary in host.projection.get("anchors", []):
		if a.get("guardian") == p.id: roles.append("护持者")
	if roles.is_empty(): roles.append("成员" if p.get("bound_member", false) else "已有联系")
	return " / ".join(roles)

func _state(value: Variant) -> String:
	return str(STATES.get(str(value), value))

func _row(host, key: String, selection: Dictionary = {}) -> Dictionary:
	for value: Dictionary in host.session.action_catalog(selection):
		if value.key == key: return value
	return {}

func _home(host, box: VBoxContainer) -> void:
	if host.projection.get("terminal", false):
		_ending(host, box)
		return
	_heading(host, box, "当前联系")
	if host.projection.phase == "between":
		box.add_child(host.label("本轮已经结算。最新变化留在编年史；你可以查看对象，再进入下一回合。"))
		box.add_child(host.button("进入下一回合", func() -> void: host.advance()))
	if not host.projection.get("manifest", {}).is_empty():
		_link(host, box, "降临正在进行 · 查看本轮续付", "self")
	if not host._responded():
		_prayers(host, box, false)
	else:
		box.add_child(host.label("本轮回应机会已用，其他祈求仍可查看。"))
		_link(host, box, "查看祈求与期限", "prayers")
	_divider(box)
	var cults: Array = host.projection.get("cults", [])
	if cults.is_empty():
		_heading(host, box, "已经与你建立联系的人")
		for p: Dictionary in host.projection.get("people", []):
			_link(host, box, host.title(p.id) + " · " + _role(host, p), "person", p.id)
		box.add_child(host.label("尚无教团。人物的献身、活动与实际形成条件，从人物处查看。"))
	else:
		_heading(host, box, "持续的联系")
		for c: Dictionary in cults.slice(0, 3):
			_link(host, box, _cult_name(host, c) + " · " + str(_members_for(host, c).size()) + "位具名成员", "cult", c.id)
		if cults.size() > 3: box.add_child(host.label("其余教团可从左侧名称索引直接定位。"))
	_link(host, box, "全部已知世界", "worlds")

func _prayers(host, box: VBoxContainer, heading: bool = true) -> void:
	if heading: _heading(host, box, "当前祈求")
	var prayers: Array = host.projection.get("prayers", [])
	if prayers.is_empty():
		box.add_child(host.label("当前没有展示中的祈求。已有联系仍可查看和主动处置。"))
		return
	for p: Dictionary in prayers:
		var descriptor: Dictionary = p.get("descriptor", {})
		var subject: String = str(descriptor.get("subjects", {}).get("petitioner", ""))
		var due: Variant = p.get("card", {}).get("due_turn")
		var text_value: String = str(p.title)
		if not subject.is_empty(): text_value += "\n" + host.title(subject)
		if due != null: text_value += " · 请求至第%d轮" % int(due)
		if descriptor.get("crisis", {}).has("due"): text_value += "\n原危机：第%d轮" % int(descriptor.crisis.due)
		if host._responded(): text_value += " · 本轮只读"
		_link(host, box, text_value, "prayer", p.id)

func _prayer(host, box: VBoxContainer, id: String) -> void:
	var p: Dictionary = _find(host, "prayers", id)
	if p.is_empty():
		box.add_child(host.label("这项请求已离开当前展示。它的实际回应与期限变化可在编年史回顾。"))
		_link(host, box, "查看相关记录", "history", id)
		return
	_heading(host, box, str(p.title))
	var details: Dictionary = ActionCatalog.new()._context(host.session, p.get("descriptor", {}), p.get("card", {}))
	for key: String in details:
		if key != "当前诉求": _pair(host, box, key.replace("时空", "世界"), details[key])
	var descriptor: Dictionary = p.get("descriptor", {})
	for role: String in descriptor.get("subjects", {}):
		var value: Variant = descriptor.subjects[role]
		var values: Array = value if value is Array else [value]
		for subject_id: Variant in values:
			if not subject_id is String: continue
			if not _find(host, "people", subject_id).is_empty(): _link(host, box, "查看 " + host.title(subject_id), "person", subject_id)
	_divider(box)
	if host._responded():
		box.add_child(host.label("本轮已回应一次。下轮仍需依据这项请求的存续与期限决定。"))
	var content: String = str(descriptor.get("content_id", p.get("card", {}).get("content_id", "")))
	var definition: Dictionary = host.session.catalog.tables.prayers.get(content, {})
	for variant: String in ["shallow", "deep"]:
		var name_value: String = "浅触" if variant == "shallow" else "深应"
		_heading(host, box, name_value)
		box.add_child(host.label(str(definition.get(variant + "_gain", ""))))
		box.add_child(host.label("始终代价　" + str(definition.get(variant + "_cost", ""))))
		var control: Button = host.button("准备" + name_value, func() -> void: host.open_action("prayer/" + id + "/" + variant))
		control.disabled = not _is_action(host) or host._responded()
		box.add_child(control)
	_link(host, box, "返回当前请求", "prayers")

func _people(host, box: VBoxContainer, domain: String) -> void:
	_heading(host, box, "已知人物" if domain.is_empty() else host.title(domain) + "的人物")
	for p: Dictionary in host.projection.get("people", []):
		if not domain.is_empty() and p.get("domain") != domain: continue
		_link(host, box, host.title(p.id) + " · " + _role(host, p) + " · " + _state(p.get("status", "仅有请求线索")), "person", p.id)

func _person(host, box: VBoxContainer, id: String) -> void:
	var p: Dictionary = _find(host, "people", id)
	if p.is_empty():
		box.add_child(host.label("尚未取得这个人物的身份资料。")); return
	_heading(host, box, host.title(id))
	_pair(host, box, "职责", _role(host, p))
	_pair(host, box, "处境", _state(p.get("status", "仅有请求线索")))
	_link(host, box, host.title(str(p.get("domain", ""))), "world", str(p.get("domain", "")))
	if p.get("bound_member", false):
		box.add_child(host.label("意志 %s · 洞察 %s · 影响 %s · 适应 %s" % [p.get("will", "?"), p.get("insight", "?"), p.get("influence", "?"), p.get("adaptation", "?")]))
		box.add_child(host.label("忠诚 %s · 理智 %s" % [p.get("loyalty", "?"), p.get("sanity", "?")]))
		box.add_child(host.label("本轮执行机会已用" if int(p.get("acted_turn", -1)) == int(host.projection.turn) else "本轮尚未承担执行任务"))
	if not str(p.get("cult_id", "")).is_empty(): _link(host, box, "所属教团与全体成员", "cult", p.cult_id)
	for r: Dictionary in host.projection.get("relics", []):
		if r.get("holder") == id and r.get("placement") != "consumed": _link(host, box, "携带 · " + host.title(r.id), "relic", r.id)
	for a: Dictionary in host.projection.get("anchors", []):
		if a.get("guardian") == id: _link(host, box, "护持 · " + host.title(a.id), "anchor", a.id)
	_divider(box)
	var selection: Dictionary = {"domain":str(p.get("domain", "")), "npc":id}
	_activities(host, box, selection)
	var transfer: Dictionary = _row(host, "cults/transfer_material", {"sender":id})
	if not transfer.is_empty(): _action(host, box, "选择记录与接收人", "cults/transfer_material", {"sender":id})
	_action(host, box, "入梦", "POWER_DREAM", selection)
	if p.get("bound_member", false):
		_action(host, box, "任命职责", "POWER_APPOINT", selection)
		_action(host, box, "查看离团条件", "attention/leave", {"npc":id})
	else: _action(host, box, "查看接纳条件", "attention/enroll", {"npc":id})
	_link(host, box, "此人的已知经历", "history", id)

func _activities(host, box: VBoxContainer, selection: Dictionary) -> void:
	_heading(host, box, "活动与正在推进的事情")
	var row: Dictionary = _row(host, "route/context", selection)
	if row.is_empty():
		box.add_child(host.label("当前阶段不可发起人物活动。")); return
	for field: Dictionary in row.get("fields", []):
		if field.key == "npc" and not field.options.any(func(option: Dictionary) -> bool: return str(option.id) == str(selection.get("npc", ""))):
			box.add_child(host.label("这个人物尚未具备可选的活动身份。可从其祈求或已有联系继续了解。")); return
	var operations: Array = []
	for field: Dictionary in row.get("fields", []):
		if field.key == "operation": operations = field.options
	if operations.is_empty():
		box.add_child(host.label("此人当前没有已知可进入的活动；人物资格和真实联系变化后重新查看。")); return
	for operation: Dictionary in operations:
		var chosen: Dictionary = selection.duplicate(true); chosen["operation"] = operation.id
		_action(host, box, str(operation.label) + " · 查看当前条件与进展", "route/context", chosen)
	box.add_child(host.label("每项活动使用自己的原参加者、材料和跨轮进展；右侧会列出当前可选对象及尚缺条件。"))

func _cult(host, box: VBoxContainer, id: String) -> void:
	var c: Dictionary = _current_cult(host, id)
	if c.is_empty():
		box.add_child(host.label("这里尚未形成已知教团。")); _link(host, box, "查看当地人物", "people", id); return
	_heading(host, box, _cult_name(host, c))
	_pair(host, box, "状态", {"active":"运作中", "dormant":"休眠", "destroyed":"已毁"}.get(str(c.get("status", "")), c.get("status")))
	_pair(host, box, "无名信众", c.get("followers", c.get("unnamed_followers")))
	_pair(host, box, "凝聚", c.get("cohesion"))
	_link(host, box, "所在世界资料", "world", c.domain)
	_heading(host, box, "本轮指令")
	var plan: Dictionary = host.projection.get("economy_plan", {})
	var current: String = str(plan.get("strategies", {}).get(c.id, c.get("strategy", "hold")))
	var controls := HBoxContainer.new(); box.add_child(controls)
	for strategy: String in ["expand", "conceal", "hold"]:
		var name_value: String = {"expand":"传教", "conceal":"敛藏", "hold":"守持"}[strategy]
		var control: Button = host.button(("✓ " if current == strategy else "") + name_value, func() -> void: host.set_strategy(c.id, strategy))
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL; control.disabled = not _is_action(host); controls.add_child(control)
	for e: Dictionary in host.projection.get("summary_income", {}).get("preview", {}).get("cults", []):
		if e.cult == c.id:
			box.add_child(host.label("本轮先付 %s 信仰 · 条件性收入 %s" % [e.fee, e.income_if_unchanged]))
			if not str(e.get("reason", "")).is_empty(): box.add_child(host.label("当前限制　" + host.describe(e.reason)))
	_link(host, box, "查看全部支出与供奉", "budget")
	_divider(box)
	_members(host, box, c.id, false)
	_divider(box)
	_anchors(host, box, c.domain, false)
	_link(host, box, "当地圣物", "relics", c.domain)
	_link(host, box, "当地已知材料与变化", "materials", c.domain)

func _members(host, box: VBoxContainer, id: String, heading: bool = true) -> void:
	var c: Dictionary = _current_cult(host, id)
	if c.is_empty(): box.add_child(host.label("未找到当前教团。")); return
	var members: Array = _members_for(host, c)
	_heading(host, box, ("全体具名成员" if heading else "具名成员") + " · " + str(members.size()))
	for p: Dictionary in members:
		var text_value: String = host.title(p.id) + " · " + _role(host, p) + "\n" + _state(p.get("status", "未掌握"))
		if p.has("acted_turn"): text_value += " · " + ("本轮已执行" if int(p.acted_turn) == int(host.projection.turn) else "本轮机会未用")
		_link(host, box, text_value, "person", p.id)
	if members.is_empty(): box.add_child(host.label("当前没有可列出的具名成员；不以领袖代替全员。"))
	_action(host, box, "任命领袖或护持者", "POWER_APPOINT", {"domain":c.domain, "cult":c.id})

func _search(host, box: VBoxContainer, key: String, changed: Callable) -> void:
	var search := LineEdit.new(); search.placeholder_text = "查找名称或编号"; search.text = str(queries.get(key, "")); search.custom_minimum_size.y = 36; box.add_child(search)
	search.text_submitted.connect(func(text_value: String) -> void: queries[key] = text_value; changed.call())
	box.add_child(host.button("查找", func() -> void: queries[key] = search.text; changed.call()))

func _worlds(host, box: VBoxContainer) -> void:
	_heading(host, box, "世界 · " + str(host.projection.get("domains", []).size()))
	_search(host, box, "worlds", func() -> void: host.show_subject("worlds"))
	var filter := OptionButton.new(); var filters: Array = ["全部", "有教团", "无教团", "关注中"]
	for item: String in filters: filter.add_item(item)
	filter.select(filters.find(world_filter)); filter.item_selected.connect(func(index: int) -> void: world_filter = filters[index]; host.show_subject("worlds")); box.add_child(filter)
	var count: int = 0
	for w: Dictionary in host.projection.get("domains", []):
		var name_value: String = host.title(w.id)
		if not str(queries.get("worlds", "")).is_empty() and not (name_value + w.id).contains(queries.worlds): continue
		var c: Dictionary = _current_cult(host, w.id)
		if world_filter == "有教团" and c.is_empty(): continue
		if world_filter == "无教团" and not c.is_empty(): continue
		if world_filter == "关注中" and not w.get("focused", false): continue
		var text_value: String = name_value + "\n" + ("无已知教团" if c.is_empty() else "已有教团")
		if w.get("focused", false): text_value += " · 关注中"
		if w.has("已知范围"): text_value += " · " + str(w["已知范围"])
		_link(host, box, text_value, "world", w.id); count += 1
	if count == 0: box.add_child(host.label("没有匹配的已知世界。"))
	box.add_child(host.label("只列已获得身份或请求线索的世界；查看不会改变关注资格。"))

func _world(host, box: VBoxContainer, id: String) -> void:
	var w: Dictionary = _find(host, "domains", id)
	if w.is_empty(): box.add_child(host.label("这个世界尚未进入你的知情范围。")); return
	_heading(host, box, host.title(id))
	if w.has("已知范围"):
		box.add_child(host.label(str(w["已知范围"]) + "；文明、机构和完整情报尚未查明。"))
	else:
		_pair(host, box, "文明层级", {"planet":"星球", "system":"星系", "cosmic":"宇宙"}.get(str(w.get("tier", "")), "未掌握"))
		for field: String in ["barrier", "pollution", "alert", "stability"]: _pair(host, box, {"barrier":"屏障", "pollution":"污染", "alert":"察觉", "stability":"稳定"}[field], w.get(field))
		for field: String in w.get("metric_sources", {}):
			var metric: Dictionary = w.metric_sources[field]
			if metric.has("source"): _link(host, box, "查看" + str({"barrier":"屏障", "pollution":"污染", "alert":"察觉", "stability":"稳定"}.get(field, field)) + "情报来源", "fact", str(metric.source))
	_action(host, box, "安排下轮释放关注" if w.get("focused", false) else "关注这个世界", "attention/release_focus" if w.get("focused", false) else "attention/focus", {"domain":id})
	var c: Dictionary = _current_cult(host, id)
	if not c.is_empty(): _link(host, box, "教团与全体成员", "cult", c.id)
	else: box.add_child(host.label("尚无已知教团。"))
	_link(host, box, "当地人物", "people", id)
	_link(host, box, "当地圣物", "relics", id)
	_anchors(host, box, id)
	for institution: Dictionary in host.projection.get("institutions", []):
		if institution.get("domain") == id:
			box.add_child(host.label(str(institution.get("title", "机构")) + " · " + ("已知代表：" + host.title(str(institution.representative)) if institution.get("representative") != null else "代表尚未查明")))
	for plan: Dictionary in host.projection.get("resistance", []):
		if plan.get("domain") == id:
			_heading(host, box, "已知危机与期限"); box.add_child(host.label(host.describe(plan)))
	_link(host, box, "这个世界的已知记录", "history", id)

func _relics(host, box: VBoxContainer, domain: String) -> void:
	_heading(host, box, "当前圣物" if domain.is_empty() else host.title(domain) + "的圣物")
	var count: int = 0
	for r: Dictionary in host.projection.get("relics", []):
		if r.get("placement") == "consumed" or (not domain.is_empty() and r.get("domain") != domain): continue
		_link(host, box, host.title(r.id) + " · " + str(PLACEMENTS.get(r.get("placement"), "仅有请求线索")), "relic", r.id); count += 1
	if count == 0: box.add_child(host.label("此范围内没有当前已知的圣物。已消耗的身份仍保留在编年史。"))
	_opportunities(host, box, domain)

func _relic(host, box: VBoxContainer, id: String) -> void:
	var r: Dictionary = _find(host, "relics", id)
	if r.is_empty(): box.add_child(host.label("未掌握这个物件的身份。")); return
	_heading(host, box, host.title(id))
	_pair(host, box, "状态", PLACEMENTS.get(str(r.get("placement", "")), "仅有请求线索"))
	if r.has("domain"): _link(host, box, "所在世界 · " + host.title(r.domain), "world", r.domain)
	if not str(r.get("holder", "")).is_empty(): _link(host, box, "持有者 · " + host.title(r.holder), "person", r.holder)
	if not str(r.get("anchor", "")).is_empty(): _link(host, box, "绑定的锚点", "anchor", r.anchor)
	var definition: Dictionary = host.session.catalog.tables.relics.get(str(r.get("type", "")), {})
	for field: String in ["carry_effect", "carry_cost"]:
		if definition.has(field): box.add_child(host.label(str(definition[field])))
	_divider(box)
	var actions: Array = {"controlled":["equip", "disassemble"], "ground":["recover"], "carried":["unequip", "disassemble"], "bound":["unbind"], "seized":["recover"], "sealed":["recover"]}.get(str(r.get("placement", "")), [])
	for action: String in actions:
		_action(host, box, {"equip":"选择携带者", "unequip":"卸下", "unbind":"解绑并查看锚点后果", "recover":"查看当前回收条件", "disassemble":"解离并选择用途"}[action], "relic/" + action, {"domain":str(r.get("domain", "")), "relic":id})
	if actions.is_empty(): box.add_child(host.label("当前不可直接处置；仍可查看其已知经历。"))
	_link(host, box, "物件的已知经历", "history", id)

func _anchors(host, box: VBoxContainer, domain: String, heading: bool = true) -> void:
	if heading: _heading(host, box, "锚点与持续护持")
	var count: int = 0
	for a: Dictionary in host.projection.get("anchors", []):
		if not domain.is_empty() and a.get("domain") != domain: continue
		_link(host, box, host.title(a.id) + " · " + ("有效" if a.get("state") == "active" else "休眠"), "anchor", a.id); count += 1
	if count == 0: box.add_child(host.label("此范围内尚无已知锚点。"))

func _anchor(host, box: VBoxContainer, id: String) -> void:
	var a: Dictionary = _find(host, "anchors", id)
	if a.is_empty(): box.add_child(host.label("没有这个已知锚点。")); return
	_heading(host, box, host.title(id))
	_pair(host, box, "状态", "有效" if a.get("state") == "active" else "休眠")
	_link(host, box, "所在世界", "world", str(a.get("domain", "")))
	_link(host, box, "护持者 · " + host.title(str(a.get("guardian", ""))), "person", str(a.get("guardian", "")))
	if not str(a.get("relic", "")).is_empty(): _link(host, box, "绑定媒介 · " + host.title(a.relic), "relic", a.relic)
	_link(host, box, "本轮供奉与优先顺序", "budget")
	_action(host, box, "查看当前锚定 / 修复条件", "POWER_ANCHOR", {"domain":str(a.get("domain", "")), "institution":str(a.get("institution", "")), "npc":str(a.get("guardian", "")), "relic":str(a.get("relic", ""))})
	_action(host, box, "任命护持者", "POWER_APPOINT", {"domain":str(a.get("domain", "")), "anchor":id})
	_link(host, box, "已知材料与实践", "materials", str(a.get("domain", "")))

func _opportunities(host, box: VBoxContainer, domain: String) -> void:
	var all: Array = host.session.action_catalog()
	var shown: bool = false
	for row: Dictionary in all:
		if not str(row.key).begins_with("opportunity/"): continue
		var source: String = str(row.key).split("/")[1]
		var fact: Dictionary = _known_fact(host, source)
		if not domain.is_empty() and fact.get("domain") != domain: continue
		if not shown: _heading(host, box, "已出现的媒介机会"); shown = true
		_action(host, box, str(row.title) + " · " + host.title(str(fact.get("domain", ""))), row.key)

func _plan(host) -> Dictionary:
	var plan: Dictionary = host.projection.get("economy_plan", {}).duplicate(true)
	if not plan.has("strategies"): plan["strategies"] = {}
	if not plan.has("anchor_priority"): plan["anchor_priority"] = []
	if not plan.has("refuse_anchors"): plan["refuse_anchors"] = []
	for a: Dictionary in host.projection.get("anchors", []):
		if not a.id in plan.anchor_priority: plan.anchor_priority.append(a.id)
	return plan

func _budget(host, box: VBoxContainer) -> void:
	_heading(host, box, "当前余额下的支出与供奉")
	box.add_child(host.label("先支付传教与锚点供奉，世界演化后才收到本轮收入。未来收入不能支付眼前费用。"))
	var result: Dictionary = host.session.economy_preview()
	if not result.get("ok", false):
		box.add_child(host.label("当前已离开可调整计划的阶段。下面保留各教团指令；实际支付及变化在编年史中回顾。"))
		for c: Dictionary in host.projection.get("cults", []):
			var strategy: String = str(host.projection.get("economy_plan", {}).get("strategies", {}).get(c.id, c.get("strategy", "hold")))
			_link(host, box, _cult_name(host, c) + " · " + str({"expand":"传教", "conceal":"敛藏", "hold":"守持"}.get(strategy, strategy)), "cult", c.id)
		_anchors(host, box, "")
		_link(host, box, "查看实际结算记录", "history")
		return
	var preview: Dictionary = result.get("preview", {})
	box.add_child(host.label("现有信仰 %s → 当前安排预付后 %s" % [preview.get("faith_before", "?"), preview.get("faith_after_prepay", "?")]))
	if not host.draft.is_empty(): box.add_child(host.label("右侧保留正在准备的行动；其付款后的供奉变化在右侧单独比较。这里显示已提交的当前安排。"))
	for c: Dictionary in preview.get("cults", []):
		if _find(host, "cults", str(c.cult)).is_empty(): continue
		_link(host, box, host.title(c.cult) + " · 先付%s / 条件性收入%s" % [c.fee, c.income_if_unchanged], "cult", c.cult)
		if not str(c.get("reason", "")).is_empty(): box.add_child(host.label(host.describe(c.reason)))
	var plan: Dictionary = _plan(host)
	for i: int in range(plan.anchor_priority.size()):
		var anchor_id: String = str(plan.anchor_priority[i])
		if _find(host, "anchors", anchor_id).is_empty(): continue
		var a: Dictionary = {}
		for row: Dictionary in preview.get("anchors", []):
			if row.anchor == anchor_id: a = row; break
		_divider(box)
		_link(host, box, str(i + 1) + ". " + host.title(anchor_id), "anchor", anchor_id)
		box.add_child(host.label("本次预付 %s · %s" % [a.get("fee", 0), "可付，轮末仍需重验" if str(a.get("reason", "")).is_empty() else host.describe(a.reason)]))
		var controls := HBoxContainer.new(); box.add_child(controls)
		var up: Button = host.button("上移", func() -> void: _move_anchor(host, anchor_id, -1)); up.disabled = not _is_action(host) or i == 0; controls.add_child(up)
		var down: Button = host.button("下移", func() -> void: _move_anchor(host, anchor_id, 1)); down.disabled = not _is_action(host) or i == plan.anchor_priority.size() - 1; controls.add_child(down)
		var refused: bool = anchor_id in plan.refuse_anchors
		var refusal: Button = host.button("恢复供奉" if refused else "本轮停供", func() -> void:
			var updated: Dictionary = _plan(host)
			if anchor_id in updated.refuse_anchors: updated.refuse_anchors.erase(anchor_id)
			else: updated.refuse_anchors.append(anchor_id)
			host.save_plan(updated))
		refusal.disabled = not _is_action(host); controls.add_child(refusal)
	if preview.get("cults", []).is_empty() and preview.get("anchors", []).is_empty(): box.add_child(host.label("当前没有教团支出或锚点供奉。"))

func _move_anchor(host, id: String, delta: int) -> void:
	var plan: Dictionary = _plan(host); var i: int = plan.anchor_priority.find(id); var j: int = i + delta
	if i < 0 or j < 0 or j >= plan.anchor_priority.size(): return
	var other: Variant = plan.anchor_priority[j]; plan.anchor_priority[j] = id; plan.anchor_priority[i] = other; host.save_plan(plan)

func _attention(host, box: VBoxContainer, id: String) -> void:
	_heading(host, box, "关注与成员名额")
	var values: Dictionary = host.projection.get("attention", {})
	var limits: Dictionary = values.get("limits", {})
	for key: String in ["focus", "members", "people"]:
		_pair(host, box, {"focus":"关注世界", "members":"正式成员", "people":"临时人物"}[key], str(values.get(key, 0)) + " / " + str(limits.get(key, "?")))
	for w: Dictionary in host.projection.get("domains", []):
		if w.get("focused", false):
			_link(host, box, host.title(w.id), "world", w.id)
			_action(host, box, "安排下轮释放", "attention/release_focus", {"domain":w.id})
	if not id.is_empty(): _action(host, box, "查看关注条件", "attention/focus", {"domain":id})
	else: _action(host, box, "选择需要关注的世界", "attention/focus")
	_action(host, box, "查看并释放未用活动预留", "attention/release_project")
	_link(host, box, "全部人物与职责", "people")
	box.add_child(host.label("查看对象不占关注；安排释放不会提前腾出本轮名额。进行中的事情仍需按其真实条件处理。"))

func _known_fact(host, id: String) -> Dictionary:
	var ids: Array = host.session.known_sources()
	var index: int = ids.find(id)
	if index < 0: return {}
	var page: Dictionary = host.session.history_page(index, 1)
	return page.get("facts", [])[0] if not page.get("facts", []).is_empty() else {}

func _history(host, box: VBoxContainer, filter_id: String) -> void:
	_heading(host, box, "编年史" if filter_id.is_empty() else host.title(filter_id) + " · 已知经历")
	var ids: Array = host.session.known_sources()
	var offset: int = int(history_offsets.get(filter_id, 0))
	var stop: int = maxi(0, ids.size() - offset)
	var start: int = maxi(0, stop - 50)
	var page: Dictionary = host.session.history_page(start, maxi(1, stop - start))
	var facts: Array = page.get("facts", []).duplicate(); facts.reverse()
	var count: int = 0
	for fact: Dictionary in facts:
		if not filter_id.is_empty() and not JSON.stringify(fact).contains(filter_id): continue
		_link(host, box, "第%s轮 · %s\n%s" % [fact.get("turn", "?"), host.describe(fact.get("kind", "记录")), _fact_summary(host, fact)], "fact", fact.id); count += 1
	if count == 0: box.add_child(host.label("这段记录中没有匹配的已知经历。"))
	if start > 0: box.add_child(host.button("更早的记录", func() -> void: history_offsets[filter_id] = offset + 50; host.show_subject("history", filter_id)))
	if offset > 0: box.add_child(host.button("返回最新记录", func() -> void: history_offsets[filter_id] = 0; host.show_subject("history", filter_id)))
	if not filter_id.is_empty(): _link(host, box, "查看全部编年史", "history")

func _fact_summary(host, fact: Dictionary) -> String:
	var items: PackedStringArray = []
	var actor: String = str(fact.get("actor", ""))
	if not actor.is_empty(): items.append(host.title(actor))
	for target: Variant in fact.get("targets", []):
		if target is String and items.size() < 3: items.append(host.title(target))
	if items.is_empty(): items.append(host.title(str(fact.get("domain", ""))))
	return " · ".join(items)

func _fact(host, box: VBoxContainer, id: String) -> void:
	var fact: Dictionary = _known_fact(host, id)
	if fact.is_empty(): box.add_child(host.label("这项前因尚未获知。")); return
	_heading(host, box, "第%s轮 · %s" % [fact.get("turn", "?"), host.describe(fact.get("kind", "记录"))])
	box.add_child(host.label(_fact_summary(host, fact)))
	_pair(host, box, "实际变化", fact.get("changes", {}))
	for target: Variant in [fact.get("actor", "")] + fact.get("targets", []):
		if not target is String or str(target).is_empty(): continue
		for pair: Array in [["people", "person"], ["relics", "relic"], ["domains", "world"], ["cults", "cult"], ["anchors", "anchor"]]:
			if not _find(host, pair[0], target).is_empty(): _link(host, box, "查看 " + host.title(target), pair[1], target)
	_heading(host, box, "已知前因")
	for parent: String in fact.get("causal_parents", []):
		if parent == "尚未知晓": box.add_child(host.label("尚未获知的前因"))
		else: _link(host, box, host.title(parent), "fact", parent)

func _materials(host, box: VBoxContainer, domain: String) -> void:
	_heading(host, box, "已知材料与实践")
	box.add_child(host.label("活动使用真实记录、原参与者及跨轮进展。选择当地人物，可以在右侧查看其当前可推进的事情和所缺材料。"))
	for p: Dictionary in host.projection.get("people", []):
		if (domain.is_empty() or p.get("domain") == domain) and p.get("bound_member", false):
			_link(host, box, host.title(p.id), "person", p.id)
	_opportunities(host, box, domain)
	_link(host, box, "此处已知记录与来源", "history", domain)

func _self(host, box: VBoxContainer) -> void:
	_heading(host, box, "本体与苏醒")
	_pair(host, box, "当前苏醒", host.projection.get("awakening"))
	for value: Dictionary in host.projection.get("awakening_sources", []):
		box.add_child(host.label(str(value.get("title", "来源")) + "　" + str(value.get("value", 0))))
	_pair(host, box, "创伤", host.projection.get("wounds"))
	var rest: Button = host.button("查看敛息与恢复代价", func() -> void: host.request_rest()); rest.disabled = not _is_action(host); box.add_child(rest)
	_divider(box)
	var manifest: Dictionary = host.projection.get("manifest", {})
	if manifest.is_empty():
		box.add_child(host.label("尚未开始降临。"))
		_action(host, box, "查看降临条件", "POWER_MANIFEST")
	else:
		_heading(host, box, "降临进行中")
		box.add_child(host.label("已付 %s / %s 轮 · 最近实付第%s轮" % [manifest.get("progress", 0), host.session.catalog.integer("manifest_duration"), manifest.get("paid_turn", "?")]))
		if manifest.has("npc"): _link(host, box, "原仪式主体 · " + host.title(manifest.npc), "person", manifest.npc)
		for key: String in ["cosmic_anchor", "system_anchor"]:
			if manifest.has(key): _link(host, box, host.title(manifest[key]), "anchor", manifest[key])
		_action(host, box, "继续本轮降临", "POWER_MANIFEST_CONTINUE")
		_action(host, box, "中止降临", "POWER_MANIFEST_CANCEL")

func _ending(host, box: VBoxContainer) -> void:
	_heading(host, box, "本局已封存")
	box.add_child(host.label(host.describe(host.projection.get("outcome", {}))))
	_pair(host, box, "最终回合", host.projection.get("turn"))
	_pair(host, box, "最终苏醒", host.projection.get("awakening"))
	_link(host, box, "回顾本局编年史", "history")
	_link(host, box, "查看已知世界", "worlds")
	_link(host, box, "查看人物", "people")
	box.add_child(host.label("本局只读。可从菜单开启新局或载入其他保存。"))
