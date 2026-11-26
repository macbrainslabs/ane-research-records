# LFM3-1.7B (pruned, strict-LUT4) single-segment Core ML build: 1756/1756 ops planned on the ANE, 256–4096 positions (same chip, single device)

MacBrains Labs research record v0.6.0 (`ane-record-ec26204bae046fbf2ef0ed37`). Diagnostic tier. All-versions DOI: 10.5281/zenodo.23798036. Previous version: v0.5.0, DOI 10.5281/zenodo.24449434. The version DOI for v0.6.0 is recorded in `records/index.json` and `CITATION.cff` once Zenodo registers it. Publication is pending owner approval — nothing has been published; this preview is staged with the record.

## Claim

Scope as recorded: same-chip, single device (Apple A18 Pro (Mac17,5), macOS 27.3 (build 26C5047e)); MLComputePlan places 1756/1756 device-assigned ops on the ANE at 256, 512, 1024, 2048 and 4096 positions; ANE execution INFERRED from compute-plan placement; decode timing INDICATIVE (load gate failed); no novelty claim

- PROVEN: MLComputePlan placement (independent Swift capture, MLModel.compileModel + MLComputePlan): at every context (256, 512, 1024, 2048, 4096), 5,267 ops enumerated including constants; 1,756 ops carry a device assignment and all 1,756 are preferred-device ANE (CPU 0, GPU 0); the other 3,511 (3,368 const + 143 ios18.constexpr_lut_to_dense) report no device usage. 143 LUT4 ops (own capture; cross-confirmed by each tar's certificate.json). weight.bin identical at all five contexts: 831,054,208 bytes, sha256 5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183. 25 counted runs (5 per context, frozen profile committed before the first counted run), all exit code 0, stdout byte-identical across all 25 (sha256 f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2). Physical ANE activity: powermetrics ane_power sampler during c256 decodes read 67-1,677 mW in decode windows vs 0-2 mW immediately after.
- INDICATIVE: Decode timing, measured on a loaded machine (load gate failed: 25 polls over 25 minutes, minimum 1-minute load 5.68). Runner-reported tok/s, 16 tokens per run, n=5, CI = mean +/- 1.96*SD/sqrt(n): c256 median 39.9, CI 36.64-41.00; c512 median 38.6, CI 35.34-39.70; c1024 median 35.3, CI 33.09-36.03; c2048 median 30.6, CI 29.95-32.17; c4096 median 23.5, CI 22.69-24.27. First-token ms medians rise across contexts (525 ms at c256 to 1,674 ms at c4096, medians computed from evidence/tok-stats.json). These figures are INDICATIVE everywhere, never guarded.
- INFERRED: Per-operation physical execution on the ANE (placement and rail activity proven; no per-operation hardware trace). The token-embedding lookup runs on the host by design (the plan has a seg00_host segment; the embedding table is a separate host-side asset consumed by the runner setup).
- UNKNOWN: Output quality against the original LFM3-1.7B (checkpoint is pruned with no recovery training; lab scorecard 31-32/39 with both RoPE questions failing on every build, from lab receipts, not re-measured here). ANE-vs-CPU greedy divergence after 8 tokens on a synthetic prompt (lab, 2026-11-24 build). Behaviour on other devices or OS builds. Literal 4,096/4,096 cache fill (a 3,939-prompt-token run completed to position 3,970 of 4,096; full fill not demonstrated). Runner internals (binary-only, anec-run r5, ad-hoc signed, no source).

The full claim, methods, disclosures and limitations are in the staged record `package/ANE_Research_Record_v0.6.0.md` (SHA-256 `cc1edc7288bc821c4fecd8b10e004d979a53d0845cc39290830f571d1cd5847d`). Reviewed package SHA-256 (hand-off manifest): `ec26204bae046fbf2ef0ed374871c69a871d1f0386fa85ebe045b27562afb2d3`.

## Counted runs

One frozen profile for all contexts: profileHash `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c`, freeze commit `40b220df5db3318cc65f86a04ec516f9ea2729ed` (corrected first commit `2dc9d12146ba10607683424c4b99476229e70fd9`). Timing columns are INDICATIVE (load gate failed).

| Context | Counted | Passed | Decode median tok/s (INDICATIVE) | CI (INDICATIVE) | First-token median ms (INDICATIVE) | Profile hash | Freeze commit |
|---|---|---|---|---|---|---|---|
| 256 | 5 | 5 | 39.9 | 36.64–41.00 | 525 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 512 | 5 | 5 | 38.6 | 35.34–39.70 | 606 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 1024 | 5 | 5 | 35.3 | 33.09–36.03 | 757 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 2048 | 5 | 5 | 30.6 | 29.95–32.17 | 1094 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |
| 4096 | 5 | 5 | 23.5 | 22.69–24.27 | 1674 | `6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c` | `40b220df` |

25 counted runs, 25 passed, 0 failed; every run exit code 0 and stdout byte-identical across all 25 (sha256 `f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2`).

## Disclosures

- Load gate failed: the machine was loaded by other work throughout the session; 25 load polls over 25 minutes gave a minimum 1-minute load of 5.68, so all decode timing in this record is INDICATIVE, not guarded.
- Compile-first-run wall times: run 1 of each context took 30.7 to 39.4 s (cold Core ML compile and cache) against about 1.4 to 2.9 s for runs 2 to 5 of each context; wall times are disclosed in the ledger and are not claimed as performance.
- Both N4a attempts are disclosed: a first attempt with a 5,059-token prompt was rejected by the runner (exit code 1, prompt exceeds the 4,096 context); the completed run used a 3,939-prompt-token prompt, ended at position 3,970 of 4,096, and its reply was a truncated description of the repeated prompt text, not the Paris sentence. A literal 4,096/4,096 cache fill was NOT demonstrated.
- Ledger state: the ANE ledger is reconciled only to 2026-10-30; the 2026-11-24 qualification and rebuild live as lab receipts (neo_qualification_20261124.md sha256 ab847e88346e8835c8ceb0768ea722b752808aac800ecaa816e6c1f71d24af8c; speculative_qualification_20261124.md sha256 3ac034c02bea59f08923989f1d7f9071dd9eeca0bf11b64e20e72e18e7432e39), cross-checked 2026-11-26. The ledger entry lfm3-1.7b-ane-v0.2.0 was added 2026-11-26 (post-append ledger sha256 56f57c2af69c7c71039935913a175b1fa595551231418a3c70d796eaecb014e9).
- The runner is binary-only: anec-run r5, ad-hoc signed, no source is included in this package or in the v0.2.0 release.
- The 2026-11-24 qualified build is NOT byte-identical to v0.2.0 (1,769 ops against 1,756 here; newer compiler; the 2026-11-24 compiled files were never hashed). Its figures (33.6 tok/s median at 256, CI 32.8-34.2, 1.48 W ANE) belong to that earlier build and are not figures of this build.
- Profile correction before any counted run: the first freeze commit 2dc9d12146ba10607683424c4b99476229e70fd9 listed the SHA256SUMS helper file as an eighth asset; the corrected freeze commit 40b220df5db3318cc65f86a04ec516f9ea2729ed lists exactly the 7 release assets and is the freeze of record.
- ComputePlan capture attempts: the first Swift build failed (MLModelStructure has no member functions in this SDK) and the first capture attempt failed on the uncompiled .mlpackage; the working capture compiles via MLModel.compileModel first. All attempts are retained in evidence/RUNLOG.md.
- Output quality was not re-measured for this record: the pruned checkpoint had no recovery training, and the lab scorecard figure (31-32/39, both RoPE questions failing on every build) comes from lab receipts.
- The first powermetrics attempt (evidence/n4/n4b-summary.json) sampled all-zero ANE power and is kept; the second attempt (evidence/n4/n4b2-summary.json) captured the 67-1,677 mW decode-window activity reported as PROVEN.
- This record measures a release published by MacBrains Labs itself (naytewilson/lfm3-1.7b-ane v0.2.0). 'Independent capture' in this record means the compute-plan placement was re-captured with a separately written tool instead of read from the build's own plan files; it does not mean independent of the lab. The measurements have not been independently replicated by another party.

## Files

- `package/`: the staged package, byte for byte: `FILES.sha256` (SHA-256 `9dc586ad198455e148f17758f7577c35f59d32a616faf4d9292c7d09bb3a710d`) and the 110 files it lists (111 files in total including `FILES.sha256` itself).
- Release assets (staged, not published): this preview, the staged record, and the package tar `package-v060-20261126.tar` (hashes reported with the build).

Model weights are not included; the build under test is pinned by release tag and asset sha256 in the staged record. This is a staged record, not a peer-reviewed result.
