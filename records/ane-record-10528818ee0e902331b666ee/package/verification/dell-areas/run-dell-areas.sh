#!/bin/bash
# run-dell-areas.sh <commit> <out-dir>
# Runs every Dell-side node probe file of the areas intake, rerun, r4 (not deploy-gates, not neo/),
# replication and diagnostic-tier against a fresh git archive of <commit> of macbrains-research-automation,
# one file at a time (each copied into the archive's tests/, run from the archive root),
# then the handoff-event run-all.mjs. One line per file: rc, tests, pass, fail, skipped.
set -u
C=$1; O=$2
REPO=$HOME/Projects/macbrains-research-automation
PR=$HOME/.local/state/anvil/review-standards/probes
[ -e "$O" ] && { echo "exists: $O" >&2; exit 2; }
mkdir -p "$O/ra" || exit 2
git -C "$REPO" archive "$C" | tar -x -C "$O/ra" || exit 2
cp "$PR"/r4/r4B-fixture.mjs "$O/ra/tests/" 2>/dev/null
cp -r "$PR"/rerun/fixtures "$O/ra/tests/rerun-fixtures" 2>/dev/null
echo "COMMIT=$C STARTED=$(date -u +%FT%TZ)" > "$O/summary.txt"
cd "$O/ra" || exit 2
for area in diagnostic-tier replication intake rerun r4; do
  for f in "$PR/$area"/*.test.mjs; do
    [ -f "$f" ] || continue
    n=$(basename "$f"); sha=$(sha256sum "$f" | cut -c1-64)
    cp "$f" "tests/$n"
    env -u NODE_TEST_CONTEXT R4A_HEAD=$C R4B1_HEAD=$C timeout 600 node --test "tests/$n" > "$O/$area--$n.log" 2>&1; rc=$?
    t=$(grep -E "^# tests " "$O/$area--$n.log" | awk '{print $3}'); p=$(grep -E "^# pass " "$O/$area--$n.log" | awk '{print $3}')
    fl=$(grep -E "^# fail " "$O/$area--$n.log" | awk '{print $3}'); s=$(grep -E "^# skipped " "$O/$area--$n.log" | awk '{print $3}')
    echo "$area $n rc=$rc tests=$t pass=$p fail=$fl skipped=$s sha256=$sha" >> "$O/summary.txt"
  done
done
env -u NODE_TEST_CONTEXT timeout 1800 node "$PR/handoff-event/run-all.mjs" > "$O/handoff-event.log" 2>&1; echo "handoff-event run-all rc=$?" >> "$O/summary.txt"
echo "FINISHED=$(date -u +%FT%TZ)" >> "$O/summary.txt"
echo DELL_AREAS_DONE >> "$O/summary.txt"
