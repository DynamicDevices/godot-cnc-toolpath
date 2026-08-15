@tool
extends VBoxContainer
## Editor dock chrome for the CNC toolpath addon.

@onready var _tool_radius: SpinBox = $ToolRadius
@onready var _stepover: SpinBox = $Stepover
@onready var _sample_step: SpinBox = $SampleStep
@onready var _status: Label = $Status

func _ready() -> void:
	$EnsureNodes.pressed.connect(_on_ensure_nodes)
	$OpenDemo.pressed.connect(_on_open_demo)

func _plugin() -> EditorPlugin:
	return get_meta("editor_plugin") as EditorPlugin

func _set_status(text: String) -> void:
	_status.text = text

func _on_open_demo() -> void:
	var path := "res://scenes/main.tscn"
	if not ResourceLoader.exists(path):
		_set_status("No scenes/main.tscn in this project — use Ensure Nodes in your scene.")
		return
	_plugin().get_editor_interface().open_scene_from_path(path)
	_set_status("Opened scenes/main.tscn — Press Play, then Bake in the viewport UI.")

func _on_ensure_nodes() -> void:
	var root := _plugin().get_edited_root()
	if root == null:
		_set_status("Open or create a scene first.")
		return

	var part := root.find_child("Part", true, false)
	if part == null:
		var mesh_root := root.get_node_or_null("MeshRoot")
		if mesh_root == null:
			mesh_root = Node3D.new()
			mesh_root.name = "MeshRoot"
			root.add_child(mesh_root)
			mesh_root.owner = root
		part = MeshInstance3D.new()
		part.name = "Part"
		part.set_script(load("res://addons/cnc_toolpath/load_obj_mesh.gd"))
		mesh_root.add_child(part)
		part.owner = root

	if root.get_node_or_null("Toolpath") == null:
		var path3d := Path3D.new()
		path3d.name = "Toolpath"
		root.add_child(path3d)
		path3d.owner = root

	if root.get_node_or_null("Tool") == null:
		var tool := MeshInstance3D.new()
		tool.name = "Tool"
		var sm := SphereMesh.new()
		sm.radius = _tool_radius.value
		sm.height = sm.radius * 2.0
		tool.mesh = sm
		tool.position = Vector3(0, 90, 0)
		root.add_child(tool)
		tool.owner = root

	if root.get_node_or_null("AnimationPlayer") == null:
		var ap := AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		root.add_child(ap)
		ap.owner = root

	if root.get_node_or_null("ToolpathUI") == null:
		var ui := CanvasLayer.new()
		ui.name = "ToolpathUI"
		ui.set_script(load("res://addons/cnc_toolpath/toolpath_ui.gd"))
		root.add_child(ui)
		ui.owner = root
		# Minimal panel matching the demo UI so Bake works at runtime.
		var panel := PanelContainer.new()
		panel.name = "Panel"
		ui.add_child(panel)
		panel.owner = root
		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		panel.add_child(vbox)
		vbox.owner = root
		for pair in [
			["ToolRadius", _tool_radius.value],
			["Stepover", _stepover.value],
			["SampleStep", _sample_step.value],
		]:
			var sb := SpinBox.new()
			sb.name = pair[0]
			sb.min_value = 0.1
			sb.max_value = 50.0
			sb.step = 0.1
			sb.value = pair[1]
			vbox.add_child(sb)
			sb.owner = root
		var bake := Button.new()
		bake.name = "Bake"
		bake.text = "Bake"
		vbox.add_child(bake)
		bake.owner = root
		var status := Label.new()
		status.name = "Status"
		status.text = "Ready"
		vbox.add_child(status)
		status.owner = root

	if root.get_script() == null:
		root.set_script(load("res://addons/cnc_toolpath/raster_baker.gd"))

	_set_status("CNC nodes ready. Assign a mesh on Part, save, Press Play, then Bake. Dock values: r=%.1f step=%.1f sample=%.1f" % [
		_tool_radius.value, _stepover.value, _sample_step.value
	])
