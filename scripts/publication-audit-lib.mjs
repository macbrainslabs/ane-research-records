// MIT licensed. Read-only archive identity helpers for the PUBLIC v0.1.0 release.
// No archive is extracted onto the filesystem. tar/unzip read members to stdout.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const MAX_MEMBER_BYTES = 8 * 1024 * 1024;
const EXEC_OPTIONS = { maxBuffer: MAX_MEMBER_BYTES };

export function hashHex(algorithm, bytes) {
  return createHash(algorithm).update(bytes).digest('hex');
}

export function gitBlobSha(bytes) {
  const b = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  return hashHex('sha1', Buffer.concat([Buffer.from(`blob ${b.length}\0`), b]));
}

export function parseSha256Sums(bytes) {
  const lines = Buffer.isBuffer(bytes) ? bytes.toString('utf8') : String(bytes);
  const result = new Map();
  for (const line of lines.trimEnd().split(/\r?\n/)) {
    const match = /^([0-9a-f]{64})  ([A-Za-z0-9._-]+)$/.exec(line);
    assert.ok(match, `invalid SHA256SUMS line: ${line.slice(0, 110)}`);
    assert.ok(!result.has(match[2]), `duplicate checksum for ${match[2]}`);
    result.set(match[2], match[1]);
  }
  return result;
}

export function normalizeMembers(names) {
  assert.ok(Array.isArray(names) && names.length > 0, 'empty archive listing');
  const roots = new Set();
  const files = new Map();
  for (const name of names) {
    assert.ok(typeof name === 'string' && name.length > 0 && name.length < 4096, 'invalid archive member');
    assert.ok(!name.startsWith('/') && !name.includes('\\') && !/[\x00-\x1f\x7f]/.test(name), 'unsafe archive path');
    const isDirectory = name.endsWith('/');
    const path = isDirectory ? name.slice(0, -1) : name;
    const parts = path.split('/');
    assert.ok(parts.every(x => x && x !== '.' && x !== '..'), `traversal or empty component: ${name}`);
    assert.ok(!/[\[\]{}*?]/.test(name), `unsupported wildcard in archive path: ${name}`);
    roots.add(parts[0]);
    if (isDirectory) continue;
    assert.ok(parts.length >= 2, `file outside archive root directory: ${name}`);
    const relative = parts.slice(1).join('/');
    assert.ok(!files.has(relative), `duplicate archive path ${relative}`);
    files.set(relative, name);
  }
  assert.equal(roots.size, 1, 'archive contains multiple top-level directories');
  assert.ok(files.size > 0, 'archive has no files');
  return files;
}

export function archiveListing(archivePath, format) {
  assert.ok(format === 'tar.gz' || format === 'zip', 'unsupported archive format');
  const args = format === 'tar.gz' ? ['-tzf', archivePath] : ['-Z', '-1', archivePath];
  const cmd = format === 'tar.gz' ? 'tar' : 'unzip';
  const output = execFileSync(cmd, args, EXEC_OPTIONS).toString('utf8');
  assert.ok(output.endsWith('\n'), 'malformed archive member listing');
  return normalizeMembers(output.trimEnd().split('\n'));
}

export function archiveMember(archivePath, format, memberName) {
  const b = format === 'tar.gz'
    ? execFileSync('tar', ['-xOzf', archivePath, memberName], EXEC_OPTIONS)
    : execFileSync('unzip', ['-p', archivePath, memberName], EXEC_OPTIONS);
  assert.ok(b.length <= MAX_MEMBER_BYTES, 'archive member exceeded size limit');
  return b;
}

export function compareToGitTree(members, tree, readMember) {
  assert.ok(Array.isArray(tree) && tree.length > 0, 'Git tree absent');
  const blobs = new Map();
  for (const entry of tree) {
    if (entry.type !== 'blob') {
      assert.equal(entry.type, 'tree', 'unsupported Git object type');
      continue;
    }
    assert.match(entry.sha, /^[0-9a-f]{40}$/, 'bad Git blob SHA');
    assert.ok(!blobs.has(entry.path), 'duplicate Git tree path');
    blobs.set(entry.path, entry.sha);
  }
  const paths = [...members.keys()].sort();
  assert.deepEqual(paths, [...blobs.keys()].sort(), 'archive file list differs from exact Git tag tree');
  const checked = [];
  for (const relative of paths) {
    const bytes = readMember(members.get(relative));
    assert.ok(Buffer.isBuffer(bytes), 'archive reader returned non-buffer');
    const computed = gitBlobSha(bytes);
    assert.equal(computed, blobs.get(relative), `Git blob mismatch: ${relative}`);
    checked.push({ path: relative, git_blob_sha1: computed, sha256: hashHex('sha256', bytes), size: bytes.length });
  }
  return checked;
}
