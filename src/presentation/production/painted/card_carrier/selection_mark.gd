extends Control
## A small pressed corner identifies a chosen candidate, never a second frame.
var chosen := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not chosen and not get_parent().get_meta("keyboard_focus", false): return
	var heel := Vector2(size.x - 9, size.y - 10)
	draw_colored_polygon(PackedVector2Array([
		heel + Vector2(-23, 3), heel + Vector2(-19, -1), heel + Vector2(-7, -2),
		heel + Vector2(1, -7), heel + Vector2(2, 2), heel + Vector2(-8, 5),
	]), Color("#d9c297", 0.84))
	if chosen:
		draw_polyline(PackedVector2Array([heel + Vector2(-17,-1), heel + Vector2(-12,3), heel + Vector2(-5,-5)]), Color("#31262a"), 1.5, true)
