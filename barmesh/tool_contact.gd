class_name BarMeshToolContact
extends RefCounted
## Accurate 3-axis tool contact in CAD Z-up.
## Tool axis is +Z. Drop along -Z from a point above (ball-nose cutter location).

static func godot_world_to_cad(p: Vector3) -> Vector3:
	## Godot Y-up (x, y, z) -> CAD Z-up (x, y_cad, z_up) = (x, z_godot, y_godot).
	return Vector3(p.x, p.z, p.y)


static func cad_aabb_from_godot(aabb: AABB) -> Dictionary:
	var c0 := godot_world_to_cad(aabb.position)
	var c1 := godot_world_to_cad(aabb.end)
	return {
		"xmin": minf(c0.x, c1.x),
		"xmax": maxf(c0.x, c1.x),
		"ymin": minf(c0.y, c1.y),
		"ymax": maxf(c0.y, c1.y),
		"zmin": minf(c0.z, c1.z),
		"zmax": maxf(c0.z, c1.z),
	}


static func mesh_triangles_cad(mesh_inst: MeshInstance3D) -> Array:
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
				tris.append([
					godot_world_to_cad(xf * verts[idx[i]]),
					godot_world_to_cad(xf * verts[idx[i + 1]]),
					godot_world_to_cad(xf * verts[idx[i + 2]]),
				])
				i += 3
		else:
			var i2 := 0
			while i2 + 2 < verts.size():
				tris.append([
					godot_world_to_cad(xf * verts[i2]),
					godot_world_to_cad(xf * verts[i2 + 1]),
					godot_world_to_cad(xf * verts[i2 + 2]),
				])
				i2 += 3
	return tris


static func drop_tool_z(x: float, y: float, radius: float, tris_cad: Array, fallback_z: float) -> float:
	## Cutter-location Z (sphere centre) for a vertical ball-nose at CAD (x, y).
	var z_best: float = -1e30
	var found := false
	var R2 := radius * radius
	for tri in tris_cad:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		for vi in 3:
			var v: Vector3 = tri[vi]
			var dx: float = x - v.x
			var dy: float = y - v.y
			var d2: float = dx * dx + dy * dy
			if d2 <= R2:
				var z: float = v.z + sqrt(R2 - d2)
				if z > z_best:
					z_best = z
					found = true
		var edges: Array = [[a, b], [b, c], [c, a]]
		for edge in edges:
			var z_e: float = _ball_edge_z(x, y, radius, edge[0], edge[1])
			if not is_nan(z_e) and z_e > z_best:
				z_best = z_e
				found = true
		var z_f: float = _ball_face_z(x, y, radius, a, b, c)
		if not is_nan(z_f) and z_f > z_best:
			z_best = z_f
			found = true
	if found:
		return z_best
	return fallback_z


static func _ball_edge_z(x: float, y: float, R: float, p0: Vector3, p1: Vector3) -> float:
	var ex := p1.x - p0.x
	var ey := p1.y - p0.y
	var ez := p1.z - p0.z
	var len2 := ex * ex + ey * ey
	if len2 < 1e-18:
		return NAN
	var t := ((x - p0.x) * ex + (y - p0.y) * ey) / len2
	t = clampf(t, 0.0, 1.0)
	var cx: float = p0.x + ex * t
	var cy: float = p0.y + ey * t
	var cz: float = p0.z + ez * t
	var dx: float = x - cx
	var dy: float = y - cy
	var d2: float = dx * dx + dy * dy
	var R2: float = R * R
	if d2 > R2:
		return NAN
	return cz + sqrt(R2 - d2)


static func _ball_face_z(x: float, y: float, R: float, a: Vector3, b: Vector3, c: Vector3) -> float:
	var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(den) < 1e-18:
		return NAN
	var w1 := ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (y - c.y)) / den
	var w2 := ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (y - c.y)) / den
	var w3 := 1.0 - w1 - w2
	if w1 < 0.0 or w2 < 0.0 or w3 < 0.0:
		return NAN
	var n := (b - a).cross(c - a)
	if absf(n.z) < 1e-10:
		return NAN
	var nlen := n.length()
	if nlen < 1e-12:
		return NAN
	n /= nlen
	var base := n.x * (x - a.x) + n.y * (y - a.y) - n.z * a.z
	var z1: float = (R - base) / n.z
	var z2: float = (-R - base) / n.z
	return maxf(z1, z2)
