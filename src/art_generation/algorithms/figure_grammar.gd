extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: figure-grammar.js; preserve contours, ordering and seed decisions.

static var GESTURES = ["offering", "appeal", "prayer", "staff", "folded", "cradle"]
static var GESTURE_NAMES = {"entreat": "伸掌求援", "bargain": "摊掌陈情", "offering": "双手奉潮", "appeal": "抚胸伸掌", "prayer": "合掌求援", "staff": "持杖求告", "folded": "拢臂守望", "cradle": "抱持潮录", "injured": "护住伤手", "guarded": "收臂戒备"}
static var GARMENTS = ["crosswrap", "mantle", "tabard", "coat"]
static var GARMENT_NAMES = {"crosswrap": "交襟束腰衣", "mantle": "宽披肩长袍", "tabard": "垂带祭衣", "coat": "敞襟长衣"}
static func hand(v_p_1, v_w_2, v_angle_3, v_scale_4, v_kind_5, v_C_6):
	var v_c_7: Variant = cos(v_angle_3)
	var v_s_8: Variant = sin(v_angle_3)
	var v_to_9: Variant = func(v_x_10, v_y_11):
		return [add(getv(v_w_2, 0.0), (v_scale_4 * ((v_x_10 * v_c_7) - (v_y_11 * v_s_8)))), add(getv(v_w_2, 1.0), (v_scale_4 * add((v_x_10 * v_s_8), (v_y_11 * v_c_7))))]
	var v_local_12: Variant = func(v_x_13, v_y_14):
		return [(add(((v_x_13 - getv(v_w_2, 0.0)) * v_c_7), ((v_y_14 - getv(v_w_2, 1.0)) * v_s_8)) / v_scale_4), (add(((-(v_x_13 - getv(v_w_2, 0.0))) * v_s_8), ((v_y_14 - getv(v_w_2, 1.0)) * v_c_7)) / v_scale_4)]
	var v_contour_15: Variant = ("M-12 7 Q-19 -2 -16 -17 L-25 -29 Q-28 -36 -22 -35 L-10 -25 L-8 -45 Q-7 -51 -3 -49 L2 -29 L3 -51 Q6 -57 10 -51 L12 -28 L17 -47 Q21 -51 24 -46 L22 -24 L28 -40 Q33 -43 34 -37 L29 -10 Q26 8 13 12Z" if truth((v_kind_5 == "palm")) else ("M-12 6 Q-15 -6 -10 -22 L0 -53 Q3 -58 6 -54 L7 -28 L12 -49 Q15 -52 18 -48 L16 -23 L21 -41 Q25 -44 27 -39 L23 -16 Q28 -19 31 -15 Q33 -10 25 -2 L12 9Z" if truth((v_kind_5 == "prayer")) else ("M-13 7 Q-21 -4 -17 -16 Q-11 -23 4 -23 L21 -20 Q28 -17 25 -11 Q31 -7 25 -2 Q29 3 22 7 L6 10 Q-2 17 -10 10Z" if truth((v_kind_5 == "fist")) else "M-13 5 Q-14 -5 -8 -17 L5 -37 Q8 -41 12 -37 L8 -23 L19 -36 Q23 -39 26 -35 L17 -19 L29 -29 Q33 -32 35 -28 L24 -13 L33 -21 Q38 -23 38 -18 L26 -2 Q16 11 4 10Z")))
	var v_corners_16: Variant = [invoke(v_to_9, [(-32.0), (-62.0)]), invoke(v_to_9, [45.0, (-62.0)]), invoke(v_to_9, [45.0, 22.0]), invoke(v_to_9, [(-32.0), 22.0])]
	var v_box_21: Variant = [map_values(v_corners_16, func(v_v_17):
		return getv(v_v_17, 0.0)).min(), map_values(v_corners_16, func(v_v_18):
		return getv(v_v_18, 1.0)).min(), map_values(v_corners_16, func(v_v_19):
		return getv(v_v_19, 0.0)).max(), map_values(v_corners_16, func(v_v_20):
		return getv(v_v_20, 1.0)).max()]
	invoke_member(v_p_1, "surface", [mapPath(v_contour_15, v_to_9), v_box_21, {"mat": "skin", "color": mix(getv(v_C_6, "copper"), "#b99b7e", 0.68), "shadow": "#5b5145", "accent": "#cdb58d", "bump": 0.35, "exposure": 0.76, "normal": [(-0.15), (-0.08), 1.0], "height": make_field("vec2 local2=vec2(((((x-@0@)*@1@)+((y-@2@)*@3@))/@4@),((((-(x-@5@))*@6@)+((y-@7@)*@8@))/@9@));return (3.0*exp((-(((local2[0]*local2[0])/380.0)+(pow((local2[1]+8.0),2.0)/530.0)))));", [getv(v_w_2, 0.0), v_c_7, getv(v_w_2, 1.0), v_s_8, v_scale_4, getv(v_w_2, 0.0), v_s_8, getv(v_w_2, 1.0), v_c_7, v_scale_4])}])
	for v_item_22 in (["M-7 -13 Q8 -9 23 -12", "M-7 -6 Q6 -3 23 -4", "M-6 1 Q6 5 20 4"] if truth((v_kind_5 == "fist")) else ["M-5 -13 Q4 -6 14 -10", "M7 -24 L13 -16", "M17 -17 L22 -12"]):
		var v_line_23: Variant = v_item_22
		invoke_member(v_p_1, "line", [mapPath(v_line_23, v_to_9), "#645848", 0.9, 0.55])
	invoke_member(v_p_1, "stroke", [mapPath("M-8 -6 Q-5 2 5 4", v_to_9), "#cdbd98", 1.2, 0.55])
