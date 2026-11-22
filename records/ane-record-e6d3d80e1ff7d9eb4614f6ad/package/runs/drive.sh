#!/bin/bash
# Counted set-mode runs for the v0.5.0 record: one cleanroom --runs 5 set per frozen profile, pinned
# cleanroom-d58fb354. Every invocation is kept, pass or fail. Args: profile short names (default all four).
W=/Users/nayte/.local/share/anvil/v050/ane-re
B=/Users/nayte/.local/share/anvil/cleanroom/bin/cleanroom-d58fb354
T=/Users/nayte/.local/share/anvil/cleanroom/release-d58fb354/spi/cleanroom/cleanroom.swift
R=/Volumes/ANVIL-SSD/ane-hot/runs/qwen25-v050-20261122
mkdir -p $R
L=${*:-dispatch-ane dispatch-gpu dispatch-cpuonly fp32-reference}
for p in $L; do
  O=$R/$p
  echo "$(date -u +%FT%TZ) start $p" >> $R/drive.log
  "$B" --profile "$W/spi/cleanroom/profiles/qwen25-v050-$p-20261122.json" --out "$O" --runs 5 --tool-source "$T" > "$R/$p.stdout" 2>&1
  rc=$?
  echo "$(date -u +%FT%TZ) end $p exit=$rc" >> $R/drive.log
done
echo "$(date -u +%FT%TZ) DONE $L" >> $R/drive.log
