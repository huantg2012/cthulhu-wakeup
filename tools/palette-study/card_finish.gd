extends Control
## Printed details above the stock and below the existing art / copy.
## A02/A03/A06/A08/A10: local broken impressions, quiet reading, stable grain.
## This is a study layer; it owns no input, layout, subject data or animation.

const PAPER := Color("#e4e0cf")
const MOUNT_PAPER := Color("#dcd8cc")
const INK := Color("#29272a")

var _kind := "hand"
var _reading := Vector2(0.625, 0.985)
var _category := Color("#71564c")
var _seed_value := 0
var _art_bounds := Rect2()
var _has_art_override := false
var _protected: Array[Rect2] = []
var _has_protection_override := false
var _marks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _hover := 0.0
var _selected := false
var _configured := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 0
	show_behind_parent = false
	use_parent_material = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_rebuild)
	set_meta("palette_study", true)


func setup(card_size: Vector2, reading_start: float, reading_end: float,
		category_colour: Color, layout_kind: String, seed_value: int) -> void:
	_kind = layout_kind
	_reading = Vector2(clampf(reading_start, 0.0, 1.0), clampf(reading_end, 0.0, 1.0))
	_reading.y = maxf(_reading.x, _reading.y)
	_category = category_colour
	_seed_value = seed_value
	size = card_size
	_configured = true
	_rebuild()


## Bounds are in card-local coordinates. A plain mount sits behind the image;
## all decorative impressions remain outside its bounds.
func set_art_bounds(rect: Rect2) -> void:
	if _has_art_override and _art_bounds == rect:
		return
	_art_bounds = rect
	_has_art_override = true
	_rebuild()


## Actual Label / Button bounds may replace the conservative layout defaults.
## Each small stroke is omitted separately, allowing an imprint to disappear
## gently behind a reading area instead of leaving a large rectangular mask.
func set_protected_rects(rects: Array[Rect2]) -> void:
	_protected.assign(rects)
	_has_protection_override = true
	_rebuild()


## Existing hover / selection only changes local impressions, never geometry.
func set_emphasis(hover_amount: float, selected: bool) -> void:
	var amount := clampf(hover_amount, 0.0, 1.0)
	if is_equal_approx(amount, _hover) and selected == _selected:
		return
	_hover = amount
	_selected = selected
	queue_redraw()


func _rebuild() -> void:
	if not _configured or size.x < 32.0 or size.y < 32.0:
		return
	_marks.clear()
	_rng.seed = _seed_value
	if not _has_art_override:
		_art_bounds = _default_art()
	if not _has_protection_override:
		_protected = _default_protection()
	var unit := clampf(size.x / 180.0, 0.78, 1.18)
	var top := size.y * _reading.x
	var bottom := size.y * _reading.y
	var on_ink := Color(PAPER, 0.23)
	var on_paper := Color(_category.lerp(INK, 0.64), 0.24)
	if _art_bounds.has_area():
		_window_mount()

	# One cut at the plate's shoulder. It is deliberately not copied to the
	# other three corners, and never competes with the original focus brush.
	var shoulder := Vector2(size.x - 10.0, 7.0)
	_stroke(shoulder + Vector2(-14.0, 0.0), shoulder + Vector2(-3.0, 0.0), 1.1 * unit, on_ink, 0.22)
	_stroke(shoulder + Vector2(0.0, 3.0), shoulder + Vector2(0.0, 11.0), 1.3 * unit, on_ink, 0.22)
	_stroke(shoulder + Vector2(-9.0, 3.0), shoulder + Vector2(-5.0, 3.0), 0.8 * unit, Color(INK, 0.20))

	if _art_bounds.has_area():
		_window_impressions(unit, on_ink)

	# The plate stops before the reading stock; a small interrupted pressure
	# mark belongs to that join, without boxing in the entire text area.
	if _kind != "choice_prayer":
		var join_y := top - 2.0
		_broken_stroke(Vector2(8.0, join_y), Vector2(minf(size.x * 0.31, 61.0), join_y + 0.7),
			1.1 * unit, Color(INK, 0.24), 4)
		_stroke(Vector2(size.x - 17.0, top + 3.0), Vector2(size.x - 7.0, top + 3.0),
			0.9 * unit, Color(PAPER, 0.29))

	_paper_edge(top, bottom, unit, on_paper)
	_reading_impressions(bottom)
	_contact_impression(top, bottom, unit)
	_plate_ticks(bottom, unit, on_paper)
	queue_redraw()


