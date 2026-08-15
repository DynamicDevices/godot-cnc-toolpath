extends MeshInstance3D
## Runtime OBJ loader + collision so raster rays can hit without editor import.

@export_file("*.obj") var obj_path: String = "res://meshes/eartip.obj"
@export var target_size: float = 2.0

func _ready() -> void:
	var mesh_data := _load_obj(obj_path)
	if mesh_data.is_empty():
		push_error("Failed to load OBJ: %s" % obj_path)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in mesh_data:
		st.add_vertex(v)
	st.generate_normals()
	mesh = st.commit()

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _load_obj(path: String) -> PackedVector3Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedVector3Array()
	var verts: Array[Vector3] = []
	var faces: PackedVector3Array = PackedVector3Array()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			if p.size() >= 4:
				verts.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var idx: Array[int] = []
			for i in range(1, p.size()):
				var token := String(p[i]).split("/")[0]
				idx.append(int(token) - 1)
			if idx.size() >= 3:
				for t in range(1, idx.size() - 1):
					faces.append(verts[idx[0]])
					faces.append(verts[idx[t]])
					faces.append(verts[idx[t + 1]])
	if faces.is_empty():
		return faces
	# Fit to target_size on longest axis.
	var mn := faces[0]
	var mx := faces[0]
	for v in faces:
		mn = mn.min(v)
		mx = mx.max(v)
	var size := mx - mn
	var longest := maxf(size.x, maxf(size.y, size.z))
	var scale := target_size / maxf(longest, 1e-6)
	var center := (mn + mx) * 0.5
	var out := PackedVector3Array()
	out.resize(faces.size())
	for i in faces.size():
		var v: Vector3 = faces[i]
		v = (v - center) * scale
		v.y += (mx.y - mn.y) * 0.5 * scale  # sit on y≈0
		out[i] = v
	return out
