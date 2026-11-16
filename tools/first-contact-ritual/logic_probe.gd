extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const Discovery = preload("res://src/presentation/person_discovery.gd")
const Arrival = preload("res://src/presentation/production/worldplay/round_arrival_model.gd")
const Ritual = preload("res://src/game/ritual_intervention.gd")
var checks := 0
var failures: Array[String] = []
var outcomes := {}
func _initialize() -> void: run.call_deferred()
func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)
func fresh(seed_value: int) -> RefCounted:
	var s := Session.new("/tmp/first-contact-ritual/logic/%d/%d" % [OS.get_process_id(), seed_value])
	verify(s.start_new(seed_value).ok,"New game %d" % seed_value)
	return s
func run() -> void:
	var s := fresh(1341549068)
	var p: Dictionary = s.project()
	verify(p.people.size()==2,"O02: background participants leaked from user's original seed")
	verify(p.people.all(func(person: Dictionary)->bool:return person.prayer_carried and person.discovery.begins_with("通过求告")),"O01/O02: prayer carriers lack public provenance")
	verify(not p.card_unlocks.has("ROUTE_CALENDAR_RITE"),"O03: hidden priest opened ritual")
	var arrival := Arrival.new(); arrival.reset(true); arrival.observe(s,p)
	verify(arrival.counts.person==0 and arrival.counts.prayer==2,"O01: duplicated opening echo identities")
	verify(s.progress().ok,"Enter action phase")
	var ids: Array = p.people.map(func(person: Dictionary)->String:return person.id)
	for id: String in ids:
		var choices: Array = s.action_choices("POWER_DREAM",{"domain":p.domains[0].id}).get("fields",[])
		verify(choices.any(func(field: Dictionary)->bool:return field.key=="npc" and field.options.any(func(o: Dictionary)->bool:return o.id==id)),"O02: carrier removed from dream candidates")
	var prayer: Dictionary = p.prayers[0]
	verify(s.execute_action(str(prayer.key)+"/dismiss",{},true).ok,"Dismiss prayer")
	verify(s.project().people.filter(func(person: Dictionary)->bool:return person.id in ids).all(func(person: Dictionary)->bool:return person.prayer_carried),"O01: dismissal reissued person")
	var path := "/tmp/first-contact-ritual/carrier.json"
	verify(s.save_game(path).ok,"Save carrier")
	var original_save := FileAccess.get_file_as_string(path)
	var restored := Session.new("/tmp/first-contact-ritual/restored")
	verify(restored.continue_game(path).ok,"O08: restore carrier")
	verify(restored._person_discovery==s._person_discovery,"O08: lost provenance or carrier on load")
	var old_snapshot: String = restored.turn.snapshot()
	Discovery.observe(restored,restored._person_discovery)
	verify(old_snapshot==restored.turn.snapshot(),"O08: observation mutated gameplay")
	# Real round transition, not a fabricated turn counter.
	verify(restored.progress(true).ok,"End action phase")
	for step: int in 12:
		if restored.turn.context.turn>1 and restored.turn.context.phase in ["events","actions"]: break
		verify(restored.progress().ok,"Advance actual turn phase")
	verify(restored.turn.context.turn==2,"O08: reached actual second turn")
	var next: Dictionary = restored.project()
	verify(next.people.filter(func(person: Dictionary)->bool:return person.id in ids).all(func(person: Dictionary)->bool:return not person.prayer_carried),"O01: next-turn people still suppressed")
	arrival.observe(restored,next)
	verify(arrival.cards.all(func(c: Dictionary)->bool:return c.get("arrival")!="person" or c.subject.id not in ids),"O08: delayed hand replayed as new discovery")
	# Legacy snapshot omits the new display ledger; original knowledge is preserved.
	var envelope: Dictionary = Session.World._normalize_numbers(JSON.parse_string(original_save))
	envelope.body.erase("person_discovery")
	envelope.checksum = Session.World.canonical(envelope.body).sha256_text()
	var file := FileAccess.open("/tmp/first-contact-ritual/legacy.json",FileAccess.WRITE);file.store_string(Session.World.canonical(envelope));file.close()
	var legacy := Session.new("/tmp/first-contact-ritual/legacy")
	verify(legacy.continue_game("/tmp/first-contact-ritual/legacy.json").ok,"O08: legacy without display ledger")
	verify(legacy.known_people()==s.known_people(),"O08: legacy knowledge lost")
	for record: String in s.known_sources(): verify(Store.entry(legacy.world.state.facts,record)==Store.entry(s.world.state.facts,record),"O08: historical public fact changed "+record)
	verify(legacy.world.state.next_fact==s.world.state.next_fact and legacy.world.state.faith==s.world.state.faith and legacy.world.state.whispers==s.world.state.whispers and legacy.turn.commit_sequence==s.turn.commit_sequence,"O08: legacy generated rewards or new history")
	identity_fixtures(s)
	for seed_value: int in range(1,17):
		var run := fresh(seed_value)
		if not run.project().card_unlocks.has("ROUTE_CALENDAR_RITE"): continue
		ritual_path(run,seed_value)
		if outcomes.has("success") and outcomes.has("failure"): break
	verify(outcomes.has("success") and outcomes.has("failure"),"O07: missing real success/failure examples")
	print("FIRST_CONTACT_RITUAL ",checks," checks, ",failures.size()," failures; outcomes=",outcomes)
	quit(0 if failures.is_empty() else 1)
