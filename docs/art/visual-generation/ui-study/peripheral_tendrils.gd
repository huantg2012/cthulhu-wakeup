extends Control
## Sparse painted folds entering the observation window from outside its bounds.
## All positions use the study's 1280 × 720 logical canvas.

const SAMPLES := 72
const BODY := Color("#273b39")
const RIDGE := Color("#526454")
const SHADOW := Color("#03090d")

var paused := false
var motion_time := 0.0
var _pigment: Texture2D

# Origin, tangent, inward direction, length, depth, root width, phase, period.
# The four occupied UI corners stay outside these six painted paths.
const STRANDS := [
	[Vector2(425, -19), Vector2.RIGHT, Vector2.DOWN, 235.0, 64.0, 56.0, 0.2, 19.0],
	[Vector2(932, -24), Vector2.LEFT, Vector2.DOWN, 160.0, 60.0, 48.0, 2.8, 23.0],
	[Vector2(484, 744), Vector2.RIGHT, Vector2.UP, 190.0, 64.0, 58.0, 4.1, 21.0],
	[Vector2(968, 739), Vector2.LEFT, Vector2.UP, 132.0, 62.0, 48.0, 1.7, 17.0],
	[Vector2(-22, 203), Vector2.DOWN, Vector2.RIGHT, 176.0, 43.0, 40.0, 3.5, 24.0],
	[Vector2(1300, 516), Vector2.UP, Vector2.LEFT, 190.0, 42.0, 40.0, 5.2, 20.0]
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_pigment = _make_pigment()
	queue_redraw()

func _process(delta: float) -> void:
	if not paused:
		set_sample_time(motion_time + delta)

func set_sample_time(seconds: float) -> void:
	motion_time = seconds
	queue_redraw()

func _draw() -> void:
	if _pigment == null:
		return
	for strand: Array in STRANDS:
		var points := PackedVector2Array()
		var widths := PackedFloat32Array()
		var phase: float = strand[6]
		var progress := motion_time * TAU / float(strand[7]) + phase
		for index in range(SAMPLES + 1):
			var t := float(index) / SAMPLES
			var local := _curled_path(t, float(strand[3]), float(strand[4]))
			# The root remains anchored outside the view. The end moves after the body,
			# so the contour unfolds instead of sliding as one rigid ornament.
			var mobility := smoothstep(0.0, 0.65, t)
			local.y += (sin(progress - t * 2.4) * 7.0 + sin(progress * 0.71 + t * 5.0) * 2.0) * mobility
			local.x += sin(progress * 0.83 - t * 3.1) * 5.0 * mobility
			points.append(strand[0] + strand[1] * local.x + strand[2] * local.y)
			var taper := pow(1.0 - t, 1.35)
			var uneven := 1.0 + sin(t * 16.0 + phase) * 0.11 + sin(t * 39.0 + phase) * 0.035
			widths.append(maxf(0.12, float(strand[5]) * taper * uneven))
		_draw_band(points, widths, SHADOW, 0.64, 1.24, 0.0, phase)
		_draw_band(points, widths, BODY, 0.72, 1.0, 0.0, phase)
		_draw_band(points, widths, RIDGE, 0.20, 0.23, -0.21, phase)

func _curled_path(t: float, length: float, depth: float) -> Vector2:
	# Two joined cubic strokes make a broad root followed by an incomplete curl.
	var bend := Vector2(length * 0.79, depth)
	if t < 0.65:
		return Vector2.ZERO.bezier_interpolate(
			Vector2(length * 0.34, 1), Vector2(length * 0.51, depth * 1.15), bend, t / 0.65)
	return bend.bezier_interpolate(
		Vector2(length * 1.07, depth * 0.90), Vector2(length * 0.96, depth * 0.05),
		Vector2(length * 0.81, depth * 0.39), (t - 0.65) / 0.35)

func _draw_band(points: PackedVector2Array, widths: PackedFloat32Array,
	tint: Color, opacity: float, width_scale: float, offset: float, phase: float) -> void:
	var outline := PackedVector2Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	for side in [1.0, -1.0]:
		for step in range(points.size()):
			var index: int = step if side > 0 else points.size() - 1 - step
			var previous := points[maxi(index - 1, 0)]
			var next := points[mini(index + 1, points.size() - 1)]
			var tangent := (next - previous).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var t := float(index) / SAMPLES
			outline.append(points[index] + normal * widths[index] * (side * width_scale * 0.5 + offset))
			var dry_break := 0.59 + 0.41 * smoothstep(-0.6, 0.6, sin(t * 23.0 + phase))
			var fade := 1.0 - smoothstep(0.78, 1.0, t)
			colors.append(Color(tint, opacity * dry_break * fade))
			uv.append(Vector2(t, 0.0 if side > 0 else 1.0))
	draw_polygon(outline, colors, uv, _pigment)

func _make_pigment() -> Texture2D:
	var bitmap := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	var grain := FastNoiseLite.new()
	grain.seed = 48157
	grain.frequency = 0.19
	grain.fractal_octaves = 2
	for y in bitmap.get_height():
		for x in bitmap.get_width():
			var sample := grain.get_noise_2d(x * 0.55, y * 1.6)
			var pigment := clampf(0.78 + sample * 0.45, 0.38, 1.0)
			var edge := smoothstep(0.0, 3.0, float(mini(y, 31 - y)))
			bitmap.set_pixel(x, y, Color(pigment, pigment, pigment, edge))
	return ImageTexture.create_from_image(bitmap)
