extends Control
## Painted aperture around the exploration scene, with a shared capture clock.
const VeilShader = preload("res://docs/art/visual-generation/ui-study/peripheral_veil.gdshader")
const Tendrils = preload("res://docs/art/visual-generation/ui-study/peripheral_tendrils.gd")
var paused := false
var elapsed := 0.0
var _veil: ShaderMaterial
var _tendrils: Control
static var _noise_texture: ImageTexture

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 size = Vector2(1280, 720)
 var wash := ColorRect.new()
 wash.size = size
 wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _veil = ShaderMaterial.new()
 _veil.shader = VeilShader
 _veil.set_shader_parameter("pigment_noise", _pigment())
 wash.material = _veil
 add_child(wash)
 _tendrils = Tendrils.new()
 _tendrils.paused = true
 add_child(_tendrils)
 set_sample_time(elapsed)

func _process(delta: float) -> void:
 if not paused:
  set_sample_time(elapsed + delta)

func set_sample_time(seconds: float) -> void:
 elapsed = seconds
 if _veil != null:
  _veil.set_shader_parameter("elapsed", elapsed)
 if is_instance_valid(_tendrils):
  _tendrils.set_sample_time(elapsed)

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
