extends RefCounted
## Small row thumbnails preserve the source painting without a square frame.
const ShaderSource = preload("res://src/presentation/production/painted/object_window.gdshader")
const Stock = preload("res://assets/ui/cards/continuous-stock.png")
static var _material: ShaderMaterial

static func style(slot: TextureRect) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = ShaderSource
		_material.set_shader_parameter("carrier_mask", Stock)
	slot.material = _material
	slot.modulate = Color.WHITE
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
