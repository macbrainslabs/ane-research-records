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

func sha256File(_ path: String) -> String? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
guard let profilePath = opt("--profile") else { dieErr("usage: cleanroom --profile P.json --out DIR [--runs-log L.json] [--tool-source cleanroom.swift] [--allow-unfrozen] [--build-only] [--control] [--ledger-dir D] [--allow-clobber] [--runs N]") }
// Absolute, standardized output dir: relative forms ("." , "./x", "../x") must not defeat the lexical scratch-dir checks.
let outDir: String = {
    let raw = opt("--out") ?? "cleanroom-out"
    let abs = raw.hasPrefix("/") ? raw : (FileManager.default.currentDirectoryPath + "/" + raw)
    return URL(fileURLWithPath: abs).standardized.path   // drops "." and ".." only; no symlink or /private rewriting
}()
let runsLogExplicit = opt("--runs-log")
let ledgerDir = opt("--ledger-dir") ?? (accountHome() + "/.local/share/anvil/cleanroom-ledger")
let buildOnly = args.contains("--build-only")
let controlMode = args.contains("--control")
let allowUnfrozen = args.contains("--allow-unfrozen")
let toolSource = opt("--tool-source")
// --runs N: run a frozen SET of N replication runs under ONE freeze manifest and ONE build (see step 3).
let runsRequested: Int? = {
    guard args.contains("--runs") else { return nil }
    guard let r = opt("--runs"), let n = Int(r), n >= 1, n <= 50 else { dieErr("--runs requires an integer from 1 to 50") }
    return n
}()
if runsRequested != nil && (controlMode || buildOnly) { dieErr("--runs applies to replication runs only, not --control or --build-only") }
let fm = FileManager.default
// Guard (reviewer HOLD H1/B): cleanroom NEVER deletes a run directory. safeReset clears only a scratch
// subdir strictly inside outDir; it refuses outDir itself, any ancestor, or anything outside outDir.
// A failed removal is fatal: silently keeping stale dumps could let a failed run compare byte-identical.
// Lexical only (no filesystem lookups): NSString.standardizingPath drops a leading /private only when
// the shorter path exists, so an existing --out and a not-yet-created subdir under /private/... compared
// unequal and every reset was refused.
func lexicalPath(_ p: String) -> String {
    var parts: [Substring] = []
    for c in p.split(separator: "/", omittingEmptySubsequences: true) {
        if c == "." { continue }
        if c == ".." { if !parts.isEmpty { parts.removeLast() }; continue }
        parts.append(c)
    }
    return "/" + parts.joined(separator: "/")
}
func safeReset(_ p: String) {
    let a = lexicalPath(p)
    let o = lexicalPath(outDir)
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

guard let pdata = fm.contents(atPath: profilePath),
      let profile = (try? JSONSerialization.jsonObject(with: pdata)) as? [String:Any] else { dieErr("cannot read profile JSON: \(profilePath)") }
let profileHash = sha256Bytes(canonical(profile))
durableExecLogPath = accountHome() + "/.local/state/anvil/execution-log/" + profileHash + ".jsonl"
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

// ---- Set-mode preflight (BEFORE the freeze manifest): one counted set per profile hash, inputs present ----
if runsRequested != nil {
    let logExists = (try? fm.attributesOfItem(atPath: durableExecLogPath)) != nil
    let logData = fm.contents(atPath: durableExecLogPath)
    let hasLogLine = logExists && (logData == nil || logData!.contains(where: { $0 != 0x0A && $0 != 0x0D && $0 != 0x20 && $0 != 0x09 }))
    let priorLedger = loadLedger(runsLogPath)
    if hasLogLine || !priorLedger.isEmpty {
        dieErr("REFUSING: profile_hash_already_has_runs: profile hash \(profileHash) already has runs (execution log \(durableExecLogPath) \(hasLogLine ? "has lines" : "has no lines"), ledger \(runsLogPath) holds \(priorLedger.count) records). One counted set per profile hash: commit a new profile id for a new set.")
    }
    func inputsMissing(_ which: String) -> Never { dieErr("REFUSING: inputs_missing: \(which)") }
    guard let fx = runSpec["fixture"] as? String, fm.fileExists(atPath: fx) else { inputsMissing("run.fixture") }
    guard let tv = runSpec["tsv"] as? String, fm.fileExists(atPath: tv) else { inputsMissing("run.tsv") }
    guard let bidx = baseline["indexJson"] as? String, let bd = fm.contents(atPath: bidx),
          let bj = (try? JSONSerialization.jsonObject(with: bd)) as? [String:Any],
          let bfiles = bj["files"] as? [[String:Any]], !bfiles.isEmpty else { inputsMissing("baseline.indexJson") }
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
    "toolGit": toolGit, "toolSourceDeclared": (toolSource != nil), "frozen": frozen]
let freezeManifestSha = sha256Bytes(canonical(freezeManifest))
freezeManifest["freezeManifestSha256"] = freezeManifestSha
if !writeJSON(freezeManifest, outDir + "/freeze-manifest.json") { dieErr("REFUSING: could not write freeze manifest \(outDir)/freeze-manifest.json") }
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
        try? blob.write(to: URL(fileURLWithPath: dst))
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
    // durable provenance: copy the binary into the receipt dir, record its sha (guard 5)
    let dst = buildDir + "/runner_copied"
    try? fm.copyItem(atPath: pre, toPath: dst)
    runnerBin = dst
    buildRecord = ["rebuilt": false, "copiedFrom": pre, "runnerSha256": sha256File(dst) ?? "",
                   "declaredCommit": (source["commit"] as? String) ?? "", "sourceRebuildVerified": false]
}

