extends "res://src/presentation/production/worldplay/study_card.gd"
## One public world on the approved continuous carrier. Session and navigation
## remain with the host; the same portrait identity and preload cache are bound.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
var ordinal := 0
var _metric_labels: Array[Label] = []
var art: TextureRect:
	get: return carrier.art if is_instance_valid(carrier) else null

func build(controls: RefCounted, world: Dictionary, number: int, extra: int, portraits: Node) -> void:
	ordinal = number
	name = "World_" + str(world.id)
	set_meta("subject_id", world.id)
	accessibility_name = world.title
	size = Fan.CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	palette = "world"
	seed_value = absi(str(world.id).hash()) % 1000
	var title_px := 24 + extra
	var width: float = controls.fonts.heading.get_string_size(world.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
	var recipe: Dictionary = world.art_recipe
	var sample := {"category_id":"world", "kind":"世界", "art_kind":"world",
		"title":world.title, "line1":"%s · %s\n%s" % [world.relation, world.tier_title, world.status],
		"line2":"", "paper_backed":int(recipe.get("request", {}).get("style", -1)) in [2,6]}
	configure_carrier(sample, null, {"title_y":263.0, "info_y":298.0,
		"title_font_size":title_px if width <= 228.0 else 18 + extra,
		"title_max_lines":1, "font_extra":extra})
	# Dense public readings fit below the title without becoming a separate panel.
	# They inherit the same exposure as the carrier's printed copy when stacked.
	var body: Label = carrier.get_node("InformationOne")
	body.add_theme_font_size_override("font_size",14 + extra)
	body.size.y = 38 + extra * 2
	for i: int in world.metrics.size():
		var line: Label = controls.label(carrier, "WorldMetrics%d" % i, world.metrics[i], Rect2(16, 341 + 20 * i, 228, 23), 14 + extra, Color("#302a29"))
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_metric_labels.append(line)
	var note: Label = carrier.art_status
	note.position = Vector2(28,120)
	note.size = Vector2(210,38)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	note.add_theme_constant_override("shadow_offset_y",1)
	art.set_meta("subject_id",world.id)
	portraits.bind(art,recipe,note)
	adapt_portrait_backing(str(recipe.get("key","")),int(recipe.get("request",{}).get("style",-1)))
	tooltip_text = str(world.title) + "\n" + str(world.status) + "\n" + "\n".join(world.metrics)

func set_exposure(side: int, exposed: float) -> void:
	super.set_exposure(side,exposed)
	# Broad overview overlaps still expose enough paper to read fragments as
	# an actual printed card. Keep that ink; the next sibling occludes it.
	# Only genuinely narrow spines switch to the vertical short-name treatment.
	var reading := 1.0 if side == 0 or exposed >= 70.0 else 0.0
	for label_name: String in ["Title","InformationOne","InformationTwo"]:
		carrier.get_node(label_name).modulate.a = reading
	if exposed >= 70.0:
		carrier.get_node("LeftSideName").visible = false
	for line: Label in _metric_labels:
		line.modulate.a = reading
