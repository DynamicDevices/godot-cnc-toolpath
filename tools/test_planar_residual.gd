extends SceneTree
## Julian 162: planar residual must use CL (node.p), not contact_point.
## Headless: godot --headless --path . -s res://tools/test_planar_residual.gd

const BarMeshGD = preload("res://barmesh/barmesh.gd")
const Subdiv = preload("res://barmesh/subdiv.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("PLANAR_FAIL " + msg)
	quit(1)


func _run() -> void:
	# Four CLs over a valley: contact points nearly coplanar on z=0, CLs bowed.
	var nodes: Array = []
	var pts := [
		Vector3(0.0, 0.0, 0.005),
		Vector3(0.02, 0.0, 0.005),
		Vector3(0.02, 0.02, 0.001),
		Vector3(0.0, 0.02, 0.005),
	]
	var contacts := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.02, 0.0, 0.0),
		Vector3(0.02, 0.02, 0.0),
		Vector3(0.0, 0.02, 0.0),
	]
	for i in 4:
		var n := BarMeshGD.BMNode.new(pts[i], i)
		n.contact_point = contacts[i]
		n.contact_normal = Vector3(0, 0, 1)
		n.contact_kind = BarMeshGD.BMNode.ContactFeature.FACE
		nodes.append(n)

	var r: float = Subdiv.cell_planar_residual(nodes)
	# Avg CL z=0.004; valley node at 0.001 → residual 0.003 (contact plane stays 0).
	if r < 0.0025:
		_fail("valley CL residual too small: %s (expected ~0.003)" % r)
		return
	# Sanity: if we only looked at contact_point, residual would be ~0.
	var csum := Vector3.ZERO
	for n2 in nodes:
		csum += (n2 as BarMeshGD.BMNode).contact_point
	csum /= 4.0
	var c_worst := 0.0
	for n3 in nodes:
		c_worst = maxf(c_worst, absf(Vector3(0, 0, 1).dot((n3 as BarMeshGD.BMNode).contact_point - csum)))
	if c_worst > 1e-6:
		_fail("test setup: contact points not coplanar")
		return
	if r <= c_worst + 1e-6:
		_fail("residual collapsed to contact_point measure")
		return
	print("PLANAR_OK residual=", r)
	quit(0)
