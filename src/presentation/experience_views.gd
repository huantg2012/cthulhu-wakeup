extends RefCounted
## Subject-side presentation of the existing player's knowledge projection.
## All mutations go through the host's Session methods; no rule state is created here.

const ActionCatalog = preload("res://src/presentation/action_catalog.gd")
const PLACEMENTS: Dictionary = {"controlled":"当地保管", "ground":"遗落", "carried":"携带", "bound":"绑定", "seized":"扣押", "sealed":"封存", "consumed":"已消耗"}
const STATES: Dictionary = {"active":"在场", "dead":"死亡", "missing":"失踪", "detained":"被拘禁", "imprisoned":"被拘禁", "dormant":"休眠", "destroyed":"已毁", "departed":"已离开"}
const WORLD_METRICS: Dictionary = {"barrier":"屏障", "pollution":"污染", "alert":"察觉", "stability":"稳定"}
const WORLD_METRIC_MEANINGS: Dictionary = {
	"barrier":"现实排斥异质影响的能力；较低通常有利于干预。",
	"pollution":"异质影响的覆盖程度；不等于世界归属或教团凝聚。",
	"alert":"文明识别威胁的程度；不等于反制已经发动。",
	"stability":"制度维持一致行动的能力；降低也可能损害信徒组织与供奉。",
}
var queries: Dictionary = {}
var world_filter: String = "全部"
var person_filters: Dictionary = {}
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

func _find(host, collection: String, id: String) -> Dictionary:
	for value: Dictionary in host.projection.get(collection, []):
		if str(value.get("id", "")) == id: return value
	return {}

func subject_domain(host, kind: String, id: String) -> String:
	# Resolve identities only through the player's projection, including request-only clues.
	if id.is_empty(): return ""
	if kind in ["world", "people", "relics", "anchors", "materials", "attention", "history"] and not _find(host, "domains", id).is_empty():
		return id
	if kind == "history":
		for collection: String in ["people", "cults", "relics", "anchors", "institutions"]:
			var known: Dictionary = _find(host, collection, id)
			if not known.is_empty(): return str(known.get("domain", ""))
		return ""
	if kind in ["cult", "members"]:
		return str(_current_cult(host, id).get("domain", ""))
	if kind == "prayer":
		var prayer: Dictionary = _find(host, "prayers", id)
		return str(prayer.get("descriptor", {}).get("domain", prayer.get("card", {}).get("domain", "")))
	var collection: String = str({"person":"people", "relic":"relics", "anchor":"anchors", "institution":"institutions"}.get(kind, ""))
	return str(_find(host, collection, id).get("domain", "")) if not collection.is_empty() else ""

func metric_display(world: Dictionary, field: String) -> Dictionary:
	var metric: Dictionary = world.get("metric_sources", {}).get(field, {})
	var precision: String = str(metric.get("precision", "exact" if metric.has("value") else ""))
	var value := "未掌握"
	var observation := ""
	if precision == "range" and metric.get("lower") is int and metric.get("upper") is int:
		value = "%d–%d" % [metric.lower, metric.upper]
		observation = "估计"
	elif precision == "exact" and metric.get("value") is int:
		value = str(metric.value)
		observation = "确知"
	var source := "未有记录"
	if not observation.is_empty():
		source = "第%d轮%s" % [int(metric.turn), observation] if metric.get("turn") is int else observation + "时间未掌握"
	return {"value":value, "source":source, "known":not observation.is_empty()}

func metric_text(world: Dictionary, field: String) -> String:
	var display := metric_display(world, field)
	return display.value + ("（" + display.source + "）" if display.known else "")

func world_metrics_text(host, domain: String, two_rows: bool = false) -> String:
	var world: Dictionary = _find(host, "domains", domain)
	var parts: PackedStringArray = []
	for field: String in WORLD_METRICS:
		parts.append(str(WORLD_METRICS[field]) + " " + metric_text(world, field))
	if two_rows: return " · ".join(parts.slice(0, 2)) + "\n" + " · ".join(parts.slice(2, 4))
	return " · ".join(parts)

func world_plans(host, domain: String) -> Array:
	var plans: Array = host.projection.get("resistance", []).filter(func(plan: Dictionary) -> bool: return str(plan.get("domain", "")) == domain)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("due", 0)) < int(b.get("due", 0)))
	return plans

func world_resistance_text(host, domain: String) -> String:
	var plans: Array = world_plans(host, domain)
	if plans.is_empty(): return "反制：暂无已知计划"
	return "反制：" + host.crisis_summary(plans[0]) + ("；另 %d 项" % (plans.size() - 1) if plans.size() > 1 else "")

func render_world_context(host, box: VBoxContainer, domain: String, allow_link: bool = true) -> void:
	if _find(host, "domains", domain).is_empty(): return
	var title: String = "世界态势 · " + host.title(domain)
	if allow_link:
		var control: Button = host.button(title + " ›", func() -> void: host.show_subject("world", domain))
		control.name = "WorldContextLink"
		box.add_child(control)
	else: box.add_child(host.label(title))
	var metrics: Label = host.label(world_metrics_text(host, domain, true))
	metrics.name = "WorldMetricSummary"
	metrics.tooltip_text = "这些是标注回合最后获知的状态，不是实时读数。区间只表示估计精度，不表示危险等级；四项不能合并为占领进度。"
	box.add_child(metrics)
	var resistance: Label = host.label(world_resistance_text(host, domain))
	resistance.name = "WorldResistanceSummary"
	box.add_child(resistance)

