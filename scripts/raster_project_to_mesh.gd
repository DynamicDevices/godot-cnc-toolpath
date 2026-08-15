class_name RasterProjectToMesh
extends RefCounted
## Stage 2: project a 2D raster line mesh onto a 3D mesh using tool + tolerances.
## Input: 2D line mesh (one surface per pass), mesh via raycasts, tool def, tolerances.
## Output: 3D line mesh (one surface per pass) + flat point list for animation.

class ToolDef:
	var radius: float = 0.0015
	var safe_y: float = 0.09
	func _init(p_radius: float = 0.0015, p_safe_y: float = 0.09) -> void:
		radius = p_radius
		safe_y = p_safe_y

class Tolerances:
	## Max vertical search below/above for a hit; samples closer than this are merged later if needed.
	var ray_below: float = 0.05
	var ray_above_pad: float = 0.05
	var min_segment_mm: float = 0.0  # reserved
	func _init(p_ray_below: float = 0.05, p_ray_above_pad: float = 0.05) -> void:
		ray_below = p_ray_below
		ray_above_pad = p_ray_above_pad

static func project_line_mesh(
	mesh_2d: ArrayMesh,
	space: PhysicsDirectSpaceState3D,
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	tol: Tolerances = null
) -> Dictionary:
	if tol == null:
		tol = Tolerances.new()
	var PassPlanner = load("res://scripts/raster_pass_planner.gd")
	var passes: Array = PassPlanner.passes_from_2d_line_mesh(mesh_2d)
	return project_passes(passes, space, mesh_inst, tool, tol)

static func project_passes(
	passes: Array,
	space: PhysicsDirectSpaceState3D,
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	tol: Tolerances = null
) -> Dictionary:
	if tol == null:
		tol = Tolerances.new()
	var aabb := mesh_inst.get_aabb()
	var top := mesh_inst.global_transform * (aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y, aabb.size.z * 0.5))
	var y_start := top.y + tol.ray_above_pad

	var out_mesh := ArrayMesh.new()
	var all_points := PackedVector3Array()

	for pass_pts in passes:
		var row: PackedVector2Array = pass_pts
		if row.size() < 2:
			continue
		var verts := PackedVector3Array()
		# Safe lead-in for this pass only.
		verts.append(Vector3(row[0].x, tool.safe_y, row[0].y))
		for xz in row:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(xz.x, y_start, xz.y),
				Vector3(xz.x, -tol.ray_below, xz.y)
			)
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
				p.y += tool.radius  # ball-nose style lift (tolerance/tool)
				verts.append(p)
			else:
				verts.append(Vector3(xz.x, tool.safe_y, xz.y))
		verts.append(Vector3(row[row.size() - 1].x, tool.safe_y, row[row.size() - 1].y))

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
		for v in verts:
			all_points.append(v)

	return {"mesh": out_mesh, "points": all_points}

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
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_z = minf(min_z, c.z)
		max_z = maxf(max_z, c.z)
	return {
		"min_x": min_x + margin,
		"max_x": max_x - margin,
		"min_z": min_z + margin,
		"max_z": max_z - margin,
	}
