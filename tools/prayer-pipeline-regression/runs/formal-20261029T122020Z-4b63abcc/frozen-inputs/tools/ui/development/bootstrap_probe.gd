extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var report: Array = []
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for seed_value: int in [42]:
  var s: RefCounted = Session.new("res://.godot/ui-bootstrap-saves-v4/" + str(seed_value))
  var opened: Dictionary = s.start_new(seed_value)
  var rows: Array = []
  if not opened.ok:
   report.append({"seed":seed_value,"error":opened}); continue
  for iteration: int in 40:
   if s.turn.context.phase == "ended" or not s.world.state.cults.is_empty(): break
   while s.turn.context.phase != "actions" and s.turn.context.phase != "ended":
    var moved: Dictionary = s.progress(true)
    if not moved.ok:
     rows.append({"step":"advance","result":moved}); break
   if s.turn.context.phase != "actions": break
   var offers: Array = []
   var selected: String = ""
   var selected_variant: String = "shallow"
   var score: int = -1
   for id: String in s.world.state.prayer_system.offered:
    var request: Dictionary = s.world.state.prayer_system.requests[id]
    var content: String = request.card.content_id
    var domain: String = request.card.domain
    var members: int = 0
    for person_id: String in s.world.state.attention.members:
     if Store.entry(s.world.state.npcs, person_id).domain == domain: members += 1
    var variant: String = "deep" if content == "PRAYER_05" else "shallow"
    var preview: Dictionary = s.modules.prayers.preview(s.turn,id,variant)
    offers.append({"id":id,"content":content,"domain":domain,"members":members,"preview":preview})
    var rank: int = 40 if content == "PRAYER_05" and members > 0 else (30 if content == "PRAYER_08" and members == 0 else (-1 if content == "PRAYER_05" else 0))
    if preview.ok and rank > score:
     selected = id; selected_variant = variant; score = rank
   var action: Dictionary = {}
   if not selected.is_empty(): action = s.execute_action("prayer/"+selected+"/"+selected_variant,{},true)
   var domains: Array = []
   for domain: String in s.known_domains():
    domains.append({"id":domain,"followers":s.world.state.domains[domain].unnamed_followers,"spend":s.world.state.cult_system.spend.get(domain,{})})
   var row: Dictionary = {"turn":s.turn.context.turn,"faith":s.world.state.faith,"members":s.world.state.attention.members.keys(),"domains":domains,"offers":offers,"selected":selected,"variant":selected_variant,"action":action}
   rows.append(row)
   print("BOOT ",seed_value," ",JSON.stringify({"turn":row.turn,"faith":row.faith,"members":row.members,"domains":domains,"selected":selected,"action":action.get("result",{})}))
   var member_domains: Array = []
   for person_id: String in s.world.state.attention.members:
    var domain: String = Store.entry(s.world.state.npcs,person_id).domain
    if not domain in member_domains: member_domains.append(domain)
   for domain: String in s.world.state.simulation.focused.duplicate():
    if not domain in member_domains: s._submit("attention", {"command":{"kind":"release_focus","domain":domain}})
   var closed: Dictionary = s.progress(true)
   if not closed.ok: rows.append({"step":"close","result":closed}); break
  var final: Dictionary = {"seed":seed_value,"turn":s.turn.context.turn,"phase":s.turn.context.phase,"cults":s.world.state.cults,"rows":rows,"ritual_keepers":s.world.history.ids("living").filter(func(id:String)->bool: return "ritual_keeper" in Store.entry(s.world.state.npcs,id).get("role_tags",[])).map(func(id:String)->Dictionary: return {"id":id,"domain":Store.entry(s.world.state.npcs,id).domain,"institution":Store.entry(s.world.state.npcs,id).institution})}
  report.append(final)
  print("BOOT FINAL ",seed_value," turn ",final.turn," phase ",final.phase," cults ",final.cults.keys())
 var out: FileAccess = FileAccess.open("res://.godot/ui-bootstrap-probe.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(report,"\t"));out.close()
 quit()
