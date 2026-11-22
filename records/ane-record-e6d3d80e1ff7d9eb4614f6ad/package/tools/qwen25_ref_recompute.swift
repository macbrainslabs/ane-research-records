// qwen25_ref_recompute.swift - independent recompute of the fp32 reference dump (qwen25_ref_runner) and of
// every metric in a qwen25_ref_compare output, written from the metric definitions in the record, not from
// either tool's code.
//
// Usage: qwen25_ref_recompute <refDump> <prompt.json> <compare.json> <out-receipt.json> <arm>=<armDump> ...
//   A. reference prefill: logits-prefill-all.f32 ([P][151936] LE fp32) re-analysed per position (sha256 of the
//      slice, winner = smallest index among maximal non-NaN values, NaN count, <|im_end|> bits/logit/rank,
//      top-5 by value desc then id asc, 4-decimal strings); logits-prefill-last.f32 equals the last slice.
//   B. reference chain: steps[k] is step promptCount-1+k; steps[0] re-feeds the last prompt id, later steps
//      feed the previous winner (0 after -1); generatedWinners, firstImEndGeneratedIndex, stepsWithAnyNaN
//      rebuilt; steps[0] logits sha equals the prefill's last position; selfCheck.bitIdentical is true. (Chain logits are not re-derived: that
//      needs the model; the step shas are only checked for presence.)
//   C. every arm metric in compare.json recomputed from the raw dumps (double accumulation, index order).
// status is EXACT only when every check matches exactly. Exit 0 on EXACT, 1 on MISMATCH, 2 on unreadable input.
//
// Build: xcrun swiftc -O qwen25_ref_recompute.swift -o qwen25_ref_recompute
import Foundation
import CryptoKit

let VOCAB = 151936
let IM_END = 151645

