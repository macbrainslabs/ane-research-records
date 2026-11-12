# Published Qwen2.5-1.5B Core ML package: greedy output depends on the compute unit, and cpuOnly returns NaN

MacBrains Labs research record v0.4.0 (`ane-record-10528818ee0e902331b666ee`). Diagnostic tier. All-versions DOI: 10.5281/zenodo.23798036. The version DOI is recorded in `records/index.json` and `CITATION.cff` on the main branch once Zenodo registers it.

## Claim

Scope as recorded: same-chip, single device (Mac17,5, macOS 27.3 26C5035r, Core ML 3610.2.3); Hugging Face package NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE at 7f9ab466, one prompt, greedy; ANE and GPU differ from the first token, cpuOnly prefill all NaN; no reference output; ANE execution inferred; no novelty claim.

Reviewed claim scope: One Mac (Mac17,5, Apple A18 Pro, macOS 27.3 26C5035r, Core ML 3610.2.3); NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE at Hugging Face commit 7f9ab466; one 28-token prompt; greedy decode. cpuAndNeuralEngine and cpuAndGPU differ from the first generated token (40 vs 9707); cpuOnly prefill logits all NaN at all 28 prompt positions (4 decode steps run; the other arms ran 200). Same-chip only. ANE execution INFERRED from compute-plan placement.

- PROVEN: the three compute-unit outputs; each arm's three dump files byte-identical across its 5 counted same-chip runs, recomputed EXACT.
- INFERRED: ANE execution (compute-plan placement).
- SUSPECTED: fp16 overflow or LUT4 dequantisation differing by backend.
- UNKNOWN: cause; which non-NaN arm, if either, is correct; other devices, OS builds, prompts.

No reference output was run, so this record does not say which of the cpuAndNeuralEngine and cpuAndGPU outputs, if either, is correct. Cross-device replication: none. Same-chip reruns are repeatability only, not cross-device replication. Novelty: UNCLAIMED.

The full claim, every attempt in order, and the limitations are in the reviewed record `package/ANE_Research_Record_v0.4.0.md` (SHA-256 `363f37782e0fa515319f6cdc7c1cd490a65e912d1a9411c46e7455c3428361a8`).

## Counted runs

| Arm | Compute units | Setup profile | Profile commit | Tool commit | Started | Completed | Passed |
|---|---|---|---|---|---|---|---|
| ane-and-gpu | cpuAndNeuralEngine, cpuAndGPU | `9f2bd532c9beb961fb815639139503f5cbefed57bdca9a59111648ee2420604f` | `8186ad8f` | `246504e8` | 10 | 10 | 10 |
| cpu-only | cpuOnly | `3de33b648fff4b94ccdb2db407ececbf4b1f043f7ef72c544656bddef4716da1` | `8186ad8f` | `246504e8` | 5 | 5 | 5 |

Each count is recounted from the device-wide append-only execution log for that profile, republished byte for byte in `package/execution-log/`. Every run was counted and every run is kept: 15 runs, 15 pass, 0 fail. Not counted: Device log also holds 8 files of scratch profile hashes, all counted:false: 2 from the claim-scope fix test (14:29:48Z, 14:29:56Z) and 6 from the cleanroom probe pr265-sub-01 at two tool commits (15:14:50Z to 15:17:38Z). All are in the package and listed in the record.

Recompute: EXACT 15/15; negative test EXACT on unaltered copies, NOT_EXACT on a flipped logits byte and an edited chain winner, both arms.

## Notes added at publication

- package/ANE_Research_Record_v0.4.0.md is the reviewed record, unchanged. Its header still reads READY FOR REVIEW, NOT PUBLISHED and says no tag, version DOI or release exists: that describes the state when it was reviewed. The reviewed hand-off set publicationAuthorized to false because the record reports a defect in a model package MacBrains Labs itself published on Hugging Face, and left the decision to publish to MacBrains Labs. This record was published after the final reviewer returned INCLUDE (round 1) for hand-off 10528818ee0e902331b666eeab96c42217b8bfbe71ce870b61dba9125986e780 and MacBrains Labs decided to publish it.
- The reviewed package directory holds five symbolic links under package/verification/cleanroom-tier-first-attempt-relative-paths/ (fixtures of a clean-room path probe; one points to /usr/bin/true). They are not files, FILES.sha256 does not list them, and they are not republished in package/. They remain in the reviewed package tar package-v040-20261112.tar, whose hash is unchanged.
- The clean-room tool at 246504e8 logs exitCode and passed for each completed run but no byte comparison. A run counts as passed here when its run_completed line has exitCode 0 and passed true. Byte identity of each compute unit's three dump files across its five runs is shown by the packaged recompute (EXACT 15/15), not by the log.
- The reviewed record has three compute-unit arms (cpuAndNeuralEngine, cpuAndGPU, cpuOnly) under two setup profiles. The runs are counted here per setup profile, as the device logs record them: ane-and-gpu (cpuAndNeuralEngine and cpuAndGPU, 10 runs) and cpu-only (5 runs).

## Disclosures (verbatim from the reviewed hand-off)

