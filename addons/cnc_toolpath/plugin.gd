@tool
extends EditorPlugin
## Editor dock for Julian: drop addons/cnc_toolpath into any Godot 4.7+ project,
## enable this plugin, then Bake against the edited scene.

const DOCK_SCENE := preload("res://addons/cnc_toolpath/dock.tscn")

var _dock: Control

func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	_dock.set_meta("editor_plugin", self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

func get_edited_root() -> Node:
	return get_editor_interface().get_edited_scene_root()
