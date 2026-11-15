shader_type canvas_item;
render_mode unshaded;

float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
	vec4 ink = COLOR;
	float g = grain(floor(FRAGCOORD.xy));
	float drag = grain(floor(FRAGCOORD.xy * vec2(.13,.47)));
	ink.rgb *= .86 + .18 * g + .05 * drag;
	ink.a *= .83 + .17 * step(.13,g);
	COLOR = ink;
}
