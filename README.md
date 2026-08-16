# godot-cnc-toolpath

Simple **Godot 4.7+** project for 3-axis CNC **raster** and **waterline**
(constant-Z) toolpaths over a mesh.

## Pipeline

1. **`raster_pass_planner.gd`** — 2D raster as a line mesh (**one LINE_STRIP surface per pass**)
2. **`raster_project_to_mesh.gd`** — `compute_line_mesh(passes, mesh, tool)` projects by **tool-shape vs mesh collision** (ball-nose drop-cutter on triangles — not Physics raycasts) → 3D line mesh
3. **`toolpath_animation.gd`** — projected points → `Animation`
4. **`raster_baker.gd`** — UI glue + save assets

Waterline uses `waterline_toolpath.gd` to intersect the mesh with horizontal
planes, join the segments into closed contours, apply planar tool-radius
compensation, and sample each loop. Passes are ordered top-down and retract to
safe height between contours. Godot's vertical axis is Y; the UI uses the
conventional CNC name **Z stepdown**.

Assets:
- `animations/raster_passes_2d.tres` — yellow 2D passes (`Raster2DPreview`)
- `animations/raster_toolpath_lines.tres` — cyan projected 3D path (`ToolpathPreview`)
- `animations/raster_toolpath.tres` — Animation
- `animations/waterline_contours.tres` — compensated constant-height contours
- `animations/waterline_toolpath_lines.tres` — contours with safe retracts
- `animations/waterline_toolpath.tres` — Animation

**Units:** metres in-scene; Bake UI in mm. **Play:** MMB orbit, Shift+MMB pan, wheel zoom.

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open in **Godot 4.7+** → `scenes/main.tscn`
2. Press Play → choose Raster or Waterline → Bake

Headless smoke proof for either strategy:

```bash
godot --headless --path . -s res://tools/bake_once.gd -- --strategy=waterline
```

## License

MIT — see [LICENSE](LICENSE).