func _window_mount() -> void:
	var a := _art_bounds.position
	var b := _art_bounds.end
	# The original image paints over this plain sheet. Only its alpha edge and
	# these fixed logical-pixel extensions expose the mount, never a bright
	# equal-width frame. Do not scale the two-pixel paper thickness by card size.
	_mount_rect(_art_bounds, MOUNT_PAPER)
	_mount_rect(Rect2(a.x - 0.55, a.y + 2.0, 0.55, _art_bounds.size.y - 2.0), Color(MOUNT_PAPER, 0.22))
	_mount_rect(Rect2(a.x + 2.0, a.y - 0.55, _art_bounds.size.x - 2.0, 0.55), Color(MOUNT_PAPER, 0.20))
	_mount_rect(Rect2(b.x, a.y + 1.0, 1.75, _art_bounds.size.y + 1.0), Color(MOUNT_PAPER, 0.84))
	_mount_rect(Rect2(a.x + 1.0, b.y, _art_bounds.size.x + 0.75, 2.0), Color(MOUNT_PAPER, 0.94))
	_broken_stroke(Vector2(a.x + 3.0, b.y + 2.6), Vector2(b.x + 0.5, b.y + 2.6),
		1.0, Color(INK, 0.40), 7)


func _mount_rect(rect: Rect2, colour: Color) -> void:
	var area := rect.intersection(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)))
	if not area.has_area():
		return
	_marks.append({"points": PackedVector2Array([
		area.position, Vector2(area.end.x, area.position.y), area.end,
		Vector2(area.position.x, area.end.y),
	]), "colour": colour, "emphasis": 0.0})


func _window_impressions(unit: float, colour: Color) -> void:
	var a := _art_bounds.position
	var b := _art_bounds.end
	# Two different local interventions: a short vertical registration scar
	# at the left shoulder, and a wider heel below the lower-right image edge.
	_broken_stroke(Vector2(a.x - 3.5, a.y + 9.0), Vector2(a.x - 3.5, a.y + 38.0),
		1.2 * unit, colour, 3)
	_stroke(Vector2(a.x - 3.5, a.y + 6.0), Vector2(a.x + 7.0, a.y + 6.0),
		0.9 * unit, Color(colour, 0.17))
	_stroke(Vector2(b.x + 2.5, b.y - 14.0), Vector2(b.x + 2.5, b.y - 4.0),
		1.1 * unit, Color(INK, 0.25))
	# A tiny side scar keeps wide empty portrait gutters visibly printed.
	if a.x > 18.0:
		var x := a.x * 0.52
		var y := a.y + _art_bounds.size.y * 0.68
		_stroke(Vector2(x, y), Vector2(x + 4.0, y - 1.0), unit, Color(colour, 0.25))
		_stroke(Vector2(x + 1.0, y + 4.0), Vector2(x + 3.0, y + 4.0), unit, Color(colour, 0.17))


