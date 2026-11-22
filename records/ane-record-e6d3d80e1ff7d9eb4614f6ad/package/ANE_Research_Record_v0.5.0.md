# Published Qwen2.5-1.5B Core ML package against an fp32 reference of its original weights: the GPU output follows the reference for 7 tokens, the ANE output differs from the first token, and cpuOnly returns NaN

**MacBrains Labs ANE Research Records | candidate v0.5.0 | READY FOR REVIEW, NOT PUBLISHED**
**Observed 2026-11-22 UTC | Disposition: READY_FOR_REVIEW | Scientific tier: diagnostic | Novelty: UNCLAIMED | Replication: same-chip**

No tag, version DOI or release exists for this record. The manager publishes only after the reviewer channel returns INCLUDE. Like v0.4.0, this record reports on a model package that MacBrains Labs itself published on Hugging Face.

Claim scope: same-chip, byte-reproducible on Apple A18 Pro (Mac17,5), macOS 27.3 (build 26C5047e), CoreML 3610.2.3; ANE execution INFERRED from Core ML compute-plan placement; no novelty claim.

## What is new against v0.4.0

v0.4.0 (DOI 10.5281/zenodo.24183178) showed that the package gives different greedy output under cpuAndNeuralEngine and cpuAndGPU and NaN under cpuOnly, and said it had no reference, so it could not say which output follows the model. This record adds that reference: an independent fp32 CPU forward pass of the original `Qwen/Qwen2.5-1.5B-Instruct` bf16 weights, run on the same prompt under its own frozen profile, and compares all three Core ML outputs with it. It also reruns the three Core ML arms under new frozen profiles on a later OS build (26C5047e; v0.4.0 used 26C5035r).

## Subjects

- **Package under test:** `NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE` at Hugging Face commit `7f9ab466b2265a96941670119670638ea22b65dc`, `qwen25_monolithic_full_lut4.mlmodelc` (the LUT4-palettized monolithic multifunction model; zip sha256 `194b8f1088030eb2f27ac68fb1ccfa240776f73cb8c1d090978c7e3bd7f51c70`; compiled-model fixture sha256 `e3c5cfc43c60b2bac682aed846b6165cfe7600c286f5d8b47a018bd134ba9e28`, which is the sha256 of the `LC_ALL=C` sorted `shasum -a 256` listing of every file under the `.mlmodelc`, paths relative to it with a `./` prefix).
- **Reference weights:** `Qwen/Qwen2.5-1.5B-Instruct` at Hugging Face commit `989aa7980e4cf806f80c7fef2b1adb7bc71aa306`, `model.safetensors` sha256 `dd924a11b4c220f385b51ffa522daea7c9f3d850e31b162bb5661df483c6d3ee` (equal to the Hugging Face LFS sha256; the reference runner also writes it into every dump).
- **Prompt:** the same 28-token Qwen2.5 ChatML prompt as v0.4.0 (system "You are a helpful assistant.", user "Hi, what can you help me with?", assistant turn open), file sha256 `20736e77c3f98a81007e6962c97d513a3189cacd566878d4145723a29c11f737`.
- **Device:** one Mac, `hw.model=Mac17,5`, Apple A18 Pro, macOS 27.3 build 26C5047e, Core ML 3610.2.3, as every counted receipt records it.

## Results

All four profiles gave verdict REPLICATED_SAME_CHIP_BYTE_IDENTICAL: 5 of 5 counted fresh-process runs each, every run's dump byte-identical to the profile's pre-freeze baseline (20 of 20 files for the reference, every dump file for each Core ML arm). The comparison below is from `analysis/compare/compare-run-001.json`; the five compare outputs (one per run index) are byte-identical, and the independent recompute is EXACT on all five.

