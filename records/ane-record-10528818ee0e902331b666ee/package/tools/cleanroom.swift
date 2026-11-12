import Foundation
import CryptoKit

// cleanroom.swift - ANVIL fabric clean-room replication harness (on-demand, native).
// Verifies a FROZEN setup profile by: rebuilding the runner from committed source,
// running it in a fresh isolated process, byte-comparing outputs to a frozen baseline
// (using the baseline`s own recorded per-file sha256), appending an immutable run
// record, and emitting a replication receipt the publication gate can consume.
//
// Freeze gate: the profile (and, when --tool-source is given, this tool`s source) MUST be
// git-tracked and clean BEFORE any counted run. A pre-run freeze-manifest records the
// profile hash and commit time; a run under an unfrozen profile is refused unless
// --allow-unfrozen is passed, and such a run is recorded NOT counted toward replication.
//
// Honest-by-construction: records the macOS build, CoreML version and E5 bundle-cache
// state actually observed before the run; labels the result same-chip clean-room; and
// NEVER sets a cross-device flag. It asserts determinism/provenance/recomputation on one
// device + OS build, not cross-device scientific replication.

func dieErr(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(2) }

// Streams the file in 4 MiB chunks, so a large fixture is never held in memory. nil if it cannot be read.
func sha256File(_ path: String) -> String? {
    guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? fh.close() }
    var h = SHA256()
    while true {
        let chunk: Data
        do { chunk = try fh.read(upToCount: 4 << 20) ?? Data() } catch { return nil }
        if chunk.isEmpty { break }
        h.update(data: chunk)
    }
    return h.finalize().map { String(format: "%02x", $0) }.joined()
}
func sha256Bytes(_ data: Data) -> String {
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func canonical(_ obj: Any) -> Data {
    return (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
}
// Atomic (temp file + rename): a crash mid-write can never leave a truncated ledger/receipt behind.
@discardableResult
func writeJSON(_ obj: Any, _ path: String) -> Bool {
    guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]) else { return false }
    do { try d.write(to: URL(fileURLWithPath: path), options: .atomic); return true } catch { return false }
}
func warnErr(_ s: String) { FileHandle.standardError.write(("WARNING: " + s + "\n").data(using: .utf8)!) }
// Real account home from the password database (not $HOME), so the device-wide log cannot be relocated by env.
func accountHome() -> String {
    if let pw = getpwuid(getuid()), let d = pw.pointee.pw_dir { return String(cString: d) }
    return NSHomeDirectory()
}

@discardableResult
func exec(_ path: String, _ argv: [String], env: [String:String]? = nil, cwd: String? = nil, stdoutPath: String? = nil) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = argv
    if let env = env { p.environment = env }
    if let cwd = cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
    let pipe = Pipe()
    var fh: FileHandle? = nil
    if let sp = stdoutPath {
        FileManager.default.createFile(atPath: sp, contents: nil)
        fh = FileHandle(forWritingAtPath: sp)
        p.standardOutput = fh
        p.standardError = fh
    } else {
        p.standardOutput = pipe
        p.standardError = pipe
    }
    do { try p.run() } catch { return (-1, "spawn failed: \(error)") }
    var out = ""
    if stdoutPath == nil {
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        out = String(data: d, encoding: .utf8) ?? ""
    }
    p.waitUntilExit()
    try? fh?.close()
    return (p.terminationStatus, out)
}
func cap(_ path: String, _ argv: [String]) -> String {
    return exec(path, argv).1.trimmingCharacters(in: .whitespacesAndNewlines)
}
func gitShow(_ repo: String, _ ref: String) -> Data? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    p.arguments = ["-C", repo, "show", ref]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    do { try p.run() } catch { return nil }
    let d = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return p.terminationStatus == 0 ? d : nil
}
func fileGitState(_ path: String) -> [String:Any] {
    let absPath = (path as NSString).isAbsolutePath ? path : (FileManager.default.currentDirectoryPath + "/" + path)
    let dir = (absPath as NSString).deletingLastPathComponent
    let (rc, root) = exec("/usr/bin/git", ["-C", dir, "rev-parse", "--show-toplevel"])
    let repoRoot = root.trimmingCharacters(in: .whitespacesAndNewlines)
    if rc != 0 { return ["tracked": false, "clean": false, "error": "not a git repository: \(dir)"] }
    let tracked = exec("/usr/bin/git", ["-C", repoRoot, "ls-files", "--error-unmatch", absPath]).0 == 0
    let status = exec("/usr/bin/git", ["-C", repoRoot, "status", "--porcelain", "--", absPath]).1.trimmingCharacters(in: .whitespacesAndNewlines)
    let clean = tracked && status.isEmpty
    let commitLine = exec("/usr/bin/git", ["-C", repoRoot, "log", "-1", "--format=%H%x09%cI", "--", absPath]).1.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = commitLine.split(separator: "\t", maxSplits: 1).map(String.init)
    let head = exec("/usr/bin/git", ["-C", repoRoot, "rev-parse", "HEAD"]).1.trimmingCharacters(in: .whitespacesAndNewlines)
    return ["tracked": tracked, "clean": clean, "status": status,
            "commit": parts.first ?? "", "commitTime": parts.count > 1 ? parts[1] : "",
            "headCommit": head, "repoRoot": repoRoot]
}

