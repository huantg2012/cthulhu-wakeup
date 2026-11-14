extends Control
## Selected left-shoulder category imprint; no stock, image, or input ownership.
## Coordinates remain in the host card's logical pixels, including 9 px slivers.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const IDS := ["world", "event", "prayer", "cult", "power", "activity", "person", "anchor", "relic", "action", "resistance"]
const CATEGORIES := {
	"world": {"label": "世界", "short": "世界", "colour": Color("#c6a471")},
	"event": {"label": "事件", "short": "事件", "colour": Color("#b35d4b")},
	"prayer": {"label": "祈求", "short": "祈求", "colour": Color("#a675a5")},
	"cult": {"label": "教团", "short": "教团", "colour": Color("#55956e")},
	"power": {"label": "权能", "short": "权能", "colour": Color("#5c7fb4")},
	"activity": {"label": "活动", "short": "活动", "colour": Color("#b5b566")},
	"person": {"label": "人物", "short": "人物", "colour": Color("#c5a399")},
	"anchor": {"label": "锚点", "short": "锚点", "colour": Color("#55a8ad")},
	"relic": {"label": "圣物", "short": "圣物", "colour": Color("#9897b3")},
	"action": {"label": "行为", "short": "行为", "colour": Color("#8c6143")},
	"resistance": {"label": "预告", "short": "预告", "colour": Color("#b27157")},
}
const DARK_INK := Color("#26272a")
const PALE_INK := Color("#e0d6bd")

## Retained for source API compatibility; the shoulder uses contrast ink.
var short_text_colour := PALE_INK:
	set(value):
		short_text_colour = value
		queue_redraw()

var _category_id := "world"
var _variant := 2
var _index := 0
var _side := 0
var _exposed := 148.0
var _peek_amount := 0.0
var _colour := Color("#c6a471")


static func info(category_id: String) -> Dictionary:
	# Visual vocabulary only; never a source of gameplay categories or rules.
	return CATEGORIES.get(category_id, CATEGORIES.action).duplicate()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	use_parent_material = false
	show_behind_parent = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func configure(category_id: String, variant: int, card_size: Vector2) -> void:
	_category_id = category_id if CATEGORIES.has(category_id) else "action"
	_index = 1 if _category_id == "resistance" else IDS.find(_category_id)
	_colour = info(_category_id).colour
	# 1 / 3 are retired candidates; only 0 (reference) and 2 remain live.
	_variant = 0 if variant == 0 else 2
	size = card_size
	_side = 0
	_exposed = card_size.x
	_peek_amount = 0.0
	queue_redraw()


func set_exposure(side: int, exposed: float) -> void:
	var next_side := clampi(side, -1, 1)
	var next_exposed := maxf(0.0, exposed)
	if next_side == _side and is_equal_approx(next_exposed, _exposed):
		return
	_side = next_side
	_exposed = next_exposed
	queue_redraw()


func set_peek_amount(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(next, _peek_amount):
		return
	_peek_amount = next
	queue_redraw()


func _draw() -> void:
	if _variant == 0 or size.x < 40.0 or size.y < 60.0:
		return
	var origin := Vector2(3.0, 7.0)
	var normalized := PackedVector2Array()
	# The selected shoulder imprint: one small cut shape on the LEFT only.
	# It never changes the carrier silhouette, input, or sibling draw order.
	match _index % 5:
		0:
			normalized = PackedVector2Array([Vector2(0, 0.08), Vector2(0.20, 0), Vector2(0.94, 0.03), Vector2(1, 0.89), Vector2(0.76, 1), Vector2(0.04, 0.97)])
		1:
			normalized = PackedVector2Array([Vector2(0.05, 0), Vector2(0.92, 0.02), Vector2(1, 0.40), Vector2(0.86, 0.51), Vector2(0.97, 0.97), Vector2(0.06, 1)])
		2:
			normalized = PackedVector2Array([Vector2(0, 0.04), Vector2(0.96, 0), Vector2(1, 0.96), Vector2(0.69, 1), Vector2(0.50, 0.93), Vector2(0.28, 0.99), Vector2(0.05, 0.96)])
		3:
			normalized = PackedVector2Array([Vector2(0.05, 0), Vector2(0.93, 0.05), Vector2(1, 0.96), Vector2(0.10, 1), Vector2(0, 0.68), Vector2(0.14, 0.55), Vector2(0.01, 0.40)])
		4:
			normalized = PackedVector2Array([Vector2(0, 0.07), Vector2(0.26, 0.01), Vector2(0.43, 0.09), Vector2(0.60, 0.02), Vector2(0.97, 0.04), Vector2(1, 0.96), Vector2(0.08, 1)])
	var points := PackedVector2Array()
	for point: Vector2 in normalized:
		points.append(origin + point * Vector2(26.0, 46.0))
	draw_colored_polygon(points, Color(_colour, 0.96))
	# Fit solid ink into the visible left edge instead of erasing it at a
	# density threshold. Keep this layout stable throughout the lift; siblings
	# supply physical occlusion and uncover both characters as the card rises.
	# Below a readable glyph width we retain real ink, rather than shrinking
	# it indefinitely or pretending that every resting sliver remains legible.
	var print_width := 26.0 if _side == 0 else clampf(_exposed - 4.0, 13.0, 26.0)
	var font_size := int(clampf(floorf(print_width - 1.0), 12.0, 14.0))
	var font: Font = Paint.fonts().body
	var label: String = info(_category_id).label
	var ink := _contrasting_ink()
	for index: int in mini(2, label.length()):
		var character := label.substr(index, 1)
		var width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, origin + Vector2((print_width - width) * 0.5, 18.0 + 18.0 * float(index)),
			character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _contrasting_ink() -> Color:
	var light := _colour.r * 0.2126 + _colour.g * 0.7152 + _colour.b * 0.0722
	return DARK_INK if light > 0.56 else PALE_INK
