extends MeshInstance3D
## Adds collision for raycasts. Mesh itself is assigned in the editor (mm units).

func _ready() -> void:
	if mesh == null:
		push_error("Part mesh missing — assign meshes/eartip.obj in the editor")
		return
	# Avoid duplicating collision on reload.
	for c in get_children():
		if c is StaticBody3D:
			c.queue_free()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	col.shape = shape
	body.add_child(col)
	add_child(body)