let args = CommandLine.arguments
func opt(_ n: String) -> String? { if let i = args.firstIndex(of: n), i + 1 < args.count { return args[i+1] }; return nil }
guard let profilePath = opt("--profile") else { dieErr("usage: cleanroom --profile P.json --out DIR [--runs-log L.json] [--tool-source cleanroom.swift] [--allow-unfrozen] [--build-only] [--control] [--ledger-dir D] [--allow-clobber]") }
// Absolute, standardized output dir: relative forms ("." , "./x", "../x") must not defeat the lexical scratch-dir checks.
// --out is required: a default dir in the cwd let a stray invocation create and claim a run dir anywhere.
guard let rawOut = opt("--out"), !rawOut.isEmpty else { dieErr("REFUSING: --out DIR is required (a fresh output directory)") }
let outDir: String = {
    let raw = rawOut
    let abs = raw.hasPrefix("/") ? raw : (FileManager.default.currentDirectoryPath + "/" + raw)
    return URL(fileURLWithPath: abs).standardized.path   // drops "." and ".." only; no symlink or /private rewriting
}()
let runsLogExplicit = opt("--runs-log")
let ledgerDir = opt("--ledger-dir") ?? (accountHome() + "/.local/share/anvil/cleanroom-ledger")
let buildOnly = args.contains("--build-only")
let controlMode = args.contains("--control")
let allowUnfrozen = args.contains("--allow-unfrozen")
let toolSource = opt("--tool-source")
let fm = FileManager.default
// Guard (reviewer HOLD H1/B): cleanroom NEVER deletes a run directory. safeReset clears only a scratch
// subdir strictly inside outDir; it refuses outDir itself, any ancestor, or anything outside outDir.
// A failed removal is fatal: silently keeping stale dumps could let a failed run compare byte-identical.
func safeReset(_ p: String) {
    let a = (p as NSString).standardizingPath
    let o = (outDir as NSString).standardizingPath
    if a == o || o.hasPrefix(a + "/") || !a.hasPrefix(o + "/") {
        dieErr("REFUSING to delete \(p): cleanroom resets only scratch subdirectories strictly inside the output dir, never a run directory.")
    }
    // removeItem on a symlink removes the link itself, never its target.
    if (try? fm.attributesOfItem(atPath: p)) != nil {
        do { try fm.removeItem(atPath: p) } catch { dieErr("cannot reset scratch dir \(p): \(error)") }
    }
    do { try fm.createDirectory(atPath: p, withIntermediateDirectories: false) } catch { dieErr("cannot create scratch dir \(p): \(error)") }
}
// Append-only device-wide execution log keyed by profileHash (path set once profileHash is known).
// One write(2) per line on an O_APPEND descriptor (kernel-atomic positioning, so concurrent cleanroom
// processes never overwrite each other's lines), then F_FULLFSYNC (fsync fallback); the parent dir is
// fsynced when the file is first created. Returns false on ANY failure so callers can refuse to run.
var durableExecLogPath = ""
@discardableResult
func appendDurable(_ obj: [String:Any]) -> Bool {
    guard !durableExecLogPath.isEmpty else { return false }
    let dir = (durableExecLogPath as NSString).deletingLastPathComponent
    do { try fm.createDirectory(atPath: dir, withIntermediateDirectories: true) } catch { return false }
    var bytes = [UInt8](canonical(obj))
    if bytes.isEmpty { return false }
    bytes.append(0x0A)
    let existed = fm.fileExists(atPath: durableExecLogPath)
    let fd = open(durableExecLogPath, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o644)
    if fd < 0 { return false }
    defer { close(fd) }
    let n = bytes.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    if n != bytes.count { return false }
    if fcntl(fd, F_FULLFSYNC) != 0 && fsync(fd) != 0 { return false }
    if !existed { let dfd = open(dir, O_RDONLY); if dfd >= 0 { _ = fsync(dfd); close(dfd) } }
    return true
}
// Summary of the device-wide log for this profile, embedded in receipts so a run that was started but
// never completed (killed, crashed) is disclosed by the receipt itself, not only by the log file.
func execLogSummary() -> [String:Any] {
    let data = fm.contents(atPath: durableExecLogPath) ?? Data()
    var started = 0, completed = 0, bad = 0
    var startKeys = Set<String>(), doneKeys = Set<String>()
    for line in data.split(separator: 0x0A) {
        guard let o = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String:Any], let k = o["kind"] as? String else { bad += 1; continue }
        let key = "\(o["outDir"] ?? "")|\(o["arm"] ?? "")|\(o["runStartedAt"] ?? "")"
        if k == "run_started" { started += 1; startKeys.insert(key) } else if k == "run_completed" { completed += 1; doneKeys.insert(key) }
    }
    return ["path": durableExecLogPath, "sha256": sha256Bytes(data), "runStarted": started, "runCompleted": completed,
            "startedWithoutCompletion": startKeys.subtracting(doneKeys).count, "unparseableLines": bad]
}
// The profile is read before the output dir is created or claimed, so an unreadable profile leaves nothing behind.
guard let pdata = fm.contents(atPath: profilePath),
      let profile = (try? JSONSerialization.jsonObject(with: pdata)) as? [String:Any] else { dieErr("cannot read profile JSON: \(profilePath)") }
let profileHash = sha256Bytes(canonical(profile))
durableExecLogPath = accountHome() + "/.local/state/anvil/execution-log/" + profileHash + ".jsonl"
// Refuse to clobber (effectively delete or overwrite) an existing run directory. A run directory is any
// outDir holding a cleanroom claim marker or ANY cleanroom artifact (freeze manifest, receipts, run log,
// dump, build-only record) - including a run that crashed or was killed before writing its receipt.
// The claim marker is created with O_EXCL, so two concurrent invocations can never share one outDir.
let allowClobber = args.contains("--allow-clobber")
let runDirArtifacts = [".cleanroom-run-claim", "freeze-manifest.json", "cleanroom-receipt.json", "cleanroom-control-receipt.json",
                       "build-only.json", "run.log", "result.json", "dump"]
if !allowClobber, let present = runDirArtifacts.first(where: { (try? fm.attributesOfItem(atPath: outDir + "/" + $0)) != nil }) {
    dieErr("REFUSING: output dir \(outDir) already holds \(present) from a prior cleanroom run (completed, crashed or killed); pick a fresh --out (never reuse or delete a run directory). Pass --allow-clobber only for a known scratch dir.")
}
do { try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true) } catch { dieErr("cannot create output dir \(outDir): \(error)") }
let claimFd = open(outDir + "/.cleanroom-run-claim", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o444)
if claimFd < 0 {
    let e = errno
    if !(allowClobber && e == EEXIST) { dieErr("REFUSING: cannot claim output dir \(outDir) (errno \(e)); another cleanroom invocation owns it or it is a prior run directory.") }
} else {
    let claim = [UInt8]("pid=\(getpid()) claimedAt=\(ISO8601DateFormatter().string(from: Date()))\n".utf8)
    _ = claim.withUnsafeBytes { write(claimFd, $0.baseAddress, $0.count) }; _ = fsync(claimFd); close(claimFd)
}

