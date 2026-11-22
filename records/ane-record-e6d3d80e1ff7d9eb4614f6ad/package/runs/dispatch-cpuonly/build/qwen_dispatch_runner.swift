// qwen_dispatch_runner.swift - cleanroom runner for a stateful multifunction Core ML LLM package
// (functions "prefill" and "infer", 16 logit chunks of 9496) under one Core ML compute-unit setting,
// writing a deterministic dump for byte comparison across fresh-process runs.
//
// Interface (cleanroom.swift): runner <argvMode> <fixture> <tsv> <tokens>
//   argvMode  must be "infer-chain"
//   fixture   path to the compiled .mlmodelc
//   tsv       path to a JSON file {"ids":[Int]} holding the prompt token ids (at most 64)
//   tokens    number of greedy decode steps after the prompt
// Env:
//   LFM3_COMPUTE_UNITS    cpuOnly | cpuAndGPU | cpuAndNeuralEngine | all   (required)
//   LFM3_VECTOR_DUMP_DIR  output dir for the deterministic dump               (required)
//   LFM3_RESULT_JSON      optional: non-deterministic run facts (wall times, compute-plan op counts)
//
// A. prefill: one batched call on the prompt (padded to 64); full logits analysed at every prompt position.
// B. infer chain: the package's decode path; the prompt is fed one token per call, then greedy decoding
//    on the in-graph per-chunk argmax outputs (argmax_idx, argmax_val) for <tokens> steps.
//
// Dump (no timestamps or paths): prefill.json, logits-prefill-last.f16, chain.json.
// Winner rules are written into the dump. An all-NaN output gives winner -1 and feeds token 0.
//
// Build: xcrun swiftc -O -parse-as-library qwen_dispatch_runner.swift -o qwen_dispatch_runner

import CoreML
import CryptoKit
import Foundation

let CHUNK = 9496
let NCHUNK = 16
let VOCAB = CHUNK * NCHUNK   // 151936
let CTX = 512
let IM_END = 151645
let BATCH = 64

// Full-logit analysis of one position: winner, NaN count, <|im_end|> logit/rank/margin, top-5, sha of the raw fp16 bytes.
func analyze(_ logits: [Float16]) -> [String: Any] {
    var nan = 0, winner = -1
    var best = -Float.infinity
    for i in 0..<VOCAB {
        let v = Float(logits[i])
        if v.isNaN { nan += 1; continue }
        if winner < 0 || v > best { best = v; winner = i }
    }
    let imEnd = logits[IM_END]
    let imEndF = Float(imEnd)
    var rank: Any = NSNull()
    if !imEndF.isNaN {
        var above = 0
        for i in 0..<VOCAB { let v = Float(logits[i]); if !v.isNaN && v > imEndF { above += 1 } }
        rank = above + 1
    }
    var top: [(Int, Float)] = []
    for i in 0..<VOCAB {
        let v = Float(logits[i]); if v.isNaN { continue }
        if top.count < 5 || v > top[4].1 {
            if top.count == 5 { top.removeLast() }
            top.append((i, v)); top.sort { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0 < $1.0) }
        }
    }
    let raw = logits.withUnsafeBufferPointer { Data(buffer: $0) }
    var row: [String: Any] = ["winner": winner, "nanCount": nan, "logitsSha256": hex(raw),
        "imEndLogitF16Bits": Int(imEnd.bitPattern), "imEndLogit": imEndF.isNaN ? "nan" : String(format: "%.4f", imEndF),
        "imEndRank": rank, "top5": top.map { ["id": $0.0, "logit": String(format: "%.4f", $0.1)] }]
    if winner >= 0 { row["winnerLogit"] = String(format: "%.4f", best); row["imEndMarginToWinner"] = imEndF.isNaN ? "nan" : String(format: "%.4f", best - imEndF) }
    return row
}

func fail(_ msg: String, _ code: Int32 = 2) -> Never { FileHandle.standardError.write(Data(("ERROR " + msg + "\n").utf8)); exit(code) }
func hex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

func unitsFrom(_ s: String) -> MLComputeUnits {
    switch s {
    case "cpuOnly": return .cpuOnly
    case "cpuAndGPU": return .cpuAndGPU
    case "cpuAndNeuralEngine": return .cpuAndNeuralEngine
    case "all": return .all
    default: fail("LFM3_COMPUTE_UNITS must be cpuOnly, cpuAndGPU, cpuAndNeuralEngine or all (got \(s))")
    }
}

