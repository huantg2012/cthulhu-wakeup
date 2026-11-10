shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

// 母星改造内容层 v3：原型 × 工程能力等级。
// 工程依据：星球级＝地表薄层改造；星系级＝可调动行星级能量的地壳剥离／全球开挖；
// 宇宙级＝把行星当原料整体拆解为非球构造（壳世界 / 轨道环 / 戴森云式散件）。
// 不做盈亏：全域均匀照明，没有昼夜半球造成的相位感。
// 不使用原作 ARCH 名称 / scene / composition / star_type / wonder / rings / eyes。
#include "res://shaders/common.gdshaderinc"

uniform int tf_level = 0;   // 0 星球级 / 1 星系级 / 2 宇宙级
uniform int tf_arch = 0;    // 0 潮界 / 1 层台 / 2 陨野 / 3 菌原
uniform int tf_shard = 0;   // 宇宙级拆下的独立壳片构件
uniform vec3 seed_off = vec3(0.0);
uniform vec3 c0 : source_color = vec3(0.012, 0.035, 0.045);
uniform vec3 c1 : source_color = vec3(0.035, 0.140, 0.160);
uniform vec3 c2 : source_color = vec3(0.100, 0.320, 0.300);
uniform vec3 c3 : source_color = vec3(0.420, 0.520, 0.400);
uniform vec3 c4 : source_color = vec3(0.550, 1.000, 0.720);
uniform vec3 atmo_col : source_color = vec3(0.30, 0.84, 0.63);
uniform vec3 struct_col : source_color = vec3(0.95, 0.78, 0.42);

varying vec3 v_dir;
varying vec3 v_wpos;
varying float v_shell;

vec3 terra_ramp(float t) {
	t = clamp(t, 0.0, 1.0) * 3.0;
	vec3 a = mix(c0, c1, clamp(t, 0.0, 1.0));
	a = mix(a, c2, clamp(t - 1.0, 0.0, 1.0));
	return mix(a, c3, clamp(t - 2.0, 0.0, 1.0));
}
vec3 warp3(vec3 q, float f, float amt) {
	return q + amt * vec3(fbm3(q * f + vec3(11.0), 3),
						  fbm3(q * f + vec3(23.0), 3),
						  fbm3(q * f + vec3(37.0), 3));
}

