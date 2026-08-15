# godot-cnc-toolpath

Experimental **Godot 4.7+** sandbox for 3-axis CNC **raster** toolpaths over a mesh, recorded as Godot `Animation` / `Path3D` assets.

Built with Julian Todd (mesh + CAM direction) and Alex Lennon / Briar (implementation).

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
```

1. Open this folder in **Godot 4.7+**
2. Open `scenes/main.tscn`
3. Press Play — use the panel to set **tool radius**, **stepover**, **sample step**, then **Bake toolpath**

Bake updates the live tool motion and writes:

- `animations/raster_toolpath.tres`
- `animations/raster_toolpath_curve.tres`

so the path is visible in the editor after reload.

## Layout

| Path | Purpose |
|---|---|
| `meshes/eartip.obj` | Example part (from Julian’s STL) |
| `scripts/raster_baker.gd` | Scan-line baker + asset save |
| `scripts/toolpath_ui.gd` | Runtime controls |
| `scripts/load_obj_mesh.gd` | Runtime OBJ + collision |

## Notes

Visual/algorithm sandbox — not production CAM. No stock simulation, machine kinematics, or G-code export yet.

## License

MIT — see [LICENSE](LICENSE).
