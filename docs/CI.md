# CI

**Godot:** workflow [`.github/workflows/godot-headless.yml`](../.github/workflows/godot-headless.yml) — self-hosted headless bake. Not a required merge check.

**Preloop:** Cloud flow **DD - Pull Request Reviewer** now includes this repo. It comments on PRs asynchronously. It does **not** block Godot CI.

| Piece | Detail |
|-------|--------|
| Findings | `preloop[bot]` summary + inline comments |
| Surface | [`.github/workflows/preloop-triage.yml`](../.github/workflows/preloop-triage.yml) labels `preloop-triage` |
| Fetch | [`scripts/fetch-preloop-pr.sh`](../scripts/fetch-preloop-pr.sh) |

```bash
./scripts/fetch-preloop-pr.sh 7
gh pr list --label preloop-triage
```
