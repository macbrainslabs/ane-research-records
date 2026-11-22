#!/bin/bash
# Pre-freeze baselines for the v0.5.0 set-mode profiles: one uncounted run per profile, by a runner rebuilt
# from commit C1 exactly as cleanroom rebuilds it (git show into a build dir; xcrun swiftc -O -parse-as-library).
# Every run is kept. index.json lists every dump file with its sha256 (cleanroom baseline format).
set -u
C1=8271bb68c0ac86afdd652e28b96e6ce71c8c3731
W=/Users/nayte/.local/share/anvil/v050/ane-re
B=/Users/nayte/.local/share/anvil/frozen-inputs/qwen25-ref-v050-20261122
PR=/Users/nayte/.local/share/anvil/frozen-inputs/qwen-dispatch-20261112/qwen25-chatml-prompt-28.json
ML=/Volumes/ANVIL-SSD/ane-hot/models/published/qwen2.5-1.5b-instruct-ane/7f9ab466b2265a96941670119670638ea22b65dc/qwen25_monolithic_full_lut4.mlmodelc
ST=/Volumes/ANVIL-SSD/ane-hot/models/reference/qwen2.5-1.5b-instruct/model.safetensors
mkdir -p $B/build && cd $B/build
for r in qwen_dispatch_runner qwen25_ref_runner; do
  git -C $W show $C1:spi/cleanroom/runners/$r.swift > $r.swift
  xcrun swiftc -O -parse-as-library $r.swift -o $r > $r.build.log 2>&1 || { echo "BUILD_FAIL $r"; exit 1; }
done
shasum -a 256 *.swift qwen_dispatch_runner qwen25_ref_runner > ../build.sha256
run() { # name binary fixture tokens computeUnits
  local n=$1 bin=$2 fx=$3 tok=$4 cu=$5 d=$B/baseline-$1
  mkdir -p $d/tmp
  local s=$(date -u +%FT%TZ)
  TMPDIR=$d/tmp/ LFM3_COMPUTE_UNITS=$cu LFM3_VECTOR_DUMP_DIR=$d/dump LFM3_RESULT_JSON=$d/result.json \
    $B/build/$bin infer-chain $fx $PR $tok > $d/run.log 2>&1
  local ec=$?
  { printf '{\n  "schema": "macbrains.research.cleanroom-baseline-index.v1",\n  "name": "%s",\n  "runStartedAt": "%s",\n  "runEndedAt": "%s",\n  "exitCode": %d,\n  "counted": false,\n  "runnerSha256": "%s",\n  "sourceCommit": "%s",\n  "computeUnits": "%s",\n  "tokens": "%s",\n  "files": [' "$n" "$s" "$(date -u +%FT%TZ)" $ec "$(shasum -a 256 $B/build/$bin | cut -c1-64)" $C1 $cu $tok
    first=1
    for f in $(cd $d/dump && find . -type f | sed 's|^\./||' | LC_ALL=C sort); do
      [ $first -eq 1 ] && first=0 || printf ','
      printf '\n    {"path": "%s", "sha256": "%s"}' "$f" "$(shasum -a 256 $d/dump/$f | cut -c1-64)"
    done
    printf '\n  ]\n}\n'; } > $d/index.json
  echo "$(date -u +%FT%TZ) baseline $n exit=$ec" >> $B/baseline.log
}
run ane qwen_dispatch_runner $ML 200 cpuAndNeuralEngine
run gpu qwen_dispatch_runner $ML 200 cpuAndGPU
run cpuonly qwen_dispatch_runner $ML 4 cpuOnly
run ref qwen25_ref_runner $ST 64 cpuOnly
echo "$(date -u +%FT%TZ) ALL_DONE" >> $B/baseline.log
