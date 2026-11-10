shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

global uniform float g_time;

uniform vec3 core_col : source_color = vec3(0.42, 0.70, 1.0);

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	// 母星被掏空后剩下的核：没有居民、没有用途，只有缓慢的呼吸
	// 正面中心最亮、边缘淡出：被掏空后剩下的核，不是暗球
	float f = pow(max(dot(normalize(v_dir), vec3(0.0, 0.0, 1.0)), 0.0), 1.5);
	float breath = 0.55 + 0.45 * sin(g_time * 0.7);
	ALBEDO = core_col * (0.20 + f * 0.95) * breath;
}
