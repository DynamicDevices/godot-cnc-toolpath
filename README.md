# godot-cnc-toolpath

Experimental **Godot 4.7+** sandbox for 3-axis CNC **raster** toolpaths over a mesh, as Godot `Animation` / `Path3D` assets.

Units are **millimetres** (1 Godot unit = 1 mm). Julian’s eartip STL is included and assigned on the Part node so it shows in the editor, aligned with the baked toolpath.

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open this folder in **Godot 4.7+**
2. Open `scenes/main.tscn` — you should see the eartip mesh and Path3D in the 3D viewport
3. Press Play — set **tool radius / stepover / sample (mm)** and **Bake**

## Notes

Visual/algorithm sandbox — not production CAM.

## License

MIT — see [LICENSE](LICENSE).
