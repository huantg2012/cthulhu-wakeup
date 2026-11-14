extends RefCounted
## Presentation of a completed prayer. Only the public response and projections
## are read; previews and a newly rolled die must never stand in for the receipt.
const Fields = preload("res://src/presentation/production/painted/card_fields.gd")
const OUTCOMES := {"deep":"深刻成功","success":"成功","failure":"失败","disaster":"灾变","deterministic":"已生效"}

static func check_condition(target: int) -> String:
	return "骰点 ≤ %d" % target if target>=0 else "无需掷骰"

static func build(host, response: Dictionary, before: Dictionary, after: Dictionary, request_id: String, choice: String, dismissed: bool) -> Dictionary:
	var receipt := {"committed":bool(response.get("ok",false)),"choice":choice,"outcome":"","label":"未能施行","roll":0,"target":-1,"no_roll":false,"body":[],"remains":true}
	if not receipt.committed:
		receipt.body = [Fields.field("原因",host.session.explain_error(str(response.get("error","当前条件不满足"))))]
		return receipt
	var data: Dictionary = {}
	var modern := false
	for fact: Dictionary in response.get("facts",[]):
		if fact.get("kind") not in ["prayer_space_result","prayer_result"]: continue
		if str(fact.get("changes",{}).get("request",""))!=request_id: continue
		data = fact.changes
		modern = fact.kind=="prayer_space_result"
		break
	var checks: Array = response.get("result",{}).get("checks",[])
	var check: Dictionary = data if data.has("roll") else (checks[0] if checks.size()==1 and not dismissed else {})
	receipt.roll = int(check.get("roll",0))
	receipt.target = int(check.get("success_target",check.get("probability",check.get("p",-1))))
	receipt.no_roll = check.has("roll") and receipt.roll==0 and receipt.target<0 and (check.has("success_target") or check.has("probability") or check.has("p"))
	receipt.outcome = "dismissed" if dismissed else str(data.get("outcome",check.get("outcome","")))
	receipt.label = "祈求已断开" if dismissed else str(OUTCOMES.get(receipt.outcome,"已回应"))
	if data.get("disclosure")=="unknown" and receipt.outcome in ["success","deep"]: receipt.label = "已显现"
	receipt.remains = after.get("prayers",[]).any(func(prayer: Dictionary)->bool:return str(prayer.id)==request_id and prayer.status=="open")
	if modern:
		if not str(data.get("effect","")).is_empty(): receipt.body.append(Fields.field("影响",data.effect))
		if int(data.get("maintenance_remaining",0))>0:
			receipt.body.append(Fields.field("后续供奉","还需 %d 轮" % int(data.maintenance_remaining)))
	elif dismissed:
		receipt.body.append("不再回应这声祈求，求告者的处境仍会继续。")
	# Keep public changes to other objects, but don't repeat the primary result,
	# its title or resource accounting. Failed attempts still retain real costs.
	var additional := response.duplicate(true)
	additional.facts = response.get("facts",[]).filter(func(fact: Dictionary)->bool:return fact.get("kind") not in ["prayer_space_result","prayer_space_closed"])
	var resources: String = host._feedback.resource_summary(before,after)
	for line: String in host._feedback.build(host,additional,before,after,""):
		if line!=resources and line!="行动已执行。": receipt.body.append(line)
	var changes: Array = []
	for pair: Array in [["whispers","低语"],["faith","信仰"],["awakening","苏醒"],["insight","洞见"],["wounds","创伤"]]:
		var key: String = pair[0]
		if before.has(key) and after.has(key) and before[key]!=after[key]:
			if not changes.is_empty(): changes.append("    ")
			changes.append(Fields.field(pair[1],"%s → %s" % [before[key],after[key]]))
	if not changes.is_empty(): receipt.body.append(changes)
	return receipt
