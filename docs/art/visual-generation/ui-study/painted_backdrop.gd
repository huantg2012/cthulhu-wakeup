extends RefCounted
## Composed paint field for the independent UI study.
## Broad silhouettes establish distance; pigment is confined to those silhouettes.
## No scene objects, camera, interaction, or illustration pixels are changed.
const SIZE := Vector2i(960, 540)
const LOGICAL := Vector2(1280.0, 720.0)
const DEEP := Color("#080d14")
const COLD := Color("#1c2330")
const HAZE := Color("#344449")
const LOW_HAZE := Color("#303e37")
const NEAR := Color("#080e12")
static var _cached: Texture2D

static func _noise(seed_value: int, frequency: float, octaves: int) -> FastNoiseLite:
 var field := FastNoiseLite.new()
 field.seed = seed_value
 field.frequency = frequency
 field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 field.fractal_octaves = octaves
 return field

static func _track(x: float, points: PackedVector2Array) -> float:
 for i in range(1, points.size()):
  if x <= points[i].x:
   var t := clampf((x-points[i-1].x)/(points[i].x-points[i-1].x),0.0,1.0)
   t = t*t*(3.0-2.0*t)
   return lerpf(points[i-1].y,points[i].y,t)
 return points[-1].y

static func _bell(distance: float, width: float) -> float:
 var d := distance/width
 return exp(-d*d)

static func texture() -> Texture2D:
 if _cached != null:
  return _cached
 var bitmap := Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
 var bank_noise := _noise(7917,0.008,2)
 var brush_noise := _noise(2381,0.082,2)
 var grit := RandomNumberGenerator.new()
 grit.seed = 187304
 # These contours are compositional marks, not iso-lines from a noise texture.
 # The distant cool bank rises behind the card group and vanishes before the text.
 var high_bank := PackedVector2Array([
  Vector2(0,450),Vector2(180,402),Vector2(350,322),Vector2(520,208),
  Vector2(730,124),Vector2(930,117),Vector2(1120,163),Vector2(1280,196)])
 # A lower, warmer wash places the cards in front of a second, separate depth.
 var low_bank := PackedVector2Array([
  Vector2(0,612),Vector2(220,593),Vector2(420,574),Vector2(650,585),
  Vector2(870,601),Vector2(1090,570),Vector2(1280,532)])
 # The near veil has an asymmetric edge; the dock remains on uninterrupted dark paint.
 var near_edge := PackedVector2Array([
  Vector2(0,536),Vector2(180,563),Vector2(370,616),Vector2(600,636),
  Vector2(880,629),Vector2(1100,615),Vector2(1280,570)])
 var upper: PackedFloat32Array = []
 var lower: PackedFloat32Array = []
 var foreground: PackedFloat32Array = []
 upper.resize(SIZE.x);lower.resize(SIZE.x);foreground.resize(SIZE.x)
 for x in SIZE.x:
  var lx := (float(x)+0.5)*LOGICAL.x/float(SIZE.x)
  upper[x] = _track(lx,high_bank)
  lower[x] = _track(lx,low_bank)
  foreground[x] = _track(lx,near_edge)
 for y in SIZE.y:
  var ly := (float(y)+0.5)*LOGICAL.y/float(SIZE.y)
  var upper_air := 1.0-smoothstep(50.0,570.0,ly)
  var dock := smoothstep(614.0,684.0,ly)
  var text_y := smoothstep(100.0,170.0,ly)*(1.0-smoothstep(530.0,600.0,ly))
  for x in SIZE.x:
   var lx := (float(x)+0.5)*LOGICAL.x/float(SIZE.x)
   var n := bank_noise.get_noise_2d(lx,ly)
   var brush := brush_noise.get_noise_2d(lx*0.43,ly*1.6)
   var quiet_left := 1.0-(1.0-smoothstep(230.0,390.0,lx))*text_y*0.87
   var cool_extent := smoothstep(260.0,600.0,lx)*(1.0-smoothstep(1090.0,1460.0,lx))
   var far_wash := _bell(ly-upper[x]-n*19.0,100.0)*cool_extent
   var high_edge := _bell(ly-upper[x]+34.0-n*13.0,34.0)*cool_extent
   var low_wash := _bell(ly-lower[x]-n*11.0,40.0)
   low_wash *= smoothstep(130.0,470.0,lx)*(1.0-smoothstep(1170.0,1430.0,lx))
   var color := DEEP.lerp(COLD,upper_air*0.24)
   # A cool distant field and a narrower warm wash do not share their light centres.
   color = color.lerp(HAZE,clampf(far_wash*(0.43+n*0.09)*quiet_left,0.0,0.60))
   color = color.lerp(Color("#4d5b5d"),high_edge*(0.10+maxf(brush,0.0)*0.08)*quiet_left)
   color = color.lerp(LOW_HAZE,low_wash*(0.35+n*0.07)*quiet_left)
   # Small, directional scumbles occur inside the washes. Most of the screen stays calm.
   var pigment_mask := clampf(far_wash*0.35+high_edge*0.24+low_wash*0.32,0.0,0.65)*quiet_left
   var pigment := brush*pigment_mask*0.012
   var fine := grit.randf_range(-0.0015,0.0015)*(0.25+pigment_mask)
   color.r += pigment+fine
   color.g += pigment*0.92+fine
   color.b += pigment*0.78+fine
   # Near paint occludes the washes with a broad uneven boundary, never a ruled horizon.
   var near_mask := smoothstep(foreground[x]-18.0+n*5.0,foreground[x]+35.0+n*5.0,ly)
   color = color.lerp(NEAR,near_mask*0.86)
   color = color.lerp(Color("#070c10"),dock*0.65)
   var side_shadow := pow(absf((lx-680.0)/790.0),2.8)*0.30
   var top_shadow := (1.0-smoothstep(0.0,110.0,ly))*0.33
   color = color.lerp(Color("#070b10"),clampf(side_shadow+top_shadow,0.0,0.48))
   color.a=1.0
   bitmap.set_pixel(x,y,color)
 _distant_marks(bitmap)
 _cached=ImageTexture.create_from_image(bitmap)
 return _cached

static func _distant_marks(bitmap: Image) -> void:
 # A sparse depth cue with no constellation lines, sparkle crosses, or bright UI ornaments.
 var rng := RandomNumberGenerator.new()
 rng.seed=47107
 for i in 38:
  var point := Vector2i(rng.randi_range(278,933),rng.randi_range(55,409))
  # The occupied card band hides most distant marks naturally; none enter the left reading zone.
  var alpha := rng.randf_range(0.05,0.16)
  var tint := Color("#86918c") if i%4 else Color("#767b91")
  bitmap.set_pixelv(point,bitmap.get_pixelv(point).lerp(tint,alpha))
  if i%7==0 and point.x+1<bitmap.get_width():
   var neighbour := point+Vector2i(1,0)
   bitmap.set_pixelv(neighbour,bitmap.get_pixelv(neighbour).lerp(tint,alpha*0.35))
