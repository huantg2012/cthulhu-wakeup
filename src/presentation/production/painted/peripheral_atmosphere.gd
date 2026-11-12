extends "res://docs/art/visual-generation/ui-study/peripheral_atmosphere.gd"
## One clock and one layered environment for the whole formal canvas.
const ProductionVeil = preload("res://src/presentation/production/painted/peripheral_veil.gdshader")
const ProductionSurface = preload("res://src/presentation/production/painted/peripheral_surface.gdshader")
const ProductionMist = preload("res://src/presentation/production/painted/peripheral_mist.gdshader")
enum Profile { FULL, QUIET, VEILED, STILL }
var _target := Vector2.ONE
var _strength := Vector2.ONE
var _protected: Array[Rect2] = []
var profile := Profile.FULL

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_add_wash(ProductionVeil)
	_carrier = Carrier.new()
	_carrier.paused = true
	_carrier.material = _make_material(ProductionSurface)
	add_child(_carrier)
	_add_wash(ProductionMist)
	_apply_protection()
	set_sample_time(elapsed)

func set_profile(value: Profile, protected: Array[Rect2]) -> void:
	profile = value
	paused = value == Profile.STILL
	if not paused:
		_target = [Vector2.ONE, Vector2(0.65, 0.38), Vector2(0.45, 0.18)][value]
	if _protected != protected:
		_protected = protected.duplicate()
		_apply_protection()

func _apply_protection() -> void:
	var uniforms: Array[Vector4] = []
	uniforms.resize(8)
	var count := mini(_protected.size(), uniforms.size())
	for i in count:
		var area := _protected[i]
		uniforms[i] = Vector4(area.position.x, area.position.y, area.end.x, area.end.y)
	for paint in _materials:
		paint.set_shader_parameter("protected_rects", uniforms)
		paint.set_shader_parameter("protected_count", count)

func _process(delta: float) -> void:
	if not paused:
		super._process(delta)
		var next := _strength.lerp(_target, 1.0 - exp(-delta * 7.0))
		if next.distance_squared_to(_target) < 0.00001: next = _target
		if _strength != next:
			_strength = next
			for paint in _materials:
				paint.set_shader_parameter("wash_strength", _strength.x)
				paint.set_shader_parameter("tissue_strength", _strength.y)
