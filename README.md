# godot-cnc-toolpath

Experimental **Godot 4.7+** sandbox / **EditorPlugin** for 3-axis CNC **raster** toolpaths over a mesh, baked as Godot `Animation` / `Path3D` assets.

Units are **millimetres** (1 Godot unit = 1 mm).

## Quick start (this repo)

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open this folder in **Godot 4.7+**
2. Plugin **CNC Raster Toolpath** is enabled — dock appears on the right
3. Open `scenes/main.tscn` — eartip mesh + Path3D in the 3D viewport
4. Press Play — set **tool radius / stepover / sample (mm)** and **Bake**

## Use as a plugin in your own project

1. Copy `addons/cnc_toolpath/` into your project (or add this repo as a git submodule under `addons/`)
2. Project → Project Settings → Plugins → enable **CNC Raster Toolpath**
3. In the dock: **Ensure CNC nodes in edited scene**, assign your mesh on `Part`, save
4. Press Play and use the on-screen **Bake** panel (raycasts need the running scene)

## Notes

Visual/algorithm sandbox — not production CAM.

## License

MIT — see [LICENSE](LICENSE).
