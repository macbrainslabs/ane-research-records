// qwen_dispatch_recompute.swift - independent recompute of one qwen_dispatch_runner dump.
//
// Usage: qwen_dispatch_recompute <dumpDir> <prompt.json> <out-receipt.json>
//
// Written from the metric definitions in the record, not from the runner's code paths:
//   A. logits-prefill-last.f16 (151936 fp16, little-endian): its sha256 must equal the last prefill position's
//      logitsSha256; winner = smallest index among the maximal non-NaN values; nanCount; <|im_end|> (151645)
//      rank = 1 + number of non-NaN values strictly greater than its value; the 4-decimal strings of the
//      im_end logit, the winner logit and their difference; the top-5 ids (value desc, id asc).
//   B. chain.json: for every step, decode the 16 fp16 chunk maxima from their bit patterns, count NaN chunks,
//      take the chunk with the largest non-NaN value (lowest chunk on ties), token = chunk*9496 + idx; all-NaN
//      -> -1. Check the step's recorded winner and nanChunks, that prompt steps feed the prompt ids in order,
//      that every decode step feeds the previous step's winner (0 after an all-NaN step), and rebuild
//      generatedWinners (from step promptCount-1), firstImEndGeneratedIndex and stepsWithAnyNaN.
// Every comparison is exact (integers, or byte-equal strings). status is EXACT only when all of them match.
//
// Build: xcrun swiftc -O qwen_dispatch_recompute.swift -o qwen_dispatch_recompute

import CryptoKit
import Foundation

let VOCAB = 151936, CHUNK = 9496, NCHUNK = 16, IM_END = 151645

func die(_ m: String) -> Never { FileHandle.standardError.write(Data(("ERROR " + m + "\n").utf8)); exit(2) }
func shaHex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
func loadJSON(_ p: String) -> [String: Any] {
    guard let d = FileManager.default.contents(atPath: p),
          let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { die("cannot read JSON \(p)") }
    return o
}
func f4(_ x: Float) -> String { String(format: "%.4f", x) }

let a = CommandLine.arguments
guard a.count == 4 else { die("usage: qwen_dispatch_recompute <dumpDir> <prompt.json> <out-receipt.json>") }
let dumpDir = a[1], promptPath = a[2], outPath = a[3]

var checks: [[String: Any]] = []
var allExact = true
func compare(_ name: String, _ recorded: Any?, _ recomputed: Any) {
    let r = recorded.map { "\($0)" } ?? "<missing>"
    let c = "\(recomputed)"
    let same = recorded != nil && r == c
    if !same { allExact = false }
    checks.append(["field": name, "recorded": r, "recomputed": c, "exact": same])
}

// ---------- inputs ----------
let promptJSON = loadJSON(promptPath)
guard let prompt = promptJSON["ids"] as? [Int], !prompt.isEmpty else { die("prompt.json has no ids") }
let prefillPath = dumpDir + "/prefill.json", chainPath = dumpDir + "/chain.json", logitsPath = dumpDir + "/logits-prefill-last.f16"
let prefill = loadJSON(prefillPath), chain = loadJSON(chainPath)
guard let logitsData = FileManager.default.contents(atPath: logitsPath) else { die("missing \(logitsPath)") }
guard logitsData.count == VOCAB * 2 else { die("logits file is \(logitsData.count) bytes, expected \(VOCAB * 2)") }

// ---------- A. last prompt position, full logits ----------
var vals = [Float](repeating: 0, count: VOCAB)
logitsData.withUnsafeBytes { raw in
    for i in 0..<VOCAB {
        let lo = UInt16(raw[2 * i]), hi = UInt16(raw[2 * i + 1])
        vals[i] = Float(Float16(bitPattern: lo | (hi << 8)))
    }
}
let finite = vals.enumerated().filter { !$0.element.isNaN }
let nanCount = VOCAB - finite.count
var winner = -1
if let maxV = finite.map({ $0.element }).max() { winner = finite.first { $0.element == maxV }!.offset }
let positions = (prefill["positions"] as? [[String: Any]]) ?? []
guard let last = positions.last else { die("prefill.json has no positions") }
compare("prefill.positions.count", positions.count, prompt.count)
compare("prefill.last.logitsSha256", last["logitsSha256"], shaHex(logitsData))
compare("prefill.last.winner", last["winner"], winner)
compare("prefill.last.nanCount", last["nanCount"], nanCount)
let imEndV = vals[IM_END]
compare("prefill.last.imEndLogit", last["imEndLogit"], imEndV.isNaN ? "nan" : f4(imEndV))
if !imEndV.isNaN {
    compare("prefill.last.imEndRank", last["imEndRank"], 1 + finite.filter { $0.element > imEndV }.count)
}
if winner >= 0 {
    let wv = vals[winner]
    compare("prefill.last.winnerLogit", last["winnerLogit"], f4(wv))
    compare("prefill.last.imEndMarginToWinner", last["imEndMarginToWinner"], imEndV.isNaN ? "nan" : f4(wv - imEndV))
}
let top5 = finite.sorted { $0.element != $1.element ? $0.element > $1.element : $0.offset < $1.offset }.prefix(5).map { $0.offset }
let recTop5 = ((last["top5"] as? [[String: Any]]) ?? []).map { ($0["id"] as? Int) ?? -1 }
compare("prefill.last.top5.ids", recTop5.map(String.init).joined(separator: ","), top5.map(String.init).joined(separator: ","))
compare("prefill.promptIds", ((prefill["promptIds"] as? [Int]) ?? []).map(String.init).joined(separator: ","), prompt.map(String.init).joined(separator: ","))

