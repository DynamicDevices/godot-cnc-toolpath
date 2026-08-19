# BarMesh (CAD Z-up)

Julian’s 3-axis tool-surface mesh. **All geometry here is Z-up** (CAD).

| File | Role |
|------|------|
| `barmesh.gd` | `Node` / `Bar` / `BuildRectBarMesh` — CL `(x, y, z)`, contact normal + tri/edge/vertex ref |
| `tool_contact.gd` | Ball-nose drop along **tool axis −Z** from a point above |
| `draw.gd` | ImmediateMesh; **only** place that converts CAD Z-up → Godot Y-up `(x, z, y)` |

Split a live `Bar` with `InsertNodeIntoBarF` when **XY > epsilon** (default 0.01 mm, stops infinite refine) **and** (**3D length > stepover** 1 mm **or** contact-normal angle **> a** 15°, via dot product). Those three are external parameters on the draw/UI.

Do not assign `Node.p` to a `Node3D.transform` without `draw.cad_to_godot`.
