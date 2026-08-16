@tool
extends Node
## Keeps the editor preview bound to the stable assets written by a bake.

@export_enum("raster", "waterline") var preview_strategy := "raster"
@export var curve_node_path := NodePath("../ToolpathCurve")
@export var animation_player_path := NodePath("../AnimationPlayer")
@export_range(0.1, 5.0, 0.1) var poll_seconds := 0.5

var _elapsed := 0.0
var _fingerprint := ""

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	call_deferred("_reload_if_changed")

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_elapsed += delta
	if _elapsed < poll_seconds:
		return
	_elapsed = 0.0
	_reload_if_changed()

func _reload_if_changed() -> void:
	var curve_path := "res://animations/%s_toolpath_curve.tres" % preview_strategy
	var animation_path := "res://animations/%s_toolpath.tres" % preview_strategy
	var fingerprint := "%s:%s:%s" % [
		preview_strategy,
		FileAccess.get_sha256(curve_path),
		FileAccess.get_sha256(animation_path),
	]
	if fingerprint == _fingerprint:
		return
	_fingerprint = fingerprint

	var curve := ResourceLoader.load(
		curve_path, "Curve3D", ResourceLoader.CACHE_MODE_REPLACE
	) as Curve3D
	var animation := ResourceLoader.load(
		animation_path, "Animation", ResourceLoader.CACHE_MODE_REPLACE
	) as Animation
	var path_node := get_node_or_null(curve_node_path) as Path3D
	var player := get_node_or_null(animation_player_path) as AnimationPlayer
	if curve == null or animation == null or path_node == null or player == null:
		push_warning("Editor toolpath preview could not reload %s assets" % preview_strategy)
		return

	path_node.curve = curve
	var library := AnimationLibrary.new()
	library.add_animation(preview_strategy + "_toolpath", animation)
	if player.has_animation_library("cnc"):
		player.remove_animation_library("cnc")
	player.add_animation_library("cnc", library)
