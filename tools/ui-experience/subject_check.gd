extends SceneTree
## Explicit presentation fixtures: indexing, known-data boundaries and controls.
## These are not generated campaigns or evidence of economic balance.
const Views = preload("res://src/presentation/experience_views.gd")
var checks: int = 0

class PublicHistory extends RefCounted:
	var facts: Array = []
	func known_sources() -> Array:
		return facts.map(func(fact: Dictionary) -> String: return fact.id)
	func history_page(cursor: int, limit: int) -> Dictionary:
		return {"ok":true, "facts":facts.slice(cursor, cursor + limit).duplicate(true)}
	func explain_error(reason: String) -> String:
		return {"insufficient_faith":"信仰不足", "explicit_refusal":"本轮停供"}.get(reason, reason)

class FixtureHost extends RefCounted:
	var projection: Dictionary = {"active":true, "phase":"actions", "turn":4, "people":[], "domains":[], "cults":[], "anchors":[]}
	var session = PublicHistory.new()
	var draft: Dictionary = {"key":"fixture-current-action", "selection":{"npc":"NPC-29"}}
	var subject: Dictionary = {}
	func title(id: String) -> String:
		for collection: String in ["people", "domains", "cults", "anchors"]:
			for item: Dictionary in projection.get(collection, []):
				if item.id == id: return str(item.get("title", id))
		return id
	func describe(value: Variant) -> String: return str(value)
	func label(text_value: String, _heading: bool = false) -> Label:
		var result := Label.new(); result.text = text_value; return result
	func button(text_value: String, callback: Callable) -> Button:
		var result := Button.new(); result.text = text_value; result.pressed.connect(callback); return result
	func show_subject(kind: String, id: String = "") -> void: subject = {"kind":kind, "id":id}
	func open_action(_key: String, _selection: Dictionary = {}) -> void: pass

func need(condition: bool, message: String) -> bool:
	if not condition:
		push_error("EXPERIENCE_SUBJECT: " + message); quit(1); return false
	checks += 1; return true

