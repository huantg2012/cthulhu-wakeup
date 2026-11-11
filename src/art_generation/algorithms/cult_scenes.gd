extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: cult-scenes.js; preserve contours, ordering and seed decisions.
const M_cult_kit = preload("res://src/art_generation/algorithms/cult_kit.gd")

static func pod(v_k_1, v_x_2, v_y_3, v_rx_4, v_h_5, v_material_6 = null, v_door_7 = null):
	if v_material_6 == null:
		v_material_6 = "shell"
	if v_door_7 == null:
		v_door_7 = true
	var v_unpack_8: Variant = v_k_1
	var v_surf_9: Variant = getv(v_unpack_8, "surf")
	var v_side_10: Variant = getv(v_unpack_8, "side")
	var v_top_11: Variant = getv(v_unpack_8, "top")
	var v_p_12: Variant = getv(v_unpack_8, "p")
	var v_C_13: Variant = getv(v_unpack_8, "C")
	var v_w_14: Variant = getv(v_unpack_8, "w")
	var v_body_15: Variant = (("M" + text_value((v_x_2 - v_rx_4)) + " " + text_value(v_y_3) + "C" + text_value((v_x_2 - (v_rx_4 * 1.1))) + " " + text_value((v_y_3 - (v_h_5 * 0.35))) + " " + text_value((v_x_2 - (v_rx_4 * 1.25))) + " " + text_value((v_y_3 - (v_h_5 * 0.6))) + " " + text_value((v_x_2 - (v_rx_4 * 0.7))) + " " + text_value((v_y_3 - (v_h_5 * 0.77))) + "C" + text_value((v_x_2 - (v_rx_4 * 0.45))) + " " + text_value((v_y_3 - (v_h_5 * 1.02))) + " " + text_value(add(v_x_2, (v_rx_4 * 0.3))) + " " + text_value((v_y_3 - (v_h_5 * 1.02))) + " " + text_value(add(v_x_2, (v_rx_4 * 0.65))) + " " + text_value((v_y_3 - (v_h_5 * 0.78))) + "C" + text_value(add(v_x_2, (v_rx_4 * 1.18))) + " " + text_value((v_y_3 - (v_h_5 * 0.63))) + " " + text_value(add(v_x_2, (v_rx_4 * 0.8))) + " " + text_value((v_y_3 - (v_h_5 * 0.39))) + " " + text_value(add(v_x_2, v_rx_4)) + " " + text_value(v_y_3) + "Q" + text_value(v_x_2) + " " + text_value(add(v_y_3, (v_rx_4 * 0.35))) + " " + text_value((v_x_2 - v_rx_4)) + " " + text_value(v_y_3) + "Z") if truth((v_material_6 == "flesh")) else ("M" + text_value((v_x_2 - v_rx_4)) + " " + text_value(v_y_3) + "C" + text_value((v_x_2 - (v_rx_4 * 1.15))) + " " + text_value((v_y_3 - (v_h_5 * 0.45))) + " " + text_value((v_x_2 - (v_rx_4 * 0.8))) + " " + text_value((v_y_3 - (v_h_5 * 0.87))) + " " + text_value(v_x_2) + " " + text_value((v_y_3 - v_h_5)) + "C" + text_value(add(v_x_2, (v_rx_4 * 0.75))) + " " + text_value((v_y_3 - (v_h_5 * 0.84))) + " " + text_value(add(v_x_2, (v_rx_4 * 1.15))) + " " + text_value((v_y_3 - (v_h_5 * 0.34))) + " " + text_value(add(v_x_2, v_rx_4)) + " " + text_value(v_y_3) + "Q" + text_value(v_x_2) + " " + text_value(add(v_y_3, (v_rx_4 * 0.35))) + " " + text_value((v_x_2 - v_rx_4)) + " " + text_value(v_y_3) + "Z"))
	invoke(v_surf_9, [v_body_15, [(v_x_2 - (v_rx_4 * 1.2)), ((v_y_3 - v_h_5) - 5.0), add(v_x_2, (v_rx_4 * 1.2)), add(v_y_3, (v_rx_4 * 0.4))], merge_dicts([v_side_10, {"field": worldField(v_material_6, v_w_14), "color": getv(v_C_13, "stone"), "normal": [(-0.25), (-0.05), 1.0], "height": make_field("return (16.0*exp((-pow(((x-@0@)/(@1@*0.78)),2.0))));", [v_x_2, v_rx_4])}])])
	var v_i_16: Variant = (-2.0)
	while truth((v_i_16 <= 2.0)):
		var v_s_17: Variant = (v_i_16 / 3.0)
		invoke_member(v_p_12, "stroke", [("M" + text_value(add(v_x_2, ((v_s_17 * v_rx_4) * 0.3))) + " " + text_value(add((v_y_3 - v_h_5), 18.0)) + "Q" + text_value(add(v_x_2, ((v_s_17 * v_rx_4) * 1.55))) + " " + text_value((v_y_3 - (v_h_5 * 0.6))) + " " + text_value(add(v_x_2, ((v_s_17 * v_rx_4) * 0.86))) + " " + text_value((v_y_3 - 7.0)) + ""), getv(v_C_13, "salt"), 2.0, 0.33])
		v_i_16 += 1
	if truth(v_door_7):
		invoke_member(v_k_1, "opening", [v_x_2, (v_y_3 - 4.0), (v_rx_4 * 0.62), (v_h_5 * 0.42)])
	for v_item_18 in [(-1.0), 1.0]:
		var v_dir_19: Variant = v_item_18
		var v_a_20: Variant = add(v_x_2, ((v_dir_19 * v_rx_4) * 0.68))
		var v_b_21: Variant = (v_y_3 - (v_h_5 * 0.39))
		invoke_member(v_k_1, "opening", [v_a_20, v_b_21, (v_rx_4 * 0.19), (v_h_5 * 0.12), (v_dir_19 * 3.0)])
	if truth((v_material_6 == "flesh")):
		var v_i_22: Variant = 0.0
		while truth((v_i_22 < 13.0)):
			var v_yy_23: Variant = add((v_y_3 - (v_h_5 * 0.75)), ((v_i_22 * v_h_5) * 0.052))
			var v_xx_24: Variant = add((v_x_2 - (v_rx_4 * 0.62)), (sin((v_i_22 * 0.3)) * 7.0))
			invoke_member(v_p_12, "line", [("M" + text_value((v_xx_24 - 4.0)) + " " + text_value((v_yy_23 - 3.0)) + "l9,6"), getv(v_C_13, "copper"), 1.6, 0.75])
			v_i_22 += 1
static func mushroom(v_k_25, v_x_26, v_y_27, v_rx_28, v_h_29, v_habitable_30 = null):
	if v_habitable_30 == null:
		v_habitable_30 = true
	var v_unpack_31: Variant = v_k_25
	var v_surf_32: Variant = getv(v_unpack_31, "surf")
	var v_p_33: Variant = getv(v_unpack_31, "p")
	var v_C_34: Variant = getv(v_unpack_31, "C")
	var v_w_35: Variant = getv(v_unpack_31, "w")
	var v_side_36: Variant = getv(v_unpack_31, "side")
	var v_stem_37: Variant = (29.0 if truth(v_habitable_30) else 13.0)
	invoke(v_surf_32, [("M" + text_value((v_x_26 - v_stem_37)) + " " + text_value(v_y_27) + "Q" + text_value((v_x_26 - (v_stem_37 * 1.25))) + " " + text_value((v_y_27 - (v_h_29 * 0.5))) + " " + text_value((v_x_26 - (v_stem_37 * 0.6))) + " " + text_value((v_y_27 - (v_h_29 * 0.75))) + "L" + text_value(add(v_x_26, (v_stem_37 * 0.8))) + " " + text_value((v_y_27 - (v_h_29 * 0.74))) + "Q" + text_value(add(v_x_26, (v_stem_37 * 0.4))) + " " + text_value((v_y_27 - (v_h_29 * 0.35))) + " " + text_value(add(v_x_26, (v_stem_37 * 1.3))) + " " + text_value(add(v_y_27, 3.0)) + "Z"), [(v_x_26 - (v_stem_37 * 1.4)), (v_y_27 - (v_h_29 * 0.8)), add(v_x_26, (v_stem_37 * 1.5)), add(v_y_27, 9.0)], merge_dicts([v_side_36, {"field": worldField("silk", v_w_35), "color": mix(getv(v_C_34, "linen"), getv(v_w_35, "c2"), 0.35), "height": make_field("return (4.0*sin(((x-@0@)*0.13)));", [v_x_26]), "normal": [(-0.35), 0.0, 1.0]}])])
	invoke(v_surf_32, [("M" + text_value((v_x_26 - v_rx_28)) + " " + text_value((v_y_27 - (v_h_29 * 0.65))) + "Q" + text_value((v_x_26 - (v_rx_28 * 0.75))) + " " + text_value((v_y_27 - (v_h_29 * 0.92))) + " " + text_value((v_x_26 - 8.0)) + " " + text_value((v_y_27 - v_h_29)) + "Q" + text_value(add(v_x_26, (v_rx_28 * 0.65))) + " " + text_value((v_y_27 - (v_h_29 * 1.03))) + " " + text_value(add(v_x_26, v_rx_28)) + " " + text_value((v_y_27 - (v_h_29 * 0.62))) + "Q" + text_value(add(v_x_26, (v_rx_28 * 0.2))) + " " + text_value((v_y_27 - (v_h_29 * 0.4))) + " " + text_value((v_x_26 - v_rx_28)) + " " + text_value((v_y_27 - (v_h_29 * 0.65))) + "Z"), [((v_x_26 - v_rx_28) - 4.0), (v_y_27 - (v_h_29 * 1.05)), add(add(v_x_26, v_rx_28), 4.0), (v_y_27 - (v_h_29 * 0.38))], merge_dicts([getv(v_k_25, "top"), {"field": worldField("fungus", v_w_35), "color": mix(getv(v_w_35, "c2"), getv(v_w_35, "c3"), 0.6), "height": make_field("return (8.0*exp((-pow(((x-@0@)/@1@),2.0))));", [v_x_26, v_rx_28]), "glow": getv(v_w_35, "c4")}])])
	invoke_member(v_p_33, "shadow", [("M" + text_value(add((v_x_26 - v_rx_28), 7.0)) + " " + text_value((v_y_27 - (v_h_29 * 0.64))) + "Q" + text_value(v_x_26) + " " + text_value((v_y_27 - (v_h_29 * 0.49))) + " " + text_value((add(v_x_26, v_rx_28) - 5.0)) + " " + text_value((v_y_27 - (v_h_29 * 0.62))) + "Q" + text_value(v_x_26) + " " + text_value((v_y_27 - (v_h_29 * 0.35))) + " " + text_value(add((v_x_26 - v_rx_28), 7.0)) + " " + text_value((v_y_27 - (v_h_29 * 0.64))) + "Z"), 0.37, 2.0])
	var v_i_38: Variant = 0.0
	while truth((v_i_38 < 10.0)):
		var v_t_39: Variant = (v_i_38 / 9.0)
		invoke_member(v_p_33, "stroke", [("M" + text_value((v_x_26 - 5.0)) + " " + text_value((v_y_27 - (v_h_29 * 0.54))) + "Q" + text_value(add((v_x_26 - (v_rx_28 * 0.8)), ((v_rx_28 * 1.6) * v_t_39))) + " " + text_value((v_y_27 - (v_h_29 * 0.43))) + " " + text_value(add((v_x_26 - v_rx_28), ((v_rx_28 * 2.0) * v_t_39))) + " " + text_value((v_y_27 - (v_h_29 * add(0.62, (0.03 * sin((v_t_39 * 3.0))))))) + ""), getv(v_C_34, "salt"), 1.0, 0.35])
		v_i_38 += 1
	if truth(v_habitable_30):
		invoke_member(v_k_25, "opening", [add(v_x_26, 2.0), (v_y_27 - 3.0), 26.0, 42.0])
		invoke_member(v_k_25, "opening", [(v_x_26 - 8.0), (v_y_27 - (v_h_29 * 0.28)), 14.0, 24.0])
		invoke_member(v_k_25, "gallery", [v_x_26, (v_y_27 - (v_h_29 * 0.2)), (v_rx_28 * 0.72)])
static func spire(v_k_40, v_x_41, v_y_42, v_rx_43, v_h_44):
	var v_unpack_45: Variant = v_k_40
	var v_surf_46: Variant = getv(v_unpack_45, "surf")
	var v_p_47: Variant = getv(v_unpack_45, "p")
	var v_side_48: Variant = getv(v_unpack_45, "side")
	var v_top_49: Variant = getv(v_unpack_45, "top")
	var v_w_50: Variant = getv(v_unpack_45, "w")
	var v_C_51: Variant = getv(v_unpack_45, "C")
	invoke(v_surf_46, [("M" + text_value((v_x_41 - v_rx_43)) + " " + text_value(v_y_42) + "L" + text_value((v_x_41 - (v_rx_43 * 0.8))) + " " + text_value((v_y_42 - (v_h_44 * 0.61))) + "L" + text_value(add(v_x_41, (v_rx_43 * 0.15))) + " " + text_value((v_y_42 - v_h_44)) + "L" + text_value(add(v_x_41, (v_rx_43 * 0.85))) + " " + text_value((v_y_42 - (v_h_44 * 0.5))) + "L" + text_value(add(v_x_41, v_rx_43)) + " " + text_value((v_y_42 - 10.0)) + "L" + text_value(add(v_x_41, 5.0)) + " " + text_value(add(v_y_42, 15.0)) + "Z"), [((v_x_41 - v_rx_43) - 5.0), ((v_y_42 - v_h_44) - 5.0), add(add(v_x_41, v_rx_43), 5.0), add(v_y_42, 20.0)], merge_dicts([v_side_48, {"field": worldField("prism", v_w_50), "normal": [(-0.45), (-0.1), 0.88], "height": make_field("return 0.0;", []), "bump": 0.15}])])
	invoke(v_surf_46, [("M" + text_value(add(v_x_41, (v_rx_43 * 0.15))) + " " + text_value((v_y_42 - v_h_44)) + "L" + text_value(add(v_x_41, (v_rx_43 * 0.85))) + " " + text_value((v_y_42 - (v_h_44 * 0.5))) + "L" + text_value(add(v_x_41, v_rx_43)) + " " + text_value((v_y_42 - 10.0)) + "L" + text_value(add(v_x_41, 5.0)) + " " + text_value(add(v_y_42, 15.0)) + "L" + text_value((v_x_41 - (v_rx_43 * 0.14))) + " " + text_value((v_y_42 - (v_h_44 * 0.55))) + "Z"), [((v_x_41 - (v_rx_43 * 0.2)) - 4.0), ((v_y_42 - v_h_44) - 4.0), add(add(v_x_41, v_rx_43), 4.0), add(v_y_42, 20.0)], merge_dicts([v_top_49, {"field": worldField("prism", v_w_50), "normal": [0.6, 0.1, 0.75], "u": make_field("return (x+190.0);", []), "bump": 0.15}])])
	invoke_member(v_p_47, "stroke", [("M" + text_value(add(v_x_41, (v_rx_43 * 0.15))) + " " + text_value((v_y_42 - v_h_44)) + "L" + text_value((v_x_41 - (v_rx_43 * 0.14))) + " " + text_value((v_y_42 - (v_h_44 * 0.55))) + "L" + text_value(add(v_x_41, 5.0)) + " " + text_value(add(v_y_42, 15.0)) + ""), getv(v_C_51, "salt"), 2.0, 0.6])
