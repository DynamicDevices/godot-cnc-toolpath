extends Node3D
## Mouse orbit around a target while the scene is running.
## LMB drag = orbit, wheel = zoom. Does not move the part mesh.

@export var target_path: NodePath = NodePath("../MeshRoot")
@export var sensitivity: float = 0.005
@export var zoom_sensitivity: float = 0.02
@export var min_distance: float = 0.05
@export var max_distance: float = 1.5

var _yaw: float = 0.6
var _pitch: float = 0.45
var _distance: float = 0.22
var _dragging: bool = false

func _ready() -> void:
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance * (1.0 - zoom_sensitivity), min_distance, max_distance)
			_apply()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * (1.0 + zoom_sensitivity), min_distance, max_distance)
			_apply()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * sensitivity
		_pitch = clampf(_pitch - mm.relative.y * sensitivity, 0.05, 1.4)
		_apply()
		get_viewport().set_input_as_handled()

func _apply() -> void:
	var target := get_node_or_null(target_path) as Node3D
	var focus := Vector3.ZERO
	if target:
		# Aim near the part centroid (AABB centre in world).
		if target is MeshInstance3D and (target as MeshInstance3D).mesh:
			var mi := target as MeshInstance3D
			focus = mi.global_transform * mi.get_aabb().get_center()
		else:
			var part := target.find_child("Part", true, false)
			if part is MeshInstance3D and (part as MeshInstance3D).mesh:
				var mi2 := part as MeshInstance3D
				focus = mi2.global_transform * mi2.get_aabb().get_center()
			else:
				focus = target.global_position
	var offset := Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)
	global_position = focus + offset
	look_at(focus, Vector3.UP)
