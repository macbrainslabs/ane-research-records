# LFM3-1.7B layer-14 diagnostic under Core ML cpuAndNeuralEngine (same chip, single device)

MacBrains Labs research record v0.2.0 (`ane-record-c188def1e88a0d94018dfe99`). Diagnostic tier. All-versions DOI: 10.5281/zenodo.23798036. The version DOI is recorded in `records/index.json` and `CITATION.cff` on the main branch once Zenodo registers it.

## Claim (verbatim from the reviewed bundle)

On a single device whose OS/Core ML reported identity is chip Apple A18 Pro, hwModel Mac17,5, macOS 27.2 (build 26B123), CoreML 3600.25.2, LFM3-1.7B layer-14 inference under computeUnits=cpuAndNeuralEngine is output-reproducible under source rebuild: THREE counted, git-frozen, source-rebuilt clean-room runs (one profile-scoped run ledger keyed to profileHash 2f0cc0c9, totalRuns=3, countedRuns=3, preFreezeRunsNotCounted=0; this ledger is scoped to the current frozen tool commit 926a78ad, and the same profileHash has 8 logged executions device-wide: 5 counted/frozen across tool commits 833b3fc8/5f827c84/926a78ad and 3 pre-freeze, one counted run's on-disk dump deleted and disclosed with recovered records, all enumerated in allDeviceExecutionsOfProfile and execution-log.jsonl) each produced output byte-identical (24/24 tensors, 0 differing) to the archived device-run baseline index. The replication runner was built from git-committed source at commit c45e8c61 (binary SHA-256 746e1200, which differs from the baseline binary 48d2d0aa); the clean-room tool and profile were git-frozen at 926a78ad / 9d6aa2a2 before each counted run. This is source-level rebuild output reproducibility, not binary identity and not cross-device scientific replication. A separately frozen, counted CPU-vs-ANE control (control profile 33e0e5a9, totalRuns=2, countedRuns=2, under the same frozen tool 926a78ad) ran both arms with the SAME source-rebuilt binary (SHA-256 e0ef750e, built from committed probe source at commit 055b54f7), differing only in the LFM3_PROBE_CPU_LAYERS environment variable (unset for the ANE arm, =14 for the layer-14 CPU arm): a like-for-like, same-binary comparison. An independently written recomputation (own IEEE-half decode) on the two frozen control dumps - cross-checked byte-identical (24/24 files) to the archived Oct-31 probe dumps - gives ANE-enabled output abs-L2 to the FP32 teacher of 0.0062 to 0.0097 at positions 161/203/217 versus the layer-14-only CPU arm's 0.036 to 0.054; i.e. the CPU-only abs-L2 is 3.8x to 8.7x the ANE-enabled abs-L2. The FP32 teacher is computed by the same runner from the fixture, and the independent recomputation reads the same frozen dumps and shares metric definitions, so it is documentary cross-checking, not an independent measurement. Core ML's compute plan assigns all 447 layer-14 ops to the ANE (0 CPU/GPU/unassigned); ANE execution is INFERRED from this placement plus the same-binary CPU control, not from a per-op hardware execution trace. Same-chip, single-device, layer-14, three-position diagnostic only; no novelty claim.

## Scope

same-chip, byte-reproducible on Apple A18 Pro (Mac17,5), macOS 27.2 (build 26B123), CoreML 3600.25.2; ANE execution INFERRED from Core ML compute-plan placement; no novelty claim

Cross-device replication: none. Same-chip reruns are repeatability only, not cross-device replication. Novelty: UNCLAIMED.

## Limits (verbatim)

- Single device (Mac17,5, macOS 27.2 build 26B123); three source-rebuilt runs against the archived same-chip baseline, which is not multi-device reproducibility.
- One layer (14) of LFM3-1.7B at three token positions (161, 203, 217) only; do not generalize.
- Only tier A (ANE-enabled) and the layer-14-only CPU control are device-measured; emulated tiers N/G/E, cosine-between-error-vectors and projected_share are not covered.
- Compiler placement is not direct hardware execution: all 447 layer-14 ops are assigned to the ANE in the plan, but no per-op hardware trace exists, so ANE execution is INFERRED.
- The CPU control is layer-14-only (layer 14 forced to CPU via LFM3_PROBE_CPU_LAYERS=14, rest on ANE); the whole-chain CPU-only run produced no finite layer-14 dump, so the ANE-vs-CPU comparison is layer-local.
- The independent recomputation shares metric definitions and reads the same raw dumps; it verifies the archived error metrics, not an independent measurement, and is not cross-device replication.
- Replication runner binary differs from the baseline binary (different SHA-256): source-level rebuild output reproducibility, not binary identity.
- The replication runner (746e1200 @ c45e8c61) and the CPU-vs-ANE control binary (e0ef750e @ 055b54f7) are distinct build artifacts; the control's same-binary claim is internal to its two arms only.
- Diagnostic only: no responsible ANE op identified, no release gate changed; prior-art coverage of the specific directional claim is INCONCLUSIVE and novelty is explicitly UNCLAIMED.
- Tensor-file unit: tensorFilesPerPosition=24 is the per-position tensor count used in the byte-identity comparisons; each control-arm dump directory holds 25 files (the 24 compared per-position tensors plus one additional non-compared file), so the 24/24 control cross-check covers the 24 tensor files only.

## Every logged execution of setup profile 2f0cc0c9

Profile hash `2f0cc0c9371123c7ea4055e755ff9d0ef714ed07e5092ca477581bad14be4042`. 8 executions are logged device-wide: 5 counted and frozen, 3 pre-freeze and not counted. One counted run's on-disk output was deleted; its record was recovered and the deletion is disclosed in `deletion-disclosure.md`.

| Run | Status | Counted | Frozen | Tool commit | Started (UTC) | On disk |
|---|---|---|---|---|---|---|
| pf-baselinebin | pre-freeze | false | false | none | 2026-11-02T19:52:00Z | present |
| pf-freshcompile | pre-freeze | false | false | none | 2026-11-02T19:57:00Z | present |
| pf-toolrun | pre-freeze | false | false | none | 2026-11-02T20:07:00Z | present |
| counted-833b3fc8-r4 | pass | true | true | 833b3fc8 | 2026-11-02T20:41:39Z | deleted |
| counted-5f827c84-r1 | pass | true | true | 5f827c84 | 2026-11-02T22:14:04Z | present |
| counted-926a78ad-r1 | pass | true | true | 926a78ad | 2026-11-03T00:04:18Z | present |
| counted-926a78ad-r2 | pass | true | true | 926a78ad | 2026-11-03T00:06:17Z | present |
| counted-926a78ad-r3 | pass | true | true | 926a78ad | 2026-11-03T00:08:15Z | present |

Correction: the log records `pf-toolrun` as starting at 2026-11-02T20:07:00Z, which is its directory modification time. That run's own runs-log records 2026-11-02T20:03:04Z. The device log is append-only: a correction line recording this was appended after review, and this record republishes the log exactly as reviewed.

## Review

- Pipeline evidence reviewer: opencode-go/deepseek-v4.1-flash, INCLUDE, score 0.82, session `ses_e60904ac1ffeacsEnVw4ZofYgS`, receipt digest `a242e7104c211bde9238a8a53c3ac9b44b9c6ac877a4d075037292f0077485a4`.
- Pipeline skeptical reviewer: opencode-go/glm-5.3, INCLUDE, score 0.8, session `ses_e60904ac1ffePgIg7R2G9ym86a`, receipt digest `b2d85d88f4d7ad8714a0c2d3cb37c01cbc034ccc001a57b26ec57cb9cc8ca907`.
- Final reviewer macbrains-labs-reviewer: INCLUDE for reviewed package `c188def1e88a0d94018dfe99f63aed795f58848871841d1c089d079a28aebff1`.
- Policy digest `3c3b6ba4f8ee69849f8c24672d26bc51f1ca36b429203f996849994b8d7ea3fa` at commit `4d23b937e55fc25a12428eb6ef965ec8666c2cc1`.

## Files

- `bundle.json`: the reviewed evidence bundle, byte for byte (SHA-256 `0d2b3f787cf0f98e6d12ed9cebd614d028b0f39e9e210e55fb93cc14ca6f49b3`).
- `execution-log.jsonl`: the append-only device-wide execution log for the profile, byte for byte (SHA-256 `879a7172d2531685cb1aef343565a7a4adf7dcee3c5bd5b2bbc53a5c5e11441f`).
- `deletion-disclosure.md`: the forensic record of the deleted run, byte for byte (SHA-256 `f05c7c0649f440a51ad4d539ccfd81e7632ec494af85e9131e65415521cd2958`).
- `attestation.json`: hashes, review attestations and the run accounting above in machine-readable form.

Raw tensor dumps, model weights and compiled models are not included. This is a reviewed record, not a peer-reviewed result.
