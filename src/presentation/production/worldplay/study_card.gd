extends Button
## One painted stock and hover motion for the hand, the table and choice cards.
const Paint = preload("res://src/presentation/production/painted/theme.gd")
const Hover = preload("res://src/presentation/production/painted/card_hover.gd")
const Carrier = preload("res://src/presentation/production/painted/card_carrier/card.gd")
const FieldText = preload("res://src/presentation/production/painted/card_fields.gd")
const CARRIER_STOCK = preload("res://assets/ui/cards/continuous-stock.png")
const STOCK := {
	"event": Color(1.82, 0.89, 0.83),  # 砖赭
	"prayer": Color(1.38, 0.89, 1.53), # 灰藤紫
	"cult": Color(0.92, 1.30, 0.87),   # 苔绿
	"power": Color(0.82, 1.02, 1.59),  # 靛蓝
	"activity": Color(1.62, 1.20, 0.67), # 烟金
	"person": Color(1.48, 1.17, 1.00), # 暖灰
	"anchor": Color(0.68, 1.29, 1.35), # 铜青
	"action": Color(1.43, 1.00, 0.71), # 深褐
	"relic": Color(1.09, 1.14, 1.44),  # 铅灰
}
var seed_value := 0
var palette := ""
var selected := false:
	set(value):
		selected = value
		if is_instance_valid(carrier): carrier.set_selected(value)
		queue_redraw()
var payload: Dictionary = {}
var tooltip_parts: Array = []
var hover_enabled := true
var _hover := Hover.new()
var _stock: StyleBoxTexture
var carrier: Control
static var _paper_backings: Dictionary = {}
var _backing_key := ""

func _make_custom_tooltip(for_text: String) -> Object:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 390
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := FieldText.line(box,tooltip_parts if not tooltip_parts.is_empty() else [for_text],14)
	# Tooltip sizing happens before the container's first layout. Give the rich
	# text its wrapping width now, so its initial height isn't one word per line.
	words.custom_minimum_size.x = 390
	words.size.x = 390
	return box

## The Button retains gameplay input; the carrier owns the continuous print.
## Every physical card uses this carrier; empty slots omit its category/copy.
func configure_carrier(sample: Dictionary, artwork: Texture2D = null, options: Dictionary = {}) -> TextureRect:
	carrier = Carrier.new()
	carrier.name = "PrintedFace"
	carrier.configure(sample, CARRIER_STOCK, artwork, size, options)
	carrier.payload = payload
	add_child(carrier)
	carrier.set_selected(selected)
	queue_redraw()
	return carrier.art

func adapt_portrait_backing(art_key: String, style_sid: int) -> void:
	# Engraving and watercolor have a paper ground by definition. Pulp can
	# instead contain a dark or saturated sky, so only that style is sampled.
	if style_sid != 7 or art_key.is_empty(): return
	_backing_key = art_key
	set_process(true)
	_process(0.0)

func _process(_delta: float) -> void:
	if _backing_key.is_empty() or not is_instance_valid(carrier):
		set_process(false)
		return
	var image_slot: TextureRect = carrier.art
	if image_slot.texture == null: return
	if not _paper_backings.has(_backing_key):
		# Read once per actual portrait, never on hover and never modify pixels.
		# Multiple neutral outer samples classify the underpainting only; this
		# value is never an input to the picture's RGB or alpha shader.
		var image := image_slot.texture.get_image()
		var pale := 0
		var count := 0
		if image != null and not image.is_empty():
			for x: float in [0.04, 0.07, 0.93, 0.96]:
				for y: float in [0.25, 0.50, 0.75, 0.85, 0.90]:
					var pixel := image.get_pixel(clampi(int(x * image.get_width()),0,image.get_width()-1),clampi(int(y * image.get_height()),0,image.get_height()-1))
					count += 1
					if pixel.a > 0.9 and minf(pixel.r,minf(pixel.g,pixel.b)) > 0.60 and pixel.s < 0.28: pale += 1
		_paper_backings[_backing_key] = count > 0 and pale >= ceili(count * 0.6)
	carrier.set_artwork(image_slot.texture, bool(_paper_backings[_backing_key]))
	_backing_key = ""
	set_process(false)

func set_exposure(side: int, exposed: float) -> void:
	if is_instance_valid(carrier): carrier.set_exposure(side, exposed)

func set_peek_amount(value: float) -> void:
	if is_instance_valid(carrier): carrier.set_peek_amount(value)

func make_drag_preview() -> Control:
	if is_instance_valid(carrier): return carrier.make_drag_preview()
	var preview := duplicate() as Control
	preview.hover_enabled = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview

func _ready() -> void:
	text = ""
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_stock = StyleBoxTexture.new()
	_stock.texture = Paint.card_stock(seed_value)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_stock.set_texture_margin(side, 9)
	mouse_entered.connect(set_card_hover.bind(true))
	mouse_exited.connect(set_card_hover.bind(false))
	focus_entered.connect(_update_focus)
	focus_exited.connect(_update_focus)
	resized.connect(apply_card_hover)
	pivot_offset = size * Vector2(0.5, 0.70)

func _update_focus() -> void:
	if is_instance_valid(carrier):
		carrier.set_meta("keyboard_focus", has_focus())
		carrier.set_selected(selected)
	queue_redraw()

func apply_card_hover() -> void:
	if hover_enabled: _hover.apply_transform(self)
	if is_instance_valid(carrier): carrier.set_peek_amount(clampf(_hover.amount, 0.0, 1.0))
	queue_redraw()

func set_card_hover(value: bool) -> void:
	_hover.set_hover(self, value and hover_enabled, apply_card_hover)

func stock_tint() -> Color:
	return STOCK.get(palette, Color(0.87, 0.94, 0.87))

func _get_drag_data(_at_position: Vector2) -> Variant:
	if payload.is_empty(): return null
	var preview := make_drag_preview()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ratio := minf(1.0, 230.0 / size.y)
	preview.scale = Vector2.ONE * ratio
	preview.position = -size * 0.5
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"worldplay_card": payload}

func _draw() -> void:
	if is_instance_valid(carrier): return
	if _stock == null: return
	_stock.modulate_color = stock_tint() * _hover.light()
	_stock.modulate_color.a = 1.0
	_stock.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if not (selected or has_focus() or get_meta("fan_focused", false)): return
	# Short dry-brush impressions follow the chip in the stock, leaving the
	# reading area and the full side of the card quiet.
	var ink := Color(Paint.ACCENT * stock_tint().lerp(Color.WHITE, 0.68), 0.70)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16,5), Vector2(19,3), Vector2(40,3), Vector2(42,4),
		Vector2(55,4), Vector2(62,6), Vector2(48,7), Vector2(25,7), Vector2(24,6),
	]), ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5,26), Vector2(7,21), Vector2(7,33), Vector2(8,36),
		Vector2(7,47), Vector2(5,51), Vector2(5,40), Vector2(4,37),
	]), Color(ink, 0.51))
	var heel := size - Vector2(12,6)
	draw_colored_polygon(PackedVector2Array([
		heel + Vector2(-34,1), heel + Vector2(-27,-2), heel + Vector2(-12,-2),
		heel + Vector2(-11,-3), heel, heel + Vector2(-5,1), heel + Vector2(-22,2),
	]), Color(ink, 0.54))
