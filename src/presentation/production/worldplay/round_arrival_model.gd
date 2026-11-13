extends RefCounted
## A presentation ledger of public identities, never a gameplay participant.
const Actions = preload("res://src/presentation/production/worldplay/action_model.gd")
var turn := -1
var seen_people := {}
var seen_actions := {}
var bootstrap := "resume"
var cards: Array = []
var counts := {}

func reset(new_game: bool) -> void:
	turn = -1
	seen_people.clear()
	seen_actions.clear()
	cards.clear()
	bootstrap = "new" if new_game else "resume"

func observe(session: RefCounted, projection: Dictionary) -> bool:
	if not projection.get("active", false) or projection.get("phase") not in ["events", "actions"]: return false
	if turn == int(projection.turn): return false
	var first := turn < 0
	turn = int(projection.turn)
	var action_cards := _actions(session, projection)
	if first and bootstrap == "resume":
		for person: Dictionary in projection.get("people", []):
			if not person.has("已知范围"): seen_people[person.id] = true
		for action: Dictionary in action_cards: seen_actions[action.id] = true
	cards = []
	counts = {"event": 0, "prayer": 0, "person": 0, "unlock": 0}
	for event: Dictionary in projection.get("events", []):
		if event.resolved: continue
		var place := str(event.descriptor.get("domain", ""))
		var options: Array = session.action_catalog({}, str(event.key) + "/")
		var names := PackedStringArray()
		for option: Dictionary in options:
			names.append(str(option.get("details", {}).get("选项名称", option.get("title", ""))))
		var actor := str(event.descriptor.get("subjects", {}).get("petitioner", ""))
		var actor_name: String = session.object_title(actor) if not actor.is_empty() else ""
		var story := "待裁决 · " + " / ".join(names)
		if not actor_name.is_empty(): story = "涉及 · " + actor_name + "\n" + story
		_add({"id": event.key, "title": event.title, "type": "action", "group": "event", "kind": "event",
			"detail": actor_name if not actor_name.is_empty() else "本轮待决", "domain": place, "arrival": "event", "eyebrow": "世界异动 · 需要裁决",
			"story": story, "guidance": "进入本轮后，先处理世界事件。此处只作预告，不选择结果。"})
	var petitioners := {}
	for prayer: Dictionary in projection.get("prayers", []):
		if prayer.status != "open": continue
		var descriptor: Dictionary = prayer.descriptor
		var person := str(descriptor.get("subjects", {}).get("petitioner", ""))
		if not person.is_empty(): petitioners[person] = true
		var due := int(prayer.card.get("due_turn", descriptor.get("due_turn", -1)))
		var fresh := int(prayer.card.get("visible_turn", descriptor.get("visible_turn", -1))) == turn
		var detail := "本轮传来" if fresh else "仍待回应"
		if due >= 0: detail += " · 第 %s 轮到期" % due
		_add({"id": prayer.key, "title": prayer.title, "type": "action", "group": "prayer", "kind": "prayer",
			"petitioner": person, "domain": descriptor.get("domain", prayer.card.get("domain", "")), "detail": detail,
			"arrival": "prayer", "eyebrow": "祈求 · " + detail,
			"story": session.prayer_appeal(descriptor, prayer.card),
			"guidance": "本轮回应机会已用，仍可查阅处境。" if projection.get("prayer_response_spent", false) else "回到所属世界，拖出这张祈求牌，查看实际回应与代价。"})
	for person: Dictionary in projection.get("people", []):
		if person.has("已知范围"): continue
		var fresh: bool = not seen_people.has(person.id)
		seen_people[person.id] = true
		if not fresh or petitioners.has(person.id): continue
		var role := str(person.get("role_name", "已知人物"))
		_add({"id": "person/"+str(person.id), "title": person.title, "type": "object", "group": "person", "kind": "person",
			"subject": person, "domain": person.get("domain", ""), "detail": role,
			"arrival": "person", "eyebrow": "新知人物 · " + ("信徒" if person.get("bound_member", false) else "已知联系"),
			"story": "身份已进入你的视野。\n" + role,
			"guidance": "人物牌可查阅其已知身份与关系。已知联系并不因此成为信徒。"})
	for action: Dictionary in action_cards:
		var fresh: bool = not seen_actions.has(action.id)
		seen_actions[action.id] = true
		if not fresh: continue
		var item := action.duplicate(true)
		item.arrival = "unlock"
		var power: bool = item.group == "power" or item.id == "anchor/bind"
		item.eyebrow = ("初醒权能" if first else "新启权能") if power else ("初始行为" if first else "新添行为")
		item.detail = item.eyebrow
		item.story = str(item.get("effect", ""))
		item.guidance = "已纳入牌桌。施行时仍须选择对象，并核对条件与代价。"
		_add(item)
	return not cards.is_empty()

func _add(card: Dictionary) -> void:
	cards.append(card)
	counts[card.arrival] += 1

func _actions(session: RefCounted, projection: Dictionary) -> Array:
	var model := Actions.new()
	var unique := {}
	for world: Dictionary in projection.get("domains", []):
		if world.has("已知范围"): continue
		var local := model.cards(session, projection, str(world.id))
		for cult: Dictionary in projection.get("cults", []):
			if cult.get("domain") == world.id and cult.get("status") != "destroyed":
				local.append_array(model.cards(session, projection, str(world.id), str(cult.id)))
		for action: Dictionary in local:
			if action.group == "prayer": continue
			# The same verb in another world/organisation is not a new action.
			var key: String = str(action.id)
			if action.get("kind") == "order": key = "order/" + str(action.selection.strategy)
			if unique.has(key): continue
			var item := action.duplicate(true)
			item.id = key
			item.domain = str(world.id)
			unique[key] = item
	return unique.values()
