# Published Qwen2.5-1.5B Core ML package against an fp32 reference of its original weights: the GPU output follows the reference for 7 tokens, the ANE output differs from the first token, and cpuOnly returns NaN

MacBrains Labs research record v0.5.0 (`ane-record-e6d3d80e1ff7d9eb4614f6ad`). Diagnostic tier. All-versions DOI: 10.5281/zenodo.23798036. Previous version: v0.4.0, DOI 10.5281/zenodo.24183178. The version DOI is recorded in `records/index.json` and `CITATION.cff` on the main branch once Zenodo registers it.

## Claim

Scope as recorded: same-chip, byte-reproducible on Apple A18 Pro (Mac17,5), macOS 27.3 (build 26C5047e), CoreML 3610.2.3; ANE execution INFERRED from Core ML compute-plan placement; no novelty claim.

- PROVEN: the fp32 reference output and self-check; each Core ML arm's distance from it (first divergence, ranks, cosine, max/mean difference, prefill winner agreement); cpuOnly NaN; every profile 5/5 byte-identical same-chip; recompute EXACT 5/5; Core ML dumps byte-identical to v0.4.0 on the earlier OS build.
- INFERRED: ANE execution (compute-plan placement).
- SUSPECTED: fp16 range or accumulation differences on the Neural Engine; LUT4 dequantisation per backend.
- UNKNOWN: cause; agreement of the reference with PyTorch or transformers; other devices, OS versions, prompts.

Result, as the reviewed record states it: against the fp32 reference, the cpuAndGPU output equals the reference for its first 7 generated tokens and first differs at generated index 7; the cpuAndNeuralEngine output differs from the first generated token; under cpuOnly all last-position prefill logits are NaN and no prompt position has a finite winner. Each Core ML arm's three dump files are byte-identical to v0.4.0's counted run-1 dumps made on macOS build 26C5035r. Cross-device replication: none. Same-chip reruns are repeatability only, not cross-device replication. Novelty: UNCLAIMED.

The full claim, every attempt in order, and the limitations are in the reviewed record `package/ANE_Research_Record_v0.5.0.md` (SHA-256 `0e4d88d1039eb946913ef1f36bd75144eb59f4f99bbeccfeecc5c385f550b02d`).

## Counted runs

| Profile | Compute units | Setup profile | Profile commit | Tool commit | Started | Completed | Passed |
|---|---|---|---|---|---|---|---|
| dispatch-ane | cpuAndNeuralEngine | `be83f5a03df95fd85761dd8e076a756aef6d50ea9297351042b1072e09a5f5af` | `728f4c22` | `d58fb354` | 5 | 5 | 5 |
| dispatch-gpu | cpuAndGPU | `501d5de7a5e3a64635fed8a194ec95bd4345e6f89d1c94375ea23c108b6617fc` | `728f4c22` | `d58fb354` | 5 | 5 | 5 |
| dispatch-cpuonly | cpuOnly | `58d8e4773ce086c1edddfedbdd6db5355b08c3d1dd21a6464008e4de58a09afe` | `7915d08f` | `d58fb354` | 5 | 5 | 5 |
| fp32-reference | fp32 CPU reference (not Core ML) | `b9c6730f68f62e3ffd83690e7345c6eb4ceb3d92de4f17733cc0bde273088d19` | `7915d08f` | `d58fb354` | 5 | 5 | 5 |

Each count is recounted from the device-wide append-only execution log for that profile, republished byte for byte in `package/execution-log/`. Every run was counted and every run is kept: 20 runs, 20 pass, 0 fail. Not counted: Device log also holds 3 counted:false scratch files from the cleanroom probe pr265-sub-01 (2026-11-22T08:41:24Z to 08:41:33Z) and 30 files from earlier work (v0.4.0 and the 2026-11-17 self-tests), none under this record's profile hashes. The four pre-freeze baselines ran outside the clean-room tool. All are in the package and listed in the record.

Recompute: EXACT 5/5 (41 checks each); negative test 4/4.

## Notes added at publication

- package/ANE_Research_Record_v0.5.0.md is the reviewed record, unchanged. Its header still reads READY FOR REVIEW, NOT PUBLISHED and says no tag, version DOI or release exists: that describes the state when it was reviewed. The reviewed hand-off set publicationAuthorized to false because the record measures a model package MacBrains Labs itself published on Hugging Face, and left the decision to publish to MacBrains Labs. This record was published after the final reviewer returned INCLUDE (round 1) for hand-off e6d3d80e1ff7d9eb4614f6ad693ea4121150c86d5ac9045f0b94dc4081731013 and MacBrains Labs decided to publish it.
- The clean-room tool at d58fb354 logs exitCode and byteIdentical for each completed run, with no separate passed field. A run counts as passed here when its run_completed line has exitCode 0 and byteIdentical true. The packaged recompute is also EXACT on all five run indexes.
- The counted receipts record the clean-room tool commit (d58fb354), not the sha256 of the run binary. The final reviewer re-read the pinned binary on the device (7df25555) and labels its use for the counted runs INFERRED, not PROVEN.
- The fp32-reference profile is an fp32 CPU forward pass of the original Qwen/Qwen2.5-1.5B-Instruct weights, not a Core ML compute unit. It runs under the same clean-room tool and is counted the same way as the three Core ML profiles. The reference is not checked against PyTorch or transformers.

