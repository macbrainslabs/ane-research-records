#!/bin/bash
# run-anerecore-all.sh: anerecore probe tier for the v0.4.0 package.
# 1. reference bindirs from a git archive of base 09177138 (pre-#264), as v0.3.0 used;
# 2. the full tier (every probe file) from the git archive of the commit under test.
# Corpus: the 142 reviewer-B corpus files rebuilt by content (each sha256 equal to the v0.3.0
# tier-inputs.sha256 entry). REALMIL: the v0.3.0 real-MIL list, corpus prefix moved, unreadable paths dropped.
set -u
V=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/verify
P=$V/probes/anerecore
export PROBES=$P CORPUS=$V/anerecore-corpus REALMIL=$V/realmil-v040-readable.txt JOBS=3
OUT=$V/anerecore-tier
[ -e "$OUT" ] && { echo "exists: $OUT" >&2; exit 2; }
mkdir -p "$OUT"
echo "STARTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OUT/run-info.txt"
bash "$P/run-pr264-B.sh" "$V/ref-09177138" "$OUT/ref-pr264-B" "$CORPUS" > "$OUT/ref-pr264-B.log" 2>&1; echo "ref_pr264B_rc=$?" >> "$OUT/run-info.txt"
bash "$P/run-pr264-B-r2.sh" "$V/ref-09177138" "$OUT/ref-pr264-B-r2" "$CORPUS" > "$OUT/ref-pr264-B-r2.log" 2>&1; echo "ref_pr264Br2_rc=$?" >> "$OUT/run-info.txt"
bash "$V/run-anerecore-tier.sh" "$V/src-7d879697" "$OUT/tier" "$OUT/ref-pr264-B" "$OUT/ref-pr264-B-r2" > "$OUT/tier.log" 2>&1; echo "tier_rc=$?" >> "$OUT/run-info.txt"
echo "FINISHED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUT/run-info.txt"
echo ANERECORE_ALL_DONE >> "$OUT/run-info.txt"
