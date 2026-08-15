class_name RasterProjectToMesh
extends RefCounted
## Stage 2: project a 2D raster line mesh onto a 3D mesh by colliding a tool
## shape with the mesh (NOT PhysicsDirectSpaceState3D raycasts).
## First implementation: ball-nose (sphere) drop-cutter against triangles.

class ToolDef:
	## Ball-nose: sphere radius in metres. Centre rides at contact + radius on +Y.
	var radius: float = 0.0015
	var safe_y: float = 0.09
	func _init(p_radius: float = 0.0015, p_safe_y: float = 0.09) -> void:
		radius = p_radius
		safe_y = p_safe_y

class Tolerances:
	## Horizontal samples whose planar distance to a feature exceeds radius are ignored.
	## Vertical clamp if no collision found.
	var no_hit_y: float = 0.09
	func _init(p_no_hit_y: float = 0.09) -> void:
		no_hit_y = p_no_hit_y

static func project_line_mesh(
	mesh_2d: ArrayMesh,
	_space: PhysicsDirectSpaceState3D,  # unused — kept so call sites stay stable
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	tol: Tolerances = null
) -> Dictionary:
	if tol == null:
		tol = Tolerances.new(tool.safe_y)
	var PassPlanner = load("res://scripts/raster_pass_planner.gd")
	var passes: Array = PassPlanner.passes_from_2d_line_mesh(mesh_2d)
	return project_passes(passes, mesh_inst, tool, tol)

static func project_passes(
	passes: Array,
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	tol: Tolerances = null
) -> Dictionary:
	if tol == null:
		tol = Tolerances.new(tool.safe_y)
	var tris := _world_triangles(mesh_inst)
	var out_mesh := ArrayMesh.new()
	var all_points := PackedVector3Array()
	var R: float = tool.radius

	for pass_pts in passes:
		var row: PackedVector2Array = pass_pts
		if row.size() < 2:
			continue
		var verts := PackedVector3Array()
		verts.append(Vector3(row[0].x, tool.safe_y, row[0].y))
		for xz in row:
			var y: float = _ball_drop_y(xz.x, xz.y, R, tris, tol.no_hit_y)
			verts.append(Vector3(xz.x, y, xz.y))
		verts.append(Vector3(row[row.size() - 1].x, tool.safe_y, row[row.size() - 1].y))

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
		for v in verts:
			all_points.append(v)

	return {"mesh": out_mesh, "points": all_points}

## Public compute entry (Julian): 2D passes + mesh + tool → 3D line mesh via tool collision.
static func compute_line_mesh(
	passes: Array,
	mesh_inst: MeshInstance3D,
	tool: ToolDef,
	tol: Tolerances = null
) -> Dictionary:
	return project_passes(passes, mesh_inst, tool, tol)

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

static func _world_triangles(mesh_inst: MeshInstance3D) -> Array:
	var tris: Array = []
	if mesh_inst == null or mesh_inst.mesh == null:
		return tris
	var xf := mesh_inst.global_transform
	var mesh := mesh_inst.mesh
	for s in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(s)
		if arr.size() <= Mesh.ARRAY_VERTEX or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var indices = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else null
		if indices != null and indices.size() >= 3:
			var idx: PackedInt32Array = indices
			var i := 0
			while i + 2 < idx.size():
				tris.append([xf * verts[idx[i]], xf * verts[idx[i + 1]], xf * verts[idx[i + 2]]])
				i += 3
		else:
			var i2 := 0
			while i2 + 2 < verts.size():
				tris.append([xf * verts[i2], xf * verts[i2 + 1], xf * verts[i2 + 2]])
				i2 += 3
	return tris

## Drop a vertical ball of radius R at (x,z); return tool-centre Y (highest contact).
static func _ball_drop_y(x: float, z: float, R: float, tris: Array, fallback_y: float) -> float:
	var y_best: float = -1e30
	var found := false
	var R2 := R * R
	for tri in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		# Vertex contributions.
		for vi in 3:
			var v: Vector3 = tri[vi]
			var dx: float = x - v.x
			var dz: float = z - v.z
			var d2: float = dx * dx + dz * dz
			if d2 <= R2:
				var y: float = v.y + sqrt(R2 - d2)
				if y > y_best:
					y_best = y
					found = true
		# Edge contributions.
		var edges: Array = [[a, b], [b, c], [c, a]]
		for edge in edges:
			var y_e: float = _ball_edge_y(x, z, R, edge[0], edge[1])
			if not is_nan(y_e) and y_e > y_best:
				y_best = y_e
				found = true
		# Face (plane) contribution if vertical projection of centre lies in triangle.
		var y_f: float = _ball_face_y(x, z, R, a, b, c)
		if not is_nan(y_f) and y_f > y_best:
			y_best = y_f
			found = true
	if found:
		return y_best
	return fallback_y

static func _ball_edge_y(x: float, z: float, R: float, p0: Vector3, p1: Vector3) -> float:
	var ex := p1.x - p0.x
	var ez := p1.z - p0.z
	var ey := p1.y - p0.y
	var len2 := ex * ex + ez * ez
	if len2 < 1e-18:
		return NAN
	# Closest point on infinite edge in XZ, then clamp to segment.
	var t := ((x - p0.x) * ex + (z - p0.z) * ez) / len2
	t = clampf(t, 0.0, 1.0)
	var cx: float = p0.x + ex * t
	var cy: float = p0.y + ey * t
	var cz: float = p0.z + ez * t
	var dx: float = x - cx
	var dz: float = z - cz
	var d2: float = dx * dx + dz * dz
	var R2: float = R * R
	if d2 > R2:
		return NAN
	return cy + sqrt(R2 - d2)

static func _ball_face_y(x: float, z: float, R: float, a: Vector3, b: Vector3, c: Vector3) -> float:
	# Plane through triangle; require (x,z) inside triangle in XZ (barycentric on XZ).
	var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(den) < 1e-18:
		return NAN
	var w1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / den
	var w2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / den
	var w3 := 1.0 - w1 - w2
	if w1 < 0.0 or w2 < 0.0 or w3 < 0.0:
		return NAN
	var n := (b - a).cross(c - a)
	if absf(n.y) < 1e-10:
		# Vertical-ish face: skip plane drop (edges/verts handle).
		return NAN
	# Plane: n·(p - a) = 0. Sphere centre (x,y,z) at distance R from plane along normal.
	# For drop-cutter we want the higher of the two offsets; machining from +Y uses the
	# contact where the sphere sits above the surface.
	var nlen := n.length()
	if nlen < 1e-12:
		return NAN
	n /= nlen
	# Signed: n·(c0 - a) = ±R with c0=(x,y,z). Solve y.
	# n.x*(x-a.x) + n.y*(y-a.y) + n.z*(z-a.z) = ±R
	var base := n.x * (x - a.x) + n.z * (z - a.z) - n.y * a.y
	# n.y * y + base = ±R  →  y = (±R - base) / n.y
	var y1: float = (R - base) / n.y
	var y2: float = (-R - base) / n.y
	return maxf(y1, y2)
