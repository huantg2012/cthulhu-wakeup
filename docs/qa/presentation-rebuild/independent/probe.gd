extends SceneTree
## Independent bounded contract check. Rendering/aesthetics remain separate.
var app
var game: Node
var checks: Array = []
var evidence := "res://docs/qa/presentation-rebuild/independent"
var started := 0

func _initialize() -> void:
 started = Time.get_ticks_msec()
 create_timer(60.0).timeout.connect(func() -> void: finish(false,"60 second timeout"))
 run.call_deferred()

func finish(ok: bool, reason := "") -> void:
 var file = FileAccess.open(evidence.path_join("results.json"),FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify({"ok":ok,"reason":reason,"seconds":float(Time.get_ticks_msec()-started)/1000.0,"engine":Engine.get_version_info().string,"source_sha256":FileAccess.get_sha256("res://src/presentation/reconstruction/lesson.gd"),"checks":checks,"scope":"Independent current real Session, seed1, synthetic Godot input events and handler checks. No human usability, art acceptance, whole-game, natural-run, optional-preparation or enlarged-text claim."},"\t"))
  file.close()
 if is_instance_valid(game): game.free()
 quit(0 if ok else 1)

func need(ok: bool, description: String, detail = {}) -> bool:
 checks.append({"check":description,"pass":ok,"detail":detail})
 print("INDEPENDENT_QA ",description," ",ok)
 if not ok: finish(false,description)
 return ok

func state() -> String:
 return app.session.turn.snapshot()

func known() -> String:
 return JSON.stringify(app.session.knowledge_snapshot())

func button(id: String) -> Button:
 return app.find_child(id,true,false) as Button

func click(id: String) -> bool:
 var target: Button = button(id)
 if not need(target != null and target.is_visible_in_tree() and not target.disabled,"input target "+id): return false
 var position = target.get_global_rect().get_center()
 var down = InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT; down.position = position; down.global_position = position; down.pressed = true
 root.push_input(down,true)
 await process_frame
 var up = InputEventMouseButton.new()
 up.button_index = MOUSE_BUTTON_LEFT; up.position = position; up.global_position = position; up.pressed = false
 root.push_input(up,true)
 await process_frame
 await process_frame
 return true

func key(code: Key) -> void:
 var down = InputEventKey.new()
 down.keycode = code; down.pressed = true
 root.push_input(down)
 await process_frame
 var up = InputEventKey.new()
 up.keycode = code; up.pressed = false
 root.push_input(up)
 await process_frame

func inside(id: String) -> bool:
 var node = app.find_child(id,true,false)
 return node is Control and node.is_visible_in_tree() and Rect2(0,0,1280,720).encloses(node.get_global_rect())

