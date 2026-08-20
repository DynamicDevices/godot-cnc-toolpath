extends SceneTree
## CI: bake BarMesh on the real eartip and fail on fall-through.
## Checks: |CL−contact|≈R; sphere not penetrating drop tris; CL not below top skin at XY.
## Headless: godot --headless --path . -s res://tools/test_eartip_quality.gd

const Contact := preload("res://barmesh/tool_contact.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("EARTIP_QUALITY_FAIL " + msg)
	quit(1)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("load main")
		return
	var root: Node = packed.instantiate()
	root.name = "Main"
	get_root().add_child(root)
	for i in 8:
		await process_frame

	var R_mm := 1.5
	var R := R_mm * 0.001
	var stats: Dictionary = await root.bake_strategy("barmesh", R_mm, 1.0, 0.01, 15.0)
	if stats.is_empty():
		_fail("bake empty")
		return

	var preview := root.get_node_or_null("BarMeshPreview")
	if preview == null or not preview.has_method("get_last_barmesh"):
		_fail("no preview accessors")
		return
	var bm = preview.get_last_barmesh()
	var tris: Array = preview.get_last_tris_cad()
	if bm == null or bm.nodes.is_empty():
		_fail("empty barmesh")
		return
	if tris.is_empty():
		_fail("empty tris")
		return

	# Part-only tris (exclude synthetic base plane at zmin) for top-skin checks.
	var zmin := 1e30
	for tri in tris:
		for v in tri:
			zmin = minf(zmin, v.z)
	var part_tris: Array = []
	for tri in tris:
		var on_base := true
		for v in tri:
			if absf(v.z - zmin) > 1e-6:
				on_base = false
				break
		if not on_base:
			part_tris.append(tri)

	var tol := 2e-4
	var checked := 0
	var below_skin := 0
	var low_flat := 0
	var penetrations := 0
	var worst_below := 0.0
	var worst_flat := 0.0
	var worst_at := Vector3.ZERO
	for node in bm.nodes:
		var nd = node
		if nd.contact_kind == 0:
			continue
		var cl: Vector3 = nd.p
		var d_contact: float = cl.distance_to(nd.contact_point)
		if absf(d_contact - R) > tol:
			_fail("|CL-contact|!=R d=%s R=%s at %s" % [d_contact, R, cl])
			return
		var d_mesh: float = Contact.min_distance_point_to_tris(cl, tris)
		if d_mesh < R - tol:
			penetrations += 1
		var z_skin: float = Contact.highest_surface_z_at_xy(cl.x, cl.y, part_tris)
		if is_finite(z_skin) and cl.z < z_skin - tol:
			below_skin += 1
			var depth: float = z_skin - cl.z
			if depth > worst_below:
				worst_below = depth
				worst_at = cl
			if below_skin <= 8:
				push_warning(
					"EARTIP_BELOW_SKIN cl.z=%s skin=%s depth_mm=%s at (%s,%s)"
					% [cl.z, z_skin, depth * 1000.0, cl.x, cl.y]
				)
		# Near-horizontal skin: ball CL must be ~ skin + R (Julian fall-through class).
		if is_finite(z_skin) and nd.contact_normal.z > 0.92:
			var expect_z: float = z_skin + R * nd.contact_normal.z
			if cl.z < expect_z - tol:
				low_flat += 1
				var gap: float = expect_z - cl.z
				if gap > worst_flat:
					worst_flat = gap
					worst_at = cl
				if low_flat <= 8:
					push_warning(
						"EARTIP_LOW_FLAT cl.z=%s expect=%s gap_mm=%s at (%s,%s)"
						% [cl.z, expect_z, gap * 1000.0, cl.x, cl.y]
					)
		checked += 1

	if checked < 10:
		_fail("too few contact nodes " + str(checked))
		return

	if penetrations > 0:
		_fail("sphere penetration at %s of %s nodes" % [penetrations, checked])
		return

	if below_skin > 0:
		_fail(
			"CL below top skin at %s of %s nodes; worst depth_mm=%s at %s"
			% [below_skin, checked, worst_below * 1000.0, worst_at]
		)
		return

	if low_flat > 0:
		_fail(
			"CL too low on flat skin at %s of %s nodes; worst gap_mm=%s at %s"
			% [low_flat, checked, worst_flat * 1000.0, worst_at]
		)
		return

	print(
		"EARTIP_QUALITY_OK nodes=",
		checked,
		" part_tris=",
		part_tris.size(),
		" R_mm=",
		R_mm
	)
	quit(0)
