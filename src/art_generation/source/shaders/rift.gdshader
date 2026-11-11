shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 edge_col : source_color = vec3(0.6, 1.0, 0.7);
uniform vec3 inner_col : source_color = vec3(0.6, 0.1, 0.8);
uniform vec3 eye_col : source_color = vec3(1.0, 0.8, 0.2);
uniform float seed = 0.0;
uniform float open_amt = 1.0;
uniform float eyes = 1.0;

#include "res://src/art_generation/source/shaders/common.gdshaderinc"

varying vec2 v_uv;
void vertex() {
	v_uv = VERTEX.xy * 2.0;
}

void fragment() {
	vec2 p = v_uv;
	float y = p.y;
	float jag = fbm2(vec2(y * 6.0 + seed, seed * 2.0), 5) * 0.12 + fbm2(vec2(y * 25.0, seed), 3) * 0.03;
	float w = 0.34 * open_amt * pow(max(1.0 - y * y, 0.0), 0.8);
	float bend = sin(y * 2.4 + seed) * 0.12 + jag;
	float dx = abs(p.x - bend) - w;
	float inside = 1.0 - smoothstep(-0.01, 0.01, dx);
	float edge = exp(-max(dx, 0.0) * 18.0) * smoothstep(1.0, 0.85, abs(y));
	float far = exp(-max(dx, 0.0) * 4.0) * smoothstep(1.0, 0.6, abs(y));
	vec2 q = vec2((p.x - bend) / max(w, 0.02), y);
	float swirl = fbm2(q * vec2(1.5, 3.0) + vec2(g_time * 0.1, -g_time * 0.15) + seed, 5);
	vec3 col = mix(vec3(0.0), inner_col * 0.7, smoothstep(-0.2, 0.6, swirl));
	// eyes inside the rift
	if (eyes > 0.0) {
		vec2 g = vec2(q.x * 1.2, y * 6.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float hh = hash12(id + seed);
		if (hh < 0.55 * eyes && abs(id.x) < 1.0) {
			vec2 o = (hash22(id + seed + 3.0) - 0.5) * 0.3;
			vec2 e = (f - o) / vec2(0.36, 0.2);
			float blink = smoothstep(0.95, 1.0, sin(g_time * 0.6 + hh * 50.0));
			float lid = (1.0 - blink) * max(1.0 - e.x * e.x, 0.0);
			float ins = (1.0 - smoothstep(-0.05, 0.05, abs(e.y) - lid)) * step(abs(e.x), 1.0);
			float ir = length(e * vec2(1.0, 0.55));
			float pup = 1.0 - smoothstep(0.08, 0.14, abs(e.x) * 1.6);
			vec3 ec = mix(eye_col * 1.2, eye_col * 0.4, smoothstep(0.0, 0.6, ir));
			ec = mix(ec, vec3(0.0), pup * step(ir, 0.6));
			col = mix(col, ec, ins * step(ir, 0.62));
		}
	}
	col = mix(col, edge_col * 1.4, smoothstep(-0.06, 0.0, dx) * inside);
	vec3 glow = edge_col * (edge * 0.9 + far * 0.25);
	float a = clamp(inside + edge + far * 0.4, 0.0, 1.0);
	vec3 outc = mix(glow / max(a, 0.001), col, inside);
	if (g_style == 5) { outc = g_holo * luma3(outc) * 1.3; }
	ALBEDO = outc;
	ALPHA = a * smoothstep(1.0, 0.9, abs(y)) * smoothstep(1.0, 0.8, abs(p.x));
}
