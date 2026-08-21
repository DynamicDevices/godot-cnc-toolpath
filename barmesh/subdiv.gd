class_name BarMeshSubdiv
extends RefCounted
## Bar vs cell subdivision conditions and insertion placement (Julian).
## Keep this module separate from BarMesh topology (InsertNodeIntoBarF /
## MakeBarBetweenNodesF). Parameters are shared; predicates and placement differ.

class Params:
	## External refine knobs. Defaults: 0.01 mm, 1 mm, 15°.
	var epsilon_m: float = 0.00001
	var stepover_m: float = 0.001
	var angle_deg: float = 15.0


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


## Face/cell (MakeBarBetweenNodesF) — Julian CNC 127:
## Prefer largest cells whose contact points stay near-coplanar; shrink XY when
## contact normals span a wide range. Connect opposite-side nodes that are not
## near-colinear and that avoid narrow slivers.
static func cell_needs_split(cell_nodes: Array, params: Params) -> bool:
	if cell_nodes.size() < 3:
		return false
	var xmin := INF
	var xmax := -INF
	var ymin := INF
	var ymax := -INF
	var normals: Array[Vector3] = []
	var points: Array[Vector3] = []
	for n in cell_nodes:
		var node: BarMesh.BMNode = n
		xmin = minf(xmin, node.p.x)
		xmax = maxf(xmax, node.p.x)
		ymin = minf(ymin, node.p.y)
		ymax = maxf(ymax, node.p.y)
		if node.contact_normal.length_squared() > 0.25:
			normals.append(node.contact_normal.normalized())
		if node.contact_point != Vector3.ZERO or node.contact_kind != BarMesh.BMNode.ContactFeature.NONE:
			points.append(node.contact_point)
	var dxy := maxf(xmax - xmin, ymax - ymin)
	if dxy <= params.epsilon_m:
		return false
	# Wide normal range → keep this cell from staying large in XY.
	if _normals_span_exceeds(normals, params.angle_deg):
		return true
	# Contact points not close to coplanar → subdivide.
	if points.size() >= 4 and not _points_near_coplanar(points, params.epsilon_m):
		return true
	return false


## Among candidate opposite-side node pairs, pick one that is not near-colinear
## with a cell edge and that maximises the smaller of the two resulting face
## areas (sliver avoidance). Returns [node_a, node_b] or empty.
static func pick_cell_split_pair(cell_nodes: Array, params: Params) -> Array:
	var n: int = cell_nodes.size()
	if n < 4:
		return []
	var best: Array = []
	var best_score := -INF
	var cos_colin := cos(deg_to_rad(maxf(180.0 - params.angle_deg, 1.0)))
	for i in n:
		# Opposite-ish: about halfway around the ring.
		var j := (i + n / 2) % n
		if j == i:
			continue
		var a: BarMesh.BMNode = cell_nodes[i]
		var b: BarMesh.BMNode = cell_nodes[j]
		var ab := Vector2(b.p.x - a.p.x, b.p.y - a.p.y)
		if ab.length() <= params.epsilon_m:
			continue
		var abn := ab.normalized()
		# Reject if nearly colinear with either adjacent edge at a or b.
		var prev_a: BarMesh.BMNode = cell_nodes[(i - 1 + n) % n]
		var next_a: BarMesh.BMNode = cell_nodes[(i + 1) % n]
		if _edge_dir_xy(prev_a, a).dot(abn) > cos_colin:
			continue
		if _edge_dir_xy(a, next_a).dot(abn) > cos_colin:
			continue
		var area_score := _split_min_poly_area_xy(cell_nodes, i, j)
		if area_score > best_score:
			best_score = area_score
			best = [a, b]
	return best


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
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 1e-24:
		return false
	n = n.normalized()
	for i in range(3, points.size()):
		if absf(n.dot(points[i] - p0)) > tol:
			return false
	return true


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
