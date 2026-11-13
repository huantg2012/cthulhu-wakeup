extends Node
## Two complete card composition studies on the unchanged production scene.
const Surface = preload("res://tools/card-design-study/surface.gdshader")
const Symbol = preload("res://tools/card-design-study/symbol.gd")
const WorldCard = preload("res://src/presentation/production/painted/world_card.gd")
const StudyCard = preload("res://src/presentation/production/worldplay/study_card.gd")
const Glyph = preload("res://src/presentation/production/worldplay/card_illustration.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const TITLES := ["A · 浸墨拓片", "B · 窥界裂印"]
const COLOURS := {"world":"#8a493d", "event":"#a34e3c", "prayer":"#99465f",
 "cult":"#317f70", "power":"#43659e", "activity":"#a17b32", "person":"#a05c43",
 "anchor":"#347d8a", "action":"#8c6036", "relic":"#6d5588"}
var choice := 1
var scope: Node
var badge: Label
var _cards: Array[Dictionary] = []
var _pending: Array[Node] = []

func start(node: Node) -> void:
	scope = node
	scan(scope)
	get_tree().node_added.connect(_added)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	badge = Label.new()
	badge.position = Vector2(40,8)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_override("font",Paint.fonts().body)
	badge.add_theme_font_size_override("font_size",12)
	badge.add_theme_color_override("font_color",Color("#d6cfb8"))
	canvas.add_child(badge)
	select(1)

func select(value: int) -> void:
	choice = clampi(value,1,2)
	for entry: Dictionary in _cards:
		entry.material.set_shader_parameter("design",choice)
	if badge != null: badge.text = "卡面设计图 · %s    1 / 2 切换 · H 隐藏标记 · 存档副本" % TITLES[choice-1]
	get_tree().root.title = "邪神苏醒 · 卡面设计 · " + TITLES[choice-1]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode in [KEY_1,KEY_2]:
		select(event.keycode-KEY_0)
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_H: badge.visible = not badge.visible

func _added(node: Node) -> void:
	if scope == null or not scope.is_ancestor_of(node): return
	_pending.append(node)
	if _pending.size()==1: _flush.call_deferred()

func _flush() -> void:
	var todo := _pending.duplicate()
	_pending.clear()
	for node: Node in todo:
		if is_instance_valid(node): _apply(node)

func scan(node: Node) -> void:
	_apply(node)
	for child: Node in node.get_children(): scan(child)

func _colour(kind: String) -> Color:
	var c := Color(COLOURS.get(kind,COLOURS.world))
	var l := c.r*.2126+c.g*.7152+c.b*.0722
	return Color(l,l,l).lerp(c,.88)

func _layout(card: Control) -> float:
	if card is WorldCard: return .715
	if card.name=="MasterCard": return .603
	if str(card.name).begins_with("Choice_"): return .04 if card.palette=="prayer" else .60
	return .625

func _owner_card(node: Node) -> Control:
	while node!=null and node!=scope:
		if node is WorldCard or node is StudyCard: return node
		node = node.get_parent()
	return null

func _apply(node: Node) -> void:
	if node.has_meta("card_design"): return
	var card := _owner_card(node)
	if card==null: return
	var kind: String = card.palette if card is StudyCard else "world"
	if node==card:
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("design",choice)
		material.set_shader_parameter("category",_colour(kind))
		material.set_shader_parameter("extent",card.size)
		material.set_shader_parameter("reading_start",_layout(card))
		material.set_shader_parameter("seed_value",float(card.seed_value if card is StudyCard else card.ordinal))
		card.material = material
		card.resized.connect(func(): material.set_shader_parameter("extent",card.size))
		var entry := {"card":card,"material":material}
		_cards.append(entry)
		card.tree_exiting.connect(func(): _cards.erase(entry),CONNECT_ONE_SHOT)
	elif node is Label:
		var spine: bool = str(node.get_parent().name) in ["LeftSpine","RightSpine"]
		var p: Vector2 = card.get_global_transform().affine_inverse()*node.get_global_transform()*(node.size*.5)
		var reading: bool = not spine and p.y/card.size.y>=_layout(card)
		node.add_theme_color_override("font_color",Color("#252126") if reading else Color("#e8dec8"))
	elif node is ColorRect and node.name=="Ink" and str(node.get_parent().name) in ["LeftSpine","RightSpine"]:
		# Name is printed on the same stock. No semi-transparent rectangular patch.
		node.hide()
	elif node is Glyph:
		var motif: String = node.motif
		var seed_value: int = node.seed_value
		var side: float = minf(node.size.x,node.size.y)
		node.position += (node.size-Vector2.ONE*side)*.5
		node.size = Vector2.ONE*side
		node.set_script(Symbol)
		node.motif = motif
		node.seed_value = seed_value
		node.ink = Color("#d4c7a6")
		node.queue_redraw()
	elif node is ColorRect and node.name=="WaitingStock":
		# Empty and populated portrait states occupy the same optical field.
		node.position = Vector2(10,35)
		node.size = Vector2(240,240)
		node.color = Color("#111a1c")
	node.set_meta("card_design",true)

func _process(_delta: float) -> void:
	for entry: Dictionary in _cards:
		var card: Control = entry.card
		var parent: Node = card.get_parent()
		var depth := 0.0
		if parent is Fan and parent.is_stacked(): depth = absf(float(parent.cards.find(card))-parent._visual_focus)
		entry.material.set_shader_parameter("stack_depth",depth)
		entry.material.set_shader_parameter("hover_light",card._hover.light())
		var sides := Vector2.ZERO
		for name_value: String in ["LeftSpine","RightSpine"]:
			var spine := card.get_node_or_null(name_value) as Control
			if spine!=null and spine.visible:
				if name_value=="LeftSpine": sides.x = spine.modulate.a
				else: sides.y = spine.modulate.a
		entry.material.set_shader_parameter("spine_sides",sides)