// Synchronous prediction (kept out of the async main so the blocking Core ML path is used).
func predictSync(_ m: MLModel, _ i: MLFeatureProvider, _ s: MLState) throws -> MLFeatureProvider { try m.prediction(from: i, using: s) }

func writeJSON(_ obj: Any, _ path: String) {
    guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted]) else { fail("cannot encode \(path)") }
    do { try d.write(to: URL(fileURLWithPath: path)) } catch { fail("cannot write \(path): \(error)") }
}

// Count preferred compute device per op of one function in the compute plan.
func planCounts(_ url: URL, _ cfg: MLModelConfiguration, _ function: String) async -> [String: Any] {
    do {
        let plan = try await MLComputePlan.load(contentsOf: url, configuration: cfg)
        guard case .program(let program) = plan.modelStructure else { return ["error": "model structure is not an ML program"] }
        guard let fn = program.functions[function] else { return ["error": "function \(function) not in compute plan"] }
        var cpu = 0, gpu = 0, ane = 0, unknown = 0, none = 0
        func visit(_ block: MLModelStructure.Program.Block) {
            for op in block.operations {
                if let usage = plan.deviceUsage(for: op) {
                    switch usage.preferred {
                    case .cpu: cpu += 1
                    case .gpu: gpu += 1
                    case .neuralEngine: ane += 1
                    @unknown default: unknown += 1
                    }
                } else { none += 1 }
                for b in op.blocks { visit(b) }
            }
        }
        visit(fn.block)
        return ["function": function, "cpu": cpu, "gpu": gpu, "neuralEngine": ane, "unknownDevice": unknown, "noDeviceUsage": none,
                "note": "Core ML compute-plan preferred device per op; placement, not a hardware execution trace"]
    } catch { return ["error": "\(error)"] }
}

@main struct QwenDispatchRunner {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count == 5 else { fail("usage: qwen_dispatch_runner infer-chain <model.mlmodelc> <prompt.json> <decodeSteps>") }
        guard args[1] == "infer-chain" else { fail("argvMode must be infer-chain (got \(args[1]))") }
        let modelPath = args[2], promptPath = args[3]
        guard let steps = Int(args[4]), steps >= 1 else { fail("decodeSteps must be a positive integer") }
        let env = ProcessInfo.processInfo.environment
        guard let unitName = env["LFM3_COMPUTE_UNITS"] else { fail("LFM3_COMPUTE_UNITS is required") }
        guard let dumpDir = env["LFM3_VECTOR_DUMP_DIR"], !dumpDir.isEmpty else { fail("LFM3_VECTOR_DUMP_DIR is required") }
        let units = unitsFrom(unitName)

        guard let pd = FileManager.default.contents(atPath: promptPath),
              let pj = (try? JSONSerialization.jsonObject(with: pd)) as? [String: Any],
              let promptAny = pj["ids"] as? [Any], !promptAny.isEmpty else { fail("\(promptPath) must be JSON with a non-empty ids array") }
        var prompt: [Int32] = []
        for v in promptAny {
            guard let n = v as? Int, n >= 0, n < VOCAB else { fail("prompt ids must be integers in [0, \(VOCAB))") }
            prompt.append(Int32(n))
        }
        let total = prompt.count + steps
        guard total <= CTX else { fail("prompt (\(prompt.count)) + decodeSteps (\(steps)) exceeds context \(CTX)") }
        do { try FileManager.default.createDirectory(atPath: dumpDir, withIntermediateDirectories: true) } catch { fail("cannot create \(dumpDir): \(error)") }

        guard prompt.count <= BATCH else { fail("prompt (\(prompt.count)) exceeds prefill batch \(BATCH)") }
        let url = URL(fileURLWithPath: modelPath)
        let neg = Float16(-40000.0), zero = Float16(0.0)
        var result: [String: Any] = ["computeUnits": unitName]

