extends SceneTree
## Explicit PUBLIC-RECEIPT PRESENTATION FIXTURES on a real Production host.
## These three dice are not claimed to be natural Session gameplay. The probe
## tests ordering, acceleration, review and cleanup, never rules or balance.
const Production = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var app: Control
var game: Node
var checks := 0
var completions := 0
var settlements := 0

func _initialize() -> void:
	run.call_deferred()

func need(condition: bool, message: String) -> bool:
	checks += 1
	if condition: return true
	push_error("DICE_QUEUE: "+message)
	quit(1)
	return false

func fixture_check(roll: int, target: int, title: String) -> Dictionary:
	return {"roll":roll,"target":target,"outcome":"success" if roll<=target else "failure",
		"label":"成功" if roll<=target else "失败","title":title,"subject":"公开回执夹具","detail":""}

func fixture_batch(title: String, dice: Array, consequence: String, resources: String) -> Dictionary:
	return {"title":title,"card":{},"checks":dice,"lines":[consequence],"resources":resources,
		"turn":1,"context":{"fixture":"public_receipt_presentation_only"}}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	app._input(event)

func text_under(node: Node) -> String:
	var text := ""
	if node is RichTextLabel: text += node.get_parsed_text()+"\n"
	elif node is Label: text += node.text+"\n"
	for child: Node in node.get_children(): text += text_under(child)
	return text

func settle() -> void:
	# Advance the actual animation component, not its result or finished signal.
	app._dice._dice_pair._process(3.0)

func run() -> void:
	root.size = Vector2i(1280,720)
	game = Production.instantiate()
	app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
	var directory := ProjectSettings.globalize_path("user://dice-queue-probe/%d" % Time.get_ticks_usec())
	app.session = Session.new(directory)
	app.display_settings_path = directory.path_join("display.cfg")
	root.add_child(game)
	app._start_new(1)
	var deadline := Time.get_ticks_msec()+180000
	while app._portraits.preparing and Time.get_ticks_msec()<deadline: await process_frame
	if not need(not app._portraits.preparing,"portrait preparation deadline"): return
	for frame: int in 3: await process_frame
	if app._arrival.visible: app._arrival.close()
	for frame: int in 3: await process_frame
	if not need(app.projection.phase=="actions" and app._dialog.is_empty(),"actual host in action phase"): return
	var original: String = app.session.turn.snapshot()
	var sequence: int = app.session.turn.commit_sequence
	var batch_a := fixture_batch("公开回执夹具甲",[
		fixture_check(42,64,"甲 · 第一项"),fixture_check(42,64,"甲 · 第二项")],
		"甲批后果：记录已封存。","低语 3 → 2")
	var batch_b := fixture_batch("公开回执夹具乙",[fixture_check(91,40,"乙 · 第一项")],
		"乙批后果：联系未能建立。","信仰 18 → 16")
	app._dice.finished.connect(func(): completions += 1)
	app._dice.enqueue(app,batch_a)
	app._dice._dice_pair.sound_enabled = false
	app._dice._dice_pair.settled.connect(func(): settlements += 1)
	app._dice.enqueue(app,batch_b)
	if not need(app._dice._batches.size()==2 and app._dice._entries==[{"batch":0,"check":0},{"batch":0,"check":1},{"batch":1,"check":0}],"same-valued checks preserve both batches and exact order"): return
	if not need(not app._stage.visible,"fixture covers real underlying scene"): return
	key(KEY_ESCAPE)
	if not need(app._dice_active() and app._dice._index==0 and not app._dice._revealed and app._dice._dice_pair.rolling and app._dice._dice_pair._speed>1,"Esc accelerates instead of cancelling or skipping"): return
	settle()
	if not need(app._dice._revealed and app._dice._total.text=="42 点" and settlements==1,"first true fixture value settles once"): return
	var reading := text_under(app._dice._reading)
	if not need(not "甲批后果" in reading and not "低语 3 → 2" in reading and not "乙批后果" in reading,"batch effects wait for every check"): return
	key(KEY_RIGHT)
	if not need(app._dice._index==1 and app._dice._dice_pair.rolling and not app._dice._revealed,"equal second die still gets its own animation"): return
	settle()
	reading = text_under(app._dice._reading)
	if not need(settlements==2 and "甲批后果" in reading and "低语 3 → 2" in reading and not "乙批后果" in reading and not "信仰 18 → 16" in reading,"first batch reveals only its own consequences and resources"): return
	key(KEY_LEFT)
	if not need(app._dice._index==0 and app._dice._revealed and not app._dice._dice_pair.rolling and settlements==2,"review is static and does not settle or reroll again"): return
	reading = text_under(app._dice._reading)
	if not need("甲批后果" in reading and "低语 3 → 2" in reading and not "乙批后果" in reading,"reviewing first die retains now-revealed batch consequences"): return
	key(KEY_RIGHT)
	if not need(app._dice._index==1 and not app._dice._dice_pair.rolling and settlements==2,"forward review remains static"): return
	key(KEY_RIGHT)
	if not need(app._dice._index==2 and app._dice._dice_pair.rolling and app._dice._title.text=="公开回执夹具乙","next batch starts after complete first batch"): return
	settle()
	reading = text_under(app._dice._reading)
	if not need(settlements==3 and app._dice._total.text=="91 点" and "乙批后果" in reading and "信仰 18 → 16" in reading and not "甲批后果" in reading and not "低语 3 → 2" in reading,"second batch value and resource accounting stay separate"): return
	key(KEY_LEFT)
	if not need(app._dice._title.text=="公开回执夹具甲" and not app._dice._dice_pair.rolling and settlements==3,"cross-batch review does not replay motion"): return
	key(KEY_RIGHT)
	key(KEY_ESCAPE)
	if not need(not app._dice_active() and completions==1 and app._stage.visible,"final Esc closes once and restores host"): return
	app._dice.handle_input(InputEventKey.new())
	app._dice._advance()
	if not need(completions==1,"closed presenter cannot finish twice"): return
	if not need(app.session.turn.snapshot()==original and app.session.turn.commit_sequence==sequence,"queue presentation leaves entire Session and RNG unchanged"): return
	print("DICE_QUEUE_OK ",checks," public_receipt_fixtures=2 checks=3 real_rolls_claimed=0 settlements=",settlements," finished=",completions)
	game.free()
	quit()
