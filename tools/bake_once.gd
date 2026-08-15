extends SceneTree
## Headless: run one Bake and quit so ToolpathPreview mesh is saved for the editor.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("BAKE_FAIL load main")
		quit(1)
		return
	var root: Node = packed.instantiate()
	root.name = "Main"
	get_root().add_child(root)
	# Give Part collision + deferred bake time.
	for i in 30:
		await process_frame
	var preview := root.get_node_or_null("ToolpathPreview") as MeshInstance3D
	if preview == null or preview.mesh == null:
		push_error("BAKE_FAIL no preview mesh")
		quit(2)
		return
	var vc := 0
	if preview.mesh.get_surface_count() > 0:
		var arr = preview.mesh.surface_get_arrays(0)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			vc = arr[Mesh.ARRAY_VERTEX].size()
	print("BAKE_OK preview_verts=", vc)
	quit(0)
