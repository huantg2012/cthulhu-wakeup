extends Control
signal card_dropped(card: Dictionary)

var accepts_card: Callable

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("worldplay_card") is Dictionary and accepts_card.is_valid() and accepts_card.call(data.worldplay_card)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data): card_dropped.emit(data.worldplay_card)
