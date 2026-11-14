extends "res://src/presentation/production/worldplay/study_card.gd"
## One public world on the approved continuous carrier. Session and navigation
## remain with the host; the same portrait identity and preload cache are bound.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
const Attention = preload("res://src/presentation/production/painted/world_attention.gd")
var _attention: Control
var ordinal := 0
var _metric_labels: Array[RichTextLabel] = []
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
	var body: RichTextLabel = carrier.get_node("InformationOne")
	body.add_theme_font_size_override("normal_font_size",14 + extra)
	body.size.y = 38 + extra * 2
	for i: int in world.metrics.size():
		var line: RichTextLabel = carrier.Fields.at(carrier,"WorldMetrics%d" % i,world.get("metric_fields",[])[i] if world.has("metric_fields") else [world.metrics[i]],Rect2(16,341+20*i,228,23),14+extra,true)
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
	tooltip_parts = [str(world.title),"\n",str(world.status)]
	for parts: Array in world.get("metric_fields",[]): tooltip_parts.append_array(["\n"]+parts)
	_attention = Attention.new()
	_attention.name = "WorldAttention"
	_attention.size = size
	add_child(_attention)

func set_attention(kind: String) -> void:
	set_meta("attention_kind",kind)
	_attention.mark(kind)

func set_exposure(side: int, exposed: float) -> void:
	super.set_exposure(side,exposed)
	if is_instance_valid(_attention):
		_attention.exposure = exposed
		_attention.queue_redraw()
	# Extra world metrics follow the same shared reading state as all copy.
	var reading := 1.0 if Carrier.face_copy_visible(side,exposed) else 0.0
	for line: RichTextLabel in _metric_labels:
		line.modulate.a = reading
