# MacBrains Labs — ANE Research Records, 2026

[![Zenodo v0.1.0 dataset DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23798037.svg)](https://doi.org/10.5281/zenodo.23798037)

[All-versions DOI](https://doi.org/10.5281/zenodo.23798036) · This is a citable archive of public summaries, not peer-reviewed validation.

**Versioned public research summaries and machine-readable measurements**, bound to the source revision of the independent MacBrains Labs website.

**Scope:** Apple Neural Engine (ANE), Core ML graph placement, numerical parity, Qwen2.5-1.5B LUT4 inference, and batch decode. This is a curated release of **already-public, source-attributed reported observations**. It is **not** raw measurement output, an independently repeated benchmark, a full model or fixture package, a peer-reviewed paper, or an Apple-affiliated result.

Published research: <https://macbrainslabs.org/research/>

Source methods: <https://macbrainslabs.org/methods/>

Correspondence: <research@macbrainslabs.org>

Researcher attribution: **[Nayte Wilson](https://orcid.org/0009-0003-4026-8212)**, ORCID iD `0009-0003-4026-8212`. The ORCID identifier connects the researcher to the existing DOI without changing the original v0.1.0 archive.

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

## Public release integrity audit

A separate check downloads the actual GitHub and Zenodo archives for v0.1.0, verifies the publisher hashes and DOI registration, and compares **every archived file** to the original tagged Git source. The deterministic corruption tests run in CI; the network audit runs locally or through the workflow's manual dispatch.

```sh
node --test tests/publication-audit.test.mjs
node scripts/audit-publication.mjs --json
```

See [Public evidence audit and limitations](docs/PUBLIC_EVIDENCE_AUDIT.md) for precise proof boundaries and a machine-readable verification receipt. These checks **do not** validate private ANE experiments, physical silicon traces, full-model correctness, or independent replication.

## How to cite

See [CITATION.cff](CITATION.cff) for recommended attribution. The **Zenodo DOI for v0.1.0** is [10.5281/zenodo.23798037](https://doi.org/10.5281/zenodo.23798037); the [all-versions DOI](https://doi.org/10.5281/zenodo.23798036) resolves to the release family. The version-specific [GitHub release](https://github.com/macbrainslabs/ane-research-records/releases/tag/v0.1.0) is pinned to commit `257e54868c26bbb407199fe042f55c82b14b9cc5`. Zenodo and DataCite independently confirmed the record on 2026-10-30. The immutable tag/archive retain the pre-assignment metadata; this default branch records the subsequently verified DOI. Only public curated summaries, not private experimental evidence, were archived.

## Legal and scope

Original text and measurement tables in this repository: [Creative Commons Attribution 4.0 International](LICENSE). The verification program in `scripts/` is provided under [MIT](LICENSE-MIT). Third-party software, models, documentation, trademarks and private ANE experiment artifacts are not relicensed by these statements.

This repository belongs to an **independent research identity**, not a formally incorporated business or university. Not affiliated with Apple.
