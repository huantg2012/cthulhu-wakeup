extends Node
## Shared animation clock and interruptible property transitions.
var params: Dictionary = {}
var enabled := true
var elapsed := 0.0
var effects: Dictionary = {}
var materials: Array = []
func _ready() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/echoes-ui/tokens.json"))
	params = raw.get("motion", {}) if raw is Dictionary else {}
func register_material(owner: Node, material: ShaderMaterial) -> void:
	materials.append([weakref(owner),material])
func _process(delta: float) -> void:
	if enabled: elapsed += delta
	for key in effects.keys():
		if effects[key][1].get_ref() == null or not effects[key][0].is_valid(): effects.erase(key)
	for node: Node in get_tree().get_nodes_in_group("motion_retiring"):
		if node.modulate.a <= 0.001: node.queue_free()
	for i in range(materials.size()-1,-1,-1):
		if materials[i][0].get_ref() == null: materials.remove_at(i)
		elif not materials[i][0].get_ref() is CanvasItem or materials[i][0].get_ref().is_visible_in_tree(): materials[i][1].set_shader_parameter("motion_time",elapsed)
func animate(node: Object, property: String, target: Variant, duration: float, delay: float = 0.0) -> void:
	var key := str(node.get_instance_id()) + ":" + property
	if effects.has(key):
		var old: Tween = effects[key][0]
		if old.is_valid(): old.kill()
	if not enabled:
		node.set_indexed(NodePath(property),target)
		effects.erase(key)
		return
	var tween := create_tween()
	if node is Node: tween.bind_node(node)
	effects[key] = [tween,weakref(node),property,target]
	if delay > 0: tween.tween_interval(delay)
	tween.tween_property(node,property,target,duration)
	tween.finished.connect(func(): effects.erase(key))
func retire(node: Control, duration: float) -> void:
	for child: Node in node.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animate(node,"modulate:a",0.0,duration)
	node.add_to_group("motion_retiring")
func toggle() -> void:
	enabled = not enabled
	if not enabled:
		for effect in effects.values():
			var tween: Tween = effect[0]
			if tween.is_valid(): tween.kill()
			var node: Object = effect[1].get_ref()
			if node != null: node.set_indexed(NodePath(effect[2]),effect[3])
		effects.clear()
		for node: Node in get_tree().get_nodes_in_group("motion_retiring"):
			if is_instance_valid(node): node.queue_free()
