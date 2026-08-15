class_name RasterPassPlanner
extends RefCounted
## Stage 1: build a 2D raster as a line mesh — one LINE_STRIP surface per pass.

static func make_passes(
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	stepover: float,
	sample_step: float
) -> Array:
	var passes: Array = []
	var row := 0
	var z := min_z
	while z <= max_z + 1e-9:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-9:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()
		var pass_pts := PackedVector2Array()
		for sx in xs:
			pass_pts.append(Vector2(sx, z))
		if pass_pts.size() >= 2:
			passes.append(pass_pts)
		z += stepover
		row += 1
	return passes

## Flat line mesh in XZ at plane_y — separate surface per raster pass.
static func make_2d_line_mesh(passes: Array, plane_y: float = 0.0) -> ArrayMesh:
	var am := ArrayMesh.new()
	for pass_pts in passes:
		var row: PackedVector2Array = pass_pts
		if row.size() < 2:
			continue
		var verts := PackedVector3Array()
		for xz in row:
			verts.append(Vector3(xz.x, plane_y, xz.y))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return am

static func passes_from_2d_line_mesh(mesh_2d: ArrayMesh) -> Array:
	var passes: Array = []
	if mesh_2d == null:
		return passes
	for s in mesh_2d.get_surface_count():
		var arr = mesh_2d.surface_get_arrays(s)
		if arr.size() <= Mesh.ARRAY_VERTEX or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var row := PackedVector2Array()
		for v in verts:
			row.append(Vector2(v.x, v.z))
		if row.size() >= 2:
			passes.append(row)
	return passes