1. **Reference.** (PROVEN, 5 of 5.) At the last prompt position the fp32 reference's winner is id 9707 (v0.4.0 decoded 9707 as "Hello"); its top 5 are 9707, 13048, 40, 18665, 2121, so id 40 is third. Greedy decoding gives 65 generated tokens, the first `<|im_end|>` (151645) at generated index 27, and no NaN. The self-check passes: the last prompt position recomputed alone on the batched prefill's KV cache is bit-identical to the batched prefill at that position (0 of 151,936 elements differ).
2. **cpuAndGPU follows the reference for its first 7 generated tokens.** (PROVEN, 5 of 5.) The GPU arm's first 7 generated tokens equal the reference's (9707, 0, 358, 2776, 1588, 311, 1492); they first differ at generated index 7 (GPU 448, reference 498). At the last prompt position the GPU arm's winner equals the reference's (9707), the reference ranks the GPU winner first, the top-5 sets share 4 ids, and over all 151,936 values cosine 0.947366964, max |GPU − ref| 8.911624, mean 1.284449. Prefill next-token winners agree at 16 of the 28 prompt positions. The GPU arm's first `<|im_end|>` is at generated index 33.
3. **cpuAndNeuralEngine differs from the reference from the first generated token.** (PROVEN, 5 of 5.) The ANE arm's first generated token is 40, the reference's 9707; the common prefix is 0 tokens. At the last prompt position the reference ranks the ANE winner (40) third and the ANE arm ranks the reference winner (9707) second; the top-5 sets share 3 ids; over all 151,936 values cosine 0.862787388, max |ANE − ref| 11.22683, mean 2.070772. Prefill winners agree at 15 of 28 positions. The ANE arm emits no `<|im_end|>` in its 201 generated tokens.
4. **cpuOnly returns NaN.** (PROVEN, 5 of 5.) All 151,936 last-position prefill logits are NaN, and no prompt position has a finite winner, so none of the 28 agrees with the reference. The infer chain yields no token (every winner is the NaN sentinel −1; 30 of its 32 infer calls have a NaN chunk).
5. **The three Core ML arms reproduce v0.4.0 exactly on the later OS build.** (PROVEN.) Each arm's three dump files (`chain.json`, `logits-prefill-last.f16`, `prefill.json`) are byte-identical to v0.4.0's counted run-1 dumps, which were made on macOS 27.3 build 26C5035r (`verification/v040-dump-identity.txt`, 9 of 9 files IDENTICAL). The runner source is the same git blob (`383b205e`) as v0.4.0's, and the clean-room rebuild produced the same runner binary sha256 (`b4f4a296a09873fbbd2f04f3461cee760b32d419f35de4ceda2c3b1e58e7143f`) as in all 10 v0.4.0 receipts.

