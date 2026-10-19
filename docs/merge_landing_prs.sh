#!/usr/bin/env bash
# Lands the three pull requests that bring everything onto main (docs/FINAL_STEPS.md step 1). YOU run it; it never runs by itself.
#
#   bash docs/merge_landing_prs.sh           # shows the plan, asks you to type "merge"
#   DRY_RUN=1 bash docs/merge_landing_prs.sh # only shows the plan
#
# Why not the old stack of pull requests: merging a stack bottom-up either lands each piece in an intermediate branch (vendor, 19 Oct) or, with "delete branch", closes the
# next pull request (website #3). So each repo now has ONE pull request from the top of the stack, which already contains every piece in order. Merge commits, no branch is deleted.
#   vendor  bottlesupapp-droid/bottles-up-vendor  #23  feat/business-brief-1 -> main  (the whole stack, version 1.3.0+8)
#   website KDR9MGR/bottles-up-website            #11  feat/business-brief-2 -> main  (organizer events, server desk, Phase 2 modules, September record, outbox, tranche 2)
#   website KDR9MGR/bottles-up-website            #9   feat/business-naming  -> main  (staff invitation e-mails say BottlesUp Business; merge it AFTER #11)
set -uo pipefail
PLAN=("bottlesupapp-droid/bottles-up-vendor 23" "KDR9MGR/bottles-up-website 11" "KDR9MGR/bottles-up-website 9")
command -v gh >/dev/null || { echo "the GitHub CLI (gh) is needed"; exit 2; }
for p in "${PLAN[@]}"; do set -- $p
  line=$(gh pr view "$2" --repo "$1" --json number,title,state,baseRefName,headRefName,mergeable --jq '"[\(.state)] \(.headRefName) -> \(.baseRefName)  \(.mergeable)  \(.title[0:60])"' 2>/dev/null) && echo "  $1 #$2 $line" || echo "  $1 #$2: not found"
done
[ "${DRY_RUN:-}" = "1" ] && { echo "dry run: nothing merged"; exit 0; }
printf 'Type "merge" to merge them in this order (anything else stops): '; read -r answer
[ "$answer" = "merge" ] || { echo "stopped, nothing merged"; exit 1; }
for p in "${PLAN[@]}"; do set -- $p
  state=$(gh pr view "$2" --repo "$1" --json state,baseRefName --jq '.state + " " + .baseRefName') || { echo "$1 #$2: cannot read it"; exit 1; }
  case "$state" in "MERGED "*) echo "$1 #$2: already merged"; continue;; "OPEN main") ;; *) echo "$1 #$2: is '$state', expected 'OPEN main'. Stopping."; exit 1;; esac
  echo "$1 #$2: merging..."
  gh pr merge "$2" --repo "$1" --merge || { echo "$1 #$2: did not merge. Stopping."; exit 1; }
done
echo "Done. Tell Claude, so the monorepo pointers can be moved."
