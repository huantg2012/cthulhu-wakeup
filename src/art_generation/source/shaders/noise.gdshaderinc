// Shared hash / noise helpers (portable to GLES3 / WebGL2)

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float gnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash33(i) * 2.0 - 1.0, f);
	float b = dot(hash33(i + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 0.0));
	float c = dot(hash33(i + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 0.0));
	float d = dot(hash33(i + vec3(1.0, 1.0, 0.0)) * 2.0 - 1.0, f - vec3(1.0, 1.0, 0.0));
	float e = dot(hash33(i + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 0.0, 1.0));
	float g = dot(hash33(i + vec3(1.0, 0.0, 1.0)) * 2.0 - 1.0, f - vec3(1.0, 0.0, 1.0));
	float h = dot(hash33(i + vec3(0.0, 1.0, 1.0)) * 2.0 - 1.0, f - vec3(0.0, 1.0, 1.0));
	float k = dot(hash33(i + vec3(1.0, 1.0, 1.0)) * 2.0 - 1.0, f - vec3(1.0, 1.0, 1.0));
	return 1.5 * mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y), mix(mix(e, g, u.x), mix(h, k, u.x), u.y), u.z);
}

float gnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash22(i) * 2.0 - 1.0, f);
	float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
	return 1.4 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm3(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) { break; }
		s += a * gnoise3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

float fbm2(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) { break; }
		s += a * gnoise2(p);
		p = p * 2.02 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

float ridged3(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float w = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) { break; }
		float n = 1.0 - abs(gnoise3(p));
		n = n * n * w;
		w = clamp(n * 1.6, 0.0, 1.0);
		s += a * n;
		p = p * 2.07 + vec3(4.1, 1.3, 7.7);
		a *= 0.5;
	}
	return s;
}

// x = F1, y = F2, z = cell hash ; cp = nearest feature point
vec4 voronoi3c(vec3 p, out vec3 cp) {
	vec3 i = floor(p);
	vec3 f = p - i;
	float f1 = 9.0;
	float f2 = 9.0;
	float id = 0.0;
	cp = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = hash13(i + g + vec3(17.0, 3.0, 11.0));
					cp = i + g + o;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec4(sqrt(f1), sqrt(f2), id, 0.0);
}

vec4 voronoi3(vec3 p) {
	vec3 cp;
	return voronoi3c(p, cp);
}

vec3 rotate_axis(vec3 v, vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// procedural eldritch glyph in a unit cell; returns distance to nearest stroke
float glyph_dist(vec2 uv, float gid) {
	float d = 9.0;
	// 3x3 lattice of anchor points in [0.2, 0.8]
	for (int k = 0; k < 12; k++) {
		float on = hash12(vec2(gid * 7.13 + float(k) * 1.37, gid * 0.71 + 3.1));
		if (on > 0.42) { continue; }
		vec2 a;
		vec2 b;
		if (k < 6) {
			float row = float(k / 2);
			float col = float(k - (k / 2) * 2);
			a = vec2(col, row);
			b = vec2(col + 1.0, row);
		} else {
			int kk = k - 6;
			float col = float(kk / 2);
			float row = float(kk - (kk / 2) * 2);
			a = vec2(col, row);
			b = vec2(col, row + 1.0);
		}
		a = vec2(0.22) + a * 0.28;
		b = vec2(0.22) + b * 0.28;
		d = min(d, sd_segment(uv, a, b));
	}
	// diagonal / circle flourish
	float fl = hash12(vec2(gid * 3.7, 9.1));
	if (fl < 0.3) {
		d = min(d, abs(length(uv - vec2(0.5)) - 0.18));
	} else if (fl < 0.55) {
		d = min(d, sd_segment(uv, vec2(0.22), vec2(0.78)));
	} else if (fl < 0.7) {
		d = min(d, length(uv - vec2(0.5, 0.86)) - 0.03);
	}
	return d;
}
