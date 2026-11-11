extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: sanctuary.js; preserve contours, ordering and seed decisions.
const M_world = preload("res://src/art_generation/algorithms/world.gd")

static func sanctuary(v_worldSeed_1 = null, v_world_2 = null, v_config_3 = null):
	if v_worldSeed_1 == null:
		v_worldSeed_1 = 1339.0
	if v_world_2 == null:
		v_world_2 = M_world.tide
	if v_config_3 == null:
		v_config_3 = merge_dicts([])
	var v_r_4: Variant = rng(v_worldSeed_1)
	var v_C_5: Variant = M_world.roles(v_world_2)
	var v_lights_6: Variant = {"well": {"id": "well", "x": 615.0, "y": 580.0, "z": 48.0, "r": 184.0, "color": [87.0, 238.0, 179.0], "power": 0.66, "falloff": 1.7, "specular": 0.2}, "altar": {"id": "altar", "x": 337.0, "y": 361.0, "z": 52.0, "r": 168.0, "color": [255.0, 140.0, 57.0], "power": 0.92, "falloff": 1.75, "specular": 0.1, "visibility": make_field("return (sm(273.0,310.0,x)*(1.0-sm(420.0,485.0,x)));", [])}, "stair": {"id": "stair", "x": 270.0, "y": 526.0, "z": 38.0, "r": 118.0, "color": [255.0, 145.0, 62.0], "power": 0.78, "falloff": 1.8, "specular": 0.09}}
	var v_Painter_7: Variant = Painter
	var v_p_8: Variant = Painter.new(v_worldSeed_1, {"emitters": v_lights_6.values()})
	var v_rock_9: Variant = {"mat": "stone", "color": getv(v_C_5, "stone"), "shadow": getv(v_C_5, "stoneShadow"), "accent": getv(v_C_5, "salt"), "scale": 40.0, "bump": 0.8}
	var v_top_10: Variant = merge_dicts([v_rock_9, {"normal": [(-0.36), (-0.64), 0.7], "exposure": 1.02}])
	var v_wall_11: Variant = merge_dicts([v_rock_9, {"normal": [0.1, 0.17, 1.0], "color": mix(getv(v_C_5, "stone"), getv(v_C_5, "wet"), 0.22), "exposure": 0.96}])
	var v_dark_12: Variant = merge_dicts([v_rock_9, {"normal": [0.31, 0.12, 0.88], "color": "#456457", "exposure": 0.86, "ambient": [0.16, 0.22, 0.27]}])
	var v_riser_13: Variant = merge_dicts([v_rock_9, {"normal": [0.48, 0.18, 0.82], "ambient": [0.12, 0.17, 0.2], "exposure": 0.85, "bump": 0.62}])
	var v_surface_14: Variant = func(v_d_15, v_box_16, v_o_17 = null):
		if v_o_17 == null:
			v_o_17 = merge_dicts([])
		invoke_member(v_p_8, "surface", [v_d_15, v_box_16, merge_dicts([v_rock_9, v_o_17])])
	var v_crack_18: Variant = func(v_d_19, v_width_20 = null):
		if v_width_20 == null:
			v_width_20 = 1.0
		invoke_member(v_p_8, "line", [v_d_19, "#102831", v_width_20, 0.65])
	var v_flame_21: Variant = func(v_x_22, v_y_23, v_s_24 = null):
		if v_s_24 == null:
			v_s_24 = 1.0
		invoke_member(v_p_8, "line", [("M" + text_value(v_x_22) + "," + text_value(v_y_23) + "v" + text_value((8.0 * v_s_24)) + ""), "#776745", (2.0 * v_s_24)])
		invoke_member(v_p_8, "fill", [ellipse(v_x_22, v_y_23, (2.0 * v_s_24), (4.0 * v_s_24)), "#ffdda0"])
		invoke_member(v_p_8, "fill", [ellipse(v_x_22, (v_y_23 - 1.0), (1.0 * v_s_24), (2.0 * v_s_24)), "#fff4cd"])
		invoke_member(v_p_8, "glow", [v_x_22, v_y_23, (24.0 * v_s_24), "#e4aa5e", 0.22])
	var v_brazier_25: Variant = func(v_e_26, v_s_27 = null):
		if v_s_27 == null:
			v_s_27 = 1.0
		var v_unpack_28: Variant = v_e_26
		var v_x_29: Variant = getv(v_unpack_28, "x")
		var v_y_30: Variant = getv(v_unpack_28, "y")
		invoke_member(v_p_8, "fill", [ellipse(add(v_x_29, (5.0 * v_s_27)), add(v_y_30, (24.0 * v_s_27)), (14.0 * v_s_27), (4.0 * v_s_27)), "#0b171d", 0.55])
		invoke(v_surface_14, [("M" + text_value((v_x_29 - (4.0 * v_s_27))) + "," + text_value(add(v_y_30, (9.0 * v_s_27))) + "L" + text_value((v_x_29 - (3.0 * v_s_27))) + "," + text_value(add(v_y_30, (23.0 * v_s_27))) + "L" + text_value(add(v_x_29, (4.0 * v_s_27))) + "," + text_value(add(v_y_30, (25.0 * v_s_27))) + "L" + text_value(add(v_x_29, (5.0 * v_s_27))) + "," + text_value(add(v_y_30, (9.0 * v_s_27))) + "Z"), [(v_x_29 - (6.0 * v_s_27)), add(v_y_30, (7.0 * v_s_27)), add(v_x_29, (8.0 * v_s_27)), add(v_y_30, (27.0 * v_s_27))], {"mat": "metal", "color": getv(v_C_5, "copper"), "shadow": getv(v_C_5, "wet"), "accent": getv(v_C_5, "salt"), "normal": [(-0.3), 0.1, 1.0]}])
		invoke_member(v_p_8, "fill", [("M" + text_value((v_x_29 - (11.0 * v_s_27))) + "," + text_value(add(v_y_30, (4.0 * v_s_27))) + "Q" + text_value(v_x_29) + "," + text_value(add(v_y_30, (19.0 * v_s_27))) + " " + text_value(add(v_x_29, (11.0 * v_s_27))) + "," + text_value(add(v_y_30, (4.0 * v_s_27))) + "Z"), "#6e5739"])
		invoke_member(v_p_8, "fill", [ellipse(v_x_29, add(v_y_30, (4.0 * v_s_27)), (11.0 * v_s_27), (3.8 * v_s_27)), "#cf8b46"])
		invoke_member(v_p_8, "glow", [v_x_29, v_y_30, (54.0 * v_s_27), "#ffa64b", 0.33])
		invoke_member(v_p_8, "fill", [("M" + text_value((v_x_29 - (5.0 * v_s_27))) + "," + text_value(add(v_y_30, (4.0 * v_s_27))) + "Q" + text_value((v_x_29 - (7.0 * v_s_27))) + "," + text_value((v_y_30 - (3.0 * v_s_27))) + " " + text_value((v_x_29 - (2.0 * v_s_27))) + "," + text_value((v_y_30 - (10.0 * v_s_27))) + "Q" + text_value((v_x_29 - (2.0 * v_s_27))) + "," + text_value((v_y_30 - (3.0 * v_s_27))) + " " + text_value(add(v_x_29, (2.0 * v_s_27))) + "," + text_value((v_y_30 - (5.0 * v_s_27))) + "L" + text_value(add(v_x_29, (4.0 * v_s_27))) + "," + text_value((v_y_30 - (13.0 * v_s_27))) + "Q" + text_value(add(v_x_29, (11.0 * v_s_27))) + "," + text_value(add(v_y_30, (1.0 * v_s_27))) + " " + text_value(add(v_x_29, (5.0 * v_s_27))) + "," + text_value(add(v_y_30, (5.0 * v_s_27))) + "Z"), "#ffc069"])
		invoke_member(v_p_8, "fill", [ellipse(add(v_x_29, (1.0 * v_s_27)), v_y_30, (2.5 * v_s_27), (5.0 * v_s_27)), "#fff0bb"])
	var v_pilgrim_31: Variant = func(v_x_32, v_y_33, v_s_34 = null, v_light_35 = null, v_bow_36 = null):
		if v_s_34 == null:
			v_s_34 = 1.0
		if v_light_35 == null:
			v_light_35 = false
		if v_bow_36 == null:
			v_bow_36 = false
		invoke_member(v_p_8, "fill", [ellipse(add(v_x_32, (6.0 * v_s_34)), add(v_y_33, (2.0 * v_s_34)), (10.0 * v_s_34), (3.2 * v_s_34)), "#04131a", 0.65])
		invoke_member(v_p_8, "fill", [("M" + text_value((v_x_32 - (5.0 * v_s_34))) + "," + text_value((v_y_33 - (17.0 * v_s_34))) + "Q" + text_value((v_x_32 - (9.0 * v_s_34))) + "," + text_value((v_y_33 - (5.0 * v_s_34))) + " " + text_value((v_x_32 - (9.0 * v_s_34))) + "," + text_value(v_y_33) + "Q" + text_value(v_x_32) + "," + text_value(add(v_y_33, (4.0 * v_s_34))) + " " + text_value(add(v_x_32, (7.0 * v_s_34))) + "," + text_value(v_y_33) + "L" + text_value(add(v_x_32, (5.0 * v_s_34))) + "," + text_value((v_y_33 - (17.0 * v_s_34))) + "Z"), ("#788e75" if truth(v_light_35) else "#233a3a")])
		invoke_member(v_p_8, "fill", [("M" + text_value((v_x_32 - (4.0 * v_s_34))) + "," + text_value((v_y_33 - (17.0 * v_s_34))) + "Q" + text_value((v_x_32 - (2.0 * v_s_34))) + "," + text_value((v_y_33 - (29.0 * v_s_34))) + " " + text_value(add(v_x_32, (2.0 * v_s_34))) + "," + text_value((v_y_33 - (26.0 * v_s_34))) + "Q" + text_value(add(v_x_32, (7.0 * v_s_34))) + "," + text_value((v_y_33 - (23.0 * v_s_34))) + " " + text_value(add(v_x_32, (5.0 * v_s_34))) + "," + text_value((v_y_33 - (17.0 * v_s_34))) + "Z"), ("#b7b99a" if truth(v_light_35) else "#567466")])
		invoke_member(v_p_8, "fill", [ellipse(add(v_x_32, ((3.0 if truth(v_bow_36) else 1.0) * v_s_34)), (v_y_33 - (20.0 * v_s_34)), (2.6 * v_s_34), (3.3 * v_s_34)), "#08191f"])
		invoke_member(v_p_8, "line", [("M" + text_value((v_x_32 - (3.0 * v_s_34))) + "," + text_value((v_y_33 - (15.0 * v_s_34))) + "l" + text_value(((-2.0) * v_s_34)) + "," + text_value((12.0 * v_s_34)) + ""), ("#bac29e" if truth(v_light_35) else "#718977"), (1.4 * v_s_34), 0.8])
		if truth(v_bow_36):
			invoke_member(v_p_8, "line", [("M" + text_value(add(v_x_32, (3.0 * v_s_34))) + "," + text_value((v_y_33 - (13.0 * v_s_34))) + "l" + text_value((6.0 * v_s_34)) + "," + text_value((3.0 * v_s_34)) + ""), ("#9bac8d" if truth(v_light_35) else "#566c5d"), (2.0 * v_s_34)])
	var v_stair_37: Variant = func(v_x_38, v_y_39, v_dx_40, v_dy_41, v_n_42, v_width_43):
		var v_i_44: Variant = 0.0
		while truth((v_i_44 < v_n_42)):
			var v_xx_45: Variant = add(v_x_38, (v_dx_40 * v_i_44))
			var v_yy_46: Variant = add(v_y_39, (v_dy_41 * v_i_44))
			var v_w_47: Variant = (v_width_43 * add(1.0, (v_i_44 * 0.004)))
			var v_d_48: Variant = ("M" + text_value((v_xx_45 - (v_w_47 * 0.5))) + "," + text_value(v_yy_46) + "l" + text_value(v_w_47) + "," + text_value(((-v_w_47) * 0.15)) + "l" + text_value((v_dx_40 * 0.85)) + "," + text_value((v_dy_41 * 0.85)) + "l" + text_value((-v_w_47)) + "," + text_value((v_w_47 * 0.15)) + "Z")
			invoke(v_surface_14, [v_d_48, [((v_xx_45 - (v_w_47 * 0.55)) - 2.0), ((v_yy_46 - (v_w_47 * 0.16)) - 2.0), add(add(add(v_xx_45, (v_w_47 * 0.55)), v_dx_40), 3.0), add(add(v_yy_46, v_dy_41), 6.0)], merge_dicts([v_top_10, {"scale": 21.0, "color": ("#879d80" if truth(fmod(v_i_44, 3.0)) else "#acb18a"), "bump": 0.45}])])
			invoke_member(v_p_8, "line", [("M" + text_value((v_xx_45 - (v_w_47 * 0.5))) + "," + text_value(add(v_yy_46, (v_dy_41 * 0.9))) + "l" + text_value(v_w_47) + "," + text_value(((-v_w_47) * 0.15)) + ""), "#172f30", 1.8, 0.9])
			invoke_member(v_p_8, "stroke", [("M" + text_value((v_xx_45 - (v_w_47 * 0.45))) + "," + text_value(v_yy_46) + "l" + text_value((v_w_47 * 0.82)) + "," + text_value(((-v_w_47) * 0.15)) + ""), "#b6bf98", 1.4, 0.65])
			v_i_44 += 1
	var v_arch_49: Variant = func(v_x_50, v_y_51, v_w_52, v_h_53, v_tilt_54 = null):
		if v_tilt_54 == null:
			v_tilt_54 = 0.0
		return ("M" + text_value((v_x_50 - (v_w_52 / 2.0))) + "," + text_value(v_y_51) + "L" + text_value((v_x_50 - (v_w_52 / 2.0))) + "," + text_value((v_y_51 - (v_h_53 * 0.55))) + "Q" + text_value((v_x_50 - (v_w_52 * 0.45))) + "," + text_value((v_y_51 - (v_h_53 * 0.85))) + " " + text_value(v_x_50) + "," + text_value((v_y_51 - v_h_53)) + "Q" + text_value(add(v_x_50, (v_w_52 * 0.4))) + "," + text_value(add((v_y_51 - (v_h_53 * 0.77)), v_tilt_54)) + " " + text_value(add(v_x_50, (v_w_52 / 2.0))) + "," + text_value(add((v_y_51 - (v_h_53 * 0.53)), v_tilt_54)) + "L" + text_value(add(v_x_50, (v_w_52 / 2.0))) + "," + text_value(add(v_y_51, v_tilt_54)) + "Z")
	var v_opening_55: Variant = func(v_x_56, v_y_57, v_w_58, v_h_59, v_lit_60 = null, v_tilt_61 = null):
		if v_lit_60 == null:
			v_lit_60 = false
		if v_tilt_61 == null:
			v_tilt_61 = 0.0
		var v_d_62: Variant = invoke(v_arch_49, [v_x_56, v_y_57, v_w_58, v_h_59, v_tilt_61])
		invoke(v_surface_14, [v_d_62, [((v_x_56 - (v_w_58 / 2.0)) - 3.0), ((v_y_57 - v_h_59) - 3.0), add(add(v_x_56, (v_w_58 / 2.0)), 3.0), add(add(v_y_57, v_tilt_61), 3.0)], {"mat": "plain", "color": ("#20322e" if truth(v_lit_60) else "#071922"), "normal": [0.0, 0.0, 1.0], "exposure": 0.35}])
		invoke_member(v_p_8, "line", [("M" + text_value(((v_x_56 - (v_w_58 / 2.0)) - 2.0)) + "," + text_value(v_y_57) + "L" + text_value(((v_x_56 - (v_w_58 / 2.0)) - 2.0)) + "," + text_value((v_y_57 - (v_h_59 * 0.55))) + "Q" + text_value((v_x_56 - (v_w_58 * 0.45))) + "," + text_value((v_y_57 - (v_h_59 * 0.85))) + " " + text_value(v_x_56) + "," + text_value((v_y_57 - v_h_59)) + "Q" + text_value(add(v_x_56, (v_w_58 * 0.4))) + "," + text_value(add((v_y_57 - (v_h_59 * 0.77)), v_tilt_61)) + " " + text_value(add(add(v_x_56, (v_w_58 / 2.0)), 2.0)) + "," + text_value(add((v_y_57 - (v_h_59 * 0.53)), v_tilt_61)) + ""), "#b3b28b", 3.0, 0.62])
		invoke_member(v_p_8, "line", [("M" + text_value(add((v_x_56 - (v_w_58 / 2.0)), 5.0)) + "," + text_value((v_y_57 - 2.0)) + "L" + text_value(add((v_x_56 - (v_w_58 / 2.0)), 5.0)) + "," + text_value((v_y_57 - (v_h_59 * 0.53))) + "Q" + text_value((v_x_56 - (v_w_58 * 0.4))) + "," + text_value((v_y_57 - (v_h_59 * 0.8))) + " " + text_value(v_x_56) + "," + text_value(add((v_y_57 - v_h_59), 7.0)) + ""), "#445d4c", 3.0, 0.7])
		if truth(v_lit_60):
			invoke_member(v_p_8, "glow", [v_x_56, (v_y_57 - (v_h_59 * 0.42)), (v_w_58 * 1.2), "#d9a965", 0.17])
			var v_k_63: Variant = 0.0
			while truth((v_k_63 < 3.0)):
				invoke(v_flame_21, [add((v_x_56 - 9.0), (v_k_63 * 9.0)), add((v_y_57 - 12.0), (fmod(v_k_63, 2.0) * 3.0)), 0.65])
				v_k_63 += 1
	for v_item_64 in [["M104 735Q135 696 198 714L282 740Q352 774 423 749Q466 740 491 769Q421 813 344 798Q279 826 198 794Q123 794 104 735Z", [100.0, 695.0, 498.0, 830.0], 0.75], ["M488 751Q584 711 687 730L822 700Q871 715 855 754Q828 794 737 785Q648 826 572 798L488 785Z", [485.0, 700.0, 876.0, 832.0], 0.65]]:
		var v_unpack_65: Variant = v_item_64
		var v_d_66: Variant = getv(v_unpack_65, 0)
		var v_b_67: Variant = getv(v_unpack_65, 1)
		var v_exp_68: Variant = getv(v_unpack_65, 2)
		invoke(v_surface_14, [v_d_66, v_b_67, {"mat": "water", "color": "#1e655b", "shadow": "#061822", "cx": (-1600.0), "cy": 2000.0, "v": make_field("return (760.0+((y-760.0)*2.1));", []), "normal": [0.0, (-0.75), 0.5], "exposure": v_exp_68, "bump": 0.3, "emission": 0.01}])
	invoke(v_surface_14, ["M422 292L470 263L496 279L511 266L530 303L574 319L568 378L541 410L462 395Z", [420.0, 260.0, 577.0, 415.0], merge_dicts([v_dark_12, {"scale": 48.0, "height": make_field("return (fbm((x*0.025),(y*0.018),@0@)*7.0);", [v_worldSeed_1])}])])
	invoke(v_surface_14, ["M575 401L615 371L655 378L662 404L700 413L723 454L706 501L634 496L594 465Z", [573.0, 370.0, 727.0, 504.0], merge_dicts([v_dark_12, {"color": "#33594f", "scale": 53.0}])])
	var v_cliff_69: Variant = "M170 431L207 408L246 422L284 400L327 419L368 413L400 438L454 443L484 478L467 532L446 558L450 610L420 641L402 710L366 728L342 692L318 726L294 706L282 760L249 776L213 754L188 719L151 704L132 658L146 623L128 576L151 549L143 496Z"
	invoke(v_surface_14, [v_cliff_69, [125.0, 398.0, 489.0, 780.0], merge_dicts([v_wall_11, {"scale": 46.0, "height": make_field("return (((26.0*fbm((x*0.008),(y*0.011),(@0@+7.0)))+(8.0*fbm((x*0.023),(y*0.024),@1@)))+(3.0*sin(((y*0.08)+(x*0.04)))));", [v_worldSeed_1, v_worldSeed_1]), "corrupt": make_field("return (exp(((-pow(((x-304.0)/82.0),2.0))-pow(((y-704.0)/67.0),2.0)))*0.65);", []), "glow": getv(v_world_2, "corruption"), "wet": make_field("return (sm(560.0,750.0,y)*(0.6+(b*0.3)));", []), "shadowField": make_field("return clamp((1.0-((x-220.0)*0.0015)),0.42,1.0);", [])}])])
	invoke_member(v_p_8, "shadow", ["M391 477L458 485L442 552L445 606L417 642L402 711L365 727L363 669L379 627L365 584Z", 0.52, 5.0])
	invoke_member(v_p_8, "shadow", ["M173 487L184 546L168 585L185 614L170 674L151 686L134 654L148 619L132 577L154 545Z", 0.32, 3.0])
	invoke(v_surface_14, ["M205 549L244 529L263 573L245 613L257 660L235 707L212 751L189 715L197 673L180 640L198 599Z", [177.0, 526.0, 267.0, 755.0], merge_dicts([v_wall_11, {"color": "#8c9b7b", "normal": [0.04, 0.22, 1.0], "height": make_field("return (fbm((x*0.025),(y*0.04),@0@)*6.0);", [v_worldSeed_1]), "wet": make_field("return sm(625.0,760.0,y);", []), "scale": 32.0}])])
	for v_item_70 in ["M184 507L203 541L198 581L214 605L205 658", "M290 481L309 516L298 548L321 578L313 629L324 658", "M355 508L343 544L353 584L340 621L347 673", "M232 689L252 681L268 692L277 722"]:
		var v_d_71: Variant = v_item_70
		invoke(v_crack_18, [v_d_71, 2.3])
	invoke(v_opening_55, [281.0, 705.0, 54.0, 102.0, false, (-9.0)])
	invoke(v_opening_55, [363.0, 653.0, 37.0, 73.0, false, (-4.0)])
	invoke_member(v_p_8, "stroke", ["M250 700Q246 640 282 601Q311 625 310 674", "#70917b", 3.0, 0.5])
	var v_terrace_72: Variant = "M161 424L213 388L259 388L293 370L359 389L414 417L469 430L491 464L460 493L418 507L382 534L338 530L300 561L264 551L219 568L192 544L204 515L170 501L179 465Z"
	invoke(v_surface_14, ["M491 464L460 493L418 507L382 534L338 530L300 561L264 551L219 568L216 589L263 575L302 586L340 555L383 559L420 532L459 517L477 501Z", [213.0, 461.0, 494.0, 592.0], merge_dicts([v_riser_13, {"scale": 35.0, "wet": make_field("return ((sm(490.0,590.0,y)*b)*0.35);", [])}])])
	invoke(v_surface_14, ["M161 424L179 465L170 501L204 515L192 544L219 568L216 589L178 563L186 530L151 516L158 468L146 444Z", [143.0, 421.0, 222.0, 592.0], merge_dicts([v_wall_11, {"color": mix(getv(v_C_5, "stone"), getv(v_C_5, "wet"), 0.3), "normal": [(-0.13), 0.3, 1.0], "scale": 35.0, "exposure": 0.8}])])
	invoke(v_surface_14, [v_terrace_72, [158.0, 368.0, 494.0, 572.0], merge_dicts([v_top_10, {"scale": 35.0, "height": make_field("return (fbm((x*0.025),(y*0.023),@0@)*4.0);", [v_worldSeed_1]), "wet": make_field("return (sm(485.0,575.0,y)*b);", [])}])])
	invoke_member(getv(v_p_8, "c"), "save", [])
	invoke_member(getv(v_p_8, "c"), "clip", [v_terrace_72])
	var v_v_73: Variant = 0.0
	while truth((v_v_73 < 7.0)):
		var v_u_74: Variant = 0.0
		while truth((v_u_74 < 12.0)):
			var v_x_75: Variant = (add(202.0, (v_u_74 * 21.0)) - (v_v_73 * 14.0))
			var v_y_76: Variant = add(add(392.0, (v_u_74 * 7.0)), (v_v_73 * 18.0))
			if truth((invoke(v_r_4, []) < 0.16)):
				v_u_74 += 1
				continue
			invoke_member(v_p_8, "stroke", [("M" + text_value(v_x_75) + "," + text_value(v_y_76) + "l18,6l-11,12"), "#283f37", 0.9, 0.5])
			if truth((invoke(v_r_4, []) > 0.68)):
				invoke_member(v_p_8, "stroke", [("M" + text_value(add(v_x_75, 2.0)) + "," + text_value(add(v_y_76, 2.0)) + "l14,4"), "#b2b693", 1.2, 0.35])
			v_u_74 += 1
		v_v_73 += 1
	invoke_member(getv(v_p_8, "c"), "restore", [])
	invoke(v_surface_14, ["M219 366L223 244L303 190L341 218L329 389L274 421Z", [216.0, 187.0, 345.0, 425.0], merge_dicts([v_wall_11, {"mat": "masonry", "color": "#516f5c", "normal": [(-0.52), 0.06, 0.85], "scale": 30.0, "height": make_field("return (fbm((x*0.03),(y*0.04),@0@)*3.0);", [v_worldSeed_1]), "pointVisibility": func(v_e_77):
		return (0.18 if truth((getv(v_e_77, "id") == "altar")) else 1.0)}])])
	invoke(v_surface_14, ["M222 245L242 229L245 221L261 223L280 202L304 191L329 207L341 218L311 235L275 245L247 269Z", [219.0, 188.0, 345.0, 273.0], merge_dicts([v_top_10, {"color": "#a3ad87", "scale": 27.0}])])
	invoke(v_opening_55, [252.0, 355.0, 24.0, 67.0, false, (-15.0)])
	invoke(v_opening_55, [290.0, 330.0, 22.0, 67.0, false, (-15.0)])
	invoke(v_surface_14, ["M232 244L251 223L270 221L286 201L306 194L332 209L349 220L362 230L351 241L329 238L311 254L292 257L276 271L258 263L246 266Z", [229.0, 191.0, 365.0, 274.0], {"mat": "metal", "color": mix(getv(v_C_5, "copper"), getv(v_C_5, "wet"), 0.48), "shadow": getv(v_C_5, "wet"), "accent": getv(v_C_5, "copper"), "normal": [(-0.35), (-0.7), 0.65], "height": make_field("return (3.0*fbm((x*0.035),(y*0.04),(@0@+11.0)));", [v_worldSeed_1]), "exposure": 0.7}])
	var v_i_78: Variant = 0.0
	while truth((v_i_78 < 7.0)):
		var v_x_79: Variant = add(249.0, (v_i_78 * 13.0))
		var v_y_80: Variant = add(238.0, (v_i_78 * 3.0))
		invoke_member(v_p_8, "stroke", [("M" + text_value(v_x_79) + "," + text_value(v_y_80) + "l16,-22"), "#7b977b", 1.8, 0.5])
		v_i_78 += 1
	var v_facade_81: Variant = "M290 260L305 251L312 234L329 237L345 213L363 230L374 261L396 272L405 259L419 269L425 288L451 294L459 286L477 298L481 322L502 332L505 440L473 463L429 450L394 440L352 423L306 413L287 393Z"
	invoke(v_surface_14, [v_facade_81, [284.0, 210.0, 510.0, 469.0], merge_dicts([v_wall_11, {"mat": "masonry", "color": mix(getv(v_C_5, "stone"), getv(v_C_5, "salt"), 0.15), "scale": 26.0, "height": make_field("return (fbm((x*0.029),(y*0.041),(@0@+9.0))*4.0);", [v_worldSeed_1]), "shadowField": make_field("return clamp((1.0-((x-325.0)*0.0019)),0.5,1.0);", [])}])])
	invoke(v_opening_55, [336.0, 400.0, 57.0, 140.0, true, 17.0])
	invoke(v_opening_55, [413.0, 425.0, 38.0, 98.0, false, 12.0])
	invoke(v_opening_55, [475.0, 445.0, 28.0, 78.0, false, 9.0])
	invoke(v_surface_14, ["M315 402L347 385L363 409L338 421Z", [312.0, 383.0, 366.0, 425.0], merge_dicts([v_top_10, {"color": "#b6ad7f", "scale": 18.0}])])
	invoke_member(v_p_8, "shadow", ["M351 282L361 304L363 413L348 407Z", 0.5, 2.0])
	for v_item_82 in [[292.0, 406.0, 122.0], [375.0, 438.0, 125.0], [447.0, 460.0, 111.0], [501.0, 458.0, 99.0]]:
		var v_unpack_83: Variant = v_item_82
		var v_x_84: Variant = getv(v_unpack_83, 0)
		var v_y_85: Variant = getv(v_unpack_83, 1)
		var v_h_86: Variant = getv(v_unpack_83, 2)
		invoke(v_surface_14, [("M" + text_value((v_x_84 - 7.0)) + "," + text_value(v_y_85) + "L" + text_value((v_x_84 - 3.0)) + "," + text_value((v_y_85 - v_h_86)) + "L" + text_value(add(v_x_84, 6.0)) + "," + text_value(add((v_y_85 - v_h_86), 4.0)) + "L" + text_value(add(v_x_84, 10.0)) + "," + text_value((v_y_85 - 21.0)) + "L" + text_value(add(v_x_84, 17.0)) + "," + text_value(add(v_y_85, 5.0)) + "L" + text_value(add(v_x_84, 5.0)) + "," + text_value(add(v_y_85, 11.0)) + "Z"), [(v_x_84 - 10.0), ((v_y_85 - v_h_86) - 3.0), add(v_x_84, 20.0), add(v_y_85, 15.0)], merge_dicts([v_wall_11, {"color": "#b4b58b", "scale": 21.0, "normal": [(-0.5), (-0.1), 0.85], "height": make_field("return (fbm((x*0.04),(y*0.05),@0@)*1.7);", [v_worldSeed_1])}])])
		invoke_member(v_p_8, "shadow", [("M" + text_value(add(v_x_84, 6.0)) + "," + text_value(add((v_y_85 - v_h_86), 5.0)) + "L" + text_value(add(v_x_84, 10.0)) + "," + text_value((v_y_85 - 21.0)) + "L" + text_value(add(v_x_84, 17.0)) + "," + text_value(add(v_y_85, 5.0)) + "L" + text_value(add(v_x_84, 9.0)) + "," + text_value(add(v_y_85, 8.0)) + "Z"), 0.4])
	var v_i_87: Variant = 0.0
	while truth((v_i_87 < 10.0)):
		var v_y_88: Variant = add(282.0, (v_i_87 * 13.0))
		invoke_member(v_p_8, "stroke", [("M296," + text_value(v_y_88) + "l35,12"), "#445443", 0.8, 0.4])
		invoke_member(v_p_8, "stroke", [("M370," + text_value(add(v_y_88, 26.0)) + "l31,10"), "#435743", 0.8, 0.4])
		invoke_member(v_p_8, "stroke", [("M434," + text_value(add(v_y_88, 46.0)) + "l30,10"), "#344c3e", 0.8, 0.4])
		v_i_87 += 1
	invoke_member(v_p_8, "shadow", ["M308 411L351 423L393 440L429 450L475 463L489 460L477 479L430 466L390 453L350 437L308 424Z", 0.56, 3.0])
	invoke_member(v_p_8, "stroke", ["M304 412L352 429L394 443L431 456", "#b5b38b", 2.0, 0.5])
	invoke_member(v_p_8, "stroke", ["M306 256L330 244L345 222L360 235", "#d1c594", 2.5, 0.8])
	invoke_member(v_p_8, "line", ["M270 254L269 166L291 153L303 160L302 238", "#374e43", 4.0])
	invoke_member(v_p_8, "line", ["M271 166L291 156L301 160", "#b4b38c", 1.7, 0.9])
	invoke_member(v_p_8, "surface", ["M280 171Q286 182 293 176L296 191L291 198L280 195L277 188Z", [275.0, 168.0, 298.0, 201.0], {"mat": "metal", "color": "#a69765", "shadow": "#2a594c", "accent": "#d0c38d", "normal": [(-0.5), 0.0, 1.0]}])
	invoke_member(v_p_8, "line", ["M287 198v7", "#8d9c74", 1.5, 0.7])
	var v_banner_89: Variant = "M237 285Q250 299 267 290L264 354L257 379L249 366L243 374Q245 341 237 316Z"
	invoke(v_surface_14, [v_banner_89, [234.0, 282.0, 270.0, 382.0], {"mat": "cloth", "color": "#759580", "shadow": "#153e3d", "accent": "#c2c09a", "height": make_field("return (4.0*sin((((x-237.0)*0.21)+((y-285.0)*0.03))));", []), "normal": [(-0.2), 0.0, 1.0], "u": make_field("return (x+(y*0.08));", [])}])
	invoke_member(v_p_8, "stroke", ["M242 295Q255 316 250 359", "#b0b999", 1.4, 0.7])
	invoke_member(v_p_8, "line", ["M237 284L268 291", "#9d9f77", 2.0, 0.75])
	invoke(v_surface_14, ["M320 368L337 359L352 368L338 378Z", [317.0, 357.0, 355.0, 380.0], merge_dicts([v_top_10, {"color": "#b0a77c", "scale": 14.0}])])
	invoke_member(v_p_8, "fill", ["M325 374L325 390L331 392L332 376Z", "#20332e"])
	invoke_member(v_p_8, "fill", ["M344 373L344 391L350 388L350 370Z", "#13282b"])
	invoke(v_brazier_25, [getv(v_lights_6, "altar"), 0.8])
	invoke(v_stair_37, [340.0, 434.0, (-5.8), 7.5, 11.0, 65.0])
	invoke(v_surface_14, ["M250 516L293 497L323 511L308 539L273 553L244 538Z", [241.0, 494.0, 326.0, 556.0], merge_dicts([v_top_10, {"scale": 24.0}])])
	invoke(v_stair_37, [268.0, 550.0, (-4.8), 8.3, 10.0, 49.0])
	invoke(v_brazier_25, [getv(v_lights_6, "stair"), 0.82])
	var v_spur_90: Variant = "M460 530L495 503L531 506L565 487L620 493L649 510L697 505L729 536L772 550L801 594L783 637L796 670L768 693L760 742L728 765L686 749L653 779L620 759L585 781L554 749L520 741L505 699L476 678L487 632L452 603Z"
	invoke(v_surface_14, [v_spur_90, [449.0, 483.0, 805.0, 784.0], merge_dicts([v_dark_12, {"color": "#738c71", "scale": 42.0, "height": make_field("return ((23.0*fbm((x*0.009),(y*0.012),(@0@+5.0)))+(5.0*fbm((x*0.024),(y*0.022),(@1@+5.0))));", [v_worldSeed_1, v_worldSeed_1]), "wet": make_field("return (sm(615.0,785.0,y)*(0.55+(b*0.4)));", [])}])])
	invoke(v_surface_14, ["M485 603L519 612L529 662L549 678L541 710L564 744L586 778L554 747L520 738L503 698L477 676L487 633Z", [474.0, 600.0, 589.0, 783.0], merge_dicts([v_wall_11, {"scale": 31.0, "color": "#879c7b", "wet": make_field("return sm(660.0,780.0,y);", [])}])])
	invoke_member(v_p_8, "shadow", ["M670 606L731 619L746 659L729 700L740 740L723 763L686 748L653 776L638 738L654 699L648 650Z", 0.23, 4.0])
	for v_item_91 in ["M582 652L573 686L593 709L582 746", "M744 628L759 651L747 683L756 704", "M613 661L629 682L619 723L633 753"]:
		var v_d_92: Variant = v_item_91
		invoke(v_crack_18, [v_d_92, 2.0])
	var v_choir_93: Variant = "M457 539L495 511L532 517L566 495L618 500L648 520L694 516L729 544L767 559L784 591L759 626L714 643L676 673L638 665L594 684L556 669L525 677L493 646L468 637L474 597L453 574Z"
	invoke(v_surface_14, [v_choir_93, [450.0, 491.0, 788.0, 688.0], merge_dicts([v_top_10, {"color": mix(getv(v_C_5, "stone"), getv(v_C_5, "wet"), 0.12), "scale": 33.0, "wet": make_field("return ((sm(480.0,670.0,y)*b)*0.65);", [])}])])
	invoke(v_surface_14, ["M340 575Q398 545 469 550L492 569Q410 574 356 602Z", [337.0, 542.0, 495.0, 605.0], merge_dicts([v_top_10, {"scale": 23.0}])])
	invoke(v_surface_14, ["M355 601Q420 573 492 569L486 583Q412 589 359 614Z", [352.0, 567.0, 495.0, 617.0], merge_dicts([v_dark_12, {"scale": 27.0}])])
	var v_i_94: Variant = 0.0
	while truth((v_i_94 < 12.0)):
		var v_x_95: Variant = add(353.0, (v_i_94 * 11.0))
		var v_y_96: Variant = (577.0 - (v_i_94 * 1.2))
		invoke_member(v_p_8, "line", [("M" + text_value(v_x_95) + "," + text_value(v_y_96) + "l8,17"), "#273f36", 1.0, 0.7])
		v_i_94 += 1
	invoke_member(v_p_8, "stroke", ["M345 574Q402 546 471 551", "#b7c09c", 2.3, 0.8])
	invoke(v_surface_14, [ellipse(615.0, 573.0, 116.0, 64.0), [496.0, 506.0, 734.0, 640.0], merge_dicts([v_top_10, {"color": getv(v_C_5, "stone"), "scale": 24.0, "wet": make_field("return 0.4;", [])}])])
	invoke(v_surface_14, [ellipse(615.0, 575.0, 97.0, 51.0), [515.0, 521.0, 715.0, 629.0], merge_dicts([v_dark_12, {"color": "#39594b", "normal": [0.0, 0.5, 0.8], "scale": 23.0}])])
	invoke_member(v_p_8, "shadow", [ellipse(614.0, 571.0, 88.0, 45.0), 0.4, 4.0])
	invoke_member(v_p_8, "surface", [ellipse(615.0, 588.0, 83.0, 35.0), [529.0, 550.0, 701.0, 626.0], {"mat": "water", "color": "#438c72", "shadow": "#041b25", "cx": 615.0, "cy": 588.0, "v": make_field("return (588.0+((y-588.0)*2.1));", []), "normal": [0.0, (-0.85), 0.52], "bump": 0.5, "emission": 0.055}])
	invoke_member(v_p_8, "glow", [getv(getv(v_lights_6, "well"), "x"), getv(getv(v_lights_6, "well"), "y"), 92.0, "#4bdf9e", 0.23])
	var v_k_97: Variant = 0.0
	while truth((v_k_97 < 6.0)):
		var v_rad_98: Variant = add(17.0, (v_k_97 * 9.0))
		var v_d_99: Variant = ""
		var v_j_100: Variant = 0.0
		while truth((v_j_100 < 54.0)):
			var v_a_101: Variant = add((((v_j_100 / 53.0) * PI) * 1.6), (v_k_97 * 0.6))
			var v_rr_102: Variant = (v_rad_98 * add(0.64, ((0.36 * v_j_100) / 53.0)))
			v_d_99 += add(add(add(("L" if truth(v_j_100) else "M"), add(615.0, (cos(v_a_101) * v_rr_102))), ","), add(588.0, ((sin(v_a_101) * v_rr_102) * 0.42)))
			v_j_100 += 1
		invoke_member(v_p_8, "stroke", [v_d_99, ("#73be91" if truth(fmod(v_k_97, 2.0)) else "#32675c"), 1.0, 0.4])
		v_k_97 += 1
	invoke_member(v_p_8, "fill", [ellipse(615.0, 588.0, 10.0, 4.5), "#03131d", 0.9])
	invoke_member(v_p_8, "stroke", ["M517 566Q550 520 612 523Q673 519 710 562", "#c1c6a0", 3.0, 0.7])
	invoke_member(v_p_8, "stroke", ["M531 610Q611 660 698 611", "#7da482", 4.0, 0.7])
	var v_i_103: Variant = 0.0
	while truth((v_i_103 < 19.0)):
		var v_a_104: Variant = (((v_i_103 / 19.0) * PI) * 2.0)
		var v_x_105: Variant = add(615.0, (cos(v_a_104) * 107.0))
		var v_y_106: Variant = add(575.0, (sin(v_a_104) * 58.0))
		invoke_member(v_p_8, "line", [("M" + text_value((v_x_105 - (cos(v_a_104) * 6.0))) + "," + text_value((v_y_106 - (sin(v_a_104) * 4.0))) + "l" + text_value((cos(v_a_104) * 11.0)) + "," + text_value((sin(v_a_104) * 7.0)) + ""), "#254538", 1.5, 0.7])
		if truth((fmod(v_i_103, 3.0) == 0.0)):
			invoke_member(v_p_8, "stroke", [("M" + text_value(v_x_105) + "," + text_value(v_y_106) + "l" + text_value(((-sin(v_a_104)) * 7.0)) + "," + text_value((cos(v_a_104) * 4.0)) + ""), "#c8cba3", 1.3, 0.7])
		v_i_103 += 1
	for v_item_107 in [[519.0, 543.0, 73.0, 14.0], [567.0, 516.0, 83.0, 15.0], [669.0, 532.0, 70.0, 14.0], [723.0, 571.0, 91.0, 16.0]]:
		var v_unpack_108: Variant = v_item_107
		var v_x_109: Variant = getv(v_unpack_108, 0)
		var v_y_110: Variant = getv(v_unpack_108, 1)
		var v_h_111: Variant = getv(v_unpack_108, 2)
		var v_w_112: Variant = getv(v_unpack_108, 3)
		invoke(v_surface_14, [("M" + text_value((v_x_109 - (v_w_112 / 2.0))) + "," + text_value(v_y_110) + "L" + text_value((v_x_109 - (v_w_112 * 0.35))) + "," + text_value((v_y_110 - v_h_111)) + "L" + text_value(add(v_x_109, (v_w_112 * 0.3))) + "," + text_value(((v_y_110 - v_h_111) - 3.0)) + "L" + text_value(add(v_x_109, (v_w_112 * 0.5))) + "," + text_value(v_y_110) + "Z"), [(v_x_109 - v_w_112), ((v_y_110 - v_h_111) - 6.0), add(v_x_109, v_w_112), add(v_y_110, 4.0)], merge_dicts([v_wall_11, {"color": getv(v_C_5, "stone"), "scale": 19.0, "height": make_field("return (2.0*sin(((x-@0@)*0.5)));", [v_x_109]), "normal": [(-0.4), 0.0, 1.0]}])])
		invoke(v_surface_14, [ellipse(v_x_109, (v_y_110 - v_h_111), (v_w_112 * 0.6), (v_w_112 * 0.25)), [(v_x_109 - v_w_112), ((v_y_110 - v_h_111) - (v_w_112 * 0.3)), add(v_x_109, v_w_112), add((v_y_110 - v_h_111), (v_w_112 * 0.3))], merge_dicts([v_top_10, {"color": "#b2bc92", "scale": 12.0}])])
		invoke_member(v_p_8, "line", [("M" + text_value(add(v_x_109, (v_w_112 * 0.3))) + "," + text_value(add((v_y_110 - v_h_111), 6.0)) + "L" + text_value(add(v_x_109, (v_w_112 * 0.4))) + "," + text_value(v_y_110) + ""), "#2d5146", 1.6, 0.7])
	invoke_member(v_p_8, "line", ["M518 472Q541 488 567 433Q617 469 669 462Q697 493 723 480", "#617e68", 1.3, 0.7])
	for v_item_113 in [[544.0, 470.0, 21.0, 46.0], [693.0, 485.0, 18.0, 44.0]]:
		var v_unpack_114: Variant = v_item_113
		var v_x_115: Variant = getv(v_unpack_114, 0)
		var v_y_116: Variant = getv(v_unpack_114, 1)
		var v_w_117: Variant = getv(v_unpack_114, 2)
		var v_h_118: Variant = getv(v_unpack_114, 3)
		invoke(v_surface_14, [("M" + text_value((v_x_115 - (v_w_117 / 2.0))) + "," + text_value(v_y_116) + "Q" + text_value(v_x_115) + "," + text_value(add(v_y_116, 7.0)) + " " + text_value(add(v_x_115, (v_w_117 / 2.0))) + "," + text_value(add(v_y_116, 2.0)) + "L" + text_value(add(v_x_115, (v_w_117 * 0.3))) + "," + text_value((add(v_y_116, v_h_118) - 5.0)) + "L" + text_value(add(v_x_115, 2.0)) + "," + text_value(add(v_y_116, v_h_118)) + "L" + text_value((v_x_115 - 4.0)) + "," + text_value((add(v_y_116, v_h_118) - 9.0)) + "L" + text_value((v_x_115 - (v_w_117 * 0.4))) + "," + text_value((add(v_y_116, v_h_118) - 3.0)) + "Z"), [(v_x_115 - v_w_117), (v_y_116 - 3.0), add(v_x_115, v_w_117), add(add(v_y_116, v_h_118), 3.0)], {"mat": "cloth", "color": mix(getv(v_C_5, "violet"), getv(v_C_5, "linen"), 0.25), "shadow": getv(v_C_5, "violet"), "accent": getv(v_C_5, "salt"), "normal": [(-0.2), 0.0, 1.0], "height": make_field("return (3.0*sin((((x-@0@)*0.28)+((y-@1@)*0.03))));", [v_x_115, v_y_116]), "bump": 0.6}])
		invoke_member(v_p_8, "stroke", [("M" + text_value((v_x_115 - 3.0)) + "," + text_value(add(v_y_116, 8.0)) + "l2," + text_value((v_h_118 - 19.0)) + ""), "#a2a484", 1.2, 0.6])
	for v_item_119 in [[509.0, 597.0, 0.88, true, true], [546.0, 639.0, 0.95, false, true], [589.0, 656.0, 1.05, true, true], [648.0, 652.0, 1.02, false, true], [699.0, 625.0, 0.94, true, true], [742.0, 604.0, 0.94, false, true], [392.0, 577.0, 0.82, true, false], [295.0, 520.0, 0.83, false, false], [250.0, 583.0, 0.88, true, false], [351.0, 448.0, 0.82, true, false], [219.0, 446.0, 0.72, false, false]]:
		var v_unpack_120: Variant = v_item_119
		var v_x_121: Variant = getv(v_unpack_120, 0)
		var v_y_122: Variant = getv(v_unpack_120, 1)
		var v_s_123: Variant = getv(v_unpack_120, 2)
		var v_lit_124: Variant = getv(v_unpack_120, 3)
		var v_bow_125: Variant = getv(v_unpack_120, 4)
		invoke(v_pilgrim_31, [v_x_121, v_y_122, v_s_123, v_lit_124, v_bow_125])
	for v_item_126 in [[490.0, 566.0, 0.9], [533.0, 630.0, 0.85], [627.0, 651.0, 0.9], [715.0, 606.0, 0.9], [307.0, 480.0, 0.8], [230.0, 607.0, 0.85], [270.0, 539.0, 0.65]]:
		var v_unpack_127: Variant = v_item_126
		var v_x_128: Variant = getv(v_unpack_127, 0)
		var v_y_129: Variant = getv(v_unpack_127, 1)
		var v_s_130: Variant = getv(v_unpack_127, 2)
		invoke(v_flame_21, [v_x_128, v_y_129, v_s_130])
	invoke(v_surface_14, ["M700 604Q713 629 703 652Q694 679 704 699L692 727L703 758L717 757Q705 728 719 706Q711 679 722 651Q730 628 716 600Z", [689.0, 598.0, 732.0, 763.0], {"mat": "water", "color": "#6ba68d", "shadow": "#103947", "cx": 704.0, "cy": 690.0, "normal": [(-0.15), 0.1, 1.0], "bump": 0.3, "emission": 0.035, "u": make_field("return x;", []), "v": make_field("return (y*0.3);", [])}])
	invoke_member(v_p_8, "stroke", ["M709 610Q725 636 712 666Q705 681 712 701Q701 727 711 750", "#9bcbb0", 2.0, 0.7])
	invoke_member(v_p_8, "glow", [710.0, 760.0, 34.0, "#50b98b", 0.12])
	invoke(v_surface_14, ["M163 680L201 671L246 699L234 727L199 741L158 717Z", [155.0, 668.0, 250.0, 745.0], merge_dicts([v_top_10, {"color": "#796f52", "scale": 24.0}])])
	var v_i_131: Variant = 0.0
	while truth((v_i_131 < 6.0)):
		var v_x_132: Variant = add(169.0, (v_i_131 * 11.0))
		var v_y_133: Variant = add(692.0, (v_i_131 * 4.0))
		invoke_member(v_p_8, "line", [("M" + text_value(v_x_132) + "," + text_value(v_y_133) + "l-7,28"), "#253d37", 1.5, 0.8])
		invoke_member(v_p_8, "line", [("M" + text_value(v_x_132) + "," + text_value(v_y_133) + "v-15"), "#778975", 2.0, 0.8])
		v_i_131 += 1
	invoke_member(v_p_8, "line", ["M169 676Q199 696 235 699", "#97a286", 1.3, 0.8])
	invoke_member(v_p_8, "surface", ["M180 751Q220 731 258 752Q225 778 180 751Z", [177.0, 730.0, 261.0, 781.0], {"mat": "plain", "color": "#6d7155", "normal": [0.0, (-0.65), 0.7]}])
	invoke_member(v_p_8, "fill", ["M188 751Q220 741 249 753Q221 768 188 751Z", "#0b2228"])
	invoke_member(v_p_8, "line", ["M218 747L220 766", "#7f9577", 3.0, 0.8])
	invoke_member(v_p_8, "line", ["M229 750L245 713", "#64856d", 0.9, 0.8])
	invoke(v_opening_55, [201.0, 491.0, 26.0, 45.0, false, (-3.0)])
	var v_i_134: Variant = 0.0
	while truth((v_i_134 < 5.0)):
		var v_x_135: Variant = add(216.0, (v_i_134 * 12.0))
		var v_y_136: Variant = add(477.0, (fmod(v_i_134, 2.0) * 8.0))
		invoke(v_surface_14, [("M" + text_value((v_x_135 - 4.0)) + "," + text_value(v_y_136) + "L" + text_value((v_x_135 - 5.0)) + "," + text_value(add(v_y_136, 11.0)) + "Q" + text_value(v_x_135) + "," + text_value(add(v_y_136, 15.0)) + " " + text_value(add(v_x_135, 5.0)) + "," + text_value(add(v_y_136, 10.0)) + "L" + text_value(add(v_x_135, 4.0)) + "," + text_value(v_y_136) + "Z"), [(v_x_135 - 7.0), (v_y_136 - 2.0), add(v_x_135, 8.0), add(v_y_136, 17.0)], {"mat": "plain", "color": "#a39168", "normal": [(-0.3), (-0.2), 1.0]}])
		invoke_member(v_p_8, "fill", [ellipse(v_x_135, v_y_136, 4.0, 2.0), "#18312d"])
		v_i_134 += 1
	invoke_member(v_p_8, "line", ["M153 524L187 535L184 572L150 560Z", "#67846d", 0.9, 0.7])
	var v_i_137: Variant = 0.0
	while truth((v_i_137 < 5.0)):
		invoke_member(v_p_8, "line", [("M" + text_value(add(156.0, (v_i_137 * 6.0))) + "," + text_value(add(526.0, (v_i_137 * 2.0))) + "l-1,33"), "#536b58", 0.7, 0.65])
		invoke_member(v_p_8, "line", [("M152," + text_value(add(532.0, (v_i_137 * 6.0))) + "l32,10"), "#536b58", 0.7, 0.65])
		v_i_137 += 1
	for v_item_138 in ["M236 711L229 732L235 745", "M563 709L570 723L568 736", "M341 675L349 686L347 699"]:
		var v_d_139: Variant = v_item_138
		invoke_member(v_p_8, "stroke", [v_d_139, "#458e79", 2.0, 0.55])
		invoke_member(v_p_8, "stroke", [v_d_139, "#86c89d", 0.65, 0.6])
	var v_i_140: Variant = 0.0
	while truth((v_i_140 < 28.0)):
		var v_x_141: Variant = add(144.0, (invoke(v_r_4, []) * 675.0))
		var v_y_142: Variant = add(767.0, (invoke(v_r_4, []) * 42.0))
		invoke_member(v_p_8, "stroke", [("M" + text_value(v_x_141) + "," + text_value(v_y_142) + "q" + text_value(add(8.0, (invoke(v_r_4, []) * 16.0))) + "," + text_value(add(3.0, (invoke(v_r_4, []) * 2.0))) + " " + text_value(add(19.0, (invoke(v_r_4, []) * 22.0))) + ",-2"), "#427c72", add(0.7, (invoke(v_r_4, []) * 0.8)), 0.26])
		v_i_140 += 1
	invoke_member(v_p_8, "reframe", [1.04, (-13.0), (-9.0)])
	invoke_member(v_p_8, "fade", [852.0])
	return {"p": invoke_member(v_p_8, "output", []), "features": {"worldSeed": v_worldSeed_1, "construction": "潮蚀断崖上的残顶礼拜堂、上行祭径、跨隙桥、下沉环井与潮汐登陆点", "method": "2D oblique footprints + correlated dry/wet stone fields + recessed water flow + local ritual lighting → original NPR", "materials": ["干盐石灰岩", "湿岩", "铜钟", "织物", "流动潮水", "旧木"], "activity": "持灯入会、围井祈求、潮水量测、供物存放与码头作业", "lighting": {"revision": "cliff-fill-plane-separation-local-sources", "backPlaneAmbient": getv(v_dark_12, "ambient"), "topNormal": getv(v_top_10, "normal"), "wallNormal": getv(v_wall_11, "normal"), "lights": map_values(v_lights_6.values(), func(v_arg_143):
		var v_unpack_144: Variant = v_arg_143
		var v_visibility_145: Variant = getv(v_unpack_144, "visibility")
		var v_source_146: Variant = without(v_unpack_144, ["visibility"])
		return v_source_146), "occlusion": "二维表面与光源遮罩；非三维阴影模拟"}}}
