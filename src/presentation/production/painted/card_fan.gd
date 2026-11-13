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
	if _blocked: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clear_hover()
	super._gui_input(event)

func _layout_cards() -> void:
	super._layout_cards()
	var stacked := is_stacked()
	for index: int in cards.size():
		var card: Control = cards[index]
		var hovered := card.visible and index == _hovered_card
		# The painted carrier used to lift a flat card in one step on entry.
		# Leave the hover lift to the tween and retain its keyboard focus offset.
		if hovered and not stacked and index != focus_index:
			card.position.y = maxf(0.0, (size.y - CARD_SIZE.y) * 0.5)
		card.set_card_hover(hovered)
		card.apply_card_hover()
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
		# The hit box follows the card layout, so the bounce itself cannot
		# steal the pointer from a neighbouring exposed edge.
		if Rect2(card.position, card.size).has_point(pointer): return cards.find(card)
	return -1
