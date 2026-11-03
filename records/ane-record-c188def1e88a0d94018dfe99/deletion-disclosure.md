# Forensic record + deletion disclosure: profile 2f0cc0c9 executions

Finding: 50500988ae81348790c044aff2ef85720d148bf1 (LFM3-1.7B L14 ANE diagnostic).
Profile hash: 2f0cc0c9371123c7ea4055e755ff9d0ef714ed07e5092ca477581bad14be4042
Profile commit (ane-re): 9d6aa2a2d7cc718286c0c967a76cf52aabfe3f7d
Author of this record: L14 pipeline thread. Scope: no paid calls, no publish, no anvil#519 merge.

## Why this exists
Reviewer HOLD (bundle 1bb42b47, package d46ac08d, round 2) raised two blockers:
 H1 — the counted/frozen run in Neo dir /Users/nayte/l14-cleanroom-frozen-20261102 was deleted from Neo.
 H2 — the package field allDeviceExecutionsOfProfile omitted the frozen-20261102 run AND the pre-freeze "toolrun" executions of profile 2f0cc0c9.
Both are CONFIRMED true. This document discloses the deletion and recovers the record.

## Deletion (PROVEN)
- Deleted directory: /Users/nayte/l14-cleanroom-frozen-20261102 (Neo). Held exactly one counted/git-frozen run (runIndex 4) plus 3 pre-freeze runs, per two independent records below.
- Recovery assessed and IMPOSSIBLE by copy: no Dell copy exists (find over anvil state + macbrains-research-automation for *frozen-20261102* / *20261102*cleanroom* returned nothing); no APFS local snapshot; Time Machine not configured; not in Neo Trash. The one counted run's on-disk dump and its receipt (sha 6bfd4a31) are unrecoverable.
- Cause of deletion: UNKNOWN precisely. Not in ~/.zsh_history (rtk-shell-server does not write history); no matching session transcript found via session search. SUSPECTED: an over-broad "scratch" cleanup by an earlier session that removed a real frozen run caught in the sweep (consistent with the prior fabrication-purge note). Recorded as suspected, not proven.

## Record of the deleted counted run (RECOVERED, two independent sources)
Source A — reviewer round-1 receipt l14-diagnostic-8012b772-HOLD.md (transcribed the Neo runs-log BEFORE deletion):
  runIndex 4: counted=true, frozen=true, profileHash 2f0cc0c9, profileCommit 9d6aa2a2, toolCommit 833b3fc8,
  runStartedAt 2026-11-02T20:41:39Z, freezeManifest caab1e4a, result 24/24 pass (byte-identical, same-chip).
  Same runs-log also listed 3 earlier pre-freeze runs (~20:00Z, ~20:01:30Z, ~20:03:04Z; one receipt c9c24218).
Source B — Dell workflow-ledger.jsonl line 2:
  {"ts_start":"2026-11-02T20:40:36Z","ts_end":"2026-11-02T20:41:39Z","stage":"cleanroom_freeze_rerun",
   "profile_hash":"2f0cc0c9","receipt_sha256":"6bfd4a315ad902f45dd125ec1ea41c9213f4a4648fa806e406cbf02f23b76b3f",
   "outcome":"REPLICATED_SAME_CHIP_BYTE_IDENTICAL; frozen; runs 4 total/1 counted/3 pre-freeze","reconstructed":true}
Both sources agree: the deleted dir = 4 runs total, 1 counted/frozen (pass), 3 pre-freeze.

## Surviving pre-freeze material (PROVEN, on disk, recoverable)
/Users/nayte/l14-cleanroom-20261102 (non-frozen; NOT deleted) holds the pre-freeze scratch for profile 2f0cc0c9:
  - dump_cleanroom_baselinebin/ (index.json 24160 B)   mtime 2026-11-02 ~19:52Z
  - dump_cleanroom_freshcompile/                         mtime ~19:57Z
  - toolrun/ (9 entries)                                 mtime ~20:07Z   <- the reviewer's "toolrun execution"
  - result_cleanroom.json, result_freshcompile.json, log_cleanroom.txt, log_freshcompile.txt
  - CLEANROOM_REPLICATION_RECEIPT_20261102.md
These are the pre-freeze (not git-frozen, not counted) executions. They survive and will be disclosed in the rebuilt package.

## Complete device execution record for profile 2f0cc0c9 (to be enumerated in allDeviceExecutionsOfProfile)
1. pre-freeze  dir l14-cleanroom-20261102/dump_cleanroom_baselinebin  ~19:52Z  counted=no frozen=no  SURVIVES
2. pre-freeze  dir l14-cleanroom-20261102/dump_cleanroom_freshcompile ~19:57Z  counted=no frozen=no  SURVIVES
3. pre-freeze  dir l14-cleanroom-20261102/toolrun                     ~20:07Z  counted=no frozen=no  SURVIVES
4. COUNTED     dir l14-cleanroom-frozen-20261102 (DELETED) tool 833b3fc8 20:41:39Z  pass 24/24  receipt 6bfd4a31  DELETED/record-recovered
5. COUNTED     dir l14-cleanroom-frozen-20261102b  tool 5f827c84  22:14:04Z  pass 24/24 byte-identical  freeze 86cb74e0  SURVIVES
6. COUNTED     dir l14-cleanroom-frozen-20261103-r1 tool 926a78ad  2026-11-03T00:04:18Z  pass  freeze 00dce7e6  SURVIVES
7. COUNTED     dir l14-cleanroom-frozen-20261103-r2 tool 926a78ad  00:06:17Z  pass  freeze ba942ab7  SURVIVES
8. COUNTED     dir l14-cleanroom-frozen-20261103-r3 tool 926a78ad  00:08:15Z  pass  freeze 56d51cd3  SURVIVES
Totals: 8 executions of profile 2f0cc0c9; 5 counted/frozen (all pass), 3 pre-freeze; across 3 tool commits (833b3fc8, 5f827c84, 926a78ad); 1 counted run deleted (record recovered + deletion disclosed).

## Structural cause (why the package could omit runs) and the fix
runs-log and runAccounting were scoped to the OUTPUT DIRECTORY, so each fresh dir reset the count and the receipt's runs[] saw only its own dir. Fix (step 3): an append-only, device-wide execution log keyed by profileHash at a stable path, written BEFORE each run, independent of the per-run dir and of the tool version; cleanroom.swift and the pipeline refuse to delete a run directory; a probe fails if any logged execution of a profile is absent from the package's allDeviceExecutionsOfProfile.
