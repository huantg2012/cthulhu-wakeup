extends Control
## Deforming painted carriers. Surface detail and attached eyes are supplied by
## the shared atmosphere material; their UV coordinates stay bound to this mesh.

const SAMPLES := 72
const LOOP_SECONDS := 24.0

# Origin, tangent, inward direction, length, depth, root width, phase.
# The roots remain outside the 1280 × 720 canvas and avoid occupied UI corners.
const STRANDS := [
	[Vector2(425, -19), Vector2.RIGHT, Vector2.DOWN, 235.0, 64.0, 72.0, 0.2],
	[Vector2(932, -24), Vector2.LEFT, Vector2.DOWN, 160.0, 60.0, 66.0, 2.8],
	[Vector2(484, 744), Vector2.RIGHT, Vector2.UP, 190.0, 64.0, 70.0, 4.1],
	[Vector2(968, 739), Vector2.LEFT, Vector2.UP, 132.0, 62.0, 66.0, 1.7],
	[Vector2(-22, 203), Vector2.DOWN, Vector2.RIGHT, 176.0, 43.0, 58.0, 3.5],
	[Vector2(1300, 516), Vector2.UP, Vector2.LEFT, 190.0, 42.0, 58.0, 5.2]
]

var paused := false
var motion_time := 0.0
var _mesh := ArrayMesh.new()
var _mesh_arrays: Array = []
var _vertices := PackedVector2Array()
var _base_paths: Array[PackedVector2Array] = []
var _widths: Array[PackedFloat32Array] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_build_topology()
	set_sample_time(motion_time)

func _process(delta: float) -> void:
	if not paused:
		set_sample_time(motion_time + delta)

func set_sample_time(seconds: float) -> void:
	motion_time = fposmod(seconds, LOOP_SECONDS)
	if not _base_paths.is_empty():
		_update_vertices()
	queue_redraw()

func _draw() -> void:
	if _mesh.get_surface_count() > 0:
		draw_mesh(_mesh, null)

func _build_topology() -> void:
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for strand_index in range(STRANDS.size()):
		var strand: Array = STRANDS[strand_index]
		var phase: float = strand[6]
		var base_path := PackedVector2Array()
		var widths := PackedFloat32Array()
		var strip_start := uv.size()
		# Red encodes the carrier ID. The shader consumes it as metadata, not tint.
		var carrier_id := Color(float(strand_index) / float(STRANDS.size() - 1), 1.0, 1.0, 1.0)
		for section in range(SAMPLES + 1):
			var t := float(section) / SAMPLES
			base_path.append(_curled_path(t, float(strand[3]), float(strand[4])))
			var taper := pow(1.0 - t, 1.35)
			var uneven := 1.0 + sin(t * 16.0 + phase) * 0.11 + sin(t * 39.0 + phase) * 0.035
			widths.append(maxf(0.12, float(strand[5]) * taper * uneven))
			uv.append(Vector2(t, 0.0))
			uv.append(Vector2(t, 1.0))
			colors.append(carrier_id)
			colors.append(carrier_id)
		_base_paths.append(base_path)
		_widths.append(widths)
		# Connect adjacent cross sections once. Deformation never retriangulates
		# the outline or changes which vertices interpolate the eye and pigment UVs.
		for segment in range(SAMPLES):
			var first := strip_start + segment * 2
			indices.append_array(PackedInt32Array([
				first, first + 2, first + 1,
				first + 1, first + 2, first + 3]))
	_vertices.resize(uv.size())
	_mesh_arrays.resize(Mesh.ARRAY_MAX)
	_mesh_arrays[Mesh.ARRAY_TEX_UV] = uv
	_mesh_arrays[Mesh.ARRAY_COLOR] = colors
	_mesh_arrays[Mesh.ARRAY_INDEX] = indices

func _update_vertices() -> void:
	var vertex_index := 0
	for strand_index in range(STRANDS.size()):
		var strand: Array = STRANDS[strand_index]
		var progress := motion_time * TAU / LOOP_SECONDS + float(strand[6])
		var points := PackedVector2Array()
		for section in range(SAMPLES + 1):
			var t := float(section) / SAMPLES
			var local := _base_paths[strand_index][section]
			var mobility := smoothstep(0.0, 0.65, t)
			# The delayed tip moves with the body. Integer harmonics close both
			# position and velocity across the 24-second loop boundary.
			local.y += (sin(progress - t * 2.4) * 7.0 + sin(progress * 2.0 + t * 5.0) * 2.0) * mobility
			local.x += (sin(progress - t * 3.1) * 4.0 + sin(progress * 3.0 + t * 2.0) * 1.0) * mobility
			points.append(strand[0] + strand[1] * local.x + strand[2] * local.y)
		for section in range(points.size()):
			var previous := points[maxi(section - 1, 0)]
			var next := points[mini(section + 1, points.size() - 1)]
			var tangent := (next - previous).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var half_width := _widths[strand_index][section] * 0.5
			_vertices[vertex_index] = points[section] + normal * half_width
			_vertices[vertex_index + 1] = points[section] - normal * half_width
			vertex_index += 2
	_mesh_arrays[Mesh.ARRAY_VERTEX] = _vertices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _mesh_arrays)

func _curled_path(t: float, length: float, depth: float) -> Vector2:
	var bend := Vector2(length * 0.79, depth)
	if t < 0.65:
		return Vector2.ZERO.bezier_interpolate(
			Vector2(length * 0.34, 1), Vector2(length * 0.51, depth * 1.15), bend, t / 0.65)
	return bend.bezier_interpolate(
		Vector2(length * 1.07, depth * 0.90), Vector2(length * 0.96, depth * 0.05),
		Vector2(length * 0.81, depth * 0.39), (t - 0.65) / 0.35)