if buildOnly {
    writeJSON(["profileHash": profileHash, "build": buildRecord, "env": ["osBuild": osBuild, "coreml": coreml], "freeze": freezeManifest], outDir + "/build-only.json")
    print("BUILD_ONLY ok runner=\(runnerBin)"); exit(0)
}

// ---- CONTROL MODE (B2/B3): run every arm with the SAME source-rebuilt binary, record each under the profile-keyed ledger, emit a control receipt ----
if controlMode {
    guard let control = profile["control"] as? [String:Any],
          let arms = control["arms"] as? [[String:Any]] else { dieErr("--control requires profile.control.arms") }
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
    for arm in arms {
        guard let name = arm["name"] as? String else { continue }
        let armEnv = (arm["env"] as? [String:String]) ?? [:]
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
        if !appendDurable(["kind": "run_completed", "profileHash": profileHash, "mode": "control", "arm": name, "outDir": outDir, "runStartedAt": sIso, "exitCode": Int(aec), "wallSeconds": aWall, "counted": frozen, "freezeManifestSha256": freezeManifestSha]) {
            ctlDurableOk = false; warnErr("could not durably record run_completed for arm \(name) in \(durableExecLogPath)")
        }
        var dumpFiles: [[String:Any]] = []
        if let en = fm.enumerator(atPath: dDir) {
            for case let f as String in en {
                var isDir: ObjCBool = false; let full = dDir + "/" + f
                if fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue {
                    dumpFiles.append(["path": f, "sha256": sha256File(full) ?? ""])
                }
            }
        }
        dumpFiles.sort { (($0["path"] as? String) ?? "") < (($1["path"] as? String) ?? "") }
        let okArm = (aec == 0 && !dumpFiles.isEmpty)
        if !okArm { allArmsOk = false }
        newCtlRecords.append(["timestamp": ISO8601DateFormatter().string(from: Date()), "profileHash": profileHash,
            "mode": "control", "arm": name, "exitCode": Int(aec), "wallSeconds": aWall,
            "frozen": frozen, "counted": frozen, "byteIdentical": false,
            "runStartedAt": sIso, "profileCommit": (profileGit["commit"] as? String) ?? "",
            "toolCommit": (toolGit["commit"] as? String) ?? "", "freezeManifestSha256": freezeManifestSha,
            "runnerSha256": binSha, "dumpDir": dDir, "dumpFileCount": dumpFiles.count])
        armResults.append(["name": name, "exitCode": Int(aec), "wallSeconds": aWall, "runStartedAt": sIso,
            "dumpDir": dDir, "envDelta": armEnv, "runnerSha256": binSha, "dumpFileCount": dumpFiles.count, "dumpFiles": dumpFiles])
    }
    let (runsLogC, _, ctlLedgerOk) = appendLedger(newCtlRecords)
    if !ctlLedgerOk { warnErr("could not write run ledger \(runsLogPath); the device-wide execution log still holds these runs") }
    let totalRunsC = runsLogC.count
    let countedRunsC = runsLogC.filter { ($0["counted"] as? Bool) ?? false }.count
    var ctlReceipt: [String:Any] = [
        "schema": "macbrains.research.cleanroom-control.v1",
        "generatedAt": iso, "profileId": (profile["id"] as? String) ?? "", "criterion": (profile["criterion"] as? String) ?? "",
        "profileHash": profileHash, "mode": "control",
        "sameChipCleanRoom": true, "crossDeviceReplication": false,
        "claimScope": (expected["claimScope"] as? String) ?? "Same-chip, same-binary control: arms differ only by their declared environment, under a frozen, committed profile and runner. Not cross-device. ANE placement is Core ML compute-plan assignment (INFERRED), not a hardware execution trace.",
        "claimScopeSource": (expected["claimScope"] is String) ? "profile.expected.claimScope" : "default",
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
        "verdict": (frozen && allArmsOk) ? "CONTROL_OK_SAME_BINARY_FROZEN_COUNTED" : (!frozen ? "NOT_FROZEN_NOT_COUNTED" : "CONTROL_ARM_FAILED")
    ]
    let cLegacy = sha256Bytes(canonical(ctlReceipt)); ctlReceipt["receiptSha256"] = cLegacy
    let cSelf = sha256Bytes(canonical(ctlReceipt)); ctlReceipt["receiptSelfHash"] = cSelf
    let cPath = outDir + "/cleanroom-control-receipt.json"
    if !writeJSON(ctlReceipt, cPath) { dieErr("could not write control receipt \(cPath)") }
    print("CONTROL verdict=\(ctlReceipt["verdict"]!) arms=\(armResults.count) sameBinary=true counted=\(countedRunsC)/\(totalRunsC)")
    print("receipt=\(cPath) sha256=\(cSelf)")
    exit((frozen && allArmsOk && ctlDurableOk && ctlLedgerOk) ? 0 : 1)
}

