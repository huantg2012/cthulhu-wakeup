extends RefCounted
## The workbench keeps only input drafts. Rules, selectors and payment stay in Session.
const OUTCOMES: Array[String] = ["deep", "success", "failure", "disaster"]
const OUTCOME_NAMES: Dictionary = {"deep": "深刻成功", "success": "成功", "failure": "失败", "disaster": "灾变"}
const OBJECT_FIELDS: Array[String] = ["domain", "npc", "agent", "other", "sender", "recipient", "participants", "cult", "institution", "target_institution", "target_domain", "relic", "preparation_relic", "anchor", "cosmic_anchor", "system_anchor", "record", "second_record", "source", "qualification"]

func resolve_row(host, key: String, selection: Dictionary) -> Dictionary:
	for row: Dictionary in host.session.action_catalog(selection):
		if str(row.key) == key: return row
	return {}

func render(host, box: VBoxContainer) -> void:
	if host.draft.is_empty():
		box.add_child(host.label("行动与后果", true))
		box.add_child(host.label("从当前人物、祈求、圣物或下方权能开始。查看其他对象时，这里会保留正在准备的行动。"))
		return
	var key: String = str(host.draft.get("key", ""))
	var selection: Dictionary = host.draft.get("selection", {})
	var row: Dictionary = resolve_row(host, key, selection)
	if row.is_empty():
		_render_unavailable(host, box, key)
		return
	# The engine can infer the first candidate; the UI deliberately does not.
	# Only a unique, mandatory candidate is filled without an explicit selection.
	for pass_number: int in range(4):
		var changed: bool = _normalize_unique(row.get("fields", []), selection)
		if not changed: break
		host.draft["review"] = false
		row = resolve_row(host, key, selection)
		if row.is_empty(): break
	host.draft["selection"] = selection
	if row.is_empty():
		_render_unavailable(host, box, key)
		return
	box.add_child(host.label(str(row.title), true))
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	if preview.get("ok", false):
		box.add_child(host.label("必付　%s 低语　·　%s 信仰" % [costs.get("whispers", 0), costs.get("faith", costs.get("faith_cost", 0))]))
	var fields: Array = row.get("fields", [])
	var missing: Array[String] = _missing_fields(fields, selection)
	if not host.draft.get("review", false):
		_render_preparation(host, box, row, selection, missing)
		return
	box.add_child(host.button("‹ 返回准备，保留当前选择", func() -> void:
		host.draft["review"] = false
		host.draft["scroll"] = 0
		host.render_workbench()))
	_render_identity(host, box, row, selection)
	_render_consequences(host, box, row, selection)
	if not missing.is_empty(): box.add_child(host.label("尚需选择：" + "、".join(missing)))
	if not preview.get("ok", false):
		box.add_child(host.label("当前不能执行：" + host.session.explain_error(str(preview.get("error", "条件尚未满足")))))
	else:
		_render_payment(host, box, row)
		if costs.get("consumes", false):
			var consumed: String = host.title(str(selection.get("relic", selection.get("npc", "")))) if costs.consumes is bool else host.describe(costs.consumes)
			box.add_child(host.label("必失对象：" + consumed))
		if costs.has("needs") and not costs.needs.get("budgets", {}).is_empty(): box.add_child(host.label("本次占用：" + host.describe(costs.needs.budgets)))
		if costs.has("net_gain"):
			var unit: String = {"faith": "信仰", "insight": "洞见", "followers": "信众", "whispers": "低语"}.get(str(selection.get("mode", "")), "")
			box.add_child(host.label("本次实际净得：" + host.describe(costs.net_gain) + " " + unit))
		if costs.has("awakening_loss") and int(costs.awakening_loss) > 0: box.add_child(host.label("立即失去苏醒：" + str(costs.awakening_loss)))
	var submitted_key: String = key
	var submitted_selection: Dictionary = selection.duplicate(true)
	var execute: Button = host.button(("确认不可逆后果…" if preview.get("irreversible", false) else "执行") + " · " + str(row.title), func() -> void:
		host.run_action(submitted_key, submitted_selection))
	execute.name = "ExecuteDraft"
	execute.disabled = not preview.get("ok", false) or not missing.is_empty() or host.projection.get("terminal", false)
	box.add_child(execute)
	box.add_child(host.label("查看资料与调整供奉不会提交本行动；执行时重查资格。"))

