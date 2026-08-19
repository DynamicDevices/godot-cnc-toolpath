#!/usr/bin/env bash
# Fetch Preloop (preloop[bot]) summary + inline review comments for a PR.
set -euo pipefail

PR="${1:-}"
if [[ -z "$PR" || "$PR" == "-h" || "$PR" == "--help" ]]; then
  echo "usage: $0 <pr-number>" >&2
  exit 2
fi

REPO="${REPO:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
REPO="${REPO:-DynamicDevices/godot-cnc-toolpath}"

echo "=== Preloop on ${REPO}#${PR} ==="
echo
echo "--- summary / issue comments ---"
gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
  --jq '.[] | select(.user.login=="preloop[bot]") | "\(.created_at)\n\(.html_url)\n\(.body)\n---"'
echo
echo "--- inline review comments ---"
gh api "repos/${REPO}/pulls/${PR}/comments" --paginate \
  --jq '.[] | select(.user.login=="preloop[bot]") | "\(.path):\(.line // .original_line)\n\(.html_url)\n\(.body)\n---"'
echo
echo "--- reviews ---"
gh api "repos/${REPO}/pulls/${PR}/reviews" --paginate \
  --jq '.[] | select(.user.login=="preloop[bot]") | "\(.submitted_at) state=\(.state)\n\(.html_url)\n\(.body)\n---"'
echo
echo "Tip: gh pr list --label preloop-triage"
