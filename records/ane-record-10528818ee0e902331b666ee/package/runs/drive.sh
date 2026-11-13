#!/bin/bash
# Counted control runs for the v0.4.0 dispatch record. Every invocation is kept, pass or fail.
WT=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/ane-re
B=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/cleanroom-bin/cleanroom
R=/Users/nayte/ane-hot/runs/qwen-dispatch-v040-20261112
for p in ane-vs-gpu cpuonly; do
  for i in 1 2 3 4 5; do
    O=$R/$p/run-$i
    echo "$(date -u +%FT%TZ) start $p run-$i" >> $R/drive.log
    "$B" --profile "$WT/spi/cleanroom/profiles/qwen25-dispatch-$p-20261112.json" --out "$O" --control --tool-source "$WT/spi/cleanroom/cleanroom.swift" > "$R/$p-run-$i.stdout" 2>&1
    echo "$(date -u +%FT%TZ) end $p run-$i exit=$?" >> $R/drive.log
  done
done
echo "$(date -u +%FT%TZ) ALL_DONE" >> $R/drive.log