Placement (from each counted run's `result.json`, the same in all 5 runs of each arm): cpuAndNeuralEngine, infer 2,147 ops preferred on the Neural Engine and 82 on the CPU, prefill 2,360 and 13; cpuAndGPU, infer 2,217 GPU and 12 CPU, prefill 2,372 and 1; cpuOnly, every assigned op on the CPU (2,229 infer, 2,373 prefill). In every arm 4,022 infer and 4,735 prefill ops report no device usage. ANE execution is INFERRED from this placement, not from a hardware trace.

**What this does not show.** The Core ML arms run fp16 arithmetic on LUT4-palettized weights, and the reference runs fp32 on the original bf16 weights, so every arm is expected to differ from the reference numerically, and the GPU arm also departs from it at generated index 7. The record shows how far each arm's output is from the reference, not that the GPU arm is correct. The reference is one independent implementation written for this record from the published architecture (bf16 widened to fp32, fixed-order reductions, RoPE theta 1e6); it has not been checked against PyTorch or the Hugging Face `transformers` implementation, so agreement with those is UNKNOWN. The cause of the ANE arm's earlier divergence and of the cpuOnly NaN is UNKNOWN; SUSPECTED causes are fp16 range or accumulation differences on the Neural Engine and LUT4 dequantisation behaving differently per backend.

## Method

- **Core ML runner:** `spi/cleanroom/runners/qwen_dispatch_runner.swift` in `naytewilson/ane-re`, rebuilt by the clean-room tool from `git show 8271bb68c0ac86afdd652e28b96e6ce71c8c3731:<path>` with `xcrun swiftc -O -parse-as-library`. The file is unchanged from v0.4.0 (git blob `383b205e067db37f7f8ba3038fad4bfbd7300321`, raw sha256 `3c28c0b068908ac595bf196003f49d859472f90350cd56b6c3feed52f2308a05`). Prefill is one batched `prefill` call with full logits analysed at every prompt position; decode is the package's `infer` function, greedy over its 16 in-graph per-chunk maxima. Steps: 200 for the ANE and GPU arms, 4 for cpuOnly, as in v0.4.0.
- **Reference runner:** `spi/cleanroom/runners/qwen25_ref_runner.swift` at `8271bb68` (raw sha256 `499bb4407b631108fb345131ed378ed5c5570725e40f072907a1a09f6afa8faf`). No Core ML, Metal or BLAS. bf16 weights are widened exactly to fp32; dot products accumulate in 16 fp32 lanes with fused multiply-add in index order and the lanes are summed 0 to 15; RMSNorm and softmax sums are sequential; RoPE angle is fp32 position times fp32 inverse frequency; exp, cos and sin come from Foundation. Prefill is one batched forward over the prompt with full fp32 logits at every position; the chain recomputes the last prompt token alone on that KV cache (the self-check) and then decodes 64 greedy steps on full fp32 logits. It ignores `LFM3_COMPUTE_UNITS`.
- **Dumps** carry no timestamps or paths, so fresh-process runs can be byte-compared.
- **Clean-room tool:** `cleanroom-d58fb354`, built from `spi/cleanroom/cleanroom.swift` at `d58fb354c6496a06ba37f4fc689ac27a19a20bc4` (git blob `8a73b8f4`), binary sha256 `7df255553753aa4a921df7755080edcd20f5fb74b544645a017f13769f1decb0`, run in set mode with `--runs 5`. Before each run it re-verifies the freeze (committed profile, inputs, source) and compares the dump with the baseline; it writes one `cleanroom-receipt.json` per profile and appends `run_started`/`run_completed` lines to the device log.
- **Compare and independent recompute:** `qwen25_ref_compare.swift` and `qwen25_ref_recompute.swift` at `8271bb68`, built with `xcrun swiftc -O` (`analysis/bin-SHA256SUMS`). The recompute is written from the metric definitions, not from the compare tool's code: it re-derives every prefill field of the reference dump from the raw fp32 logits (28 positions), checks the reference chain's token feeding, and recomputes every compare metric for each arm from the raw dumps. 41 checks per run index, EXACT on all five. The negative test (`test_qwen25_ref_negatives.sh`) passes 4 of 4: EXACT on an unaltered copy, mismatch on one flipped logits byte, on one edited chain token, and on one edited compare metric.
- **Profiles** declare a top-level `deviceScope` equal to the device fields above.

## Counted runs

Four profiles in `naytewilson/ane-re`, each committed before its first counted run. The profile hash is sha256 of the canonical JSON of the committed file; it equals the receipt's `profileHash` and `freeze.committedProfileBlobSha256`.

| Profile | Commit (time UTC) | profileHash | First counted run | Wall s (runs 1 to 5) | Receipt self-hash |
|---|---|---|---|---|---|
| `qwen25-v050-dispatch-ane-20261122.json` | `728f4c22` (08:08:26) | `be83f5a03df95fd85761dd8e076a756aef6d50ea9297351042b1072e09a5f5af` | 08:08:54.671Z | 703, 35, 23, 18, 16 | `700f1e54844fe990…` |
| `qwen25-v050-dispatch-gpu-20261122.json` | `728f4c22` (08:08:26) | `501d5de7a5e3a64635fed8a194ec95bd4345e6f89d1c94375ea23c108b6617fc` | 08:22:52.665Z | 361, 122, 115, 120, 108 | `48630668213eda71…` |
| `qwen25-v050-dispatch-cpuonly-20261122.json` | `7915d08f` (08:36:06) | `58d8e4773ce086c1edddfedbdd6db5355b08c3d1dd21a6464008e4de58a09afe` | 08:36:39.969Z | 442, 423, 302, 293, 317 | `2e979e2017215443…` |
| `qwen25-v050-fp32-reference-20261122.json` | `7915d08f` (08:36:06) | `b9c6730f68f62e3ffd83690e7345c6eb4ceb3d92de4f17733cc0bde273088d19` | 09:06:44.036Z | 1006, 1159, 940, 932, 956 | `58c94ac2e7918fad…` |

Every receipt: 5 counted, 5 total, 0 pre-freeze runs not counted, frozen, `crossDeviceReplication: false`. The three Core ML profiles' runs all used rebuilt runner `b4f4a296…`; the reference's used `65cf2f6f47cfa07f709f18e631adb078ba788dbe7d8acabeeb602509140c5736`. Full receipts are in `runs/<profile>/cleanroom-receipt.json`.

## Execution log

Neo keeps one append-only device log per profile hash under `~/.local/state/anvil/execution-log/`. The package carries all 37 files as they stand at packaging.

- The four counted files, 10 lines each (a `run_started` and a `run_completed` per counted run, all `counted: true`, all exit 0): `be83f5a0….jsonl` (sha256 `2c14ac25bfc096145845cadc629b26e5d05340a2bb4ae33621157a16ed867b09`), `501d5de7….jsonl` (`6d1b238a1bbefad2da2ceac08323416b74e17eb65fd4c0e1f6ee8e20c8848ff8`), `58d8e477….jsonl` (`bc383eb16358079b05fbca94872ac7756c967f64e326f02394c2d38a543dc8ec`), `b9c6730f….jsonl` (`72eee97880ebd436a2f5d96bda7d6a5d0cb1cec15f2f45af5bb59ba35530352d`). Each receipt's `executionLog` block records the same sha256, 5 started, 5 completed, 0 started without completion.
- Three files of 2 lines each, `counted: false`, from the scratch runs the reviewer probe `pr265-sub-01` makes when the cleanroom tier runs (2026-11-22T08:41:24Z to 08:41:33Z): `60ed7cba…`, `3685dd11…`, `07192c5f…`.
- 30 files from earlier work on this machine, none under this record's profile hashes: v0.4.0's two counted files (`9f2bd532…`, `3de33b64…`) and its eight test and probe files (2026-11-12); 19 files written 2026-11-17 between 12:32Z and 12:36Z by the clean-room and rerun self-tests (outputs under `/tmp` or `/private/tmp`, throwaway profile hashes); and one marker file of those self-tests (`b1b8e57a…`, one line `{"kind":"rerun-selftest-marker", …}`, no run).

## Every attempt, in order

All times UTC, 2026-11-22. No counted run was removed or repeated. Items marked "file times" come from file modification times.

| Time | What | Counted | Outcome |
|---|---|---|---|
| 07:44:49 | Runner and analysis tools committed, `8271bb68` | | |
| 07:45:41 | Baseline runners built directly from that source (file times) | no | built (binaries differ from the clean-room rebuilds, see Disclosures) |
| to 07:50:34 | Baseline, cpuAndNeuralEngine, direct runner (no clean-room, no log line) | no | first token 40, no `<|im_end|>` in 200 steps |
| to 07:58:24 | Baseline, cpuAndGPU | no | first token 9707, `<|im_end|>` at 33 |
| 08:08:26 | ANE and GPU profiles committed, `728f4c22` | | |
| 08:08:54 to about 08:22:22 | dispatch-ane runs 1 to 5 | yes | table above |
| to 08:11:40 | Baseline, cpuOnly (ran during dispatch-ane run 1) | no | all NaN |
| 08:22:52 to about 08:36:51 | dispatch-gpu runs 1 to 5 | yes | table above |
| to 08:35:38 | Baseline, fp32 reference | no | winner 9707, self-check bit-identical |
| 08:36:06 | cpuOnly and reference profiles committed, `7915d08f` | | |
| 08:36:39 to 09:06:30 | dispatch-cpuonly runs 1 to 5 | yes | table above |
| 08:41:24 to 10:09:54 | Neo probe tiers, cleanroom then ANERECore run 1 (see Verification) | no | |
| 09:06:44 to 10:30:09 | fp32-reference runs 1 to 5 | yes | table above |
| about 10:31 | Analysis: compare, recompute, negative test | no | EXACT 5/5, 4/4 |
| 10:34:08 to 11:02:44 | ANERECore tier run 2, after evicting 8 iCloud corpus files | no | 57 pass, 0 fail |

## Disclosures

1. **Baselines outside the clean-room tool.** The four pre-freeze baselines were run directly by runners built from `8271bb68`, not through the clean-room tool, so they are not in the device log or in any receipt's `runs[]`, and `preFreezeRunsNotCounted` is 0. They are kept under `pre-freeze/` with their log, and each profile pins its baseline index by sha256.
2. **Baseline binaries differ from the rebuilds.** The baseline runner binaries (`54ee4d1f…` Core ML, `7ef66677…` reference) were built at another path than the clean-room tool's rebuild, so each receipt records `rebuiltMatchesBaselineBinary: false`. The source blobs are the same, and every counted dump is byte-identical to its baseline.
3. **Concurrent load.** Two drivers ran the profiles in two lanes (ANE then GPU; cpuOnly then reference), so dispatch-cpuonly run 1 started while dispatch-gpu run 5 was still running. The cpuOnly and reference baselines, the Neo probe tiers (including `pr265-sub-01`'s three scratch runs) and the counted runs overlapped in time on this one machine, which other agents were also using. Dumps were byte-identical regardless; wall times vary with load and Core ML compile caches (the ANE arm's run 1 took 703 s with a cold compile, later runs 16 to 35 s) and are not claimed.
4. **Reference profile's compute units.** The reference profile sets `computeUnits: cpuOnly` because the clean-room interface requires one; the reference runner ignores it and never uses Core ML.
5. **Analysis tools before the runs.** Unlike v0.4.0, the compare, recompute and negative-test tools were committed in `8271bb68`, before the first counted run. They read the dumps and write nothing into the run directories.
6. **Publisher.** MacBrains Labs published the package this record measures.
7. **ANERECore corpus state.** The first Neo ANERECore tier run gave 55 pass and 2 fail. Both FAILs (`pr264-A-10`, `pr264-B-06`) are hard-coded corpus counts (OK 134, UNREADABLE 14) that the v0.3.0 and v0.4.0 corpus met because 14 of its entries are links to iCloud files that are not downloaded. Since v0.4.0, 8 of those 14 files had been downloaded to the Mac, so the corpus read OK 142, UNREADABLE 6; the reference base `09177138` failed the same check. For run 2 those 8 local copies were evicted with `brctl evict` (their contents stay in iCloud), all 14 links were confirmed dataless, and the whole tier was rerun. Run 1 is kept as `verification/anerecore/`, run 2 is `verification/anerecore-2/`, and the eviction log with flags before and after is `verification/anerecore-2/eviction.txt`. A proposal to derive those counts from the corpus instead of hard-coding them is filed for the reviewer.
8. **Pipeline fix found along the way.** The research-automation intake rerun step recorded a tool-pin mismatch for a failed or abandoned rerun status that names no tools (seen in the 2026-11-17 dry-run ledger). The fix is commit `a1dcfdc0` on research-automation main (full suite 726/726); the Dell probe tiers below were run at both `327fc84` and `a1dcfdc` with identical results. It is not yet deployed to the installed intake release; this record does not use the intake path.

## Verification

Every reviewer probe file in each area was run from a `git archive` of the exact commit, one line per file; full output is in `verification/`.

- **cleanroom** (`probes/cleanroom/`, 9 files, Neo, archive of ane-re `7915d08f`, clean-room binary built from it `cc6072a8…`): 7 pass, 0 fail, 2 superseded. Per-file counts equal v0.4.0's.
- **anerecore** (`probes/anerecore/`, 64 files, Neo, archive of `7915d08f`): run 2, after the eviction (10:34:08Z to 11:02:44Z): 57 pass, 0 fail, 3 informational, 4 tools, 2 superseded, 64 probe files. The reference base `09177138`, which the tier runs as its differential input, fails `pr264-B-08` in both runs and the corpus count in run 1 only. Run 1, before the eviction: 55 pass, 2 fail (the two corpus counts in Disclosure 7), 3 informational, 4 tools, 2 superseded. The real-MIL list is v0.4.0's with the `~/ane-hot` prefix moved to `/Volumes/ANVIL-SSD/ane-hot`; 376 of 377 paths resolve (`realmil-unresolved.txt`).
- **diagnostic-tier** (Dell, research-automation at `327fc84` and `a1dcfdc`): 24/24. **replication**: 8/8. **handoff-event**: 39/39 with `HANDOFF_EVENT_SRC` set to the archive's `src/`. **intake, rerun, r4** and the other Dell areas: 49 files, 34 exit 0 and 15 exit 1, where the 15 are exactly the files the probe README marks superseded, the same list as v0.4.0 (`verification/dell/dell-areas-a1dcfdc/summary.txt`).
- **Recompute**: EXACT on all five run indices; negative test 4 of 4.
- **Preflight**: profiles committed before their first counted runs; freeze time after the profile commit in every receipt; every device-log line under the four counted hashes matches a counted run by start time; every file in `FILES.sha256` re-hashed.

Not run: `fabric-mcp/` and `media-tier/` (other systems), and the Neo zsh probes and deploy gates under `rerun/neo`, `r4/neo` and `r4/deploy-gates`, which test installed intake tools that this record does not use.

## Prior art

Six searches, all completed (`prior-art/priorart-evidence.json`). Device-dependent Core ML outputs and fp16 overflow on the Neural Engine are reported in prior work and forum threads, so the general phenomenon is known. No result found measures this published package against an fp32 reference of its original weights. That is not a novelty claim; novelty is UNCLAIMED.

## Limitations

- One device, one chip, one OS build, one Core ML version, one prompt, one package revision. Same-chip only; not cross-device. The v0.4.0 identity in result 5 covers two builds of macOS 27.3 on the same Mac.
- The reference is an independent implementation not checked against PyTorch or `transformers`; it is a yardstick for distance, not ground truth for the package.
- The Core ML decode is greedy over the package's in-graph per-chunk maxima; full Core ML logits exist only for the prefill call.
- cpuOnly runs only 4 decode steps (each cpuOnly call takes about 10 s); the reference runs 64.
- ANE execution is INFERRED from compute-plan placement.
- Cause UNKNOWN.
