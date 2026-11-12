extends SceneTree
var view: Control
func _initialize() -> void: call_deferred("run")
func capture(name_value: String) -> void:
	view._capture_path = "res://docs/art/visual-generation/worldplay-study/evidence/"+name_value+".png"
	await view._capture_when_ready()
func run() -> void:
	root.add_child(load("res://docs/art/visual-generation/worldplay-study/worldplay.tscn").instantiate())
	view = root.get_node("GameRoot/Presentation/CanvasLayer/OverlayRoot")
	root.size = Vector2i(1920,1080)
	await process_frame
	await capture("four-zone-world")
	view._enter_cult("CULT/DOMAIN-001")
	view._play_card(view._deck.filter(func(card: Dictionary)->bool:return card.id=="order/CULT/DOMAIN-001/expand")[0])
	await capture("four-zone-cult")
	view._open_library("power")
	view._play_card(view._deck.filter(func(card: Dictionary)->bool:return card.id=="record/POWER_ANCHOR")[0])
	await capture("four-zone-library")
	quit()
