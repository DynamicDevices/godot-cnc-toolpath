class_name BarMeshSubdiv
extends RefCounted
## Bar vs cell subdivision conditions and insertion placement (Julian).
## Keep this module separate from BarMesh topology (InsertNodeIntoBarF /
## MakeBarBetweenNodesF). Parameters are shared; predicates and placement differ.

class Params:
	## External refine knobs. Defaults: 0.01 mm, 1 mm, 15°.
	var epsilon_m: float = 0.00001
	var stepover_m: float = 0.001
	## Bar length/normal split and cell (2): max angle between any pair of contact normals.
	var angle_deg: float = 15.0
	## Cell (1): max ⊥ distance of contact points to the best-fit plane (3 pts → always 0).
	var coplanar_tol_m: float = 0.00001


enum BarInsertMode {
	## Bisect the bar in XY (simple isolation of z / normal discontinuities).
	XY_MIDPOINT,
	## Guess the transition by intersecting contact planes at the tool centres
	## with the bar's XY line; falls back to midpoint if the guess is unusable.
	XY_PLANE_INTERSECT,
}


## Edge: InsertNodeIntoBarF when XY > ε and (3D length > stepover or normal angle > a).
static func bar_needs_split(bar: BarMesh.BMBar, params: Params) -> bool:
	if bar.bbardeleted:
		return false
	var a: Vector3 = bar.nodeback.p
	var b: Vector3 = bar.nodefore.p
	var dxy := Vector2(a.x - b.x, a.y - b.y).length()
	if dxy <= params.epsilon_m:
		return false
	var need_len := a.distance_to(b) > params.stepover_m
	var need_ang := false
	var na: Vector3 = bar.nodeback.contact_normal
	var nb: Vector3 = bar.nodefore.contact_normal
	if na.length_squared() > 0.25 and nb.length_squared() > 0.25:
		var c := clampf(na.dot(nb), -1.0, 1.0)
		need_ang = c < cos(deg_to_rad(params.angle_deg))
	return need_len or need_ang


## Face/cell (MakeBarBetweenNodesF) — Julian CNC 127/132/144:
## Split when avg-normal/avg-point plane residual > coplanar_tol, or contact-normal
## span > a (and XY > ε). Future anti-over-subdivide rule stays separate here.
static func cell_needs_split(cell_nodes: Array, params: Params) -> bool:
	if cell_nodes.size() < 3:
		return false
	var xmin := INF
	var xmax := -INF
	var ymin := INF
	var ymax := -INF
	for n in cell_nodes:
		var node: BarMesh.BMNode = n
		xmin = minf(xmin, node.p.x)
		xmax = maxf(xmax, node.p.x)
		ymin = minf(ymin, node.p.y)
		ymax = maxf(ymax, node.p.y)
	if maxf(xmax - xmin, ymax - ymin) <= params.epsilon_m:
		return false
	if cell_planar_residual(cell_nodes) > params.coplanar_tol_m:
		return true
	var normals: Array[Vector3] = []
	for n2 in cell_nodes:
		var nd: BarMesh.BMNode = n2
		if nd.contact_normal.length_squared() > 0.25:
			normals.append(nd.contact_normal.normalized())
	return _normals_span_exceeds(normals, params.angle_deg)


## Julian 144: plane through avg(contact_points) with normal avg(contact_normals);
## residual = max |⊥ distance|. Three points → 0 if normals define a plane.
static func cell_planar_residual(cell_nodes: Array) -> float:
	if cell_nodes.size() <= 3:
		return 0.0
	var c := Vector3.ZERO
	var nsum := Vector3.ZERO
	var n_pts := 0
	var n_nrm := 0
	for n in cell_nodes:
		var node: BarMesh.BMNode = n
		if node.contact_kind != BarMesh.BMNode.ContactFeature.NONE:
			c += node.contact_point
			n_pts += 1
		if node.contact_normal.length_squared() > 0.25:
			nsum += node.contact_normal.normalized()
			n_nrm += 1
	if n_pts < 3 or n_nrm < 1 or nsum.length_squared() < 1e-12:
		return 0.0
	c /= float(n_pts)
	var normal: Vector3 = nsum.normalized()
	var worst := 0.0
	for n2 in cell_nodes:
		var node2: BarMesh.BMNode = n2
		if node2.contact_kind == BarMesh.BMNode.ContactFeature.NONE:
			continue
		worst = maxf(worst, absf(normal.dot(node2.contact_point - c)))
	return worst


