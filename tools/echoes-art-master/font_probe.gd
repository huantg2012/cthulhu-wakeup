extends SceneTree
## Read-only runtime font resolution diagnostic. No system font is copied.
func _initialize() -> void:
	var report: Array[Dictionary] = []
	for family: String in ["Songti SC","PingFang SC","Heiti SC"]:
		var font := SystemFont.new()
		font.font_names = PackedStringArray([family])
		font.allow_system_fallback = true
		report.append({"requested":family,"resolved":font.get_font_name(),"available":OS.get_system_fonts().has(family),"supports_yuan":font.has_char("远".unicode_at(0))})
	var output := FileAccess.open("res://tools/echoes-art-master/evidence/font-resolution.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print(JSON.stringify(report))
	quit()
