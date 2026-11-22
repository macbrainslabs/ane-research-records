#!/bin/bash
# v0.5.0 anerecore tier, run 2. Run 1 (verify/anerecore) failed pr264-A-10 and pr264-B-06 only because 8 of the
# corpus's 14 iCloud links had been downloaded since v0.4.0 (OK 142 / UNREADABLE 6, not 134 / 14). This run evicts
# those 8 local copies with brctl (contents stay in iCloud; the v0.3.0/v0.4.0 corpus state is "dataless") and reruns
# the whole tier into verify/anerecore-2. Run 1 is kept as it stands.
set -u
W=/Users/nayte/.local/share/anvil/v050/verify
V=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/verify
G=/Users/nayte/.local/share/anvil/v050/ane-re
C=$V/anerecore-corpus-v2
O=$W/anerecore-2
[ -e "$O" ] && { echo "exists: $O" >&2; exit 2; }
mkdir -p "$O"
{
echo "STARTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "# link flags before eviction"
for l in $(find $C -type l | LC_ALL=C sort); do t=$(readlink "$l"); echo "$(ls -lO "$t" | awk '{print $5}') $t"; done
for l in $(find $C -type l | LC_ALL=C sort); do t=$(readlink "$l"); ls -lO "$t" | awk '{print $5}' | grep -q dataless || { brctl evict "$t"; echo "evict rc=$? $t"; }; done
sleep 20
echo "# link flags after eviction"
for l in $(find $C -type l | LC_ALL=C sort); do t=$(readlink "$l"); echo "$(ls -lO "$t" | awk '{print $5}') $t"; done
} > "$O/eviction.txt" 2>&1
n=$(grep -c '^compressed,dataless' <(sed -n '/after eviction/,$p' "$O/eviction.txt"))
echo "dataless_after=$n" > "$O/run-info.txt"
[ "$n" = 14 ] || { echo "EVICT_INCOMPLETE" >> "$O/run-info.txt"; exit 3; }
# Sources: git archive of the commit under test and of the pre-#264 reference base.
mkdir -p "$O/archive" "$O/ref-09177138-archive"
git -C "$G" archive 7915d08fdcbd59c2d157a538c52016ace6d4fd81 | tar -x -C "$O/archive"
git -C "$G" archive 09177138 | tar -x -C "$O/ref-09177138-archive"
cp -p $W/anerecore/realmil-v050-readable.txt "$O/"
echo "STARTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$O/run-info.txt"
export PROBES=$V/probes/anerecore CORPUS=$C REALMIL=$O/realmil-v050-readable.txt JOBS=3
export FUGU=/Volumes/ANVIL-SSD/ane-hot/runs/anerecore-parity-v03-20261105.n82Rhe/expanded/attempt2-fugu.mil
P=$PROBES
bash "$P/run-pr264-B.sh" "$O/ref-09177138-archive" "$O/ref-pr264-B" "$CORPUS" > "$O/ref-pr264-B.log" 2>&1; echo "ref_pr264B_rc=$?" >> "$O/run-info.txt"
bash "$P/run-pr264-B-r2.sh" "$O/ref-09177138-archive" "$O/ref-pr264-B-r2" "$CORPUS" > "$O/ref-pr264-B-r2.log" 2>&1; echo "ref_pr264Br2_rc=$?" >> "$O/run-info.txt"
bash "$W/run-anerecore-tier.sh" "$O/archive" "$O/tier" "$O/ref-pr264-B" "$O/ref-pr264-B-r2" > "$O/tier.log" 2>&1; echo "tier_rc=$?" >> "$O/run-info.txt"
echo "FINISHED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$O/run-info.txt"
rm -rf "$O/archive" "$O/ref-09177138-archive"
echo ANERECORE2_DONE >> "$O/run-info.txt"
