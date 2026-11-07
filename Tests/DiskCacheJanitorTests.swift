import Foundation

@main
struct DiskCacheJanitorTests {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("SwiftLens-test-\(UUID().uuidString)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }
        for i in 0..<3 {
            let file = folder.appendingPathComponent("\(i).jpg")
            try Data(repeating: UInt8(i), count: 1000).write(to: file)
            try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(i) + 1000)],
                                 ofItemAtPath: file.path)
        }
        let userFile = folder.appendingPathComponent("user.txt")
        try Data(repeating: 0, count: 1000).write(to: userFile)
        DiskCacheJanitor.prune(folder, maxBytes: 1500)
        let remaining = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let jpg = remaining.filter { $0.pathExtension == "jpg" }
        precondition(jpg.count == 1, "Cache was not pruned to target size")
        precondition(jpg[0].lastPathComponent == "2.jpg", "Newest image must be retained")
        precondition(fm.fileExists(atPath: userFile.path), "Never touch non-cache files")
        print("PASS bounded cache size")
        print("PASS oldest cache files pruned first")
        print("PASS non-cache file preservation")
        print("3 DiskCacheJanitor tests passed")
    }
}
