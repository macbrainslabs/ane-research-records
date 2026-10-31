// MIT licensed offline negative tests. Synthetic fixtures; no private model data.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import {
  hashHex, gitBlobSha, parseSha256Sums, normalizeMembers,
  archiveListing, archiveMember, compareToGitTree
} from '../scripts/publication-audit-lib.mjs';

test('canonical Git blob SHA-1 calculation', () => {
  assert.equal(gitBlobSha(Buffer.from('test\n')), '9daeafb9864cf43055ae93beb0afd6c7d144bfa4');
});

test('SHA256SUMS rejects malformed or duplicated evidence', () => {
  const good = hashHex('sha256', Buffer.from('known'));
  const sum = parseSha256Sums(`${good}  research.tar.gz\n`);
  assert.equal(sum.get('research.tar.gz'), good);
  assert.throws(() => parseSha256Sums('madeup  research.tar.gz\n'), /invalid SHA256SUMS/);
  assert.throws(() => parseSha256Sums(`${good}  research.tar.gz\n${good}  research.tar.gz\n`),
    /duplicate checksum/);
  assert.notEqual(hashHex('sha256', Buffer.from('tampereD')), sum.get('research.tar.gz'));
});

test('archive paths reject traversal, wildcard, duplicate, and multiple roots', () => {
  for (const names of [
    ['root/../evil'],
    ['/etc/passwd'],
    ['root/a', 'second/b'],
    ['root/a', 'root/a'],
    ['root/a', 'root/a/./b'],
    ['root/data/*.csv'],
    ['root/a', 'root\\b']
  ]) assert.throws(() => normalizeMembers(names), undefined, JSON.stringify(names));
  assert.equal(normalizeMembers(['root/', 'root/data/', 'root/data/a.csv']).get('data/a.csv'),
    'root/data/a.csv');
});

test('exact tree comparison rejects a modified file and missing/extra files', () => {
  const content = Buffer.from('curated public summary\n');
  const tree = [{ path: 'README.md', type: 'blob', sha: gitBlobSha(content) }];
  const entries = normalizeMembers(['release/', 'release/README.md']);
  const read = () => content;
  assert.deepEqual(compareToGitTree(entries, tree, read).map(x=>x.path), ['README.md']);
  assert.throws(() => compareToGitTree(entries, tree, () => Buffer.from('modified')) ,
    /Git blob mismatch/);
  assert.throws(() => compareToGitTree(entries, [...tree,{path:'extra',type:'blob',sha:gitBlobSha(content)}], read),
    /archive file list differs/);
});

test('real tar.gz and zip parsers read matching content and reject tampering', () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'macbrains-audit-fixture-'));
  try {
    const root = path.join(scratch, 'release');
    fs.mkdirSync(path.join(root, 'data'), { recursive: true });
    const original = Buffer.from('2,090,79\n');
    fs.writeFileSync(path.join(root, 'data', 'counts.txt'), original);
    fs.writeFileSync(path.join(root, 'README.md'), 'Public synthetic test fixture\n');
    const paths = ['README.md', 'data/counts.txt'];
    const tree = paths.map(p => ({ path:p, type:'blob', sha:gitBlobSha(fs.readFileSync(path.join(root,p))) }));
    const tarPath = path.join(scratch, 'release.tar.gz');
    const zipPath = path.join(scratch, 'release.zip');
    execFileSync('tar', ['-czf', tarPath, 'release'], { cwd:scratch });
    execFileSync('zip', ['-q', '-r', zipPath, 'release'], { cwd:scratch });
    for (const [format, file] of [['tar.gz', tarPath], ['zip', zipPath]]) {
      const entries = archiveListing(file, format);
      const verify = () => compareToGitTree(entries, tree, name => archiveMember(file, format, name));
      assert.equal(verify().length, 2);
    }
    fs.writeFileSync(path.join(root,'data','counts.txt'), Buffer.from('2,090,80\n'));
    const badTar = path.join(scratch, 'bad.tar.gz');
    const badZip = path.join(scratch, 'bad.zip');
    execFileSync('tar', ['-czf', badTar, 'release'], { cwd:scratch });
    execFileSync('zip', ['-q', '-r', badZip, 'release'], { cwd:scratch });
    for (const [format, file] of [['tar.gz', badTar], ['zip', badZip]]) {
      const members = archiveListing(file, format);
      assert.throws(() => compareToGitTree(members, tree,
        name => archiveMember(file, format, name)), /Git blob mismatch/);
    }
  } finally {
    fs.rmSync(scratch, { recursive:true, force:true });
  }
});
