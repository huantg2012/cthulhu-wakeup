extends Control
## Native development workbench. Deliberately separate from game presentation.
const Service = preload("res://src/art_generation/service.gd")
const SourceData = preload("res://src/art_generation/source/data.gd")
signal generation_finished
var service: Node
var template: OptionButton
var style: OptionButton
var palette: OptionButton
var background: OptionButton
var world_seed: SpinBox
var person_seed: SpinBox
var count: SpinBox
var pass_choice: OptionButton
var status: Label
var summary: Label
var context_row: HBoxContainer
var people_grid: GridContainer
var buttons: Array[Button] = []
var result: Dictionary = {}
var export_dialog: FileDialog
var zoom: Window
var zoom_rect: TextureRect
func _ready():
	get_window().title="诸界立绘生成 · Godot 原生工作台"
	get_window().size=Vector2i(1600,1000)
	get_window().content_scale_size=Vector2i(1600,1000)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("090f14"))
	service=Service.new();add_child(service)
	service.progress.connect(func(message):status.text=message)
	_build()
	_generate.call_deferred()
func _build():
	var theme_new=Theme.new();theme_new.default_font_size=18
	var font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei"]);theme_new.default_font=font;theme=theme_new
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var main=VBoxContainer.new();main.add_theme_constant_override("separation",14);margin.add_child(main)
	var title=Label.new();title.text="诸界 · 世界、教团与祈求者";title.add_theme_font_size_override("font_size",30);main.add_child(title)
	var note=Label.new();note.text="Godot 工程内实时生成  /  独立美术工作台  /  未接入游戏 Session";note.modulate=Color("91a8b6");main.add_child(note)
	var first=HBoxContainer.new();first.add_theme_constant_override("separation",16);main.add_child(first)
	template=_option(first,"世界原型")
	for row in service.catalog.templates:template.add_item(SourceData.ARCHETYPES[int(row.archetype)].name)
	template.item_selected.connect(_world_changed)
	style=_option(first,"美术风格（原作 sid）")
	for row in SourceData.STYLES:style.add_item(row.name+" · "+str(row.sid),row.sid)
	palette=_option(first,"色板")
	for row in SourceData.PALETTES:palette.add_item(row.name)
	world_seed=_number(first,"世界种子",999999,1339)
	_button(first,"生成这一组",_generate)
	_button(first,"世界下一种子",func():world_seed.value=fmod(world_seed.value+1,1000000);_generate())
	var second=HBoxContainer.new();second.add_theme_constant_override("separation",16);main.add_child(second)
	background=_option(second,"人物背景")
	person_seed=_number(second,"人物独立种子",4294967295,1000)
	count=_number(second,"人物数量",8,4);count.min_value=1;count.custom_minimum_size.x=90
	_button(second,"只换人物",func():person_seed.value=fmod(person_seed.value+count.value,4294967296.0);_generate())
	_button(second,"同参重绘",func():service.invalidate_context();_generate())
	pass_choice=_option(second,"查看绘制阶段")
	for text in ["最终 NPR","完整受光","材料色","形体受光"]:pass_choice.add_item(text)
	pass_choice.item_selected.connect(func(_i):_show_result())
	_button(second,"导出 PNG 与参数",_export)
	status=Label.new();status.text="准备生成…";status.modulate=Color("c3d9ce");main.add_child(status)
	summary=Label.new();summary.modulate=Color("91a8b6");main.add_child(summary)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(scroll)
	var gallery=VBoxContainer.new();gallery.size_flags_horizontal=Control.SIZE_EXPAND_FILL;gallery.add_theme_constant_override("separation",24);scroll.add_child(gallery)
	context_row=HBoxContainer.new();context_row.add_theme_constant_override("separation",20);gallery.add_child(context_row)
	people_grid=GridContainer.new();people_grid.columns=4;people_grid.add_theme_constant_override("h_separation",18);people_grid.add_theme_constant_override("v_separation",24);gallery.add_child(people_grid)
	export_dialog=FileDialog.new();export_dialog.access=FileDialog.ACCESS_FILESYSTEM;export_dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR;export_dialog.title="选择导出目录";export_dialog.size=Vector2i(850,600);add_child(export_dialog);export_dialog.dir_selected.connect(_save)
	zoom=Window.new();zoom.title="立绘原图";zoom.size=Vector2i(980,980);zoom.visible=false;zoom.close_requested.connect(func():zoom.hide());add_child(zoom)
	zoom_rect=TextureRect.new();zoom_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);zoom_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;zoom_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;zoom.add_child(zoom_rect)
	_world_changed(0)
