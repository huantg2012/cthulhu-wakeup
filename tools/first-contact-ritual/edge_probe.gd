extends "res://tools/first-contact-ritual/logic_probe.gd"

class ContactFixture extends RefCounted:
	var turn := {"context":{"turn":1}}
	var world := {"state":{"facts":{}}}
	var ledger := {"request_people":{},"known_people":{},"known_prayers":{},"known_events":{},"known_facts":{}}
	func knowledge_snapshot() -> Dictionary: return ledger
	func prayer_title(_descriptor: Dictionary, card: Dictionary) -> String: return card.title

func run() -> void:
	# Presentation-only fixtures: multiple prayers, same name/different IDs,
	# old contact later praying, and late-round first encounter survive reopening.
	var fixture := ContactFixture.new()
	var records := {"OLD":{"first_turn":0,"prayer_turn":-1,"source":"","reason":"此前联系"}}
	fixture.ledger.known_people={"NEW":true,"OLD":true}
	for pair: Array in [["one","NEW"],["two","NEW"],["three","OLD"]]:
		fixture.ledger.known_prayers[pair[0]]={"descriptor":{"subjects":{"petitioner":pair[1]}},"card":{"title":pair[0],"visible_turn":1}}
	Discovery.observe(fixture,records)
	verify(records.NEW.prayer_turn==1 and records.OLD.prayer_turn==-1,"O01: duplicate requests/old contact carrier incorrect")
	var row: Dictionary={"id":"NEW"};Discovery.decorate(row,records,2)
	verify(row.prayer_introduced and not row.prayer_carried,"O01/O08: mid-turn encounter would replay next-turn discovery")
	fixture.ledger.known_prayers.clear();Discovery.observe(fixture,records)
	verify(records.NEW.prayer_turn==1,"O01: closed prayers reissued contact")
	# Same production projection path for world and cult; this fixture changes
	# presentation data only, never creates a real cult or edits the Session.
	var host := preload("res://src/presentation/production/worldplay/view.gd").new()
	host.projection={"cults":[{"id":"CULT","domain":"WORLD"}],"people":[{"id":"NEW","domain":"WORLD","cult_id":"CULT","bound_member":true,"prayer_carried":true},{"id":"OLD","domain":"WORLD","cult_id":"CULT","bound_member":true,"prayer_carried":false}]}
	host._world_id="WORLD"
	verify(host._known_objects().filter(func(o: Dictionary)->bool:return o.kind=="person").size()==1,"O08: world carrier projection")
	host._study_cult="CULT"
	verify(host._known_objects().size()==1 and host._known_objects()[0].subject.id=="OLD","O08: cult carrier projection differs")
	host._study_cult="";host._world_id="ELSEWHERE"
	verify(host._known_objects().is_empty(),"O08: world switch leaked prior contacts")
	# This detached view never runs _ready, which normally adopts Motion.
	host._motion.free()
	host.free()
	var s := fresh(2);verify(s.progress().ok,"Dream route enter actions")
	var p: Dictionary=s.project()
	var person_id := "NPC-00000002"
	var person: Dictionary=Store.entry(s.world.state.npcs,person_id)
	var original_sources := Ritual.sources(s.world.state,person,s._known_facts,s.catalog)
	verify(original_sources.size()==1,"O03: opening priest prayer source")
	var dream := selection(s,"POWER_DREAM",{"domain":person.domain,"npc":person_id})
	var result: Dictionary=s.execute_action("POWER_DREAM",dream,true)
	verify(result.ok,"O03: actual dream path unavailable: "+str(result))
	var dream_sources: Array=[]
	for source: String in Ritual.sources(s.world.state,Store.entry(s.world.state.npcs,person_id),s._known_facts,s.catalog):
		if Store.entry(s.world.state.facts,source).kind=="power_result": dream_sources.append(source)
	verify(dream_sources.size()==1,"O03: successful real dream did not provide contact")
	print("DREAM_ROUTE ",result.get("result",{}).get("checks",[]))
	var prayer: Dictionary=p.prayers.filter(func(item: Dictionary)->bool:return item.descriptor.subjects.petitioner==person_id)[0]
	verify(s.execute_action(str(prayer.key)+"/dismiss",{},true).ok,"Close priest petition")
	person=Store.entry(s.world.state.npcs,person_id)
	verify(not Ritual.source_valid(s.world.state,person,original_sources[0],s.catalog),"O05: closed petition still valid")
	if not dream_sources.is_empty():
		verify(Ritual.source_valid(s.world.state,person,dream_sources[0],s.catalog),"O03: actual dream lost with petition closure")
		var other: Dictionary=person.duplicate(true);other.id="NPC-00000003"
		verify(not Ritual.source_valid(s.world.state,other,dream_sources[0],s.catalog),"O03: dream of another person accepted")
		# Detached rules fixture; cannot change the live campaign or fake natural proof.
		var invalidated: Dictionary=s.world.state.duplicate(false);invalidated.invalid_records={dream_sources[0]:"fixture"}
		verify(not Ritual.source_valid(invalidated,person,dream_sources[0],s.catalog),"O03: invalidated dream accepted")
	# Bound-member alternative tested as a detached rule fixture, not a played route.
	var member: Dictionary=person.duplicate(true);member.bound_member=true;member.loyalty=100;member.binding_source="BIND"
	var state: Dictionary=s.world.state.duplicate(false)
	state.facts={"BIND":{"kind":"member_enrolled","actor":person_id,"domain":person.domain,"changes":{}}};state.invalid_records={}
	verify(Ritual.source_valid(state,member,"BIND",s.catalog),"O03: loyal actual binding rejected")
	member.bound_member=false
	verify(not Ritual.source_valid(state,member,"BIND",s.catalog),"O03: departed member accepted")
	member.bound_member=true;member.loyalty=0
	verify(not Ritual.source_valid(state,member,"BIND",s.catalog),"O03: disloyal member accepted")
	var legacy_path := "/tmp/cthulhu-ritual-audit/input.json"
	if FileAccess.file_exists(legacy_path):
		var bytes:=FileAccess.get_file_as_bytes(legacy_path)
		var legacy := Session.new("/tmp/first-contact-ritual/original-legacy")
		verify(legacy.continue_game(legacy_path).ok,"O08: original screenshot save did not load")
		verify(legacy.project().people.size()==5,"O08: previously public identities erased")
		var snapshot: String=legacy.turn.snapshot();var seq: int=legacy.turn.commit_sequence
		legacy.project();Discovery.observe(legacy,legacy._person_discovery,true)
		verify(snapshot==legacy.turn.snapshot() and seq==legacy.turn.commit_sequence,"O08: legacy viewing rewrote history")
		verify(bytes==FileAccess.get_file_as_bytes(legacy_path),"O08: original legacy input changed")
	else: verify(false,"Missing original screenshot save copy")
	print("FIRST_CONTACT_EDGES ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
