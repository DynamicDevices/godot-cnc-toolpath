extends MeshInstance3D
## ImmediateMesh draw of CAD Z-up BarMesh. Only this file converts to Godot Y-up.

const BarMeshGD = preload("res://barmesh/barmesh.gd")
const Contact = preload("res://barmesh/tool_contact.gd")

@export var part_path: NodePath = NodePath("../MeshRoot/Part")
@export var nparts: int = 16
@export var row_delay_s: float = 0.06
@export var pad_m: float = 0.003
@export var tool_radius_m: float = 0.0015
@export var epsilon_mm: float = 0.01
@export var stepover_mm: float = 1.0
@export var angle_deg: float = 15.0
@export var max_refine_passes: int = 12
@export var show_bars: bool = true
@export var show_normals: bool = true
@export var include_base_plane: bool = true

var _playing: bool = false
var _run_id: int = 0
var _last_bm: BarMesh
var _normals_mi: MeshInstance3D


static func cad_to_godot(p: Vector3) -> Vector3:
	## CAD Z-up (x, y, z) -> Godot Y-up (x, z, y).
	return Vector3(p.x, p.z, p.y)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.25, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 0.5)
	mat.emission_energy_multiplier = 1.8
	material_override = mat
	_normals_mi = MeshInstance3D.new()
	_normals_mi.name = "ContactNormals"
	var nmat := StandardMaterial3D.new()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.albedo_color = Color(0.25, 0.95, 0.45)
	nmat.emission_enabled = true
	nmat.emission = Color(0.1, 0.6, 0.25)
	_normals_mi.material_override = nmat
	add_child(_normals_mi)
	if DisplayServer.get_name() == "headless":
		row_delay_s = 0.0
	call_deferred("play_over_part")


func play_over_part(p_radius: float = -1.0) -> void:
	var part := get_node_or_null(part_path) as MeshInstance3D
	if part == null or part.mesh == null:
		push_warning("BarMesh draw: no part mesh")
		return
	var R: float = tool_radius_m if p_radius <= 0.0 else p_radius
	_run_id += 1
	var my_run: int = _run_id
	_playing = true
	var aabb: AABB = part.global_transform * part.get_aabb()
	aabb = aabb.grow(pad_m)
	var cad: Dictionary = Contact.cad_aabb_from_godot(aabb)
	var tris: Array = Contact.mesh_triangles_cad(part)
	if include_base_plane:
		tris.append_array(_base_plane_tris(cad))
	var nx := _grid_parts(cad["xmin"], cad["xmax"])
	var ny := _grid_parts(cad["ymin"], cad["ymax"])
	var xpart := BarMeshGD.Partition1.new(cad["xmin"], cad["xmax"], nx)
	var ypart := BarMeshGD.Partition1.new(cad["ymin"], cad["ymax"], ny)
	var z_above: float = cad["zmax"] + R + pad_m
	var z_plane: float = cad["zmin"]
	var bm := BarMeshGD.new()
	bm.start_rect_bar_mesh(xpart, ypart, z_above)
	var more := true
	while more:
		if my_run != _run_id:
			return
		more = bm.add_next_rect_row()
		_drop_last_row(bm, R, tris, z_plane)
		_draw_barmesh(bm)
		if row_delay_s > 0.0:
			await get_tree().create_timer(row_delay_s).timeout
	await _refine_barmesh(bm, R, tris, z_plane, z_above, my_run)
	if my_run == _run_id:
		_playing = false


func _drop_last_row(bm: BarMesh, R: float, tris: Array, z_plane: float) -> void:
	var n: int = bm.nxs()
	if n <= 0:
		return
	var start: int = bm.nodes.size() - n
	for i in range(n):
		var node: BarMesh.BMNode = bm.nodes[start + i]
		_apply_contact(node, R, tris, z_plane)


