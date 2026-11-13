extends Node
## Opt-in study on the actual production tree. No Session or input-flow changes.
const Pigment = preload("res://tools/palette-study/pigment.gdshader")
const WorldCard = preload("res://src/presentation/production/painted/world_card.gd")
const StudyCard = preload("res://src/presentation/production/worldplay/study_card.gd")
const Glyph = preload("res://src/presentation/production/worldplay/card_illustration.gd")
const Fan = preload("res://src/presentation/production/painted/card_fan.gd")
const Finish = preload("res://tools/palette-study/card_finish.gd")
const ImageEdge = preload("res://tools/palette-study/image_edge.gdshader")
const TITLES := ["0 原版", "1 厚纸套印"]
const CATEGORY := {
	"world": Color("#8a493d"),
	"event": Color("#a34e3c"), "prayer": Color("#99465f"),
	"cult": Color("#317f70"), "power": Color("#43659e"),
	"activity": Color("#a17b32"), "person": Color("#a05c43"),
	"anchor": Color("#347d8a"), "action": Color("#8c6036"),
	"relic": Color("#6d5588"),
}
var choice := 0
var scope: Node
var _materials: Array[ShaderMaterial] = []
var _pending: Array[Node] = []
var _badge: Label
var _stocks: Array[Dictionary] = []

func start(root_node: Node) -> void:
	scope = root_node
	_scan(scope)
	get_tree().node_added.connect(_added)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_badge = Label.new()
	_badge.position = Vector2(39, 8)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_override("font", preload("res://src/presentation/production/painted/theme.gd").fonts().body)
	_badge.add_theme_font_size_override("font_size", 12)
	_badge.add_theme_color_override("font_color", Color("#a6adb2"))
	layer.add_child(_badge)
	select(0)

