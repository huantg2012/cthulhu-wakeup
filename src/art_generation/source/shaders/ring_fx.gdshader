shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;               // 0 orbit line, 1 sigil circle, 2 accretion disk
uniform vec3 col_a : source_color = vec3(0.4, 1.0, 0.7);
uniform vec3 col_b : source_color = vec3(1.0, 0.5, 0.2);
uniform float intensity = 1.0;
uniform float inner = 0.25;
uniform float seed = 0.0;
uniform float spin = 0.1;
uniform float line_px = 1.2;
uniform float dash = 0.0;

#include "res://src/art_generation/source/shaders/common.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_wpos;
void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float circle_line(float r, float at, float px) {
	float fw = fwidth(r);
	return 1.0 - smoothstep(px * 0.5 * fw, (px * 0.5 + 1.0) * fw, abs(r - at));
}

void fragment() {
	float r = length(v_obj.xz);
	float ang = atan(v_obj.z, v_obj.x);
	vec3 col = vec3(0.0);
	if (mode == 0) {
		float l = circle_line(r, 0.985, line_px);
		if (dash > 0.0) {
			l *= step(0.45, fract(ang / TAU * dash + g_time * 0.02));
		}
		col = col_a * l;
		if (g_style == 5) {
			float tick = step(0.94, fract(ang / TAU * 72.0)) * (1.0 - smoothstep(0.0, fwidth(r) * 6.0, abs(r - 0.97)));
			col = g_holo * (l + tick * 0.7);
		}
	} else if (mode == 1) {
		float rot = g_time * spin;
		float a2 = ang + rot;
		float l = circle_line(r, 0.98, line_px) + circle_line(r, 0.86, line_px * 0.7) + circle_line(r, 0.66, line_px)
			+ circle_line(r, 0.56, line_px * 0.6) * 0.8 + circle_line(r, 0.3, line_px * 0.8);
		// rune band between 0.9 and 0.98 (wait: use 0.64..0.88)
		float ncell = 56.0;
		float gx = (a2 / TAU + 0.5) * ncell;
		float gy = (r - 0.7) / 0.13;
		float gd = glyph_dist(vec2(fract(gx), gy), floor(gx) + seed * 17.0);
		float fw = fwidth(gx);
		float g = (1.0 - smoothstep(0.035, 0.035 + fw * 0.8 + 0.015, gd)) * step(0.0, gy) * step(gy, 1.0);
		// star polygon (heptagram) strokes
		float star = 0.0;
		for (int k = 0; k < 7; k++) {
			float a0 = float(k) * TAU / 7.0 - rot * 0.5;
			float a1 = float(k + 3) * TAU / 7.0 - rot * 0.5;
			vec2 p0 = vec2(cos(a0), sin(a0)) * 0.56;
			vec2 p1 = vec2(cos(a1), sin(a1)) * 0.56;
			float d = sd_segment(v_obj.xz, p0, p1);
			star = max(star, 1.0 - smoothstep(fwidth(r) * line_px * 0.4, fwidth(r) * (line_px * 0.4 + 1.0), d));
		}
		// small glyphs on the inner ring
		float gx2 = (-a2 * 1.0 / TAU + 0.5) * 16.0;
		float gy2 = (r - 0.33) / 0.17;
		float gd2 = glyph_dist(vec2(fract(gx2), gy2), floor(gx2) + seed * 29.0 + 100.0);
		float g2 = (1.0 - smoothstep(0.04, 0.04 + fwidth(gx2) + 0.015, gd2)) * step(0.0, gy2) * step(gy2, 1.0);
		float flick = 0.85 + 0.15 * sin(g_time * 3.0 + ang * 5.0);
		col = mix(col_a, col_b, smoothstep(0.3, 0.9, r)) * (l + g + star * 0.8 + g2) * flick;
		col += col_a * exp(-abs(r - 0.94) * 30.0) * 0.08;
		if (g_style == 5) { col = g_holo * luma3(col) * 1.2; }
	} else {
		// accretion disk
		float f = (r - inner) / (1.0 - inner);
		if (f < 0.0) { discard; }
		float sw = ang + g_time * spin / (0.25 + f) ;
		float sp = fbm2(vec2(sw * 3.0 / TAU * 6.0, f * 7.0 - g_time * 0.1) + vec2(seed), 5);
		float streak = fbm2(vec2(cos(sw) * 2.0 + f * 30.0, sin(sw) * 2.0), 4);
		float dens = (0.55 + 0.45 * sp + streak * 0.3) * smoothstep(0.0, 0.05, f) * pow(1.0 - f, 1.8);
		float temp = pow(1.0 - f, 2.5);
		vec3 c = mix(col_b, col_a, temp);
		c = mix(c, vec3(1.0, 0.97, 0.9), temp * temp * 0.7);
		// doppler beaming: tangent velocity vs view
		vec3 tang = normalize(mat3(MODEL_MATRIX) * vec3(-v_obj.z, 0.0, v_obj.x));
		vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
		float dop = 1.0 + 0.75 * dot(tang, V);
		col = c * dens * dop * 2.0;
		if (g_style == 5) { col = g_holo * luma3(col); }
	}
	ALBEDO = col * intensity;
}