func _apply_contact(node: BarMesh.BMNode, R: float, tris: Array, z_plane: float) -> void:
	var hit: Dictionary = Contact.drop_tool_contact(node.p.x, node.p.y, R, tris, z_plane)
	node.p.z = float(hit["z"])
	node.contact_kind = int(hit["kind"])
	node.contact_tri = int(hit["tri"])
	node.contact_elem = int(hit["elem"])
	node.contact_normal = hit["normal"]
	node.contact_point = hit["point"]


func _refine_barmesh(bm: BarMesh, R: float, tris: Array, z_plane: float, z_above: float, my_run: int) -> void:
	var params := BarMeshGD.SubdivParams.new()
	params.epsilon_m = epsilon_mm * 0.001
	params.stepover_m = stepover_mm * 0.001
	params.angle_deg = angle_deg
	for _pass in range(max_refine_passes):
		if my_run != _run_id:
			return
		var batch: Array = []
		for bar in bm.live_bars():
			if bm.bar_needs_split(bar, params):
				batch.append(bar)
		if batch.is_empty() or bm.nodes.size() > 8000:
			break
		for bar in batch:
			var b: BarMesh.BMBar = bar
			if b.bbardeleted:
				continue
			var mid := Vector3(
				0.5 * (b.nodeback.p.x + b.nodefore.p.x),
				0.5 * (b.nodeback.p.y + b.nodefore.p.y),
				z_above
			)
			var node: BarMesh.BMNode = bm.new_node(mid)
			_apply_contact(node, R, tris, z_plane)
			bm.insert_node_into_bar_f(b, node)
		_draw_barmesh(bm)
		if row_delay_s > 0.0:
			await get_tree().create_timer(row_delay_s).timeout


func _grid_parts(lo: float, hi: float) -> int:
	var gs: float = maxf(stepover_mm * 0.001, 0.0002)
	return clampi(int(ceil((hi - lo) / gs)), 1, 48)


func _base_plane_tris(cad: Dictionary) -> Array:
	var z0: float = float(cad["zmin"])
	var p00 := Vector3(cad["xmin"], cad["ymin"], z0)
	var p10 := Vector3(cad["xmax"], cad["ymin"], z0)
	var p11 := Vector3(cad["xmax"], cad["ymax"], z0)
	var p01 := Vector3(cad["xmin"], cad["ymax"], z0)
	return [[p00, p10, p11], [p00, p11, p01]]


func set_show_bars(v: bool) -> void:
	show_bars = v
	if _last_bm:
		_draw_barmesh(_last_bm)


func set_show_normals(v: bool) -> void:
	show_normals = v
	if _last_bm:
		_draw_barmesh(_last_bm)


func _draw_barmesh(bm: BarMesh) -> void:
	_last_bm = bm
	if show_bars:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for bar in bm.live_bars():
			var b: BarMesh.BMBar = bar
			im.surface_add_vertex(cad_to_godot(_draw_pt(b.nodeback)))
			im.surface_add_vertex(cad_to_godot(_draw_pt(b.nodefore)))
		im.surface_end()
		mesh = im
	else:
		mesh = null
	if _normals_mi == null:
		return
	if show_normals:
		var nim := ImmediateMesh.new()
		nim.surface_begin(Mesh.PRIMITIVE_LINES)
		var tick: float = 0.003
		for node in bm.nodes:
			var nd: BarMesh.BMNode = node
			if nd.contact_kind == BarMesh.BMNode.ContactFeature.NONE:
				continue
			if nd.contact_normal.length_squared() < 1e-12:
				continue
			var p0: Vector3 = _draw_pt(nd)
			var p1: Vector3 = p0 + nd.contact_normal * tick
			nim.surface_add_vertex(cad_to_godot(p0))
			nim.surface_add_vertex(cad_to_godot(p1))
		nim.surface_end()
		_normals_mi.mesh = nim
	else:
		_normals_mi.mesh = null


func _draw_pt(nd: BarMesh.BMNode) -> Vector3:
	if nd.contact_kind != BarMesh.BMNode.ContactFeature.NONE:
		return nd.contact_point
	return nd.p