// ---- ① 统一 Surf 契约：每个原型一份结构性不同的场配方 ----
void surface(vec3 p, vec3 q, out vec3 alb, out float h, out float land,
			 out float keyline, out float keyid) {
	vec3 w = q + 0.24 * vec3(fbm3(q * 1.5, 4), fbm3(q * 1.5 + vec3(5.2), 4), fbm3(q * 1.5 + vec3(9.1), 4));
	float lon = atan(p.z, p.x);
	alb = vec3(0.1); h = 0.0; land = 1.0; keyline = 0.0; keyid = 0.0;
	if (tf_arch == 0) {
		// 潮界：域扭曲 + 海平面阈值 + 对数螺旋洋流 + Voronoi 石缝
		float turb = fbm3(warp3(q, 1.2, 0.26) * 2.2, 5);
		vec4 vo = voronoi3(w * 7.0);
		float stone = 1.0 - smoothstep(0.0, 0.06, vo.y - vo.x);
		h = turb - stone * 0.06;
		land = smoothstep(-0.03, 0.01, h);
		float swirl = sin(lon * 3.0 + log(length(p.xz) + 0.16) * 9.0 - g_time * 0.05);
		alb = mix(terra_ramp(0.12) * (0.55 + 0.25 * swirl), terra_ramp(clamp(0.46 + h * 0.9, 0.0, 1.0)), land);
		alb += vec3(0.06, 0.14, 0.16) * stone;
		keyline = (1.0 - smoothstep(0.0, 0.030, abs(h))) * 0.9 + stone * 0.25;
		keyid = fract(swirl * 0.5 + 0.5);
	} else if (tf_arch == 1) {
		// 层台：高度量化台地 + 雪线 + 脊线裂纹
		float terr = fbm3(w * 2.0, 5);
		float qh = floor(terr * 7.0 + 0.5) / 7.0;
		float crack = pow(1.0 - abs(gnoise3(w * 9.0)), 13.0);
		h = qh + crack * 0.05;
		land = smoothstep(0.30, 0.72, abs(p.y));
		vec3 rock = terra_ramp(clamp(0.42 + qh * 0.9, 0.0, 1.0)) + vec3(0.10) * crack;
		alb = mix(rock, vec3(0.66, 0.72, 0.70), land * 0.72);
		keyline = clamp((1.0 - smoothstep(0.0, 0.045, abs(fract(terr * 7.0) - 0.5) - 0.40)) * 0.85 + crack * 0.6, 0.0, 1.0);
		keyid = fract(qh * 3.0 + 0.5);
	} else if (tf_arch == 2) {
		// 陨野：双层解析陨坑 + 环脊
		vec4 vo = voronoi3(q * 4.3 + vec3(2.0)), vo2 = voronoi3(q * 9.1 + vec3(7.0));
		float rr = 0.20 + 0.34 * vo.z, d = vo.x / rr;
		float crater = d < 1.0 ? (d * d - 1.0) * 0.28 : 0.0;
		float rim = exp(-pow((d - 1.0) / 0.16, 2.0)) * 0.12;
		float rr2 = 0.09 + 0.15 * vo2.z, d2 = vo2.x / rr2;
		h = crater + rim + (d2 < 1.0 ? (d2 * d2 - 1.0) * 0.10 : 0.0);
		land = fbm3(w * 3.0, 3) * 0.5 + 0.5;
		alb = mix(vec3(0.13, 0.12, 0.13), vec3(0.40, 0.37, 0.34), clamp(h * 2.0 + 0.5, 0.0, 1.0)) * (0.78 + 0.35 * land);
		keyline = clamp(rim * 7.0 + (1.0 - smoothstep(0.0, 0.05, abs(d - 1.0))) * 0.7, 0.0, 1.0);
		keyid = fract(vo.z + vo2.z);
	} else {
		// 菌原：Voronoi 细胞斑 + 血管脊线 + 余弦调色板
		vec4 vo = voronoi3(w * 5.6 + vec3(3.0));
		float cell = vo.z, seam = 1.0 - smoothstep(0.0, 0.075, vo.y - vo.x);
		float vein = pow(1.0 - abs(gnoise3(w * 3.4 + vec3(0.0, g_time * 0.06, 0.0))), 12.0);
		float breath = 0.5 + 0.5 * sin(g_time * 0.8 + cell * 19.0);
		h = (cell - 0.5) * 0.35 + vein * 0.10 - seam * 0.06;
		land = smoothstep(0.32, 0.68, cell);
		vec3 iri = 0.5 + 0.5 * cos(TAU * (fract(cell * 0.8 + g_time * 0.012) + vec3(0.0, 0.33, 0.67)));
		alb = mix(terra_ramp(0.22), terra_ramp(0.68), cell) * (0.55 + iri * 0.9) * (0.72 + 0.35 * breath) + vec3(0.12, 0.18, 0.10) * seam;
		keyline = clamp(seam * 0.85 + vein * 0.55, 0.0, 1.0);
		keyid = cell;
	}
	alb = clamp(alb, 0.0, 1.0);
	keyline = clamp(keyline, 0.0, 1.0);
}

// ---- ② 破坏性开挖场：按原型决定从哪里、以什么形状剥离地壳 ----
float excavation(vec3 p, vec3 q) {
	float lon = atan(p.z, p.x);
	float n = fbm3(q * 1.9, 3);
	if (tf_arch == 0) {
		// 潮界：沿螺旋洋流带抽干海水、剥去水层，露出海底盆地
		return smoothstep(-0.18, 0.34, sin(lon * 2.0 + log(length(p.xz) + 0.16) * 8.0) + n * 0.75);
	} else if (tf_arch == 1) {
		// 层台：整层地壳被阶梯状剥离，露出地幔
		return smoothstep(0.26, 0.70, fract(p.y * 4.5 + n * 0.8) + n * 0.55);
	} else if (tf_arch == 2) {
		// 陨野：沿坑环挖穿地壳成巨型竖井
		return smoothstep(0.24, 0.68, voronoi3(q * 4.3 + vec3(2.0)).z + n * 0.85);
	}
	// 菌原：沿细胞边界把地壳整块掀起、翻开
	return smoothstep(0.28, 0.70, voronoi3(q * 5.6 + vec3(3.0)).z + n * 0.80);
}

