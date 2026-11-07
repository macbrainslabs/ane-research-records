# ANERECore v0.3.0 round-2: pr264-A-r2-05 real-MIL selection

This evidence repairs the **verification inputs**, not the MIL parser or reviewer probe. No ANE-RE source commit or counted clean-room profile changed.

## Root cause
The original tier runner exported `PR264A_CORPUS` for **all** reviewer probes, including `pr264-A-r2-05-real-mil-no-false-reject`. Reviewer A explicitly defines r2-05 over **real MIL** input files. The shared reviewer-B corpus contains five intentionally body-less function *declarations* without executable `{ ... }` bodies, which the parser correctly refuses with `MILParseError.functionWithoutBody`:

| Negative control | SHA-256 |
| --- | --- |
| m001.mil | d2541948ba69776f36f0d13d048ec4448668422d9d9fcad8964ff9f13e351e2b |
| m002.mil | 7a23a1493036e7971669c794713473f457508a6568af25aa4b1704b9ee037d35 |
| m004.mil | 300efca3e76ead05d60e8a4cbf954c6839dc273d9da007bbe6858dea37d20ab3 |
| m005.mil | 77dbf502ed7ca27209b6e051739575e05cf569c2836e81dcdb84941aebf29997 |
| m007.mil | 7c4ff4c5c4d4e3c77c625328b4359eb2e505a42daff4d86faf854bdc74cc3d03 |

The base parser also produces those same five `functionWithoutBody` errors (baseline r2-05 run under `realmil-base/out-full.txt`, `-D NOCOLS`). Reviewer A's unchanged `pr264-A-10-corpus-real-artifacts` and reviewer B's unchanged corpus differential **require** all five to be rejected, and they pass.

## Narrow correction
The new runner differs from the prior runner in only three explanatory lines and one scoped environment change: immediately before executing **r2-05 only**, `unset PR264A_CORPUS`. Every other probe continues receiving the original full reviewer-B corpus (including all negative controls). The new `realmil-validated.txt` supplies all original real-model paths plus the **137 other readable** reviewer-B corpus files. The five body-less controls are *not* included in this positive input list, but **remain exercised** as expected failures in the A-10 and B-06 corpus probes. Neither probes nor production source were modified.

The original reviewer-B corpus has 156 files: 142 readable (5 malformed body-less declarations, 137 additional files), plus 14 iCloud-dataless files whose contents cannot presently be read. Those 14 remain explicitly UNKNOWN; no claim is made about them.

The corrected tier is executed on Neo from a freshly extracted `git archive` of source commit `87cb836094c2c5c3d356ffefbe6bef369ff2249e`, with baseline reference builds for B differential probes. Artifacts include the complete unchanged reviewer probe files, corrected runner, input-list, per-probe stdout/build logs, and complete summary. The earlier failed tier and its logs remain preserved.

## Scientific and process limitation
A passing corrected tier demonstrates that no *parseable real MIL among the tested readable inputs* was falsely rejected. It does not prove general Core ML compatibility or validate 14 unavailable iCloud placeholders. Reviewer should evaluate the documented positive/negative corpus selection, not be told the parser was repaired. No new clean-room counted runs are required because the source/profiles never changed; both previously committed five-run arms remain unchanged.
