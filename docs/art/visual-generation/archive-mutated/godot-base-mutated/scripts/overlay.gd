extends Control
## Draws title card, body labels, palette strip and style-specific frames on top of the
## post-processed render (inside the final SubViewport, so they end up in exported PNGs).

var font_ui: Font
var font_title: Font
var info: Dictionary = {}
var label_pts: Array = []        # [{p: Vector2, text, sub, main}]
var main_pt := Vector2(-1, -1)
var style := 0
var pal: Dictionary = {}
var show_title := true
var show_labels := true
var show_frame := true
var show_swatch := false
var seed_val := 0
var k := 1.0


func refresh() -> void:
	queue_redraw()


func _ink() -> Color:
	return EData.INK


func _txt(pos: Vector2, s: String, sz: float, col: Color, f: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0.0, ocol := Color.BLACK) -> void:
	var fnt := f if f else font_ui
	var fs := int(round(sz * k))
	if outline > 0.0:
		draw_string_outline(fnt, pos, s, align, w, fs, int(round(outline * k)), ocol)
	draw_string(fnt, pos, s, align, w, fs, col)


func _tw(s: String, sz: float, f: Font = null) -> float:
	var fnt := f if f else font_ui
	return fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(sz * k))).x


func _wobble_rect(r: Rect2, col: Color, wid: float, amp: float, sd: int) -> void:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(a.distance_to(b) / (18.0 * k)) + 2
		for j in n:
			var t := float(j) / float(n)
			var p := a.lerp(b, t)
			p += Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp)) * k
			pts.append(p)
	pts.append(pts[0])
	draw_polyline(pts, col, wid * k, true)


func _corner_ornament(c: Vector2, dir: Vector2, col: Color) -> void:
	var s := 26.0 * k
	draw_arc(c + dir * s * 0.5, s * 0.42, 0, TAU, 24, col, 1.2 * k, true)
	draw_arc(c + dir * s * 0.5, s * 0.22, 0, TAU, 16, col, 1.0 * k, true)
	draw_line(c + Vector2(dir.x * s * 1.6, 0), c + Vector2(dir.x * s * 3.2, 0), col, 1.0 * k, true)
	draw_line(c + Vector2(0, dir.y * s * 1.6), c + Vector2(0, dir.y * s * 3.2), col, 1.0 * k, true)


func _draw() -> void:
	var W := size.x
	var H := size.y
	k = minf(W, H) / 720.0
	if pal.is_empty():
		return
	var accent: Color = pal["c4"]
	var atmo: Color = pal["atmo"]
	if show_frame:
		_draw_frame(W, H, accent, atmo)
	if show_labels:
		_draw_labels(accent)
	if show_title and not info.is_empty():
		_draw_title(W, H, accent, atmo)
	if show_swatch:
		_draw_swatch(W, H)


