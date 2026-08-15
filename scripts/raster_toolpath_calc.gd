class_name RasterToolpathCalc
extends RefCounted
## Toolpath calculation only.
## Input: 2D passes + mesh (via world raycasts) + tool definition.
## Output: line-strip ArrayMesh (and the underlying points).

class ToolDef:
	var radius: float = 0.0015
	var safe_y: float = 0.09
	func _init(p_radius: float = 0.0015, p_safe_y: float = 0.09) -> void:
		radius = p_radius
		safe_y = p_safe_y

static func mesh_bounds_xz(mesh_inst: MeshInstance3D, margin: float) -> Dictionary:
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
	return {
		"min_x": min_x + margin,
		"max_x": max_x - margin,
		"min_z": min_z + margin,
		"max_z": max_z - margin,
		"max_y": max_y,
	}

## Core API Julian asked for: 2D passes + mesh + tool → line mesh.
static func compute_line_mesh(
	passes: Array,
	space: PhysicsDirectSpaceState3D,
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	y_start_pad: float = 0.05
) -> Dictionary:
	var points := PackedVector3Array()
	var aabb := mesh_inst.get_aabb()
	var top := mesh_inst.global_transform * (aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y, aabb.size.z * 0.5))
	var y_start := top.y + y_start_pad

	for pass_pts in passes:
		var row: PackedVector2Array = pass_pts
		if row.is_empty():
			continue
		# Lead-in at safe height.
		points.append(Vector3(row[0].x, tool.safe_y, row[0].y))
		for xz in row:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(xz.x, y_start, xz.y),
				Vector3(xz.x, -0.05, xz.y)
			)
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
				p.y += tool.radius
				points.append(p)
			else:
				points.append(Vector3(xz.x, tool.safe_y, xz.y))
		var last: Vector3 = points[points.size() - 1]
		points.append(Vector3(last.x, tool.safe_y, last.z))

	var mesh := make_line_mesh(points)
	return {"points": points, "mesh": mesh}

static func make_line_mesh(points: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var am := ArrayMesh.new()
	if points.size() >= 2:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return am
