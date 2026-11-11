extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: world-person.js; preserve contours, ordering and seed decisions.

static func configureWorldPerson(v_config_1, v_recipe_2, v_C_3, v_world_4):
	var v_d_5: Variant = getv(v_recipe_2, "dimensions")
	var v_k_6: Variant = getv(v_recipe_2, "construction")
	var v_cold_7: Variant = (getv(v_world_4, "archetype") == 5.0)
	var v_under_8: Variant = getv(getv(v_config_1, "layers"), "underSleeves")
	var v_collar_9: Variant = getv(v_config_1, "collar")
	var v_head_10: Variant = getv(v_config_1, "headwork")
	var v_fabric_11: Variant = {"mat": "cloth", "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "salt"), "bump": 0.55}
	var v_lining_12: Variant = mix(getv(v_C_3, "linen"), ("#aab4bb" if truth(v_cold_7) else "#8b7667"), (0.3 if truth(v_cold_7) else 0.4))
	var v_front_13: Variant = (mix(getv(v_C_3, "outer"), "#59697a", 0.38) if truth(v_cold_7) else mix(getv(v_C_3, "outer"), "#976541", 0.25))
	v_config_1["framing"] = [1.48, (-210.0), (-130.0)]
	v_config_1["sleeveMaterial"] = ("cloth" if truth(v_cold_7) else "canvas")
	v_config_1["rolledSleeves"] = ((getv(v_k_6, "garment") in ["apron", "workshirt", "jerkin"]) if truth((not truth(v_cold_7))) else (not truth(v_cold_7)))
	v_config_1["environmentWorld"] = v_world_4
	v_config_1["environmentRule"] = getv(getv(v_recipe_2, "background"), "environment")
	v_config_1["emitters"] = ([{"x": 235.0, "y": 245.0, "z": 190.0, "r": 750.0, "power": 0.1, "color": rgb(getv(v_world_4, "c4"))}] if truth(v_cold_7) else [{"x": 730.0, "y": 680.0, "z": 170.0, "r": 710.0, "power": 0.27, "color": rgb(getv(v_world_4, "c4")), "falloff": 1.6}])
	getv(v_config_1, "layers")["underSleeves"] = func(v_p_14, v_materials_15):
		invoke(v_under_8, [v_p_14, v_materials_15])
		if truth(v_cold_7):
			if truth((getv(v_k_6, "garment") in ["workshirt", "jerkin", "waistcoat"])):
				var v_vest_16: Variant = "M372 361 Q348 406 351 467 L341 728 Q396 755 453 737 L464 428 L484 735 Q548 755 593 724 L579 452 Q556 387 489 352 L461 401 L424 391Z"
				invoke_member(v_p_14, "surface", [v_vest_16, [334.0, 346.0, 601.0, 765.0], merge_dicts([v_fabric_11, {"color": v_front_13, "height": foldField([[[376.0, 400.0], [389.0, 515.0], [366.0, 633.0], [370.0, 730.0], 20.0, 10.0], [[531.0, 391.0], [551.0, 505.0], [532.0, 620.0], [551.0, 732.0], 24.0, 12.0]])}])])
				var v_j_17: Variant = 0.0
				while truth((v_j_17 < 8.0)):
					var v_y_18: Variant = add(438.0, (v_j_17 * 37.0))
					invoke_member(v_p_14, "line", [("M356 " + text_value(v_y_18) + " Q400 " + text_value(add(v_y_18, 18.0)) + " 452 " + text_value(add(v_y_18, 8.0)) + ""), getv(v_C_3, "clothShadow"), 1.5, 0.42])
					invoke_member(v_p_14, "line", [("M481 " + text_value(add(v_y_18, 7.0)) + " Q534 " + text_value(add(v_y_18, 18.0)) + " 581 " + text_value((v_y_18 - 2.0)) + ""), getv(v_C_3, "clothShadow"), 1.5, 0.42])
					v_j_17 += 1
				var v_j_19: Variant = 0.0
				while truth((v_j_19 < 4.0)):
					invoke_member(v_p_14, "stroke", [("M449 " + text_value(add(461.0, (v_j_19 * 65.0))) + "q12,5 33,-1"), getv(v_C_3, "copper"), 5.0, 0.65])
					v_j_19 += 1
			if truth((getv(v_k_6, "garment") == "apron")):
				invoke_member(v_p_14, "surface", ["M370 384 L390 393 L403 461 L386 465Z", [363.0, 378.0, 410.0, 472.0], merge_dicts([v_fabric_11, {"color": v_lining_12, "height": make_field("return (2.0*sin((y*0.13)));", [])}])])
				var v_j_20: Variant = 0.0
				while truth((v_j_20 < 3.0)):
					invoke_member(v_p_14, "stroke", [("M" + text_value(add(407.0, (v_j_20 * 29.0))) + " 666l-3,43q9,7 18,0l3,-41"), getv(v_C_3, "clothShadow"), 2.0, 0.6])
					v_j_20 += 1
			if truth((getv(v_k_6, "garment") in ["tailored", "drivercoat"])):
				for v_item_21 in [[405.0, (-1.0)], [514.0, 1.0]]:
					var v_unpack_22: Variant = v_item_21
					var v_x_23: Variant = getv(v_unpack_22, 0)
					var v_side_24: Variant = getv(v_unpack_22, 1)
					invoke_member(v_p_14, "surface", [("M" + text_value(v_x_23) + " 397 Q" + text_value(add(v_x_23, (v_side_24 * 15.0))) + " 528 " + text_value(add(v_x_23, (v_side_24 * 8.0))) + " 776 L" + text_value(add(v_x_23, (v_side_24 * 25.0))) + " 779 Q" + text_value(add(v_x_23, (v_side_24 * 34.0))) + " 530 " + text_value(add(v_x_23, (v_side_24 * 14.0))) + " 394Z"), [(v_x_23 - 40.0), 388.0, add(v_x_23, 40.0), 790.0], merge_dicts([v_fabric_11, {"color": v_lining_12, "height": foldField([[[v_x_23, 400.0], [add(v_x_23, (v_side_24 * 25.0)), 512.0], [add(v_x_23, (v_side_24 * 8.0)), 659.0], [add(v_x_23, (v_side_24 * 20.0)), 773.0], 8.0, 6.0]])}])])
		else:
			if truth((getv(v_k_6, "garment") == "apron")):
				invoke_member(v_p_14, "surface", ["M401 514 Q451 528 526 517 L532 646 Q465 667 395 640Z", [389.0, 508.0, 540.0, 675.0], {"mat": "leather", "color": mix(getv(v_C_3, "outer"), "#4d3327", 0.5), "shadow": getv(v_C_3, "clothShadow"), "accent": v_lining_12, "height": foldField([[[414.0, 528.0], [438.0, 552.0], [418.0, 603.0], [409.0, 635.0], 17.0, 6.0]])}])
				invoke_member(v_p_14, "stroke", ["M402 521 Q459 536 521 524", v_lining_12, 1.5, 0.5])
			if truth((getv(v_k_6, "garment") in ["drivercoat", "tailored"])):
				invoke_member(v_p_14, "surface", ["M361 365 Q414 390 438 425 L416 464 L330 410Z", [324.0, 359.0, 444.0, 470.0], merge_dicts([v_fabric_11, {"mat": "canvas", "color": v_front_13, "normal": [(-0.2), (-0.3), 1.0], "height": foldField([[[366.0, 377.0], [386.0, 405.0], [405.0, 438.0], [418.0, 451.0], 15.0, 7.0]])}])])
				invoke_member(v_p_14, "surface", ["M494 360 Q545 376 579 414 L513 460 L477 416Z", [471.0, 354.0, 585.0, 466.0], merge_dicts([v_fabric_11, {"mat": "canvas", "color": v_front_13, "normal": [0.35, (-0.24), 1.0], "height": foldField([[[502.0, 374.0], [523.0, 396.0], [536.0, 418.0], [520.0, 445.0], 13.0, 6.0]])}])])
			if truth((getv(v_k_6, "garment") != "tailored")):
				invoke_member(v_p_14, "surface", ["M347 695 Q461 721 596 688 L593 715 Q469 747 349 722Z", [341.0, 682.0, 602.0, 753.0], merge_dicts([v_fabric_11, {"color": mix(getv(v_C_3, "outer"), "#463f48", 0.5), "height": make_field("return (4.0*sin((y*0.21)));", [])}])])
				invoke_member(v_p_14, "surface", ["M534 717 Q567 757 544 814 L526 828 Q543 767 518 719Z", [512.0, 711.0, 574.0, 834.0], merge_dicts([v_fabric_11, {"color": mix(getv(v_C_3, "outer"), "#463f48", 0.5), "height": foldField([[[532.0, 724.0], [552.0, 753.0], [536.0, 800.0], [531.0, 818.0], 8.0, 6.0]])}])])
	v_config_1["collar"] = func(v_p_25, v_materials_26):
		invoke(v_collar_9, [v_p_25, v_materials_26])
		if truth(v_cold_7):
			var v_fur_27: Variant = {"mat": "hair", "color": v_lining_12, "shadow": mix(getv(v_C_3, "clothShadow"), v_lining_12, 0.3), "accent": getv(v_C_3, "salt"), "bump": 0.35, "u": make_field("return ((x*0.8)+(y*0.35));", []), "v": make_field("return (y*3.0);", [])}
			invoke_member(v_p_25, "surface", ["M386 337 Q391 371 442 387 L425 425 Q357 403 350 370Z", [344.0, 331.0, 448.0, 432.0], merge_dicts([v_fur_27, {"normal": [(-0.12), (-0.6), 0.7], "height": foldField([[[379.0, 348.0], [368.0, 378.0], [403.0, 401.0], [427.0, 409.0], 14.0, 12.0]])}])])
			invoke_member(v_p_25, "surface", ["M477 336 Q480 367 443 388 L474 420 Q526 394 519 359Z", [437.0, 330.0, 532.0, 427.0], merge_dicts([v_fur_27, {"color": mix(v_lining_12, getv(v_C_3, "clothShadow"), 0.2), "normal": [0.26, (-0.45), 0.8], "height": foldField([[[492.0, 346.0], [511.0, 369.0], [487.0, 396.0], [474.0, 406.0], 14.0, 12.0]])}])])
	v_config_1["headwork"] = func(v_p_28):
		invoke(v_head_10, [v_p_28])
		if truth(((getv(v_k_6, "head") == "workcap") if truth(v_cold_7) else v_cold_7)):
			for v_item_29 in [[379.0, (-1.0)], [504.0, 1.0]]:
				var v_unpack_30: Variant = v_item_29
				var v_x_31: Variant = getv(v_unpack_30, 0)
				var v_side_32: Variant = getv(v_unpack_30, 1)
				invoke_member(v_p_28, "surface", [("M" + text_value(v_x_31) + " 228 L" + text_value(add(v_x_31, (v_side_32 * 15.0))) + " 246 L" + text_value(add(v_x_31, (v_side_32 * 8.0))) + " 302 L" + text_value((v_x_31 - (v_side_32 * 13.0))) + " 300 L" + text_value((v_x_31 - (v_side_32 * 10.0))) + " 251Z"), [(v_x_31 - 25.0), 221.0, add(v_x_31, 25.0), 309.0], merge_dicts([v_fabric_11, {"color": v_front_13, "normal": [(v_side_32 * 0.3), 0.0, 1.0], "height": make_field("return (4.0*exp((-pow(((x-((@0@<0.0)?373.0:509.0))/15.0),2.0))));", [v_side_32])}])])
		var v_cover_33: Variant = (mix(getv(v_C_3, "outer"), "#52606c", 0.48) if truth(v_cold_7) else mix(getv(v_C_3, "outer"), "#796656", 0.52))
		if truth((getv(v_k_6, "head") == "brim")):
			invoke_member(v_p_28, "stroke", ["M401 296 Q422 322 452 329", mix(getv(v_C_3, "salt"), getv(v_C_3, "clothShadow"), 0.76), 2.0, 0.4])
			return
		if truth(((getv(v_k_6, "head") == "tiedhair") if truth((getv(v_d_5, "cover") < 0.3)) else (getv(v_d_5, "cover") < 0.3))):
			invoke_member(v_p_28, "surface", ["M389 255 Q438 244 504 259 L500 321 Q471 354 446 348 L398 326Z", [383.0, 238.0, 511.0, 359.0], merge_dicts([v_fabric_11, {"color": mix(getv(v_C_3, "outer"), getv(v_C_3, "clothShadow"), 0.65), "shadow": getv(v_C_3, "clothShadow"), "exposure": 0.62, "normal": [(-0.1), (-0.3), 1.0], "height": foldField([[[400.0, 258.0], [407.0, 288.0], [415.0, 325.0], [427.0, 340.0], 8.0, 4.0], [[466.0, 253.0], [466.0, 285.0], [480.0, 313.0], [476.0, 334.0], 9.0, 4.0]])}])])
			invoke_member(v_p_28, "stroke", ["M391 258 Q442 250 501 263", getv(v_C_3, "copper"), 1.5, 0.45])
			return
		invoke_member(v_p_28, "surface", ["M393 283 Q414 271 437 265 L454 252 Q466 269 504 278 L499 311 Q475 337 454 338 Q419 331 399 311Z", [387.0, 246.0, 511.0, 345.0], merge_dicts([v_fabric_11, {"color": v_cover_33, "shadow": mix(getv(v_C_3, "clothShadow"), v_cover_33, 0.16), "normal": [(-0.16), (-0.38), 0.91], "exposure": 0.65, "height": foldField([[[453.0, 257.0], [449.0, 278.0], [448.0, 299.0], [454.0, 327.0], 16.0, 7.0], [[403.0, 294.0], [429.0, 307.0], [474.0, 313.0], [496.0, 291.0], 12.0, 4.0]])}])])
		invoke_member(v_p_28, "stroke", ["M401 306 Q446 318 495 306", mix(v_cover_33, getv(v_C_3, "clothShadow"), 0.5), 1.6, 0.5])
		if truth(((getv(v_d_5, "cover") > 0.5) if truth((not truth(v_cold_7))) else (not truth(v_cold_7)))):
			invoke_member(v_p_28, "surface", ["M491 302 Q525 333 512 391 L494 415 Q506 352 478 331Z", [472.0, 296.0, 534.0, 422.0], merge_dicts([v_fabric_11, {"color": v_cover_33, "height": foldField([[[493.0, 316.0], [520.0, 340.0], [502.0, 378.0], [501.0, 406.0], 9.0, 8.0]])}])])
		invoke_member(v_p_28, "stroke", ["M416 260 Q438 249 450 252", mix(getv(v_C_3, "salt"), getv(v_C_3, "clothShadow"), 0.63), 2.0, 0.38])
