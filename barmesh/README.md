# BarMesh (CAD Z-up)

Julian’s 3-axis tool-surface mesh. **All geometry here is Z-up** (CAD).

| File | Role |
|------|------|
| `barmesh.gd` | `Node` / `Bar` / `BuildRectBarMesh` — CL `(x, y, z)`, contact normal + tri/edge/vertex ref |
| `subdiv.gd` | Bar vs cell split **conditions** + insertion XY placement (params; not topology) |
| `tool_contact.gd` | Ball-nose drop along **tool axis −Z** from a point above |
| `draw.gd` | ImmediateMesh; **only** place that converts CAD Z-up → Godot Y-up `(x, z, y)` |

**Conditions** live in `subdiv.gd` (shared ε / stepover / a). Split a live `Bar` with `InsertNodeIntoBarF` when **XY > epsilon** (default 0.01 mm) **and** (**3D length > stepover** 1 mm **or** contact-normal angle **> a** 15°). Cell splits (`MakeBarBetweenNodesF`): walk right-hand rings via `GetBarBackRight`; rank cells by continuous **planar tolerance** (⊥ residual to avg-normal/avg-point plane — Julian 155); split the worst, then **subdivide the new bar to tolerance** (Julian 156). Stop when all cells are in tolerance or XY extent is too small. Tol: **coplanar_tol** (⊥) + max pairwise normal angle **a**. Interactive builds leave cell splits to **Subdivide next N cells** (default N=10); headless/CI still auto-runs up to `max_refine_passes`. Insertion XY defaults to midpoint bisection; optional plane-intersect guess brackets z/normal discontinuities along the bar.

Do not assign `Node.p` to a `Node3D.transform` without `draw.cad_to_godot`.