## Disclosures (verbatim from the reviewed hand-off)

- The record measures a model package MacBrains Labs published (Hugging Face NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE @7f9ab466).
- The four pre-freeze baselines ran outside the clean-room tool (direct runner): not in the device log or runs[]; preFreezeRunsNotCounted 0.
- Baseline runner binaries were built at another path than the clean-room rebuild, so rebuiltMatchesBaselineBinary is false in every receipt; same source blobs, every counted dump byte-identical to its baseline.
- Two driver lanes ran concurrently (ANE then GPU; cpuOnly then reference), with probe tiers and other agents on the same machine; dumps byte-identical regardless; wall times not claimed.
- The reference profile sets computeUnits cpuOnly because the interface requires one; the reference runner ignores it.
- ANERECore run 1 failed two hard-coded corpus counts because 8 of 14 iCloud corpus links had been downloaded since v0.4.0; those 8 local copies were evicted with brctl and the whole tier rerun (run 2). Run 1 and the eviction log are kept. A probe proposal to derive the counts is filed.
- The reference implementation is not checked against PyTorch or transformers.
- Research-automation fix a1dcfdc (intake rerun tool-pin mismatch on a toolless terminal status) is on main, not deployed to the installed intake release; this record does not use intake.

## Review

- Final reviewer macbrains-labs-reviewer: INCLUDE, round 1, for hand-off `e6d3d80e1ff7d9eb4614f6ad693ea4121150c86d5ac9045f0b94dc4081731013` (verdict receipt SHA-256 `cfe81d8a8ca3362a2b8cde79f616e57f57696228cd582a57e56cf4e5e3d06ae4`).
- Pipeline model reviews of bundle `2fe4d49e6873e1800095f34e3d84c690d801f27b8ede0a466b7443b32705bd17` under diagnostic-tier policy digest `bac3cc4d2aa17eb259fe9ee191e1f614adc23cd666f11a11ea0354a7e06f4cbf`: one round, evidence_reviewer include (`3f12f04ba4aa3cf1b7c5b9fc945f3a2d65855bffad11a27dc95f47fae6045a94`), skeptical_reviewer include (`1d91a79440c1c18435253bf78132b45759bfb245a1410b5b6e96e863d9ad14f2`).
- Policy assessment `ASSESSMENTS.json` (SHA-256 `f009df41df6406f10e83f410356d491a295eab1ddac84c1dd9ceadecf598a98c`): all four profiles eligible, device scope from the committed profiles.
- Probe tier anerecore: TIER TOTAL: pass=57 fail=0 info=3 tool=4 superseded=2 probe-files=64 src=/Users/nayte/.local/share/anvil/v050/verify/anerecore-2/archive finished=2026-11-22T11:02:44Z.
- Probe tier anerecoreRun1: 55 pass, 2 fail (corpus counts; 8 iCloud links downloaded since v0.4.0), kept.
- Probe tier cleanroom: TOTAL pass=7 fail=0 superseded=2 skipped=0 probe-files=9 bin=cc6072a82724a0445e0ffbdb6300b64672a3d492c70ed381a6e5edfae5360e31 src=/Users/nayte/.local/share/anvil/v050/verify/archive.
- Probe tier dellAreas: 49 files: 34 rc0, 15 rc1, the 15 exactly the README-superseded list, at 327fc84 and a1dcfdc.
- Probe tier diagnosticTier: 24/24.
- Probe tier handoffEvent: 39/39 with HANDOFF_EVENT_SRC set.
- Probe tier replication: 8/8.
- ANE-RE commits pinned: cleanroomTool `d58fb354c6496a06ba37f4fc689ac27a19a20bc4`, profilesAneGpu `728f4c220023a9507929a42aee0f59208ad2dfd7`, profilesCpuonlyReference `7915d08fdcbd59c2d157a538c52016ace6d4fd81`, tools `8271bb68c0ac86afdd652e28b96e6ce71c8c3731`.

## Files

- `package/`: the reviewed package, byte for byte: `FILES.sha256` (SHA-256 `290be0157447bc891fd236a2b708d85daf30537f0c49f1328400692eed07909f`) and the 839 files it lists.
- `attestation.json`: hashes, the final review, the recounted runs and the notes above in machine-readable form.
- Release assets: this preview, the attestation, the reviewed record, the reviewed package tar `package-v050-20261122.tar` (SHA-256 `28dd41f1f0acacf62b6522f6a18e728ce948264bddee21177aeee66601eabfff`, the same 840 files) and SHA256SUMS.

Model weights are not included; the package under test and the reference weights are pinned by Hugging Face commit and sha256 in the reviewed record. This is a reviewed record, not a peer-reviewed result.
