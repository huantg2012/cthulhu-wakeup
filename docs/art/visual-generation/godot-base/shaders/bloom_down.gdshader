shader_type canvas_item;
uniform float threshold = 0.62;
uniform float knee = 0.3;
uniform vec2 src_px = vec2(0.001);
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec3 c = vec3(0.0);
	c += textureLod(TEXTURE, UV + src_px * vec2(-1.0, -1.0), 0.0).rgb;
	c += textureLod(TEXTURE, UV + src_px * vec2(1.0, -1.0), 0.0).rgb;
	c += textureLod(TEXTURE, UV + src_px * vec2(-1.0, 1.0), 0.0).rgb;
	c += textureLod(TEXTURE, UV + src_px * vec2(1.0, 1.0), 0.0).rgb;
	c *= 0.25;
	float l = max(max(c.r, c.g), c.b);
	float w = smoothstep(threshold - knee, threshold + knee, l);
	COLOR = vec4(c * w, 1.0);
}