// ---- 3-6. Replication: one run (legacy) or a frozen SET of runs (--runs N) ----
// Set mode (--runs N): ONE freeze manifest (written above, before any run) and ONE build, then N runs,
// each in its own fresh run directory <out>/run-NNN. Every run is recorded run_started/run_completed in
// the device-wide log and appended to the profile-keyed ledger (pass or fail, never discarded); ONE
// receipt covers the set. Before every run the freeze is re-verified (profile bytes, profile and tool
// still clean at their freeze commits) and the runner binary is re-hashed; if anything changed, the set
// stops (no further runs) and the receipt says SET_INCOMPLETE. Without --runs the tool behaves exactly
// as before: one run directly in <out>.
// Set mode refuses BEFORE the freeze manifest (exit 2) when the profile hash already has runs (device
// execution log has a line, or the profile ledger is non-empty: one counted set per profile hash) or
// when its inputs are missing (run.fixture, run.tsv, baseline.indexJson with a non-empty files[]).
guard let fixture = runSpec["fixture"] as? String, let tsv = runSpec["tsv"] as? String else { dieErr("run.fixture and run.tsv required") }
let tokens = (runSpec["tokens"] as? String) ?? "270"
let argvMode = (runSpec["argvMode"] as? String) ?? "fixture"
let sandbox = (isolation["sandboxExec"] as? Bool) ?? false
let computeUnits = (runSpec["computeUnits"] as? String) ?? "cpuAndNeuralEngine"
let counted = frozen
let setMode = (runsRequested != nil)
let runsToDo = runsRequested ?? 1
let runnerShaAtBuild = sha256File(runnerBin) ?? ""

