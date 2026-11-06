extends RefCounted
## Quiet native game rows: fixed name/value/state columns and opt-in detail.
## Fits inside the existing task scroller; never creates a nested scroll surface.
const UI = preload("res://src/presentation/ui/ui_components.gd")
static var _controls: RefCounted = UI.new()

static func render(parent: VBoxContainer, groups: Array, large := false) -> void:
	for section: Dictionary in groups:
		if section.get("items", []).is_empty(): continue
		var block := VBoxContainer.new()
		block.name = "Requirements_" + str(parent.get_child_count())
		block.add_theme_constant_override("separation", 3)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(block)
		var heading := _label(str(section.title), 15 if not large else 17, UI.GOLD)
		heading.custom_minimum_size.y = 28
		block.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 5)
		block.add_child(grid)
		var detail := _label("", 14 if not large else 16, UI.MUTED)
		detail.name = "RequirementDetail"
		detail.visible = false
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for item: Dictionary in section.items:
			var met: bool = item.state == "met"
			var color: Color = UI.BOUND if met else (UI.RISK if item.state == "missing" else UI.MUTED)
			var title := _label(str(item.title), 16 if not large else 18, UI.BONE)
			title.name = "Requirement_" + str(item.id)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.custom_minimum_size.y = 29
			title.set_meta("requirement", item.duplicate(true))
			grid.add_child(title)
			var value: String = str(item.get("value", ""))
			if item.has("current"): value = "%s / %s" % [item.current, item.required]
			if item.has("previous"):
				var previous: String = "%s / %s" % [item.previous, item.required] if item.has("current") and (item.previous is int or item.previous is float) else str(item.previous)
				value = previous + " → " + value
			if item.has("projected"): value += " → " + str(item.projected)
			var number := _label(value, 16 if not large else 18, UI.GOLD_HI if met else UI.BONE)
			number.name = "RequirementValue_" + str(item.id)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(number)
			var state_text: String = {"met":"已满足", "missing":"未满足", "unknown":"待确认", "selected":"待核验"}.get(str(item.state), "待确认")
			if item.get("progress", false): state_text = "已完成" if met else "进行中"
			if item.has("projected"): state_text = "预计推进"; color = UI.CYAN
			grid.add_child(_label("" if item.state == "info" else ("✓ " if met else "· ") + state_text, 14 if not large else 16, color))
			var hint: String = str(item.get("hint", ""))
			if hint.is_empty():
				var space := Control.new(); space.custom_minimum_size.x = 24; grid.add_child(space)
			else:
				var more := Button.new()
				more.name = "RequirementHelp_" + str(item.id)
				more.text = "?"; more.flat = true
				more.custom_minimum_size = Vector2(24, 26)
				more.tooltip_text = hint
				more.accessibility_name = str(item.title) + "：说明"
				more.add_theme_color_override("font_color", UI.CYAN)
				more.add_theme_font_override("font", _controls.fonts.heading)
				more.add_theme_font_size_override("font_size", 14 if not large else 16)
				for state: String in ["normal", "hover", "pressed", "focus", "disabled"]: more.add_theme_stylebox_override(state, _controls.unframed_style(state))
				_controls.transparent_button(more)
				grid.add_child(more)
				more.pressed.connect(func() -> void:
					var text: String = str(item.title) + " · " + hint
					detail.visible = not detail.visible or detail.text != text
					detail.text = text)
		block.add_child(detail)

static func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
