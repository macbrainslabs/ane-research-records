# MacBrains Labs — ANE Research Records, 2026

**Versioned public research summaries and machine-readable measurements**, bound to the source revision of the independent MacBrains Labs website.

**Scope:** Apple Neural Engine (ANE), Core ML graph placement, numerical parity, Qwen2.5-1.5B LUT4 inference, and batch decode. This is a curated release of **already-public, source-attributed reported observations**. It is **not** raw measurement output, an independently repeated benchmark, a full model or fixture package, a peer-reviewed paper, or an Apple-affiliated result.

Published research: <https://macbrainslabs.org/research/>

Source methods: <https://macbrainslabs.org/methods/>

Correspondence: <research@macbrainslabs.org>

## Contents

| Data file | Scope | Key boundaries |
| --- | --- | --- |
| [qwen-placement.csv](data/qwen-placement.csv) | Compiled 28-layer Qwen LUT4 `infer` graph | Core ML MLComputePlan assignment only: 2,090 ANE / 79 CPU; not direct silicon tracing |
| [qwen-state-primitives.csv](data/qwen-state-primitives.csv) | Four graph state primitive families | All listed operations were ANE-assigned in the named artifact; **not** all graph operations |
| [lfm-s2-parity.csv](data/lfm-s2-parity.csv) | Two sealed LFM S2 production outputs | ANE output vs pinned FP16 fixture; production graph had 743/743 ANE-assigned compute ops |
| [lfm-s2-diagnostic.csv](data/lfm-s2-diagnostic.csv) | **Two illustrative** failing diagnostic outputs | A separately compiled 46-output artifact had 34/46 ANE gate passes; this file is **not** a full 46-output dataset |
| [qwen-batch-throughput.csv](data/qwen-batch-throughput.csv) | Real batch B=1,2,4,8 | Aggregate tokens/second on the specified A18 Pro setup; no per-stream or universal ceiling claim |

## Quantitative interpretation

1. Placement of a Core ML operation on ANE is **compiler-reported**, not a privileged hardware trace.
2. The LFM **production** graph and the 46-output **debug** graph are different compiled interfaces. The 12 failures in the debug ANE gate cannot be imputed to the production graph.
3. Batch throughput reports `tokens actually executed / measured elapsed time` using real input batch shapes; multiplying B=1 throughput by a parameter is invalid.
4. The supposed 57.3 tokens/second *bandwidth ceiling* was falsified. Neither that value nor an extrapolated compiler DRAM planning figure is a measured hardware limit.
5. The original underlying source code, fixture binaries, compiled model, weights, device logs and full receipts remain private. This release captures **derived public summaries only** and is not a complete reproducibility bundle.

## Source provenance

The release's `manifest.json` pins the public site commit and the SHA-256 of each source document. View the corresponding source at:

- <https://github.com/naytewilson/macbrainslabs-site/tree/27ac1941b26e865b1894a715946e2db7bcf7ed8b>
- <https://macbrainslabs.org/notes/qwen-lut4/>
- <https://macbrainslabs.org/notes/lfm-parity/>
- <https://macbrainslabs.org/notes/decode-regimes/>

Run offline self-consistency checks with:

```sh
node scripts/verify.mjs
```

Run an **independent upstream SHA-256 verification** using raw pinned GitHub source files (read-only network):

```sh
node scripts/verify.mjs --upstream
```

These tests verify **the transcription and declared invariants**, not the existence or correctness of the private underlying measurements.

## How to cite

See [CITATION.cff](CITATION.cff) for recommended attribution. The published release tag identifies this version. A **Zenodo DOI has not yet been assigned**; no DOI is claimed until a deposit is confirmed by Zenodo. Update the metadata only after the publisher issues a legitimate identifier.

## Legal and scope

Original text and measurement tables in this repository: [Creative Commons Attribution 4.0 International](LICENSE). The verification program in `scripts/` is provided under [MIT](LICENSE-MIT). Third-party software, models, documentation, trademarks and private ANE experiment artifacts are not relicensed by these statements.

This repository belongs to an **independent research identity**, not a formally incorporated business or university. Not affiliated with Apple.
