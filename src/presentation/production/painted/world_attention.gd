extends Control
## A dry pigment impression on the exposed LEFT edge, never a second frame.
const Marks = preload("res://src/presentation/production/painted/card_carrier/category_marks.gd")
const Paint = preload("res://src/presentation/production/painted/theme.gd")
var kind := ""
var exposure := 260.0
var _elapsed := 0.0
var _strength := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func mark(value: String) -> void:
	kind = value
	_elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	_strength = move_toward(_strength, 0.0 if kind.is_empty() else 1.0, delta * 5.0)
	queue_redraw()
	if _elapsed > 1.8: set_process(false)

func _draw() -> void:
	if _strength <= 0.0: return
	var ink: Color = Marks.info(kind).colour.lightened(0.2)
	var pulse := sin(minf(_elapsed / 1.8, 1.0) * PI) * .20
	var alpha := _strength * (.76 + pulse)
	var width := minf(exposure - 3.0, 106.0)
	# Small irregular deposit, long enough to survive extremely dense piles.
	for strand: int in 4:
		var points := PackedVector2Array()
		for step: int in 23:
			points.append(Vector2(3.5+strand*.8+sin(float(step)*2.1)*.7,61+step*6.0))
		draw_polyline(points,Color(ink,alpha*(.55 if strand == 1 else .18)),1.3,false)
	if width > 60.0:
		var left := 35.0
		draw_colored_polygon(PackedVector2Array([Vector2(left,10),Vector2(left+15,8),Vector2(left+32,10),Vector2(width,11),Vector2(width-2,18),Vector2(width,30),Vector2(width-17,33),Vector2(left+2,34)]),Color("#181b21",_strength*.86))
		draw_line(Vector2(left+2,33),Vector2(width-2,32),Color(ink,alpha),1.3,false)
		var label := str(Marks.info(kind).label)
		draw_string(Paint.fonts().body,Vector2(left+5,26),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(ink,_strength))
	# Uneven short top stroke reads as pigment caught on the card's cut edge.
	var length := maxf(2.0,minf(exposure-4.0,70.0))
	draw_colored_polygon(PackedVector2Array([Vector2(3,9),Vector2(length*.4,7),Vector2(length,9),Vector2(length-2,11),Vector2(4,12)]),Color(ink,alpha))
