extends "res://docs/art/visual-generation/ui-study/painted_card.gd"
## A07/A08 painted carrier for one public world. No input or Session calls.
const UI = preload("res://src/presentation/production/locked_controls.gd")
const WindowArt = preload("res://src/presentation/production/painted/object_window.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
var art: TextureRect:
	get: return _art

func _ready() -> void:
	# The production constructor supplies a bound TextureRect and public copy.
	pass

func build(controls: RefCounted, world: Dictionary, number: int, extra: int, portraits: Node) -> void:
	ordinal = number
	name = "World_" + str(world.id)
	set_meta("subject_id", world.id)
	accessibility_name = world.title
	size = Fan.CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	controls.label(self, "Ordinal", "%02d" % (ordinal + 1), Rect2(17, 9, 32, 24), 14 + extra, UI.MUTED)
	var kind := "%s / %s" % [world.relation, world.tier_title]
	var tag: Label = controls.label(self, "Category", kind, Rect2(94, 9, 149, 24), 14 + extra, UI.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.clip_text = true
	controls.fill(self, "WaitingStock", Rect2(14, 39, 232, 232), Color("#121d1f"))
	var note: Label = controls.label(self, "ArtStatus", "", Rect2(16, 139, 228, 24), 14 + extra, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art = controls.image(self, "WorldArt", Rect2(10, 35, 240, 240), null)
	WindowArt.style(art)
	var title_px := 24 + extra
	var title_width: float = controls.fonts.heading.get_string_size(world.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
	var title: Label = controls.label(self, "WorldName", world.title, Rect2(19, 283, 224, 33), title_px if title_width <= 224 else 18 + extra, UI.BONE, title_width <= 224)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	var subtitle: Label = controls.label(self, "WorldStatus", world.status, Rect2(21, 316, 220, 20), 14 + extra, UI.MUTED)
	subtitle.clip_text = true
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details.assign([title, subtitle])
	for i: int in world.metrics.size():
		var line: Label = controls.label(self, "WorldMetrics%d" % i, world.metrics[i], Rect2(21, 338 + 19 * i, 224, 22), 14 + extra)
		_details.append(line)
	portraits.bind(art, world.art_recipe, note)