        // ---- A. prefill: one batched call on the prompt; full logits at every prompt position ----
        var prefillRows: [[String: Any]] = []
        var prefillNaNPositions = 0
        do {
            let pcfg = MLModelConfiguration(); pcfg.functionName = "prefill"; pcfg.computeUnits = units
            let t0 = Date()
            let pmodel: MLModel
            do { pmodel = try MLModel(contentsOf: url, configuration: pcfg) } catch { fail("prefill model load failed: \(error)", 3) }
            result["prefillLoadSeconds"] = Date().timeIntervalSince(t0)
            let pstate = pmodel.makeState()
            guard let ids = try? MLMultiArray(shape: [1, NSNumber(value: BATCH)], dataType: .int32),
                  let posIds = try? MLMultiArray(shape: [NSNumber(value: BATCH)], dataType: .int32),
                  let cur = try? MLMultiArray(shape: [1], dataType: .int32),
                  let mask = try? MLMultiArray(shape: [1, 1, NSNumber(value: BATCH), NSNumber(value: CTX)], dataType: .float16) else { fail("cannot allocate prefill inputs") }
            for i in 0..<BATCH { posIds[i] = NSNumber(value: i); ids[i] = NSNumber(value: i < prompt.count ? prompt[i] : 0) }
            cur[0] = 0
            let mp = mask.dataPointer.assumingMemoryBound(to: Float16.self)
            for q in 0..<BATCH { for k in 0..<CTX { mp[q * CTX + k] = (q < prompt.count && k <= q) ? zero : neg } }
            let input: MLDictionaryFeatureProvider
            do { input = try MLDictionaryFeatureProvider(dictionary: ["input_ids": ids, "position_ids": posIds, "current_pos": cur, "causal_mask": mask]) } catch { fail("prefill input: \(error)") }
            let t1 = Date()
            let out: MLFeatureProvider
            do { out = try predictSync(pmodel, input, pstate) } catch { fail("prefill prediction failed: \(error)", 4) }
            result["prefillSeconds"] = Date().timeIntervalSince(t1)
            var logits = [Float16](repeating: 0, count: VOCAB)
            var chunks: [MLMultiArray] = []
            for c in 0..<NCHUNK {
                guard let arr = out.featureValue(for: "logits\(c + 1)")?.multiArrayValue else { fail("prefill: missing output logits\(c + 1)") }
                guard arr.dataType == .float16, arr.count == BATCH * CHUNK, arr.strides.last?.intValue == 1 else { fail("prefill logits\(c + 1): expected \(BATCH)x\(CHUNK) contiguous float16, got shape \(arr.shape) strides \(arr.strides)") }
                chunks.append(arr)
            }
            for p in 0..<prompt.count {
                for c in 0..<NCHUNK {
                    let rowStride = chunks[c].strides[chunks[c].strides.count - 2].intValue
                    chunks[c].withUnsafeBufferPointer(ofType: Float16.self) { bp in
                        for j in 0..<CHUNK { logits[c * CHUNK + j] = bp[p * rowStride + j] }
                    }
                }
                var row = analyze(logits)
                row["position"] = p; row["tokenIn"] = Int(prompt[p])
                if (row["nanCount"] as? Int ?? 0) > 0 { prefillNaNPositions += 1 }
                prefillRows.append(row)
                if p == prompt.count - 1 {
                    let raw = logits.withUnsafeBufferPointer { Data(buffer: $0) }
                    do { try raw.write(to: URL(fileURLWithPath: dumpDir + "/logits-prefill-last.f16")) } catch { fail("cannot write logits dump: \(error)") }
                }
            }
            result["computePlanPrefill"] = await planCounts(url, pcfg, "prefill")
        }
        writeJSON(["schema": "macbrains.research.qwen-dispatch-prefill.v1", "computeUnits": unitName, "function": "prefill",
                   "promptIds": prompt.map { Int($0) }, "batch": BATCH,
                   "winnerRule": "argmax over non-NaN logits across 16 chunks, lowest index on ties; all-NaN -> winner -1",
                   "positionsWithAnyNaN": prefillNaNPositions, "imEndTokenId": IM_END, "positions": prefillRows], dumpDir + "/prefill.json")

        // ---- B. infer chain: the package's decode path, one token per call, greedy on the in-graph chunk argmax ----
        let cfg = MLModelConfiguration(); cfg.functionName = "infer"; cfg.computeUnits = units
        let t2 = Date()
        let model: MLModel
        do { model = try MLModel(contentsOf: url, configuration: cfg) } catch { fail("infer model load failed: \(error)", 3) }
        result["inferLoadSeconds"] = Date().timeIntervalSince(t2)
        let state = model.makeState()
        guard let ids = try? MLMultiArray(shape: [1, 1], dataType: .int32),
              let posIds = try? MLMultiArray(shape: [1], dataType: .int32),
              let cur = try? MLMultiArray(shape: [1], dataType: .int32),
              let mask = try? MLMultiArray(shape: [1, 1, 1, NSNumber(value: CTX)], dataType: .float16) else { fail("cannot allocate infer inputs") }
        let mp = mask.dataPointer.assumingMemoryBound(to: Float16.self)
        for k in 0..<CTX { mp[k] = neg }

