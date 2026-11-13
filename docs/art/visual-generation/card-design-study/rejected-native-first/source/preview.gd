extends "res://tools/palette-study/preview.gd"
const DesignStudy = preload("res://tools/card-design-study/controller.gd")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var setup_args := PackedStringArray()
	var design := 1
	output = "res://docs/art/visual-generation/card-design-study/evidence"
	for arg: String in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--save="): setup_args.append(arg)
		if arg.begins_with("--design="): design = int(arg.trim_prefix("--design="))
	if setup_args.is_empty(): setup_args.append("--save="+_five_world_save())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await setup(setup_args): return
	study = DesignStudy.new()
	root.add_child(study)
	study.start(app)
	study.select(design)
	var fan: Control = app.find_child("WorldFan",true,false)
	if fan!=null: fan.set_focus(mini(2,fan.cards.size()-1),false)
	print("CARD_DESIGN_READY: real session copy; 1/A 2/B; ",app.projection.domains.size()," worlds")
	if "--capture" in args:
		await _design_evidence()
		if not "--leave-open" in args: quit()

func _design_evidence() -> void:
	var before: String = app.session.turn.snapshot()
	var generated: int = app._portraits.generated_count
	study.badge.hide()
	app._atmosphere.paused = true
	app._atmosphere.set_sample_time(6.0)
	for design: int in [1,2]:
		study.select(design)
		await _park_pointer()
		await capture("worlds-%d" % design)
	var domain: String = app.projection.cults[0].domain if not app.projection.cults.is_empty() else app.projection.domains[0].id
	if not await world(domain): return
	var request := ""
	for card: Dictionary in app._hand_cards:
		if card.group=="prayer": request = card.id; break
	if not request.is_empty() and not await play(request): return
	for design: int in [1,2]:
		study.select(design)
		await _park_pointer()
		await capture("table-%d" % design)
	if card_index("POWER_APPOINT")>=0:
		if not await play("POWER_APPOINT"): return
		for design: int in [1,2]:
			study.select(design)
			await _park_pointer()
			await capture("power-%d" % design)
	if not require(before==app.session.turn.snapshot(),"Design study changed Session"): return
	if not require(generated==app._portraits.generated_count,"Design study regenerated illustration"): return
	print("CARD_DESIGN_CAPTURE: two compositions; real world/prayer/power/stack; Session unchanged; new portraits 0")
	study.select(1)
	study.badge.show()
	app._atmosphere.paused = false
