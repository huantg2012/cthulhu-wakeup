extends "res://tools/prayer-knowledge/source_cases.gd"
## All inherited Knowledge behavior/expected assertions remain unchanged.
## Only the newly explicit initialization boundary is added for Events worlds.

func _attach_notice_modules(data: Dictionary) -> void:
	super._attach_notice_modules(data)
	data["producer_notice_dream"] = super._payload(data, "POWER_DREAM")
	var result: Dictionary = data.turn.bootstrap_prayers()
	assert(result.get("ok", false))

func _payload(data: Dictionary, power: String) -> Dictionary:
	if power == "POWER_DREAM" and data.has("producer_notice_dream"): return data.producer_notice_dream.duplicate(true)
	return super._payload(data, power)
