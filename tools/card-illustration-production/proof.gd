extends "res://tools/card-illustration-study/full_deck/proof.gd"
## Native review using the same frozen resources as the formal Session.
const Library = preload("res://src/presentation/production/worldplay/illustrations/library.gd")
const DEST := "res://docs/art/visual-generation/card-illustration-study/painted-deck/"
func face(parent: Node, entry: Dictionary, box: Rect2, note := "暗黑厚涂 · 固化成品") -> Control:
	if "构形" in note: note="暗黑厚涂 · 固化成品"
	var card := Carrier.new()
	card.position = box.position
	card.configure({"category_id":entry.category,"title":entry.title,"line1":note},Stock,
		Library.texture(0,entry.illustration_key),box.size,{"title_font_size":20 if box.size.x < 250 else 24,"body_font_size":14})
	parent.add_child(card)
	return card
func capture(filename: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(DEST+filename)==OK)
func export_cards() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(336,496)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder:=Control.new()
	holder.theme=Paint.native_theme()
	viewport.add_child(holder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"cards"))
	for entry: Dictionary in entries:
		var card:=face(holder,entry,Rect2(8,8,320,480))
		await process_frame
		RenderingServer.force_draw(false)
		assert(viewport.get_texture().get_image().save_png(DEST+"cards/"+str(entry.id).replace("/","__")+".png")==OK)
		holder.remove_child(card)
		card.queue_free()
	viewport.queue_free()
func show_context() -> void:
	super.show_context()
	for child: Node in page.get_children():
		if not child is Label: continue
		if child.text.begins_with("上排前三张"):
			child.text="上排前三张为原生成图；其余为正式固化图。后期共用原生成器暗黑厚涂 sid 0；卡壳、肩签、厚度不变。"
		elif child.text.begins_with("原图参数"):
			child.text="原图：tide / seed 1339；人物 seed 1000。新图：71 幅离线固化，正式 Session 只加载，不重新绘制。"

func show_sheet(index: int) -> void:
	super.show_sheet(index)
	for child: Node in page.get_children():
		if child is Label:
			child.text=child.text.replace("逐卡构形 / ","正式固化立绘 / ").replace("构形待确认，未替换正式游戏","原生成器厚涂后期，已接入正式游戏").replace("构形审阅用目录","全目录美术阅览")

func show_hand() -> void:
	super.show_hand()
	for card: Node in page.find_children("*","Control",true,false):
		if card is Label and card.text=="构形稿": card.text="固化成品"
