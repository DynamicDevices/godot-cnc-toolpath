extends Node3D
## Shared bake glue for raster and waterline strategies.

const MM := 0.001
const PassPlanner = preload("res://scripts/raster_pass_planner.gd")
const Projector = preload("res://scripts/raster_project_to_mesh.gd")
const Waterline = preload("res://scripts/waterline_toolpath.gd")
const AnimMod = preload("res://scripts/toolpath_animation.gd")

@export var mesh_path: NodePath = NodePath("MeshRoot/Part")
@export var tool_path: NodePath = NodePath("Tool")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var preview_2d_path: NodePath = NodePath("Raster2DPreview")
@export var preview_3d_path: NodePath = NodePath("ToolpathPreview")
@export var ui_path: NodePath = NodePath("ToolpathUI")
@export var safe_y_mm: float = 90.0
@export var plane_y_mm: float = 0.0
@export var feed_mm_per_sec: float = 40.0
@export var margin_mm: float = 1.0
@export var default_strategy := "raster"
@export var default_z_stepdown_mm: float = 2.0

var last_bake_stats: Dictionary = {}

func _ready() -> void:
	var ui := get_node_or_null(ui_path)
	if ui and ui.has_signal("bake_requested"):
		ui.bake_requested.connect(_on_bake_requested)
	if DisplayServer.get_name() != "headless":
		call_deferred(
			"_on_bake_requested",
			default_strategy,
			1.5,
			2.0,
			1.0,
			default_z_stepdown_mm
		)

func _on_bake_requested(
	strategy: String,
	tool_radius_mm: float,
	stepover_mm: float,
	sample_step_mm: float,
	z_stepdown_mm: float
) -> void:
	await bake_strategy(strategy, tool_radius_mm, stepover_mm, sample_step_mm, z_stepdown_mm)

func bake_strategy(
	strategy: String,
	tool_radius_mm: float = 1.5,
	stepover_mm: float = 2.0,
	sample_step_mm: float = 1.0,
	z_stepdown_mm: float = 2.0
) -> Dictionary:
	var mesh_inst := get_node(mesh_path) as MeshInstance3D
	var tool_node := get_node(tool_path) as MeshInstance3D
	var anim_player := get_node(animation_player_path) as AnimationPlayer
	var preview_2d := get_node_or_null(preview_2d_path) as MeshInstance3D
	var preview_3d := get_node_or_null(preview_3d_path) as MeshInstance3D
	var ui := get_node_or_null(ui_path)
	if mesh_inst == null or tool_node == null or anim_player == null or preview_3d == null:
		push_error("Missing mesh/tool/AnimationPlayer/ToolpathPreview")
		return {}

	var tool_radius := tool_radius_mm * MM
	var stepover := stepover_mm * MM
	var sample_step := sample_step_mm * MM
	var z_stepdown := z_stepdown_mm * MM
	var safe_y := safe_y_mm * MM
	var plane_y := plane_y_mm * MM
	var feed := feed_mm_per_sec * MM
	var margin := margin_mm * MM

	if tool_node.mesh is SphereMesh:
		var sm := tool_node.mesh as SphereMesh
		sm.radius = maxf(tool_radius, 0.0001)
		sm.height = sm.radius * 2.0

	await get_tree().physics_frame
	await get_tree().physics_frame

	if strategy == "waterline":
		last_bake_stats = _bake_waterline(
			mesh_inst, preview_2d, preview_3d, anim_player, ui,
			tool_radius, z_stepdown, sample_step, plane_y, safe_y, feed
		)
	else:
		last_bake_stats = _bake_raster(
			mesh_inst, preview_2d, preview_3d, anim_player, ui,
			tool_radius, stepover, sample_step, plane_y, safe_y, feed, margin
		)
	return last_bake_stats

