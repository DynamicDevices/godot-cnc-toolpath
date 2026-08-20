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


func _assert_cl_xy(hit: Dictionary, x: float, y: float) -> void:
	## Drop along +Z tool axis: returned (x,y) must equal the probe.
	if not _near(float(hit["x"]), x) or not _near(float(hit["y"]), y):
		_fail("CL xy drifted probe=(%s,%s) hit=(%s,%s)" % [x, y, hit["x"], hit["y"]])


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
	_assert_cl_xy(face, 0.005, 0.005)
	if not _near(float(face["z"]), R):
		_fail("face CL z " + str(face["z"]))
		return
	if absf(face["point"].z) > 1e-5:
		_fail("face point not on plane")
		return
	var cl_f := Vector3(float(face["x"]), float(face["y"]), float(face["z"]))
	if absf(cl_f.distance_to(face["point"]) - R) > 1e-4:
		_fail("face |CL-pt| != R")
		return

	var vert: Dictionary = Contact.drop_tool_contact(0.0, 0.0, R, tris, -1.0)
	if int(vert["kind"]) != KIND_VERTEX:
		_fail("vertex kind " + str(vert))
		return
	_assert_cl_xy(vert, 0.0, 0.0)
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
	_assert_cl_xy(edge, 0.01, 0.0)
	if absf(edge["point"].y) > 1e-6 or absf(edge["point"].z) > 1e-5:
		_fail("edge point not on ab")
		return
	if absf(Vector3(0.01, 0.0, float(edge["z"])).distance_to(edge["point"]) - R) > 1e-4:
		_fail("edge |CL-pt| != R")
		return

	# Tilted face: contact XY can move; cutter CL must still keep probe (x,y).
	var tilt: Array = [
		[Vector3(0, 0, 0), Vector3(0.02, 0, 0), Vector3(0, 0.02, 0.01)],
	]
	var tilt_hit: Dictionary = Contact.drop_tool_contact(0.006, 0.006, R, tilt, -1.0)
	_assert_cl_xy(tilt_hit, 0.006, 0.006)
	if int(tilt_hit["kind"]) == 0:
		_fail("tilt no contact")
		return
	var cl_t := Vector3(float(tilt_hit["x"]), float(tilt_hit["y"]), float(tilt_hit["z"]))
	if absf(cl_t.distance_to(tilt_hit["point"]) - R) > 1e-4:
		_fail("tilt |CL-pt| != R")
		return
	# On a tilt, contact point should generally differ from CL in XY (else face was flat).
	var dxy: float = Vector2(cl_t.x - tilt_hit["point"].x, cl_t.y - tilt_hit["point"].y).length()
	if dxy < 1e-6 and int(tilt_hit["kind"]) == KIND_FACE:
		_fail("tilt face contact XY unexpected equal to CL")
		return

	print("CONTACT_OK face,vertex,edge,tilt_xy R=", R)
	quit(0)