static func watcher(v_k_52):
	var v_unpack_53: Variant = v_k_52
	var v_terrace_54: Variant = getv(v_unpack_53, "terrace")
	var v_surf_55: Variant = getv(v_unpack_53, "surf")
	var v_side_56: Variant = getv(v_unpack_53, "side")
	var v_top_57: Variant = getv(v_unpack_53, "top")
	var v_hall_58: Variant = getv(v_unpack_53, "hall")
	var v_stair_59: Variant = getv(v_unpack_53, "stair")
	var v_p_60: Variant = getv(v_unpack_53, "p")
	var v_C_61: Variant = getv(v_unpack_53, "C")
	var v_w_62: Variant = getv(v_unpack_53, "w")
	var v_fire_63: Variant = invoke_member(v_k_52, "lamp", [367.0, 558.0, 0.85, "#efae67", 150.0])
	var v_lamp_64: Variant = invoke_member(v_k_52, "lamp", [628.0, 461.0, 0.65, getv(v_w_62, "c4"), 135.0])
	v_lamp_64["marker"] = false
	v_fire_63["marker"] = getv(v_lamp_64, "marker")
	invoke(v_terrace_54, ["M152 447L177 334L245 269L336 274L417 238L512 277L570 350L551 451L491 505L396 525L307 504L225 536Z", "M152 447L225 536L307 504L396 525L491 505L551 451L570 350L597 504L553 598L463 651L371 629L289 666L216 613L170 552Z", [146.0, 232.0, 603.0, 672.0]])
	invoke(v_surf_55, ["M413 282Q472 191 564 207Q697 231 728 392L699 518L658 503L650 370Q612 304 566 325L550 461L495 495Z", [408.0, 186.0, 734.0, 524.0], merge_dicts([v_side_56, {"field": worldField("ridge", v_w_62), "normal": [0.5, 0.12, 0.85], "exposure": 0.65, "height": make_field("return (fbm((x*0.013),(y*0.012),@0@)*15.0);", [getv(v_w_62, "worldSeed")])}])])
	invoke(v_terrace_54, ["M179 625L251 573L337 587L411 550L501 573L582 546L683 580L769 648L776 722L701 780L601 804L506 787L399 824L300 792L205 802L152 729Z", "M179 625L152 729L205 802L300 792L399 824L506 787L601 804L701 780L776 722L788 800L715 844L609 866L504 842L410 874L297 844L206 858L155 795Z", [146.0, 540.0, 794.0, 880.0]])
	invoke(v_hall_58, [228.0, 442.0, 171.0, 126.0, {"roof": "broken", "windows": 2.0}])
	invoke_member(v_k_52, "cloth", [255.0, 336.0, 32.0, 80.0, getv(v_C_61, "violet")])
	invoke_member(v_k_52, "gallery", [314.0, 473.0, 142.0])
	invoke(v_surf_55, ["M442 466L490 382L530 402L518 543L474 574L438 553Z", [432.0, 377.0, 536.0, 579.0], merge_dicts([v_side_56, {"normal": [(-0.6), 0.1, 0.8], "color": getv(v_C_61, "stone")}])])
	invoke_member(v_k_52, "opening", [479.0, 530.0, 13.0, 89.0, 7.0])
	invoke(v_stair_59, [351.0, 489.0, (-7.0), 8.0, 10.0, 64.0])
	invoke(v_stair_59, [345.0, 595.0, 7.0, 8.0, 8.0, 58.0])
	invoke_member(v_k_52, "basin", [595.0, 659.0, 139.0, 74.0, {"color": getv(v_w_62, "c2")}])
	var v_i_65: Variant = 0.0
	while truth((v_i_65 < 48.0)):
		var v_a_66: Variant = (((v_i_65 / 48.0) * PI) * 2.0)
		invoke_member(v_p_60, "stroke", [("M" + text_value(add(595.0, (cos(v_a_66) * 34.0))) + " " + text_value(add(670.0, (sin(v_a_66) * 14.0))) + "L" + text_value(add(595.0, (cos(v_a_66) * 99.0))) + " " + text_value(add(670.0, (sin(v_a_66) * 42.0))) + ""), (getv(v_C_61, "copper") if truth(fmod(v_i_65, 3.0)) else getv(v_C_61, "salt")), 1.6, 0.65])
		v_i_65 += 1
	invoke_member(v_p_60, "fill", [ellipse(595.0, 670.0, 18.0, 32.0), getv(v_w_62, "c0")])
	invoke_member(v_p_60, "glow", [592.0, 668.0, 80.0, getv(v_w_62, "c4"), 0.14])
	for v_item_67 in [[494.0, 623.0, 79.0], [547.0, 594.0, 105.0], [679.0, 618.0, 91.0]]:
		var v_unpack_68: Variant = v_item_67
		var v_x_69: Variant = getv(v_unpack_68, 0)
		var v_y_70: Variant = getv(v_unpack_68, 1)
		var v_h_71: Variant = getv(v_unpack_68, 2)
		invoke(v_surf_55, [("M" + text_value((v_x_69 - 7.0)) + " " + text_value(v_y_70) + "l2," + text_value((-v_h_71)) + "l12,1l2," + text_value(v_h_71) + "Z"), [(v_x_69 - 11.0), ((v_y_70 - v_h_71) - 4.0), add(v_x_69, 13.0), add(v_y_70, 5.0)], merge_dicts([v_side_56, {"mat": "masonry", "field": null, "color": getv(v_C_61, "salt")}])])
		invoke_member(v_p_60, "line", [("M" + text_value(v_x_69) + " " + text_value((v_y_70 - v_h_71)) + "l" + text_value((595.0 - v_x_69)) + "," + text_value(add((590.0 - v_y_70), v_h_71)) + ""), getv(v_C_61, "copper"), 1.0, 0.5])
	invoke(v_hall_58, [188.0, 681.0, 94.0, 67.0, {"roof": "tile", "windows": 2.0}])
	invoke_member(v_k_52, "opening", [271.0, 788.0, 39.0, 67.0, (-4.0)])
	invoke_member(v_k_52, "table", [293.0, 686.0, 62.0])
	invoke_member(v_k_52, "supplies", [302.0, 688.0, 4.0])
	invoke_member(v_k_52, "table", [656.0, 751.0, 48.0])
	invoke_member(v_k_52, "brazier", [v_fire_63, 0.82])
	invoke_member(v_k_52, "brazier", [v_lamp_64, 0.72])
	for v_item_72 in [[238.0, 461.0], [387.0, 495.0], [468.0, 554.0]]:
		var v_unpack_73: Variant = v_item_72
		var v_x_74: Variant = getv(v_unpack_73, 0)
		var v_y_75: Variant = getv(v_unpack_73, 1)
		invoke_member(v_p_60, "shadow", [("M" + text_value(v_x_74) + " " + text_value(v_y_75) + "l31,9l26,28l-37,-8Z"), 0.35, 3.0])
	var v_i_76: Variant = 0.0
	while truth((v_i_76 < 5.0)):
		var v_x_77: Variant = add(203.0, (v_i_76 * 21.0))
		var v_y_78: Variant = add(728.0, (v_i_76 * 4.0))
		invoke_member(v_p_60, "line", [("M" + text_value(v_x_77) + " " + text_value(v_y_78) + "v-31"), getv(v_C_61, "copper"), 2.0])
		invoke_member(v_k_52, "cloth", [(v_x_77 - 7.0), (v_y_78 - 29.0), 14.0, 18.0, getv(v_C_61, "violet")])
		v_i_76 += 1
	for v_item_79 in [[303.0, 481.0, "carry", false], [309.0, 552.0, "torch", true], [391.0, 627.0, "bow", false], [320.0, 721.0, "work", true], [516.0, 734.0, "kneel", false], [619.0, 759.0, "bow", true], [716.0, 715.0, "torch", false], [247.0, 811.0, "carry", false]]:
		var v_unpack_80: Variant = v_item_79
		var v_x_81: Variant = getv(v_unpack_80, 0)
		var v_y_82: Variant = getv(v_unpack_80, 1)
		var v_a_83: Variant = getv(v_unpack_80, 2)
		var v_l_84: Variant = getv(v_unpack_80, 3)
		invoke_member(v_k_52, "actor", [v_x_81, v_y_82, (1.05 if truth((v_y_82 > 700.0)) else 0.8), v_a_83, v_l_84])
static func flesh(v_k_85):
	var v_unpack_86: Variant = v_k_85
	var v_terrace_87: Variant = getv(v_unpack_86, "terrace")
	var v_surf_88: Variant = getv(v_unpack_86, "surf")
	var v_side_89: Variant = getv(v_unpack_86, "side")
	var v_top_90: Variant = getv(v_unpack_86, "top")
	var v_stair_91: Variant = getv(v_unpack_86, "stair")
	var v_p_92: Variant = getv(v_unpack_86, "p")
	var v_C_93: Variant = getv(v_unpack_86, "C")
	var v_w_94: Variant = getv(v_unpack_86, "w")
	var v_fire_95: Variant = invoke_member(v_k_85, "lamp", [293.0, 602.0, 0.85, "#ffc080", 142.0])
	var v_inner_96: Variant = invoke_member(v_k_85, "lamp", [569.0, 414.0, 0.62, getv(v_w_94, "c4"), 125.0])
	v_inner_96["marker"] = false
	v_fire_95["marker"] = getv(v_inner_96, "marker")
	invoke(v_terrace_87, ["M188 491Q144 383 263 342Q372 312 428 360Q493 287 610 317Q729 348 756 468L718 555Q641 608 537 578Q451 635 346 595Q234 623 188 491Z", "M188 491Q234 623 346 595Q451 635 537 578Q641 608 718 555L756 468Q795 582 730 667Q641 727 540 683Q431 750 344 697Q235 735 186 645Z", [157.0, 284.0, 796.0, 755.0]])
	invoke(v_terrace_87, ["M149 668Q205 600 293 629L392 671L491 635L603 670L696 644Q782 681 802 747L759 808L656 835L550 814L436 854L323 819L223 843L158 789Z", "M149 668L158 789L223 843L323 819L436 854L550 814L656 835L759 808L802 747L815 814L754 856L661 876L552 852L443 882L323 851L218 876L158 832Z", [142.0, 594.0, 821.0, 888.0]])
	pod(v_k_85, 565.0, 480.0, 125.0, 320.0, "flesh")
	invoke_member(v_k_85, "gallery", [564.0, 486.0, 187.0])
	pod(v_k_85, 703.0, 523.0, 41.0, 108.0, "flesh")
	invoke(v_surf_88, ["M188 492Q230 393 328 374Q402 405 449 506Q350 461 296 503Q231 474 188 492Z", [182.0, 369.0, 455.0, 512.0], merge_dicts([v_top_90, {"mat": "cloth", "field": worldField("silk", v_w_94), "color": mix("#b3987c", getv(v_w_94, "c3"), 0.28), "height": foldField([[[328.0, 378.0], [282.0, 421.0], [239.0, 459.0], [189.0, 491.0], 22.0, 12.0], [[330.0, 379.0], [373.0, 427.0], [407.0, 466.0], [447.0, 504.0], 18.0, 12.0]])}])])
	for v_item_97 in [[191.0, 492.0], [444.0, 504.0], [328.0, 378.0]]:
		var v_unpack_98: Variant = v_item_97
		var v_x_99: Variant = getv(v_unpack_98, 0)
		var v_y_100: Variant = getv(v_unpack_98, 1)
		invoke_member(v_p_92, "line", [("M" + text_value(v_x_99) + " " + text_value(v_y_100) + "v94"), getv(v_C_93, "copper"), 4.0])
		invoke_member(v_p_92, "line", [("M" + text_value(v_x_99) + " " + text_value(v_y_100) + "l-21,105"), getv(v_C_93, "salt"), 1.0, 0.5])
	invoke_member(v_p_92, "shadow", ["M192 496Q321 475 447 509L469 571Q320 551 190 566Z", 0.3, 9.0])
	invoke_member(v_k_85, "table", [233.0, 543.0, 89.0])
	invoke_member(v_k_85, "table", [345.0, 562.0, 62.0])
	invoke_member(v_k_85, "supplies", [239.0, 548.0, 5.0])
	invoke_member(v_k_85, "cloth", [250.0, 487.0, 18.0, 45.0, "#879387"])
	invoke(v_stair_91, [508.0, 519.0, (-9.0), 8.0, 10.0, 70.0])
	invoke(v_stair_91, [392.0, 608.0, (-6.0), 8.0, 8.0, 58.0])
	invoke_member(v_k_85, "basin", [583.0, 714.0, 90.0, 46.0, {"liquid": "flesh", "color": getv(v_w_94, "c3")}])
	invoke_member(v_k_85, "table", [655.0, 727.0, 57.0])
	invoke_member(v_k_85, "supplies", [665.0, 731.0, 5.0])
	var v_i_101: Variant = 0.0
	while truth((v_i_101 < 16.0)):
		var v_x_102: Variant = add(191.0, (v_i_101 * 16.0))
		var v_y_103: Variant = add(652.0, (sin((v_i_101 * 0.32)) * 16.0))
		invoke_member(v_p_92, "line", [("M" + text_value((v_x_102 - 3.0)) + " " + text_value((v_y_103 - 6.0)) + "l8,13"), getv(v_C_93, "copper"), 2.0, 0.75])
		v_i_101 += 1
	invoke_member(v_k_85, "opening", [244.0, 780.0, 43.0, 70.0, (-3.0)])
	invoke_member(v_k_85, "gallery", [341.0, 737.0, 111.0])
	invoke_member(v_k_85, "cloth", [539.0, 355.0, 25.0, 68.0, getv(v_C_93, "violet")])
	for v_item_104 in [[528.0, 414.0], [605.0, 437.0]]:
		var v_unpack_105: Variant = v_item_104
		var v_x_106: Variant = getv(v_unpack_105, 0)
		var v_y_107: Variant = getv(v_unpack_105, 1)
		invoke_member(v_p_92, "line", [("M" + text_value(v_x_106) + " " + text_value(v_y_107) + "v30"), getv(v_C_93, "copper"), 1.2, 0.6])
		invoke_member(v_p_92, "fill", [ellipse(v_x_106, add(v_y_107, 32.0), 6.0, 9.0), getv(v_C_93, "salt"), 0.7])
	invoke_member(v_k_85, "brazier", [v_fire_95, 0.8])
	invoke_member(v_k_85, "brazier", [v_inner_96, 0.7])
	for v_item_108 in [[524.0, 502.0, "bow", true], [619.0, 516.0, "carry", false], [271.0, 579.0, "work", true], [366.0, 599.0, "work", false], [432.0, 595.0, "carry", true], [321.0, 701.0, "torch", false], [550.0, 762.0, "kneel", false], [687.0, 771.0, "work", true], [235.0, 811.0, "carry", false]]:
		var v_unpack_109: Variant = v_item_108
		var v_x_110: Variant = getv(v_unpack_109, 0)
		var v_y_111: Variant = getv(v_unpack_109, 1)
		var v_a_112: Variant = getv(v_unpack_109, 2)
		var v_l_113: Variant = getv(v_unpack_109, 3)
		invoke_member(v_k_85, "actor", [v_x_110, v_y_111, (1.08 if truth((v_y_111 > 700.0)) else 0.83), v_a_112, v_l_113])