func _render_preparation(host, box: VBoxContainer, row: Dictionary, selection: Dictionary, missing: Array[String]) -> void:
	_render_context(host, box, row)
	var fields: Array = row.get("fields", [])
	var optional_count: int = fields.filter(func(field: Dictionary) -> bool: return field.get("optional", false)).size()
	for field: Dictionary in fields:
		if not field.get("optional", false): _render_field(host, box, field, selection)
	if optional_count > 0:
		var expanded: bool = host.draft.get("preparations_open", false)
		if not host.draft.has("preparations_open"):
			for field: Dictionary in fields:
				if field.get("optional", false) and _has_value(selection.get(field.key)): expanded = true
		box.add_child(host.button(("收起" if expanded else "展开") + "准备与可选对象（%d）" % optional_count, func() -> void:
			host.draft["preparations_open"] = not expanded
			host.render_workbench()))
		if expanded:
			for field: Dictionary in fields:
				if field.get("optional", false): _render_field(host, box, field, selection)
	if row.key == "route/context":
		box.add_child(host.label("当前进展", true))
		box.add_child(host.label(host.describe(row.get("details", {}))))
	if not missing.is_empty(): box.add_child(host.label("尚需选择：" + "、".join(missing)))
	var preview: Dictionary = row.get("preview", {})
	if not preview.get("ok", false):
		box.add_child(host.label("当前不能执行：" + host.session.explain_error(str(preview.get("error", "条件尚未满足")))))
	var next: Button = host.button("查看代价与后果 →", func() -> void:
		host.draft["review"] = true
		host.draft["scroll"] = 0
		host.render_workbench())
	next.disabled = not missing.is_empty()
	box.add_child(next)

func _render_unavailable(host, box: VBoxContainer, key: String) -> void:
	var definition: Dictionary = host.session.catalog.tables.powers.get(key, {}) if host.session.catalog != null else {}
	box.add_child(host.label(str(definition.get("name", "当前行动")), true))
	if not definition.is_empty():
		box.add_child(host.label("需要苏醒 %s　·　%s 低语 / %s 信仰" % [definition.unlock_awakening, definition.whispers, definition.faith]))
		box.add_child(host.label(str(definition.target_requirement)))
		for outcome: String in OUTCOMES:
			box.add_child(host.label(OUTCOME_NAMES[outcome] + "：" + str(definition.get("deep_success" if outcome == "deep" else outcome, ""))))
	box.add_child(host.label("当前阶段不能执行此行动。原选择保留，可继续查看对象；处理事件或进入行动阶段后再试。"))

func _normalize_unique(fields: Array, selection: Dictionary) -> bool:
	var changed: bool = false
	for field: Dictionary in fields:
		var options: Array = field.get("options", [])
		var field_key: String = str(field.key)
		if field.get("multiple", false):
			if not selection.has(field_key): continue
			var old: Array = selection[field_key] if selection[field_key] is Array else []
			var kept: Array = old.filter(func(value: Variant) -> bool: return options.any(func(option: Dictionary) -> bool: return option.id == value))
			if kept != old: selection[field_key] = kept; changed = true
		elif selection.has(field_key) and _has_value(selection[field_key]) and not options.any(func(option: Dictionary) -> bool: return option.id == selection[field_key]):
			selection.erase(field_key); changed = true
		if not field.get("optional", false) and not field.get("multiple", false) and options.size() == 1 and not _has_value(selection.get(field_key)):
			selection[field_key] = options[0].id; changed = true
	return changed

func _has_value(value: Variant) -> bool:
	return value != null and not (value is String and value.is_empty()) and not (value is Array and value.is_empty())

