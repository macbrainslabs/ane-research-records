#!/usr/bin/env node
// Public distribution audit: GitHub release, its tag, Zenodo archive and DataCite.
// Validates actual downloaded bytes against the pinned source tree.
// This does NOT validate private ANE experimental measurements or independently repeat a benchmark.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  hashHex, parseSha256Sums, archiveListing, archiveMember, compareToGitTree
} from './publication-audit-lib.mjs';

const repo = 'macbrainslabs/ane-research-records';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
const tag = 'v0.1.0';
const releaseBase = `https://api.github.com/repos/${repo}`;
const archiveName = 'ane-research-records-v0.1.0.tar.gz';
const MAX_DOWNLOAD = 16 * 1024 * 1024;
const result = {
  schema: 'macbrainslabs.publication-audit.v1',
  checked_at_utc: new Date().toISOString(),
  source: { repository: repo, tag, site_commit: manifest.site_commit },
  checks: [],
  boundaries: {
    public_distribution_bytes: 'assessed',
    exact_public_git_tag_files: 'assessed',
    issuer_doi_metadata: 'assessed',
    private_raw_measurements: 'NOT_ASSESSED',
    numerical_model_correctness: 'NOT_ASSESSED',
    direct_ane_hardware_execution: 'NOT_ASSESSED',
    independent_human_replication: 'NOT_ASSESSED'
  }
};
const json = process.argv.includes('--json');
const outputs = process.argv.filter(a => a.startsWith('--report='));
assert.ok(outputs.length <= 1, 'only one --report argument permitted');
assert.ok(process.argv.slice(2).every(a => a === '--json' || a.startsWith('--report=')), 'Usage: node scripts/audit-publication.mjs [--json] [--report=PATH]');

async function retrieve(url, type='json') {
  const r = await fetch(url, {
    headers: { 'User-Agent': 'MacBrainsLabs-Publication-Audit/1.0', 'Accept': 'application/json' },
    signal: AbortSignal.timeout(25000)
  });
  assert.equal(r.status, 200, `${url}: HTTP ${r.status}`);
  const size = Number(r.headers.get('content-length') || 0);
  assert.ok(size <= MAX_DOWNLOAD, 'download too large');
  const body = Buffer.from(await r.arrayBuffer());
  assert.ok(body.length > 0 && body.length <= MAX_DOWNLOAD, 'invalid download length');
  return type === 'bytes' ? body : JSON.parse(body.toString('utf8'));
}
async function step(name, run) {
  const details = await run();
  result.checks.push({ name, result: 'PASS', ...(details || {}) });
  if (!json) console.log(`PASS ${name}`);
}