func _bake_raster(
	mesh_inst: MeshInstance3D,
	preview_2d: MeshInstance3D,
	preview_3d: MeshInstance3D,
	anim_player: AnimationPlayer,
	ui: Node,
	tool_radius: float,
	stepover: float,
	sample_step: float,
	plane_y: float,
	safe_y: float,
	feed: float,
	margin: float
) -> Dictionary:
	# Stage 1 — 2D raster line mesh (separate line per pass).
	var bounds: Dictionary = Projector.mesh_bounds_xz(mesh_inst, margin)
	var passes: Array = PassPlanner.make_passes(
		bounds["min_x"], bounds["max_x"], bounds["min_z"], bounds["max_z"],
		stepover, sample_step
	)
	var mesh_2d: ArrayMesh = PassPlanner.make_2d_line_mesh(passes, plane_y)
	if preview_2d:
		preview_2d.mesh = mesh_2d

	# Stage 2 — project 2D passes onto 3D mesh with tool + tolerances.
	var tool_def = Projector.ToolDef.new(tool_radius, safe_y)
	# No-hit samples rest on the base plane (plane_y), not clearance/safe height.
	var tol = Projector.Tolerances.new(plane_y)
	var projected: Dictionary = Projector.compute_line_mesh(
		passes,
		mesh_inst,
		tool_def,
		tol
	)
	var mesh_3d: ArrayMesh = projected["mesh"]
	var points: PackedVector3Array = projected["points"]
	preview_3d.mesh = mesh_3d

	if points.is_empty():
		if ui:
			ui.set_status("No projected points — check mesh collision")
		return {}

	# Stage 3 — animation from projected points.
	var anim: Animation = AnimMod.from_points(points, NodePath("Tool"), feed)
	_install_animation(anim_player, "raster_toolpath", anim)

	DirAccess.make_dir_recursive_absolute("res://animations")
	var e1 := ResourceSaver.save(mesh_2d, "res://animations/raster_passes_2d.tres")
	var e2 := ResourceSaver.save(mesh_3d, "res://animations/raster_toolpath_lines.tres")
	var e3 := ResourceSaver.save(anim, "res://animations/raster_toolpath.tres")
	var status := "2D(%d passes)→project→anim %d pts" % [mesh_2d.get_surface_count(), points.size()]
	if e1 != OK or e2 != OK or e3 != OK:
		status += " (save failed)"
	else:
		status += " — saved"
	if ui:
		ui.set_status(status)
	print(status)
	return {
		"strategy": "raster",
		"points": points.size(),
		"passes": mesh_2d.get_surface_count(),
	}

func _bake_waterline(
	mesh_inst: MeshInstance3D,
	preview_2d: MeshInstance3D,
	preview_3d: MeshInstance3D,
	anim_player: AnimationPlayer,
	ui: Node,
	tool_radius: float,
	z_stepdown: float,
	sample_step: float,
	plane_y: float,
	safe_y: float,
	feed: float
) -> Dictionary:
	var result: Dictionary = Waterline.compute(
		mesh_inst, tool_radius, z_stepdown, sample_step, plane_y, safe_y
	)
	var path_mesh: ArrayMesh = result["mesh"]
	var contour_mesh: ArrayMesh = result["contour_mesh"]
	var points: PackedVector3Array = result["points"]
	if preview_2d:
		preview_2d.mesh = contour_mesh
	preview_3d.mesh = path_mesh
	if points.is_empty():
		if ui:
			ui.set_status("No waterline contours — check mesh/floor/stepdown")
		return result

	var anim: Animation = AnimMod.from_points(points, NodePath("Tool"), feed)
	anim.resource_name = "waterline_toolpath"
	_install_animation(anim_player, "waterline_toolpath", anim)

	DirAccess.make_dir_recursive_absolute("res://animations")
	var e1 := ResourceSaver.save(contour_mesh, "res://animations/waterline_contours.tres")
	var e2 := ResourceSaver.save(path_mesh, "res://animations/waterline_toolpath_lines.tres")
	var e3 := ResourceSaver.save(anim, "res://animations/waterline_toolpath.tres")
	var levels: Array = result["cut_levels"]
	var status := "Waterline %d levels / %d contours / %d pts" % [
		levels.size(), result["contour_count"], points.size()
	]
	if e1 != OK or e2 != OK or e3 != OK:
		status += " (save failed)"
	else:
		status += " — saved"
	if ui:
		ui.set_status(status)
	print(status)
	result["strategy"] = "waterline"
	return result

func _install_animation(anim_player: AnimationPlayer, name: String, anim: Animation) -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(name, anim)
	if anim_player.has_animation_library("cnc"):
		anim_player.remove_animation_library("cnc")
	anim_player.add_animation_library("cnc", lib)
	anim_player.play("cnc/" + name)
