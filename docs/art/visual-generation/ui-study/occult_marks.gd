extends RefCounted
## Shared dry-pigment marks for the observer's field and its cards.
static var _seals: Dictionary = {}

static func _grain(x: float, y: float, seed_value: int) -> float:
 return fposmod(sin(x * 12.9898 + y * 78.233 + float(seed_value) * 1.37) * 43758.5453, 1.0)

static func stroke(bitmap: Image, points: PackedVector2Array, color: Color, width: float, opacity: float, seed_value: int) -> void:
 if points.size() < 2:
  return
 # Union coverage avoids dark knots where brush segments overlap.
 var coverage: Dictionary = {}
 for i in range(1, points.size()):
  var start := points[i - 1]
  var end := points[i]
  var segment := end - start
  var length_squared := maxf(segment.length_squared(), 0.001)
  var radius := width * (0.45 + 0.12 * sin(float(i) * 0.31 + seed_value))
  var left := maxi(0, int(floorf(minf(start.x, end.x) - radius - 1.0)))
  var right := mini(bitmap.get_width() - 1, int(ceilf(maxf(start.x, end.x) + radius + 1.0)))
  var top := maxi(0, int(floorf(minf(start.y, end.y) - radius - 1.0)))
  var bottom := mini(bitmap.get_height() - 1, int(ceilf(maxf(start.y, end.y) + radius + 1.0)))
  for y in range(top, bottom + 1):
   for x in range(left, right + 1):
    var pixel := Vector2(x + 0.5, y + 0.5)
    var along := clampf((pixel - start).dot(segment) / length_squared, 0.0, 1.0)
    var distance := pixel.distance_to(start + segment * along)
    var amount := 1.0 - smoothstep(radius * 0.35, radius + 0.65, distance)
    var key := Vector2i(x, y)
    if amount > float(coverage.get(key, 0.0)):
     coverage[key] = amount
 for key: Vector2i in coverage:
  var grain := _grain(key.x, key.y, seed_value)
  var dry := 0.48 + grain * 0.52
  if grain < 0.09:
   dry *= 0.2
  var alpha := clampf(float(coverage[key]) * opacity * dry, 0.0, 1.0)
  bitmap.set_pixelv(key, bitmap.get_pixelv(key).lerp(color, alpha))

static func paint_eye(bitmap: Image, center: Vector2, extent: Vector2, color: Color, opacity: float, seed_value: int) -> void:
 var upper := PackedVector2Array()
 var lower := PackedVector2Array()
 var crease := PackedVector2Array()
 var steps := 64
 for i in range(steps + 1):
  var t := float(i) / steps
  var arch := pow(sin(t * PI), 0.82)
  var x := (t - 0.5) * extent.x
  var tilt := (t - 0.5) * extent.y * 0.10
  var broken_edge := sin(t * 31.0 + seed_value) * extent.y * 0.012
  upper.append(center + Vector2(x, -arch * extent.y * 0.48 + tilt + broken_edge))
  lower.append(center + Vector2(x, arch * extent.y * 0.34 + tilt + broken_edge))
  crease.append(center + Vector2(x * 1.12, -arch * extent.y * 0.68 + tilt))
 # The aperture is dark ink. It contains no bright sclera or outward-facing catchlight.
 var bounds := Rect2(center - extent * Vector2(0.5, 0.5), extent)
 for y in range(maxi(0, int(bounds.position.y)), mini(bitmap.get_height(), int(bounds.end.y))):
  for x in range(maxi(0, int(bounds.position.x)), mini(bitmap.get_width(), int(bounds.end.x))):
   var t := (float(x) - center.x) / extent.x + 0.5
   var arch := pow(maxf(0.0, sin(t * PI)), 0.82)
   var relative_y := (float(y) - center.y) / extent.y
   if relative_y > -arch * 0.46 and relative_y < arch * 0.32:
    var pixel := Vector2i(x, y)
    bitmap.set_pixelv(pixel, bitmap.get_pixelv(pixel).lerp(Color("#070d12"), opacity * 0.7))
 var width := maxf(1.4, extent.y * 0.045)
 stroke(bitmap, upper, color, width * 1.7, opacity, seed_value)
 stroke(bitmap, lower, color, width, opacity * 0.72, seed_value + 1)
 stroke(bitmap, crease, color, width * 0.8, opacity * 0.37, seed_value + 2)
 # The iris drops into the lower lid: attention descends into the card field.
 var iris_center := center + Vector2(extent.x * 0.016, extent.y * 0.13)
 var radii := Vector2(extent.x * 0.075, extent.y * 0.29)
 var iris := PackedVector2Array()
 for i in range(49):
  var angle := float(i) / 48.0 * TAU
  var wavering := 1.0 + sin(angle * 5.0 + seed_value) * 0.06
  iris.append(iris_center + Vector2(cos(angle), sin(angle)) * radii * wavering)
 stroke(bitmap, iris, color, width * 1.1, opacity * 0.83, seed_value + 3)
 var slit := PackedVector2Array([
  iris_center + Vector2(-width * 0.3, -radii.y * 0.72),
  iris_center + Vector2(width * 0.2, 0.0),
  iris_center + Vector2(-width * 0.2, radii.y * 0.82)])
 stroke(bitmap, slit, Color("#03090c"), width * 2.3, opacity * 1.5, seed_value + 4)
 if extent.x > 100.0:
  for i in range(19):
   var angle := float(i) / 19.0 * TAU
   var ray := Vector2(cos(angle), sin(angle)) * radii
   var points := PackedVector2Array([iris_center + ray * 0.55, iris_center + ray * 0.90])
   stroke(bitmap, points, color, width * 0.55, opacity * 0.36, seed_value + i + 5)

static func seal(active: bool) -> Texture2D:
 if _seals.has(active):
  return _seals[active]
 var bitmap := Image.create(80, 36, false, Image.FORMAT_RGBA8)
 bitmap.fill(Color.TRANSPARENT)
 var extent := Vector2(68, 24 if active else 13)
 paint_eye(bitmap, Vector2(40, 17), extent, Color("#a0ae94"), 0.73 if active else 0.28, 63)
 var texture := ImageTexture.create_from_image(bitmap)
 _seals[active] = texture
 return texture
