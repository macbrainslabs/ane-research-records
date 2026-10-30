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
  assert.ok(fs.readFileSync('CITATION.cff','utf8').includes('doi: "' + manifest.version_doi + '"'));
  const readme=fs.readFileSync('README.md','utf8');
  assert.ok(readme.includes('raw measurement output') && readme.includes('**not** raw measurement output'));
  assert.ok(readme.includes('not direct silicon tracing')||readme.includes('not direct ANE hardware tracing')||readme.includes('not direct silicon tracing'));
  assert.ok(readme.includes('not a complete reproducibility bundle'));
  assert.ok(readme.includes('Zenodo DOI'));
  assert.ok(readme.includes('https://doi.org/' + manifest.version_doi));
  assert.ok(readme.includes('https://zenodo.org/badge/DOI/' + manifest.version_doi + '.svg'));
  assert.ok(readme.includes('https://doi.org/' + manifest.concept_doi));
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
