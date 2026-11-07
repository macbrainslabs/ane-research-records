// main.swift - clean-room runner driver for the ANERECore v0.3.0 MIL-parity rerun.
//
// One file, compiled unchanged against either implementation's ANERECore sources:
//   ANE-RE: spi/swift_emit/Sources/ANERECore/*.swift
//   Fugu:   Sources/ANERECore/*.swift
// Build (as the cleanroom tool does): xcrun swiftc -O main.swift <ANERECore/*.swift> -o runner_rebuilt
//
// Cleanroom runner contract:
//   argv: <argvMode=fixture> <fixture model.mil> <tsv> <tokens>   (tsv and tokens are ignored)
//   env:  LFM3_VECTOR_DUMP_DIR  directory that receives tap.mil, steer.mil, functionWide.mil
//
// The fixture must be tests/fixtures/qwen/model.mil with sha256 PINNED_FIXTURE_SHA256; any other file is
// refused. The three operation sequences are ported from the Fugu PR #6 harness
// (Tests/ANERECoreParity/main.swift, tap and steer) and the v0.3.0 supplemental (functionWide). Each
// operation starts from a fresh parse of the same fixture bytes. Exit 0 only when all three files were
// written; claim scope is MIL text bytes only.
import Foundation
import CryptoKit

let PINNED_FIXTURE_SHA256 = "9c8dccb6900d2bf2be2be6a08cf78e38de3bb44aabddaaf7b53b0f3494d4c72f"

func die(_ code: Int32, _ m: String) -> Never {
    FileHandle.standardError.write(("anerecore_cleanroom_driver: " + m + "\n").data(using: .utf8)!)
    exit(code)
}
func hex(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

let argv = CommandLine.arguments
guard argv.count == 5 else { die(2, "usage: driver fixture <model.mil> <tsv> <tokens>") }
guard argv[1] == "fixture" else { die(2, "argvMode must be 'fixture', got '\(argv[1])'") }
let fixturePath = argv[2]
guard let dumpDir = ProcessInfo.processInfo.environment["LFM3_VECTOR_DUMP_DIR"], !dumpDir.isEmpty else {
    die(2, "LFM3_VECTOR_DUMP_DIR is required")
}
guard let fixtureData = FileManager.default.contents(atPath: fixturePath) else { die(3, "cannot read fixture \(fixturePath)") }
let fixtureSha = hex(fixtureData)
print("FIXTURE=\(fixturePath) SHA256=\(fixtureSha) BYTES=\(fixtureData.count)")
guard fixtureSha == PINNED_FIXTURE_SHA256 else {
    die(3, "FIXTURE_SHA256_MISMATCH want=\(PINNED_FIXTURE_SHA256) have=\(fixtureSha)")
}
guard let source = String(data: fixtureData, encoding: .utf8) else { die(3, "fixture is not valid UTF-8") }

// tap: Fugu harness mode "tap".
func runTap() throws -> String {
    let program = try MILTextParser.parse(source)
    let tx = RewriteTransaction(program)
    try tx.addReturn("hidden_states_21")
    return try tx.commit().raw
}

// steer: Fugu harness mode "steer".
func runSteer() throws -> String {
    let program = try MILTextParser.parse(source)
    let tx = RewriteTransaction(program)
    let constLine = "tensor<fp16, [1, 1, 1536]> const_steer = const()[name = string(\"const_steer\"), val = tensor<fp16, [1, 1, 1536]>(BLOBFILE(path = string(\"@model_path/weights/weight.bin\"), offset = uint64(64)))];"
    let addLine = "tensor<fp16, [1, 1, 1536]> hidden_states_5_steered = add(x = hidden_states_5, y = const_steer)[name = string(\"hidden_states_5_steered\")];"
    try tx.insertOp(constLine, afterVar: "hidden_states_5")
    try tx.insertOp(addLine, afterVar: "const_steer")
    try tx.replaceUses(of: "hidden_states_5", with: "hidden_states_5_steered", scope: .downstream)
    return try tx.commit().raw
}

// functionWide: v0.3.0 supplemental (addReturn, then replaceUses .functionWide, then commit).
func runFunctionWide() throws -> String {
    let program = try MILTextParser.parse(source)
    let tx = RewriteTransaction(program)
    try tx.addReturn("hidden_states_21")
    try tx.replaceUses(of: "hidden_states_21", with: "hidden_states_21_replaced", scope: .functionWide)
    return try tx.commit().raw
}

let operations: [(String, () throws -> String)] = [("tap", runTap), ("steer", runSteer), ("functionWide", runFunctionWide)]
var written = 0
for (name, op) in operations {
    let outPath = dumpDir + "/" + name + ".mil"
    do {
        let raw = try op()
        try raw.write(toFile: outPath, atomically: true, encoding: .utf8)
        guard let back = FileManager.default.contents(atPath: outPath) else { throw NSError(domain: "driver", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read back \(outPath)"]) }
        print("OP=\(name) FILE=\(name).mil BYTES=\(back.count) SHA256=\(hex(back))")
        written += 1
    } catch {
        FileHandle.standardError.write("OP=\(name) FAIL: \(error)\n".data(using: .utf8)!)
    }
}
print("WRITTEN=\(written)/\(operations.count)")
exit(written == operations.count ? 0 : 1)
