import Foundation

struct PhotoFile: Hashable {
    let url: URL
    let name: String
    let size: Int64
    let modified: Date
    let pixelWidth: Int
    let pixelHeight: Int

    static func == (lhs: PhotoFile, rhs: PhotoFile) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    var subtitle: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
    var dimensions: String { pixelWidth > 0 ? "\(pixelWidth)×\(pixelHeight)" : "—" }
    var aspectRatio: CGFloat {
        guard pixelWidth > 0 && pixelHeight > 0 else { return 1.1 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }
}

final class FolderNode: NSObject {
    let url: URL
    private(set) var children: [FolderNode]?
    init(url: URL) { self.url = url }
    var title: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }

    func loadChildren() -> [FolderNode] {
        if let children { return children }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: url,
            includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants])) ?? []
        children = urls.compactMap { item -> FolderNode? in
            guard let v = try? item.resourceValues(forKeys: keys), v.isDirectory == true,
                  v.isPackage != true, v.isSymbolicLink != true else { return nil }
            return FolderNode(url: item)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return children ?? []
    }
}

extension PhotoFile: BrowserAsset {}
