// qwen25_ref_runner.swift - independent fp32 CPU reference forward pass of the ORIGINAL
// Qwen/Qwen2.5-1.5B-Instruct weights (bf16 safetensors), for the cleanroom harness.
// No Core ML, no Metal, no BLAS: every reduction runs in a fixed order, so the dump is
// byte-reproducible on the same binary and input, independent of thread scheduling.
//
// Interface (cleanroom.swift): runner <argvMode> <fixture> <tsv> <tokens>
//   argvMode  must be "infer-chain"
//   fixture   path to model.safetensors (bf16, Qwen2 architecture, tied embeddings)
//   tsv       path to a JSON file {"ids":[Int]} holding the prompt token ids
//   tokens    number of greedy decode steps after the prompt
// Env:
//   LFM3_VECTOR_DUMP_DIR  output dir for the deterministic dump (required)
//   LFM3_RESULT_JSON      optional: non-deterministic run facts (wall times)
//   LFM3_COMPUTE_UNITS    ignored (the reference never uses Core ML)
//
// A. prefill: one batched forward over the whole prompt; full fp32 logits analysed at every prompt position.
// B. chain: the last prompt token is recomputed alone on A's KV cache (steps[0], step = promptCount-1), then
//    greedy decoding on the full fp32 logits for <tokens> steps. steps[0] logits are compared with A's last
//    position (self-check: both paths use the same per-element arithmetic, so they must be bit-identical).
//    The prompt is not re-fed token by token: on this 8 GB device every forward re-reads the 3 GB weights.
//
// Dump (no timestamps or paths): prefill.json, logits-prefill-all.f32, logits-prefill-last.f32, chain.json.
// Arithmetic: bf16 weights widened exactly to fp32; dot products accumulate in 16 fp32 lanes with fused
// multiply-add in index order, lanes summed 0..15; RMSNorm/softmax sums sequential; RoPE angle = fp32
// position * fp32 inverse frequency (theta 1e6, half-split rotation); exp/cos/sin from Foundation.
//
// Build: xcrun swiftc -O -parse-as-library qwen25_ref_runner.swift -o qwen25_ref_runner
import CryptoKit
import Foundation

let HID = 1536, NLAYER = 28, NHEAD = 12, NKV = 2, HDIM = 128, INTER = 8960, VOCAB = 151936
let IM_END = 151645
let CTX = 512
let EPS: Float = 1e-6
let THETA = 1_000_000.0
let QPERKV = NHEAD / NKV

func fail(_ msg: String, _ code: Int32 = 2) -> Never { FileHandle.standardError.write(Data(("ERROR " + msg + "\n").utf8)); exit(code) }
func hex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
func f4(_ v: Float) -> String { v.isNaN ? "nan" : String(format: "%.4f", v) }
func writeJSON(_ obj: Any, _ path: String) {
    guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted]) else { fail("cannot encode \(path)") }
    do { try d.write(to: URL(fileURLWithPath: path)) } catch { fail("cannot write \(path): \(error)") }
}

