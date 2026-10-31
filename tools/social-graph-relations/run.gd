extends "res://tools/social-graph-initialization/run.gd"
## Fresh execution of protected initialization checks plus relation components.
const Events = preload("res://src/game/events.gd")
const View = preload("res://src/simulation/state_view.gd")

class RetirementRow extends Prayers:
	## Select a real authored row to isolate its actual production interpreter.
	## No target condition, receipt, writer or validator is replaced.
	func _rows(content: String, variant: String, stage: String) -> Array:
		return super._rows(content, variant, stage).filter(func(row: Dictionary) -> bool: return row.id == "PRAYER_03/deep/success/02")

class RelationFaultWorld extends World:
	var reject_relation_commit: bool = false
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_relation_commit and World.canonical(candidate.social_graph.edge_heads) != World.canonical(trusted.social_graph.edge_heads): issues.append("QA injected post-relation publication rejection")
		return issues

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("SGI-CATALOG", loaded, {"errors": catalog.errors})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	scratch = args[0].get_base_dir()
	if loaded:
		_catalog_cases()
		_control_cases()
		_world_cases()
		_business_cases()
		_lifecycle_cases()
		_state_cases()
		_scale_cases()
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	_write(args[0], {"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string,
		"checks": checks, "executionScope": "real_social_graph_relation_lifecycle_components",
		"inheritedRegression": {"suite": "social-graph-initialization", "expectedChecks": 50, "unchangedChecks": 48, "writerPrerequisitesAdaptedToCurrentProofContract": 2, "actuallyExecutedHere": true},
		"limitations": ["The protected initialization test functions execute again in this new archive.", "Current relation components do not establish a complete prayer/event response or natural request.", "Strong joint birth-provenance restore, complete Session and both parent acceptances remain downstream."]})
	quit(0 if passed else 1)

func _owned(seed_value: int = 7, faulty: bool = false) -> Dictionary:
	var world: RefCounted = RelationFaultWorld.new(catalog) if faulty else World.new(catalog)
	var valid: bool = world.generate(seed_value)
	var owner: RefCounted = Turn.new(world)
	return {"world": world, "owner": owner, "valid": valid and owner._attached, "sequence": 0}

func _apply(data: Dictionary, operation: Callable) -> Dictionary:
	data.sequence += 1
	var transaction: RefCounted = Transaction.new(data.world, data.owner.context.duplicate(true), data.sequence)
	if not data.valid or not transaction.activate():
		return {"ok": false, "error": transaction.error, "value": {}, "issues": []}
	data.world.stage_current()
	var value: Variant = operation.call()
	var accepted: bool = value.get("ok", false) if value is Dictionary else value == true
	var issues: Array = transaction.validate_world()
	if accepted and issues.is_empty(): transaction.publish()
	else: transaction.rollback()
	return {"ok": accepted and issues.is_empty(), "value": value, "issues": issues, "rolledBack": not accepted or not issues.is_empty()}

func _event_component(data: Dictionary, event: String, a: String, b: String, origin: String, swap: bool = false, omit_effect: bool = false) -> Dictionary:
	var world: RefCounted = data.world
	var id: String = "EVENT_03/A/03" if event == "EVENT_03" else "EVENT_09/A/02"
	var subjects: Dictionary = {"former": a, "cooperator": b} if event == "EVENT_03" else {"cooperator": a, "opponent": b}
	var descriptor: Dictionary = {"content_id": event, "domain": Store.entry(world.state.npcs, a).domain, "institution": Store.entry(world.state.npcs, a).institution, "actors": [a, b], "subjects": subjects, "facts": {"relation": origin, "relations": [origin]}, "source": origin, "source_ids": [origin]}
	var result: String = world._record("event_result", descriptor.domain, "", [a, b], [origin], {"event": "relation-component-" + str(data.sequence), "content_id": event, "option": "A", "descriptor": descriptor.duplicate(true), "operations": [id], "payment": "", "default": true})
	world.stage_collections(["applied_authorizations"])
	Store.put(world.state.applied_authorizations, "event/resolved/relation-component-" + str(data.sequence), result)
	if swap:
		if event == "EVENT_03": descriptor.subjects.former = b; descriptor.subjects.cooperator = a
		else: descriptor.subjects.cooperator = b; descriptor.subjects.opponent = a
	var service: RefCounted = Events.new(catalog)
	var accepted: bool = true if omit_effect else service._operation(world, descriptor, "A", catalog.tables.event_operations[id], result, data.owner, "")
	var kind: String = "favor_owed" if event == "EVENT_03" else "hostile"
	return {"ok": accepted, "proof": result, "a": a, "b": b, "kind": kind, "head": str(History.mapget(world.state.social_graph.edge_heads, Graph.edge_key(a, b, kind, "directed"), "")), "descriptor": descriptor}

