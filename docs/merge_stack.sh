#!/usr/bin/env bash
# Merges a stack of pull requests bottom-up with the GitHub CLI, the way docs/FINAL_STEPS.md step 1 describes. YOU run it; it never runs by itself.
#
#   bash docs/merge_stack.sh website     # KDR9MGR/bottles-up-website:   2 3 4 5 6 7 8 9 10
#   bash docs/merge_stack.sh vendor      # bottlesupapp-droid/bottles-up-vendor: 16 13 14 15 17 18 19 20 21
#   DRY_RUN=1 bash docs/merge_stack.sh website     # only shows what it would do
#
# Before each merge it checks that the pull request is open, not a draft, that it is based on main (GitHub moves a stacked pull request onto main by itself once the one
# below it is merged and its branch deleted; it waits up to 2 minutes for that), and that nothing blocks it. It merges with a merge commit and deletes the branch. It stops
# at the first thing that is not as expected and tells you which pull request and why. It asks you to type "merge" first.
set -uo pipefail
case "${1:-}" in
  website) REPO="KDR9MGR/bottles-up-website";            PRS="2 3 4 5 6 7 8 9 10" ;;
  vendor)  REPO="bottlesupapp-droid/bottles-up-vendor";  PRS="16 13 14 15 17 18 19 20 21" ;;
  *) echo "usage: bash docs/merge_stack.sh website|vendor"; exit 2 ;;
esac
command -v gh >/dev/null || { echo "the GitHub CLI (gh) is needed"; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "run 'gh auth login' first"; exit 2; }

echo "Repository: $REPO"
echo "Order:      $PRS"
for n in $PRS; do
  gh pr view "$n" --repo "$REPO" --json number,title,state,baseRefName,headRefName,isDraft,mergeable \
    --jq '"  #\(.number) [\(.state)] \(.headRefName) -> \(.baseRefName)  \(.title[0:70])"' 2>/dev/null || echo "  #$n: not found"
done
if [ "${DRY_RUN:-}" = "1" ]; then echo "dry run: nothing merged"; exit 0; fi
printf 'Type "merge" to merge them in this order (anything else stops): '
read -r answer
[ "$answer" = "merge" ] || { echo "stopped, nothing merged"; exit 1; }

for n in $PRS; do
  info() { gh pr view "$n" --repo "$REPO" --json state,baseRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup 2>/dev/null; }
  state=$(info | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["state"])') || { echo "#$n: cannot read it"; exit 1; }
  if [ "$state" = "MERGED" ]; then echo "#$n: already merged, skipping"; continue; fi
  [ "$state" = "OPEN" ] || { echo "#$n: is $state, not open. Stopping."; exit 1; }
  for i in $(seq 1 24); do
    base=$(info | python3 -c 'import json,sys; print(json.load(sys.stdin)["baseRefName"])')
    [ "$base" = "main" ] && break
    echo "#$n: still based on $base, waiting for GitHub to move it onto main ($i/24)..."; sleep 5
  done
  [ "$base" = "main" ] || { echo "#$n: is based on $base, not main. Stopping (do not merge it into another branch)."; exit 1; }
  python3 - "$n" <<PY || exit 1
import json, subprocess, sys
n = sys.argv[1]
d = json.loads(subprocess.run(["gh", "pr", "view", n, "--repo", "$REPO", "--json", "isDraft,mergeable,mergeStateStatus,statusCheckRollup"], capture_output=True, text=True).stdout)
if d["isDraft"]: sys.exit(f"#{n}: is a draft. Stopping.")
if d["mergeable"] == "CONFLICTING": sys.exit(f"#{n}: has merge conflicts. Stopping (tell Claude which pull request).")
bad = [c.get("name") or c.get("context") for c in d.get("statusCheckRollup") or [] if (c.get("conclusion") or c.get("state")) in ("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT")]
if bad: sys.exit(f"#{n}: a check failed ({', '.join(map(str, bad))}). Stopping.")
PY
  echo "#$n: merging..."
  gh pr merge "$n" --repo "$REPO" --merge --delete-branch || { echo "#$n: the merge did not go through. Stopping."; exit 1; }
done
echo "All merged. Tell Claude, so the monorepo pointers can be moved."