// ---- ③ 露出的内层：每个原型的材料不同 ----
vec3 innerLayer(vec3 p, vec3 q, float cut) {
	float strata = fract(q.y * 11.0 + fbm3(q * 3.0, 3) * 1.5);
	if (tf_arch == 0) {
		// 盐渍海底盆地 + 残水
		return mix(vec3(0.05, 0.09, 0.13), vec3(0.52, 0.60, 0.58), smoothstep(0.25, 0.75, strata)) * 0.95;
	} else if (tf_arch == 1) {
		// 地幔层理 + 熔光
		return mix(vec3(0.16, 0.08, 0.07), vec3(0.96, 0.40, 0.13), smoothstep(0.30, 0.72, strata)) * 1.05;
	} else if (tf_arch == 2) {
		// 挖穿后的深井 + 断面熔光
		return vec3(0.025, 0.020, 0.025) + vec3(0.80, 0.32, 0.10) * pow(smoothstep(0.75, 1.0, strata), 2.0);
	}
	// 生物质内层
	return vec3(0.08, 0.24, 0.09) + vec3(0.42, 0.92, 0.22) * smoothstep(0.35, 0.80, strata) * 0.75;
}

void vertex() {
	vec3 q = normalize(VERTEX);
	v_dir = q;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_shell = 0.0;
	if (tf_level == 1 && tf_shard == 0) {
		// 全球重构：壳面整体外凸一点点做出面板厚度，不挖洞、不留缺口
		float ridge = sin(atan(q.z, q.x) * 16.0) * sin(q.y * 11.0);
		VERTEX = q * (1.0 + 0.012 * ridge);
	}
	if (tf_level == 2 && tf_shard == 0) {
		// 兼容旧路径；正式宇宙级由 generator 装配独立构件，不再出现完整球
		float lon = atan(q.z, q.x), band = 0.0, panel = 0.0;
		if (tf_arch == 0) { band = floor(lon / TAU * 8.0 + q.y * 3.0); panel = floor(q.y * 9.0); }
		else if (tf_arch == 1) { band = floor((q.y + 1.0) * 7.0); panel = floor((lon + PI) / TAU * 14.0); }
		else if (tf_arch == 2) { band = floor(length(q.xz) * 6.0 + q.y * 2.0); panel = floor((lon + PI) / TAU * 12.0); }
		else { vec4 vo = voronoi3(q * 4.6 + seed_off); band = floor(vo.z * 9.0); panel = floor(vo.x * 7.0); }
		float hid = hash13(vec3(band, panel, seed_off.x + 3.0));
		VERTEX = q * (1.0 + 0.18 + 0.44 * hid);
		v_shell = hid;
	}
	NORMAL = normalize(VERTEX);
}

