class_name RasterPassPlanner
extends RefCounted
## Builds 2D raster passes (XZ sample points) from a world AABB-like bounds.
## Each pass is a PackedVector2Array of (x, z) samples in zigzag order.

static func make_passes(
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	stepover: float,
	sample_step: float
) -> Array:
	var passes: Array = []
	var row := 0
	var z := min_z
	while z <= max_z + 1e-9:
		var xs: Array[float] = []
		var x := min_x
		while x <= max_x + 1e-9:
			xs.append(x)
			x += sample_step
		if row % 2 == 1:
			xs.reverse()
		var pass_pts := PackedVector2Array()
		for sx in xs:
			pass_pts.append(Vector2(sx, z))
		if pass_pts.size() > 0:
			passes.append(pass_pts)
		z += stepover
		row += 1
	return passes
