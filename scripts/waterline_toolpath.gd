class_name WaterlineToolpath
extends RefCounted
## Constant-height ("Z-level" in CNC terms) contours from horizontal mesh slices.
## Godot uses +Y as the machining height, with each contour living in XZ.

const EPS := 1e-8

static func compute(
	mesh_inst: MeshInstance3D,
	tool_radius: float,
	z_stepdown: float,
	sample_step: float,
	floor_y: float,
	safe_y: float
) -> Dictionary:
	var triangles: Array = _world_triangles(mesh_inst)
	var path_mesh := ArrayMesh.new()
	var contour_mesh := ArrayMesh.new()
	var all_points := PackedVector3Array()
	var cut_levels: Array[float] = []
	var contour_count := 0
	var closed_count := 0
	if triangles.is_empty():
		return _result(path_mesh, contour_mesh, all_points, cut_levels, contour_count, closed_count)

	var bounds := _world_y_bounds(mesh_inst)
	var top_y: float = bounds["max_y"]
	var bottom_y: float = maxf(floor_y, bounds["min_y"])
	var join_tolerance := maxf(sample_step * 0.05, 1e-7)
	var previous_end := Vector2.ZERO
	var have_previous := false

	for level_y in _levels_top_down(top_y, bottom_y, z_stepdown):
		var segments := _slice_segments(triangles, level_y)
		var contours := _join_segments(segments, join_tolerance)
		var compensated: Array[PackedVector2Array] = []
		for contour in contours:
			var loop: PackedVector2Array = contour
			if loop.size() < 3 or loop[0].distance_to(loop[loop.size() - 1]) > join_tolerance:
				continue
			loop.remove_at(loop.size() - 1)
			var offset_loops: Array[PackedVector2Array] = Geometry2D.offset_polygon(
				loop, tool_radius, Geometry2D.JOIN_MITER
			)
			for offset_loop in offset_loops:
				if offset_loop.size() >= 3:
					compensated.append(_resample_closed(offset_loop, sample_step))

		if compensated.is_empty():
			continue
		cut_levels.append(level_y)
		compensated = _order_nearest(compensated, previous_end, have_previous)
		for loop in compensated:
			if loop.size() < 4:
				continue
			_add_contour_surface(contour_mesh, loop, level_y)
			var cutting := PackedVector3Array()
			for xz in loop:
				cutting.append(Vector3(xz.x, level_y, xz.y))
			var path := PackedVector3Array()
			path.append(Vector3(cutting[0].x, safe_y, cutting[0].z))
			path.append_array(cutting)
			path.append(Vector3(cutting[cutting.size() - 1].x, safe_y, cutting[cutting.size() - 1].z))
			_add_line_surface(path_mesh, path)
			all_points.append_array(path)
			previous_end = loop[loop.size() - 1]
			have_previous = true
			contour_count += 1
			closed_count += 1

	return _result(path_mesh, contour_mesh, all_points, cut_levels, contour_count, closed_count)

static func _result(
	path_mesh: ArrayMesh,
	contour_mesh: ArrayMesh,
	points: PackedVector3Array,
	levels: Array[float],
	contours: int,
	closed: int
) -> Dictionary:
	return {
		"mesh": path_mesh,
		"contour_mesh": contour_mesh,
		"points": points,
		"cut_levels": levels,
		"contour_count": contours,
		"closed_count": closed,
	}

static func _world_triangles(mesh_inst: MeshInstance3D) -> Array:
	var triangles: Array = []
	if mesh_inst == null or mesh_inst.mesh == null:
		return triangles
	var xf := mesh_inst.global_transform
	for surface in mesh_inst.mesh.get_surface_count():
		var arrays = mesh_inst.mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		if indices != null and indices.size() >= 3:
			var index_array: PackedInt32Array = indices
			var i := 0
			while i + 2 < index_array.size():
				triangles.append([
					xf * vertices[index_array[i]],
					xf * vertices[index_array[i + 1]],
					xf * vertices[index_array[i + 2]],
				])
				i += 3
		else:
			var i := 0
			while i + 2 < vertices.size():
				triangles.append([xf * vertices[i], xf * vertices[i + 1], xf * vertices[i + 2]])
				i += 3
	return triangles

static func _world_y_bounds(mesh_inst: MeshInstance3D) -> Dictionary:
	var aabb := mesh_inst.get_aabb()
	var xf := mesh_inst.global_transform
	var min_y := INF
	var max_y := -INF
	for i in 8:
		var local := Vector3(
			aabb.position.x + (aabb.size.x if (i & 1) else 0.0),
			aabb.position.y + (aabb.size.y if (i & 2) else 0.0),
			aabb.position.z + (aabb.size.z if (i & 4) else 0.0)
		)
		var world := xf * local
		min_y = minf(min_y, world.y)
		max_y = maxf(max_y, world.y)
	return {"min_y": min_y, "max_y": max_y}