# ------------------------------------------------------------------ frames
func _draw_frame(W: float, H: float, accent: Color, atmo: Color) -> void:
	var m := 18.0 * k
	match style:
		0:
			var g := Color(0.85, 0.72, 0.45, 0.75)
			draw_rect(Rect2(m, m, W - m * 2, H - m * 2), g, false, 1.4 * k)
			draw_rect(Rect2(m + 6 * k, m + 6 * k, W - m * 2 - 12 * k, H - m * 2 - 12 * k), Color(g, 0.35), false, 1.0 * k)
			for c in [Vector2(m, m), Vector2(W - m, m), Vector2(W - m, H - m), Vector2(m, H - m)]:
				var d := 7.0 * k
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), g)
		1:
			draw_rect(Rect2(0, 0, W, H), Color.BLACK, false, 14.0 * k)
			draw_rect(Rect2(10 * k, 10 * k, W - 20 * k, H - 20 * k), Color.WHITE, false, 3.0 * k)
			# speed lines in corners
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_val
			for i in 26:
				var side := rng.randi() % 4
				var t := rng.randf()
				var p0: Vector2
				match side:
					0: p0 = Vector2(t * W, 12 * k)
					1: p0 = Vector2(W - 12 * k, t * H)
					2: p0 = Vector2(t * W, H - 12 * k)
					_: p0 = Vector2(12 * k, t * H)
				var dir := (Vector2(W, H) * 0.5 - p0).normalized()
				draw_line(p0, p0 + dir * rng.randf_range(30, 90) * k, Color(0, 0, 0, 0.6), rng.randf_range(1.0, 3.0) * k, true)
		2:
			var ink := _ink()
			draw_rect(Rect2(m, m, W - m * 2, H - m * 2), ink, false, 2.4 * k)
			draw_rect(Rect2(m + 7 * k, m + 7 * k, W - m * 2 - 14 * k, H - m * 2 - 14 * k), ink, false, 0.9 * k)
			for c in [[Vector2(m + 7 * k, m + 7 * k), Vector2(1, 1)], [Vector2(W - m - 7 * k, m + 7 * k), Vector2(-1, 1)], [Vector2(W - m - 7 * k, H - m - 7 * k), Vector2(-1, -1)], [Vector2(m + 7 * k, H - m - 7 * k), Vector2(1, -1)]]:
				_corner_ornament(c[0], c[1], ink)
			var plate := "PLATE %s." % ELore.roman((seed_val % 10) + 1)
			_txt(Vector2(0, m + 30 * k), plate, 15, ink, font_title, HORIZONTAL_ALIGNMENT_CENTER, W)
			_txt(Vector2(0, m + 50 * k), "— 星辰异象图谱 · ATLAS OF THE OUTER SPHERES —", 11, Color(ink, 0.8), font_ui, HORIZONTAL_ALIGNMENT_CENTER, W)
		3:
			var c := Color(1, 1, 1, 0.55)
			var l := 34.0 * k
			for p in [[Vector2(m, m), Vector2(1, 1)], [Vector2(W - m, m), Vector2(-1, 1)], [Vector2(W - m, H - m), Vector2(-1, -1)], [Vector2(m, H - m), Vector2(1, -1)]]:
				draw_line(p[0], p[0] + Vector2(l * p[1].x, 0), c, 2.0 * k)
				draw_line(p[0], p[0] + Vector2(0, l * p[1].y), c, 2.0 * k)
		4:
			var px := 4.0 * k
			var c1 := Color(accent, 1.0)
			var c0 := Color(0.02, 0.02, 0.03)
			draw_rect(Rect2(0, 0, W, px * 3), c0)
			draw_rect(Rect2(0, H - px * 3, W, px * 3), c0)
			draw_rect(Rect2(0, 0, px * 3, H), c0)
			draw_rect(Rect2(W - px * 3, 0, px * 3, H), c0)
			draw_rect(Rect2(px * 3, px * 3, W - px * 6, px), c1)
			draw_rect(Rect2(px * 3, H - px * 4, W - px * 6, px), c1)
			draw_rect(Rect2(px * 3, px * 3, px, H - px * 6), c1)
			draw_rect(Rect2(W - px * 4, px * 3, px, H - px * 6), c1)
			for c in [Vector2(px * 3, px * 3), Vector2(W - px * 6, px * 3), Vector2(px * 3, H - px * 6), Vector2(W - px * 6, H - px * 6)]:
				draw_rect(Rect2(c, Vector2(px * 3, px * 3)), c1)
		5:
			var hc := EData.HOLO
			var l := 40.0 * k
			var mm := 24.0 * k
			for p in [[Vector2(mm, mm), Vector2(1, 1)], [Vector2(W - mm, mm), Vector2(-1, 1)], [Vector2(W - mm, H - mm), Vector2(-1, -1)], [Vector2(mm, H - mm), Vector2(1, -1)]]:
				draw_line(p[0], p[0] + Vector2(l * p[1].x, 0), hc, 2.0 * k)
				draw_line(p[0], p[0] + Vector2(0, l * p[1].y), hc, 2.0 * k)
			_txt(Vector2(mm + 10 * k, mm + 26 * k), "OBSERVATION LOG // MISKATONIC DEEP ARRAY", 12, Color(hc, 0.9))
			_txt(Vector2(mm + 10 * k, mm + 44 * k), "SEED %06d   SIGNAL ■■■■□   ANOMALY: CONFIRMED" % seed_val, 10, Color(hc, 0.65))
			_txt(Vector2(0, mm + 26 * k), "RA %02dh %02dm  DEC %+03d°" % [seed_val % 24, (seed_val / 7) % 60, (seed_val % 170) - 85], 11, Color(hc, 0.8), font_ui, HORIZONTAL_ALIGNMENT_RIGHT, W - mm - 10 * k)
			# ruler ticks along right edge
			var n := 30
			for i in n:
				var y := lerpf(H * 0.2, H * 0.8, float(i) / float(n - 1))
				var ll := (14.0 if i % 5 == 0 else 6.0) * k
				draw_line(Vector2(W - mm, y), Vector2(W - mm - ll, y), Color(hc, 0.6), 1.0 * k)
			if main_pt.x >= 0.0:
				var r := 18.0 * k
				draw_arc(main_pt, r, 0, TAU, 32, Color(hc, 0.6), 1.0 * k, true)
				draw_line(main_pt + Vector2(-r * 1.8, 0), main_pt + Vector2(-r * 0.6, 0), Color(hc, 0.6), 1.0 * k)
				draw_line(main_pt + Vector2(r * 0.6, 0), main_pt + Vector2(r * 1.8, 0), Color(hc, 0.6), 1.0 * k)
				draw_line(main_pt + Vector2(0, -r * 1.8), main_pt + Vector2(0, -r * 0.6), Color(hc, 0.6), 1.0 * k)
				draw_line(main_pt + Vector2(0, r * 0.6), main_pt + Vector2(0, r * 1.8), Color(hc, 0.6), 1.0 * k)
		6:
			var ink := Color(_ink(), 0.8)
			_wobble_rect(Rect2(m * 1.4, m * 1.4, W - m * 2.8, H - m * 2.8), ink, 1.6, 1.4, seed_val)
			_wobble_rect(Rect2(m * 1.4 + 4 * k, m * 1.4 + 3 * k, W - m * 2.8 - 7 * k, H - m * 2.8 - 5 * k), Color(ink, 0.4), 1.0, 2.0, seed_val + 1)
			_txt(Vector2(m * 2.4, m * 1.4 + 28 * k), "调查员手记 · 第 %d 页" % ((seed_val % 97) + 3), 14, ink, font_title)
			_txt(Vector2(0, m * 1.4 + 28 * k), "“我不该看向那里。”", 13, Color(ink, 0.7), font_title, HORIZONTAL_ALIGNMENT_RIGHT, W - m * 2.4)
		7:
			var red := Color(0.72, 0.1, 0.08)
			var yel := Color(0.98, 0.82, 0.25)
			var bh := 58.0 * k
			draw_rect(Rect2(0, 0, W, bh), red)
			draw_rect(Rect2(0, bh, W, 4 * k), Color.BLACK)
			_txt(Vector2(22 * k, bh * 0.72), "UNSPEAKABLE SKIES", 30, yel, font_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color.BLACK)
			var sub := "不可名状的天空 · 宇宙恐怖奇谈"
			_txt(Vector2(22 * k + _tw("UNSPEAKABLE SKIES", 30, font_title) + 16 * k, bh * 0.66), sub, 15, Color.WHITE, font_ui, HORIZONTAL_ALIGNMENT_LEFT, -1, 3, Color.BLACK)
			_txt(Vector2(0, bh * 0.66), "VOL.%d  NO.%d   25¢" % [(seed_val % 9) + 1, (seed_val % 12) + 1], 14, yel, font_title, HORIZONTAL_ALIGNMENT_RIGHT, W - 22 * k, 3, Color.BLACK)
			draw_rect(Rect2(0, 0, W, H), Color.BLACK, false, 8 * k)


