extends RefCounted
## Fixed, offline-baked full-deck art. Semantic identity is separate from shoulder category;
## no localized title, random object id or hidden rule state selects an image.
const Registry = preload("res://assets/ui/card-illustrations/painted-deck/registry.gd")
const FIXED_ROOT := "res://assets/ui/card-illustrations/painted-deck/"
const VARIANTS := ["全目录 · 暗黑厚涂", "旧 B · 前版", "旧 B · 打磨"]
const ASSETS := "res://assets/ui/card-illustrations/b-refinement/"
const FILES := ["", "b-before.png", "b-refined.png"]
const SAMPLES := ["dream", "gathering", "relic_bell", "breach", "records", "relic_book"]
static var _atlases: Dictionary = {}
static var _regions: Dictionary = {}
const POWERS := {
	"POWER_LISTEN":"power_listen", "POWER_DREAM":"power_dream", "POWER_ORACLE":"power_oracle",
	"POWER_BESTOW":"power_bestow", "POWER_APPOINT":"power_appoint", "POWER_SACRIFICE":"power_sacrifice",
	"POWER_BREACH":"power_breach", "POWER_SEED":"power_seed", "POWER_ANCHOR":"anchor_bind",
	"POWER_VEIL":"power_veil", "POWER_TRANSFER":"power_transfer", "POWER_MANIFEST":"power_manifest"}
const ROUTES := {
	"ROUTE_GUIDED_DREAM":"power_dream", "ROUTE_AXIOM_PROBE":"route_axiom_probe",
	"ROUTE_AXIOM_RECHECK":"route_axiom_recheck", "ROUTE_AXIOM_REPEAT":"route_axiom_repeat",
	"ROUTE_NETWORK_EXCHANGE":"route_network_exchange", "ROUTE_PRIVATE_DEVOTION":"route_private_devotion",
	"ROUTE_JOINT_WORK":"route_joint_work", "ROUTE_COVERT_GATHERING":"route_covert_gathering",
	"ROUTE_CALENDAR_RITE":"route_calendar_rite", "ROUTE_RECORD_PRACTICE":"route_record_practice",
	"ROUTE_CALENDAR_KEEPING":"route_calendar_keeping", "ROUTE_RITUAL_TRANSMISSION":"route_ritual_transmission",
	"ROUTE_MEMORY_CIRCLE":"route_memory_circle", "ROUTE_MEMORY_PRACTICE":"route_memory_practice",
	"ROUTE_DISSENT_PRACTICE":"route_dissent_practice", "ROUTE_PACT_AGREEMENT":"route_pact_agreement",
	"ROUTE_PACT_PERFORMANCE":"route_pact_agreement", "ROUTE_RECIPROCAL_COVENANT":"route_reciprocal_covenant"}
const RELICS := {
	"RELIC_ECHO_BELL":"relic_echo_bell", "RELIC_WITNESS_LENS":"relic_witness_lens",
	"RELIC_HOLLOW_SEAL":"relic_hollow_seal", "RELIC_LIVING_SCRIPT":"relic_living_script",
	"RELIC_ROOT_NAIL":"relic_root_nail", "RELIC_LAST_EMBER":"relic_last_ember"}
const RESISTANCE := {"RESIST_TRACE":"resist_trace", "RESIST_PURGE":"resist_purge", "RESIST_SEIZE":"resist_seize",
	"RESIST_REPAIR":"resist_repair", "RESIST_ERASE":"resist_erase", "RESIST_REWRITE":"resist_rewrite"}
const EVENTS := {"EVENT_01":"event_01", "EVENT_02":"event_02", "EVENT_03":"event_03",
	"EVENT_04":"event_04", "EVENT_05":"event_05", "EVENT_06":"event_06",
	"EVENT_07":"event_07", "EVENT_08":"event_08", "EVENT_09":"event_09",
	"EVENT_10":"event_10", "EVENT_11":"event_11", "EVENT_12":"event_12"}
const VERBS := {"equip":"relic_action_equip", "unequip":"relic_action_unequip", "unbind":"relic_action_unbind",
	"recover":"relic_action_recover", "disassemble":"relic_action_disassemble", "public":"relic_action_public", "wait":"relic_action_wait"}

static func identity(card: Dictionary, motif: String) -> String:
	var subject: Dictionary = card.get("subject",{})
	var selection: Dictionary = card.get("selection",{})
	var id := str(card.get("id",""))
	if Registry.RECORDS.has(id): return Registry.RECORDS[id]
	if card.get("type")=="object" and card.get("kind")=="anchor": return "object_anchor"
	if str(card.get("kind",""))=="order" or id.begins_with("order/"):
		var strategy := str(selection.get("strategy",id.get_slice("/",id.get_slice_count("/")-1)))
		return Registry.RECORDS.get("order/"+strategy,"fallback_resolution")
	# A relic action has its own art even when a concrete relic is preselected.
	for entry: String in [id,str(card.get("entry",""))]:
		if entry.begins_with("relic/") or entry.begins_with("opportunity/"):
			var verb := entry.get_slice("/",entry.get_slice_count("/")-1)
			if VERBS.has(verb): return VERBS[verb]
	for value: String in [str(card.get("entry","")), str(selection.get("operation","")), str(subject.get("id","")), id.trim_prefix("record/")]:
		if POWERS.has(value): return POWERS[value]
		if ROUTES.has(value): return ROUTES[value]
	var relic_type := str(subject.get("type",card.get("relic_type","")))
	if RELICS.has(relic_type): return RELICS[relic_type]
	var rule := str(subject.get("rule",card.get("rule","")))
	if RESISTANCE.has(rule): return RESISTANCE[rule]
	var event := str(card.get("content_id",subject.get("content_id","")))
	if EVENTS.has(event): return EVENTS[event]
	# Generic reading surfaces are intentional collection/object pictures,
	# never an arbitrary actionable power such as Listen or Bind.
	return {"power":"cover_power", "relic":"cover_relic", "person":"cover_person",
		"anchor":"object_anchor", "event":"cover_events"}.get(motif,"fallback_resolution")

static func texture(variant: int, subject: String) -> Texture2D:
	if variant==0: return production_texture(subject)
	var key := "%d/%s" % [variant,subject]
	if _regions.has(key): return _regions[key]
	var legacy_subject: String = {"power_dream":"dream","route_covert_gathering":"gathering","relic_echo_bell":"relic_bell","power_breach":"breach","route_record_practice":"records","relic_living_script":"relic_book"}.get(subject,subject)
	var index := SAMPLES.find(legacy_subject)
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
	var key := "fixed/"+subject
	if _regions.has(key): return _regions[key]
	if not subject in Registry.KEYS:
		push_error("Unmapped fixed illustration: "+subject)
		return null
	# Native compressed Texture2D resources are exportable without SVG/PNG
	# imports, viewport rendering, postprocessing or any drawing at startup.
	var texture := load(FIXED_ROOT+subject+".res") as Texture2D
	if texture==null:
		push_error("Missing baked illustration: "+subject)
		return null
	_regions[key]=texture
	return texture
