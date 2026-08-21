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


## Face/cell: MakeBarBetweenNodesF — conditions TBD with Julian; stub keeps API ready.
static func cell_needs_split(_cell_bars: Array, _params: Params) -> bool:
	return false


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
