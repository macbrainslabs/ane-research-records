# ANERECore cross-repo MIL parity: `tap`, `steer` and `functionWide`

**MacBrains Labs ANE Research Records | candidate v0.3.0, corrected round-2 package | READY FOR REVIEW, NOT PUBLISHED**
**Observed 2026-11-05 to 2026-11-07 UTC | Disposition: READY_FOR_REVIEW | Scientific tier: diagnostic | Novelty: UNCLAIMED | Replication: same-chip**

No tag, version DOI or release exists for this record. The manager publishes only after the reviewer channel returns INCLUDE. This corrected round-2 package supersedes the held, unreviewed submission `ee23a1f3f093088351d41262c234710dfad99d4afc46098ed0ec8796187af77b`; round 1 `bf76dc26` was retired on B1 to B3. No additional reviewer round was opened.

## Claim (MIL text byte equality only)

On one Mac (`Naytes-MacBook-Neo.local`, OS-reported `hw.model=Mac17,5`, macOS build 26C5035r, Core ML 3610.2.3, `xcrun swiftc -O`), the clean-room tool rebuilt each implementation's ANERECore from `git show` of a pinned commit and ran it on the Qwen text fixture `tests/fixtures/qwen/model.mil` (sha256 `9c8dccb6900d2bf2be2be6a08cf78e38de3bb44aabddaaf7b53b0f3494d4c72f`). In every counted run of both arms, the three output files were byte-identical to the committed baseline index:

| Operation | Bytes | sha256 | Pin source |
|---|---:|---|---|
| `tap` | 2,061,448 | `295dd3b56f12505ba28e6a89e02fa4f8f8273ce3f5f3b2c0855b1f179957aad6` | attempt 0: Fugu and ANE-RE identical |
| `steer` | 2,061,794 | `e8dea18c9249ee025f460c61b6cb918d9c865658e1743aa5b65ecb9c7e05c5af` | attempt 0: Fugu and ANE-RE identical |
| `functionWide` (addReturn then replaceUses `.functionWide`) | 2,061,502 | `6739a5dde650770bdbea27fc1f2ebd4fc69808039f095d5769aaad8fe3ff27c7` | **Fugu-referenced**: Fugu's own output in attempt 2. Not an independent reference. |

The `functionWide` pin is Fugu's output, so a match on it shows that ANE-RE now agrees with Fugu, not that either is correct. The claim is limited to MIL text byte equality on this fixture, device and toolchain. It says nothing about Core ML compilation, Apple Neural Engine execution, numerics, other fixtures, or other ANERECore operations.

## Counted runs (both arms)

Each arm has its own profile, committed and pushed before its first counted run. Both profiles, the baseline index and the op list are in branch `feat/anerecore-v030-cleanroom-20261106` of `naytewilson/ane-re`, kept in the durable worktree `/Users/nayte/.local/share/anvil/anerecore-v030/ane-re` on Neo.

| | Fugu arm | ANE-RE arm |
|---|---|---|
| Profile | `spi/cleanroom/profiles/anerecore-v030-fugu.profile.json` | `spi/cleanroom/profiles/anerecore-v030-ane-re.profile.json` |
| Profile hash | `0959e19f8b1830426af347355b403f775cdac15c8f343f8d31778aa0cef7577c` | `84c276441ec23b090bc5db708d952ff70dc16dcfb77bfdd8c1d01e8a5305df97` |
| Profile commit | `017df3d17461150bcfa417c40dff05043da2ec6a`, 2026-11-07T05:55:50Z | `87cb836094c2c5c3d356ffefbe6bef369ff2249e`, 2026-11-07T09:02:05Z |
| First counted run | 2026-11-07T05:56:30.476Z (40 s after the commit) | 2026-11-07T09:34:43Z (32 min 38 s after the commit) |
| Source pinned | Fugu `f22c653ef4503d0cac9b8b0fd2d45f4f9a1bd473` (fugu `d9ea96bf` plus the committed driver; `Sources/ANERECore` tree equals fugu `5a435b21`) | ANE-RE `7a8bce4714d6984b843851c39e3a20e747dab01e` (main `c55e9e7d`, which holds the S2-g fix, merged into the clean-room branch) |
| Clean-room tool | `cleanroom-d485ad2e` (`--runs 5`, one freeze manifest) | `cleanroom-c55e9e7d` (one run per invocation, run index from the profile ledger) |
| Counted runs | 5 of 5 pass, 15 of 15 files identical | 5 of 5 pass, 15 of 15 files identical |
| Run dirs | `/Users/nayte/.local/share/anvil/anerecore-v030/runs/fugu-set/run-001` to `run-005` | `/Users/nayte/.local/share/anvil/anerecore-v030/runs/ane-re-set/run-001` to `run-005` |
| Receipt (`receiptSelfHash` field, not the file sha256) | set receipt `fugu-set/set-receipt.json`: `5b71fbf88f6f957dbc27548fb5c3e5e743a611ea7a794c12e2f422a24ba26c98` | one receipt per run, `ane-re-set/run-00N/cleanroom-receipt.json`: `670b22cd…`, `6c58e563…`, `82de1491…`, `78d09425…`, `7965cd76…` |

