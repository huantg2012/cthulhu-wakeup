extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Model = preload("res://src/presentation/production/worldplay/action_model.gd")
const Arrival = preload("res://src/presentation/production/worldplay/round_arrival_model.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
func run() -> void:
	var folder := "user://card-unlock-probe/%d" % OS.get_process_id()
	var s := Session.new(folder)
	check(s.start_new(1).ok, "New game failed")
	var p: Dictionary = s.project()
	var policy: RefCounted = s.card_unlock_policy
	var required: Array = s.catalog.tables.powers.keys()
	for id: String in s.catalog.tables.progression_route_operations:
		if id not in ["ROUTE_GUIDED_DREAM", "ROUTE_PACT_PERFORMANCE"]: required.append(id)
	check(required.size() == policy.rules.size(), "Functional-card policy coverage differs from catalogue")
	for id: String in required: check(policy.rules.has(id), "No explicit discovery rule for " + id)
	for id: String in ["POWER_APPOINT", "POWER_ANCHOR", "POWER_MANIFEST", "ROUTE_COVERT_GATHERING", "ROUTE_PRIVATE_DEVOTION"]:
		check(not p.card_unlocks.has(id), "Premature opening: " + id)
	check(p.card_unlocks.has("POWER_DREAM"), "Initial actual dream contact was hidden")
	var before: String = s.turn.snapshot()
	var ledger: Dictionary = s._card_unlocks.duplicate(true)
	var started := Time.get_ticks_usec()
	policy.observe(s,p,s._card_unlocks)
	print("DISCOVERY_OBSERVE ms=",(Time.get_ticks_usec()-started)/1000.0)
	check(s.turn.snapshot() == before and s._card_unlocks == ledger, "Read-only discovery rerolled/changed rules or repeated an unlock")
	var cards: Array = Model.new().cards(s,p,str(p.domains[0].id))
	check(cards.all(func(c: Dictionary) -> bool: return c.id != "POWER_APPOINT" and c.id != "anchor/bind"), "Table bypassed initial discovery")
	print("STARTER_CARDS ",cards.map(func(c: Dictionary):return c.title))
	var arrivals := Arrival.new()
	arrivals.reset(true)
	arrivals.observe(s,p)
	check(arrivals.cards.all(func(c: Dictionary) -> bool: return c.id != "POWER_APPOINT" and c.id != "anchor/bind"), "Round arrival bypassed discovery")
	check(arrivals.cards.any(func(c: Dictionary) -> bool: return c.id == "ROUTE_JOINT_WORK" and c.arrival == "unlock"), "Event phase suppressed a genuinely opened activity from arrival")
	# Persisted presentation history is separate from current ability to execute.
	var retained: Dictionary = p.duplicate(true)
	retained.card_unlocks["POWER_APPOINT"] = {"turn":1,"domain":p.domains[0].id}
	retained.card_unlocks["POWER_MANIFEST"] = {"turn":1,"domain":p.domains[0].id}
	retained.awakening = 0; retained.faith = 0; retained.whispers = 0
	check(Model.unlocked({"id":"POWER_APPOINT","type":"action","group":"power","entry":"POWER_APPOINT"},s.catalog,retained), "A discovered card vanished with its prerequisites")
	check(Model.unlocked({"id":"record/POWER_MANIFEST","type":"object","group":"power","subject":{"id":"POWER_MANIFEST"}},s.catalog,retained), "Reference library uses a different unlock rule")
	var high: Dictionary = p.duplicate(true); high.awakening = 100
	check(not Model.unlocked({"id":"POWER_MANIFEST","type":"action","group":"power","entry":"POWER_MANIFEST"},s.catalog,high), "Awakening alone opened Manifest")
	predicate_checks(s,p)
	var path := folder.path_join("test.json")
	check(s.save_game(path).ok,"Save failed")
	var restored := Session.new(folder+"/restore")
	check(restored.continue_game(ProjectSettings.globalize_path(path)).ok,"Current save failed to load")
	check(restored.project().card_unlocks == s.project().card_unlocks,"Discovery did not survive reload")
	var envelope: Dictionary = Session.World._normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string(path)))
	# A pre-change Session has no presentation ledger. No rule snapshot migration.
	envelope.body.erase("card_unlocks")
	envelope.checksum = Session.World.canonical(envelope.body).sha256_text()
	var old_path := folder.path_join("legacy.json")
	var file := FileAccess.open(old_path,FileAccess.WRITE); file.store_string(Session.World.canonical(envelope)); file.close()
	var legacy := Session.new(folder+"/legacy")
	check(legacy.continue_game(ProjectSettings.globalize_path(old_path)).ok,"Save without discovery ledger became incompatible")
	check(legacy.project().card_unlocks == s.project().card_unlocks,"Legacy import reverted to threshold-only cards")
	# Synthetic historical discovery, with no present cult: persistence must not
	# recompute it away. It grants no execution rights and never changes Turn.
	s._card_unlocks["POWER_APPOINT"] = {"turn":int(p.turn),"domain":p.domains[0].id}
	check(s.save_game(path).ok,"Historical discovery save failed")
	check(restored.continue_game(ProjectSettings.globalize_path(path)).ok,"Historical discovery load failed")
	check(restored.project().card_unlocks.has("POWER_APPOINT") and restored.project().cults.is_empty(),"Lost prerequisites erased a persisted opening")
	check(s.turn.snapshot() == before,"Presentation ledger altered the simulation snapshot")
	# A real Session boundary retains already opened foundation activities.
	check(legacy._submit("finish_events").ok,"Could not enter the real first action phase")
	var actionable: Dictionary = legacy.project()
	check(actionable.card_unlocks.has("ROUTE_JOINT_WORK") and actionable.card_unlocks.has("ROUTE_RECORD_PRACTICE"),"Real available foundation activities failed to remain open")
	check(not actionable.card_unlocks.has("POWER_APPOINT") and not actionable.card_unlocks.has("POWER_ANCHOR"),"Entering actions manufactured organisation prerequisites")
	arrivals.observe(legacy, actionable) # Same round does not replay.
	var next := actionable.duplicate(true); next.turn += 1
	# A public discovery fixture checks the next-round report, not game execution.
	next.card_unlocks["POWER_APPOINT"] = {"turn":int(next.turn),"domain":p.domains[0].id}
	arrivals.observe(legacy, next)
	check(arrivals.cards.any(func(c: Dictionary) -> bool: return c.id == "POWER_APPOINT" and c.arrival == "unlock"),"Newly discovered function missing from next-round report")
	check(arrivals.cards.all(func(c: Dictionary) -> bool: return c.arrival != "unlock" or c.id != "ROUTE_JOINT_WORK"),"Previously opened activity replayed as new")
	check(not arrivals.observe(legacy,next),"Same-round report repeated a new unlock")
	check(not policy.valid({"version":1,"entries":{"POWER_APPOINT":{"turn":99,"domain":p.domains[0].id}}},1,s.world.state.domains),"Accepted future unlock")
	check(not policy.valid({"version":1,"entries":{"POWER_FAKE":{"turn":1,"domain":p.domains[0].id}}},1,s.world.state.domains),"Accepted invented function")
	print("CARD_UNLOCKS_OK ",checks," assertions; all 28 functional entries, starter deck/arrival, prerequisites, persistence, legacy save, no RNG/state mutation")
	quit()

