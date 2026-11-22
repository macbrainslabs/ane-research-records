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

# Qwen2.5 fp32 reference tools (v0.5.0)

`runners/qwen25_ref_runner.swift` is an independent fp32 CPU forward pass of the original
`Qwen/Qwen2.5-1.5B-Instruct` bf16 safetensors (no Core ML, Metal or BLAS; every reduction in a
fixed order), with the same cleanroom interface as `qwen_dispatch_runner.swift`. Its dump
(`prefill.json`, `logits-prefill-all.f32`, `logits-prefill-last.f32`, `chain.json`) carries the
weights' sha256 and a self-check: the last prompt position recomputed alone on the prefill KV
cache must be bit-identical to the batched prefill.

## qwen25_ref_compare

    xcrun swiftc -O qwen25_ref_compare.swift -o qwen25_ref_compare
    ./qwen25_ref_compare <refDump> <out.json> <arm>=<armDump> ...

Compares each Core ML arm dump with the reference: prefill winner agreement per position, the
last position's ranks, top-5 overlap, max/mean |arm - ref| and cosine over non-NaN values, and
the common prefix of the greedy generated tokens.

## qwen25_ref_recompute

    xcrun swiftc -O qwen25_ref_recompute.swift -o qwen25_ref_recompute
    ./qwen25_ref_recompute <refDump> <prompt.json> <compare.json> <out-receipt.json> <arm>=<armDump> ...

Independent recompute, written from the metric definitions in its header: re-derives every
prefill field of the reference dump from the raw fp32 logits, checks the chain's token feeding
and generated tokens, and recomputes every metric in the compare output from the raw dumps.
Receipt `macbrains.research.qwen25-ref-recompute.v1`, `status` `EXACT` or `MISMATCH`, with a
`receiptSelfHash`. Exit 0 on EXACT, 1 on MISMATCH, 2 on unreadable input.

`test_qwen25_ref_negatives.sh <recompute-binary> <refDump> <prompt.json> <compare.json> <scratchDir> <arm>=<armDump> ...`
checks EXACT on unmodified copies and MISMATCH after one flipped logits byte, one edited chain
token and one edited compare metric.
