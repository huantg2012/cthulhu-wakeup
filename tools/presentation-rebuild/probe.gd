extends SceneTree
## Real UI dispatch and finite review captures. No test edits game state.
const Scene = preload("res://src/presentation/reconstruction/lesson.tscn")
var app: Control
var checks: Array = []
var evidence: String
var game: Node
var finished: bool = false

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, name_value: String, details: Dictionary = {}) -> bool:
 checks.append({"name":name_value,"pass":ok,"details":details})
 print("REBUILD_CHECK ",name_value," ",ok)
 if not ok: finish(false)
 return ok

func finish(ok: bool) -> void:
 if finished: return
 finished = true
 var file = FileAccess.open(evidence.path_join("results.json"),FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify({"status":"pass" if ok else "fail","checks":checks,"scope":"Seed 1 real Session and mouse/keyboard events in isolated save directory; 3 visual combinations, no natural full-run or aesthetic acceptance claim."},"\t")+"\n")
  file.close()
 if is_instance_valid(game): game.free()
 quit(0 if ok else 1)

func click(id: String) -> bool:
 var target: Button = app.find_child(id,true,false)
 if not check(target != null and not target.disabled and target.is_visible_in_tree(),"button "+id): return false
 var point = target.get_global_rect().get_center()
 var event = InputEventMouseButton.new()
 event.position = point
 event.global_position = point
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = true
 root.push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event,true)
 await process_frame
 await process_frame
 return true

func key(value: Key) -> void:
 var event = InputEventKey.new()
 event.keycode = value; event.pressed = true
 root.push_input(event,true)
 event = event.duplicate(); event.pressed = false
 root.push_input(event,true)
 await process_frame
 await process_frame

func capture(name_value: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await create_timer(.3).timeout
 RenderingServer.force_draw()
 var frame = root.get_texture().get_image()
 if check(frame.get_size() == Vector2i(1920,1080),"1080p "+name_value):
  frame.save_png(evidence.path_join(name_value+".png"))

func run() -> void:
 var args = OS.get_cmdline_user_args()
 evidence = args[0] if not args.is_empty() else "/tmp/presentation-rebuild-probe"
 DirAccess.make_dir_recursive_absolute(evidence)
 create_timer(75).timeout.connect(func() -> void:
  if not finished:
   checks.append({"name":"bounded 75 second timeout","pass":false})
   finish(false))
 game = Scene.instantiate()
 app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
 root.add_child(game)
 await process_frame
 if not check(app.projection.phase == "actions" and app.prayer.card.content_id == "PRAYER_08","ordinary seed1 actual prayer"): return
 var original = app.session.turn.snapshot()
 for card: int in range(3):
  if not await click("Variant%d" % card): return
  if not check(app.variant == card and app.session.turn.snapshot() == original,"switch preserves Session %d" % card): return
  await capture("%s-01-overview" % app.IDS[card])
  if not await click("OpenPrayer"): return
  if not check(app.page == "detail","mouse opens prayer"): return
  if not await click("Mode_deep"): return
  if not check(app.mode == "deep","mouse selects deep"): return
  await capture("%s-02-detail" % app.IDS[card])
  if not await click("InspectPerson"): return
  if not check(app.page == "person" and app.find_child("Respond",true,false) == null,"person page has no execute"): return
  await capture("%s-03-person" % app.IDS[card])
  if not await click("BackToPrayer"): return
  if not check(app.page == "detail" and app.mode == "deep" and app.session.turn.snapshot() == original,"person return restores choice pure"): return
  if not await click("Respond"): return
  if not check(app.page == "confirm" and app.session.turn.snapshot() == original,"ordinary irreversible gate pure"): return
  await capture("%s-04-confirm" % app.IDS[card])
  if not await click("CancelPrayer"): return
  if not check(app.page == "detail" and app.session.turn.snapshot() == original,"cancel pure"): return
  if not await click("Respond") or not await click("ConfirmPrayer"): return
  if not check(app.page == "result" and app.projection.prayer_response_spent and app.projection.faith == 14 and app.projection.whispers == 1,"actual deep payment and receipt"): return
  await capture("%s-05-result" % app.IDS[card])
  var after = app.session.turn.snapshot()
  await key(KEY_1 if card != 0 else KEY_2)
  if not check(app.session.turn.snapshot() == after and app.page == "result","keyboard switch retains executed state"): return
  if not await click("ResetSample"): return
  if not check(app.page == "overview" and app.session.turn.snapshot() == original,"independent checkpoint exact restore"): return
 print("REBUILD_OK real mouse and keyboard, three Session loops, cancellation, payment, checkpoint restore")
 finish(true)
