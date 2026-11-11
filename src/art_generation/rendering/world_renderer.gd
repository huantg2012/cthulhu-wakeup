extends Node
## Adapter around the unchanged celestial generation algorithms, relocated to
## this project. Per-material uniforms replace global shader parameters.
const Gen = preload("res://src/art_generation/source/generator.gd")
const Data = preload("res://src/art_generation/source/data.gd")
const BASE = "res://src/art_generation/source/shaders/"
var gen = Gen.new()
var viewport: SubViewport
var world_root: Node3D
var cam: Camera3D
var setup_done = false
func _setup():
	var shaders = {}
	for name in ["sky","atmo","ring_dust","ring_fx","star","corona","tentacle","prop","rift","portal"]: shaders[name]=load(BASE+name+".gdshader")
	for i in 11:
		var sh=Shader.new()
		sh.code='shader_type spatial;\nrender_mode unshaded,cull_back,depth_draw_opaque,shadows_disabled;\n#define ARCH %d\n#include "%splanet_body.gdshaderinc"\n'%[i,BASE]
		shaders["planet_%d"%i]=sh
	var meshes={}
	var model=load("res://src/art_generation/source/assets/celestial_meshes.res").instantiate()
	_collect(model,meshes)
	model.free()
	gen.setup(meshes,shaders)
	viewport=SubViewport.new();viewport.size=Vector2i(960,960);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.mesh_lod_threshold=0;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.transparent_bg=false;add_child(viewport)
	var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color.BLACK;e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var env=WorldEnvironment.new();env.environment=e;viewport.add_child(env)
	cam=Camera3D.new();cam.current=true;viewport.add_child(cam)
	world_root=Node3D.new();viewport.add_child(world_root)
	setup_done=true
func _collect(n: Node,out: Dictionary):
	if n is MeshInstance3D:out[n.name]=n.mesh
	for child in n.get_children():_collect(child,out)
func generate(world: Dictionary) -> Dictionary:
	if not setup_done:_setup()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var params={"scene":0,"style":world.styleIndex,"seed":world.worldSeed,"archetype":world.archetype,"palette":world.palette,"composition":1,"star_type":-1,"wonder":-1,"count":0,"rings":2,"tentacles":0.0,"eyes":0.0,"glyphs":0.0,"corruption":.2,"madness":.06,"nebula":.25,"aspect":1,"quality":1,"animate":false,"show_title":false,"show_labels":false,"show_frame":false,"show_swatch":false}
	var info=gen.build(params,world_root,cam,Vector2i(960,960))
	var l=info.light
	var values={"g_time":3.0,"g_style":world.styleSid,"g_light_dir":l.dir,"g_light_pos":l.pos,"g_light_point":l.point,"g_light_col":_vec(l.col),"g_amb":_vec(l.amb),"g_rim_col":_vec(l.rim_col),"g_rim_dir":l.rim_dir,"g_rim_amt":l.rim_amt,"g_holo":_vec(Data.HOLO)}
	_apply(world_root,values)
	for frame in 4:await _render_frame()
	var world_image=viewport.get_texture().get_image()
	var sky_count=0
	for child in world_root.get_children():
		var mat=child.material_override if child is MeshInstance3D else null
		var sky=mat is ShaderMaterial and mat.shader.resource_path==BASE+"sky.gdshader"
		if sky:sky_count+=1
		else:child.visible=false
	assert(sky_count==1,"Original sky missing from celestial renderer")
	for frame in 4:await _render_frame()
	var sky_image=viewport.get_texture().get_image()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	return {"world":world_image,"sky":sky_image,"params":params}
func _vec(c: Color) -> Vector3:return Vector3(c.r,c.g,c.b)
func _apply(n: Node,values: Dictionary):
	if n is MeshInstance3D and n.material_override is ShaderMaterial:
		for k in values:n.material_override.set_shader_parameter(k,values[k])
	for child in n.get_children():_apply(child,values)

func _render_frame():
	await get_tree().process_frame
	# Explicit offscreen draw also works when the tool window is occluded.
	RenderingServer.force_draw(false)