func _world_overview(host, box: VBoxContainer) -> void:
	var worlds: Array = host.projection.get("domains", []).duplicate()
	if worlds.is_empty(): return
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_plans: Array = world_plans(host, str(a.id))
		var b_plans: Array = world_plans(host, str(b.id))
		var a_due: int = int(a_plans[0].get("due", 0)) if not a_plans.is_empty() else 2147483647
		var b_due: int = int(b_plans[0].get("due", 0)) if not b_plans.is_empty() else 2147483647
		if a_due != b_due: return a_due < b_due
		if bool(a.get("focused", false)) != bool(b.get("focused", false)): return bool(a.get("focused", false))
		return str(a.id) < str(b.id))
	_heading(host, box, "世界态势")
	for world: Dictionary in worlds.slice(0, 3):
		var control: Button = host.button(host.title(str(world.id)) + "\n" + world_metrics_text(host, str(world.id)) + "\n" + world_resistance_text(host, str(world.id)), func() -> void: host.show_subject("world", str(world.id)))
		control.name = "WorldOverview_" + str(world.id)
		box.add_child(control)
	if worlds.size() > 3: box.add_child(host.label("当前列出 %d / %d 个世界；其余可从顶部世界名单查找。" % [mini(3, worlds.size()), worlds.size()]))

func render_comparison(host, box: VBoxContainer, entries: Array) -> void:
	# Compare a small, current projection; never render full subject pages or rules.
	var columns := HBoxContainer.new(); box.add_child(columns)
	for index: int in range(mini(2, entries.size())):
		var entry: Dictionary = entries[index]
		var column := VBoxContainer.new(); column.name = "ComparisonSlot_" + str(index); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; columns.add_child(column)
		var id: String = str(entry.get("id", ""))
		var kind: String = str(entry.get("kind", ""))
		var collection: String = str({"world":"domains", "person":"people", "cult":"cults", "relic":"relics", "anchor":"anchors", "institution":"institutions"}.get(kind, ""))
		var subject: Dictionary = _find(host, collection, id)
		_heading(host, column, host.title(id))
		if subject.is_empty():
			column.add_child(host.label("目前没有可对照的已知资料。")); continue
		if subject.has("已知范围"): column.add_child(host.label(str(subject["已知范围"])))
		if subject.has("domain"): _pair(host, column, "世界", host.title(str(subject.domain)))
		match kind:
			"person":
				_pair(host, column, "职责", _role(host, subject))
				_pair(host, column, "处境", _state(subject.get("status", "未掌握")))
				column.add_child(host.label(_execution_status(host, subject)))
				if subject.get("bound_member", false):
					column.add_child(host.label("意志 %s · 洞察 %s\n影响 %s · 适应 %s\n忠诚 %s · 理智 %s" % [subject.get("will", "未掌握"), subject.get("insight", "未掌握"), subject.get("influence", "未掌握"), subject.get("adaptation", "未掌握"), subject.get("loyalty", "未掌握"), subject.get("sanity", "未掌握")]))
			"cult":
				_pair(host, column, "状态", {"active":"运作中", "dormant":"休眠", "destroyed":"已毁"}.get(str(subject.get("status", "")), "未掌握"))
				_pair(host, column, "无名信众", subject.get("followers", subject.get("unnamed_followers")))
				_pair(host, column, "凝聚", subject.get("cohesion"))
				_pair(host, column, "具名成员", _members_for(host, subject).size())
				_pair(host, column, "当前指令", _strategy_name(str(host.projection.get("economy_plan", {}).get("strategies", {}).get(id, subject.get("strategy", "hold")))))
				var forecast: Dictionary = _cult_forecast(host.projection.get("summary_income", {}).get("preview", {}), id)
				if not forecast.is_empty(): column.add_child(host.label("本轮支出 %s · 预计收入 %s" % [forecast.get("fee", 0), forecast.get("income_if_unchanged", 0)]))
			"world":
				_pair(host, column, "层级", subject.get("tier"))
				for field: String in WORLD_METRICS: _pair(host, column, str(WORLD_METRICS[field]), metric_text(subject, field))
				_pair(host, column, "关注", "关注中" if subject.get("focused", false) else ("未关注" if subject.has("focused") else "未掌握"))
				var cult: Dictionary = _current_cult(host, id)
				_pair(host, column, "教团", _cult_name(host, cult) if not cult.is_empty() else "尚无已知教团")
			"relic":
				_pair(host, column, "状态", PLACEMENTS.get(str(subject.get("placement", "")), "未掌握"))
				if not str(subject.get("holder", "")).is_empty(): _pair(host, column, "持有者", host.title(str(subject.holder)))
				if not str(subject.get("anchor", "")).is_empty(): _pair(host, column, "绑定锚点", host.title(str(subject.anchor)))
			"anchor":
				_pair(host, column, "状态", "有效" if subject.get("state") == "active" else _state(subject.get("state", "未掌握")))
				if subject.has("guardian"): _pair(host, column, "护持者", host.title(str(subject.guardian)))
				if not str(subject.get("relic", "")).is_empty(): _pair(host, column, "绑定媒介", host.title(str(subject.relic)))
				_pair(host, column, "当前苏醒贡献", _anchor_contributions(host).get(id, 0))
			"institution":
				_pair(host, column, "状态", "运作中" if subject.get("active", false) else ("停止运作" if subject.has("active") else "未掌握"))
				_pair(host, column, "代表", host.title(str(subject.representative)) if subject.get("representative") != null else null)
	if entries.is_empty(): box.add_child(host.label("先在对象页留下一至两个对象。"))

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
	_heading(host, box, "总览")
	_world_overview(host, box)
	if not host._responded():
		_prayers(host, box, false)
	else:
		box.add_child(host.label("本轮已回应一次。其余请求可从上方祈求入口查看；仍可使用权能和安排教团。"))
	_divider(box)
	var cults: Array = host.projection.get("cults", [])
	if cults.is_empty():
		_heading(host, box, "已经与你建立联系的人")
		for p: Dictionary in host.projection.get("people", []):
			_link(host, box, host.title(p.id) + " · " + _role(host, p), "person", p.id)
		box.add_child(host.label("尚无教团。人物的献身、活动与实际形成条件，从人物处查看。"))
	else:
		_heading(host, box, "教团近况")
		box.add_child(host.label("%d 个已知教团，具名成员 %d 人。选择左侧教团可查看全员与本轮指令。" % [cults.size(), host.projection.people.filter(func(p: Dictionary) -> bool: return p.get("bound_member", false)).size()]))
		box.add_child(host.label(budget_summary(host)))

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
		if key not in ["当前诉求", "求告方向"]: _pair(host, box, key.replace("时空", "世界"), details[key])
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
	elif _is_action(host):
		box.add_child(host.label("在右侧选择回应方式。查看资料不会消耗本轮回应机会。"))
	else:
		box.add_child(host.label("先处理轮初事件，随后可以回应。"))