func _prayer_component(data: Dictionary, a: String, b: String, disclosure: String) -> Dictionary:
	var world: RefCounted = data.world
	var source: String = world.introduce_fact("message", Store.entry(world.state.npcs, a).domain, a, [a], [disclosure], {"fixture": "explicit prayer-success component input, not a naturally generated request"}, [], [], data.owner)
	var plan: Dictionary = {"request": "relation-prayer-component-" + str(data.sequence), "variant": "shallow", "actor": a, "produced": {}, "descriptor": {"content_id": "PRAYER_10", "domain": Store.entry(world.state.npcs, a).domain, "institution": Store.entry(world.state.npcs, a).institution, "source": source, "subjects": {"petitioner": a, "opponent": b}, "facts": {"relation": disclosure}}}
	var outer: Dictionary = _begin_prayer(data, plan)
	var accepted: bool = Prayers.new(catalog)._apply_rows(world, plan, "success", "success", outer.check, data.owner)
	_finish_prayer(data, plan, outer)
	return {"ok": accepted, "proof": str(plan.produced.get("hostility", "")), "produced": plan.produced.duplicate(true), "a": b, "b": a, "kind": "hostile", "head": str(History.mapget(world.state.social_graph.edge_heads, Graph.edge_key(b, a, "hostile", "directed"), ""))}

func _begin_prayer(data: Dictionary, plan: Dictionary) -> Dictionary:
	var world: RefCounted = data.world
	var domain: String = plan.descriptor.domain
	var actors: Array = plan.descriptor.subjects.values().filter(func(id: Variant) -> bool: return id is String and Store.has(world.state.npcs, id))
	plan.descriptor["actors"] = actors
	var registered: String = world._record("prayer_registered", domain, plan.actor, actors, [plan.descriptor.source], {"request": plan.request, "source": plan.descriptor.source, "descriptor": plan.descriptor.duplicate(true), "due": world.state.turn + 2})
	var fee: int = catalog.integer("prayer_" + plan.variant + "_faith")
	var whispers: int = catalog.integer("prayer_" + plan.variant + "_whispers")
	var payment: String = world._record("turn_action", domain, "", [], [registered], {"outcome": "prayer_attempt", "faith_cost": fee, "whispers_cost": whispers, "fixture": "outer payment/check prerequisites; not full Turn response acceptance"})
	var attempt: String = world._record("prayer_attempt", domain, plan.actor, actors, [registered, plan.descriptor.source, payment], {"request": plan.request, "variant": plan.variant, "actor": plan.actor, "descriptor": plan.descriptor.duplicate(true), "p": 80, "probability": 80, "payment": payment, "preparations": []})
	var checked: String = world._record("turn_check", domain, plan.actor, [plan.actor], [attempt], {"probability": 80, "roll": 50, "outcome": world.check_result(80, 50)})
	return {"attempt": attempt, "check": checked, "payment": payment, "registered": registered}

func _finish_prayer(data: Dictionary, plan: Dictionary, outer: Dictionary) -> String:
	var result: String = data.world._record("prayer_result", plan.descriptor.domain, plan.actor, [plan.actor], [outer.attempt, outer.check], {"request": plan.request, "prayer": plan.descriptor.content_id, "variant": plan.variant, "actor": plan.actor, "p": 80, "roll": 50, "outcome": "success", "produced": plan.produced.duplicate(true)})
	data.world.stage_collections(["applied_authorizations"])
	Store.put(data.world.state.applied_authorizations, "prayer/response/" + plan.request, result)
	return result

func _writer_cases() -> void:
	# Two initialization assertions keep their original strength while their
	# old receipt-only inputs acquire the newly required complete proof chain.
	var data: Dictionary = _owned()
	var world: RefCounted = data.world
	var original: Dictionary = _first_relation(world)
	var a: String = original.changes.a; var b: String = original.changes.b
	var first: Dictionary = _apply(data, func() -> Dictionary: return _prayer_component(data, a, b, original.id))
	var count: int = _facts(world, "relationship").size()
	var second: Dictionary = _apply(data, func() -> Dictionary: return _prayer_component(data, a, b, original.id))
	var source: String = str(first.value.get("head", ""))
	_check("SGI-RELATION/MANAGED-WRITER", first.ok and second.ok and count == 1 and _facts(world, "relationship").size() == count and second.value.get("head") == source and first.value.get("proof") != second.value.get("proof"), {"attempts": [first, second], "relationshipCount": count, "scope": "Current prerequisite adaptation only: complete managed outer proof fixtures plus actual PR10 _apply_rows; original two independent business proofs / single episode assertion retained."})
	var before: String = world.snapshot()
	var rejected: Array = []
	var result: Dictionary = _apply(data, func() -> Dictionary:
		var outsider: String = str(_people(world, "DOMAIN-002")[0])
		rejected.append(world.establish_relation(b, a, "cooperation", [world.state.domains[original.domain].origin], [], data.owner))
		rejected.append(world.establish_relation(a, a, "hostile", [first.value.proof], [], data.owner))
		rejected.append(world.establish_relation(b, a, "hostile", [first.value.proof], [outsider], data.owner))
		return {"ok": false})
	_check("SGI-RELATION/WRITER-REJECT-SOURCE", not result.ok and rejected.size() == 3 and rejected.all(func(row: Dictionary) -> bool: return not row.get("ok", true)) and before == world.snapshot(), {"responses": rejected, "snapshotUnchanged": before == world.snapshot(), "scope": "Same missing source/self endpoint/third-party recipient assertions under the current proof prerequisites."})

