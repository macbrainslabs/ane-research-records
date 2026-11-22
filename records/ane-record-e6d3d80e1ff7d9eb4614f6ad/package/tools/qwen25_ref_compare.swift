// qwen25_ref_compare.swift - compare Core ML dispatch-runner dumps (qwen_dispatch_runner) against the
// fp32 reference dump (qwen25_ref_runner) of the original Qwen2.5-1.5B-Instruct weights.
//
// Usage: qwen25_ref_compare <refDump> <out.json> <arm>=<armDump> [<arm>=<armDump> ...]
//   refDump  holds prefill.json, logits-prefill-last.f32, chain.json from qwen25_ref_runner
//   armDump  holds prefill.json, logits-prefill-last.f16, chain.json from qwen_dispatch_runner
// Per arm:
//   prefill  winner agreement with the reference at every prompt position (positions that differ are listed);
//            at the last prompt position: reference rank of the arm's winner and arm rank of the reference winner
//            (rank = 1 + number of non-NaN values strictly greater), top-5 id overlap, and over the indices where
//            the arm is not NaN: max |arm - ref|, mean |arm - ref| and cosine similarity (double accumulation,
//            index order), plus the arm's NaN count.
//   chain    generated greedy tokens vs the reference: length of the common prefix (first divergence index),
//            tokens compared, both first <|im_end|> indices.
// All floats are written as fixed-format strings so the output is byte-reproducible.
//
// Build: xcrun swiftc -O qwen25_ref_compare.swift -o qwen25_ref_compare
import Foundation

let VOCAB = 151936
func fail(_ m: String) -> Never { FileHandle.standardError.write(Data(("ERROR " + m + "\n").utf8)); exit(2) }
func readJSON(_ p: String) -> [String: Any] {
    guard let d = FileManager.default.contents(atPath: p), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { fail("cannot read JSON \(p)") }
    return o
}
func readF32(_ p: String) -> [Float] {
    guard let d = FileManager.default.contents(atPath: p), d.count == VOCAB * 4 else { fail("\(p): expected \(VOCAB) fp32 values") }
    return d.withUnsafeBytes { raw in (0..<VOCAB).map { Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self))) } }
}
func readF16(_ p: String) -> [Float] {
    guard let d = FileManager.default.contents(atPath: p), d.count == VOCAB * 2 else { fail("\(p): expected \(VOCAB) fp16 values") }
    return d.withUnsafeBytes { raw in (0..<VOCAB).map { Float(Float16(bitPattern: UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 2, as: UInt16.self)))) } }
}
func rank(_ v: [Float], _ id: Int) -> Any {
    guard id >= 0, id < v.count, !v[id].isNaN else { return NSNull() }
    var above = 0; for x in v where !x.isNaN && x > v[id] { above += 1 }
    return above + 1
}
func winners(_ prefill: [String: Any]) -> [Int] {
    guard let pos = prefill["positions"] as? [[String: Any]] else { fail("prefill.json without positions") }
    return pos.map { $0["winner"] as? Int ?? -2 }
}
func top5(_ prefill: [String: Any]) -> [Int] {
    guard let last = (prefill["positions"] as? [[String: Any]])?.last, let t = last["top5"] as? [[String: Any]] else { return [] }
    return t.compactMap { $0["id"] as? Int }
}
func nn(_ x: Any?) -> Any { x ?? NSNull() }
func e6(_ x: Double) -> String { String(format: "%.6e", x) }