- The finding is a defect in a model package MacBrains Labs published (Hugging Face NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE). Publishing this record is a decision for Nayte.
- All 10 counted receipts carry a stale layer-14 claimScope sentence written by the clean-room tool at 246504e8; no claim rests on it. Fix is ane-re PR #288 (head 5e98f68b), made after the runs; counted runs not repeated because the field enters no hash or verdict.
- The diagnostic-tier policy module fixes its expected device to macOS 27.2 26B123 / Core ML 3600.25.2 (the L14 record), not this device (27.3 26C5035r / 3610.2.3). Its automatic eligibility check was not applied; device fields were checked against the receipts. Updating that scope is for the reviewer.
- Commits 543c3df3 and 8186ad8f carry author "Hyun-woo <hyunwoo@MiniMax.local>" from a repository-local git config in the clone they were made from; pinned by receipts, so not rewritten.
- The first ANERECore tier run gave one FAIL (pr264-B-06 corpus counts lacked UNREADABLE=14) because its rebuilt corpus omitted the 14 iCloud-dataless links of the v0.3.0 corpus. The corpus was rebuilt with those links and the tier rerun; run 1 is kept in verification/anerecore-tier-run1-corpus-missing-14-links/.
- Round 1 (both include) asked for record wording fixes: the step count differs (200 decode steps for ANE and GPU, 4 for cpuOnly); byte-identical covers each arm's three dump files, not whole runs; cpuOnly all-NaN covers the prefill logits, with the first two infer calls finite; the zip sha256 is tied to a Hugging Face API check added as verification/hf-file-check.txt. The record and package were rebuilt and reviewed again in round 2; the round 1 package, bundle and receipts are kept.
- Analysis tools (recompute, compare, negative test) were committed at 7d879697 after the counted runs; they only read the dumps.
- Two reviewer-probe proposals are filed, not applied: a probes/README cleanroom section (superseded r1-01, r1-02) and HANDOFF_EVENT_SRC being required for the handoff-event harness.
- Not run: fabric-mcp, media-tier, and the Neo zsh probes and deploy gates under rerun/neo, r4/neo, r4/deploy-gates (they test installed intake tools this record does not use).

## Review

- Final reviewer macbrains-labs-reviewer: INCLUDE, round 1, for hand-off `10528818ee0e902331b666eeab96c42217b8bfbe71ce870b61dba9125986e780` (verdict receipt SHA-256 `d3c41bcf26f78a021d8fe734385166fcdfb635074ce8efe585710926de48c7df`).
- Pipeline model reviews of bundle `b6efc3eaf9568ec0a827827b6bf224958bd2667330bc4841a044bfad3091be64` under policy digest `3c3b6ba4f8ee69849f8c24672d26bc51f1ca36b429203f996849994b8d7ea3fa`: two rounds, an evidence reviewer and a skeptical reviewer in each, all four include. Round 2 receipts: evidence_reviewer `658855d461d329a1b5617f4efcb285cf08fa5c3fde1c0926d95dcbad9dd11849`, skeptical_reviewer `1198be06df8526a88a06b4adcaa1584015d499cb015391743d67d8730b41a2d5`.
- Probe tier anerecore: TIER TOTAL: pass=57 fail=0 info=3 tool=4 superseded=2 probe-files=64 src=/Users/nayte/.local/share/anvil/qwen-dispatch-v040/verify/src-7d879697 finished=2026-11-12T15:58:53Z.
- Probe tier cleanroom: 7 pass, 0 fail, 2 superseded at 7d879697 and at 5e98f68b.
- Probe tier diagnosticTier: 24/24.
- Probe tier handoffEvent: 39/39 with HANDOFF_EVENT_SRC set.
- Probe tier intakeRerunR4: every current file passes; FAIL lines only in files the probe README marks superseded.
- Probe tier replication: 8/8.
- ANE-RE commits pinned: analysisTools `7d879697ab1a8cf78087f95333644408caa9d3e6`, claimScopeFixPR288Head `5e98f68b`, cleanroomTool `246504e8df8d7ee957855e56f6936a46a9c39cee`, profiles `8186ad8f4a75d18bdf74705b57f852a70bae01ce`, runner `543c3df3126b8adb973e0ae026d528624e3161ef`.

## Files

- `package/`: the reviewed package, byte for byte: `FILES.sha256` (SHA-256 `d3628555fe2e01975cd386fd1ec2cbdcbad027da97ba27d2d21ea8df14c2b3d9`) and the 837 files it lists.
- `attestation.json`: hashes, the final review, the recounted runs and the notes above in machine-readable form.
- Release assets: this preview, the attestation, the reviewed record, the reviewed package tar `package-v040-20261112.tar` (SHA-256 `8a42b1faa4e44033061d1f311178b59631fe040d4fc2ada73fa931722aa46109`, the same 838 files plus the five symbolic links in note N2) and SHA256SUMS.

The model package itself (828 MB) is not included; it is pinned by its Hugging Face commit and sha256 in the reviewed record. This is a reviewed record, not a peer-reviewed result.