        var rows: [[String: Any]] = []
        var generated: [Int] = []
        var firstImEnd: Any = NSNull()
        var nanStepCount = 0
        var lastFed: Int32 = 0
        let t3 = Date()
        for s in 0..<total {
            let isPrompt = s < prompt.count
            let tokenIn: Int32 = isPrompt ? prompt[s] : lastFed
            ids[0] = NSNumber(value: tokenIn); posIds[0] = NSNumber(value: s); cur[0] = NSNumber(value: s)
            mp[s] = zero   // causal row: positions 0...s visible
            let input: MLDictionaryFeatureProvider
            do { input = try MLDictionaryFeatureProvider(dictionary: ["input_ids": ids, "position_ids": posIds, "current_pos": cur, "causal_mask": mask]) } catch { fail("infer input: \(error)") }
            let out: MLFeatureProvider
            do { out = try predictSync(model, input, state) } catch { fail("infer prediction failed at step \(s): \(error)", 4) }
            guard let ai = out.featureValue(for: "argmax_idx")?.multiArrayValue, ai.dataType == .int32, ai.count == NCHUNK,
                  let av = out.featureValue(for: "argmax_val")?.multiArrayValue, av.dataType == .float16, av.count == NCHUNK else { fail("infer: expected argmax_idx int32[16] and argmax_val float16[16]") }
            var idx = [Int](repeating: 0, count: NCHUNK), valBits = [Int](repeating: 0, count: NCHUNK)
            var vals = [Float](repeating: 0, count: NCHUNK)
            ai.withUnsafeBufferPointer(ofType: Int32.self) { bp in for c in 0..<NCHUNK { idx[c] = Int(bp[c]) } }
            av.withUnsafeBufferPointer(ofType: Float16.self) { bp in for c in 0..<NCHUNK { valBits[c] = Int(bp[c].bitPattern); vals[c] = Float(bp[c]) } }
            var bestChunk = -1, bestV = -Float.infinity, nanChunks = 0
            for c in 0..<NCHUNK {
                if vals[c].isNaN { nanChunks += 1; continue }
                if bestChunk < 0 || vals[c] > bestV { bestV = vals[c]; bestChunk = c }
            }
            if nanChunks > 0 { nanStepCount += 1 }
            let winner = bestChunk >= 0 ? bestChunk * CHUNK + idx[bestChunk] : -1
            let fed: Int32 = winner >= 0 ? Int32(winner) : 0
            var row: [String: Any] = ["step": s, "phase": isPrompt ? "prompt" : "decode", "tokenIn": Int(tokenIn),
                                      "chunkArgmaxIdx": idx, "chunkArgmaxValF16Bits": valBits, "nanChunks": nanChunks, "winner": winner]
            if winner >= 0 { row["winnerValue"] = String(format: "%.4f", bestV) } else { row["fedToken"] = Int(fed) }
            rows.append(row)
            if s >= prompt.count - 1 {
                // the output at step s predicts the token at s+1; generation starts at the last prompt step
                generated.append(winner)
                if winner == IM_END, firstImEnd is NSNull { firstImEnd = generated.count - 1 }
            }
            lastFed = fed
        }
        result["inferChainSeconds"] = Date().timeIntervalSince(t3)
        result["computePlanInfer"] = await planCounts(url, cfg, "infer")
        let chain: [String: Any] = [
            "schema": "macbrains.research.qwen-dispatch-chain.v1", "computeUnits": unitName, "function": "infer",
            "promptIds": prompt.map { Int($0) }, "promptCount": prompt.count, "decodeSteps": steps,
            "winnerRule": "chunk with the largest non-NaN argmax_val (lowest chunk on ties); token = chunk*9496 + argmax_idx[chunk]; all-NaN -> winner -1, fed token 0",
            "generatedWinners": generated, "generatedNote": "generatedWinners[i] is the winner at step promptCount-1+i, i.e. generated token i",
            "firstImEndGeneratedIndex": firstImEnd, "stepsWithAnyNaN": nanStepCount, "imEndTokenId": IM_END, "steps": rows]
        writeJSON(chain, dumpDir + "/chain.json")
        result["firstImEndGeneratedIndex"] = firstImEnd; result["inferStepsWithAnyNaN"] = nanStepCount; result["prefillPositionsWithAnyNaN"] = prefillNaNPositions
        if let rj = env["LFM3_RESULT_JSON"], !rj.isEmpty { writeJSON(result, rj) }
        print("ok units=\(unitName) firstImEnd=\(firstImEnd) inferNaNSteps=\(nanStepCount) prefillNaNPositions=\(prefillNaNPositions)")
    }
}
