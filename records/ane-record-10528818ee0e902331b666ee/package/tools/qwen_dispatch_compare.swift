// qwen_dispatch_compare.swift - summarise counted cleanroom control runs of qwen_dispatch_runner.
//
// Usage: qwen_dispatch_compare <runsRoot> <out.json>
//   runsRoot holds <profileDir>/run-<n>/cleanroom-control-receipt.json and dump_<arm>/ for every run
//   (profileDir = ane-vs-gpu, cpuonly). Every run directory found is read; none is skipped.
// For each arm: dump digest per run, whether every run is byte-identical to the first, and the facts in
// the first run's dump (generated tokens, first <|im_end|>, NaN counts, prefill winners and the
// <|im_end|> rank at the last prompt position). Cross-arm: ane vs gpu generated-token divergence,
// prefill winner agreement, and fp16 logit differences at the last prompt position.
//
// Build: xcrun swiftc -O qwen_dispatch_compare.swift -o qwen_dispatch_compare

import CryptoKit
import Foundation

func fail(_ m: String) -> Never { FileHandle.standardError.write(Data(("ERROR " + m + "\n").utf8)); exit(2) }
func hex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
func readJSON(_ p: String) -> [String: Any] {
    guard let d = FileManager.default.contents(atPath: p), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { fail("cannot read JSON \(p)") }
    return o
}
func readF16(_ p: String) -> [Float] {
    guard let d = FileManager.default.contents(atPath: p), d.count % 2 == 0 else { fail("cannot read fp16 file \(p)") }
    return d.withUnsafeBytes { raw in raw.bindMemory(to: UInt16.self).map { Float(Float16(bitPattern: UInt16(littleEndian: $0))) } }
}

let args = CommandLine.arguments
guard args.count == 3 else { fail("usage: qwen_dispatch_compare <runsRoot> <out.json>") }
let root = args[1], outPath = args[2]
let fm = FileManager.default

var profiles: [String: Any] = [:]
var firstRunDumpDir: [String: String] = [:]   // arm -> dump dir of run-1
for pdir in ["ane-vs-gpu", "cpuonly"] {
    let base = root + "/" + pdir
    guard let entries = try? fm.contentsOfDirectory(atPath: base) else { fail("missing \(base)") }
    let runs = entries.filter { $0.hasPrefix("run-") }.sorted { Int($0.dropFirst(4)) ?? 0 < Int($1.dropFirst(4)) ?? 0 }
    var runRows: [[String: Any]] = []
    var armDigests: [String: [String]] = [:]
    var profileHashes = Set<String>(), binaryShas = Set<String>()
    for r in runs {
        let rp = base + "/" + r + "/cleanroom-control-receipt.json"
        guard fm.fileExists(atPath: rp) else { runRows.append(["run": r, "receipt": "missing"]); continue }
        let rc = readJSON(rp)
        profileHashes.insert(rc["profileHash"] as? String ?? "")
        binaryShas.insert(rc["binarySha256"] as? String ?? "")
        var armsOut: [[String: Any]] = []
        for a in (rc["arms"] as? [[String: Any]]) ?? [] {
            let name = a["name"] as? String ?? "?"
            let files = ((a["dumpFiles"] as? [[String: Any]]) ?? []).map { "\($0["path"] as? String ?? "?")\t\($0["sha256"] as? String ?? "?")" }.sorted()
            let digest = hex(Data(files.joined(separator: "\n").utf8))
            armDigests[name, default: []].append(digest)
            if r == runs.first { firstRunDumpDir[name] = base + "/" + r + "/dump_" + name }
            armsOut.append(["arm": name, "passed": a["passed"] as? Bool ?? false, "exitCode": a["exitCode"] as? Int ?? -1,
                            "dumpFileCount": files.count, "dumpDigest": digest, "wallSeconds": a["wallSeconds"] as? Int ?? -1])
        }
        let ra = rc["runAccounting"] as? [String: Any] ?? [:]
        let fr = rc["freeze"] as? [String: Any] ?? [:]
        runRows.append(["run": r, "verdict": rc["verdict"] as? String ?? "?", "frozen": rc["frozen"] as? Bool ?? false,
                        "receiptSelfHash": rc["receiptSelfHash"] as? String ?? "", "inputsUnchanged": (rc["inputs"] as? [String: Any])?["unchanged"] as? Bool ?? false,
                        "countedRunsInLedger": ra["countedRuns"] as? Int ?? -1, "totalRunsInLedger": ra["totalRuns"] as? Int ?? -1,
                        "profileCommit": fr["profileCommit"] as? String ?? "", "toolCommit": fr["toolCommit"] as? String ?? "",
                        "arms": armsOut])
    }
    var armSummary: [String: Any] = [:]
    for (arm, ds) in armDigests {
        let same = ds.filter { $0 == ds.first }.count
        armSummary[arm] = ["runs": ds.count, "byteIdenticalToFirstRun": same, "allByteIdentical": same == ds.count, "distinctDumpDigests": Set(ds).count]
    }
    profiles[pdir] = ["runsFound": runs.count, "profileHashes": Array(profileHashes).sorted(), "binarySha256s": Array(binaryShas).sorted(),
                      "runs": runRows, "armDeterminism": armSummary]
}

