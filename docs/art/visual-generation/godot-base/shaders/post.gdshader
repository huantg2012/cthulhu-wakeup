shader_type canvas_item;
// Final composite: style filters + bloom + madness. TEXTURE = rendered 3D scene.

uniform sampler2D bloom_tex : filter_linear, repeat_disable;
uniform int style = 0;
uniform float madness = 0.0;
uniform float bloom_amt = 0.8;
uniform float grain = 0.04;
uniform float vignette = 0.45;
uniform float px_scale = 1.0;
uniform float seed = 0.0;
uniform vec3 paper : source_color = vec3(0.88, 0.82, 0.69);
uniform vec3 ink : source_color = vec3(0.13, 0.09, 0.07);
uniform vec3 accent : source_color = vec3(0.6, 0.1, 0.1);
uniform vec3 pal_a : source_color = vec3(0.1, 0.5, 0.45);
uniform vec3 pal_b : source_color = vec3(0.85, 0.35, 0.2);
uniform vec3 holo : source_color = vec3(0.3, 0.9, 1.0);

global uniform float g_time;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), u.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 tex(sampler2D t, vec2 uv) { return textureLod(t, uv, 0.0).rgb; }
vec3 btex(vec2 uv) { return textureLod(bloom_tex, uv, 0.0).rgb; }

float sobel(sampler2D t, vec2 uv, vec2 px) {
	float tl = luma(tex(t, uv + px * vec2(-1.0, -1.0)));
	float tc = luma(tex(t, uv + px * vec2(0.0, -1.0)));
	float tr = luma(tex(t, uv + px * vec2(1.0, -1.0)));
	float ml = luma(tex(t, uv + px * vec2(-1.0, 0.0)));
	float mr = luma(tex(t, uv + px * vec2(1.0, 0.0)));
	float bl = luma(tex(t, uv + px * vec2(-1.0, 1.0)));
	float bc = luma(tex(t, uv + px * vec2(0.0, 1.0)));
	float br = luma(tex(t, uv + px * vec2(1.0, 1.0)));
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	return sqrt(gx * gx + gy * gy);
}

vec3 kuwahara(sampler2D t, vec2 uv, vec2 px) {
	vec3 m[4];
	vec3 s[4];
	for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); }
	for (int j = 0; j <= 3; j++) {
		for (int i = 0; i <= 3; i++) {
			vec3 c;
			c = tex(t, uv + px * vec2(float(-i), float(-j))); m[0] += c; s[0] += c * c;
			c = tex(t, uv + px * vec2(float(i), float(-j)));  m[1] += c; s[1] += c * c;
			c = tex(t, uv + px * vec2(float(-i), float(j)));  m[2] += c; s[2] += c * c;
			c = tex(t, uv + px * vec2(float(i), float(j)));   m[3] += c; s[3] += c * c;
		}
	}
	vec3 best = vec3(0.0);
	float bs = 1e9;
	for (int k = 0; k < 4; k++) {
		vec3 mm = m[k] / 16.0;
		vec3 vv = abs(s[k] / 16.0 - mm * mm);
		float sv = vv.r + vv.g + vv.b;
		if (sv < bs) { bs = sv; best = mm; }
	}
	return best;
}

vec3 sat(vec3 c, float k) { return mix(vec3(luma(c)), c, k); }

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return (m[idx] + 0.5) / 16.0;
}

float halftone(vec2 fc, float ang, float cell, float v) {
	float c = cos(ang);
	float s = sin(ang);
	vec2 p = mat2(vec2(c, -s), vec2(s, c)) * fc / cell;
	vec2 f = fract(p) - 0.5;
	float r = sqrt(clamp(v, 0.0, 1.0)) * 0.62;
	return 1.0 - smoothstep(r - 0.08, r + 0.08, length(f));
}