func freezeStillHolds() -> (Bool, String) {
    guard let d = fm.contents(atPath: profilePath), let p = try? JSONSerialization.jsonObject(with: d) else { return (false, "profile unreadable") }
    if sha256Bytes(canonical(p)) != profileHash { return (false, "profile content changed") }
    let pg = fileGitState(profilePath)
    if !((pg["clean"] as? Bool) ?? false) || (pg["commit"] as? String) != (profileGit["commit"] as? String) {
        return (false, "profile no longer clean at its freeze commit")
    }
    if let ts = toolSource {
        let tg = fileGitState(ts)
        if !((tg["clean"] as? Bool) ?? false) || (tg["commit"] as? String) != (toolGit["commit"] as? String) {
            return (false, "tool source no longer clean at its freeze commit")
        }
    }
    return (true, "")
}

var ledgerSnapshot: [[String:Any]] = []
var allLedgerOk = true
var allCompletedOk = true

// One execution in runDir (== outDir in legacy mode). Returns nil if run_started could not be made durable
// (nothing was executed).
func runOnce(_ runDir: String) -> [String:Any]? {
    let dumpDir = runDir + "/dump"
    safeReset(dumpDir)
    let freshTmp = runDir + "/tmp"; safeReset(freshTmp)
    var renv = ProcessInfo.processInfo.environment
    renv["TMPDIR"] = freshTmp + "/"
    renv["LFM3_COMPUTE_UNITS"] = computeUnits
    renv["LFM3_ANCHOR_LAYERS"] = (runSpec["anchorLayers"] as? String) ?? "14"
    renv["LFM3_VECTOR_DUMP_DIR"] = dumpDir
    renv["LFM3_VECTOR_DUMP_POSITIONS"] = (runSpec["dumpPositions"] as? String) ?? "161,203,217"
    renv["LFM3_VECTOR_DUMP_LAYERS"] = (runSpec["dumpLayers"] as? String) ?? "14"
    renv["LFM3_RESULT_JSON"] = runDir + "/result.json"
    let logPath = runDir + "/run.log"
    let t0 = Date()
    // Set mode records runStartedAt with fractional seconds (exec log, ledger, receipt); legacy keeps whole seconds.
    let runStartedAtIso: String = {
        let f = ISO8601DateFormatter()
        if setMode { f.formatOptions = [.withInternetDateTime, .withFractionalSeconds] }
        return f.string(from: t0)
    }()
    // Record BEFORE executing; if the record cannot be made durable, do not execute.
    if !appendDurable(["kind": "run_started", "profileHash": profileHash, "mode": "replication", "outDir": runDir, "runStartedAt": runStartedAtIso, "frozen": frozen, "counted": counted, "profileCommit": (profileGit["commit"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "", "freezeManifestSha256": freezeManifestSha]) {
        return nil
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

    // Byte-compare to the frozen baseline (using the baseline`s own recorded hashes).
    var identical = 0, differing = 0, missing = 0
    var diffs: [String] = []
    if let bidx = baseline["indexJson"] as? String, let bd = fm.contents(atPath: bidx),
       let bj = (try? JSONSerialization.jsonObject(with: bd)) as? [String:Any],
       let files = bj["files"] as? [[String:Any]] {
        for f in files {
            guard let rel = f["path"] as? String, let want = f["sha256"] as? String else { continue }
            let got = sha256File(dumpDir + "/" + rel)
            if got == nil { missing += 1; diffs.append("MISSING \(rel)") }
            else if got == want { identical += 1 }
            else { differing += 1; diffs.append("DIFF \(rel) want=\(want) got=\(got!)") }
        }
    } else { diffs.append("baseline index.json unreadable") }
    let logText = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
    let logTail = logText.split(separator: "\n").suffix(3).joined(separator: " | ")
    let planSummary = logText.split(separator: "\n").first(where: { $0.contains("FULL_PLAN_SUMMARY") }).map(String.init) ?? ""
    let byteIdentical = (differing == 0 && missing == 0 && identical > 0)

    // Append immutable run record (never discard).
    let runRecord: [String:Any] = ["timestamp": iso, "profileHash": profileHash,
        "exitCode": Int(ec), "wallSeconds": wall, "byteIdentical": byteIdentical,
        "identical": identical, "differing": differing, "missing": missing,
        "osBuild": osBuild, "e5CacheFileCountBefore": e5Files.count, "sandbox": sandbox,
        "method": "cli", "frozen": frozen, "counted": counted,
        "profileCommit": (profileGit["commit"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "",
        "runStartedAt": runStartedAtIso, "freezeManifestSha256": freezeManifestSha]
    let (all, runIndex, ledgerOk) = appendLedger([runRecord])
    if !ledgerOk { allLedgerOk = false; warnErr("could not write run ledger \(runsLogPath); the device-wide execution log still holds this run") }
    ledgerSnapshot = all
    let completedOk = appendDurable(["kind": "run_completed", "profileHash": profileHash, "mode": "replication", "outDir": runDir, "runIndex": runIndex, "runStartedAt": runStartedAtIso, "byteIdentical": byteIdentical, "counted": counted, "exitCode": Int(ec), "freezeManifestSha256": freezeManifestSha])
    if !completedOk { allCompletedOk = false; warnErr("could not durably record run_completed in \(durableExecLogPath)") }
    return ["runIndex": runIndex, "runDir": runDir, "runStartedAt": runStartedAtIso, "exitCode": Int(ec), "wallSeconds": wall,
            "byteIdentical": byteIdentical, "identical": identical, "differing": differing, "missing": missing,
            "diffs": Array(diffs.prefix(20)), "planSummary": planSummary, "logTail": logTail]
}

var results: [[String:Any]] = []
var stopReason = ""
for k in 1...runsToDo {
    var runDir = outDir
    if setMode {
        if frozen {
            let (ok, why) = freezeStillHolds()
            if !ok { stopReason = "freeze broken before run \(k): \(why)"; break }
        }
        if (sha256File(runnerBin) ?? "") != runnerShaAtBuild { stopReason = "runner binary changed before run \(k)"; break }
        runDir = outDir + "/" + String(format: "run-%03d", k)
        do { try fm.createDirectory(atPath: runDir, withIntermediateDirectories: false) }
        catch { stopReason = "cannot create fresh run dir \(runDir): \(error)"; break }
    }
    guard let r = runOnce(runDir) else {
        if !setMode { dieErr("REFUSING to run: cannot durably record run_started in \(durableExecLogPath)") }
        stopReason = "cannot durably record run_started for run \(k) in \(durableExecLogPath)"
        break
    }
    results.append(r)
}
guard let last = results.last else {
    dieErr("REFUSING: no run executed: \(stopReason)")
}
let setComplete = (results.count == runsToDo && stopReason.isEmpty)
let allIdentical = results.allSatisfy { ($0["byteIdentical"] as? Bool) ?? false }
let runIndex = (last["runIndex"] as? Int) ?? 0
let totalRuns = ledgerSnapshot.count
let countedRuns = ledgerSnapshot.filter { ($0["counted"] as? Bool) ?? false }.count
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
let runsArray: [[String:Any]] = ledgerSnapshot.map { r in
    ["index": r["runIndex"] ?? 0, "counted": (r["counted"] as? Bool) ?? false,
     "passed": (r["byteIdentical"] as? Bool) ?? false, "runStartedAt": r["runStartedAt"] ?? ""]
}

// Comparison: the single run (legacy) or every run of the set (sums; byteIdentical only if ALL runs were).
var comparison: [String:Any] = ["baselineIndex": (baseline["indexJson"] as? String) ?? ""]
if setMode {
    comparison["identical"] = results.reduce(0) { $0 + (($1["identical"] as? Int) ?? 0) }
    comparison["differing"] = results.reduce(0) { $0 + (($1["differing"] as? Int) ?? 0) }
    comparison["missing"] = results.reduce(0) { $0 + (($1["missing"] as? Int) ?? 0) }
    comparison["byteIdentical"] = allIdentical
    var sd: [String] = []
    for r in results {
        let name = (((r["runDir"] as? String) ?? "") as NSString).lastPathComponent
        for d in ((r["diffs"] as? [String]) ?? []) { sd.append("\(name): \(d)") }
    }
    comparison["diffs"] = Array(sd.prefix(20))
    comparison["scope"] = "all runs of this set"
} else {
    comparison["identical"] = last["identical"] ?? 0
    comparison["differing"] = last["differing"] ?? 0
    comparison["missing"] = last["missing"] ?? 0
    comparison["byteIdentical"] = last["byteIdentical"] ?? false
    comparison["diffs"] = last["diffs"] ?? []
}
var runField: [String:Any] = ["computeUnits": computeUnits, "tokens": tokens, "fixture": fixture, "tsv": tsv, "sandbox": sandbox,
    "exitCode": last["exitCode"] ?? -1, "wallSeconds": last["wallSeconds"] ?? 0, "runStartedAt": last["runStartedAt"] ?? "",
    "planSummary": last["planSummary"] ?? "", "logTail": last["logTail"] ?? ""]
if setMode { runField["runDir"] = last["runDir"] ?? ""; runField["note"] = "last run of the set; every run is in set.runs" }

let verdict: String
if !frozen { verdict = "NOT_FROZEN_NOT_COUNTED" }
else if setMode && !setComplete { verdict = "SET_INCOMPLETE" }
else if (setMode ? allIdentical : ((last["byteIdentical"] as? Bool) ?? false)) { verdict = "REPLICATED_SAME_CHIP_BYTE_IDENTICAL" }
else { verdict = "NOT_BYTE_IDENTICAL" }

// ---- 6. Emit replication receipt ----
var receipt: [String:Any] = [
    "schema": "macbrains.research.cleanroom-replication.v1",
    "generatedAt": iso,
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
    "run": runField,
    "frozen": frozen,
    "freeze": ["freezeManifestSha256": freezeManifestSha, "freezeTime": freezeTime, "profileCommit": (profileGit["commit"] as? String) ?? "", "profileCommitTime": (profileGit["commitTime"] as? String) ?? "", "toolCommit": (toolGit["commit"] as? String) ?? "", "toolCommitTime": (toolGit["commitTime"] as? String) ?? "", "headCommit": (profileGit["headCommit"] as? String) ?? "", "toolSourceDeclared": (toolSource != nil), "committedProfileBlobSha256": committedProfileBlobSha],
    "runs": runsArray,
    "runAccounting": ["totalRuns": totalRuns, "countedRuns": countedRuns, "preFreezeRunsNotCounted": preFreezeRuns, "thisRunCounted": counted],
    "executionLog": execLogSummary(),
    "comparison": comparison,
    "expected": expected,
    "permittedModifications": (profile["permittedModifications"] as? [Any]) ?? [],
    "verdict": verdict
]
if setMode {
    receipt["set"] = ["runsRequested": runsToDo, "runsExecuted": results.count, "complete": setComplete, "stopReason": stopReason,
        "freezeReverifiedBeforeEachRun": frozen, "runnerSha256": runnerShaAtBuild,
        "runs": results.map { r -> [String:Any] in
            var s = r; s.removeValue(forKey: "diffs"); s.removeValue(forKey: "logTail"); return s }]
}
let receiptBase = receipt
let legacyReceiptSha = sha256Bytes(canonical(receiptBase))
var withLegacy = receiptBase; withLegacy["receiptSha256"] = legacyReceiptSha
let selfHash = sha256Bytes(canonical(withLegacy))
var finalReceipt = withLegacy; finalReceipt["receiptSelfHash"] = selfHash
let receiptPath = outDir + "/cleanroom-receipt.json"
if !writeJSON(finalReceipt, receiptPath) { dieErr("could not write receipt \(receiptPath)") }
let cmp = comparison
print("CLEANROOM verdict=\(verdict) identical=\(cmp["identical"] ?? 0) differing=\(cmp["differing"] ?? 0) missing=\(cmp["missing"] ?? 0) wall=\(last["wallSeconds"] ?? 0)s runIndex=\(runIndex) frozen=\(frozen) counted=\(countedRuns)/\(totalRuns)" + (setMode ? " set=\(results.count)/\(runsToDo)" + (stopReason.isEmpty ? "" : " stop=\(stopReason)") : ""))
print("receipt=\(receiptPath) sha256=\(selfHash)")
exit(verdict == "REPLICATED_SAME_CHIP_BYTE_IDENTICAL" && allLedgerOk && allCompletedOk ? 0 : 1)
