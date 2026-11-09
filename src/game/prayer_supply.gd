extends RefCounted
## A versioned, forward-only minimum supply at a real turn boundary. Natural
## dispatch clocks and historical receipts retain their original semantics.
const Store = preload("res://src/simulation/archive_store.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Producers = preload("res://src/game/prayer_producers.gd")
const Dispatch = preload("res://src/game/prayer_dispatch.gd")
const StateView = preload("res://src/simulation/state_view.gd")
const VERSION := "prayer-supply/1"
const POLICY_KEY := "prayer/supply/policy"

static func _fact(state: Dictionary, id: String) -> Dictionary:
	return Store.entry(state.facts, id, {})

static func _record(world: RefCounted, key: String, kind: String, domain: String, parents: Array, data: Dictionary) -> String:
	var source: String = world._record(kind, domain, "", [], parents, data)
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, key, source)
	return source

static func adopt(world: RefCounted, owner: Object) -> bool:
	var previous: String = str(Store.entry(world.state.applied_authorizations, POLICY_KEY, ""))
	if not previous.is_empty(): return _fact(world.state, previous).get("changes", {}).get("version") == VERSION
	# Existing campaigns are fully restored under their original policies first.
	# This real advance transaction appends the policy switch; it never rewrites
	# a saved checksum, original fact, random state or historical response.
	_record(world, POLICY_KEY, "prayer_supply_adopted", "", [], {"version": VERSION, "previous": "legacy-zero-allowed", "effective_turn": int(world.state.turn), "sequence": int(world.transaction.sequence) + 1, "fact_before": int(world.transaction.base_state.next_fact), "minimum": world.catalog.integer("prayer_response_limit"), "maximum": world.catalog.integer("prayer_offer_limit")})
	return true

static func available(world: RefCounted, owner: Object, only_request: String = "") -> bool:
	var shadow: Dictionary = world.state.duplicate(false)
	if not only_request.is_empty():
		shadow.prayer_system = world.state.prayer_system.duplicate(true)
		shadow.prayer_system.offered = [only_request]
	var cursor: Dictionary = owner.context.duplicate(false); cursor.phase = "actions"
	var reader: RefCounted = StateView.new(shadow, cursor, owner.commit_sequence, world.history)
	var view: Dictionary = reader.participant("prayers", "actions")
	var found: bool = false
	for id: String in shadow.prayer_system.offered:
		for variant: String in ["shallow", "deep"]:
			var prepared: Dictionary = owner._participants.prayers.instance.prepare(view, id, variant)
			if prepared.get("ok", false) and world.attention.preview_needs(shadow, prepared.attention).get("ok", false):
				found = true; break
		if found: break
	reader.close()
	return found

static func playable_situation(world: RefCounted, owner: Object) -> String:
	var space: Dictionary = world.state.prayer_system.get("space", {})
	var cursor: Dictionary = owner.context.duplicate(false)
	cursor.phase = "actions"
	var reader: RefCounted = StateView.new(world.state, cursor, owner.commit_sequence, world.history)
	var view: Dictionary = reader.participant("prayers", "actions")
	var source := ""
	for id: String in space.get("offered", []):
		for variant: String in space.scenes[id].choices:
			var prepared: Dictionary = owner._participants.prayers.instance.prepare(view, id, variant)
			if not prepared.get("ok", false) or not world.attention.preview_needs(world.state, prepared.attention).get("ok", false): continue
			source = str(prepared.descriptor.source)
			break
		if not source.is_empty(): break
	reader.close()
	return source

static func grant(world: RefCounted, owner: Object, source: String) -> bool:
	if not owner.prayer_supply_active or world.transaction == null: return false
	var sample: Dictionary = Knowledge.capture(world, owner)
	var window_key: String = "prayer/supply/window/" + str(sample.commit_seq)
	var window: String = str(Store.entry(world.state.applied_authorizations, window_key, ""))
	if window.is_empty() or _fact(world.state, window).get("changes", {}).get("snapshot") != sample: return false
	var key: String = "prayer/supply/source/" + source
	if Store.has(world.state.applied_authorizations, key): return false
	_record(world, key, "prayer_supply_admitted", _fact(world.state, source).get("domain", ""), [window, source], {"version": VERSION, "source": source, "window": window, "snapshot": sample, "visible_turn": int(world.state.turn)})
	return true

static func _possible(world: RefCounted, descriptor: Dictionary) -> bool:
	var actors: Array = descriptor.get("actors", []).duplicate()
	var content: String = str(descriptor.get("content_id", ""))
	if actors.is_empty(): return false
	if content == "PRAYER_04": actors = [descriptor.subjects.petitioner]
	if content == "PRAYER_07": actors = [descriptor.subjects.petitioner, descriptor.subjects.memory_people[0]]
	return world.attention.preview_needs(world.state, {"family": "prayer", "content_id": content, "variant": "shallow", "participants": actors, "target": descriptor.domain, "nominees": [descriptor.subjects.petitioner] if content == "PRAYER_08" else []}).get("ok", false)

