shader_type canvas_item;
render_mode unshaded;

// Opt-in composition study. Only the existing 260 x 390 stock is recoloured.
// Child illustrations, copy, seals, focus cuts and shadows retain their draw.
uniform int design = 1;
uniform vec4 category : source_color = vec4(0.51, 0.29, 0.25, 1.0);
uniform vec2 extent = vec2(260.0, 390.0);
uniform float reading_start = 0.715;
uniform float seed_value = 0.0;
uniform float hover_light = 1.0;
uniform float stack_depth = 0.0;
uniform vec2 spine_sides = vec2(0.0);

varying vec2 stock_pos;

void vertex() {
	// UV follows the original texture's nine slices, not the host card's face.
	stock_pos = VERTEX / max(extent, vec2(1.0));
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float reading_reserve(vec2 p) {
	// This soft interior reserve is embedded in each composition, rather than
	// a horizontal rectangle switched on at the text's first baseline.
	float across = smoothstep(0.045, 0.105, p.x) * (1.0 - smoothstep(0.76, 0.85, p.x));
	float below = smoothstep(reading_start - 0.15, reading_start + 0.012, p.y);
	float above = 1.0 - smoothstep(0.975, 1.025, p.y);
	return across * below * above;
}

float arc_fold(vec2 p, vec2 center, vec2 radius, float ring, float width, float phase) {
	vec2 q = (p - center) / radius;
	float angle = atan(q.y, q.x);
	float irregular = 0.041 * sin(angle * 3.0 + phase) + 0.016 * sin(angle * 7.0 - phase);
	float distance_to_fold = abs(length(q) - ring + irregular);
	float fold = 1.0 - smoothstep(width, width + 0.014, distance_to_fold);
	// A missing angular wedge and a few dry gaps prevent closed outlined eyes.
	float open = smoothstep(-3.05, -2.84, angle) * (1.0 - smoothstep(-0.52, -0.29, angle));
	float drag = grain(vec2(angle * 13.0 + phase, length(q) * 3.2));
	return fold * open * smoothstep(0.23, 0.49, drag);
}

float pore(vec2 p, vec2 center, vec2 radius, float phase) {
	vec2 q = (p - center) / radius;
	float a = atan(q.y, q.x);
	float r = length(q) + 0.12 * sin(a * 3.0 + phase);
	return 1.0 - smoothstep(0.62, 1.02, r);
}

vec3 soaked_impression(vec2 p, vec3 paper, vec3 ink, float drag, float seed) {
	float reserve = reading_reserve(p);
	float sparse_card = 1.0 - smoothstep(0.07, 0.15, reading_start);
	float broken = (grain(vec2(p.x * 10.0 + seed, p.y * 3.1)) - 0.5) * 0.032;
	// The dense upper-left print moves down through the two open side fields.
	// Its lower edge is curved and diffuse; there is no full-width head plate.
	float upper = 1.0 - smoothstep(0.105 + 0.17 * (1.0 - p.x),
		0.29 + 0.23 * (1.0 - p.x), p.y + broken);
	float left = (1.0 - smoothstep(0.035, 0.20 + 0.044 * sin(p.y * 4.8), p.x + broken)) * 0.82;
	float right = smoothstep(0.81 + 0.035 * sin(p.y * 5.4 + 0.6), 1.015, p.x + broken) * 0.83;
	vec2 pool = (p - vec2(-0.10, -0.06)) / vec2(1.10, 0.79);
	float field = (1.0 - smoothstep(0.55, 1.13, length(pool))) * 0.73;
	float pigment = max(max(upper, field), max(left, right));
	pigment *= 1.0 - reserve * 0.965;
	pigment *= mix(1.0, 0.12, sparse_card);
	pigment = clamp(pigment + (drag - 0.5) * 0.033 * pigment, 0.0, 1.0);
	vec3 surface = mix(paper, ink, pigment);

	// Two broad linked sweeps run from the upper-left towards the lower-right
	// imprint. Most of their area lies beneath the actual illustration.
	float sweep_x = 0.06 + 0.97 * pow(max(p.y, 0.001), 0.72);
	float sweep_a = 1.0 - smoothstep(0.025, 0.063, abs(p.x - sweep_x));
	float sweep_b = 1.0 - smoothstep(0.018, 0.052, abs(p.x - sweep_x + 0.115));
	float sweeps = (sweep_a + sweep_b * 0.65) * (1.0 - reserve * 0.97);
	surface = mix(surface, mix(paper, category.rgb, 0.47), sweeps * 0.13);

	// A large incomplete, three-fold contact escapes the lower-right corner.
	// Off-centre pores do not form a single iris or a human almond outline.
	float fold_top = mix(reading_start + 0.075, 0.73, 0.55);
	vec2 center = vec2(1.10, 1.035);
	vec2 radius = vec2(0.43, max(0.25, 1.06 - fold_top));
	float folds = arc_fold(p, center, radius, 1.00, 0.032, 0.9)
		+ arc_fold(p, center + vec2(0.012, -0.010), radius, 0.78, 0.027, 1.45) * 0.82
		+ arc_fold(p, center + vec2(-0.017, 0.006), radius, 0.57, 0.036, 0.35) * 0.70;
	float holes = pore(p, vec2(0.967, 0.955), vec2(0.022, 0.017), 1.2)
		+ pore(p, vec2(1.004, 0.892), vec2(0.014, 0.020), 0.4) * 0.80
		+ pore(p, vec2(0.893, 1.008), vec2(0.019, 0.012), 2.1) * 0.62;
	float visible = (1.0 - reserve * 0.975) * mix(1.0, 0.24, sparse_card);
	surface = mix(surface, ink * 0.61, clamp(folds * 0.34 + holes * 0.42, 0.0, 0.65) * visible);
	return surface;
}

vec3 broken_aperture(vec2 p, vec3 paper, vec3 ink, float drag, float seed) {
	float reserve = reading_reserve(p);
	float sparse_card = 1.0 - smoothstep(0.07, 0.15, reading_start);
	// The governing arc is centred outside the left side. It turns from the
	// upper-right down to the lower-left, leaving a tall light interior.
	vec2 q = (p - vec2(-0.075, 0.105)) / vec2(1.12, 0.935);
	float angle = atan(q.y, q.x);
	float relief = 0.023 * sin(angle * 4.0 + 0.4) + 0.009 * sin(angle * 9.0);
	float distance_to_center = length(q) + relief;
	float dry_edge = (grain(vec2(angle * 19.0 + seed, distance_to_center * 5.0)) - 0.5) * 0.017;
	float outside = smoothstep(0.88, 1.015, distance_to_center + dry_edge);
	float upper = 1.0 - smoothstep(0.11 + p.x * 0.16, 0.25 + p.x * 0.23, p.y);
	float pigment = max(outside * 0.95, upper);
	pigment *= 1.0 - reserve * 0.97;
	pigment *= mix(1.0, 0.11, sparse_card);
	pigment = clamp(pigment + (drag - 0.5) * 0.027 * pigment, 0.0, 1.0);
	vec3 surface = mix(paper, ink, pigment);

	// A single broad broken residual arc dominates; the nearby echo is only
	// a partial blind impression, not a second border around the illustration.
	float width = 0.018 + 0.012 * (0.5 + 0.5 * sin(angle * 3.0 + 0.5));
	float main_arc = 1.0 - smoothstep(width, width + 0.014, abs(distance_to_center - 0.935));
	float angle_gate = smoothstep(-0.25, -0.10, angle) * (1.0 - smoothstep(1.76, 1.96, angle));
	float gap_a = smoothstep(0.018, 0.074, abs(angle - 0.44));
	float gap_b = smoothstep(0.030, 0.081, abs(angle - 1.17));
	float dry = smoothstep(0.16, 0.47, grain(vec2(angle * 28.0 + seed, distance_to_center * 2.8)));
	main_arc *= angle_gate * gap_a * gap_b * dry;
	float echo = 1.0 - smoothstep(0.008, 0.018, abs(distance_to_center - 1.047));
	echo *= smoothstep(0.29, 0.44, angle) * (1.0 - smoothstep(1.31, 1.54, angle)) * dry;
	float visible = (1.0 - reserve * 0.978) * mix(1.0, 0.25, sparse_card);
	surface = mix(surface, ink * 0.53, (main_arc * 0.40 + echo * 0.15) * visible);

	// Unequal contact pits stay at the foot / right edge of this same arc.
	float holes = pore(p, vec2(0.235, 0.987), vec2(0.023, 0.014), 0.8)
		+ pore(p, vec2(0.178, 1.009), vec2(0.013, 0.021), 2.4) * 0.71
		+ pore(p, vec2(0.957, 0.771), vec2(0.016, 0.027), 1.6) * 0.46;
	surface = mix(surface, ink * 0.56, clamp(holes * 0.41, 0.0, 0.53) * visible);
	return surface;
}

vec3 expose_spines(vec3 surface, vec2 p, vec3 ink, float drag, float seed) {
	// Existing vertical names reveal coloured sides of this very same print.
	// The 7..29 / 119..141 host ranges are expressed in 148-wide hand units.
	float edge_drag = (grain(vec2(p.x * 6.0 + seed, p.y * 43.0)) - 0.5) * 0.006;
	float left = smoothstep(6.0 / 148.0, 8.0 / 148.0, p.x + edge_drag)
		* (1.0 - smoothstep(28.0 / 148.0, 30.0 / 148.0, p.x + edge_drag));
	float right = smoothstep(118.0 / 148.0, 120.0 / 148.0, p.x + edge_drag)
		* (1.0 - smoothstep(140.0 / 148.0, 142.0 / 148.0, p.x + edge_drag));
	float side = max(left * clamp(spine_sides.x, 0.0, 1.0), right * clamp(spine_sides.y, 0.0, 1.0));
	vec3 side_ink = ink * (0.91 + (drag - 0.5) * 0.043);
	return mix(surface, side_ink, side);
}

void fragment() {
	vec4 original = COLOR;
	bool is_stock = abs(TEXTURE_PIXEL_SIZE.x - 1.0 / 260.0) < 0.000001
		&& abs(TEXTURE_PIXEL_SIZE.y - 1.0 / 390.0) < 0.000001;
	if (is_stock && (design == 1 || design == 2)) {
		vec4 stock = texture(TEXTURE, UV);
		vec2 p = stock_pos;
		float seed = fract(seed_value * 0.6180339887) * 23.0;
		vec2 pixels = p * extent;
		// Anisotropic dragged fibres are broad in one direction. Pixel grit is
		// subordinate, and the original stock contributes only scalar relief.
		float drag = grain(vec2(pixels.x * 0.022 + pixels.y * 0.008 + seed, pixels.y * 0.34));
		float fibre = hash21(floor(pixels) + vec2(seed));
		float source_light = dot(stock.rgb, vec3(0.2126, 0.7152, 0.0722));
		float relief = clamp((source_light - 0.20) * 0.13, -0.012, 0.024);
		vec3 paper = vec3(0.862745, 0.847059, 0.800000)
			* (1.0 + (fibre - 0.5) * 0.012 + (drag - 0.5) * 0.009 + relief);
		vec3 ink = category.rgb * vec3(0.82, 0.80, 0.84) + vec3(0.008, 0.007, 0.010);
		ink *= 1.0 + (drag - 0.5) * 0.050 + relief * 0.6;
		vec3 surface = design == 1 ? soaked_impression(p, paper, ink, drag, seed)
			: broken_aperture(p, paper, ink, drag, seed);
		surface = expose_spines(surface, p, ink, drag, seed);
		surface *= (1.0 - 0.043 * min(max(stack_depth, 0.0), 3.0))
			* mix(1.0, hover_light, 0.40);
		// Keep the stock's original torn silhouette, alpha and existing draw
		// opacity. Source RGB / tint cannot contribute the rejected green cast.
		original.rgb = clamp(surface, vec3(0.0), vec3(1.0));
	}
	COLOR = original;
}
