class_name RasterToolpathCalc
extends RefCounted
## Pure raster toolpath calculation.
## Input: mesh (via world raycasts), tool radius / stepover / sample (metres).
## Output: ordered tool centre points (PackedVector3Array). Caller builds line mesh + Animation.

static func compute(
	space: PhysicsDirectSpaceState3D,
	mesh_inst: MeshInstance3D,
	tool_radius: float,
	stepover: float,
	sample_step: float,
	safe_y: float,
	margin: float
) -> PackedVector3Array:
	var aabb := mesh_inst.get_aabb()
	var xf := mesh_inst.global_transform
	var corners: Array[Vector3] = []
	for i in 8:
		var local := Vector3(
			aabb.position.x + (aabb.size.x if (i & 1) else 0.0),
			aabb.position.y + (aabb.size.y if (i & 2) else 0.0),
			aabb.position.z + (aabb.size.z if (i & 4) else 0.0)
		)
		corners.append(xf * local)

	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_z := corners[0].z
	var max_z := corners[0].z
	var max_y := corners[0].y
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_z = minf(min_z, c.z)
		max_z = maxf(max_z, c.z)
		max_y = maxf(max_y, c.y)

	min_x += margin
	max_x -= margin
	min_z += margin
	max_z -= margin

	var points := PackedVector3Array()
	var row := 0
	var z := min_z
	var y_start := max_y + 0.05
	while z <= max_z + 1e-9:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-9:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()
		if xs.size() > 0:
			points.append(Vector3(xs[0], safe_y, z))
		for sx in xs:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(sx, y_start, z),
				Vector3(sx, -0.05, z)
			)
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
				p.y += tool_radius
				points.append(p)
			else:
				points.append(Vector3(sx, safe_y, z))
		if points.size() > 0:
			var last: Vector3 = points[points.size() - 1]
			points.append(Vector3(last.x, safe_y, last.z))
		z += stepover
		row += 1
	return points

static func make_line_mesh(points: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return am

static func make_position_animation(
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