func _retire_component(data: Dictionary, head: String, failed_check: bool = false) -> Dictionary:
	var world: RefCounted = data.world
	var relation: Dictionary = Graph.relation_data(Store.entry(world.state.facts, head, {}), catalog)
	if relation.is_empty(): return {"ok": false, "error": "No actual episode to pursue"}
	var a: String = relation.a; var b: String = relation.b
	var domain: String = Store.entry(world.state.facts, head).domain
	var institution: String = Store.entry(world.state.npcs, a).institution
	var pursuit: String = world.introduce_fact("pursuit_condition", domain, a, [a, b], [head], {"subject": a, "pursuer": b, "institution": institution, "relation": head, "clue": head, "due": world.state.turn + 3}, [], [], data.owner)
	var source: String = world.introduce_fact("message", domain, a, [a], [pursuit], {"fixture": "existing pursuit response outer context; not natural PR03 production"}, [], [], data.owner)
	# Keep only the real descriptor's pursuit root here. The exact head is
	# reached through that actual pursuit, not an invented direct receipt edge.
	var plan: Dictionary = {"request": "retirement-component-" + str(data.sequence), "variant": "deep", "actor": a, "produced": {}, "descriptor": {"content_id": "PRAYER_03", "domain": domain, "institution": institution, "source": source, "subjects": {"petitioner": a, "pursuer": b}, "facts": {"pursuit": pursuit}}}
	var outer: Dictionary = _begin_prayer(data, plan)
	if failed_check:
		var failed: String = world._record("turn_check", domain, a, [a], [outer.attempt], {"probability": 80, "roll": 90, "outcome": "failure"})
		outer.check = failed
	var service: RefCounted = RetirementRow.new(catalog)
	var accepted: bool = service._apply_rows(world, plan, "success", "success", outer.check, data.owner)
	var final: String = _finish_prayer(data, plan, outer)
	return {"ok": accepted, "head": head, "receipt": str(plan.produced.get("pursuit_relation_withdrawn", "")), "pursuit": pursuit, "final": final, "outer": outer, "scope": "Exact authored PR03 retirement row interpreted by real _apply_rows; registered/payment/attempt/check/final records are explicit managed outer prerequisites, not a complete prayer response."}

