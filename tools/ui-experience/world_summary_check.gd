extends SceneTree
## Real Session navigation plus explicit late-game knowledge fixtures.
## Fixture values are presentation contracts, not generated campaign/balance evidence.
const Experience = preload("res://src/presentation/experience_root.tscn")
const Session = preload("res://src/presentation/session.gd")
var checks: Array[String] = []
var app

func _initialize() -> void:
	_run.call_deferred()

func need(condition: bool, description: String) -> bool:
	if not condition:
		push_error("WORLD_SUMMARY: " + description)
		quit(1)
		return false
	checks.append(description)
	return true

func text_of(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += text_of(child)
	return result

func capture(name_value: String) -> bool:
	if not "--capture" in OS.get_cmdline_user_args(): return true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return need(root.get_texture().get_image().save_png("res://.godot/world-summary-" + name_value + ".png") == OK, "保存原生截图 " + name_value)

func _run() -> void:
	app = Experience.instantiate()
	app.session = Session.new("res://.godot/world-summary-campaigns")
	root.add_child(app)
	await process_frame
	app.start_new(1)
	if app.projection.phase == "events":
		app.close_modal()
		app._advance(false)
	if not need(app.projection.phase == "actions" and not app.projection.prayers.is_empty(), "真实新局可进入行动且有有效祈求"): return
	var prayer: Dictionary = app.projection.prayers[0]
	var domain: String = str(prayer.descriptor.domain)
	var state_before: String = JSON.stringify(app.session.world.state)
	app.show_subject("prayer", str(prayer.id))
	await process_frame
	await process_frame
	var summary_text: String = text_of(app._world_summary)
	if not need(app.title(domain) in summary_text and "屏障" in summary_text and "污染" in summary_text and "察觉" in summary_text and "稳定" in summary_text and "反制" in summary_text, "真实祈求同时呈现所属世界四项情报与反制"): return
	var initial_world: Dictionary = app._views._find(app, "domains", domain)
	for field: String in ["barrier", "pollution", "alert", "stability"]:
		var metric: Dictionary = initial_world.get("metric_sources", {}).get(field, {})
		if not need(metric.get("precision") == "range" and initial_world.get(field) == null, "首次知晓的 %s 是区间快照而非当前确值" % field): return
	var execute: Button = app._work_footer.find_child("ExecuteDraft", true, false)
	var summary_rect: Rect2 = app._world_summary.get_global_rect()
	var geometry: Dictionary = {"summary":str(summary_rect), "subject_scroll":str(app._subject_scroll.get_global_rect()), "execute":str(execute.get_global_rect()) if execute != null else "missing"}
	if not need(execute != null and execute.get_global_rect().end.y <= 900 and not app._subject_scroll.is_ancestor_of(app._world_summary) and summary_rect.end.y <= app._subject_scroll.get_global_rect().position.y and summary_rect.end.x <= 1600, "常驻世界摘要不随主体滚动且祈求提交仍在画布内"): return
	if not need(summary_rect.size.y <= 190 and app._subject_scroll.size.y >= 200, "行动打开时世界摘要为紧凑区域并保留主体可读高度"): return
	if not await capture("prayer"): return
	var original_draft: Dictionary = app.draft.duplicate(true)
	var context_link: Button = app._world_summary.find_child("WorldContextLink", true, false)
	context_link.pressed.emit()
	if not need(app.subject == {"kind":"world", "id":domain} and app.draft == original_draft, "从祈求世界摘要一次进入世界详情且保留回应草稿"): return
	if not await capture("world"): return
	var metric_source: String = str(initial_world.metric_sources.barrier.source)
	var original_subject: Dictionary = app.subject.duplicate(true)
	app.show_subject("fact", metric_source)
	if not need(app._modal_kind == "detail" and app.subject == original_subject and app.draft == original_draft, "情报来源使用临时详情而不增加主区深度或丢草稿"): return
	app.close_modal()
	app.back_subject()
	if not need(app.subject.kind == "home" and app.draft.is_empty() and JSON.stringify(app.session.world.state) == state_before, "一次返回总览且查看世界及来源不推进或修改模拟"): return
	if not await capture("home"): return

	# Inject only the projected view. Never write fixture values into world.state.
	var real_projection: Dictionary = app.projection.duplicate(true)
	var fixture: Dictionary = real_projection.duplicate(true)
	fixture.turn = 46
	fixture.domains = [
		{"id":"DOMAIN-UI-A", "title":"遥远灰塔", "tier":"planet", "focused":false, "barrier":28, "pollution":null, "alert":null, "stability":null, "metric_sources":{
			"barrier":{"value":28, "source":metric_source, "turn":45},
			"pollution":{"precision":"range", "lower":50, "upper":74, "source":metric_source, "turn":45},
			"stability":{"precision":"range", "lower":75, "upper":100, "source":metric_source, "turn":44}}},
		{"id":"DOMAIN-UI-B", "title":"无声海岸", "focused":true, "barrier":null, "pollution":null, "alert":null, "stability":null, "metric_sources":{}},
		{"id":"DOMAIN-UI-C", "title":"第三世界", "focused":false},
		{"id":"DOMAIN-UI-D", "title":"第四世界", "focused":false},
		{"id":"DOMAIN-UI-E", "title":"第五世界", "focused":false}
	]
	fixture.people = [{"id":"NPC-UI-A", "title":"灰塔求告者", "domain":"DOMAIN-UI-A"}, {"id":"NPC-UI-B", "title":"海岸求告者", "domain":"DOMAIN-UI-B"}]
	fixture.cults = [{"id":"CULT/UI-A", "domain":"DOMAIN-UI-A", "leader":"NPC-UI-A"}]
	fixture.relics = [{"id":"RELIC/UI-A", "domain":"DOMAIN-UI-A"}]
	fixture.institutions = [{"id":"INSTITUTION-UI-A", "title":"灰塔守望者", "domain":"DOMAIN-UI-A"}]
	fixture.anchors = [{"id":"ANCHOR/UI-A", "domain":"DOMAIN-UI-A", "institution":"INSTITUTION-UI-A", "state":"active"}]
	fixture.prayers = [{"id":"PRAYER-UI-A", "descriptor":{"domain":"DOMAIN-UI-A"}}]
	fixture.resistance = [
		{"id":"PLAN-UI-LATER", "domain":"DOMAIN-UI-A", "target":"RELIC/UI-A", "rule":"RESIST_SEIZE", "due":49},
		{"id":"PLAN-UI-NEXT", "domain":"DOMAIN-UI-A", "target":"CULT/UI-A", "rule":"RESIST_PURGE", "due":47}
	]
	app.projection = fixture
	var fixture_before: Dictionary = fixture.duplicate(true)
	app.draft = {}
	for entry: Array in [["world", "DOMAIN-UI-A"], ["person", "NPC-UI-A"], ["cult", "CULT/UI-A"], ["members", "CULT/UI-A"], ["prayer", "PRAYER-UI-A"], ["relic", "RELIC/UI-A"], ["anchor", "ANCHOR/UI-A"], ["institution", "INSTITUTION-UI-A"], ["history", "NPC-UI-A"]]:
		app.subject = {"kind":entry[0], "id":entry[1]}
		app._render_world_summary()
		if not need("遥远灰塔" in text_of(app._world_summary) and app.context_selection().get("domain") == "DOMAIN-UI-A", "%s 上下文以投影身份解析正确所属世界" % entry[0]): return
	summary_text = text_of(app._world_summary)
	if not need("屏障 28（第45轮确知）" in summary_text and "污染 50–74（第45轮估计）" in summary_text and "察觉 未掌握" in summary_text and not "第46轮" in summary_text, "混合确知区间未知保留各自观测回合而不伪装当前读数"): return
	if not need(app._views.metric_text({"pollution":99}, "pollution") == "未掌握", "缺少知情记录的总值不能被当成确知情报显示"): return
	if not need("清洗教团" in summary_text and "第47轮到期" in summary_text and "另 1 项" in summary_text and not "第49轮到期" in summary_text, "固定摘要显示最近反制目标及期限并告知其余计划数量"): return
	app.subject = {"kind":"person", "id":"NPC-UI-B"}
	app._render_world_summary()
	if not need("无声海岸" in text_of(app._world_summary) and not "遥远灰塔" in text_of(app._world_summary) and not "清洗教团" in text_of(app._world_summary), "切换世界对象时旧世界数值与反制不会残留"): return
	app.subject = {"kind":"worlds", "id":""}
	app._render_world_summary()
	if not need(app._world_summary.get_child_count() == 0, "全局索引在无行动时不会残留上个对象世界"): return
	app.draft = {"selection":{"domain":"DOMAIN-UI-B"}}
	app._render_world_summary()
	if not need("无声海岸" in text_of(app._world_summary), "全局页面的当前行动所属世界提供明确上下文"): return
	app.subject = {"kind":"person", "id":"NPC-UI-A"}
	app._render_world_summary()
	if not need(app._world_summary.find_child("ActionWorldContext", true, false) != null and "当前行动另指向 · 无声海岸" in text_of(app._world_summary), "查看世界与行动世界不同时明确区分而不混写状态"): return

	var box := VBoxContainer.new()
	app._views._world_overview(app, box)
	var overview: Array = box.get_children().filter(func(node: Node) -> bool: return node is Button)
	if not need(overview.size() == 3 and overview[0].name == "WorldOverview_DOMAIN-UI-A" and overview[1].name == "WorldOverview_DOMAIN-UI-B" and "3 / 5" in text_of(box), "多世界总览优先临近反制其次关注并将常驻条目限制为三项"): return
	box.free(); box = VBoxContainer.new()
	app._views.queries.worlds = "无声海岸"
	app._views._worlds(app, box)
	if not need("匹配 1 / 5" in text_of(box) and "无声海岸" in text_of(box) and not "遥远灰塔" in text_of(box), "世界索引按名字检索且展示未知状态不补值"): return
	box.free(); box = VBoxContainer.new()
	app._views.queries.worlds = ""
	app._views.world_filter = "有反制"
	app._views._worlds(app, box)
	if not need("匹配 1 / 5" in text_of(box) and "遥远灰塔" in text_of(box) and not "无声海岸" in text_of(box), "反制筛选依据实际已知计划而非察觉数值"): return
	box.free(); box = VBoxContainer.new()
	app._views._world(app, box, "DOMAIN-UI-A")
	var detail: String = text_of(box)
	var consequence: String = app.session.catalog.tables.resistance_plans.RESIST_PURGE.result
	if not need("察觉　未掌握" in detail and "区间表示精度" in detail and "若未阻止：" + consequence in detail and detail.find("已发动的反制") < detail.find("锚点与持续护持") and not "PLAN-UI-NEXT" in detail and not "required_target" in detail, "世界详情前置独立语义与计划后果且不倾倒底层计划字典"): return
	var source_links: Array = box.get_children().filter(func(node: Node) -> bool: return node is Button and "情报来源" in node.text)
	if not need(source_links.size() == 1 and "屏障 / 污染 / 稳定" in source_links[0].text and detail.find("已发动的反制") < detail.find("屏障　"), "相同情报事实只保留一个来源入口且反制先于详细指标说明"): return
	if not need(app.projection == fixture_before and JSON.stringify(app.session.world.state) == state_before, "所有投影夹具查看均不改变投影或真实模拟"): return
	box.free()
	app.projection = real_projection
	app.draft = {}
	app._views.queries.clear()
	app._views.world_filter = "全部"
	app.show_subject("home")
	await process_frame
	var report := FileAccess.open("res://.godot/world-summary-checks.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok":true, "checks":checks, "scope":"real-session navigation plus explicit late-game presentation fixtures", "geometry":geometry}, "\t"))
	report.close()
	print("WORLD_SUMMARY_OK ", checks.size(), " checks")
	app.queue_free()
	await process_frame
	quit(0)
