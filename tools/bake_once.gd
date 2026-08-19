extends SceneTree
## Headless smoke: BarMesh tool-surface only.

func _init() -> void:
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
	for i in 5:
		await process_frame
	var stats: Dictionary = await root.bake_strategy("barmesh", 1.5)
	if stats.is_empty() or stats.get("strategy", "") != "barmesh":
		push_error("BAKE_FAIL barmesh stats: " + str(stats))
		quit(4)
		return
	var preview := root.get_node_or_null("BarMeshPreview") as MeshInstance3D
	if preview == null or preview.mesh == null:
		push_error("BAKE_FAIL no BarMeshPreview mesh")
		quit(2)
		return
	var vertex_count := 0
	for surface in preview.mesh.get_surface_count():
		var arr = preview.mesh.surface_get_arrays(surface)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			vertex_count += arr[Mesh.ARRAY_VERTEX].size()
	if vertex_count == 0:
		push_error("BAKE_FAIL empty BarMesh preview")
		quit(5)
		return
	print("ASSET_PROOF strategy=barmesh preview_verts=", vertex_count)
	print("BAKE_OK strategy=barmesh preview_verts=", vertex_count)
	quit(0)
