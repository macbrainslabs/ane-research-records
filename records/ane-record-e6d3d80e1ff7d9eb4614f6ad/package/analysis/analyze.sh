#!/bin/bash
# v0.5.0 analysis over the counted runs: builds compare/recompute from the committed source (C1), then for each
# run index i = 1..5 compares ref run-i against ane/gpu/cpuonly run-i, recomputes it independently, and runs the
# negative test once on run-1. Also checks every counted dump is byte-identical across runs (sha listing).
set -u
C1=8271bb68c0ac86afdd652e28b96e6ce71c8c3731
W=/Users/nayte/.local/share/anvil/v050/ane-re
R=/Volumes/ANVIL-SSD/ane-hot/runs/qwen25-v050-20261122
A=/Users/nayte/.local/share/anvil/v050/analysis
PR=/Users/nayte/.local/share/anvil/frozen-inputs/qwen-dispatch-20261112/qwen25-chatml-prompt-28.json
[ -e "$A" ] && { echo "exists: $A" >&2; exit 2; }
mkdir -p "$A/bin" "$A/src" "$A/compare" "$A/recompute" "$A/negtest"
for f in qwen25_ref_compare qwen25_ref_recompute; do
  git -C "$W" show "$C1:spi/cleanroom/analysis/$f.swift" > "$A/src/$f.swift"
  xcrun swiftc -O "$A/src/$f.swift" -o "$A/bin/$f" > "$A/bin/$f.build.log" 2>&1 || { echo "build failed $f" >&2; exit 1; }
done
git -C "$W" show "$C1:spi/cleanroom/analysis/test_qwen25_ref_negatives.sh" > "$A/src/test_qwen25_ref_negatives.sh"
(cd "$A" && shasum -a 256 src/* bin/qwen25_ref_compare bin/qwen25_ref_recompute) > "$A/bin/SHA256SUMS"
status=0
for i in 1 2 3 4 5; do
  n=$(printf 'run-%03d' $i)
  REF=$R/fp32-reference/$n/dump
  ARMS=("ane=$R/dispatch-ane/$n/dump" "gpu=$R/dispatch-gpu/$n/dump" "cpuonly=$R/dispatch-cpuonly/$n/dump")
  "$A/bin/qwen25_ref_compare" "$REF" "$A/compare/compare-$n.json" "${ARMS[@]}" > "$A/compare/compare-$n.log" 2>&1; c=$?
  "$A/bin/qwen25_ref_recompute" "$REF" "$PR" "$A/compare/compare-$n.json" "$A/recompute/recompute-$n.json" "${ARMS[@]}" > "$A/recompute/recompute-$n.log" 2>&1; r=$?
  echo "$n compare_exit=$c recompute_exit=$r $(grep -o '"status" *: *"[A-Z]*"' "$A/recompute/recompute-$n.json" | head -1)" | tee -a "$A/analysis.log"
  [ $c -eq 0 ] && [ $r -eq 0 ] || status=1
done
REF=$R/fp32-reference/run-001/dump
bash "$A/src/test_qwen25_ref_negatives.sh" "$A/bin/qwen25_ref_recompute" "$REF" "$PR" "$A/compare/compare-run-001.json" "$A/negtest/scratch" \
  "ane=$R/dispatch-ane/run-001/dump" "gpu=$R/dispatch-gpu/run-001/dump" "cpuonly=$R/dispatch-cpuonly/run-001/dump" > "$A/negtest/negtest.log" 2>&1
echo "negtest exit=$? $(grep SUMMARY "$A/negtest/negtest.log")" | tee -a "$A/analysis.log"
# Compare outputs must be identical across the five run indices (dumps are byte-identical per profile).
echo "compare files distinct sha256: $(shasum -a 256 "$A"/compare/compare-run-*.json | cut -c1-64 | sort -u | wc -l | tr -d ' ')" | tee -a "$A/analysis.log"
# Byte identity across runs per profile, from the dumps themselves.
for p in dispatch-ane dispatch-gpu dispatch-cpuonly fp32-reference; do
  d=$(for k in 1 2 3 4 5; do (cd "$R/$p/$(printf 'run-%03d' $k)/dump" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | cut -c1-64); done | sort -u | wc -l | tr -d ' ')
  echo "$p distinct dump listings across 5 runs: $d" | tee -a "$A/analysis.log"
done
echo "ANALYSIS_DONE status=$status" | tee -a "$A/analysis.log"