# ------------------------------------------------------------------ labels
func _draw_labels(accent: Color) -> void:
	for L in label_pts:
		if L.get("main", false):
			continue
		var p: Vector2 = L["p"]
		if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
			continue
		var tcol := Color(1, 1, 1, 0.92)
		var scol := Color(accent, 0.85)
		var lcol := Color(1, 1, 1, 0.45)
		var outline := 3.0
		var oc := Color(0, 0, 0, 0.75)
		if style == 2 or style == 6 or style == 7:
			tcol = _ink()
			scol = Color(_ink(), 0.75)
			lcol = Color(_ink(), 0.6)
			outline = 3.0
			oc = Color(EData.PAPER, 0.85)
		elif style == 5:
			tcol = EData.HOLO
			scol = Color(EData.HOLO, 0.7)
			lcol = Color(EData.HOLO, 0.5)
			outline = 0.0
		var q := p + Vector2(0, 16 * k)
		draw_line(p, q, lcol, 1.0 * k, true)
		draw_circle(p, 2.0 * k, lcol)
		var s: String = L["text"]
		var w := _tw(s, 12, font_title)
		_txt(q + Vector2(-w * 0.5, 14 * k), s, 12, tcol, font_title, HORIZONTAL_ALIGNMENT_LEFT, -1, outline, oc)
		var sub: String = L.get("sub", "")
		if sub != "":
			var w2 := _tw(sub, 10)
			_txt(q + Vector2(-w2 * 0.5, 29 * k), sub, 10, scol, font_ui, HORIZONTAL_ALIGNMENT_LEFT, -1, outline, oc)


