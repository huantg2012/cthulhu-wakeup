extends RefCounted
## Typed power declarations and authored effects, committed in Turn transactions.
const PlayerSources = preload("res://src/game/player_sources.gd")
const PrayerRules = preload("res://src/game/prayer_rules.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const History = preload("res://src/simulation/history_index.gd")
const Knowledge = preload("res://src/game/prayer_knowledge.gd")
const Anchors = preload("res://src/game/anchors.gd")
const Cults = preload("res://src/game/cults.gd")
const Relics = preload("res://src/game/relics.gd")
const Economy = preload("res://src/game/economy.gd")
const ID: String = "powers"
const SCHEMA: int = 1
const EXECUTORS: Array[String] = ["POWER_BREACH", "POWER_SEED", "POWER_ANCHOR", "POWER_VEIL", "POWER_TRANSFER", "POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]
const ATTRIBUTES: Array[String] = ["will", "insight", "influence", "adaptation"]
var catalog: RefCounted
var issuers: Dictionary
var version: String
var relics: RefCounted

func _init(content: RefCounted, accepted_issuers: Dictionary = {}) -> void:
	catalog = content; issuers = accepted_issuers.duplicate(true)
	version = rule_version(content); relics = Relics.new(content, accepted_issuers)

static func rule_version(content: RefCounted) -> String:
	return "2/" + content.version + "/" + str(content.extension_versions.get("powers", "missing")) + "/" + str(content.extension_versions.get("power_effects", "missing")) + "/" + str(content.extension_versions.get("relic_effects", "missing")) + "/" + Knowledge.version(content)

func install(turn: RefCounted) -> bool:
	if not turn._attached or turn.context.turn != 0 or Store.size(turn.context.receipts) != 0 or turn.world.state.has("power_system") or not turn.world.state.has("cult_system"): return false
	if not Knowledge.install(turn.world): return false
	for key: Variant in issuers:
		if not key is String or key.is_empty() or not issuers[key] is String or str(issuers[key]).is_empty(): return false
	turn.world.state["power_system"] = {"schema": SCHEMA, "version": version, "issuers": issuers.duplicate(true), "cooldowns": {}, "preparations": {}, "detentions": {}, "manifest": {}, "completion": ""}
	if not turn.register_participant(ID, version + "/" + JSON.stringify(issuers, "", true, true).sha256_text(), ["actions", "powers_start", "powers_end"], ["powers"], handle):
		turn.world.state.erase("power_system"); return false
	return true

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _entity(view: Dictionary, collection: String, id: String) -> Dictionary:
	var result: Dictionary = view.reader.entity(collection, id)
	if result.ok: view.world[collection][id] = result.item; return result.item
	return {}

func _fact(view: Dictionary, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var result: Dictionary = view.reader.fact(id)
	if result.ok: view.world.facts[id] = result.item; return result.item
	return {}

func _used(view: Dictionary, key: String) -> bool:
	var result: Dictionary = view.reader.authorization(key)
	return not result.ok or result.used

func _valid_source(view: Dictionary, id: String, domain: String = "") -> bool:
	var fact: Dictionary = _fact(view, id)
	return not fact.is_empty() and not view.reader.invalidated(id) and (domain.is_empty() or fact.domain == domain)

func _proof(view: Dictionary, payload: Dictionary, rule: String, target: String, actor: String, domain: String) -> Dictionary:
	var source: String = str(payload.get("proofs", {}).get(rule, payload.get("qualification", payload.get("source", ""))))
	var fact: Dictionary = _fact(view, source)
	if fact.is_empty() or fact.kind != "power_qualification" or fact.domain != domain or view.reader.invalidated(source): return _error("Missing current " + rule + " qualification")
	var data: Dictionary = fact.changes
	if not issuers.has(data.get("issuer", "")) or issuers[data.issuer] != data.get("version") or data.get("rule") != rule or data.get("target") != target or data.get("actor") != actor or not data.get("institution") is String or not data.get("basis") is Dictionary: return _error("Incompatible qualification issuer, object or schema")
	if not actor.is_empty() and not actor in fact.targets: return _error("Qualification does not name its actor")
	if data.issuer == PlayerSources.ID and not PlayerSources.new(catalog).valid_proof(view.world, fact, view.reader): return _error("Player qualification source is no longer current")
	var basis: Dictionary = data.basis
	var sources: Array = []
	match rule:
		"listen":
			if not basis.get("clue") is String or not basis.get("fact") is String or basis.fact != target: return _error("Listen needs its exact clue and fact")
			sources = [basis.clue, basis.fact]
			if _used(view, "power/revealed/" + basis.fact): return _error("Fact already revealed")
			var clue: Dictionary = _fact(view, basis.clue)
			if clue.is_empty() or (not basis.fact in clue.targets and clue.changes.get("fact") != basis.fact and clue.changes.get("target_fact") != basis.fact): return _error("Clue does not point to the requested fact")
		"dream":
			if not basis.get("contact") is String: return _error("Dream needs its current contact")
			sources = [basis.contact]
			var contact: Dictionary = _fact(view, basis.contact)
			if contact.is_empty() or not actor in contact.targets: return _error("Contact does not name the dreamer")
		"weakness", "milestone", "witness":
			if not basis.get("source") is String: return _error("Qualification needs a durable source")
			sources = [basis.source]
			if rule in ["weakness", "witness"] and _used(view, "power/" + rule + "/" + basis.source): return _error("One-use source already consumed")
			var root: Dictionary = _fact(view, basis.source)
			if root.is_empty() or (rule != "weakness" and not actor in root.targets and root.actor != actor and not actor in root.changes.get("witnesses", [])): return _error("Experience has no actual participant or witness")
		"spread", "anchor":
			if not basis.get("institution") is String or basis.institution != data.institution or not basis.get("sources") is Array or basis.sources.is_empty(): return _error("Institution qualification lacks concrete sources")
			if not view.world.institutions.has(data.institution): return _error("Unknown institution")
			var institution: Dictionary = view.world.institutions[data.institution]
			if institution.domain != domain or not institution.active or (rule == "spread" and institution.role != "propagation"): return _error("Institution no longer supports this action")
			var representative: Dictionary = _entity(view, "npcs", str(institution.representative))
			if representative.is_empty() or representative.status != "active" or representative.domain != domain: return _error("Institution representative unavailable")
			sources = basis.sources
		"evidence":
			if not basis.get("source") is String or not basis.get("benefits") is Array: return _error("Evidence needs its real propagation derivatives")
			sources = [basis.source] + basis.benefits
			if _used(view, "power/evidence/" + basis.source): return _error("Evidence already destroyed")
			for benefit: Variant in basis.benefits:
				if not benefit is String: return _error("Invalid propagation benefit")
				var derived: Dictionary = _fact(view, benefit)
				if derived.is_empty() or not basis.source in derived.causal_parents: return _error("Propagation benefit is unrelated to evidence")
		"tenure":
			if not basis.get("joined") is String: return _error("Tenure needs a joined source")
			sources = [basis.joined]
			var person: Dictionary = view.world.npcs[actor]
			var joined: Dictionary = _fact(view, basis.joined)
			if joined.is_empty() or joined.kind != "cult_member_joined" or joined.changes.get("cult") != target or not actor in joined.targets or person.get("joined_source") != basis.joined or person.get("cult_id") != target or joined.turn < view.world.cults[target].established_turn or view.world.turn - joined.turn < catalog.integer("sacrifice_min_tenure"): return _error("Current cult tenure is too short or invalid")
		_: return _error("Unsupported qualification")
	for source_id: Variant in sources:
		if not source_id is String or not source_id in fact.causal_parents or not _valid_source(view, source_id, domain): return _error("Qualification has missing, invalid or wrong-domain causes")
	return {"ok": true, "source": source, "basis": basis, "institution": data.institution, "issuer": data.issuer, "version": data.version}

func _cult(state: Dictionary, domain: String) -> String:
	var keys: Array = state.cults.keys(); keys.sort()
	for id: String in keys:
		if state.cults[id].domain == domain and state.cults[id].status == "active": return id
	return ""

func probability(person: Dictionary, domain: Dictionary, power: Dictionary, preparation: int) -> int:
	var modifier: int = 0
	if person.sanity >= catalog.integer("sanity_stable_threshold"): modifier = catalog.integer("sanity_stable_" + power.check_kind + "_modifier")
	elif person.sanity < catalog.integer("sanity_fractured_threshold"): modifier = catalog.integer("sanity_disordered_" + power.check_kind + "_modifier")
	var p: int = catalog.integer("check_base") + catalog.integer("check_attribute_step") * (int(person[power.attribute]) - catalog.integer("check_" + domain.tier + "_difficulty"))
	p += clampi(preparation, -catalog.integer("check_preparation_limit"), catalog.integer("check_preparation_limit")) + modifier
	p -= int(floor(float(domain.barrier) / catalog.number("check_barrier_divisor"))) + int(floor(float(domain.alert) / catalog.number("check_alert_divisor")))
	return clampi(p, catalog.integer("check_probability_min"), catalog.integer("check_probability_max"))

func _manifest_valid(state: Dictionary, data: Dictionary) -> bool:
	if state.awakening < catalog.integer("manifest_requirement") or not state.anchors.has(data.get("cosmic_anchor", "")) or not state.anchors.has(data.get("system_anchor", "")): return false
	var cosmic: Dictionary = state.anchors[data.cosmic_anchor]; var system: Dictionary = state.anchors[data.system_anchor]
	if cosmic.state != "active" or system.state != "active" or state.domains[cosmic.domain].tier != "cosmic" or state.domains[system.domain].tier != "system" or cosmic.guardian != data.get("npc"): return false
	if not Store.has(state.npcs, cosmic.guardian): return false
	var actor: Dictionary = Store.entry(state.npcs, cosmic.guardian)
	return actor.status == "active" and actor.domain == cosmic.domain and actor.get("bound_member", false) and actor.loyalty >= catalog.integer("loyalty_follower_threshold")

static func primary_key(power: String, payload: Dictionary, npc: String, domain: String, cult: String, proofs: Dictionary) -> String:
	match power:
		"POWER_ANCHOR": return str(payload.get("institution", ""))
		"POWER_BREACH": return domain
		"POWER_SEED": return cult
		"POWER_VEIL": return str(proofs.get("evidence", {}).get("basis", {}).get("source", ""))
	return npc if not npc.is_empty() else domain

func prepare(view: Dictionary, power_id: String, payload: Dictionary) -> Dictionary:
	for key: Variant in payload:
		if not key in ["npc", "domain", "source", "qualification", "proofs", "cult", "attribute", "mode", "target_domain", "escort", "institution", "relic", "preparations", "declared_action", "cosmic_anchor", "system_anchor", "milestones", "witness", "role", "anchor", "preparation_relic"]: return _error("Unknown power input field")
	if not payload.get("source") is String or not _valid_source(view, payload.source): return _error("Power needs an actual current source")
	if not payload.get("proofs", {}) is Dictionary: return _error("Invalid qualification map")
	if not view.world.has("power_system") or view.world.power_system.version != version: return _error("Power policy unavailable")
	var state: Dictionary = view.world
	if not state.power_system.completion.is_empty(): return _error("Ritual completion awaits ending consumption")
	if power_id == "POWER_MANIFEST_CANCEL":
		if state.power_system.manifest.is_empty(): return _error("No ongoing ritual")
		return {"ok": true, "power": power_id, "payload": payload, "npc": "", "domain": "", "faith": 0, "whispers": 0, "probability": -1, "attention": {"family": "system", "content_id": "REST", "variant": "use"}, "preparations": [], "relic_effects": [], "proofs": {}}
	var continuation: bool = power_id == "POWER_MANIFEST_CONTINUE"
	if not catalog.tables.powers.has("POWER_MANIFEST" if continuation else power_id): return _error("Unknown power")
	var row: Dictionary = catalog.tables.powers["POWER_MANIFEST" if continuation else power_id]
	var npc: String = str(payload.get("npc", ""))
	var manifest: Dictionary = state.power_system.manifest
	if continuation:
		if manifest.is_empty() or manifest.paid_turn >= state.turn or manifest.progress >= catalog.integer("manifest_duration"): return _error("Ritual is not awaiting continuation")
		npc = manifest.npc
	var person: Dictionary = {} if npc.is_empty() else _entity(view, "npcs", npc)
	var domain: String = str(payload.get("domain", person.get("domain", "")))
	if continuation: domain = state.anchors[manifest.cosmic_anchor].domain
	if not state.domains.has(domain): return _error("Power needs its actual target domain")
	if power_id != "POWER_LISTEN" and (person.is_empty() or person.status != "active" or person.domain != domain): return _error("Power subject unavailable or in another domain")
	if not power_id in ["POWER_LISTEN", "POWER_DREAM", "POWER_ANCHOR"] and (not person.get("bound_member", false) or person.loyalty < catalog.integer("loyalty_follower_threshold")): return _error("Power needs a loyal bound member")
	if power_id == "POWER_ANCHOR":
		_fact(view, str(person.get("dedication_source", ""))); _fact(view, str(person.get("binding_source", "")))
		if not Cults.eligible(state, person, catalog): return _error("Anchor guardian cannot join")
	var cult: String = _cult(state, domain)
	if payload.has("cult") and payload.cult != cult: return _error("Wrong or inactive cult")
	if power_id in ["POWER_SEED", "POWER_ANCHOR", "POWER_VEIL", "POWER_SACRIFICE"] and cult.is_empty(): return _error("Power needs its local active cult")
	if not person.is_empty() and not person.get("cult_id", "").is_empty() and person.cult_id != cult and power_id != "POWER_TRANSFER": return _error("Member belongs to another cult")
	if power_id == "POWER_SEED" and PrayerRules.blocked(state, npc, "propagation"): return _error("Prayer consequence prevents this person from propagating this turn")
	if power_id in EXECUTORS and person.acted_turn == state.turn: return _error("Person already executed this turn")
	if state.awakening < int(row.unlock_awakening): return _error("Current awakening is below the power threshold")
	var faith: int = catalog.integer("manifest_continue_faith") if continuation else int(row.faith)
	var whispers: int = catalog.integer("manifest_continue_whispers") if continuation else int(row.whispers)
	if state.faith < faith or state.whispers < whispers: return _error("Power is not affordable")
	var proofs: Dictionary = {}
	var target_domain: String = str(payload.get("target_domain", domain))
	if power_id != "POWER_TRANSFER" and target_domain != domain: return _error("Power cannot substitute another check domain")
	match power_id:
		"POWER_LISTEN":
			var qualification: Dictionary = _fact(view, str(payload.get("qualification", payload.source)))
			var target: String = str(qualification.get("changes", {}).get("basis", {}).get("fact", ""))
			proofs.listen = _proof(view, payload, "listen", target, "", domain)
		"POWER_DREAM": proofs.dream = _proof(view, payload, "dream", npc, npc, domain)
		"POWER_ORACLE":
			if not payload.get("declared_action") is String: return _error("Oracle needs an explicitly declared future check")
			var action: String = payload.declared_action
			if catalog.tables.powers.has(action):
				if catalog.tables.powers[action].check_kind == "deterministic": return _error("Oracle cannot prepare a deterministic operation")
			else:
				if not PrayerRules.prayer_target(state, action, npc): return _error("Oracle needs the same petitioner and a current fixed prayer check")
				var target_request: Dictionary = state.prayer_system.requests[PrayerRules.prayer_action(action).request]
				if not _valid_source(view, str(target_request.descriptor.source), domain): return _error("Prayer situation source is no longer current")
		"POWER_BESTOW":
			if not payload.get("attribute", "") in ATTRIBUTES or int(person[payload.attribute]) >= catalog.integer("npc_attribute_max") or _used(view, "power/bestow/" + npc): return _error("Lifetime bestowal or attribute unavailable")
		"POWER_BREACH": proofs.weakness = _proof(view, payload, "weakness", npc, npc, domain)
		"POWER_SEED": proofs.spread = _proof(view, payload, "spread", cult, npc, domain)
		"POWER_VEIL": proofs.evidence = _proof(view, payload, "evidence", cult, npc, domain)
		"POWER_SACRIFICE":
			if not payload.get("mode", "") in ["faith", "insight", "heal"]: return _error("Sacrifice needs exactly one mode")
			proofs.tenure = _proof(view, payload, "tenure", cult, npc, domain)
			if payload.mode == "insight":
				var witness_payload: Dictionary = payload.duplicate(true); witness_payload["qualification"] = payload.get("witness", ""); witness_payload["proofs"] = {}
				proofs.witness = _proof(view, witness_payload, "witness", npc, npc, domain)
			var roots: Array = []
			if not payload.get("milestones", []) is Array: return _error("Invalid milestone list")
			for source: Variant in payload.get("milestones", []):
				if not source is String: return _error("Milestone must be a qualified source")
				var milestone_payload: Dictionary = payload.duplicate(true); milestone_payload["qualification"] = source; milestone_payload["proofs"] = {}
				var proof: Dictionary = _proof(view, milestone_payload, "milestone", npc, npc, domain)
				if not proof.ok: return proof
				if not proof.basis.source in roots: roots.append(proof.basis.source)
			payload = payload.duplicate(true); payload["_rank"] = mini(catalog.integer("sacrifice_rank_cap"), 1 + roots.size() / catalog.integer("sacrifice_rank_milestones"))
		"POWER_TRANSFER":
			if not state.domains.has(target_domain) or not target_domain in state.domains[domain].neighbors or _cult(state, target_domain).is_empty() or not payload.get("escort", 0) is int or int(payload.get("escort", 0)) < 0: return _error("Transfer needs a reachable receiving cult and existing escort")
			if int(state.domains[target_domain].population) >= catalog.integer("domain_population_capacity"): return _error("Transfer destination has no space for its person")
			for held: Dictionary in state.relics.values():
				if held.get("holder", "") == npc and held.placement == "bound": return _error("Bound media cannot migrate as baggage")
		"POWER_ANCHOR":
			if not payload.get("institution") is String or not state.institutions.has(payload.institution) or state.institutions[payload.institution].domain != domain or not payload.get("relic") is String: return _error("Anchor needs a fixed institution and medium")
			if state.has("anchor_system"):
				var institution_source: String = str(payload.get("proofs", {}).get("anchor", payload.get("qualification", payload.get("source", ""))))
				proofs.anchor = Anchors.qualify(state, payload.institution, institution_source, catalog, view.reader)
				if not proofs.anchor.get("allowed", false): return _error(str(proofs.anchor.get("reason", proofs.anchor.get("error", "Institution recognition unavailable"))))
			else:
				proofs.anchor = _proof(view, payload, "anchor", payload.institution, npc, domain)
				if proofs.anchor.ok and (not state.has("economy") or state.economy.issuers.get(proofs.anchor.issuer) != proofs.anchor.version): return _error("Anchor maintenance capability issuer unavailable")
			if not state.has("relic_system"): return _error("Formal medium lifecycle unavailable")
			var medium: Dictionary = _entity(view, "relics", payload.relic)
			if medium.is_empty() or medium.domain != domain or not medium.placement in ["controlled", "carried", "bound"] or (medium.placement == "carried" and medium.holder != npc): return _error("Anchor medium is not controllable locally")
			var anchor_id: String = "ANCHOR/" + payload.institution
			var ordinal: int = 1
			var occupied: Array = []
			for anchor: Dictionary in state.anchors.values():
				if anchor.institution == payload.institution: anchor_id = anchor.id; ordinal = anchor.ordinal
				if anchor.domain == domain: occupied.append(anchor.ordinal)
			if not state.anchors.has(anchor_id):
				while ordinal in occupied: ordinal += 1
			if ordinal > state.domains[domain].institutions.size() or state.domains[domain].pollution < catalog.integer("anchor_create_pollution_" + str(ordinal)) or state.domains[domain].unnamed_followers < catalog.integer("anchor_followers_min") or state.cults[cult].cohesion < catalog.integer("anchor_cohesion_min"): return _error("Anchor organization, slot or pollution threshold unmet")
			for anchor: Dictionary in state.anchors.values():
				if anchor.id != anchor_id and (anchor.guardian == npc or anchor.relic == payload.relic) and anchor.state != "absent": return _error("Person or medium already supports another anchor")
			if state.anchors.has(anchor_id) and state.anchors[anchor_id].guardian != npc: return _error("Existing anchor needs prior effective guardian appointment")
			if medium.placement == "bound" and medium.get("anchor", "") != anchor_id: return _error("Medium belongs to another anchor")
			payload = payload.duplicate(true); payload["_anchor"] = anchor_id; payload["_ordinal"] = ordinal
		"POWER_MANIFEST", "POWER_MANIFEST_CONTINUE":
			var fixed: Dictionary = manifest if continuation else payload
			_entity(view, "npcs", str(fixed.get("npc", "")))
			if not _manifest_valid(state, fixed) or (not continuation and not manifest.is_empty()): return _error("Fixed ritual anchors, subject or awakening unavailable")
			if continuation:
				payload = payload.duplicate(true); payload["cosmic_anchor"] = fixed.cosmic_anchor; payload["system_anchor"] = fixed.system_anchor
	for proof: Dictionary in proofs.values():
		if not proof.ok: return proof
	var primary: String = primary_key(power_id, payload, npc, domain, cult, proofs)
	var cooldown: Dictionary = state.power_system.cooldowns.get(power_id + "/" + primary, {})
	if int(cooldown.get("until", -1)) >= int(state.turn): return _error("Power target is still cooling down")
	var preparation: int = 0; var preparations: Array = []
	if not payload.get("preparations", []) is Array: return _error("Invalid preparation sources")
	for source: Variant in payload.get("preparations", []):
		if not source is String or not state.power_system.preparations.has(source) or source in preparations: return _error("Unknown or duplicate preparation")
		var entry: Dictionary = state.power_system.preparations[source]
		if entry.npc != npc or entry.action != ("POWER_MANIFEST" if continuation else power_id) or entry.expires < state.turn: return _error("Preparation belongs to another action or expired")
		preparation += int(entry.amount); preparations.append(source)
	var relic_effects: Array = []
	var preparation_relic: String = str(payload.get("preparation_relic", payload.get("relic", "") if power_id != "POWER_ANCHOR" else ""))
	if not preparation_relic.is_empty():
		_entity(view, "relics", preparation_relic)
		var bonus: Dictionary = relics.preparation(state, preparation_relic, "POWER_MANIFEST" if continuation else power_id, npc)
		if not bonus.ok: return _error("Selected relic cannot prepare this check")
		preparation += int(bonus.bonus); relic_effects = bonus.effects
	var p: int = probability(person, state.domains[target_domain], row, preparation) if row.check_kind != "deterministic" else -1
	var attention: Dictionary = {"family": "power", "content_id": "POWER_MANIFEST" if continuation else power_id, "variant": "use", "participants": [] if npc.is_empty() else [npc], "target": domain, "source_domain": domain, "nominees": [npc] if power_id == "POWER_ANCHOR" else []}
	if power_id == "POWER_TRANSFER": attention.target = target_domain
	if power_id in ["POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]:
		attention["ritual_domains"] = [state.anchors[payload.cosmic_anchor].domain, state.anchors[payload.system_anchor].domain]
		attention["persistent"] = not continuation
	return {"ok": true, "power": power_id, "payload": payload, "npc": npc, "domain": domain, "target_domain": target_domain, "cult": cult, "primary": primary, "faith": faith, "whispers": whispers, "probability": p, "attention": attention, "preparations": preparations, "relic_effects": relic_effects, "proofs": proofs}

func handle(view: Dictionary, input: Dictionary) -> Dictionary:
	if input.slot in ["powers_start", "powers_end"]: return {"ok": true, "empty": false, "effects": [{"type": "powers", "operation": input.slot}], "state": {}}
	var plan: Dictionary = prepare(view, str(input.get("action", "")), input.get("payload", {}))
	if not plan.ok: return {"ok": false, "empty": true, "effects": [], "state": {}, "error": plan.error}
	return {"ok": true, "empty": false, "effects": [{"type": "powers", "operation": "attempt", "plan": plan}], "state": {}, "meta": {"faith_cost": plan.faith, "whispers_cost": plan.whispers, "min_awakening": 0, "actor": plan.npc if plan.power in EXECUTORS else "", "source": input.payload.source, "outcome": "power_attempt", "responds": false, "used_power": true, "used_relic": not plan.relic_effects.is_empty(), "target": plan.target_domain if plan.power == "POWER_TRANSFER" else plan.domain, "attention": plan.attention}}

func preview(turn: RefCounted, power_id: String, payload: Dictionary) -> Dictionary:
	if not turn._attached or turn._in_transaction or turn._in_participant or turn.context.phase != "actions": return _error("Power preview requires the action phase")
	if power_id == "POWER_APPOINT":
		if not turn._participants.has("cults"): return _error("Cult appointment capability unavailable")
		var cult_view: Dictionary = turn._read_view("cults", "actions")
		var result: Dictionary = turn._participants.cults.instance.handle(cult_view, {"operation": "act", "slot": "actions", "action": "appoint", "payload": payload})
		cult_view.reader.close()
		if not result.ok: return _error("Appointment does not satisfy current cult eligibility")
		if turn.world.state.faith < result.meta.faith_cost or turn.world.state.whispers < result.meta.whispers_cost or turn.world.state.awakening < result.meta.min_awakening: return _error("Appointment is not affordable or unlocked")
		var output: Dictionary = {"ok": true, "power": power_id, "faith": result.meta.faith_cost, "whispers": result.meta.whispers_cost, "probability": -1, "attention": result.meta.attention, "declaration": result}
		if turn.world.state.has("attention"):
			var needs: Dictionary = turn.world.attention.preview_needs(turn.world.state, result.meta.attention, result.effects)
			if not needs.ok: return needs
			output["needs"] = needs
		return output
	var view: Dictionary = turn._read_view(ID, "actions")
	var plan: Dictionary = prepare(view, power_id, payload)
	if plan.ok and turn.world.state.has("attention"):
		var needs: Dictionary = turn.world.attention.preview_needs(turn.world.state, plan.attention, [], plan.npc if plan.power in EXECUTORS else "")
		if not needs.ok: view.reader.close(); return needs
		plan["needs"] = needs
	view.reader.close()
	return plan

func validate_effect(state: Dictionary, slot: String, effect: Dictionary) -> bool:
	if not state.has("power_system") or state.power_system.version != version: return false
	if slot in ["powers_start", "powers_end"]: return effect.get("operation") == slot
	return slot == "actions" and effect.get("operation") == "attempt" and effect.get("plan") is Dictionary and effect.plan.get("ok") == true

func _consume(world: RefCounted, key: String, source: String) -> void:
	world.stage_collections(["applied_authorizations"]); Store.put(world.state.applied_authorizations, key, source)
	if key.begins_with("power/revealed/") and world.history != null: world.history.consume_listen(key.trim_prefix("power/revealed/"))

func _rows(power: String, outcome: String) -> Array:
	var rows: Array = []
	for id: String in catalog.tables.power_effects:
		var row: Dictionary = catalog.tables.power_effects[id]
		if row.power_id == power and row.outcome == outcome: rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return rows

func _amount(row: Dictionary) -> int:
	return catalog.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)

func _delta(world: RefCounted, plan: Dictionary, row: Dictionary, amount: int, source: String, owner: Object) -> bool:
	var state: Dictionary = world.state; var field: String = row.field
	if row.subject == "global":
		if field in ["faith_base", "faith_per_rank"]:
			if plan.payload.mode != "faith": return true
			if field == "faith_per_rank": amount *= int(plan.payload.get("_rank", 1))
			state.faith = mini(Economy.capacity(state, catalog), int(state.faith) + amount)
		elif field == "insight":
			if plan.power == "POWER_SACRIFICE" and plan.payload.mode != "insight": return true
			state.insight = mini(catalog.integer("insight_cap"), int(state.insight) + amount)
		elif field == "wound_recovery":
			if plan.payload.mode == "heal": state.wounds = maxi(0, int(state.wounds) - amount)
		elif field == "wounds": state.wounds = maxi(0, int(state.wounds) + amount)
		else: return false
		return true
	if row.subject == "actor":
		var person: Dictionary = world.mutable_npc(plan.npc)
		if field == "selected_attribute": field = plan.payload.attribute
		if not field in ATTRIBUTES + ["sanity", "loyalty"]: return false
		person[field] = clampi(int(person[field]) + amount, 0, catalog.integer("npc_attribute_max") if field in ATTRIBUTES else catalog.integer("attribute_max"))
		return true
	if row.subject == "cult":
		if not state.cults.has(plan.cult): return false
		if field == "cohesion_loss": field = "cohesion"; amount = -amount
		if field != "cohesion": return false
		state.cults[plan.cult].cohesion = clampi(int(state.cults[plan.cult].cohesion) + amount, 0, catalog.integer("attribute_max")); return true
	var domain_id: String = plan.target_domain if row.subject == "target_domain" else plan.domain
	if not row.subject in ["domain", "source_domain", "target_domain"] or not state.domains.has(domain_id): return false
	if field == "followers":
		var available: int = state.domains[domain_id].unnamed_nonfollowers if amount > 0 else state.domains[domain_id].unnamed_followers
		var actual: int = mini(absi(amount), available)
		return actual == 0 or world.submit({"kind": "population", "domain": domain_id, "mode": "convert" if amount > 0 else "leave", "amount": actual, "parents": [source]}, owner, true)
	if not field in ["alert", "pollution", "barrier"]: return false
	var before: int = int(state.domains[domain_id][field])
	state.domains[domain_id][field] = clampi(before + amount, 0, catalog.integer("attribute_max"))
	var actual: int = int(state.domains[domain_id][field]) - before
	var result_source: String = world._record("power_effect", domain_id, plan.npc, [] if plan.npc.is_empty() else [plan.npc], [source], {"power": plan.power, "field": field, "requested": amount, "actual": actual})
	if field == "pollution" and actual > 0: state.domains[domain_id].pollution_changed_turn = state.turn
	if field == "alert" and actual > 0: state.domains[domain_id].exposure_turn = state.turn
	if field == "barrier": state.domains[domain_id].barrier_source = result_source
	return true

func _apply_rows(world: RefCounted, plan: Dictionary, outcome: String, source: String, owner: Object, token: String) -> bool:
	for row: Dictionary in _rows("POWER_MANIFEST" if plan.power == "POWER_MANIFEST_CONTINUE" else plan.power, outcome):
		match str(row.operation):
			"delta":
				if not _delta(world, plan, row, _amount(row), source, owner): return false
			"sacrifice":
				if not world.submit({"kind": "status", "npc": plan.npc, "status": "dead", "parents": [source]}, owner): return false
			"reveal": _consume(world, "power/revealed/" + plan.proofs.listen.basis.fact, source)
			"grant_preparation": world.state.power_system.preparations[source] = {"npc": plan.npc, "action": plan.payload.declared_action, "expires": world.state.turn + 1, "amount": _amount(row), "source": source}
			"invalidate_evidence":
				var basis: Dictionary = plan.proofs.evidence.basis
				world.stage_collections(["invalid_records"])
				for invalid: String in [basis.source] + basis.benefits: Store.put(world.state.invalid_records, invalid, source)
				_consume(world, "power/evidence/" + basis.source, source)
			"migrate":
				var escort: int = mini(int(plan.payload.get("escort", 0)), mini(_amount(row), int(world.state.domains[plan.domain].unnamed_followers)))
				escort = mini(escort, maxi(0, catalog.integer("domain_population_capacity") - int(world.state.domains[plan.target_domain].population) - 1))
				if escort > 0 and not world.submit({"kind": "population", "domain": plan.domain, "mode": "migrate", "target": plan.target_domain, "amount": escort, "parents": [source]}, owner, true): return false
				if not world.submit({"kind": "migrate", "npc": plan.npc, "domain": plan.target_domain, "parents": [source]}, owner): return false
				if not Cults.membership(world, "enroll", plan.npc, source, token, _cult(world.state, plan.target_domain)): return false
			"detain":
				if not world.submit({"kind": "status", "npc": plan.npc, "status": "detained", "parents": [source]}, owner): return false
				world.state.power_system.detentions[plan.npc] = {"due": world.state.turn + _amount(row) + 1, "source": Store.entry(world.state.npcs, plan.npc).status_source}
			"seal":
				if not relics.seal(world, plan.payload.relic, _amount(row), source, owner): return false
			"anchor":
				if not _anchor(world, plan, source, owner, token): return false
			"set":
				if row.subject != "anchor" or row.field != "state" or not world.state.anchors.has(plan.payload.cosmic_anchor): return false
				world.state.anchors[plan.payload.cosmic_anchor].state = row.value
			"manifest_complete":
				world.state.power_system.completion = world._record("manifest_completed", plan.domain, plan.npc, [plan.npc], [source], {"awakening": _amount(row), "ritual": plan.payload})
			_: return false
	return true

func _anchor(world: RefCounted, plan: Dictionary, source: String, owner: Object, token: String) -> bool:
	var id: String = plan.payload._anchor
	var origin: String = world.state.anchors[id].origin if world.state.anchors.has(id) else source
	if world.state.anchors.has(id):
		var old_medium: String = world.state.anchors[id].relic
		if old_medium != plan.payload.relic and Store.has(world.state.relics, old_medium) and Store.entry(world.state.relics, old_medium).placement == "bound":
			if not relics.commit(world, {"type": "relics", "operation": "unbind", "payload": {"relic": old_medium, "source": source}}, owner): return false
	if not Cults.membership(world, "enroll", plan.npc, source, token, plan.cult): return false
	world.state.anchors[id] = {"id": id, "domain": plan.domain, "institution": plan.payload.institution, "cult": plan.cult, "guardian": plan.npc, "relic": plan.payload.relic, "state": "dormant", "ordinal": plan.payload._ordinal, "origin": origin, "needs_rebind": false, "established_source": source}
	if Store.entry(world.state.relics, plan.payload.relic).placement != "bound" and not relics.bind(world, plan.payload.relic, id, source, owner): return false
	var proof: Dictionary = plan.proofs.anchor
	if world.state.has("anchor_system"): return Anchors.bind(world, id, proof, source, owner)
	var parents: Array = [source, proof.source]
	var prior: String = world.state.economy_qualifications.get("anchor|" + id, "")
	if not prior.is_empty(): parents.append(prior)
	return world.submit({"kind": "economy_qualification", "rule": "anchor", "subject": id, "allowed": true, "institution": plan.payload.institution, "issuer": proof.issuer, "version": proof.version, "power_qualification": proof.source, "parents": parents}, owner)

func _interrupt(world: RefCounted, reason: String) -> void:
	var ritual: Dictionary = world.state.power_system.manifest
	if ritual.is_empty(): return
	var stopped: String = world._record("manifest_interrupted", world.state.anchors[ritual.cosmic_anchor].domain, ritual.npc, [ritual.npc], [ritual.source], {"reason": reason, "progress": ritual.progress})
	for anomaly: String in ritual.get("anomalies", []):
		var fact: Dictionary = Store.entry(world.state.facts, anomaly)
		if History.has(world.state.domains[fact.domain].public_anomalies, anomaly):
			world.introduce_fact("anomaly_resolved", fact.domain, "", fact.targets, [stopped, anomaly], {"source": anomaly, "power": "POWER_MANIFEST"}, [], [], world._turn_owner.get_ref())
	if world.state.has("attention") and world.state.attention.reservations.has(ritual.token): world.attention.release_reservation(world, ritual.token)
	world.state.power_system.manifest = {}

func finish_manifest(world: RefCounted, owner: Object) -> bool:
	if not world._driver_allowed(owner): return false
	world.stage_current()
	var ritual: Dictionary = world.state.power_system.manifest
	if ritual.is_empty(): return true
	if ritual.paid_turn != world.state.turn or not _manifest_valid(world.state, ritual): _interrupt(world, "unpaid_or_end_conditions_invalid"); return true
	if ritual.progress < catalog.integer("manifest_duration"): return true
	var roll: int = world.randoms.checks.randi_range(1, 100)
	var outcome: String = world.check_result(ritual.probability, roll)
	owner._checks.append({"probability": ritual.probability, "roll": roll, "outcome": outcome})
	var check: String = world._record("turn_check", world.state.anchors[ritual.cosmic_anchor].domain, ritual.npc, [ritual.npc], [ritual.source], {"probability": ritual.probability, "roll": roll, "outcome": outcome, "locked": true})
	var plan: Dictionary = {"power": "POWER_MANIFEST", "npc": ritual.npc, "domain": world.state.anchors[ritual.cosmic_anchor].domain, "payload": ritual}
	if not _apply_rows(world, plan, "deep_success" if outcome == "deep" else outcome, check, owner, ritual.token): return false
	_interrupt(world, "completed" if outcome in ["deep", "success"] else "final_check_" + outcome)
	return true

func commit(world: RefCounted, effect: Dictionary, owner: Object, token: String = "") -> bool:
	if not world._driver_allowed(owner): return false
	world.stage_current()
	if effect.operation == "powers_start":
		for id: String in world.state.power_system.detentions.keys():
			var entry: Dictionary = world.state.power_system.detentions[id]
			if entry.due > world.state.turn: continue
			var person: Dictionary = Store.entry(world.state.npcs, id)
			if person.status == "detained" and person.status_source == entry.source and not world.submit({"kind": "status", "npc": id, "status": "active", "parents": [entry.source]}, owner): return false
			world.state.power_system.detentions.erase(id)
		for key: String in world.state.power_system.cooldowns.keys():
			if world.state.power_system.cooldowns[key].until < world.state.turn: world.state.power_system.cooldowns.erase(key)
		for key: String in world.state.power_system.preparations.keys():
			if world.state.power_system.preparations[key].expires < world.state.turn: world.state.power_system.preparations.erase(key)
		if not world.state.power_system.manifest.is_empty() and not _manifest_valid(world.state, world.state.power_system.manifest): _interrupt(world, "start_conditions_invalid")
		return true
	if effect.operation == "powers_end":
		return true if world.state.has("ending_system") else finish_manifest(world, owner)
	var plan: Dictionary = effect.plan
	if plan.power == "POWER_MANIFEST_CANCEL": _interrupt(world, "player_cancelled"); return true
	var paid_id: String = "FACT-%08d" % (int(world.state.next_fact) - 1)
	var paid: Dictionary = Store.entry(world.state.facts, paid_id)
	if paid.kind == "cult_local_payment": paid_id = paid.changes.payment
	var source: String = world._record("power_attempt", plan.domain, plan.npc, [] if plan.npc.is_empty() else [plan.npc], [plan.payload.source, paid_id], {"power": plan.power, "payload": plan.payload, "probability": plan.probability, "preparations": plan.preparations, "faith_cost": plan.faith, "whispers_cost": plan.whispers, "payment": paid_id, "proofs": plan.proofs, "primary": plan.primary, "cult": plan.cult})
	for selected: String in plan.preparations:
		_consume(world, "power/preparation/" + selected, source); world.state.power_system.preparations.erase(selected)
	for relic_effect: Dictionary in plan.relic_effects:
		relic_effect = relic_effect.duplicate(true); relic_effect.payload["source"] = source
		if not relics.commit(world, relic_effect, owner, token): return false
	if plan.proofs.has("weakness"): _consume(world, "power/weakness/" + plan.proofs.weakness.basis.source, source)
	if plan.proofs.has("witness"): _consume(world, "power/witness/" + plan.proofs.witness.basis.source, source)
	if plan.power in ["POWER_MANIFEST", "POWER_MANIFEST_CONTINUE"]:
		var ritual: Dictionary
		if plan.power == "POWER_MANIFEST":
			ritual = {"npc": plan.npc, "cosmic_anchor": plan.payload.cosmic_anchor, "system_anchor": plan.payload.system_anchor, "progress": 1, "paid_turn": world.state.turn, "source": source, "token": token, "probability": -1, "steps": [source], "anomalies": []}
		else:
			ritual = world.state.power_system.manifest
			ritual.progress += 1; ritual.paid_turn = world.state.turn; ritual.source = source; ritual.steps.append(source)
			if ritual.progress == catalog.integer("manifest_duration"): ritual.probability = plan.probability
		world.state.power_system.manifest = ritual
		for anchor_id: String in [ritual.cosmic_anchor, ritual.system_anchor]:
			var domain: String = world.state.anchors[anchor_id].domain
			var fact: String = world.introduce_fact("public_anomaly", domain, ritual.npc, [world.state.anchors[anchor_id].institution], [source], {"power": "POWER_MANIFEST", "anchor": anchor_id}, [], [], owner)
			if fact.is_empty(): return false
			ritual.anomalies.append(fact)
		return true
	if not _apply_rows(world, plan, "always", source, owner, token): return false
	var outcome: String = "success"
	var cause: String = source
	if plan.probability >= 0:
		var roll: int = world.randoms.checks.randi_range(1, 100)
		outcome = world.check_result(plan.probability, roll)
		owner._checks.append({"probability": plan.probability, "roll": roll, "outcome": outcome})
		cause = world._record("turn_check", plan.target_domain, plan.npc, [plan.npc], [source], {"probability": plan.probability, "roll": roll, "outcome": outcome, "snapshot_before_always": true})
	if not _apply_rows(world, plan, "deep_success" if outcome == "deep" else outcome, cause, owner, token): return false
	if plan.power == "POWER_BESTOW" and outcome in ["deep", "success"]: _consume(world, "power/bestow/" + plan.npc, cause)
	var row: Dictionary = catalog.tables.powers[plan.power]
	if int(row.cooldown_turns) > 0: world.state.power_system.cooldowns[plan.power + "/" + plan.primary] = {"until": world.state.turn + int(row.cooldown_turns), "source": cause}
	var result_data: Dictionary = {"power": plan.power, "outcome": outcome}
	var identity_rule: String = "KNOW_DREAM" if plan.power == "POWER_DREAM" else ("KNOW_ORACLE" if plan.power == "POWER_ORACLE" else "")
	if not identity_rule.is_empty() and outcome in ["deep", "success"]:
		result_data["recognition"] = Knowledge.recognition(world, plan.npc, identity_rule, owner)
	var result_source: String = world._record("power_result", plan.domain, plan.npc, [] if plan.npc.is_empty() else [plan.npc], [cause], result_data)
	if result_data.has("recognition") and not Knowledge.identify(world, plan.npc, result_source, identity_rule, owner).ok: return false
	if not plan.npc.is_empty() and Store.entry(world.state.npcs, plan.npc).status == "active":
		world._know(plan.npc, result_source)
		if outcome in ["deep", "success"] and plan.power in ["POWER_DREAM", "POWER_BESTOW", "POWER_BREACH", "POWER_SEED", "POWER_ANCHOR"]:
			var details: Dictionary = {"witnesses": [plan.npc], "public": false, "power": plan.power}
			if plan.power == "POWER_ANCHOR": details["institution"] = plan.payload.institution
			if world.introduce_fact("miracle", plan.domain, plan.npc, [plan.npc], [cause, result_source], details, [plan.npc], [], owner).is_empty(): return false
	return true

static func _attempt_for(state: Dictionary, source: String) -> Dictionary:
	var fact: Variant = Store.entry(state.facts, source)
	if not fact is Dictionary: return {}
	if fact.get("kind") == "power_attempt": return fact
	if fact.get("kind") != "turn_check" or not fact.get("causal_parents") is Array: return {}
	for parent: String in fact.causal_parents:
		var attempt: Variant = Store.entry(state.facts, parent)
		if attempt is Dictionary and attempt.get("kind") == "power_attempt": return attempt
	return {}

static func _valid_preparation_consumer(state: Dictionary, preparation: String, consumer: String) -> bool:
	var oracle: Dictionary = _attempt_for(state, preparation)
	var fact: Variant = Store.entry(state.facts, consumer)
	if oracle.is_empty() or not fact is Dictionary or not fact.get("kind") in ["power_attempt", "prayer_attempt"] or fact.get("actor") != oracle.actor or fact.get("turn", -1) < oracle.turn or fact.get("turn", 2147483647) > oracle.turn + 1: return false
	var selected: Variant = fact.get("changes", {}).get("preparations")
	if not selected is Array or selected.count(preparation) != 1: return false
	var action: String = str(fact.changes.get("power", "")) if fact.kind == "power_attempt" else "PRAYER/" + str(fact.changes.get("request", "")) + "/" + str(fact.changes.get("variant", ""))
	if action == "POWER_MANIFEST_CONTINUE": action = "POWER_MANIFEST"
	return oracle.changes.get("payload", {}).get("declared_action") == action

static func _audit_history(state: Dictionary, content: RefCounted) -> Array[String]:
	# This exhaustive pass belongs only to load/adoption. Committed historical
	# roots are immutable during ordinary transactions; current heads below are
	# checked without enumerating the archive.
	var expected_cooldowns: Dictionary = {}
	var expected_preparations: Dictionary = {}
	var ids: Array = Store.keys(state.facts); ids.sort()
	for id: String in ids:
		var fact: Dictionary = Store.entry(state.facts, id)
		if fact.get("kind") == "power_attempt":
			var data: Dictionary = fact.changes
			var power: String = str(data.get("power", ""))
			var base: String = "POWER_MANIFEST" if power == "POWER_MANIFEST_CONTINUE" else power
			if not content.tables.powers.has(base) or not data.get("payload") is Dictionary or not data.get("payment") is String: return ["Malformed historical power attempt"]
			var payment: Variant = Store.entry(state.facts, data.payment)
			var faith: int = content.integer("manifest_continue_faith") if power == "POWER_MANIFEST_CONTINUE" else int(content.tables.powers[base].faith)
			var whispers: int = content.integer("manifest_continue_whispers") if power == "POWER_MANIFEST_CONTINUE" else int(content.tables.powers[base].whispers)
			if not payment is Dictionary or payment.get("kind") != "turn_action" or payment.turn != fact.turn or payment.changes.get("faith_cost") != faith or payment.changes.get("whispers_cost") != whispers or not data.payment in fact.causal_parents: return ["Historical power attempt lacks exact paid costs"]
			for preparation: Variant in data.get("preparations", []):
				if not preparation is String or Store.entry(state.applied_authorizations, "power/preparation/" + preparation, "") != id: return ["Used preparation lost its consumption source"]
			for rule: String in ["weakness", "witness"]:
				if data.get("proofs", {}).has(rule):
					var proof: Dictionary = data.proofs[rule]
					if Store.entry(state.applied_authorizations, "power/" + rule + "/" + str(proof.get("basis", {}).get("source", "")), "") != id: return ["One-use power source lost its consumption"]
			if power == "POWER_LISTEN":
				var target: String = str(data.get("proofs", {}).get("listen", {}).get("basis", {}).get("fact", ""))
				if Store.entry(state.applied_authorizations, "power/revealed/" + target, "") != id: return ["Revealed fact lost its source"]
		if fact.get("kind") != "turn_check": continue
		var attempt: Dictionary = _attempt_for(state, id)
		if attempt.is_empty(): continue
		var power: String = str(attempt.changes.get("power", ""))
		if not content.tables.powers.has(power): continue
		var outcome: String = str(fact.changes.get("outcome", ""))
		var p: Variant = fact.changes.get("probability"); var roll: Variant = fact.changes.get("roll")
		if not p is int or p < content.integer("check_probability_min") or p > content.integer("check_probability_max") or not roll is int or roll < 1 or roll > 100 or p != attempt.changes.get("probability"): return ["Historical check disagrees with its locked probability"]
		var divisor: int = content.integer("check_critical_divisor")
		var expected: String = "deep" if roll <= int(floor(float(p) / divisor)) else ("success" if roll <= p else ("disaster" if roll > 100 - int(ceil(float(100 - p) / divisor)) else "failure"))
		if outcome != expected: return ["Historical check result disagrees with its die"]
		if power == "POWER_BESTOW" and outcome in ["deep", "success"] and Store.entry(state.applied_authorizations, "power/bestow/" + attempt.actor, "") != id: return ["Lifetime bestowal lost its source"]
		var cooldown: int = int(content.tables.powers[power].cooldown_turns)
		if cooldown > 0 and attempt.turn + cooldown >= state.turn: expected_cooldowns[power + "/" + primary_key(power, attempt.changes.payload, attempt.actor, attempt.domain, str(attempt.changes.get("cult", "")), attempt.changes.get("proofs", {}))] = {"until": attempt.turn + cooldown, "source": id}
		if power == "POWER_ORACLE" and outcome in ["deep", "success"]:
			var consumer: String = str(Store.entry(state.applied_authorizations, "power/preparation/" + id, ""))
			if not consumer.is_empty():
				if not _valid_preparation_consumer(state, id, consumer): return ["Preparation consumption disagrees with its declared actor/action"]
			elif attempt.turn + 1 >= state.turn: expected_preparations[id] = true
	if expected_cooldowns != state.power_system.cooldowns: return ["Current cooldowns omitted or invented historical duties"]
	if expected_preparations.size() != state.power_system.preparations.size(): return ["Preparation ledger omitted or invented a source"]
	for source: String in expected_preparations:
		if not state.power_system.preparations.has(source): return ["Unused oracle preparation disappeared"]
	return []

static func validate_state(state: Dictionary, content: RefCounted, trusted: Dictionary = {}) -> Array[String]:
	if not state.has("power_system"):
		if trusted.has("power_system"): return ["Power policy cannot disappear"]
		return []
	var ledger: Variant = state.power_system
	if not ledger is Dictionary or ledger.get("schema") != SCHEMA or ledger.get("version") != rule_version(content) or not ledger.get("issuers") is Dictionary or not ledger.get("cooldowns") is Dictionary or not ledger.get("preparations") is Dictionary or not ledger.get("detentions") is Dictionary or not ledger.get("manifest") is Dictionary or not ledger.get("completion") is String: return ["Invalid power policy/schema"]
	if not trusted.is_empty() and trusted.has("power_system") and ledger.issuers != trusted.power_system.issuers: return ["Power issuers cannot change during play"]
	if trusted.is_empty():
		var history_errors: Array[String] = _audit_history(state, content)
		if not history_errors.is_empty(): return history_errors
	for key: String in ledger.cooldowns:
		var entry: Variant = ledger.cooldowns[key]
		if not entry is Dictionary or not entry.get("until") is int or not Store.has(state.facts, entry.get("source", "")): return ["Invalid power cooldown"]
		var attempt: Dictionary = _attempt_for(state, entry.source)
		if attempt.is_empty() or not content.tables.powers.has(attempt.changes.get("power", "")): return ["Cooldown lacks a power attempt"]
		var power: String = attempt.changes.power
		if entry.until != attempt.turn + int(content.tables.powers[power].cooldown_turns) or key != power + "/" + primary_key(power, attempt.changes.payload, attempt.actor, attempt.domain, str(attempt.changes.get("cult", "")), attempt.changes.get("proofs", {})): return ["Cooldown contradicts its original attempt"]
	for key: String in ledger.preparations:
		var entry: Variant = ledger.preparations[key]
		if not entry is Dictionary or entry.get("source") != key or not Store.has(state.facts, key) or not Store.has(state.npcs, entry.get("npc", "")) or (not content.tables.powers.has(entry.get("action", "")) and not PrayerRules.prayer_action(str(entry.get("action", ""))).ok) or not entry.get("amount") is int or not entry.get("expires") is int: return ["Invalid power preparation"]
		var attempt: Dictionary = _attempt_for(state, key)
		var check: Dictionary = Store.entry(state.facts, key)
		if attempt.is_empty() or attempt.changes.get("power") != "POWER_ORACLE" or attempt.actor != entry.npc or attempt.changes.payload.get("declared_action") != entry.action or entry.expires != attempt.turn + 1 or not check.changes.get("outcome", "") in ["deep", "success"]: return ["Preparation contradicts its oracle source"]
		var outcome: String = "deep_success" if check.changes.outcome == "deep" else "success"
		var expected: int = -1
		for row: Dictionary in content.tables.power_effects.values():
			if row.power_id == "POWER_ORACLE" and row.outcome == outcome and row.operation == "grant_preparation": expected = content.integer(row.parameter) if not row.parameter.is_empty() else int(row.value)
		if entry.amount != expected: return ["Preparation amount contradicts authored result"]
	for id: String in ledger.detentions:
		var entry: Variant = ledger.detentions[id]
		if not entry is Dictionary or not Store.has(state.npcs, id) or not entry.get("due") is int or not Store.has(state.facts, entry.get("source", "")): return ["Invalid temporary detention"]
		var fact: Dictionary = Store.entry(state.facts, entry.source)
		if fact.kind != "status_change" or fact.actor != id or fact.changes.get("to") != "detained": return ["Detention contradicts its identity source"]
	if not ledger.completion.is_empty():
		if not Store.has(state.facts, ledger.completion): return ["Missing ritual completion"]
		var completion: Dictionary = Store.entry(state.facts, ledger.completion)
		if completion.kind != "manifest_completed" or completion.changes.get("awakening") != content.integer("awakening_terminal") or not completion.changes.get("ritual") is Dictionary or not completion.get("causal_parents") is Array or completion.causal_parents.size() != 1: return ["Invalid ritual completion"]
		var ritual: Dictionary = completion.changes.ritual
		var final_check: Variant = Store.entry(state.facts, completion.causal_parents[0])
		if not final_check is Dictionary or final_check.get("kind") != "turn_check" or not final_check.changes.get("outcome", "") in ["deep", "success"] or final_check.changes.get("probability") != ritual.get("probability") or ritual.get("progress") != content.integer("manifest_duration") or not ritual.get("steps") is Array or ritual.steps.size() != content.integer("manifest_duration"): return ["Ritual completion lacks the third-round locked check"]
		var prior_turn: int = -1
		for index: int in ritual.steps.size():
			var step: Variant = Store.entry(state.facts, ritual.steps[index])
			if not step is Dictionary or step.get("kind") != "power_attempt" or step.actor != completion.actor or step.changes.get("power") != ("POWER_MANIFEST" if index == 0 else "POWER_MANIFEST_CONTINUE") or (prior_turn >= 0 and step.turn != prior_turn + 1): return ["Ritual completion has a broken consecutive step chain"]
			prior_turn = step.turn
		if not final_check.changes.get("roll") is int or final_check.changes.roll < 1 or final_check.changes.roll > ritual.probability or ritual.probability < content.integer("check_probability_min") or ritual.probability > content.integer("check_probability_max"): return ["Ritual completion has an impossible successful die"]
		if prior_turn != completion.turn or ritual.steps[-1] != ritual.get("source") or not ritual.source in final_check.causal_parents or Store.entry(state.facts, ritual.source).changes.get("probability") != ritual.probability: return ["Ritual completion does not match its final paid step"]
	if not ledger.manifest.is_empty():
		var ritual: Dictionary = ledger.manifest
		if not Store.has(state.npcs, ritual.get("npc", "")) or not state.anchors.has(ritual.get("cosmic_anchor", "")) or not state.anchors.has(ritual.get("system_anchor", "")) or not ritual.get("progress") is int or ritual.progress < 1 or ritual.progress > content.integer("manifest_duration") or not ritual.get("paid_turn") is int or ritual.paid_turn > state.turn or not Store.has(state.facts, ritual.get("source", "")) or not ritual.get("probability") is int: return ["Invalid ongoing ritual"]
		if not ritual.get("steps") is Array or ritual.steps.size() != ritual.progress or ritual.steps[-1] != ritual.source: return ["Ritual progression has no exact step sources"]
		if not ritual.get("anomalies") is Array or ritual.anomalies.size() > content.integer("manifest_duration") * 2: return ["Invalid ritual public source set"]
		for source: Variant in ritual.anomalies:
			var fact: Variant = Store.entry(state.facts, source)
			if not source is String or not fact is Dictionary or fact.get("kind") != "public_anomaly" or fact.changes.get("power") != "POWER_MANIFEST" or not fact.changes.get("anchor", "") in [ritual.cosmic_anchor, ritual.system_anchor]: return ["Ritual public source changed its fixed object"]
		var prior_turn: int = -1
		for index: int in ritual.steps.size():
			var step: Variant = Store.entry(state.facts, ritual.steps[index])
			if not step is Dictionary or step.get("kind") != "power_attempt" or step.actor != ritual.npc or step.changes.get("power") != ("POWER_MANIFEST" if index == 0 else "POWER_MANIFEST_CONTINUE") or step.changes.payload.get("cosmic_anchor") != ritual.cosmic_anchor or step.changes.payload.get("system_anchor") != ritual.system_anchor or (prior_turn >= 0 and step.turn != prior_turn + 1): return ["Ritual steps contradict fixed objects or consecutive turns"]
			var payment: Variant = Store.entry(state.facts, step.changes.get("payment", ""))
			var expected_faith: int = int(content.tables.powers.POWER_MANIFEST.faith) if index == 0 else content.integer("manifest_continue_faith")
			var expected_whispers: int = int(content.tables.powers.POWER_MANIFEST.whispers) if index == 0 else content.integer("manifest_continue_whispers")
			if not payment is Dictionary or payment.get("kind") != "turn_action" or payment.turn != step.turn or payment.changes.get("faith_cost") != expected_faith or payment.changes.get("whispers_cost") != expected_whispers: return ["Ritual step lacks actual continuation payment"]
			prior_turn = step.turn
		if prior_turn != ritual.paid_turn or (ritual.progress == content.integer("manifest_duration") and (ritual.probability < content.integer("check_probability_min") or ritual.probability > content.integer("check_probability_max") or Store.entry(state.facts, ritual.source).changes.get("probability") != ritual.probability)) or (ritual.progress < content.integer("manifest_duration") and ritual.probability != -1): return ["Ritual locked probability or paid turn disagrees"]
		if state.has("attention"):
			if not state.attention.reservations.has(ritual.get("token", "")): return ["Ritual lost persistent capacity"]
			var reservation: Dictionary = state.attention.reservations[ritual.token]
			if not reservation.persistent or reservation.get("owner") != ID or not ritual.npc in reservation.people or not state.anchors[ritual.cosmic_anchor].domain in reservation.focus or not state.anchors[ritual.system_anchor].domain in reservation.focus: return ["Ritual capacity does not match its fixed objects"]
	return []
