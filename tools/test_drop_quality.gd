extends SceneTree
## CI quality model of Julian's debug case: 2-triangle flat plate + dense drop probes.
## Also a shallow roof (two slopes) so fall-through on edges/faces fails the job.
## Headless: godot --headless --path . -s res://tools/test_drop_quality.gd

const Contact := preload("res://barmesh/tool_contact.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("DROP_QUALITY_FAIL " + msg)
	quit(1)


func _near(a: float, b: float, eps: float = 1e-5) -> bool:
	return absf(a - b) <= eps


func _check_hit(hit: Dictionary, x: float, y: float, R: float, z_min: float, label: String) -> void:
	if not _near(float(hit["x"]), x) or not _near(float(hit["y"]), y):
		_fail("%s CL xy drifted (%s,%s) -> (%s,%s)" % [label, x, y, hit["x"], hit["y"]])
		return
	var z: float = float(hit["z"])
	if z < z_min - 1e-5:
		_fail("%s fall-through z=%s < %s at (%s,%s)" % [label, z, z_min, x, y])
		return
	if int(hit["kind"]) == 0:
		_fail("%s no contact at (%s,%s)" % [label, x, y])
		return
	var cl := Vector3(x, y, z)
	if absf(cl.distance_to(hit["point"]) - R) > 1e-4:
		_fail("%s |CL-pt|!=R at (%s,%s) d=%s" % [label, x, y, cl.distance_to(hit["point"])])
		return


func _run() -> void:
	var R := 0.0015
	var z_plane := 0.0
	# Same idea as Debug flat mesh: two triangles, CAD Z-up, rectangle in XY.
	var p00 := Vector3(0, 0, z_plane)
	var p10 := Vector3(0.02, 0, z_plane)
	var p11 := Vector3(0.02, 0.02, z_plane)
	var p01 := Vector3(0, 0.02, z_plane)
	var flat: Array = [[p00, p10, p11], [p00, p11, p01]]

	var n_ok := 0
	var nx := 9
	var ny := 9
	for ix in nx:
		for iy in ny:
			var x: float = 0.001 + (0.018 * float(ix) / float(nx - 1))
			var y: float = 0.001 + (0.018 * float(iy) / float(ny - 1))
			var hit: Dictionary = Contact.drop_tool_contact(x, y, R, flat, -1.0)
			_check_hit(hit, x, y, R, z_plane + R - 1e-6, "flat")
			if not _near(float(hit["z"]), z_plane + R, 1e-4):
				_fail("flat CL z expected %s got %s at (%s,%s)" % [z_plane + R, hit["z"], x, y])
				return
			n_ok += 1

	# Shallow roof: ridge at (0.01,0.01,0.005). Assert tangent integrity + known ridge height.
	var ridge := Vector3(0.01, 0.01, 0.005)
	var roof: Array = [
		[Vector3(0, 0, 0), Vector3(0.02, 0, 0), ridge],
		[Vector3(0, 0.02, 0), Vector3(0.02, 0.02, 0), ridge],
		[Vector3(0, 0, 0), Vector3(0, 0.02, 0), ridge],
		[Vector3(0.02, 0, 0), Vector3(0.02, 0.02, 0), ridge],
	]
	for ix in nx:
		for iy in ny:
			var x2: float = 0.001 + (0.018 * float(ix) / float(nx - 1))
			var y2: float = 0.001 + (0.018 * float(iy) / float(ny - 1))
			var hit2: Dictionary = Contact.drop_tool_contact(x2, y2, R, roof, -1.0)
			_check_hit(hit2, x2, y2, R, R - 1e-6, "roof")
			n_ok += 1

	var ridge_hit: Dictionary = Contact.drop_tool_contact(0.01, 0.01, R, roof, -1.0)
	_check_hit(ridge_hit, 0.01, 0.01, R, 0.005 + R - 1e-4, "ridge")
	if not _near(float(ridge_hit["z"]), 0.005 + R, 1e-4):
		_fail("ridge CL z expected %s got %s" % [0.005 + R, ridge_hit["z"]])
		return
	n_ok += 1

	print("DROP_QUALITY_OK probes=", n_ok, " R=", R)
	quit(0)
