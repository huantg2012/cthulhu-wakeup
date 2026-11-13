shader_type canvas_item;
render_mode unshaded;

// The image occupies the full width and starts at the carrier's top. Its upper
// and side silhouettes belong to the same stock, never an inset soft window.
uniform sampler2D carrier_mask : filter_linear, repeat_disable;
uniform float art_card_fraction : hint_range(0.1, 1.0, 0.001) = 0.666667;
uniform float fade_bottom : hint_range(0.04, 0.45, 0.005) = 0.28;
uniform float grain_scale : hint_range(3.0, 16.0, 0.25) = 7.0;
uniform float seed_value = 0.0;

// This is an opacity floor for the subject, never a visible crop silhouette.
// Adjust to the actual world / place / person rather than cutting every image
// to one circular outline. It can only restore internal alpha, never remove it.
uniform vec2 protected_center = vec2(0.50, 0.51);
uniform vec2 protected_radius = vec2(0.36, 0.37);

varying float source_opacity;

void vertex() {
	source_opacity = COLOR.a;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float stable_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// One unshifted sample: no blur, recolouring, colour key, or RGB-dependent
	// coverage. Existing white, dark, and halftone backgrounds remain imagery.
	vec4 source = texture(TEXTURE, UV);
	vec2 p = UV;
	float seed = fract(seed_value * 0.61803398875) * 43.0;
	float scale = max(grain_scale, 1.0);
	float bottom = max(fade_bottom, 0.005);
	float carrier_alpha = texture(carrier_mask, vec2(p.x, p.y * art_card_fraction)).a;

	// Only the lower boundary moves inside the picture. Two broad fields and
	// a slight one-sided drift form a few unequal washes, not a picket of
	// narrow vertical cuts. The feather is narrow relative to the large sway.
	float broad = stable_noise(vec2(p.x * scale * 0.23 + seed, 11.4));
	float secondary = stable_noise(vec2(p.x * scale * 0.48 + 7.1, seed + 23.6));
	float edge_height = 1.0 - bottom * (0.15 + 0.44 * broad + 0.17 * secondary + 0.12 * p.x);
	float feather = 0.014 + bottom * (0.034 + 0.028 * secondary);

	// Short, oblique fibres break the transition itself. They do not texture
	// the subject, blur the source, or produce full-height translucent strips.
	vec2 brush = vec2(p.x + p.y * 0.31, p.y - p.x * 0.22);
	float dry = stable_noise(brush * vec2(scale * 8.0, scale * 3.6) + vec2(seed, 7.6));
	float fibre_offset = (dry - 0.5) * 0.010;
	float coverage = 1.0 - smoothstep(edge_height - feather, edge_height + feather, p.y + fibre_offset);
	float transition = 4.0 * coverage * (1.0 - coverage);
	coverage = clamp(coverage + (dry - 0.52) * 0.40 * transition, 0.0, 1.0);

	// The subject floor only restores interior coverage. It still retires
	// before the square image ends and remains constrained by the actual paper
	// alpha, so it cannot resurrect a rectangular outer image or cover its teeth.
	vec2 protected_q = (p - protected_center) / max(protected_radius, vec2(0.01));
	float protection = 1.0 - smoothstep(0.82, 1.24, length(protected_q));
	protection *= 1.0 - smoothstep(0.90, 0.985, p.y);
	coverage = max(coverage, protection);

	COLOR = vec4(source.rgb, source.a * source_opacity * coverage * carrier_alpha);
}
