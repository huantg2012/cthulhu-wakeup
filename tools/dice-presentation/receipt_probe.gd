extends SceneTree
## Explicit public-receipt fixtures. They test projection/association only and
## do not claim to be Session gameplay, balance, or animation evidence.
const Model = preload("res://src/presentation/production/dice/result_model.gd")
const Fields = preload("res://src/presentation/production/painted/card_fields.gd")

class Host extends RefCounted:
	var _feedback = preload("res://src/presentation/experience_feedback.gd").new()
	func title(id: String) -> String:
		return {"NPC-A":"诺拉","NPC-B":"伊文","DOMAIN-A":"灰海"}.get(id,id)

var checks := 0
var failures: Array[String] = []

func require(condition: bool, note: String) -> void:
	checks += 1
	if not condition: failures.append(note)

func die(roll: int, target: int, outcome: String) -> Dictionary:
	return {"roll":roll,"probability":target,"outcome":outcome}

func fact(id: String, actor: String, check: Dictionary) -> Dictionary:
	return {"id":id,"kind":"turn_check","actor":actor,"domain":"DOMAIN-A","changes":check.duplicate(true),"causal_parents":[]}

func response(dice: Array, facts: Array = []) -> Dictionary:
	return {"ok":true,"turn":3,"result":{"checks":dice,"outcome":""},"facts":facts}

func text_lines(batch: Dictionary) -> String:
	var parts: Array[String] = []
	for line: Variant in batch.lines:
		parts.append(Fields.plain([line]) if line is Dictionary else (Fields.plain(line) if line is Array else str(line)))
	return "\n".join(parts)

