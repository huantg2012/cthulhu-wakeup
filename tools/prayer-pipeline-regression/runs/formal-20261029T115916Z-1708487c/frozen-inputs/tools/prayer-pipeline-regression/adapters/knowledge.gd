extends "res://tools/prayer-producers/knowledge_regression.gd"
const Support = preload("res://tools/prayer-pipeline-regression/adapters/support.gd")

func _initialize() -> void:
	catalog = Catalog.new()
	var loaded: bool = catalog.load_files()
	_check("PK-CATALOG", "Formal current Catalog loads", loaded, {"errors": catalog.errors})
	if not loaded:
		_write_knowledge_report()
		return
	scratch = OS.get_cmdline_user_args()[0].get_base_dir().path_join("archives")
	assert(DirAccess.make_dir_recursive_absolute(scratch) == OK)
	for power: String in ["POWER_DREAM", "POWER_ORACLE"]:
		for outcome: String in ["deep", "success", "failure", "disaster"]:
			_knowledge_power(power, outcome)
		_knowledge_preview(power)
	for variant: String in ["shallow", "deep"]:
		for outcome: String in ["deep", "success", "failure", "disaster"]:
			_knowledge_devotion(variant, outcome)
	_knowledge_legacy()
	_knowledge_nonfollower()
	_knowledge_identity_replay()
	_knowledge_transaction_failure()
	if has_method("run_knowledge_source_cases"):
		call("run_knowledge_source_cases")
	_write_knowledge_report()

func _new_hybrid(seed_value: int = 7919) -> RefCounted:
	return Support.new_world(catalog, seed_value if qa_seed_override < 0 else qa_seed_override)

func _write_knowledge_report() -> void:
	Support.write_report(records, "current_knowledge_component_regression", ["Standalone source-backed identity prerequisites; actual old outcome and persistence assertions retained."], ["Explicit high-world and source prerequisites; no natural new game or complete Session."])
	quit(0 if records.all(func(row: Dictionary) -> bool: return row.status == "pass") else 1)

func _notice_fixture(variant: String) -> Dictionary:
	var data: Dictionary = _high()
	var world: RefCounted = data.world
	data.domain = "DOMAIN-001"
	var picked: Dictionary = Support.pair(world, ["support", "cooperation"], variant == "same_institution")
	assert(not picked.is_empty())
	data.sender = picked.a; data.recipient = picked.b
	data["micro_pair"] = picked.duplicate(true)
	if variant in ["same_batch_relation", "no_relation"]:
		data.recipient = "NPC-%08d" % int(world.state.next_npc)
		assert(world._nominate_local(data.domain, data.domain + "/interpretation", "NPC_PROFILE_01", world.state.domains[data.domain].origin))
	data.leader = data.sender
	var sender_institution: String = Store.entry(world.state.npcs, data.sender).institution
	var recipient_institution: String = Store.entry(world.state.npcs, data.recipient).institution
	data.relation = world.state.domains[data.domain].origin if variant in ["same_batch_relation", "no_relation"] else picked.source
	data.source = _given_fact(data, "devotion_contact", data.sender, [data.sender], {"subject": data.sender, "institution": sender_institution})
	if variant == "dead_recipient": assert(world.submit({"kind": "status", "npc": data.recipient, "status": "dead", "parents": [data.relation]}))
	_attach_notice_modules(data)
	var payload: Dictionary = _payload(data, "POWER_DREAM")
	_seed(data, "POWER_DREAM", "success", payload)
	assert(_open(data))
	if variant != "unidentified_sender": assert(_power(data, "POWER_DREAM", payload).ok)
	var due: int = int(world.state.simulation.cursors[data.domain].next_turn)
	while world.state.turn < due: assert(_evolve(data) and _finish(data) and _open(data))
	var route: String = "" if sender_institution == recipient_institution else recipient_institution
	if variant == "wrong_route": route = data.domain + ("/interpretation" if recipient_institution != data.domain + "/interpretation" else "/propagation")
	world.qa_notice = {"root_rule": "ROOT_IDENTITY_NOTICE", "domain": data.domain, "sender": data.sender, "recipient": data.recipient, "relation": data.relation, "route": route}
	world.qa_notice_late_relation = variant == "same_batch_relation"
	world.qa_notice_bad_coordinator = variant == "wrong_coordinator"
	if variant == "wrong_knowledge": world.qa_notice["knowledge"] = data.relation
	if variant == "cross_domain": world.qa_notice["recipient"] = data.guardians["DOMAIN-007"][0]
	return data

