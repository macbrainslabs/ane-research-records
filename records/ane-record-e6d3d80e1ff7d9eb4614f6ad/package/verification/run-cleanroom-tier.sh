#!/bin/bash
# run-cleanroom-tier.sh <probes-dir> <git-archive-root> <cleanroom-binary> <work-root> [<superseded-list> | --skip-sub]
# Runs EVERY *.sh probe file in <probes-dir> (checklist 9.x) against a cleanroom binary built from
# <git-archive-root>/spi/cleanroom/cleanroom.swift. One line per file, then a total.
# Arguments per probe follow each file's own Usage line. Each probe gets its own fresh work dir.
# <superseded-list>: optional file, one line per superseded original:
#   <probe-name><TAB><expected SUMMARY counts, e.g. pass=14 fail=8><TAB><where the supersession is recorded>
# A listed probe is still run and its output kept. It is shown as SUPERSEDED and not counted only when
# its SUMMARY counts equal the recorded ones exactly; any other result is a FAIL, so a change in a
# superseded probe's behaviour is never hidden. The originals' own exit codes are shown.
# pr265-sub-01.sh does 3 real NOT-counted scratch runs (6 device-log lines under scratch hashes);
# --skip-sub leaves it out and the total then says so (not a full tier).
set -u
P=$1; SRC=$2; BIN=$3; W=$4; OPT=${5:-}
SKIP=""; SUPF=""
case "$OPT" in --skip-sub) SKIP=1 ;; "") ;; *) SUPF=$OPT; [ -f "$SUPF" ] || { echo "superseded list missing: $SUPF" >&2; exit 2; } ;; esac
[ -e "$W" ] && { echo "work root exists: $W" >&2; exit 2; }
mkdir -p "$W" || exit 2
# Probes cd elsewhere and call the binary by the path given, so every path is made absolute here.
abs() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(pwd)" "$1" ;; esac; }
P=$(abs "$P"); SRC=$(abs "$SRC"); BIN=$(abs "$BIN"); W=$(abs "$W"); [ -n "$SUPF" ] && SUPF=$(abs "$SUPF")
[ -x "$BIN" ] || { echo "binary not executable: $BIN" >&2; exit 2; }
[ -f "$SRC/spi/cleanroom/cleanroom.swift" ] || { echo "no cleanroom.swift under $SRC" >&2; exit 2; }
SWIFT="$SRC/spi/cleanroom/cleanroom.swift"
L14="$SRC/spi/cleanroom/profiles/l14-minimal.profile.json"
pass=0; fail=0; skipped=0; sup=0
for f in "$P"/*.sh; do
  n=$(basename "$f" .sh); sha=$(shasum -a 256 "$f" | cut -c1-64)
  case "$n" in
    pr265-sub-01) [ -n "$SKIP" ] && { echo "SKIP $n sha256=$sha"; skipped=$((skipped+1)); continue; }
                  args=("$BIN" "$W/$n") ;;
    pr265-r1-02-l14-committed-profile|pr265-r1-02-l14-committed-profile.v2) args=("$BIN" "$L14" "$W/$n") ;;
    pr265-r3-01-relative-link-and-walkdump) args=("$BIN" "$SWIFT" "$W/$n") ;;
    pr265-r4-01-control-dump-records) args=("$SWIFT" "$W/$n") ;;
    *) args=("$BIN" "$W/$n") ;;
  esac
  /bin/bash "$f" "${args[@]}" > "$W/$n.log" 2>&1; rc=$?
  counts=$(grep -E "^(SUMMARY|RESULT) " "$W/$n.log" | tail -1 | grep -oE "pass=[0-9]+ fail=[0-9]+")
  want=""; where=""
  if [ -n "$SUPF" ]; then
    want=$(awk -F'\t' -v n="$n" '$1==n{print $2}' "$SUPF"); where=$(awk -F'\t' -v n="$n" '$1==n{print $3}' "$SUPF")
  fi
  if [ -n "$want" ]; then
    if [ "$counts" = "$want" ]; then echo "SUPERSEDED $n exit=$rc $counts (equals the recorded $want; $where; not counted) sha256=$sha"; sup=$((sup+1));
    else echo "FAIL $n exit=$rc ${counts:-no SUMMARY} (superseded original expected exactly $want; $where) sha256=$sha"; fail=$((fail+1)); fi
    continue
  fi
  if [ $rc -eq 0 ]; then echo "PASS $n ${counts} sha256=$sha"; pass=$((pass+1)); else echo "FAIL $n exit=$rc ${counts} log=$W/$n.log sha256=$sha"; fail=$((fail+1)); fi
done
echo "TOTAL pass=$pass fail=$fail superseded=$sup skipped=$skipped probe-files=$((pass+fail+sup+skipped)) bin=$(shasum -a 256 "$BIN" | cut -c1-64) src=$SRC"
[ $fail -eq 0 ] && [ $skipped -eq 0 ]
