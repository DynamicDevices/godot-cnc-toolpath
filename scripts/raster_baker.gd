extends Node3D
## Raster toolpath baker: updates AnimationPlayer + Path3D from UI params.
## tool_radius currently sizes the tool mesh and lifts the contact point by that amount.

@export var mesh_path: NodePath = NodePath("MeshRoot/Part")
@export var tool_path: NodePath = NodePath("Tool")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var path3d_path: NodePath = NodePath("Toolpath")
@export var ui_path: NodePath = NodePath("ToolpathUI")
@export var safe_y: float = 1.4
@export var feed_units_per_sec: float = 0.9
@export var margin: float = 0.05

func _ready() -> void:
	var ui := get_node_or_null(ui_path)
	if ui and ui.has_signal("bake_requested"):
		ui.bake_requested.connect(_on_bake_requested)
	# Initial bake after mesh collision exists.
	call_deferred("_on_bake_requested", 0.05, 0.12, 0.04)

func _on_bake_requested(tool_radius: float, stepover: float, sample_step: float) -> void:
	var mesh_inst := get_node(mesh_path) as MeshInstance3D
	var tool := get_node(tool_path) as MeshInstance3D
	var anim_player := get_node(animation_player_path) as AnimationPlayer
	var path3d := get_node(path3d_path) as Path3D
	var ui := get_node_or_null(ui_path)
	if mesh_inst == null or tool == null or anim_player == null or path3d == null:
		push_error("Missing mesh/tool/AnimationPlayer/Path3D")
		return

	# Visual tool size.
	if tool.mesh is SphereMesh:
		var sm := tool.mesh as SphereMesh
		sm.radius = maxf(tool_radius, 0.005)
		sm.height = sm.radius * 2.0

	await get_tree().physics_frame
	await get_tree().physics_frame

	var aabb := mesh_inst.get_aabb()
	var xf := mesh_inst.global_transform
	var corners: Array[Vector3] = []
	for i in 8:
		var local := Vector3(
			aabb.position.x + (aabb.size.x if (i & 1) else 0.0),
			aabb.position.y + (aabb.size.y if (i & 2) else 0.0),
			aabb.position.z + (aabb.size.z if (i & 4) else 0.0)
		)
		corners.append(xf * local)

	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_z := corners[0].z
	var max_z := corners[0].z
	var max_y := corners[0].y
	for c in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_z = minf(min_z, c.z)
		max_z = maxf(max_z, c.z)
		max_y = maxf(max_y, c.y)

	min_x += margin
	max_x -= margin
	min_z += margin
	max_z -= margin

	var points: Array[Vector3] = []
	var space := get_world_3d().direct_space_state
	var row := 0
	var z := min_z
	var y_start := max_y + 2.0
	while z <= max_z + 1e-6:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-6:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()
		if xs.size() > 0:
			points.append(Vector3(xs[0], safe_y, z))
		for sx in xs:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(sx, y_start, z),
				Vector3(sx, -10.0, z)
			)
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
				# Simple ball-nose compensation: lift by tool radius along +Y.
				p.y += tool_radius
				points.append(p)
			else:
				points.append(Vector3(sx, safe_y, z))
		if points.size() > 0:
			var last: Vector3 = points[points.size() - 1]
			points.append(Vector3(last.x, safe_y, last.z))
		z += stepover
		row += 1

	if points.is_empty():
		if ui:
			ui.set_status("No points — check mesh collision")
		return

	# Update Path3D curve (editor-visible after save; live in play mode).
	var curve := Curve3D.new()
	for p in points:
		curve.add_point(p)
	path3d.curve = curve

	# Bake Animation.
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("Tool"))
	var t := 0.0
	var prev: Vector3 = points[0]
	anim.track_insert_key(track, t, prev)
	for i in range(1, points.size()):
		var cur: Vector3 = points[i]
		t += maxf(prev.distance_to(cur) / feed_units_per_sec, 0.01)
		anim.track_insert_key(track, t, cur)
		prev = cur
	anim.length = t
	anim.resource_name = "raster_toolpath"

	var lib := AnimationLibrary.new()
	lib.add_animation("raster_toolpath", anim)
	if anim_player.has_animation_library("cnc"):
		anim_player.remove_animation_library("cnc")
	anim_player.add_animation_library("cnc", lib)
	anim_player.play("cnc/raster_toolpath")

	# Persist into res:// so the editor can reload them next open.
	# (Works when running from the editor / writable project.)
	DirAccess.make_dir_recursive_absolute("res://animations")
	var err1 := ResourceSaver.save(anim, "res://animations/raster_toolpath.tres")
	var err2 := ResourceSaver.save(curve, "res://animations/raster_toolpath_curve.tres")
	var status := "Baked %d pts, %.1fs" % [points.size(), anim.length]
	if err1 != OK or err2 != OK:
		status += " (runtime only — save failed)"
	else:
		status += " — saved to animations/"
	if ui:
		ui.set_status(status)
	print(status)
