#!/bin/bash
# run-anerecore-tier.sh: the full anerecore review-probe tier, every probe file run exactly once.
# Usage: run-anerecore-tier.sh <src-tree> <outdir> [<pr264-B ref bindir> [<pr264-B-r2 ref bindir>]]
#   <src-tree>  a `git archive <commit>` extract of naytewilson/ane-re (never a working tree)
#   <outdir>    fresh output dir (binaries, per-probe output, summary.txt)
#   <ref>       optional bindir of a run-pr264-B.sh run on another tree (the base), for its differential
# Env: PROBES (probe dir; default: this script's dir if it holds the probes, else ./tier-probes next to it),
#   FUGU (Fugu artifact), CORPUS (on-device *.mil corpus), JOBS (parallel builds, default 3), SWIFTC,
#   REALMIL (file listing real *.mil paths for pr264-A-r2-05; default realmil.txt next to this script).
# pr264-B-r2-* run through run-pr264-B-r2.sh once, with the 4th argument as its reference bindir.
# Each probe is built the way its own runner builds it (swiftc -O -parse-as-library with
# <src>/spi/swift_emit/Sources/ANERECore/*.swift) and run with the arguments its runner passes.
# pr264-B-* run through run-pr264-B.sh once (its corpus driver and CLI checks need the runner).
# One line per probe file: PASS / FAIL (counted), INFO (reviewer-declared informational probe,
# never counted), TOOL (analysis tool, not a probe: never run by any runner).
# Exit status = number of FAIL lines. On Neo prefix with ANVIL_LOCAL_REASON="...".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = "--job" ]; then
  # Worker: --job <jobfile>; the job file holds <probe-file> <outdir> <src> args..., one per line.
  jf="$2"; set --; while IFS= read -r a; do set -- "$@" "$a"; done < "$jf"
  p="$1"; OUT="$2"; SRC="$3"; shift 3
  n="$(basename "$p" .swift)"; CORE="$SRC/spi/swift_emit/Sources/ANERECore"
  SWIFTC="${SWIFTC:-swiftc}"; command -v xcrun >/dev/null 2>&1 && [ "$SWIFTC" = swiftc ] && SWIFTC="xcrun swiftc"
  # r2-05 covers real MIL only; PR264A_CORPUS includes 5 intentionally body-less negative controls.
  # Keep all 5 in the other corpus probes, and include every readable real MIL in REALMIL.
  if [ "$n" = "pr264-A-r2-05-real-mil-no-false-reject" ]; then unset PR264A_CORPUS; fi
  if ! $SWIFTC -O -parse-as-library "$CORE"/*.swift "$p" -o "$OUT/bin/$n" > "$OUT/$n.build.log" 2>&1; then
    echo 98 > "$OUT/$n.rc"; echo "build failed (see $OUT/$n.build.log)" > "$OUT/$n.out"; exit 0
  fi
  "$OUT/bin/$n" "$@" > "$OUT/$n.out" 2>&1; echo $? > "$OUT/$n.rc"; exit 0
fi
SRC="$(cd "${1:?usage: run-anerecore-tier.sh <src-tree> <outdir> [ref-bindir]}" && pwd)"
[ -n "$SRC" ] || { echo "TIER_FAIL src tree missing" >&2; exit 97; }
OUT="${2:?outdir}"; REF="${3:-}"; REF2="${4:-}"
REALMIL="${REALMIL:-$HERE/realmil.txt}"
if [ -n "${PROBES:-}" ]; then D="$PROBES"; elif ls "$HERE"/pr262-A-01-*.swift >/dev/null 2>&1; then D="$HERE"; else D="$HERE/tier-probes"; fi
FUGU="${FUGU:-/Users/nayte/ane-hot/runs/anerecore-parity-v03-20261105.n82Rhe/expanded/attempt2-fugu.mil}"
CORPUS="${CORPUS:-/Users/nayte/.anvil/tmp/review-B-262/corpus}"
JOBS="${JOBS:-3}"
FIX="$SRC/tests/fixtures/qwen/model.mil"
rm -rf "$OUT"; mkdir -p "$OUT/bin"; OUT="$(cd "$OUT" && pwd)"
export PR263A_CORPUS="$CORPUS" PR264A_CORPUS="$CORPUS"
shaf() { shasum -a 256 "$1" 2>/dev/null | cut -c1-64 || sha256sum "$1" | cut -c1-64; }
echo "TIER src=$SRC probes=$D started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# Background: reviewer B's #264 runner (its probes, corpus driver, CLI pins, differential).
( bash "$D/run-pr264-B.sh" "$SRC" "$OUT/pr264-B" "$CORPUS" $REF > "$OUT/pr264-B.log" 2>&1; echo $? > "$OUT/pr264-B.rc" ) &
B264=$!
( bash "$D/run-pr264-B-r2.sh" "$SRC" "$OUT/pr264-B-r2" "$CORPUS" $REF2 > "$OUT/pr264-B-r2.log" 2>&1; echo $? > "$OUT/pr264-B-r2.rc" ) &
B264R2=$!
mkdir -p "$OUT/jobs"; k=0
for p in "$D"/*.swift; do
  n="$(basename "$p" .swift)"
  case "$n" in
    pr264-B-*|pr263-B-tool-*|pr263-B-r2-tool-*) continue;;
    pr262-A-0*|pr263-A-0*) set -- "$FIX" "$FUGU";;
    pr262-B-09-*) set -- "$SRC" "$FUGU";;
    pr263-B-04-*|pr263-B-I2-*|pr263-B-r2-I2-*) set -- "$SRC" "$CORPUS";;
    pr262-B-*|pr263-B-*) set -- "$SRC";;
    pr264-A-r2-05-*) if [ -f "$REALMIL" ]; then set -- "$REALMIL"; else set --; fi;;
    *) set --;;
  esac
  k=$((k+1)); jf="$OUT/jobs/$(printf %03d $k)"; printf '%s\n' "$p" "$OUT" "$SRC" "$@" > "$jf"
done
ls "$OUT"/jobs/* | xargs -P "$JOBS" -n 1 /bin/bash "$HERE/$(basename "$0")" --job
wait $B264 $B264R2
# A probe a later probe file declares superseded ("(supersedes pr263-B-03; ...") is run and shown, never counted.
SUPS="$(grep -ho "supersedes pr[0-9A-Za-z-]*" "$D"/*.swift 2>/dev/null | sed "s/^supersedes //" | sort -u | tr "\n" " ")"; sup=0
superseded() { for s in $SUPS; do case "$1" in "$s"|"$s"-*) return 0;; esac; done; return 1; }
pass=0; fail=0; info=0; tool=0; S="$OUT/summary.txt"; : > "$S"
line() { echo "$*" | tee -a "$S" >/dev/null; }
for p in "$D"/*.swift; do
  n="$(basename "$p" .swift)"; sha="$(shaf "$p")"
  if superseded "$n"; then rc="$(cat "$OUT/$n.rc" 2>/dev/null || echo 99)"; line "SUPERSEDED $n rc=$rc (a later probe file declares it superseded; never counted) sha256=$sha"; sup=$((sup+1)); continue; fi
  case "$n" in
    pr263-B-tool-*|pr263-B-r2-tool-*) line "TOOL $n (analysis tool, not run by any runner) sha256=$sha"; tool=$((tool+1)); continue;;
    pr264-B-shim-base) line "TOOL $n (linked by run-pr264-B.sh only into the corpus driver of a pre-#264 tree) sha256=$sha"; tool=$((tool+1)); continue;;
    pr264-B-06-*)
      bad=$(grep -E "^FAIL (corpus|$n)" "$OUT/pr264-B.log" | wc -l | tr -d " "); good=$(grep -cE "^PASS corpus" "$OUT/pr264-B.log")
      if [ "$bad" = 0 ] && [ "$good" -gt 0 ]; then line "PASS $n (corpus checks $good pass) sha256=$sha"; pass=$((pass+1)); else line "FAIL $n (corpus checks: $good pass, $bad fail) sha256=$sha"; fail=$((fail+1)); fi; continue;;
    pr264-B-r2-01-*)
      r="$(grep -E "^(PASS|FAIL) corpus-line-edits-identical-to-ref " "$OUT/pr264-B-r2.log" | head -1)"
      case "$r" in PASS*) line "PASS $n (${r#PASS }) sha256=$sha"; pass=$((pass+1));; *) line "FAIL $n ${r:-no result line (needs a 09177138 run-pr264-B-r2.sh bindir as 4th argument)} sha256=$sha"; fail=$((fail+1));; esac; continue;;
    pr264-B-r2-02-*)
      bad=$(grep -cE "^FAIL $n" "$OUT/pr264-B-r2.log"); good=$(grep -cE "^PASS $n:" "$OUT/pr264-B-r2.log")
      if [ "$bad" = 0 ] && [ "$good" -gt 0 ]; then line "PASS $n ($good cases pass) sha256=$sha"; pass=$((pass+1)); else line "FAIL $n ($good pass, $bad fail) sha256=$sha"; fail=$((fail+1)); grep -E "^FAIL $n" "$OUT/pr264-B-r2.log" | sed 's/^/    /' >> "$S"; fi; continue;;
    pr264-B-*)
      r="$(grep -E "^(PASS|FAIL) $n " "$OUT/pr264-B.log" | head -1)"
      case "$r" in PASS*) line "PASS $n ${r#PASS $n } sha256=$sha"; pass=$((pass+1));; *) line "FAIL $n ${r:-no result line} sha256=$sha"; fail=$((fail+1));; esac; continue;;
  esac
  rc="$(cat "$OUT/$n.rc" 2>/dev/null || echo 99)"; last="$(grep -v '^ *$' "$OUT/$n.out" 2>/dev/null | tail -1 | cut -c1-160)"
  case "$n" in
    pr263-B-I*|pr263-B-r2-I*) line "INFO $n rc=$rc (informational per reviewer B, never counted): $last sha256=$sha"; info=$((info+1));;
    *) if [ "$rc" = 0 ]; then line "PASS $n: $last sha256=$sha"; pass=$((pass+1)); else line "FAIL $n rc=$rc: $last sha256=$sha"; fail=$((fail+1)); fi;;
  esac
done
# run-pr264-B-r2.sh checks that are not a probe file of their own (shared-line products, builds).
r2p=$(grep -E "^PASS (shared|cli)" "$OUT/pr264-B-r2.log" | wc -l | tr -d " "); r2f=$(grep -E "^FAIL (shared|cli|pr264-B-r2-0[12][^:]* build)" "$OUT/pr264-B-r2.log" | wc -l | tr -d " ")
if [ "$r2f" = 0 ] && [ "$r2p" -gt 0 ]; then line "PASS run-pr264-B-r2.sh shared-line product checks ($r2p pass)"; pass=$((pass+1)); else line "FAIL run-pr264-B-r2.sh shared-line product checks ($r2p pass, $r2f fail)"; fail=$((fail+1)); grep -E "^FAIL (shared|cli)" "$OUT/pr264-B-r2.log" | sed 's/^/    /' >> "$S"; fi
# run-pr264-B.sh checks that are not a probe file of their own (CLI pins, differential).
extra_p=$(grep -E "^PASS (cli|differential)" "$OUT/pr264-B.log" | wc -l | tr -d " ")
extra_f=$(grep -E "^FAIL (cli|differential)" "$OUT/pr264-B.log" | wc -l | tr -d " ")
if [ "$extra_f" = 0 ]; then line "PASS run-pr264-B.sh CLI/differential checks ($extra_p pass)"; pass=$((pass+1)); else line "FAIL run-pr264-B.sh CLI/differential checks ($extra_p pass, $extra_f fail)"; fail=$((fail+1)); grep -E "^FAIL (cli|differential)" "$OUT/pr264-B.log" | sed 's/^/    /' >> "$S"; fi
grep -E "^(INFO|DIFF)" "$OUT/pr264-B.log" | sed 's/^/    pr264-B /' >> "$S"
cat "$S"
echo "TIER TOTAL: pass=$pass fail=$fail info=$info tool=$tool superseded=$sup probe-files=$(ls "$D"/*.swift | wc -l | tr -d " ") src=$SRC finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$S"
exit $fail