func _people(host, box: VBoxContainer, domain: String) -> void:
	_heading(host, box, "已知人物" if domain.is_empty() else host.title(domain) + "的人物")
	var people: Array = []
	for p: Dictionary in host.projection.get("people", []):
		if not domain.is_empty() and p.get("domain") != domain: continue
		people.append(p)
	_person_list(host, box, people, "people/" + domain, func() -> void: host.show_subject("people", domain))

func _person(host, box: VBoxContainer, id: String) -> void:
	var p: Dictionary = _find(host, "people", id)
	if p.is_empty():
		box.add_child(host.label("尚未取得这个人物的身份资料。")); return
	_heading(host, box, host.title(id))
	_pair(host, box, "职责", _role(host, p))
	_pair(host, box, "处境", _state(p.get("status", "仅有请求线索")))
	if p.get("bound_member", false):
		box.add_child(host.label("意志 %s · 洞察 %s · 影响 %s · 适应 %s" % [p.get("will", "?"), p.get("insight", "?"), p.get("influence", "?"), p.get("adaptation", "?")]))
		box.add_child(host.label("忠诚 %s · 理智 %s" % [p.get("loyalty", "?"), p.get("sanity", "?")]))
		box.add_child(host.label(_execution_status(host, p)))
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
	box.add_child(host.label("每项活动使用自己的原参加者、材料和跨轮进展；行动准备会列出当前可选对象及尚缺条件。"))

func _cult(host, box: VBoxContainer, id: String) -> void:
	var c: Dictionary = _current_cult(host, id)
	if c.is_empty():
		box.add_child(host.label("这里尚未形成已知教团。")); _link(host, box, "查看当地人物", "people", id); return
	_heading(host, box, _cult_name(host, c))
	_pair(host, box, "状态", {"active":"运作中", "dormant":"休眠", "destroyed":"已毁"}.get(str(c.get("status", "")), c.get("status")))
	_pair(host, box, "无名信众", c.get("followers", c.get("unnamed_followers")))
	_pair(host, box, "凝聚", c.get("cohesion"))
	_heading(host, box, "本轮指令")
	var plan: Dictionary = _plan(host)
	var current: String = str(plan.get("strategies", {}).get(c.id, c.get("strategy", "hold")))
	box.add_child(host.label("当前 · " + _strategy_name(current) + "。结束回合时执行；预计收入不能支付本轮费用。"))
	var current_preview: Dictionary = host.session.preview_plan(plan).get("preview", {})
	var supply: String = _supply_summary(host, current_preview)
	if not supply.is_empty(): box.add_child(host.label(supply))
	for strategy: String in ["expand", "conceal", "hold"]:
		var alternative: Dictionary = plan.duplicate(true); alternative.strategies[c.id] = strategy
		var preview: Dictionary = current_preview if strategy == current else host.session.preview_plan(alternative).get("preview", {})
		var control: Button = host.button(("✓ " if current == strategy else "") + _strategy_name(strategy), func() -> void: host.set_strategy(c.id, strategy))
		control.name = "CultStrategy_" + strategy; control.disabled = not _is_action(host); box.add_child(control)
		box.add_child(host.label(_strategy_summary(host, _cult_forecast(preview, str(c.id)))))
		if strategy != current:
			var changed_supply: String = _supply_summary(host, preview)
			if not changed_supply.is_empty() and changed_supply != supply: box.add_child(host.label("改选后 · " + changed_supply))
	box.add_child(host.label("以上按当前局势预计，人物与世界变化仍可能影响结算。"))
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
	_heading(host, box, "全体具名成员" if heading else "具名成员")
	_person_list(host, box, members, "members/" + str(c.id), func() -> void: host.show_subject("members" if heading else "cult", str(c.id)))
	_action(host, box, "任命领袖或护持者", "POWER_APPOINT", {"domain":c.domain, "cult":c.id})

