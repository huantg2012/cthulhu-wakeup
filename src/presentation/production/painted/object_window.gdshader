shader_type canvas_item;
render_mode unshaded;
varying float carrier_opacity;
void vertex() { carrier_opacity = COLOR.a; }
uniform sampler2D carrier_mask : filter_linear, repeat_disable;

float field(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 n = fract(sin(vec4(dot(i, vec2(127.1, 311.7)),
		dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)),
		dot(i + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

void fragment() {
	vec4 pigment = texture(TEXTURE, UV);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	// The same fixed stock silhouette plus unequal wash depths retires the
	// image border; no frame, colour key, blur, animated noise or RGB changes.
	float wash = field(UV * vec2(7.0, 5.0) + vec2(13.7, 8.3));
	float fibres = field(UV * vec2(71.0, 31.0));
	float limit = 0.012 + wash * 0.038;
	float coverage = smoothstep(limit - 0.012, limit + 0.014, edge + (fibres - 0.5) * 0.009);
	float stock = texture(carrier_mask, UV).a;
	COLOR = vec4(pigment.rgb, pigment.a * coverage * stock * carrier_opacity);
}
