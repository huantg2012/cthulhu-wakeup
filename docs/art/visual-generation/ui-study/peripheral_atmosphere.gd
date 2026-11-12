extends Control
## Painted aperture around the exploration scene, with a shared capture clock.
const VeilShader = preload("res://docs/art/visual-generation/ui-study/peripheral_veil.gdshader")
const SurfaceShader = preload("res://docs/art/visual-generation/ui-study/peripheral_surface.gdshader")
const MistShader = preload("res://docs/art/visual-generation/ui-study/peripheral_mist.gdshader")
const Carrier = preload("res://docs/art/visual-generation/ui-study/peripheral_tendrils.gd")
const LOOP_SECONDS := 24.0
var paused := false
var elapsed := 0.0
var _materials: Array[ShaderMaterial] = []
var _carrier: Control
static var _noise_texture: ImageTexture

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 size = Vector2(1280, 720)
 _add_wash(VeilShader)
 _carrier = Carrier.new()
 _carrier.paused = true
 _carrier.material = _make_material(SurfaceShader)
 add_child(_carrier)
 _add_wash(MistShader)
 set_sample_time(elapsed)

func _make_material(shader: Shader) -> ShaderMaterial:
 var paint := ShaderMaterial.new()
 paint.shader = shader
 paint.set_shader_parameter("pigment_noise", _pigment())
 _materials.append(paint)
 return paint

func _add_wash(shader: Shader) -> void:
 var wash := ColorRect.new()
 wash.size = size
 wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
 wash.material = _make_material(shader)
 add_child(wash)

func _process(delta: float) -> void:
 if not paused:
  set_sample_time(elapsed + delta)

func set_sample_time(seconds: float) -> void:
 # Every moving field closes over this period, including its velocity.
 elapsed = fposmod(seconds, LOOP_SECONDS)
 for paint in _materials:
  paint.set_shader_parameter("elapsed", elapsed)
 if is_instance_valid(_carrier):
  _carrier.set_sample_time(elapsed)

static func _pigment() -> ImageTexture:
 if _noise_texture != null:
  return _noise_texture
 var broad := FastNoiseLite.new()
 broad.seed = 98714
 broad.frequency = 0.025
 broad.fractal_octaves = 3
 var dry := FastNoiseLite.new()
 dry.seed = 4017
 dry.frequency = 0.21
 dry.fractal_octaves = 2
 var bitmap := Image.create(256, 256, false, Image.FORMAT_RGBA8)
 for y in 256:
  for x in 256:
   # Tile via blending opposite samples so drifting fields have no texture seam.
   var u := float(x) / 256.0
   var v := float(y) / 256.0
   var a := lerpf(broad.get_noise_2d(x,y), broad.get_noise_2d(x-256,y), u)
   var b := lerpf(broad.get_noise_2d(x,y-256), broad.get_noise_2d(x-256,y-256), u)
   var field := clampf(lerpf(a,b,v)*1.4+0.5,0.0,1.0)
   var grain := dry.get_noise_2d(x*0.7,y*1.6)*0.5+0.5
   bitmap.set_pixel(x,y,Color(field,grain,0.0,1.0))
 _noise_texture = ImageTexture.create_from_image(bitmap)
 return _noise_texture