## Unique right-hand cells (one seed bar each). Dedupes so bars > cells.
static func unique_cell_seeds(bm: BarMesh) -> Array:
	var seen: Dictionary = {}
	var seeds: Array = []
	for bar in bm.live_bars():
		var ring: Dictionary = bm.cell_ring_right(bar)
		if not bool(ring.get("ok", false)):
			continue
		var key := _cell_key(ring["nodes"])
		if seen.has(key):
			continue
		seen[key] = true
		seeds.append(bar)
	return seeds


## Cell farthest from its avg-normal/avg-point plane (among those needing split).
static func find_worst_cell_seed(bm: BarMesh, params: Params) -> Dictionary:
	var worst: Dictionary = {"ok": false, "residual": -1.0}
	for seed in unique_cell_seeds(bm):
		var ring: Dictionary = bm.cell_ring_right(seed)
		if not bool(ring.get("ok", false)):
			continue
		var nodes: Array = ring["nodes"]
		if not cell_needs_split(nodes, params):
			continue
		var r: float = cell_planar_residual(nodes)
		if bool(worst.get("ok", false)) and r <= float(worst["residual"]):
			continue
		worst = {
			"ok": true,
			"seed": seed,
			"nodes": nodes,
			"bars": ring["bars"],
			"residual": r,
		}
	return worst


## Pick node/bar pair for MakeBarBetweenNodesF that minimises max child planar residual.
static func pick_cell_split_for_make_bar(ring_nodes: Array, ring_bars: Array, params: Params) -> Dictionary:
	var n: int = ring_nodes.size()
	if n < 4 or ring_bars.size() != n:
		return {"ok": false}
	var best: Dictionary = {"ok": false, "score": INF}
	for i in n:
		for j in range(i + 2, n):
			# Skip adjacent wrap (i=0,j=n-1).
			if i == 0 and j == n - 1:
				continue
			if (j - i) < 2 or (n - (j - i)) < 2:
				continue
			var a: BarMesh.BMNode = ring_nodes[i]
			var b: BarMesh.BMNode = ring_nodes[j]
			if Vector2(b.p.x - a.p.x, b.p.y - a.p.y).length() <= params.epsilon_m:
				continue
			var left: Array = _ring_slice(ring_nodes, i, j)
			var right: Array = _ring_slice(ring_nodes, j, i)
			var score: float = maxf(cell_planar_residual(left), cell_planar_residual(right))
			# Mild sliver guard: reject tiny min face area.
			if _split_min_poly_area_xy(ring_nodes, i, j) < params.epsilon_m * params.epsilon_m:
				continue
			if score < float(best.get("score", INF)):
				var bar_a: BarMesh.BMBar = ring_bars[(i - 1 + n) % n]
				var bar_b: BarMesh.BMBar = ring_bars[(j - 1 + n) % n]
				var n1: BarMesh.BMNode = a
				var n2: BarMesh.BMNode = b
				var b1: BarMesh.BMBar = bar_a
				var b2: BarMesh.BMBar = bar_b
				if n2.i < n1.i:
					var tn = n1
					n1 = n2
					n2 = tn
					var tb = b1
					b1 = b2
					b2 = tb
				best = {
					"ok": true,
					"score": score,
					"node1": n1,
					"bar1": b1,
					"node2": n2,
					"bar2": b2,
				}
	return best


static func _cell_key(nodes: Array) -> String:
	var ids: Array = []
	for n in nodes:
		var node: BarMesh.BMNode = n
		ids.append(node.i)
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		parts.append(str(id))
	return ",".join(parts)


static func _ring_slice(nodes: Array, i: int, j: int) -> Array:
	var out: Array = []
	var n: int = nodes.size()
	var k := i
	while true:
		out.append(nodes[k])
		if k == j:
			break
		k = (k + 1) % n
	return out


static func _edge_dir_xy(a: BarMesh.BMNode, b: BarMesh.BMNode) -> Vector2:
	var d := Vector2(b.p.x - a.p.x, b.p.y - a.p.y)
	if d.length_squared() < 1e-24:
		return Vector2.ZERO
	return d.normalized()


static func _normals_span_exceeds(normals: Array[Vector3], angle_deg: float) -> bool:
	if normals.size() < 2:
		return false
	var lim := cos(deg_to_rad(angle_deg))
	for i in normals.size():
		for j in range(i + 1, normals.size()):
			if normals[i].dot(normals[j]) < lim:
				return true
	return false


static func _points_near_coplanar(points: Array[Vector3], tol: float) -> bool:
	# Three points are always coplanar (⊥ residual 0).
	if points.size() <= 3:
		return true
	var plane: Dictionary = _best_fit_plane(points)
	if not bool(plane.get("ok", false)):
		return false
	var origin: Vector3 = plane["origin"]
	var normal: Vector3 = plane["normal"]
	for p in points:
		if absf(normal.dot(p - origin)) > tol:
			return false
	return true