// B1 fix: run accounting is keyed to the profile hash in a ledger that PERSISTS across output dirs (never per-outDir).
let runsLogPath = runsLogExplicit ?? (ledgerDir + "/cleanroom-ledger-" + profileHash + ".json")
try? fm.createDirectory(atPath: (runsLogPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
// An existing ledger that cannot be parsed is NEVER treated as empty (that would silently reset run accounting).
func loadLedger(_ path: String) -> [[String:Any]] {
    guard (try? fm.attributesOfItem(atPath: path)) != nil else { return [] }
    guard let ld = fm.contents(atPath: path), let arr = (try? JSONSerialization.jsonObject(with: ld)) as? [[String:Any]] else {
        dieErr("REFUSING: run ledger \(path) exists but is unreadable or not a JSON array; refusing to reset run accounting. Device-wide execution log: \(durableExecLogPath)")
    }
    return arr
}
// Read-modify-write of the profile-scoped ledger under an exclusive flock, so concurrent runs of the same
// profile cannot lose each other's records. runIndex is assigned inside the lock.
func appendLedger(_ recs: [[String:Any]]) -> (all: [[String:Any]], firstIndex: Int, ok: Bool) {
    let lfd = open(runsLogPath + ".lock", O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
    if lfd >= 0 { _ = flock(lfd, LOCK_EX) }
    defer { if lfd >= 0 { _ = flock(lfd, LOCK_UN); close(lfd) } }
    var all = loadLedger(runsLogPath)
    let first = all.count + 1
    for (i, rec) in recs.enumerated() { var r = rec; r["runIndex"] = first + i; all.append(r) }
    return (all, first, writeJSON(all, runsLogPath))
}
_ = loadLedger(runsLogPath)   // fail closed BEFORE any run if the ledger is corrupt
let source = profile["source"] as? [String:Any] ?? [:]
let runSpec = profile["run"] as? [String:Any] ?? [:]
let baseline = profile["baseline"] as? [String:Any] ?? [:]
let isolation = profile["isolation"] as? [String:Any] ?? [:]
let expected = profile["expected"] as? [String:Any] ?? [:]
let iso = ISO8601DateFormatter().string(from: Date())

func isHex64(_ s: String) -> Bool {
    return s.utf8.count == 64 && s.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
}
// Directory input (a fixture bundle), listing recipe v1. Every entry under the directory, recursively, gives
// one line:
//   "d<TAB>rel"                        a directory
//   "f<TAB>rel<TAB>sha256"             a regular file
//   "l<TAB>rel<TAB>target<TAB>f<TAB>sha256"   a symlink to a regular file (its target text and the file's sha256)
//   "l<TAB>rel<TAB>target<TAB>d<TAB>sha256"   a symlink to a directory (its target text and that directory's
//                                      own listing sha256, by this recipe; a link cycle makes the input unreadable)
// rel is relative to the directory, "/"-separated, with no leading "./". The lines are sorted by their UTF-8
// bytes and joined with "\n" under the header line "cleanroom-dir-listing-v1" (no trailing newline); the
// input's sha256 is the sha256 of that text. Any unreadable entry, a dangling symlink, or any other file type
// makes the whole input unreadable (nil), never a partial listing.
func dirListingSha(_ root: String, _ visiting: Set<String> = []) -> String? {
    let rootURL = URL(fileURLWithPath: root).resolvingSymlinksInPath().standardizedFileURL
    let rootPath = rootURL.path
    if visiting.contains(rootPath) { return nil }
    let inside = visiting.union([rootPath])
    var failed = false
    let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
    guard let en = fm.enumerator(at: rootURL, includingPropertiesForKeys: keys, options: [],
                                 errorHandler: { _, _ in failed = true; return false }) else { return nil }
    var lines: [String] = []
    for case let u as URL in en {
        let p = u.standardizedFileURL.path
        guard p.hasPrefix(rootPath + "/") else { return nil }
        let rel = String(p.dropFirst(rootPath.count + 1))
        guard let v = try? u.resourceValues(forKeys: Set(keys)) else { return nil }
        // No skipDescendants() here: the URL enumerator never descends into a symlink, and skipDescendants()
        // would skip the most recently entered directory instead, silently dropping its later entries.
        if v.isSymbolicLink == true {
            guard let t = try? fm.destinationOfSymbolicLink(atPath: p) else { return nil }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: p, isDirectory: &isDir) else { return nil }   // dangling
            if isDir.boolValue {
                guard let h = dirListingSha(p, inside) else { return nil }
                lines.append("l\t" + rel + "\t" + t + "\td\t" + h)
            } else {
                let rp = (p as NSString).resolvingSymlinksInPath
                guard ((try? fm.attributesOfItem(atPath: rp))?[.type] as? FileAttributeType) == .typeRegular,
                      let h = sha256File(rp) else { return nil }
                lines.append("l\t" + rel + "\t" + t + "\tf\t" + h)
            }
        } else if v.isDirectory == true {
            lines.append("d\t" + rel)
        } else if v.isRegularFile == true {
            guard let h = sha256File(p) else { return nil }
            lines.append("f\t" + rel + "\t" + h)
        } else { return nil }
    }
    if failed { return nil }
    let sorted = lines.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
    return sha256Bytes(Data((["cleanroom-dir-listing-v1"] + sorted).joined(separator: "\n").utf8))
}
// Relative paths of every entry under a dump dir (symlinks are not followed), plus the entries the enumerator
// could not read: an unreadable subdirectory is reported, never skipped silently. A missing dir gives nothing.
func walkDump(_ dir: String) -> (entries: [String], unreadable: [String]) {
    guard fm.fileExists(atPath: dir) else { return ([], []) }
    let root = URL(fileURLWithPath: dir).resolvingSymlinksInPath().standardizedFileURL
    let rp = root.path
    func relOf(_ u: URL) -> String { let p = u.standardizedFileURL.path; return p.hasPrefix(rp + "/") ? String(p.dropFirst(rp.count + 1)) : p }
    var bad: [String] = []
    guard let en = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [],
                                 errorHandler: { u, _ in bad.append(relOf(u)); return true }) else { return ([], ["."]) }
    var out: [String] = []
    for case let u as URL in en { out.append(relOf(u)) }
    return (out, bad)
}
// --control dump records: one per entry that is not a real directory, sorted by path. Every symlink's record
// carries "symlink": true, whatever it points to. A regular file (or a symlink to one) gives its sha256; an
// unreadable entry, a dangling symlink, a symlink to a directory (whose contents the walk does not follow) or any
// other file type (FIFO, socket, device) gives "unreadable", which fails the arm. Nothing is skipped silently.
func dumpRecords(_ dDir: String) -> [[String:Any]] {
    let walk = walkDump(dDir)
    var recs: [[String:Any]] = []
    for f in walk.entries {
        let full = dDir + "/" + f
        // attributesOfItem does not follow a final symlink, so only a real directory is skipped here
        let t = (try? fm.attributesOfItem(atPath: full))?[.type] as? FileAttributeType
        if t == .typeDirectory { continue }
        // resolve once and hash that same path, so the type check and the read see one target
        let rp = (full as NSString).resolvingSymlinksInPath
        var rec: [String:Any] = ["path": f, "sha256": (isRegularFileResolved(rp) ? sha256File(rp) : nil) ?? "unreadable"]
        if t == .typeSymbolicLink { rec["symlink"] = true }   // a symlink to a file is hashed but marked, as it may point outside the dump
        recs.append(rec)
    }
    for f in walk.unreadable { recs.append(["path": f, "sha256": "unreadable"]) }
    return recs.sorted { (($0["path"] as? String) ?? "") < (($1["path"] as? String) ?? "") }
}
// One input: kind "file" (sha256 of its bytes), "directory" (listing recipe v1) or "unreadable" (missing,
// unreadable, or an unsupported file type; sha256 is then "unreadable", which no declared hash can equal).
// Every directory listing text starts with the header line, so a regular file whose bytes start with that
// header is refused (kind "listing-text-file"): otherwise such a file would hash equal to a directory and a
// declared hash could not tell the two apart. File and directory hashes are therefore disjoint.
let listingHeader = Data("cleanroom-dir-listing-v1".utf8)
// read(upToCount:) returns nil at end of file, so an empty file reads as empty Data (not as unreadable).
func startsWithListingHeader(_ path: String) -> Bool? {
    guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? fh.close() }
    let head: Data
    do { head = try fh.read(upToCount: listingHeader.count) ?? Data() } catch { return nil }
    return head == listingHeader
}
// Only a regular file (after resolving symlinks) is opened: opening a FIFO or device would block or read
// unbounded data, so any other type is recorded as unreadable before anything opens it.
func isRegularFileResolved(_ path: String) -> Bool {
    let rp = (path as NSString).resolvingSymlinksInPath
    return ((try? fm.attributesOfItem(atPath: rp))?[.type] as? FileAttributeType) == .typeRegular
}
func inputRecord(_ path: String) -> [String:Any] {
    var isDir: ObjCBool = false
    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue || isRegularFileResolved(path) {
        if isDir.boolValue, let h = dirListingSha(path) { return ["path": path, "kind": "directory", "sha256": h] }
        if !isDir.boolValue, let lh = startsWithListingHeader(path) {
            if lh { return ["path": path, "kind": "listing-text-file", "sha256": "listing-text-file"] }
            if let h = sha256File(path) { return ["path": path, "kind": "file", "sha256": h] }
        }
    }
    return ["path": path, "kind": "unreadable", "sha256": "unreadable"]
}
// Inputs: run.fixture and run.tsv (every mode) and baseline.indexJson (replication mode) must exist and be
// readable, or the tool refuses before it builds or runs anything. Each input is recorded in the freeze
// manifest. A hash the profile declares (run.fixtureSha256, run.tsvSha256, baseline.indexSha256) must be a
// 64-hex string equal to the recorded sha256; any other *Sha256 key in run or baseline is refused. The
// inputs are hashed again after every run (each arm in --control); any change marks that run as not passed.
func inputState() -> [String:Any] {
    var s: [String:Any] = [:]
    let paths: [(String, String?)] = [("fixture", runSpec["fixture"] as? String), ("tsv", runSpec["tsv"] as? String),
                                      ("baselineIndex", baseline["indexJson"] as? String)]
    for (k, p) in paths { if let p = p { s[k] = inputRecord(p) } }
    return s
}
let inputsBefore = inputState()
var inputMismatches: [String] = []
var requiredInputs: [(String, String, String)] = [("fixture", "run.fixture", "run"), ("tsv", "run.tsv", "run")]
if !controlMode { requiredInputs.append(("baselineIndex", "baseline.indexJson", "baseline")) }
for (k, name, section) in requiredInputs {
    let raw = (section == "run" ? runSpec : baseline)[String(name.split(separator: ".")[1])]
    guard raw is String else { inputMismatches.append("\(k): \(name) is required and must be a path string"); continue }
    if ((inputsBefore[k] as? [String:Any])?["kind"] as? String) == "unreadable" {
        inputMismatches.append("\(k): \(name) is missing or unreadable")
    }
    if ((inputsBefore[k] as? [String:Any])?["kind"] as? String) == "listing-text-file" {
        inputMismatches.append("\(k): \(name) is a regular file that starts with the directory-listing header \"cleanroom-dir-listing-v1\", so its hash could equal a directory's")
    }
}
let declaredInputs: [(String, String, [String:Any])] = [("fixture", "fixtureSha256", runSpec), ("tsv", "tsvSha256", runSpec),
                                                        ("baselineIndex", "indexSha256", baseline)]