static func _levels_top_down(top_y: float, floor_y: float, stepdown: float) -> Array[float]:
	var levels: Array[float] = []
	var step := maxf(stepdown, 1e-6)
	var y := top_y
	while y > floor_y + EPS:
		levels.append(y)
		y -= step
	if levels.is_empty() or absf(levels[levels.size() - 1] - floor_y) > EPS:
		levels.append(floor_y)
	return levels

static func _slice_segments(triangles: Array, level_y: float) -> Array:
	var segments: Array = []
	for triangle in triangles:
		var segment := _triangle_plane_segment(triangle, level_y)
		if segment.size() == 2 and segment[0].distance_squared_to(segment[1]) > EPS * EPS:
			segments.append(segment)
	return segments

static func _triangle_plane_segment(triangle: Array, level_y: float) -> PackedVector2Array:
	var hits := PackedVector2Array()
	for edge in [[0, 1], [1, 2], [2, 0]]:
		var a: Vector3 = triangle[edge[0]]
		var b: Vector3 = triangle[edge[1]]
		var da := a.y - level_y
		var db := b.y - level_y
		if absf(da) <= EPS and absf(db) <= EPS:
			continue
		if absf(da) <= EPS:
			_append_unique(hits, Vector2(a.x, a.z))
		elif absf(db) <= EPS:
			_append_unique(hits, Vector2(b.x, b.z))
		elif (da < 0.0) != (db < 0.0):
			var t := da / (da - db)
			var p := a.lerp(b, t)
			_append_unique(hits, Vector2(p.x, p.z))
	if hits.size() <= 2:
		return hits
	var farthest := PackedVector2Array([hits[0], hits[1]])
	var farthest_distance := hits[0].distance_squared_to(hits[1])
	for i in hits.size():
		for j in range(i + 1, hits.size()):
			var distance := hits[i].distance_squared_to(hits[j])
			if distance > farthest_distance:
				farthest = PackedVector2Array([hits[i], hits[j]])
				farthest_distance = distance
	return farthest

static func _append_unique(points: PackedVector2Array, point: Vector2) -> void:
	for existing in points:
		if existing.distance_squared_to(point) <= EPS * EPS:
			return
	points.append(point)

static func _join_segments(segments: Array, tolerance: float) -> Array[PackedVector2Array]:
	var remaining := segments.duplicate()
	var contours: Array[PackedVector2Array] = []
	while not remaining.is_empty():
		var first: PackedVector2Array = remaining.pop_back()
		var contour := PackedVector2Array([first[0], first[1]])
		var extended := true
		while extended and not remaining.is_empty():
			extended = false
			var tail := contour[contour.size() - 1]
			for i in remaining.size():
				var segment: PackedVector2Array = remaining[i]
				if tail.distance_to(segment[0]) <= tolerance:
					contour.append(segment[1])
				elif tail.distance_to(segment[1]) <= tolerance:
					contour.append(segment[0])
				else:
					continue
				remaining.remove_at(i)
				extended = true
				break
			if contour.size() >= 4 and contour[0].distance_to(contour[contour.size() - 1]) <= tolerance:
				contour[contour.size() - 1] = contour[0]
				break
		contours.append(contour)
	return contours

static func _resample_closed(loop: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var sampled := PackedVector2Array()
	var step := maxf(spacing, 1e-6)
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		var length := a.distance_to(b)
		var divisions := maxi(1, ceili(length / step))
		for j in divisions:
			sampled.append(a.lerp(b, float(j) / float(divisions)))
	if not sampled.is_empty():
		sampled.append(sampled[0])
	return sampled

static func _order_nearest(
	contours: Array[PackedVector2Array],
	start: Vector2,
	have_start: bool
) -> Array[PackedVector2Array]:
	var remaining := contours.duplicate()
	var ordered: Array[PackedVector2Array] = []
	var current := start
	var use_distance := have_start
	while not remaining.is_empty():
		var best_index := 0
		var best_vertex := 0
		var best_distance := INF
		if use_distance:
			for i in remaining.size():
				var contour: PackedVector2Array = remaining[i]
				for j in contour.size() - 1:
					var distance := current.distance_squared_to(contour[j])
					if distance < best_distance:
						best_distance = distance
						best_index = i
						best_vertex = j
		var chosen: PackedVector2Array = remaining.pop_at(best_index)
		chosen = _rotate_closed(chosen, best_vertex)
		ordered.append(chosen)
		current = chosen[chosen.size() - 1]
		use_distance = true
	return ordered

static func _rotate_closed(loop: PackedVector2Array, first_index: int) -> PackedVector2Array:
	if first_index == 0 or loop.size() < 2:
		return loop
	var rotated := PackedVector2Array()
	var unique_size := loop.size() - 1
	for i in unique_size:
		rotated.append(loop[(first_index + i) % unique_size])
	rotated.append(rotated[0])
	return rotated

static func _add_contour_surface(mesh: ArrayMesh, contour: PackedVector2Array, level_y: float) -> void:
	var vertices := PackedVector3Array()
	for xz in contour:
		vertices.append(Vector3(xz.x, level_y, xz.y))
	_add_line_surface(mesh, vertices)

static func _add_line_surface(mesh: ArrayMesh, vertices: PackedVector3Array) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