static func fungal(v_k_114):
	var v_unpack_115: Variant = v_k_114
	var v_terrace_116: Variant = getv(v_unpack_115, "terrace")
	var v_stair_117: Variant = getv(v_unpack_115, "stair")
	var v_queue_118: Variant = getv(v_unpack_115, "queue")
	var v_lamp_119: Variant = getv(v_unpack_115, "lamp")
	var v_C_120: Variant = getv(v_unpack_115, "C")
	var v_w_121: Variant = getv(v_unpack_115, "w")
	var v_p_122: Variant = getv(v_unpack_115, "p")
	var v_surf_123: Variant = getv(v_unpack_115, "surf")
	var v_side_124: Variant = getv(v_unpack_115, "side")
	var v_top_125: Variant = getv(v_unpack_115, "top")
	var v_hearth_126: Variant = invoke(v_lamp_119, [606.0, 635.0, 0.85, "#ffad60", 154.0])
	v_hearth_126["marker"] = false
	invoke(v_lamp_119, [390.0, 453.0, 0.35, getv(v_w_121, "c4"), 125.0])
	invoke(v_lamp_119, [230.0, 688.0, 0.25, getv(v_w_121, "c4"), 85.0])
	assign(getv(v_k_114, "wood"), {"mat": "canvas", "field": null, "color": [111.0, 87.0, 63.0], "shadow": [27.0, 27.0, 32.0], "accent": [173.0, 147.0, 103.0]})
	invoke(v_terrace_116, ["M168 544Q154 467 219 421Q301 377 405 400Q513 369 610 436L702 502L716 580L650 637L539 658L433 638L318 678L225 625Z", "M168 544L225 625L318 678L433 638L539 658L650 637L716 580L727 695L661 756L560 779L453 751L357 791L270 748L207 703L170 633Z", [153.0, 370.0, 733.0, 798.0], {"exposure": 0.68}])
	invoke(v_terrace_116, ["M143 704Q180 652 244 655L329 693L402 680L456 717L529 688L627 712L702 684L787 741L771 796L679 823L566 809L459 841L348 817L252 839L178 791Z", "M143 704L178 791L252 839L348 817L459 841L566 809L679 823L771 796L787 741L799 810L736 850L658 864L559 847L468 873L349 853L246 871L176 831Z", [137.0, 649.0, 805.0, 879.0], {"exposure": 0.76}])
	invoke(v_surf_123, ["M298 544Q316 416 322 287L463 265Q441 415 496 550Q398 599 298 544Z", [292.0, 260.0, 503.0, 604.0], merge_dicts([v_side_124, {"field": worldField("silk", v_w_121), "color": mix(getv(v_C_120, "linen"), getv(v_w_121, "c2"), 0.3), "normal": [(-0.3), 0.1, 0.95], "height": make_field("return (9.0*sin(((x*0.027)+(y*0.008))));", [])}])])
	invoke(v_surf_123, ["M132 287Q172 181 326 157Q472 143 613 246L649 294Q524 356 401 326Q238 367 132 287Z", [127.0, 144.0, 655.0, 374.0], merge_dicts([v_top_125, {"field": worldField("fungus", v_w_121), "normal": [(-0.3), (-0.6), 0.74], "shadowField": make_field("return max(0.48,(1.0-((x-220.0)*0.0008)));", []), "height": make_field("return (70.0*exp((-(pow(((x-370.0)/250.0),2.0)+pow(((y-222.0)/92.0),2.0)))));", [])}])])
	invoke_member(v_p_122, "shadow", ["M137 290Q280 323 400 302Q551 330 644 294Q534 377 402 342Q241 386 137 290Z", 0.65, 3.0])
	var v_i_127: Variant = 0.0
	while truth((v_i_127 < 29.0)):
		var v_x_128: Variant = add(151.0, (v_i_127 * 16.0))
		invoke_member(v_p_122, "stroke", [("M390 316Q" + text_value(v_x_128) + " 362 " + text_value(v_x_128) + " " + text_value(add(295.0, (sin((v_i_127 * 0.17)) * 16.0))) + ""), getv(v_C_120, "salt"), 1.2, 0.23])
		v_i_127 += 1
	invoke_member(v_k_114, "opening", [372.0, 523.0, 54.0, 106.0])
	invoke_member(v_k_114, "opening", [434.0, 418.0, 22.0, 44.0])
	invoke_member(v_k_114, "opening", [337.0, 409.0, 19.0, 35.0])
	invoke_member(v_k_114, "gallery", [399.0, 535.0, 206.0])
	invoke_member(v_k_114, "gallery", [389.0, 424.0, 138.0])
	invoke(v_stair_117, [447.0, 566.0, (-7.0), 9.0, 9.0, 61.0])
	mushroom(v_k_114, 610.0, 567.0, 73.0, 137.0)
	mushroom(v_k_114, 691.0, 603.0, 48.0, 94.0)
	invoke_member(v_k_114, "bridge", [473.0, 558.0, 568.0, 594.0, 22.0])
	invoke_member(v_p_122, "shadow", ["M247 526Q404 589 556 542L621 619Q431 690 251 603Z", 0.25, 12.0])
	invoke_member(v_k_114, "table", [290.0, 586.0, 74.0])
	invoke_member(v_k_114, "table", [539.0, 665.0, 67.0])
	invoke_member(v_k_114, "table", [612.0, 694.0, 48.0])
	invoke_member(v_k_114, "supplies", [552.0, 662.0, 6.0])
	invoke_member(v_k_114, "supplies", [297.0, 588.0, 4.0])
	var v_i_129: Variant = 0.0
	while truth((v_i_129 < 5.0)):
		var v_x_130: Variant = add(509.0, (v_i_129 * 22.0))
		var v_y_131: Variant = add(613.0, (v_i_129 * 3.0))
		invoke_member(v_p_122, "line", [("M" + text_value(v_x_130) + " " + text_value(v_y_131) + "v-57"), getv(v_C_120, "copper"), 3.0])
		invoke_member(v_p_122, "line", [("M" + text_value((v_x_130 - 9.0)) + " " + text_value((v_y_131 - 47.0)) + "l22,3"), getv(v_C_120, "salt"), 2.0])
		invoke_member(v_k_114, "cloth", [(v_x_130 - 6.0), (v_y_131 - 43.0), 12.0, 26.0, mix(getv(v_w_121, "c3"), getv(v_w_121, "c2"), 0.3)])
		v_i_129 += 1
	invoke_member(v_k_114, "gallery", [590.0, 750.0, 193.0])
	invoke(v_stair_117, [283.0, 714.0, 9.0, 6.0, 8.0, 53.0])
	invoke_member(v_k_114, "opening", [233.0, 738.0, 37.0, 56.0, (-3.0)])
	for v_item_132 in [[174.0, 697.0, 42.0, 78.0], [733.0, 758.0, 52.0, 99.0], [377.0, 759.0, 21.0, 40.0], [215.0, 589.0, 27.0, 62.0], [493.0, 461.0, 28.0, 52.0]]:
		var v_unpack_133: Variant = v_item_132
		var v_x_134: Variant = getv(v_unpack_133, 0)
		var v_y_135: Variant = getv(v_unpack_133, 1)
		var v_a_136: Variant = getv(v_unpack_133, 2)
		var v_b_137: Variant = getv(v_unpack_133, 3)
		mushroom(v_k_114, v_x_134, v_y_135, v_a_136, v_b_137, false)
	var v_i_138: Variant = 0.0
	while truth((v_i_138 < 6.0)):
		var v_x_139: Variant = add(206.0, (v_i_138 * 19.0))
		var v_y_140: Variant = add(311.0, (v_i_138 * 4.0))
		invoke_member(v_p_122, "line", [("M" + text_value(v_x_139) + " " + text_value(v_y_140) + "Q" + text_value(add(v_x_139, 12.0)) + " 409 " + text_value(add(v_x_139, 6.0)) + " " + text_value(add(490.0, (v_i_138 * 5.0))) + ""), getv(v_C_120, "copper"), 1.0, 0.6])
		invoke_member(v_p_122, "fill", [ellipse(add(v_x_139, 6.0), add(490.0, (v_i_138 * 5.0)), 5.0, 8.0), getv(v_C_120, "copper"), 0.8])
		v_i_138 += 1
	invoke_member(v_k_114, "cloth", [357.0, 459.0, 24.0, 59.0, mix("#596e62", getv(v_C_120, "linen"), 0.25)])
	invoke_member(v_k_114, "cloth", [424.0, 377.0, 17.0, 33.0, "#977c62"])
	for v_item_141 in [[352.0, 529.0], [448.0, 538.0], [564.0, 582.0], [651.0, 608.0]]:
		var v_unpack_142: Variant = v_item_141
		var v_x_143: Variant = getv(v_unpack_142, 0)
		var v_y_144: Variant = getv(v_unpack_142, 1)
		invoke_member(v_p_122, "line", [("M" + text_value(v_x_143) + " " + text_value(v_y_144) + "l-12,49l30,-41"), getv(v_C_120, "copper"), 3.0, 0.8])
	invoke_member(v_k_114, "brazier", [v_hearth_126, 0.76])
	for v_item_145 in [[554.0, 672.0], [580.0, 677.0], [620.0, 704.0]]:
		var v_unpack_146: Variant = v_item_145
		var v_x_147: Variant = getv(v_unpack_146, 0)
		var v_y_148: Variant = getv(v_unpack_146, 1)
		invoke_member(v_p_122, "fill", [("M" + text_value(v_x_147) + " " + text_value(v_y_148) + "l17,3l8,-7l-16,-4Z"), "#29252c"])
		var v_j_149: Variant = 0.0
		while truth((v_j_149 < 4.0)):
			invoke_member(v_p_122, "fill", [ellipse(add(add(v_x_147, 5.0), (v_j_149 * 3.0)), (v_y_148 - 1.0), 1.7, 2.0), "#a7ae80"])
			v_j_149 += 1
	invoke_member(v_p_122, "line", ["M166 602L211 613L211 655L166 644Z", "#8b775b", 2.0])
	var v_i_150: Variant = 0.0
	while truth((v_i_150 < 6.0)):
		invoke_member(v_p_122, "line", [("M" + text_value(add(170.0, (v_i_150 * 7.0))) + " " + text_value(add(605.0, (v_i_150 * 2.0))) + "v36"), "#aa9270", 0.8, 0.6])
		invoke_member(v_p_122, "line", [("M169 " + text_value(add(610.0, (v_i_150 * 6.0))) + "l40,10"), "#aa9270", 0.8, 0.6])
		v_i_150 += 1
	var v_i_151: Variant = 0.0
	while truth((v_i_151 < 13.0)):
		var v_x_152: Variant = add(174.0, (v_i_151 * 32.0))
		var v_y_153: Variant = add(282.0, (sin((v_i_151 * 0.53)) * 17.0))
		invoke_member(v_p_122, "stroke", [("M" + text_value(v_x_152) + " " + text_value(v_y_153) + "q10,11 21,4"), mix(getv(v_C_120, "salt"), getv(v_w_121, "c2"), 0.4), 2.0, 0.32])
		v_i_151 += 1
	for v_item_154 in [[350.0, 549.0, "torch", false], [432.0, 550.0, "carry", false], [309.0, 620.0, "work", true], [571.0, 712.0, "work", true], [641.0, 737.0, "carry", false], [264.0, 786.0, "carry", true], [423.0, 791.0, "bow", false], [627.0, 615.0, "kneel", false]]:
		var v_unpack_155: Variant = v_item_154
		var v_x_156: Variant = getv(v_unpack_155, 0)
		var v_y_157: Variant = getv(v_unpack_155, 1)
		var v_a_158: Variant = getv(v_unpack_155, 2)
		var v_lit_159: Variant = getv(v_unpack_155, 3)
		invoke_member(v_k_114, "actor", [v_x_156, v_y_157, (1.05 if truth((v_y_157 > 700.0)) else 0.84), v_a_158, v_lit_159])
