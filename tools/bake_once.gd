extends SceneTree
## Headless smoke bake. Usage: -- --strategy=raster|waterline

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var strategy := "waterline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="):
			strategy = arg.trim_prefix("--strategy=")
	if strategy != "raster" and strategy != "waterline":
		push_error("BAKE_FAIL unknown strategy: " + strategy)
		quit(3)
		return
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
	var stats: Dictionary = await root.bake_strategy(strategy, 1.5, 2.0, 1.0, 2.0)
	if stats.is_empty():
		push_error("BAKE_FAIL empty stats for " + strategy)
		quit(4)
		return
	var preview := root.get_node_or_null("ToolpathPreview") as MeshInstance3D
	if preview == null or preview.mesh == null:
		push_error("BAKE_FAIL no preview mesh")
		quit(2)
		return
	var vertex_count := 0
	for surface in preview.mesh.get_surface_count():
		var arr = preview.mesh.surface_get_arrays(surface)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			vertex_count += arr[Mesh.ARRAY_VERTEX].size()
	if vertex_count == 0:
		push_error("BAKE_FAIL empty preview for " + strategy)
		quit(5)
		return
	if strategy == "waterline":
		var levels: Array = stats.get("cut_levels", [])
		var descending := levels.size() > 0
		for i in range(1, levels.size()):
			if levels[i] >= levels[i - 1]:
				descending = false
				break
		var contours: int = stats.get("contour_count", 0)
		var closed: int = stats.get("closed_count", 0)
		if levels.is_empty() or contours == 0 or closed != contours or not descending:
			push_error("BAKE_FAIL implausible waterline stats: " + str(stats))
			quit(6)
			return
		print(
			"WATERLINE_PROOF levels=", levels.size(),
			" contours=", contours,
			" closed=", closed,
			" descending=", descending,
			" top_y=", levels[0],
			" bottom_y=", levels[levels.size() - 1]
		)
	print("BAKE_OK strategy=", strategy, " preview_verts=", vertex_count)
	quit(0)
