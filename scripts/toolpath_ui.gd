extends CanvasLayer
## Tool-surface controls. Raster/waterline UI is on archive/raster-waterline-toolpaths.

signal bake_requested(
	strategy: String,
	tool_radius: float,
	stepover: float,
	sample_step: float,
	z_stepdown: float
)

@onready var strategy: OptionButton = $Panel/VBox/Strategy
@onready var tool_radius: SpinBox = $Panel/VBox/ToolRadius
@onready var stepover_label: Label = $Panel/VBox/StepoverLabel
@onready var stepover: SpinBox = $Panel/VBox/Stepover
@onready var sample_step: SpinBox = $Panel/VBox/SampleStep
@onready var z_stepdown_label: Label = $Panel/VBox/ZStepdownLabel
@onready var z_stepdown: SpinBox = $Panel/VBox/ZStepdown
@onready var status: Label = $Panel/VBox/Status

func _ready() -> void:
	strategy.clear()
	strategy.add_item("BarMesh (tool surface)")
	strategy.set_item_metadata(0, "barmesh")
	strategy.disabled = true
	$Panel/VBox/StrategyLabel.visible = false
	strategy.visible = false
	stepover_label.visible = false
	stepover.visible = false
	z_stepdown_label.visible = false
	z_stepdown.visible = false
	$Panel/VBox/SampleLabel.visible = false
	sample_step.visible = false
	$Panel/VBox/Title.text = "Tool surface (CAD Z-up)"
	$Panel/VBox/Bake.text = "Build tool surface"
	status.text = "BarMesh only — raster/waterline archived."
	$Panel/VBox/Bake.pressed.connect(_on_bake)

func _on_bake() -> void:
	status.text = "Building…"
	bake_requested.emit("barmesh", tool_radius.value, 0.0, 0.0, 0.0)

func set_status(text: String) -> void:
	status.text = text
