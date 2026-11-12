import Foundation
let fm = FileManager.default
func walkDump(_ dir: String) -> (entries: [String], unreadable: [String]) {
    guard fm.fileExists(atPath: dir) else { return ([], []) }
    let root = URL(fileURLWithPath: dir).resolvingSymlinksInPath().standardizedFileURL
    let rp = root.path
    func relOf(_ u: URL) -> String { let p = u.standardizedFileURL.path; return p.hasPrefix(rp + "/") ? String(p.dropFirst(rp.count + 1)) : p }
    var bad: [String] = []
    guard let en = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [],
                                 errorHandler: { u, _ in bad.append(relOf(u)); return true }) else { return ([], ["."]) }
    var out: [String] = []
    for case let u as URL in en { out.append(relOf(u)) }
    return (out, bad)
}
let r = walkDump(CommandLine.arguments[1]); for e in r.entries.sorted() { print("E \(e)") }; for b in r.unreadable.sorted() { print("U \(b)") }