// ---- safetensors (mmap, bf16 only) ----
struct BF { let p: UnsafePointer<UInt16>; let shape: [Int] }
final class Weights {
    var t: [String: BF] = [:]
    var fileSha = ""
    init(_ path: String) {
        let fd = open(path, O_RDONLY); if fd < 0 { fail("cannot open \(path)") }
        var st = stat(); if fstat(fd, &st) != 0 { fail("cannot stat \(path)") }
        let size = Int(st.st_size)
        guard let base = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0), base != MAP_FAILED else { fail("mmap failed") }
        close(fd)
        let raw = UnsafeRawPointer(base)
        // Hash the whole weights file into the dump so a byte-identical dump also pins the weights.
        var h = SHA256(); var off = 0; let step = 64 << 20
        while off < size { let n = min(step, size - off); h.update(bufferPointer: UnsafeRawBufferPointer(start: raw + off, count: n)); off += n }
        fileSha = h.finalize().map { String(format: "%02x", $0) }.joined()
        let hlen = Int(raw.loadUnaligned(as: UInt64.self).littleEndian)
        guard hlen > 0, 8 + hlen <= size else { fail("bad safetensors header length") }
        let hdata = Data(bytes: raw + 8, count: hlen)
        guard let hj = (try? JSONSerialization.jsonObject(with: hdata)) as? [String: Any] else { fail("bad safetensors header json") }
        let dataStart = 8 + hlen
        for (k, v) in hj where k != "__metadata__" {
            guard let e = v as? [String: Any], let dt = e["dtype"] as? String, let shape = e["shape"] as? [Int],
                  let offs = e["data_offsets"] as? [Int], offs.count == 2 else { fail("bad tensor entry \(k)") }
            guard dt == "BF16" else { fail("tensor \(k) dtype \(dt), expected BF16") }
            let n = shape.reduce(1, *)
            guard offs[1] - offs[0] == n * 2, dataStart + offs[1] <= size, (dataStart + offs[0]) % 2 == 0 else { fail("tensor \(k) bounds") }
            t[k] = BF(p: (raw + dataStart + offs[0]).assumingMemoryBound(to: UInt16.self), shape: shape)
        }
    }
    func get(_ k: String, _ shape: [Int]) -> BF {
        guard let b = t[k] else { fail("missing tensor \(k)") }
        guard b.shape == shape else { fail("tensor \(k) shape \(b.shape), expected \(shape)") }
        return b
    }
}

@inline(__always) func bf(_ u: UInt16) -> Float { Float(bitPattern: UInt32(u) << 16) }

// Fixed-order dot of a bf16 row with an fp32 vector; n % 16 == 0.
@inline(__always) func dotBF(_ w: UnsafePointer<UInt16>, _ x: UnsafePointer<Float>, _ n: Int) -> Float {
    var acc = SIMD16<Float>(repeating: 0)
    var i = 0
    let wr = UnsafeRawPointer(w), xr = UnsafeRawPointer(x)
    while i < n {
        let wu = wr.loadUnaligned(fromByteOffset: i * 2, as: SIMD16<UInt16>.self)
        let wf = unsafeBitCast(SIMD16<UInt32>(truncatingIfNeeded: wu) &<< 16, to: SIMD16<Float>.self)
        let xv = xr.loadUnaligned(fromByteOffset: i * 4, as: SIMD16<Float>.self)
        acc = acc.addingProduct(wf, xv)
        i += 16
    }
    var s: Float = 0
    for l in 0..<16 { s += acc[l] }
    return s
}
@inline(__always) func dotF(_ a: UnsafePointer<Float>, _ b: UnsafePointer<Float>, _ n: Int) -> Float {
    var acc = SIMD16<Float>(repeating: 0)
    var i = 0
    let ar = UnsafeRawPointer(a), br = UnsafeRawPointer(b)
    while i < n {
        acc = acc.addingProduct(ar.loadUnaligned(fromByteOffset: i * 4, as: SIMD16<Float>.self),
                                br.loadUnaligned(fromByteOffset: i * 4, as: SIMD16<Float>.self))
        i += 16
    }
    var s: Float = 0
    for l in 0..<16 { s += acc[l] }
    return s
}

// y[t][o] = W[o] . x[t] (+ b[o]); rows split across threads, each element computed by one fixed-order dot.
func linear(_ x: [Float], _ T: Int, _ inDim: Int, _ w: BF, _ outDim: Int, _ b: BF?) -> [Float] {
    var y = [Float](repeating: 0, count: T * outDim)
    let chunk = 64
    let nChunks = (outDim + chunk - 1) / chunk
    x.withUnsafeBufferPointer { xp in
        y.withUnsafeMutableBufferPointer { yp in
            let xb = xp.baseAddress!, yb = yp.baseAddress!
            DispatchQueue.concurrentPerform(iterations: nChunks) { c in
                let o0 = c * chunk, o1 = min(outDim, o0 + chunk)
                for o in o0..<o1 {
                    let wr = w.p + o * inDim
                    let bias: Float = b.map { bf($0.p[o]) } ?? 0
                    for t in 0..<T { yb[t * outDim + o] = dotBF(wr, xb + t * inDim, inDim) + bias }
                }
            }
        }
    }
    return y
}

