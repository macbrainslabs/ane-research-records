#!/bin/sh
# test_recompute_negatives.sh <recompute-binary> <dumpDir> <prompt.json> <scratchDir>
# Copies one dump into a new scratch dir (refuses an existing one) and checks:
#   1. the unmodified copy recomputes EXACT (exit 0),
#   2. one changed byte in logits-prefill-last.f16 gives NOT_EXACT (exit 1),
#   3. one changed step winner in chain.json gives NOT_EXACT (exit 1).
# Prints one PASS/FAIL line per check and exits non-zero on any FAIL.
set -u
[ $# -eq 4 ] || { echo "usage: $0 <recompute-binary> <dumpDir> <prompt.json> <scratchDir>" >&2; exit 2; }
BIN=$1; DUMP=$2; PROMPT=$3; S=$4
[ -e "$S" ] && { echo "scratch dir already exists: $S" >&2; exit 2; }
mkdir -p "$S/good" "$S/flip" "$S/edit" || exit 2
for d in good flip edit; do
  cp "$DUMP/prefill.json" "$DUMP/chain.json" "$DUMP/logits-prefill-last.f16" "$S/$d/" || exit 2
done
fails=0
check() { # name expected-exit actual-exit
  if [ "$2" -eq "$3" ]; then echo "PASS $1 (exit $3)"; else echo "FAIL $1 (expected exit $2, got $3)"; fails=$((fails + 1)); fi
}

"$BIN" "$S/good" "$PROMPT" "$S/good.json" >/dev/null; check unmodified-copy-exact 0 $?

L="$DUMP/logits-prefill-last.f16"; F="$S/flip/logits-prefill-last.f16"
head -c 100 "$L" > "$F"
b=$(head -c 101 "$L" | tail -c 1 | od -An -tu1 | tr -d ' ')
nb=$(( (b + 1) % 256 ))
printf "\\$(printf %03o "$nb")" >> "$F"
tail -c +102 "$L" >> "$F"
[ "$(wc -c < "$F")" -eq "$(wc -c < "$L")" ] || { echo "FAIL flipped file size differs"; exit 1; }
cmp -s "$F" "$L" && { echo "FAIL flip did not change the file"; exit 1; }
"$BIN" "$S/flip" "$PROMPT" "$S/flip.json" >/dev/null; check flipped-logits-byte-not-exact 1 $?

jq '.steps[30].winner = (.steps[30].winner + 1)' "$DUMP/chain.json" > "$S/edit/chain.json" || exit 2
"$BIN" "$S/edit" "$PROMPT" "$S/edit.json" >/dev/null; check edited-chain-winner-not-exact 1 $?

echo "TOTAL $((3 - fails)) pass, $fails fail of 3"
[ "$fails" -eq 0 ]
