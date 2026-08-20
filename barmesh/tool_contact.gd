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
				if _beats(z, 1, z_best, kind, found):
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
			if not hit.is_empty() and _beats(float(hit["z"]), 2, z_best, kind, found):
				z_best = float(hit["z"])
				found = true
				kind = 2
				tri_i = ti
				elem = ei
				hit_pt = hit["point"]
		var face: Dictionary = _ball_face_hit(x, y, radius, a, b, c)
		if not face.is_empty() and _beats(float(face["z"]), 3, z_best, kind, found):
			z_best = float(face["z"])
			found = true
			kind = 3
			tri_i = ti
			elem = -1
			hit_pt = face["point"]
	if not found:
		return {
			"x": x,
			"y": y,
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
		hit_pt = cl - n * radius
	elif n.length_squared() < 1e-12:
		n = Vector3(0, 0, 1)
	## CL is always (probe_x, probe_y, z). Contact point may differ in XY on tilted faces.
	return {
		"x": x,
		"y": y,
		"z": z_best,
		"kind": kind,
		"tri": tri_i,
		"elem": elem,
		"normal": n,
		"point": hit_pt,
	}


static func _beats(z: float, kind: int, z_best: float, kind_best: int, found: bool) -> bool:
	## Higher CL wins. Same height: vertex more specific than edge than face.
	if not found:
		return true
	if z > z_best + 1e-9:
		return true
	if z < z_best - 1e-9:
		return false
	return kind < kind_best


static func _ball_edge_z(x: float, y: float, R: float, p0: Vector3, p1: Vector3) -> float:
	var hit := _ball_edge_hit(x, y, R, p0, p1)
	if hit.is_empty():
		return NAN
	return float(hit["z"])


static func _ball_edge_hit(x: float, y: float, R: float, p0: Vector3, p1: Vector3) -> Dictionary:
	## True ball↔segment contact: (CL − pt) ⊥ edge and |CL − pt| = R.
	## (Old XY-only projection is wrong for tilted edges and causes fall-through.)
	var dx := p1.x - p0.x
	var dy := p1.y - p0.y
	var dz := p1.z - p0.z
	var L2 := dx * dx + dy * dy + dz * dz
	if L2 < 1e-18:
		return {}
	var cx := x - p0.x
	var cy := y - p0.y
	var A := cx * dx + cy * dy
	var H2 := dx * dx + dy * dy
	var R2 := R * R
	var best_z: float = -1e30
	var best_pt := Vector3.ZERO
	var found := false

	if H2 < 1e-18:
		# Nearly vertical edge: cylinder test in XY, z from segment extent.
		var d2xy := cx * cx + cy * cy
		if d2xy > R2:
			return {}
		var z_off := sqrt(R2 - d2xy)
		for t in [0.0, 1.0]:
			var pt_v := Vector3(p0.x + dx * t, p0.y + dy * t, p0.z + dz * t)
			var z_cl: float = pt_v.z + z_off
			if z_cl > best_z:
				best_z = z_cl
				best_pt = pt_v
				found = true
	else:
		# Quadratic in cz = z - p0.z from |C-P|^2=R^2 and (C-P)·d=0.
		var a := H2
		var b := -2.0 * A * dz
		var c := L2 * (cx * cx + cy * cy) - A * A - R2 * L2
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return {}
		var sdisc := sqrt(disc)
		for sign in [-1.0, 1.0]:
			var cz: float = (-b + sign * sdisc) / (2.0 * a)
			var z: float = p0.z + cz
			var t: float = (A + cz * dz) / L2
			if t < -1e-6 or t > 1.0 + 1e-6:
				continue
			t = clampf(t, 0.0, 1.0)
			var pt := Vector3(p0.x + dx * t, p0.y + dy * t, p0.z + dz * t)
			var cl := Vector3(x, y, z)
			if absf(cl.distance_to(pt) - R) > 1e-3:
				continue
			if z > best_z:
				best_z = z
				best_pt = pt
				found = true

	# Endpoints are also covered by vertex tests; keep segment-interior hits here.
	if not found:
		return {}
	return {"z": best_z, "point": best_pt}


static func _ball_face_z(x: float, y: float, R: float, a: Vector3, b: Vector3, c: Vector3) -> float:
	var hit := _ball_face_hit(x, y, R, a, b, c)
	if hit.is_empty():
		return NAN
	return float(hit["z"])


static func _ball_face_hit(x: float, y: float, R: float, a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	## Tangent CL only if the contact point (CL − R n) lies in the triangle.
	var n := (b - a).cross(c - a)
	if absf(n.z) < 1e-10:
		return {}
	var nlen := n.length()
	if nlen < 1e-12:
		return {}
	n /= nlen
	var base := n.x * (x - a.x) + n.y * (y - a.y) - n.z * a.z
	var z1: float = (R - base) / n.z
	var z2: float = (-R - base) / n.z
	var best_z: float = -1e30
	var best_pt := Vector3.ZERO
	var found := false
	for z in [z1, z2]:
		var cl := Vector3(x, y, z)
		var nn: Vector3 = n
		if nn.dot(cl - a) < 0.0:
			nn = -nn
		var pt: Vector3 = cl - nn * R
		if not _point_in_triangle(pt, a, b, c):
			continue
		if z > best_z:
			best_z = z
			found = true
			best_pt = pt
	if not found:
		return {}
	return {"z": best_z, "point": best_pt}


static func _point_in_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var n := v0.cross(v1)
	if absf(n.dot(v2)) > 1e-6 * n.length():
		return false
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-18:
		return false
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	var u := 1.0 - v - w
	var eps := -1e-6
	return u >= eps and v >= eps and w >= eps


static func highest_surface_z_at_xy(x: float, y: float, tris_cad: Array) -> float:
	## Highest mesh z along vertical line (x,y,*) — for fall-through vs top skin.
	var z_best: float = -1e30
	var found := false
	for tri in tris_cad:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var n := (b - a).cross(c - a)
		if absf(n.z) < 1e-12:
			continue
		# Plane: n·(p-a)=0 → z = a.z + (-n.x*(x-a.x)-n.y*(y-a.y))/n.z
		var z: float = a.z - (n.x * (x - a.x) + n.y * (y - a.y)) / n.z
		var p := Vector3(x, y, z)
		if not _point_in_triangle(p, a, b, c):
			continue
		if z > z_best:
			z_best = z
			found = true
	if not found:
		return NAN
	return z_best


static func min_distance_point_to_tris(p: Vector3, tris_cad: Array) -> float:
	## Closest distance from point to any triangle (for sphere penetration checks).
	var best: float = 1e30
	for tri in tris_cad:
		var d: float = _point_triangle_distance(p, tri[0], tri[1], tri[2])
		if d < best:
			best = d
	return best


static func _point_triangle_distance(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return ap.length()
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return bp.length()
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v: float = d1 / (d1 - d3)
		return (a + ab * v - p).length()
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return cp.length()
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w: float = d2 / (d2 - d6)
		return (a + ac * w - p).length()
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w2: float = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return (b + (c - b) * w2 - p).length()
	var n := ab.cross(ac)
	var nlen2 := n.length_squared()
	if nlen2 < 1e-24:
		return ap.length()
	return absf(n.dot(ap)) / sqrt(nlen2)