func rmsnorm(_ x: [Float], _ T: Int, _ w: BF) -> [Float] {
    var y = [Float](repeating: 0, count: T * HID)
    for t in 0..<T {
        var ss: Float = 0
        for i in 0..<HID { let v = x[t * HID + i]; ss += v * v }
        let r = 1 / (ss / Float(HID) + EPS).squareRoot()
        for i in 0..<HID { y[t * HID + i] = bf(w.p[i]) * (x[t * HID + i] * r) }
    }
    return y
}

struct Layer { let ln1, q, qb, k, kb, v, vb, o, ln2, gate, up, down: BF }

final class Model {
    let embed: BF, norm: BF, lmHead: BF, layers: [Layer]
    let tiedHead: Bool
    var cosT = [Float](repeating: 0, count: CTX * (HDIM / 2)), sinT = [Float](repeating: 0, count: CTX * (HDIM / 2))
    var kc: [[Float]], vc: [[Float]]
    var len = 0
    init(_ w: Weights) {
        embed = w.get("model.embed_tokens.weight", [VOCAB, HID])
        norm = w.get("model.norm.weight", [HID])
        if let h = w.t["lm_head.weight"] { guard h.shape == [VOCAB, HID] else { fail("lm_head shape") }; lmHead = h; tiedHead = false }
        else { lmHead = embed; tiedHead = true }
        var ls: [Layer] = []
        for l in 0..<NLAYER {
            let p = "model.layers.\(l)."
            ls.append(Layer(ln1: w.get(p + "input_layernorm.weight", [HID]),
                q: w.get(p + "self_attn.q_proj.weight", [NHEAD * HDIM, HID]), qb: w.get(p + "self_attn.q_proj.bias", [NHEAD * HDIM]),
                k: w.get(p + "self_attn.k_proj.weight", [NKV * HDIM, HID]), kb: w.get(p + "self_attn.k_proj.bias", [NKV * HDIM]),
                v: w.get(p + "self_attn.v_proj.weight", [NKV * HDIM, HID]), vb: w.get(p + "self_attn.v_proj.bias", [NKV * HDIM]),
                o: w.get(p + "self_attn.o_proj.weight", [HID, NHEAD * HDIM]),
                ln2: w.get(p + "post_attention_layernorm.weight", [HID]),
                gate: w.get(p + "mlp.gate_proj.weight", [INTER, HID]), up: w.get(p + "mlp.up_proj.weight", [INTER, HID]),
                down: w.get(p + "mlp.down_proj.weight", [HID, INTER])))
        }
        layers = ls
        let half = HDIM / 2
        for d in 0..<half {
            let inv = Float(1.0 / pow(THETA, Double(2 * d) / Double(HDIM)))
            for p in 0..<CTX {
                let a = Float(p) * inv
                cosT[p * half + d] = Float(cos(Double(a))); sinT[p * half + d] = Float(sin(Double(a)))
            }
        }
        kc = Array(repeating: [Float](repeating: 0, count: CTX * NKV * HDIM), count: NLAYER)
        vc = Array(repeating: [Float](repeating: 0, count: CTX * NKV * HDIM), count: NLAYER)
    }
    func reset() { len = 0 }
    func rope(_ x: inout [Float], _ T: Int, _ heads: Int, _ p0: Int) {
        let half = HDIM / 2
        for t in 0..<T { for h in 0..<heads {
            let base = (t * heads + h) * HDIM, pos = p0 + t
            for d in 0..<half {
                let c = cosT[pos * half + d], s = sinT[pos * half + d]
                let x1 = x[base + d], x2 = x[base + d + half]
                x[base + d] = x1 * c - x2 * s
                x[base + d + half] = x2 * c + x1 * s
            }
        } }
    }
    // Forward T new tokens at positions len..<len+T; returns fp32 logits [T][VOCAB].
    func forward(_ ids: [Int]) -> [Float] {
        let T = ids.count, p0 = len
        guard p0 + T <= CTX else { fail("context overflow") }
        var h = [Float](repeating: 0, count: T * HID)
        for t in 0..<T { let r = embed.p + ids[t] * HID; for i in 0..<HID { h[t * HID + i] = bf(r[i]) } }
        let scale = 1 / Float(HDIM).squareRoot()
        for l in 0..<NLAYER {
            let L = layers[l]
            let xn = rmsnorm(h, T, L.ln1)
            var q = linear(xn, T, HID, L.q, NHEAD * HDIM, L.qb)
            var k = linear(xn, T, HID, L.k, NKV * HDIM, L.kb)
            let v = linear(xn, T, HID, L.v, NKV * HDIM, L.vb)
            rope(&q, T, NHEAD, p0); rope(&k, T, NKV, p0)
            for t in 0..<T { for i in 0..<(NKV * HDIM) {
                kc[l][(p0 + t) * NKV * HDIM + i] = k[t * NKV * HDIM + i]; vc[l][(p0 + t) * NKV * HDIM + i] = v[t * NKV * HDIM + i]
            } }
            var att = [Float](repeating: 0, count: T * NHEAD * HDIM)
            q.withUnsafeBufferPointer { qp in kc[l].withUnsafeBufferPointer { kp in vc[l].withUnsafeBufferPointer { vp in att.withUnsafeMutableBufferPointer { ap in
                let qb = qp.baseAddress!, kb = kp.baseAddress!, vb = vp.baseAddress!, ab = ap.baseAddress!
                DispatchQueue.concurrentPerform(iterations: T * NHEAD) { th in
                    let t = th / NHEAD, hd = th % NHEAD, kvh = hd / QPERKV
                    let n = p0 + t + 1
                    let qv = qb + (t * NHEAD + hd) * HDIM
                    var sc = [Float](repeating: 0, count: n)
                    var mx = -Float.infinity
                    for j in 0..<n { let s = dotF(qv, kb + (j * NKV + kvh) * HDIM, HDIM) * scale; sc[j] = s; if s > mx { mx = s } }
                    var sum: Float = 0
                    for j in 0..<n { let e = Float(exp(Double(sc[j] - mx))); sc[j] = e; sum += e }
                    let out = ab + (t * NHEAD + hd) * HDIM
                    for d in 0..<HDIM { out[d] = 0 }
                    for j in 0..<n { let pj = sc[j] / sum; let vr = vb + (j * NKV + kvh) * HDIM; for d in 0..<HDIM { out[d] += pj * vr[d] } }
                }
            } } } }
            let o = linear(att, T, NHEAD * HDIM, L.o, HID, nil)
            for i in 0..<(T * HID) { h[i] += o[i] }
            let xn2 = rmsnorm(h, T, L.ln2)
            let g = linear(xn2, T, HID, L.gate, INTER, nil)
            let u = linear(xn2, T, HID, L.up, INTER, nil)
            var a = [Float](repeating: 0, count: T * INTER)
            for i in 0..<(T * INTER) { let gv = g[i]; a[i] = (gv / (1 + Float(exp(Double(-gv))))) * u[i] }
            let dn = linear(a, T, INTER, L.down, HID, nil)
            for i in 0..<(T * HID) { h[i] += dn[i] }
        }
        len = p0 + T
        let hn = rmsnorm(h, T, norm)
        return linear(hn, T, HID, lmHead, VOCAB, nil)
    }
}

