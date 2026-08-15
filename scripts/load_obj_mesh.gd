@tool
extends MeshInstance3D
## Adds collision for raycasts and applies flat (faceted) normals.
## Mesh is assigned in the editor. Units: Godot metres (STL mm × 0.001).

func _ready() -> void:
	if mesh == null:
		push_error("Part mesh missing — assign meshes/eartip.obj in the editor")
		return
	_apply_flat_shading()
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

func _apply_flat_shading() -> void:
	if mesh.get_surface_count() < 1:
		return
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()  # per-corner after deindex → flat faces
	mesh = st.commit()
