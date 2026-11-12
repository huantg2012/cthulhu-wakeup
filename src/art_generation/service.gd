extends Node
## The public generation boundary. Input recipes/data -> images and metadata.
## No gameplay, Session, save game or scene-tree presentation dependencies.
const Catalog = preload("res://src/art_generation/catalog.gd")
const People = preload("res://src/art_generation/algorithms/people.gd")
const Tide = preload("res://src/art_generation/algorithms/sanctuary.gd")
const Cults = preload("res://src/art_generation/algorithms/cult_scenes.gd")
const SurfaceRenderer = preload("res://src/art_generation/rendering/surface_renderer.gd")
const WorldRenderer = preload("res://src/art_generation/rendering/world_renderer.gd")
const Post = preload("res://src/art_generation/post/npr_pipeline.gd")
signal progress(message: String)
var catalog = Catalog.new()
# Injectable Nodes: future backends implement render(plan), generate(recipe),
# or apply(image, recipe, sky, illustration), without modifying consumers.
var surfaces: Node
var celestial: Node
var post: Node
var busy = false
var cached_context: Dictionary = {}
var cache_key = ""
const REVISION = "native-godot-surface-1"
func _ready():
	if surfaces == null: surfaces=SurfaceRenderer.new()
	if celestial == null: celestial=WorldRenderer.new()
	if post == null: post=Post.new()
	for node in [surfaces,celestial,post]:add_child(node)
	surfaces.progress=func(message):progress.emit(message)
func generate(request: Dictionary, options: Dictionary) -> Dictionary:
	if busy:return {"error":"生成器正忙"}
	var error=catalog.validate(request)
	if not error.is_empty():return {"error":error}
	var person_seed=options.get("seed",1000)
	var count=options.get("count",4)
	if not People.is_integer(person_seed) or person_seed<0 or person_seed>0xffffffff:return {"error":"人物种子须为 uint32"}
	if not People.is_integer(count) or count<1 or count>8:return {"error":"人物数量须为 1–8"}
	var backgrounds=catalog.backgrounds(request.template)
	if options.get("background","all") != "all":backgrounds=backgrounds.filter(func(b):return b.caseId==options.background)
	if backgrounds.is_empty():return {"error":"当前世界不支持这个人物背景"}
	busy=true
	var started=Time.get_ticks_msec()
	var w=catalog.world_recipe(request)
	var reused = cache_key == _key(request) and cached_context.has("cult_passes")
	await _ensure_world(request, w)
	await _ensure_cult(w)
	var items=[]
	for i in int(count):
		progress.emit("绘制人物 %d/%d…"%[i+1,count])
		await get_tree().process_frame
		items.append(await _draw_person((int(person_seed)+i)&0xffffffff, w, backgrounds[i%backgrounds.size()]))
	busy=false
	progress.emit("生成完成 · %.1f 秒"%((Time.get_ticks_msec()-started)/1000.0))
	return {"context":cached_context,"people":items,"reused_world":reused,"duration_ms":Time.get_ticks_msec()-started,"revision":REVISION,"options":options.duplicate(true)}
## A single final illustration for a formal object slot; the workbench keeps its passes.
func generate_subject(kind: String, request: Dictionary, options := {}) -> Dictionary:
	if busy: return {"error": "生成器正忙"}
	var error: String = catalog.validate(request)
	if not error.is_empty(): return {"error": error}
	if kind not in ["world", "cult", "person"]: return {"error": "未知立绘种类"}
	var background: Dictionary = {}
	if kind == "person":
		var seed_value = options.get("seed", -1)
		if not People.is_integer(seed_value) or seed_value < 0 or seed_value > 0xffffffff:
			return {"error": "人物种子须为 uint32"}
		background = catalog.formal_background(request.template, str(options.get("profile", "")))
		if background.is_empty(): return {"error": "当前世界不支持这个人物背景"}
	busy = true
	var w: Dictionary = catalog.world_recipe(request)
	await _ensure_world(request, w)
	var image: Image
	match kind:
		"world": image = cached_context.world_image
		"cult":
			await _ensure_cult(w)
			image = cached_context.cult_image
		"person":
			var person: Dictionary = await _draw_person(int(options.seed), w, background)
			image = person.image
	busy = false
	return {"image": image, "revision": REVISION}

