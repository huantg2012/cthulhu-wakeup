extends RefCounted
## Production B art. Semantic identity is separate from shoulder category;
## no localized title, random object id or hidden rule state selects an image.
const VARIANTS := ["B · 正式", "B · 前版", "B · 当前打磨"]
const ASSETS := "res://assets/ui/card-illustrations/b-refinement/"
const FILES := ["", "b-before.png", "b-refined.png"]
const SAMPLES := ["dream", "gathering", "relic_bell", "breach", "records", "relic_book"]
const CORE := ["listen","dream","oracle","bestow","appoint","sacrifice","breach","seed","anchor","veil","transfer","manifest",
	"devotion","joint_work","gathering","rite","records","calendar","teach","memory_circle","memory_practice","dissent","pact","reciprocal"]
const EXTRA := ["axiom_probe","axiom_recheck","axiom_repeat","network","relic_bell","relic_lens","relic_seal","relic_book","relic_nail","relic_ember",
	"ward","purify","trace","seize","raid","exclude","upkeep","unbind","recover","disassemble","wait","event","cult_order","carry"]
static var _atlases: Dictionary = {}
static var _regions: Dictionary = {}
const POWERS := {
	"POWER_LISTEN":"listen", "POWER_DREAM":"dream", "POWER_ORACLE":"oracle",
	"POWER_BESTOW":"bestow", "POWER_APPOINT":"appoint", "POWER_SACRIFICE":"sacrifice",
	"POWER_BREACH":"breach", "POWER_SEED":"seed", "POWER_ANCHOR":"anchor",
	"POWER_VEIL":"veil", "POWER_TRANSFER":"transfer", "POWER_MANIFEST":"manifest"}
const ROUTES := {
	"ROUTE_GUIDED_DREAM":"dream", "ROUTE_AXIOM_PROBE":"axiom_probe",
	"ROUTE_AXIOM_RECHECK":"axiom_recheck", "ROUTE_AXIOM_REPEAT":"axiom_repeat",
	"ROUTE_NETWORK_EXCHANGE":"network", "ROUTE_PRIVATE_DEVOTION":"devotion",
	"ROUTE_JOINT_WORK":"joint_work", "ROUTE_COVERT_GATHERING":"gathering",
	"ROUTE_CALENDAR_RITE":"rite", "ROUTE_RECORD_PRACTICE":"records",
	"ROUTE_CALENDAR_KEEPING":"calendar", "ROUTE_RITUAL_TRANSMISSION":"teach",
	"ROUTE_MEMORY_CIRCLE":"memory_circle", "ROUTE_MEMORY_PRACTICE":"memory_practice",
	"ROUTE_DISSENT_PRACTICE":"dissent", "ROUTE_PACT_AGREEMENT":"pact",
	"ROUTE_PACT_PERFORMANCE":"pact", "ROUTE_RECIPROCAL_COVENANT":"reciprocal"}
const RELICS := {
	"RELIC_ECHO_BELL":"relic_bell", "RELIC_WITNESS_LENS":"relic_lens",
	"RELIC_HOLLOW_SEAL":"relic_seal", "RELIC_LIVING_SCRIPT":"relic_book",
	"RELIC_ROOT_NAIL":"relic_nail", "RELIC_LAST_EMBER":"relic_ember"}
const RESISTANCE := {"RESIST_TRACE":"trace", "RESIST_PURGE":"raid", "RESIST_SEIZE":"seize",
	"RESIST_REPAIR":"ward", "RESIST_ERASE":"purify", "RESIST_REWRITE":"exclude"}
const EVENTS := {"EVENT_01":"bestow", "EVENT_02":"records", "EVENT_03":"appoint",
	"EVENT_04":"dissent", "EVENT_05":"pact", "EVENT_06":"memory_practice",
	"EVENT_07":"oracle", "EVENT_08":"trace", "EVENT_09":"joint_work",
	"EVENT_10":"relic_seal", "EVENT_11":"event", "EVENT_12":"devotion"}
const VERBS := {"equip":"bestow", "unequip":"transfer", "unbind":"unbind",
	"recover":"recover", "disassemble":"disassemble", "public":"oracle", "wait":"wait"}

