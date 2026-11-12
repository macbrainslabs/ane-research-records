# Published Qwen2.5-1.5B Core ML package: greedy output depends on the compute unit, and cpuOnly returns NaN

**MacBrains Labs ANE Research Records | candidate v0.4.0 | READY FOR REVIEW, NOT PUBLISHED**
**Observed 2026-11-12 UTC | Disposition: READY_FOR_REVIEW | Scientific tier: diagnostic | Novelty: UNCLAIMED | Replication: same-chip**

No tag, version DOI or release exists for this record. The manager publishes only after the reviewer channel returns INCLUDE. This record reports a defect in a model package that MacBrains Labs itself published on Hugging Face.

## Claim

The subject is the published package `NayteThaGreat/Qwen2.5-1.5B-Instruct-ANE` at Hugging Face commit `7f9ab466b2265a96941670119670638ea22b65dc`: the LUT4 monolithic multifunction model `qwen25_monolithic_full_lut4.mlmodelc` (zip sha256 `194b8f1088030eb2f27ac68fb1ccfa240776f73cb8c1d090978c7e3bd7f51c70`, 828,554,544 bytes, as the Hugging Face API lists the file at that commit, read 2026-11-12 in `verification/hf-file-check.txt`; the zip itself is not kept; compiled-model fixture sha256 `0322a5e996e36f78ced043404ff4001dfab237314d94fe482e22e7807bff4461` as the clean-room tool hashes it).

On one Mac (`hw.model=Mac17,5`, Apple A18 Pro, macOS 27.3 build 26C5035r, Core ML 3610.2.3), one source-rebuilt runner fed the same 28-token Qwen2.5 ChatML prompt (system "You are a helpful assistant.", user "Hi, what can you help me with?", assistant turn open; prompt file sha256 `20736e77c3f98a81007e6962c97d513a3189cacd566878d4145723a29c11f737`) to the package under three Core ML compute-unit settings. The binary, model and prompt were identical across all three settings, and only `LFM3_COMPUTE_UNITS` changed between arms. The step count was not the same: cpuAndNeuralEngine and cpuAndGPU ran 200 decode steps each, and cpuOnly ran 4 because each cpuOnly call takes about 10 s.

1. **cpuAndNeuralEngine and cpuAndGPU give different greedy output from the first generated token.** (PROVEN, 5 of 5 counted runs per arm. Each arm's three dump files, `chain.json`, `logits-prefill-last.f16` and `prefill.json`, are byte-identical across its 5 runs; receipts and wall times differ.)
   - cpuAndNeuralEngine: first token id 40 ("I"). The 201 generated tokens decode to "I'm here to help! How can I assist you? (I'm sorry, but you didn't specify what you needed help with. …)" and then repeat that parenthesised paragraph. `<|im_end|>` (151645) never appears in 201 generated tokens.
   - cpuAndGPU: first token id 9707 ("Hello"). The reply "Hello! I'm here to help with any questions you have. Just let me know what you need assistance with, and I'll do my best to assist you." ends with `<|im_end|>` at generated index 33. (The runner does not stop at `<|im_end|>`, so the model then writes a new turn; that continuation is not part of the claim.)
2. **The two settings disagree well beyond a rounding tie at the last prompt position.** (PROVEN.) From the full 151,936-value fp16 logit vector of the batched prefill call:
   - cpuAndNeuralEngine top two: id 40 at 21.7031, id 9707 at 21.5781 (margin 0.125).
   - cpuAndGPU top two: id 9707 at 22.7188, id 40 at 21.2812 (margin 1.4376).
   - Across all 151,936 values: max absolute difference 8.6895, mean absolute difference 1.37946, no non-finite pair.
   - Next-token winners disagree at 11 of the 28 prompt positions (0, 1, 2, 4, 8, 9, 13, 16, 24, 25, 27).
   - `<|im_end|>` rank at the last prompt position: 56,325 (ANE arm), 66,187 (GPU arm).
3. **cpuOnly returns NaN.** (PROVEN, 5 of 5 counted runs, the three dump files byte-identical.) Every one of the 151,936 prefill logits is NaN at every one of the 28 prompt positions. The infer path's first two calls return finite per-chunk maxima, and every call from the third on has a NaN chunk (30 of 32 calls), so no token is generated in the 4 decode steps run. Decode returns only the package's in-graph per-chunk maxima, so full logits exist only for the prefill call.

Each arm's own prefill agrees with its own infer path at the last prompt step (the infer chain's first generated token equals the prefill winner), so the split is between compute units, not between the package's two functions.