void fragment() {
	vec3 p = normalize(v_dir);
	vec3 q = p + seed_off;
	float t = g_time;
	float lon = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	vec3 L = light_vec(v_wpos);
	vec3 N = normalize(NORMAL);
	float ndl = dot(N, L);

	vec3 alb; float h, land, keyline, keyid;
	surface(p, q, alb, h, land, keyline, keyid);

	// 全域均匀照明：没有昼夜半球、没有盈亏相位
	vec3 col = alb * (0.94 + 0.06 * ndl);
	float fres = pow(1.0 - max(dot(N, normalize(CAMERA_POSITION_WORLD - v_wpos)), 0.0), 3.0);
	col += atmo_col * fres * 0.16;

	if (tf_shard == 1) {
		// 宇宙级拆下的独立壳片：保留原型纹样 + 断面层理 + 结构边缘光
		vec3 inner = innerLayer(p, q, 0.5);
		float strata = fract(dot(v_dir, vec3(3.0, 7.0, 2.0)) * 6.0 + seed_off.x);
		vec3 shard = mix(alb * 1.05, inner, 0.42);
		shard += struct_col * smoothstep(0.80, 1.0, strata) * 0.42;
		shard += vec3(0.40, 0.72, 1.0) * fres * 0.62;
		shard += c4 * keyline * 0.28;
		float breath = 0.82 + 0.18 * sin(t * 0.6 + seed_off.x * 10.0);
		// 亮原型（层台）压暗、暗原型（潮界／陨野）提亮，避免整片过曝或糊成黑块
		float boost = mix(1.30, 0.82, smoothstep(0.48, 0.88, luma3(alb)));
		ALBEDO = clamp(shard * breath * boost, 0.0, 1.25);
	} else if (tf_level == 0) {
		// 星球级 · 顺应：场一点不改，只沿原型的 keyline 放极稀疏标记
		vec3 cid = floor(q * 54.0);
		float hv = hash13(cid + vec3(3.3));
		float near_line = smoothstep(0.25, 0.75, keyline);
		if (hv > 0.948 && near_line > 0.35) {
			col += vec3(0.95, 0.82, 0.55) * (0.55 + 0.45 * sin(t * 2.0 + hv * 40.0)) * 0.50 * near_line;
		}
		ALBEDO = clamp(col, 0.0, 1.6);
	} else if (tf_level == 1) {
		// 星系级：少数几条巨大、连续、有厚度的实体工程带缠住母星。
		// 没有等间距经纬分缝；带与带之间仍露出原型的自然地表。
		float bc = 0.0;
		if (tf_arch == 0) {
			bc = sin(lon * 2.0 + log(length(p.xz) + 0.16) * 8.0) * 0.5 + 0.5;  // 螺旋堤
		} else if (tf_arch == 1) {
			bc = p.y * 0.5 + 0.5;                                                  // 水平台地
		} else if (tf_arch == 2) {
			bc = abs(p.y);                                                          // 同心环墙
		} else {
			bc = keyid;                                                             // 大胞格板
		}
		// 两三条宽带，连续、非周期；不是铺满球的网格
		float belt = 0.0;
		belt = max(belt, smoothstep(0.13, 0.21, bc) * (1.0 - smoothstep(0.31, 0.39, bc)));
		belt = max(belt, smoothstep(0.55, 0.63, bc) * (1.0 - smoothstep(0.73, 0.81, bc)));
		if (tf_arch == 3) {
			belt = max(belt, smoothstep(0.84, 0.90, bc) * 0.85);
		}
		// 带的厚度：两侧暗边 + 受光侧亮边
		float beltEdge = clamp(
			(smoothstep(0.13, 0.21, bc) - smoothstep(0.31, 0.39, bc)) * 0.0 +
			exp(-pow((bc - 0.21) / 0.028, 2.0)) + exp(-pow((bc - 0.63) / 0.028, 2.0)), 0.0, 1.0);
		// 带内是连续金属面：低频渐变、铸造纹理，不是细格子
		float panel = 0.5 + 0.5 * sin(lon * 3.0 + bc * 7.0);
		float grain = 0.5 + 0.5 * sin(lon * 170.0 + lat * 130.0);
		vec3 built = struct_col * (0.22 + 0.30 * panel + 0.08 * grain);
		built += c4 * 0.05;
		col = mix(col, built, belt * 0.93);
		col += struct_col * beltEdge * 0.30;
		// 极少数大型接缝（整颗球只有几条），不是网格
		float joint = 1.0 - smoothstep(0.004, 0.014, abs(fract(lon / TAU * 5.0 + 0.25) - 0.5));
		col *= 1.0 - joint * belt * 0.62;
		ALBEDO = clamp(col, 0.0, 1.6);
	} else {
		// 兼容旧路径：主宇宙级已改由 generator 装配独立构件
		if (v_shell > 0.58) discard;
		col = mix(col, innerLayer(p, q, 0.5), 0.55);
		ALBEDO = clamp(col, 0.0, 1.6);
	}
}