func identity_fixtures(s: RefCounted) -> void:
	# Pure display fixtures exercise identities, never inject gameplay rewards.
	var ledger := {"A":{"first_turn":1,"prayer_turn":1,"reason":"求告","source":""},"B":{"first_turn":0,"prayer_turn":-1,"reason":"此前相识","source":""}}
	var a := {"id":"A","title":"同名"}; var b := {"id":"B","title":"同名"}
	Discovery.decorate(a,ledger,1);Discovery.decorate(b,ledger,1)
	verify(a.prayer_carried and not b.prayer_carried,"O01: names conflated identities or old person suppressed")
	Discovery.decorate(a,ledger,2)
	verify(not a.prayer_carried,"O01: carrier survived its discovery turn")
	var corrupt: Dictionary = s._person_discovery.duplicate(true)
	corrupt.values()[0].first_turn=999
	verify(not Discovery.valid(corrupt,s.world.state,1),"O08: future discovery accepted")
func selection(s: RefCounted, entry: String, initial: Dictionary) -> Dictionary:
	var result := initial.duplicate(true)
	for step: int in 8:
		var changed := false
		for field: Dictionary in s.action_choices(entry,result).get("fields",[]):
			if not field.optional and not field.multiple and not result.has(field.key) and field.options.size()==1:
				result[field.key]=field.options[0].id;changed=true
		if not changed: break
	return result
func ritual_path(s: RefCounted, seed_value: int) -> void:
	var p: Dictionary = s.project()
	verify(p.cults.is_empty(),"O03: starter ritual path already had cult")
	verify(s.progress().ok,"Ritual enter actions")
	var pick := selection(s,"route/context",{"domain":p.domains[0].id,"operation":"ROUTE_CALENDAR_RITE"})
	var fields: Array = s.action_choices("route/context",pick).fields
	verify(fields.any(func(f: Dictionary)->bool:return f.key=="source" and f.get("automatic",false) and f.options.size()==1),"O05: unneeded causal-record picker")
	for f: Dictionary in fields:
		if f.key=="npc":
			verify(f.options.all(func(o: Dictionary)->bool:return "ritual_keeper" in Store.entry(s.world.state.npcs,str(o.id)).role_tags),"O04: messenger offered for rite")
	var before: String = s.turn.snapshot()
	var preview: Dictionary = s.preview_action("route/context",pick)
	verify(preview.ok,"O03/O04: real pre-cult ritual path not executable: "+str(preview))
	verify(before==s.turn.snapshot(),"O05: preparing changes world or RNG")
	var wrong := pick.duplicate(); wrong.source=s.world.state.domains[pick.domain].origin
	verify(not s.execute_action("route/context",wrong,true).ok and before==s.turn.snapshot(),"O03: unrelated source bypassed or charged")
	var person: Dictionary = Store.entry(s.world.state.npcs,pick.npc)
	var bare := person.duplicate(true); bare.bound_member=false
	verify(not Ritual.source_valid(s.world.state,bare,wrong.source,s.catalog),"O03: merely knowing priest admitted action")
	var details: Dictionary = s.action_choices("route/context",pick).details
	var profile: String=s.world.state.domains[pick.domain].profile
	if profile!=s.catalog.tables.anchor_route_rules.calendar_rites.profile: verify(not details.has("所需成功回合"),"O06: false cross-turn target for "+profile)
	var initial_followers: int = s.world.state.domains[pick.domain].unnamed_followers
	var initial_people: int = s.world.state.next_npc
	var result: Dictionary = s.execute_action("route/context",pick,true)
	verify(result.ok,"O07: preview/submit disagreement")
	var rolls: Array = result.get("result",{}).get("checks",[])
	verify(rolls.size()==1,"O07: not one real die")
	if rolls.is_empty(): return
	var outcome: String=rolls[0].outcome
	outcomes["success" if outcome in ["success","deep"] else "failure"]={"seed":seed_value,"roll":rolls[0].roll,"target":rolls[0].probability,"outcome":outcome}
	var actual: int=s.world.state.domains[pick.domain].unnamed_followers-initial_followers
	verify(actual==(s.catalog.integer("rite_followers") if outcome in ["success","deep"] else 0),"O07: actual followers disagree with check")
	verify(s.world.state.next_npc==initial_people,"O06: unnamed converts became generated people")
	var receipt: Dictionary=result.get("action_effects",{})
	verify(receipt.get("developments",[]).any(func(row: Dictionary)->bool:return row.kind=="activity"),"O07: no activity consequence")
	verify(receipt.get("deltas",[]).any(func(row: Dictionary)->bool:return row.field=="sanity" and row.delta<0),"O07: missing real actor consequence")
	verify(s.project().people.filter(func(x: Dictionary)->bool:return x.id==pick.npc)[0].prayer_carried,"O01: action reissued carried person")
	var repeated: Dictionary=s.preview_action("route/context",pick)
	verify(not repeated.ok,"O04: temporary action budget not checked")
	verify(s.project().card_unlocks.has("ROUTE_CALENDAR_RITE"),"O04: spent action relocked discovery")
	print("RITUAL_REAL ",seed_value," ",rolls," effects=",receipt)
	# Query all independent activities and powers without mutating simulation.
	var saved: String=s.turn.snapshot()
	var activities:=0;var powers:=0
	for id: String in s.catalog.tables.progression_route_operations:
		if id in ["ROUTE_GUIDED_DREAM","ROUTE_PACT_PERFORMANCE"]: continue
		activities+=1
		var options: Dictionary=s.action_choices("route/context",{"domain":pick.domain,"operation":id})
		verify(options.get("fields") is Array,"O04: route selector failed "+id)
	for id: String in s.catalog.tables.powers:
		powers+=1;s.action_choices(id,{"domain":pick.domain})
	verify(activities==16 and powers==12 and saved==s.turn.snapshot(),"O04: full selector coverage or read-only failure")
