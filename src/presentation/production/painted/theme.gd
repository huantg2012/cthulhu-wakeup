extends RefCounted
## Palette and native control styles shared by the formal presentation.
const MaterialSource = preload("res://docs/art/visual-generation/ui-study/painted_material.gd")
const TITLE_FACE := MaterialSource.FONT_PATH
const BODY_FACE := MaterialSource.BODY_PATH
const INK := MaterialSource.INK
const BONE := MaterialSource.BONE
const MUTED := MaterialSource.MUTED
const ACCENT := Color("#b1c09b")
const HOVER := Color("#eee8cc")
const WARM := Color("#d8bc85")
const RISK := Color("#d5a28d")
const UNKNOWN := Color("#afa9c6")
const LINE := Color("#4b5549")
const FIELD := Color("#192421")
const READING := Color("#141d1c")

enum Role { NAVIGATION, RESPONSIBILITY, PRIMARY }
static var _styles: Dictionary = {}
static var _fonts: Dictionary = {}

static func prime_card_stock() -> void:
	# Share the four original world-card substrates. Object identity belongs
	# to the illustration, not another 100,000 CPU-painted stock pixels.
	for seed_value: int in range(31, 35):
		MaterialSource.pigment("card", seed_value)

static func card_stock(seed_value: int) -> Texture2D:
	return MaterialSource.pigment("card", 31 + posmod(seed_value - 31, 4))

static func fonts() -> Dictionary:
	if _fonts.is_empty():
		var body := _font_file(BODY_FACE)
		var title := _font_file(TITLE_FACE)
		for font: FontFile in [title, body]:
			font.multichannel_signed_distance_field = false
			font.allow_system_fallback = false
		body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		body.hinting = TextServer.HINTING_LIGHT
		body.oversampling = 2.0
		title.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		title.hinting = TextServer.HINTING_NONE
		title.oversampling = 1.0
		title.fallbacks = [body]
		_fonts = {"body": body, "heading": title}
	return _fonts

static func _font_file(path: String) -> FontFile:
	# Source launches need no editor import. Exported packs carry the imported font.
	if ResourceLoader.exists(path, "FontFile"):
		var imported := load(path) as FontFile
		if imported != null: return imported.duplicate()
	var raw := FontFile.new()
	raw.data = FileAccess.get_file_as_bytes(path)
	return raw

static func native_theme() -> Theme:
	var base := Theme.new()
	base.default_font = fonts().body
	base.default_font_size = 14
	base.set_color("font_color", "Label", BONE)
	base.set_stylebox("separator", "HSeparator", StyleBoxEmpty.new())
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 4
	base.set_stylebox("scroll", "VScrollBar", track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color(ACCENT, 0.32 if state == "grabber" else 0.68)
		grip.content_margin_left = 4
		base.set_stylebox(state, "VScrollBar", grip)
	base.set_stylebox("panel", "TooltipPanel", reading_plate(1.0))
	base.set_color("font_color", "TooltipLabel", BONE)
	for state: String in ["normal", "focus", "read_only"]:
		base.set_stylebox(state, "LineEdit", field_style(state))
	base.set_color("font_color", "LineEdit", BONE)
	base.set_color("font_placeholder_color", "LineEdit", MUTED)
	base.set_color("font_uneditable_color", "LineEdit", MUTED)
	base.set_color("caret_color", "LineEdit", ACCENT)
	base.set_color("selection_color", "LineEdit", LINE)
	return base

static func button_style(state: String, role: Role, selected := false) -> StyleBox:
	var key := [state, role, selected]
	if _styles.has(key): return _styles[key]
	var opacity: float = [0.16, 0.38, 0.88][role]
	match state:
		"hover", "focus": opacity = 0.93 if role == Role.PRIMARY else 0.66
		"pressed", "hover_pressed": opacity = 1.0
		"disabled": opacity = 0.10
	if selected and state == "normal": opacity = maxf(opacity, 0.52)
	var box := _paint_box(opacity)
	if state == "pressed": box.modulate_color = Color(0.8, 0.88, 0.8, opacity)
	if state == "focus" or selected:
		box.texture = _marked_texture()
		box.modulate_color.a = maxf(opacity, 0.62) if state != "disabled" else 0.24
	_styles[key] = box
	return box

static func _marked_texture() -> Texture2D:
	const KEY := "marked-button"
	if not _styles.has(KEY):
		var bitmap := MaterialSource.pigment("button").get_image()
		for y in range(7, bitmap.get_height() - 7):
			for x in range(3, 5 + (1 if y % 7 == 0 else 0)):
				var base := bitmap.get_pixel(x, y)
				if base.a > 0.0: bitmap.set_pixel(x, y, ACCENT.lerp(base, 0.22))
		_styles[KEY] = ImageTexture.create_from_image(bitmap)
	return _styles[KEY]

static func _paint_box(opacity: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = MaterialSource.pigment("button")
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 5)
		box.set_content_margin(side, 9 if side in [SIDE_LEFT, SIDE_RIGHT] else 2)
	box.modulate_color = Color(1, 1, 1, opacity)
	return box

static func reading_plate(opacity: float) -> StyleBoxTexture:
	var key := ["reading", opacity]
	if not _styles.has(key):
		var box := StyleBoxTexture.new()
		box.texture = _reading_stock()
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, 10)
			box.set_content_margin(side, 9 if side in [SIDE_LEFT, SIDE_RIGHT] else 2)
		box.modulate_color.a = opacity
		_styles[key] = box
	return _styles[key]

static func _reading_stock() -> Texture2D:
	const KEY := "reading-stock"
	if _styles.has(KEY): return _styles[KEY]
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var field := MaterialSource.noise(71, 0.055)
	for y: int in 96:
		for x: int in 96:
			var edge := minf(minf(x, 95 - x), minf(y, 95 - y))
			var drag := field.get_noise_2d(float(x) * 0.52, float(y) * 1.35)
			if edge < 2.0 + drag * 1.9: continue
			var ink := READING.lerp(FIELD, 0.22 + drag * 0.12)
			if edge < 4.0 + drag: ink = ink.lerp(LINE, 0.28 + drag * 0.12)
			image.set_pixel(x, y, ink)
	_styles[KEY] = ImageTexture.create_from_image(image)
	return _styles[KEY]

static func field_style(state: String) -> StyleBox:
	if state == "focus": return button_style("focus", Role.RESPONSIBILITY)
	return reading_plate(0.92 if state == "normal" else 0.65)

static func action_slot_style(state: String, filled: bool) -> StyleBoxTexture:
	if not filled: return reading_plate(0.78 if state == "normal" else 1.0)
	var key := ["action-slot", state]
	if not _styles.has(key):
		var stock := _paint_box(0.88 if state == "normal" else 1.0)
		stock.modulate_color = Color(0.85, 1.01, 0.82, stock.modulate_color.a)
		_styles[key] = stock
	return _styles[key]
