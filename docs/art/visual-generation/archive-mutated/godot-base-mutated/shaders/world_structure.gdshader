shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// 实体巨构材质。两种几何：
//   kind 0 = Ring 连续环带（轨道环 / 环世界）
//   kind 1 = Planet 球壳，被切成几条连续大弧带并逐层径向拉开、错转 —— 行星被拆得面目全非
// 不透明、有解析明暗、金属表面、厚度边与桁架开口；不是加法发光线框，不是散落碎片。
global uniform float g_time;

// 只取噪声算子；不 include common，避免重复声明全局 uniform
#include "res://shaders/noise.gdshaderinc"

uniform int kind = 0;
uniform int tf_arch = 0;
uniform float pull = 0.42;       // 拆解拉开程度
uniform vec3 struct_col : source_color = vec3(0.72, 0.80, 0.86);
uniform vec3 glow_col : source_color = vec3(0.45, 1.0, 0.82);
uniform float seed_off = 0.0;

varying vec3 v_obj;
varying vec3 v_wpos;
varying vec3 v_wn;
varying float v_band;
varying float v_edge;

float band_coord(vec3 q) {
	if (tf_arch == 0) {
		return fract(atan(q.z, q.x) / TAU * 3.0 + q.y * 1.1);   // 螺旋带
	} else if (tf_arch == 1) {
		return q.y * 0.5 + 0.5;                                     // 水平层带
	} else if (tf_arch == 2) {
		return abs(q.y);                                             // 同心环带
	}
	return fract(voronoi3(q * 3.0 + vec3(seed_off)).z);             // 大胞格带
}

void vertex() {
	vec3 q = normalize(VERTEX);
	v_obj = q;
	v_band = 0.0;
	v_edge = 0.0;
	vec3 d = q;
	if (kind == 1) {
		float bc = band_coord(q);
		float band = floor(bc * 4.0);
		v_band = band;
		v_edge = fract(bc * 4.0);
		float spin = band * 0.28 + seed_off * 0.5;
		d.xz = mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin))) * d.xz;
		// 每层推到不同半径，层与层明显错开；仍是整圈连续壳带
		d *= 1.0 + pull * (0.12 + 0.20 * band);
	}
	VERTEX = d;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float t = g_time;
	vec3 N = normalize(v_wn);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_wpos);
	vec3 L = normalize(vec3(0.48, 0.66, 0.58));
	float fres = pow(1.0 - abs(dot(N, V)), 2.2);

	float a = 0.0;
	float band = 0.0;
	float radial = 0.0;
	if (kind == 0) {
		a = atan(v_obj.y, v_obj.x) / TAU + 0.5;
		radial = length(v_obj.xy);
		band = fract((radial - 0.2) / 0.8 * 2.0 + seed_off * 0.1);
	} else {
		// 带与带之间是真的空隙：球壳已被切开
		if (v_edge < 0.16 || v_edge > 0.84) discard;
		a = atan(v_obj.z, v_obj.x) / TAU + 0.5;
		band = v_edge;
		radial = 0.5 + 0.5 * sin(a * TAU * 4.0);
	}

	float segN = (tf_arch == 1) ? 6.0 : 8.0;
	float seg = fract(a * segN);
	float seam = 1.0 - smoothstep(0.006, 0.022, abs(seg - 0.5));
	float rib = 1.0 - smoothstep(0.006, 0.020, abs(band - 0.5));
	float panel = 0.5 + 0.5 * sin(a * TAU * (segN * 0.25) + band * TAU);
	float plate = step(0.5, fract(floor(a * segN) * 0.37 + floor(band * 3.0) * 0.23));
	float beam = 1.0 - smoothstep(0.0, 0.035, abs(fract(a * segN * 0.5) - 0.5));

	// 桁架窗：实体上开有规律的开口，不是线框、不是实心盘
	float thrA = (kind == 1) ? 0.66 : 0.74;
	float thrB = (kind == 1) ? 0.64 : 0.72;
	float winA = step(thrA, fract(a * segN + seed_off));
	float winB = step(thrB, band);
	if (winA * winB > 0.5 && abs(seg - 0.5) > 0.14) discard;

	float face = 0.58 + 0.42 * max(dot(N, L), 0.0);
	float rimIn = 1.0 - smoothstep(0.0, 0.06, abs(radial - 0.22));
	float rimOut = 1.0 - smoothstep(0.0, 0.06, abs(radial - 0.98));
	float thick = rimIn * 0.55 + rimOut * 0.85;
	// 切开的断口：每层壳带的边是厚的、亮的，能读出这是被切开的行星
	float cut = (kind == 1) ? (1.0 - smoothstep(0.16, 0.24, min(v_edge, 1.0 - v_edge))) : 0.0;

	vec3 metal = struct_col * (0.16 + 0.34 * panel + 0.20 * plate + 0.08 * radial) * face;
	metal *= 1.0 - seam * 0.80 - rib * 0.52;
	metal += struct_col * (beam * 0.30 + thick * 0.36 + cut * 0.55) * face;
	metal += vec3(0.055, 0.062, 0.070) * face;
	float grain = 0.5 + 0.5 * sin(a * 340.0 + band * 190.0 + seed_off * 20.0);
	metal *= 0.92 + 0.10 * grain;
	metal += glow_col * seam * (0.06 + 0.05 * sin(t * 0.7 - a * TAU * 3.0));
	metal += glow_col * fres * 0.10;
	ALBEDO = clamp(metal, 0.0, 1.15);
}