func _execution_status(host, person: Dictionary) -> String:
	if not person.get("acted_turn") is int: return "执行机会未掌握"
	return "本轮机会已用" if int(person.acted_turn) == int(host.projection.turn) else "本轮机会未用"

func _person_matches(host, person: Dictionary, query: String, unused_only: bool) -> bool:
	if unused_only and (not person.get("acted_turn") is int or int(person.acted_turn) == int(host.projection.turn)): return false
	return query.is_empty() or (host.title(str(person.id)) + " " + str(person.id)).to_lower().contains(query.to_lower())

func _person_list(host, box: VBoxContainer, people: Array, key: String, changed: Callable) -> void:
	_search(host, box, key, changed)
	var filter := OptionButton.new()
	filter.name = "PersonFilter_" + key.replace("/", "_")
	filter.add_item("全部"); filter.add_item("本轮机会未用")
	var unused_only: bool = bool(person_filters.get(key, false))
	filter.select(1 if unused_only else 0)
	filter.item_selected.connect(func(index: int) -> void: person_filters[key] = index == 1; changed.call())
	box.add_child(filter)
	var matched: Array = []
	for person: Dictionary in people:
		if _person_matches(host, person, str(queries.get(key, "")).strip_edges(), unused_only): matched.append(person)
	box.add_child(host.label("全部 %d 人 · 匹配 %d 人" % [people.size(), matched.size()]))
	for person: Dictionary in matched:
		_link(host, box, host.title(person.id) + " · " + _role(host, person) + "\n" + _state(person.get("status", "仅有请求线索")) + " · " + _execution_status(host, person), "person", person.id)
	if people.is_empty(): box.add_child(host.label("此范围内尚无已知人物。"))
	elif matched.is_empty(): box.add_child(host.label("没有符合查找与筛选条件的人物。"))

func _strategy_name(strategy: String) -> String:
	return str({"expand":"传教", "conceal":"敛藏", "hold":"守持"}.get(strategy, strategy))

func _cult_forecast(preview: Dictionary, cult_id: String) -> Dictionary:
	for entry: Dictionary in preview.get("cults", []):
		if entry.get("cult") == cult_id: return entry
	return {}

func _strategy_summary(host, entry: Dictionary, income_separator := " · ") -> String:
	if entry.is_empty(): return "当前阶段不能调整指令；实际结算请查看编年史。"
	var reason: String = str(entry.get("reason", ""))
	var text_value: String = ""
	if not reason.is_empty(): text_value = "不能按所选指令执行：" + _economy_reason(host, reason) + "。\n"
	var alert: String = "指令不改变察觉"
	if entry.get("effective") == "expand" and int(entry.get("growth", 0)) > 0: alert = "增加察觉"
	elif entry.get("effective") == "conceal": alert = "降低察觉"
	return text_value + "支出 %s 信仰 · 信众 +%s / 流失 %s · %s%s预计收入 %s" % [entry.get("fee", 0), entry.get("growth", 0), entry.get("attrition", 0), alert, income_separator, entry.get("income_if_unchanged", 0)]

func _economy_reason(host, reason: String) -> String:
	var meanings: Dictionary = {
		"insufficient_faith":"信仰不足", "explicit_refusal":"本轮已停供", "no_recruitable_population":"没有可招募的无名人口",
		"attention_focus_capacity":"关注世界的名额已满", "cult_dormant":"教团正在休眠", "cult_destroyed":"教团已经瓦解",
		"no_organization_base":"教团缺少信众或凝聚", "no_leader":"教团没有领袖", "leader_unavailable":"领袖当前无法主持教团",
		"prayer_propagation_restricted":"传教受到尚未解除的限制", "propagation_evidence_destroyed":"原传播依据已经失效",
		"propagation_object_unavailable":"原传播联系当前不可用", "upstream_denied":"当前依托不允许执行", "event_permit_no_longer_current":"原许可已经失效",
		"structure_unavailable":"锚点已毁或需要重新绑定", "missing_structure_metadata":"锚点缺少有效的建立记录",
		"organization_unavailable":"教团当前无法维持锚点", "pollution_below_threshold":"当地污染不足以维持锚点",
		"binding_unavailable":"护持者、圣物或机构的绑定已失效", "guardian_or_institution_unavailable":"护持者或当地机构当前不可用",
		"missing_current_anchor_basis":"缺少当前有效的锚定依据", "current_basis_material_bundle_changed":"锚定依托的材料已经变化",
		"missing_current_bound_route":"原锚定依托已失效",
	}
	return str(meanings[reason]) if meanings.has(reason) else host.session.explain_error(reason)

