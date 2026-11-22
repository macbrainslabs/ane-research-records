#!/bin/bash
# v0.5.0 Neo tiers: cleanroom (9 files) then anerecore (64 files). Derived from v0.4.0 run-anerecore-all-2.sh.
set -u
W=/Users/nayte/.local/share/anvil/v050/verify
V=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/verify
SRC=$W/archive
mkdir -p $W/cleanroom
{
echo "STARTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cd $SRC/spi/cleanroom && xcrun swiftc -O cleanroom.swift -o $W/cleanroom/cleanroom-7915d08f > $W/cleanroom/build.log 2>&1; echo "build_rc=$?"
shasum -a 256 $W/cleanroom/cleanroom-7915d08f
cd $W
bash $W/run-cleanroom-tier.sh $V/probes/cleanroom $SRC $W/cleanroom/cleanroom-7915d08f $W/cleanroom/tier $W/cleanroom-superseded.tsv > $W/cleanroom/tier.out 2>&1; echo "cleanroom_tier_rc=$?"
echo "CLEANROOM_FINISHED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > $W/cleanroom/run-info.txt 2>&1
# anerecore: relocation of ~/ane-hot -> /Volumes/ANVIL-SSD/ane-hot only
mkdir -p $W/anerecore
sed 's#^/Users/nayte/ane-hot/#/Volumes/ANVIL-SSD/ane-hot/#' $V/realmil-v040-readable.txt > $W/anerecore/realmil-relocated.txt
n_all=$(wc -l < $W/anerecore/realmil-relocated.txt)
while read p; do [ -r "$p" ] && echo "$p"; done < $W/anerecore/realmil-relocated.txt > $W/anerecore/realmil-v050-readable.txt
while read p; do [ -r "$p" ] || echo "$p"; done < $W/anerecore/realmil-relocated.txt > $W/anerecore/realmil-unresolved.txt
echo "realmil: listed=$n_all readable=$(wc -l < $W/anerecore/realmil-v050-readable.txt) unresolved=$(wc -l < $W/anerecore/realmil-unresolved.txt)" > $W/anerecore/run-info.txt
echo "STARTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $W/anerecore/run-info.txt
export PROBES=$V/probes/anerecore CORPUS=$V/anerecore-corpus-v2 REALMIL=$W/anerecore/realmil-v050-readable.txt JOBS=3
export FUGU=/Volumes/ANVIL-SSD/ane-hot/runs/anerecore-parity-v03-20261105.n82Rhe/expanded/attempt2-fugu.mil
P=$PROBES
bash "$P/run-pr264-B.sh" "$W/ref-09177138-archive" "$W/anerecore/ref-pr264-B" "$CORPUS" > "$W/anerecore/ref-pr264-B.log" 2>&1; echo "ref_pr264B_rc=$?" >> $W/anerecore/run-info.txt
bash "$P/run-pr264-B-r2.sh" "$W/ref-09177138-archive" "$W/anerecore/ref-pr264-B-r2" "$CORPUS" > "$W/anerecore/ref-pr264-B-r2.log" 2>&1; echo "ref_pr264Br2_rc=$?" >> $W/anerecore/run-info.txt
bash "$W/run-anerecore-tier.sh" "$SRC" "$W/anerecore/tier" "$W/anerecore/ref-pr264-B" "$W/anerecore/ref-pr264-B-r2" > "$W/anerecore/tier.log" 2>&1; echo "tier_rc=$?" >> $W/anerecore/run-info.txt
echo "FINISHED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $W/anerecore/run-info.txt
echo NEO_ALL_DONE >> $W/anerecore/run-info.txt
