extends Node3D
## Raster (scan-line) 3-axis toolpath over a MeshInstance3D.
## Samples Z by casting rays downward; keys XYZ onto AnimationPlayer.

@export var mesh_path: NodePath = NodePath("MeshRoot/Part")
@export var tool_path: NodePath = NodePath("Tool")
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var stepover: float = 0.15
@export var sample_step: float = 0.05
@export var safe_z: float = 1.2
@export var feed_units_per_sec: float = 0.8
@export var margin: float = 0.05

func _ready() -> void:
	call_deferred("_build_and_play")

func _build_and_play() -> void:
	var mesh_inst := get_node(mesh_path) as MeshInstance3D
	var tool := get_node(tool_path) as Node3D
	var anim_player := get_node(animation_player_path) as AnimationPlayer
	if mesh_inst == null or tool == null or anim_player == null:
		push_error("Missing mesh/tool/AnimationPlayer")
		return

	var aabb := mesh_inst.get_aabb()
	# Transform AABB into this node's space roughly via mesh global transform.
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
	var y_start := max_y + 2.0
	var space := get_world_3d().direct_space_state
	var row := 0
	var z := min_z
	while z <= max_z + 1e-6:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-6:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()

		# Rapid at safe height to first sample of the row.
		if xs.size() > 0:
			points.append(Vector3(xs[0], safe_z, z))

		for sx in xs:
			var from := Vector3(sx, y_start, z)
			var to := Vector3(sx, -10.0, z)
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			var hit := space.intersect_ray(q)
			if hit:
				var p: Vector3 = hit.position
				# Slight retract so tool sits on surface (+Y up in this demo).
				points.append(Vector3(p.x, p.y + 0.02, p.z))
			else:
				# Air move at safe Z if no hit.
				points.append(Vector3(sx, safe_z, z))

		# Lift at end of row.
		if points.size() > 0:
			var last: Vector3 = points[points.size() - 1]
			points.append(Vector3(last.x, safe_z, last.z))

		z += stepover
		row += 1

	if points.is_empty():
		push_error("No toolpath points generated")
		return

	var anim := Animation.new()
	anim.length = 0.0
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath(str(tool_path)))

	var t := 0.0
	var prev: Vector3 = points[0]
	anim.track_insert_key(track, t, prev)
	for i in range(1, points.size()):
		var cur: Vector3 = points[i]
		var dist := prev.distance_to(cur)
		t += maxf(dist / feed_units_per_sec, 0.01)
		anim.track_insert_key(track, t, cur)
		prev = cur
	anim.length = t

	var lib := AnimationLibrary.new()
	lib.add_animation("raster_toolpath", anim)
	if anim_player.has_animation_library("cnc"):
		anim_player.remove_animation_library("cnc")
	anim_player.add_animation_library("cnc", lib)
	anim_player.play("cnc/raster_toolpath")
	print("Raster toolpath: %d points, %.2fs" % [points.size(), anim.length])