static func fire(v_k_160):
	var v_unpack_161: Variant = v_k_160
	var v_terrace_162: Variant = getv(v_unpack_161, "terrace")
	var v_surf_163: Variant = getv(v_unpack_161, "surf")
	var v_side_164: Variant = getv(v_unpack_161, "side")
	var v_top_165: Variant = getv(v_unpack_161, "top")
	var v_hall_166: Variant = getv(v_unpack_161, "hall")
	var v_stair_167: Variant = getv(v_unpack_161, "stair")
	var v_lamp_168: Variant = getv(v_unpack_161, "lamp")
	var v_queue_169: Variant = getv(v_unpack_161, "queue")
	var v_w_170: Variant = getv(v_unpack_161, "w")
	var v_C_171: Variant = getv(v_unpack_161, "C")
	var v_p_172: Variant = getv(v_unpack_161, "p")
	invoke(v_lamp_168, [501.0, 614.0, 1.16, getv(v_w_170, "c4"), 237.0])["marker"] = false
	var v_hearth_173: Variant = invoke(v_lamp_168, [629.0, 416.0, 0.65, "#ffac62", 142.0])
	var v_gateFire_174: Variant = invoke(v_lamp_168, [264.0, 671.0, 0.63, "#ffb46c", 118.0])
	v_hearth_173["marker"] = false
	v_gateFire_174["marker"] = false
	invoke(v_terrace_162, ["M187 474L208 387L310 322L413 333L487 288L607 306L697 363L749 449L727 538L659 572L555 553L488 585L378 566L286 594L218 550Z", "M187 474L218 550L286 594L378 566L488 585L555 553L659 572L727 538L749 449L774 574L720 653L615 691L514 666L410 704L310 681L235 625L195 555Z", [182.0, 281.0, 780.0, 710.0]])
	invoke(v_hall_166, [445.0, 427.0, 242.0, 189.0, {"roof": "broken", "windows": 4.0}])
	invoke(v_hall_166, [245.0, 455.0, 145.0, 90.0, {"roof": "tile", "windows": 3.0}])
	for v_item_175 in [[478.0, 251.0, 128.0], [589.0, 273.0, 169.0], [663.0, 296.0, 109.0]]:
		var v_unpack_176: Variant = v_item_175
		var v_x_177: Variant = getv(v_unpack_176, 0)
		var v_y_178: Variant = getv(v_unpack_176, 1)
		var v_h_179: Variant = getv(v_unpack_176, 2)
		invoke(v_surf_163, [("M" + text_value((v_x_177 - 18.0)) + " " + text_value(v_y_178) + "L" + text_value((v_x_177 - 14.0)) + " " + text_value((v_y_178 - v_h_179)) + "L" + text_value(add(v_x_177, 12.0)) + " " + text_value(((v_y_178 - v_h_179) - 7.0)) + "L" + text_value(add(v_x_177, 25.0)) + " " + text_value(add(v_y_178, 9.0)) + "Z"), [(v_x_177 - 24.0), ((v_y_178 - v_h_179) - 12.0), add(v_x_177, 31.0), add(v_y_178, 16.0)], merge_dicts([v_side_164, {"field": worldField("basalt", v_w_170), "color": getv(v_w_170, "c2"), "normal": [0.3, 0.1, 0.94]}])])
		invoke_member(v_p_172, "fill", [ellipse(v_x_177, (v_y_178 - v_h_179), 14.0, 5.0), getv(v_w_170, "c0")])
		invoke_member(v_p_172, "glow", [v_x_177, add((v_y_178 - v_h_179), 3.0), 19.0, getv(v_w_170, "c4"), 0.1])
	for v_item_180 in [464.0, 542.0, 620.0, 687.0]:
		var v_x_181: Variant = v_item_180
		invoke(v_surf_163, [("M" + text_value(v_x_181) + " 474l-19,-13l4,-130l13,-5l5,105l24,39Z"), [(v_x_181 - 23.0), 321.0, add(v_x_181, 30.0), 479.0], merge_dicts([v_side_164, {"mat": "masonry", "field": null, "color": getv(v_C_171, "stone"), "normal": [(-0.6), 0.1, 0.8]}])])
	invoke_member(v_k_160, "gallery", [571.0, 467.0, 199.0])
	invoke(v_stair_167, [409.0, 489.0, (-9.0), 8.0, 12.0, 69.0])
	invoke(v_terrace_162, ["M146 655L226 599L315 614L374 654L431 676L501 701L596 682L692 634L775 658L808 726L758 794L670 825L558 807L466 845L350 817L247 833L166 768Z", "M146 655L166 768L247 833L350 817L466 845L558 807L670 825L758 794L808 726L823 794L766 841L681 870L572 847L472 881L346 853L241 869L170 817Z", [140.0, 593.0, 829.0, 888.0]])
	invoke(v_surf_163, ["M365 617Q442 551 550 556Q665 568 692 629Q647 696 522 716Q425 704 365 617Z", [360.0, 548.0, 698.0, 722.0], merge_dicts([v_side_164, {"normal": [0.1, 0.2, 0.97], "color": getv(v_w_170, "c1"), "exposure": 0.49}])])
	invoke(v_surf_163, ["M420 634Q455 596 529 599Q601 601 639 638Q591 681 521 690Q459 681 420 634Z", [415.0, 593.0, 645.0, 696.0], merge_dicts([v_top_165, {"field": worldField("lava", v_w_170), "color": getv(v_w_170, "c4"), "exposure": 0.7}])])
	invoke_member(v_p_172, "shadow", ["M369 618Q449 552 549 557L556 591Q452 579 419 636Z", 0.5, 4.0])
	invoke_member(v_k_160, "opening", [570.0, 553.0, 38.0, 55.0])
	invoke_member(v_k_160, "opening", [649.0, 541.0, 28.0, 43.0])
	invoke_member(v_p_172, "glow", [568.0, 537.0, 44.0, getv(v_w_170, "c4"), 0.2])
	invoke_member(v_k_160, "bridge", [291.0, 681.0, 406.0, 714.0, 27.0, {"rope": false}])
	invoke_member(v_k_160, "gallery", [710.0, 685.0, 110.0])
	invoke(v_stair_167, [725.0, 707.0, (-8.0), 8.0, 8.0, 47.0])
	invoke_member(v_p_172, "line", ["M327 671L334 481L483 523", getv(v_C_171, "copper"), 8.0])
	invoke_member(v_p_172, "line", ["M334 481L410 539L483 523", getv(v_C_171, "stone"), 3.0])
	invoke_member(v_p_172, "line", ["M477 524v70", getv(v_C_171, "copper"), 2.0])
	invoke_member(v_p_172, "line", ["M491 527v69", getv(v_C_171, "copper"), 2.0])
	invoke(v_surf_163, ["M463 591L506 599L498 623L474 619Z", [458.0, 586.0, 511.0, 628.0], {"mat": "metal", "field": null, "color": getv(v_C_171, "copper"), "normal": [(-0.4), 0.2, 0.9]}])
	invoke(v_hall_166, [173.0, 668.0, 91.0, 69.0, {"roof": "tile", "windows": 2.0}])
	invoke_member(v_k_160, "table", [266.0, 746.0, 68.0])
	invoke_member(v_k_160, "table", [625.0, 747.0, 71.0])
	invoke_member(v_k_160, "supplies", [632.0, 749.0, 5.0])
	invoke_member(v_k_160, "supplies", [207.0, 711.0, 4.0])
	var v_i_182: Variant = 0.0
	while truth((v_i_182 < 8.0)):
		var v_x_183: Variant = add(369.0, (v_i_182 * 23.0))
		var v_y_184: Variant = add(774.0, (fmod(v_i_182, 3.0) * 6.0))
		invoke(v_surf_163, [("M" + text_value(v_x_183) + " " + text_value(v_y_184) + "l8,-10l15,3l-5,13Z"), [(v_x_183 - 3.0), (v_y_184 - 14.0), add(v_x_183, 27.0), add(v_y_184, 17.0)], {"mat": "metal", "field": null, "color": getv(v_C_171, "copper"), "normal": [(-0.3), (-0.6), 0.74]}])
		v_i_182 += 1
	invoke(v_surf_163, ["M532 704Q570 733 570 776L598 826L581 838L552 783Q552 742 518 716Z", [512.0, 698.0, 604.0, 844.0], merge_dicts([v_top_165, {"field": worldField("lava", v_w_170), "exposure": 0.55}])])
	for v_item_185 in [[492.0, 442.0, 44.0, 93.0], [570.0, 457.0, 35.0, 73.0]]:
		var v_unpack_186: Variant = v_item_185
		var v_x_187: Variant = getv(v_unpack_186, 0)
		var v_y_188: Variant = getv(v_unpack_186, 1)
		var v_ww_189: Variant = getv(v_unpack_186, 2)
		var v_hh_190: Variant = getv(v_unpack_186, 3)
		invoke_member(v_k_160, "opening", [v_x_187, v_y_188, v_ww_189, v_hh_190])
		invoke(v_surf_163, [("M" + text_value((v_x_187 - (v_ww_189 * 0.4))) + " " + text_value((v_y_188 - 3.0)) + "l" + text_value((v_ww_189 * 0.4)) + ",-15l" + text_value((v_ww_189 * 0.4)) + ",19l" + text_value(((-v_ww_189) * 0.4)) + ",6Z"), [(v_x_187 - (v_ww_189 * 0.5)), (v_y_188 - 22.0), add(v_x_187, (v_ww_189 * 0.5)), add(v_y_188, 11.0)], merge_dicts([v_top_165, {"mat": "masonry", "field": null, "color": "#9c7c53"}])])
		invoke_member(v_p_172, "glow", [v_x_187, (v_y_188 - 17.0), (v_ww_189 * 0.6), getv(v_w_170, "c4"), 0.12])
		invoke_member(v_p_172, "line", [("M" + text_value(add(v_x_187, (v_ww_189 * 0.35))) + " " + text_value((v_y_188 - 4.0)) + "v" + text_value(((-v_hh_190) * 0.52)) + ""), getv(v_w_170, "c2"), 4.0, 0.7])
	invoke_member(v_k_160, "brazier", [v_hearth_173, 0.72])
	invoke_member(v_k_160, "brazier", [v_gateFire_174, 0.78])
	invoke(v_surf_163, ["M572 141L606 149L606 163L570 154Z", [566.0, 137.0, 611.0, 168.0], merge_dicts([v_side_164, {"mat": "metal", "field": null, "color": getv(v_C_171, "copper")}])])
	var v_i_191: Variant = 0.0
	while truth((v_i_191 < 5.0)):
		var v_yy_192: Variant = add(157.0, (v_i_191 * 21.0))
		invoke_member(v_p_172, "line", [("M575 " + text_value(v_yy_192) + "l23,6"), getv(v_C_171, "stoneShadow"), 2.0, 0.7])
		v_i_191 += 1
	invoke_member(v_k_160, "cloth", [451.0, 323.0, 21.0, 63.0, "#635f50"])
	invoke_member(v_k_160, "cloth", [641.0, 357.0, 17.0, 46.0, "#8d7858"])
	invoke(v_surf_163, ["M682 501L699 507L633 605L615 598Z", [610.0, 497.0, 705.0, 610.0], {"mat": "metal", "field": null, "color": "#7a6247", "shadow": getv(v_w_170, "c0"), "accent": "#c89a61", "normal": [(-0.4), (-0.6), 0.7]}])
	invoke_member(v_p_172, "line", ["M687 506L622 599", getv(v_w_170, "c0"), 4.0, 0.7])
	var v_i_193: Variant = 0.0
	while truth((v_i_193 < 5.0)):
		var v_x_194: Variant = add(642.0, (v_i_193 * 8.0))
		var v_y_195: Variant = (552.0 - (v_i_193 * 12.0))
		invoke_member(v_p_172, "fill", [("M" + text_value(v_x_194) + " " + text_value(v_y_195) + "l5,-6l6,5l-5,7Z"), "#302622"])
		v_i_193 += 1
	for v_item_196 in [[299.0, 754.0], [653.0, 760.0]]:
		var v_unpack_197: Variant = v_item_196
		var v_x_198: Variant = getv(v_unpack_197, 0)
		var v_y_199: Variant = getv(v_unpack_197, 1)
		invoke(v_surf_163, [("M" + text_value((v_x_198 - 8.0)) + " " + text_value(v_y_199) + "l17,-7l12,8l-8,12l-19,-3Z"), [(v_x_198 - 12.0), (v_y_199 - 10.0), add(v_x_198, 24.0), add(v_y_199, 16.0)], merge_dicts([v_side_164, {"mat": "metal", "field": null, "color": "#615d4f"}])])
		invoke_member(v_p_172, "line", [("M" + text_value(v_x_198) + " " + text_value((v_y_199 - 8.0)) + "l17,-12"), getv(v_C_171, "copper"), 2.0])
	invoke_member(v_p_172, "line", ["M377 802l16,-19m-11,18l16,-18", "#918374", 2.0])
	invoke_member(v_p_172, "line", ["M694 738l22,7m-19,-1l16,-8", getv(v_C_171, "copper"), 2.0])
	invoke_member(v_p_172, "shadow", ["M325 675L337 675L387 739L374 742Z", 0.4, 3.0])
	invoke_member(v_p_172, "shadow", ["M172 686L265 709L298 739L208 716Z", 0.3, 4.0])
	for v_item_200 in [[480.0, 476.0, "torch", true], [607.0, 499.0, "bow", false], [350.0, 550.0, "carry", false], [279.0, 596.0, "carry", false], [233.0, 713.0, "torch", false], [307.0, 780.0, "work", true], [656.0, 791.0, "work", true], [412.0, 761.0, "bow", false], [716.0, 746.0, "carry", false]]:
		var v_unpack_201: Variant = v_item_200
		var v_x_202: Variant = getv(v_unpack_201, 0)
		var v_y_203: Variant = getv(v_unpack_201, 1)
		var v_a_204: Variant = getv(v_unpack_201, 2)
		var v_lit_205: Variant = getv(v_unpack_201, 3)
		invoke_member(v_k_160, "actor", [v_x_202, v_y_203, (1.1 if truth((v_y_203 > 700.0)) else 0.78), v_a_204, v_lit_205])
