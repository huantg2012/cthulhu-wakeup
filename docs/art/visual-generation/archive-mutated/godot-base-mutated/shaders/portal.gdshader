shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec3 col_a : source_color = vec3(0.4, 1.0, 0.7);
uniform vec3 col_b : source_color = vec3(0.5, 0.1, 0.7);
uniform vec3 col_c : source_color = vec3(1.0, 0.9, 0.6);
uniform float seed = 0.0;
uniform float eye_amt = 0.0;
uniform float spin = 0.25;

#include "res://shaders/common.gdshaderinc"

varying vec2 v_uv;
void vertex() {
	v_uv = VERTEX.xy * 2.0;
}

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 p = v_uv;
	float r = length(p);
	if (r > 1.0) { discard; }
	vec2 q = rot2(p, 2.4 / (r + 0.25) - g_time * spin);
	float n = fbm2(q * 2.6 + vec2(seed), 5);
	float n2 = fbm2(q * 6.0 - vec2(seed * 2.0), 4);
	vec3 col = mix(col_b * 0.08, col_b * 0.9, smoothstep(-0.25, 0.45, n));
	col = mix(col, col_a * 0.8, smoothstep(0.25, 0.6, n2) * 0.6);
	col *= 0.25 + 0.95 * smoothstep(0.0, 0.9, r);
	// distant alien stars streaking into the vortex
	vec2 sg = q * 18.0;
	vec2 id = floor(sg);
	vec2 f = fract(sg) - 0.5;
	float st = smoothstep(0.12, 0.0, length(f - (hash22(id) - 0.5) * 0.6)) * step(0.82, hash12(id + vec2(seed)));
	col += vec3(0.9, 0.95, 1.0) * st * smoothstep(0.1, 0.5, r);
	col += col_c * exp(-r * 7.0) * 1.3;
	col += col_a * smoothstep(0.82, 1.0, r) * 0.9;
	if (eye_amt > 0.0) {
		vec2 e = p / vec2(0.55, 0.32);
		float lid = max(1.0 - e.x * e.x, 0.0);
		float ins = (1.0 - smoothstep(-0.04, 0.04, abs(e.y) - lid * 0.9)) * step(abs(e.x), 1.0);
		float ir = length(p) / 0.26;
		float fib = gnoise3(vec3(atan(p.y, p.x) * 5.0, ir * 6.0, seed)) * 0.5 + 0.5;
		vec3 iris = mix(col_c * 0.4, col_c * 1.3, fib) * step(ir, 1.0);
		float pup = 1.0 - smoothstep(0.035, 0.06, abs(p.x)) ;
		pup *= step(ir, 0.95);
		vec3 sclera = mix(vec3(0.7, 0.65, 0.5), col_b * 0.6, 0.4);
		vec3 ec = mix(sclera, iris, step(ir, 1.0));
		ec = mix(ec, vec3(0.0), pup);
		col = mix(col, ec, ins * eye_amt);
	}
	if (g_style == 5) { col = g_holo * (luma3(col) * 1.1 + smoothstep(0.96, 1.0, r)); }
	ALBEDO = col;
}
