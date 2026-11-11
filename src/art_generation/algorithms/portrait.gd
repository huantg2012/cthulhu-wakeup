extends "res://src/art_generation/algorithms/drawing_math.gd"
## Native GDScript port of the existing 2D drawing rules. No browser runtime.
## Source: portrait.js; preserve contours, ordering and seed decisions.
const M_world = preload("res://src/art_generation/algorithms/world.gd")

static func portrait(v_personSeed_1 = null, v_worldSeed_2 = null, v_world_3 = null, v_config_4 = null):
	if v_personSeed_1 == null:
		v_personSeed_1 = 1339.0
	if v_worldSeed_2 == null:
		v_worldSeed_2 = 1339.0
	if v_world_3 == null:
		v_world_3 = M_world.tide
	if v_config_4 == null:
		v_config_4 = merge_dicts([])
	var v_r_5: Variant = rng(v_personSeed_1)
	var v_tension_6: Variant = (add(0.92, (invoke(v_r_5, []) * 0.15)) * or_value(getv(v_config_4, "tension"), 1.0))
	var v_C_7: Variant = or_value(getv(v_config_4, "colors"), M_world.roles(v_world_3))
	var v_ellipse_8: Variant = ellipse
	var v_Painter_9: Variant = Painter
	var v_p_10: Variant = Painter.new(v_personSeed_1, {"emitters": or_value(getv(v_config_4, "emitters"), [{"x": 480.0, "y": 568.0, "z": 70.0, "r": 245.0, "color": [96.0, 235.0, 178.0], "power": 0.24}])})
	v_p_10.configure(v_config_4)
	var v_dark_11: Variant = {"mat": "cloth", "color": getv(v_C_7, "cloth"), "shadow": getv(v_C_7, "clothShadow"), "accent": getv(v_C_7, "salt"), "salt": 0.18, "bump": 0.85}
	var v_pale_12: Variant = {"mat": "cloth", "color": getv(v_C_7, "linen"), "shadow": getv(v_C_7, "linenShadow"), "accent": getv(v_C_7, "salt"), "salt": 0.34, "bump": 0.8}
	var v_bronze_13: Variant = {"mat": "metal", "color": getv(v_C_7, "copper"), "shadow": getv(v_C_7, "wet"), "accent": "#dfc891", "bump": 0.7}
	var v_root_14: Variant = or_value(getv(v_config_4, "root"), "M365 339 Q325 357 298 397 C272 430 253 486 243 535 Q226 586 241 638 C255 674 283 691 307 694 L277 935 Q439 976 691 933 L667 705 Q705 647 691 589 C684 517 651 451 616 414 Q582 375 533 365 L491 340Z")
	var v_mainFolds_15: Variant = foldField([[[359.0, 371.0], [341.0, 470.0], [366.0, 539.0], [337.0, 677.0], 18.0, (16.0 * v_tension_6)], [[381.0, 415.0], [409.0, 493.0], [369.0, 700.0], [345.0, 937.0], 19.0, 18.0], [[425.0, 471.0], [472.0, 571.0], [416.0, 738.0], [429.0, 959.0], 21.0, 17.0], [[475.0, 540.0], [518.0, 666.0], [475.0, 804.0], [498.0, 968.0], 15.0, 13.0], [[550.0, 479.0], [604.0, 610.0], [549.0, 736.0], [611.0, 935.0], 21.0, 16.0], [[601.0, 442.0], [632.0, 537.0], [631.0, 660.0], [657.0, 742.0], 13.0, 10.0]], make_field("return ((32.0*exp((-pow(((x-425.0)/163.0),2.0))))-(0.065*(x-430.0)));", []))
	invoke_member(v_p_10, "surface", [v_root_14, or_value(getv(v_config_4, "rootBox"), [225.0, 336.0, 708.0, 960.0]), merge_dicts([v_dark_11, {"height": or_value(getv(v_config_4, "rootHeight"), v_mainFolds_15), "u": make_field("return (x+(sin((y*0.007))*19.0));", []), "shadowField": make_field("return clamp((0.98-((x-430.0)*0.0014)),0.42,1.0);", []), "wet": make_field("return clamp(((y-820.0)/220.0),0.0,1.0);", [])}])])
	if truth((not truth(getv(v_config_4, "arms")))):
		invoke_member(v_p_10, "shadow", ["M526 372 Q605 407 647 477 Q682 538 682 604 L644 672 L579 639 Q625 550 584 493 Q552 440 526 372Z", 0.32, 10.0])
		invoke_member(v_p_10, "shadow", ["M337 676 Q372 643 426 634 L579 665 Q554 701 482 699 L374 713Z", 0.38, 12.0])
	var v_stole_16: Variant = "M408 402 Q448 421 477 410 L535 944 L406 960 Q424 743 395 538Z"
	if truth((not truth(getv(v_config_4, "suppressStole")))):
		invoke_member(v_p_10, "surface", [v_stole_16, [391.0, 400.0, 540.0, 960.0], merge_dicts([v_dark_11, {"color": getv(v_C_7, "violet"), "shadow": getv(v_C_7, "clothShadow"), "accent": mix(getv(v_world_3, "nebula"), getv(v_world_3, "c3"), 0.4), "height": foldField([[[422.0, 423.0], [443.0, 581.0], [425.0, 737.0], [441.0, 954.0], 9.0, 7.0], [[453.0, 443.0], [481.0, 612.0], [457.0, 771.0], [494.0, 954.0], 12.0, 9.0]]), "normal": [0.15, 0.08, 1.0], "exposure": 0.7}])])
	invoke_member(getv(v_config_4, "layers"), "underSleeves", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	if truth(getv(v_config_4, "arms")):
		invoke_member(v_config_4, "arms", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	else:
		var v_sleeve_17: Variant = "M319 397 Q288 434 272 486 C253 531 239 578 246 618 Q256 666 291 697 Q332 702 362 674 L435 615 L429 578 Q382 598 351 581 Q330 555 332 514 Q343 463 351 424Z"
		var v_armFolds_18: Variant = foldField([[[322.0, 423.0], [298.0, 486.0], [271.0, 577.0], [280.0, 657.0], 22.0, 6.0], [[427.0, 587.0], [394.0, 622.0], [332.0, 670.0], [288.0, 686.0], 15.0, 12.0], [[420.0, 607.0], [378.0, 643.0], [334.0, 666.0], [312.0, 697.0], 10.0, 8.0], [[315.0, 515.0], [307.0, 551.0], [343.0, 588.0], [399.0, 590.0], 10.0, (-3.0)], [[287.0, 569.0], [301.0, 611.0], [331.0, 626.0], [367.0, 620.0], 17.0, 5.0]], make_field("return (7.0*exp((-pow(((x-300.0)/100.0),2.0))));", []))
		invoke_member(v_p_10, "surface", [v_sleeve_17, [239.0, 392.0, 439.0, 707.0], merge_dicts([v_dark_11, {"color": mix(getv(v_C_7, "cloth"), getv(v_C_7, "linen"), 0.15), "height": v_armFolds_18, "u": make_field("return (x-(y*0.15));", []), "v": make_field("return y;", []), "shadowField": make_field("return clamp((1.0-((x-300.0)*0.001)),0.7,1.0);", [])}])])
		invoke_member(v_p_10, "shadow", ["M327 535 Q324 565 341 577 L369 586 Q344 591 332 578 Q319 558 327 535Z", 0.35, 3.0])
		invoke_member(v_p_10, "stroke", ["M273 588 Q278 616 306 632", "#9ba888", 2.0, 0.32])
		invoke_member(v_p_10, "stroke", ["M307 683 Q345 656 386 632", "#526f59", 2.0, 0.42])
		var v_far_19: Variant = "M628 480 Q663 530 679 578 Q695 626 662 674 L627 694 Q594 682 575 652 L529 613 L539 577 L606 594 Q620 578 613 549 L601 532Z"
		invoke_member(v_p_10, "surface", [v_far_19, [525.0, 478.0, 695.0, 699.0], merge_dicts([v_dark_11, {"color": (mix(getv(v_C_7, "cloth"), getv(v_C_7, "clothShadow"), 0.12) if truth(getv(v_config_4, "colors")) else "#4a6a5d"), "height": foldField([[[623.0, 516.0], [632.0, 556.0], [641.0, 584.0], [625.0, 609.0], 18.0, 7.0], [[541.0, 598.0], [580.0, 632.0], [627.0, 663.0], [651.0, 679.0], 17.0, 9.0], [[624.0, 560.0], [631.0, 581.0], [632.0, 600.0], [615.0, 602.0], 6.0, (-7.0)]], make_field("return (8.0*exp((-pow(((y-611.0)/57.0),2.0))));", [])), "normal": [0.28, 0.0, 1.0], "shadowField": make_field("return 0.65;", [])}])])
		invoke_member(v_p_10, "stroke", ["M562 618 Q602 650 632 665", "#749278", 2.0, 0.32])
	if truth(getv(v_config_4, "collar")):
		invoke_member(v_config_4, "collar", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	else:
		var v_cowl_20: Variant = "M363 319 Q404 337 447 329 L532 351 Q568 379 615 415 L590 474 Q535 471 486 447 Q420 425 371 401 Q337 414 306 450 Q310 405 330 376Z"
		var v_neckFolds_21: Variant = foldField([[[365.0, 334.0], [378.0, 381.0], [483.0, 397.0], [565.0, 423.0], 16.0, 16.0], [[350.0, 366.0], [402.0, 397.0], [484.0, 440.0], [585.0, 448.0], 10.0, 14.0], [[341.0, 392.0], [368.0, 382.0], [407.0, 416.0], [459.0, 422.0], 8.0, 8.0], [[499.0, 352.0], [529.0, 380.0], [565.0, 410.0], [596.0, 421.0], 11.0, 9.0]], make_field("return ((12.0*exp((-pow(((y-380.0)/50.0),2.0))))-(0.03*(x-400.0)));", []))
		invoke_member(v_p_10, "surface", [v_cowl_20, [300.0, 315.0, 620.0, 481.0], merge_dicts([v_pale_12, {"height": v_neckFolds_21, "u": make_field("return x;", []), "v": make_field("return (y-(0.35*x));", []), "shadowField": make_field("return clamp((1.0-((x-440.0)*0.002)),0.5,1.0);", [])}])])
		invoke_member(v_p_10, "shadow", ["M373 400 Q450 453 514 464 Q554 479 588 471 L583 485 Q518 490 466 465 Q411 438 373 400Z", 0.55, 2.0])
		invoke_member(v_p_10, "stroke", ["M333 392 Q358 369 386 394 Q480 450 574 455", "#d2cfaa", 2.4, 0.68])
		invoke_member(v_p_10, "surface", ["M327 413 Q337 399 347 411 L353 432 Q348 444 337 440 L329 434Z", [325.0, 398.0, 357.0, 447.0], merge_dicts([v_bronze_13, {"height": make_field("return (4.0*exp((-pow(((x-339.0)/9.0),2.0))));", []), "normal": [(-0.4), (-0.2), 1.0], "exposure": 0.65}])])
		invoke_member(v_p_10, "line", ["M333 415 Q340 410 345 418 L344 432 Q340 436 337 429Z", "#d5c18b", 1.6, 0.8])
		var v_i_22: Variant = 0.0
		while truth((v_i_22 < 9.0)):
			invoke_member(v_p_10, "line", [("M" + text_value(add(344.0, (v_i_22 * 3.3))) + "," + text_value(add(add(437.0, (sin(((v_i_22 / 9.0) * PI)) * 11.0)), (v_i_22 * 2.0))) + "l3,3"), "#8d9b78", 1.5, 0.7])
			v_i_22 += 1
	if truth(getv(v_config_4, "headwork")):
		invoke_member(v_config_4, "headwork", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	else:
		var v_hood_23: Variant = or_value(getv(v_config_4, "hood"), "M355 348 C331 317 329 267 349 221 C367 182 398 153 425 145 Q458 137 490 164 C519 185 538 222 536 253 Q538 281 516 311 Q495 339 485 365 Q420 382 355 348Z")
		var v_hoodFolds_24: Variant = foldField([[[424.0, 155.0], [389.0, 187.0], [361.0, 245.0], [364.0, 315.0], 13.0, 11.0], [[450.0, 159.0], [431.0, 180.0], [397.0, 214.0], [384.0, 260.0], 12.0, 10.0], [[367.0, 286.0], [369.0, 331.0], [405.0, 355.0], [452.0, 353.0], 10.0, 14.0], [[497.0, 196.0], [532.0, 234.0], [527.0, 271.0], [510.0, 293.0], 9.0, 7.0]], make_field("return (23.0*exp(((-pow(((x-416.0)/91.0),2.0))-pow(((y-242.0)/143.0),2.0))));", []))
		invoke_member(v_p_10, "surface", [v_hood_23, or_value(getv(v_config_4, "hoodBox"), [328.0, 137.0, 543.0, 382.0]), merge_dicts([v_pale_12, {"height": or_value(getv(v_config_4, "hoodFolds"), v_hoodFolds_24), "u": make_field("return (x+((y-190.0)*0.28));", []), "shadowField": make_field("return clamp((1.0-((x-418.0)*0.003)),0.36,1.0);", []), "color": getv(v_C_7, "linen")}])])
		var v_opening_25: Variant = or_value(getv(v_config_4, "opening"), "M395 247 Q419 217 449 217 Q481 223 503 249 L501 279 Q482 309 460 326 Q428 332 404 312 L390 286Z")
		invoke_member(v_p_10, "surface", [v_opening_25, [385.0, 212.0, 509.0, 333.0], {"mat": "plain", "color": "#0b1d25", "normal": [0.3, 0.3, 1.0], "exposure": 0.3}])
		invoke_member(v_p_10, "shadow", ["M397 247 Q425 215 453 219 Q481 229 503 252 L502 271 Q465 236 433 248 L393 280Z", 0.65, 3.0])
		invoke_member(v_p_10, "surface", ["M402 296 Q430 318 458 312 L491 294 Q475 326 454 340 Q426 341 405 325Z", [398.0, 292.0, 493.0, 345.0], merge_dicts([v_dark_11, {"color": "#53766a", "height": foldField([[[405.0, 306.0], [433.0, 332.0], [461.0, 318.0], [484.0, 304.0], 5.0, 4.0]]), "normal": [0.1, (-0.1), 1.0], "exposure": 0.6}])])
		if truth((not truth(getv(v_config_4, "headStrokes")))):
			invoke_member(v_p_10, "stroke", ["M400 246 Q427 213 451 220 Q480 226 501 250", "#d0cba2", 2.5, 0.65])
			invoke_member(v_p_10, "stroke", ["M350 270 Q350 223 388 184", "#d9d4ad", 2.0, 0.55])
			invoke_member(v_p_10, "stroke", ["M370 324 Q402 357 448 357", "#8ba88e", 2.3, 0.5])
		else:
			invoke_member(v_config_4, "headStrokes", [v_p_10])
		invoke_member(getv(v_config_4, "layers"), "face", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	if truth((not truth(getv(v_config_4, "collar")))):
		var v_i_26: Variant = 0.0
		while truth((v_i_26 < 43.0)):
			var v_t_27: Variant = (v_i_26 / 42.0)
			var v_x_28: Variant = add(378.0, (v_t_27 * 202.0))
			var v_y_29: Variant = add(415.0, (46.0 * sin((v_t_27 * 1.1))))
			var v_a_30: Variant = add(0.4, (v_t_27 * 0.2))
			invoke_member(v_p_10, "line", [("M" + text_value(v_x_28) + "," + text_value(v_y_29) + "l" + text_value(((2.0 * cos(v_a_30)) - (4.0 * sin(v_a_30)))) + "," + text_value(add((2.0 * sin(v_a_30)), (4.0 * cos(v_a_30)))) + ""), "#b3b08a", 0.75, 0.5])
			v_i_26 += 1
	if truth(getv(v_config_4, "handwork")):
		invoke_member(v_config_4, "handwork", [v_p_10, {"dark": v_dark_11, "pale": v_pale_12, "bronze": v_bronze_13}])
	else:
		for v_item_31 in [["M410 581 L429 571 Q447 589 445 610 L427 625 Q421 600 410 581Z", [407.0, 568.0, 450.0, 628.0], false], ["M532 573 L553 581 Q548 606 537 622 L518 611Z", [515.0, 570.0, 558.0, 625.0], true]]:
			var v_unpack_32: Variant = v_item_31
			var v_d_33: Variant = getv(v_unpack_32, 0)
			var v_b_34: Variant = getv(v_unpack_32, 1)
			var v_flip_35: Variant = getv(v_unpack_32, 2)
			invoke_member(v_p_10, "surface", [v_d_33, v_b_34, merge_dicts([v_pale_12, {"color": "#9aab8c", "height": make_field("return (3.0*sin(((y*0.2)+(x*0.1))));", []), "normal": [(0.2 if truth(v_flip_35) else (-0.3)), (-0.2), 1.0], "exposure": 0.75}])])
		if truth(getv(v_config_4, "drawObject")):
			invoke_member(v_config_4, "drawObject", [v_p_10, {"bronze": v_bronze_13, "pale": v_pale_12, "dark": v_dark_11}])
		else:
			invoke_member(v_p_10, "surface", ["M427 566 Q480 547 535 566 L524 609 Q481 630 440 606Z", [425.0, 550.0, 537.0, 631.0], merge_dicts([v_bronze_13, {"color": "#788a65", "height": make_field("return (10.0*exp((-pow(((x-477.0)/50.0),2.0))));", []), "normal": [0.0, 0.25, 1.0]}])])
			invoke_member(v_p_10, "surface", [invoke(v_ellipse_8, [480.0, 567.0, 56.0, 17.0]), [423.0, 548.0, 538.0, 586.0], merge_dicts([v_bronze_13, {"color": "#cabf89", "normal": [0.0, (-0.65), 0.72]}])])
			invoke_member(v_p_10, "surface", [invoke(v_ellipse_8, [480.0, 567.0, 47.0, 11.0]), [431.0, 555.0, 529.0, 579.0], {"mat": "water", "color": "#72cba1", "shadow": "#09262e", "cx": 480.0, "cy": 567.0, "v": make_field("return (567.0+((y-567.0)*3.0));", []), "emission": 0.16, "normal": [0.0, (-0.8), 0.6], "bump": 0.35}])
			invoke_member(v_p_10, "glow", [479.0, 565.0, 58.0, "#70f9b1", 0.11])
			invoke_member(v_p_10, "line", ["M437 566 Q478 551 507 563", "#a3ce9d", 1.2, 0.55])
		var v_skin_36: Variant = {"mat": "skin", "color": "#9e8c70", "shadow": "#76604e", "accent": "#cbb48b", "bump": 0.45, "exposure": 0.66}
		invoke_member(v_p_10, "surface", ["M433 585 Q443 582 449 589 L455 600 Q471 606 484 609 Q490 612 486 616 L469 617 Q451 615 443 608 L437 603 L429 606Z", [426.0, 581.0, 491.0, 620.0], merge_dicts([v_skin_36, {"height": foldField([[[436.0, 593.0], [451.0, 605.0], [468.0, 607.0], [484.0, 613.0], 5.0, 3.0]]), "normal": [(-0.25), (-0.1), 1.0]}])])
		invoke_member(v_p_10, "surface", ["M529 585 Q522 578 514 581 L503 588 Q499 590 502 594 Q505 596 512 591 L515 592 L510 605 Q503 614 491 616 Q486 618 489 622 Q507 624 518 613 L529 604 L537 607Z", [484.0, 576.0, 541.0, 629.0], merge_dicts([v_skin_36, {"normal": [0.05, (-0.2), 1.0], "height": make_field("return (3.0*exp((-pow(((y-603.0)/11.0),2.0))));", [])}])])
		invoke_member(v_p_10, "stroke", ["M445 601 Q465 611 481 612", "#dfcba6", 1.2, 0.65])
		invoke_member(v_p_10, "line", ["M450 608 Q465 615 477 615", "#615b46", 0.85, 0.6])
		invoke_member(v_p_10, "stroke", ["M514 602 Q508 617 495 618", "#c9c9a2", 1.1, 0.65])
		invoke_member(v_p_10, "line", ["M519 605 Q512 617 505 619", "#685e49", 0.9, 0.5])
		invoke_member(v_p_10, "line", ["M444 610 Q459 621 478 622", "#192e2b", 1.7, 0.7])
		var v_i_37: Variant = 0.0
		while truth((v_i_37 < 31.0)):
			var v_x_38: Variant = add(426.0, (invoke(v_r_5, []) * 10.0))
			var v_y_39: Variant = add(582.0, (invoke(v_r_5, []) * 34.0))
			invoke_member(v_p_10, "stroke", [("M" + text_value(v_x_38) + "," + text_value(v_y_39) + "l2,-3"), "#d1c99d", 0.7, 0.24])
			v_i_37 += 1
	var v_i_40: Variant = 0.0
	while truth((v_i_40 < 34.0)):
		var v_y_41: Variant = add(703.0, (v_i_40 * 6.0))
		var v_x_42: Variant = add(324.0, (sin((v_y_41 * 0.017)) * 6.0))
		invoke_member(v_p_10, "line", [("M" + text_value(v_x_42) + "," + text_value(v_y_41) + "l2,3"), "#7b9a80", 0.75, 0.35])
		v_i_40 += 1
	invoke_member(v_p_10, "reframe", [or_value(getv(v_config_4, "framing"), [1.14, (-60.0), (-48.0)])])
	invoke_member(v_p_10, "fade", [855.0])
	return {"p": invoke_member(v_p_10, "output", []), "features": {"pose": "俯首托持潮水盏", "structure": "颈肩连续披衣；肘与腕约束褶场；掌托与指缘遮挡", "personSeed": v_personSeed_1, "worldSeed": v_worldSeed_2, "materials": ["染色粗布", "盐蚀亚麻", "氧化铜", "湿润皮肤", "发光潮水"], "method": "2D masks + constrained cloth fields + coupled surface channels + illustrated lighting → original NPR"}}
