extends SceneTree
## Focused regression for prebuilt cards binding an already prepared texture.
## Synthetic cache only: no Session, saved game, generator or disk-cache writes.
const Portraits = preload("res://src/presentation/production/painted/object_portraits.gd")

func _initialize() -> void:
	var portraits := Portraits.new()
	var first := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	var second := ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_RGBA8))
	portraits._textures = {"first": first, "second": second}
	var slot := TextureRect.new()
	var note := Label.new()
	portraits.bind(slot, {"key": "first"}, note)
	if not _check(slot.texture == first and not note.visible, "Prebuilt cache hit was not displayed synchronously"): return
	portraits.bind(slot, {"key": "second"}, note)
	portraits._display(weakref(slot), weakref(note), "first", first)
	if not _check(slot.texture == second, "Stale-key delivery replaced a rebound portrait"): return
	slot.queue_free()
	portraits._display(weakref(slot), weakref(note), "second", first)
	if not _check(slot.texture == second, "Queued-for-deletion portrait accepted a late result"): return
	note.free()
	portraits.free()
	print("PORTRAIT_BINDING_OK prebuilt synchronous cache hit; stale key rejected; queued deletion rejected")
	quit()

func _check(value: bool, message: String) -> bool:
	if value: return true
	push_error(message)
	quit(1)
	return false
