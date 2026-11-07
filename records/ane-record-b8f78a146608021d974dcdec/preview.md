# ANERECore cross-repo MIL parity: tap, steer and functionWide (same chip, single device)

MacBrains Labs research record v0.3.0 (`ane-record-b8f78a146608021d974dcdec`). Diagnostic tier. All-versions DOI: 10.5281/zenodo.23798036. The version DOI is recorded in `records/index.json` and `CITATION.cff` on the main branch once Zenodo registers it.

## Claim

Scope as recorded: same-chip, single device (Mac17,5, macOS build 26C5035r); MIL text byte equality only, one Qwen fixture, operations tap, steer and functionWide; functionWide pin is Fugu-referenced; no Core ML compile, ANE execution or numerics; no novelty claim.

In every counted run of both arms, the three output files (`tap`, `steer`, `functionWide`) were byte-identical to the committed baseline index; across the two arms 75 of 75 file comparisons byte-identical (cmp). The `functionWide` pin is Fugu's own output, so a match on it shows that ANE-RE agrees with Fugu, not that either is correct. Cross-device replication: none. Same-chip reruns are repeatability only, not cross-device replication. Novelty: UNCLAIMED.

The full claim, every attempt in order, and the limitations are in the reviewed record `package/ANERECore_v0.3.0_record.md` (SHA-256 `dbd33eb410dfb624158f1bcb8ff0458b72a6c8601a6dd6ad93fb349ff73081e0`).

## Counted runs

| Arm | Setup profile | Profile commit | Tool commit (log) | Started | Completed | Passed |
|---|---|---|---|---|---|---|
| fugu | `0959e19f8b1830426af347355b403f775cdac15c8f343f8d31778aa0cef7577c` | `017df3d1` | `d485ad2e` | 5 | 5 | 5 |
| ane-re | `84c276441ec23b090bc5db708d952ff70dc16dcfb77bfdd8c1d01e8a5305df97` | `87cb8360` | `0ae0b6d7` | 5 | 5 | 5 |

Each count is recounted from the device-wide append-only execution log for that profile, republished byte for byte in `package/execution-log/`. Every run was counted and every run is kept: 10 runs, 10 pass, 0 fail. A run is counted as passed when its run_completed line has exitCode 0 and byteIdentical true; the older Fugu tool build logs no separate passed field, and every ANE-RE line that has one says true.

## Notes added at publication

- The reviewed hand-off manifest still says, in its round1Blockers.B3 line, that the full probe tier was 56 pass, 1 fail. That line predates the input-selection correction. The reviewed record and the manifest's own mainVerification both state 57 pass, 0 fail of 57 (corrected summary package/verification/tier-87cb836-corrected-summary.txt, SHA-256 a398c45e716b7703c527f07d7e29541e0ec474c436ed0e78fc2bc451347d18ec), and the final reviewer confirmed 57/57 and that the record governs. The manifest was not edited and is not republished.
- The ANE-RE arm's execution-log lines name toolCommit 0ae0b6d7454496809b5876493d78653ec5b7a81e, while the record labels that arm's tool cleanroom-c55e9e7d. 0ae0b6d7 (PR #266) is the last commit that touched the clean-room tool source and is part of ANE-RE main c55e9e7d; the final reviewer proved the tool source tree identical at both commits. This is labeling only; no run or result changes.
- package/ANERECore_v0.3.0_record.md is the reviewed record, unchanged. Its header still reads READY FOR REVIEW, NOT PUBLISHED and says no tag or DOI exists: that describes the state when it was reviewed. This record was published after the final reviewer returned INCLUDE (round 2 of 2) for hand-off b8f78a146608021d974dcdec34ced0407a2c8449d23eab3e416649dec221cc2e.

## Disclosures (verbatim from the reviewed hand-off)

- This corrected round-2 package supersedes received-but-held ee23a1f3; original tier 56/57 failed only on 5 intentionally body-less negative controls mistakenly passed to the real-MIL-positive probe.
- Full tier from git archive of unchanged 87cb8360 is now 57/57. Reviewer probes were not edited. Only the tier runner stopped supplying the negative-control directory to r2-05; all 5 remain tested for proper refusal by other probes.
- No production source, committed clean-room profile or counted replication result changed. Existing 5/5 per arm with device-wide execution log stands.
- Original 54/3 and 56/1 probe results remain preserved; do not reinterpret the earlier runs as passing.
- The 14 iCloud-dataless corpus files are still UNKNOWN; they were not tested, and the record makes no general MIL/Core ML correctness claim.
- The two clean-room arms used different tool builds; Fugu inputs were hashed before and after, but the older build did not verify content hashes internally.
- Diagnostic-tier preflight CHECK_DIGEST is N/A: no pipeline review receipt digest; replication and package hash checks were performed separately.

## Review

- Final reviewer macbrains-labs-reviewer: INCLUDE, round 2 of 2, for hand-off `b8f78a146608021d974dcdec34ced0407a2c8449d23eab3e416649dec221cc2e` (verdict receipt SHA-256 `f80745c7f3344a5fa9022dc94381d7e18f5212bca184837705e33ce85edd6e54`).
- Round 1 (`bf76dc26`) was held on blockers B1 to B3 and retired; round 2 checked only those blockers. No pipeline model reviews apply to this record.
- Full ANERECore probe tier on ANE-RE `87cb8360`: 57 pass, 0 fail (summary `a398c45e716b7703c527f07d7e29541e0ec474c436ed0e78fc2bc451347d18ec`).

## Files

- `package/`: the reviewed package, byte for byte: `FILES.sha256` (SHA-256 `f81ff1837688ac91c656dd6a0bbf45a2d5f7e594909830760458831be2337043`) and the 270 files it lists.
- `attestation.json`: hashes, the final review, the recounted runs and the notes above in machine-readable form.
- Release assets: this preview, the attestation, the reviewed record, the reviewed package tar `package-r2-20261107-corrected.tar` (SHA-256 `b248505187be8e9862e2f2048ffca8c15b54039df3542182fddeb59125a07b0a`, the same 271 files) and SHA256SUMS.

Generated MIL outputs, model weights and compiled models are not included. This is a reviewed record, not a peer-reviewed result.
