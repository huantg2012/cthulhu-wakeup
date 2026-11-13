extends "res://src/presentation/production/worldplay/hand_fan.gd"
## World navigation uses the same stable shoulder browsing and damped lift as
## the hand. Only scale and activation differ: click / Enter opens a world.
signal card_chosen(index: int)

const CARD_SIZE := Vector2(260.0,390.0)
const WORLD_GAP := 28.0
var _press_was_focused := false

func _ready() -> void:
	allow_play = false
	super._ready()

func configure(new_cards: Array[Control]) -> void:
	allow_play = false
	super.configure(new_cards)

func _step() -> float:
	if cards.size() <= 1: return CARD_SIZE.x + WORLD_GAP
	return minf(CARD_SIZE.x + WORLD_GAP,maxf(0.0,size.x-16.0-CARD_SIZE.x)/float(cards.size()-1))

func _left() -> float:
	return (size.x-CARD_SIZE.x-float(maxi(0,cards.size()-1))*_step())*0.5

func _rest_y() -> float:
	return clampf(size.y-CARD_SIZE.y-8.0,0.0,58.0)

func is_stacked() -> bool:
	return cards.size()>1 and _step()<CARD_SIZE.x

func _layout_cards() -> void:
	if cards.is_empty() or _lifts.size()!=cards.size(): return
	var spacing := _step()
	var resting := _rest_y()
	var maximum_lift := _lift_height()
	for i: int in cards.size():
		var card: Control = cards[i]
		card.visible = true
		card.size = CARD_SIZE
		card.position = Vector2(_left()+float(i)*spacing,resting-_lifts[i])
		card.scale = Vector2.ONE
		card.rotation = 0.0
		card.z_index = 0
		card.modulate = Color.WHITE
		var exposed := minf(CARD_SIZE.x,spacing) if i<cards.size()-1 else CARD_SIZE.x
		card.set_exposure(-1 if exposed<CARD_SIZE.x else 0,exposed)
		card.set_peek_amount(_lifts[i]/maximum_lift if maximum_lift>0.0 else 0.0)
		card.set_meta("fan_stacked",is_stacked())
		card.set_meta("fan_focused",i==_browse_index)

func _card_at(pointer: Vector2) -> int:
	if not Rect2(Vector2.ZERO,size).has_point(pointer): return -1
	if pointer.y>=_rest_y() and pointer.y<_rest_y()+CARD_SIZE.y:
		for i: int in range(cards.size()-1,-1,-1):
			var width := minf(_step(),CARD_SIZE.x) if i<cards.size()-1 else CARD_SIZE.x
			var left := _left()+float(i)*_step()
			if pointer.x>=left and pointer.x<left+width: return i
		return -1
	for i: int in range(cards.size()-1,-1,-1):
		if cards[i].visible and cards[i].get_rect().has_point(pointer): return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if _blocked or cards.is_empty(): return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_press_was_focused = _card_at(event.position)==focus_index
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		card_chosen.emit(focus_index)
		accept_event()
		return
	super._gui_input(event)

func _finish_gesture(pointer: Vector2) -> void:
	var released := _card_at(pointer)
	var activate := not _dragging and released>=0 and released==_pressed_card and (not is_stacked() or _press_was_focused)
	super._finish_gesture(pointer)
	if activate: card_chosen.emit(released)