func _lifecycle_cases() -> void:
	var data: Dictionary = _owned()
	var world: RefCounted = data.world
	var initial: Dictionary = _first_relation(world)
	var a: String = initial.changes.a; var b: String = initial.changes.b
	var before_neighbors: Dictionary = world.contact_page(a)
	var first: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
	var old_head: String = str(first.value.get("head", ""))
	var proof: String = str(first.value.get("proof", ""))
	var alias: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
	var alias_proof: String = str(alias.value.get("proof", ""))
	var favors: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_03", a, b, initial.id))
	var reverse: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", b, a, initial.id))
	var pairs: Array = world.relation_between(a, b)
	var multi: bool = first.ok and favors.ok and reverse.ok and [old_head, favors.value.head, reverse.value.head].all(func(id: String) -> bool: return pairs.any(func(item: Dictionary) -> bool: return item.source == id))
	_check("SGR-RELATION/MULTI-TYPE", multi and world.contact_page(a).items.size() == before_neighbors.items.size(), {"relations": pairs, "originalContacts": before_neighbors, "contactsAfterMultipleTypes": world.contact_page(a), "distinctNeighborsUnchanged": world.contact_page(a).items.size() == before_neighbors.items.size()})
	_check("SGR-RELATION/REVERSE-DIRECTED", multi and old_head != reverse.value.head and world.relation_between(b, a, ["hostile"]).size() == 2 and world.relation_source(old_head).get("a") == a and world.relation_source(reverse.value.head).get("a") == b, {"forwardEpisode": world.relation_source(old_head), "reverseEpisode": world.relation_source(reverse.value.head)})
	var mutual: Dictionary = {}
	for candidate: Dictionary in _facts(world, "initial_relationship"):
		if candidate.changes.direction == "mutual": mutual = candidate; break
	var mutual_ok: bool = not mutual.is_empty()
	if mutual_ok:
		var original_state: String = world.snapshot()
		mutual_ok = mutual.changes.a < mutual.changes.b and world.relation_between(mutual.changes.a, mutual.changes.b, [mutual.changes.kind]) == world.relation_between(mutual.changes.b, mutual.changes.a, [mutual.changes.kind]) and world.add_relation(mutual.changes.a, mutual.changes.b, mutual.changes.kind, mutual.id, data.owner) and world.add_relation(mutual.changes.b, mutual.changes.a, mutual.changes.kind, mutual.id, data.owner) and world.snapshot() == original_state
	_check("SGR-RELATION/MUTUAL", mutual_ok, {"actualInitialMutualFact": mutual, "scope": "Real generated mutual relation, both lookup orientations and compatibility dedup; no new mutual-producing business is invented."})
	var historical: String = World.canonical(Store.entry(world.state.facts, old_head))
	var retired: Dictionary = _apply(data, func() -> Dictionary: return _retire_component(data, old_head))
	var receipt: String = str(retired.value.get("receipt", ""))
	var withdrawal: Dictionary = Store.entry(world.state.facts, receipt, {})
	_check("SGR-RETIRE/EXACT", retired.ok and Store.entry(world.state.invalid_records, old_head, "") == receipt and not receipt.is_empty() and retired.value.pursuit in withdrawal.get("causal_parents", []) and Store.entry(world.state.facts, retired.value.pursuit).changes.get("relation") == old_head, {"result": retired, "actualReceipt": withdrawal, "headReachedThroughActualPursuit": Store.entry(world.state.facts, retired.value.pursuit).changes.get("relation") == old_head, "headIsDirectParentNotRequired": old_head in withdrawal.get("causal_parents", [])})
	_check("SGR-RETIRE/HEAD-INDEX", retired.ok and world.relation_source(old_head).is_empty() and not world.history.relation(a, b, old_head).is_empty() and World.canonical(Store.entry(world.state.facts, old_head)) == historical and not world.relation_source(favors.value.head).is_empty() and not world.relation_source(reverse.value.head).is_empty(), {"retiredCurrentLookup": world.relation_source(old_head), "historicalLookup": world.history.relation(a, b, old_head), "otherTypesAndReverseRetained": not world.relation_source(favors.value.head).is_empty() and not world.relation_source(reverse.value.head).is_empty()})
	var before: String = world.snapshot()
	var deleted_alias: Dictionary = _apply(data, func() -> Dictionary:
		world.stage_collections(["applied_authorizations"])
		Store.erase(world.state.applied_authorizations, "social/relation/proof/" + alias_proof)
		return {"ok": true})
	_check("SGR-RETIRE/REJECT-DELETE-ALIAS", alias.ok and not deleted_alias.ok and not deleted_alias.issues.is_empty() and world.snapshot() == before, {"result": deleted_alias, "aliasProof": alias_proof, "fullStateUnchanged": world.snapshot() == before})
	var repeat: Dictionary = _apply(data, func() -> Dictionary: return world.retire_relation(old_head, receipt, data.owner))
	_check("SGR-RETIRE/REPEAT", repeat.ok and repeat.value.get("existing") == true and world.snapshot() == before, {"result": repeat, "stateUnchanged": world.snapshot() == before})
	var reused: Dictionary = _apply(data, func() -> Dictionary: return world.establish_relation(a, b, "hostile", [proof, initial.id], [], data.owner))
	_check("SGR-RETIRE/OLD-PROOF", reused.ok and reused.value.get("source") == old_head and world.relation_source(old_head).is_empty() and world.snapshot() == before, {"result": reused, "retiredNotRevived": world.relation_source(old_head).is_empty(), "stateUnchanged": world.snapshot() == before})
	var replacement: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
	var new_head: String = str(replacement.value.get("head", ""))
	_check("SGR-RETIRE/NEW-EPISODE", replacement.ok and new_head != old_head and not world.relation_source(new_head).is_empty() and world.relation_source(old_head).is_empty(), {"oldEpisode": old_head, "newEpisode": new_head, "result": replacement})
	var late_alias: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id))
	var late_proof: String = str(late_alias.value.get("proof", ""))
	before = world.snapshot()
	var stale: Dictionary = _apply(data, func() -> Dictionary: return world.retire_relation(old_head, receipt, data.owner))
	_check("SGR-RETIRE/OLD-RECEIPT", stale.ok and world.snapshot() == before and not world.relation_source(new_head).is_empty(), {"result": stale, "newEpisodeStillCurrent": world.relation_source(new_head), "stateUnchanged": world.snapshot() == before})
	var missing_alias: Dictionary = _apply(data, func() -> Dictionary: return _event_component(data, "EVENT_09", a, b, initial.id, false, true))
	_check("SGR-RETIRE/MISSING-ALIAS-BINDING", not missing_alias.ok and not missing_alias.issues.is_empty() and world.snapshot() == before, {"result": missing_alias, "fullStateUnchanged": world.snapshot() == before, "scope": "Adversarial outer result claims the authored relation operation but omits its actual effect/once consumption; must not be accepted."})
	var rebound: Dictionary = _apply(data, func() -> Dictionary:
		world.stage_collections(["applied_authorizations"])
		Store.put(world.state.applied_authorizations, "social/relation/proof/" + proof, new_head)
		return {"ok": true})
	_check("SGR-RETIRE/REJECT-REBIND", not rebound.ok and not rebound.issues.is_empty() and world.snapshot() == before, {"result": rebound, "oldProofBindingUnchanged": world.snapshot() == before, "scope": "Adversarial existing once-binding replacement inside an actual transaction; validator must reject."})
	var invalidation: Dictionary = _apply(data, func() -> Dictionary:
		world.stage_collections(["invalid_records"])
		Store.put(world.state.invalid_records, new_head, world.state.domains[initial.domain].origin)
		return {"ok": true})
	_check("SGR-RETIRE/UNAUTHORIZED-INVALIDATION", not invalidation.ok and not invalidation.issues.is_empty() and world.snapshot() == before, {"result": invalidation, "headAndWorldUnchanged": world.snapshot() == before, "scope": "Adversarial ordinary origin as fake retirement; no test fixture is accepted as a real retirement."})
	for name: String in ["ORIGIN", "HEAD"]:
		var target: String = new_head
		var cause: String = world.state.domains[initial.domain].origin if name == "ORIGIN" else receipt
		var denied: Dictionary = _apply(data, func() -> Dictionary: return world.retire_relation(target, cause, data.owner))
		_check("SGR-RETIRE/REJECT-" + name, not denied.ok and world.snapshot() == before, {"result": denied, "stateUnchanged": world.snapshot() == before})
	var failed: Dictionary = _apply(data, func() -> Dictionary: return _retire_component(data, new_head, true))
	_check("SGR-RETIRE/FAILED-CHECK", not failed.ok and not failed.value.get("ok", true) and world.snapshot() == before, {"result": failed, "actualRetirementInterpreterRefused": not failed.value.get("ok", true), "fullStateUnchanged": world.snapshot() == before})
	_relation_views(data, a, b, new_head)
	_local_save_cases(world, new_head, old_head, receipt, late_proof)
	var fault: Dictionary = _owned(7, true)
	var seed_relation: Dictionary = _first_relation(fault.world)
	var stable: String = fault.world.snapshot()
	fault.world.reject_relation_commit = true
	var rolled: Dictionary = _apply(fault, func() -> Dictionary: return _event_component(fault, "EVENT_09", seed_relation.changes.a, seed_relation.changes.b, seed_relation.id))
	var creation_atomic: bool = not rolled.ok and rolled.rolledBack and fault.world.snapshot() == stable
	fault.world.reject_relation_commit = false
	var actual: Dictionary = _apply(fault, func() -> Dictionary: return _event_component(fault, "EVENT_09", seed_relation.changes.a, seed_relation.changes.b, seed_relation.id))
	stable = fault.world.snapshot()
	fault.world.reject_relation_commit = true
	var retired_fault: Dictionary = _apply(fault, func() -> Dictionary: return _retire_component(fault, str(actual.value.get("head", ""))))
	_check("SGR-RETIRE/ATOMIC", creation_atomic and actual.ok and not retired_fault.ok and retired_fault.rolledBack and fault.world.snapshot() == stable, {"creationFailure": rolled, "retirementFailure": retired_fault, "creationAtomic": creation_atomic, "retirementAndAllOuterSourcesRolledBack": fault.world.snapshot() == stable})