func _anchor_contributions(host) -> Dictionary:
	var values: Dictionary = {}
	for source: Dictionary in host.projection.get("awakening_sources", []):
		if source.get("kind") == "anchor" and not _find(host, "anchors", str(source.get("title", ""))).is_empty(): values[str(source.title)] = int(source.get("value", 0))
	return values

func _supply_summary(host, preview: Dictionary) -> String:
	if preview.is_empty() or host.projection.get("anchors", []).is_empty(): return ""
	var warnings: PackedStringArray = []
	var lost: int = 0
	var affected: int = 0
	var contributions: Dictionary = _anchor_contributions(host)
	for entry: Dictionary in preview.get("anchors", []):
		var id: String = str(entry.get("anchor", ""))
		if _find(host, "anchors", id).is_empty() or str(entry.get("reason", "")).is_empty(): continue
		affected += 1
		if warnings.size() < 3: warnings.append(host.title(id) + "：" + _economy_reason(host, str(entry.reason)))
		lost += int(contributions.get(id, 0))
	if warnings.is_empty(): return "按当前余额，可支付已知锚点的供奉；有效性仍在结算时复核。"
	var text_value: String = "锚点供奉 · " + "；".join(warnings)
	if affected > warnings.size(): text_value += "；另 %d 处，详见本轮收支" % (affected - warnings.size())
	if lost > 0: text_value += "。若保持当前计划，现有苏醒贡献预计减少 %d。" % lost
	else: text_value += "；这些锚点目前没有提供苏醒贡献。"
	return text_value

func _search(host, box: VBoxContainer, key: String, changed: Callable) -> void:
	var search := LineEdit.new(); search.placeholder_text = "查找名称或编号"; search.text = str(queries.get(key, "")); search.custom_minimum_size.y = 36; box.add_child(search)
	search.name = "SubjectSearch_" + key.replace("/", "_")
	search.text_submitted.connect(func(text_value: String) -> void: queries[key] = text_value; changed.call())
	box.add_child(host.button("查找", func() -> void: queries[key] = search.text; changed.call()))

func _worlds(host, box: VBoxContainer) -> void:
	_heading(host, box, "世界 · " + str(host.projection.get("domains", []).size()))
	_search(host, box, "worlds", func() -> void: host.show_subject("worlds"))
	var filter := OptionButton.new(); var filters: Array = ["全部", "有教团", "无教团", "关注中", "有反制"]
	filter.name = "SubjectFilter_worlds"
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
		if world_filter == "有反制" and world_plans(host, str(w.id)).is_empty(): continue
		var text_value: String = name_value + "\n" + ("无已知教团" if c.is_empty() else "已有教团")
		if w.get("focused", false): text_value += " · 关注中"
		if w.has("已知范围"): text_value += " · " + str(w["已知范围"])
		text_value += "\n" + world_metrics_text(host, str(w.id)) + "\n" + world_resistance_text(host, str(w.id))
		_link(host, box, text_value, "world", w.id); count += 1
	if count == 0: box.add_child(host.label("没有匹配的已知世界。"))
	box.add_child(host.label("匹配 %d / %d 个已知世界" % [count, host.projection.get("domains", []).size()]))
	box.add_child(host.label("只列已获得身份或请求线索的世界；查看不会改变关注资格。"))