// Full-logit analysis of one fp32 position (same fields as the Core ML dispatch runner, fp32 bits).
func analyze(_ lg: UnsafeBufferPointer<Float>) -> [String: Any] {
    var nan = 0, winner = -1
    var best = -Float.infinity
    for i in 0..<VOCAB { let v = lg[i]; if v.isNaN { nan += 1; continue }; if winner < 0 || v > best { best = v; winner = i } }
    let im = lg[IM_END]
    var rank: Any = NSNull()
    if !im.isNaN { var above = 0; for i in 0..<VOCAB { let v = lg[i]; if !v.isNaN && v > im { above += 1 } }; rank = above + 1 }
    var top: [(Int, Float)] = []
    for i in 0..<VOCAB {
        let v = lg[i]; if v.isNaN { continue }
        if top.count < 5 || v > top[4].1 {
            if top.count == 5 { top.removeLast() }
            top.append((i, v)); top.sort { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0 < $1.0) }
        }
    }
    var row: [String: Any] = ["winner": winner, "nanCount": nan, "logitsSha256": hex(Data(buffer: lg)),
        "imEndLogitF32Bits": Int(im.bitPattern), "imEndLogit": f4(im), "imEndRank": rank,
        "top5": top.map { ["id": $0.0, "logit": f4($0.1)] }]
    if winner >= 0 { row["winnerLogit"] = f4(best); row["imEndMarginToWinner"] = im.isNaN ? "nan" : f4(best - im) }
    return row
}