# ------------------------------------------------------------------ title card
func _draw_title(W: float, H: float, accent: Color, atmo: Color) -> void:
	var title: String = info.get("title", "")
	var cn: String = info.get("cn", "")
	var ep: String = info.get("epithet", "")
	var kind: String = info.get("kind", "")
	var cat: String = info.get("catalog", "")
	var mx := 44.0 * k
	var by := H - 46.0 * k
	if style == 7:
		by = H - 40.0 * k
	var tsz := 34.0
	var paperish := style == 2 or style == 6
	match style:
		2:
			# engraving: centred caption at the bottom, between rules
			var ink := _ink()
			var cy := H - 64.0 * k
			_txt(Vector2(0, cy), "Fig. I. — %s" % title, 22, ink, font_title, HORIZONTAL_ALIGNMENT_CENTER, W)
			_txt(Vector2(0, cy + 22 * k), "%s · %s  （%s）" % [cn, ep, cat], 13, Color(ink, 0.85), font_ui, HORIZONTAL_ALIGNMENT_CENTER, W)
			var tw := _tw("Fig. I. — %s" % title, 22, font_title)
			draw_line(Vector2(W * 0.5 - tw * 0.5 - 60 * k, cy - 7 * k), Vector2(W * 0.5 - tw * 0.5 - 12 * k, cy - 7 * k), ink, 1.0 * k)
			draw_line(Vector2(W * 0.5 + tw * 0.5 + 12 * k, cy - 7 * k), Vector2(W * 0.5 + tw * 0.5 + 60 * k, cy - 7 * k), ink, 1.0 * k)
			return
		7:
			# pulp: bottom tagline strip
			var bh := 64.0 * k
			draw_rect(Rect2(0, H - bh, W, bh), Color(0.06, 0.04, 0.03, 0.92))
			draw_rect(Rect2(0, H - bh, W, 3 * k), Color(0.98, 0.82, 0.25))
			_txt(Vector2(26 * k, H - bh + 34 * k), title.to_upper(), 26, Color(0.98, 0.82, 0.25), font_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 3, Color.BLACK)
			_txt(Vector2(26 * k, H - bh + 54 * k), "%s——%s" % [cn, ep], 13, Color.WHITE)
			_txt(Vector2(0, H - bh + 38 * k), "“%s”" % _short_hook(), 13, Color(1, 1, 1, 0.85), font_title, HORIZONTAL_ALIGNMENT_RIGHT, W - 26 * k)
			return
	# generic bottom-left card
	var tcol := Color(1, 1, 1, 0.96)
	var scol := Color(accent.lerp(Color.WHITE, 0.35), 0.95)
	var dcol := Color(1, 1, 1, 0.65)
	var outline := 0.0
	var oc := Color.BLACK
	if paperish:
		tcol = _ink()
		scol = Color(_ink(), 0.85)
		dcol = Color(_ink(), 0.65)
	elif style == 5:
		tcol = EData.HOLO
		scol = Color(EData.HOLO, 0.8)
		dcol = Color(EData.HOLO, 0.55)
	elif style == 1:
		outline = 5.0
	elif style == 4:
		outline = 3.0
	if not paperish and style != 5 and style != 1:
		# soft gradient backdrop for legibility
		var gh := 150.0 * k
		draw_polygon(PackedVector2Array([Vector2(0, H - gh), Vector2(W * 0.6, H - gh), Vector2(W * 0.6, H), Vector2(0, H)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6)]))
	if style == 1:
		# manga caption box
		var tw := maxf(maxf(_tw(title, tsz, font_title), _tw("%s · %s" % [cn, ep], 15)), _tw("%s   ·   %s" % [kind, cat], 11)) + 36 * k
		var r := Rect2(mx - 16 * k, by - 72 * k, tw, 92 * k)
		draw_rect(Rect2(r.position + Vector2(6, 6) * k, r.size), Color.BLACK)
		draw_rect(r, Color.WHITE)
		draw_rect(r, Color.BLACK, false, 3 * k)
		tcol = Color.BLACK
		scol = Color(accent.darkened(0.45), 1.0)
		dcol = Color(0, 0, 0, 0.7)
		outline = 0.0
	if style == 5:
		draw_rect(Rect2(mx - 14 * k, by - 74 * k, 3 * k, 94 * k), EData.HOLO)
	_txt(Vector2(mx, by - 34 * k), title, tsz, tcol, font_title, HORIZONTAL_ALIGNMENT_LEFT, -1, outline)
	_txt(Vector2(mx, by - 10 * k), "%s · %s" % [cn, ep], 15, scol, font_ui, HORIZONTAL_ALIGNMENT_LEFT, -1, outline * 0.7)
	_txt(Vector2(mx, by + 10 * k), "%s   ·   %s" % [kind, cat], 11, dcol, font_ui, HORIZONTAL_ALIGNMENT_LEFT, -1, outline * 0.6)
	if style == 0 or style == 3:
		draw_line(Vector2(mx, by - 76 * k), Vector2(mx + 60 * k, by - 76 * k), Color(atmo, 0.9), 2.0 * k)