func _relation_views(data: Dictionary, a: String, b: String, source: String) -> void:
	var world: RefCounted = data.world
	var view: RefCounted = View.new(world.state, data.owner.context, 0, world.history)
	var current: Dictionary = view.relation_source(source)
	var exact: Dictionary = world.relation_source(source)
	if not current.is_empty(): current["kind"] = "QA_MUTATION"
	var forward: Array = view.relation_between(a, b)
	if not forward.is_empty(): forward[0]["a"] = "QA_MUTATION"
	_check("SGR-INDEX/DETACHED-SOURCE", not exact.is_empty() and world.relation_source(source) == exact and view.relation_source(source) == exact, {"exact": exact, "afterMutatingReturnedCopies": world.relation_source(source)})
	var all: Dictionary = view.contact_page(a)
	var merged: Array = []; var cursor: int = 0
	var legal: bool = all.get("ok", false)
	for ignored: int in 16:
		var page: Dictionary = view.contact_page(a, cursor, 1)
		legal = legal and page.get("ok", false) and page.get("items", []).size() <= 1
		merged.append_array(page.get("items", []))
		if page.get("complete", false): break
		legal = legal and int(page.get("cursor", -1)) > cursor
		cursor = int(page.get("cursor", -1))
	var ids: Array = merged.map(func(item: Dictionary) -> String: return str(item.person))
	var distinct: Dictionary = {}
	for id: String in ids: distinct[id] = true
	_check("SGR-INDEX/PAGINATION", legal and merged == all.items and distinct.size() == ids.size() and not view.contact_page(a, -1, 1).get("ok", true) and not view.contact_page(a, 0, world.history.page_limit + 1).get("ok", true), {"full": all, "singlePages": merged, "uniqueContacts": distinct.size()})
	view.close()
	_check("SGR-INDEX/CLOSED-VIEW", view.relation_source(source).is_empty() and view.relation_between(a, b).is_empty() and not view.contact_page(a).get("ok", true), {"closedSourceLookup": view.relation_source(source), "closedPage": view.contact_page(a)})

