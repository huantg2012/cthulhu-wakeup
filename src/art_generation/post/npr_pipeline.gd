extends Node
## Replaceable post stage: accepts a linear painting or original world texture.
## Owns its viewports and shader parameters. No global shader state or Session.
const Data = preload("res://src/art_generation/source/data.gd")
const BASE = "res://src/art_generation/source/shaders/"
var composite: SubViewport
var down: SubViewport
var blur: SubViewport
var final: SubViewport
var source_rect: TextureRect
var sky_rect: TextureRect
var post: ShaderMaterial
var down_mat: ShaderMaterial
func _ready():
	composite=_viewport(Vector2i(960,960))
	sky_rect=_rect(composite)
	source_rect=_rect(composite)
	down=_viewport(Vector2i(240,240))
	var down_rect=_rect(down)
	down_rect.texture=composite.get_texture()
	down_mat=_material(BASE+"bloom_down.gdshader")
	down_mat.set_shader_parameter("src_px",Vector2.ONE/960)
	down_mat.set_shader_parameter("threshold",.55)
	down_rect.material=down_mat
	blur=_viewport(Vector2i(240,240))
	var blur_rect=_rect(blur)
	blur_rect.texture=down.get_texture()
	blur_rect.material=_material(BASE+"bloom_blur.gdshader")
	final=_viewport(Vector2i(960,960))
	var final_rect=_rect(final)
	final_rect.texture=composite.get_texture()
	post=_material(BASE+"post.gdshader")
	post.set_shader_parameter("bloom_tex",blur.get_texture())
	final_rect.material=post
func _viewport(size: Vector2i) -> SubViewport:
	var v=SubViewport.new();v.size=size;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;v.transparent_bg=false;add_child(v);return v
func _rect(v: SubViewport) -> TextureRect:
	var r=TextureRect.new();r.size=Vector2(v.size);r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_SCALE;v.add_child(r);return r
func _material(path: String) -> ShaderMaterial:
	var m=ShaderMaterial.new();m.shader=load(path);return m
func apply(subject: Image, world: Dictionary, sky: Image = null, illustration: bool = true) -> Image:
	for v in [composite,down,blur,final]:v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	sky_rect.texture=ImageTexture.create_from_image(sky) if sky != null else null
	source_rect.texture=ImageTexture.create_from_image(subject)
	var s=Data.STYLES[world.styleIndex]
	var p=Data.pal_colors(world.palette)
	var values={"style":world.styleSid,"madness":.06,"bloom_amt":s.bloom,"grain":s.grain,"vignette":s.vig,"px_scale":.68 if illustration else 960.0/720.0,"seed":float(world.worldSeed%1000)*.37,"paper":Data.PAPER,"ink":Data.INK,"accent":p.cor_glow,"holo":Data.HOLO}
	for k in values:post.set_shader_parameter(k,values[k])
	for frame in 4:await _render_frame()
	var image=final.get_texture().get_image()
	for v in [composite,down,blur,final]:v.render_target_update_mode=SubViewport.UPDATE_DISABLED
	return image

func _render_frame():
	await get_tree().process_frame
	# Explicit offscreen draw also works when the tool window is occluded.
	RenderingServer.force_draw(false)
