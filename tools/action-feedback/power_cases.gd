extends SceneTree
## Receipt boundary tests; these deliberately supplied facts are NOT evidence
## that every mature power has been played in a production campaign.
const Session = preload("res://src/presentation/session.gd")
const Receipt = preload("res://src/presentation/action_effect_receipt.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
const Store = preload("res://src/simulation/archive_store.gd")
var checks := 0
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message); push_error(message)

func _initialize() -> void:
	var session := Session.new("user://action-feedback-boundary")
	check(session.start_new(1).get("ok",false),"Real Session startup")
	var feedback := Feedback.new()
	var before := {"people":[{"id":"NPC-known","title":"求告者"}],"domains":[{"id":"DOMAIN-known","title":"当地世界","alert":10,"pollution":20}]}
	var after: Dictionary = before.duplicate(true)
	# Hidden person totals and stale world intelligence cannot erase own effects.
	var result := {"ok":true,"action_effects":{"deltas":[{"subject":"NPC-known","field":"loyalty","delta":10},{"subject":"NPC-known","field":"sanity","delta":-4},{"subject":"DOMAIN-known","field":"pollution","delta":2},{"subject":"DOMAIN-known","field":"alert","delta":1}]}}
	var lines := "\n".join(feedback.build(null,result,before,after,""))
	check("忠诚 +10" in lines and "理智 -4" in lines and "污染 +2" in lines and "察觉 +1" in lines,"Unbound actor and stale intelligence")
	check(not "20 → 22" in lines,"Must not turn delta into invented current world reading")
	before.people[0].loyalty=40; after.people[0].loyalty=50
	lines = "\n".join(feedback.build(null,result,before,after,""))
	check(lines.count("忠诚")==1,"Bound actor delta duplicated by projection diff")
	result.action_effects.deltas=[{"subject":"NPC-known","field":"adaptation","delta":0}]
	lines = "\n".join(feedback.build(null,result,before,before,""))
	check("适应 未变化" in lines and not "+1" in lines,"Actual zero clamping")
	# Use the real catalog and known-id privacy filter; isolate a tiny receipt
	# fixture from the actual simulation so tests do not forge committed gameplay.
	var probe := Session.new("user://action-feedback-fixture")
	probe.catalog=session.catalog
	probe.world=RefCountedWorld.new()
	probe.turn=RefCountedTurn.new()
	probe._known_domains["DOMAIN-test"]=true
	probe._known_people["NPC-test"]=true
	var fact := {"id":"FACT-00000001","kind":"world_observation","domain":"DOMAIN-test","actor":"","turn":0,"changes":{"metrics":{"barrier":75}}}
	var attempt := {"id":"FACT-00000002","kind":"power_attempt","domain":"DOMAIN-test","actor":"","turn":1,"changes":{"power":"POWER_LISTEN","proofs":{"listen":{"basis":{"fact":fact.id}}}}}
	var success := {"id":"FACT-00000003","kind":"power_result","domain":"DOMAIN-test","actor":"","turn":1,"changes":{"power":"POWER_LISTEN","outcome":"success"}}
	probe.world.state={"attention":{"reservations":{}},"next_fact":4,"facts":{fact.id:fact,attempt.id:attempt,success.id:success},"npcs":{},"cults":{},"institutions":{},"power_system":{"preparations":{},"manifest":{}}}
	probe._known_facts={attempt.id:true,success.id:true}
	var hidden := Receipt.collect(probe,{}, {},2)
	check(hidden.revealed.is_empty(),"Unknown listen target leaked")
	probe._known_facts[fact.id]=true
	var frozen := JSON.stringify(probe.world.state)
	var revealed := Receipt.collect(probe,{}, {},2)
	check(revealed.revealed.size()==1 and revealed.revealed[0].turn==0,"Reveal an old fact with original observation date")
	check(frozen==JSON.stringify(probe.world.state),"Receipt mutated state")
	# Future effects must be read from actual stored grants / jobs, not the
	# attempt's success label or an authored description.
	attempt.actor="NPC-test"; attempt.changes={"power":"POWER_ORACLE","proofs":{}}
	success.changes={"power":"POWER_ORACLE","outcome":"success"}
	probe.world.state.power_system.preparations[attempt.id]={"npc":"NPC-test","action":"POWER_BREACH","amount":10,"expires":2,"source":attempt.id}
	var oracle := Receipt.collect(probe,{}, {},2)
	check(oracle.developments.size()==1 and oracle.developments[0].expires==2 and oracle.developments[0].action=="POWER_BREACH","Oracle reads actual stored preparation")
	probe.world.state.power_system.preparations.clear()
	check(Receipt.collect(probe,{}, {},2).developments.is_empty(),"Success label alone cannot fabricate preparation")
	probe.world.state.facts[success.id]={"id":success.id,"kind":"turn_scheduled","changes":{"participant":"cults","id":"test-appointment"}}
	probe.turn.context.queued=[{"id":"test-appointment","action":"appointment","due":2,"payload":{"npc":"NPC-test","cult":"","role":"leader"}}]
	var appointment := Receipt.collect(probe,{}, {},3)
	check(appointment.developments.size()==1 and appointment.developments[0].due==2,"Pending appointment reads real queue")
	probe.turn.context.queued.clear()
	check(Receipt.collect(probe,{}, {},3).developments.is_empty(),"Missing job cannot be presented as pending appointment")
	attempt.changes={"power":"POWER_SEED","payload":{},"proofs":{}}
	probe.world.state.facts[success.id]=success
	success.changes={"power":"POWER_SEED","outcome":"success"}
	probe.world.state.domains={"DOMAIN-test":{"unnamed_followers":40}}
	var population_before := {"actor":"","values":{},"cults":{},"populations":{"DOMAIN-test":40}}
	var full := Receipt.collect(probe,{},population_before,2)
	check(full.deltas.size()==1 and full.deltas[0].field=="followers" and full.deltas[0].delta==0,"No available recruits must show zero, not authored four")
	# Every current authored effect family has an explicit actual-result route.
	var paths := {"appoint":"scheduled appointment","delta":"actual delta / resource change / population fact","sacrifice":"status change","reveal":"known old fact","grant_preparation":"stored preparation","invalidate_evidence":"invalidated records","migrate":"migration + population fact","detain":"status change","seal":"relic state","anchor":"binding fact","set":"anchor state","manifest_complete":"manifest completion fact"}
	var powers := {}
	for row: Dictionary in session.catalog.tables.power_effects.values():
		check(paths.has(row.operation),"Unhandled effect family "+row.operation)
		powers[row.power_id]=true
	check(powers.size()==12 and session.catalog.tables.powers.has("POWER_APPOINT"),"Audit must cover all 12 powers including queued appointment")
	var notes := [
		{"kind":"appointment","actor":"NPC-known","cult":"CULT-known","role":"leader","due":2},
		{"kind":"preparation","actor":"NPC-known","action":"PRAYER/example","amount":10,"expires":3},
		{"kind":"manifest","progress":2,"duration":3},
		{"kind":"evidence","count":2}]
	result.action_effects={"developments":notes}
	lines="\n".join(feedback.build(null,result,before,before,""))
	check("尚未就任" in lines and "第 2 轮" in lines,"Appointment is pending, not already done")
	check("+10" in lines and "第 3 轮" in lines and "使用一次" in lines,"Oracle names amount, deadline and single use")
	check("2 / 3" in lines and "下轮仍需" in lines,"Manifest describes continuation instead of completion")
	check("2 项追查依据" in lines,"Veil actual invalidation")
	print("ACTION_FEEDBACK_BOUNDARY ","PASS" if errors.is_empty() else "FAIL"," ",checks," checks")
	quit(0 if errors.is_empty() else 1)

class RefCountedWorld extends RefCounted:
	var state: Dictionary
class RefCountedTurn extends RefCounted:
	var context := {"queued":[]}
