import Foundation

/// Local, non-destructive ratings and favorites; original media files are never modified.
/// Uses a single JSON file in Application Support, not Finder metadata or a hidden sidecar.
struct PhotoAnnotation: Codable {
    var rating: Int = 0
    var favorite: Bool = false
}

final class PhotoAnnotations {
    static let shared = PhotoAnnotations()
    private var values: [String: PhotoAnnotation] = [:]
    private let saveQueue = DispatchQueue(label: "SwiftLens.annotations.save", qos: .utility)
    private let file: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("SwiftLens", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("annotations.json")
        if let data = try? Data(contentsOf: file),
           let parsed = try? JSONDecoder().decode([String: PhotoAnnotation].self, from: data) {
            values = parsed
        }
    }

    func annotation(for url: URL) -> PhotoAnnotation { values[url.path] ?? PhotoAnnotation() }

    func setRating(_ rating: Int, for url: URL) {
        var annotation = self.annotation(for: url)
        annotation.rating = min(5, max(0, rating))
        values[url.path] = annotation
        persist()
    }

    func toggleFavorite(for url: URL) {
        var annotation = self.annotation(for: url)
        annotation.favorite.toggle()
        values[url.path] = annotation
        persist()
    }

    /// Keep local ratings/favorites linked after file management operations.
    func transfer(from source: URL, to destination: URL, copy: Bool) {
        guard let item = values[source.path] else { return }
        values[destination.path] = item
        if !copy { values.removeValue(forKey: source.path) }
        persist()
    }

    private func persist() {
        let snapshot = values
        let destination = file
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: destination, options: .atomic)
        }
    }
}