// ---------- B. infer chain ----------
let steps = (chain["steps"] as? [[String: Any]]) ?? []
let promptCount = prompt.count
compare("chain.promptCount", chain["promptCount"], promptCount)
let decodeSteps = (chain["decodeSteps"] as? Int) ?? -1
compare("chain.steps.count", steps.count, promptCount + decodeSteps)
var gen: [Int] = [], nanSteps = 0, prevFed = 0
var stepMismatch = 0, feedMismatch = 0, nanChunkMismatch = 0
for (s, row) in steps.enumerated() {
    let idx = (row["chunkArgmaxIdx"] as? [Int]) ?? []
    let bits = (row["chunkArgmaxValF16Bits"] as? [Int]) ?? []
    guard idx.count == NCHUNK, bits.count == NCHUNK else { die("step \(s): expected 16 chunk entries") }
    var best = -1, bestV: Float = 0, nanC = 0
    for c in 0..<NCHUNK {
        let v = Float(Float16(bitPattern: UInt16(bits[c])))
        if v.isNaN { nanC += 1 } else if best < 0 || v > bestV { best = c; bestV = v }
    }
    let w = best < 0 ? -1 : best * CHUNK + idx[best]
    if (row["winner"] as? Int) != w { stepMismatch += 1 }
    if (row["nanChunks"] as? Int) != nanC { nanChunkMismatch += 1 }
    if nanC > 0 { nanSteps += 1 }
    let expectedIn = s < promptCount ? prompt[s] : prevFed
    if (row["tokenIn"] as? Int) != expectedIn { feedMismatch += 1 }
    if (row["step"] as? Int) != s { stepMismatch += 1 }
    if s >= promptCount - 1 { gen.append(w) }
    prevFed = w < 0 ? 0 : w
}
compare("chain.steps.winnerMismatches", 0, stepMismatch)
compare("chain.steps.nanChunkMismatches", 0, nanChunkMismatch)
compare("chain.steps.tokenInMismatches", 0, feedMismatch)
let recGen = (chain["generatedWinners"] as? [Int]) ?? []
compare("chain.generatedWinners", recGen.map(String.init).joined(separator: ","), gen.map(String.init).joined(separator: ","))
let firstIm: Any = gen.firstIndex(of: IM_END).map { $0 as Any } ?? "null"
compare("chain.firstImEndGeneratedIndex", (chain["firstImEndGeneratedIndex"] as? Int).map { $0 as Any } ?? "null", firstIm)
compare("chain.stepsWithAnyNaN", chain["stepsWithAnyNaN"], nanSteps)

// ---------- receipt ----------
func fileSha(_ p: String) -> String { shaHex(FileManager.default.contents(atPath: p) ?? Data()) }
var receipt: [String: Any] = [
    "schema": "macbrains.research.qwen-dispatch-recompute.v1",
    "status": allExact ? "EXACT" : "NOT_EXACT",
    "dumpDir": dumpDir, "computeUnits": chain["computeUnits"] ?? "?",
    "inputs": ["prefill.json": fileSha(prefillPath), "chain.json": fileSha(chainPath),
               "logits-prefill-last.f16": shaHex(logitsData), "prompt": fileSha(promptPath)],
    "checks": checks, "checkCount": checks.count, "exactCount": checks.filter { ($0["exact"] as? Bool) ?? false }.count,
    "facts": ["prefillLastWinner": winner, "prefillLastNaN": nanCount, "generatedWinners": gen.count,
              "firstImEndGeneratedIndex": firstIm, "inferStepsWithAnyNaN": nanSteps,
              "prefillLastAgreesWithInferAtLastPromptStep": gen.first.map { $0 == winner } as Any],
    "method": "independent recompute from raw fp16 bytes and recorded chunk maxima; definitions in the file header"]
guard let body = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]) else { die("encode") }
receipt["receiptSelfHash"] = shaHex(body)
guard let out = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys, .prettyPrinted]) else { die("encode") }
do { try out.write(to: URL(fileURLWithPath: outPath)) } catch { die("write \(outPath): \(error)") }
print("RECOMPUTE status=\(allExact ? "EXACT" : "NOT_EXACT") checks=\(checks.count) units=\(chain["computeUnits"] ?? "?") out=\(outPath)")
exit(allExact ? 0 : 1)
