extends Node3D
## Tool-surface session host. Raster/waterline toolpaths live on
## archive/raster-waterline-toolpaths until the BarMesh surface is right.

const MM := 0.001

@export var mesh_path: NodePath = NodePath("MeshRoot/Part")
@export var tool_path: NodePath = NodePath("Tool")
@export var ui_path: NodePath = NodePath("ToolpathUI")
@export var barmesh_preview_path: NodePath = NodePath("BarMeshPreview")

func _ready() -> void:
	var ui := get_node_or_null(ui_path)
	if ui and ui.has_signal("bake_requested"):
		ui.bake_requested.connect(_on_bake_requested)
	if DisplayServer.get_name() != "headless":
		call_deferred("_on_bake_requested", "barmesh", 1.5, 2.0, 1.0, 2.0)


func _on_bake_requested(
	_strategy: String,
	tool_radius_mm: float,
	_stepover_mm: float,
	_sample_step_mm: float,
	_z_stepdown_mm: float
) -> void:
	await bake_strategy("barmesh", tool_radius_mm)


func bake_strategy(strategy: String, tool_radius_mm: float = 1.5, _a = 2.0, _b = 1.0, _c = 2.0) -> Dictionary:
	if strategy != "barmesh":
		push_error("Toolpaths archived; only barmesh/toolsurface is active: " + strategy)
		return {}
	var mesh_inst := get_node(mesh_path) as MeshInstance3D
	var tool_node := get_node(tool_path) as MeshInstance3D
	var ui := get_node_or_null(ui_path)
	var viz := get_node_or_null(barmesh_preview_path)
	if mesh_inst == null or tool_node == null or viz == null:
		push_error("Missing mesh/tool/BarMeshPreview")
		return {}
	var tool_radius := tool_radius_mm * MM
	if tool_node.mesh is SphereMesh:
		var sm := tool_node.mesh as SphereMesh
		sm.radius = maxf(tool_radius, 0.0001)
		sm.height = sm.radius * 2.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	if ui:
		ui.set_status("BarMesh: Z-up contact lattice…")
	if viz.get("tool_radius_m") != null:
		viz.tool_radius_m = tool_radius
	await viz.play_over_part(tool_radius)
	if ui:
		ui.set_status("BarMesh tool-contact lattice (CAD Z-up).")
	return {"strategy": "barmesh", "ok": true}
