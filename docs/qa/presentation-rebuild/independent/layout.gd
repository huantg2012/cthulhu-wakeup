extends SceneTree
var game
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 game = load("res://src/presentation/reconstruction/lesson.tscn").instantiate()
 root.add_child(game)
 var app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
 await process_frame
 var report: Array = []
 for index: int in range(3):
  app.set_variant(index); app.mode = "deep"; app.show_page("detail")
  await process_frame
  var labels: Array = []
  for id: String in ["MainHeading","DetailDue" if index != 1 else "PrayerDue","MandatoryCost","OutcomeRisk","FixedPayment"]:
   var node: Label = app.find_child(id,true,false)
   var font = node.get_theme_font("font")
   var height: float = font.get_height(node.get_theme_font_size("font_size"))*node.get_line_count()
   var rectangle: Rect2 = node.get_global_rect()
   labels.append({"name":id,"text":node.text,"line_count":node.get_line_count(),"rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"glyph_height_estimate":height})
  report.append({"variant":index,"labels":labels})
 var file = FileAccess.open("res://docs/qa/presentation-rebuild/independent/layout.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source_sha256":FileAccess.get_sha256("res://src/presentation/reconstruction/lesson.gd"),"scope":"Label line-count and font-height estimates, not a replacement for image inspection","variants":report},"\t"))
 file.close()
 game.free()
 quit()
