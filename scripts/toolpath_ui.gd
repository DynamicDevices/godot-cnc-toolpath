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
	stepover_label.visible = true
	stepover.visible = true
	stepover_label.text = "Stepover (mm)"
	stepover.min_value = 0.1
	stepover.value = 6.0
	tool_radius.value = 5.0
	z_stepdown_label.visible = true
	z_stepdown.visible = true
	z_stepdown_label.text = "Normal angle (deg)"
	z_stepdown.min_value = 1.0
	z_stepdown.max_value = 90.0
	z_stepdown.value = 15.0
	$Panel/VBox/SampleLabel.visible = true
	sample_step.visible = true
	$Panel/VBox/SampleLabel.text = "XY epsilon (mm)"
	sample_step.min_value = 0.001
	sample_step.step = 0.001
	sample_step.value = 0.01
	$Panel/VBox/Title.text = "Tool surface (CAD Z-up)"
	$Panel/VBox/Bake.text = "Build tool surface"
	status.text = "BarMesh refine: epsilon / stepover / angle."
	$Panel/VBox/Bake.pressed.connect(_on_bake)
	var bars := $Panel/VBox/ShowBars as CheckBox
	var norms := $Panel/VBox/ShowNormals as CheckBox
	var ortho := $Panel/VBox/Ortho as CheckBox
	if bars:
		bars.button_pressed = true
		bars.toggled.connect(func(v: bool) -> void:
			var viz := _preview()
			if viz and viz.has_method("set_show_bars"):
				viz.set_show_bars(v)
		)
	if norms:
		norms.button_pressed = true
		norms.toggled.connect(func(v: bool) -> void:
			var viz := _preview()
			if viz and viz.has_method("set_show_normals"):
				viz.set_show_normals(v)
		)
	if ortho:
		ortho.button_pressed = true
		ortho.toggled.connect(func(v: bool) -> void:
			var cam := get_parent().get_node_or_null("Camera3D")
			if cam and cam.has_method("apply_orthogonal"):
				cam.apply_orthogonal(v)
		)
	var flat := $Panel/VBox/DebugFlatMesh as CheckBox
	if flat:
		flat.button_pressed = false
		flat.toggled.connect(func(v: bool) -> void:
			var part := get_parent().get_node_or_null("MeshRoot/Part")
			if part and part.has_method("set_debug_flat_mesh"):
				part.set_debug_flat_mesh(v)
			# Rebuild lattice on the substituted mesh.
			_on_bake()
		)


func _preview() -> Node:
	return get_parent().get_node_or_null("BarMeshPreview")

func _on_bake() -> void:
	status.text = "Building…"
	bake_requested.emit("barmesh", tool_radius.value, stepover.value, sample_step.value, z_stepdown.value)

func set_status(text: String) -> void:
	status.text = text
