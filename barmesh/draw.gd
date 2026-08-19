extends MeshInstance3D
## ImmediateMesh draw of CAD Z-up BarMesh. Only this file converts to Godot Y-up.

const BarMeshGD = preload("res://barmesh/barmesh.gd")
const Contact = preload("res://barmesh/tool_contact.gd")

@export var part_path: NodePath = NodePath("../MeshRoot/Part")
@export var nparts: int = 16
@export var row_delay_s: float = 0.06
@export var pad_m: float = 0.003
@export var tool_radius_m: float = 0.0015

var _playing: bool = false
var _run_id: int = 0


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
	var xpart := BarMeshGD.Partition1.new(cad["xmin"], cad["xmax"], nparts)
	var ypart := BarMeshGD.Partition1.new(cad["ymin"], cad["ymax"], nparts)
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
	if my_run == _run_id:
		_playing = false


func _drop_last_row(bm: BarMesh, R: float, tris: Array, z_plane: float) -> void:
	var n: int = bm.nxs()
	if n <= 0:
		return
	var start: int = bm.nodes.size() - n
	for i in range(n):
		var node: BarMesh.BMNode = bm.nodes[start + i]
		node.p.z = Contact.drop_tool_z(node.p.x, node.p.y, R, tris, z_plane)


func _draw_barmesh(bm: BarMesh) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for bar in bm.live_bars():
		var b: BarMesh.BMBar = bar
		im.surface_add_vertex(cad_to_godot(b.nodeback.p))
		im.surface_add_vertex(cad_to_godot(b.nodefore.p))
	im.surface_end()
	mesh = im
