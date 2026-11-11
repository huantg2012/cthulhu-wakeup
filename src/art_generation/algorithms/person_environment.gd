extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: person-environment.js; preserve contours, ordering and seed decisions.

static func configureEnvironmentPerson(v_config_1, v_recipe_2, v_C_3, v_world_4):
	var v_rule_5: Variant = getv(getv(v_recipe_2, "background"), "environment")
	if truth((not truth(v_rule_5))):
		assert(false, str("该世界缺少人物环境规则"))
	v_config_1["environmentWorld"] = v_world_4
	v_config_1["environmentRule"] = getv(getv(v_recipe_2, "background"), "environment")
	v_config_1["framing"] = [1.48, (-210.0), (-130.0)]
	var v_under_6: Variant = getv(getv(v_config_1, "layers"), "underSleeves")
	var v_collar_7: Variant = getv(v_config_1, "collar")
	var v_cloth_8: Variant = {"mat": "cloth", "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "salt"), "bump": 0.55}
	getv(v_config_1, "layers")["underSleeves"] = func(v_p_9, v_m_10):
		invoke(v_under_6, [v_p_9, v_m_10])
		if truth((getv(v_rule_5, "layer") == "straps")):
			for v_item_11 in [[378.0, (-1.0)], [533.0, 1.0]]:
				var v_unpack_12: Variant = v_item_11
				var v_x_13: Variant = getv(v_unpack_12, 0)
				var v_side_14: Variant = getv(v_unpack_12, 1)
				invoke_member(v_p_9, "surface", [("M" + text_value(v_x_13) + " 376 Q" + text_value(add(v_x_13, (v_side_14 * 15.0))) + " 521 " + text_value((v_x_13 - (v_side_14 * 20.0))) + " 694 L" + text_value((v_x_13 - (v_side_14 * 5.0))) + " 702 Q" + text_value(add(v_x_13, (v_side_14 * 29.0))) + " 522 " + text_value(add(v_x_13, 14.0)) + " 375Z"), [(v_x_13 - 40.0), 368.0, add(v_x_13, 45.0), 710.0], merge_dicts([v_cloth_8, {"mat": "leather", "color": mix(getv(v_C_3, "copper"), getv(v_C_3, "clothShadow"), 0.45), "height": make_field("return (2.0*sin((y*0.06)));", [])}])])
		if truth((getv(v_rule_5, "layer") == "lapels")):
			for v_item_15 in [[407.0, (-1.0)], [514.0, 1.0]]:
				var v_unpack_16: Variant = v_item_15
				var v_x_17: Variant = getv(v_unpack_16, 0)
				var v_side_18: Variant = getv(v_unpack_16, 1)
				invoke_member(v_p_9, "surface", [("M" + text_value(v_x_17) + " 369 L" + text_value(add(v_x_17, (v_side_18 * 40.0))) + " 409 L" + text_value(add(v_x_17, (v_side_18 * 18.0))) + " 476 L" + text_value((v_x_17 - (v_side_18 * 12.0))) + " 429Z"), [(v_x_17 - 55.0), 362.0, add(v_x_17, 55.0), 484.0], merge_dicts([v_cloth_8, {"color": mix(getv(v_C_3, "outer"), getv(v_C_3, "linen"), 0.2), "normal": [(v_side_18 * 0.15), (-0.25), 1.0], "height": make_field("return (4.0*sin((y*0.024)));", [])}])])
	v_config_1["collar"] = func(v_p_19, v_m_20):
		invoke(v_collar_7, [v_p_19, v_m_20])
		if truth((getv(v_rule_5, "layer") == "capelet")):
			invoke_member(v_p_19, "surface", ["M375 347 Q424 369 487 344 Q551 368 593 420 L573 473 Q488 458 434 406 Q378 447 333 427Z", [326.0, 338.0, 601.0, 480.0], merge_dicts([v_cloth_8, {"color": mix(getv(v_C_3, "outer"), getv(v_C_3, "linen"), 0.3), "normal": [(-0.1), (-0.45), 0.9], "height": foldField([[[365.0, 374.0], [398.0, 406.0], [446.0, 402.0], [482.0, 382.0], 16.0, 11.0], [[490.0, 365.0], [516.0, 408.0], [544.0, 442.0], [578.0, 455.0], 18.0, 13.0]])}])])
		if truth((getv(v_rule_5, "layer") in ["wrap", "collar"])):
			invoke_member(v_p_19, "surface", ["M387 335 Q429 359 481 338 L514 377 Q456 409 372 373Z", [365.0, 329.0, 521.0, 415.0], merge_dicts([v_cloth_8, {"color": mix(getv(v_C_3, "linen"), getv(v_C_3, "outer"), 0.4), "normal": [(-0.1), (-0.5), 0.85], "height": foldField([[[386.0, 349.0], [424.0, 387.0], [470.0, 390.0], [505.0, 370.0], 13.0, 10.0]])}])])