func run() -> void:
 var packed = load("res://src/presentation/reconstruction/lesson.tscn")
 if not need(packed is PackedScene,"comparison scene loads"): return
 game = packed.instantiate()
 app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
 root.add_child(game)
 await process_frame
 await process_frame
 if not need(app.projection.get("phase") == "actions" and not app.prayer.is_empty(),"real seed1 action window and prayer"): return
 var original: String = state()
 var knowledge: String = known()
 var player = app.session
 var start_hash: String = FileAccess.get_sha256(app._start_path)
 if not need(app.session.save_directory.begins_with("user://presentation-rebuild-review/"),"independent review save directory"): return
 if not await click("OpenPrayer"): return
 if not need(app.page == "detail","mouse opens real request"): return
 if not await click("Mode_deep"): return
 var preview: Dictionary = app._row().get("preview",{}).duplicate(true)
 if not need(preview.get("ok",false),"real deep preview valid"): return
 for index: int in range(3):
  await key([KEY_1,KEY_2,KEY_3][index])
  if not need(app.variant == index and app.session == player,"keyboard variant %d retains Session" % index): return
  if not need(state() == original and known() == knowledge and app._row().get("preview",{}) == preview,"variant %d preserves state, knowledge, preview" % index): return
  for id: String in ["MainHeading","Mode_shallow","Mode_deep","MandatoryCost","OutcomeRisk","FixedPayment","Respond","BackOverview","Probability_disaster","PrayerDue" if index == 1 else "DetailDue"]:
   if not need(inside(id),"variant %d in-frame %s" % [index,id]): return
  var risk: Label = app.find_child("OutcomeRisk",true,false)
  if not need(risk.text.contains("失败") and risk.text.contains("灾变"),"variant %d fixed risks have actual text" % index): return
  if not await click("WorldInfo"): return
  if not need(app.page == "world","variant %d keyboard return starts in world reading" % index): return
  await key(KEY_ESCAPE)
  var returned_focus = root.gui_get_focus_owner()
  if not need(app.page == "detail" and app.mode == "deep" and app._row().get("preview",{}) == preview and returned_focus != null and str(returned_focus.name) == "WorldInfo","variant %d escape restores world source task and focus" % index): return
  if not need(state() == original and known() == knowledge,"variant %d escape browsing is pure" % index): return
  if index == 1:
   if not await click("ReadConsequences"): return
   if not need(app.page == "consequences","B complete consequences opens"): return
   await key(KEY_ESCAPE)
   returned_focus = root.gui_get_focus_owner()
   if not need(app.page == "detail" and app.mode == "deep" and returned_focus != null and str(returned_focus.name) == "ReadConsequences" and app._row().get("preview",{}) == preview and state() == original and known() == knowledge,"B escape returns from consequences without losing preparation"): return
 if not await click("InspectPerson"): return
 if not need(app.page == "person" and button("Respond") == null,"person reading hides execution"): return
 if not await click("BackToPrayer"): return
 if not need(app.page == "detail" and app.mode == "deep" and app._row().get("preview",{}) == preview,"person return restores mode and current preview"): return
 var focus = root.gui_get_focus_owner()
 if not need(focus != null and str(focus.name) == "InspectPerson","person return restores source focus",{"focus":str(focus.name) if focus else "none"}): return
 if not await click("WorldInfo"): return
 if not need(app.page == "world","world opens as related reading"): return
 if not await click("BackWorld"): return
 if not need(app.page == "detail" and app.mode == "deep" and app._row().get("preview",{}) == preview,"world return restores original preparation"): return
 focus = root.gui_get_focus_owner()
 if not need(focus != null and str(focus.name) == "WorldInfo","world return restores source focus"): return
 if not await click("Respond"): return
 if not need(app.page == "confirm" and state() == original and known() == knowledge,"irreversible confirmation is pure"): return
 if not await click("CancelPrayer"): return
 if not need(app.page == "detail" and state() == original and known() == knowledge,"cancel confirmation is pure"): return
 var before: Dictionary = app.projection.duplicate(true)
 if not await click("Respond"): return
 if not await click("ConfirmPrayer"): return
 var after: Dictionary = app.projection.duplicate(true)
 if not need(app.page == "result" and after.get("prayer_response_spent",false) and not app.receipt.is_empty(),"real confirmed result and response spent"): return
 var cost: Dictionary = preview.get("preview",{})
 if not need(int(before.faith)-int(after.faith) == int(cost.get("faith",0)) and int(before.whispers)-int(after.whispers) == int(cost.get("whispers",0)),"real payment matches preview",{"faith":int(before.faith)-int(after.faith),"whispers":int(before.whispers)-int(after.whispers)}): return
 var done: String = state()
 app.respond(true)
 if not need(state() == done,"repeat submit after result has no second payment"): return
 for index: int in range(3):
  app.set_variant(index)
  await process_frame
  if not need(app.page == "result" and state() == done and app.projection.get("prayer_response_spent",false),"result remains spent in variant %d" % index): return
 app.restore_sample()
 await process_frame
 if not need(state() == original and known() == knowledge and app.page == "overview" and not app.projection.get("prayer_response_spent",false),"explicit restore returns exact shared start"): return
 if not need(FileAccess.get_sha256(app._start_path) == start_hash,"review start save unchanged"): return
 finish(true)