@main struct Qwen25RefRunner {
    static func main() {
        let args = CommandLine.arguments
        guard args.count == 5 else { fail("usage: qwen25_ref_runner infer-chain <model.safetensors> <prompt.json> <decodeSteps>") }
        guard args[1] == "infer-chain" else { fail("argvMode must be infer-chain (got \(args[1]))") }
        guard let steps = Int(args[4]), steps >= 1 else { fail("decodeSteps must be a positive integer") }
        let env = ProcessInfo.processInfo.environment
        guard let dumpDir = env["LFM3_VECTOR_DUMP_DIR"], !dumpDir.isEmpty else { fail("LFM3_VECTOR_DUMP_DIR is required") }
        guard let pd = FileManager.default.contents(atPath: args[3]),
              let pj = (try? JSONSerialization.jsonObject(with: pd)) as? [String: Any],
              let pa = pj["ids"] as? [Any], !pa.isEmpty else { fail("\(args[3]) must be JSON with a non-empty ids array") }
        var prompt: [Int] = []
        for v in pa { guard let n = v as? Int, n >= 0, n < VOCAB else { fail("prompt ids must be integers in [0, \(VOCAB))") }; prompt.append(n) }
        guard prompt.count + steps <= CTX else { fail("prompt + decodeSteps exceeds context \(CTX)") }
        do { try FileManager.default.createDirectory(atPath: dumpDir, withIntermediateDirectories: true) } catch { fail("cannot create \(dumpDir)") }
        var result: [String: Any] = [:]
        let t0 = Date()
        let w = Weights(args[2])
        let m = Model(w)
        result["loadAndHashSeconds"] = Date().timeIntervalSince(t0)
        let header: [String: Any] = ["weightsSha256": w.fileSha, "tensorCount": w.t.count, "tiedLmHead": m.tiedHead,
            "config": ["hidden": HID, "layers": NLAYER, "heads": NHEAD, "kvHeads": NKV, "headDim": HDIM, "intermediate": INTER,
                       "vocab": VOCAB, "ropeTheta": "1000000", "rmsNormEps": "1e-6", "activation": "silu"],
            "precision": "bf16 weights widened to fp32; fp32 activations, KV cache, logits"]

        // ---- A. batched prefill ----
        let t1 = Date()
        let pl = m.forward(prompt)
        result["prefillSeconds"] = Date().timeIntervalSince(t1)
        var rows: [[String: Any]] = []
        var nanPos = 0
        pl.withUnsafeBufferPointer { bp in
            for p in 0..<prompt.count {
                var row = analyze(UnsafeBufferPointer(rebasing: bp[(p * VOCAB)..<((p + 1) * VOCAB)]))
                row["position"] = p; row["tokenIn"] = prompt[p]
                if (row["nanCount"] as? Int ?? 0) > 0 { nanPos += 1 }
                rows.append(row)
            }
            do {
                try Data(buffer: bp).write(to: URL(fileURLWithPath: dumpDir + "/logits-prefill-all.f32"))
                try Data(buffer: UnsafeBufferPointer(rebasing: bp[((prompt.count - 1) * VOCAB)..<(prompt.count * VOCAB)])).write(to: URL(fileURLWithPath: dumpDir + "/logits-prefill-last.f32"))
            } catch { fail("cannot write logits dump: \(error)") }
        }
        var pre = header
        pre["schema"] = "macbrains.research.qwen25-fp32-reference-prefill.v1"; pre["function"] = "prefill"
        pre["promptIds"] = prompt; pre["batch"] = prompt.count
        pre["winnerRule"] = "argmax over non-NaN fp32 logits, lowest index on ties; all-NaN -> winner -1"
        pre["positionsWithAnyNaN"] = nanPos; pre["imEndTokenId"] = IM_END; pre["positions"] = rows
        pre["logitsLayout"] = "logits-prefill-all.f32: [promptCount][151936] little-endian fp32; logits-prefill-last.f32: last prompt position"
        writeJSON(pre, dumpDir + "/prefill.json")

        // ---- B. single-token chain, greedy on full fp32 logits ----
        // Step promptCount-1 recomputes the last prompt token alone (len rewound by one; the KV cache rows of
        // positions 0..<promptCount-1 come from A) - that is the self-check. Then <tokens> decode steps.
        m.len = prompt.count - 1
        let total = prompt.count + steps
        var srows: [[String: Any]] = []
        var generated: [Int] = []
        var firstImEnd: Any = NSNull()
        var nanSteps = 0
        var last = 0
        var selfCheck: [String: Any] = [:]
        let lastOff = (prompt.count - 1) * VOCAB
        let t2 = Date()
        for s in (prompt.count - 1)..<total {
            let isPrompt = s < prompt.count
            let tok = isPrompt ? prompt[s] : last
            let lg = m.forward([tok])
            if s % 8 == 0 { FileHandle.standardError.write(Data("progress step \(s)/\(total - 1) t=\(Int(Date().timeIntervalSince(t2)))s\n".utf8)) }
            var winner = -1, best = -Float.infinity, second = -1, secondV = -Float.infinity, nan = 0
            for i in 0..<VOCAB {
                let v = lg[i]; if v.isNaN { nan += 1; continue }
                if winner < 0 || v > best { second = winner; secondV = best; best = v; winner = i }
                else if second < 0 || v > secondV { second = i; secondV = v }
            }
            if nan > 0 { nanSteps += 1 }
            var row: [String: Any] = ["step": s, "position": s, "tokenIn": tok, "phase": isPrompt ? "prompt" : "decode",
                "winner": winner, "winnerLogit": f4(best), "runnerUp": second, "runnerUpLogit": f4(secondV),
                "imEndLogit": f4(lg[IM_END]), "nanCount": nan]
            lg.withUnsafeBufferPointer { row["logitsSha256"] = hex(Data(buffer: $0)) }
            srows.append(row)
            if s == prompt.count - 1 {
                var maxAbs: Float = 0, differ = 0
                for i in 0..<VOCAB { let d = abs(lg[i] - pl[lastOff + i]); if lg[i].bitPattern != pl[lastOff + i].bitPattern { differ += 1 }; if d > maxAbs { maxAbs = d } }
                selfCheck = ["comparedPosition": s, "elementsWithDifferentBits": differ, "maxAbsDiff": String(format: "%.6e", maxAbs),
                             "bitIdentical": differ == 0,
                             "what": "single-token recompute of the last prompt position (KV cache of earlier positions from the batched prefill) vs the batched prefill logits at that position"]
            }
            if s >= prompt.count - 1 {
                generated.append(winner)
                if winner == IM_END, firstImEnd is NSNull { firstImEnd = generated.count - 1 }
                last = winner >= 0 ? winner : 0
            }
        }
        result["chainSeconds"] = Date().timeIntervalSince(t2)
        var chain = header
        chain["schema"] = "macbrains.research.qwen25-fp32-reference-chain.v1"; chain["function"] = "chain"
        chain["promptIds"] = prompt; chain["decodeSteps"] = steps
        chain["winnerRule"] = "argmax over non-NaN fp32 logits, lowest index on ties; all-NaN -> winner -1 and token 0 fed"
        chain["generatedRule"] = "generatedWinners[i] is the winner at step promptCount-1+i"
        chain["generatedWinners"] = generated; chain["firstImEndGeneratedIndex"] = firstImEnd
        chain["stepsWithAnyNaN"] = nanSteps; chain["imEndTokenId"] = IM_END
        chain["selfCheck"] = selfCheck; chain["steps"] = srows
        writeJSON(chain, dumpDir + "/chain.json")
        if let rj = env["LFM3_RESULT_JSON"], !rj.isEmpty {
            result["selfCheckBitIdentical"] = selfCheck["bitIdentical"] ?? false
            writeJSON(result, rj)
        }
        print("REF_DONE prefillWinnerLast=\(rows.last?["winner"] ?? -1) generated0=\(generated.first ?? -1) selfCheckBitIdentical=\(selfCheck["bitIdentical"] ?? false)")
    }
}