for (k, declKey, spec) in declaredInputs {
    guard let raw = spec[declKey] else { continue }
    guard let want = raw as? String, isHex64(want) else { inputMismatches.append("\(k): declared \(declKey) is not a 64-hex sha256 string"); continue }
    guard let rec = inputsBefore[k] as? [String:Any] else { inputMismatches.append("\(k): \(declKey) is declared but the input path is absent"); continue }
    let got = (rec["sha256"] as? String) ?? "unreadable"
    if got != want.lowercased() { inputMismatches.append("\(k): declared \(want) does not match actual \(got)") }
}
let knownHashKeys: [String:Set<String>] = ["run": ["fixtureSha256", "tsvSha256"], "baseline": ["indexSha256"]]
// Case-insensitive, so a key such as run.fixtureSHA256 is refused rather than silently ignored; an input hash
// key at the profile's top level (where it would be ignored) is refused too.
for (section, spec) in [("run", runSpec), ("baseline", baseline)] {
    for key in spec.keys.sorted() where key.lowercased().hasSuffix("sha256") && !(knownHashKeys[section] ?? []).contains(key) {
        inputMismatches.append("\(section).\(key) is not a recognised input hash key (run.fixtureSha256, run.tsvSha256, baseline.indexSha256)")
    }
}
let inputHashKeyNames: Set<String> = ["fixturesha256", "tsvsha256", "indexsha256"]
for key in profile.keys.sorted() where inputHashKeyNames.contains(key.lowercased()) {
    inputMismatches.append("\(key) at the profile top level is not read; input hashes go in run.fixtureSha256, run.tsvSha256 or baseline.indexSha256")
}
// Replication mode: the baseline index must list at least one output, each with a relative path that stays
// inside the dump dir and a 64-hex sha256; a malformed entry would otherwise be skipped by the compare.
var baselineFiles: [(String, String)] = []
if !controlMode, let bidx = baseline["indexJson"] as? String {
    if ((inputsBefore["baselineIndex"] as? [String:Any])?["kind"] as? String) == "directory" {
        inputMismatches.append("baselineIndex: \(bidx) is a directory, not an index file")
    } else if let bd = fm.contents(atPath: bidx), let bj = (try? JSONSerialization.jsonObject(with: bd)) as? [String:Any],
       let files = bj["files"] as? [[String:Any]], !files.isEmpty {
        for (i, f) in files.enumerated() {
            guard let rel = f["path"] as? String, let want = f["sha256"] as? String, isHex64(want), !rel.isEmpty, !rel.hasPrefix("/"),
                  !rel.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
                inputMismatches.append("baselineIndex: files[\(i)] needs a relative path inside the dump dir and a 64-hex sha256"); continue
            }
            if baselineFiles.contains(where: { $0.0 == rel }) {
                inputMismatches.append("baselineIndex: files[\(i)] repeats the path \(rel)"); continue
            }
            baselineFiles.append((rel, want.lowercased()))
        }
    } else { inputMismatches.append("baselineIndex: \(bidx) is not JSON with a non-empty files array") }
}
// --control: at least one arm, each with a unique, path-safe name and (if given) an env of string values only.
if controlMode {
    if let control = profile["control"] as? [String:Any], let arms = control["arms"] as? [[String:Any]], !arms.isEmpty {
        var seen = Set<String>()
        for (i, arm) in arms.enumerated() {
            guard let name = arm["name"] as? String, !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
                inputMismatches.append("control.arms[\(i)] needs a non-empty name without '/'"); continue
            }
            if !seen.insert(name).inserted { inputMismatches.append("control.arms[\(i)] repeats the name \(name)") }
            if let e = arm["env"], !(e is [String:String]) { inputMismatches.append("control.arms[\(i)] (\(name)): env must map names to string values") }
        }
    } else { inputMismatches.append("--control requires a non-empty profile.control.arms") }
}

// ---- 0. Freeze gate: profile (and tool) must be committed + clean BEFORE any run ----
let profileGit = fileGitState(profilePath)
var toolGit: [String:Any] = ["provided": false]
if let ts = toolSource { toolGit = fileGitState(ts); toolGit["provided"] = true; toolGit["path"] = ts }
let profileFrozen = (profileGit["clean"] as? Bool) ?? false
let toolFrozen = (toolSource == nil) ? true : ((toolGit["clean"] as? Bool) ?? false)
let frozen = profileFrozen && toolFrozen
let freezeTime = ISO8601DateFormatter().string(from: Date())
var freezeManifest: [String:Any] = ["schema": "macbrains.research.cleanroom-freeze.v1", "freezeTime": freezeTime,
    "profilePath": profilePath, "profileHash": profileHash, "profileGit": profileGit,
    "toolGit": toolGit, "toolSourceDeclared": (toolSource != nil), "frozen": frozen,
    "inputs": inputsBefore, "inputMismatches": inputMismatches]
