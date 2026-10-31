# Public evidence audit: what is actually verified

This repository contains **curated summaries of previously reported ANE/Core ML experiments**. It does not release private raw tensors, model weights, compiled model packages, full timing logs or the full experimental notebooks. No audit here can reconstruct those missing measurements.

## Run the checks

Requires Node.js 22+, `tar`, `unzip`, and (for the offline corruption tests) `zip`. Uses no dependencies, credentials, private model files or paid services.

```sh
node scripts/verify.mjs
node scripts/verify.mjs --upstream
node --test tests/publication-audit.test.mjs
node scripts/audit-publication.mjs --json
```

The upstream check reads the four exact website files from the source commit pinned in `manifest.json`, computes their SHA-256 hashes, and requires them to equal the manifest. This proves the **public source texts are bound to the manifest**. It does not independently reproduce their empirical claims.

The new publication audit fetches the *actual* v0.1.0 GitHub release, Git tag ref and recursive source tree, release attachments, Zenodo's **published** record and ZIP, and DataCite's DOI registration. It checks:

1. The GitHub release is published and its tag ref is the expected commit.
2. Zenodo describes the same released dataset and version/concept DOI.
3. DataCite reports a findable Dataset DOI and correctly links the version to its concept DOI.
4. Downloaded GitHub release asset SHA-256 hashes match both GitHub's asset digest and the distributed `SHA256SUMS`.
5. Downloaded Zenodo source archive matches the issuer's declared MD5 checksum.
6. Every file in both downloaded archives matches the exact v0.1.0 Git tree by Git blob identity. The audit also compares per-file SHA-256 digests across the two archives.
7. The offline unit tests reject altered content, missing or extra files, path traversal, malformed checksums and synthetic archive tampering.

The v0.1.0 release is deliberately audited **at its original tagged commit**, not today's `main`. The subsequent DOI and `.zenodo.json` edits to `main` cannot retroactively change the original archived version.

The online audit prints machine-readable JSON with `--json`. Save a non-overwriting snapshot with `--report=/absolute/path/to/new-receipt.json`. Snapshots are dated observations, not proofs that external services will always remain online. The existing GitHub Actions workflow executes the deterministic offline corruption tests on pushes and PRs. Its **Run workflow** action executes the cross-provider online audit on demand; an unavailable provider is a failed/inconclusive audit, never silently treated as a pass.

## Claims and their verification boundaries

| Question | Evidence available here | Status |
| --- | --- | --- |
| Are the public summary files internally consistent? | Existing `scripts/verify.mjs` | **Testable** |
| Do the source hashes match the four pinned public site documents? | `verify.mjs --upstream` | **Testable online** |
| Do GitHub and Zenodo publish the exact same tag source files? | `audit-publication.mjs` | **Testable online** |
| Is the specific dataset DOI registered and typed as a Dataset? | Zenodo + DataCite API responses | **Testable online** |
| Did the Qwen/ANE or LFM numerical experiments really produce these values? | Underlying raw measurements and model fixtures are not included | **NOT ESTABLISHED** |
| Did all operations physically execute on the ANE? | Core ML MLComputePlan assignments are not physical hardware tracing | **NOT ESTABLISHED** |
| Are throughput values correctness-qualified full-model generation rates? | Reported probe output quality was not validated | **NOT ESTABLISHED** |
| Has an outside person independently replicated the experiments? | No third-party replication receipt provided | **NOT ESTABLISHED** |

**Do not refer to archive equivalence, DOI registration, AI code review, or the internal summary checker as independent scientific replication.** The checks establish public artifact provenance and transcription integrity. Hardware-bound correctness requires separate original evidence and explicit qualification before any public promotion.

## First useful future expansion

When a *shareable* experiment is available, add one minimal self-contained reproduction package: exact source and toolchain, original model or public redistributable fixture, pinned input and expected output, a run script, versioned hardware/OS details, a numerical tolerance policy and raw machine-readable measurements. Run it on the identified compatible Apple device before claiming numerical or hardware acceptance. Avoid publishing private weights, internal service data, credentials or proprietary raw captures.

This is an engineering gate, not a prerequisite for maintaining the existing citable research-summary release.