static func _finish_attempt(world: RefCounted, owner: Object, sample: Dictionary, domain: String, origins: Dictionary, selected: Dictionary, choice: Dictionary, source: String, outcome: String) -> void:
	var window: String = str(Store.entry(world.state.applied_authorizations, "prayer/supply/window/" + str(sample.commit_seq), ""))
	var parents: Array = [window]
	if not source.is_empty(): parents.append(source)
	var key: String = "prayer/supply/attempt/" + str(world.state.next_fact)
	_record(world, key, "prayer_supply_attempt", domain, parents, {"version": VERSION, "snapshot": sample, "window": window, "origins": origins, "origin_selected": selected, "choice": choice, "produced": source, "outcome": outcome})

static func ensure(world: RefCounted, owner: Object) -> bool:
	if not world.state.has("prayer_dispatch"): return true
	if not adopt(world, owner): return owner._fail("Prayer supply policy is incompatible")
	if int(owner.context.responses) >= world.catalog.integer("prayer_response_limit") or available(world, owner): return true
	if world.state.whispers < world.catalog.integer("prayer_shallow_whispers"):
		return owner._fail("本轮低语不足，无法提供可回应的祈求")
	owner.prayer_supply_active = true
	var sample: Dictionary = Knowledge.capture(world, owner)
	var policy: String = str(Store.entry(world.state.applied_authorizations, POLICY_KEY, ""))
	_record(world, "prayer/supply/window/" + str(sample.commit_seq), "prayer_supply_window", "", [policy], {"version": VERSION, "policy": policy, "snapshot": sample, "offered_before": world.state.prayer_system.offered.duplicate(), "minimum": world.catalog.integer("prayer_response_limit")})
	var view: Dictionary = world._evolution_snapshot()
	var domains: Array = view.domains.keys()
	domains.sort_custom(func(left: String, right: String) -> bool:
		var left_focus: bool = left in view.simulation.focused
		var right_focus: bool = right in view.simulation.focused
		return left_focus if left_focus != right_focus else left < right)
	# First use one old real occurrence. Inspect a finite page per world; do not
	# alter natural dispatch's source cursor, random stream or four-turn clock.
	for domain: String in domains:
		var origins: Dictionary = Producers.prepare_existing(world, view, domain, sample)
		var pending: Dictionary = Dispatch._pending(world, view, domain, view.prayer_dispatch.positions[domain])
		var selected: Dictionary = origins.selected
		var source: String = str(pending.selected)
		if not selected.is_empty() and (source.is_empty() or selected.order < Dispatch._source_order(view, source)):
			if not _possible(world, selected.descriptor): continue
			Producers.commit_scan(world, origins, sample)
			var outcome: Dictionary = Producers.commit_existing(world, selected, sample, owner)
			if not outcome.get("ok", false): owner.prayer_supply_active = false; return owner._fail(str(outcome.get("error", "Prayer source failed")))
			_finish_attempt(world, owner, sample, domain, origins, selected, {}, str(outcome.get("source", "")), str(outcome.get("outcome", "")))
			if outcome.get("outcome") == "fixed": owner.prayer_supply_active = false; return true
			owner.prayer_supply_active = false
			return owner._fail("祈求来源已找到，但无法合法固定：" + str(outcome.get("outcome", "")))
		elif not source.is_empty():
			var descriptor: Dictionary = owner._participants.prayers.instance.validate_situation(world, source)
			if not descriptor.get("ok", false) or not _possible(world, descriptor): continue
			if not grant(world, owner, source): owner.prayer_supply_active = false; return owner._fail("Prayer supply authorization failed")
			var preview: Dictionary = world.preview_prayer_fix(source, owner)
			if preview.get("ok", false):
				if not world.fix_prayer_source(source, owner): owner.prayer_supply_active = false; return owner._fail("Admitted prayer could not be fixed")
				_finish_attempt(world, owner, sample, domain, {}, {}, {}, source, "fixed")
				owner.prayer_supply_active = false; return true
			owner.prayer_supply_active = false
			return owner._fail("祈求来源无法进入本轮：" + str(preview.get("error", preview.get("outcome", ""))))
	# No usable old occurrence: the existing contact producer creates one real
	# present appeal. Population, P/N and fixed-pool admission remain authoritative.
	for domain: String in domains:
		for choice: Dictionary in Producers.prepare_options(world, view, domain, sample):
			if not choice.root in ["ROOT_CURRENT_APPEAL", "ROOT_CURRENT_PASSAGE"]: continue
			choice.proposal.once_key = "supply/" + str(world.state.turn) + "/" + domain + "/" + str(choice.root)
			var outcome: Dictionary = Producers.commit(world, choice, owner)
			if not outcome.get("ok", false): owner.prayer_supply_active = false; return owner._fail(str(outcome.get("error", "Prayer contact failed")))
			_finish_attempt(world, owner, sample, domain, {}, {}, choice, str(outcome.get("source", "")), str(outcome.get("outcome", "")))
			if outcome.get("outcome") == "fixed": owner.prayer_supply_active = false; return true
			if not str(outcome.get("source", "")).is_empty():
				owner.prayer_supply_active = false
				return owner._fail("实际求告无法进入本轮：" + str(outcome.get("outcome", "")))
	owner.prayer_supply_active = false
	return owner._fail("无法提供本轮祈求：现有来源、人口或名额不满足合法回应条件")

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	var policy_id: String = str(Store.entry(state.applied_authorizations, POLICY_KEY, ""))
	if policy_id.is_empty():
		var missing: Array[String] = []
		if Store.has(trusted.get("applied_authorizations", {}), POLICY_KEY): missing.append("Prayer supply policy disappeared")
		for number: int in range(int(trusted.get("next_fact", 1)), int(state.next_fact)):
			var fact: Dictionary = _fact(state, "FACT-%08d" % number)
			if str(fact.get("kind", "")).begins_with("prayer_supply_"):
				missing.append("Prayer supply facts lost their policy index"); break
		return missing
	var policy: Dictionary = _fact(state, policy_id)
	var data: Dictionary = policy.get("changes", {})
	if policy.get("kind") != "prayer_supply_adopted" or data.get("version") != VERSION or data.get("previous") != "legacy-zero-allowed" or data.get("effective_turn") != policy.get("turn") or data.get("minimum") != content.integer("prayer_response_limit") or data.get("maximum") != content.integer("prayer_offer_limit") or not data.get("sequence") is int or not data.get("fact_before") is int:
		return ["Invalid forward prayer supply policy adoption"]
	var first: int = int(trusted.get("next_fact", 1))
	for number: int in range(first, int(state.next_fact)):
		var fact: Dictionary = _fact(state, "FACT-%08d" % number)
		var kind: String = str(fact.get("kind", ""))
		if kind == "prayer_supply_adopted" and fact.id != policy_id: return ["Repeated prayer supply policy adoption"]
		if not kind.begins_with("prayer_supply_") or kind == "prayer_supply_adopted": continue
		var row: Dictionary = fact.changes
		if row.get("version") != VERSION or fact.turn < policy.turn or not row.get("snapshot") is Dictionary: return ["Unknown prayer supply fact policy"]
		var sample: Dictionary = row.snapshot
		if sample.size() != 4 or str(sample.get("phase")) != "turn_supply" or sample.get("turn") != fact.turn or not sample.get("commit_seq") is int or not sample.get("fact_cutoff") is int or sample.fact_cutoff >= number: return ["Invalid prayer supply frozen input"]
		var window_id: String = str(Store.entry(state.applied_authorizations, "prayer/supply/window/" + str(sample.commit_seq), ""))
		var window: Dictionary = _fact(state, window_id)
		if window.get("kind") != "prayer_supply_window" or window.changes.get("snapshot") != sample or window.changes.get("policy") != policy_id: return ["Prayer supply lost its actual window"]
		if kind == "prayer_supply_window":
			if fact.id != window_id or not policy_id in fact.causal_parents or row.get("minimum") != content.integer("prayer_response_limit") or not row.get("offered_before") is Array: return ["Invalid prayer supply window"]
		elif kind == "prayer_supply_admitted":
			var source: String = str(row.get("source", ""))
			if row.get("window") != window_id or row.get("visible_turn") != fact.turn or not source in fact.causal_parents or not window_id in fact.causal_parents or _fact(state, source).get("kind") != "prayer_situation" or Store.entry(state.applied_authorizations, "prayer/supply/source/" + source, "") != fact.id: return ["Invalid current-turn supply admission"]
		elif kind == "prayer_supply_attempt":
			if row.get("window") != window_id or not window_id in fact.causal_parents or not row.get("origins") is Dictionary or not row.get("origin_selected") is Dictionary or not row.get("choice") is Dictionary or not row.get("produced") is String: return ["Invalid prayer supply producer receipt"]
			if Store.entry(state.applied_authorizations, "prayer/supply/attempt/" + str(number), "") != fact.id: return ["Supply attempt lost its unique receipt index"]
			if row.get("outcome") == "fixed":
				var source: String = row.produced
				var fixed: Dictionary = _fact(state, str(Store.entry(state.applied_authorizations, "prayer/source/" + source, "")))
				var grant_fact: Dictionary = _fact(state, str(Store.entry(state.applied_authorizations, "prayer/supply/source/" + source, "")))
				if fixed.get("kind") != "prayer_fixed" or fixed.changes.candidate.source != source or fixed.changes.candidate.visible_turn != fact.turn or fixed.changes.candidate.snapshot_version != sample.commit_seq or not source in fact.causal_parents or grant_fact.get("kind") != "prayer_supply_admitted" or grant_fact.changes.get("window") != window_id: return ["Supply claim has no actual fixed request"]
		else: return ["Unregistered prayer supply fact"]
	return []