let tmp;
try {
  assert.equal(manifest.release_tag, tag, 'manifest release tag differs');
  assert.equal(manifest.version_doi, '10.5281/zenodo.23798037', 'unexpected version DOI');
  assert.equal(manifest.concept_doi, '10.5281/zenodo.23798036', 'unexpected concept DOI');
  let release, ref, tree, zenodo, datacite, ghArchive, sums, zenodoZip;
  await step('GitHub v0.1.0 published release and tag identity', async () => {
    release = await retrieve(`${releaseBase}/releases/tags/${tag}`);
    ref = await retrieve(`${releaseBase}/git/ref/tags/${tag}`);
    assert.equal(release.tag_name, tag);
    assert.equal(release.draft, false);
    assert.equal(release.prerelease, false);
    assert.ok(release.published_at);
    assert.equal(ref.object.type, 'commit', 'tag is not a direct commit ref');
    assert.equal(ref.object.sha, release.target_commitish, 'tag commit differs from release target');
    assert.match(ref.object.sha, /^[0-9a-f]{40}$/);
    result.source.tag_commit = ref.object.sha;
    return { tag_commit: ref.object.sha, published_at: release.published_at };
  });

  await step('Zenodo publisher record is published dataset with same DOI', async () => {
    zenodo = await retrieve('https://zenodo.org/api/records/23798037');
    assert.equal(zenodo.id, 23798037);
    assert.equal(zenodo.status, 'published');
    assert.equal(zenodo.doi, manifest.version_doi);
    assert.equal(zenodo.conceptdoi, manifest.concept_doi);
    assert.equal(zenodo.metadata.resource_type.type, 'dataset');
    assert.ok(zenodo.metadata.related_identifiers.some(x =>
      x.identifier === `https://github.com/${repo}/tree/${tag}`), 'no exact release source link');
    return { doi: zenodo.doi, concept_doi: zenodo.conceptdoi };
  });

  await step('DataCite DOI registration and version relationship', async () => {
    datacite = await retrieve('https://api.datacite.org/dois/10.5281/zenodo.23798037');
    const a = datacite.data.attributes;
    assert.equal(a.doi, manifest.version_doi);
    assert.equal(a.state, 'findable');
    assert.equal(a.types.resourceTypeGeneral, 'Dataset');
    assert.ok(a.relatedIdentifiers.some(x => x.relationType === 'IsVersionOf'
      && x.relatedIdentifier === manifest.concept_doi), 'missing concept DOI relationship');
    return { doi_state: a.state, type: a.types.resourceTypeGeneral };
  });

  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'macbrains-publication-audit-'));
  const tarPath = path.join(tmp, archiveName);
  const zipPath = path.join(tmp, 'zenodo-source.zip');
  await step('GitHub release asset SHA-256 and independent SHA256SUMS', async () => {
    const assets = release.assets;
    assert.deepEqual(assets.map(x => x.name).sort(), ['SHA256SUMS', archiveName].sort(),
      'unexpected release attachment inventory');
    for (const a of assets) assert.ok(a.browser_download_url.startsWith(
      `https://github.com/${repo}/releases/download/${tag}/`), 'unsafe asset URL');
    const asset = assets.find(x => x.name === archiveName);
    const sumsAsset = assets.find(x => x.name === 'SHA256SUMS');
    ghArchive = await retrieve(asset.browser_download_url, 'bytes');
    sums = await retrieve(sumsAsset.browser_download_url, 'bytes');
    assert.equal(ghArchive.length, asset.size);
    assert.equal(sums.length, sumsAsset.size);
    assert.equal('sha256:' + hashHex('sha256', ghArchive), asset.digest);
    assert.equal('sha256:' + hashHex('sha256', sums), sumsAsset.digest);
    const parsed = parseSha256Sums(sums);
    assert.equal(parsed.size, 1, 'unexpected checksum entries');
    assert.equal(parsed.get(archiveName), hashHex('sha256', ghArchive), 'release sum does not match archive');
    fs.writeFileSync(tarPath, ghArchive);
    return { archive_sha256: hashHex('sha256', ghArchive), sums_sha256: hashHex('sha256', sums) };
  });

  await step('Zenodo source ZIP MD5 matches actual published bytes', async () => {
    assert.equal(zenodo.files.length, 1, 'unexpected Zenodo attachment inventory');
    const z = zenodo.files[0];
    assert.equal(z.key, 'macbrainslabs/ane-research-records-v0.1.0.zip');
    assert.ok(z.links.self.startsWith('https://zenodo.org/api/records/23798037/files/'), 'unsafe Zenodo URL');
    zenodoZip = await retrieve(z.links.self, 'bytes');
    assert.equal(zenodoZip.length, z.size);
    assert.equal('md5:' + hashHex('md5', zenodoZip), z.checksum, 'Zenodo bytes differ from issuer MD5');
    fs.writeFileSync(zipPath, zenodoZip);
    return { zenodo_zip_md5: hashHex('md5', zenodoZip) };
  });

  await step('Exact public Git commit tree is not truncated', async () => {
    tree = await retrieve(`${releaseBase}/git/trees/${ref.object.sha}?recursive=1`);
    assert.equal(tree.truncated, false);
    assert.ok(tree.tree.length > 0);
    return { git_tag_commit: ref.object.sha, blob_count: tree.tree.filter(x => x.type === 'blob').length };
  });

  let ghFiles, zFiles;
  await step('GitHub release tarball matches every Git tag file byte-for-byte', () => {
    const members = archiveListing(tarPath, 'tar.gz');
    ghFiles = compareToGitTree(members, tree.tree,
      member => archiveMember(tarPath, 'tar.gz', member));
    return { matching_files: ghFiles.length };
  });
  await step('Zenodo archived ZIP matches every Git tag file byte-for-byte', () => {
    const members = archiveListing(zipPath, 'zip');
    zFiles = compareToGitTree(members, tree.tree,
      member => archiveMember(zipPath, 'zip', member));
    assert.deepEqual(zFiles, ghFiles, 'archive file content differs across providers');
    return { matching_files: zFiles.length };
  });
  result.ok = true;
} catch (err) {
  result.ok = false;
  result.error = String(err?.message || err);
  result.checks.push({ name: 'audit failure', result: 'FAIL', reason: result.error });
} finally {
  if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
}
if (outputs.length) {
  const reportPath = outputs[0].slice('--report='.length);
  assert.ok(reportPath, 'empty report path');
  fs.writeFileSync(reportPath, JSON.stringify(result, null, 2) + '\n', { flag: 'wx' });
}
if (json) console.log(JSON.stringify(result, null, 2));
else console.log(result.ok ? `PUBLIC DISTRIBUTION AUDIT PASS: ${result.checks.length} checks; raw measurements NOT ASSESSED`
  : `PUBLIC DISTRIBUTION AUDIT FAIL: ${result.error}`);
if (!result.ok) process.exitCode = 1;
