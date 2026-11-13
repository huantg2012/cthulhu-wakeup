extends RefCounted
## Shared response for the tabletop and the world overview.
var amount := 0.0
var _hovered := false
var _tween: Tween

func set_hover(card: Control, hovered: bool, redraw: Callable) -> void:
	if hovered == _hovered: return
	_hovered = hovered
	if _tween != null: _tween.kill()
	_tween = card.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var motion: WeakRef = weakref(self)
	var update := func(value: float) -> void:
		var current = motion.get_ref()
		if current != null:
			current.amount = value
			redraw.call()
	if hovered:
		_tween.tween_method(update, amount, 1.65, 0.11)
		_tween.tween_method(update, 1.65, 1.0, 0.10)
	else:
		_tween.tween_method(update, amount, 0.0, 0.14)

func apply_transform(card: Control) -> void:
	card.pivot_offset = card.size * Vector2(0.5, 0.70)
	card.scale = Vector2.ONE * (1.0 + amount * 0.014)

func light() -> float:
	return 1.0 + amount * 0.07
