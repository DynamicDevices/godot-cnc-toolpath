@tool
extends MeshInstance3D
## Adds collision for raycasts and applies flat (faceted) normals.
## Mesh is assigned in the editor. Units: Godot metres (STL mm × 0.001).

var _original_mesh: Mesh
var _debug_flat: bool = false


func _ready() -> void:
	if mesh == null:
		push_error("Part mesh missing — assign meshes/eartip.obj in the editor")
		return
	_original_mesh = mesh
	_apply_flat_shading()
	_rebuild_collision()


func set_debug_flat_mesh(enabled: bool) -> void:
	## Same XY/Z AABB as the part, but only two triangles (flat top of the bbox).
	if mesh == null and _original_mesh == null:
		return
	if _original_mesh == null:
		_original_mesh = mesh
	_debug_flat = enabled
	if enabled:
		mesh = _make_two_triangle_bbox(_original_mesh)
	else:
		mesh = _original_mesh.duplicate() if _original_mesh else null
	_apply_flat_shading()
	_rebuild_collision()


func is_debug_flat_mesh() -> bool:
	return _debug_flat


func _rebuild_collision() -> void:
	for c in get_children():
		if c is StaticBody3D:
			c.queue_free()
	if mesh == null:
		return
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _make_two_triangle_bbox(src: Mesh) -> ArrayMesh:
	var aabb: AABB = src.get_aabb()
	# Godot Y-up mesh space: flat plate at max Y (CAD Z-up max), covering XY footprint.
	var x0 := aabb.position.x
	var x1 := aabb.position.x + aabb.size.x
	var z0 := aabb.position.z
	var z1 := aabb.position.z + aabb.size.z
	var y := aabb.position.y + aabb.size.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two tris, CCW when viewed from above (+Y).
	st.add_vertex(Vector3(x0, y, z0))
	st.add_vertex(Vector3(x1, y, z0))
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x0, y, z0))
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x0, y, z1))
	st.generate_normals()
	return st.commit()


func _apply_flat_shading() -> void:
	if mesh == null or mesh.get_surface_count() < 1:
		return
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()  # per-corner after deindex → flat faces
	mesh = st.commit()