let a = CommandLine.arguments
guard a.count >= 4 else { fail("usage: qwen25_ref_compare <refDump> <out.json> <arm>=<armDump> ...") }
let refDir = a[1], outPath = a[2]
let refPre = readJSON(refDir + "/prefill.json"), refChain = readJSON(refDir + "/chain.json")
let refLast = readF32(refDir + "/logits-prefill-last.f32")
let refW = winners(refPre)
guard let refGen = refChain["generatedWinners"] as? [Int] else { fail("reference chain.json without generatedWinners") }
guard (refPre["promptIds"] as? [Int]) == (refChain["promptIds"] as? [Int]) else { fail("reference prefill/chain prompt mismatch") }
let refWinnerLast = refW.last ?? -1
var arms: [String: Any] = [:]
for spec in a[3...] {
    let parts = spec.split(separator: "=", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { fail("arm spec must be name=dir: \(spec)") }
    let name = parts[0], dir = parts[1]
    let pre = readJSON(dir + "/prefill.json"), chain = readJSON(dir + "/chain.json")
    guard (pre["promptIds"] as? [Int]) == (refPre["promptIds"] as? [Int]) else { fail("arm \(name): prompt differs from the reference") }
    let w = winners(pre)
    guard w.count == refW.count else { fail("arm \(name): prompt length differs") }
    var differ: [[String: Any]] = []
    for i in 0..<w.count where w[i] != refW[i] { differ.append(["position": i, "arm": w[i], "reference": refW[i]]) }
    let last = readF16(dir + "/logits-prefill-last.f16")
    var nan = 0, n = 0
    var maxAbs = 0.0, sumAbs = 0.0, dot = 0.0, na = 0.0, nr = 0.0
    for i in 0..<VOCAB {
        if last[i].isNaN { nan += 1; continue }
        let x = Double(last[i]), r = Double(refLast[i])
        let d = abs(x - r); if d > maxAbs { maxAbs = d }
        sumAbs += d; dot += x * r; na += x * x; nr += r * r; n += 1
    }
    let armWinnerLast = w.last ?? -1
    let t5a = top5(pre), t5r = top5(refPre)
    var prefill: [String: Any] = [
        "positions": w.count, "winnerAgreement": w.count - differ.count, "positionsDiffering": differ,
        "lastPosition": [
            "armWinner": armWinnerLast, "referenceWinner": refWinnerLast,
            "referenceRankOfArmWinner": rank(refLast, armWinnerLast), "armRankOfReferenceWinner": rank(last, refWinnerLast),
            "top5Arm": t5a, "top5Reference": t5r, "top5Overlap": t5a.filter { t5r.contains($0) }.count,
            "armNaNCount": nan, "comparedValues": n]]
    if n > 0 {
        var lp = prefill["lastPosition"] as! [String: Any]
        lp["maxAbsDiff"] = e6(maxAbs); lp["meanAbsDiff"] = e6(sumAbs / Double(n))
        lp["cosine"] = (na > 0 && nr > 0) ? String(format: "%.9f", dot / (na.squareRoot() * nr.squareRoot())) : "undefined"
        prefill["lastPosition"] = lp
    }
    let gen = chain["generatedWinners"] as? [Int] ?? []
    let m = min(gen.count, refGen.count)
    var common = 0; while common < m && gen[common] == refGen[common] { common += 1 }
    let armOut: [String: Any] = ["dumpComputeUnits": (pre["computeUnits"] as? String) ?? "", "prefill": prefill,
        "chain": ["armGenerated": gen.count, "referenceGenerated": refGen.count, "compared": m,
                  "commonPrefixLength": common, "firstDivergenceIndex": nn(common < m ? common : nil),
                  "armFirstImEnd": nn(chain["firstImEndGeneratedIndex"]),
                  "referenceFirstImEnd": nn(refChain["firstImEndGeneratedIndex"]),
                  "armStepsWithAnyNaN": nn(chain["stepsWithAnyNaN"])] as [String: Any]]
    arms[name] = armOut
}
let out: [String: Any] = ["schema": "macbrains.research.qwen25-ref-compare.v1",
    "reference": ["weightsSha256": refPre["weightsSha256"] ?? "", "selfCheck": nn(refChain["selfCheck"]),
                  "prefillWinners": refW, "generatedWinners": refGen,
                  "firstImEndGeneratedIndex": nn(refChain["firstImEndGeneratedIndex"])],
    "arms": arms,
    "rankRule": "1 + number of non-NaN values strictly greater than the value at the id; null when that value is NaN",
    "note": "Arm logits are fp16 from a LUT4-palettized Core ML package; the reference is fp32 from the original bf16 weights, so non-zero differences are expected on every arm"]
guard let d = try? JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted]) else { fail("encode") }
do { try d.write(to: URL(fileURLWithPath: outPath)) } catch { fail("write \(outPath)") }
print("COMPARE_DONE arms=\(arms.count)")