// Facts from the first run's dump of every arm.
var armFacts: [String: Any] = [:]
var chains: [String: [String: Any]] = [:], prefills: [String: [String: Any]] = [:]
for (arm, dir) in firstRunDumpDir {
    let ch = readJSON(dir + "/chain.json"), pf = readJSON(dir + "/prefill.json")
    chains[arm] = ch; prefills[arm] = pf
    let pos = (pf["positions"] as? [[String: Any]]) ?? []
    let last = pos.last ?? [:]
    let steps = (ch["steps"] as? [[String: Any]]) ?? []
    let firstNaNStep = steps.first { ($0["nanChunks"] as? Int ?? 0) > 0 }?["step"] ?? NSNull()
    armFacts[arm] = ["computeUnits": ch["computeUnits"] ?? "?", "generatedWinners": ch["generatedWinners"] ?? [],
                     "firstImEndGeneratedIndex": ch["firstImEndGeneratedIndex"] ?? NSNull(), "inferStepsWithAnyNaN": ch["stepsWithAnyNaN"] ?? -1,
                     "inferFirstNaNStep": firstNaNStep, "prefillPositionsWithAnyNaN": pf["positionsWithAnyNaN"] ?? -1,
                     "prefillWinners": pos.map { $0["winner"] ?? -1 },
                     "prefillLastPosition": ["winner": last["winner"] ?? -1, "imEndLogit": last["imEndLogit"] ?? "?", "imEndRank": last["imEndRank"] ?? NSNull(),
                                             "imEndMarginToWinner": last["imEndMarginToWinner"] ?? NSNull(), "top5": last["top5"] ?? []]]
}

var cross: [String: Any] = [:]
if let a = chains["ane"], let g = chains["gpu"], let pa = prefills["ane"], let pg = prefills["gpu"] {
    let ga = a["generatedWinners"] as? [Int] ?? [], gg = g["generatedWinners"] as? [Int] ?? []
    var firstDiff: Any = NSNull()
    for i in 0..<min(ga.count, gg.count) where ga[i] != gg[i] { firstDiff = i; break }
    let wa = ((pa["positions"] as? [[String: Any]]) ?? []).map { $0["winner"] as? Int ?? -1 }
    let wg = ((pg["positions"] as? [[String: Any]]) ?? []).map { $0["winner"] as? Int ?? -1 }
    var agree = 0, disagreeAt: [Int] = []
    for i in 0..<min(wa.count, wg.count) { if wa[i] == wg[i] { agree += 1 } else { disagreeAt.append(i) } }
    let la = readF16(firstRunDumpDir["ane"]! + "/logits-prefill-last.f16"), lg = readF16(firstRunDumpDir["gpu"]! + "/logits-prefill-last.f16")
    var maxAbs: Float = 0, sumAbs: Double = 0, n = 0, nonFinite = 0
    for i in 0..<min(la.count, lg.count) {
        if !la[i].isFinite || !lg[i].isFinite { nonFinite += 1; continue }
        let d = abs(la[i] - lg[i]); maxAbs = max(maxAbs, d); sumAbs += Double(d); n += 1
    }
    cross["aneVsGpu"] = ["firstDivergentGeneratedIndex": firstDiff, "generatedCompared": min(ga.count, gg.count),
                         "prefillWinnerAgreement": agree, "prefillPositions": min(wa.count, wg.count), "prefillWinnerDisagreeAt": disagreeAt,
                         "lastPromptLogits": ["values": n, "nonFinitePairs": nonFinite, "maxAbsDiff": String(format: "%.4f", maxAbs),
                                              "meanAbsDiff": String(format: "%.5f", n > 0 ? sumAbs / Double(n) : 0)]]
}

let out: [String: Any] = ["schema": "macbrains.research.qwen-dispatch-summary.v1", "runsRoot": root, "profiles": profiles,
                          "armFactsFromFirstRun": armFacts, "crossArm": cross,
                          "note": "Facts are from run-1 dumps; armDeterminism shows whether every other run's dump is byte-identical to run-1."]
guard let d = try? JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted]) else { fail("encode") }
do { try d.write(to: URL(fileURLWithPath: outPath)) } catch { fail("write \(outPath): \(error)") }
print("wrote \(outPath)")