**What this does not show.** There is no reference (fp32, PyTorch, or the original Hugging Face Qwen2.5-1.5B-Instruct) in this record, so it does not say which of the ANE and GPU outputs is correct. The ANE arm's 0.125 margin makes its first token a near tie, but the GPU arm's first token is not a tie, and the full-vector differences above are far larger than one fp16 rounding step at these magnitudes. The cause of the divergence and of the cpuOnly NaN is UNKNOWN; SUSPECTED causes are fp16 overflow or LUT4 dequantisation behaving differently per backend. That ANE placement means ANE execution is INFERRED from the Core ML compute plan, not from a hardware execution trace. The plan counts come from `computePlanInfer` and `computePlanPrefill` in each counted run's `result_<arm>.json` and are the same in all 5 runs of each arm (infer: 2,147 ops preferred on the Neural Engine, 82 on the CPU; prefill: 2,360 and 13). The GPU arm's plan has 2,217 GPU / 12 CPU ops (infer) and 2,372 / 1 (prefill); the cpuOnly arm places every op it assigns on the CPU (2,229 infer, 2,373 prefill). In every arm, 4,022 infer and 4,735 prefill ops report no device usage.

## Method

- Runner: `spi/cleanroom/runners/qwen_dispatch_runner.swift` in `naytewilson/ane-re`, commit `543c3df3126b8adb973e0ae026d528624e3161ef`, rebuilt by the clean-room tool from `git show` with `xcrun swiftc -O -parse-as-library`. Prefill: one batched `prefill` call over the 28 prompt tokens with the full logit vector analysed at every position. Decode: the package's own `infer` function, fed the prompt one token at a time and then its own greedy choice, where the greedy choice is the largest of the 16 in-graph per-chunk maxima (`argmax_idx`, `argmax_val`, 9,496 tokens per chunk). The infer path exposes only those per-chunk maxima, not full logits.
- Dump: `prefill.json`, `logits-prefill-last.f16`, `chain.json`. They carry no timestamps or paths, so fresh-process runs can be byte-compared.
- Clean-room tool: `spi/cleanroom/cleanroom.swift` in `--control` mode, tool commit `246504e8df8d7ee957855e56f6936a46a9c39cee` (last commit touching the tool on main `99c08b13`). Each invocation builds once, runs every arm with the same binary, hashes the declared inputs before the build and after every arm, and writes `cleanroom-control-receipt.json`.
- Independent recompute: `qwen_dispatch_recompute.swift`, written from the metric definitions, not from the runner's code, re-derives 18 fields from the raw fp16 bytes and the recorded chunk maxima (logit file sha256, winner, NaN count, `<|im_end|>` logit, rank and margin, top-5 ids, prompt ids, every step's winner and NaN-chunk count, the token fed at every step, the generated ids, the first `<|im_end|>` index, the NaN step count). Every comparison is exact. Status EXACT on all 15 counted dumps (18 checks each for the ANE and GPU arms; 15 for cpuOnly, where the `<|im_end|>` rank, the winner logit and the margin are undefined because every logit is NaN). A negative test (`test_recompute_negatives.sh`) shows the tool returns NOT_EXACT for one flipped logits byte and for one edited chain winner.
- Text decode for this record only: the pinned Qwen2.5 tokenizer (`vocab.json` sha256 `ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910`, `merges.txt` `599bab54075088774b1733fde865d5bd747cbcc7a547c5bc12610e874e26f5e3`) through `tokdecode` (`c0fe236fee9d9b7b21fc69f4f6edf2f56000a29119a13bffbf9e3d3c5b4975cc`, source `TokDecode.swift` `15e58449c03c6f44c6b39fa647ab5436cae338615bbaf4de27e401891fdb3af6`). No claim depends on decoded text.