func _key(request: Dictionary) -> String:
	return JSON.stringify([REVISION, request.template, request.seed, request.style, request.palette])

func _ensure_world(request: Dictionary, w: Dictionary) -> void:
	var key := _key(request)
	if cache_key == key and not cached_context.is_empty(): return
	progress.emit("生成原作星球与天空…")
	var source: Dictionary = await celestial.generate(w)
	var planet: Image = await post.apply(source.world, w, null, false)
	cached_context = {"world_image": planet, "sky_image": source.sky, "world_recipe": w,
		"request": request.duplicate(true), "world_params": source.params}
	cache_key = key

func _ensure_cult(w: Dictionary) -> void:
	if cached_context.has("cult_image"): return
	progress.emit("构建教团的二维轮廓与材质场…")
	var rule: Dictionary = catalog.cult_rule(w)
	var draw: Dictionary = Tide.sanctuary(w.worldSeed, w) if w.archetype == 0 else Cults.newCult(w, rule)
	draw.p.world = w
	draw.p.styleSid = w.styleSid
	if w.archetype == 0: _tide_palette(draw.p, w)
	var passes: Dictionary = await surfaces.render(draw.p)
	var final: Image = await post.apply(passes.lit, w, cached_context.sky_image, true)
	cached_context.merge({"cult_image": final, "cult_passes": passes, "rule": rule, "cult_features": draw.features})

func _draw_person(seed_value: int, w: Dictionary, background: Dictionary) -> Dictionary:
	var recipe = People.recipe(seed_value, w, background)
	var draw = People.generate(recipe)
	var passes: Dictionary = await surfaces.render(draw.p)
	progress.emit("人物：原作 NPR 后期…")
	var final: Image = await post.apply(passes.lit, w, cached_context.sky_image, true)
	return {"image": final, "passes": passes, "recipe": recipe, "features": draw.features}

func _tide_palette(plan,w):
	if w.palette==0:return
	for e in plan.emitters:e.color=_palette(e.color,w)
	for command in plan.commands:
		if command.has("color") and command.color is String:command.color=_palette(command.color,w)
		if command.has("options"):
			for key in ["color","shadow","accent","glow"]:
				if command.options.get(key) is String:command.options[key]=_palette(command.options[key],w)
func _palette(value,w):
	var c=People.rgb(value)
	var lum=c[0]*.299+c[1]*.587+c[2]*.114
	if c[0]>c[1]*1.15 and c[1]>c[2]*1.25:return c
	if c[2]>c[1]*1.1 and c[0]>c[1]*1.12:return People.mix(w.c0,w.nebula,clampf(lum/95,0,1))
	var stops=[w.c0,w.c1,w.c2,w.c3,w.star]
	var levels=[12,44,78,145,242]
	var i=0
	while i<3 and lum>levels[i+1]:i+=1
	return People.mix(stops[i],stops[i+1],clampf((lum-levels[i])/float(levels[i+1]-levels[i]),0,1))
func invalidate_context():
	cache_key=""
	cached_context={}
static func metadata(result: Dictionary) -> Dictionary:
	return {"revision":result.revision,"scope":"Godot 本体内独立生成；未接 Session","request":result.context.request,"world_recipe":result.context.world_recipe,"world_params":result.context.world_params,"cult_rule":result.context.rule,"options":result.options,"people":result.people.map(func(p):return {"recipe":p.recipe,"features":p.features}),"counts_note":"潮汐 6 类/48 种离散组合；其他世界 4 类/24 种。种子不等于新职业。","reused_world":result.reused_world,"duration_ms":result.duration_ms}
static func export_result(result: Dictionary, folder: String) -> Error:
	var err=DirAccess.make_dir_recursive_absolute(folder)
	if err!=OK:return err
	var images={"world":result.context.world_image,"cult":result.context.cult_image}
	for k in result.context.cult_passes:images["cult-"+k]=result.context.cult_passes[k]
	for i in result.people.size():
		var name="person-%d-%d"%[i,result.people[i].recipe.personSeed]
		images[name]=result.people[i].image
		for k in result.people[i].passes:images[name+"-"+k]=result.people[i].passes[k]
	for name in images:
		err=images[name].save_png(folder.path_join(name+".png"))
		if err!=OK:return err
	var file=FileAccess.open(folder.path_join("parameters.json"),FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(metadata(result),"\t"))
	return OK
