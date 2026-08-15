# godot-cnc-toolpath

Experimental **Godot 4.7+** sandbox / **EditorPlugin** for 3-axis CNC **raster** toolpaths over a mesh, baked as Godot `Animation` / `Path3D` assets.

**Units:** Godot scene units are **metres** (engine default). The eartip STL is millimetres on disk and imported ×0.001 (~72 mm wide, not ~72 m). Bake UI spinboxes stay in **mm** and convert internally.

## Quick start (this repo)

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open this folder in **Godot 4.7+**
2. Plugin **CNC Raster Toolpath** is enabled — dock on the right
3. Open `scenes/main.tscn` — flat-shaded eartip on a base plane, Path3D aligned
4. Press Play — set **tool radius / stepover / sample (mm)** and **Bake**

## Use as a plugin in your own project

1. Copy `addons/cnc_toolpath/` into your project (or git submodule under `addons/`)
2. Project → Project Settings → Plugins → enable **CNC Raster Toolpath**
3. Dock: **Ensure CNC nodes in edited scene**, assign your mesh on `Part`, save
4. Press Play and use the on-screen **Bake** panel (raycasts need the running scene)

## Notes

Visual/algorithm sandbox — not production CAM.

## License

MIT — see [LICENSE](LICENSE).
