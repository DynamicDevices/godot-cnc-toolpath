extends Node3D
## Editor-like viewport controls while running:
## Middle-mouse drag = orbit, Shift+middle-mouse drag = pan, wheel = zoom.

@export var target_path: NodePath = NodePath("../MeshRoot")
@export var sensitivity: float = 0.005
@export var pan_sensitivity: float = 0.001
@export var zoom_sensitivity: float = 0.02
@export var min_distance: float = 0.05
@export var max_distance: float = 1.5

var _yaw: float = 0.6
var _pitch: float = 0.45
var _distance: float = 0.22
var _focus: Vector3 = Vector3.ZERO
var _orbiting: bool = false
var _panning: bool = false
var _focus_inited: bool = false

func _ready() -> void:
	_init_focus()
	_apply()

func _init_focus() -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		_focus = Vector3.ZERO
		_focus_inited = true
		return
	if target is MeshInstance3D and (target as MeshInstance3D).mesh:
		var mi := target as MeshInstance3D
		_focus = mi.global_transform * mi.get_aabb().get_center()
	else:
		var part := target.find_child("Part", true, false)
		if part is MeshInstance3D and (part as MeshInstance3D).mesh:
			var mi2 := part as MeshInstance3D
			_focus = mi2.global_transform * mi2.get_aabb().get_center()
		else:
			_focus = target.global_position
	_focus_inited = true

func _unhandled_input(event: InputEvent) -> void:
	if not _focus_inited:
		_init_focus()

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = mb.shift_pressed
				_orbiting = not _panning
			else:
				_orbiting = false
				_panning = false
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance * (1.0 - zoom_sensitivity), min_distance, max_distance)
			_apply()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * (1.0 + zoom_sensitivity), min_distance, max_distance)
			_apply()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_yaw -= mm.relative.x * sensitivity
			_pitch = clampf(_pitch - mm.relative.y * sensitivity, 0.05, 1.4)
			_apply()
			get_viewport().set_input_as_handled()
		elif _panning:
			# Pan in camera local right/up, scaled by distance (editor-like).
			var right := global_transform.basis.x
			var up := global_transform.basis.y
			var scale := _distance * pan_sensitivity
			_focus -= right * mm.relative.x * scale
			_focus += up * mm.relative.y * scale
			_apply()
			get_viewport().set_input_as_handled()

func _apply() -> void:
	var offset := Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)
	global_position = _focus + offset
	look_at(_focus, Vector3.UP)
