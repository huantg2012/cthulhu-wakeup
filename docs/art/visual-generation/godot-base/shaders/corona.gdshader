shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform int mode = 0;               // 0 恒星日冕 1 黑洞透镜 2 柔光
uniform vec3 col_a : source_color = vec3(1.0, 0.85, 0.5);
uniform vec3 col_b : source_color = vec3(1.0, 0.4, 0.1);
uniform float inner = 0.3;          // radius of body in quad units (0..0.5)
uniform float intensity = 1.0;
uniform float rays = 1.0;
uniform float seed = 0.0;
uniform float push_back = 0.0;

#include "res://shaders/common.gdshaderinc"

varying vec2 v_uv;

void vertex() {
	v_uv = VERTEX.xy * 2.0;   // quad mesh 1x1 -> [-1,1]
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 fwd = normalize(CAMERA_POSITION_WORLD - c);
	c -= fwd * push_back * sc;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * sc, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * sc, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * sc, 0.0), vec4(c, 1.0));
}

void fragment() {
	float r = length(v_uv);
	float a = atan(v_uv.y, v_uv.x);
	float rn = r / (inner * 2.0);          // 1.0 at body edge
	vec3 col = vec3(0.0);
	if (mode == 0) {
		float glow = exp(-(rn - 1.0) * 2.2) * 0.7 + exp(-(rn - 1.0) * 0.6) * 0.18;
		float ray = 0.0;
		float t = g_time * 0.05;
		ray += pow(fbm2(vec2(a * 4.0 + seed, t), 4) * 0.5 + 0.5, 3.0);
		ray += pow(abs(sin(a * 6.0 + seed + fbm2(vec2(a * 2.0, rn - t), 3) * 2.0)), 18.0) * 0.6;
		float rr = ray * exp(-(rn - 1.0) * 0.9) * rays;
		col = mix(col_b, col_a, exp(-(rn - 1.0) * 1.5)) * (glow + rr * 0.9);
		col *= smoothstep(1.0, 0.85, r);
	} else if (mode == 1) {
		// photon ring + lensed far side of the disk wrapping above / below the shadow
		float ring = exp(-pow((rn - 1.05) / 0.025, 2.0)) * 1.3 + exp(-pow((rn - 1.08) / 0.12, 2.0)) * 0.25;
		float yy = v_uv.y / (inner * 2.0);
		float lens_r = 1.25 + 0.55 * smoothstep(0.0, 1.0, abs(yy));
		float band = exp(-pow((rn - lens_r) / 0.28, 2.0)) * (yy > 0.0 ? 1.0 : 0.45);
		float swirl = fbm2(vec2(a * 3.0 + g_time * 0.4, rn * 6.0) + vec2(seed), 4) * 0.5 + 0.5;
		float vert = smoothstep(0.15, 0.85, abs(sin(a)));
		vec3 disk = mix(col_b, col_a, smoothstep(1.2, 2.0, 2.4 - rn)) * band * vert * (0.5 + swirl) * 0.9;
		col = col_a * ring + disk;
		col += col_b * exp(-(rn - 1.0) * 1.0) * 0.08;
		col *= smoothstep(1.0, 0.8, r);
	} else {
		float glow = exp(-r * r * 6.0) + exp(-r * 3.5) * 0.25;
		col = mix(col_b, col_a, exp(-r * 4.0)) * glow;
		col *= smoothstep(1.0, 0.85, r);
	}
	if (g_style == 5) { col = g_holo * luma3(col); }
	if (g_style == 6) { col *= 0.6; }
	ALBEDO = col * intensity;
}
