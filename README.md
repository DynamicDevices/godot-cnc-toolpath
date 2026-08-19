# godot-cnc-toolpath

Godot 4.7+ **3-axis tool surface** (BarMesh). Raster/waterline **toolpaths** are
archived on `archive/raster-waterline-toolpaths` — see [ARCHIVE.md](ARCHIVE.md).
We get the tool surface right before generating paths from it.

## BarMesh (`barmesh/`)

CAD **Z-up** throughout:

| File | Role |
|------|------|
| `barmesh.gd` | `Node` / `Bar` / `BuildRectBarMesh` — cutter locations `(x, y, z)` |
| `tool_contact.gd` | Ball-nose drop along tool axis **−Z** from a point above |
| `draw.gd` | ImmediateMesh; **only** Y-up conversion for Godot `(x, z, y)` |

Play `scenes/main.tscn` (or **Build tool surface**) to watch the contact lattice
drape over the part.

**Units:** metres in-scene; UI in mm. **Play:** MMB orbit, Shift+MMB pan, wheel zoom.

## Quick start

```bash
git clone https://github.com/DynamicDevices/godot-cnc-toolpath.git
cd godot-cnc-toolpath
git pull
```

1. Open in **Godot 4.7+** → `scenes/main.tscn`
2. Press Play

Headless smoke:

```bash
godot --headless --path . -s res://tools/bake_once.gd
```

## License

MIT — see [LICENSE](LICENSE).
