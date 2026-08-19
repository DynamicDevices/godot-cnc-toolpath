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
- `animations/raster_toolpath_curve.tres` — editor `Path3D` preview
- `animations/raster_toolpath.tres` — Animation
- `animations/waterline_contours.tres` — compensated constant-height contours
- `animations/waterline_toolpath_lines.tres` — contours with safe retracts
- `animations/waterline_toolpath_curve.tres` — editor `Path3D` preview
- `animations/waterline_toolpath.tres` — Animation

All generated resources use stable `res://animations/...` paths and are
overwritten on each bake. In the editor, `ToolpathCurve` is the placeholder
`Path3D`, and `AnimationPlayer` is the animation placeholder. Select
`EditorAssetReload` and set **Preview Strategy** to `raster` or `waterline`;
its `@tool` script detects rewritten Curve3D/Animation files and reloads those
two placeholders automatically. Select `ToolpathCurve` to see the Path3D
editor gizmo. No game rerun or scene reopen is required.

**BarMesh** (`barmesh/`): CAD **Z-up** `Node`/`Bar`/`BuildRectBarMesh`, ball-nose drop along −Z (`tool_contact.gd`). ImmediateMesh in `draw.gd` is the only Y-up conversion. Strategy **BarMesh viz**.

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

The smoke bake also asserts the stable Curve3D/Animation paths and placeholder
wiring, and prints an `ASSET_PROOF` line.

## License

MIT — see [LICENSE](LICENSE).