func _short_hook() -> String:
	var h: String = info.get("hook", "")
	var i := h.find("，")
	if i > 4 and i < 26:
		return h.substr(0, i) + "……"
	if h.length() > 26:
		return h.substr(0, 25) + "……"
	return h


func _draw_swatch(W: float, H: float) -> void:
	var keys := ["c0", "c1", "c2", "c3", "c4", "atmo", "iris"]
	var sw := 30.0 * k
	var x0 := W - (sw + 6 * k) * keys.size() - 36 * k
	var y0 := H - 64.0 * k
	if style == 7:
		y0 = H - 64.0 * k - 60 * k
	for i in keys.size():
		var c: Color = pal[keys[i]]
		var r := Rect2(x0 + i * (sw + 6 * k), y0, sw, sw)
		draw_rect(r, c)
		draw_rect(r, Color(1, 1, 1, 0.5) if style != 2 and style != 6 else Color(_ink(), 0.6), false, 1.0 * k)
		var hx := c.to_html(false).to_upper()
		var col := Color(1, 1, 1, 0.75) if style != 2 and style != 6 else Color(_ink(), 0.8)
		_txt(Vector2(r.position.x - 4 * k, y0 + sw + 13 * k), hx, 8, col, font_ui, HORIZONTAL_ALIGNMENT_CENTER, sw + 8 * k, 2.0 if style != 2 and style != 6 else 0.0)
