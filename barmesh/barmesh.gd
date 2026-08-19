class_name BarMesh
extends RefCounted
## CAD Z-up BarMesh (vendor/barmesh/barmesh.py subset).
## Node.p is (x, y, z) with Z up. Do not put these vectors on Node3D without
## the draw conversion to Godot Y-up.

class Partition1:
	var lo: float
	var hi: float
	var nparts: int
	var vs: PackedFloat32Array = PackedFloat32Array()

	func _init(p_lo: float, p_hi: float, p_nparts: int) -> void:
		lo = p_lo
		hi = p_hi
		nparts = p_nparts
		vs.resize(p_nparts + 1)
		for i in range(p_nparts + 1):
			var lam := float(i) / float(p_nparts)
			vs[i] = lo * (1.0 - lam) + hi * lam


class BMNode:
	## Tool pose in contact: cutter location in CAD XYZ (Z up).
	enum ContactFeature { NONE, VERTEX, EDGE, FACE }

	var p: Vector3
	var i: int
	var pointzone = null
	## Unit normal at the mesh contact, CAD Z-up, pointing from part toward the tool.
	var contact_normal: Vector3 = Vector3.ZERO
	var contact_kind: int = ContactFeature.NONE
	## Index into the CAD triangle list used for the drop.
	var contact_tri: int = -1
	## Vertex 0–2, edge 0–2 (a-b, b-c, c-a), unused for FACE.
	var contact_elem: int = -1

	func _init(p_p: Vector3, p_i: int) -> void:
		p = p_p
		i = p_i


class BMBar:
	var nodeback: BMNode
	var nodefore: BMNode
	var barforeright: BMBar
	var barbackleft: BMBar
	var bbardeleted: bool = false
	var barvecN: Vector3

	func _init(p_back: BMNode, p_fore: BMNode) -> void:
		assert(p_fore.i > p_back.i)
		nodeback = p_back
		nodefore = p_fore
		barvecN = (p_fore.p - p_back.p).normalized()


var nodes: Array = []
var bars: Array = []
var xlo: float = 0.0
var xhi: float = 0.0
var ylo: float = 0.0
var yhi: float = 0.0
var zlo: float = 0.0
var zhi: float = 0.0

var _xpart: Partition1
var _ypart: Partition1
var _z: float = 0.0
var _nxs: int = 0
var _xbars: Array = []
var _ybars: Array = []
var _next_y: int = 0


func nxs() -> int:
	return _nxs


func new_node(p: Vector3) -> BMNode:
	if nodes.is_empty():
		xlo = p.x
		xhi = p.x
		ylo = p.y
		yhi = p.y
		zlo = p.z
		zhi = p.z
	else:
		xlo = minf(xlo, p.x)
		xhi = maxf(xhi, p.x)
		ylo = minf(ylo, p.y)
		yhi = maxf(yhi, p.y)
		zlo = minf(zlo, p.z)
		zhi = maxf(zhi, p.z)
	var node := BMNode.new(p, nodes.size())
	nodes.append(node)
	return node


func start_rect_bar_mesh(xpart: Partition1, ypart: Partition1, z: float) -> void:
	nodes.clear()
	bars.clear()
	_xpart = xpart
	_ypart = ypart
	_z = z
	_nxs = xpart.nparts + 1
	_xbars.clear()
	_ybars.clear()
	_next_y = 0


func add_next_rect_row() -> bool:
	if _ypart == null or _next_y >= _ypart.vs.size():
		return false
	var y: float = _ypart.vs[_next_y]
	var bfirstrow := nodes.is_empty()
	for i in range(_nxs):
		new_node(Vector3(_xpart.vs[i], y, _z))
		if not bfirstrow:
			var xbar := BMBar.new(nodes[-_nxs - 1], nodes[-1])
			_xbars.append(xbar)
			bars.append(xbar)
			if i != 0:
				xbar.barbackleft = _ybars[1 - _nxs]
				_ybars[1 - _nxs].barbackleft = _xbars[-2]
		if i != 0:
			var ybar := BMBar.new(nodes[-2], nodes[-1])
			_ybars.append(ybar)
			bars.append(ybar)
			if not bfirstrow:
				ybar.barforeright = _xbars[-1]
				_xbars[-2].barforeright = ybar
	_next_y += 1
	return _next_y < _ypart.vs.size()


func build_rect_bar_mesh(xpart: Partition1, ypart: Partition1, z: float) -> void:
	start_rect_bar_mesh(xpart, ypart, z)
	while add_next_rect_row():
		pass


func live_bars() -> Array:
	var out: Array = []
	for bar in bars:
		var b: BMBar = bar
		if not b.bbardeleted:
			out.append(b)
	return out
