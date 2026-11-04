extends RefCounted
## Read an installed font; never copy or embed it into a saved scene/asset.
const TTC := "/System/Library/Fonts/Supplemental/Songti.ttc"
static func regular() -> Font:
	if FileAccess.file_exists(TTC):
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(TTC)
		if bytes.size()>40 and bytes.slice(0,4).get_string_from_ascii()=="ttcf":
			var count:int=(int(bytes[8])<<24)|(int(bytes[9])<<16)|(int(bytes[10])<<8)|int(bytes[11])
			if count>6:
				# Godot 4.7.2 selects Black even when TTC face6 is requested.
				# Redirect only the in-memory first face pointer to SC Regular.
				for i:int in range(4):bytes[12+i]=bytes[36+i]
				var font:=FontFile.new()
				font.data=bytes
				if font.get_font_style_name()=="Regular" and font.has_char("远".unicode_at(0)):
					return font
	var fallback:=SystemFont.new()
	fallback.font_names=PackedStringArray(["Noto Serif CJK SC","Source Han Serif SC","Songti SC","STSong"])
	fallback.font_weight=400
	fallback.allow_system_fallback=true
	return fallback