func die(_ m: String) -> Never {
    FileHandle.standardError.write(Data(("ERROR " + m + "\n").utf8))
    exit(2)
}
func readData(_ p: String) -> Data? { FileManager.default.contents(atPath: p) }
func readJSON(_ p: String) -> [String: Any]? {
    guard let d = readData(p), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
    return o
}
func f32s(_ d: Data, _ start: Int, _ n: Int) -> [Float] {
    d.withUnsafeBytes { raw in
        (0..<n).map { Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: start + $0 * 4, as: UInt32.self))) }
    }
}
func f16s(_ d: Data, _ n: Int) -> [Float] {
    d.withUnsafeBytes { raw in
        (0..<n).map { Float(Float16(bitPattern: UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 2, as: UInt16.self)))) }
    }
}
func sha(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
func f4(_ x: Float) -> String { x.isNaN ? "nan" : String(format: "%.4f", Double(x)) }
func winnerOf(_ v: [Float]) -> Int {
    var w = -1
    for i in 0..<v.count where !v[i].isNaN { if w < 0 || v[i] > v[w] { w = i } }
    return w
}
func top5Of(_ v: [Float]) -> [Int] {
    var top: [Int] = []
    for i in 0..<v.count where !v[i].isNaN {
        if top.count == 5 && !(v[i] > v[top[4]]) { continue }
        let j = top.firstIndex(where: { v[i] > v[$0] }) ?? top.count
        top.insert(i, at: j)
        if top.count > 5 { top.removeLast() }
    }
    return top
}
func rankOf(_ v: [Float], _ id: Int) -> Int? {
    guard id >= 0, id < v.count, !v[id].isNaN else { return nil }
    let x = v[id]
    var c = 0
    for y in v where y > x { c += 1 }
    return 1 + c
}
func nanCount(_ v: [Float]) -> Int { v.reduce(0) { $0 + ($1.isNaN ? 1 : 0) } }
func opt(_ i: Int?) -> Any { if let i = i { return i } else { return NSNull() } }
func same(_ e: Any, _ a: Any?) -> Bool {
    guard let a = a else { return false }
    if e is NSNull { return a is NSNull }
    if let ei = e as? Int { return (a as? Int) == ei }
    if let es = e as? String { return (a as? String) == es }
    if let eb = e as? Bool { return (a as? Bool) == eb }
    if let ea = e as? [Any] {
        guard let aa = a as? [Any], aa.count == ea.count else { return false }
        for i in 0..<ea.count where !same(ea[i], aa[i]) { return false }
        return true
    }
    if let ed = e as? [String: Any] {
        guard let ad = a as? [String: Any], ad.count == ed.count else { return false }
        for (k, v) in ed where !same(v, ad[k]) { return false }
        return true
    }
    return false
}
func diffKeys(_ e: [String: Any], _ a: [String: Any]?, absent: [String] = []) -> [String] {
    var out: [String] = []
    for k in e.keys.sorted() where !same(e[k]!, a?[k]) { out.append(k) }
    for k in absent where a?[k] != nil { out.append(k) }
    return out
}

var checks: [[String: Any]] = []
func add(_ n: String, _ ok: Bool, _ d: String) { checks.append(["name": n, "ok": ok, "detail": d]) }
func addDiff(_ n: String, _ keys: [String]) { add(n, keys.isEmpty, keys.isEmpty ? "match" : "differs: " + keys.joined(separator: ",")) }

let args = CommandLine.arguments
if args.count < 5 { die("usage: qwen25_ref_recompute <refDump> <prompt.json> <compare.json> <out-receipt.json> <arm>=<armDump> ...") }
let refDir = args[1], outPath = args[4]
guard let promptJ = readJSON(args[2]), let ids = promptJ["ids"] as? [Int], !ids.isEmpty else { die("unreadable prompt.json") }
guard let cmp = readJSON(args[3]) else { die("unreadable compare.json") }
guard let pf = readJSON(refDir + "/prefill.json") else { die("unreadable prefill.json") }
guard let allD = readData(refDir + "/logits-prefill-all.f32") else { die("unreadable logits-prefill-all.f32") }
guard let lastD = readData(refDir + "/logits-prefill-last.f32") else { die("unreadable logits-prefill-last.f32") }
guard let ch = readJSON(refDir + "/chain.json") else { die("unreadable chain.json") }
let P = ids.count
let sliceBytes = VOCAB * 4

// ---- A: reference prefill ----
let sizeOK = allD.count == P * sliceBytes
add("prefill.files", sizeOK && lastD.count == sliceBytes && allD.count >= sliceBytes && lastD == allD.subdata(in: (allD.count - sliceBytes)..<allD.count),
    "allBytes=\(allD.count) expected=\(P * sliceBytes) lastBytes=\(lastD.count)")
add("prefill.promptIds", (pf["promptIds"] as? [Int]) == ids, "promptIds vs prompt.json ids")
let positions = pf["positions"] as? [[String: Any]] ?? []
add("prefill.positions.count", positions.count == P, "positions=\(positions.count) expected=\(P)")

var refW = [Int](repeating: -2, count: P)
var refLast = [Float](repeating: .nan, count: VOCAB)
for p in 0..<P {
    let name = "prefill.position.\(p)"
    guard (p + 1) * sliceBytes <= allD.count else { add(name, false, "slice missing in logits-prefill-all.f32"); continue }
    let v = f32s(allD, p * sliceBytes, VOCAB)
    let s = sha(allD.subdata(in: (p * sliceBytes)..<((p + 1) * sliceBytes)))
    let w = winnerOf(v)
    refW[p] = w
    if p == P - 1 { refLast = v }
    let t5 = top5Of(v)
    let im = v[IM_END]
    var e: [String: Any] = [
        "position": p, "tokenIn": ids[p], "logitsSha256": s, "winner": w, "nanCount": nanCount(v),
        "imEndLogitF32Bits": Int(im.bitPattern), "imEndLogit": f4(im), "imEndRank": opt(rankOf(v, IM_END)),
        "top5": t5.map { ["id": $0, "logit": f4(v[$0])] as [String: Any] },
    ]
    if w >= 0 { e["winnerLogit"] = f4(v[w]); e["imEndMarginToWinner"] = f4(v[w] - im) }
    addDiff(name, diffKeys(e, p < positions.count ? positions[p] : nil))
}
let refWinnerLast = refW[P - 1]
let refTop5Last = top5Of(refLast)

// ---- B: reference chain ----
var issues: [String] = []
let D = ch["decodeSteps"] as? Int ?? -1
if (ch["promptIds"] as? [Int]) != ids { issues.append("promptIds") }
let steps = ch["steps"] as? [[String: Any]] ?? []
// steps[k] is step P-1+k: steps[0] re-feeds the last prompt id, every later step feeds the previous winner.
if D < 0 || steps.count != D + 1 { issues.append("steps.count=\(steps.count) expected=\(D + 1)") }
var chW: [Int] = []
var nanSteps = 0
for k in 0..<steps.count {
    let st = steps[k]
    let w = st["winner"] as? Int
    chW.append(w ?? -9)
    if w == nil { issues.append("steps[\(k)].winner") }
    if (st["step"] as? Int) != P - 1 + k { issues.append("steps[\(k)].step") }
    let expTok = k == 0 ? ids[P - 1] : (chW[k - 1] == -1 ? 0 : chW[k - 1])
    if (st["tokenIn"] as? Int) != expTok { issues.append("steps[\(k)].tokenIn") }
    guard let nc = st["nanCount"] as? Int else { issues.append("steps[\(k)].nanCount"); continue }
    if nc > 0 { nanSteps += 1 }
    if !(st["logitsSha256"] is String) { issues.append("steps[\(k)].logitsSha256") }
}
let gw: [Int] = chW
if (ch["generatedWinners"] as? [Int]) != gw { issues.append("generatedWinners") }
let refFirstIm: Int? = gw.firstIndex(of: IM_END)
if !same(opt(refFirstIm), ch["firstImEndGeneratedIndex"]) { issues.append("firstImEndGeneratedIndex") }
if (ch["stepsWithAnyNaN"] as? Int) != nanSteps { issues.append("stepsWithAnyNaN") }
let pfLastSha = P - 1 < positions.count ? positions[P - 1]["logitsSha256"] as? String : nil
if !steps.isEmpty, let a = steps[0]["logitsSha256"] as? String, let b = pfLastSha, a == b {} else { issues.append("steps[0].sha!=prefill") }
if ((ch["selfCheck"] as? [String: Any])?["bitIdentical"] as? Bool) != true { issues.append("selfCheck.bitIdentical") }
add("chain.reference", issues.isEmpty, issues.isEmpty ? "match" : "differs: " + issues.joined(separator: ","))

// ---- C: arms ----
let armsJ = cmp["arms"] as? [String: Any]
for spec in args[5...] {
    guard let eq = spec.firstIndex(of: "=") else { die("bad arm spec \(spec)") }
    let arm = String(spec[spec.startIndex..<eq]), dir = String(spec[spec.index(after: eq)...])
    let nP = "arm.\(arm).prefill", nL = "arm.\(arm).lastPosition", nC = "arm.\(arm).chain"
    guard let apf = readJSON(dir + "/prefill.json"), let acj = readJSON(dir + "/chain.json"),
          let hd = readData(dir + "/logits-prefill-last.f16"), hd.count == VOCAB * 2 else {
        for n in [nP, nL, nC] { add(n, false, "arm dump unreadable or wrong size") }
        continue
    }
    let armC = armsJ?[arm] as? [String: Any]
    let aposs = apf["positions"] as? [[String: Any]] ?? []
    let armW = (0..<P).map { $0 < aposs.count ? (aposs[$0]["winner"] as? Int ?? -2) : -2 }
    let armLast = f16s(hd, VOCAB)
    var differing: [Any] = []
    var agree = 0
    for p in 0..<P {
        if armW[p] == refW[p] { agree += 1 } else { differing.append(["position": p, "arm": armW[p], "reference": refW[p]] as [String: Any]) }
    }
    let pe: [String: Any] = ["positions": P, "winnerAgreement": agree, "positionsDiffering": differing]
    let pc = armC?["prefill"] as? [String: Any]
    addDiff(nP, diffKeys(pe, pc).map { "prefill." + $0 })

    let aw = armW[P - 1]
    let a5: [Int] = ((P - 1 < aposs.count ? aposs[P - 1]["top5"] as? [Any] : nil) ?? []).compactMap { ($0 as? [String: Any])?["id"] as? Int }
    let nanA = nanCount(armLast)
    let cv = VOCAB - nanA
    var le: [String: Any] = [
        "armWinner": aw, "referenceWinner": refWinnerLast,
        "referenceRankOfArmWinner": opt(aw < 0 ? nil : rankOf(refLast, aw)),
        "armRankOfReferenceWinner": opt(refWinnerLast < 0 ? nil : rankOf(armLast, refWinnerLast)),
        "top5Arm": a5, "top5Reference": refTop5Last, "top5Overlap": a5.filter { refTop5Last.contains($0) }.count,
        "armNaNCount": nanA, "comparedValues": cv,
    ]
    var absent: [String] = []
    if cv > 0 {
        var mx = 0.0, sa = 0.0, sxr = 0.0, sxx = 0.0, srr = 0.0
        for i in 0..<VOCAB where !armLast[i].isNaN {
            let x = Double(armLast[i]), r = Double(refLast[i])
            let d = abs(x - r)
            if d > mx { mx = d }
            sa += d; sxr += x * r; sxx += x * x; srr += r * r
        }
        le["maxAbsDiff"] = String(format: "%.6e", mx)
        le["meanAbsDiff"] = String(format: "%.6e", sa / Double(cv))
        le["cosine"] = String(format: "%.9f", sxr / (sxx.squareRoot() * srr.squareRoot()))
    } else { absent = ["maxAbsDiff", "meanAbsDiff", "cosine"] }
    addDiff(nL, diffKeys(le, pc?["lastPosition"] as? [String: Any], absent: absent).map { "prefill.lastPosition." + $0 })

    let agw = acj["generatedWinners"] as? [Int] ?? []
    let compared = min(agw.count, gw.count)
    var cpl = 0
    while cpl < compared && agw[cpl] == gw[cpl] { cpl += 1 }
    var afirst: Any = NSNull()
    if let i = acj["firstImEndGeneratedIndex"] as? Int { afirst = i }
    let ce: [String: Any] = [
        "armGenerated": agw.count, "referenceGenerated": gw.count, "compared": compared,
        "commonPrefixLength": cpl, "firstDivergenceIndex": opt(cpl < compared ? cpl : nil),
        "armFirstImEnd": afirst, "armStepsWithAnyNaN": acj["stepsWithAnyNaN"] as? Int ?? -1,
        "referenceFirstImEnd": opt(refFirstIm),
    ]
    addDiff(nC, diffKeys(ce, armC?["chain"] as? [String: Any]).map { "chain." + $0 })
}

let mism = checks.filter { ($0["ok"] as? Bool) == false }.count
let status = mism == 0 ? "EXACT" : "MISMATCH"
var receipt: [String: Any] = ["schema": "macbrains.research.qwen25-ref-recompute.v1", "checks": checks, "mismatches": mism, "status": status]
// receiptSelfHash = sha256 of the compact sorted-key JSON body without that field.
guard let body = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]) else { die("cannot encode receipt") }
receipt["receiptSelfHash"] = sha(body)
guard let out = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys, .prettyPrinted]),
      (try? out.write(to: URL(fileURLWithPath: outPath))) != nil else { die("cannot write receipt") }
print("RECOMPUTE status=\(status) mismatches=\(mism)")
exit(mism == 0 ? 0 : 1)
