extends SceneTree
const Scene=preload("res://tools/echoes-art-master/scene.tscn")
var app
func _initialize()->void:_run.call_deferred()
func capture(path:String)->void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var result:Error=root.get_texture().get_image().save_png("res://tools/echoes-art-master/evidence/"+path+".png")
 print("RESTORATION_CAPTURE ",path," ",result)
func _run()->void:
 app=Scene.instantiate()
 root.add_child(app)
 await process_frame
 await process_frame
 await capture("restoration-adjusted")
 app.set_reference_layout(true)
 await capture("restoration-reference-layout")
 app.queue_free()
 await process_frame
 quit()
