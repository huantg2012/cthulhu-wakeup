extends RefCounted
## Render value, state and expandable details for each requirement.
## Fits inside the existing task scroller; never creates a nested scroll surface.
static var _legacy_controls: RefCounted

static func render(parent: VBoxContainer, groups: Array, large := false, controls: RefCounted = null) -> void:
	var locked := controls != null
	if not locked:
		if _legacy_controls == null: _legacy_controls = load("res://src/presentation/ui/ui_components.gd").new()
		controls = _legacy_controls
	var colors: Dictionary = controls.get_script().get_script_constant_map()
	for section: Dictionary in groups:
		if section.get("items", []).is_empty(): continue
		var block := VBoxContainer.new()
		block.name = "Requirements_" + str(parent.get_child_count())
		block.add_theme_constant_override("separation", 3)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(block)
		var heading := _label(str(section.title), 15 if not large else 17, colors.GOLD)
		heading.custom_minimum_size.y = 28
		block.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2 if locked else 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 5)
		block.add_child(grid)
		var detail := _label("", 14 if not large else 16, colors.MUTED)
		detail.name = "RequirementDetail"
		detail.visible = false
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for item: Dictionary in section.items:
			var met: bool = item.state == "met"
			var color: Color = colors.BOUND if met else (colors.RISK if item.state == "missing" else colors.MUTED)
			var title := _label(str(item.title), 16 if not large else 18, colors.BONE)
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
			var number := _label(value, 16 if not large else 18, colors.GOLD_HI if met else colors.BONE)
			number.name = "RequirementValue_" + str(item.id)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(number)
			var state_text: String = {"met":"已满足", "missing":"未满足", "unknown":"待确认", "selected":"待核验"}.get(str(item.state), "待确认")
			if item.get("progress", false): state_text = "已完成" if met else "进行中"
			if item.has("projected"): state_text = "预计推进"; color = colors.CYAN
			var state_label := _label("" if item.state == "info" else ("✓ " if met else "· ") + state_text, 14 if not large else 16, color)
			grid.add_child(state_label)
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
				more.add_theme_color_override("font_color", colors.CYAN)
				more.add_theme_font_override("font", controls.fonts.body)
				more.add_theme_font_size_override("font_size", 14 if not large else 16)
				if locked:
					controls.style_action(more, false)
					more.focus_entered.connect(controls.sync_focus_style.bind(more))
				else:
					for state: String in ["normal", "hover", "pressed", "focus", "disabled"]: more.add_theme_stylebox_override(state, controls.unframed_style(state))
					controls.transparent_button(more)
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
