extends SceneTree
## Fast construction checks; no aesthetic approval and no 66-combination render.
func _init():
	var catalog=load("res://src/art_generation/catalog.gd").new()
	var people=load("res://src/art_generation/algorithms/people.gd")
	var tide=load("res://src/art_generation/algorithms/sanctuary.gd")
	var cults=load("res://src/art_generation/algorithms/cult_scenes.gd")
	for row in catalog.templates:
		var request={"template":row.id,"seed":1339,"palette":0,"style":0}
		var w=catalog.world_recipe(request)
		var cult=tide.sanctuary(w.worldSeed,w) if w.archetype==0 else cults.newCult(w,catalog.cult_rule(w))
		assert(cult.p.layers>20,"Incomplete institution drawing")
		var all=catalog.backgrounds(row.id)
		for i in all.size():
			var r=people.recipe(1000+i,w,all[i])
			var again=people.recipe(1000+i,w,all[i])
			assert(JSON.stringify(r)==JSON.stringify(again),"Recipe must reproduce")
			var drawn=people.generate(r)
			assert(drawn.p.layers>15,"Incomplete character drawing")
		print(row.id," ",catalog.counts(row.id)," cult surfaces=",cult.p.layers)
	print("RULE_CONSTRUCTION_COMPLETE")
	quit()