static func identity(card: Dictionary, motif: String) -> String:
	var subject: Dictionary = card.get("subject",{})
	var selection: Dictionary = card.get("selection",{})
	var id := str(card.get("id",""))
	if id=="anchor/maintain": return "upkeep"
	if id=="anchor/bind": return "anchor"
	if str(card.get("kind",""))=="order" or id.begins_with("order/"):
		return {"expand":"seed", "conceal":"veil", "hold":"ward"}.get(str(selection.get("strategy",id.get_slice("/",id.get_slice_count("/")-1))),"cult_order")
	for value: String in [str(card.get("entry","")), str(selection.get("operation","")), str(subject.get("id","")), id.trim_prefix("record/")]:
		if POWERS.has(value): return POWERS[value]
		if ROUTES.has(value): return ROUTES[value]
	var relic_type := str(subject.get("type",card.get("relic_type","")))
	if RELICS.has(relic_type): return RELICS[relic_type]
	var rule := str(subject.get("rule",card.get("rule","")))
	if RESISTANCE.has(rule): return RESISTANCE[rule]
	var event := str(card.get("content_id",subject.get("content_id","")))
	if EVENTS.has(event): return EVENTS[event]
	if id.begins_with("relic/") or str(card.get("entry","")).begins_with("relic/") or id.begins_with("opportunity/"):
		var entry := id if id.begins_with("relic/") or id.begins_with("opportunity/") else str(card.entry)
		return VERBS.get(entry.get_slice("/",entry.get_slice_count("/")-1),"relic_seal")
	return {"power":"listen", "activity":"gathering", "resistance":"ward", "relic":"relic_seal",
		"anchor":"anchor", "event":"event", "cult":"cult_order", "person":"memory_circle", "prayer":"devotion"}.get(motif,"wait")

static func texture(variant: int, subject: String) -> Texture2D:
	if variant==0: return production_texture(subject)
	var key := "%d/%s" % [variant,subject]
	if _regions.has(key): return _regions[key]
	var index := SAMPLES.find(subject)
	if index<0:
		push_error("No illustration for semantic subject: "+subject)
		return null
	if variant<1 or variant>=FILES.size(): return null
	var path: String = ASSETS + FILES[variant]
	if not _atlases.has(path):
		var resource := load(path) as Texture2D
		var source := resource.get_image() if resource!=null else null
		if source==null or source.is_empty(): return null
		_atlases[path] = source
	var atlas: Image = _atlases[path]
	var cell := Vector2i(atlas.get_width()/3,atlas.get_height()/2)
	# The carrier's blend shader expects one complete image in UV 0..1.
	# Native AtlasTexture would pass atlas-space UV and misplace its alpha mask.
	# Extract the exact cell once; no recolouring, background keying or repaint.
	var origin := Vector2i(index%3,index/3)*cell
	var region := ImageTexture.create_from_image(atlas.get_region(Rect2i(origin,cell)))
	_regions[key] = region
	return region

static func production_texture(subject: String) -> Texture2D:
	# Preserve the six approved paintings exactly; expansions use the same B brushwork.
	if subject in SAMPLES: return texture(2,subject)
	var key := "production/"+subject
	if _regions.has(key): return _regions[key]
	var index := CORE.find(subject)
	var sheet := "core"
	var rows := [0,248,500,736,976,1220]
	if index<0:
		index = EXTRA.find(subject)
		sheet = "extra"
		rows = [0,256,512,770,1002,1240]
	if index<0:
		push_error("Unmapped production illustration: "+subject)
		return null
	var path := "res://assets/ui/card-illustrations/production/"+sheet+".png"
	if not _atlases.has(path):
		var resource := load(path) as Texture2D
		if resource==null: return null
		_atlases[path] = resource.get_image()
	var atlas: Image = _atlases[path]
	var rect := Rect2i(Vector2i(index%4*256,int(rows[index/4])),Vector2i(256,256))
	var result := ImageTexture.create_from_image(atlas.get_region(rect))
	_regions[key] = result
	return result
