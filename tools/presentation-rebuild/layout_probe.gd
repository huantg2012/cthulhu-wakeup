extends SceneTree
const Scene = preload("res://src/presentation/reconstruction/lesson.tscn")
var errors: Array[String] = []
var game: Node
func _initialize() -> void: run.call_deferred()
func all_labels(node: Node) -> Array:
 var nodes: Array = []
 if node is Label: nodes.append(node)
 for child: Node in node.get_children(): nodes.append_array(all_labels(child))
 return nodes
func run() -> void:
 game = Scene.instantiate()
 root.add_child(game)
 var app = game.get_node("Presentation/CanvasLayer/OverlayRoot")
 for card: int in range(3):
  app.set_variant(card)
  app.mode = "deep"; app.show_page("detail")
  await process_frame
  await process_frame
  for c: Label in all_labels(app._canvas):
   if not c.has_meta("layout_bounds"): continue
   var bounds: Rect2 = c.get_meta("layout_bounds")
   if c.size.x > bounds.size.x+1 or c.get_minimum_size().y > bounds.size.y+1:
    errors.append("%s/%s needs %s but allocated %s" % [card,c.name,c.get_minimum_size(),bounds.size])
  var critical: Array = []
  for id: String in ["MainHeading","DetailDue","MandatoryCost","OutcomeRisk","FixedPayment","Probability_deep","Probability_success","Probability_failure","Probability_disaster"]:
   var label = app.find_child(id,true,false)
   if label == null: continue
   var text_bounds: Rect2 = label.get_global_rect()
   text_bounds.size.y = label.get_minimum_size().y
   for prior: Dictionary in critical:
    if text_bounds.intersects(prior.rect): errors.append("%s text overlap: %s/%s" % [card,prior.name,id])
   critical.append({"name":id,"rect":text_bounds})
  if card == 1:
   var face = app.find_child("FaceSafeArea",true,false)
   for name_value: String in ["ReadingPaper","StoryCaption","BenefitPaper"]:
    var panel = app.find_child(name_value,true,false)
    if panel != null and panel.get_global_rect().intersects(face.get_global_rect()):
     errors.append("B face obscured by "+name_value)
 if errors.is_empty(): print("REBUILD_LAYOUT_OK fixed label widths, critical text separation, B face safe area")
 else:
  for message: String in errors: push_error(message)
 game.free()
 quit(0 if errors.is_empty() else 1)
