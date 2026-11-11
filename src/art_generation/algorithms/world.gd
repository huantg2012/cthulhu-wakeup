extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: world.js; preserve contours, ordering and seed decisions.

static var tide = {"archetype": 0.0, "styleSid": 0.0, "palette": 0.0, "worldSeed": 1339.0, "c0": "#04161a", "c1": "#0b3b3d", "c2": "#1f6b5e", "c3": "#8c9a6a", "c4": "#6bff9e", "nebula": "#5a2a6e", "corruption": "#c040ff", "star": "#fff4c8"}
static func roles(v_w_1 = null):
	if v_w_1 == null:
		v_w_1 = tide
	return {"cloth": mix(getv(v_w_1, "c2"), getv(v_w_1, "c3"), 0.44), "clothShadow": mix(getv(v_w_1, "c0"), getv(v_w_1, "nebula"), 0.22), "linen": mix(getv(v_w_1, "c3"), getv(v_w_1, "star"), 0.19), "linenShadow": mix(getv(v_w_1, "c1"), getv(v_w_1, "c3"), 0.4), "stone": mix(getv(v_w_1, "c3"), getv(v_w_1, "star"), 0.08), "stoneShadow": mix(getv(v_w_1, "c0"), getv(v_w_1, "c2"), 0.35), "salt": mix(getv(v_w_1, "c3"), getv(v_w_1, "star"), 0.37), "wet": mix(getv(v_w_1, "c1"), getv(v_w_1, "c2"), 0.25), "copper": mix(getv(v_w_1, "c3"), "#b78b50", 0.55), "water": mix(getv(v_w_1, "c1"), getv(v_w_1, "c2"), 0.5), "light": getv(v_w_1, "c4"), "violet": mix(getv(v_w_1, "c0"), getv(v_w_1, "nebula"), 0.66)}
