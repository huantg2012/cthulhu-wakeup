extends SceneTree
## Focused public-receipt contract: a missing roll is not a deterministic check,
## and a successful unknown manifestation is not a promise of a good outcome.
const Receipt = preload("res://src/presentation/production/worldplay/prayer_receipt.gd")

class Feedback extends RefCounted:
	func resource_summary(_before, _after) -> String: return ""
	func build(_host, _response, _before, _after, _title) -> Array[String]: return []

class Host extends RefCounted:
	var _feedback := Feedback.new()

func _initialize() -> void:
	var host := Host.new()
	var count := 0
	var samples := [
		[{"roll":7,"success_target":64,"outcome":"deep"},"深刻成功",false,7,64],
		[{"roll":51,"probability":50,"outcome":"failure"},"失败",false,51,50],
		[{"roll":0,"probability":-1,"outcome":"success"},"成功",true,0,-1],
		[{"roll":7,"probability":64,"outcome":"deep","disclosure":"unknown"},"已显现",false,7,64],
		[{"outcome":"success"},"成功",false,0,-1],
		[{},"已回应",false,0,-1],
	]
	for sample: Array in samples:
		var data: Dictionary = sample[0].duplicate(true)
		data.request = "fixture"
		var response := {"ok":true,"facts":[{"kind":"prayer_space_result","changes":data}],"result":{"checks":[]}}
		var result: Dictionary = Receipt.build(host,response,{}, {"prayers":[]},"fixture","测试回应",false)
		if result.label!=sample[1] or result.no_roll!=sample[2] or result.roll!=sample[3] or result.target!=sample[4]:
			push_error("Wrong receipt interpretation: "+str(result))
			quit(1)
			return
		count += 1
	print("PRAYER_RECEIPT_OK ",count)
	quit()