func _paper_edge(top: float, bottom: float, unit: float, colour: Color) -> void:
	var available := bottom - top
	if available < 18.0:
		return
	var x := size.x - 5.5
	var start_y := top + minf(15.0, available * 0.2)
	var finish_y := bottom - 13.0
	if finish_y > start_y:
		_broken_stroke(Vector2(x, start_y), Vector2(x, finish_y), 1.2 * unit, Color(colour, 0.17), 5)
		_stroke(Vector2(x - 1.8, start_y + 5.0), Vector2(x - 1.8, minf(finish_y, start_y + 24.0)),
			0.8 * unit, Color(PAPER, 0.42))
	# Local paper thickness at one heel, no continuous outer border.
	var heel := Vector2(10.0, bottom - 1.0)
	_broken_stroke(heel, heel + Vector2(minf(size.x * 0.26, 45.0), 0.0),
		1.2 * unit, Color(colour, 0.28), 3)


func _reading_impressions(bottom: float) -> void:
	var factor := size / _base_size()
	if _kind == "master":
		# Thin, uneven pressure left below the four existing information lines;
		# actual glyph bounds still win over every individual fragment.
		for y: float in [371.0, 403.0, 435.0, 467.0]:
			_broken_stroke(Vector2(16.0 * factor.x, y * factor.y),
				Vector2(size.x - 18.0 * factor.x, y * factor.y), 0.70, Color(INK, 0.072), 13)
	elif _kind == "hand":
		# Only place this short rule when the actual title and detail leave a
		# five-pixel air gap. Conservative default bounds therefore omit it.
		var x := 10.0 * factor.x
		var length := clampf(29.0 * factor.x, 24.0, 35.0)
		for offset: int in 10:
			var y := (146.0 + float(offset)) * factor.y
			if not _reading_gap_clear(Rect2(x - 1.0, y - 2.5, length + 2.0, 5.0)):
				continue
			_broken_stroke(Vector2(x, y), Vector2(x + length, y), 0.85, Color(INK, 0.16), 3)
			break
	elif _kind == "choice_prayer":
		# Two small bits of paper remain at the upper sides of the fee plate.
		# Their fixed three-pixel width breaks the block join without touching
		# the existing description or cost text.
		_stroke(Vector2(5.0, bottom + 1.0), Vector2(5.0, bottom + 4.5), 3.0, Color(MOUNT_PAPER, 0.48))
		_stroke(Vector2(size.x - 5.0, bottom + 0.5), Vector2(size.x - 5.0, bottom + 3.0),
			3.0, Color(MOUNT_PAPER, 0.40))


func _reading_gap_clear(rect: Rect2) -> bool:
	for protection: Rect2 in _protected:
		if protection.intersects(rect):
			return false
	return not (_art_bounds.has_area() and _art_bounds.intersects(rect))


func _contact_impression(top: float, bottom: float, unit: float) -> void:
	if bottom - top < 25.0 or _kind == "choice_prayer":
		return
	# An incomplete three-lobed contact, with no almond outline, pupil, face
	# or functional symbol. Most of it is lost behind actual reading bounds.
	var radius := minf(22.0 * unit, (bottom - top) * 0.27)
	var center := Vector2(size.x - radius * 0.60 - 5.0, bottom - radius * 0.72 - 8.0)
	var phase := _rng.randf_range(-0.3, 0.3)
	var colour := Color(_category.lerp(INK, 0.5), 0.060)
	for ring: int in 2:
		var count := 25
		var previous := Vector2.ZERO
		for i: int in count + 1:
			var angle := float(i) / float(count) * TAU + phase
			var radius_at := radius * (0.71 + 0.13 * sin(angle * 3.0 + 0.6) + 0.06 * cos(angle * 5.0))
			radius_at *= 1.0 - float(ring) * 0.27
			var point := center + Vector2(cos(angle) * radius_at * 0.81, sin(angle) * radius_at)
			if i > 0 and i % 7 != 0 and i % 11 != 0:
				_stroke(previous, point, (1.0 if ring == 0 else 0.85) * unit, colour)
			previous = point
	# A small loose inner trace is offset, avoiding a familiar eye silhouette.
	_stroke(center + Vector2(3.0, -6.0) * unit, center + Vector2(1.0, -2.0) * unit,
		1.8 * unit, Color(colour, 0.045))