func _given_relation(data: Dictionary, first: String, second: String, kind: String) -> String:
	return Support.existing_relation(data.world, first, second, kind)

func _notice_cases() -> void:
	for variant: String in ["valid", "same_institution", "unidentified_sender", "no_relation", "wrong_route", "wrong_knowledge", "wrong_coordinator", "dead_recipient", "cross_domain"]:
		var data: Dictionary = _notice_fixture(variant)
		var prior: Dictionary = Knowledge.known(data.world.state, data.recipient)
		var evolved: bool = _evolve(data)
		var result: Dictionary = data.world.qa_notice_result
		var received: Array = _facts(data.world, "deity_identity_received")
		var current: Dictionary = Knowledge.known(data.world.state, data.recipient)
		var valid: bool = evolved and not prior.get("known", false)
		if variant in ["valid", "same_institution"]:
			valid = valid and result.get("authorization", {}).get("ok", false) and result.get("tell", {}).get("ok", false) and result.get("retry", {}).get("source") == result.get("tell", {}).get("source") and received.size() == 1 and current.get("known", false) and received[0].changes.get("person") == data.recipient and received[0].changes.get("sender") == data.sender
			if valid:
				var saved: String = data.turn.snapshot()
				valid = data.turn.restore(saved) and data.turn.snapshot() == saved and Knowledge.known(data.world.state, data.recipient) == current
				data.world.qa_notice = {}
				data.fixture.deadlines = [{"type": "world_command", "source": data.source, "command": {"kind": "status", "npc": data.sender, "status": "dead", "parents": [data.source]}}]
				valid = _finish(data) and valid and Knowledge.known(data.world.state, data.recipient) == current
				result["recipientKnowledgeAfterSenderDeath"] = Knowledge.known(data.world.state, data.recipient)
		else:
			valid = valid and not result.get("authorization", {}).get("ok", false) and received.is_empty() and not current.get("known", false)
		_check("PK-NOTICE/" + variant, "Managed actual Events selection transfers only sourced identity with valid frozen relationship and route", valid, {"evolved": evolved, "result": result, "received": received, "knowledge": current, "scope": "Explicit coordinator selection probe; automatic shared-opportunity scheduling remains ORIGINS"})

	_late_relation_equivalence()