let freezeManifestSha = sha256Bytes(canonical(freezeManifest))
freezeManifest["freezeManifestSha256"] = freezeManifestSha
writeJSON(freezeManifest, outDir + "/freeze-manifest.json")
if !inputMismatches.isEmpty {
    dieErr("REFUSING to build or run: " + inputMismatches.joined(separator: "; "))
}
if !buildOnly && !frozen && !allowUnfrozen {
    dieErr("REFUSING to run under an unfrozen profile/tool. profileClean=\(profileFrozen) toolClean=\(toolFrozen) profileStatus=\((profileGit["status"] as? String) ?? "") toolStatus=\((toolGit["status"] as? String) ?? ""). Commit the profile" + (toolSource != nil ? " and tool" : "") + " first, or pass --allow-unfrozen to record an explicitly NON-counted pre-freeze run.")
}

// ---- 1. Environment captured BEFORE the run (honest cache-state record) ----
let osBuild = cap("/usr/bin/sw_vers", ["-buildVersion"])
let osVer = cap("/usr/bin/sw_vers", ["-productVersion"])
let hwModel = cap("/usr/sbin/sysctl", ["-n", "hw.model"])
let chip = cap("/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"])
let coreml = cap("/usr/bin/defaults", ["read", "/System/Library/Frameworks/CoreML.framework/Resources/Info.plist", "CFBundleVersion"])
let e5cache = NSString(string: "~/Library/Caches/com.apple.e5rt.e5bundlecache").expandingTildeInPath
var e5Files: [String] = []
if let en = fm.enumerator(atPath: e5cache) { for case let f as String in en { var isDir: ObjCBool = false; let full = e5cache + "/" + f; if fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue { e5Files.append(f) } } }
let e5State: [String:Any] = ["path": e5cache, "fileCount": e5Files.count, "listingSha256": sha256Bytes(Data(e5Files.sorted().joined(separator: "\n").utf8))]
let memPressure = cap("/bin/zsh", ["-c", "memory_pressure | tail -1"])

// ---- 2. Rebuild runner from committed source (provenance leg) ----
let buildDir = outDir + "/build"
safeReset(buildDir)   // never reuse a stale runner_copied / runner_rebuilt from an earlier (scratch) run
var buildRecord: [String:Any] = ["rebuilt": false]
var runnerBin = ""
let doRebuild = (source["rebuild"] as? Bool) ?? false
if doRebuild {
    guard let repo = source["repo"] as? String, let commit = source["commit"] as? String,
          let probeFiles = source["probeFiles"] as? [String], let mainFile = source["mainFile"] as? String else { dieErr("source.rebuild requires repo/commit/probeFiles/mainFile") }
    let swiftcArgs = (source["swiftcArgs"] as? [String]) ?? ["-O"]
    var srcShas: [String:String] = [:]
    var compiled: [String] = []
    var mainCompiled = ""
    for pf in probeFiles {
        guard let blob = gitShow(repo, "\(commit):\(pf)") else { dieErr("git show failed for \(commit):\(pf)") }
        let base = (pf as NSString).lastPathComponent
        let dst = buildDir + "/" + base
        if fm.fileExists(atPath: dst) { dieErr("two probeFiles share the file name \(base); the build dir would hold only one of them") }
        do { try blob.write(to: URL(fileURLWithPath: dst)) } catch { dieErr("cannot write source file \(dst): \(error)") }
        srcShas[pf] = sha256Bytes(blob)
        if base == mainFile { mainCompiled = dst } else { compiled.append(dst) }
    }
    if mainCompiled.isEmpty { dieErr("mainFile \(mainFile) not among probeFiles") }
    let runnerOut = buildDir + "/runner_rebuilt"
    let swArgs = swiftcArgs + [mainCompiled] + compiled + ["-o", runnerOut]
    let (ec, so) = exec("/usr/bin/xcrun", ["swiftc"] + swArgs)
    let errLines = so.split(separator: "\n").filter { $0.contains("error:") }
    if ec != 0 || !errLines.isEmpty || !fm.fileExists(atPath: runnerOut) { dieErr("swiftc build failed (ec=\(ec)):\n\(so)") }
    runnerBin = runnerOut
    buildRecord = ["rebuilt": true, "repo": repo, "commit": commit,
                   "sourceBlobSha256": srcShas, "swiftcArgs": swiftcArgs,
                   "rebuiltRunnerSha256": sha256File(runnerOut) ?? "",
                   "baselineRunnerSha256": (source["baselineRunnerSha"] as? String) ?? "",
                   "rebuiltMatchesBaselineBinary": (sha256File(runnerOut) == (source["baselineRunnerSha"] as? String))]
} else {
    guard let pre = source["prebuilt"] as? String, fm.fileExists(atPath: pre) else { dieErr("source.rebuild=false requires an existing source.prebuilt binary") }
    // durable provenance: copy the binary's bytes (a symlink is resolved, never copied as a link) into the
    // receipt dir and record its sha (guard 5). A failed or differing copy is fatal.
    let resolved = (pre as NSString).resolvingSymlinksInPath
    guard let attrs = try? fm.attributesOfItem(atPath: resolved), (attrs[.type] as? FileAttributeType) == .typeRegular,
          let srcSha = sha256File(resolved) else { dieErr("source.prebuilt \(pre) does not resolve to a readable regular file") }
    let dst = buildDir + "/runner_copied"
    do { try fm.copyItem(atPath: resolved, toPath: dst) } catch { dieErr("cannot copy source.prebuilt \(resolved) into \(dst): \(error)") }
    guard let dstSha = sha256File(dst), dstSha == srcSha else { dieErr("copied runner \(dst) does not match source.prebuilt \(resolved)") }
    runnerBin = dst
    buildRecord = ["rebuilt": false, "copiedFrom": pre, "copiedFromResolved": resolved, "runnerSha256": dstSha,
                   "declaredCommit": (source["commit"] as? String) ?? "", "sourceRebuildVerified": false]
}

if buildOnly {
    writeJSON(["profileHash": profileHash, "build": buildRecord, "env": ["osBuild": osBuild, "coreml": coreml], "freeze": freezeManifest], outDir + "/build-only.json")
    print("BUILD_ONLY ok runner=\(runnerBin)"); exit(0)
}