func _missing_fields(fields: Array, selection: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field: Dictionary in fields:
		if not field.get("optional", false) and not _has_value(selection.get(field.key)): result.append(str(field.label).replace("时空", "世界"))
	return result

func _render_field(host, box: VBoxContainer, field: Dictionary, selection: Dictionary) -> void:
	var key: String = str(field.key)
	box.add_child(host.label(str(field.label).replace("时空", "世界")))
	var options: Array = field.get("options", [])
	if options.is_empty():
		box.add_child(host.label("暂无符合条件的已知对象。" if not field.get("optional", false) else "当前没有此类可用准备。"))
		return
	if field.get("multiple", false):
		var scroller := ScrollContainer.new()
		scroller.custom_minimum_size.y = minf(170.0, 36.0 * options.size())
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var choices := VBoxContainer.new(); choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(choices); box.add_child(scroller)
		for option: Dictionary in options:
			var id: Variant = option.id
			var check := CheckBox.new(); check.text = _option_title(host, option); check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			check.set_pressed_no_signal(id in selection.get(key, [])); choices.add_child(check)
			check.toggled.connect(func(on: bool) -> void:
				var values: Array = host.draft.selection.get(key, []).duplicate()
				if on and not id in values: values.append(id)
				elif not on: values.erase(id)
				host.draft.selection[key] = values
				host.draft["review"] = false
				host.render_workbench())
	else:
		var picker := OptionButton.new(); picker.name = "Field_" + key
		picker.custom_minimum_size = Vector2(120, 36); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picker.clip_text = true; picker.fit_to_longest_item = false
		picker.add_item("不用" if field.get("optional", false) else "请选择"); picker.set_item_metadata(0, "")
		for option: Dictionary in options:
			picker.add_item(_option_title(host, option)); var index: int = picker.item_count - 1; picker.set_item_metadata(index, option.id)
			if selection.get(key) == option.id: picker.select(index)
		picker.item_selected.connect(func(index: int) -> void:
			var value: Variant = picker.get_item_metadata(index)
			if value is String and value.is_empty(): host.draft.selection.erase(key)
			else: host.draft.selection[key] = value
			host.draft["review"] = false
			if key == "domain":
				for child: String in ["npc", "source", "cult", "anchor", "relic", "institution", "qualification", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"]: host.draft.selection.erase(child)
			elif key == "npc":
				for child: String in ["source", "other", "participants", "operation", "record", "second_record", "target", "preparations", "preparation_relic"]: host.draft.selection.erase(child)
			elif key == "operation":
				for child: String in ["source", "other", "participants", "record", "second_record", "target", "stage"]: host.draft.selection.erase(child)
			host.render_workbench())
		box.add_child(picker)

func _option_title(host, option: Dictionary) -> String:
	var id: String = str(option.id)
	for collection: String in ["domains", "people", "cults", "relics", "institutions", "anchors"]:
		for object: Dictionary in host.projection.get(collection, []):
			if str(object.id) == id: return host.title(id)
	return str(option.get("label", id)).replace("时空", "世界")

func _render_context(host, box: VBoxContainer, row: Dictionary) -> void:
	var details: Dictionary = row.get("details", {})
	var context: Dictionary = {}
	for key: String in details:
		if not key in ["requirement", "always", "success", "deep", "failure", "disaster", "回应所得", "始终代价"] and row.key != "route/context": context[key.replace("时空", "世界")] = details[key]
	if not context.is_empty(): box.add_child(host.label(host.describe(context)))
	if details.has("requirement"): box.add_child(host.label("需要：" + str(details.requirement)))

func _render_identity(host, box: VBoxContainer, row: Dictionary, selection: Dictionary) -> void:
	var shown: Dictionary = {}
	box.add_child(host.label("本次对象", true))
	var details: Dictionary = row.get("details", {})
	for key: String in ["祈求人", "濒死亲属", "对手", "契约另一方", "记忆持有人", "所在时空", "请求期限", "原危机期限", "固定仪式主体"]:
		if details.has(key): box.add_child(host.label(key.replace("时空", "世界") + "：" + host.describe(details[key])))
	for field: Dictionary in row.get("fields", []):
		var key: String = str(field.key)
		if not key in OBJECT_FIELDS or not _has_value(selection.get(key)): continue
		var value: Variant = selection[key]
		var ids: Array = value if value is Array else [value]
		for id_value: Variant in ids:
			var id: String = str(id_value)
			if shown.has(id): continue
			shown[id] = true
			var selected_label: String = host.title(id)
			for option: Dictionary in field.get("options", []):
				if option.id == id_value: selected_label = _option_title(host, option); break
			var kind: String = _object_kind(host, id)
			if key in ["source", "qualification", "record", "second_record"]: selected_label = "已选记录" if key in ["record", "second_record"] else "已选来源"
			elif selected_label.length() > 45: selected_label = selected_label.left(42) + "…"
			var line := HBoxContainer.new(); box.add_child(line)
			var text: Label = host.label(str(field.label).replace("时空", "世界") + "：" + selected_label)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(text)
			if not kind.is_empty(): line.add_child(host.button("查看", func() -> void: host.show_subject(kind, id)))

func _object_kind(host, id: String) -> String:
	var map: Dictionary = {"domains": "world", "people": "person", "cults": "cult", "relics": "relic", "anchors": "anchor", "institutions": "institution"}
	for collection: String in map:
		if host.projection.get(collection, []).any(func(item: Dictionary) -> bool: return str(item.id) == id): return map[collection]
	if host.session.is_known_source(id): return "fact"
	return ""

func _render_consequences(host, box: VBoxContainer, row: Dictionary, selection: Dictionary) -> void:
	var details: Dictionary = row.get("details", {})
	var preview: Dictionary = row.get("preview", {})
	var costs: Dictionary = preview.get("preview", {})
	var always: String = str(details.get("always", details.get("始终代价", details.get("不可逆代价", ""))))
	if row.key == "route/context":
		var operation: Dictionary = host.session.catalog.tables.progression_route_operations.get(str(selection.get("operation", "")), {})
		var parts: Array[String] = ["资源与本轮执行机会"]
		if int(operation.get("always_alert", 0)) > 0: parts.append("当地察觉 +" + str(operation.always_alert))
		if int(operation.get("always_sanity_loss", 0)) > 0: parts.append("参加者理智 −" + str(operation.always_sanity_loss))
		always = "、".join(parts)
	if not always.is_empty(): box.add_child(host.label("无论结果都承担：" + always))
	var effects: Dictionary = _outcome_effects(host, row, selection)
	var probabilities: Dictionary = costs.get("outcomes", {})
	box.add_child(host.label("结果与持续后果", true))
	if not probabilities.is_empty():
		for outcome: String in OUTCOMES:
			box.add_child(host.label("%s　%s%%\n%s" % [OUTCOME_NAMES[outcome], probabilities.get(outcome, 0), effects.get(outcome, "按原行动规则结算。")]))
	else:
		if row.key in ["POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]: box.add_child(host.label("支付当前轮次费用并登记仪式进展；后续仍须原锚点、护持者及继续支付。最终结果在规定的轮末核验，此处不提前确认成功。"))
		else: box.add_child(host.label(str(effects.get("success", details.get("选择后果", "按所选对象和当前条件结算。")))))
		if preview.get("ok", false): box.add_child(host.label("此步骤不进行随机四档检定。"))

func _outcome_effects(host, row: Dictionary, selection: Dictionary) -> Dictionary:
	var details: Dictionary = row.get("details", {})
	if str(row.key) == "POWER_MANIFEST_CONTINUE":
		var definition: Dictionary = host.session.catalog.tables.powers.POWER_MANIFEST
		return {"deep": definition.deep_success, "success": definition.success, "failure": definition.failure, "disaster": definition.disaster}
	if str(row.key).begins_with("POWER_") and details.has("success"):
		return {"deep": details.get("deep", details.success), "success": details.success, "failure": details.get("failure", ""), "disaster": details.get("disaster", "")}
	if str(row.key).begins_with("prayer/"):
		var parts: PackedStringArray = str(row.key).split("/")
		var entry: Dictionary = host.session.prayer_entry(parts[1])
		var content: String = str(entry.get("card", {}).get("content_id", ""))
		var variant: String = parts[2]
		var gain: String = str(details.get("回应所得", "原诉求获得回应。"))
		var disaster: Array[String] = []
		for effect: Dictionary in host.session.catalog.tables.prayer_effects.values():
			if effect.stage != "disaster" or not effect.prayer_id in ["*", content] or not effect.variant in ["both", variant]: continue
			var amount: int = host.session.catalog.integer(str(effect.parameter)) if not str(effect.parameter).is_empty() else int(effect.value)
			if effect.field == "sanity_loss": disaster.append("回应者额外损失 %d 理智" % amount)
			elif effect.field == "alert": disaster.append("当地察觉额外增加 %d" % amount)
			else: disaster.append(host.describe({str(effect.field): amount}))
		var multiplier: String = str(host.session.catalog.number("prayer_deep_success_multiplier"))
		return {"deep": gain + "；数量型收益按 " + multiplier + " 倍规则增强，人物与物件事实不复制。", "success": gain, "failure": "回应未产生成功收益；必付代价与本轮回应次数仍消耗，原危机按实际期限继续。", "disaster": "回应未产生成功收益；" + "；".join(disaster) + "。原危机按实际期限继续。"}
	if str(row.key) == "route/context":
		var operation: Dictionary = host.session.catalog.tables.progression_route_operations.get(str(selection.get("operation", "")), {})
		var success: String = "完成当前实际活动，按原参加者与记录推进本轮进展。"
		if operation.get("mode") == "private_devotion": success = "当前知晓且自愿的人物实际献身，按原资格接纳为成员并留下持续联系。"
		elif operation.get("mode") == "joint_work": success = "两位参加者完成共同工作，建立当前合作联系。"
		elif operation.get("mode") in ["covert_gathering", "calendar_rite"]:
			var parameter: String = "gathering_followers" if operation.mode == "covert_gathering" else "rite_followers"
			success = "从当地可接触人群转化至多 %d 名信众；首个教团仍在轮末核验形成。" % host.session.catalog.integer(parameter)
		elif operation.get("mode") in ["memory_circle", "pact_agreement"]: success = "建立本次共同情境或原约定；之后从相应祈求回应，不立即完成其后续结果。"
		elif operation.get("mode") == "ritual_transmission": success = "按当前步骤完成教习或原学徒施行；另一回合的步骤仍须原人物完成。"
		elif operation.get("mode") == "reciprocal_covenant": success = "固定原两项约定或完成当前一项交付；剩余交付仍受原条款约束。"
		if int(operation.get("success_pollution", 0)) > 0: success += " 当地污染 +" + str(operation.success_pollution) + "。"
		return {"deep": success, "success": success, "failure": "本轮未取得成功进展；资源、执行机会及该活动必付后果仍消耗。", "disaster": "本轮未取得成功进展；资源、执行机会及该活动必付后果仍消耗。"}
	return {"success": str(details.get("选择后果", details.get("取得内容", "按所选处置更新原对象，实际结果进入编年史。")))}

func payment_projection(host, row: Dictionary) -> Dictionary:
	var action_preview: Dictionary = row.get("preview", {})
	if not action_preview.get("ok", false) or host.session.turn == null: return {"ok": false}
	var costs: Dictionary = action_preview.get("preview", {})
	var fee: int = int(costs.get("faith", costs.get("faith_cost", 0)))
	var view: Dictionary = host.session.turn._read_view("economy", "prepay")
	var state: Dictionary = view.world.duplicate(false)
	var plan: Dictionary = host.session.turn.context.plans.get("economy", {}).duplicate(true)
	var before: Dictionary = host.session.modules.economy.preview(view.world, plan, view.reader)
	state["faith"] = maxi(0, int(state.faith) - fee)
	var after: Dictionary = host.session.modules.economy.preview(state, plan, view.reader)
	view.reader.close()
	if not before.get("ok", false) or not after.get("ok", false): return {"ok": false, "error": host.session.explain_error(str(after.get("error", before.get("error", "当前无法预览供奉"))))}
	var known_cults: Dictionary = {}; var known_anchors: Dictionary = {}; var contributions: Dictionary = {}
	for object: Dictionary in host.projection.get("cults", []): known_cults[object.id] = object
	for object: Dictionary in host.projection.get("anchors", []): known_anchors[object.id] = object
	for source: Dictionary in host.projection.get("awakening_sources", []):
		if source.get("kind") == "anchor" and known_anchors.has(source.get("title")): contributions[source.title] = int(source.value)
	var changes: Array = []; var lost: int = 0
	for cult_after: Dictionary in after.preview.get("cults", []):
		if not known_cults.has(cult_after.cult): continue
		for cult_before: Dictionary in before.preview.get("cults", []):
			if cult_before.cult == cult_after.cult and (cult_before.fee != cult_after.fee or cult_before.effective != cult_after.effective):
				changes.append({"kind": "cult", "id": cult_after.cult, "before": cult_before.effective, "after": cult_after.effective, "reason": cult_after.reason})
	for anchor_after: Dictionary in after.preview.get("anchors", []):
		if not known_anchors.has(anchor_after.anchor): continue
		for anchor_before: Dictionary in before.preview.get("anchors", []):
			if anchor_before.anchor == anchor_after.anchor and anchor_before.expected != anchor_after.expected:
				var contribution: int = int(contributions.get(anchor_after.anchor, 0)) if anchor_after.expected == "dormant" else 0
				lost += contribution
				changes.append({"kind": "anchor", "id": anchor_after.anchor, "before": anchor_before.expected, "after": anchor_after.expected, "reason": anchor_after.reason, "awakening_loss": contribution})
	return host.session._public({"ok": true, "faith_before": int(host.projection.get("faith", 0)), "fee": fee, "faith_after_action": state.faith, "faith_after_prepay": after.preview.faith_after_prepay, "changes": changes, "additional_awakening_loss": lost})

func _render_payment(host, box: VBoxContainer, row: Dictionary) -> void:
	var projection: Dictionary = payment_projection(host, row)
	box.add_child(host.label("付款后，本轮供奉会怎样", true))
	if not projection.get("ok", false):
		box.add_child(host.label(str(projection.get("error", "当前无法计算；请查看支出与供奉。"))))
	else:
		box.add_child(host.label("信仰 %s → 行动后 %s → 预付后 %s" % [projection.faith_before, projection.faith_after_action, projection.faith_after_prepay]))
		if projection.changes.is_empty(): box.add_child(host.label("这次付款不会额外改变现有教团指令与锚点供奉结果。"))
		for change: Dictionary in projection.changes:
			var summary: String = "本轮无法支付传教，将按守持处理" if change.kind == "cult" else "本轮无法支付供奉，将休眠"
			if int(change.get("awakening_loss", 0)) > 0: summary += "；苏醒 −" + str(change.awakening_loss)
			box.add_child(host.label(host.title(str(change.id)) + "\n" + summary))
			var kind: String = str(change.kind); var id: String = str(change.id)
			box.add_child(host.button("查看受影响对象", func() -> void: host.show_subject(kind, id)))
		if int(projection.additional_awakening_loss) > 0: box.add_child(host.label("仅此次付款，预计额外失去苏醒 %s。" % projection.additional_awakening_loss))
	box.add_child(host.label("这里只假设支付本次费用，尚未加入随机结果、人口变化和后续演化；这些条件仍会在轮末重查。"))
	box.add_child(host.button("并置查看 / 调整支出与供奉", func() -> void: host.show_subject("budget")))
