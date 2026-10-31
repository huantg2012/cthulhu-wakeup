extends RefCounted
## Fixture compatibility only. Never installs a gameplay capability or bypasses
## an audit. In-transaction local births still use the original production path.
const OldKnowledge = preload("res://tools/prayer-knowledge/run.gd")
const Store = preload("res://src/simulation/archive_store.gd")
const World = preload("res://src/simulation/world.gd")

class CompatibleWorld extends OldKnowledge.KnowledgeRejectWorld:
	var reject_dispatch: bool = false
	var reject_calls: bool = false
	var prerequisite_people: Array = []
	func _nominate_local(domain: String, institution: String, profile: String, source: String) -> bool:
		if transaction != null: return super._nominate_local(domain, institution, profile, source)
		# Old suites used this internal local-expansion helper for their existing
		# named prerequisites. Use actual standalone admission/nomination instead.
		var key: String = "pipeline-prerequisite/" + domain + "/" + str(state.next_npc)
		# Standalone naming reserves K only, not an interaction. Future fixation
		# must still obtain its real P/N budget through the unchanged entry.
		var needs: Dictionary = {"focus": [], "people": [], "members": [], "identities": [key], "source": source}
		var reserved: Dictionary = attention.reserve(self, needs)
		if not reserved.get("ok", false): return false
		var accepted: bool = submit({"kind": "nominate", "domain": domain, "institution": institution, "profile": profile, "group": "unnamed_nonfollowers", "parents": [source], "identity_key": key, "attention_token": reserved.token})
		attention.finish(self, reserved.token)
		return accepted
	func validate_increment(candidate: Dictionary, trusted: Dictionary) -> Array[String]:
		var issues: Array[String] = super.validate_increment(candidate, trusted)
		if reject_dispatch and candidate.get("prayer_dispatch", {}) != trusted.get("prayer_dispatch", {}): issues.append("Injected dispatcher publication failure")
		if reject_calls:
			for number: int in range(int(trusted.next_fact), int(candidate.next_fact)):
				if Store.entry(candidate.facts, "FACT-%08d" % number, {}).get("kind") == "prayer_call":
					issues.append("Injected new call publication failure")
					break
		return issues

static func new_world(catalog: RefCounted, seed_value: int) -> RefCounted:
	var world: RefCounted = CompatibleWorld.new(catalog)
	assert(world.generate_hybrid(seed_value))
	return world

static func people(world: RefCounted, domain: String = "DOMAIN-001") -> Array:
	var result: Array = world.history.ids("active/" + domain); result.sort()
	return result

static func pair(world: RefCounted, kinds: Array, same_institution: Variant = null, anchor: String = "") -> Dictionary:
	var ids: Array = people(world)
	for a: String in ids:
		if not anchor.is_empty() and a != anchor: continue
		for b: String in ids:
			if a == b: continue
			var left: Dictionary = Store.entry(world.state.npcs, a); var right: Dictionary = Store.entry(world.state.npcs, b)
			if same_institution is bool and (left.institution == right.institution) != same_institution: continue
			var matches: Array = world.relation_between(a, b, kinds)
			if matches.is_empty(): matches = world.relation_between(b, a, kinds)
			if not matches.is_empty(): return {"a": a, "b": b, "source": matches[0].source, "kind": matches[0].kind}
	return {}

static func ordered_people(world: RefCounted) -> Array:
	if not world.prerequisite_people.is_empty(): return world.prerequisite_people.duplicate()
	var ids: Array = people(world)
	var family: Dictionary = pair(world, ["family"])
	if family.is_empty(): return ids
	var result: Array = [family.a, family.b]
	for person: String in ids:
		if not person in result: result.append(person)
	return result

static func family_world(catalog: RefCounted, shape: String) -> RefCounted:
	# Conditional consumer prerequisites, not a graph probability test. No
	# sampled failures are hidden: this finite search is recorded as setup.
	for seed_value: int in range(1, 513):
		var world: RefCounted = new_world(catalog, seed_value)
		var ids: Array = people(world)
		if shape == "branch":
			for person: String in ids:
				var relatives: Array = []
				for other: String in ids:
					if other != person and not world.relation_between(person, other, ["family"]).is_empty(): relatives.append(other)
				if relatives.size() >= 2:
					world.prerequisite_people = [person, relatives[0], relatives[1]]
					for other: String in ids:
						if not other in world.prerequisite_people: world.prerequisite_people.append(other)
					return world
		else:
			for a: String in ids:
				for b: String in ids:
					if a >= b or world.relation_between(a, b, ["family"]).is_empty(): continue
					var remaining: Array = ids.filter(func(id: String) -> bool: return not id in [a, b])
					for c: String in remaining:
						for d: String in remaining:
							if c >= d or world.relation_between(c, d, ["family"]).is_empty(): continue
							var last: Array = remaining.filter(func(id: String) -> bool: return not id in [c, d])
							if last.size() == 2 and not world.relation_between(last[0], last[1], ["family"]).is_empty():
								world.prerequisite_people = [a, b, c, d, last[0], last[1]]
								return world
	assert(false, "No real family prerequisite of requested shape in the declared 512-seed setup search")
	return null

static func existing_relation(world: RefCounted, first: String, second: String, kind: String) -> String:
	var matches: Array = world.relation_between(first, second, [kind])
	if matches.is_empty(): matches = world.relation_between(second, first, [kind])
	assert(not matches.is_empty(), "Fixture requested a relation the actual graph did not produce: " + first + "/" + second + "/" + kind)
	return str(matches[0].source) if not matches.is_empty() else ""

static func write_report(checks: Array, scope: String, adaptations: Array, limitations: Array) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var passed: bool = checks.all(func(row: Dictionary) -> bool: return row.status == "pass")
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"status": "pass" if passed else "fail", "engine": Engine.get_version_info().string, "checks": checks, "executionScope": scope, "explicitPrerequisiteAdaptations": adaptations, "limitations": limitations}, "\t", true, true) + "\n")
	file.close()
