extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: civilian.js; preserve contours, ordering and seed decisions.

static var OUTFIT_NAMES = {"oilcoat": "防潮短外衣", "jerkin": "工作马甲与衬衣", "waistcoat": "排扣背心与衬衣", "workshirt": "日常衬衣", "apron": "皮围裙与工作衫", "tailored": "挺括翻领外衣", "drivercoat": "车夫短外套"}
static var HEAD_NAMES = {"workcap": "劳作软帽", "brim": "压低帽檐", "short_hair": "短发与面部阴影", "tiedhair": "束发与面部阴影", "swept_hair": "侧分发与面部阴影"}
static func configureCivilian(v_config_1, v_recipe_2, v_C_3):
	var v_d_4: Variant = getv(v_recipe_2, "dimensions")
	var v_k_5: Variant = getv(v_recipe_2, "construction")
	var v_b_6: Variant = getv(v_recipe_2, "background")
	var v_waist_7: Variant = (137.0 - (getv(v_d_4, "presentation") * 27.0))
	var v_hip_8: Variant = add(164.0, (getv(v_d_4, "presentation") * 16.0))
	var v_hem_9: Variant = add(743.0, (getv(v_d_4, "hem") * 57.0))
	var v_F_10: Variant = foldField([[[377.0, 400.0], [392.0, 509.0], [363.0, 639.0], [369.0, v_hem_9], 18.0, 11.0], [[439.0, 425.0], [465.0, 540.0], [424.0, 647.0], [446.0, v_hem_9], 18.0, 12.0], [[545.0, 418.0], [566.0, 532.0], [552.0, 670.0], [580.0, v_hem_9], 19.0, 13.0]], make_field("return (17.0*exp((-pow(((x-449.0)/151.0),2.0))));", []))
	v_config_1["sleeveMaterial"] = (getv(v_b_6, "material") if truth((getv(v_k_5, "garment") in ["oilcoat", "drivercoat"])) else "cloth")
	v_config_1["root"] = ("M372 346 Q354 365 343 412 Q348 531 " + text_value((470.0 - v_waist_7)) + " 664 L" + text_value((470.0 - v_hip_8)) + " 949 Q465 968 " + text_value(add(470.0, v_hip_8)) + " 949 L" + text_value(add(470.0, v_waist_7)) + " 664 Q590 512 568 416 Q539 375 491 345Z")
	v_config_1["rootBox"] = [290.0, 337.0, 660.0, 966.0]
	v_config_1["rootHeight"] = v_F_10
	v_config_1["emitters"] = []
	var v_cloth_11: Variant = {"mat": "cloth", "color": getv(v_C_3, "cloth"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "salt"), "salt": 0.1, "bump": 0.7}
	getv(v_config_1, "layers")["underSleeves"] = func(v_p_12, v_arg_13):
		var v_unpack_14: Variant = v_arg_13
		var v_pale_15: Variant = getv(v_unpack_14, "pale")
		var v_bronze_16: Variant = getv(v_unpack_14, "bronze")
		invoke_member(v_p_12, "surface", [("M" + text_value((470.0 - v_waist_7)) + " 697 Q470 726 " + text_value(add(470.0, v_waist_7)) + " 699 L" + text_value(add(470.0, v_hip_8)) + " 949 Q545 968 480 945 L465 804 L456 950 Q365 967 " + text_value((470.0 - v_hip_8)) + " 948Z"), [290.0, 690.0, 658.0, 964.0], merge_dicts([v_cloth_11, {"color": mix(getv(v_C_3, "clothShadow"), "#53574d", 0.48), "height": foldField([[[389.0, 740.0], [374.0, 814.0], [370.0, 886.0], [352.0, 949.0], 19.0, 9.0], [[552.0, 750.0], [568.0, 824.0], [562.0, 891.0], [585.0, 951.0], 21.0, 10.0]]), "exposure": 0.78}])])
		var v_shirt_17: Variant = ("M370 347 Q356 366 350 416 Q350 541 " + text_value(add((470.0 - v_waist_7), 10.0)) + " 668 L" + text_value(((470.0 - v_waist_7) - 2.0)) + " " + text_value(v_hem_9) + " Q449 " + text_value(add(v_hem_9, 23.0)) + " " + text_value(add(470.0, v_waist_7)) + " " + text_value((v_hem_9 - 3.0)) + " L" + text_value((add(470.0, v_waist_7) - 10.0)) + " 665 Q580 521 561 418 Q536 377 489 345Z")
		invoke_member(v_p_12, "surface", [v_shirt_17, [299.0, 340.0, 640.0, add(v_hem_9, 31.0)], merge_dicts([v_cloth_11, {"color": (getv(v_C_3, "cloth") if truth((getv(v_k_5, "garment") == "workshirt")) else getv(v_C_3, "linen")), "height": v_F_10}])])
		invoke_member(v_p_12, "shadow", [("M" + text_value(((470.0 - v_waist_7) - 1.0)) + " " + text_value(v_hem_9) + " Q449 " + text_value(add(v_hem_9, 23.0)) + " " + text_value(add(470.0, v_waist_7)) + " " + text_value((v_hem_9 - 3.0)) + " L" + text_value(add(470.0, v_waist_7)) + " " + text_value(add(v_hem_9, 8.0)) + " Q441 " + text_value(add(v_hem_9, 31.0)) + " " + text_value(((470.0 - v_waist_7) - 3.0)) + " " + text_value(add(v_hem_9, 10.0)) + "Z"), 0.33, 2.0])
		invoke_member(v_p_12, "stroke", [("M461 394 Q474 532 465 " + text_value((v_hem_9 - 8.0)) + ""), getv(v_C_3, "clothShadow"), 2.0, 0.5])
		var v_j_18: Variant = 0.0
		while truth((v_j_18 < 5.0)):
			var v_y_19: Variant = add(443.0, (v_j_18 * 52.0))
			invoke_member(v_p_12, "surface", [ellipse(add(466.0, (sin(v_j_18) * 3.0)), v_y_19, 3.5, 3.5), [458.0, (v_y_19 - 6.0), 474.0, add(v_y_19, 6.0)], merge_dicts([v_bronze_16, {"color": getv(v_C_3, "copper"), "exposure": 0.7}])])
			v_j_18 += 1
		if truth((getv(v_k_5, "garment") == "apron")):
			var v_a_20: Variant = add(374.0, (getv(v_d_4, "panel") * 0.12))
			var v_r_21: Variant = add(561.0, (getv(v_d_4, "panel") * 0.1))
			invoke_member(v_p_12, "surface", [("M" + text_value(add(v_a_20, 12.0)) + " 458 Q466 478 " + text_value((v_r_21 - 8.0)) + " 460 L" + text_value(v_r_21) + " " + text_value(add(v_hem_9, 43.0)) + " Q464 " + text_value(add(v_hem_9, 67.0)) + " " + text_value((v_a_20 - 12.0)) + " " + text_value(add(v_hem_9, 40.0)) + "Z"), [(v_a_20 - 18.0), 452.0, add(v_r_21, 8.0), add(v_hem_9, 72.0)], {"mat": "leather", "color": getv(v_C_3, "outer"), "shadow": mix(getv(v_C_3, "outer"), getv(v_C_3, "clothShadow"), 0.6), "accent": getv(v_C_3, "salt"), "height": foldField([[[add(v_a_20, 22.0), 478.0], [add(v_a_20, 3.0), 579.0], [add(v_a_20, 13.0), 686.0], [add(v_a_20, 3.0), add(v_hem_9, 31.0)], 17.0, 11.0], [[510.0, 485.0], [532.0, 600.0], [509.0, 699.0], [529.0, add(v_hem_9, 49.0)], 23.0, 9.0]])}])
			for v_item_22 in [add(v_a_20, 15.0), (v_r_21 - 25.0)]:
				var v_x_23: Variant = v_item_22
				invoke_member(v_p_12, "surface", [("M" + text_value(v_x_23) + " 458 L" + text_value((v_x_23 - 14.0)) + " 376 L" + text_value(add(v_x_23, 2.0)) + " 374 L" + text_value(add(v_x_23, 16.0)) + " 460Z"), [(v_x_23 - 20.0), 369.0, add(v_x_23, 22.0), 466.0], {"mat": "leather", "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "height": make_field("return (2.0*sin((x*0.11)));", [])}])
			invoke_member(v_p_12, "stroke", [("M" + text_value(add(v_a_20, 27.0)) + " 642 Q471 652 " + text_value((v_r_21 - 26.0)) + " 641 L" + text_value((v_r_21 - 31.0)) + " 705 Q475 720 " + text_value(add(v_a_20, 28.0)) + " 706Z"), getv(v_C_3, "copper"), 2.0, 0.65])
		else:
			if truth((getv(v_k_5, "garment") in ["jerkin", "waistcoat"])):
				var v_bottom_24: Variant = ((v_hem_9 - 12.0) if truth((getv(v_k_5, "garment") == "jerkin")) else (v_hem_9 - 54.0))
				for v_item_25 in [[326.0, 453.0, (-1.0)], [481.0, 611.0, 1.0]]:
					var v_unpack_26: Variant = v_item_25
					var v_l_27: Variant = getv(v_unpack_26, 0)
					var v_r_28: Variant = getv(v_unpack_26, 1)
					var v_side_29: Variant = getv(v_unpack_26, 2)
					var v_vest_30: Variant = ("M" + text_value((376.0 if truth((v_side_29 < 0.0)) else 487.0)) + " 356 Q" + text_value((349.0 if truth((v_side_29 < 0.0)) else 544.0)) + " 377 " + text_value((add(v_l_27, 10.0) if truth((v_side_29 < 0.0)) else (v_r_28 - 35.0))) + " 426 L" + text_value((add(v_l_27, 20.0) if truth((v_side_29 < 0.0)) else (v_r_28 - 18.0))) + " " + text_value(v_bottom_24) + " L" + text_value((add(v_r_28, 10.0) if truth((v_side_29 < 0.0)) else (v_l_27 - 8.0))) + " " + text_value(add(v_bottom_24, 20.0)) + " Q" + text_value((461.0 if truth((v_side_29 < 0.0)) else 470.0)) + " 543 " + text_value((431.0 if truth((v_side_29 < 0.0)) else 496.0)) + " 418Z")
					invoke_member(v_p_12, "surface", [v_vest_30, [(v_l_27 - 8.0), 349.0, add(v_r_28, 17.0), add(v_bottom_24, 28.0)], {"mat": ("leather" if truth((getv(v_k_5, "garment") == "jerkin")) else "cloth"), "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "salt"), "height": foldField([[[(355.0 if truth((v_side_29 < 0.0)) else 575.0), 408.0], [(367.0 if truth((v_side_29 < 0.0)) else 568.0), 515.0], [(370.0 if truth((v_side_29 < 0.0)) else 560.0), 628.0], [(368.0 if truth((v_side_29 < 0.0)) else 572.0), v_bottom_24], 16.0, 10.0]])}])
				invoke_member(v_p_12, "line", [("M440 431 Q459 535 455 " + text_value(add(v_bottom_24, 8.0)) + ""), getv(v_C_3, "copper"), 2.0, 0.65])
				if truth((getv(v_k_5, "garment") == "waistcoat")):
					var v_j_31: Variant = 0.0
					while truth((v_j_31 < 5.0)):
						invoke_member(v_p_12, "surface", [ellipse(472.0, add(475.0, (v_j_31 * 40.0)), 4.0, 4.0), [466.0, add(469.0, (v_j_31 * 40.0)), 478.0, add(481.0, (v_j_31 * 40.0))], merge_dicts([v_bronze_16, {"exposure": 0.7}])])
						v_j_31 += 1
			else:
				if truth((getv(v_k_5, "garment") != "workshirt")):
					for v_item_32 in [[(-1.0), 411.0], [1.0, 513.0]]:
						var v_unpack_33: Variant = v_item_32
						var v_side_34: Variant = getv(v_unpack_33, 0)
						var v_x_35: Variant = getv(v_unpack_33, 1)
						var v_outer_36: Variant = (313.0 if truth((v_side_34 < 0.0)) else 621.0)
						var v_shoulder_37: Variant = (340.0 if truth((v_side_34 < 0.0)) else 575.0)
						var v_edge_38: Variant = add(v_x_35, (v_side_34 * 13.0))
						invoke_member(v_p_12, "surface", [("M" + text_value(v_x_35) + " 353 Q" + text_value(v_shoulder_37) + " 371 " + text_value(v_shoulder_37) + " 425 Q" + text_value((v_outer_36 - (v_side_34 * 19.0))) + " 575 " + text_value((v_outer_36 - (v_side_34 * 10.0))) + " " + text_value(add(v_hem_9, 9.0)) + " L" + text_value(v_edge_38) + " " + text_value(add(v_hem_9, 18.0)) + " Q" + text_value(add(v_x_35, (v_side_34 * 8.0))) + " 551 " + text_value(v_x_35) + " 353Z"), [([v_outer_36, v_x_35].min() - 10.0), 346.0, add([v_outer_36, v_x_35].max(), 15.0), add(v_hem_9, 26.0)], {"mat": getv(v_b_6, "material"), "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "salt"), "height": foldField([[[add(v_x_35, (v_side_34 * 35.0)), 400.0], [add(v_x_35, (v_side_34 * 58.0)), 526.0], [add(v_x_35, (v_side_34 * 39.0)), 665.0], [add(v_x_35, (v_side_34 * 57.0)), add(v_hem_9, 10.0)], 19.0, 11.0]])}])
						var v_px_39: Variant = (355.0 if truth((v_side_34 < 0.0)) else 548.0)
						invoke_member(v_p_12, "stroke", [("M" + text_value(v_px_39) + " 651 l49,2 l-4,57 q-20,10 -44,-2Z"), mix(getv(v_C_3, "outer"), getv(v_C_3, "clothShadow"), 0.5), 2.5, 0.75])
					if truth((getv(v_k_5, "garment") == "tailored")):
						var v_j_40: Variant = 0.0
						while truth((v_j_40 < 4.0)):
							for v_item_41 in [439.0, 497.0]:
								var v_x_42: Variant = v_item_41
								invoke_member(v_p_12, "surface", [ellipse(v_x_42, add(503.0, (v_j_40 * 42.0)), 4.0, 5.0), [(v_x_42 - 6.0), add(496.0, (v_j_40 * 42.0)), add(v_x_42, 6.0), add(510.0, (v_j_40 * 42.0))], merge_dicts([v_bronze_16, {"exposure": 0.85}])])
							v_j_40 += 1
		if truth((getv(v_b_6, "workDetail") in ["net", "harness", "medical_bag"])):
			var v_strap_43: Variant = "M369 383 Q452 502 586 688 L569 706 Q427 527 355 391Z"
			invoke_member(v_p_12, "surface", [v_strap_43, [349.0, 377.0, 595.0, 712.0], {"mat": "leather", "color": mix(getv(v_C_3, "copper"), getv(v_C_3, "clothShadow"), 0.38), "shadow": getv(v_C_3, "clothShadow"), "height": make_field("return (3.0*sin(((x+y)*0.04)));", []), "exposure": 0.8}])
			if truth((getv(v_b_6, "workDetail") == "medical_bag")):
				invoke_member(v_p_12, "surface", ["M551 650 Q589 640 617 668 L626 754 Q586 783 542 751Z", [536.0, 637.0, 633.0, 790.0], {"mat": "leather", "color": getv(v_C_3, "outer"), "shadow": getv(v_C_3, "clothShadow"), "accent": getv(v_C_3, "copper"), "height": foldField([[[551.0, 664.0], [580.0, 685.0], [610.0, 677.0], [620.0, 701.0], 12.0, 6.0]])}])
				invoke_member(v_p_12, "stroke", ["M551 657 Q584 695 618 669", getv(v_C_3, "salt"), 2.0, 0.4])
				var v_j_44: Variant = 0.0
				while truth((v_j_44 < 3.0)):
					invoke_member(v_p_12, "line", [("M" + text_value(add(559.0, (v_j_44 * 13.0))) + " 671l3,27"), getv(v_C_3, "copper"), 2.0, 0.55])
					v_j_44 += 1
		if truth((getv(v_b_6, "workDetail") == "net")):
			var v_net_45: Variant = "M343 685 Q378 701 403 675 L422 804 Q379 844 331 808Z"
			invoke_member(v_p_12, "fill", [v_net_45, mix(getv(v_C_3, "outer"), getv(v_C_3, "clothShadow"), 0.6), 0.8])
			var v_j_46: Variant = 0.0
			while truth((v_j_46 < 7.0)):
				var v_y_47: Variant = add(692.0, (v_j_46 * 17.0))
				invoke_member(v_p_12, "line", [("M341 " + text_value(v_y_47) + " Q376 " + text_value(add(v_y_47, 32.0)) + " " + text_value(add(404.0, (v_j_46 * 2.0))) + " " + text_value((v_y_47 - 4.0)) + ""), getv(v_C_3, "salt"), 1.8, 0.4])
				v_j_46 += 1
			var v_j_48: Variant = 0.0
			while truth((v_j_48 < 5.0)):
				var v_x_49: Variant = add(344.0, (v_j_48 * 14.0))
				invoke_member(v_p_12, "line", [("M" + text_value(v_x_49) + " 693 Q" + text_value(add(v_x_49, 9.0)) + " 758 " + text_value(add(v_x_49, 2.0)) + " 816"), getv(v_C_3, "copper"), 1.5, 0.55])
				v_j_48 += 1
		if truth((getv(v_b_6, "workDetail") == "repair")):
			invoke_member(v_p_12, "surface", ["M357 625 L397 631 L392 679 L351 672Z", [347.0, 620.0, 403.0, 685.0], merge_dicts([v_cloth_11, {"color": mix(getv(v_C_3, "linen"), getv(v_C_3, "outer"), 0.5), "height": make_field("return (1.5*sin((y*0.17)));", [])}])])
			var v_j_50: Variant = 0.0
			while truth((v_j_50 < 8.0)):
				invoke_member(v_p_12, "line", [("M355 " + text_value(add(630.0, (v_j_50 * 5.0))) + "l5,1"), getv(v_C_3, "salt"), 1.0, 0.5])
				v_j_50 += 1
		if truth((getv(v_b_6, "workDetail") == "office_chain")):
			invoke_member(v_p_12, "line", ["M391 444 Q447 503 527 440", getv(v_C_3, "copper"), 2.4, 0.7])
			invoke_member(v_p_12, "surface", ["M462 479 L478 480 L480 498 L465 504Z", [457.0, 474.0, 486.0, 510.0], merge_dicts([v_bronze_16, {"color": getv(v_C_3, "copper"), "exposure": 0.7}])])
	v_config_1["collar"] = func(v_p_51, v_arg_52):
		var v_unpack_53: Variant = v_arg_52
		var v_pale_54: Variant = getv(v_unpack_53, "pale")
		var v_sturdy_55: Variant = (getv(v_k_5, "garment") in ["tailored", "oilcoat", "drivercoat"])
		var v_color_56: Variant = (getv(v_C_3, "outer") if truth(v_sturdy_55) else getv(v_C_3, "linen"))
		invoke_member(v_p_51, "surface", ["M383 346 Q407 358 438 374 L415 421 L366 384Z", [360.0, 340.0, 445.0, 427.0], merge_dicts([v_cloth_11, {"color": v_color_56, "height": foldField([[[385.0, 354.0], [391.0, 377.0], [407.0, 393.0], [417.0, 410.0], 10.0, 7.0]])}])])
		invoke_member(v_p_51, "surface", ["M477 346 Q470 369 438 374 L477 419 L515 380Z", [431.0, 340.0, 522.0, 426.0], merge_dicts([v_cloth_11, {"color": v_color_56, "height": foldField([[[484.0, 355.0], [492.0, 375.0], [480.0, 390.0], [476.0, 409.0], 10.0, 7.0]]), "normal": [0.18, 0.02, 1.0]}])])
		if truth(v_sturdy_55):
			invoke_member(v_p_51, "surface", ["M377 360 L417 420 L393 470 L346 393Z", [340.0, 354.0, 424.0, 477.0], merge_dicts([v_cloth_11, {"color": mix(getv(v_C_3, "outer"), getv(v_C_3, "linen"), 0.12), "height": foldField([[[361.0, 386.0], [380.0, 415.0], [397.0, 438.0], [396.0, 462.0], 11.0, 9.0]])}])])
			invoke_member(v_p_51, "surface", ["M494 355 L461 418 L494 460 L533 392Z", [455.0, 349.0, 539.0, 468.0], merge_dicts([v_cloth_11, {"color": getv(v_C_3, "outer"), "height": foldField([[[519.0, 390.0], [499.0, 414.0], [486.0, 429.0], [492.0, 451.0], 10.0, 8.0]]), "normal": [0.22, 0.0, 1.0]}])])
	v_config_1["headwork"] = func(v_p_57):
		return drawHead(v_p_57, v_recipe_2, v_C_3)
static func drawHead(v_p_58, v_recipe_59, v_C_60):
	var v_d_61: Variant = getv(v_recipe_59, "dimensions")
	var v_k_62: Variant = getv(v_recipe_59, "construction")
	var v_hair_63: Variant = {"mat": "hair", "color": getv(v_C_60, "hair"), "shadow": mix(getv(v_C_60, "hair"), "#061619", 0.66), "accent": getv(v_C_60, "salt"), "bump": 0.4}
	var v_skin_64: Variant = {"mat": "skin", "color": mix("#a28d78", getv(v_C_60, "clothShadow"), 0.33), "shadow": getv(v_C_60, "clothShadow"), "bump": 0.3, "exposure": 0.58}
	invoke_member(v_p_58, "surface", ["M413 304 Q439 327 471 310 L478 352 Q456 384 432 373 L402 346Z", [396.0, 299.0, 485.0, 390.0], merge_dicts([v_skin_64, {"height": foldField([[[417.0, 316.0], [421.0, 334.0], [433.0, 354.0], [444.0, 365.0], 10.0, 3.0]]), "normal": [0.2, 0.1, 1.0], "shadowField": make_field("return 0.55;", [])}])])
	if truth((getv(v_k_62, "head") == "tiedhair")):
		invoke_member(v_p_58, "surface", ["M485 207 Q535 172 549 211 Q551 241 520 249 L506 290 L479 272Z", [474.0, 171.0, 557.0, 298.0], merge_dicts([v_hair_63, {"height": foldField([[[520.0, 189.0], [548.0, 208.0], [531.0, 228.0], [510.0, 233.0], 12.0, 6.0]])}])])
	var v_skull_65: Variant = "M378 244 Q377 203 409 186 Q452 170 486 197 Q512 219 510 255 L505 303 Q484 338 453 348 Q424 343 401 320 L384 287Z"
	invoke_member(v_p_58, "surface", [v_skull_65, [371.0, 172.0, 518.0, 356.0], merge_dicts([v_skin_64, {"color": mix(getv(v_C_60, "clothShadow"), "#766957", 0.48), "exposure": 0.35, "normal": [0.38, 0.15, 1.0], "height": make_field("return ((5.0*exp((-pow(((x-430.0)/58.0),2.0))))-(2.0*exp((-pow(((x-463.0)/17.0),2.0)))));", [])}])])
	invoke_member(v_p_58, "shadow", ["M391 242 Q438 210 506 249 L505 300 Q479 326 455 342 Q424 332 406 316Z", 0.66, 9.0])
	invoke_member(v_p_58, "surface", ["M383 263 Q372 260 375 280 Q378 296 391 296 L394 278Z", [369.0, 255.0, 400.0, 302.0], merge_dicts([v_skin_64, {"exposure": 0.44, "height": make_field("return (2.0*exp((-pow(((x-383.0)/8.0),2.0))));", [])}])])
	invoke_member(v_p_58, "stroke", ["M398 300 Q419 335 451 340", mix(getv(v_C_60, "hair"), getv(v_C_60, "salt"), 0.2), 1.7, 0.32])
	var v_swept_66: Variant = or_value((getv(v_k_62, "head") == "swept_hair"), (getv(v_k_62, "head") == "tiedhair"))
	var v_hairline_67: Variant = ("M374 276 Q357 222 387 194 Q409 169 449 174 Q492 174 512 213 L514 260 Q492 252 483 217 Q456 238 413 233 Q396 252 391 283Z" if truth(v_swept_66) else "M374 280 L365 246 L373 226 L367 213 L389 192 L390 181 L417 183 L433 174 L456 182 L472 179 L495 196 L513 213 L512 267 L496 269 Q488 243 477 236 L465 244 L441 230 L420 240 L409 231 L393 266 L390 289Z")
	invoke_member(v_p_58, "surface", [v_hairline_67, [352.0, 165.0, 521.0, 296.0], merge_dicts([v_hair_63, {"height": foldField([[[390.0, 204.0], [409.0, 181.0], [463.0, 184.0], [497.0, 219.0], 13.0, 8.0], [[385.0, 233.0], [411.0, 209.0], [462.0, 205.0], [492.0, 233.0], 11.0, 7.0]]), "u": make_field("return (x+((y-210.0)*0.35));", []), "flow": make_field("return 0.45;", []), "exposure": 0.85}])])
	var v_j_68: Variant = 0.0
	while truth((v_j_68 < 7.0)):
		invoke_member(v_p_58, "stroke", [("M" + text_value(add(383.0, (v_j_68 * 8.0))) + " " + text_value((224.0 - (v_j_68 * 4.0))) + "Q" + text_value(add(421.0, (v_j_68 * 6.0))) + " " + text_value(add(184.0, (v_j_68 * 2.0))) + " " + text_value(add(484.0, (v_j_68 * 3.0))) + " " + text_value(add(213.0, (v_j_68 * 5.0))) + ""), mix(getv(v_C_60, "hair"), getv(v_C_60, "salt"), 0.2), 1.5, 0.25])
		v_j_68 += 1
	if truth((getv(v_k_62, "head") == "workcap")):
		var v_rise_69: Variant = add(8.0, (getv(v_d_61, "capRise") * 20.0))
		invoke_member(v_p_58, "surface", [("M365 237 Q363 " + text_value((191.0 - v_rise_69)) + " 410 " + text_value((181.0 - v_rise_69)) + " Q466 " + text_value((170.0 - v_rise_69)) + " 506 " + text_value((205.0 - (v_rise_69 * 0.5))) + " L516 239 Q437 252 365 237Z"), [356.0, 140.0, 524.0, 260.0], {"mat": "cloth", "color": mix(getv(v_C_60, "outer"), getv(v_C_60, "hair"), 0.2), "shadow": getv(v_C_60, "clothShadow"), "accent": getv(v_C_60, "salt"), "height": foldField([[[383.0, (201.0 - v_rise_69)], [406.0, (180.0 - v_rise_69)], [461.0, (180.0 - v_rise_69)], [494.0, (212.0 - (v_rise_69 * 0.5))], 16.0, 11.0]])}])
		invoke_member(v_p_58, "surface", ["M366 231 Q438 241 514 230 L528 249 Q460 271 388 257 L357 248Z", [350.0, 223.0, 535.0, 280.0], {"mat": "canvas", "color": mix(getv(v_C_60, "outer"), getv(v_C_60, "clothShadow"), 0.35), "shadow": getv(v_C_60, "clothShadow"), "height": make_field("return (3.0*exp((-pow(((y-246.0)/10.0),2.0))));", []), "normal": [0.0, (-0.3), 1.0]}])
		invoke_member(v_p_58, "shadow", ["M388 260 Q451 263 508 253 L503 297 Q451 285 398 293Z", 0.47, 4.0])
	else:
		if truth((getv(v_k_62, "head") == "brim")):
			var v_crown_70: Variant = add(10.0, (getv(v_d_61, "capRise") * 25.0))
			invoke_member(v_p_58, "surface", [("M381 229 L390 " + text_value((190.0 - v_crown_70)) + " Q439 " + text_value((173.0 - v_crown_70)) + " 486 " + text_value((197.0 - v_crown_70)) + " L503 237Z"), [374.0, 137.0, 511.0, 245.0], {"mat": "canvas", "color": getv(v_C_60, "outer"), "shadow": getv(v_C_60, "clothShadow"), "height": foldField([[[396.0, (192.0 - v_crown_70)], [404.0, (180.0 - v_crown_70)], [462.0, (189.0 - v_crown_70)], [485.0, (205.0 - v_crown_70)], 13.0, 8.0]])}])
			invoke_member(v_p_58, "surface", ["M335 239 Q390 222 443 231 Q501 234 543 257 Q508 278 456 270 Q384 264 335 239Z", [328.0, 216.0, 550.0, 285.0], {"mat": "canvas", "color": mix(getv(v_C_60, "outer"), getv(v_C_60, "clothShadow"), 0.2), "shadow": getv(v_C_60, "clothShadow"), "normal": [(-0.25), (-0.45), 0.8], "height": foldField([[[342.0, 240.0], [398.0, 240.0], [477.0, 261.0], [534.0, 257.0], 11.0, 6.0]])}])
			invoke_member(v_p_58, "shadow", ["M393 266 Q446 263 507 277 L499 311 Q444 295 403 306Z", 0.55, 5.0])