static func frozen(v_k_206):
	var v_unpack_207: Variant = v_k_206
	var v_terrace_208: Variant = getv(v_unpack_207, "terrace")
	var v_hall_209: Variant = getv(v_unpack_207, "hall")
	var v_stair_210: Variant = getv(v_unpack_207, "stair")
	var v_lamp_211: Variant = getv(v_unpack_207, "lamp")
	var v_queue_212: Variant = getv(v_unpack_207, "queue")
	var v_cloth_213: Variant = getv(v_unpack_207, "cloth")
	var v_w_214: Variant = getv(v_unpack_207, "w")
	var v_C_215: Variant = getv(v_unpack_207, "C")
	var v_p_216: Variant = getv(v_unpack_207, "p")
	var v_surf_217: Variant = getv(v_unpack_207, "surf")
	var v_top_218: Variant = getv(v_unpack_207, "top")
	var v_side_219: Variant = getv(v_unpack_207, "side")
	var v_hearth_220: Variant = invoke(v_lamp_211, [453.0, 461.0, 0.83, "#ff9c50", 135.0])
	var v_gateFire_221: Variant = invoke(v_lamp_211, [280.0, 622.0, 0.67, "#ffab60", 112.0])
	v_hearth_220["marker"] = false
	v_gateFire_221["marker"] = false
	invoke(v_lamp_211, [653.0, 566.0, 0.12, "#b2d6e7", 77.0])
	invoke(v_terrace_208, ["M167 445L155 353L205 265L305 232L381 251L463 209L583 241L683 301L740 377L717 470L625 517L521 505L447 538L350 508L256 521Z", "M167 445L256 521L350 508L447 538L521 505L625 517L717 470L740 377L759 528L708 609L620 649L538 630L462 667L366 630L276 647L205 591L170 521Z", [150.0, 204.0, 766.0, 673.0]])
	invoke(v_surf_217, ["M583 241L683 301L740 377L759 528L708 609L663 568L680 423L630 359Z", [580.0, 237.0, 764.0, 613.0], merge_dicts([v_side_219, {"normal": [0.78, 0.16, 0.6], "exposure": 0.64}])])
	invoke(v_terrace_208, ["M208 583L277 541L351 558L430 527L514 550L587 524L677 553L754 615L731 690L636 735L541 747L452 721L349 761L258 727L193 657Z", "M208 583L193 657L258 727L349 761L452 721L541 747L636 735L731 690L754 615L769 729L718 786L627 814L546 799L468 832L383 805L302 834L230 783L185 711Z", [180.0, 520.0, 774.0, 840.0]])
	invoke(v_hall_209, [303.0, 436.0, 277.0, 116.0, {"roof": "snow", "windows": 5.0}])
	invoke(v_hall_209, [216.0, 504.0, 93.0, 78.0, {"roof": "snow", "windows": 2.0}])
	invoke_member(v_p_216, "shadow", ["M305 450L582 515L657 563L571 580L322 509Z", 0.32, 9.0])
	invoke_member(v_k_206, "gallery", [442.0, 472.0, 242.0])
	invoke(v_stair_210, [465.0, 499.0, (-8.0), 8.0, 10.0, 78.0])
	invoke(v_surf_217, ["M220 629Q286 695 385 696L396 728Q270 744 204 658Z", [198.0, 622.0, 402.0, 749.0], merge_dicts([v_side_219, {"normal": [(-0.55), 0.1, 0.82], "exposure": 0.94}])])
	invoke(v_surf_217, ["M220 629Q286 695 385 696L395 686Q283 680 229 615Z", [216.0, 610.0, 402.0, 704.0], merge_dicts([v_top_218, {"color": getv(v_C_215, "salt")}])])
	invoke(v_hall_209, [541.0, 634.0, 119.0, 69.0, {"roof": "snow", "windows": 2.0}])
	invoke_member(v_k_206, "opening", [266.0, 746.0, 40.0, 67.0, (-4.0)])
	invoke(v_stair_210, [275.0, 755.0, (-7.0), 7.0, 6.0, 48.0])
	invoke_member(v_p_216, "line", ["M666 533L669 349", getv(v_C_215, "copper"), 4.0])
	invoke_member(v_p_216, "line", ["M630 389L710 402", getv(v_C_215, "salt"), 3.0])
	invoke_member(v_p_216, "line", ["M645 375L692 419", getv(v_C_215, "copper"), 2.0])
	var v_i_222: Variant = 0.0
	while truth((v_i_222 < 5.0)):
		var v_x_223: Variant = add(617.0, (v_i_222 * 23.0))
		var v_y_224: Variant = add(595.0, (v_i_222 * 3.0))
		invoke_member(v_p_216, "line", [("M" + text_value(v_x_223) + " " + text_value(v_y_224) + "v-57"), getv(v_C_215, "copper"), 3.0])
		invoke(v_cloth_213, [v_x_223, (v_y_224 - 55.0), 21.0, 29.0, mix(getv(v_w_214, "c2"), getv(v_w_214, "c3"), 0.45)])
		v_i_222 += 1
	invoke(v_surf_217, ["M505 676Q468 719 486 756L455 817L432 825L458 755Q445 714 480 682Z", [427.0, 670.0, 510.0, 832.0], merge_dicts([v_top_218, {"mat": "water", "field": null, "color": getv(v_w_214, "c2"), "shadow": getv(v_w_214, "c0"), "cx": 900.0, "cy": 100.0, "bump": 0.2}])])
	invoke_member(v_k_206, "table", [304.0, 623.0, 65.0])
	invoke_member(v_k_206, "supplies", [316.0, 622.0, 4.0])
	invoke_member(v_k_206, "table", [554.0, 688.0, 42.0])
	invoke_member(v_k_206, "supplies", [223.0, 589.0, 3.0])
	for v_item_225 in [[373.0, 375.0], [493.0, 401.0], [554.0, 420.0]]:
		var v_unpack_226: Variant = v_item_225
		var v_x_227: Variant = getv(v_unpack_226, 0)
		var v_y_228: Variant = getv(v_unpack_226, 1)
		invoke_member(v_k_206, "opening", [v_x_227, v_y_228, 14.0, 26.0])
		invoke_member(v_p_216, "fill", [ellipse(v_x_227, (v_y_228 - 10.0), 3.0, 5.0), "#edb16d", 0.55])
	invoke_member(v_p_216, "line", ["M311 679l56,11m-60,-5l56,11", getv(v_C_215, "copper"), 3.0])
	var v_i_229: Variant = 0.0
	while truth((v_i_229 < 6.0)):
		invoke_member(v_p_216, "line", [("M" + text_value(add(319.0, (v_i_229 * 6.0))) + " " + text_value(add(673.0, v_i_229)) + "l4,15"), getv(v_C_215, "stone"), 3.0])
		v_i_229 += 1
	for v_item_230 in [[228.0, 569.0], [282.0, 533.0], [524.0, 561.0], [579.0, 576.0]]:
		var v_unpack_231: Variant = v_item_230
		var v_x_232: Variant = getv(v_unpack_231, 0)
		var v_y_233: Variant = getv(v_unpack_231, 1)
		invoke_member(v_p_216, "line", [("M" + text_value(v_x_232) + " " + text_value(v_y_233) + "v-21"), getv(v_C_215, "copper"), 2.0])
		invoke_member(v_p_216, "stroke", [("M" + text_value((v_x_232 - 7.0)) + " " + text_value(add(v_y_233, 3.0)) + "l16,3"), getv(v_C_215, "salt"), 1.0, 0.5])
	for v_item_234 in [[304.0, 442.0, 110.0], [389.0, 469.0, 104.0], [484.0, 488.0, 108.0], [583.0, 506.0, 101.0]]:
		var v_unpack_235: Variant = v_item_234
		var v_x_236: Variant = getv(v_unpack_235, 0)
		var v_y_237: Variant = getv(v_unpack_235, 1)
		var v_hh_238: Variant = getv(v_unpack_235, 2)
		invoke(v_surf_217, [("M" + text_value((v_x_236 - 7.0)) + " " + text_value(v_y_237) + "L" + text_value((v_x_236 - 3.0)) + " " + text_value((v_y_237 - v_hh_238)) + "L" + text_value(add(v_x_236, 6.0)) + " " + text_value(add((v_y_237 - v_hh_238), 4.0)) + "L" + text_value(add(v_x_236, 8.0)) + " " + text_value((v_y_237 - 18.0)) + "L" + text_value(add(v_x_236, 19.0)) + " " + text_value(add(v_y_237, 10.0)) + "L" + text_value(add(v_x_236, 4.0)) + " " + text_value(add(v_y_237, 15.0)) + "Z"), [(v_x_236 - 11.0), ((v_y_237 - v_hh_238) - 4.0), add(v_x_236, 23.0), add(v_y_237, 19.0)], merge_dicts([v_side_219, {"mat": "masonry", "field": null, "color": mix(getv(v_C_215, "salt"), "#958c72", 0.3), "normal": [(-0.55), 0.1, 0.83], "exposure": 0.73}])])
		invoke_member(v_p_216, "shadow", [("M" + text_value(add(v_x_236, 8.0)) + " " + text_value(add((v_y_237 - v_hh_238), 8.0)) + "L" + text_value(add(v_x_236, 9.0)) + " " + text_value((v_y_237 - 18.0)) + "L" + text_value(add(v_x_236, 19.0)) + " " + text_value(add(v_y_237, 10.0)) + "L" + text_value(add(v_x_236, 11.0)) + " " + text_value(add(v_y_237, 13.0)) + "Z"), 0.38])
	for v_item_239 in ["M203 320L247 344L237 381L262 406", "M330 265L349 288L343 312", "M535 278L562 310L552 336", "M664 335L655 371L681 400L675 429"]:
		var v_d_240: Variant = v_item_239
		invoke_member(v_p_216, "line", [v_d_240, getv(v_w_214, "c1"), 2.0, 0.55])
		invoke_member(v_p_216, "stroke", [v_d_240, getv(v_C_215, "salt"), 1.0, 0.3])
	for v_item_241 in [[209.0, 362.0], [535.0, 312.0], [615.0, 419.0]]:
		var v_unpack_242: Variant = v_item_241
		var v_x_243: Variant = getv(v_unpack_242, 0)
		var v_y_244: Variant = getv(v_unpack_242, 1)
		invoke(v_surf_217, [("M" + text_value(v_x_243) + " " + text_value(v_y_244) + "l30,-13l21,11l-23,16Z"), [(v_x_243 - 3.0), (v_y_244 - 17.0), add(v_x_243, 55.0), add(v_y_244, 19.0)], merge_dicts([v_top_218, {"color": getv(v_C_215, "salt"), "exposure": 0.73}])])
		invoke_member(v_p_216, "shadow", [("M" + text_value(add(v_x_243, 2.0)) + " " + text_value(add(v_y_244, 5.0)) + "l44,-1l-20,15Z"), 0.35, 2.0])
	invoke_member(v_k_206, "brazier", [v_hearth_220, 0.77])
	invoke_member(v_k_206, "brazier", [v_gateFire_221, 0.78])
	invoke_member(v_k_206, "cloth", [312.0, 358.0, 18.0, 52.0, "#717166"])
	invoke_member(v_k_206, "cloth", [551.0, 402.0, 22.0, 55.0, "#7f6a58"])
	var v_i_245: Variant = 0.0
	while truth((v_i_245 < 7.0)):
		var v_x_246: Variant = add(212.0, (v_i_245 * 7.0))
		var v_y_247: Variant = add(607.0, (fmod(v_i_245, 2.0) * 5.0))
		invoke_member(v_p_216, "line", [("M" + text_value(v_x_246) + " " + text_value(v_y_247) + "l22,6"), "#796448", 4.0])
		invoke_member(v_p_216, "fill", [ellipse(v_x_246, v_y_247, 2.0, 3.0), "#ae9064"])
		v_i_245 += 1
	invoke(v_surf_217, ["M559 674L574 646L629 658L641 690L593 682Z", [554.0, 641.0, 647.0, 695.0], {"mat": "cloth", "field": null, "color": "#897c5e", "shadow": getv(v_w_214, "c1"), "accent": getv(v_C_215, "salt"), "normal": [(-0.2), (-0.65), 0.75], "height": make_field("return (sin((x*0.15))*2.0);", [])}])
	invoke_member(v_p_216, "line", ["M564 674v38M638 689v27", getv(v_C_215, "copper"), 3.0])
	invoke_member(v_k_206, "supplies", [584.0, 704.0, 3.0])
	var v_i_248: Variant = 0.0
	while truth((v_i_248 < 5.0)):
		invoke_member(v_p_216, "fill", [("M" + text_value(add(321.0, (v_i_248 * 7.0))) + " " + text_value(add(671.0, v_i_248)) + "l7,-9l9,4l-3,10Z"), "#665b4c"])
		v_i_248 += 1
	for v_item_249 in [[353.0, 502.0, "torch", false], [493.0, 527.0, "carry", false], [418.0, 557.0, "bow", false], [322.0, 655.0, "work", true], [269.0, 664.0, "bow", false], [373.0, 716.0, "carry", false], [596.0, 741.0, "work", true], [694.0, 611.0, "torch", false], [252.0, 786.0, "carry", true]]:
		var v_unpack_250: Variant = v_item_249
		var v_x_251: Variant = getv(v_unpack_250, 0)
		var v_y_252: Variant = getv(v_unpack_250, 1)
		var v_a_253: Variant = getv(v_unpack_250, 2)
		var v_lit_254: Variant = getv(v_unpack_250, 3)
		invoke_member(v_k_206, "actor", [v_x_251, v_y_252, (1.04 if truth((v_y_252 > 650.0)) else 0.78), v_a_253, v_lit_254])