func _local_save_cases(world: RefCounted, current: String, retired: String, receipt: String, late_proof: String) -> void:
	var saved: String = world.snapshot()
	_write_text(scratch.path_join("relation-lifecycle-current-save.json"), saved)
	var restored: RefCounted = World.new(catalog)
	var admitted: bool = restored.restore(saved)
	var resigned: RefCounted = World.new(catalog)
	var normal: String = _resign(JSON.parse_string(saved))
	var good: bool = resigned.restore(normal)
	_check("SGR-SAVE/CURRENT-AND-RESIGNED", admitted and good and restored.snapshot() == saved and resigned.snapshot() == saved and restored.relation_source(retired).is_empty() and not restored.relation_source(current).is_empty(), {"restored": admitted, "unchangedResigned": good, "error": restored.last_error, "scope": "Necessary current relation proof/retirement closure only; full joint birth provenance and projection equivalence are deferred."})
	if not admitted: return
	var envelope: Dictionary = JSON.parse_string(saved)
	var proof: String = ""
	for key: String in envelope.body.state.applied_authorizations:
		if key.begins_with("social/relation/proof/") and envelope.body.state.applied_authorizations[key] == current: proof = key; break
	var missing: Dictionary = envelope.duplicate(true); missing.body.state.applied_authorizations.erase(proof)
	var alias_missing: Dictionary = envelope.duplicate(true)
	var alias_key: String = ""
	for key: String in alias_missing.body.state.applied_authorizations:
		if key.begins_with("social/relation/proof/") and alias_missing.body.state.applied_authorizations[key] == retired and not key.trim_prefix("social/relation/proof/") in alias_missing.body.state.facts[retired].causal_parents: alias_key = key; break
	alias_missing.body.state.applied_authorizations.erase(alias_key)
	# Move only a later alias. Keep the new episode's primary proof intact so
	# rejection must identify the retirement-before-new-proof temporal defect.
	var rebound: Dictionary = envelope.duplicate(true)
	rebound.body.state.applied_authorizations["social/relation/proof/" + late_proof] = retired
	var wrong: Dictionary = envelope.duplicate(true); wrong.body.state.invalid_records[retired] = envelope.body.state.domains["DOMAIN-001"].origin
	var final: Dictionary = envelope.duplicate(true)
	var request: String = str(final.body.state.facts[receipt].changes.request)
	var result_id: String = str(final.body.state.applied_authorizations["prayer/response/" + request])
	final.body.state.facts[result_id].changes.produced.erase("pursuit_relation_withdrawn")
	var old: Dictionary = envelope.duplicate(true); old.body.schema = 2
	for item: Dictionary in [{"id": "MISSING-PROOF", "value": missing}, {"id": "MISSING-ALIAS", "value": alias_missing}, {"id": "REBOUND-PROOF", "value": rebound}, {"id": "INVALID-RETIREMENT", "value": wrong}, {"id": "INCOMPLETE-RESULT", "value": final}, {"id": "OLD-WORLD-2", "value": old}]:
		var before: String = restored.snapshot()
		var input: String = _resign(item.value)
		_write_text(scratch.path_join("bad-relation-save-" + item.id + ".json"), input)
		var accepted: bool = restored.restore(input)
		var isolated: bool = true
		if item.id == "REBOUND-PROOF": isolated = not late_proof.is_empty() and late_proof > receipt and envelope.body.state.applied_authorizations.get("social/relation/proof/" + late_proof) == current and rebound.body.state.applied_authorizations.get(proof) == current and restored.last_error.contains("already retired")
		_check("SGR-SAVE/" + item.id, not accepted and restored.snapshot() == before and isolated, {"accepted": accepted, "correctChecksum": true, "error": restored.last_error, "currentWorldRetained": restored.snapshot() == before, "isolatedTemporalBranch": isolated if item.id == "REBOUND-PROOF" else null, "newEpisodePrimaryProofRetained": rebound.body.state.applied_authorizations.get(proof) == current if item.id == "REBOUND-PROOF" else null})

func _business_cases() -> void:
	for content: String in ["PRAYER_10", "EVENT_03", "EVENT_09"]:
		var data: Dictionary = _owned()
		var world: RefCounted = data.world
		var initial: Dictionary = _first_relation(world)
		var a: String = initial.changes.a; var b: String = initial.changes.b
		var invoke: Callable = func() -> Dictionary: return _prayer_component(data, a, b, initial.id) if content == "PRAYER_10" else _event_component(data, content, a, b, initial.id)
		var first: Dictionary = _apply(data, invoke)
		var value: Dictionary = first.value
		var source: String = str(value.get("head", ""))
		var proof: String = str(value.get("proof", ""))
		var exact: Dictionary = Graph.relation_data(Store.entry(world.state.facts, source, {}), catalog)
		var correct: bool = first.ok and not source.is_empty() and exact.get("a") == value.a and exact.get("b") == value.b and exact.get("kind") == value.kind and exact.get("direction") == "directed" and proof in Store.entry(world.state.facts, source, {}).get("causal_parents", [])
		_check("SGR-BUSINESS/" + content + "/WRITE", correct, {"result": first, "actualRelationship": exact, "scope": "Actual authored relation-consequence handler in a managed transaction; event_result or success input is an explicit outer-result fixture, not a full/natural prayer or event transaction."})
		var count: int = _facts(world, "relationship").size()
		var second: Dictionary = _apply(data, invoke)
		var second_proof: String = str(second.value.get("proof", ""))
		var bindings: bool = Store.entry(world.state.applied_authorizations, "social/relation/proof/" + proof, "") == source and Store.entry(world.state.applied_authorizations, "social/relation/proof/" + second_proof, "") == source
		_check("SGR-BUSINESS/" + content + "/IDEMPOTENT", correct and second.ok and second.value.get("head") == source and _facts(world, "relationship").size() == count and proof != second_proof and bindings, {"firstProof": proof, "secondProof": second_proof, "head": source, "relationshipCountBefore": count, "relationshipCountAfter": _facts(world, "relationship").size(), "proofsBothConsumed": bindings})
		var original: String = world.snapshot()
		var denied: Dictionary = _apply(data, func() -> Dictionary: return world.establish_relation(value.a, value.b, value.kind, [initial.id], [], data.owner))
		_check("SGR-BUSINESS/" + content + "/REJECT-SOURCE", not denied.ok and denied.rolledBack and world.snapshot() == original, {"result": denied, "fullStateUnchanged": world.snapshot() == original})
		var unsupported: Dictionary = _apply(data, func() -> Dictionary: return world.establish_relation(value.b, value.a, value.kind, [proof], [], data.owner))
		_check("SGR-BUSINESS/" + content + "/REJECT-DIRECTION", not unsupported.ok and world.snapshot() == original, {"result": unsupported, "fullStateUnchanged": world.snapshot() == original})
		var replay: Dictionary = _apply(data, func() -> Dictionary: return world.establish_relation(value.a, value.b, value.kind, [proof, initial.id], [], data.owner))
		_check("SGR-BUSINESS/" + content + "/REPLAY", replay.ok and replay.value.get("source") == source and _facts(world, "relationship").size() == count, {"result": replay, "originalEpisode": source})
	# Isolate the actual PR10 row's knows_disclosure condition. The disclosure
	# fact is genuine but deliberately not an endpoint fact of this opponent.
	var negative: Dictionary = _owned()
	var fact: Dictionary = _first_relation(negative.world)
	var petitioner: String = fact.changes.a
	var opponent: String = ""
	for id: String in _people(negative.world, fact.domain):
		if not id in [fact.changes.a, fact.changes.b]: opponent = id; break
	var conditional: Dictionary = _apply(negative, func() -> Dictionary: return _prayer_component(negative, petitioner, opponent, fact.id))
	_check("SGR-BUSINESS/PRAYER_10/UNKNOWN-DISCLOSURE", conditional.ok and conditional.value.get("proof", "").is_empty() and _facts(negative.world, "relationship").is_empty(), {"result": conditional, "scope": "Row-condition isolation with a genuine unknown disclosure fact; this is not admission of a complete PR10 situation."})

