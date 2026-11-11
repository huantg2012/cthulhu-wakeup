extends "res://src/art_generation/algorithms/drawing_math.gd"
const World = preload("res://src/art_generation/algorithms/world.gd")
const Figure = preload("res://src/art_generation/algorithms/figure_grammar.gd")
const Civilian = preload("res://src/art_generation/algorithms/civilian.gd")
const WorldPerson = preload("res://src/art_generation/algorithms/world_person.gd")
const EnvironmentPerson = preload("res://src/art_generation/algorithms/person_environment.gd")
const Portrait = preload("res://src/art_generation/algorithms/portrait.gd")
static func _between(r,a,b): return lerpf(a,b,r.call())
static func recipe(person_seed: int, world: Dictionary, background: Dictionary) -> Dictionary:
	assert(person_seed>=0 and person_seed<=0xffffffff,"Person seed must be uint32")
	var version = "tide-people-3" if world.archetype == 0 else "world-people-1"
	var stream = func(name):return rng(seedOf([version,person_seed,name]))
	var body = stream.call("body")
	var head = stream.call("head")
	var pose = stream.call("gesture")
	var cloth = stream.call("garment")
	var pigment = stream.call("pigment")
	var d = {"width":_between(body,.84,1.20),"height":_between(body,.94,1.04),"lean":_between(body,-.065,.065),"shoulderSlope":_between(body,-.11,.11),"headTilt":_between(head,-.18,.18),"headWidth":_between(head,.88,1.09),"headShift":_between(head,-12,12),"crown":_between(head,-15,15),"capRise":head.call(),"hairTone":head.call(),"gripX":_between(pose,-22,22),"gripY":_between(pose,-35,38),"elbowSpread":_between(pose,-20,18),"elbowDrop":_between(pose,-12,12),"mantle":_between(cloth,18,140),"panel":_between(cloth,35,116),"panelSlant":_between(cloth,-30,30),"veil":cloth.call(),"border":_between(cloth,.1,.95),"hem":cloth.call(),"dye":pigment.call(),"linen":pigment.call(),"panelDye":pigment.call(),"tension":_between(cloth,.85,1.15),"sleeve":cloth.call()}
	var gender = stream.call("gender-expression").call()
	d.presentation = gender*.28 if background.genderRule == "male" else gender
	d.handScale = 1.05-d.presentation*.2
	d.width *= lerpf(1.04,.91,d.presentation)
	d.headWidth *= lerpf(1.04,.96,d.presentation)
	d.elbowSpread = maxf(d.elbowSpread,-22+(d.width-1)*30)
	var choose = func(values,name):return values[int(floor(stream.call(name).call()*values.size()))]
	var construction = {"civilian":true,"head":choose.call(background.heads,"head-construction"),"garment":choose.call(background.garments,"garment-construction"),"gesture":choose.call(background.gestures,"situational-gesture"),"held":"none"}
	if world.archetype != 0:
		d.viewPitch = .28+body.call()*.08
		d.headLift = .35+head.call()*.5
		d.sleeve *= .55 if world.archetype == 4 else 1
		d.cover = cloth.call()
	return {"version":version if world.archetype in [0,4,5] else "unified-people-1","world":world.duplicate(true),"personSeed":person_seed,"background":background.duplicate(true),"dimensions":d,"construction":construction}
static func generate(r: Dictionary) -> Dictionary:
	var w = r.world
	var d = r.dimensions
	var k = r.construction
	var b = r.background
	var c = World.roles(w)
	var pigments = {"ochre":mix("#aa8b50",w.c3,.3),"linen":mix("#a8ad9d",w.c3,.25),"umber":mix("#795b43",w.c3,.19),"ink":mix("#353e4e",w.nebula,.12),"slate":mix("#5d7274",w.c2,.2)}
	var base = pigments[b.pigment]
	var outer = mix(base,c.salt,d.dye*.26)
	var shirt = mix(c.linen,"#bab8a6",.35+d.linen*.2)
	c.merge({"outer":outer,"cloth":mix(shirt,w.c1,.18) if k.garment in ["apron","jerkin","waistcoat"] else outer,"clothShadow":mix(w.c0,base,.2),"linen":shirt,"violet":mix(w.nebula,w.c0,.7),"hair":mix("#34312b","#867768",d.hairTone*.7)},true)
	var config = {"colors":c,"layers":{},"tension":d.tension,"emitters":[],"dimensions":d,"styleSid":w.styleSid}
	var anatomy = Figure.configureFigure(config,r,c)
	Civilian.configureCivilian(config,r,c)
	if w.archetype in [4,5]: WorldPerson.configureWorldPerson(config,r,c,w)
	elif w.archetype != 0: EnvironmentPerson.configureEnvironmentPerson(config,r,c,w)
	var result = Portrait.portrait(r.personSeed,w.worldSeed,w,config)
	result.features.merge({"recipe":r,"role":b.role,"caseTitle":b.title,"pose":anatomy.gesture,"silhouette":Civilian.OUTFIT_NAMES[k.garment]+" · "+Civilian.HEAD_NAMES[k.head],"genderExpression":"masculine" if d.presentation<.34 else "feminine" if d.presentation>.66 else "androgynous","scope":"独立立绘；未绑定 Session"},true)
	config.clear() # Release mutually captured drawing hooks after command construction.
	return result
