shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 pigment = texture(TEXTURE, UV);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	COLOR = vec4(pigment.rgb, pigment.a * smoothstep(0.0, 0.04, edge));
}