func select(index: int) -> void:
	choice = clampi(index,0,1)
	for paint: ShaderMaterial in _materials: paint.set_shader_parameter("palette",choice)
	for entry: Dictionary in _stocks:
		if is_instance_valid(entry.get("finish")): entry.finish.visible = choice != 0
	if is_instance_valid(_badge):
		_badge.text = "配色对照 · %s     0 原版 / 1 厚纸套印 · H 隐藏提示 · 独立存档副本" % TITLES[choice]
	get_tree().root.title = "邪神苏醒 · 配色对照 · " + TITLES[choice]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode >= KEY_0 and event.keycode <= KEY_1:
		select(event.keycode-KEY_0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_H:
		_badge.visible = not _badge.visible
		get_viewport().set_input_as_handled()

func _added(node: Node) -> void:
	if scope == null: return
	# Godot's built-in tooltip lives in a subwindow outside OverlayRoot.
	var tooltip: bool = node is Control and node.get_window() is PopupPanel
	if not scope.is_ancestor_of(node) and not tooltip: return
	_pending.append(node)
	if _pending.size() == 1: _flush.call_deferred()

func _flush() -> void:
	var pending := _pending.duplicate()
	_pending.clear()
	for node: Node in pending:
		if is_instance_valid(node): _apply(node)

func _scan(node: Node) -> void:
	_apply(node)
	for child: Node in node.get_children(): _scan(child)

func _process(_delta: float) -> void:
	for entry: Dictionary in _stocks:
		var card: Control = entry.card
		var fan: Node = card.get_parent()
		var depth := 0.0
		if fan is Fan and fan.is_stacked(): depth = absf(float(fan.cards.find(card))-fan._visual_focus)
		var light: float = card._hover.light()
		if not is_equal_approx(entry.depth,depth):
			entry.paint.set_shader_parameter("stack_depth",depth)
			entry.depth = depth
		if not is_equal_approx(entry.light,light):
			entry.paint.set_shader_parameter("hover_light",light)
			entry.light = light
		if is_instance_valid(entry.get("finish")):
			entry.finish.set_emphasis(card._hover.amount,card.get_meta("fan_focused",false) or (card.selected if card is StudyCard else false))

func _apply(node: Node) -> void:
	if not node is CanvasItem or node.has_meta("palette_study"): return
	if node.material is ShaderMaterial:
		# Organic motion stays verbatim. Portraits only get a narrower alpha rim.
		if node.material.shader.resource_path.ends_with("object_window.gdshader"):
			_finish_image(node)
		return
	var role := -1
	if node is WorldCard or node is StudyCard: role = 1
	elif node is Glyph: role = 3
	elif node is Label or node is Button or node is LineEdit or node is PanelContainer or node is Panel or node is ColorRect or node is ProgressBar: role = 0
	if role < 0: return
	var paint := ShaderMaterial.new()
	paint.shader = Pigment
	paint.set_shader_parameter("role",role)
	paint.set_shader_parameter("palette",choice)
	if node is Control:
		paint.set_shader_parameter("extent",node.size)
		node.resized.connect(func(): paint.set_shader_parameter("extent",node.size))
	var ancestor: Node = node
	while ancestor != null and ancestor != scope:
		if ancestor is WorldCard or ancestor is StudyCard:
			paint.set_shader_parameter("on_card",true)
			var kind: String = ancestor.palette if ancestor is StudyCard else "world"
			paint.set_shader_parameter("category",_colour(kind))
			var layout := _layout(ancestor)
			paint.set_shader_parameter("reading_start",layout.x)
			paint.set_shader_parameter("reading_end",layout.y)
			if node is Label:
				var center: Vector2 = ancestor.get_global_transform().affine_inverse() * node.get_global_transform() * (node.size*.5)
				var is_spine: bool = node.get_parent().name in ["LeftSpine","RightSpine"]
				paint.set_shader_parameter("paper_text",not is_spine and center.y/ancestor.size.y >= layout.x and center.y/ancestor.size.y <= layout.y)
			break
		ancestor = ancestor.get_parent()
	if node is StudyCard:
		paint.set_shader_parameter("original_tint",node.stock_tint())
		paint.set_shader_parameter("category",_colour(node.palette))
	elif node is ColorRect and node.name == "Ink" and node.get_parent().get_parent() is StudyCard:
		var card: Control = node.get_parent().get_parent()
		paint.set_shader_parameter("role",1)
		paint.set_shader_parameter("original_tint",card.stock_tint())
		paint.set_shader_parameter("category",_colour(card.palette))
		paint.set_shader_parameter("spine",true)
	node.material = paint
	node.set_meta("palette_study",true)
	_materials.append(paint)
	if node is WorldCard or node is StudyCard:
		paint.set_shader_parameter("stock_seed",float(node.seed_value if node is StudyCard else node.ordinal))
		var entry := {"card":node,"paint":paint,"depth":-1.0,"light":-1.0,"finish":null}
		_stocks.append(entry)
		node.tree_exiting.connect(func(): _stocks.erase(entry),CONNECT_ONE_SHOT)
		_attach_finish.call_deferred(entry)
	# Resources retire with their controls; no growing list across scene changes.
	node.tree_exiting.connect(func(): _materials.erase(paint),CONNECT_ONE_SHOT)

func _layout(card: Control) -> Vector2:
	if card is WorldCard: return Vector2(0.715,0.985)
	if card.name == "MasterCard": return Vector2(0.603,0.985)
	if str(card.name).begins_with("Choice_"):
		return Vector2(0.045,0.68) if card.palette == "prayer" else Vector2(0.60,0.985)
	return Vector2(0.625,0.985)

func _colour(kind: String) -> Color:
	var pigment: Color = CATEGORY.get(kind,CATEGORY.world)
	var value := pigment.r*.2126+pigment.g*.7152+pigment.b*.0722
	return Color(value,value,value).lerp(pigment,.88)

func _finish_image(node: TextureRect) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = ImageEdge
	paint.set_shader_parameter("palette",choice)
	var update := func(): paint.set_shader_parameter("image_extent",Vector2.ONE*minf(node.size.x,node.size.y))
	update.call()
	node.resized.connect(update)
	node.material = paint
	node.set_meta("palette_study",true)
	_materials.append(paint)
	node.tree_exiting.connect(func(): _materials.erase(paint),CONNECT_ONE_SHOT)

func _attach_finish(entry: Dictionary) -> void:
	if not is_instance_valid(entry.card) or not entry.card.is_inside_tree(): return
	var card: Control = entry.card
	var finish := Finish.new()
	finish.name = "PrintedFinish"
	card.add_child(finish)
	card.move_child(finish,0)
	entry.finish = finish
	finish.visible = choice != 0
	_configure_finish(card,finish)
	card.resized.connect(_configure_finish.bind(card,finish))

func _configure_finish(card: Control,finish: Control) -> void:
	var layout := _layout(card)
	var kind := "world" if card is WorldCard else str(card.palette)
	var carrier := "world" if card is WorldCard else ("master" if card.name == "MasterCard" else "hand")
	if str(card.name).begins_with("Choice_"): carrier = "choice_prayer" if card.palette == "prayer" else "choice_object"
	finish.setup(card.size,layout.x,layout.y,_colour(kind),carrier,card.seed_value if card is StudyCard else card.ordinal)
	var art_box := Rect2()
	for child: Node in card.get_children():
		if child is TextureRect and child.material is ShaderMaterial and child.material.shader in [ImageEdge,preload("res://src/presentation/production/painted/object_window.gdshader")]:
			var side: float = minf(child.size.x,child.size.y)
			art_box = Rect2(child.position+(child.size-Vector2.ONE*side)*.5,Vector2.ONE*side)
		elif child is Glyph: art_box = Rect2(child.position,child.size)
	finish.set_art_bounds(art_box)
	var protected: Array[Rect2] = []
	for label: Label in card.find_children("*","Label",true,false):
		if label.text.is_empty(): continue
		var font: Font = label.get_theme_font("font")
		var px: int = label.get_theme_font_size("font_size")
		var lines := maxi(1,label.get_line_count())
		if label.max_lines_visible>0: lines = mini(lines,label.max_lines_visible)
		var ink_size := Vector2(minf(label.size.x,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x),minf(label.size.y,font.get_height(px)*lines))
		if lines>1: ink_size.x = label.size.x
		var offset := Vector2.ZERO
		if label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER: offset.y = (label.size.y-ink_size.y)*.5
		if label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER: offset.x = (label.size.x-ink_size.x)*.5
		elif label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT: offset.x = label.size.x-ink_size.x
		var transform := card.get_global_transform().affine_inverse()*label.get_global_transform()
		protected.append((transform*Rect2(offset,ink_size)).grow(1.0))
	finish.set_protected_rects(protected)