func _world(host, box: VBoxContainer, id: String) -> void:
	var w: Dictionary = _find(host, "domains", id)
	if w.is_empty(): box.add_child(host.label("这个世界尚未进入你的知情范围。")); return
	_heading(host, box, "世界情报与反制 · " + host.title(id))
	box.add_child(host.label("以下为标注回合最后获知的状态，不保证仍等于当前值。估计区间表示精度，不是危险等级；察觉与已发动的反制分别判断。"))
	if w.has("已知范围"):
		box.add_child(host.label(str(w["已知范围"]) + "；文明、机构和完整情报尚未查明。"))
	else:
		_pair(host, box, "文明层级", {"planet":"星球", "system":"星系", "cosmic":"宇宙"}.get(str(w.get("tier", "")), "未掌握"))
	var plans: Array = world_plans(host, id)
	if not plans.is_empty():
		_heading(host, box, "已发动的反制")
		for plan: Dictionary in plans:
			box.add_child(host.label(host.crisis_summary(plan)))
			var rule: Dictionary = host.session.catalog.tables.resistance_plans.get(str(plan.get("rule", "")), {})
			box.add_child(host.label("若未阻止：" + str(rule.get("result", "后果尚未掌握"))))
		box.add_child(host.label("察觉降低不会自动撤销已经发动的计划。"))
	var sources: Dictionary = {}
	for field: String in WORLD_METRICS:
		_pair(host, box, str(WORLD_METRICS[field]), metric_text(w, field))
		box.add_child(host.label(str(WORLD_METRIC_MEANINGS[field])))
		var source: String = str(w.get("metric_sources", {}).get(field, {}).get("source", ""))
		if not source.is_empty():
			if not sources.has(source): sources[source] = []
			sources[source].append(str(WORLD_METRICS[field]))
	for source: String in sources:
		_link(host, box, "查看" + " / ".join(sources[source]) + "情报来源", "fact", source)
	_divider(box)
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
	if not str(r.get("holder", "")).is_empty(): _link(host, box, "持有者 · " + host.title(r.holder), "person", r.holder)
	if not str(r.get("anchor", "")).is_empty(): _link(host, box, "绑定的锚点", "anchor", r.anchor)
	var definition: Dictionary = host.session.catalog.tables.relics.get(str(r.get("type", "")), {})
	for field: String in ["carry_effect", "carry_cost"]:
		if definition.has(field): box.add_child(host.label(str(definition[field])))
	_divider(box)
	var actions: Array = {"controlled":["equip", "disassemble"], "ground":["recover"], "carried":["unequip", "disassemble"], "bound":["unbind"], "seized":["recover"]}.get(str(r.get("placement", "")), [])
	for action: String in actions:
		_action(host, box, {"equip":"选择携带者", "unequip":"卸下", "unbind":"解绑并查看锚点后果", "recover":"查看当前回收条件", "disassemble":"解离并选择用途"}[action], "relic/" + action, {"domain":str(r.get("domain", "")), "relic":id})
	if actions.is_empty(): box.add_child(host.label("当前不可直接处置；仍可查看其已知经历。"))
	_link(host, box, "物件的已知经历", "history", id)

func _anchors(host, box: VBoxContainer, domain: String, heading: bool = true) -> void:
	if heading: _heading(host, box, "锚点与持续护持")
	var count: int = 0
	for a: Dictionary in host.projection.get("anchors", []):
		if not domain.is_empty() and a.get("domain") != domain: continue
		_link(host, box, host.title(a.id) + " · " + _anchor_state(a), "anchor", a.id); count += 1
	if count == 0: box.add_child(host.label("此范围内尚无已知锚点。"))

func _anchor(host, box: VBoxContainer, id: String) -> void:
	var a: Dictionary = _find(host, "anchors", id)
	if a.is_empty(): box.add_child(host.label("没有这个已知锚点。")); return
	_heading(host, box, host.title(id))
	_pair(host, box, "状态", _anchor_state(a))
	if a.get("needs_rebind", false): box.add_child(host.label("原锚点需重新绑定媒介。"))
	_link(host, box, "护持者 · " + host.title(str(a.get("guardian", ""))), "person", str(a.get("guardian", "")))
	if not str(a.get("relic", "")).is_empty(): _link(host, box, "绑定媒介 · " + host.title(a.relic), "relic", a.relic)
	_action(host, box, "查看当前锚定 / 修复条件", "POWER_ANCHOR", {"domain":str(a.get("domain", "")), "institution":str(a.get("institution", "")), "npc":str(a.get("guardian", "")), "relic":str(a.get("relic", ""))})
	_action(host, box, "任命护持者", "POWER_APPOINT", {"domain":str(a.get("domain", "")), "anchor":id})
	_link(host, box, "已知材料与实践", "materials", str(a.get("domain", "")))
	_link(host, box, "供奉与轮末支付", "budget")

func _anchor_state(anchor: Dictionary) -> String:
	return {"active":"有效", "dormant":"休眠", "destroyed":"已毁", "absent":"尚未建立"}.get(str(anchor.get("state", "")), "未掌握")

func _opportunities(host, box: VBoxContainer, domain: String) -> void:
	var all: Array = host.session.action_catalog()
	var shown := {}
	for row: Dictionary in all:
		if not str(row.key).begins_with("opportunity/"): continue
		var source: String = str(row.key).split("/")[1]
		var fact: Dictionary = _known_fact(host, source)
		if fact.is_empty() or (not domain.is_empty() and fact.get("domain") != domain): continue
		if not shown.has(source):
			if shown.is_empty(): _heading(host, box, "已出现的媒介机会")
			shown[source] = true
			var details: Dictionary = fact.get("changes", {})
			var item: Dictionary = host.session.catalog.tables.relics.get(details.get("relic_type", ""), {})
			box.add_child(host.label("%s · %s" % [host.title(str(fact.domain)), item.get("name", "机构媒介")], true))
			if details.get("due") is int: box.add_child(host.label("第 %s 轮到期" % details.due))
			_link(host, box, "机会来源", "fact", source)
		_action(host, box, str(row.title), row.key)

