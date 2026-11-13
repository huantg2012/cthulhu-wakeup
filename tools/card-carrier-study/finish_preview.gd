extends "res://tools/card-carrier-study/category_preview.gd"
## A bounded material proof using the exact production carrier and hand.
## Run with --probe --output=...; no Session or gameplay actions are created.
func _probe() -> void:
	_set_count(5)
	_fan.set_focus(1)
	await _settle(0.3)
	await _capture("flat-cards.png")
	_set_count(48)
	_fan.set_focus(1)
	await _settle(0.3)
	await _capture("dense-cards.png")
	_set_count(18)
	_place({"sample_index":1,"id":"1"})
	_fan.set_focus(4)
	await _settle(0.3)
	await _capture("full-and-hand.png")
