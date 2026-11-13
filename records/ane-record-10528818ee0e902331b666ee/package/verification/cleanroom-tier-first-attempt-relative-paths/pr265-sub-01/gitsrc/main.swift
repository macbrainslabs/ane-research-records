import Foundation
let env = ProcessInfo.processInfo.environment
let a = CommandLine.arguments            // argvMode fixture tsv tokens
let dump = env["LFM3_VECTOR_DUMP_DIR"] ?? "."
FileManager.default.createFile(atPath: dump + "/a.bin", contents: Data("a-bytes".utf8))
if env["SUB_EXTRA"] == "1" { FileManager.default.createFile(atPath: dump + "/extra.bin", contents: Data("x".utf8)) }
if env["SUB_TOUCH_FIXTURE"] == "1" { try? Data("changed\n".utf8).write(to: URL(fileURLWithPath: a[2])) }
print("FULL_PLAN_SUMMARY scratch")