func _initialize() -> void:
	var host := Host.new()
	var context := {"title":"回应求告","card":{"kind":"prayer","title":"真实处境","subject_id":"request"}}
	var before := {"turn":3,"faith":18,"whispers":3,"people":[{"id":"NPC-A","name":"诺拉","sanity":50}]}
	var after := {"turn":3,"faith":16,"whispers":2,"people":[{"id":"NPC-A","name":"诺拉","sanity":47}]}
	var repeated := [die(42,64,"success"),die(42,64,"success")]
	var public_checks := [fact("FACT-A","NPC-A",repeated[0]),fact("FACT-B","NPC-B",repeated[1])]
	var receipt := response(repeated,public_checks)
	var frozen := JSON.stringify([receipt,before,after,context])
	var batch: Dictionary = Model.build(host,receipt,before,after,context)
	require(batch.checks.size()==2,"Two equal dice were collapsed")
	require(batch.checks[0].subject=="诺拉" and batch.checks[1].subject=="伊文","Equal dice lost their ordered actor association")
	require(batch.checks[0].title.ends_with("检定 1") and batch.checks[1].title.ends_with("检定 2"),"Multi-check identity is ambiguous")
	require(batch.turn==3 and batch.card==context.card,"Public context or turn lost")
	require("理智 50 → 47" in text_lines(batch),"Actual public consequence was lost")
	require("信仰 18 → 16" in batch.resources and "低语 3 → 2" in batch.resources,"Actual resource accounting lost")
	require(not "信仰 18 → 16" in text_lines(batch),"Resource accounting duplicated in body")
	require(frozen==JSON.stringify([receipt,before,after,context]),"Presentation mutated input data")
	# Data returned to the presenter must not retain mutable card/draft aliases.
	batch.card.title = "presentation only"
	batch.context.title = "presentation only"
	require(context.card.title=="真实处境" and context.title=="回应求告","Presentation retained mutable input aliases")
	# A partly public sequence cannot be zipped or joined by the identical roll.
	batch = Model.build(host,response(repeated,[public_checks[1]]),before,after,context)
	require(batch.checks.size()==2 and batch.checks[0].subject.is_empty() and batch.checks[1].subject.is_empty(),"Partial facts fabricated an actor assignment")
	var different := [die(12,64,"deep"),die(88,64,"failure")]
	batch = Model.build(host,response(different,[fact("FACT-A","NPC-A",different[1]),fact("FACT-B","NPC-B",different[0])]),before,after,context)
	require(batch.checks[0].roll==12 and batch.checks[1].roll==88,"Fact order changed original dice")
	require(batch.checks[0].subject.is_empty() and batch.checks[1].subject.is_empty(),"Mismatching fact order attached wrong actor")
	var prayer := {"id":"RESULT","kind":"prayer_space_result","causal_parents":["FACT-A"],"changes":{"request":"request","title":"真实处境","choice_label":"曲解 · 留下回声","roll":7,"success_target":64,"outcome":"deep","disclosure":"unknown","effect":"隔门出现另一道声音。","tradeoff":"原说话者仍被隔在门外。","maintenance_remaining":2}}
	var twist := {"kind":"prayer_space_twist","changes":{"roll":7,"total":64}}
	var single := die(7,64,"deep")
	batch = Model.build(host,response([single],[fact("FACT-A","NPC-A",single),prayer,twist]),before,after,context)
	require(batch.checks.size()==1,"Check/result/twist facts created duplicate dice")
	require(batch.checks[0].label=="已显现" and batch.checks[0].outcome=="deep","Unknown manifestation was advertised as rescue success")
	require(batch.checks[0].title=="曲解 · 留下回声","Chosen prayer response name was lost")
	require("隔门出现另一道声音。" in text_lines(batch) and not "原说话者仍被隔在门外。" in text_lines(batch) and "还需 2 轮" in text_lines(batch),"Prayer effect/upkeep lost or removed tradeoff shown")
	require(text_lines(batch).count("隔门出现另一道声音。")==1,"Prayer effect repeated")
	require(not "真实处境" in text_lines(batch),"Prayer title repeated inside result body")
	batch = Model.build(host,response([single],[prayer]),before,after,context)
	require(batch.checks[0].label=="已显现" and batch.checks[0].subject.is_empty(),"Sole explicit prayer result was lost or fabricated actor")
	# A route attempt remains hidden: the public receipt still supplies its die.
	batch = Model.build(host,response([die(83,44,"failure")]),before,after,{"title":"研习神迹记录","card":{}})
	require(batch.checks[0].title=="研习神迹记录" and batch.checks[0].roll==83 and batch.checks[0].label=="失败","Activity receipt requires hidden route_attempt")
	# A public locked check identifies the final manifestation; raw ritual state
	# and an uncommitted preview are deliberately absent from this host.
	var locked := fact("FINAL","NPC-A",die(100,64,"disaster"))
	locked.changes.locked = true
	batch = Model.build(host,response([die(100,64,"disaster")],[locked]),before,after,{"title":"第 3 轮 · 轮末检定","card":{}})
	require(batch.checks[0].title=="降临 · 终极检定" and batch.checks[0].roll==100 and batch.checks[0].label=="灾变","Final ritual context or D100=100 changed")
	var masked := fact("MASKED","尚未知晓",single)
	masked.domain = "尚未知晓"
	batch = Model.build(host,response([single],[masked]),before,after,context)
	require(batch.checks[0].subject.is_empty() and batch.checks[0].detail.is_empty(),"Masked identities leaked into check labels")
	require(Model.build(host,response([], [prayer,twist]),before,after,context).is_empty(),"Facts generated dice when receipt has none")
	var rejected := response([single]); rejected.ok = false
	require(Model.build(host,rejected,before,after,context).is_empty(),"Rejected transaction played dice")
	require(Model.build(host,response([die(0,-1,"success")]),before,after,context).is_empty(),"Deterministic operation fabricated a die")
	var won := response([single]); won.result.outcome = "awakened"
	batch = Model.build(host,won,before,after,context)
	require("降临已成" in text_lines(batch),"Committed terminal outcome lost")
	if not failures.is_empty():
		for message: String in failures: push_error(message)
		print("DICE_RECEIPT_FAILED ",failures.size()," / ",checks)
		quit(1)
		return
	print("DICE_RECEIPT_OK ",checks)
	quit()