func _late_relation_equivalence() -> void:
	var data: Dictionary = _notice_fixture("same_batch_relation")
	var before: String = data.turn.snapshot()
	var prior: Dictionary = Knowledge.known(data.world.state, data.recipient)
	# Preserve the original illegal assembly verbatim in inherited evolve:
	# raw relationship + add_relation after its frozen snapshot, no real proof.
	var evolved: bool = _evolve(data)
	var rejected: bool = not evolved and data.turn.snapshot() == before and not prior.get("known", false) and not Knowledge.known(data.world.state, data.recipient).get("known", false)
	_check("PPR-K-LEGACY-LATE-RELATION-REJECTED", "The old raw post-snapshot support assembly is atomically rejected by the current relation writer audit", rejected, {"evolved": evolved, "error": data.turn.last_error, "currentUnchanged": data.turn.snapshot() == before, "originalManagedAssembly": "Inherited KnowledgeRejectWorld.evolve, unchanged", "notApplicableAsLegalProducer": true})
	var original: String = FileAccess.get_file_as_string("res://src/game/prayer_knowledge.gd")
	var dependency: String = "var knowledge: Dictionary = known(state, sender.id, selection.snapshot)"
	var replacement: String = "var knowledge: Dictionary = {\"known\": true, \"source\": str(selection.get(\"knowledge\", \"\"))}"
	var guard: String = "if Store.has(state.invalid_records, relation) or _number(relation) > int(selection.snapshot.fact_cutoff): return false"
	var weakened_guard: String = "if Store.has(state.invalid_records, relation): return false"
	assert(original.count(dependency) == 1 and original.count(guard) == 1)
	# An explicitly controlled dependency seam in an in-memory microprobe:
	# no World knowledge, relationship, proof, gameplay file or save is changed.
	var controlled: String = original.replace(dependency, replacement)
	var counterfactual: String = controlled.replace(guard, weakened_guard)
	var generated: Array = []
	for item: Array in [["notice-controlled.gd", controlled], ["notice-counterfactual.gd", counterfactual]]:
		var path: String = scratch.path_join(item[0])
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		assert(file != null); file.store_string(item[1]); file.close()
		generated.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var baseline_script: GDScript = GDScript.new(); baseline_script.source_code = controlled
	var counter_script: GDScript = GDScript.new(); counter_script.source_code = counterfactual
	assert(baseline_script.reload() == OK and counter_script.reload() == OK)
	var picked: Dictionary = data.micro_pair
	var sender: Dictionary = Store.entry(data.world.state.npcs, picked.a); var recipient: Dictionary = Store.entry(data.world.state.npcs, picked.b)
	var selection: Dictionary = {"root_rule": "ROOT_IDENTITY_NOTICE", "domain": sender.domain, "sender": picked.a, "recipient": picked.b, "relation": picked.source, "route": "" if sender.institution == recipient.institution else recipient.institution, "knowledge": Knowledge.known(data.world.state, picked.a).get("source", ""), "snapshot": data.world.qa_snapshot.duplicate(true)}
	selection.snapshot.fact_cutoff = int(str(picked.source).trim_prefix("FACT-")) - 1
	var old_snapshot_rejects: bool = not baseline_script.call("_notice_objects", data.world, selection)
	var removal_flips: bool = counter_script.call("_notice_objects", data.world, selection)
	var fresh: Dictionary = selection.duplicate(true); fresh.snapshot.fact_cutoff = int(data.world.state.next_fact) - 1
	var fresh_accepts: bool = baseline_script.call("_notice_objects", data.world, fresh)
	var isolated: bool = old_snapshot_rejects and removal_flips and fresh_accepts and data.turn.snapshot() == before
	var evidence: Dictionary = {"oldSnapshotRejects": old_snapshot_rejects, "removingOnlyRelationCutoffFlipsToAccept": removal_flips, "freshSnapshotAccepts": fresh_accepts, "sourceSha256": original.sha256_text(), "generatedArtifacts": generated, "dependencyControl": {"original": dependency, "replacement": replacement}, "counterfactualChange": {"original": guard, "replacement": weakened_guard}, "selection": selection, "liveWorldUnchanged": data.turn.snapshot() == before, "scope": "In-memory predicate microprobe only. The controlled known() return is not a source-backed identity grant, a legal World, a managed notice or a phase-four relation producer."}
	_check("PPR-K-RELATION-CUTOFF-SENSITIVITY", "The actual relation cutoff guard rejects a later source independently of identity eligibility and is sensitive to removing only that guard", isolated, evidence)
	_check("PK-NOTICE/same_batch_relation", "Managed actual Events selection transfers only sourced identity with valid frozen relationship and route", rejected and isolated, {"evolved": evolved, "originalFixtureInapplicable": true, "legacyAssemblyAtomicallyRejected": rejected, "equivalentRequirementEvidence": evidence, "scope": "Mixed current-runtime rejection and controlled predicate sensitivity; not the old legal managed fixture executed unchanged."})
