extends "res://src/presentation/production/worldplay/study_card.gd"
## Read-only portrait adapter for the retained preparation / related-reading
## surfaces. The host keeps its bounds, public identity and existing navigation.

func build(bounds: Rect2, kind: String, caption: String, recipe: Dictionary, font_extra: int) -> TextureRect:
	var width := minf(bounds.size.x, bounds.size.y / 1.48)
	size = Vector2(width, width * 1.48)
	position = bounds.position + (bounds.size - size) * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	hover_enabled = false
	palette = kind
	var sample := {
		"kind": {"world": "世界", "cult": "教团", "person": "人物"}.get(kind, "人物"),
		"category_id": kind, "art_kind": kind, "title": caption,
		"line1": "", "line2": "", "identity_variant": 2,
		"paper_backed": int(recipe.get("request", {}).get("style", -1)) in [2, 6],
	}
	# Long copy remains in the surrounding reading area. The carrier supplies
	# only the object's name, with a full accessibility / tooltip alternative.
	var image := configure_carrier(sample, null, {
		"title_font_size": (18 if width >= 170.0 else 14) + font_extra,
		"title_max_lines": 2, "font_extra": font_extra,
	})
	accessibility_name = caption
	tooltip_text = caption
	return image
