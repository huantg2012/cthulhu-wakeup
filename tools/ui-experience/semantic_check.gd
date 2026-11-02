extends SceneTree
## Presentation-only contract checks against the real CSV. This is deliberately
## not a claim that all prayer situations were reached in a natural campaign.
const Catalog = preload("res://src/simulation/catalog.gd")
const Semantics = preload("res://src/presentation/experience_semantics.gd")
const Actions = preload("res://src/presentation/experience_actions.gd")
const Feedback = preload("res://src/presentation/experience_feedback.gd")
var checks: int = 0

func need(condition: bool, message: String) -> bool:
	if not condition:
		push_error("EXPERIENCE_SEMANTICS: " + message)
		quit(1)
		return false
	checks += 1
	return true

func _initialize() -> void:
	var catalog := Catalog.new()
	if not need(catalog.load_files(), "formal CSV catalog loads"): return
	var semantics := Semantics.new()
	var all_text: String = ""
	for content: String in catalog.tables.prayers:
		for variant: String in ["shallow", "deep"]:
			var summary: Dictionary = semantics.prayer(catalog, content, variant)
			if not need(not summary.success.is_empty() and not summary.failure.is_empty() and "额外" in summary.disaster, content + "/" + variant + " keeps distinct outcomes"): return
			if not need("污染" in summary.success and "污染" in summary.deep and not "污染" in summary.always, content + "/" + variant + " pollution belongs to success"): return
			all_text += JSON.stringify(summary)
	for row: Dictionary in catalog.tables.prayer_effects.values():
		if not row.stage in ["always", "success", "disaster"] or row.operation == "callback": continue
		if not need(not semantics.effect_text(catalog, row, "shallow" if row.variant == "both" else row.variant).is_empty(), "translated effect: " + str(row.id)): return
	# Formerly conflated success-only consequences. An unsuccessful attempt
	# must not claim these as a payment, even when old prayers.*_cost prose does.
	var cases: Array = [
		["PRAYER_02", "shallow", "对手获知"], ["PRAYER_02", "deep", "匿名"],
		["PRAYER_03", "deep", "职位空缺"], ["PRAYER_04", "deep", "调查"],
		["PRAYER_05", "deep", "正统质疑"], ["PRAYER_06", "deep", "敌对见证"],
		["PRAYER_07", "deep", "记忆冲突"], ["PRAYER_08", "deep", "公开先知"],
		["PRAYER_09", "deep", "失踪风险"], ["PRAYER_10", "shallow", "敌意"],
		["PRAYER_11", "shallow", "关联暴露"], ["PRAYER_12", "deep", "反制"],
	]
	for item: Array in cases:
		var summary: Dictionary = semantics.prayer(catalog, item[0], item[1])
		if not need(item[2] in summary.success and not item[2] in summary.always and item[2] in summary.warning, str(item[0]) + " success consequence is visible without false payment"): return
	var devotion: Dictionary = semantics.prayer(catalog, "PRAYER_08", "shallow")
	if not need("忠诚至少" in devotion.success and "忠诚" not in devotion.always and "理智" in devotion.always, "devotion loyalty floor is not paid/reset"): return
	var rescue: Dictionary = semantics.prayer(catalog, "PRAYER_01", "deep")
	if not need("若亲属仍存活" in rescue.always and "不会使其立即死亡" in rescue.failure, "rescue preserves alive condition and original crisis on failure"): return
	var obligation: Dictionary = semantics.prayer(catalog, "PRAYER_06", "shallow")
	if not need("本次契约义务完成" in obligation.success and "义务仍未完成" in obligation.failure and "不能被任命" in obligation.always, "obligation completion is not confused with a mere witness"): return
	if not need("若争端另一方已知晓该披露" in semantics.prayer(catalog, "PRAYER_10", "shallow").success, "hostility keeps knowledge condition"): return
	var effect: Dictionary = catalog.tables.prayer_effects["*/deep/success/01"]
	var scaled: int = maxi(1, int(floor(catalog.integer("prayer_deep_pollution") * catalog.number("prayer_deep_success_multiplier"))))
	if not need("污染 +" + str(scaled) in semantics.prayer(catalog, "PRAYER_07", "deep").deep and semantics.amount(catalog, effect, true) == scaled, "deep success scales pollution as the executable consumer does"): return
	if not need("污染 +%s–%s" % [catalog.integer("prayer_deep_pollution"), scaled] in semantics.prayer(catalog, "PRAYER_07", "deep").summary, "combined success probability uses both possible numeric effects"): return
	for token: String in ["PRAYER_", "EVENT_", "scale", "sanity_loss", "investigation_candidate"]:
		if not need(not token in all_text, "no implementation token: " + token): return
	var actions := Actions.new()
	var event: Dictionary = {"key": "event/private/A", "fields": [], "details": {"幸存者": "守灯者", "原圣物": "裂纹镜", "所在时空": "灰塔", "事件期限": "第 4 轮", "实际来源": "FACT-SECRET", "选择后果": "不应成为身份摘要"}}
	var context: String = "\n".join(actions.context_lines(event))
	if not need("守灯者" in context and "裂纹镜" in context and "灰塔" in context and "第 4 轮" in context and not "FACT-" in context and not "选择后果" in context, "event identity survives empty selectors without dictionary dump"): return
	var selected: Dictionary = {"details": {}, "fields": [{"key": "npc", "label": "执行者", "options": [{"id": "NPC-1", "label": "守灯者"}]}, {"key": "source", "label": "来源", "options": [{"id": "FACT-SECRET", "label": "FACT-SECRET"}]}]}
	context = "\n".join(actions.context_lines(selected, {"npc": "NPC-1", "source": "FACT-SECRET"}))
	if not need("执行者：守灯者" in context and not "FACT-" in context and not "NPC-" in context, "other action identity uses selected known labels only"): return
	var cancel: String = actions._manifest_cancel_loss({"details": {"已付仪式轮次": 2}})
	if not need("2 轮" in cancel and "不保留" in cancel and "不退还" in cancel and not "锚点" in cancel, "cancel explains existing progress loss without inventing anchor loss"): return
	var feedback := Feedback.new()
	var before: Dictionary = {"faith": 20, "people": [{"id": "NPC-1", "title": "守灯者", "sanity": 2, "status": "active"}], "domains": [{"id": "DOMAIN-1", "title": "灰塔", "alert": null}]}
	var after: Dictionary = {"faith": 14, "people": [{"id": "NPC-1", "title": "守灯者", "sanity": 0, "status": "active"}], "domains": [{"id": "DOMAIN-1", "title": "灰塔", "alert": null}]}
	var result: Dictionary = {"ok": true, "facts": [{"kind": "prayer_delta", "targets": ["NPC-1"], "changes": {"field": "sanity", "amount": -10}}, {"kind": "event_delta", "targets": ["DOMAIN-1"], "changes": {"field": "alert", "amount": 4}}, {"kind": "prayer_fact", "targets": ["NPC-1"], "changes": {"tag": "condition_cured"}}]}
	var receipt: Array[String] = feedback.build(null, result, before, after, "回应祈求")
	var receipt_text: String = "\n".join(receipt)
	if not need("守灯者：已脱离此次病危" in receipt[1] and "理智 2 → 0" in receipt_text and not "10" in receipt_text and not "察觉" in receipt_text and "信仰" in receipt[-1], "receipt prioritizes actual cure; clamped known delta only; no unknown world value"): return
	var hidden_before: Dictionary = {"people": [{"id": "NPC-1", "title": "求告者"}]}
	var revealed_after: Dictionary = {"people": [{"id": "NPC-1", "title": "守灯者", "loyalty": 40, "sanity": 67}]}
	receipt_text = "\n".join(feedback.build(null, {"ok": true, "facts": []}, hidden_before, revealed_after, "回应祈求"))
	if not need("现可知" in receipt_text and "忠诚 40" in receipt_text and not "→" in receipt_text, "newly revealed statistics are current values, not fabricated deltas"): return
	result = {"ok": true, "facts": [{"kind": "material_received", "changes": {"sender": "NPC-1", "recipient": "NPC-2", "source": "FACT-SECRET", "grant": "knowledge"}}]}
	var transfer_view: Dictionary = {"people": [{"id": "NPC-1", "title": "守灯者"}, {"id": "NPC-2", "title": "抄写员"}]}
	receipt_text = "\n".join(feedback.build(null, result, transfer_view, transfer_view, "交予记录"))
	if not need("抄写员已从守灯者获知" in receipt_text and not "副本" in receipt_text and not "FACT-" in receipt_text, "knowledge transfer names actual participants without inventing custody"): return
	print("EXPERIENCE_SEMANTICS_OK ", checks, " checks; 12 prayer types / 24 variants; presentation only")
	quit(0)
