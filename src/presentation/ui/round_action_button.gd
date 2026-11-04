extends Button
## Editable text and native input over an isolated illustrative ritual plaque.
const PLAQUE := "res://docs/art/echoes-ui/round-start-master/restoration-assets/round-ritual-plaque.png"
var plaque: Texture2D
var plaque_view: TextureRect
var keyboard_focus_query: Callable
var caption := "下一回合"
var caption_size := 21

func _ready() -> void:
	text = ""
	var source := Image.new()
	if source.load(PLAQUE) == OK:
		plaque = ImageTexture.create_from_image(source)
		plaque_view = TextureRect.new()
		plaque_view.name = "Plaque"
		plaque_view.texture = plaque
		plaque_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plaque_view.stretch_mode = TextureRect.STRETCH_SCALE
		plaque_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plaque_view.show_behind_parent = true
		plaque_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
 vec3 muted = mix(source.rgb, vec3(luminance), 0.46) * vec3(0.78, 0.84, 0.81);
 float fade_x = smoothstep(0.0, 0.27, UV.x) * (1.0 - smoothstep(0.73, 1.0, UV.x));
 float fade_y = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
 COLOR = vec4(muted * tint.rgb, source.a * fade_x * fade_y * tint.a);
}"""
		var material := ShaderMaterial.new()
		material.shader = shader
		plaque_view.material = material
		add_child(plaque_view)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	var keyboard_focus: bool = keyboard_focus_query.is_valid() and keyboard_focus_query.call()
	var active := is_hovered() or (keyboard_focus and has_focus())
	var tint := Color(1.13, 1.10, 1.02, 1.0) if active else Color(0.90, 0.87, 0.80, 0.96)
	if button_pressed:
		tint = Color(0.76, 0.72, 0.65, 1.0)
	if plaque_view != null:
		(plaque_view.material as ShaderMaterial).set_shader_parameter("tint", tint)
	if keyboard_focus and has_focus():
		draw_arc(size * Vector2(0.5, 0.31), 22.0, 0.0, TAU, 48, Color(0.75, 0.9, 0.85, 0.8), 1.5, true)
	var font := get_theme_default_font()
	var label := caption
	var font_size := caption_size
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2((size.x - width) * 0.5, size.y * 0.54 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.02, 0.02, 0.015, 0.85))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.88, 0.70))
