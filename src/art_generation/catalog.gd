extends RefCounted
## Read-only adapter to authored CSVs. Does not construct game NPCs or institutions.
const SourceData = preload("res://src/art_generation/source/data.gd")
var templates = []
var cults = []
var contexts = []
var world_rules = []
var environments = []
var person_profiles: Dictionary = {}
func _init():
	templates = read_csv("res://data/art_world_templates.csv")
	cults = read_csv("res://data/cult_visual_rules.csv")
	world_rules = read_csv("res://data/portrait_world_rules.csv")
	environments = read_csv("res://data/portrait_environment_rules.csv")
	var cases = {}
	for row in read_csv("res://data/prayer_space_cases.csv"): cases[row.id] = row
	for row in read_csv("res://data/portrait_context_rules.csv"):
		var source = cases[row.case_id]
		contexts.append({"caseId":source.id,"role":source.petitioner,"frame":source.frame,"scene":source.scene,"title":source.title,"context":source.context,"appeal":source.appeal,"goal":source.goal,"garments":Array(row.garments.split("|")),"heads":Array(row.heads.split("|")),"gestures":Array(row.gestures.split("|")),"material":row.material,"pigment":row.pigment,"workDetail":row.work_detail,"genderRule":row.gender_rule,"appearanceNote":row.appearance_note})
	for row: Dictionary in read_csv("res://data/art_person_profiles.csv"):
		person_profiles[row.profile_id] = row
	for row in cults:
		row.archetype = int(row.archetype)
		row.default_palette = int(row.default_palette)
static func read_csv(path: String) -> Array:
	var f = FileAccess.open(path,FileAccess.READ)
	assert(f != null,"Missing authored art data: "+path)
	var headers = f.get_csv_line()
	var out = []
	while not f.eof_reached():
		var values = f.get_csv_line()
		if values.size() == 1 and values[0].is_empty(): continue
		assert(values.size()==headers.size(),"Malformed art CSV: "+path)
		var row = {}
		for i in headers.size(): row[headers[i]] = values[i]
		out.append(row)
	return out
func backgrounds(template: String) -> Array:
	if template == "tide": return contexts.duplicate(true)
	var out = []
	for rule in world_rules:
		if rule.template != template: continue
		for base in contexts:
			if base.caseId != rule.case_id: continue
			var b = base.duplicate(true)
			b.worldRule = rule.duplicate(true)
			for k in ["garments","heads","gestures"]: b[k] = Array(rule[k].split("|"))
			for e in environments:
				if e.template == template: b.environment = e.duplicate(true)
			out.append(b)
	return out
func formal_background(template: String, profile: String) -> Dictionary:
	if not person_profiles.has(profile): return {}
	var rule: Dictionary = person_profiles[profile]
	for candidate: Dictionary in backgrounds(template):
		if candidate.caseId != rule.cut_basis: continue
		candidate.gestures = Array(str(rule.gestures).split("|"))
		candidate.pigment = rule.pigment
		candidate.workDetail = ""
		candidate.genderRule = "any"
		candidate.role = profile
		candidate.title = ""
		return candidate
	return {}

func counts(template: String) -> Dictionary:
	var all = backgrounds(template)
	var combos = 0
	for b in all: combos += b.garments.size()*b.heads.size()*b.gestures.size()
	return {"backgrounds":all.size(),"discreteCombinations":combos}
func validate(request: Dictionary) -> String:
	for k in ["template","seed","style","palette"]:
		if not request.has(k): return "缺少世界参数："+k
	if not request.template in templates.map(func(t):return t.id): return "未知的世界原型"
	if not request.style in SourceData.STYLES.map(func(s):return s.sid): return "无效的原作画风 sid"
	for k in ["seed","palette"]:
		if not (request[k] is int or request[k] is float) or request[k] != floor(request[k]): return "参数必须是整数："+k
	if request.seed<0 or request.seed>999999: return "世界种子须为 0–999999"
	if request.palette<0 or request.palette>=SourceData.PALETTES.size(): return "无效色板"
	return ""
func world_recipe(request: Dictionary) -> Dictionary:
	assert(validate(request).is_empty(),validate(request))
	var identity: Dictionary
	for row in templates:
		if row.id == request.template: identity = row
	var pal = SourceData.PALETTES[int(request.palette)]
	var sid_index = SourceData.STYLES.map(func(s):return s.sid).find(request.style)
	var w = {"version":"godot-surface-1","archetype":int(identity.archetype),"template":request.template,"worldSeed":int(request.seed),"palette":int(request.palette),"styleSid":int(request.style),"styleIndex":sid_index,"nebula":"#"+pal.neb[2],"star":"#"+pal.star[0],"corruption":"#"+pal.cor[1]}
	for i in 5: w["c%d"%i]="#"+pal.c[i]
	return w
func cult_rule(world: Dictionary) -> Dictionary:
	return cults[int(world.archetype)].duplicate(true)
