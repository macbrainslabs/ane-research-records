import Foundation
import CoreML

guard CommandLine.arguments.count >= 2 else { print("usage: computeplan <mlpackage>"); exit(2) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let sem = DispatchSemaphore(value: 0)
Task {
    defer { sem.signal() }
    do {
        var planURL = url
        if url.pathExtension == "mlpackage" {
            print("COMPILING mlpackage first via MLModel.compileModel")
            planURL = try await MLModel.compileModel(at: url)
            print("COMPILED_TO \(planURL.path)")
        }
        let plan = try await MLComputePlan.load(contentsOf: planURL, configuration: MLModelConfiguration())
        var total = 0
        var counts: [String:Int] = [:]
        var nonANE: [String] = []
        var opTypes: [String:Int] = [:]
        func devName(_ d: MLComputeDevice) -> String {
            if case .neuralEngine = d { return "ANE" }
            if case .cpu = d { return "CPU" }
            if case .gpu = d { return "GPU" }
            return String(describing: d)
        }
        func walk(_ ops: [MLModelStructure.Program.Operation], _ fname: String) {
            for op in ops {
                total += 1
                opTypes[op.operatorName, default: 0] += 1
                var pref = "nil"
                if let du = plan.deviceUsage(for: op) { pref = devName(du.preferred) }
                counts[pref, default: 0] += 1
                if pref != "ANE" {
                    let outNames = op.outputs.map { $0.name }.joined(separator: ",")
                    nonANE.append("\(fname): \(op.operatorName) outputs=\(outNames) pref=\(pref)")
                }
                for b in op.blocks { walk(b.operations, fname) }
            }
        }
        switch plan.modelStructure {
        case .program(let prog):
            for (fname, fn) in prog.functions { walk(fn.block.operations, fname) }
        case .neuralNetwork(let nn):
            for layer in nn.layers {
                total += 1
                var pref = "nil"
                if let du = plan.deviceUsage(for: layer) { pref = devName(du.preferred) }
                counts[pref, default: 0] += 1
                if pref != "ANE" { nonANE.append("\(layer.name): \(layer.type) pref=\(pref)") }
            }
        default:
            print("OTHER_STRUCTURE")
        }
        print("TOTAL \(total)")
        for k in counts.keys.sorted() { print("DEVICE \(k) \(counts[k]!)") }
        print("NON_ANE_COUNT \(nonANE.count)")
        for s in nonANE { print("NON_ANE \(s)") }
        print("OP_TYPES \(opTypes)")
    } catch {
        print("ERROR \(error)")
    }
}
sem.wait()
