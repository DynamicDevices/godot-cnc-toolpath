class_name ToolpathAnimation
extends RefCounted
## Separate module: turn toolpath points (or a line mesh's vertices) into an Animation.

static func from_points(
	points: PackedVector3Array,
	tool_node_path: NodePath,
	feed_units_per_sec: float
) -> Animation:
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, tool_node_path)
	if points.is_empty():
		anim.length = 0.0
		return anim
	var t := 0.0
	var prev: Vector3 = points[0]
	anim.track_insert_key(track, t, prev)
	for i in range(1, points.size()):
		var cur: Vector3 = points[i]
		t += maxf(prev.distance_to(cur) / maxf(feed_units_per_sec, 1e-6), 0.01)
		anim.track_insert_key(track, t, cur)
		prev = cur
	anim.length = t
	anim.resource_name = "raster_toolpath"
	return anim

static func from_line_mesh(
	line_mesh: ArrayMesh,
	tool_node_path: NodePath,
	feed_units_per_sec: float
) -> Animation:
	var points := PackedVector3Array()
	if line_mesh and line_mesh.get_surface_count() > 0:
		var arr = line_mesh.surface_get_arrays(0)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			points = arr[Mesh.ARRAY_VERTEX]
	return from_points(points, tool_node_path, feed_units_per_sec)