static func sleeve(v_p_24, v_S_25, v_E_26, v_W_27, v_side_28, v_volume_29, v_C_30, v_material_31, v_civilian_32 = null, v_rolled_33 = null):
	if v_civilian_32 == null:
		v_civilian_32 = false
	if v_rolled_33 == null:
		v_rolled_33 = false
	if truth(v_rolled_33):
		var v_dx_34: Variant = (getv(v_W_27, 0.0) - getv(v_E_26, 0.0))
		var v_dy_35: Variant = (getv(v_W_27, 1.0) - getv(v_E_26, 1.0))
		var v_l_36: Variant = hypot([v_dx_34, v_dy_35])
		var v_nx_37: Variant = (((-v_dy_35) / v_l_36) * 16.0)
		var v_ny_38: Variant = ((v_dx_34 / v_l_36) * 16.0)
		var v_mid_39: Variant = [add(getv(v_E_26, 0.0), (v_dx_34 * 0.42)), add(getv(v_E_26, 1.0), (v_dy_35 * 0.42))]
		invoke_member(v_p_24, "surface", [("M" + text_value(add(getv(v_mid_39, 0.0), (v_nx_37 * 1.2))) + " " + text_value(add(getv(v_mid_39, 1.0), (v_ny_38 * 1.2))) + " C" + text_value(add(add(getv(v_mid_39, 0.0), (v_dx_34 * 0.23)), (v_nx_37 * 1.3))) + " " + text_value(add(add(getv(v_mid_39, 1.0), (v_dy_35 * 0.23)), (v_ny_38 * 1.3))) + " " + text_value(add((getv(v_W_27, 0.0) - (v_dx_34 * 0.16)), (v_nx_37 * 0.85))) + " " + text_value(add((getv(v_W_27, 1.0) - (v_dy_35 * 0.16)), (v_ny_38 * 0.85))) + " " + text_value(add(getv(v_W_27, 0.0), (v_nx_37 * 0.85))) + " " + text_value(add(getv(v_W_27, 1.0), (v_ny_38 * 0.85))) + " Q" + text_value(add(getv(v_W_27, 0.0), (v_dx_34 * 0.04))) + " " + text_value(add(getv(v_W_27, 1.0), (v_dy_35 * 0.04))) + " " + text_value((getv(v_W_27, 0.0) - (v_nx_37 * 0.85))) + " " + text_value((getv(v_W_27, 1.0) - (v_ny_38 * 0.85))) + " C" + text_value(((getv(v_W_27, 0.0) - (v_dx_34 * 0.18)) - (v_nx_37 * 0.8))) + " " + text_value(((getv(v_W_27, 1.0) - (v_dy_35 * 0.18)) - (v_ny_38 * 0.8))) + " " + text_value((add(getv(v_mid_39, 0.0), (v_dx_34 * 0.24)) - (v_nx_37 * 1.3))) + " " + text_value((add(getv(v_mid_39, 1.0), (v_dy_35 * 0.24)) - (v_ny_38 * 1.3))) + " " + text_value((getv(v_mid_39, 0.0) - (v_nx_37 * 1.1))) + " " + text_value((getv(v_mid_39, 1.0) - (v_ny_38 * 1.1))) + "Z"), [([getv(v_mid_39, 0.0), getv(v_W_27, 0.0)].min() - 29.0), ([getv(v_mid_39, 1.0), getv(v_W_27, 1.0)].min() - 29.0), add([getv(v_mid_39, 0.0), getv(v_W_27, 0.0)].max(), 29.0), add([getv(v_mid_39, 1.0), getv(v_W_27, 1.0)].max(), 29.0)], {"mat": "skin", "color": mix(getv(v_C_30, "copper"), "#b99b7e", 0.68), "shadow": "#5b5145", "normal": [(v_side_28 * 0.28), (-0.18), 1.0], "height": make_field("float local2=((((x-@0@)*@1@)-((y-@2@)*@3@))/@4@);float local3=((((x-@5@)*@6@)+((y-@7@)*@8@))/@9@);return ((7.0*exp((-pow((local2/21.0),2.0))))*(1.0-((local3/@10@)*0.2)));", [getv(v_mid_39, 0.0), v_dy_35, getv(v_mid_39, 1.0), v_dx_34, v_l_36, getv(v_mid_39, 0.0), v_dx_34, getv(v_mid_39, 1.0), v_dy_35, v_l_36, v_l_36]), "exposure": 0.76}])
		v_W_27 = v_mid_39
	var v_dx_40: Variant = (getv(v_W_27, 0.0) - getv(v_E_26, 0.0))
	var v_dy_41: Variant = (getv(v_W_27, 1.0) - getv(v_E_26, 1.0))
	var v_len_42: Variant = hypot([v_dx_40, v_dy_41])
	var v_n_43: Variant = [((-v_dy_41) / v_len_42), (v_dx_40 / v_len_42)]
	if truth((getv(v_n_43, 1.0) < 0.0)):
		v_n_43 = map_values(v_n_43, func(v_v_44):
			return (-v_v_44))
	var v_cuff_45: Variant = add(18.0, (v_volume_29 * 0.075))
	var v_A_46: Variant = (([372.0, 346.0] if truth((v_side_28 < 0.0)) else [491.0, 345.0]) if truth(v_civilian_32) else [(getv(v_S_25, 0.0) - (v_side_28 * 35.0)), (getv(v_S_25, 1.0) - 30.0)])
	var v_B_47: Variant = [(getv(v_S_25, 0.0) - (v_side_28 * 45.0)), add(getv(v_S_25, 1.0), 84.0)]
	var v_O_48: Variant = [add(getv(v_W_27, 0.0), (getv(v_n_43, 0.0) * v_cuff_45)), add(getv(v_W_27, 1.0), (getv(v_n_43, 1.0) * v_cuff_45))]
	var v_I_49: Variant = [(getv(v_W_27, 0.0) - (getv(v_n_43, 0.0) * v_cuff_45)), (getv(v_W_27, 1.0) - (getv(v_n_43, 1.0) * v_cuff_45))]
	var v_drop_50: Variant = add(32.0, (v_volume_29 * 0.55))
	var v_inward_51: Variant = ((v_dx_40 * v_side_28) < 0.0)
	var v_dropX_52: Variant = add(getv(v_E_26, 0.0), (v_side_28 * ((-12.0) if truth(v_inward_51) else 27.0)))
	var v_bendX_53: Variant = add(getv(v_E_26, 0.0), (v_side_28 * ((-43.0) if truth(v_inward_51) else 55.0)))
	var v_d_54: Variant = ("M" + text_value(v_A_46) + " C" + text_value(add(getv(v_S_25, 0.0), (v_side_28 * 40.0))) + " " + text_value(add(getv(v_S_25, 1.0), 5.0)) + " " + text_value(add(getv(v_E_26, 0.0), (v_side_28 * 44.0))) + " " + text_value((getv(v_E_26, 1.0) - 35.0)) + " " + text_value(add(getv(v_E_26, 0.0), (v_side_28 * 40.0))) + " " + text_value(add(getv(v_E_26, 1.0), 8.0)) + " Q" + text_value(add(getv(v_E_26, 0.0), (v_side_28 * 35.0))) + " " + text_value(add(getv(v_E_26, 1.0), v_drop_50)) + " " + text_value(v_dropX_52) + " " + text_value(add(getv(v_E_26, 1.0), v_drop_50)) + " C" + text_value(v_bendX_53) + " " + text_value(add(getv(v_E_26, 1.0), v_drop_50)) + " " + text_value((getv(v_O_48, 0.0) - (v_dx_40 * 0.23))) + " " + text_value(add((getv(v_O_48, 1.0) - (v_dy_41 * 0.23)), 12.0)) + " " + text_value(v_O_48) + " Q" + text_value(add(getv(v_W_27, 0.0), ((v_dx_40 / v_len_42) * 4.0))) + " " + text_value(add(getv(v_W_27, 1.0), ((v_dy_41 / v_len_42) * 4.0))) + " " + text_value(v_I_49) + " Q" + text_value((getv(v_E_26, 0.0) - (v_side_28 * 26.0))) + " " + text_value((getv(v_E_26, 1.0) - 27.0)) + " " + text_value(v_B_47) + " Q" + text_value((getv(v_S_25, 0.0) - (v_side_28 * 16.0))) + " " + text_value(add(getv(v_S_25, 1.0), 12.0)) + " " + text_value(v_A_46) + "Z")
	var v_box_55: Variant = [([getv(v_A_46, 0.0), (getv(v_E_26, 0.0) - 65.0), (getv(v_W_27, 0.0) - 34.0)].min() - 8.0), (getv(v_A_46, 1.0) - 8.0), add([getv(v_A_46, 0.0), add(getv(v_E_26, 0.0), 65.0), add(getv(v_W_27, 0.0), 34.0)].max(), 8.0), add([add(getv(v_E_26, 1.0), v_drop_50), add(getv(v_W_27, 1.0), 35.0)].max(), 8.0)]
	var v_F_56: Variant = foldField([[v_A_46, [add(getv(v_S_25, 0.0), (v_side_28 * 38.0)), add(getv(v_S_25, 1.0), 76.0)], [add(getv(v_E_26, 0.0), (v_side_28 * 29.0)), (getv(v_E_26, 1.0) - 8.0)], [add(getv(v_E_26, 0.0), (v_side_28 * 20.0)), (add(getv(v_E_26, 1.0), v_drop_50) - 8.0)], 18.0, 7.0], [v_O_48, [(getv(v_W_27, 0.0) - (v_dx_40 * 0.3)), add((getv(v_W_27, 1.0) - (v_dy_41 * 0.3)), 20.0)], [add(getv(v_E_26, 0.0), 10.0), (add(getv(v_E_26, 1.0), v_drop_50) - 6.0)], [(getv(v_E_26, 0.0) - (v_side_28 * 7.0)), add(getv(v_E_26, 1.0), v_drop_50)], 15.0, 13.0], [[getv(v_I_49, 0.0), add(getv(v_I_49, 1.0), 6.0)], [(getv(v_W_27, 0.0) - (v_dx_40 * 0.34)), (getv(v_W_27, 1.0) - (v_dy_41 * 0.34))], [(getv(v_E_26, 0.0) - (v_side_28 * 4.0)), add(getv(v_E_26, 1.0), 10.0)], [add(getv(v_E_26, 0.0), (v_side_28 * 18.0)), (add(getv(v_E_26, 1.0), v_drop_50) - 14.0)], 10.0, 8.0], [[(getv(v_S_25, 0.0) - (v_side_28 * 9.0)), add(getv(v_S_25, 1.0), 60.0)], [(getv(v_S_25, 0.0) - (v_side_28 * 10.0)), add(getv(v_S_25, 1.0), 103.0)], [(getv(v_E_26, 0.0) - (v_side_28 * 18.0)), (getv(v_E_26, 1.0) - 22.0)], [(getv(v_E_26, 0.0) - (v_side_28 * 20.0)), (getv(v_E_26, 1.0) - 3.0)], 13.0, (-4.0)]], make_field("return (6.0*exp((-pow(((x-@0@)/97.0),2.0))));", [getv(v_E_26, 0.0)]))
	invoke_member(v_p_24, "surface", [v_d_54, v_box_55, merge_dicts([v_material_31, {"height": v_F_56, "color": (mix(getv(v_C_30, "cloth"), getv(v_C_30, "linen"), 0.09) if truth((v_side_28 < 0.0)) else getv(v_C_30, "cloth")), "normal": ([(-0.12), 0.0, 1.0] if truth((v_side_28 < 0.0)) else [0.18, 0.0, 1.0]), "shadowField": make_field("return ((@0@<0.0)?0.98:0.73);", [v_side_28]), "u": make_field("return (x-(y*0.12));", [])}])])
	invoke_member(v_p_24, "surface", [("M" + text_value(v_O_48) + " L" + text_value(add(getv(v_O_48, 0.0), ((v_dx_40 / v_len_42) * 11.0))) + " " + text_value(add(getv(v_O_48, 1.0), ((v_dy_41 / v_len_42) * 11.0))) + " Q" + text_value(add(getv(v_W_27, 0.0), ((v_dx_40 / v_len_42) * 18.0))) + " " + text_value(add(getv(v_W_27, 1.0), ((v_dy_41 / v_len_42) * 18.0))) + " " + text_value(add(getv(v_I_49, 0.0), ((v_dx_40 / v_len_42) * 11.0))) + " " + text_value(add(getv(v_I_49, 1.0), ((v_dy_41 / v_len_42) * 11.0))) + " L" + text_value(v_I_49) + "Z"), [(getv(v_W_27, 0.0) - 38.0), (getv(v_W_27, 1.0) - 38.0), add(getv(v_W_27, 0.0), 38.0), add(getv(v_W_27, 1.0), 38.0)], merge_dicts([v_material_31, {"color": mix(getv(v_C_30, "cloth"), getv(v_C_30, "linen"), 0.48), "height": make_field("return (2.0*sin(((((x*@0@)+(y*@1@))/@2@)*0.2)));", [v_dx_40, v_dy_41, v_len_42]), "exposure": 0.85}])])
	invoke_member(v_p_24, "stroke", [("M" + text_value(getv(v_O_48, 0.0)) + " " + text_value(getv(v_O_48, 1.0)) + " Q" + text_value(add(getv(v_W_27, 0.0), ((v_dx_40 / v_len_42) * 5.0))) + " " + text_value(add(getv(v_W_27, 1.0), ((v_dy_41 / v_len_42) * 5.0))) + " " + text_value(getv(v_I_49, 0.0)) + " " + text_value(getv(v_I_49, 1.0)) + ""), getv(v_C_30, "salt"), 1.5, 0.45])