func _first_relation(world: RefCounted, cross: bool = false) -> Dictionary:
	for fact: Dictionary in _facts(world, "initial_relationship"):
		if not cross or Store.entry(world.state.npcs, fact.changes.a).institution != Store.entry(world.state.npcs, fact.changes.b).institution:
			return fact
	return {}

func _stable_relation(world: RefCounted, source: String, before: String, graph_before: String) -> bool:
	return World.canonical(Store.entry(world.state.facts, source, {})) == before and World.canonical(world.state.social_graph) == graph_before

func _state_cases() -> void:
	var data: Dictionary = _owned()
	var world: RefCounted = data.world
	var fact: Dictionary = _first_relation(world, true) if data.valid else {}
	if fact.is_empty():
		for id: String in ["MISSING", "DETAINED", "RESTORED", "MIGRATION", "DEATH", "INSTITUTION", "CHANNEL"]:
			_check("SGR-STATE/" + id, false, {"error": "No real generated cross-institution relation"})
		return
	var a: String = fact.changes.a; var b: String = fact.changes.b
	var person_id: String = a
	var initial: String = World.canonical(fact)
	var graph: String = World.canonical(world.state.social_graph)
	var known: String = World.canonical(Store.entry(world.state.npcs, b).known_facts)
	for status: String in ["missing", "detained", "active"]:
		var result: Dictionary = _apply(data, func() -> bool: return world.submit({"kind": "status", "npc": person_id, "status": status, "parents": [fact.id]}, data.owner))
		var eligible: bool = not world.contact_context(a, b).is_empty()
		var id: String = {"missing": "MISSING", "detained": "DETAINED", "active": "RESTORED"}[status]
		_check("SGR-STATE/" + id, result.ok and eligible == (status == "active") and _stable_relation(world, fact.id, initial, graph), {"result": result, "contactEligible": eligible, "stableHistoryAndHeads": _stable_relation(world, fact.id, initial, graph)})
	var original_domain: String = Store.entry(world.state.npcs, a).domain
	var target: String = str(world.state.domains[original_domain].neighbors[0])
	var moved: Dictionary = _apply(data, func() -> bool: return world.submit({"kind": "migrate", "npc": person_id, "domain": target, "parents": [fact.id]}, data.owner))
	_check("SGR-STATE/MIGRATION", moved.ok and world.contact_context(a, b).is_empty() and Store.entry(world.state.npcs, a).domain == target and _stable_relation(world, fact.id, initial, graph), {"result": moved, "target": target, "stableHistoryAndHeads": _stable_relation(world, fact.id, initial, graph)})
	var dead: Dictionary = _apply(data, func() -> bool: return world.submit({"kind": "status", "npc": person_id, "status": "dead", "parents": [fact.id]}, data.owner))
	_check("SGR-STATE/DEATH", dead.ok and world.contact_context(a, b).is_empty() and _stable_relation(world, fact.id, initial, graph) and World.canonical(Store.entry(world.state.npcs, b).known_facts) == known, {"result": dead, "historicalRelationRetained": _stable_relation(world, fact.id, initial, graph), "otherEndpointKnowledgeUnchanged": World.canonical(Store.entry(world.state.npcs, b).known_facts) == known, "ownStatusKnowledgeAllowed": true})
	# No production institution/link mutation command currently exists. These
	# explicit current-state fixtures test qualification reads, not a new actor.
	var fresh: RefCounted = World.new(catalog)
	var ready: bool = fresh.generate(7)
	var relation: Dictionary = _first_relation(fresh, true) if ready else {}
	var left: String = relation.changes.a; var right: String = relation.changes.b
	var office_a: String = Store.entry(fresh.state.npcs, left).institution
	var office_b: String = Store.entry(fresh.state.npcs, right).institution
	var saved: String = World.canonical(fresh.state.social_graph)
	fresh.state.institutions[office_a].active = false
	var inactive: bool = fresh.contact_context(left, right).is_empty()
	fresh.state.institutions[office_a].active = true
	_check("SGR-STATE/INSTITUTION", ready and inactive and not fresh.contact_context(left, right).is_empty() and saved == World.canonical(fresh.state.social_graph), {"inactiveDenied": inactive, "restoredAllowed": not fresh.contact_context(left, right).is_empty(), "scope": "Explicit current institution eligibility fixture; no institution-operation production claim."})
	fresh.state.institutions[office_a].links.erase(office_b)
	var one_way: bool = fresh.contact_context(left, right).is_empty()
	fresh.state.institutions[office_a].links.append(office_b)
	_check("SGR-STATE/CHANNEL", ready and one_way and not fresh.contact_context(left, right).is_empty() and saved == World.canonical(fresh.state.social_graph), {"oneWayDenied": one_way, "restoredMutualChannelAllowed": not fresh.contact_context(left, right).is_empty(), "scope": "Explicit current link fixture; no historical link source is forged or submitted for acceptance."})