func _option(parent: Node,label: String) -> OptionButton:
	var box=VBoxContainer.new();parent.add_child(box);var text=Label.new();text.text=label;text.add_theme_font_size_override("font_size",15);box.add_child(text);var button=OptionButton.new();button.custom_minimum_size=Vector2(160,40);box.add_child(button);return button
func _number(parent: Node,label: String,max_value: float,value: float) -> SpinBox:
	var box=VBoxContainer.new();parent.add_child(box);var text=Label.new();text.text=label;text.add_theme_font_size_override("font_size",15);box.add_child(text);var field=SpinBox.new();field.min_value=0;field.max_value=max_value;field.step=1;field.value=value;field.custom_minimum_size=Vector2(150,40);box.add_child(field);return field
func _button(parent: Node,text: String,action: Callable):
	var button=Button.new();button.text=text;button.custom_minimum_size.y=40;button.size_flags_vertical=Control.SIZE_SHRINK_END;button.pressed.connect(action);parent.add_child(button);buttons.append(button)
func _world_changed(index: int):
	var id=service.catalog.templates[index].id
	background.clear();background.add_item("按背景轮换")
	for b in service.catalog.backgrounds(id):background.add_item(b.role+" · "+b.title)
	palette.select(service.catalog.cults[index].default_palette)
func _generate():
	if service.busy:return
	var t=service.catalog.templates[template.selected].id
	var bs=service.catalog.backgrounds(t)
	var request={"template":t,"seed":int(world_seed.value),"style":style.get_selected_id(),"palette":palette.selected}
	var options={"seed":int(person_seed.value),"count":int(count.value),"background":"all" if background.selected==0 else bs[background.selected-1].caseId}
	_busy(true)
	var generated=await service.generate(request,options)
	_busy(false)
	if generated.has("error"):status.text=generated.error;return
	result=generated
	_show_result()
	generation_finished.emit()
func _busy(value: bool):
	for b in buttons:b.disabled=value
	for o in [template,style,palette,background]:o.disabled=value
	for n in [world_seed,person_seed,count]:n.editable=not value
func _show_result():
	if result.is_empty():return
	for container in [context_row,people_grid]:
		for child in container.get_children():container.remove_child(child);child.queue_free()
	var w=result.context.world_recipe
	var rule=result.context.rule
	var totals=service.catalog.counts(result.context.request.template)
	summary.text="%s · %s · 世界种子 %d · sid %d · 色板 %s  |  %d 类背景 / %d 种离散组合  |  %s"%[SourceData.ARCHETYPES[w.archetype].name,rule.institution,w.worldSeed,w.styleSid,SourceData.PALETTES[w.palette].name,totals.backgrounds,totals.discreteCombinations,"世界与教团沿用" if result.reused_world else "重新生成世界与教团"]
	_card(context_row,result.context.world_image,"世界 · "+SourceData.ARCHETYPES[w.archetype].name,"旧日星图原算法 · seed "+str(w.worldSeed),360)
	_card(context_row,_image(result.context.cult_image,result.context.cult_passes),"候选教团 · "+rule.institution,rule.activity+" · "+rule.material,360)
	for person_index in result.people.size():
		var p=result.people[person_index]
		var expression={"masculine":"偏男性","feminine":"偏女性","androgynous":"中性表达"}[p.features.genderExpression]
		_card(context_row if person_index<2 else people_grid,_image(p.image,p.passes),p.features.role+" · "+str(p.recipe.personSeed),p.features.silhouette+"\n"+expression+" · "+p.features.pose,360)
func _image(final: Image,passes: Dictionary) -> Image:
	return final if pass_choice.selected==0 else passes[["lit","material","form"][pass_choice.selected-1]]
func _card(parent: Node,img: Image,title: String,caption: String,width: float):
	var box=VBoxContainer.new();box.custom_minimum_size.x=width;parent.add_child(box)
	var picture=TextureRect.new();picture.texture=ImageTexture.create_from_image(img);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=Vector2(width,width);box.add_child(picture)
	picture.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:zoom_rect.texture=picture.texture;zoom.title=title;zoom.popup_centered())
	var heading=Label.new();heading.text=title;box.add_child(heading)
	var detail=Label.new();detail.text=caption;detail.add_theme_font_size_override("font_size",14);detail.modulate=Color("91a8b6");detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size.x=width;box.add_child(detail)
func _export():
	if result.is_empty():return
	export_dialog.popup_centered()
func _save(folder: String):
	var target=folder.path_join("godot-art-"+Time.get_datetime_string_from_system().replace(":","-"))
	var error=Service.export_result(result,target)
	status.text="已导出："+target if error==OK else "导出失败："+error_string(error)