## Counted runs

Two profiles, both committed in `naytewilson/ane-re` at `8186ad8f4a75d18bdf74705b57f852a70bae01ce` (2026-11-12T14:16:32Z), before the first counted run (2026-11-12T14:16:47Z). The profile hash is sha256 of the canonical JSON of `git show 8186ad8f:<path>`, recomputed on the Dell with the hand-off tool's own `canonicalJSON`:

- `spi/cleanroom/profiles/qwen25-dispatch-ane-vs-gpu-20261112.json`: profileHash `9f2bd532c9beb961fb815639139503f5cbefed57bdca9a59111648ee2420604f` (raw file sha256 `b383bd0425461d6ac7373e062598bf1a3084f2ae5c1ec93133074d13cb2e9a33`, git object `b2169aae`). Arms `ane` (cpuAndNeuralEngine) and `gpu` (cpuAndGPU), 200 decode steps.
- `spi/cleanroom/profiles/qwen25-dispatch-cpuonly-20261112.json`: profileHash `3de33b648fff4b94ccdb2db407ececbf4b1f043f7ef72c544656bddef4716da1` (raw file sha256 `f6de70886e0dd5e2e8a40139a6f886ae429ad0c1b2eaec498a269b80e0607212`, git object `5f603ff6`). Arm `cpu` (cpuOnly), 4 decode steps.

Every invocation built the runner once from `git show 543c3df3` and ran every arm with that one binary (sha256 `b4f4a296a09873fbbd2f04f3461cee760b32d419f35de4ceda2c3b1e58e7143f` in all 10 receipts). The clean-room binary was built from `spi/cleanroom/cleanroom.swift` as it stands at `246504e8` (sha256 `21699f18…`, unchanged through `7d879697`); its own sha256 is `5e2ebe460548b907676dd5d1eb7d04fcd9ccf0f464fc2751a7f85a0312a8e60d`. The ledger counts one record per arm.

| Profile | Invocation | Arm | Dump digest | Wall s | Verdict | Ledger counted/total | Receipt self-hash |
|---|---|---|---|---|---|---|---|
| ane-vs-gpu | run-1 | ane / gpu | `b5853466…` / `06d8e3a3…` | 272 / 354 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 2/2 | `4b9b65e9f3c17523…` |
| ane-vs-gpu | run-2 | ane / gpu | `b5853466…` / `06d8e3a3…` | 277 / 160 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 4/4 | `f11c0ca974acd437…` |
| ane-vs-gpu | run-3 | ane / gpu | `b5853466…` / `06d8e3a3…` | 14 / 109 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 6/6 | `267193e11cf7e214…` |
| ane-vs-gpu | run-4 | ane / gpu | `b5853466…` / `06d8e3a3…` | 11 / 116 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 8/8 | `ddc9bd8cbf6bf84d…` |
| ane-vs-gpu | run-5 | ane / gpu | `b5853466…` / `06d8e3a3…` | 11 / 116 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 10/10 | `a2b49352f534bb4b…` |
| cpuonly | run-1 | cpu | `283fdefe…` | 371 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 1/1 | `3247936cca86816f…` |
| cpuonly | run-2 | cpu | `283fdefe…` | 283 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 2/2 | `ed32c557d2f9c28e…` |
| cpuonly | run-3 | cpu | `283fdefe…` | 278 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 3/3 | `f01589e3f6f68349…` |
| cpuonly | run-4 | cpu | `283fdefe…` | 272 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 4/4 | `9a5ae6b4e005b538…` |
| cpuonly | run-5 | cpu | `283fdefe…` | 274 | CONTROL_OK_SAME_BINARY_FROZEN_COUNTED | 5/5 | `52d8ae886564533b…` |

