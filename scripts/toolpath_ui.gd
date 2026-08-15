extends CanvasLayer
## Simple runtime controls for raster toolpath bake.

signal bake_requested(tool_radius: float, stepover: float, sample_step: float)

@onready var tool_radius: SpinBox = $Panel/VBox/ToolRadius
@onready var stepover: SpinBox = $Panel/VBox/Stepover
@onready var sample_step: SpinBox = $Panel/VBox/SampleStep
@onready var status: Label = $Panel/VBox/Status

func _ready() -> void:
	$Panel/VBox/Bake.pressed.connect(_on_bake)

func _on_bake() -> void:
	status.text = "Baking…"
	bake_requested.emit(tool_radius.value, stepover.value, sample_step.value)

func set_status(text: String) -> void:
	status.text = text
