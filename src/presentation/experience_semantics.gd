extends RefCounted
## Read-only wording for the executable prayer grammar. Numeric values, stages,
## conditions and scaling remain owned by the CSV and Prayers consumer.
const SUBJECTS: Dictionary = {
	"domain": "当地", "petitioner": "求告者", "actor": "回应者", "relative": "亲属",
	"institution": "所在机构", "rival": "对手", "second": "第二见证者",
	"counterparty": "契约另一方", "opponent": "争端另一方", "relic": "原圣物",
	"other_institution": "关联机构",
}
const ATTRIBUTES: Dictionary = {"sanity": "理智", "sanity_loss": "理智", "alert": "察觉", "pollution": "污染", "loyalty": "忠诚", "stability": "稳定", "barrier": "屏障"}
const RECORDS: Dictionary = {
	"miracle_witness": "成为此次神迹的见证者", "private_testimony": "取得秘密证言",
	"public_witness": "留下公开见证", "lost_anonymity": "失去匿名身份",
	"anomaly_record": "保留这份异常记录", "investigation_candidate": "可能遭到后续调查",
	"ritual_witness": "记录此次仪式见证", "public_ritual": "记录一次公开神迹仪式",
	"orthodoxy_question": "可能面临正统质疑", "contract_witness": "留下履约见证",
	"contract_dependency": "开始依赖此次神迹履约", "hostile_witness": "成为潜在敌对见证者",
	"memory_conflict": "留下记忆冲突", "public_prophet": "成为公开先知",
	"anomaly_evidence": "取得公开异常证据", "missing_risk": "面临后续失踪风险（不会立即失踪）",
	"hostility": "对求告者产生敌意", "public_evidence": "取得公开关系证据",
	"relationship_exposed": "与圣物的关联暴露", "exception_record": "保留法则例外记录",
	"public_exception_qualification": "的公开例外证据可能引来反制",
}
const SUCCESS_WARNINGS: Array[String] = ["lost_anonymity", "investigation_candidate", "orthodoxy_question", "contract_dependency", "hostile_witness", "memory_conflict", "public_prophet", "missing_risk", "hostility", "relationship_exposed", "public_exception_qualification"]

func prayer(catalog: RefCounted, content: String, variant: String) -> Dictionary:
	var always: Array[String] = stage_lines(catalog, content, variant, "always")
	var success: Array[String] = stage_lines(catalog, content, variant, "success")
	var deep: Array[String] = stage_lines(catalog, content, variant, "success", true)
	var summary: Array[String] = stage_lines(catalog, content, variant, "success", false, true)
	var disaster: Array[String] = stage_lines(catalog, content, variant, "disaster")
	var failure: String = str(catalog.display_tables.prayer_facts.get(content, {}).get("failure_fact", "原诉求未解决"))
	# The fact table also serves audit prose. Remove audit phrasing without
	# changing which existing facts survive an unsuccessful response.
	failure = failure.replace("不凭失败立即死亡", "；失败本身不会使其立即死亡").replace("且不凭文本增加见证者", "，也未产生新的见证者")
	failure = failure.replace("没有生成新证言也没有新增追随者", "没有新的证言，也未增加信众").replace("不创造新事实也不揭露原事实", "原有关系未被揭露").replace("例外没有被新机构记录但已有记录不删除", "原有例外记录仍在，本次未留下新记录")
	return {"always": "；".join(always), "summary": "；".join(summary), "success": "；".join(success), "deep": "；".join(deep), "failure": failure, "disaster": failure + "；额外：" + "；".join(disaster), "warning": warning(catalog, content, variant)}