void fragment() {
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = UV;
	vec2 fc = uv * res;
	vec2 px = TEXTURE_PIXEL_SIZE * px_scale;
	float t = g_time;

	// ---- madness distortion
	if (madness > 0.001) {
		vec2 d = uv - 0.5;
		float w = fbm(uv * 3.0 + vec2(t * 0.07, -t * 0.05) + seed) - 0.5;
		uv += d * dot(d, d) * 0.12 * madness + vec2(w, -w) * 0.012 * madness;
		uv += vec2(sin(uv.y * 40.0 + t * 2.0), 0.0) * 0.0012 * madness * step(0.6, madness);
	}

	vec3 c;
	float lum;
	if (style == 4) {
		float ps = 4.0 * px_scale;
		vec2 blk = floor(uv * res / ps);
		vec2 cuv = (blk + 0.5) * ps / res;
		vec2 bp = ps / res;
		c = tex(TEXTURE, cuv);
		c = mix(c, (tex(TEXTURE, cuv + bp * vec2(0.25, 0.25)) + tex(TEXTURE, cuv - bp * vec2(0.25, 0.25))) * 0.5, 0.5);
		float l0 = luma(c);
		float l1 = luma(tex(TEXTURE, cuv + vec2(bp.x, 0.0)));
		float l2 = luma(tex(TEXTURE, cuv + vec2(0.0, bp.y)));
		float l3 = luma(tex(TEXTURE, cuv - vec2(bp.x, 0.0)));
		float l4 = luma(tex(TEXTURE, cuv - vec2(0.0, bp.y)));
		float edge = step(0.18, max(max(l1, l2), max(l3, l4)) - l0) * step(l0, 0.25);
		c += btex(cuv) * bloom_amt * 0.6;
		float dth = bayer4(blk) - 0.5;
		float lv = 5.0;
		c = floor(c * lv + dth * 0.9 + 0.5) / lv;
		c = mix(c, ink * 0.5, edge * 0.85);
		fc = blk;
	} else if (style == 0) {
		c = kuwahara(TEXTURE, uv, px * 1.2);
		float stroke = fbm(vec2(fc.x * 0.05 + fc.y * 0.12, fc.y * 0.05 - fc.x * 0.02) / px_scale + seed);
		c *= 0.93 + 0.14 * stroke;
		c = sat(c, 1.1);
	} else if (style == 1) {
		c = tex(TEXTURE, uv);
		float e = sobel(TEXTURE, uv, px * 1.1);
		float l = luma(c);
		float lq = floor(l * 4.0 + 0.5) / 4.0;
		c = c * clamp(mix(1.0, (lq + 0.04) / (l + 0.04), 0.55), 0.6, 1.6);
		c = sat(c, 1.25);
		c = mix(c, ink * 0.25, smoothstep(0.25, 0.6, e) * 0.9);
	} else if (style == 2) {
		vec3 src = tex(TEXTURE, uv);
		float e = sobel(TEXTURE, uv, px * 1.5);
		float l = clamp(pow(luma(src), 0.7) * 1.2, 0.0, 1.0);
		float sp = 5.0 * px_scale;
		float wob = (fbm(fc * 0.02 / px_scale) - 0.5) * 2.0;
		float h1 = abs(fract((fc.x + fc.y) / sp + wob * 0.4) - 0.5) * 2.0;
		float h2 = abs(fract((fc.x - fc.y) / sp + wob * 0.4) - 0.5) * 2.0;
		float h3 = abs(fract(fc.y / (sp * 0.7) + wob * 0.3) - 0.5) * 2.0;
		float inkv = 0.0;
		inkv = max(inkv, 1.0 - smoothstep(0.0, 0.25, h1 - (1.0 - l) * 0.9 + 0.12));
		inkv = max(inkv, (1.0 - smoothstep(0.0, 0.25, h2 - (0.62 - l) * 1.4)) * step(l, 0.62));
		inkv = max(inkv, (1.0 - smoothstep(0.0, 0.25, h3 - (0.32 - l) * 2.2)) * step(l, 0.32));
		inkv = max(inkv, smoothstep(0.2, 0.5, e));
		inkv = max(inkv, 1.0 - smoothstep(0.02, 0.06, l));
		vec3 pap = paper * (0.92 + 0.08 * fbm(fc * 0.01 / px_scale + seed)) * (0.96 + 0.04 * vn(fc * 0.7));
		c = mix(pap, ink, inkv);
		// hand tinting: saturated regions keep their colour like a coloured plate
		float s = length(src - vec3(luma(src))) * 2.0;
		c = mix(c, c * (src / max(luma(src), 0.05)) * 0.9, clamp(s, 0.0, 0.8));
	} else if (style == 3) {
		c = tex(TEXTURE, uv);
		c = floor(c * 14.0 + 0.5) / 14.0;
		c = sat(c, 1.08);
	} else if (style == 5) {
		float ca = 1.6 * px_scale;
		vec2 dir = normalize(uv - 0.5 + 0.0001) * TEXTURE_PIXEL_SIZE * ca;
		c = vec3(tex(TEXTURE, uv + dir).r, tex(TEXTURE, uv).g, tex(TEXTURE, uv - dir).b);
		c *= 0.82 + 0.18 * sin(fc.y / px_scale * 1.6);
		float flick = 0.94 + 0.06 * sin(t * 13.0) * sin(t * 7.3);
		float band = smoothstep(0.0, 0.02, abs(fract(uv.y * 0.6 - t * 0.12) - 0.5) - 0.48);
		c *= flick;
		c += holo * (1.0 - band) * 0.06;
		c += holo * 0.035 * vn(fc * 0.5 + t * 30.0);
	} else if (style == 6) {
		vec2 wob = (vec2(fbm(fc * 0.012 / px_scale + seed), fbm(fc * 0.012 / px_scale + seed + 7.0)) - 0.5) * 6.0 * px;
		vec2 wuv = uv + wob;
		c = tex(TEXTURE, wuv);
		vec3 b = vec3(0.0);
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785;
			b += tex(TEXTURE, wuv + vec2(cos(a), sin(a)) * px * 4.0);
		}
		b /= 8.0;
		float edge = smoothstep(0.03, 0.18, length(c - b));
		c = mix(c, c * c * 0.95, edge * 0.55);
		float l = luma(c);
		float gran = vn(fc * 0.45 / px_scale) * 0.6 + vn(fc * 0.12 / px_scale) * 0.4;
		c *= 1.0 - (1.0 - l) * 0.22 * gran;
		c = sat(c, 0.85);
		float pap = 0.93 + 0.07 * fbm(fc * 0.02 / px_scale + seed * 3.0);
		c *= pap;
		float e = sobel(TEXTURE, wuv + wob * 0.5, px * 0.9);
		c = mix(c, ink * 0.9 + c * 0.1, smoothstep(0.3, 0.7, e) * 0.55);
	} else {
		// pulp magazine: CMYK halftone + misregistration + heavy ink
		float cell = 5.0 * px_scale;
		vec3 src = pow(tex(TEXTURE, uv), vec3(0.75)) * 1.2;
		vec3 srcm = pow(tex(TEXTURE, uv + vec2(1.5, -1.0) * px), vec3(0.75)) * 1.2;
		src += btex(uv) * bloom_amt * 0.5;
		float k = 1.0 - max(max(src.r, src.g), src.b);
		vec3 cmy = (1.0 - vec3(srcm.r, src.g, src.b) - k) / max(1.0 - k, 0.001);
		float dc = halftone(fc, 0.26, cell, cmy.r * 0.9);
		float dm = halftone(fc, 1.31, cell, cmy.g * 0.9);
		float dy = halftone(fc, 0.0, cell, cmy.b * 0.9);
		float dk = halftone(fc, 0.785, cell, k * 0.85);
		vec3 pap = paper * (0.94 + 0.06 * fbm(fc * 0.01 / px_scale + seed));
		c = pap;
		c *= 1.0 - vec3(0.85, 0.0, 0.0) * dc;
		c *= 1.0 - vec3(0.0, 0.8, 0.0) * dm;
		c *= 1.0 - vec3(0.0, 0.0, 0.85) * dy;
		c *= 1.0 - 0.9 * dk;
		float e = sobel(TEXTURE, uv, px * 1.3);
		c = mix(c, ink * 0.6, smoothstep(0.3, 0.6, e));
	}

	// ---- bloom
	if (style != 4 && style != 7) {
		float bk = bloom_amt;
		if (style == 2) { bk *= 0.35; }
		if (style == 6) { bk *= 0.4; }
		if (style == 5) { bk *= 1.6; }
		vec3 bl = btex(uv);
		if (style == 2 || style == 6) {
			c = mix(c, c * (1.0 + bl * 2.0), 0.5) + bl * bk * 0.3;
		} else {
			c += bl * bk;
		}
	}

	// ---- madness overlays: dark tendrils creeping in from the frame + colour bleed
	vec2 d = UV - 0.5;
	float rr = length(d * vec2(res.x / res.y, 1.0));
	if (madness > 0.001) {
		float ang = atan(d.y, d.x);
		// distance to the frame edge (0 at border)
		float edge_d = min(min(UV.x, 1.0 - UV.x) * res.x / res.y, min(UV.y, 1.0 - UV.y));
		float reach = 0.03 + madness * 0.14;
		// tendrils: angular stripes with noise-warped tips
		float tn = fbm(vec2(ang * 2.2 + seed, t * 0.05));
		float stripes = pow(abs(sin(ang * 9.0 + tn * 5.0 + edge_d * 9.0)), 3.0);
		float len = reach * (0.45 + 0.9 * stripes) * (0.7 + 0.6 * fbm(vec2(ang * 6.0, seed + 3.0)));
		float wob = (fbm(UV * 7.0 + vec2(t * 0.04, seed)) - 0.5) * 0.06 * madness;
		float m = 1.0 - smoothstep(len * 0.6, len, edge_d + wob);
		float haze = (1.0 - smoothstep(0.0, reach * 1.4, edge_d)) * 0.5;
		vec3 tint = (style == 2 || style == 6 || style == 7) ? ink : vec3(0.0);
		c = mix(c, tint, clamp(max(m * 0.95, haze * madness), 0.0, 1.0));
		// glowing rim on the tendrils
		float rim = smoothstep(len * 0.6, len * 0.85, edge_d + wob) * (1.0 - smoothstep(len * 0.85, len * 1.05, edge_d + wob));
		c += accent * rim * 0.45 * madness;
		// sickly desaturation + chromatic split
		vec3 split = vec3(tex(TEXTURE, uv + d * 0.006 * madness).r, c.g, tex(TEXTURE, uv - d * 0.006 * madness).b);
		if (style == 0 || style == 1 || style == 3 || style == 5) {
			c = mix(c, mix(c, split, 0.5), madness * (1.0 - m));
		}
		c = mix(c, vec3(luma(c)) * vec3(1.05, 0.97, 0.85), madness * 0.3);
	}

	// ---- vignette + grain
	if (style != 4) {
		c *= 1.0 - smoothstep(0.45, 1.1, rr) * vignette;
		float g = h12(fc + vec2(fract(t * 7.0) * 100.0)) - 0.5;
		c += g * grain;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
