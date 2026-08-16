extends CanvasLayer
## Runtime controls shared by raster and waterline toolpath bakes.

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
	strategy.add_item("Raster")
	strategy.set_item_metadata(0, "raster")
	strategy.add_item("Waterline (constant Z)")
	strategy.set_item_metadata(1, "waterline")
	strategy.item_selected.connect(_on_strategy_selected)
	$Panel/VBox/Bake.pressed.connect(_on_bake)
	_on_strategy_selected(strategy.selected)

func _on_bake() -> void:
	status.text = "Baking…"
	var strategy_id: String = strategy.get_item_metadata(strategy.selected)
	bake_requested.emit(
		strategy_id,
		tool_radius.value,
		stepover.value,
		sample_step.value,
		z_stepdown.value
	)

func _on_strategy_selected(index: int) -> void:
	var is_waterline: bool = str(strategy.get_item_metadata(index)) == "waterline"
	stepover_label.visible = not is_waterline
	stepover.visible = not is_waterline
	z_stepdown_label.visible = is_waterline
	z_stepdown.visible = is_waterline

func set_status(text: String) -> void:
	status.text = text
