#!/usr/bin/env node
// MacBrains Labs public-data consistency verifier. No external dependencies.
// It validates transcription and source fingerprints, NOT privately held raw experiments.
import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const manifest = JSON.parse(fs.readFileSync('manifest.json', 'utf8'));
const lines = [];
let count = 0;
function check(label, f) {
  try { f(); count++; lines.push('PASS ' + label); }
  catch (e) { console.error('FAIL ' + label + ': ' + e.message); process.exitCode = 1; }
}
function csv(p) {
  const s = fs.readFileSync(p, 'utf8').trim().split(/\r?\n/);
  const header = s.shift().split(',');
  return s.map(line => Object.fromEntries(line.split(',').map((v,i) => [header[i],v])));
}
// Later versions are listed in records/index.json; v0.1.0 (manifest.json) is the baseline.
const INDEX = fs.existsSync('records/index.json') ? JSON.parse(fs.readFileSync('records/index.json','utf8')) : null;
const semver = v => { const m=/^v(\d+)\.(\d+)\.(\d+)$/.exec(v||''); assert.ok(m,'bad version '+v); return m.slice(1).map(Number); };
const cmpVer = (a,b) => { const x=semver(a),y=semver(b); return x[0]-y[0]||x[1]-y[1]||x[2]-y[2]; };
const LATEST = INDEX && INDEX.records.length ? [...INDEX.records].sort((a,b)=>cmpVer(a.version,b.version)).at(-1) : null;
const canonicalJSON = v => v===null||typeof v!=='object' ? JSON.stringify(v) : Array.isArray(v) ? '['+v.map(canonicalJSON).join(',')+']' :
  '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonicalJSON(v[k])).join(',')+'}';
const sha256 = s => crypto.createHash('sha256').update(s).digest('hex');
function n(v) {const x=Number(v);assert.ok(Number.isFinite(x), 'non-finite number');return x;}
function eq(a,b){assert.equal(a,b);}
const P = csv('data/qwen-placement.csv'), S = csv('data/qwen-state-primitives.csv'), L = csv('data/lfm-s2-parity.csv'),
  D = csv('data/lfm-s2-diagnostic.csv'), B = csv('data/qwen-batch-throughput.csv');
