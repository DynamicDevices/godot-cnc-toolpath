extends SceneTree
## Poka-yoke: ball is tangent to a face, edge, or vertex (CAD Z-up).
## Headless: godot --headless --path . -s res://tools/test_contact.gd

const Contact := preload("res://barmesh/tool_contact.gd")
const KIND_VERTEX := 1
const KIND_EDGE := 2
const KIND_FACE := 3


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("CONTACT_FAIL " + msg)
	quit(1)


func _near(a: float, b: float, eps: float = 1e-5) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(0.02, 0, 0)
	var c := Vector3(0, 0.02, 0)
	var tris: Array = [[a, b, c]]
	var R := 0.0015

	var face: Dictionary = Contact.drop_tool_contact(0.005, 0.005, R, tris, -1.0)
	if int(face["kind"]) != KIND_FACE:
		_fail("face kind " + str(face))
		return
	if not _near(float(face["z"]), R):
		_fail("face CL z " + str(face["z"]))
		return
	if absf(face["point"].z) > 1e-5:
		_fail("face point not on plane")
		return
	var cl_f := Vector3(0.005, 0.005, float(face["z"]))
	if absf(cl_f.distance_to(face["point"]) - R) > 1e-4:
		_fail("face |CL-pt| != R")
		return

	var vert: Dictionary = Contact.drop_tool_contact(0.0, 0.0, R, tris, -1.0)
	if int(vert["kind"]) != KIND_VERTEX:
		_fail("vertex kind " + str(vert))
		return
	if vert["point"].distance_to(a) > 1e-6:
		_fail("vertex point")
		return
	if absf(Vector3(0, 0, float(vert["z"])).distance_to(vert["point"]) - R) > 1e-4:
		_fail("vertex |CL-pt| != R")
		return

	var edge: Dictionary = Contact.drop_tool_contact(0.01, 0.0, R, tris, -1.0)
	if int(edge["kind"]) != KIND_EDGE:
		_fail("edge kind " + str(edge))
		return
	if absf(edge["point"].y) > 1e-6 or absf(edge["point"].z) > 1e-5:
		_fail("edge point not on ab")
		return
	if absf(Vector3(0.01, 0.0, float(edge["z"])).distance_to(edge["point"]) - R) > 1e-4:
		_fail("edge |CL-pt| != R")
		return

	print("CONTACT_OK face,vertex,edge R=", R)
	quit(0)
