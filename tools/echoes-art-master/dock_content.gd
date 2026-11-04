extends "res://src/presentation/ui/dock_content.gd"
## Isolated art fixture only. Shared controls contain no fixture state.

static func build(app: Control, box: Control, bounds: Rect2) -> void:
	var awakened := int(app.fixture_state.awakening)
	var unlocked := 0
	for key: String in app.POWER_ICONS:
		if int(app.catalog.tables.powers["POWER_"+key.to_upper()].unlock_awakening) <= awakened: unlocked += 1
	app._label(box,"PowerHeading","权能",Rect2(bounds.position.x+20,48,65,30),22,app.GOLD,true)
	app._label(box,"PowerCount","%d/%d"%[unlocked,app.POWER_ICONS.size()],Rect2(bounds.position.x+73,53,60,25),16,app.MUTED)
	var powers := _scroll(app.components,box,"PowerScroll",Rect2(bounds.position.x+138,20,614,100))
	var power_row: HBoxContainer = powers.row
	var power_scroll: ScrollContainer = powers.scroll
	for key: String in app.POWER_ICONS:
		var id := "POWER_"+key.to_upper()
		var data: Dictionary = app.catalog.tables.powers[id]
		var locked := int(data.unlock_awakening) > awakened
		var button := power_entry(app.components,power_row,id,data,locked,func(): app.open_power(id))
		var base := Color(0.55,0.58,0.60,0.95) if locked else Color.WHITE
		bind_icon(button,button.get_node("Icon"),func() -> bool: return app.keyboard_input,power_scroll,base)
	var relic_total := maxi(0,int(app.fixture_state.relics))
	app._label(box,"RelicHeading","圣物",Rect2(bounds.position.x+788,48,70,30),22,app.GOLD,true)
	app._label(box,"RelicCount","",Rect2(bounds.position.x+848,53,30,22),14,app.MUTED)
	if relic_total == 0:
		app._label(box,"RelicEmpty","尚无圣物",Rect2(bounds.position.x+875,38,240,55),20,app.MUTED)
		return
	var relics := _scroll(app.components,box,"RelicScroll",Rect2(bounds.position.x+875,20,531,100))
	var relic_row: HBoxContainer = relics.row
	var relic_scroll: ScrollContainer = relics.scroll
	for i: int in range(relic_total):
		var id: String = RELIC_IDS[i%RELIC_IDS.size()]
		var state: String = ["绑定","携带","携带","保管"][i] if i<4 else ("绑定" if i%4==0 else ("保管" if i%3==0 else "携带"))
		var button := relic_entry(app.components,relic_row,i,str(app.catalog.tables.relics[id].name),state,app.open_relics)
		bind_icon(button,button.get_node("Icon"),func() -> bool: return app.keyboard_input,relic_scroll)
