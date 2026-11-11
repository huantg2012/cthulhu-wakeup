extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: cult-kit.js; preserve contours, ordering and seed decisions.
const M_world = preload("res://src/art_generation/algorithms/world.gd")

static func cultKit(v_w_1, v_rule_2):
	var v_C_3: Variant = M_world.roles(v_w_1)
	var v_r_4: Variant = rng(add(getv(v_w_1, "worldSeed"), (getv(v_rule_2, "archetype") * 1009.0)))
	var v_lights_5: Variant = []
	var v_p_6: Variant = Painter.new(getv(v_w_1, "worldSeed"), {"emitters": v_lights_5, "styleSid": getv(v_w_1, "styleSid")})
	var v_field_7: Variant = worldField(getv(v_rule_2, "material"), v_w_1)
	var v_base_8: Variant = {"mat": getv(v_rule_2, "material"), "field": v_field_7, "color": mix(getv(v_C_3, "stone"), getv(v_w_1, "c2"), 0.2), "shadow": mix(getv(v_w_1, "c1"), getv(v_w_1, "c0"), 0.35), "accent": getv(v_C_3, "salt"), "glow": getv(v_w_1, "c4"), "bump": 0.65, "exposure": 0.83}
	var v_top_9: Variant = merge_dicts([v_base_8, {"normal": [(-0.28), (-0.66), 0.72]}])
	var v_side_10: Variant = merge_dicts([v_base_8, {"normal": [0.35, 0.12, 0.9], "ambient": [0.14, 0.17, 0.21], "exposure": 0.84}])
	var v_built_11: Variant = {"mat": "masonry", "field": null, "color": mix(getv(v_C_3, "stone"), getv(v_w_1, "c2"), 0.17), "shadow": getv(v_C_3, "stoneShadow"), "accent": getv(v_C_3, "salt"), "bump": 0.5, "scale": 27.0}
	var v_wood_12: Variant = {"mat": "wood", "field": worldField("wood", v_w_1), "color": mix(getv(v_C_3, "copper"), getv(v_w_1, "c3"), 0.4), "shadow": getv(v_C_3, "stoneShadow"), "accent": getv(v_C_3, "salt")}
	var v_rect_13: Variant = func(v_x_14, v_y_15, v_a_16, v_b_17):
		return [((v_x_14 - v_a_16) - 4.0), ((v_y_15 - v_b_17) - 4.0), add(add(v_x_14, v_a_16), 4.0), add(add(v_y_15, v_b_17), 4.0)]
	var v_surf_18: Variant = func(v_d_19, v_b_20, v_o_21 = null):
		if v_o_21 == null:
			v_o_21 = merge_dicts([])
		invoke_member(v_p_6, "surface", [v_d_19, v_b_20, merge_dicts([v_base_8, v_o_21])])
	var v_lamp_22: Variant = func(v_x_23, v_y_24, v_power_25 = null, v_color_26 = null, v_radius_27 = null):
		if v_power_25 == null:
			v_power_25 = 0.55
		if v_color_26 == null:
			v_color_26 = getv(v_w_1, "c4")
		if v_radius_27 == null:
			v_radius_27 = 145.0
		var v_e_28: Variant = {"x": v_x_23, "y": v_y_24, "z": 58.0, "r": v_radius_27, "color": rgb(v_color_26), "power": (v_power_25 * 0.66), "falloff": 1.8, "specular": 0.055}
		v_lights_5.append(v_e_28)
		return v_e_28
	var v_lightMark_29: Variant = func(v_e_30):
		var v_unpack_31: Variant = v_e_30
		var v_x_32: Variant = getv(v_unpack_31, "x")
		var v_y_33: Variant = getv(v_unpack_31, "y")
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_32, 3.0), add(v_y_33, 16.0), 9.0, 3.0), getv(v_w_1, "c0"), 0.7])
		invoke_member(v_p_6, "line", [("M" + text_value(v_x_32) + " " + text_value(add(v_y_33, 3.0)) + "v15"), getv(v_C_3, "copper"), 3.0])
		invoke_member(v_p_6, "fill", [ellipse(v_x_32, v_y_33, 5.0, 7.0), mix(getv(v_e_30, "color"), getv(v_w_1, "star"), 0.6)])
		invoke_member(v_p_6, "glow", [v_x_32, v_y_33, 26.0, getv(v_e_30, "color"), 0.32])
	var v_person_34: Variant = func(v_x_35, v_y_36, v_s_37 = null, v_light_38 = null):
		if v_s_37 == null:
			v_s_37 = 0.85
		if v_light_38 == null:
			v_light_38 = false
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_35, (5.0 * v_s_37)), add(v_y_36, (2.0 * v_s_37)), (9.0 * v_s_37), (3.0 * v_s_37)), getv(v_w_1, "c0"), 0.68])
		invoke_member(v_p_6, "fill", [("M" + text_value((v_x_35 - (4.0 * v_s_37))) + " " + text_value((v_y_36 - (17.0 * v_s_37))) + "Q" + text_value((v_x_35 - (8.0 * v_s_37))) + " " + text_value((v_y_36 - (5.0 * v_s_37))) + " " + text_value((v_x_35 - (7.0 * v_s_37))) + " " + text_value(v_y_36) + "Q" + text_value(v_x_35) + " " + text_value(add(v_y_36, (3.0 * v_s_37))) + " " + text_value(add(v_x_35, (7.0 * v_s_37))) + " " + text_value(v_y_36) + "L" + text_value(add(v_x_35, (4.0 * v_s_37))) + " " + text_value((v_y_36 - (17.0 * v_s_37))) + "Z"), (getv(v_C_3, "linen") if truth(v_light_38) else mix(getv(v_w_1, "c1"), getv(v_w_1, "c3"), 0.38))])
		invoke_member(v_p_6, "fill", [ellipse(v_x_35, (v_y_36 - (20.0 * v_s_37)), (4.0 * v_s_37), (6.0 * v_s_37)), (getv(v_C_3, "salt") if truth(v_light_38) else getv(v_C_3, "stone"))])
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_35, (1.0 * v_s_37)), (v_y_36 - (20.0 * v_s_37)), (2.0 * v_s_37), (3.0 * v_s_37)), getv(v_w_1, "c0")])
		invoke_member(v_p_6, "line", [("M" + text_value((v_x_35 - (3.0 * v_s_37))) + " " + text_value((v_y_36 - (14.0 * v_s_37))) + "l" + text_value(((-2.0) * v_s_37)) + "," + text_value((12.0 * v_s_37)) + ""), getv(v_C_3, "salt"), (1.3 * v_s_37), 0.65])
	var v_actor_39: Variant = func(v_x_40, v_y_41, v_s_42 = null, v_action_43 = null, v_light_44 = null):
		if v_s_42 == null:
			v_s_42 = 1.0
		if v_action_43 == null:
			v_action_43 = "carry"
		if v_light_44 == null:
			v_light_44 = false
		var v_lean_45: Variant = (6.0 if truth((v_action_43 == "work")) else (4.0 if truth((v_action_43 == "bow")) else 0.0))
		var v_body_46: Variant = (mix(getv(v_C_3, "linen"), "#bcac89", 0.48) if truth(v_light_44) else mix(getv(v_w_1, "c2"), "#514e48", 0.52))
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_40, (8.0 * v_s_42)), add(v_y_41, (2.0 * v_s_42)), (12.0 * v_s_42), (3.5 * v_s_42)), getv(v_w_1, "c0"), 0.62])
		if truth((v_action_43 != "kneel")):
			for v_item_47 in [(-1.0), 1.0]:
				var v_d_48: Variant = v_item_47
				invoke_member(v_p_6, "line", [("M" + text_value(add(v_x_40, ((v_d_48 * 3.0) * v_s_42))) + " " + text_value((v_y_41 - (5.0 * v_s_42))) + "l" + text_value(((v_d_48 * 1.5) * v_s_42)) + "," + text_value((7.0 * v_s_42)) + ""), getv(v_w_1, "c0"), (3.0 * v_s_42)])
		var v_hem_49: Variant = (11.0 if truth((v_action_43 == "kneel")) else 7.0)
		invoke(v_surf_18, [("M" + text_value(add(v_x_40, (add((-5.0), v_lean_45) * v_s_42))) + " " + text_value((v_y_41 - (23.0 * v_s_42))) + "Q" + text_value((v_x_40 - (8.0 * v_s_42))) + " " + text_value((v_y_41 - (13.0 * v_s_42))) + " " + text_value((v_x_40 - (v_hem_49 * v_s_42))) + " " + text_value((v_y_41 - (3.0 * v_s_42))) + "Q" + text_value(v_x_40) + " " + text_value(add(v_y_41, (2.0 * v_s_42))) + " " + text_value(add(v_x_40, (v_hem_49 * v_s_42))) + " " + text_value((v_y_41 - (3.0 * v_s_42))) + "L" + text_value(add(v_x_40, (add(5.0, v_lean_45) * v_s_42))) + " " + text_value((v_y_41 - (22.0 * v_s_42))) + "Q" + text_value(add(v_x_40, (v_lean_45 * v_s_42))) + " " + text_value((v_y_41 - (27.0 * v_s_42))) + " " + text_value(add(v_x_40, (add((-5.0), v_lean_45) * v_s_42))) + " " + text_value((v_y_41 - (23.0 * v_s_42))) + "Z"), [(v_x_40 - (14.0 * v_s_42)), (v_y_41 - (28.0 * v_s_42)), add(v_x_40, (18.0 * v_s_42)), add(v_y_41, (5.0 * v_s_42))], {"mat": "cloth", "field": null, "color": v_body_46, "shadow": getv(v_w_1, "c0"), "accent": getv(v_C_3, "salt"), "normal": [(-0.3), 0.1, 1.0], "height": make_field("return (sin(((x-@0@)*0.5))*0.6);", [v_x_40]), "bump": 0.3}])
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_40, (v_lean_45 * v_s_42)), (v_y_41 - (27.0 * v_s_42)), (4.5 * v_s_42), (5.5 * v_s_42)), mix(v_body_46, getv(v_C_3, "salt"), 0.45)])
		invoke_member(v_p_6, "fill", [ellipse(add(v_x_40, (add(v_lean_45, 2.0) * v_s_42)), (v_y_41 - (26.0 * v_s_42)), (2.3 * v_s_42), (3.0 * v_s_42)), getv(v_w_1, "c0")])
		invoke_member(v_p_6, "stroke", [("M" + text_value((v_x_40 - (3.0 * v_s_42))) + " " + text_value((v_y_41 - (18.0 * v_s_42))) + "l" + text_value(((-2.0) * v_s_42)) + "," + text_value((12.0 * v_s_42)) + ""), getv(v_C_3, "salt"), (1.3 * v_s_42), 0.45])
		var v_wristX_50: Variant = add(v_x_40, ((16.0 if truth((v_action_43 == "work")) else (11.0 if truth((v_action_43 == "torch")) else 8.0)) * v_s_42))
		var v_wristY_51: Variant = (v_y_41 - ((28.0 if truth((v_action_43 == "torch")) else (14.0 if truth((v_action_43 == "work")) else 13.0)) * v_s_42))
		invoke_member(v_p_6, "line", [("M" + text_value(add(v_x_40, (add(v_lean_45, 4.0) * v_s_42))) + " " + text_value((v_y_41 - (20.0 * v_s_42))) + "Q" + text_value(add(v_x_40, (9.0 * v_s_42))) + " " + text_value((v_y_41 - (9.0 * v_s_42))) + " " + text_value(v_wristX_50) + " " + text_value(v_wristY_51) + ""), v_body_46, (4.0 * v_s_42)])
		invoke_member(v_p_6, "fill", [ellipse(v_wristX_50, v_wristY_51, (2.3 * v_s_42), (1.8 * v_s_42)), mix("#b2a17d", getv(v_C_3, "salt"), 0.2)])
		if truth((v_action_43 == "carry")):
			invoke_member(v_p_6, "fill", [("M" + text_value((v_x_40 - (1.0 * v_s_42))) + " " + text_value((v_y_41 - (16.0 * v_s_42))) + "l" + text_value((14.0 * v_s_42)) + "," + text_value((3.0 * v_s_42)) + "l" + text_value(((-2.0) * v_s_42)) + "," + text_value((8.0 * v_s_42)) + "l" + text_value(((-11.0) * v_s_42)) + "," + text_value(((-2.0) * v_s_42)) + "Z"), "#827052"])
			invoke_member(v_p_6, "line", [("M" + text_value(add(v_x_40, (1.0 * v_s_42))) + " " + text_value((v_y_41 - (17.0 * v_s_42))) + "l" + text_value((4.0 * v_s_42)) + "," + text_value(((-4.0) * v_s_42)) + "l" + text_value((7.0 * v_s_42)) + "," + text_value((6.0 * v_s_42)) + ""), "#b2a17d", (1.0 * v_s_42)])
		if truth((v_action_43 == "work")):
			invoke_member(v_p_6, "line", [("M" + text_value(v_wristX_50) + " " + text_value(v_wristY_51) + "l" + text_value((10.0 * v_s_42)) + "," + text_value(((-10.0) * v_s_42)) + ""), getv(v_C_3, "copper"), (1.8 * v_s_42)])
		if truth((v_action_43 == "torch")):
			invoke_member(v_p_6, "line", [("M" + text_value(v_wristX_50) + " " + text_value(add(v_wristY_51, (5.0 * v_s_42))) + "v" + text_value(((-16.0) * v_s_42)) + ""), getv(v_C_3, "copper"), (2.0 * v_s_42)])
			invoke_member(v_p_6, "fill", [ellipse(v_wristX_50, (v_wristY_51 - (13.0 * v_s_42)), (2.0 * v_s_42), (4.0 * v_s_42)), "#ffc079"])
			invoke_member(v_p_6, "glow", [v_wristX_50, (v_wristY_51 - (13.0 * v_s_42)), (19.0 * v_s_42), "#f4a251", 0.22])
	var v_brazier_52: Variant = func(v_e_53, v_s_54 = null):
		if v_s_54 == null:
			v_s_54 = 1.0
		v_e_53["marker"] = false
		var v_unpack_55: Variant = v_e_53
		var v_x_56: Variant = getv(v_unpack_55, "x")
		var v_y_57: Variant = getv(v_unpack_55, "y")
		invoke(v_surf_18, [("M" + text_value((v_x_56 - (4.0 * v_s_54))) + " " + text_value(add(v_y_57, (7.0 * v_s_54))) + "L" + text_value((v_x_56 - (5.0 * v_s_54))) + " " + text_value(add(v_y_57, (25.0 * v_s_54))) + "L" + text_value(add(v_x_56, (6.0 * v_s_54))) + " " + text_value(add(v_y_57, (27.0 * v_s_54))) + "L" + text_value(add(v_x_56, (4.0 * v_s_54))) + " " + text_value(add(v_y_57, (7.0 * v_s_54))) + "Z"), [(v_x_56 - (9.0 * v_s_54)), add(v_y_57, (5.0 * v_s_54)), add(v_x_56, (10.0 * v_s_54)), add(v_y_57, (30.0 * v_s_54))], {"mat": "metal", "field": null, "color": "#88714f", "shadow": getv(v_w_1, "c0"), "accent": "#bfa36f", "normal": [(-0.4), 0.1, 1.0]}])
		invoke_member(v_p_6, "fill", [("M" + text_value((v_x_56 - (12.0 * v_s_54))) + " " + text_value(add(v_y_57, (3.0 * v_s_54))) + "Q" + text_value(v_x_56) + " " + text_value(add(v_y_57, (19.0 * v_s_54))) + " " + text_value(add(v_x_56, (12.0 * v_s_54))) + " " + text_value(add(v_y_57, (3.0 * v_s_54))) + "Z"), "#775237"])
		invoke_member(v_p_6, "fill", [ellipse(v_x_56, add(v_y_57, (4.0 * v_s_54)), (11.0 * v_s_54), (3.0 * v_s_54)), "#e8984c"])
		invoke_member(v_p_6, "fill", [("M" + text_value((v_x_56 - (6.0 * v_s_54))) + " " + text_value(add(v_y_57, (3.0 * v_s_54))) + "Q" + text_value((v_x_56 - (8.0 * v_s_54))) + " " + text_value((v_y_57 - (4.0 * v_s_54))) + " " + text_value((v_x_56 - (2.0 * v_s_54))) + " " + text_value((v_y_57 - (12.0 * v_s_54))) + "L" + text_value(add(v_x_56, (1.0 * v_s_54))) + " " + text_value((v_y_57 - (3.0 * v_s_54))) + "L" + text_value(add(v_x_56, (4.0 * v_s_54))) + " " + text_value((v_y_57 - (15.0 * v_s_54))) + "Q" + text_value(add(v_x_56, (11.0 * v_s_54))) + " " + text_value(add(v_y_57, (3.0 * v_s_54))) + " " + text_value(add(v_x_56, (4.0 * v_s_54))) + " " + text_value(add(v_y_57, (5.0 * v_s_54))) + "Z"), "#ffbd68"])
		invoke_member(v_p_6, "fill", [ellipse(v_x_56, v_y_57, (2.4 * v_s_54), (5.0 * v_s_54)), "#ffecb4"])
		invoke_member(v_p_6, "glow", [v_x_56, v_y_57, (40.0 * v_s_54), "#f6a457", 0.2])
	var v_queue_58: Variant = func(v_points_59):
		var v_i_60: Variant = 0.0
		while truth((v_i_60 < len(v_points_59))):
			invoke(v_person_34, [getv(getv(v_points_59, v_i_60), 0.0), getv(getv(v_points_59, v_i_60), 1.0), or_value(getv(getv(v_points_59, v_i_60), 2.0), 0.8), (fmod(v_i_60, 3.0) == 0.0)])
			v_i_60 += 1
	var v_terrace_61: Variant = func(v_topPath_62, v_facePath_63, v_box_64, v_arg_65 = null):
		if v_arg_65 == null:
			v_arg_65 = merge_dicts([])
		var v_unpack_66: Variant = v_arg_65
		var v_material_67: Variant = fallback(getv(v_unpack_66, "material"), getv(v_rule_2, "material"))
		var v_depth_68: Variant = fallback(getv(v_unpack_66, "depth"), 1.0)
		var v_options_69: Variant = without(v_unpack_66, ["material","depth"])
		var v_own_70: Variant = merge_dicts([{"field": worldField(v_material_67, v_w_1)}, v_options_69])
		invoke(v_surf_18, [v_facePath_63, v_box_64, merge_dicts([v_side_10, v_own_70, {"height": make_field("return (((fbm((x*0.017),(y*0.006),@0@)*19.0)*@1@)+(sin(((y*0.045)+(x*0.014)))*3.0));", [getv(v_w_1, "worldSeed"), v_depth_68])}])])
		for v_item_71 in [getv(v_p_6, "c"), getv(v_p_6, "mc"), getv(v_p_6, "fc")]:
			var v_c_72: Variant = v_item_71
			invoke_member(v_c_72, "save", [])
			invoke_member(v_c_72, "clip", [v_facePath_63])
		var v_j_73: Variant = 0.0
		while truth((v_j_73 < 11.0)):
			var v_yy_74: Variant = add(getv(v_box_64, 1.0), (((getv(v_box_64, 3.0) - getv(v_box_64, 1.0)) * add(v_j_73, 0.5)) / 11.0))
			var v_x_75: Variant = getv(v_box_64, 0.0)
			var v_wid_76: Variant = (getv(v_box_64, 2.0) - getv(v_box_64, 0.0))
			invoke_member(v_p_6, "stroke", [("M" + text_value(v_x_75) + " " + text_value(v_yy_74) + "Q" + text_value(add(v_x_75, (v_wid_76 * 0.3))) + " " + text_value(add(v_yy_74, 17.0)) + " " + text_value(add(v_x_75, (v_wid_76 * 0.58))) + " " + text_value((v_yy_74 - 9.0)) + "T" + text_value(add(v_x_75, v_wid_76)) + " " + text_value(add(v_yy_74, 6.0)) + ""), (getv(v_C_3, "stoneShadow") if truth(fmod(v_j_73, 3.0)) else getv(v_C_3, "salt")), 1.2, 0.2])
			v_j_73 += 1
		for v_item_77 in [getv(v_p_6, "c"), getv(v_p_6, "mc"), getv(v_p_6, "fc")]:
			var v_c_78: Variant = v_item_77
			invoke_member(v_c_78, "restore", [])
		invoke(v_surf_18, [v_topPath_62, v_box_64, merge_dicts([v_top_9, v_own_70, {"height": make_field("return (fbm((x*0.017),(y*0.024),@0@)*4.0);", [getv(v_w_1, "worldSeed")])}])])
		if truth((v_material_67 in ["sand", "frost", "basalt", "bone", "ridge"])):
			for v_item_79 in [getv(v_p_6, "c"), getv(v_p_6, "mc"), getv(v_p_6, "fc")]:
				var v_c_80: Variant = v_item_79
				invoke_member(v_c_80, "save", [])
				invoke_member(v_c_80, "clip", [v_topPath_62])
			var v_j_81: Variant = 0.0
			while truth((v_j_81 < 10.0)):
				var v_i_82: Variant = 0.0
				while truth((v_i_82 < 11.0)):
					var v_x_83: Variant = (add(getv(v_box_64, 0.0), (v_i_82 * 33.0)) - (v_j_81 * 11.0))
					var v_y_84: Variant = add(add(getv(v_box_64, 1.0), (v_j_81 * 21.0)), (v_i_82 * 8.0))
					if truth((invoke(v_r_4, []) < 0.35)):
						v_i_82 += 1
						continue
					invoke_member(v_p_6, "line", [("M" + text_value(v_x_83) + " " + text_value(v_y_84) + "l29,7l-10,15"), getv(v_C_3, "stoneShadow"), 1.0, 0.25])
					if truth((invoke(v_r_4, []) > 0.7)):
						invoke_member(v_p_6, "stroke", [("M" + text_value(add(v_x_83, 3.0)) + " " + text_value(add(v_y_84, 2.0)) + "l20,5"), getv(v_C_3, "salt"), 1.2, 0.28])
					v_i_82 += 1
				v_j_81 += 1
			for v_item_85 in [getv(v_p_6, "c"), getv(v_p_6, "mc"), getv(v_p_6, "fc")]:
				var v_c_86: Variant = v_item_85
				invoke_member(v_c_86, "restore", [])
		invoke_member(v_p_6, "stroke", [v_topPath_62, getv(v_C_3, "salt"), 1.3, 0.14])
	var v_stair_87: Variant = func(v_x_88, v_y_89, v_dx_90, v_dy_91, v_n_92, v_width_93, v_options_94 = null):
		if v_options_94 == null:
			v_options_94 = merge_dicts([])
		var v_i_95: Variant = 0.0
		while truth((v_i_95 < v_n_92)):
			var v_a_96: Variant = add(v_x_88, (v_i_95 * v_dx_90))
			var v_b_97: Variant = add(v_y_89, (v_i_95 * v_dy_91))
			invoke(v_surf_18, [("M" + text_value((v_a_96 - (v_width_93 / 2.0))) + " " + text_value(v_b_97) + "l" + text_value(v_width_93) + "," + text_value(((-v_width_93) * 0.19)) + "l" + text_value(v_dx_90) + "," + text_value(v_dy_91) + "l" + text_value((-v_width_93)) + "," + text_value((v_width_93 * 0.19)) + "Z"), [((v_a_96 - (v_width_93 / 2.0)) - 7.0), ((v_b_97 - (v_width_93 * 0.21)) - 4.0), add(add(v_a_96, (v_width_93 / 2.0)), 12.0), add(add(v_b_97, v_dy_91), 8.0)], merge_dicts([v_top_9, v_options_94, {"bump": 0.35}])])
			invoke_member(v_p_6, "line", [("M" + text_value((v_a_96 - (v_width_93 / 2.0))) + " " + text_value(add(v_b_97, v_dy_91)) + "l" + text_value(v_width_93) + "," + text_value(((-v_width_93) * 0.19)) + ""), getv(v_w_1, "c0"), 1.8, 0.72])
			invoke_member(v_p_6, "stroke", [("M" + text_value(add((v_a_96 - (v_width_93 / 2.0)), 3.0)) + " " + text_value(v_b_97) + "l" + text_value((v_width_93 - 6.0)) + "," + text_value(((-v_width_93) * 0.19)) + ""), getv(v_C_3, "salt"), 1.2, 0.6])
			v_i_95 += 1
	var v_opening_98: Variant = func(v_x_99, v_y_100, v_width_101, v_height_102, v_tilt_103 = null):
		if v_tilt_103 == null:
			v_tilt_103 = 0.0
		var v_d_104: Variant = ("M" + text_value((v_x_99 - (v_width_101 / 2.0))) + " " + text_value(v_y_100) + "L" + text_value((v_x_99 - (v_width_101 / 2.0))) + " " + text_value((v_y_100 - (v_height_102 * 0.53))) + "Q" + text_value((v_x_99 - (v_width_101 * 0.43))) + " " + text_value((v_y_100 - (v_height_102 * 0.85))) + " " + text_value(v_x_99) + " " + text_value((v_y_100 - v_height_102)) + "Q" + text_value(add(v_x_99, (v_width_101 * 0.4))) + " " + text_value(add((v_y_100 - (v_height_102 * 0.8)), v_tilt_103)) + " " + text_value(add(v_x_99, (v_width_101 / 2.0))) + " " + text_value(add((v_y_100 - (v_height_102 * 0.53)), v_tilt_103)) + "L" + text_value(add(v_x_99, (v_width_101 / 2.0))) + " " + text_value(add(v_y_100, v_tilt_103)) + "Z")
		invoke_member(v_p_6, "fill", [v_d_104, getv(v_w_1, "c0"), 0.97])
		invoke_member(v_p_6, "stroke", [("M" + text_value(((v_x_99 - (v_width_101 / 2.0)) - 2.0)) + " " + text_value(v_y_100) + "L" + text_value(((v_x_99 - (v_width_101 / 2.0)) - 2.0)) + " " + text_value((v_y_100 - (v_height_102 * 0.53))) + "Q" + text_value((v_x_99 - (v_width_101 * 0.4))) + " " + text_value((v_y_100 - (v_height_102 * 0.87))) + " " + text_value(v_x_99) + " " + text_value((v_y_100 - v_height_102)) + ""), getv(v_C_3, "salt"), 3.0, 0.65])
		invoke_member(v_p_6, "line", [("M" + text_value((add(v_x_99, (v_width_101 / 2.0)) - 4.0)) + " " + text_value(add(v_y_100, v_tilt_103)) + "v" + text_value(((-v_height_102) * 0.5)) + ""), mix(getv(v_w_1, "c2"), getv(v_w_1, "c0"), 0.4), 3.0, 0.8])
	var v_hall_105: Variant = func(v_x_106, v_y_107, v_width_108, v_height_109, v_arg_110 = null):
		if v_arg_110 == null:
			v_arg_110 = merge_dicts([])
		var v_unpack_111: Variant = v_arg_110
		var v_material_112: Variant = fallback(getv(v_unpack_111, "material"), "masonry")
		var v_roof_113: Variant = fallback(getv(v_unpack_111, "roof"), "tile")
		var v_tower_114: Variant = fallback(getv(v_unpack_111, "tower"), false)
		var v_windows_115: Variant = fallback(getv(v_unpack_111, "windows"), 3.0)
		var v_a_116: Variant = (v_width_108 * 0.36)
		var v_h_117: Variant = v_height_109
		var v_mat_118: Variant = (v_built_11 if truth((v_material_112 == "masonry")) else merge_dicts([v_base_8, {"mat": v_material_112, "field": worldField(v_material_112, v_w_1)}]))
		var v_far_119: Variant = add(v_x_106, v_width_108)
		invoke_member(v_p_6, "shadow", [("M" + text_value((v_x_106 - 10.0)) + " " + text_value(v_y_107) + "L" + text_value(add(v_far_119, 30.0)) + " " + text_value(add(v_y_107, (v_width_108 * 0.26))) + "L" + text_value((v_far_119 - 26.0)) + " " + text_value(add(v_y_107, (v_width_108 * 0.48))) + "L" + text_value((v_x_106 - 34.0)) + " " + text_value(add(v_y_107, 28.0)) + "Z"), 0.45, 5.0])
		invoke(v_surf_18, [("M" + text_value(v_x_106) + " " + text_value((v_y_107 - v_h_117)) + "Q" + text_value(add(v_x_106, (v_a_116 * 0.42))) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.7))) + " " + text_value(add(v_x_106, v_a_116)) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.5))) + "L" + text_value(add(v_x_106, v_a_116)) + " " + text_value((v_y_107 - (v_a_116 * 0.5))) + "L" + text_value(v_x_106) + " " + text_value(v_y_107) + "Z"), [(v_x_106 - 4.0), ((v_y_107 - v_h_117) - (v_a_116 * 0.75)), add(v_far_119, 4.0), add(v_y_107, 10.0)], merge_dicts([v_mat_118, {"normal": [(-0.65), 0.0, 0.76], "ambient": [0.1, 0.13, 0.16]}])])
		invoke(v_surf_18, [("M" + text_value(v_x_106) + " " + text_value((v_y_107 - v_h_117)) + "Q" + text_value(add(v_x_106, (v_width_108 * 0.4))) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.07))) + " " + text_value(v_far_119) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.24))) + "L" + text_value(v_far_119) + " " + text_value(add(v_y_107, (v_width_108 * 0.25))) + "Q" + text_value(add(v_x_106, (v_width_108 * 0.45))) + " " + text_value(add(v_y_107, (v_width_108 * 0.1))) + " " + text_value(v_x_106) + " " + text_value(v_y_107) + "Z"), [(v_x_106 - 4.0), ((v_y_107 - v_h_117) - 4.0), add(v_far_119, 4.0), add(v_y_107, (v_width_108 * 0.28))], merge_dicts([v_mat_118, {"normal": [0.16, 0.12, 0.98]}])])
		if truth((v_roof_113 == "tile")):
			invoke(v_surf_18, [("M" + text_value((v_x_106 - 10.0)) + " " + text_value(add((v_y_107 - v_h_117), 4.0)) + "Q" + text_value(add(v_x_106, (v_a_116 * 0.55))) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.65))) + " " + text_value(add(v_x_106, v_a_116)) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.59))) + "L" + text_value(add(v_far_119, 17.0)) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.06))) + "L" + text_value(add(v_far_119, 5.0)) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.27))) + "Q" + text_value(add(v_x_106, (v_width_108 * 0.45))) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.11))) + " " + text_value((v_x_106 - 10.0)) + " " + text_value(add((v_y_107 - v_h_117), 4.0)) + "Z"), [(v_x_106 - 15.0), ((v_y_107 - v_h_117) - (v_a_116 * 0.7)), add(v_far_119, 24.0), add((v_y_107 - v_h_117), (v_width_108 * 0.3))], merge_dicts([v_top_9, {"mat": "metal", "field": null, "color": mix(getv(v_w_1, "c2"), getv(v_C_3, "copper"), 0.4), "shadow": getv(v_C_3, "stoneShadow"), "height": make_field("return (sin(((x+(y*0.3))*0.24))*1.6);", [])}])])
			var v_i_120: Variant = 1.0
			while truth((v_i_120 < 8.0)):
				var v_xx_121: Variant = add(v_x_106, ((v_width_108 * v_i_120) / 8.0))
				var v_yy_122: Variant = add((v_y_107 - v_h_117), (((v_width_108 * v_i_120) * 0.24) / 8.0))
				invoke_member(v_p_6, "stroke", [("M" + text_value(v_xx_121) + " " + text_value(v_yy_122) + "l" + text_value((v_a_116 * 0.44)) + "," + text_value(((-v_a_116) * 0.5)) + ""), getv(v_C_3, "salt"), 1.0, 0.35])
				v_i_120 += 1
		else:
			if truth((v_roof_113 == "snow")):
				invoke(v_surf_18, [("M" + text_value((v_x_106 - 13.0)) + " " + text_value(add((v_y_107 - v_h_117), 6.0)) + "Q" + text_value(add(v_x_106, (v_a_116 * 0.5))) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.82))) + " " + text_value(add(v_x_106, v_a_116)) + " " + text_value(((v_y_107 - v_h_117) - (v_a_116 * 0.64))) + "L" + text_value(add(v_far_119, 12.0)) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.09))) + "L" + text_value(add(v_far_119, 9.0)) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.3))) + "Q" + text_value(add(v_x_106, (v_width_108 * 0.4))) + " " + text_value(add((v_y_107 - v_h_117), (v_width_108 * 0.09))) + " " + text_value((v_x_106 - 13.0)) + " " + text_value(add((v_y_107 - v_h_117), 6.0)) + "Z"), [(v_x_106 - 18.0), ((v_y_107 - v_h_117) - (v_a_116 * 0.87)), add(v_far_119, 19.0), add((v_y_107 - v_h_117), (v_width_108 * 0.32))], merge_dicts([v_top_9, {"field": worldField("frost", v_w_1), "color": mix(getv(v_w_1, "c3"), getv(v_w_1, "star"), 0.28), "accent": getv(v_w_1, "star"), "bump": 0.2}])])
			else:
				if truth((v_roof_113 == "broken")):
					var v_i_123: Variant = 0.0
					while truth((v_i_123 < 5.0)):
						var v_xx_124: Variant = add(v_x_106, ((v_width_108 * v_i_123) / 5.0))
						var v_yy_125: Variant = add((v_y_107 - v_h_117), (((v_width_108 * 0.24) * v_i_123) / 5.0))
						invoke(v_surf_18, [("M" + text_value(v_xx_124) + " " + text_value(v_yy_125) + "l4,-12l12,3l2,14Z"), [(v_xx_124 - 2.0), (v_yy_125 - 15.0), add(v_xx_124, 20.0), add(v_yy_125, 10.0)], merge_dicts([v_mat_118, {"color": getv(v_C_3, "salt")}])])
						v_i_123 += 1
		var v_i_126: Variant = 0.0
		while truth((v_i_126 < v_windows_115)):
			invoke(v_opening_98, [add(v_x_106, ((v_width_108 * add(v_i_126, 0.5)) / v_windows_115)), (add(v_y_107, (((v_width_108 * 0.24) * add(v_i_126, 0.5)) / v_windows_115)) - 7.0), (v_width_108 / (v_windows_115 * 2.4)), (v_height_109 * (0.74 if truth((v_i_126 == 0.0)) else 0.55)), (v_width_108 * 0.035)])
			v_i_126 += 1
		var v_i_127: Variant = 0.0
		while truth((v_i_127 <= v_windows_115)):
			var v_xx_128: Variant = add(v_x_106, ((v_width_108 * v_i_127) / v_windows_115))
			var v_yy_129: Variant = add(v_y_107, (((v_width_108 * 0.24) * v_i_127) / v_windows_115))
			invoke_member(v_p_6, "stroke", [("M" + text_value(v_xx_128) + " " + text_value(v_yy_129) + "l2," + text_value(((-v_h_117) * 0.8)) + ""), getv(v_C_3, "salt"), 3.0, 0.48])
			v_i_127 += 1
		invoke(v_surf_18, [("M" + text_value((v_x_106 - 5.0)) + " " + text_value(v_y_107) + "L" + text_value(add(v_far_119, 5.0)) + " " + text_value(add(v_y_107, (v_width_108 * 0.25))) + "L" + text_value(add(v_far_119, 7.0)) + " " + text_value(add(add(v_y_107, (v_width_108 * 0.25)), 9.0)) + "L" + text_value((v_x_106 - 6.0)) + " " + text_value(add(v_y_107, 8.0)) + "Z"), [(v_x_106 - 10.0), (v_y_107 - 4.0), add(v_far_119, 12.0), add(add(v_y_107, (v_width_108 * 0.25)), 14.0)], merge_dicts([v_mat_118, {"normal": [0.4, 0.1, 0.9], "exposure": 0.65}])])
		var v_i_130: Variant = 0.0
		while truth((v_i_130 < v_windows_115)):
			var v_xx_131: Variant = add(v_x_106, ((v_width_108 * add(v_i_130, 0.5)) / v_windows_115))
			var v_yy_132: Variant = (add(v_y_107, (((v_width_108 * 0.24) * add(v_i_130, 0.5)) / v_windows_115)) - 4.0)
			invoke_member(v_p_6, "stroke", [("M" + text_value((v_xx_131 - (v_width_108 / (v_windows_115 * 5.0)))) + " " + text_value(v_yy_132) + "l" + text_value((v_width_108 / (v_windows_115 * 2.6))) + "," + text_value((v_width_108 * 0.025)) + ""), getv(v_C_3, "salt"), 1.6, 0.5])
			v_i_130 += 1
		return [add(v_x_106, (v_width_108 * 0.5)), add(v_y_107, (v_width_108 * 0.1))]
	var v_cloth_133: Variant = func(v_x_134, v_y_135, v_width_136, v_height_137, v_color_138 = null):
		if v_color_138 == null:
			v_color_138 = getv(v_C_3, "violet")
		var v_d_139: Variant = ("M" + text_value(v_x_134) + " " + text_value(v_y_135) + "Q" + text_value(add(v_x_134, (v_width_136 * 0.5))) + " " + text_value(add(v_y_135, 12.0)) + " " + text_value(add(v_x_134, v_width_136)) + " " + text_value(add(v_y_135, 5.0)) + "L" + text_value((add(v_x_134, v_width_136) - 8.0)) + " " + text_value(add(v_y_135, v_height_137)) + "L" + text_value(add(v_x_134, (v_width_136 * 0.5))) + " " + text_value((add(v_y_135, v_height_137) - 8.0)) + "L" + text_value(add(v_x_134, 5.0)) + " " + text_value(add(add(v_y_135, v_height_137), 5.0)) + "Z")
		invoke(v_surf_18, [v_d_139, [(v_x_134 - 4.0), (v_y_135 - 4.0), add(add(v_x_134, v_width_136), 4.0), add(add(v_y_135, v_height_137), 10.0)], {"mat": "cloth", "field": null, "color": v_color_138, "shadow": getv(v_w_1, "c1"), "accent": getv(v_C_3, "salt"), "normal": [0.2, 0.0, 1.0], "height": foldField([[[add(v_x_134, (v_width_136 * 0.25)), add(v_y_135, 5.0)], [add(v_x_134, (v_width_136 * 0.5)), add(v_y_135, 20.0)], [add(v_x_134, (v_width_136 * 0.2)), add(v_y_135, (v_height_137 * 0.7))], [add(v_x_134, (v_width_136 * 0.3)), add(v_y_135, v_height_137)], 10.0, 7.0]])}])
		invoke_member(v_p_6, "line", [("M" + text_value((v_x_134 - 4.0)) + " " + text_value((v_y_135 - 2.0)) + "l" + text_value(add(v_width_136, 8.0)) + ",7"), getv(v_C_3, "copper"), 2.0, 0.85])
	var v_bridge_140: Variant = func(v_x_141, v_y_142, v_xx_143, v_yy_144, v_width_145 = null, v_arg_146 = null):
		if v_width_145 == null:
			v_width_145 = 30.0
		if v_arg_146 == null:
			v_arg_146 = merge_dicts([])
		var v_unpack_147: Variant = v_arg_146
		var v_rope_148: Variant = fallback(getv(v_unpack_147, "rope"), true)
		var v_dx_149: Variant = (v_xx_143 - v_x_141)
		var v_dy_150: Variant = (v_yy_144 - v_y_142)
		invoke(v_surf_18, [("M" + text_value(v_x_141) + " " + text_value(v_y_142) + "Q" + text_value(add(v_x_141, (v_dx_149 * 0.45))) + " " + text_value((add(v_y_142, (v_dy_150 * 0.5)) - 10.0)) + " " + text_value(v_xx_143) + " " + text_value(v_yy_144) + "L" + text_value(add(v_xx_143, 4.0)) + " " + text_value(add(v_yy_144, v_width_145)) + "Q" + text_value(add(v_x_141, (v_dx_149 * 0.5))) + " " + text_value(add(add(add(v_y_142, (v_dy_150 * 0.5)), v_width_145), 2.0)) + " " + text_value(add(v_x_141, 3.0)) + " " + text_value(add(v_y_142, v_width_145)) + "Z"), [([v_x_141, v_xx_143].min() - 5.0), ([v_y_142, v_yy_144].min() - 15.0), add([v_x_141, v_xx_143].max(), 10.0), add(add([v_y_142, v_yy_144].max(), v_width_145), 7.0)], merge_dicts([v_wood_12, {"normal": [0.0, (-0.65), 0.76], "height": make_field("return (sin((x*0.23))*1.3);", [])}])])
		var v_i_151: Variant = 0.0
		while truth((v_i_151 < (abs(v_dx_149) / 12.0))):
			var v_t_152: Variant = (v_i_151 / (abs(v_dx_149) / 12.0))
			var v_a_153: Variant = add(v_x_141, (v_dx_149 * v_t_152))
			var v_b_154: Variant = add(v_y_142, (v_dy_150 * v_t_152))
			invoke_member(v_p_6, "line", [("M" + text_value(v_a_153) + " " + text_value(v_b_154) + "l4," + text_value(v_width_145) + ""), getv(v_w_1, "c0"), 1.0, 0.65])
			v_i_151 += 1
		if truth(v_rope_148):
			var v_side_155: Variant = 0.0
			while truth((v_side_155 < 2.0)):
				var v_offset_156: Variant = (v_side_155 * v_width_145)
				invoke_member(v_p_6, "line", [("M" + text_value(v_x_141) + " " + text_value(add((v_y_142 - 28.0), v_offset_156)) + "Q" + text_value((add(v_x_141, v_xx_143) * 0.5)) + " " + text_value(add((add(v_y_142, v_yy_144) * 0.5), v_offset_156)) + " " + text_value(v_xx_143) + " " + text_value(add((v_yy_144 - 28.0), v_offset_156)) + ""), getv(v_C_3, "copper"), 1.5, 0.85])
				var v_t_157: Variant = 0.0
				while truth((v_t_157 <= 1.0)):
					var v_a_158: Variant = add(v_x_141, (v_dx_149 * v_t_157))
					var v_b_159: Variant = add(add(v_y_142, (v_dy_150 * v_t_157)), v_offset_156)
					invoke_member(v_p_6, "line", [("M" + text_value(v_a_158) + " " + text_value(v_b_159) + "v-28"), getv(v_C_3, "stone"), 2.0, 0.8])
					v_t_157 += 0.25
				v_side_155 += 1
	var v_basin_160: Variant = func(v_x_161, v_y_162, v_rx_163, v_ry_164, v_arg_165 = null):
		if v_arg_165 == null:
			v_arg_165 = merge_dicts([])
		var v_unpack_166: Variant = v_arg_165
		var v_liquid_167: Variant = fallback(getv(v_unpack_166, "liquid"), "water")
		var v_color_168: Variant = fallback(getv(v_unpack_166, "color"), getv(v_w_1, "c2"))
		var v_emission_169: Variant = fallback(getv(v_unpack_166, "emission"), 0.08)
		invoke(v_surf_18, [ellipse(v_x_161, v_y_162, v_rx_163, v_ry_164), invoke(v_rect_13, [v_x_161, v_y_162, v_rx_163, v_ry_164]), merge_dicts([v_top_9, {"color": getv(v_C_3, "stone")}])])
		invoke(v_surf_18, [ellipse(v_x_161, v_y_162, (v_rx_163 * 0.85), (v_ry_164 * 0.78)), invoke(v_rect_13, [v_x_161, v_y_162, v_rx_163, v_ry_164]), merge_dicts([v_side_10, {"color": mix(getv(v_w_1, "c1"), getv(v_w_1, "c0"), 0.4)}])])
		invoke_member(v_p_6, "shadow", [ellipse(v_x_161, (v_y_162 - 3.0), (v_rx_163 * 0.76), (v_ry_164 * 0.63)), 0.4, 4.0])
		invoke(v_surf_18, [ellipse(v_x_161, add(v_y_162, (v_ry_164 * 0.18)), (v_rx_163 * 0.72), (v_ry_164 * 0.56)), invoke(v_rect_13, [v_x_161, v_y_162, v_rx_163, v_ry_164]), {"mat": v_liquid_167, "field": (null if truth((v_liquid_167 == "water")) else worldField(v_liquid_167, v_w_1)), "color": v_color_168, "shadow": getv(v_w_1, "c0"), "accent": getv(v_C_3, "salt"), "cx": v_x_161, "cy": v_y_162, "normal": [0.0, (-0.8), 0.6], "emission": v_emission_169, "glow": getv(v_w_1, "c4"), "bump": 0.25}])
		invoke_member(v_p_6, "stroke", [("M" + text_value((v_x_161 - (v_rx_163 * 0.8))) + " " + text_value(add(v_y_162, (v_ry_164 * 0.42))) + "Q" + text_value(v_x_161) + " " + text_value(add(v_y_162, (v_ry_164 * 1.26))) + " " + text_value(add(v_x_161, (v_rx_163 * 0.8))) + " " + text_value(add(v_y_162, (v_ry_164 * 0.42))) + ""), getv(v_C_3, "salt"), 3.0, 0.5])
	var v_supplies_170: Variant = func(v_x_171, v_y_172, v_n_173 = null):
		if v_n_173 == null:
			v_n_173 = 4.0
		var v_i_174: Variant = 0.0
		while truth((v_i_174 < v_n_173)):
			var v_a_175: Variant = add(v_x_171, (v_i_174 * 12.0))
			var v_b_176: Variant = add(v_y_172, (fmod(v_i_174, 2.0) * 6.0))
			invoke_member(v_p_6, "surface", [("M" + text_value((v_a_175 - 4.0)) + " " + text_value(v_b_176) + "q4,-4 8,0l1,12q-5,5 -10,0Z"), [(v_a_175 - 7.0), (v_b_176 - 6.0), add(v_a_175, 8.0), add(v_b_176, 17.0)], merge_dicts([v_wood_12, {"color": getv(v_C_3, "copper")}])])
			invoke_member(v_p_6, "fill", [ellipse(v_a_175, v_b_176, 4.0, 2.0), getv(v_w_1, "c0")])
			v_i_174 += 1
	var v_gallery_177: Variant = func(v_x_178, v_y_179, v_width_180 = null):
		if v_width_180 == null:
			v_width_180 = 95.0
		invoke(v_surf_18, [("M" + text_value((v_x_178 - (v_width_180 * 0.5))) + " " + text_value(v_y_179) + "Q" + text_value(v_x_178) + " " + text_value((v_y_179 - 13.0)) + " " + text_value(add(v_x_178, (v_width_180 * 0.5))) + " " + text_value(add(v_y_179, 4.0)) + "L" + text_value((add(v_x_178, (v_width_180 * 0.5)) - 6.0)) + " " + text_value(add(v_y_179, 24.0)) + "Q" + text_value(v_x_178) + " " + text_value(add(v_y_179, 9.0)) + " " + text_value(((v_x_178 - (v_width_180 * 0.5)) - 5.0)) + " " + text_value(add(v_y_179, 17.0)) + "Z"), [(v_x_178 - (v_width_180 * 0.6)), (v_y_179 - 17.0), add(v_x_178, (v_width_180 * 0.6)), add(v_y_179, 30.0)], merge_dicts([v_wood_12, {"normal": [(-0.2), (-0.7), 0.7]}])])
		var v_i_181: Variant = 0.0
		while truth((v_i_181 < 7.0)):
			var v_xx_182: Variant = add((v_x_178 - (v_width_180 * 0.5)), ((v_i_181 * v_width_180) / 6.0))
			var v_yy_183: Variant = add(v_y_179, (sin(((v_i_181 / 6.0) * PI)) * (-6.0)))
			invoke_member(v_p_6, "line", [("M" + text_value(v_xx_182) + " " + text_value(add(v_yy_183, 13.0)) + "v-25"), getv(v_C_3, "copper"), 2.0])
			invoke_member(v_p_6, "line", [("M" + text_value(v_xx_182) + " " + text_value(add(v_yy_183, 15.0)) + "l-4,35"), getv(v_C_3, "stoneShadow"), 3.0, 0.8])
			v_i_181 += 1
		invoke_member(v_p_6, "line", [("M" + text_value((v_x_178 - (v_width_180 * 0.5))) + " " + text_value((v_y_179 - 10.0)) + "Q" + text_value(v_x_178) + " " + text_value((v_y_179 - 23.0)) + " " + text_value(add(v_x_178, (v_width_180 * 0.5))) + " " + text_value((v_y_179 - 6.0)) + ""), getv(v_C_3, "salt"), 1.6, 0.7])
	var v_table_184: Variant = func(v_x_185, v_y_186, v_width_187 = null):
		if v_width_187 == null:
			v_width_187 = 58.0
		invoke_member(v_p_6, "fill", [("M" + text_value(v_x_185) + " " + text_value(add(v_y_186, 4.0)) + "v17l4,2v-17Z"), getv(v_w_1, "c0")])
		invoke_member(v_p_6, "fill", [("M" + text_value((add(v_x_185, v_width_187) - 7.0)) + " " + text_value(add(v_y_186, (v_width_187 * 0.2))) + "v18l4,1v-19Z"), getv(v_w_1, "c0")])
		invoke(v_surf_18, [("M" + text_value((v_x_185 - 3.0)) + " " + text_value(v_y_186) + "l12,-8l" + text_value(v_width_187) + "," + text_value((v_width_187 * 0.2)) + "l-12,9Z"), [(v_x_185 - 7.0), (v_y_186 - 12.0), add(add(v_x_185, v_width_187), 18.0), add(add(v_y_186, (v_width_187 * 0.2)), 15.0)], merge_dicts([v_wood_12, {"normal": [0.0, (-0.7), 0.7]}])])
	var v_finish_188: Variant = func(v_extra_189 = null):
		if v_extra_189 == null:
			v_extra_189 = merge_dicts([])
		for v_item_190 in v_lights_5:
			var v_e_191: Variant = v_item_190
			if truth((getv(v_e_191, "marker") != false)):
				invoke(v_lightMark_29, [v_e_191])
		invoke_member(v_p_6, "fade", [873.0])
		return {"p": invoke_member(v_p_6, "output", []), "features": merge_dicts([{"worldSeed": getv(v_w_1, "worldSeed"), "archetype": getv(v_w_1, "archetype"), "styleSid": getv(v_w_1, "styleSid"), "palette": getv(v_w_1, "palette"), "institution": getv(v_rule_2, "institution"), "construction": getv(v_rule_2, "translation"), "activity": getv(v_rule_2, "activity"), "materialAlgorithm": getv(v_rule_2, "material"), "lights": v_lights_5, "scope": "视觉候选，非正式游戏机构"}, v_extra_189])}
	return {"actor": v_actor_39, "brazier": v_brazier_52, "w": v_w_1, "C": v_C_3, "r": v_r_4, "p": v_p_6, "base": v_base_8, "top": v_top_9, "side": v_side_10, "built": v_built_11, "wood": v_wood_12, "surf": v_surf_18, "lamp": v_lamp_22, "lightMark": v_lightMark_29, "person": v_person_34, "queue": v_queue_58, "terrace": v_terrace_61, "stair": v_stair_87, "opening": v_opening_98, "hall": v_hall_105, "cloth": v_cloth_133, "bridge": v_bridge_140, "basin": v_basin_160, "supplies": v_supplies_170, "gallery": v_gallery_177, "table": v_table_184, "finish": v_finish_188}
