extends Control
signal card_dropped(card: Dictionary)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("worldplay_card") is Dictionary

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(data.worldplay_card)