func predicate_checks(s: RefCounted, p: Dictionary) -> void:
	var view: Dictionary = s.turn._read_view("powers","actions")
	var ctx: Dictionary = s.EntrySelectors.context(view,s.knowledge_snapshot(),s.modules)
	var policy: RefCounted = s.card_unlock_policy
	var person: Dictionary = Store.entry(s.world.state.npcs,str(p.people[0].id)).duplicate(true)
	var domain: String = person.domain
	var cult := {"id":"unlock-fixture-cult","domain":domain,"status":"active"}
	# Explicit detached prerequisite fixtures, never written to Session or saved.
	check(not policy._ready(ctx,p,domain,{},[person],"POWER_APPOINT"),"Appointment without cult")
	person.bound_member = true; person.loyalty = s.catalog.integer("loyalty_follower_threshold")
	ctx.world.npcs[person.id] = person
	check(not policy._ready(ctx,p,domain,{},[person],"POWER_APPOINT"),"Member alone opened appointment")
	check(policy._ready(ctx,p,domain,cult,[person],"POWER_APPOINT"),"Cult plus officer did not open appointment")
	cult.status = "dormant"
	check(policy._ready(ctx,p,domain,cult,[person],"POWER_APPOINT"),"Dormant cult lost its recovery route")
	var ledger := {"POWER_APPOINT":{"turn":1,"domain":domain}}
	policy.observe(s,p,ledger)
	check(ledger.has("POWER_APPOINT"),"Observation relocked a previously opened feature")
	# Losing the only specialist must affect execution, not erase the activity
	# from the world-profile catalogue by auto-selecting its sole remaining NPC.
	ctx.knowledge.known_people = {person.id:true}
	person.role_tags = []
	var operations: Array = policy._activity_options(ctx,domain)
	check(operations.any(func(option: Dictionary) -> bool: return option.id == "ROUTE_RECORD_PRACTICE"),"Sole non-specialist hid an already discoverable activity")
	var cosmic := ""; var system := ""
	for id: String in ctx.world.domains:
		if ctx.world.domains[id].tier == "cosmic": cosmic = id
		if ctx.world.domains[id].tier == "system": system = id
	person.domain = cosmic
	ctx.knowledge.known_people[person.id] = true
	ctx.knowledge.known_domains[cosmic] = true; ctx.knowledge.known_domains[system] = true
	var a := {"id":"fixture-cosmic","domain":cosmic,"guardian":person.id,"state":"active"}
	var b := {"id":"fixture-system","domain":system,"guardian":"","state":"active"}
	ctx.world.anchors = {a.id:a,b.id:b}
	var projection := {"anchors":[a,b]}
	check(policy._ready(ctx,projection,cosmic,{},[person],"POWER_MANIFEST"),"Valid formal manifestation configuration was hidden")
	b.state = "dormant"
	check(not policy._ready(ctx,projection,cosmic,{},[person],"POWER_MANIFEST"),"Dormant system anchor opened manifestation")
	b.state = "active"; person.bound_member = false
	check(not policy._ready(ctx,projection,cosmic,{},[person],"POWER_MANIFEST"),"Unbound guardian opened manifestation")
	view.reader.close()