func _scale_cases() -> void:
	var samples: Array = []
	var valid: bool = true
	for amount: int in [0, 256, 2048]:
		var world: RefCounted = World.new(catalog)
		var ready: bool = world.generate(7)
		var origin: String = str(world.state.domains["DOMAIN-001"].origin)
		for at: int in amount:
			ready = ready and not world.introduce_fact("message", "DOMAIN-001", "", [], [origin], {"cold_fixture": at}, []).is_empty()
		var data: Dictionary = _clock(world)
		ready = ready and _open(data)
		var relation: Dictionary = _first_relation(world)
		var a: String = relation.changes.a; var b: String = relation.changes.b
		world.history.reset_metrics()
		var start: int = Time.get_ticks_usec()
		var view: RefCounted = View.new(world.state, data.turn.context, 0, world.history)
		var queried: Array = view.relation_between(a, b, [relation.changes.kind])
		var reverse: Array = view.relation_between(b, a, [relation.changes.kind])
		var page: Dictionary = view.contact_page(a, 0, 1)
		var exact: Dictionary = view.relation(a, b, relation.id)
		var current: Dictionary = view.relation_source(relation.id)
		var metrics: Dictionary = world.history.metrics.duplicate(true)
		var elapsed: int = Time.get_ticks_usec() - start
		var read_ok: bool = ready and queried.size() >= 1 and reverse.size() >= 1 and page.get("ok", false) and page.get("items", []).size() <= 1 and not exact.is_empty() and current.get("source") == relation.id and int(metrics.history_scanned) == 0 and int(metrics.rebuild_records) == 0
		var steps: Array = []
		for op: String in ["end_actions", "advance", "advance", "advance"]:
			world.history.reset_metrics()
			var result: Dictionary = _request(data, op)
			steps.append({"operation": op, "result": result, "metrics": world.history.metrics.duplicate(true)})
			read_ok = read_ok and result.get("ok", false) and int(world.history.metrics.history_scanned) == 0 and int(world.history.metrics.rebuild_records) == 0
		valid = valid and read_ok
		samples.append({"coldFacts": amount, "queries": {"forward": queried, "reverse": reverse, "page": page, "exact": exact, "currentSourceReverse": current}, "queryMetrics": metrics, "queryMicrosObservedOnly": elapsed, "steps": steps, "ok": read_ok})
	var envelopes: Array = []
	for sample: Dictionary in samples:
		var bounded: bool = true
		for field: String in ["tree_nodes_read", "output_sources", "current_entities", "copied_history_values"]:
			var query_limit: int = int(samples[0].queryMetrics[field]) * 4 + 256
			bounded = bounded and int(sample.queryMetrics[field]) <= query_limit
			for step: int in sample.steps.size():
				var step_limit: int = int(samples[0].steps[step].metrics[field]) * 4 + 256
				bounded = bounded and int(sample.steps[step].metrics[field]) <= step_limit
		valid = valid and bounded
		envelopes.append({"coldFacts": sample.coldFacts, "bounded": bounded})
	_write(scratch.path_join("cold-history-scaling.json"), {"samples": samples, "workEnvelope": envelopes})
	_check("SGR-INDEX/COLD-HISTORY", valid, {"samples": samples, "workEnvelope": envelopes, "scope": "Actual message facts supply cold history; same generated population, StateView point/page queries and real Turn end-of-round component transitions. Work-count ceiling is four times the matching zero-cold-history baseline plus 256, accommodating tree depth/current work; not an asymptotic proof. Time is observation only; no full Session claim."})
