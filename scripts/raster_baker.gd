extends Node3D
## Raster toolpath baker: Bake UI (mm) → Animation + line-mesh preview (metres).

const MM := 0.001

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
	var tool := get_node(tool_path) as MeshInstance3D
	var anim_player := get_node(animation_player_path) as AnimationPlayer
	var preview := get_node_or_null(preview_path) as MeshInstance3D
	var ui := get_node_or_null(ui_path)
	if mesh_inst == null or tool == null or anim_player == null or preview == null:
		push_error("Missing mesh/tool/AnimationPlayer/ToolpathPreview")
		return

	var tool_radius := tool_radius_mm * MM
	var stepover := stepover_mm * MM
	var sample_step := sample_step_mm * MM
	var safe_y := safe_y_mm * MM
	var feed := feed_mm_per_sec * MM
	var margin := margin_mm * MM

	if tool.mesh is SphereMesh:
		var sm := tool.mesh as SphereMesh
		sm.radius = maxf(tool_radius, 0.0001)
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
	var y_start := max_y + 0.05
	while z <= max_z + 1e-9:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-9:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()
		if xs.size() > 0:
			points.append(Vector3(xs[0], safe_y, z))
		for sx in xs:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(sx, y_start, z),
				Vector3(sx, -0.05, z)
			)
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
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

	var line_mesh := _make_line_mesh(points)
	preview.mesh = line_mesh

	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath("Tool"))
	var t := 0.0
	var prev: Vector3 = points[0]
	anim.track_insert_key(track, t, prev)
	for i in range(1, points.size()):
		var cur: Vector3 = points[i]
		t += maxf(prev.distance_to(cur) / maxf(feed, 1e-6), 0.01)
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

	DirAccess.make_dir_recursive_absolute("res://animations")
	var err1 := ResourceSaver.save(anim, "res://animations/raster_toolpath.tres")
	var err3 := ResourceSaver.save(line_mesh, "res://animations/raster_toolpath_lines.tres")
	var status := "Baked %d pts, %.1fs — line-mesh preview" % [points.size(), anim.length]
	if err1 != OK or err3 != OK:
		status += " (some saves failed)"
	else:
		status += " + animations/*.tres"
	if ui:
		ui.set_status(status)
	print(status)

func _make_line_mesh(points: Array[Vector3]) -> ArrayMesh:
	var verts := PackedVector3Array()
	for p in points:
		verts.append(p)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return am
