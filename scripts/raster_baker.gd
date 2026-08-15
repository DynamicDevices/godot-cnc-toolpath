extends Node3D
## Scene glue only:
##   RasterPassPlanner → RasterToolpathCalc (passes+mesh+tool → line mesh)
##   → ToolpathAnimation (line mesh/points → Animation) → save assets.

const MM := 0.001
const PassPlanner = preload("res://scripts/raster_pass_planner.gd")
const Calc = preload("res://scripts/raster_toolpath_calc.gd")
const AnimMod = preload("res://scripts/toolpath_animation.gd")

@export var mesh_path: NodePath = NodePath("MeshRoot/Part")
@export var tool_path: NodePath = NodePath("Tool")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var preview_path: NodePath = NodePath("ToolpathPreview")
@export var ui_path: NodePath = NodePath("ToolpathUI")
@export var safe_y_mm: float = 90.0
@export var feed_mm_per_sec: float = 40.0
@export var margin_mm: float = 1.0

func _ready() -> void:
	var ui := get_node_or_null(ui_path)
	if ui and ui.has_signal("bake_requested"):
		ui.bake_requested.connect(_on_bake_requested)
	call_deferred("_on_bake_requested", 1.5, 2.0, 1.0)

func _on_bake_requested(tool_radius_mm: float, stepover_mm: float, sample_step_mm: float) -> void:
	var mesh_inst := get_node(mesh_path) as MeshInstance3D
	var tool_node := get_node(tool_path) as MeshInstance3D
	var anim_player := get_node(animation_player_path) as AnimationPlayer
	var preview := get_node_or_null(preview_path) as MeshInstance3D
	var ui := get_node_or_null(ui_path)
	if mesh_inst == null or tool_node == null or anim_player == null or preview == null:
		push_error("Missing mesh/tool/AnimationPlayer/ToolpathPreview")
		return

	var tool_radius := tool_radius_mm * MM
	var stepover := stepover_mm * MM
	var sample_step := sample_step_mm * MM
	var safe_y := safe_y_mm * MM
	var feed := feed_mm_per_sec * MM
	var margin := margin_mm * MM

	if tool_node.mesh is SphereMesh:
		var sm := tool_node.mesh as SphereMesh
		sm.radius = maxf(tool_radius, 0.0001)
		sm.height = sm.radius * 2.0

	await get_tree().physics_frame
	await get_tree().physics_frame

	var bounds: Dictionary = Calc.mesh_bounds_xz(mesh_inst, margin)
	var passes: Array = PassPlanner.make_passes(
		bounds["min_x"], bounds["max_x"], bounds["min_z"], bounds["max_z"],
		stepover, sample_step
	)
	var tool_def = Calc.ToolDef.new(tool_radius, safe_y)
	var result: Dictionary = Calc.compute_line_mesh(
		passes,
		get_world_3d().direct_space_state,
		mesh_inst,
		tool_def
	)
	var points: PackedVector3Array = result["points"]
	var line_mesh: ArrayMesh = result["mesh"]
	if points.is_empty():
		if ui:
			ui.set_status("No points — check mesh collision")
		return

	preview.mesh = line_mesh

	var anim: Animation = AnimMod.from_points(points, NodePath("Tool"), feed)
	var lib := AnimationLibrary.new()
	lib.add_animation("raster_toolpath", anim)
	if anim_player.has_animation_library("cnc"):
		anim_player.remove_animation_library("cnc")
	anim_player.add_animation_library("cnc", lib)
	anim_player.play("cnc/raster_toolpath")

	DirAccess.make_dir_recursive_absolute("res://animations")
	var err1 := ResourceSaver.save(anim, "res://animations/raster_toolpath.tres")
	var err3 := ResourceSaver.save(line_mesh, "res://animations/raster_toolpath_lines.tres")
	var status := "passes→line mesh→anim %d pts, %.1fs" % [points.size(), anim.length]
	if err1 != OK or err3 != OK:
		status += " (save failed)"
	else:
		status += " — saved"
	if ui:
		ui.set_status(status)
	print(status)