static func colour(v_k_255):
	var v_unpack_256: Variant = v_k_255
	var v_terrace_257: Variant = getv(v_unpack_256, "terrace")
	var v_surf_258: Variant = getv(v_unpack_256, "surf")
	var v_side_259: Variant = getv(v_unpack_256, "side")
	var v_top_260: Variant = getv(v_unpack_256, "top")
	var v_hall_261: Variant = getv(v_unpack_256, "hall")
	var v_stair_262: Variant = getv(v_unpack_256, "stair")
	var v_p_263: Variant = getv(v_unpack_256, "p")
	var v_C_264: Variant = getv(v_unpack_256, "C")
	var v_w_265: Variant = getv(v_unpack_256, "w")
	var v_light_266: Variant = invoke_member(v_k_255, "lamp", [527.0, 563.0, 0.78, "#e8c78a", 147.0])
	var v_prism_267: Variant = invoke_member(v_k_255, "lamp", [615.0, 409.0, 0.48, getv(v_w_265, "c4"), 123.0])
	v_prism_267["marker"] = false
	v_light_266["marker"] = getv(v_prism_267, "marker")
	invoke(v_terrace_257, ["M382 487L409 373L491 313L590 296L676 345L745 427L759 511L697 568L596 602L484 570L408 589Z", "M382 487L408 589L484 570L596 602L697 568L759 511L780 624L714 703L605 747L505 700L422 724L387 623Z", [376.0, 290.0, 786.0, 754.0]])
	spire(v_k_255, 581.0, 414.0, 88.0, 283.0)
	spire(v_k_255, 700.0, 459.0, 39.0, 188.0)
	spire(v_k_255, 445.0, 456.0, 30.0, 130.0)
	invoke(v_terrace_257, ["M139 607L205 542L302 532L401 573L473 558L558 615L658 637L723 698L696 771L605 811L505 791L414 833L302 804L205 824L140 757L121 678Z", "M139 607L121 678L140 757L205 824L302 804L414 833L505 791L605 811L696 771L723 698L741 787L680 839L594 861L500 832L414 874L299 843L204 865L138 818L115 741Z", [109.0, 526.0, 747.0, 881.0]])
	invoke(v_hall_261, [463.0, 525.0, 188.0, 118.0, {"roof": "broken", "windows": 3.0}])
	invoke_member(v_k_255, "gallery", [556.0, 557.0, 173.0])
	invoke(v_stair_262, [479.0, 581.0, (-8.0), 8.0, 11.0, 65.0])
	invoke(v_hall_261, [175.0, 618.0, 105.0, 65.0, {"roof": "tile", "windows": 2.0}])
	invoke_member(v_k_255, "cloth", [488.0, 445.0, 21.0, 62.0, getv(v_C_264, "violet")])
	invoke_member(v_k_255, "basin", [384.0, 704.0, 113.0, 57.0, {"liquid": "prism"}])
	spire(v_k_255, 260.0, 733.0, 28.0, 115.0)
	spire(v_k_255, 600.0, 747.0, 21.0, 80.0)
	invoke(v_surf_258, ["M465 669L496 645L540 654L527 689L487 710Z", [460.0, 640.0, 545.0, 715.0], merge_dicts([v_side_259, {"field": null, "mat": "masonry", "color": getv(v_w_265, "c1"), "exposure": 0.55}])])
	invoke_member(v_k_255, "table", [504.0, 704.0, 74.0])
	invoke_member(v_k_255, "table", [193.0, 694.0, 56.0])
	invoke_member(v_k_255, "supplies", [513.0, 708.0, 4.0])
	invoke_member(v_k_255, "opening", [209.0, 796.0, 36.0, 63.0, (-4.0)])
	invoke_member(v_k_255, "brazier", [v_light_266, 0.78])
	invoke_member(v_k_255, "brazier", [v_prism_267, 0.65])
	var v_i_268: Variant = 0.0
	while truth((v_i_268 < 7.0)):
		var v_x_269: Variant = add(534.0, (v_i_268 * 9.0))
		var v_y_270: Variant = add(751.0, (fmod(v_i_268, 3.0) * 4.0))
		invoke(v_surf_258, [("M" + text_value(v_x_269) + " " + text_value(v_y_270) + "l3,-13l7,5l-2,11Z"), [(v_x_269 - 3.0), (v_y_270 - 17.0), add(v_x_269, 13.0), add(v_y_270, 7.0)], merge_dicts([v_top_260, {"field": worldField("prism", v_w_265), "exposure": 0.7}])])
		v_i_268 += 1
	for v_item_271 in [[509.0, 564.0, "torch", false], [616.0, 588.0, "bow", true], [425.0, 630.0, "carry", false], [230.0, 731.0, "work", true], [527.0, 750.0, "work", true], [348.0, 778.0, "kneel", false], [639.0, 783.0, "carry", false], [203.0, 824.0, "torch", false]]:
		var v_unpack_272: Variant = v_item_271
		var v_x_273: Variant = getv(v_unpack_272, 0)
		var v_y_274: Variant = getv(v_unpack_272, 1)
		var v_a_275: Variant = getv(v_unpack_272, 2)
		var v_l_276: Variant = getv(v_unpack_272, 3)
		invoke_member(v_k_255, "actor", [v_x_273, v_y_274, (1.05 if truth((v_y_274 > 700.0)) else 0.8), v_a_275, v_l_276])
static func archive(v_k_277):
	var v_unpack_278: Variant = v_k_277
	var v_terrace_279: Variant = getv(v_unpack_278, "terrace")
	var v_hall_280: Variant = getv(v_unpack_278, "hall")
	var v_stair_281: Variant = getv(v_unpack_278, "stair")
	var v_basin_282: Variant = getv(v_unpack_278, "basin")
	var v_queue_283: Variant = getv(v_unpack_278, "queue")
	var v_lamp_284: Variant = getv(v_unpack_278, "lamp")
	var v_cloth_285: Variant = getv(v_unpack_278, "cloth")
	var v_w_286: Variant = getv(v_unpack_278, "w")
	var v_C_287: Variant = getv(v_unpack_278, "C")
	var v_p_288: Variant = getv(v_unpack_278, "p")
	var v_r_289: Variant = getv(v_unpack_278, "r")
	var v_surf_290: Variant = getv(v_unpack_278, "surf")
	var v_top_291: Variant = getv(v_unpack_278, "top")
	var v_upperFire_292: Variant = invoke(v_lamp_284, [354.0, 386.0, 0.47, "#efba73", 131.0])
	var v_courtFire_293: Variant = invoke(v_lamp_284, [549.0, 651.0, 0.58, "#ffbc6f", 137.0])
	v_courtFire_293["marker"] = false
	v_upperFire_292["marker"] = getv(v_courtFire_293, "marker")
	invoke(v_surf_290, ["M122 715Q263 664 378 704Q460 733 499 779Q380 817 253 827Q147 801 122 715Z", [115.0, 655.0, 505.0, 834.0], merge_dicts([v_top_291, {"mat": "water", "field": null, "color": getv(v_w_286, "c1"), "shadow": getv(v_w_286, "c0"), "cx": (-900.0), "cy": 1600.0, "bump": 0.25, "emission": 0.0}])])
	invoke(v_terrace_279, ["M168 453L193 380L255 337L337 317L405 351L461 403L441 478L366 525L280 548L209 507Z", "M168 453L209 507L280 548L366 525L441 478L461 403L479 529L420 576L357 620L277 649L216 607L173 553Z", [162.0, 310.0, 485.0, 655.0]])
	invoke(v_terrace_279, ["M338 650L382 566L457 532L553 539L626 570L716 592L795 653L781 721L704 771L604 800L528 769L449 789L375 739Z", "M338 650L375 739L449 789L528 769L604 800L704 771L781 721L795 653L797 759L732 812L664 846L595 826L534 854L467 827L414 845L357 780Z", [332.0, 526.0, 803.0, 860.0]])
	invoke(v_hall_280, [245.0, 330.0, 162.0, add(182.0, (invoke(v_r_289, []) * 28.0)), {"roof": "broken", "windows": 3.0}])
	invoke(v_hall_280, [173.0, 436.0, 136.0, 95.0, {"roof": "tile", "windows": 3.0}])
	invoke(v_hall_280, [324.0, 445.0, 143.0, 113.0, {"roof": "broken"}])
	invoke(v_hall_280, [505.0, 606.0, 159.0, 86.0, {"roof": "tile", "windows": 3.0}])
	invoke(v_hall_280, [680.0, 670.0, 81.0, 63.0, {"roof": "broken", "windows": 2.0}])
	invoke(v_hall_280, [409.0, 666.0, 117.0, 77.0, {"roof": "tile", "windows": 2.0}])
	invoke(v_stair_281, [370.0, 495.0, (-7.0), 9.0, 11.0, 61.0])
	invoke(v_stair_281, [572.0, 614.0, (-9.0), 9.0, 9.0, 69.0])
	invoke(v_cloth_285, [278.0, 255.0, 27.0, 70.0, mix(getv(v_w_286, "c3"), getv(v_w_286, "star"), 0.28)])
	invoke(v_cloth_285, [526.0, 499.0, 31.0, 83.0, getv(v_C_287, "linen")])
	invoke(v_cloth_285, [688.0, 597.0, 18.0, 45.0, getv(v_C_287, "violet")])
	invoke(v_basin_282, [597.0, 746.0, 53.0, 27.0, {"color": getv(v_w_286, "c0"), "emission": 0.0}])
	invoke_member(v_k_277, "supplies", [527.0, 733.0, 6.0])
	var v_i_294: Variant = 0.0
	while truth((v_i_294 < 5.0)):
		var v_x_295: Variant = add(440.0, (v_i_294 * 17.0))
		var v_y_296: Variant = (715.0 - (v_i_294 * 4.0))
		invoke_member(v_p_288, "fill", [("M" + text_value(v_x_295) + " " + text_value(v_y_296) + "l12,-4l-1,16l-13,4Z"), getv(v_C_287, "linen")])
		invoke_member(v_p_288, "line", [("M" + text_value(add(v_x_295, 2.0)) + " " + text_value(add(v_y_296, 4.0)) + "l7,-2"), getv(v_w_286, "c1"), 1.0, 0.8])
		v_i_294 += 1
	invoke_member(v_k_277, "table", [536.0, 713.0, 60.0])
	invoke_member(v_k_277, "table", [620.0, 714.0, 51.0])
	invoke_member(v_k_277, "opening", [242.0, 607.0, 33.0, 61.0, (-6.0)])
	invoke_member(v_k_277, "opening", [447.0, 781.0, 31.0, 57.0, (-5.0)])
	invoke_member(v_k_277, "gallery", [609.0, 576.0, 133.0])
	for v_item_297 in [[247.0, 334.0, 166.0], [309.0, 349.0, 160.0], [400.0, 369.0, 147.0]]:
		var v_unpack_298: Variant = v_item_297
		var v_x_299: Variant = getv(v_unpack_298, 0)
		var v_y_300: Variant = getv(v_unpack_298, 1)
		var v_h_301: Variant = getv(v_unpack_298, 2)
		invoke(v_surf_290, [("M" + text_value((v_x_299 - 6.0)) + " " + text_value(v_y_300) + "l3," + text_value((-v_h_301)) + "l11,4l4," + text_value((v_h_301 - 19.0)) + "l9,23l-13,7Z"), [(v_x_299 - 11.0), ((v_y_300 - v_h_301) - 4.0), add(v_x_299, 26.0), add(v_y_300, 18.0)], merge_dicts([getv(v_k_277, "side"), {"mat": "masonry", "field": null, "color": getv(v_C_287, "salt"), "normal": [(-0.55), 0.05, 0.85]}])])
		invoke_member(v_p_288, "shadow", [("M" + text_value(add(v_x_299, 8.0)) + " " + text_value(add((v_y_300 - v_h_301), 9.0)) + "l6," + text_value((v_h_301 - 22.0)) + "l9,22l-10,7Z"), 0.4, 1.0])
	invoke_member(v_k_277, "gallery", [328.0, 380.0, 153.0])
	invoke_member(v_k_277, "brazier", [v_upperFire_292, 0.76])
	invoke_member(v_k_277, "brazier", [v_courtFire_293, 0.84])
	invoke_member(v_k_277, "opening", [333.0, 302.0, 31.0, 84.0, 4.0])
	invoke(v_surf_290, ["M321 305L333 293L348 309L335 316Z", [316.0, 288.0, 353.0, 320.0], merge_dicts([v_top_291, {"color": getv(v_C_287, "salt")}])])
	invoke_member(v_k_277, "bridge", [290.0, 587.0, 420.0, 650.0, 34.0])
	invoke_member(v_k_277, "actor", [359.0, 630.0, 0.8, "carry", false])
	for v_item_302 in [[546.0, 716.0], [631.0, 718.0], [468.0, 694.0]]:
		var v_unpack_303: Variant = v_item_302
		var v_x_304: Variant = getv(v_unpack_303, 0)
		var v_y_305: Variant = getv(v_unpack_303, 1)
		invoke_member(v_p_288, "fill", [("M" + text_value(v_x_304) + " " + text_value(v_y_305) + "l11,-4l12,5l-10,5Z"), "#c4b48a"])
		invoke_member(v_p_288, "line", [("M" + text_value(add(v_x_304, 11.0)) + " " + text_value((v_y_305 - 4.0)) + "l2,8"), getv(v_w_286, "c1"), 1.0])
		invoke_member(v_p_288, "line", [("M" + text_value(add(v_x_304, 3.0)) + " " + text_value(v_y_305) + "l6,-1m8,3l5,-1"), getv(v_w_286, "c1"), 0.7, 0.7])
	invoke(v_surf_290, ["M188 723L252 694L311 723L273 754L209 760Z", [182.0, 688.0, 317.0, 766.0], merge_dicts([v_top_291, {"mat": "wood", "field": worldField("wood", v_w_286), "color": "#817052"}])])
	var v_i_306: Variant = 0.0
	while truth((v_i_306 < 8.0)):
		invoke_member(v_p_288, "line", [("M" + text_value(add(199.0, (v_i_306 * 11.0))) + " " + text_value(add(724.0, (v_i_306 * 2.0))) + "l-5,28"), getv(v_w_286, "c0"), 1.5, 0.6])
		v_i_306 += 1
	invoke_member(v_p_288, "fill", ["M190 776Q233 751 272 776Q238 802 190 776Z", "#6c6247"])
	invoke_member(v_p_288, "fill", ["M199 776Q234 762 262 777Q237 791 199 776Z", getv(v_w_286, "c0")])
	invoke_member(v_p_288, "line", ["M238 777L260 737", getv(v_C_287, "copper"), 1.0])
	invoke_member(v_k_277, "supplies", [223.0, 722.0, 4.0])
	invoke_member(v_k_277, "cloth", [680.0, 621.0, 21.0, 51.0, getv(v_C_287, "violet")])
	for v_item_307 in [[287.0, 397.0, "carry", true], [218.0, 480.0, "torch", false], [324.0, 554.0, "carry", false], [473.0, 724.0, "work", true], [555.0, 744.0, "work", false], [646.0, 749.0, "work", true], [721.0, 723.0, "carry", false], [235.0, 744.0, "carry", true]]:
		var v_unpack_308: Variant = v_item_307
		var v_x_309: Variant = getv(v_unpack_308, 0)
		var v_y_310: Variant = getv(v_unpack_308, 1)
		var v_a_311: Variant = getv(v_unpack_308, 2)
		var v_l_312: Variant = getv(v_unpack_308, 3)
		invoke_member(v_k_277, "actor", [v_x_309, v_y_310, (1.03 if truth((v_y_310 > 650.0)) else 0.78), v_a_311, v_l_312])
