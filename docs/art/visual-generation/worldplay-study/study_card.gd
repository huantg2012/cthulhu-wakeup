extends Button
## A real-size card using the accepted painted stock; labels are never scaled.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
var seed_value := 0
var actionable := false
var payload: Dictionary = {}
var hand_card := false
var _hover_tween: Tween
var _stock: StyleBoxTexture

func _ready() -> void:
	text = ""
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_stock = StyleBoxTexture.new()
	_stock.texture = Paint.MaterialSource.pigment("card", seed_value)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_stock.set_texture_margin(side, 9)
	mouse_entered.connect(queue_redraw)
	mouse_entered.connect(_lift.bind(true))
	mouse_exited.connect(queue_redraw)
	mouse_exited.connect(_lift.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	queue_redraw()

func _lift(raised: bool) -> void:
	if not hand_card: return
	if _hover_tween != null: _hover_tween.kill()
	z_index = 10 if raised else 0
	pivot_offset = Vector2(size.x / 2.0, size.y)
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (1.065 if raised else 1.0), 0.14)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if payload.is_empty(): return null
	var preview := duplicate() as Control
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = -size / 2.0
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"worldplay_card": payload}

func _draw() -> void:
	if _stock == null: return
	_stock.modulate_color = Color(0.87, 0.94, 0.87, 1.0)
	_stock.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if is_hovered() or has_focus() or get_meta("fan_hovered",false):
		var edge: float = size.x-5 if get_meta("fan_stacked",false) and get_meta("fan_edge",-1)>0 and not get_meta("fan_focused",false) else 5.0
		draw_line(Vector2(edge, 10), Vector2(edge, size.y - 10), Paint.ACCENT, 2)
		draw_line(Vector2(6, 7), Vector2(34, 7), Paint.ACCENT, 1)
	if actionable:
		draw_line(Vector2(15, size.y - 7), Vector2(38, size.y - 7), Color(Paint.ACCENT, 0.7), 1)