func _plate_ticks(bottom: float, unit: float, colour: Color) -> void:
	# These are material registration cuts, not counts or gameplay state.
	var x := size.x - 37.0 * unit
	var y := minf(size.y - 5.0, bottom - 1.0)
	for index: int in 5:
		var length := [2.4, 4.0, 2.1, 3.2, 1.8][index] as float
		var position_at := Vector2(x + float(index) * 4.0 * unit, y)
		_stroke(position_at, position_at + Vector2(0.0, -length * unit),
			1.15 * unit, Color(colour, 0.38 if index == 1 else 0.25), 0.16)


func _broken_stroke(from: Vector2, to: Vector2, width: float, colour: Color, pieces: int) -> void:
	for index: int in pieces:
		var start := (float(index) + _rng.randf_range(0.02, 0.11)) / float(pieces)
		var finish := (float(index) + _rng.randf_range(0.68, 0.92)) / float(pieces)
		_stroke(from.lerp(to, start), from.lerp(to, finish), width * _rng.randf_range(0.72, 1.15), colour)


func _stroke(from: Vector2, to: Vector2, width: float, colour: Color, emphasis := 0.0) -> void:
	if from.is_equal_approx(to):
		return
	var normal := (to - from).normalized().orthogonal() * width * 0.5
	var points := PackedVector2Array([
		from + normal * 0.72, to + normal, to - normal * 0.68,
		from.lerp(to, 0.19) - normal * 1.13, from - normal * 0.81,
	])
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	if not Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)).encloses(bounds):
		return
	if _art_bounds.has_area() and _art_bounds.grow(0.6).intersects(bounds):
		return
	for protection: Rect2 in _protected:
		if protection.grow(1.0).intersects(bounds):
			return
	_marks.append({"points": points, "colour": colour, "emphasis": emphasis})


func _draw() -> void:
	var strength := maxf(_hover * 0.60, 1.0 if _selected else 0.0)
	for mark: Dictionary in _marks:
		var colour: Color = mark.colour
		colour.a = minf(maxf(0.52, colour.a), colour.a + float(mark.emphasis) * strength)
		draw_colored_polygon(mark.points, colour)


func _default_art() -> Rect2:
	var base := _base_size()
	var rect := Rect2()
	match _kind:
		"world": rect = Rect2(10.0, 35.0, 240.0, 240.0)
		"master": rect = Rect2(15.0, 103.0, 220.0, 220.0)
		"hand": rect = Rect2(22.0, 28.0, 104.0, 95.0)
		"choice_object": rect = Rect2(22.0, 6.0, 80.0, 60.0)
	return Rect2(rect.position * size / base, rect.size * size / base)


func _default_protection() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	match _kind:
		"world": rects = [Rect2(16.0, 8.0, 228.0, 25.0), Rect2(18.0, 283.0, 227.0, 97.0)]
		"master": rects = [Rect2(15.0, 12.0, 220.0, 83.0), Rect2(15.0, 340.0, 220.0, 193.0)]
		"hand": rects = [Rect2(8.0, 5.0, 132.0, 20.0), Rect2(9.0, 126.0, 130.0, 62.0)]
		"choice_prayer": rects = [Rect2(8.0, 8.0, 108.0, 67.0), Rect2(8.0, 79.0, 108.0, 25.0)]
		"choice_object": rects = [Rect2(8.0, 66.0, 108.0, 40.0)]
	var factor := size / _base_size()
	for index: int in rects.size():
		rects[index] = Rect2(rects[index].position * factor, rects[index].size * factor)
	return rects


func _base_size() -> Vector2:
	match _kind:
		"world": return Vector2(260.0, 390.0)
		"master": return Vector2(250.0, 552.0)
		"choice_prayer", "choice_object": return Vector2(124.0, 112.0)
	return Vector2(148.0, 198.0)