func _plan(host) -> Dictionary:
	var plan: Dictionary = host.projection.get("economy_plan", {}).duplicate(true)
	if not plan.has("strategies"): plan["strategies"] = {}
	if not plan.has("anchor_priority"): plan["anchor_priority"] = []
	if not plan.has("refuse_anchors"): plan["refuse_anchors"] = []
	for a: Dictionary in host.projection.get("anchors", []):
		if not a.id in plan.anchor_priority: plan.anchor_priority.append(a.id)
	return plan

func _budget(host, box: VBoxContainer) -> void:
	_heading(host, box, "本轮收支")
	box.add_child(host.label("结束回合时，先花费信仰执行教团指令、维持锚点，再结算教团收入。\n这里可以调整锚点的供奉顺序，或停供某个锚点；教团指令在各教团页修改。"))
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
	box.add_child(host.label(budget_summary(host)))
	if not host.draft.is_empty(): box.add_child(host.label("这里按当前信仰计算；右侧行动尚未执行，尚未扣费。"))
	for c: Dictionary in preview.get("cults", []):
		if _find(host, "cults", str(c.cult)).is_empty(): continue
		_link(host, box, host.title(c.cult) + " · 支出 %s 信仰 / 预计收入 %s" % [c.fee, c.income_if_unchanged], "cult", c.cult)
		if not str(c.get("reason", "")).is_empty(): box.add_child(host.label("指令未生效：" + _economy_reason(host, str(c.reason))))
	var plan: Dictionary = _plan(host)
	for i: int in range(plan.anchor_priority.size()):
		var anchor_id: String = str(plan.anchor_priority[i])
		if _find(host, "anchors", anchor_id).is_empty(): continue
		var a: Dictionary = {}
		for row: Dictionary in preview.get("anchors", []):
			if row.anchor == anchor_id: a = row; break
		_divider(box)
		_link(host, box, str(i + 1) + ". " + host.title(anchor_id), "anchor", anchor_id)
		box.add_child(host.label("供奉 %s 信仰 · %s" % [a.get("fee", 0), "可以支付" if str(a.get("reason", "")).is_empty() else _economy_reason(host, str(a.reason))]))
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

func budget_summary(host) -> String:
	var preview: Dictionary = host.session.economy_preview().get("preview", {})
	if preview.is_empty(): return "本轮收支已结算，实际变化可在编年史查看。"
	var before: int = int(preview.get("faith_before", 0))
	var after: int = int(preview.get("faith_after_prepay", 0))
	var income: int = 0
	var warnings: PackedStringArray = []
	for c: Dictionary in preview.get("cults", []):
		income += int(c.get("income_if_unchanged", 0))
		if c.get("reason", "") == "insufficient_faith": warnings.append(host.title(str(c.cult)) + "无法支付传教费用")
	for a: Dictionary in preview.get("anchors", []):
		if a.get("reason", "") == "insufficient_faith": warnings.append(host.title(str(a.anchor)) + "无法支付供奉，将休眠")
	var summary: String = "现有信仰 %d · 本轮支出 %d · 支出后剩余 %d\n预计教团收入 %d（局势变化可能影响收入）" % [before, before - after, after, income]
	if not warnings.is_empty(): summary += "\n" + "；".join(warnings)
	return summary

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
			if values.get("scheduled_release", {}).has(w.id):
				box.add_child(host.label("已安排释放 · 最早第 %s 轮，仍承担责任则延后" % values.scheduled_release[w.id]))
			else: _action(host, box, "安排下轮释放", "attention/release_focus", {"domain":w.id})
	if not id.is_empty(): _action(host, box, "查看关注条件", "attention/focus", {"domain":id})
	else: _action(host, box, "选择需要关注的世界", "attention/focus")
	_action(host, box, "查看并释放未用活动预留", "attention/release_project")
	box.add_child(host.label("查看对象不占关注；安排释放不会提前腾出本轮名额。进行中的事情仍需按其真实条件处理。"))

func _known_fact(host, id: String) -> Dictionary:
	var ids: Array = host.session.known_sources()
	var index: int = ids.find(id)
	if index < 0: return {}
	var page: Dictionary = host.session.history_page(index, 1)
	return page.get("facts", [])[0] if not page.get("facts", []).is_empty() else {}

func _history(host, box: VBoxContainer, filter_id: String) -> void:
	_heading(host, box, "编年史" if filter_id.is_empty() else host.title(filter_id) + " · 已知经历")
	var offset: int = int(history_offsets.get(filter_id, 0))
	var page: Dictionary = _history_slice(host, filter_id, offset)
	for fact: Dictionary in page.facts:
		var kind_title: String = ("世界态势记录" if fact.kind == "world_observation" else "世界态势线索") if _world_observation_fact(fact) else host.describe(fact.get("kind", "记录"))
		_link(host, box, "第%s轮 · %s\n%s" % [fact.get("turn", "?"), kind_title, _fact_summary(host, fact)], "fact", fact.id)
	if page.facts.is_empty(): box.add_child(host.label("没有匹配的已知经历。"))
	if page.has_older: box.add_child(host.button("更早的记录", func() -> void: history_offsets[filter_id] = offset + 50; host.show_subject("history", filter_id)))
	if offset > 0: box.add_child(host.button("返回最新记录", func() -> void: history_offsets[filter_id] = 0; host.show_subject("history", filter_id)))

