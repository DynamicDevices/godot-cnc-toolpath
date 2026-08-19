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
	return float(drop_tool_contact(x, y, radius, tris_cad, fallback_z)["z"])


static func drop_tool_contact(x: float, y: float, radius: float, tris_cad: Array, fallback_z: float) -> Dictionary:
	## Highest ball-nose CL at CAD (x, y), plus contact feature and normal (Z-up).
	var z_best: float = -1e30
	var found := false
	var kind := 0
	var tri_i := -1
	var elem := -1
	var hit_pt := Vector3(x, y, fallback_z)
	var R2 := radius * radius
	for ti in range(tris_cad.size()):
		var tri: Array = tris_cad[ti]
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var verts: Array = [a, b, c]
		for vi in 3:
			var v: Vector3 = verts[vi]
			var dx: float = x - v.x
			var dy: float = y - v.y
			var d2: float = dx * dx + dy * dy
			if d2 <= R2:
				var z: float = v.z + sqrt(R2 - d2)
				if z > z_best:
					z_best = z
					found = true
					kind = 1
					tri_i = ti
					elem = vi
					hit_pt = v
		var edges: Array = [[a, b], [b, c], [c, a]]
		for ei in 3:
			var edge: Array = edges[ei]
			var hit: Dictionary = _ball_edge_hit(x, y, radius, edge[0], edge[1])
			if not hit.is_empty() and float(hit["z"]) > z_best:
				z_best = float(hit["z"])
				found = true
				kind = 2
				tri_i = ti
				elem = ei
				hit_pt = hit["point"]
		var z_f: float = _ball_face_z(x, y, radius, a, b, c)
		if not is_nan(z_f) and z_f > z_best:
			z_best = z_f
			found = true
			kind = 3
			tri_i = ti
			elem = -1
			hit_pt = Vector3(x, y, z_f - radius)
	if not found:
		return {
			"z": fallback_z,
			"kind": 0,
			"tri": -1,
			"elem": -1,
			"normal": Vector3(0, 0, 1),
			"point": Vector3(x, y, fallback_z),
		}
	var cl := Vector3(x, y, z_best)
	var n := (cl - hit_pt).normalized()
	if kind == 3:
		var tri_n: Array = tris_cad[tri_i]
		n = (tri_n[1] - tri_n[0]).cross(tri_n[2] - tri_n[0]).normalized()
		if n.dot(cl - tri_n[0]) < 0.0:
			n = -n
	elif n.length_squared() < 1e-12:
		n = Vector3(0, 0, 1)
	return {
		"z": z_best,
		"kind": kind,
		"tri": tri_i,
		"elem": elem,
		"normal": n,
		"point": hit_pt,
	}


static func _ball_edge_z(x: float, y: float, R: float, p0: Vector3, p1: Vector3) -> float:
	var hit := _ball_edge_hit(x, y, R, p0, p1)
	if hit.is_empty():
		return NAN
	return float(hit["z"])


static func _ball_edge_hit(x: float, y: float, R: float, p0: Vector3, p1: Vector3) -> Dictionary:
	var ex := p1.x - p0.x
	var ey := p1.y - p0.y
	var ez := p1.z - p0.z
	var len2 := ex * ex + ey * ey
	if len2 < 1e-18:
		return {}
	var t := ((x - p0.x) * ex + (y - p0.y) * ey) / len2
	t = clampf(t, 0.0, 1.0)
	var pt := Vector3(p0.x + ex * t, p0.y + ey * t, p0.z + ez * t)
	var dx: float = x - pt.x
	var dy: float = y - pt.y
	var d2: float = dx * dx + dy * dy
	var R2: float = R * R
	if d2 > R2:
		return {}
	return {"z": pt.z + sqrt(R2 - d2), "point": pt}


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
