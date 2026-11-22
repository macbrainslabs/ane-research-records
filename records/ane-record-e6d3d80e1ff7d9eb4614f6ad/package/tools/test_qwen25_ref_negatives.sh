#!/bin/sh
# test_qwen25_ref_negatives.sh <recompute-binary> <refDump> <prompt.json> <compare.json> <scratchDir> <arm>=<armDump> ...
# Copies the reference dump and the compare output into a new scratch dir (refuses an existing one) and checks:
#   1. the unmodified copies recompute EXACT (exit 0),
#   2. one changed byte in logits-prefill-all.f32 gives MISMATCH (exit 1),
#   3. one changed decode-step tokenIn in chain.json gives MISMATCH (exit 1),
#   4. one changed metric string (the first "cosine") in compare.json gives MISMATCH (exit 1).
# Prints one PASS/FAIL line per check and exits non-zero on any FAIL.
set -u
[ $# -ge 6 ] || { echo "usage: $0 <recompute-binary> <refDump> <prompt.json> <compare.json> <scratchDir> <arm>=<armDump> ..." >&2; exit 2; }
BIN=$1; REF=$2; PROMPT=$3; CMP=$4; S=$5; shift 5
[ -e "$S" ] && { echo "scratch dir already exists: $S" >&2; exit 2; }
for d in good flip edit metric; do
  mkdir -p "$S/$d/ref" || exit 2
  cp "$REF/prefill.json" "$REF/chain.json" "$REF/logits-prefill-all.f32" "$REF/logits-prefill-last.f32" "$S/$d/ref/" || exit 2
  cp "$CMP" "$S/$d/compare.json" || exit 2
done
fails=0
check() { # name expected-exit actual-exit
  if [ "$2" -eq "$3" ]; then echo "PASS $1 (exit $3)"; else echo "FAIL $1 (expected exit $2, got $3)"; fails=$((fails + 1)); fi
}

"$BIN" "$S/good/ref" "$PROMPT" "$S/good/compare.json" "$S/good.json" "$@" >/dev/null; check unmodified-copy-exact 0 $?

L="$REF/logits-prefill-all.f32"; F="$S/flip/ref/logits-prefill-all.f32"
head -c 4000 "$L" > "$F"
b=$(head -c 4001 "$L" | tail -c 1 | od -An -tu1 | tr -d ' ')
nb=$(( (b + 1) % 256 ))
printf "\\$(printf %03o "$nb")" >> "$F"
tail -c +4002 "$L" >> "$F"
[ "$(wc -c < "$F")" -eq "$(wc -c < "$L")" ] || { echo "FAIL flipped file size differs"; exit 1; }
cmp -s "$F" "$L" && { echo "FAIL flip did not change the file"; exit 1; }
"$BIN" "$S/flip/ref" "$PROMPT" "$S/flip/compare.json" "$S/flip.json" "$@" >/dev/null; check flipped-logits-byte-mismatch 1 $?

# chain.json: the second "tokenIn" in the file belongs to steps[1] (the first decode step); add 1 to it.
C="$S/edit/ref/chain.json"
awk 'BEGIN{n=0} /"tokenIn" : [0-9]+/ { n++; if (n==2) { match($0, /[0-9]+/); v=substr($0,RSTART,RLENGTH)+1; $0=substr($0,1,RSTART-1) v substr($0,RSTART+RLENGTH) } } {print}' "$REF/chain.json" > "$C.tmp" && mv "$C.tmp" "$C"
cmp -s "$C" "$REF/chain.json" && { echo "FAIL chain edit did not change the file"; exit 1; }
"$BIN" "$S/edit/ref" "$PROMPT" "$S/edit/compare.json" "$S/edit.json" "$@" >/dev/null; check edited-chain-token-mismatch 1 $?

M="$S/metric/compare.json"
awk 'BEGIN{d=0} /"cosine" : "/ && d==0 { sub(/"cosine" : "[0-9]/, "\"cosine\" : \"9"); d=1 } {print}' "$CMP" > "$M.tmp" && mv "$M.tmp" "$M"
cmp -s "$M" "$CMP" && { echo "FAIL metric edit did not change the file"; exit 1; }
"$BIN" "$S/metric/ref" "$PROMPT" "$S/metric/compare.json" "$S/metric.json" "$@" >/dev/null; check edited-compare-metric-mismatch 1 $?

echo "SUMMARY pass=$((4 - fails)) fail=$fails"
[ "$fails" -eq 0 ]