## Best-fit plane via centroid + covariance (ilikebigbits determinant form).
static func _best_fit_plane(points: Array[Vector3]) -> Dictionary:
	var c := Vector3.ZERO
	for p in points:
		c += p
	c /= float(points.size())
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for p in points:
		var d: Vector3 = p - c
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z
	var det_x := yy * zz - yz * yz
	var det_y := xx * zz - xz * xz
	var det_z := xx * yy - xy * xy
	var abs_x := absf(det_x)
	var abs_y := absf(det_y)
	var abs_z := absf(det_z)
	var n := Vector3.ZERO
	if abs_x >= abs_y and abs_x >= abs_z:
		n = Vector3(det_x, xz * yz - xy * zz, xy * yz - xz * yy)
	elif abs_y >= abs_z:
		n = Vector3(xz * yz - xy * zz, det_y, xy * xz - yz * xx)
	else:
		n = Vector3(xy * yz - xz * yy, xy * xz - yz * xx, det_z)
	if n.length_squared() < 1e-24:
		return {"ok": false}
	return {"ok": true, "origin": c, "normal": n.normalized()}


static func _split_min_poly_area_xy(cell_nodes: Array, i: int, j: int) -> float:
	var ring_a: PackedVector2Array = PackedVector2Array()
	var ring_b: PackedVector2Array = PackedVector2Array()
	var n: int = cell_nodes.size()
	var k := i
	while true:
		var node: BarMesh.BMNode = cell_nodes[k]
		ring_a.append(Vector2(node.p.x, node.p.y))
		if k == j:
			break
		k = (k + 1) % n
	k = j
	while true:
		var node2: BarMesh.BMNode = cell_nodes[k]
		ring_b.append(Vector2(node2.p.x, node2.p.y))
		if k == i:
			break
		k = (k + 1) % n
	return minf(_poly_area_xy(ring_a), _poly_area_xy(ring_b))


static func _poly_area_xy(ring: PackedVector2Array) -> float:
	if ring.size() < 3:
		return 0.0
	var a := 0.0
	for i in ring.size():
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[(i + 1) % ring.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


## XY placement for a new node on a live bar (z filled later by dropcutter).
static func bar_insert_xy(bar: BarMesh.BMBar, mode: BarInsertMode = BarInsertMode.XY_MIDPOINT) -> Vector2:
	var a: Vector3 = bar.nodeback.p
	var b: Vector3 = bar.nodefore.p
	if mode == BarInsertMode.XY_PLANE_INTERSECT:
		var t := _bar_plane_intersect_lambda(bar)
		if t > 0.02 and t < 0.98:
			return Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t))
	return Vector2(0.5 * (a.x + b.x), 0.5 * (a.y + b.y))


## Contact planes through tool centres (CL) with contact normals; solve for (t, z)
## on the bar XY line P(t)=(lerp xy, z). Returns lambda in (0,1) or -1 on failure.
static func _bar_plane_intersect_lambda(bar: BarMesh.BMBar) -> float:
	var a: Vector3 = bar.nodeback.p
	var b: Vector3 = bar.nodefore.p
	var na: Vector3 = bar.nodeback.contact_normal
	var nb: Vector3 = bar.nodefore.contact_normal
	if na.length_squared() < 0.25 or nb.length_squared() < 0.25:
		return -1.0
	na = na.normalized()
	nb = nb.normalized()
	var dx := b.x - a.x
	var dy := b.y - a.y
	# na·(P-a)=0, nb·(P-b)=0 with P=(a.x+t*dx, a.y+t*dy, z)
	# [ na.x*dx + na.y*dy , na.z ] [t] = [ 0 ]
	# [ nb.x*dx + nb.y*dy , nb.z ] [z]   [ nb·(b-a)_xy wait ]
	# P-b = ((t-1)*dx, (t-1)*dy, z-b.z)
	# Eq1: na.x*t*dx + na.y*t*dy + na.z*(z-a.z) = 0
	# Eq2: nb.x*(t-1)*dx + nb.y*(t-1)*dy + nb.z*(z-b.z) = 0
	var a11 := na.x * dx + na.y * dy
	var a12 := na.z
	var b1 := na.z * a.z
	var a21 := nb.x * dx + nb.y * dy
	var a22 := nb.z
	# Eq2 expanded: a21*(t-1) + nb.z*(z-b.z)=0 → a21*t + a22*z = a21 + nb.z*b.z
	var b2 := a21 + nb.z * b.z
	var det := a11 * a22 - a12 * a21
	if absf(det) < 1e-12:
		return -1.0
	var t := (b1 * a22 - a12 * b2) / det
	if not is_finite(t):
		return -1.0
	return t