static func configureFigure(v_config_57, v_recipe_58, v_C_59):
	var v_d_60: Variant = getv(v_recipe_58, "dimensions")
	var v_k_61: Variant = getv(v_recipe_58, "construction")
	var v_gesture_62: Variant = getv(v_k_61, "gesture")
	var v_garment_63: Variant = getv(v_k_61, "garment")
	var v_f_64: Variant = getv(v_d_60, "presentation")
	var v_waist_65: Variant = (132.0 - (v_f_64 * 32.0))
	var v_hip_66: Variant = add(173.0, (v_f_64 * 11.0))
	var v_volume_67: Variant = (add(10.0, (getv(v_d_60, "sleeve") * 22.0)) if truth(getv(v_k_61, "civilian")) else (75.0 if truth((v_garment_63 == "mantle")) else (25.0 if truth((v_garment_63 == "coat")) else add(42.0, (getv(v_d_60, "sleeve") * 40.0)))))
	v_config_57["root"] = ("M365 339 Q327 365 303 410 Q326 510 " + text_value((470.0 - v_waist_65)) + " 667 L" + text_value((470.0 - v_hip_66)) + " 949 Q470 979 " + text_value(add(470.0, v_hip_66)) + " 947 L" + text_value(add(470.0, v_waist_65)) + " 667 Q646 502 618 415 Q568 373 492 340Z")
	v_config_57["rootBox"] = [285.0, 333.0, 670.0, 965.0]
	v_config_57["suppressStole"] = true
	v_config_57["rootHeight"] = foldField([[[369.0, 383.0], [381.0, 509.0], [add((470.0 - v_waist_65), 16.0), 680.0], [add((470.0 - v_hip_66), 29.0), 949.0], 18.0, 13.0], [[424.0, 442.0], [442.0, 555.0], [407.0, 758.0], [425.0, 960.0], 20.0, 15.0], [[491.0, 410.0], [540.0, 565.0], [510.0, 771.0], [552.0, 958.0], 19.0, 14.0], [[573.0, 432.0], [595.0, 551.0], [584.0, 768.0], [620.0, 948.0], 14.0, 10.0]], make_field("return ((26.0*exp((-pow(((x-455.0)/148.0),2.0))))-(0.04*(x-430.0)));", []))
	var v_S_68: Variant = [[326.0, 414.0], [610.0, 422.0]]
	var v_E_69: Variant = [[(285.0 - (getv(v_d_60, "sleeve") * 6.0)), 591.0], [add(650.0, (getv(v_d_60, "sleeve") * 7.0)), 599.0]]
	var v_W_70: Variant = null
	var v_angles_71: Variant = null
	var v_kinds_72: Variant = null
	if truth((v_gesture_62 == "entreat")):
		v_W_70 = [[324.0, 492.0], [520.0, 516.0]]
		v_E_69[int(0.0)] = [277.0, 607.0]
		v_E_69[int(1.0)] = [637.0, 606.0]
		v_angles_71 = [(-0.25), (-0.8)]
		v_kinds_72 = ["palm", "touch"]
	else:
		if truth((v_gesture_62 == "bargain")):
			v_W_70 = [[357.0, 559.0], [514.0, 488.0]]
			v_E_69[int(0.0)] = [283.0, 607.0]
			v_angles_71 = [0.85, (-0.6)]
			v_kinds_72 = ["palm", "touch"]
		else:
			if truth((v_gesture_62 == "appeal")):
				v_W_70 = [[350.0, 637.0], [514.0, 484.0]]
				v_angles_71 = [1.28, (-0.7)]
				v_kinds_72 = ["palm", "touch"]
			else:
				if truth((v_gesture_62 == "prayer")):
					v_W_70 = [[467.0, 516.0], [498.0, 516.0]]
					getv(v_E_69, 0.0)[int(1.0)] = 626.0
					getv(v_E_69, 1.0)[int(1.0)] = 629.0
					v_angles_71 = [0.12, (-0.26)]
					v_kinds_72 = ["prayer", "prayer"]
				else:
					if truth((v_gesture_62 == "staff")):
						v_W_70 = [[442.0, 573.0], [683.0, 515.0]]
						v_E_69[int(1.0)] = [641.0, 628.0]
						v_angles_71 = [0.58, 1.3]
						v_kinds_72 = ["touch", "fist"]
					else:
						if truth((v_gesture_62 == "folded")):
							v_W_70 = [[509.0, 563.0], [425.0, 577.0]]
							v_angles_71 = [1.5, (-1.5)]
							v_kinds_72 = ["touch", "touch"]
						else:
							if truth((v_gesture_62 == "cradle")):
								v_W_70 = [[465.0, 627.0], [529.0, 521.0]]
								v_angles_71 = [1.2, (-2.2)]
								v_kinds_72 = ["touch", "touch"]
							else:
								if truth((v_gesture_62 == "injured")):
									v_W_70 = [[482.0, 583.0], [503.0, 555.0]]
									v_angles_71 = [1.3, (-0.2)]
									v_kinds_72 = ["touch", "touch"]
								else:
									if truth((v_gesture_62 == "guarded")):
										v_W_70 = [[474.0, 612.0], [508.0, 501.0]]
										v_angles_71 = [0.9, (-0.6)]
										v_kinds_72 = ["fist", "touch"]
									else:
										v_W_70 = [[431.0, 596.0], [530.0, 596.0]]
										v_angles_71 = [1.25, (-1.25)]
										v_kinds_72 = ["touch", "touch"]
	getv(v_config_57, "layers")["underSleeves"] = func(v_p_73, v_arg_74):
		var v_unpack_75: Variant = v_arg_74
		var v_dark_76: Variant = getv(v_unpack_75, "dark")
		var v_pale_77: Variant = getv(v_unpack_75, "pale")
		var v_bronze_78: Variant = getv(v_unpack_75, "bronze")
		if truth((v_garment_63 == "crosswrap")):
			invoke_member(v_p_73, "surface", [("M371 347 Q414 405 536 479 L" + text_value((add(470.0, v_waist_65) - 10.0)) + " 671 L" + text_value((add(470.0, v_hip_66) - 17.0)) + " 949 L" + text_value(add((470.0 - v_hip_66), 32.0)) + " 949 Q405 751 439 651 L513 487 Q398 450 340 396Z"), [325.0, 341.0, 654.0, 960.0], merge_dicts([v_pale_77, {"color": mix(getv(v_C_59, "cloth"), getv(v_C_59, "linen"), 0.4), "height": foldField([[[365.0, 372.0], [411.0, 433.0], [491.0, 454.0], [521.0, 485.0], 15.0, 15.0], [[518.0, 491.0], [490.0, 566.0], [450.0, 612.0], [447.0, 659.0], 17.0, 13.0], [[441.0, 683.0], [397.0, 786.0], [370.0, 863.0], [344.0, 945.0], 19.0, 12.0]])}])])
			invoke_member(v_p_73, "surface", [("M" + text_value((470.0 - v_waist_65)) + " 655 Q470 688 " + text_value(add(470.0, v_waist_65)) + " 657 L" + text_value((add(470.0, v_waist_65) - 4.0)) + " 686 Q470 710 " + text_value(add((470.0 - v_waist_65), 3.0)) + " 686Z"), [330.0, 650.0, 610.0, 713.0], merge_dicts([v_dark_76, {"color": getv(v_C_59, "violet"), "height": make_field("return (4.0*sin((y*0.16)));", [])}])])
			invoke_member(v_p_73, "surface", ["M496 681 Q517 710 503 808 L478 834 Q503 735 482 687Z", [475.0, 677.0, 520.0, 840.0], merge_dicts([v_dark_76, {"color": getv(v_C_59, "violet"), "height": foldField([[[491.0, 690.0], [509.0, 732.0], [490.0, 775.0], [485.0, 828.0], 9.0, 7.0]])}])])
		else:
			if truth((v_garment_63 == "tabard")):
				for v_item_79 in [[367.0, add(42.0, (getv(v_d_60, "panel") * 0.25))], [516.0, add(35.0, (getv(v_d_60, "panel") * 0.2))]]:
					var v_unpack_80: Variant = v_item_79
					var v_x_81: Variant = getv(v_unpack_80, 0)
					var v_w_82: Variant = getv(v_unpack_80, 1)
					invoke_member(v_p_73, "surface", [("M" + text_value(v_x_81) + " 366 Q" + text_value(add(v_x_81, 4.0)) + " 516 " + text_value((v_x_81 - 14.0)) + " 947 L" + text_value(add(v_x_81, v_w_82)) + " 957 Q" + text_value((add(v_x_81, v_w_82) - 11.0)) + " 570 " + text_value(add(v_x_81, v_w_82)) + " 388Z"), [(v_x_81 - 20.0), 360.0, add(add(v_x_81, v_w_82), 8.0), 962.0], merge_dicts([v_pale_77, {"color": getv(v_C_59, "violet"), "height": foldField([[[add(v_x_81, 13.0), 390.0], [add(v_x_81, 16.0), 545.0], [add(v_x_81, 8.0), 773.0], [add(v_x_81, 9.0), 949.0], 11.0, 10.0], [[(add(v_x_81, v_w_82) - 7.0), 405.0], [(add(v_x_81, v_w_82) - 11.0), 550.0], [(add(v_x_81, v_w_82) - 8.0), 764.0], [(add(v_x_81, v_w_82) - 7.0), 951.0], 8.0, 7.0]])}])])
			else:
				if truth((v_garment_63 == "coat")):
					invoke_member(v_p_73, "surface", ["M412 370 Q448 391 498 370 L540 955 L392 953Z", [387.0, 365.0, 546.0, 960.0], merge_dicts([v_pale_77, {"color": mix(getv(v_C_59, "violet"), getv(v_C_59, "linen"), 0.36), "height": foldField([[[432.0, 406.0], [452.0, 571.0], [428.0, 774.0], [433.0, 951.0], 12.0, 10.0], [[479.0, 407.0], [491.0, 610.0], [487.0, 777.0], [506.0, 952.0], 12.0, 11.0]])}])])
					for v_item_83 in [[402.0, (-1.0)], [512.0, 1.0]]:
						var v_unpack_84: Variant = v_item_83
						var v_x_85: Variant = getv(v_unpack_84, 0)
						var v_s_86: Variant = getv(v_unpack_84, 1)
						invoke_member(v_p_73, "surface", [("M" + text_value(v_x_85) + " 351 L" + text_value(add(v_x_85, (v_s_86 * 34.0))) + " 390 L" + text_value(add(v_x_85, (v_s_86 * 17.0))) + " 463 L" + text_value(add(v_x_85, (v_s_86 * 61.0))) + " 945 L" + text_value(add(v_x_85, (v_s_86 * 22.0))) + " 951 L" + text_value((v_x_85 - (v_s_86 * 15.0))) + " 449Z"), [[(v_x_85 - 55.0), add(v_x_85, (v_s_86 * 65.0))].min(), 345.0, [add(v_x_85, 55.0), add(v_x_85, (v_s_86 * 65.0))].max(), 958.0], merge_dicts([v_dark_76, {"color": mix(getv(v_C_59, "cloth"), getv(v_C_59, "linen"), 0.23), "height": foldField([[[v_x_85, 376.0], [add(v_x_85, (v_s_86 * 7.0)), 452.0], [add(v_x_85, (v_s_86 * 22.0)), 687.0], [add(v_x_85, (v_s_86 * 45.0)), 949.0], 12.0, 10.0]])}])])
				else:
					invoke_member(v_p_73, "surface", [("M345 355 Q417 326 479 350 Q571 369 618 418 L653 " + text_value(add(495.0, (getv(v_d_60, "mantle") * 0.6))) + " Q564 " + text_value(add(576.0, (getv(v_d_60, "mantle") * 0.3))) + " 462 484 Q363 563 283 478Z"), [275.0, 325.0, 659.0, 635.0], merge_dicts([v_pale_77, {"color": mix(getv(v_C_59, "cloth"), getv(v_C_59, "linen"), 0.38), "height": foldField([[[349.0, 375.0], [361.0, 424.0], [388.0, 489.0], [425.0, 508.0], 17.0, 15.0], [[443.0, 366.0], [474.0, 436.0], [530.0, 505.0], [620.0, 536.0], 20.0, 18.0], [[530.0, 387.0], [570.0, 441.0], [590.0, 495.0], [642.0, 512.0], 12.0, 11.0]])}])])
	v_config_57["collar"] = func(v_p_87, v_arg_88):
		var v_unpack_89: Variant = v_arg_88
		var v_dark_90: Variant = getv(v_unpack_89, "dark")
		var v_pale_91: Variant = getv(v_unpack_89, "pale")
		var v_bronze_92: Variant = getv(v_unpack_89, "bronze")
		if truth((v_garment_63 == "mantle")):
			invoke_member(v_p_87, "surface", ["M361 322 Q429 348 491 339 Q553 371 600 408 L573 450 Q474 426 383 387 L330 418Z", [324.0, 317.0, 606.0, 457.0], merge_dicts([v_pale_91, {"color": getv(v_C_59, "linen"), "height": foldField([[[367.0, 336.0], [405.0, 382.0], [489.0, 397.0], [583.0, 429.0], 16.0, 14.0], [[350.0, 364.0], [405.0, 397.0], [474.0, 418.0], [559.0, 437.0], 10.0, 11.0]])}])])
		else:
			if truth((v_garment_63 == "crosswrap")):
				invoke_member(v_p_87, "surface", ["M363 324 Q395 356 459 384 L542 433 L523 458 Q403 414 348 368Z", [343.0, 319.0, 547.0, 464.0], merge_dicts([v_pale_91, {"height": foldField([[[366.0, 338.0], [401.0, 380.0], [464.0, 402.0], [531.0, 443.0], 12.0, 13.0]])}])])
				invoke_member(v_p_87, "surface", ["M485 336 Q473 371 422 414 L401 398 Q447 358 453 330Z", [396.0, 325.0, 490.0, 419.0], merge_dicts([v_pale_91, {"color": mix(getv(v_C_59, "linen"), getv(v_C_59, "cloth"), 0.3), "height": foldField([[[472.0, 345.0], [458.0, 373.0], [439.0, 389.0], [412.0, 405.0], 10.0, 10.0]])}])])
			else:
				invoke_member(v_p_87, "surface", ["M365 326 Q426 349 491 326 L517 377 Q443 415 350 369Z", [345.0, 321.0, 523.0, 420.0], merge_dicts([v_pale_91, {"color": getv(v_C_59, "linen"), "height": foldField([[[365.0, 342.0], [416.0, 378.0], [466.0, 378.0], [507.0, 365.0], 14.0, 13.0], [[370.0, 364.0], [415.0, 397.0], [467.0, 392.0], [506.0, 378.0], 9.0, 8.0]])}])])
		invoke_member(v_p_87, "surface", ["M364 390 Q377 382 386 394 L382 415 Q370 423 363 409Z", [358.0, 378.0, 391.0, 428.0], merge_dicts([v_bronze_92, {"height": make_field("return (3.0*exp((-pow(((x-375.0)/9.0),2.0))));", []), "exposure": 0.75}])])
	v_config_57["arms"] = func(v_p_93, v_arg_94):
		var v_unpack_95: Variant = v_arg_94
		var v_dark_96: Variant = getv(v_unpack_95, "dark")
		var v_bronze_97: Variant = getv(v_unpack_95, "bronze")
		if truth((v_gesture_62 == "staff")):
			invoke_member(v_p_93, "surface", ["M688 335 Q693 326 697 335 L692 932 L683 934Z", [678.0, 324.0, 702.0, 940.0], merge_dicts([v_bronze_97, {"color": mix(getv(v_C_59, "copper"), getv(v_C_59, "clothShadow"), 0.36), "height": make_field("return (3.0*exp((-pow(((x-690.0)/4.0),2.0))));", []), "exposure": 0.7}])])
			invoke_member(v_p_93, "line", ["M691 341 Q668 323 682 300 Q704 285 715 309 Q723 328 701 337", getv(v_C_59, "copper"), 7.0, 0.9])
			invoke_member(v_p_93, "stroke", ["M681 307 Q696 290 707 308", getv(v_C_59, "salt"), 2.0, 0.7])
		if truth((v_gesture_62 == "cradle")):
			invoke_member(v_p_93, "surface", ["M451 472 L563 493 L548 642 L433 618Z", [428.0, 466.0, 570.0, 649.0], {"mat": "cloth", "color": mix(getv(v_C_59, "linen"), getv(v_C_59, "copper"), 0.24), "shadow": getv(v_C_59, "linenShadow"), "accent": getv(v_C_59, "salt"), "height": make_field("return (3.0*sin(((x+(y*0.15))*0.13)));", []), "exposure": 0.8}])
			invoke_member(v_p_93, "stroke", ["M460 484 L551 501 L537 626 L445 609Z", getv(v_C_59, "copper"), 2.0, 0.7])
			var v_i_98: Variant = 0.0
			while truth((v_i_98 < 8.0)):
				invoke_member(v_p_93, "line", [("M463 " + text_value(add(508.0, (v_i_98 * 11.0))) + "l69,13"), getv(v_C_59, "clothShadow"), 1.0, 0.65])
				v_i_98 += 1
		var v_armMaterial_99: Variant = (merge_dicts([v_dark_96, {"mat": or_value(getv(v_config_57, "sleeveMaterial"), "cloth")}]) if truth(getv(v_k_61, "civilian")) else v_dark_96)
		sleeve(v_p_93, getv(v_S_68, 0.0), getv(v_E_69, 0.0), getv(v_W_70, 0.0), (-1.0), v_volume_67, v_C_59, v_armMaterial_99, getv(v_k_61, "civilian"), getv(v_config_57, "rolledSleeves"))
		sleeve(v_p_93, getv(v_S_68, 1.0), getv(v_E_69, 1.0), getv(v_W_70, 1.0), 1.0, v_volume_67, v_C_59, v_armMaterial_99, getv(v_k_61, "civilian"), getv(v_config_57, "rolledSleeves"))
	var v_offering_100: Variant = getv(v_config_57, "drawObject")
	v_config_57["handwork"] = func(v_p_101, v_arg_102):
		var v_unpack_103: Variant = v_arg_102
		var v_bronze_104: Variant = getv(v_unpack_103, "bronze")
		var v_pale_105: Variant = getv(v_unpack_103, "pale")
		var v_dark_106: Variant = getv(v_unpack_103, "dark")
		if truth((v_gesture_62 == "offering")):
			if truth(v_offering_100):
				invoke(v_offering_100, [v_p_101, {"bronze": v_bronze_104, "pale": v_pale_105, "dark": v_dark_106}])
			else:
				invoke_member(v_p_101, "surface", ["M425 564 Q480 548 538 564 L525 608 Q480 630 438 606Z", [420.0, 545.0, 544.0, 633.0], merge_dicts([v_bronze_104, {"color": getv(v_C_59, "copper"), "height": make_field("return (7.0*exp((-pow(((x-480.0)/52.0),2.0))));", []), "normal": [0.0, 0.2, 1.0]}])])
				invoke_member(v_p_101, "surface", ["M425 564 C425 542 538 542 538 564 C538 585 425 585 425 564Z", [419.0, 540.0, 544.0, 589.0], {"mat": "water", "color": "#72cba1", "shadow": "#09262e", "cx": 480.0, "cy": 564.0, "v": make_field("return (564.0+((y-564.0)*3.0));", []), "emission": 0.13, "normal": [0.0, (-0.8), 0.6], "bump": 0.35}])
				invoke_member(v_p_101, "glow", [480.0, 564.0, 55.0, getv(v_C_59, "light"), 0.1])
			hand(v_p_101, [434.0, 601.0], 1.2, 0.84, "touch", v_C_59)
			hand(v_p_101, [527.0, 602.0], (-1.2), 0.84, "touch", v_C_59)
		else:
			if truth((v_gesture_62 == "prayer")):
				var v_skin_107: Variant = {"mat": "skin", "color": mix(getv(v_C_59, "copper"), "#b99b7e", 0.68), "shadow": "#5b5145", "accent": "#cdb58d", "bump": 0.35, "exposure": 0.7}
				invoke_member(v_p_101, "surface", ["M456 526 Q451 510 458 493 L476 460 Q479 451 484 455 Q487 459 484 470 L478 491 L488 472 Q491 465 495 469 Q499 474 490 490 L487 513 L477 532Z", [447.0, 447.0, 503.0, 537.0], merge_dicts([v_skin_107, {"normal": [(-0.2), (-0.06), 1.0], "height": foldField([[[480.0, 461.0], [472.0, 480.0], [464.0, 495.0], [464.0, 518.0], 4.0, 2.3], [[490.0, 473.0], [484.0, 488.0], [480.0, 503.0], [479.0, 520.0], 4.0, 2.0]])}])])
				invoke_member(v_p_101, "surface", ["M482 524 Q492 502 490 486 L485 460 Q485 454 489 453 Q494 453 497 461 L512 488 Q519 500 515 516 L505 533Z", [477.0, 447.0, 524.0, 539.0], merge_dicts([v_skin_107, {"normal": [0.25, 0.0, 1.0], "exposure": 0.58, "height": foldField([[[491.0, 461.0], [495.0, 478.0], [503.0, 497.0], [502.0, 520.0], 5.0, 2.6]])}])])
				invoke_member(v_p_101, "stroke", ["M487 468 Q490 482 490 496 Q488 511 482 522", getv(v_C_59, "clothShadow"), 1.2, 0.6])
				invoke_member(v_p_101, "stroke", ["M462 505 Q469 488 476 477", getv(v_C_59, "salt"), 1.0, 0.5])
				invoke_member(v_p_101, "line", ["M493 493 Q503 490 509 498", getv(v_C_59, "clothShadow"), 0.8, 0.5])
			else:
				if truth((v_gesture_62 == "folded")):
					hand(v_p_101, [499.0, 558.0], 1.4, (getv(v_d_60, "handScale") * 0.82), "touch", v_C_59)
					invoke_member(v_p_101, "surface", ["M415 550 Q441 530 475 548 L491 587 Q451 611 420 590Z", [408.0, 525.0, 497.0, 618.0], merge_dicts([v_dark_106, {"color": mix(getv(v_C_59, "cloth"), getv(v_C_59, "linen"), 0.2), "height": foldField([[[421.0, 560.0], [445.0, 550.0], [463.0, 566.0], [480.0, 583.0], 12.0, 10.0]])}])])
				else:
					var v_i_108: Variant = 0.0
					while truth((v_i_108 < 2.0)):
						hand(v_p_101, getv(v_W_70, v_i_108), getv(v_angles_71, v_i_108), getv(v_d_60, "handScale"), getv(v_kinds_72, v_i_108), v_C_59)
						v_i_108 += 1
	if truth((v_gesture_62 != "offering")):
		v_config_57["emitters"] = []
	return {"shoulders": v_S_68, "elbows": v_E_69, "wrists": v_W_70, "gesture": getv(GESTURE_NAMES, v_gesture_62), "garment": getv(GARMENT_NAMES, v_garment_63)}
