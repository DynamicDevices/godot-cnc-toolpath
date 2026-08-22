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
	## Same XY footprint as the part AABB, but only two triangles folded along the
	## diagonal (not coplanar) so dropcutter sees a dihedral, not a flat plate.
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
	# Godot Y-up: cover the XY footprint near the top of the AABB, folded so the
	# two faces meet along the (x0,z0)-(x1,z1) diagonal ridge (not coplanar).
	var x0 := aabb.position.x
	var x1 := aabb.position.x + aabb.size.x
	var z0 := aabb.position.z
	var z1 := aabb.position.z + aabb.size.z
	var y_hi := aabb.position.y + aabb.size.y
	var fold := maxf(aabb.size.y * 0.15, 0.001)
	var y_lo := y_hi - fold
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Ridge high: (x0,z0) and (x1,z1). Free corners low → dihedral.
	var p00 := Vector3(x0, y_hi, z0)
	var p10 := Vector3(x1, y_lo, z0)
	var p11 := Vector3(x1, y_hi, z1)
	var p01 := Vector3(x0, y_lo, z1)
	# Two tris, CCW when viewed from above (+Y).
	st.add_vertex(p00)
	st.add_vertex(p10)
	st.add_vertex(p11)
	st.add_vertex(p00)
	st.add_vertex(p11)
	st.add_vertex(p01)
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
