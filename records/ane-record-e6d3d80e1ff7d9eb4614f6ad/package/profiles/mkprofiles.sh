#!/bin/bash
# Writes the four v0.5.0 set-mode profiles from the finished pre-freeze baselines. Run after baseline.sh.
set -eu
C1=8271bb68c0ac86afdd652e28b96e6ce71c8c3731
W=/Users/nayte/.local/share/anvil/v050/ane-re
P=$W/spi/cleanroom/profiles
B=/Users/nayte/.local/share/anvil/frozen-inputs/qwen25-ref-v050-20261122
PR=/Users/nayte/.local/share/anvil/frozen-inputs/qwen-dispatch-20261112/qwen25-chatml-prompt-28.json
MLD=/Volumes/ANVIL-SSD/ane-hot/models/published/qwen2.5-1.5b-instruct-ane/7f9ab466b2265a96941670119670638ea22b65dc
ML=$MLD/qwen25_monolithic_full_lut4.mlmodelc
ST=/Volumes/ANVIL-SSD/ane-hot/models/reference/qwen2.5-1.5b-instruct/model.safetensors
[ -n "${ONLY:-}" ] || grep -q ALL_DONE $B/baseline.log
want() { [ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]; }
TSV=$(shasum -a 256 $PR | cut -c1-64)
MLSHA=$( (cd $ML && find . -type f | LC_ALL=C sort | xargs shasum -a 256) | shasum -a 256 | cut -c1-64)
STSHA=dd924a11b4c220f385b51ffa522daea7c9f3d850e31b162bb5661df483c6d3ee
DEV='"deviceScope": {"chip": "Apple A18 Pro", "hwModel": "Mac17,5", "osVersion": "27.3", "osBuild": "26C5047e", "coreMLBundleVersion": "3610.2.3"}'
mk() { # file id runner fixture fixtureSha fixtureNote tokens computeUnits baselineName criterion hypothesis
  local f=$1 id=$2 r=$3 fx=$4 fxs=$5 fxn=$6 tok=$7 cu=$8 bn=$9 crit=${10} hyp=${11}
  local idx=$B/baseline-$bn/index.json
  local rsha=$(grep '"runnerSha256"' $idx | sed 's/.*: "\([0-9a-f]*\)".*/\1/')
  cat > $P/$f <<EOF
{
  "id": "$id",
  "criterion": "$crit",
  "mode": "replication-set",
  "source": {
    "rebuild": true,
    "repo": "$W",
    "commit": "$C1",
    "probeFiles": ["spi/cleanroom/runners/$r.swift"],
    "mainFile": "$r.swift",
    "swiftcArgs": ["-O", "-parse-as-library"],
    "baselineRunnerSha": "$rsha"
  },
  "run": {
    "argvMode": "infer-chain",
    "fixture": "$fx",
    "tsv": "$PR",
    "tokens": "$tok",
    "computeUnits": "$cu",
    "fixtureSha256": "$fxs",
    "fixtureShaMethod": "$fxn",
    "tsvSha256": "$TSV"
  },
  "baseline": {
    "indexJson": "$idx",
    "indexSha256": "$(shasum -a 256 $idx | cut -c1-64)",
    "note": "One uncounted pre-freeze run (2026-11-22) by a runner rebuilt from source.commit the way cleanroom rebuilds it; kept with its log next to index.json"
  },
  "isolation": {"sandboxExec": false},
  $DEV,
  "expected": {
    "byteIdenticalToBaseline": true,
    "hypothesis": "$hyp",
    "placement": "Core ML compute-plan preferred device per op is recorded in result.json for Core ML arms; ANE execution is INFERRED from placement, not traced"
  },
  "permittedModifications": [
    "None: binary, fixture, prompt, decode steps and compute units are fixed by this profile; each counted run must be byte-identical to the baseline."
  ]
}
EOF
}
MLN="sha256 of the LC_ALL=C sorted 'shasum -a 256' listing of every file under the .mlmodelc (paths relative to it, ./ prefix); the package zip qwen25_monolithic_full_lut4.mlmodelc.zip at the same commit has sha256 194b8f1088030eb2f27ac68fb1ccfa240776f73cb8c1d090978c7e3bd7f51c70"
STN="sha256 of model.safetensors, Qwen/Qwen2.5-1.5B-Instruct at Hugging Face commit 989aa7980e4cf806f80c7fef2b1adb7bc71aa306 (equals the Hugging Face LFS sha256); the runner also hashes it into every dump"
CRITD="Published Qwen2.5-1.5B-Instruct-ANE LUT4 package (HF NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE @7f9ab466), qwen_dispatch_runner"
want ane && mk qwen25-v050-dispatch-ane-20261122.json qwen25-v050-dispatch-ane-20261122 qwen_dispatch_runner $ML $MLSHA "$MLN" 200 cpuAndNeuralEngine ane \
  "$CRITD under Core ML cpuAndNeuralEngine, 200 greedy steps: every counted fresh-process run byte-identical to the pre-freeze baseline" \
  "Pre-freeze baseline (not counted) and the v0.4.0 record: first generated token 40; compared with the fp32 reference of the original weights, the first token differs"
want gpu && mk qwen25-v050-dispatch-gpu-20261122.json qwen25-v050-dispatch-gpu-20261122 qwen_dispatch_runner $ML $MLSHA "$MLN" 200 cpuAndGPU gpu \
  "$CRITD under Core ML cpuAndGPU, 200 greedy steps: every counted fresh-process run byte-identical to the pre-freeze baseline" \
  "Pre-freeze baseline (not counted) and the v0.4.0 record: first generated token 9707, which equals the fp32 reference's first token"
want cpuonly && mk qwen25-v050-dispatch-cpuonly-20261122.json qwen25-v050-dispatch-cpuonly-20261122 qwen_dispatch_runner $ML $MLSHA "$MLN" 4 cpuOnly cpuonly \
  "$CRITD under Core ML cpuOnly, 4 greedy steps: every counted fresh-process run byte-identical to the pre-freeze baseline" \
  "Pre-freeze baseline (not counted) and the v0.4.0 record: every prefill position all-NaN"
want ref && mk qwen25-v050-fp32-reference-20261122.json qwen25-v050-fp32-reference-20261122 qwen25_ref_runner $ST $STSHA "$STN" 64 cpuOnly ref \
  "Independent fp32 CPU reference of the original Qwen/Qwen2.5-1.5B-Instruct bf16 weights (qwen25_ref_runner, no Core ML), same prompt, 64 greedy steps: every counted fresh-process run byte-identical to the pre-freeze baseline, self-check bit-identical" \
  "Pre-freeze dev and baseline runs (not counted): last-prompt-position winner 9707 (40 ranked third), self-check bit-identical"
for f in $P/qwen25-v050-*.json; do jq -e . $f >/dev/null && echo "$f ok"; done
