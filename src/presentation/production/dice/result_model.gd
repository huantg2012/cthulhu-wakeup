extends RefCounted
## Public presentation only. The receipt's ordered checks are the sole authority
## for dice; result facts describe consequences and never create extra rolls.
const Fields = preload("res://src/presentation/production/painted/card_fields.gd")
const OUTCOMES := {"deep":"深刻成功", "success":"成功", "failure":"失败", "disaster":"灾变"}

static func build(host, response: Dictionary, before: Dictionary, after: Dictionary, context: Dictionary) -> Dictionary:
	if not response.get("ok",false): return {}
	var supplied: Variant = response.get("result",{}).get("checks",[])
	if not supplied is Array or supplied.is_empty(): return {}
	# Reject a malformed presentation batch rather than silently dropping a die
	# and shifting every remaining actor/result association by one position.
	for check: Variant in supplied:
		if not _valid_check(check): return {}
	var facts: Array = response.get("facts",[]).filter(func(fact: Variant)->bool:return fact is Dictionary)
	var checked: Array = facts.filter(func(fact: Dictionary)->bool:return fact.get("kind")=="turn_check")
	var aligned: bool = checked.size()==supplied.size()
	if aligned:
		for index: int in supplied.size():
			if not _same_check(checked[index].get("changes",{}),supplied[index]):
				aligned = false
				break
	var title := str(context.get("title","")).strip_edges()
	if title.is_empty(): title = "轮末检定" if str(context.get("scope","")) in ["round","turn","ending"] else "行动检定"
	var rows: Array = []
	for index: int in supplied.size():
		var original: Dictionary = supplied[index]
		var source: Dictionary = checked[index] if aligned else {}
		var result := _linked_result(facts,source,supplied,index)
		var data: Dictionary = result.get("changes",{})
		var name := title if supplied.size()==1 else "%s · 检定 %d" % [title,index+1]
		var subject := _known_title(host,str(source.get("actor","")))
		var world := _known_title(host,str(source.get("domain","")))
		var detail: Array[String] = []
		if not world.is_empty(): detail.append("所在世界 · "+world)
		if source.get("changes",{}).get("locked",false):
			name = "降临 · 终极检定"
			detail.append("依最终继续时锁定的成功上限结算")
		elif not str(data.get("choice_label","")).is_empty(): name = str(data.choice_label)
		if supplied.size()>1: detail.append("本批第 %d / %d 次检定" % [index+1,supplied.size()])
		var outcome: String = original.outcome
		var label: String = OUTCOMES[outcome]
		if result.get("kind")=="prayer_space_result" and data.get("disclosure")=="unknown" and outcome in ["deep","success"]:
			label = "已显现"
		rows.append({"roll":original.roll,"target":original.probability,"outcome":outcome,"label":label,"title":name,"subject":subject,"detail":" · ".join(detail)})
	var resources: String = host._feedback.resource_summary(before,after)
	var lines := _consequences(host,response,before,after,facts,resources)
	return {"title":title,"card":context.get("card",{}).duplicate(true),"checks":rows,"lines":lines,"resources":resources,"turn":int(response.get("turn",after.get("turn",before.get("turn",0)))),"context":context.duplicate(true)}

static func _valid_check(value: Variant) -> bool:
	return value is Dictionary and value.get("roll") is int and value.roll>=1 and value.roll<=100 and value.get("probability") is int and value.probability>=0 and value.probability<=100 and OUTCOMES.has(str(value.get("outcome","")))

static func _same_check(data: Dictionary, check: Dictionary) -> bool:
	return data.get("roll",-1)==check.roll and data.get("probability",data.get("success_target",data.get("p",-1)))==check.probability and data.get("outcome","")==check.outcome

static func _linked_result(facts: Array, source: Dictionary, checks: Array, index: int) -> Dictionary:
	var results: Array = facts.filter(func(fact: Dictionary)->bool:return fact.get("kind") in ["prayer_space_result","prayer_result","power_result"])
	var id := str(source.get("id",""))
	if not id.is_empty():
		for result: Dictionary in results:
			if id in result.get("causal_parents",[]): return result
	# A single prayer result explicitly reports the sole committed die. This
	# fallback is not a value-keyed join: multiple identical dice remain separate.
	if checks.size()==1 and results.size()==1 and results[0].get("kind") in ["prayer_space_result","prayer_result"] and _same_check(results[0].get("changes",{}),checks[index]):
		return results[0]
	return {}

static func _known_title(host, id: String) -> String:
	if id.is_empty() or id=="尚未知晓": return ""
	var title := str(host.title(id))
	return "" if title.is_empty() or title==id or title=="尚未知晓" else title

static func _consequences(host, response: Dictionary, before: Dictionary, after: Dictionary, facts: Array, resources: String) -> Array:
	var lines: Array = []
	var prayers: Array = facts.filter(func(fact: Dictionary)->bool:return fact.get("kind")=="prayer_space_result")
	for fact: Dictionary in prayers:
		var data: Dictionary = fact.get("changes",{})
		if prayers.size()>1 and not str(data.get("choice_label","")).is_empty(): lines.append(Fields.field("回应",data.choice_label))
		if not str(data.get("effect","")).is_empty(): lines.append(Fields.field("影响",data.effect))
		if int(data.get("maintenance_remaining",0))>0: lines.append(Fields.field("后续供奉","还需 %d 轮" % int(data.maintenance_remaining)))
	# Modern prayer effects are already expressed above; retain every other
	# publicly reported object change once, including costs of a failed attempt.
	var additional := response.duplicate(true)
	additional.facts = facts.filter(func(fact: Dictionary)->bool:return fact.get("kind")!="prayer_space_result")
	for line: String in host._feedback.build(host,additional,before,after,""):
		if line!=resources and line!="行动已执行。" and not line in lines: lines.append(line)
	var ending := str(response.get("result",{}).get("outcome",""))
	if ending=="awakened": lines.append(Fields.field("终局","降临已成，神意苏醒。"))
	elif ending=="extinction": lines.append(Fields.field("终局","维系已断，本局归于寂灭。"))
	if lines.is_empty(): lines.append("此次检定已结算。")
	return lines