func _history_slice(host, filter_id: String, offset: int, limit: int = 50, query := "") -> Dictionary:
	# Read only public history pages. Count associated records, not global records,
	# so unrelated activity cannot hide this object's latest known experience.
	var stop: int = host.session.known_sources().size()
	var skipped: int = 0
	var result: Array = []
	while stop > 0:
		var start: int = maxi(0, stop - 100)
		var page: Dictionary = host.session.history_page(start, stop - start)
		var facts: Array = page.get("facts", []).duplicate(); facts.reverse()
		for fact: Dictionary in facts:
			if not filter_id.is_empty() and not _fact_refers_to(fact, filter_id): continue
			if not query.is_empty() and not ("%s %s %s" % [fact.get("turn", ""), host.describe(fact.kind), _fact_summary(host, fact)]).containsn(query): continue
			if skipped < offset: skipped += 1; continue
			if result.size() == limit: return {"facts":result, "has_older":true}
			result.append(fact)
		stop = start
	return {"facts":result, "has_older":false}

func _fact_refers_to(fact: Dictionary, id: String) -> bool:
	return fact.get("domain") == id or fact.get("actor") == id or _contains_reference(fact.get("targets", []), id) or _contains_reference(fact.get("changes", {}), id)

func _contains_reference(value: Variant, id: String) -> bool:
	if value is String: return value == id
	if value is Array:
		for item: Variant in value:
			if _contains_reference(item, id): return true
	elif value is Dictionary:
		for key: Variant in value:
			if key == id or _contains_reference(value[key], id): return true
	return false

func _fact_summary(host, fact: Dictionary) -> String:
	if _world_observation_fact(fact): return host.title(str(fact.id))
	var items: PackedStringArray = []
	var actor: String = str(fact.get("actor", ""))
	if not actor.is_empty(): items.append(host.title(actor))
	for target: Variant in fact.get("targets", []):
		if target is String and items.size() < 3 and not host.title(target) in items: items.append(host.title(target))
	if items.is_empty(): items.append(host.title(str(fact.get("domain", ""))))
	return " · ".join(items)

func _world_observation_fact(fact: Dictionary) -> bool:
	return fact.get("kind") == "world_observation" or (fact.get("kind") == "message" and fact.get("changes", {}).get("observation_version") == "world-observation/1")

func _observation_details(host, box: VBoxContainer, fact: Dictionary) -> void:
	_heading(host, box, host.title(str(fact.id)))
	box.add_child(host.label("这是第%d轮留下的世界记录，不代表当前实时状态。" % int(fact.turn)))
	var metrics: Dictionary = fact.changes.get("intelligence", {}).duplicate(true)
	if fact.kind == "world_observation":
		for field: String in WORLD_METRICS:
			if fact.changes.get("metrics", {}).get(field) is int:
				metrics[field] = {"precision":"exact", "value":fact.changes.metrics[field], "turn":fact.turn}
	else:
		var heard: bool = host.session.is_known_source(str(fact.changes.get("fact", "")))
		box.add_child(host.label("这份记录已聆听；确值记录在下方已知前因中。" if heard else "这条线索给出估计区间。可在“聆听”的来源列表中选择它，查明当时的四项状态。"))
	for field: String in WORLD_METRICS:
		_pair(host, box, str(WORLD_METRICS[field]), metric_text({"metric_sources":metrics}, field))

func _fact(host, box: VBoxContainer, id: String) -> void:
	var fact: Dictionary = _known_fact(host, id)
	if fact.is_empty(): box.add_child(host.label("这项前因尚未获知。")); return
	if _world_observation_fact(fact):
		_observation_details(host, box, fact)
	else:
		_heading(host, box, "第%s轮 · %s" % [fact.get("turn", "?"), host.describe(fact.get("kind", "记录"))])
		box.add_child(host.label(_fact_summary(host, fact)))
		_pair(host, box, "实际变化", fact.get("changes", {}))
	var subjects := {}
	for target: Variant in [fact.get("actor", "")] + fact.get("targets", []):
		if not target is String or str(target).is_empty() or subjects.has(target): continue
		subjects[target] = true
		for pair: Array in [["people", "person"], ["relics", "relic"], ["domains", "world"], ["cults", "cult"], ["anchors", "anchor"]]:
			if not _find(host, pair[0], target).is_empty(): _link(host, box, "查看 " + host.title(target), pair[1], target)
	_heading(host, box, "已知前因")
	for parent: String in fact.get("causal_parents", []):
		if parent == "尚未知晓": box.add_child(host.label("尚未获知的前因"))
		else: _link(host, box, host.title(parent), "fact", parent)

func _materials(host, box: VBoxContainer, domain: String) -> void:
	_heading(host, box, "已知材料与实践")
	box.add_child(host.label("活动使用真实记录、原参与者及跨轮进展。选择当地人物查看其当前可推进的事情和所缺材料。"))
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
	box.add_child(host.label("本局只读。世界、人物和编年史仍可从常驻入口查看；暂停菜单可开启新局或载入其他保存。"))
