import Foundation
@main struct EchoRunner { static func main() {
  let d = ProcessInfo.processInfo.environment["LFM3_VECTOR_DUMP_DIR"] ?? "."
  try? FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true)
  try? "echo \(CommandLine.arguments.dropFirst().joined(separator: " "))\n".write(toFile: d + "/echo.txt", atomically: true, encoding: .utf8)
} }