func rows(catalog: RefCounted, content: String, variant: String, stage: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in catalog.display_tables.prayer_effects.values():
		if row.prayer_id in ["*", content] and row.variant in ["both", variant] and row.stage == stage: result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return result

func amount(catalog: RefCounted, row: Dictionary, deep_success: bool = false) -> int:
	var value: int = catalog.integer(str(row.parameter)) if not str(row.parameter).is_empty() else int(row.value)
	if deep_success and row.scale == "count": value = signi(value) * maxi(1, int(floor(absi(value) * catalog.number("prayer_deep_success_multiplier"))))
	return value

func stage_lines(catalog: RefCounted, content: String, variant: String, stage: String, deep_success: bool = false, success_range: bool = false) -> Array[String]:
	var result: Array[String] = []
	var common: Array[String] = []
	for row: Dictionary in rows(catalog, content, variant, stage):
		var text: String = effect_text(catalog, row, variant, deep_success, success_range)
		if text.is_empty(): continue
		# Keep the requested change first; the shared pollution consequence is
		# still visible in every successful result, including deep success.
		if row.prayer_id == "*" and stage == "success": common.append(text)
		else: result.append(text)
	result.append_array(common)
	return result

func warning(catalog: RefCounted, content: String, variant: String) -> String:
	var paid: Array[String] = []
	var risks: Array[String] = []
	for row: Dictionary in rows(catalog, content, variant, "always"):
		if row.operation == "delta" and row.field == "sanity" and amount(catalog, row) < 0: paid.append(effect_text(catalog, row, variant))
	for row: Dictionary in rows(catalog, content, variant, "success"):
		if (row.operation == "record" and row.field in SUCCESS_WARNINGS) or row.operation == "vacate" or (row.operation == "withdraw" and row.field == "support") or (row.operation == "learn" and row.subject == "rival"):
			risks.append(effect_text(catalog, row, variant))
	var result: Array[String] = []
	if not paid.is_empty(): result.append("必付：" + "；".join(paid))
	if not risks.is_empty(): result.append("成功也会：" + "；".join(risks))
	return "\n".join(result)

func effect_text(catalog: RefCounted, row: Dictionary, variant: String, deep_success: bool = false, success_range: bool = false) -> String:
	var subject: String = str(SUBJECTS.get(str(row.subject), ""))
	if row.subject == "memory_people": subject = "首位记忆持有人" if variant == "shallow" else "各位记忆持有人"
	var result: String = ""
	match str(row.operation):
		"delta":
			var value: int = amount(catalog, row, deep_success)
			if row.field == "sanity_loss": value = -value
			var quantity: String = str(absi(value))
			if success_range and row.stage == "success" and row.scale == "count":
				var greater: int = absi(amount(catalog, row, true))
				if greater != absi(value): quantity += "–" + str(greater)
			if row.field == "followers": result = "当地新增至多 %s 名信众" % quantity
			elif ATTRIBUTES.has(row.field): result = subject + str(ATTRIBUTES[row.field]) + (" +" if value >= 0 else " −") + quantity
		"set_min": result = subject + str(ATTRIBUTES.get(row.field, "")) + "至少 " + str(amount(catalog, row))
		"record": result = subject + str(RECORDS.get(row.field, "")) if RECORDS.has(row.field) else ""
		"cure": result = subject + "脱离此次病危"
		"fulfill": result = subject + "的本次契约义务完成"
		"learn":
			var knowledge: String = {"testimony": "这份秘密证言", "record": "同一异常事实", "contract": "此次契约", "relation": "原有关系事实", "relic_holder": "圣物当前持有机构", "exception": "这份法则例外"}.get(str(row.field), "")
			if not knowledge.is_empty(): result = subject + "获知" + knowledge
		"withdraw": result = {"pursuit_clue": "撤销此次追查线索", "pursuit_relation": "切断此次追查关系", "support": "所在机构失去求告者的支持"}.get(str(row.field), "")
		"restrict":
			var duration: String = "本轮" if row.value == "current_turn" else "本轮及之后 %d 轮" % int(row.value)
			result = subject + duration + ("不能参与传播" if row.field == "spread" else "不能被任命")
		"conceal": result = subject + "隐匿至本轮之后第 %d 轮结束" % amount(catalog, row)
		"vacate": result = subject + "原有职位空缺"
		"memory": result = subject + "保留这段记忆的见证资格"
		"enroll": result = subject + "成为具名信徒"
		"route": result = subject + "取得此次逃离路线"
		"recovery":
			var event: Dictionary = catalog.display_tables.events.get(str(row.value), {})
			result = "出现争夺原圣物的机会（本轮后第 %s–%s 轮）" % [event.get("min_age", ""), event.get("max_age", "")]
		"callback": return "" # A pending candidate is not a guaranteed future event.
	if result.is_empty(): return ""
	if row.condition == "subject_alive": result = "若" + subject + "仍存活，" + result
	elif row.condition == "knows_disclosure": result = "若争端另一方已知晓该披露，" + result
	return result
