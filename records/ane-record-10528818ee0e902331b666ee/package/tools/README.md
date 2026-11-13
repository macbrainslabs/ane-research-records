# Qwen dispatch analysis tools

Read-only tools for the counted `--control` runs of `runners/qwen_dispatch_runner.swift`
(profiles `profiles/qwen25-dispatch-ane-vs-gpu-20261112.json` and
`profiles/qwen25-dispatch-cpuonly-20261112.json`). Neither tool writes into a run directory.

## qwen_dispatch_recompute

    xcrun swiftc -O qwen_dispatch_recompute.swift -o qwen_dispatch_recompute
    ./qwen_dispatch_recompute <dumpDir> <prompt.json> <out-receipt.json>

Independent recompute of one arm's dump, written from the metric definitions in the file
header, not from the runner's code. It re-derives 18 fields from `logits-prefill-last.f16`
(raw fp16) and the recorded per-chunk maxima in `chain.json`, compares each one exactly with
the recorded value, and writes a `macbrains.research.qwen-dispatch-recompute.v1` receipt with
`status` `EXACT` or `NOT_EXACT` and a `receiptSelfHash` (sha256 of the sorted-key body
without that field). Exit 0 on EXACT, 1 on NOT_EXACT, 2 on unreadable input.

`test_recompute_negatives.sh <recompute-binary> <dumpDir> <prompt.json> <scratchDir>` copies a
dump, then checks that EXACT holds on the copy, that one flipped logits byte gives NOT_EXACT,
and that one edited chain winner gives NOT_EXACT.

## qwen_dispatch_compare

    xcrun swiftc -O qwen_dispatch_compare.swift -o qwen_dispatch_compare
    ./qwen_dispatch_compare <runsRoot> <out.json>

Reads every `run-<n>` under `<runsRoot>/ane-vs-gpu` and `<runsRoot>/cpuonly` (none skipped;
a run without a receipt is listed as missing), and reports per arm whether every run's dump
digest equals run-1's, the facts in run-1's dump, and the ANE-vs-GPU divergence (first
divergent generated token, prefill winner agreement, fp16 logit differences at the last
prompt position). Dump digests come from the clean-room receipts; the recompute tool is the
independent check.