Across the two arms, each of the 25 run pairs gave the same three files: 75 of 75 file comparisons byte-identical (`cmp`). The input hashes recorded before and after the ANE-RE set match (`ane-re-set/ane-re-set-inputs-before.txt`, `ane-re-set/ane-re-set-inputs-after.txt` in the package).

Pass rule (frozen in each profile): a run passes when all three output files are byte-identical to the baseline index. Every run is counted, pass or fail.

## Execution log

Every clean-room run, counted or not, appends a `run_started` line before the runner starts and a `run_completed` line after it, to the device-wide append-only log `~/.local/state/anvil/execution-log/<profileHash>.jsonl` on Neo (one `write(2)` on an `O_APPEND` descriptor, then `F_FULLFSYNC`). For this record:

- Fugu profile `0959e19f…`: 10 lines, 5 started and 5 completed, 2026-11-07T05:56:30.476Z to 05:57:57.169Z. No other lines.
- ANE-RE profile `84c27644…`: 10 lines, 5 started and 5 completed, run starts 2026-11-07T09:34:43Z to 09:36:20Z, every line `counted=true`, `profileCommit=87cb8360`, `inputsUnchanged=true`, `passed=true`. No other lines. The device log went from 848 to 858 lines.
- Three scratch profiles (`7610312c…`, `7c0a3a9b…`, `99ff6f49…`): 6 lines at 2026-11-07T07:42:20Z to 07:42:24Z. These were the not-counted part-B tests of the input-hash gate (PR #265), run with `--allow-unfrozen` under their own scratch ids. They touched no file of either arm.
- Build-only checks write nothing to the log. The device log held 848 lines before every build-only check of this round and after it.

## Every attempt, in order

| # | When (UTC) | What ran | Result |
|---|---|---|---|
| 0 | 2026-11-05 22:54:32 to 22:55:00 | Fugu PR #6 harness, unmodified, ANE-RE `2c52b410`: `tap`, `steer` once each | PASS, both byte-identical |
| 1 | 2026-11-05, about 22:57:58 (file mtime; INFERRED) | First functionWide supplemental driver (`7992c9e2…`) | FAIL_INVALID_TEST_FIXTURE_DUPLICATE_PRODUCER: the driver built an invalid program. Excluded from parity, kept here. |
| 2 | 2026-11-05 22:58:11 to 22:58:30 | Corrected supplemental (`b7636212…`), ANE-RE `2c52b410` | MISMATCH: Fugu `6739a5dd…`, ANE-RE `837d7cc4…` (dangling return tuple) |
| 3 | 2026-11-05 23:00:45 to 23:01:08 | ANE-RE `2c52b410` plus an isolated patch | functionWide PASS; not committed |
| 4 | 2026-11-06 04:12:10 to 04:17:35 | Round-1 profile `19ad531c…` (`run-20261106-01`), script `replicate.sh`, ANE-RE `b8f9b3b7`, 5 runs x 3 ops | 15/15 PASS. **Not counted in this round**: the profile was hashed and made read-only but never committed (round-1 blocker B1), and the script kept no device-wide log (B2). |
| 5 | 2026-11-07 05:56:30 to 05:57:57 | Fugu arm, profile `0959e19f…`, tool `d485ad2e` | 5/5 PASS (counted) |
| 6 | 2026-11-07 09:34:43 to about 09:36:30 | ANE-RE arm, profile `84c27644…`, tool `c55e9e7d` | 5/5 PASS (counted) |

Builds that ran no runner and wrote no log line: a build-only check of a Fugu-profile id-variant (`DRYBUILD`, hash `3119acd1…`, not in git) and one of an ANE-RE-profile id-variant (`scratch-buildcheck-…`). A rebuilt runner binary differs from the profile's `baselineRunnerSha` in both arms (the binary depends on the build path), so the verdict is judged on the output files only.

## How ANE-RE was fixed

- PR #262 (merged as `84f86340`) fixed the dangling return tuple for `replaceUses(.functionWide)`.
- PR #263 (merged as `b8f9b3b7`) fixed bugs found in #262's review (renamed argument and attribute keys and op type tokens, output order in `renameVar`, dropped staged edits, skipped sha256 pins on Linux). Its round-2 fixes included S2. **Correction to round 1:** the round-1 record said S2 was "confirmed by both reviewers". That was wrong. The S2 fix covered an argument key on the next line, but reviewer A's probe `pr263-A-r3-08` still failed on two operations on one line (S2-g). S2-g was fixed in PR #264 (head `3e69af8a`, merged as `5555c15e`, 2026-11-07T08:11:01Z).
- PR #265 (merged as `1e7101af`) made the clean-room tool hash the declared inputs before the build and after every run. PR #266 (merged as `c55e9e7d`) made `--control` dump records fail on a dangling symlink, a symlink to a directory or a special file.
- The pinned commit `87cb8360`, run from a fresh `git archive` on Neo: full suite `ALL TESTS PASS` (existing log sha256 `076f3220…`, finished 09:05:10Z). Corrected **full anerecore tier 57 pass, 0 fail** of 57 counted checks, finished 2026-11-07T11:02:41Z; corrected summary sha256 `a398c45e716b7703c527f07d7e29541e0ec474c436ed0e78fc2bc451347d18ec`. The round-1 S2-g test `pr263-A-r3-08` passes.
- The original 56/57 run failed `pr264-A-r2-05-real-mil-no-false-reject` on five deliberately body-less declarations: `m001`, `m002`, `m004`, `m005`, `m007`. Their original error `MILParseError.functionWithoutBody` also occurs on base `09177138` with no per-file difference. Unmodified reviewer probes A-10 and B-06 require those **five negative controls** to fail parsing and continue to pass. In the corrected runner, ONLY r2-05 no longer inherits a directory containing invalid declarations, while its positive input file covers all other readable corpus files plus existing real-model paths. It passes on 243 distinct real-MIL inputs. The reviewer probes, ANE-RE source and both committed clean-room profiles are unchanged. See `verification/INPUT_SELECTION.md`; corrected real-MIL list sha256 `28c95741213cbb2ea2df779fd97d4ac8e0f6141de39c25af8bc904ac6b9e0533`. This is a documented input-selection correction, not a parser fix or a weakening of a probe.
- The initial full tier had 54 pass / 3 fail without the two required reference builds (summary `db4e8af9…`). Re-running with the references gave **56 pass / 1 fail**, summary `1fe7c75e…`. The final corrected *full* tier with the references and the input-selection fix gives **57 pass / 0 fail**. All three result generations are retained as evidence; none is silently reclassified as having passed.
- Durable copies (N1): the tier's probe files, its runner and the readable part of its corpus are copied to `/Users/nayte/.local/share/anvil/anerecore-v030/verify/tier-inputs` (file list with hashes: `verification/tier-inputs.sha256`, sha256 `421b17e6…`, in the package). 14 of the corpus's 156 files could not be copied or read: their link targets are iCloud files that macOS has evicted to the cloud (`dataless`), and reading them from this shell fails with `EDEADLK`. Every corpus probe already lists those 14 as UNKNOWN and does not test them (`verification/corpus-unreadable.txt`). Some probes also read corpus files outside that folder; those were not copied.

The corrected probe runner and complete r2-05 input list, selected fixture hashes, and new probe outputs are packaged. No new counted replication run was made because the source and profiles were not modified; the earlier 5/5 per arm, device-wide execution log, and source pins remain authoritative. The 14 unreadable iCloud-dataless files remain UNKNOWN.

## Limitations

- One device, one chip, one OS build, one toolchain, one fixture, three operation sequences. Same-chip only.
- MIL text only: no Core ML compile, no ANE execution, no numerical or model-output parity.
- The `functionWide` pin is Fugu-referenced, so it checks agreement with Fugu, not correctness.
- The two arms used different builds of the clean-room tool. `d485ad2e` is on a Neo-local branch (`feat/cleanroom-runs-set-20261103`) that is not on GitHub, and it checks only that the inputs exist; the Fugu-arm input hashes were recorded at 05:56:05Z, before its first run, and again at 09:37:36Z, after both arms ran; they match (`fugu-set/fugu-set-inputs-before.txt`, `fugu-set/fugu-set-inputs-after.txt` in the package). `c55e9e7d` is on ANE-RE main and checks the input hashes itself before the build and after every run. The `toolCommit` field in the execution log names the last commit that touched the tool source: `d485ad2e` for the Fugu arm, `0ae0b6d7` (PR #266, part of main `c55e9e7d`) for the ANE-RE arm.
- Attempt 1's time is inferred from file modification time. Attempts 0 to 4 are not counted.