check('Pinned source revision and four document hashes', () => {
  assert.match(manifest.site_commit, /^[0-9a-f]{40}$/);
  eq(Object.keys(manifest.source_files).length,4);
  for(const [path,obj] of Object.entries(manifest.source_files)) {
    assert.ok(!path.includes('..'));
    assert.match(obj.sha256,/^[a-f0-9]{64}$/);
    assert.ok(obj.url.startsWith('https://macbrainslabs.org/'));
  }
});
check('Qwen 28L MLComputePlan operator partition', () => {
  eq(P.length,1);eq(P[0].compiled_function,'infer');
  eq(n(P[0].ane_assigned_ops),2090);eq(n(P[0].cpu_assigned_ops),79);
  eq(n(P[0].total_assigned_ops),n(P[0].ane_assigned_ops)+n(P[0].cpu_assigned_ops));
  assert.ok(Math.abs(2090/2169*100 - 96.4)<0.1);
  eq(P[0].placement_evidence,'MLComputePlan');
});
check('Qwen state operations are all assigned ANE, 394 total', () => {
  eq(S.length,4);
  const state = Object.fromEntries(S.map(r=>[r.primitive,[n(r.ane_assigned_ops),n(r.cpu_assigned_ops)]]));
  eq(state.slice_update[0],56);eq(state.read_state[0],57);eq(state.write_state[0],56);
  eq(state.slice_by_index[0],225);
  eq(Object.values(state).reduce((x,v)=>x+v[0],0),394);
  eq(Object.values(state).reduce((x,v)=>x+v[1],0),0);
});
check('LFM sealed production 743/743 and both parity gates', () => {
  eq(L.length,2);eq(new Set(L.map(r=>r.output)).size,2);
  eq(L[0].output,'lfm_h_after_liv');eq(L[1].output,'lfm_h_after_gqa');
  for(const row of L) {
    eq(row.artifact,'sealed_LFM_S2_production');eq(n(row.ane_assigned_compute_ops),743);
    eq(n(row.total_compute_ops),743);
    assert.ok(n(row.ane_cosine_against_fp16_fixture)>=0.999);
    assert.ok(n(row.ane_relative_l2_against_fp16_fixture)<=0.03);
    eq(row.passes_declared_ane_gate,'true');
  }
  eq(n(L[0].ane_relative_l2_against_fp16_fixture),0.017295585);
  eq(n(L[1].ane_relative_l2_against_fp16_fixture),0.027863104);
});
check('Distinct diagnostic graph; only two examples are disclosed', () => {
  eq(D.length,2);
  eq(D[0].output,'liv_14_mlp_output');eq(D[1].output,'gqa_15_head_merge');
  for(const row of D) {
    eq(row.artifact,'LFM_PARITY_DEBUG_46_outputs');
    assert.ok(n(row.ane_relative_l2_against_fp16_fixture)>0.03);
    assert.ok(!L.some(x=>x.output===row.output));
  }
  assert.ok(fs.readFileSync('README.md','utf8').includes('34/46'));
});
check('Qwen real-batch aggregate throughput and rounded relative factors', () => {
  eq(B.length,4);eq(B.map(x=>x.batch_size).join(','),'1,2,4,8');
  eq(B.map(x=>x.aggregate_tokens_per_second).join(','),'45.4,68.1,102.1,125.8');
  for(const row of B) {
    eq(row.device,'A18 Pro');
    assert.ok(Math.abs(n(row.reported_relative_to_b1)-n(row.aggregate_tokens_per_second)/45.4)<0.011);
    assert.ok(row.measurement_type.includes('five-round'));
  }
});
check('DOI metadata consistency and private evidence limits', () => {
  assert.ok(manifest.doi_status.startsWith('issued;'));
  assert.strictEqual(manifest.version_doi, '10.5281/zenodo.23798037');
  assert.strictEqual(manifest.concept_doi, '10.5281/zenodo.23798036');
  assert.strictEqual(manifest.release_tag, 'v0.1.0');
  assert.strictEqual(manifest.zenodo_record_url, 'https://zenodo.org/records/23798037');
  // CITATION.cff cites the newest version: the baseline DOI until a later record
  // exists, then that record's version DOI, or none while Zenodo is still minting it.
  const cff=fs.readFileSync('CITATION.cff','utf8');
  const citedDoi=(cff.match(/^doi: "([^"]+)"$/m)||[])[1]||null;
  const citedVersion=(cff.match(/^version: "([^"]+)"$/m)||[])[1];
  if(!LATEST){ eq(citedDoi, manifest.version_doi); eq(citedVersion, manifest.release_tag.slice(1)); }
  else { eq(citedDoi, LATEST.versionDoi||null); eq(citedVersion, LATEST.version.slice(1));
    assert.ok(cff.includes('value: "'+manifest.concept_doi+'"'),'CITATION.cff must carry the concept DOI'); }
  const readme=fs.readFileSync('README.md','utf8');
  assert.ok(readme.includes('raw measurement output') && readme.includes('**not** raw measurement output'));
  assert.ok(readme.includes('not direct silicon tracing')||readme.includes('not direct ANE hardware tracing')||readme.includes('not direct silicon tracing'));
  assert.ok(readme.includes('not a complete reproducibility bundle'));
  assert.ok(readme.includes('Zenodo DOI'));
  assert.ok(readme.includes('https://doi.org/' + manifest.version_doi));
  assert.ok(readme.includes('https://zenodo.org/badge/DOI/' + manifest.version_doi + '.svg'));
  assert.ok(readme.includes('https://doi.org/' + manifest.concept_doi));
});
check('Zenodo deposit metadata agrees with CITATION.cff', () => {
  // Zenodo reads .zenodo.json (not CITATION.cff) when the next GitHub release
  // mints a version, so the two must not drift apart.
  const zj=JSON.parse(fs.readFileSync('.zenodo.json','utf8'));
  const cff=fs.readFileSync('CITATION.cff','utf8');
  const field=k=>{const m=cff.match(new RegExp('^'+k+': "?([^"\n]*?)"?$','m'));assert.ok(m,'CITATION.cff missing '+k);return m[1];};
  eq(zj.title,field('title'));
  eq(zj.upload_type,field('type'));
  eq(zj.license,field('license').toLowerCase());
  const orcid=(cff.match(/orcid: "https:\/\/orcid\.org\/([0-9X-]+)"/)||[])[1];
  assert.ok(orcid,'CITATION.cff missing author ORCID');
  eq(zj.creators.length,1);eq(zj.creators[0].orcid,orcid);eq(zj.creators[0].name,'Wilson, Nayte');
  assert.ok(zj.description.includes('not independently replicated')||zj.description.includes('have not been independently replicated'));
});
// Diagnostic-tier records republish the reviewed bundle and evidence files byte for byte.
// The reviewed hand-off manifest is bound by its SHA-256; attestation.json carries the
// review attestations and run accounting, and every claim field is checked against the bundle.
function verifyDiagnosticRecord(r){
  const dir=r.path;
  for(const f of ['bundle.json','attestation.json','execution-log.jsonl','deletion-disclosure.md','preview.md'])
    assert.ok(fs.existsSync(dir+f),'missing '+dir+f);
  const aRaw=fs.readFileSync(dir+'attestation.json','utf8'); const a=JSON.parse(aRaw);
  eq(aRaw, canonicalJSON(a)+'\n'); eq(sha256(aRaw), r.attestationSha256);
  eq(a.schema,'macbrains.dataset.diagnostic-attestation.v1'); eq(a.tag,r.tag); eq(a.version,r.version);
  eq(a.findingId,r.findingId); eq(a.siteUrl,r.siteUrl); eq(a.conceptDoi, manifest.concept_doi);
  eq(a.files.map(f=>f.name).join(','),'bundle.json,execution-log.jsonl,deletion-disclosure.md,preview.md');
  for(const f of a.files){ const b=fs.readFileSync(dir+f.name); eq(sha256(b),f.sha256); eq(b.length,f.bytes); }
  const bRaw=fs.readFileSync(dir+'bundle.json'); const b=JSON.parse(bRaw.toString('utf8'));
  eq(sha256(bRaw), a.bundle.sha256); eq(a.bundle.sha256, r.bundleSha256);
  eq(b.findingId,a.findingId); eq(b.claim,a.claim); eq(b.claimScope,a.claimScope); eq(b.policyDigest,a.policy.digest);
  eq(canonicalJSON(b.limits),canonicalJSON(a.limits)); eq(canonicalJSON(b.device),canonicalJSON(a.device));
  assert.match(a.policy.commit,/^[0-9a-f]{40}$/); assert.match(a.reviewedPackage.sha256,/^[0-9a-f]{64}$/);
  eq(a.reviewedPackage.sha256, r.reviewedPackageSha256);
  eq(a.finalReview.reviewer,'macbrains-labs-reviewer'); eq(a.finalReview.decision,'INCLUDE');
  eq(a.finalReview.reviewedPackageSha256, r.reviewedPackageSha256); assert.match(a.finalReview.verdictReceiptSha256,/^[0-9a-f]{64}$/);
  eq(a.pipelineReviews.map(x=>x.role).sort().join(','),'evidence_reviewer,skeptical_reviewer');
  for(const x of a.pipelineReviews){ eq(x.verdict,'INCLUDE'); assert.ok(x.score>=0&&x.score<=1); assert.ok(x.sessionId); }
  // Scope: same chip, single device, never cross-device; ANE execution inferred; no novelty claim.
  const br=b.evidence.byteReproducibility;
  eq(br.crossDeviceReplication,false); eq(a.replication.crossDeviceReplication,false); eq(a.replication.scope,'same-chip');
  eq(r.replication.scope,'same-chip'); eq(r.replication.claim,a.claimScope);
  assert.ok(a.claimScope.startsWith('same-chip')); assert.ok(a.claimScope.includes('ANE execution INFERRED'));
  assert.ok(a.claimScope.includes('no novelty claim')); eq(a.noveltyClaim,'UNCLAIMED'); eq(b.evidence.priorArt.noveltyClaim,'UNCLAIMED');
  assert.ok(a.claim.includes('not cross-device'));
  // Every logged execution of the profile is disclosed and counted from the log itself.
  const log=fs.readFileSync(dir+'execution-log.jsonl','utf8').trim().split('\n').map(l=>JSON.parse(l));
  const ex=log.filter(x=>x.kind!=='log-header');
  for(const x of ex) eq(x.profileHash, br.profileHash);
  eq(a.replication.profileHash, br.profileHash); eq(r.replication.profileHash, br.profileHash);
  const counts={logged:ex.length,counted:ex.filter(x=>x.counted===true).length,
    preFreeze:ex.filter(x=>x.status==='pre-freeze').length,deleted:ex.filter(x=>x.present==='deleted').length};
  for(const k of Object.keys(counts)){ eq(a.replication[k],counts[k]); eq(r.replication[k],counts[k]); }
  eq(counts.logged, counts.counted+counts.preFreeze);
  const preview=fs.readFileSync(dir+'preview.md','utf8');
  assert.ok(preview.includes(a.claim)); assert.ok(preview.includes(a.claimScope));
  for(const x of ex) assert.ok(preview.includes('| '+x.runId+' |'),'preview omits '+x.runId);
}
check('Versioned records: index, files, review package hash, INCLUDE verdict, replication labels', () => {
  if(!INDEX){ assert.ok(!fs.existsSync('records'),'records/ without records/index.json'); return; }
  eq(INDEX.schema,'macbrains.dataset.records-index.v1');
  eq(INDEX.conceptDoi, manifest.concept_doi);
  eq(INDEX.baseline.version, manifest.release_tag); eq(INDEX.baseline.versionDoi, manifest.version_doi);
  const tags=new Set(), versions=new Set();
  for(const r of INDEX.records){
    assert.match(r.tag,/^ane-record-[0-9a-f]{24}$/); assert.ok(!tags.has(r.tag)); tags.add(r.tag);
    assert.ok(cmpVer(r.version, manifest.release_tag)>0); assert.ok(!versions.has(r.version)); versions.add(r.version);
    eq(r.path,'records/'+r.tag+'/');
    if(r.versionDoi!==undefined) assert.match(r.versionDoi,/^10\.5281\/zenodo\.\d+$/);
    if(r.kind==='diagnostic'){ verifyDiagnosticRecord(r); continue; }
    for(const f of ['finding.json','citations.json','preview.md','manifest.json','review-package.json','final-verdict.json'])
      assert.ok(fs.existsSync(r.path+f),'missing '+r.path+f);
    const rpRaw=fs.readFileSync(r.path+'review-package.json','utf8');
    const rp=JSON.parse(rpRaw);
    eq(rpRaw, canonicalJSON(rp)+'\n'); eq(sha256(canonicalJSON(rp)), r.reviewPackageHash);
    eq(rp.publication.packageHash, r.packageHash); eq(rp.publication.releaseTag, r.tag);
    for(const f of rp.publication.files) eq(sha256(fs.readFileSync(r.path+f.name)), f.sha256);
    const v=JSON.parse(fs.readFileSync(r.path+'final-verdict.json','utf8'));
    eq(v.reviewer,'macbrains-labs-reviewer'); eq(v.decision,'INCLUDE'); eq(v.reviewPackageHash, r.reviewPackageHash);
    eq(v.verdictDigest, r.verdictDigest);
    const rep=rp.replication;
    eq(rep.runCount, rep.runs.length); eq(rep.runsLog.entryCount, rep.runCount);
    eq(r.replication.runCount, rep.runCount); eq(r.replication.profileHash, rep.profileHash); eq(r.replication.claim, rep.claim);
    if(rep.scope!=='cross-device') assert.ok(rep.claim.includes('not cross-device replication'));
  }
  const zj=JSON.parse(fs.readFileSync('.zenodo.json','utf8'));
  eq(zj.version, LATEST.version);
  assert.ok(zj.related_identifiers.some(x=>x.relation==='isDocumentedBy'&&x.identifier===LATEST.siteUrl));
  // Setting related_identifiers here replaces the tag-tree link Zenodo's GitHub
  // integration would add, so the release's tree must be listed explicitly.
  assert.ok(zj.related_identifiers.some(x=>x.relation==='isSupplementTo'&&x.identifier==='https://github.com/macbrainslabs/ane-research-records/tree/'+LATEST.tag),'.zenodo.json must link the latest record tag tree');
});
check('License/citation/security metadata and workflow', () => {
  assert.ok(fs.readFileSync('LICENSE','utf8').includes('Attribution 4.0 International'));
  assert.ok(fs.readFileSync('LICENSE-MIT','utf8').includes('MIT License'));
  const cff=fs.readFileSync('CITATION.cff','utf8');
  assert.ok(cff.includes('license: "CC-BY-4.0"'));
  for(const keyword of ['Apple Neural Engine','Core ML','Qwen2.5','LFM S2']) assert.ok(cff.includes('  - "'+keyword+'"'));
  assert.ok(fs.readFileSync('SECURITY.md','utf8').includes('research@macbrainslabs.org'));
  assert.ok(fs.readFileSync('.github/workflows/verify.yml','utf8').includes('node scripts/verify.mjs'));
});
for(const line of lines)console.log(line);
if(process.exitCode)process.exit();
if(process.argv.includes('--upstream')) {
  const ref=manifest.site_commit;
  for(const [p,{sha256:want}] of Object.entries(manifest.source_files)) {
    const url=`https://raw.githubusercontent.com/naytewilson/macbrainslabs-site/${ref}/${p}`;
    const r=await fetch(url,{signal:AbortSignal.timeout(20000)});
    assert.equal(r.status,200,'Pinned upstream unavailable: '+p+' HTTP '+r.status);
    const data=Buffer.from(await r.arrayBuffer());
    const actual=crypto.createHash('sha256').update(data).digest('hex');
    assert.equal(actual,want,'Pinned source changed: '+p);
    console.log('PASS upstream SHA256 '+p);
    count++;
  }
}
console.log('Research record verification: '+count+'/' + count+' checks passed.');
