# LFM3-1.7B (pruned, strict-LUT4) single-segment Core ML build: 1756/1756 ops planned on the ANE, 256–4096 positions (same chip, single device)

**MacBrains Labs ANE Research Records | candidate v0.6.0 | STAGED RECORD, READY FOR REVIEW, NOT PUBLISHED**

**Observed 2026-11-26 | Disposition: STAGED / PENDING REVIEW | Scientific tier: diagnostic | Novelty: UNCLAIMED | Replication: same-chip**

Publication is NOT authorized. This staged record is pending a reviewer pass and an owner decision; no tag, version DOI, or release exists for v0.6.0. Nothing in this package has been published.

Claim scope: same-chip, single device (Apple A18 Pro (Mac17,5), macOS 27.3 (build 26C5047e)); MLComputePlan places 1756/1756 device-assigned ops on the ANE at 256, 512, 1024, 2048 and 4096 positions; ANE execution INFERRED from compute-plan placement; decode timing INDICATIVE (load gate failed); no novelty claim

## Claims

- **PROVEN:** MLComputePlan placement (independent Swift capture, MLModel.compileModel + MLComputePlan): at every context (256, 512, 1024, 2048, 4096), 5,267 ops enumerated including constants; 1,756 ops carry a device assignment and all 1,756 are preferred-device ANE (CPU 0, GPU 0); the other 3,511 (3,368 const + 143 ios18.constexpr_lut_to_dense) report no device usage. 143 LUT4 ops (own capture; cross-confirmed by each tar's certificate.json). weight.bin identical at all five contexts: 831,054,208 bytes, sha256 5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183. 25 counted runs (5 per context, frozen profile committed before the first counted run), all exit code 0, stdout byte-identical across all 25 (sha256 f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2). Physical ANE activity: powermetrics ane_power sampler during c256 decodes read 67-1,677 mW in decode windows vs 0-2 mW immediately after.
- **INDICATIVE:** Decode timing, measured on a loaded machine (load gate failed: 25 polls over 25 minutes, minimum 1-minute load 5.68). Runner-reported tok/s, 16 tokens per run, n=5, CI = mean +/- 1.96*SD/sqrt(n): c256 median 39.9, CI 36.64-41.00; c512 median 38.6, CI 35.34-39.70; c1024 median 35.3, CI 33.09-36.03; c2048 median 30.6, CI 29.95-32.17; c4096 median 23.5, CI 22.69-24.27. First-token ms medians rise across contexts (525 ms at c256 to 1,674 ms at c4096, medians computed from evidence/tok-stats.json). These figures are INDICATIVE everywhere, never guarded.
- **INFERRED:** Per-operation physical execution on the ANE (placement and rail activity proven; no per-operation hardware trace). The token-embedding lookup runs on the host by design (the plan has a seg00_host segment; the embedding table is a separate host-side asset consumed by the runner setup).
- **UNKNOWN:** Output quality against the original LFM3-1.7B (checkpoint is pruned with no recovery training; lab scorecard 31-32/39 with both RoPE questions failing on every build, from lab receipts, not re-measured here). ANE-vs-CPU greedy divergence after 8 tokens on a synthetic prompt (lab, 2026-11-24 build). Behaviour on other devices or OS builds. Literal 4,096/4,096 cache fill (a 3,939-prompt-token run completed to position 3,970 of 4,096; full fill not demonstrated). Runner internals (binary-only, anec-run r5, ad-hoc signed, no source).

## Subject

- **Build under test:** strict-LUT4 one-segment build of a width-pruned LFM3-1.7B (feed-forward width 7680 to 7168; 1.65B parameters), released as `naytewilson/lfm3-1.7b-ane` **v0.2.0** (2026-11-26T01:59:51Z): https://github.com/naytewilson/lfm3-1.7b-ane/releases/tag/v0.2.0
- **Palette profile:** `cand1_g4conv_w2_g8`. Every large weight is a 4-bit lookup table (143 LUT4 operations).
- **Pruned checkpoint:** sha256 `92bc789529bbaf1584efd0e8c10a5d5550648531b06391c90e68f71684e9e2cb`, pruned from `LiquidAI/LFM3-1.7B` (Hugging Face, revision 40ebe0aa), with no recovery training.
- **Device:** one Mac, Apple A18 Pro (Mac17,5), macOS 27.3 (build 26C5047e), re-proven 2026-11-26.
- **Prompt (counted runs):** "What is the capital of France?" (18 prompt tokens as tokenized by the runner; chat mode, units `ane`, up to 32 new tokens; 16 new tokens per counted run as reported).
- **Runner:** `anec-run` r5 from the release runner tar (binary-only, ad-hoc signed, no source).

### Release assets (all sha256-verified 7/7 against the release SHA256SUMS)

| Asset | SHA-256 |
|---|---|
| `lfm3-1.7b-pruned7168-strict-lut4-c256.tar` | `a9b3f866ee589bdeb02e1b25ea283dfabfcad93a01907e912caf9e3949cf366a` |
| `lfm3-1.7b-pruned7168-strict-lut4-c512.tar` | `e66da789940deb8933bfc90b7407377d9c18db30244e89aa8b763a920d22fbde` |
| `lfm3-1.7b-pruned7168-strict-lut4-c1024.tar` | `91d4bcb0a2234dd4a87880d730186b047b730da31973e5ec3bf451f220ef07ed` |
| `lfm3-1.7b-pruned7168-strict-lut4-c2048.tar` | `9f869ebba7961e056813e54eeb80ef7af5ed6ce39cd93f250a6488615e235c2f` |
| `lfm3-1.7b-pruned7168-strict-lut4-c4096.tar` | `b151274754fed55a163a3ca7151e9a2b07b6811297ab56bcf37057417b4f0505` |
| `lfm3-ane-runner-r5-macos-arm64.tar` | `0279b0ae76e87992fb66dcda6ac2e4c7063e6d8f572b99717aceb2e04d536da6` |
| `embed_tokens.bf16.bin` | `5f1df3bbc564554f48a7fb542f96e745c92e2315c92279944d9e65d234bec4bc` |

## Results

1. **Placement (PROVEN).** At every context (256, 512, 1024, 2048, 4096) the independent MLComputePlan capture enumerates 5,267 ops including constants; 1,756 ops carry a device assignment and all 1,756 are preferred-device ANE (CPU 0, GPU 0); the other 3,511 report no device usage (3,368 `const` + 143 `ios18.constexpr_lut_to_dense`). So 1756/1756 device-assigned ops are planned on the ANE at each of 256/512/1024/2048/4096. Per-operation physical execution is INFERRED from this placement (see Claims).
2. **LUT4 (PROVEN).** 143 LUT4 ops in the capture, cross-confirmed by the `certificate.json` shipped in each context tar (143 tensors palettized, profile `cand1_g4conv_w2_g8`).
3. **Weights (PROVEN).** `weight.bin` is identical at all five contexts: 831,054,208 bytes, sha256 `5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183` (`evidence/weights.json`).
4. **Counted runs (PROVEN).** 25 counted runs, 5 per context, under the frozen profile committed before the first counted run; all exit code 0; stdout byte-identical across all 25: "The capital of France is Paris, which has been the capital for centuries." (stdout sha256 `f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2`).
5. **Physical ANE activity (PROVEN).** The powermetrics `ane_power` sampler during c256 decodes read 67–1,677 mW in decode windows against 0–2 mW immediately after: ANE hardware was demonstrably active during decode (`evidence/n4/`).
6. **Decode timing (INDICATIVE).** The load gate failed (Disclosure 1), so the medians and CIs in the counted-runs table are INDICATIVE only, never guarded figures.
7. **Long prompt (N4a).** A 3,939-prompt-token run on c4096 completed in 196.8 s (prompt read one token at a time; first token 158,959 ms (INDICATIVE, same session)), ending at position 3,970 of 4,096, with 32 new tokens at 26.3 tok/s (INDICATIVE — same unguarded session as the counted runs); its reply was a truncated description of the repeated prompt text, not the Paris sentence. A first attempt with a 5,059-token prompt was rejected by the runner (exit code 1) and is disclosed (Disclosure 3). A literal 4,096/4,096 fill was NOT demonstrated, so cache-full stays UNKNOWN, with the 3,970/4,096 near-fill stated exactly.

## Counted runs

One frozen profile for all contexts: profileHash `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c`, freeze commit `40b220df5db3318cc65f86a04ec516f9ea2729ed` (corrected first commit `2dc9d12146ba10607683424c4b99476229e70fd9`, see Disclosure 7). Timing columns are INDICATIVE (load gate failed).

| Context | Counted | Passed | Decode median tok/s (INDICATIVE) | CI (INDICATIVE) | First-token median ms (INDICATIVE) | Profile hash | Freeze commit |
|---|---|---|---|---|---|---|---|
| 256 | 5 | 5 | 39.9 | 36.64–41.00 | 525 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 512 | 5 | 5 | 38.6 | 35.34–39.70 | 606 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 1024 | 5 | 5 | 35.3 | 33.09–36.03 | 757 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 2048 | 5 | 5 | 30.6 | 29.95–32.17 | 1094 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 4096 | 5 | 5 | 23.5 | 22.69–24.27 | 1674 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |

Every counted run: exit code 0, stdout sha256 `f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2`, byte-identical to every other counted run. Per-run values (tok/s, first-token ms, load at start, wall seconds) are in `execution-log/c<context>.jsonl` and `ledger/cleanroom-ledger-c<context>.json`; raw outputs are in `runs/c<context>/`.

## Methods

- **Assets** were downloaded from the v0.2.0 release and verified 7/7 against its SHA256SUMS before use (`evidence/asset-hashes.json`).
- **Placement capture** used an independent Swift tool (`tools/computeplan.swift`, binary sha256 in `tools/computeplan.bin.sha256`): `MLModel.compileModel` on each shipped `.mlpackage`, then `MLComputePlan` enumeration of all operations including constants, recording `deviceUsage(for:)` per op. Raw output: `evidence/computeplan/c<context>.txt`. The build's own plan/certificate/semantic files are in `evidence/plan/c<context>/`.
- **Counted runs** ran the release runner (`anec-run`, units `ane`, chat mode) once per run as a fresh process, 5 runs per context, after the profile freeze. The load gate polled machine load for 25 minutes before the counted runs; it never passed, and the runs proceeded labelled INDICATIVE.
- **ANE power** was sampled with powermetrics (`ane_power`) during and immediately after c256 decodes (`evidence/n4/powermetrics*.txt`, summaries in `evidence/n4/n4b*-summary.json`).
- **Token statistics** (`evidence/tok-stats.json`) are parsed from the runner's own per-run reporting (16 new tokens per run); CIs are mean ± 1.96·SD/√n with n=5.
- The full session log, including failed attempts, is `evidence/RUNLOG.md`.

## Disclosures

1. Load gate failed: the machine was loaded by other work throughout the session; 25 load polls over 25 minutes gave a minimum 1-minute load of 5.68, so all decode timing in this record is INDICATIVE, not guarded.
2. Compile-first-run wall times: run 1 of each context took 30.7 to 39.4 s (cold Core ML compile and cache) against about 1.4 to 2.9 s for runs 2 to 5 of each context; wall times are disclosed in the ledger and are not claimed as performance.
3. Both N4a attempts are disclosed: a first attempt with a 5,059-token prompt was rejected by the runner (exit code 1, prompt exceeds the 4,096 context); the completed run used a 3,939-prompt-token prompt, ended at position 3,970 of 4,096, and its reply was a truncated description of the repeated prompt text, not the Paris sentence. A literal 4,096/4,096 cache fill was NOT demonstrated.
4. Ledger state: the ANE ledger is reconciled only to 2026-10-30; the 2026-11-24 qualification and rebuild live as lab receipts (neo_qualification_20261124.md sha256 ab847e88346e8835c8ceb0768ea722b752808aac800ecaa816e6c1f71d24af8c; speculative_qualification_20261124.md sha256 3ac034c02bea59f08923989f1d7f9071dd9eeca0bf11b64e20e72e18e7432e39), cross-checked 2026-11-26. The ledger entry lfm3-1.7b-ane-v0.2.0 was added 2026-11-26 (post-append ledger sha256 56f57c2af69c7c71039935913a175b1fa595551231418a3c70d796eaecb014e9).
5. The runner is binary-only: anec-run r5, ad-hoc signed, no source is included in this package or in the v0.2.0 release.
6. The 2026-11-24 qualified build is NOT byte-identical to v0.2.0 (1,769 ops against 1,756 here; newer compiler; the 2026-11-24 compiled files were never hashed). Its figures (33.6 tok/s median at 256, CI 32.8-34.2, 1.48 W ANE) belong to that earlier build and are not figures of this build.
7. Profile correction before any counted run: the first freeze commit 2dc9d12146ba10607683424c4b99476229e70fd9 listed the SHA256SUMS helper file as an eighth asset; the corrected freeze commit 40b220df5db3318cc65f86a04ec516f9ea2729ed lists exactly the 7 release assets and is the freeze of record.
8. ComputePlan capture attempts: the first Swift build failed (MLModelStructure has no member functions in this SDK) and the first capture attempt failed on the uncompiled .mlpackage; the working capture compiles via MLModel.compileModel first. All attempts are retained in evidence/RUNLOG.md.
9. Output quality was not re-measured for this record: the pruned checkpoint had no recovery training, and the lab scorecard figure (31-32/39, both RoPE questions failing on every build) comes from lab receipts.
10. The first powermetrics attempt (evidence/n4/n4b-summary.json) sampled all-zero ANE power and is kept; the second attempt (evidence/n4/n4b2-summary.json) captured the 67-1,677 mW decode-window activity reported as PROVEN.
11. This record measures a release published by MacBrains Labs itself (naytewilson/lfm3-1.7b-ane v0.2.0). 'Independent capture' in this record means the compute-plan placement was re-captured with a separately written tool instead of read from the build's own plan files; it does not mean independent of the lab. The measurements have not been independently replicated by another party.

## Limitations

- One device, one chip, one OS build, one prompt for the counted runs. Same-chip only; not cross-device replication.
- Decode timing is INDICATIVE: the machine was loaded by other work and the load gate never passed.
- Per-operation ANE execution is INFERRED from compute-plan placement plus rail activity; there is no per-operation hardware trace.
- Output quality against the original LFM3-1.7B is UNKNOWN from this record (pruned checkpoint, no recovery training; lab scorecard 31–32/39 from lab receipts only).
- Cache-full behaviour is UNKNOWN: the near-fill reached position 3,970 of 4,096, not 4,096/4,096.
- The runner is binary-only; its internals are UNKNOWN from this record.

## Relation to the 2026-11-24 qualification

The 2026-11-24 lab qualification (receipt `neo_qualification_20261124.md`, sha256 `ab847e88346e8835c8ceb0768ea722b752808aac800ecaa816e6c1f71d24af8c`; rebuild receipt `speculative_qualification_20261124.md`, sha256 `3ac034c02bea59f08923989f1d7f9071dd9eeca0bf11b64e20e72e18e7432e39`) qualified an earlier build of the same model line: 1,769 ops, 33.6 tok/s median at 256 (CI 32.8–34.2), 1.48 W ANE. That build is NOT byte-identical to v0.2.0 (newer compiler; 1,756 ops here; the 2026-11-24 compiled files were never hashed), so its figures belong to that earlier build and must not be presented as this build's. This record re-proves placement, weights, counted-run identity, and ANE rail activity for the v0.2.0 build itself, and reports this build's timing only as INDICATIVE. The ANE ledger entry `lfm3-1.7b-ane-v0.2.0` was added 2026-11-26 to the lab ledger (post-append sha256 `56f57c2af69c7c71039935913a175b1fa595551231418a3c70d796eaecb014e9`); the ledger itself is reconciled only to 2026-10-30 (Disclosure 4).

## Notes

1. An earlier staged assembly of this record (reviewed-package SHA-256 849baed72284d2ffbf18524d741f9648d78f0a0ec62abc16eee88d2274dd4716) was superseded before review when the five per-context execution logs were merged into one file; a second staged assembly (72aad304607a235d91323ccae463ddb98fdfe0b2ca6f12aacb05d1a18e5cec0c) was superseded after a skeptical review round corrected claim wording and added disclosures. Nothing was published under any superseded identity.

## Files

- `ANE_Research_Record_v0.6.0.md`: this record.
- `profiles/`: the frozen profile and its freeze receipt.
- `tools/`: the computeplan capture source, its README, and the binary hash.
- `runs/`: the 25 counted run outputs (`.out` and `.stdout` per run) and per-context `summary.json`.
- `execution-log/`: one JSONL per context, one `run_completed` object per counted run.
- `evidence/`: plan/certificate/semantic files per context, computeplan captures, weights and asset hashes, token statistics, N4 summaries and powermetrics captures, and the full RUNLOG.
- `ledger/`: per-context ledger receipts for the 25 counted runs.
- `FILES.sha256`: sha256 of every other file in this package.

Model weights are not included; the build under test is pinned by the release tag and the asset hashes above. This is a staged record, not a peer-reviewed result, and publication is pending review and an owner decision.