static func chaos(v_k_313):
	var v_unpack_314: Variant = v_k_313
	var v_terrace_315: Variant = getv(v_unpack_314, "terrace")
	var v_surf_316: Variant = getv(v_unpack_314, "surf")
	var v_top_317: Variant = getv(v_unpack_314, "top")
	var v_side_318: Variant = getv(v_unpack_314, "side")
	var v_hall_319: Variant = getv(v_unpack_314, "hall")
	var v_stair_320: Variant = getv(v_unpack_314, "stair")
	var v_p_321: Variant = getv(v_unpack_314, "p")
	var v_C_322: Variant = getv(v_unpack_314, "C")
	var v_w_323: Variant = getv(v_unpack_314, "w")
	var v_fire_324: Variant = invoke_member(v_k_313, "lamp", [446.0, 581.0, 0.76, "#eebc7c", 153.0])
	var v_far_325: Variant = invoke_member(v_k_313, "lamp", [662.0, 348.0, 0.45, getv(v_w_323, "c4"), 105.0])
	v_far_325["marker"] = false
	v_fire_324["marker"] = getv(v_far_325, "marker")
	var v_island_326: Variant = func(v_a_327, v_b_328, v_c_329):
		return invoke(v_terrace_315, [v_a_327, v_b_328, v_c_329, {"material": "ridge", "color": mix(getv(v_w_323, "c2"), "#777567", 0.42)}])
	assign(v_top_317, {"field": worldField("ridge", v_w_323), "color": mix(getv(v_w_323, "c2"), "#777567", 0.42)})
	assign(v_side_318, {"field": worldField("ridge", v_w_323)})
	var v_flux_330: Variant = worldField("flux", v_w_323)
	var v_quietFlux_331: Variant = worldField("quiet_flux", v_w_323)
	invoke(v_surf_316, ["M112 544Q216 410 398 507Q500 571 607 434Q702 317 825 454L851 504Q734 420 641 540Q525 698 364 588Q220 495 136 606Z", [105.0, 310.0, 858.0, 705.0], merge_dicts([v_top_317, {"field": v_quietFlux_331, "color": getv(v_w_323, "c3")}])])
	invoke(v_island_326, ["M587 334L624 285L687 277L745 318L763 374L720 408L653 423L607 392Z", "M587 334L607 392L653 423L720 408L763 374L746 466L697 516L664 533L644 472L607 455Z", [581.0, 271.0, 769.0, 540.0]])
	invoke(v_hall_319, [622.0, 347.0, 88.0, 66.0, {"roof": "broken", "windows": 2.0}])
	invoke_member(v_k_313, "gallery", [667.0, 377.0, 89.0])
	invoke(v_island_326, ["M138 620L183 525L281 477L395 501L474 477L577 533L645 613L622 709L546 762L433 786L341 759L238 803L166 743Z", "M138 620L166 743L238 803L341 759L433 786L546 762L622 709L645 613L661 755L595 831L501 863L422 843L344 881L252 849L208 877L160 803Z", [131.0, 471.0, 667.0, 888.0]])
	invoke_member(v_p_321, "line", ["M391 611L399 251", getv(v_C_322, "copper"), 7.0])
	invoke(v_surf_316, ["M399 251Q317 327 212 481Q326 448 395 477Q487 437 581 532Q493 365 399 251Z", [206.0, 245.0, 587.0, 539.0], {"mat": "cloth", "field": null, "color": mix(getv(v_C_322, "linen"), "#9b9d85", 0.45), "shadow": getv(v_w_323, "c1"), "accent": getv(v_C_322, "salt"), "normal": [(-0.35), (-0.17), 1.0], "height": foldField([[[399.0, 257.0], [360.0, 346.0], [287.0, 427.0], [215.0, 480.0], 24.0, 18.0], [[400.0, 258.0], [445.0, 367.0], [507.0, 447.0], [579.0, 530.0], 24.0, 17.0]])}])
	invoke_member(v_p_321, "shadow", ["M212 488Q368 472 581 537L594 616Q426 590 253 571Z", 0.32, 10.0])
	for v_item_332 in [[212.0, 481.0], [581.0, 532.0]]:
		var v_unpack_333: Variant = v_item_332
		var v_x_334: Variant = getv(v_unpack_333, 0)
		var v_y_335: Variant = getv(v_unpack_333, 1)
		invoke_member(v_p_321, "line", [("M" + text_value(v_x_334) + " " + text_value(v_y_335) + "v104"), getv(v_C_322, "copper"), 5.0])
		invoke_member(v_p_321, "line", [("M399 251L" + text_value((v_x_334 - 28.0)) + " " + text_value(add(v_y_335, 128.0)) + ""), getv(v_C_322, "salt"), 1.5, 0.7])
	invoke(v_hall_319, [221.0, 598.0, 105.0, 65.0, {"roof": "tile", "windows": 2.0}])
	invoke_member(v_k_313, "gallery", [434.0, 628.0, 194.0])
	invoke(v_stair_320, [415.0, 655.0, (-7.0), 8.0, 10.0, 62.0])
	invoke_member(v_k_313, "bridge", [553.0, 563.0, 633.0, 410.0, 23.0])
	invoke_member(v_k_313, "table", [459.0, 702.0, 69.0])
	invoke_member(v_k_313, "supplies", [470.0, 704.0, 5.0])
	invoke_member(v_k_313, "table", [242.0, 686.0, 59.0])
	for v_item_336 in [[235.0, 756.0], [554.0, 734.0], [652.0, 417.0]]:
		var v_unpack_337: Variant = v_item_336
		var v_x_338: Variant = getv(v_unpack_337, 0)
		var v_y_339: Variant = getv(v_unpack_337, 1)
		invoke_member(v_p_321, "fill", [ellipse(v_x_338, v_y_339, 14.0, 7.0), getv(v_C_322, "copper")])
		invoke_member(v_p_321, "fill", [ellipse(v_x_338, v_y_339, 7.0, 3.0), getv(v_w_323, "c0")])
		invoke_member(v_p_321, "line", [("M" + text_value(v_x_338) + " " + text_value((v_y_339 - 10.0)) + "l22,8"), getv(v_C_322, "salt"), 3.0])
	var v_j_340: Variant = 0.0
	while truth((v_j_340 < 3.0)):
		invoke_member(v_p_321, "line", [("M" + text_value(add(235.0, (v_j_340 * 4.0))) + " 754Q138 772 " + text_value(add(108.0, (v_j_340 * 4.0))) + " 681"), getv(v_C_322, "copper"), 1.3, 0.7])
		v_j_340 += 1
	invoke_member(v_k_313, "cloth", [383.0, 295.0, 23.0, 62.0, getv(v_C_322, "violet")])
	invoke_member(v_k_313, "opening", [216.0, 789.0, 33.0, 54.0, (-4.0)])
	invoke_member(v_k_313, "brazier", [v_fire_324, 0.82])
	invoke_member(v_k_313, "brazier", [v_far_325, 0.6])
	for v_item_341 in [[653.0, 395.0, "torch", false], [606.0, 481.0, "carry", false], [359.0, 583.0, "bow", true], [473.0, 621.0, "carry", false], [274.0, 722.0, "work", true], [495.0, 747.0, "work", false], [545.0, 777.0, "work", true], [340.0, 784.0, "torch", false], [211.0, 824.0, "carry", true]]:
		var v_unpack_342: Variant = v_item_341
		var v_x_343: Variant = getv(v_unpack_342, 0)
		var v_y_344: Variant = getv(v_unpack_342, 1)
		var v_a_345: Variant = getv(v_unpack_342, 2)
		var v_l_346: Variant = getv(v_unpack_342, 3)
		invoke_member(v_k_313, "actor", [v_x_343, v_y_344, (1.08 if truth((v_y_344 > 650.0)) else 0.8), v_a_345, v_l_346])
static func cocoon(v_k_347):
	var v_unpack_348: Variant = v_k_347
	var v_terrace_349: Variant = getv(v_unpack_348, "terrace")
	var v_bridge_350: Variant = getv(v_unpack_348, "bridge")
	var v_queue_351: Variant = getv(v_unpack_348, "queue")
	var v_lamp_352: Variant = getv(v_unpack_348, "lamp")
	var v_w_353: Variant = getv(v_unpack_348, "w")
	var v_C_354: Variant = getv(v_unpack_348, "C")
	var v_p_355: Variant = getv(v_unpack_348, "p")
	var v_r_356: Variant = getv(v_unpack_348, "r")
	var v_surf_357: Variant = getv(v_unpack_348, "surf")
	var v_side_358: Variant = getv(v_unpack_348, "side")
	var v_centralFire_359: Variant = invoke(v_lamp_352, [457.0, 601.0, 0.78, "#f4b572", 160.0])
	var v_sideFire_360: Variant = invoke(v_lamp_352, [712.0, 495.0, 0.48, getv(v_w_353, "c4"), 121.0])
	v_sideFire_360["marker"] = false
	v_centralFire_359["marker"] = getv(v_sideFire_360, "marker")
	invoke(v_lamp_352, [217.0, 653.0, 0.26, getv(v_w_353, "c4"), 83.0])
	invoke(v_terrace_349, ["M637 487L667 451L722 430L775 459L812 506L774 546L707 564L662 537Z", "M637 487L662 537L707 564L774 546L812 506L791 590L751 641L718 664L690 611L656 585Z", [632.0, 425.0, 818.0, 671.0]])
	pod(v_k_347, 719.0, 493.0, 54.0, 157.0, "shell")
	invoke_member(v_k_347, "gallery", [718.0, 515.0, 100.0])
	invoke(v_terrace_349, ["M148 620L182 583L244 575L294 614L277 659L224 685L175 667Z", "M148 620L175 667L224 685L277 659L294 614L282 712L240 763L212 784L186 729L160 713Z", [142.0, 570.0, 299.0, 792.0]])
	pod(v_k_347, 214.0, 630.0, 39.0, 112.0, "shell")
	invoke_member(v_k_347, "gallery", [215.0, 650.0, 83.0])
	invoke(v_terrace_349, ["M310 644Q334 565 418 537L510 541L580 572L644 642L652 708L601 767L530 805L452 786L379 808L334 755Z", "M310 644L334 755L379 808L452 786L530 805L601 767L652 708L651 782L593 843L532 870L477 842L424 867L368 843L332 799Z", [304.0, 531.0, 659.0, 878.0]])
	invoke(v_bridge_350, [570.0, 665.0, 685.0, 539.0, 28.0])
	invoke(v_bridge_350, [267.0, 646.0, 364.0, 715.0, 27.0])
	pod(v_k_347, 464.0, 632.0, 130.0, add(432.0, (invoke(v_r_356, []) * 28.0)), "shell")
	for v_item_361 in [[334.0, (-1.0)], [588.0, 1.0]]:
		var v_unpack_362: Variant = v_item_361
		var v_x_363: Variant = getv(v_unpack_362, 0)
		var v_dir_364: Variant = getv(v_unpack_362, 1)
		invoke(v_surf_357, [("M" + text_value(v_x_363) + " 716Q" + text_value((v_x_363 - (v_dir_364 * 28.0))) + " 464 " + text_value(add(464.0, (v_dir_364 * 31.0))) + " 195Q" + text_value(add(464.0, (v_dir_364 * 86.0))) + " 353 " + text_value(add(v_x_363, (v_dir_364 * 24.0))) + " 520L" + text_value(add(v_x_363, (v_dir_364 * 20.0))) + " 727Z"), [[(v_x_363 - 50.0), 420.0].min(), 189.0, [add(v_x_363, 50.0), 517.0].max(), 734.0], merge_dicts([v_side_358, {"field": worldField("shell", v_w_353), "color": getv(v_C_354, "salt"), "normal": [(-0.3), 0.02, 1.0]}])])
	invoke_member(v_k_347, "gallery", [465.0, 650.0, 182.0])
	invoke_member(v_k_347, "stair", [464.0, 673.0, (-5.0), 9.0, 10.0, 65.0])
	var v_i_365: Variant = 0.0
	while truth((v_i_365 < 7.0)):
		var v_y_366: Variant = add(316.0, (v_i_365 * 23.0))
		invoke_member(v_p_355, "line", [("M501 " + text_value(v_y_366) + "Q594 " + text_value(add(v_y_366, 70.0)) + " " + text_value(add(702.0, (v_i_365 * 7.0))) + " 492"), getv(v_C_354, "copper"), 1.0, 0.48])
		invoke_member(v_p_355, "line", [("M426 " + text_value(add(v_y_366, 45.0)) + "Q312 " + text_value(add(v_y_366, 167.0)) + " " + text_value(add(190.0, (v_i_365 * 8.0))) + " 619"), getv(v_C_354, "salt"), 1.0, 0.28])
		v_i_365 += 1
	invoke_member(v_k_347, "cloth", [413.0, 547.0, 27.0, 65.0, getv(v_C_354, "violet")])
	invoke_member(v_k_347, "table", [523.0, 737.0, 50.0])
	invoke_member(v_k_347, "supplies", [551.0, 756.0, 4.0])
	invoke_member(v_k_347, "opening", [464.0, 628.0, 83.0, 183.0, 9.0])
	invoke(v_surf_357, ["M427 627L461 596L503 634L469 650Z", [422.0, 591.0, 509.0, 656.0], merge_dicts([getv(v_k_347, "top"), {"field": worldField("silk", v_w_353), "color": getv(v_C_354, "salt"), "exposure": 0.8}])])
	invoke(v_surf_357, ["M490 468Q511 535 504 633L490 624Q498 538 482 483Z", [477.0, 464.0, 515.0, 638.0], merge_dicts([v_side_358, {"field": worldField("shell", v_w_353), "normal": [0.65, 0.1, 0.74], "exposure": 0.52}])])
	invoke_member(v_k_347, "cloth", [439.0, 488.0, 23.0, 69.0, mix(getv(v_C_354, "violet"), getv(v_w_353, "c1"), 0.35)])
	invoke_member(v_k_347, "table", [443.0, 609.0, 37.0])
	invoke_member(v_k_347, "brazier", [v_centralFire_359, 0.72])
	invoke_member(v_k_347, "brazier", [v_sideFire_360, 0.64])
	for v_item_367 in [[410.0, 413.0], [513.0, 449.0], [395.0, 509.0], [535.0, 536.0]]:
		var v_unpack_368: Variant = v_item_367
		var v_x_369: Variant = getv(v_unpack_368, 0)
		var v_y_370: Variant = getv(v_unpack_368, 1)
		invoke_member(v_k_347, "opening", [v_x_369, v_y_370, 17.0, 35.0])
		invoke_member(v_p_355, "stroke", [("M" + text_value((v_x_369 - 11.0)) + " " + text_value(add(v_y_370, 3.0)) + "q13,8 26,1"), getv(v_C_354, "salt"), 2.0, 0.6])
	invoke_member(v_k_347, "gallery", [461.0, 458.0, 117.0])
	invoke_member(v_p_355, "line", ["M411 465l-6,42M514 465l8,44", getv(v_C_354, "copper"), 2.5, 0.7])
	var v_i_371: Variant = 0.0
	while truth((v_i_371 < 9.0)):
		var v_x_372: Variant = add(480.0, (v_i_371 * 8.0))
		var v_y_373: Variant = add(707.0, (v_i_371 * 3.0))
		invoke_member(v_p_355, "line", [("M" + text_value(v_x_372) + " " + text_value(v_y_373) + "l-4,22"), getv(v_C_354, "copper"), 2.0])
		invoke_member(v_p_355, "line", [("M" + text_value((v_x_372 - 5.0)) + " " + text_value(add(v_y_373, 3.0)) + "l12,3"), getv(v_C_354, "salt"), 1.3, 0.5])
		v_i_371 += 1
	invoke_member(v_p_355, "line", ["M538 722L577 733L575 774L538 763Z", getv(v_C_354, "copper"), 3.0])
	var v_i_374: Variant = 0.0
	while truth((v_i_374 < 6.0)):
		invoke_member(v_p_355, "line", [("M" + text_value(add(542.0, (v_i_374 * 6.0))) + " " + text_value(add(727.0, (v_i_374 * 2.0))) + "l-1,31"), getv(v_C_354, "salt"), 0.8, 0.65])
		v_i_374 += 1
	for v_item_375 in [[525.0, 749.0], [538.0, 751.0], [553.0, 753.0]]:
		var v_unpack_376: Variant = v_item_375
		var v_x_377: Variant = getv(v_unpack_376, 0)
		var v_y_378: Variant = getv(v_unpack_376, 1)
		invoke_member(v_p_355, "fill", [ellipse(v_x_377, v_y_378, 4.0, 7.0), getv(v_C_354, "linen")])
		invoke_member(v_p_355, "line", [("M" + text_value((v_x_377 - 4.0)) + " " + text_value((v_y_378 - 6.0)) + "h8m-8,12h8"), getv(v_C_354, "copper"), 1.2])
	invoke_member(v_k_347, "opening", [411.0, 806.0, 32.0, 52.0, (-4.0)])
	invoke_member(v_k_347, "cloth", [357.0, 643.0, 23.0, 57.0, getv(v_C_354, "violet")])
	for v_item_379 in [[208.0, 665.0, "carry", false], [700.0, 538.0, "torch", true], [465.0, 650.0, "bow", true], [403.0, 704.0, "carry", false], [417.0, 766.0, "kneel", false], [555.0, 789.0, "work", true], [590.0, 747.0, "carry", false], [375.0, 790.0, "torch", false]]:
		var v_unpack_380: Variant = v_item_379
		var v_x_381: Variant = getv(v_unpack_380, 0)
		var v_y_382: Variant = getv(v_unpack_380, 1)
		var v_a_383: Variant = getv(v_unpack_380, 2)
		var v_l_384: Variant = getv(v_unpack_380, 3)
		invoke_member(v_k_347, "actor", [v_x_381, v_y_382, (1.08 if truth((v_y_382 > 700.0)) else 0.78), v_a_383, v_l_384])
