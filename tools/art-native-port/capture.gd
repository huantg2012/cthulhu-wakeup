extends SceneTree
## Native, bounded migration evidence. No browser or image server.
const OUT = "res://docs/art/visual-generation/procedural-study/native-evidence"
func _init():run.call_deferred()
func run():
	var service=load("res://src/art_generation/service.gd").new();root.add_child(service)
	service.progress.connect(func(message):print(message))
	var records=[]
	for job in [{"id":"tide","template":"tide","palette":0,"style":0,"count":1,"background":"judge_letter"},{"id":"frozen","template":"frozen","palette":4,"style":0,"count":4,"background":"all"},{"id":"fire","template":"fire","palette":6,"style":0,"count":4,"background":"all"},{"id":"bone-watercolor","template":"bone","palette":8,"style":6,"count":1,"background":"judge_letter"}]:
		if "--cold-fire-only" in OS.get_cmdline_user_args() and not job.id in ["frozen","fire"]:continue
		var result=await service.generate({"template":job.template,"seed":1339,"palette":job.palette,"style":job.style},{"seed":1000,"count":job.count,"background":job.background})
		assert(not result.has("error"),str(result.get("error")))
		assert(service.export_result(result,ProjectSettings.globalize_path(OUT.path_join(job.id)))==OK)
		records.append(service.metadata(result))
		if job.id=="tide":
			var again=await service.generate(result.context.request,{"seed":1000,"count":1,"background":"judge_letter"})
			var repeat=_hash(result.people[0].image)==_hash(again.people[0].image)
			assert(repeat,"Same recipe must reproduce final pixels")
			var changed=await service.generate(result.context.request,{"seed":1001,"count":1,"background":"judge_letter"})
			assert(changed.reused_world)
			assert(_hash(result.context.world_image)==_hash(changed.context.world_image))
			assert(_hash(result.context.cult_image)==_hash(changed.context.cult_image))
			assert(_hash(result.people[0].image)!=_hash(changed.people[0].image))
			var f=FileAccess.open(OUT.path_join("invariants.json"),FileAccess.WRITE)
			f.store_string(JSON.stringify({"same_parameters_final_pixels_equal":repeat,"person_seed_changes_visible_pixels":true,"world_and_cult_unchanged":true,"scope":"tide 1339 / palette 0 / sid 0 / judge 1000→1001; same machine and renderer"},"\t"))
	if not "--cold-fire-only" in OS.get_cmdline_user_args():
		var f=FileAccess.open(OUT.path_join("samples.json"),FileAccess.WRITE);f.store_string(JSON.stringify(records,"\t"))
	print("NATIVE_EVIDENCE_COMPLETE")
	quit()
func _hash(image: Image):
	var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(image.get_data());return h.finish().hex_encode()
