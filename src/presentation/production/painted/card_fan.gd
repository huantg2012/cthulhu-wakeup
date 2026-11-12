extends "res://docs/art/visual-generation/ui-study/card_fan.gd"
## The approved carrier owns geometry and gestures. Production adds modal
## isolation and uses sibling draw order so cards never escape their layer.
var _blocked := false

func set_blocked(value: bool) -> void:
	if _blocked == value: return
	_blocked = value
	if value:
		_pressed = false
		_dragging = false
		_clear_hover()

func _gui_input(event: InputEvent) -> void:
	if not _blocked: super._gui_input(event)

func _layout_cards() -> void:
	super._layout_cards()
	var drawing_order: Array[Control] = cards.filter(func(card: Control) -> bool: return card.visible)
	drawing_order.sort_custom(func(a: Control, b: Control) -> bool:
		return a.z_index < b.z_index if a.z_index != b.z_index else cards.find(a) < cards.find(b))
	for card: Control in drawing_order:
		card.z_index = 0
		if card.get_index() != get_child_count() - 1: move_child(card, -1)

func _card_at(pointer: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(pointer): return -1
	for order: int in range(get_child_count() - 1, -1, -1):
		var card := get_child(order) as Control
		if card == null or not card.visible or card.modulate.a < 0.2: continue
		var local := card.get_transform().affine_inverse() * pointer
		if Rect2(Vector2.ZERO, card.size).has_point(local): return cards.find(card)
	return -1