static func bone(v_k_385):
	var v_unpack_386: Variant = v_k_385
	var v_terrace_387: Variant = getv(v_unpack_386, "terrace")
	var v_basin_388: Variant = getv(v_unpack_386, "basin")
	var v_hall_389: Variant = getv(v_unpack_386, "hall")
	var v_stair_390: Variant = getv(v_unpack_386, "stair")
	var v_lamp_391: Variant = getv(v_unpack_386, "lamp")
	var v_queue_392: Variant = getv(v_unpack_386, "queue")
	var v_w_393: Variant = getv(v_unpack_386, "w")
	var v_C_394: Variant = getv(v_unpack_386, "C")
	var v_p_395: Variant = getv(v_unpack_386, "p")
	var v_surf_396: Variant = getv(v_unpack_386, "surf")
	var v_side_397: Variant = getv(v_unpack_386, "side")
	var v_archiveFire_398: Variant = invoke(v_lamp_391, [333.0, 439.0, 0.78, "#f3ba78", 143.0])
	var v_courtFire_399: Variant = invoke(v_lamp_391, [561.0, 675.0, 0.7, "#d2bd95", 157.0])
	v_courtFire_399["marker"] = false
	v_archiveFire_398["marker"] = getv(v_courtFire_399, "marker")
	invoke(v_terrace_387, ["M140 520Q149 390 263 356Q373 326 483 376L548 403Q660 377 751 461L810 574L788 696Q746 784 630 807L510 790Q399 817 292 754L192 674Z", "M140 520L192 674L292 754Q399 817 510 790L630 807Q746 784 788 696L810 574L826 718L778 796L705 852L626 879L552 851L490 879L417 849L349 866L285 823L223 785L180 708L148 649Z", [134.0, 320.0, 833.0, 886.0]])
	invoke(v_surf_396, ["M203 487L260 452L348 477L420 507L461 557L421 598L363 570L313 606L249 572L192 538Z", [187.0, 447.0, 467.0, 612.0], merge_dicts([getv(v_k_385, "top"), {"mat": "masonry", "field": null, "color": mix(getv(v_w_393, "c3"), getv(v_w_393, "c1"), 0.36), "exposure": 0.75}])])
	invoke(v_surf_396, ["M265 620L326 584L406 611L444 655L480 726L563 751L651 711L713 657L763 675L744 740L657 787L558 807L465 778L377 797L298 747Z", [259.0, 578.0, 769.0, 813.0], merge_dicts([getv(v_k_385, "top"), {"mat": "masonry", "field": null, "color": mix(getv(v_w_393, "c3"), getv(v_w_393, "c1"), 0.4), "exposure": 0.75}])])
	invoke(v_hall_389, [220.0, 430.0, 184.0, 129.0, {"roof": "broken"}])
	invoke(v_hall_389, [591.0, 481.0, 134.0, 83.0, {"roof": "broken", "windows": 2.0}])
	invoke(v_basin_388, [543.0, 647.0, 171.0, 88.0, {"liquid": "ivory", "color": getv(v_w_393, "c1"), "emission": 0.0}])
	invoke(v_stair_390, [382.0, 497.0, 9.0, 9.0, 12.0, 63.0])
	invoke(v_stair_390, [502.0, 584.0, 4.0, 7.0, 9.0, 40.0, {"color": getv(v_C_394, "salt")}])
	for v_item_400 in [[406.0, 595.0, 116.0], [505.0, 552.0, 133.0], [612.0, 558.0, 119.0], [695.0, 624.0, 135.0]]:
		var v_unpack_401: Variant = v_item_400
		var v_x_402: Variant = getv(v_unpack_401, 0)
		var v_y_403: Variant = getv(v_unpack_401, 1)
		var v_h_404: Variant = getv(v_unpack_401, 2)
		invoke(v_surf_396, [("M" + text_value((v_x_402 - 11.0)) + " " + text_value(v_y_403) + "Q" + text_value((v_x_402 - 16.0)) + " " + text_value((v_y_403 - (v_h_404 * 0.6))) + " " + text_value(add(v_x_402, 38.0)) + " " + text_value((v_y_403 - v_h_404)) + "Q" + text_value(add(v_x_402, 84.0)) + " " + text_value((v_y_403 - (v_h_404 * 0.67))) + " " + text_value(add(v_x_402, 81.0)) + " " + text_value(add(v_y_403, 7.0)) + "L" + text_value(add(v_x_402, 68.0)) + " " + text_value(add(v_y_403, 5.0)) + "Q" + text_value(add(v_x_402, 74.0)) + " " + text_value((v_y_403 - (v_h_404 * 0.58))) + " " + text_value(add(v_x_402, 39.0)) + " " + text_value(add((v_y_403 - v_h_404), 18.0)) + "Q" + text_value((v_x_402 - 3.0)) + " " + text_value((v_y_403 - (v_h_404 * 0.45))) + " " + text_value(add(v_x_402, 1.0)) + " " + text_value(v_y_403) + "Z"), [(v_x_402 - 22.0), ((v_y_403 - v_h_404) - 5.0), add(v_x_402, 89.0), add(v_y_403, 13.0)], merge_dicts([v_side_397, {"field": worldField("ivory", v_w_393), "color": mix(getv(v_w_393, "c3"), getv(v_w_393, "star"), 0.16), "height": make_field("return (sin((y*0.04))*2.0);", [])}])])
	var v_i_405: Variant = 0.0
	while truth((v_i_405 < 8.0)):
		var v_x_406: Variant = add(193.0, (v_i_405 * 22.0))
		var v_y_407: Variant = add(548.0, (v_i_405 * 12.0))
		invoke(v_surf_396, [("M" + text_value((v_x_406 - 6.0)) + " " + text_value(v_y_407) + "l2,-31q6,-9 11,-1l2,35Z"), [(v_x_406 - 10.0), (v_y_407 - 40.0), add(v_x_406, 13.0), add(v_y_407, 9.0)], merge_dicts([v_side_397, {"color": getv(v_C_394, "salt")}])])
		invoke_member(v_p_395, "line", [("M" + text_value(v_x_406) + " " + text_value((v_y_407 - 24.0)) + "v12"), getv(v_w_393, "c1"), 1.3, 0.7])
		v_i_405 += 1
	invoke_member(v_k_385, "opening", [351.0, 774.0, 42.0, 73.0, (-7.0)])
	invoke_member(v_k_385, "opening", [440.0, 811.0, 36.0, 65.0, (-5.0)])
	invoke_member(v_k_385, "opening", [681.0, 789.0, 38.0, 64.0, (-6.0)])
	invoke_member(v_k_385, "table", [300.0, 658.0, 63.0])
	invoke_member(v_k_385, "table", [560.0, 760.0, 59.0])
	invoke_member(v_k_385, "supplies", [612.0, 747.0, 4.0])
	invoke_member(v_k_385, "cloth", [269.0, 363.0, 25.0, 57.0, getv(v_C_394, "violet")])
	invoke_member(v_k_385, "opening", [306.0, 445.0, 57.0, 109.0, 9.0])
	invoke(v_surf_396, ["M281 445L306 426L335 452L310 464Z", [276.0, 421.0, 341.0, 470.0], merge_dicts([getv(v_k_385, "top"), {"mat": "masonry", "field": null, "color": getv(v_C_394, "salt")}])])
	invoke_member(v_k_385, "brazier", [v_archiveFire_398, 0.78])
	invoke_member(v_k_385, "brazier", [v_courtFire_399, 0.8])
	for v_item_408 in [[406.0, 595.0, 116.0], [505.0, 552.0, 133.0], [612.0, 558.0, 119.0], [695.0, 624.0, 135.0]]:
		var v_unpack_409: Variant = v_item_408
		var v_x_410: Variant = getv(v_unpack_409, 0)
		var v_y_411: Variant = getv(v_unpack_409, 1)
		var v_h_412: Variant = getv(v_unpack_409, 2)
		invoke_member(v_p_395, "shadow", [("M" + text_value(add(v_x_410, 69.0)) + " " + text_value(add(v_y_411, 4.0)) + "Q" + text_value(add(v_x_410, 76.0)) + " " + text_value((v_y_411 - (v_h_412 * 0.6))) + " " + text_value(add(v_x_410, 39.0)) + " " + text_value(add((v_y_411 - v_h_412), 16.0)) + "Q" + text_value(add(v_x_410, 87.0)) + " " + text_value((v_y_411 - (v_h_412 * 0.65))) + " " + text_value(add(v_x_410, 82.0)) + " " + text_value(add(v_y_411, 8.0)) + "Z"), 0.35, 1.0])
		invoke_member(v_p_395, "stroke", [("M" + text_value((v_x_410 - 5.0)) + " " + text_value((v_y_411 - 3.0)) + "Q" + text_value((v_x_410 - 6.0)) + " " + text_value((v_y_411 - (v_h_412 * 0.5))) + " " + text_value(add(v_x_410, 36.0)) + " " + text_value(add((v_y_411 - v_h_412), 6.0)) + ""), getv(v_C_394, "salt"), 2.0, 0.6])
	invoke_member(v_k_385, "stair", [591.0, 605.0, (-6.0), 6.0, 9.0, 47.0])
	invoke(v_surf_396, ["M501 670L538 651L584 674L545 698Z", [495.0, 645.0, 590.0, 704.0], merge_dicts([getv(v_k_385, "top"), {"field": worldField("ivory", v_w_393), "color": getv(v_C_394, "salt")}])])
	invoke(v_surf_396, ["M501 670L545 698L584 674L584 694L546 717L501 691Z", [495.0, 665.0, 590.0, 722.0], merge_dicts([v_side_397, {"mat": "masonry", "field": null, "color": getv(v_w_393, "c2"), "normal": [0.3, 0.2, 0.92]}])])
	var v_i_413: Variant = 0.0
	while truth((v_i_413 < 5.0)):
		var v_x_414: Variant = add(516.0, (v_i_413 * 10.0))
		var v_y_415: Variant = add(670.0, (v_i_413 * 3.0))
		invoke_member(v_p_395, "line", [("M" + text_value(v_x_414) + " " + text_value(v_y_415) + "l11,-5"), getv(v_C_394, "salt"), 3.0])
		invoke_member(v_p_395, "fill", [ellipse(v_x_414, v_y_415, 3.0, 2.0), getv(v_w_393, "c1"), 0.4])
		v_i_413 += 1
	for v_item_416 in [[316.0, 662.0], [575.0, 763.0]]:
		var v_unpack_417: Variant = v_item_416
		var v_x_418: Variant = getv(v_unpack_417, 0)
		var v_y_419: Variant = getv(v_unpack_417, 1)
		invoke_member(v_p_395, "fill", [("M" + text_value(v_x_418) + " " + text_value(v_y_419) + "l13,-5l15,5l-12,7Z"), "#b7a481"])
		invoke_member(v_p_395, "line", [("M" + text_value(add(v_x_418, 3.0)) + " " + text_value(v_y_419) + "l13,2"), getv(v_w_393, "c1"), 1.0])
	invoke_member(v_k_385, "cloth", [618.0, 430.0, 19.0, 41.0, getv(v_C_394, "violet")])
	invoke_member(v_k_385, "supplies", [260.0, 705.0, 4.0])
	for v_item_420 in [[268.0, 481.0, "torch", false], [327.0, 516.0, "carry", true], [393.0, 565.0, "bow", false], [317.0, 688.0, "work", true], [505.0, 726.0, "kneel", false], [589.0, 728.0, "bow", true], [574.0, 790.0, "work", true], [711.0, 718.0, "carry", false], [378.0, 806.0, "torch", false]]:
		var v_unpack_421: Variant = v_item_420
		var v_x_422: Variant = getv(v_unpack_421, 0)
		var v_y_423: Variant = getv(v_unpack_421, 1)
		var v_a_424: Variant = getv(v_unpack_421, 2)
		var v_l_425: Variant = getv(v_unpack_421, 3)
		invoke_member(v_k_385, "actor", [v_x_422, v_y_423, (1.06 if truth((v_y_423 > 650.0)) else 0.8), v_a_424, v_l_425])
static var SCENES = {"watcher": watcher, "flesh": flesh, "fungal": fungal, "fire": fire, "frozen": frozen, "colour": colour, "archive": archive, "chaos": chaos, "cocoon": cocoon, "bone": bone}
static func newCult(v_w_426, v_rule_427):
	var v_scene_428: Variant = getv(SCENES, getv(v_rule_427, "layout"))
	if truth((not truth(v_scene_428))):
		assert(false, str(add("未实现的教团组织 ", getv(v_rule_427, "layout"))))
	var v_k_429: Variant = M_cult_kit.cultKit(v_w_426, v_rule_427)
	invoke(v_scene_428, [v_k_429])
	return invoke_member(v_k_429, "finish", [{"compositionRevision": (3.0 if truth((getv(v_rule_427, "layout") in ["fungal", "fire", "frozen"])) else 2.0)}])
