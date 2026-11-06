extends SceneTree
## Actual production scene, with one runtime portrait-slot substitution.
const Production = preload("res://src/presentation/production/game_root.tscn")
const Session = preload("res://src/presentation/session.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var player = Session.new("user://presentation-rebuild-baseline")
 if not player.start_new(1).get("ok",false): quit(1); return
 var p = player.project()
 if p.phase == "events" and p.events.is_empty(): player.progress()
 var game = Production.instantiate()
 var app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
 app.session = player
 root.add_child(game)
 app._close_surface()
 var prayers: Array = app._pending_prayers()
 if prayers.is_empty(): quit(1); return
 app._prayers.open(prayers[0],null)
 var slot: TextureRect = app.find_child("SceneSlot",true,false)
 if slot != null:
  slot.material = null
  slot.texture = ImageTexture.create_from_image(Image.load_from_file("res://docs/art/presentation-rebuild/assets/chronicle-portrait.png"))
  slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 root.title = "旧生产布局 · 同一真实祈求补入示意立绘"
 print("BASELINE_READY actual production scene, seed1 prayer, one runtime portrait substitution")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
   await create_timer(.4).timeout
   RenderingServer.force_draw()
   root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
   print("BASELINE_CAPTURED")
   game.free()
   quit()
