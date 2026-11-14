extends SceneTree
const Catalog = preload("res://src/simulation/catalog.gd")
const Catalogue = preload("res://tools/card-illustration-study/catalogue.gd")
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_files("res://data"): quit(1); return
	var cards := Catalogue.cards(catalog)
	var groups := {}
	var subjects := {}
	var ids := {}
	for card: Dictionary in cards:
		if ids.has(card.id) or card.title.is_empty():
			push_error("Duplicate/unnamed art catalogue entry "+str(card.id)); quit(1); return
		ids[card.id] = true
		groups[card.catalogue_section] = int(groups.get(card.catalogue_section,0))+1
		var subject := Library.identity(card,str(card.group))
		if subject=="wait" and card.id!="relic/wait":
			push_error("Unmapped semantic identity "+str(card.id)); quit(1); return
		subjects[subject] = true
	var expected := {"powers":12,"activities":16,"relics":6,"previews":6,"actions":12,"events":12}
	if groups!=expected:
		push_error("Art catalogue coverage changed: "+str(groups)); quit(1); return
	if Library.identity({"id":"record/POWER_DREAM"},"power")!="dream" or Library.identity({"entry":"POWER_DREAM"},"power")!="dream":
		push_error("Record/action art identity diverged"); quit(1); return
	# Guard asset assembly, not aesthetics: every sample has a distinct source
	# cell, with square UVs and no reuse of the rejected sculptural atlases.
	var fingerprints := {}
	for variant: int in range(1,Library.FILES.size()):
		var atlas := Image.load_from_file(Library.ASSETS+Library.FILES[variant])
		if atlas==null or atlas.get_size()!=Vector2i(1536,1024):
			push_error("Category sample atlas size invalid"); quit(1); return
		for i: int in Library.SAMPLES.size():
			var region := atlas.get_region(Rect2i(Vector2i(i%3,i/3)*512,Vector2i(512,512)))
			var fingerprint := hash(region.get_data())
			if fingerprints.has(fingerprint):
				push_error("Category samples reuse the same source pixels"); quit(1); return
			fingerprints[fingerprint] = true
			if variant==2 and i in [1,4]:
				# Local pigment visibility only; this is NOT an aesthetic score.
				# Prevent the refined activities from reverting to thin dark traces.
				var readable := 0
				for y: int in 512:
					for x: int in 512:
						var pixel := region.get_pixel(x,y)
						if pixel.r*.2126+pixel.g*.7152+pixel.b*.0722>=.24: readable += 1
				var minimum := .06 if i==1 else .04
				if float(readable)/(512*512)<minimum:
					push_error("Refined activity lost readable pigment area: "+Library.SAMPLES[i]); quit(1); return
	print("ART_MAPPING_OK ",cards.size()," definitions / ",subjects.size()," semantic drawings; ",groups)
	print("CATEGORY_ASSEMBLY_OK ", fingerprints.size()," distinct 512px sample cells; B before/current, visual quality remains human-reviewed")
	quit()