Full digests and self-hashes are in `verification/summary.json` and the receipts. Each arm's five dumps have one digest: ane `b5853466f77ce0570f2a601ad8a68398eca0adf84d44b906355bcbfb8354c47d`, gpu `06d8e3a3021ad103c060c8eb01e5f3ad54e2ed20d3b0486ffaff11546b458d14`, cpu `283fdefee563b0936a50b9b4b353cc3cb3ff2213afc8bd357a2cc539f44104f2`. Same-chip, same-binary: this is a determinism and dispatch result on one machine, not a cross-device replication.

## Execution log

Neo keeps one append-only device log per profile hash under `~/.local/state/anvil/execution-log/`. At packaging the directory holds ten files, all written on 2026-11-12, and the package carries all ten as they stand. The older log history on Neo was lost in an unrelated folder deletion on 2026-11-10, so nothing before that date is claimed from it.

- `9f2bd532….jsonl` (sha256 `8b5552b3afb41828c8f2e04bdc1f8c45440c8aa9c248a173dfb4fa30dba71dfb`): 20 lines, a `run_started` and a `run_completed` for each of the 10 counted arm runs above, all `counted: true`, profile commit `8186ad8f`, tool commit `246504e8`, every run exit 0. First arm start 2026-11-12T14:17:01Z.
- `3de33b64….jsonl` (sha256 `7659769c7e83a1992e829bfe51a17d67746ca3a5943a060afd2469e25d7e873e`): 10 lines, the same pair for each of the 5 counted cpuOnly runs, all counted, all exit 0. First arm start 14:42:11Z.
- `a77be2f6….jsonl` and `ae6fde7b….jsonl`: 2 lines each, from the test of the claim-scope fix (below). These are throwaway profiles in a throwaway repository, not this record's profiles.
- Six files of 2 lines each, from the three not-counted scratch runs that the reviewer probe `pr265-sub-01` makes every time it runs (it ran twice, see Verification): `cc5f3e20…`, `10b81835…`, `d457b7f7…` (2026-11-12T15:14:50Z to 15:14:55Z, tier at `7d879697`) and `87827a44…`, `19529cc5…`, `64ab19b4…` (15:17:33Z to 15:17:38Z, tier at PR #288's head). Each is `counted: false` under the probe's own scratch profile hash.

No line under either counted profile hash is missing from the table, and no other run was made under them. A search of every `.json` and `.jsonl` file under Neo's run, tool-state and log directories (`verification/hash-search.txt`) finds those two hashes only in the ten counted runs' receipts and freeze manifests, their two device logs, the clean-room tool's two profile-scoped ledgers (packaged under `ledger/`), the two build-only checks listed below (no run, no log line) and this record's own analysis summaries. Each invocation's freeze manifest hash differs (for example `0b36e81d…` for ane-vs-gpu run-1 and `999791d6…` for run-2) because the manifest records that invocation's own freeze time; the hashed inputs inside it are the same.

## Every attempt, in order

All times UTC, 2026-11-12. No experiment run was removed or rerun (the one rerun probe tier is described under Verification). Items marked "file times" come from file modification times, not from a log.

| Time | What | Counted | Outcome |
|---|---|---|---|
| 13:58:29 | Dev build of the runner from its pre-commit source (file times) | no | built |
| 13:59:43 to 14:01:37 | Dev smoke, cpuAndNeuralEngine, 16 steps, run directly (no clean-room, no log line; file times) | no | first ids 40, 2776, 1588, 311 |
| 14:02:03 to 14:04:02 | Dev smoke, cpuAndGPU, 16 steps (file times) | no | first ids 9707, 0, 358, 2776 |
| 14:04:45 to 14:13:44 | Dev smoke, cpuOnly, 16 steps (file times) | no | every winner -1, 42 steps with NaN |
| 14:16:08 to 14:16:21 | Clean-room build-only check of each profile (file times; build-only writes no log line) | no | both built |
| 14:16:32 | Profiles committed, `8186ad8f` | | |
| 14:16:47 to 14:42:02 | ane-vs-gpu runs 1 to 5 | yes | table above |
| 14:29:32 to 14:29:56 | Test of the claim-scope fix: two throwaway profiles, echo runner, during ane-vs-gpu run-2's ANE arm | no (own throwaway hashes) | both CONTROL_OK; 2 log lines each |
| 14:42:02 to 15:07:36 | cpuonly runs 1 to 5 | yes | table above |
| after 15:07 | Reviewer probe tiers (see Verification); the cleanroom tier's `pr265-sub-01` makes 3 not-counted scratch runs under its own scratch hashes | no | see Verification |

The dev smokes agree with the counted runs on every first token they share. Earlier receipts from 2026-11-07 and 2026-11-08 that first showed this behaviour are context only: they were not frozen under a committed profile and their device log was lost.

## Disclosures

1. **Stale claim-scope text in the counted receipts.** The clean-room tool at `246504e8` wrote a fixed layer-14 sentence ("Same-chip, same-binary CPU-vs-ANE layer-14 control…") into every `--control` receipt's `claimScope`, whatever the profile tested. All 10 counted receipts carry that sentence; it does not describe this experiment and no claim here rests on it. The fix (claim scope read from the profile, with a `claimScopeSource` field) is draft PR `naytewilson/ane-re#288`, made after the bug was found here. The counted runs were not repeated under the fixed tool, because the field is text only and does not enter any hash, verdict or measurement.
2. **Field name.** The receipt field `freeze.committedProfileBlobSha256` holds the canonical-JSON profile hash (equal to the profileHash above), not the sha256 of the raw file. This is the tool's documented meaning (`cleanroom.swift` line 721), not a mismatch; the raw-file hashes are listed under Counted runs.
3. **Commit author.** Commits `543c3df3` (runner) and `8186ad8f` (profiles) carry the author `Hyun-woo <hyunwoo@MiniMax.local>`, taken from a repository-local git setting in the clone they were made from, not from the person who made them. They are pinned by the counted receipts, so they were not rewritten. The analysis-tools commit `7d879697` carries the correct author.
4. **Concurrent load.** The claim-scope test runs (an echo runner, under 30 s) ran on the same machine during ane-vs-gpu run-2's ANE arm. That arm's dump is byte-identical to the other four.
5. **Wall times.** The cpuOnly and ANE-arm wall times vary with Core ML compile caches and machine load; they are recorded, not claimed.
6. **Analysis tools after the runs.** `qwen_dispatch_recompute`, `qwen_dispatch_compare` and the negative test were committed at `7d879697`, after the counted runs. They read the dumps and write nothing into the run directories.
7. **Publisher.** MacBrains Labs published the package this record finds a defect in.
8. **Review policy device scope.** The reviews are bound to the research-automation diagnostic-tier policy digest. That policy module fixes its expected device to the earlier layer-14 record (macOS 27.2 build 26B123, Core ML 3600.25.2), not to this machine (macOS 27.3 build 26C5035r, Core ML 3610.2.3), so its automatic eligibility check was not applied to this record. The device fields were instead checked against all 10 receipts, which agree with each other and with the claim. Updating the policy's device scope is for the reviewer.

## Verification

Every reviewer probe file in each area was run from a `git archive` of the exact commit, one line per file, and the full output is in `verification/`. A file marked superseded below is still run and its output kept; it is set aside only when its result equals the result the probe README or ledger records for it, so a change in a superseded probe's behaviour would show as a FAIL.

- **cleanroom** (`probes/cleanroom/`, 9 files, Neo): at ane-re `7d879697` (clean-room binary `d109a60e…`), 7 pass, 0 fail, 2 superseded. `pr265-sub-01` 41/0, `r1-01.v2` 23/0, `r1-02.v2` 7/0, `r2-01` 83/0, `r2-02` 9/0, `r3-01` 6/0, `r4-01` 18/0; the originals `r1-01` (14/8) and `r1-02` (3/2) gave exactly the counts the PR #265 ledger records for their superseded contract. The probe README has no cleanroom section yet; a proposal to add one is filed for the reviewer (`review-standards/proposals/v040-cleanroom-readme/`). The same 9 files at PR #288's head `5e98f68b` give the same 7/0/2. The first attempt at this tier passed relative paths, so the probes could not find the binary and nothing ran; it is kept as `verification/cleanroom-tier-first-attempt-relative-paths/` and not counted.
- **anerecore** (`probes/anerecore/`, 64 files, Neo, against a `git archive` of ane-re `7d879697`): 57 pass, 0 fail, 3 informational, 4 analysis tools (not run by any runner), 2 superseded. The pr264-B corpus differential ran over the v0.3.0 corpus (142 MIL copies plus 14 links to iCloud files that are not downloaded, which the probe counts as UNREADABLE) and passed all 16 corpus checks. A first run of this tier gave 56 pass and 1 fail: its rebuilt corpus left out the 14 not-downloaded links, so the corpus-count check did not see UNREADABLE=14. The corpus was rebuilt with those links pointing at the same files the v0.3.0 corpus lists and the tier was rerun; the first run is kept as `verification/anerecore-tier-run1-corpus-missing-14-links/`, and both corpus listings are in `verification/`.
- **diagnostic-tier** (Dell, research-automation `f042b510`): 24/24.
- **replication** (Dell, `f042b510`): 8/8.
- **intake, rerun, r4** (Dell, `f042b510`, every `*.test.mjs` in each folder): every current file passes (intake v3 49/49, reviewer A 10/10, reviewer B 9/9; rerun current files 6/6, 3/3, 9/9 plus 1 skipped where the legacy status copy is absent, 6/6, 2/2, 5/5; r4 current files all pass). Every file with a FAIL line is one the probe README names as superseded by a later version in the same folder (intake v1 and v2; rerun r1-A-queue, r1-B v1 to v4, r2-A v1 and v2, r2-B provenance-binding v1; r4A rerun-start-pin v1 and v2, ssh-trailer v2, v1-recompute-unpinned v1, r4B-1 v1). Per-file lines: `verification/dell-areas/summary.txt`.
- **handoff-event** (Dell, `f042b510`): 39/39 with `HANDOFF_EVENT_SRC` set to the archive's `src/`. A first run without it used the harness's default, a stale copy from 2026-11-06, and failed 8 probes; it is kept (`handoff-event.log`) and a proposal to make the variable required is filed with the cleanroom one.
- **Recompute**: EXACT on all 15 counted dumps. The negative test, run on a copy of one GPU-arm dump and one cpuOnly dump, gives EXACT for the unaltered copy and NOT_EXACT (17 of 18, 14 of 15) for one flipped logits byte and for one edited chain winner, in both arms (`analysis/negtest/`).
- **Preflight**: the three worktrees used (`ane-re` and `ane-re-tools` at `7d879697`, `ane-re-claimscope` at `5e98f68b`) show no changed, untracked or ignored files; `543c3df3`, `8186ad8f` and `246504e8` are ancestors of `7d879697`, which changes none of the runner, profile or clean-room tool files; the runner source at `543c3df3` hashes to the `sourceBlobSha256` in the receipts (`3c28c0b0…`); every file in `FILES.sha256` re-hashed; profile hashes recomputed on the Dell from `git show 8186ad8f` with the hand-off tool's `canonicalJSON`; freeze manifest time before the first arm start in all 10 receipts.

Not run: `fabric-mcp/` and `media-tier/` (other systems, not touched by this record) and the Neo zsh probes and deploy gates under `rerun/neo`, `r4/neo` and `r4/deploy-gates`, which test installed intake tools that this record does not use or change.

## Limitations

- One device, one chip, one OS build, one Core ML version, one prompt, one package revision. Same-chip only; not cross-device.
- No reference output, so neither non-NaN arm is shown correct.
- Decode is greedy over the package's in-graph per-chunk maxima; full logits exist only for the prefill call.
- ANE execution is INFERRED from compute-plan placement.
- Wall times are recorded in the receipts but not claimed. The ANE arm's first two invocations took 272 s and 277 s with cold Core ML compile caches (prefill load 81 s, infer load 54 s in run-1) and 11 to 14 s after that (loads under 1 s); outputs were byte-identical either way.
- The cpuOnly profile runs only 4 decode steps because each cpuOnly call takes about 10 s; its NaN claim covers those 4 steps and the 28 prompt steps.
