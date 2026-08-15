# godot-cnc-toolpath

Simple **Godot 4.7+** project for 3-axis CNC **raster** toolpaths over a mesh.

Bake writes editor-loadable assets:
- `animations/raster_toolpath.tres` — `Animation`
- `animations/raster_toolpath_curve.tres` — `Curve3D` on Path3D

**Units:** Godot scene = **metres**. STL source is mm; mesh is imported ×0.001 (~72 mm wide). Bake UI spinboxes are in **mm**.

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open this folder in **Godot 4.7+**
2. Open `scenes/main.tscn` — flat-shaded eartip on a base plane
3. Press Play → set tool radius / stepover / sample (mm) → **Bake**
4. Stop Play — Path3D curve + AnimationPlayer library should remain as saved `.tres` assets

## Notes

Visual/algorithm sandbox — not production CAM. Not an EditorPlugin.

## License

MIT — see [LICENSE](LICENSE).
