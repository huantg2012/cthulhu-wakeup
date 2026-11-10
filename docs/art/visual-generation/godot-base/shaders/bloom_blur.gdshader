shader_type canvas_item;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 s = vec3(0.0);
	float wsum = 0.0;
	for (int j = -4; j <= 4; j++) {
		for (int i = -4; i <= 4; i++) {
			vec2 o = vec2(float(i), float(j));
			float w = exp(-dot(o, o) / 8.0);
			s += textureLod(TEXTURE, UV + o * px * 1.6, 0.0).rgb * w;
			wsum += w;
		}
	}
	vec3 small = s / wsum;
	vec3 s2 = vec3(0.0);
	float w2 = 0.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			vec2 o = vec2(float(i), float(j));
			float w = exp(-dot(o, o) / 6.0);
			s2 += textureLod(TEXTURE, UV + o * px * 4.5, 0.0).rgb * w;
			w2 += w;
		}
	}
	COLOR = vec4(small * 0.65 + (s2 / w2) * 0.75, 1.0);
}
