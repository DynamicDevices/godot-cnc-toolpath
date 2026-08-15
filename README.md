# godot-cnc-toolpath

Simple **Godot 4.7+** project for 3-axis CNC **raster** toolpaths over a mesh.

Bake writes editor-loadable assets:
- `animations/raster_toolpath_lines.tres` — line-strip `ArrayMesh` assigned to `ToolpathPreview` (editor-visible)
- `animations/raster_toolpath.tres` — `Animation` for the Tool node

No Path3D — preview is the line mesh.

**Units:** Godot scene = **metres**. STL source is mm; mesh is imported ×0.001 (~72 mm wide). Bake UI spinboxes are in **mm**.

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open this folder in **Godot 4.7+**
2. Open `scenes/main.tscn` — flat-shaded eartip, base plane, **cyan line-mesh toolpath** already on ToolpathPreview
3. Press Play — **MMB drag** orbits, **Shift+MMB** pans, **wheel** zooms (same idea as the Godot editor); tweak params → **Bake**

Bake pipeline: `RasterToolpathCalc` (mesh + tool → points/line mesh) then unpack into Animation + save under `animations/`.

## Notes

Visual/algorithm sandbox — not production CAM.

## License

MIT — see [LICENSE](LICENSE).