// ---- CONTROL MODE (B2/B3): run every arm with the SAME source-rebuilt binary, record each under the profile-keyed ledger, emit a control receipt ----
if controlMode {
    guard let control = profile["control"] as? [String:Any],
          let arms = control["arms"] as? [[String:Any]], !arms.isEmpty else { dieErr("--control requires a non-empty profile.control.arms") }
    guard (buildRecord["rebuilt"] as? Bool) ?? false else { dieErr("--control requires source.rebuild=true (binary must be source-verified)") }
    guard let fixtureC = runSpec["fixture"] as? String, let tsvC = runSpec["tsv"] as? String else { dieErr("run.fixture and run.tsv required") }
    let tokensC = (runSpec["tokens"] as? String) ?? "270"
    let argvModeC = (runSpec["argvMode"] as? String) ?? "fixture"
    let binSha = sha256File(runnerBin) ?? ""
    var ctlCommittedProfileSha = profileHash
    if let commit = profileGit["commit"] as? String, !commit.isEmpty, let repoRoot = profileGit["repoRoot"] as? String {
        let pAbs = (profilePath as NSString).isAbsolutePath ? profilePath : (fm.currentDirectoryPath + "/" + profilePath)
        let rel = exec("/usr/bin/git", ["-C", repoRoot, "ls-files", "--full-name", "--", pAbs]).1.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rel.isEmpty, let blob = gitShow(repoRoot, "\(commit):\(rel)"), let parsed = try? JSONSerialization.jsonObject(with: blob) {
            ctlCommittedProfileSha = sha256Bytes(canonical(parsed))
            try? blob.write(to: URL(fileURLWithPath: outDir + "/committed-profile.json"))
        }
    }
    var newCtlRecords: [[String:Any]] = []
    var ctlDurableOk = true
    var armResults: [[String:Any]] = []
    var allArmsOk = true
    var allInputsUnchanged = true
    var inputsAfterArms: [String:Any] = [:]
    for arm in arms {
        // names and env were validated before the build (inputMismatches); these guards cannot fail here
        guard let name = arm["name"] as? String else { dieErr("control arm without a name") }
        guard let armEnv = (arm["env"] == nil) ? [:] : (arm["env"] as? [String:String]) else { dieErr("control arm \(name): env must map names to string values") }
        let dDir = outDir + "/dump_" + name
        safeReset(dDir)
        let aTmp = outDir + "/tmp_" + name; safeReset(aTmp)
        var aenv = ProcessInfo.processInfo.environment
        aenv.removeValue(forKey: "LFM3_PROBE_CPU_LAYERS")
        aenv["TMPDIR"] = aTmp + "/"
        aenv["LFM3_ANCHOR_LAYERS"] = (runSpec["anchorLayers"] as? String) ?? "14"
        aenv["LFM3_VECTOR_DUMP_DIR"] = dDir
        aenv["LFM3_VECTOR_DUMP_POSITIONS"] = (runSpec["dumpPositions"] as? String) ?? "161,203,217"
        aenv["LFM3_VECTOR_DUMP_LAYERS"] = (runSpec["dumpLayers"] as? String) ?? "14"
        aenv["LFM3_RESULT_JSON"] = outDir + "/result_" + name + ".json"
        if let cu = runSpec["computeUnits"] as? String { aenv["LFM3_COMPUTE_UNITS"] = cu }
        for (k, v) in armEnv { aenv[k] = v }
        let aLog = outDir + "/log_" + name + ".txt"
        let s0 = Date(); let sIso = ISO8601DateFormatter().string(from: s0)
        // Record BEFORE executing; if the record cannot be made durable, refuse to execute (keep arms already run).
        if !appendDurable(["kind": "run_started", "profileHash": profileHash, "mode": "control", "arm": name, "outDir": outDir, "runStartedAt": sIso, "frozen": frozen, "counted": frozen, "profileCommit": (profileGit["commit"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "", "freezeManifestSha256": freezeManifestSha]) {
            if !newCtlRecords.isEmpty { _ = appendLedger(newCtlRecords) }
            dieErr("REFUSING to run arm \(name): cannot durably record run_started in \(durableExecLogPath)")
        }
        let (aec, _) = exec(runnerBin, [argvModeC, fixtureC, tsvC, tokensC], env: aenv, stdoutPath: aLog)
        let aWall = Int(Date().timeIntervalSince(s0))
        let armInputsAfter = inputState()
        let armInputsUnchanged = NSDictionary(dictionary: inputsBefore).isEqual(to: armInputsAfter)
        if !armInputsUnchanged { allInputsUnchanged = false; warnErr("an input changed during arm \(name); this arm is not counted as passed") }
        inputsAfterArms[name] = armInputsAfter
        let dumpFiles = dumpRecords(dDir)
        let dumpReadable = !dumpFiles.contains { ($0["sha256"] as? String) == "unreadable" }
        if !dumpReadable { warnErr("arm \(name): part of the dump could not be read; this arm is not counted as passed") }
        let okArm = (aec == 0 && !dumpFiles.isEmpty && armInputsUnchanged && dumpReadable)
        if !okArm { allArmsOk = false }
        if !appendDurable(["kind": "run_completed", "profileHash": profileHash, "mode": "control", "arm": name, "outDir": outDir, "runStartedAt": sIso, "exitCode": Int(aec), "wallSeconds": aWall, "counted": frozen, "inputsUnchanged": armInputsUnchanged, "passed": okArm, "freezeManifestSha256": freezeManifestSha]) {
            ctlDurableOk = false; warnErr("could not durably record run_completed for arm \(name) in \(durableExecLogPath)")
        }
        // byteIdentical stays false: a control arm is not compared to a baseline. "passed" is the arm's own result.
        newCtlRecords.append(["timestamp": ISO8601DateFormatter().string(from: Date()), "profileHash": profileHash,
            "mode": "control", "arm": name, "exitCode": Int(aec), "wallSeconds": aWall,
            "frozen": frozen, "counted": frozen, "byteIdentical": false, "inputsUnchanged": armInputsUnchanged, "passed": okArm,
            "runStartedAt": sIso, "profileCommit": (profileGit["commit"] as? String) ?? "",
            "toolCommit": (toolGit["commit"] as? String) ?? "", "freezeManifestSha256": freezeManifestSha,
            "runnerSha256": binSha, "dumpDir": dDir, "dumpFileCount": dumpFiles.count])
        armResults.append(["name": name, "exitCode": Int(aec), "wallSeconds": aWall, "runStartedAt": sIso,
            "inputsUnchanged": armInputsUnchanged, "passed": okArm,
            "dumpDir": dDir, "envDelta": armEnv, "runnerSha256": binSha, "dumpFileCount": dumpFiles.count, "dumpFiles": dumpFiles])
    }
    let (runsLogC, _, ctlLedgerOk) = appendLedger(newCtlRecords)
    if !ctlLedgerOk { warnErr("could not write run ledger \(runsLogPath); the device-wide execution log still holds these runs") }
    let totalRunsC = runsLogC.count
    let countedRunsC = runsLogC.filter { ($0["counted"] as? Bool) ?? false }.count
    var ctlReceipt: [String:Any] = [
        "schema": "macbrains.research.cleanroom-control.v1",
        "generatedAt": ISO8601DateFormatter().string(from: Date()), "toolStartedAt": iso,
        "profileId": (profile["id"] as? String) ?? "", "criterion": (profile["criterion"] as? String) ?? "",
        "profileHash": profileHash, "mode": "control",
        "inputs": ["before": inputsBefore, "afterEachArm": inputsAfterArms, "unchanged": allInputsUnchanged],
        "sameChipCleanRoom": true, "crossDeviceReplication": false,
        "claimScope": "Same-chip, same-binary CPU-vs-ANE layer-14 control under a frozen, committed profile and runner. ANE placement is Core ML compute-plan assignment (INFERRED), not a hardware execution trace.",
        "device": ["hwModel": hwModel, "chip": chip, "osVersion": osVer, "osBuild": osBuild, "coreMLBundleVersion": coreml],
        "e5CacheStateBefore": e5State, "memoryPressureBefore": memPressure,
        "build": buildRecord, "sameBinary": true, "binarySha256": binSha,
        "arms": armResults, "armCount": armResults.count,
        "frozen": frozen,
        "freeze": ["freezeManifestSha256": freezeManifestSha, "freezeTime": freezeTime,
            "profileCommit": (profileGit["commit"] as? String) ?? "", "profileCommitTime": (profileGit["commitTime"] as? String) ?? "",
            "toolCommit": (toolGit["commit"] as? String) ?? "", "toolCommitTime": (toolGit["commitTime"] as? String) ?? "",
            "toolSourceDeclared": (toolSource != nil), "committedProfileBlobSha256": ctlCommittedProfileSha],
        "runAccounting": ["totalRuns": totalRunsC, "countedRuns": countedRunsC, "preFreezeRunsNotCounted": totalRunsC - countedRunsC,
            "ledgerPath": runsLogPath, "ledgerProfileScoped": (runsLogExplicit == nil)],
        "executionLog": execLogSummary(),
        "expected": expected,
        "verdict": !frozen ? "NOT_FROZEN_NOT_COUNTED" : (!allInputsUnchanged ? "INPUTS_CHANGED_DURING_RUN" : (allArmsOk ? "CONTROL_OK_SAME_BINARY_FROZEN_COUNTED" : "CONTROL_ARM_FAILED"))
    ]
    let cLegacy = sha256Bytes(canonical(ctlReceipt)); ctlReceipt["receiptSha256"] = cLegacy
    let cSelf = sha256Bytes(canonical(ctlReceipt)); ctlReceipt["receiptSelfHash"] = cSelf
    let cPath = outDir + "/cleanroom-control-receipt.json"
    if !writeJSON(ctlReceipt, cPath) { dieErr("could not write control receipt \(cPath)") }
    print("CONTROL verdict=\(ctlReceipt["verdict"]!) arms=\(armResults.count) sameBinary=true counted=\(countedRunsC)/\(totalRunsC)")
    print("receipt=\(cPath) sha256=\(cSelf)")
    exit((frozen && allArmsOk && ctlDurableOk && ctlLedgerOk) ? 0 : 1)
}

// ---- 3. Run in a fresh isolated process ----
let dumpDir = outDir + "/dump"
safeReset(dumpDir)
let freshTmp = outDir + "/tmp"; safeReset(freshTmp)
guard let fixture = runSpec["fixture"] as? String, let tsv = runSpec["tsv"] as? String else { dieErr("run.fixture and run.tsv required") }
let tokens = (runSpec["tokens"] as? String) ?? "270"
let argvMode = (runSpec["argvMode"] as? String) ?? "fixture"
var renv = ProcessInfo.processInfo.environment
renv["TMPDIR"] = freshTmp + "/"
renv["LFM3_COMPUTE_UNITS"] = (runSpec["computeUnits"] as? String) ?? "cpuAndNeuralEngine"
renv["LFM3_ANCHOR_LAYERS"] = (runSpec["anchorLayers"] as? String) ?? "14"
renv["LFM3_VECTOR_DUMP_DIR"] = dumpDir
renv["LFM3_VECTOR_DUMP_POSITIONS"] = (runSpec["dumpPositions"] as? String) ?? "161,203,217"
renv["LFM3_VECTOR_DUMP_LAYERS"] = (runSpec["dumpLayers"] as? String) ?? "14"
renv["LFM3_RESULT_JSON"] = outDir + "/result.json"
let logPath = outDir + "/run.log"
let sandbox = (isolation["sandboxExec"] as? Bool) ?? false
let t0 = Date()
let runStartedAtIso = ISO8601DateFormatter().string(from: t0)
// Record BEFORE executing; if the record cannot be made durable, refuse to execute at all.
if !appendDurable(["kind": "run_started", "profileHash": profileHash, "mode": "replication", "outDir": outDir, "runStartedAt": runStartedAtIso, "frozen": frozen, "counted": frozen, "profileCommit": (profileGit["commit"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "", "freezeManifestSha256": freezeManifestSha]) {
    dieErr("REFUSING to run: cannot durably record run_started in \(durableExecLogPath)")
}
var ec: Int32 = -1
if sandbox {
    // filesystem confinement: reads anywhere, writes only under outDir + system tmp; ANE XPC allowed via (allow default) minus file-write*. If ANE breaks, honest record below.
    let sbProfile = freshTmp + "/cleanroom.sb"
    let sb = "(version 1)\n(allow default)\n(deny file-write*)\n(allow file-write* (subpath \"\(outDir)\") (subpath \"/private/var/folders\") (subpath \"/dev\"))\n"
    try? sb.write(to: URL(fileURLWithPath: sbProfile), atomically: true, encoding: .utf8)
    (ec, _) = exec("/usr/bin/sandbox-exec", ["-f", sbProfile, runnerBin, argvMode, fixture, tsv, tokens], env: renv, stdoutPath: logPath)
} else {
    (ec, _) = exec(runnerBin, [argvMode, fixture, tsv, tokens], env: renv, stdoutPath: logPath)
}
let wall = Int(Date().timeIntervalSince(t0))

// ---- 4. Byte-compare to the frozen baseline (using baseline`s own recorded hashes) ----
// baselineFiles was validated before the build (relative paths inside the dump dir, 64-hex sha256, non-empty).
// Any regular file or symlink in the dump that the baseline does not list counts as extra and fails the
// compare, except a top-level index.json, the runner's own listing of the dump.
var identical = 0, differing = 0, missing = 0, extra = 0
var diffs: [String] = []
var listed = Set<String>()
for (rel, want) in baselineFiles {
    listed.insert(rel)
    let full = dumpDir + "/" + rel
    let isLink = ((try? fm.attributesOfItem(atPath: full))?[.type] as? FileAttributeType) == .typeSymbolicLink
    let regular = !isLink && isRegularFileResolved(full)
    let got = regular ? sha256File(full) : nil
    if got == nil { missing += 1; diffs.append(isLink ? "SYMLINK \(rel)" : (fm.fileExists(atPath: full) && !regular ? "NOT_A_FILE \(rel)" : "MISSING \(rel)")) }
    else if got == want { identical += 1 }
    else { differing += 1; diffs.append("DIFF \(rel) want=\(want) got=\(got!)") }
}
let dumpWalk = walkDump(dumpDir)
for rel in dumpWalk.entries {
    let t = (try? fm.attributesOfItem(atPath: dumpDir + "/" + rel))?[.type] as? FileAttributeType
    if t == .typeDirectory || rel == "index.json" || listed.contains(rel) { continue }
    extra += 1; diffs.append("EXTRA \(rel)")
}
for rel in dumpWalk.unreadable { extra += 1; diffs.append("UNREADABLE \(rel)") }
let logTail = (try? String(contentsOfFile: logPath, encoding: .utf8))?.split(separator: "\n").suffix(3).joined(separator: " | ") ?? ""
let planSummary = (try? String(contentsOfFile: logPath, encoding: .utf8))?.split(separator: "\n").first(where: { $0.contains("FULL_PLAN_SUMMARY") }).map(String.init) ?? ""
let byteIdentical = (differing == 0 && missing == 0 && extra == 0 && identical > 0)
let inputsAfter = inputState()
let inputsUnchanged = NSDictionary(dictionary: inputsBefore).isEqual(to: inputsAfter)
if !inputsUnchanged { warnErr("an input changed during the run; this run is not counted as passed") }

// ---- 5. Append immutable run record (never discard) ----
let counted = frozen
let passed = byteIdentical && inputsUnchanged
let runRecord: [String:Any] = ["timestamp": ISO8601DateFormatter().string(from: Date()), "profileHash": profileHash, "mode": "replication",
    "exitCode": Int(ec), "wallSeconds": wall, "byteIdentical": byteIdentical, "inputsUnchanged": inputsUnchanged, "passed": passed,
    "identical": identical, "differing": differing, "missing": missing, "extra": extra,
    "osBuild": osBuild, "e5CacheFileCountBefore": e5Files.count, "sandbox": sandbox,
    "method": "cli", "frozen": frozen, "counted": counted,
    "profileCommit": (profileGit["commit"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "",
    "runStartedAt": runStartedAtIso, "freezeManifestSha256": freezeManifestSha]
let (runsLog, runIndex, ledgerOk) = appendLedger([runRecord])
if !ledgerOk { warnErr("could not write run ledger \(runsLogPath); the device-wide execution log still holds this run") }
let completedOk = appendDurable(["kind": "run_completed", "profileHash": profileHash, "mode": "replication", "outDir": outDir, "runIndex": runIndex, "runStartedAt": runStartedAtIso, "byteIdentical": byteIdentical, "inputsUnchanged": inputsUnchanged, "passed": passed, "counted": counted, "exitCode": Int(ec), "freezeManifestSha256": freezeManifestSha])
if !completedOk { warnErr("could not durably record run_completed in \(durableExecLogPath)") }
let totalRuns = runsLog.count
let countedRuns = runsLog.filter { ($0["counted"] as? Bool) ?? false }.count
let preFreezeRuns = totalRuns - countedRuns

// committed profile blob: canonical-JSON hash of the profile read from its commit (matches policy committedProfileBlobSha256)
let profileAbsForBlob = (profilePath as NSString).isAbsolutePath ? profilePath : (FileManager.default.currentDirectoryPath + "/" + profilePath)
var committedProfileBlobSha = profileHash
var committedProfileBytes: Data? = nil
if let commit = profileGit["commit"] as? String, !commit.isEmpty, let repoRoot = profileGit["repoRoot"] as? String {
    let rel = exec("/usr/bin/git", ["-C", repoRoot, "ls-files", "--full-name", "--", profileAbsForBlob]).1.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rel.isEmpty, let blob = gitShow(repoRoot, "\(commit):\(rel)"), let parsed = try? JSONSerialization.jsonObject(with: blob) {
        committedProfileBlobSha = sha256Bytes(canonical(parsed))
        committedProfileBytes = blob
    }
}
if let cpb = committedProfileBytes { try? cpb.write(to: URL(fileURLWithPath: outDir + "/committed-profile.json")) }
// A record's own "passed" wins; an older record without it passes when byteIdentical (control arms of older
// tools therefore list as not passed). mode and arm say which kind of run each entry is.
let runsArray: [[String:Any]] = runsLog.map { r in
    ["index": r["runIndex"] ?? 0, "counted": (r["counted"] as? Bool) ?? false,
     "mode": (r["mode"] as? String) ?? "replication", "arm": (r["arm"] as? String) ?? "",
     "passed": (r["passed"] as? Bool) ?? (((r["byteIdentical"] as? Bool) ?? false) && ((r["inputsUnchanged"] as? Bool) ?? true)),
     "inputsChecked": r["inputsUnchanged"] != nil, "runStartedAt": r["runStartedAt"] ?? ""]
}
let inputsCheckedRuns = runsLog.filter { $0["inputsUnchanged"] != nil }.count


// ---- 6. Emit replication receipt ----
let receipt: [String:Any] = [
    "schema": "macbrains.research.cleanroom-replication.v1",
    "generatedAt": ISO8601DateFormatter().string(from: Date()), "toolStartedAt": iso,
    "profileId": (profile["id"] as? String) ?? "",
    "criterion": (profile["criterion"] as? String) ?? "",
    "profileHash": profileHash,
    "runIndex": runIndex,
    "sameChipCleanRoom": true,
    "crossDeviceReplication": false,
    "claimScope": "Deterministic, source-rebuilt, same-chip / same-OS-build replication with recorded environment. NOT cross-device and NOT a hardware execution trace; ANE placement is Core ML compute-plan assignment.",
    "device": ["hwModel": hwModel, "chip": chip, "osVersion": osVer, "osBuild": osBuild, "coreMLBundleVersion": coreml],
    "e5CacheStateBefore": e5State,
    "memoryPressureBefore": memPressure,
    "build": buildRecord,
    "run": ["computeUnits": renv["LFM3_COMPUTE_UNITS"] ?? "", "tokens": tokens, "fixture": fixture, "tsv": tsv, "sandbox": sandbox, "exitCode": Int(ec), "wallSeconds": wall, "runStartedAt": runStartedAtIso, "planSummary": planSummary, "logTail": logTail],
    "frozen": frozen,
    "freeze": ["freezeManifestSha256": freezeManifestSha, "freezeTime": freezeTime, "profileCommit": (profileGit["commit"] as? String) ?? "", "profileCommitTime": (profileGit["commitTime"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "", "toolCommitTime": (toolGit["commitTime"] as? String) ?? "", "headCommit": (profileGit["headCommit"] as? String) ?? "", "toolSourceDeclared": (toolSource != nil), "committedProfileBlobSha256": committedProfileBlobSha],
    "runs": runsArray,
    "runAccounting": ["totalRuns": totalRuns, "countedRuns": countedRuns, "preFreezeRunsNotCounted": preFreezeRuns, "thisRunCounted": counted, "inputsCheckedRuns": inputsCheckedRuns],
    "executionLog": execLogSummary(),
    "comparison": ["baselineIndex": (baseline["indexJson"] as? String) ?? "", "identical": identical, "differing": differing, "missing": missing, "extra": extra, "byteIdentical": byteIdentical, "diffs": Array(diffs.prefix(20))],
    "expected": expected,
    "permittedModifications": (profile["permittedModifications"] as? [Any]) ?? [],
    "inputs": ["before": inputsBefore, "after": inputsAfter, "unchanged": inputsUnchanged],
    "verdict": (!frozen) ? "NOT_FROZEN_NOT_COUNTED" : (!inputsUnchanged ? "INPUTS_CHANGED_DURING_RUN" : (byteIdentical ? "REPLICATED_SAME_CHIP_BYTE_IDENTICAL" : "NOT_BYTE_IDENTICAL"))
]
let receiptBase = receipt
let legacyReceiptSha = sha256Bytes(canonical(receiptBase))
var withLegacy = receiptBase; withLegacy["receiptSha256"] = legacyReceiptSha
let selfHash = sha256Bytes(canonical(withLegacy))
var finalReceipt = withLegacy; finalReceipt["receiptSelfHash"] = selfHash
let receiptPath = outDir + "/cleanroom-receipt.json"
if !writeJSON(finalReceipt, receiptPath) { dieErr("could not write receipt \(receiptPath)") }
print("CLEANROOM verdict=\(receipt["verdict"]!) identical=\(identical) differing=\(differing) missing=\(missing) extra=\(extra) inputsUnchanged=\(inputsUnchanged) wall=\(wall)s runIndex=\(runIndex) frozen=\(frozen) counted=\(countedRuns)/\(totalRuns)")
print("receipt=\(receiptPath) sha256=\(selfHash)")
exit(byteIdentical && inputsUnchanged && frozen && ledgerOk && completedOk ? 0 : 1)
