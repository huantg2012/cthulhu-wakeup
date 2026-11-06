extends SceneTree
const Session = preload("res://src/presentation/session.gd")
const Text = preload("res://src/presentation/player_record_text.gd")
class Host extends RefCounted:
	var session: RefCounted
	var projection: Dictionary
	func title(id: String) -> String:
		for key: String in ["people", "institutions", "relics", "cults", "anchors", "domains"]:
			for item: Dictionary in projection.get(key, []):
				if item.get("id") == id: return str(item.get("title", item.get("name", id)))
		return id

func _initialize() -> void:
	run.call_deferred()

func visible(record: Dictionary) -> String:
	return str(record.title) + "\n" + str(record.summary) + "\n" + "\n".join(record.lines)

func run() -> void:
	var host := Host.new()
	host.session = Session.new("/tmp/player-record-text-probe")
	assert(host.session.continue_game("res://docs/qa/ui-manifest/saves/ongoing.json").ok)
	host.projection = host.session.project()
	var before: String = host.session.turn.snapshot()
	var knowledge: Dictionary = host.session.knowledge_snapshot()
	var count := 0
	var fallback_kinds := {}
	var cursor := 0
	while true:
		var page: Dictionary = host.session.history_page(cursor, 100)
		for fact: Dictionary in page.facts:
			var rendered: Dictionary = Text.summarize(host, fact)
			var text: String = visible(rendered)
			assert(not text.contains("FACT-") and not text.contains("shared_memory") and not text.contains("issuer") and not text.contains("fixture") and not text.contains("{"), text)
			assert(not str(rendered.title).is_empty() and not str(rendered.summary).is_empty())
			if rendered.title == "当地经历": fallback_kinds[fact.kind] = true
			count += 1
		if page.complete: break
		cursor = page.cursor
	var anchor := {"kind":"anchor_basis", "domain":"DOMAIN-001", "changes":{"rule":"shared_memory", "institution":"DOMAIN-001/interpretation", "basis":{"secret":"NEVER_REVEAL"}}, "targets":[]}
	var text: String = visible(Text.summarize(host, anchor))
	assert(text.contains("共同记忆") and text.contains("当前条件") and not text.contains("NEVER_REVEAL"))
	var opportunity := {"kind":"institution_relic_opportunity", "domain":"DOMAIN-001", "changes":{"relic_type":"RELIC_HOLLOW_SEAL", "due":3}, "targets":[]}
	text = visible(Text.summarize(host, opportunity))
	assert(text.contains("空名印") and text.contains("第 3 轮到期") and text.contains("等待不会延长"))
	var effect := {"kind":"power_effect", "changes":{"power":"POWER_BESTOW", "field":"sanity", "requested":-8, "actual":-2}, "targets":[]}
	text = visible(Text.summarize(host, effect))
	assert(text.contains("理智 -2") and not text.contains("-8"))
	var event := {"kind":"event_result", "changes":{"content_id":"EVENT_02", "option":"B"}, "targets":[]}
	text = visible(Text.summarize(host, event))
	assert(text.contains("第二份证词") and text.contains("公开收录"))
	text = visible(Text.summarize(host, {"kind":"institution_relic_public", "changes":{}, "targets":[]}))
	assert(text.contains("放弃物件") and text.contains("暴露"))
	text = visible(Text.summarize(host, {"kind":"economy_rest", "changes":{"recovered":2, "faith_cost":4}, "targets":[]}))
	assert(text.contains("恢复创伤 2") and text.contains("4 信仰"))
	assert(not Text.is_history_entry({"kind":"cult_local_payment"}) and Text.is_history_entry({"kind":"power_result"}))
	var unknown := {"kind":"unreleased_internal_operation", "actor":"NPC-99999999", "changes":{"raw_rule":"secret_material_graph", "cost":999}, "targets":[]}
	text = visible(Text.summarize(host, unknown))
	assert(not text.contains("unreleased") and not text.contains("999") and not text.contains("secret"))
	var named := Host.new()
	named.projection = {"people":[{"id":"NPC-00000007", "title":"记录者 · 00000007"}, {"id":"NPC-00000008", "title":"记录者 · 00000008"}, {"id":"NPC-00000009", "title":"祭司 · 00000009"}]}
	var identities: Dictionary = named.projection.duplicate(true)
	assert(Text.entity_name(named, "NPC-00000007") == "记录者 · 7")
	assert(Text.entity_name(named, "NPC-00000008") == "记录者 · 8")
	assert(Text.entity_name(named, "NPC-00000009") == "祭司")
	assert(Text.entity_name(named, "NPC-99999999").is_empty())
	assert(named.projection == identities)
	var remembrance := {"kind":"shared_observation", "actor":"NPC-00000007", "targets":["NPC-00000007", "NPC-00000008", "NPC-99999999"], "changes":{}}
	text = visible(Text.summarize(named, remembrance))
	assert(text.contains("记录者 · 7") and text.contains("记录者 · 8") and not text.contains("000000") and not text.contains("999"))
	assert(host.session.turn.snapshot() == before and host.session.knowledge_snapshot() == knowledge)
	print("PLAYER_RECORD_TEXT_OK public_records=", count, " fallback_kinds=", fallback_kinds.keys())
	quit()