func text_of(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += text_of(child)
	return result

func _initialize() -> void:
	var views := Views.new()
	var host := FixtureHost.new()
	for index: int in range(55):
		host.session.facts.append({"id":"FACT-" + str(index), "actor":"NPC-1", "changes":{}, "targets":[], "turn":index})
	for index: int in range(80):
		host.session.facts.append({"id":"UNRELATED-" + str(index), "actor":"NPC-10", "changes":{"note":"prefix NPC-1 suffix"}, "targets":[], "turn":55 + index})
	var page: Dictionary = views._history_slice(host, "NPC-1", 0)
	if not need(page.facts.size() == 50 and page.facts[0].id == "FACT-54" and page.facts[-1].id == "FACT-5" and page.has_older, "filter before paging reaches latest object fact beyond 80 unrelated records"): return
	page = views._history_slice(host, "NPC-1", 50)
	if not need(page.facts.size() == 5 and page.facts[0].id == "FACT-4" and not page.has_older, "next page counts matched facts only"): return
	if not need(not views._fact_refers_to({"actor":"NPC-10", "changes":{"note":"prefix NPC-1 suffix"}}, "NPC-1"), "IDs and narrative substrings cannot falsely match"): return
	if not need(views._fact_refers_to({"changes":{"dependency":{"anchor":"ANCHOR-1"}}}, "ANCHOR-1") and views._fact_refers_to({"changes":{"ANCHOR-1":{"state":"active"}}}, "ANCHOR-1"), "structured nested references and keyed outcomes remain associated"): return
	if not need(views._history_slice(host, "UNKNOWN", 0).facts.is_empty(), "history stays within public history API"): return
	for index: int in range(35):
		var person: Dictionary = {"id":"NPC-" + str(index), "title":"成员" + str(index), "domain":"DOMAIN-A", "cult_id":"CULT-A", "bound_member":true, "status":"active", "acted_turn":3}
		if index == 30: person.erase("acted_turn")
		if index == 31: person.acted_turn = 4
		host.projection.people.append(person)
	host.projection.people.append({"id":"OUTSIDE", "title":"成员30", "domain":"DOMAIN-B", "cult_id":"CULT-B", "bound_member":true, "status":"active", "acted_turn":3})
	host.projection.cults = [{"id":"CULT-A", "title":"甲教团", "domain":"DOMAIN-A", "leader":"NPC-0"}]
	var original_draft: Dictionary = host.draft.duplicate(true)
	views.queries["people/DOMAIN-A"] = "成员30"
	var box := VBoxContainer.new()
	views.render(host, box, "people", "DOMAIN-A")
	var text_value: String = text_of(box)
	if not need("全部 35 人 · 匹配 1 人" in text_value and "执行机会未掌握" in text_value and not "OUTSIDE" in text_value, "name search finds member 30 and retains world scope"): return
	var filter: OptionButton = box.find_child("PersonFilter_people_DOMAIN-A", true, false)
	filter.item_selected.emit(1)
	if not need(views.person_filters["people/DOMAIN-A"] and host.subject == {"kind":"people", "id":"DOMAIN-A"}, "unused filter redraws original world scope"): return
	box.free(); box = VBoxContainer.new()
	views.render(host, box, "people", "DOMAIN-A")
	if not need("全部 35 人 · 匹配 0 人" in text_of(box), "unknown acted_turn does not become an unused opportunity"): return
	box.free(); box = VBoxContainer.new()
	views.queries["members/CULT-A"] = "成员29"
	views.render(host, box, "members", "CULT-A")
	if not need("全部 35 人 · 匹配 1 人" in text_of(box), "member search keeps cult membership boundary"): return
	if not need(not views._person_matches(host, host.projection.people[31], "", true) and views._person_matches(host, host.projection.people[29], "", true), "used and unused opportunities remain distinct"): return
	box.free(); box = VBoxContainer.new()
	host.projection.domains = [{"id":"DOMAIN-A", "title":"灰塔", "tier":"lower", "barrier":null}]
	var before: Dictionary = host.projection.duplicate(true)
	views.render_comparison(host, box, [{"kind":"person", "id":"NPC-29"}, {"kind":"world", "id":"DOMAIN-A"}, {"kind":"person", "id":"OUTSIDE"}])
	text_value = text_of(box)
	if not need(box.find_child("ComparisonSlot_0", true, false) != null and box.find_child("ComparisonSlot_1", true, false) != null and box.find_child("ComparisonSlot_2", true, false) == null, "comparison presents at most two actual subject columns"): return
	if not need("成员29" in text_value and "灰塔" in text_value and "屏障　未掌握" in text_value and not "OUTSIDE" in text_value, "comparison uses known fields without hidden values or third subject"): return
	if not need(before == host.projection and original_draft == host.draft, "viewing and comparison do not mutate projection or current action"): return
	box.free()
	host.projection.anchors = [{"id":"ANCHOR-KNOWN", "title":"旧钟", "state":"active"}]
	host.projection.awakening_sources = [{"kind":"anchor", "title":"ANCHOR-KNOWN", "value":7}, {"kind":"anchor", "title":"ANCHOR-UNKNOWN", "value":20}]
	var forecast: Dictionary = {"anchors":[{"anchor":"ANCHOR-KNOWN", "reason":"insufficient_faith"}, {"anchor":"ANCHOR-UNKNOWN", "reason":"insufficient_faith"}]}
	var supply: String = views._supply_summary(host, forecast)
	if not need("旧钟" in supply and "减少 7" in supply and not "UNKNOWN" in supply and not "27" in supply, "supply impact uses only known anchors and projected current contributions"): return
	host.projection.anchors = []
	if not need(views._supply_summary(host, forecast).is_empty(), "no anchor means no empty supply block"): return
	print("EXPERIENCE_SUBJECT_OK ", checks, " checks; explicit presentation fixtures only")
	quit(0)
