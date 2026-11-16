extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const Catalogue = preload("res://tools/card-illustration-study/catalogue.gd")
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_files("res://data"): quit(1); return
	var cards := Catalogue.cards(catalog)
	var groups := {}
	var subjects := {}
	var ids := {}
	for card: Dictionary in cards:
		if ids.has(card.id) or card.title.is_empty():
			push_error("Duplicate/unnamed art catalogue entry "+str(card.id)); quit(1); return
		ids[card.id] = true
		groups[card.catalogue_section] = int(groups.get(card.catalogue_section,0))+1
		var subject := Library.identity(card,str(card.group))
		if subject!=Library.Registry.RECORDS.get(card.id, ""):
			push_error("Unmapped semantic identity "+str(card.id)); quit(1); return
		subjects[subject] = true
	var expected := {"powers":12,"activities":16,"relics":6,"previews":6,"actions":12,"events":12}
	if groups!=expected:
		push_error("Art catalogue coverage changed: "+str(groups)); quit(1); return
	if Library.identity({"id":"record/POWER_DREAM"},"power")!="power_dream" or Library.identity({"entry":"POWER_DREAM"},"power")!="power_dream":
		push_error("Record/action art identity diverged"); quit(1); return
	# Distinct concrete meanings must use the approved per-card images, including
	# runtime cards whose instance IDs differ from their catalogue definitions.
	var cases := [
		[{"id":"relic/object-17","type":"object","subject":{"type":"RELIC_ECHO_BELL"}},"relic","relic_echo_bell"],
		[{"id":"opportunity/object-17/unbind","subject":{"type":"RELIC_ECHO_BELL"}},"action","relic_action_unbind"],
		[{"id":"anchor/object-17","type":"object","kind":"anchor"},"anchor","object_anchor"],
		[{"id":"order/cult-17/hold","kind":"order","selection":{"strategy":"hold"}},"cult","order_hold"],
		[{"id":"event/instance-17","subject":{"content_id":"EVENT_03"}},"event","event_03"],
		[{"id":"resistance/instance-17","subject":{"rule":"RESIST_SEIZE"}},"resistance","resist_seize"],
		[{"id":"activity/instance-17","entry":"route/context","selection":{"operation":"ROUTE_MEMORY_PRACTICE"}},"activity","route_memory_practice"]]
	for row: Array in cases:
		if Library.identity(row[0],row[1])!=row[2]:
			push_error("Wrong runtime art identity "+str(row)); quit(1); return
	for id: String in Library.Registry.RECORDS:
		if Library.identity({"id":id},"action")!=Library.Registry.RECORDS[id]:
			push_error("Missing support / definition mapping "+id); quit(1); return
	if subjects.size()!=63 or Library.Registry.KEYS.size()!=71:
		push_error("Concrete art was inadvertently shared"); quit(1); return
	print("ART_MAPPING_OK ",cards.size()," definitions / ",subjects.size()," unique drawings / 8 support images; ",groups)
	print("RUNTIME_IDENTITY_OK: objects, actions, operations, event instances, resistance instances, collections")
	quit()
