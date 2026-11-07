import Foundation

/// Prunes oldest cached thumbnails without ever touching user pictures.
enum DiskCacheJanitor {
    static func prune(_ folder: URL, maxBytes: Int64) {
        let fm = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? fm.contentsOfDirectory(at: folder,
                            includingPropertiesForKeys: Array(resourceKeys),
                            options: [.skipsHiddenFiles]) else { return }
        let entries: [(url: URL, bytes: Int64, date: Date)] = urls.compactMap { url in
            guard url.pathExtension == "jpg",
                  let info = try? url.resourceValues(forKeys: resourceKeys),
                  info.isRegularFile == true else { return nil }
            return (url, Int64(info.fileSize ?? 0), info.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.bytes }
        if total <= maxBytes { return }
        for item in entries.sorted(by: { $0.date < $1.date }) {
            guard total > maxBytes * 3 / 4 else { break }
            if (try? fm.removeItem(at: item.url)) != nil { total -= item.bytes }
        }
    }
}
