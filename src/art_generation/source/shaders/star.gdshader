shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform int stype = 0;              // 0 燃烧之星 1 黑日 2 眼之星 3 苍白残星 4 黑洞(纯黑)
uniform vec3 hot : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 cool : source_color = vec3(1.0, 0.45, 0.15);
uniform vec3 accent : source_color = vec3(0.5, 1.0, 0.6);
uniform vec3 seed_off = vec3(0.0);

#include "res://src/art_generation/source/shaders/common.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_wpos;

void vertex() {
	v_obj = normalize(VERTEX);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 C = MODEL_MATRIX[3].xyz;
	vec3 Nn = normalize(v_wpos - C);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	float ndv = clamp(dot(Nn, V), 0.0, 1.0);
	vec3 q = v_obj * 3.0 + seed_off;
	float t = g_time * 0.08;
	vec3 w = q + 0.4 * vec3(fbm3(q + vec3(t), 3), fbm3(q + vec3(4.0, -t, 1.0), 3), fbm3(q + vec3(9.0, 2.0, t), 3));
	vec4 vo = voronoi3(w * 3.0);
	float gran = smoothstep(0.0, 0.6, vo.y - vo.x);
	float spots = smoothstep(0.25, 0.4, fbm3(q * 0.6 + vec3(t * 0.5), 4));
	float limb = pow(ndv, 0.45);
	vec3 col;
	if (stype == 0 || stype == 2 || stype == 3) {
		vec3 base = mix(cool, hot, gran * 0.7 + 0.3 * limb);
		base *= mix(1.0, 0.35, spots);
		col = base * (0.5 + 0.45 * limb);
		col = mix(col, vec3(1.0), pow(limb, 4.0) * 0.25);
		if (stype == 3) { col = mix(vec3(luma3(col)), col, 0.35) * 0.9; }
		if (stype == 2) {
			// giant pupil staring at viewer
			vec3 ed = V;
			vec3 up = vec3(0.0, 1.0, 0.0);
			vec3 eu = normalize(cross(up, ed));
			vec3 ev = cross(ed, eu);
			vec2 e = vec2(dot(Nn, eu), dot(Nn, ev));
			float pup = 1.0 - smoothstep(0.9, 1.05, length(e / vec2(0.11, 0.55)));
			float iris = 1.0 - smoothstep(0.62, 0.68, length(e));
			float fib = gnoise3(vec3(atan(e.y, e.x) * 6.0, length(e) * 8.0, 0.0) + seed_off) * 0.5 + 0.5;
			float fib2 = gnoise3(vec3(atan(e.y, e.x) * 17.0, length(e) * 20.0, 3.0) + seed_off) * 0.5 + 0.5;
			vec3 irc = accent * (0.35 + 0.65 * fib) * (0.7 + 0.5 * fib2);
			irc *= mix(1.0, 0.35, smoothstep(0.45, 0.66, length(e)));
			col = mix(col, irc, iris);
			col = mix(col, col * 0.35, (1.0 - iris) * 0.4);
			col *= 1.0 - pup;
		}
	} else if (stype == 1) {
		float crack = 1.0 - smoothstep(0.0, 0.05, vo.y - vo.x);
		col = vec3(0.004, 0.0, 0.004) + cool * crack * 0.35 * (0.5 + 0.5 * sin(g_time + vo.z * 30.0));
		col += hot * pow(1.0 - ndv, 6.0) * 1.2;
	} else {
		col = vec3(0.0);
		col += accent * pow(1.0 - ndv, 12.0) * 0.4;
	}
	if (g_style == 5) {
		col = g_holo * (luma3(col) * 0.6 + pow(1.0 - ndv, 2.0) * 0.8);
	}
	ALBEDO = col;
}
