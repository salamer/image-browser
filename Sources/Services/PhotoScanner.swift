import Foundation
import ImageIO

/// An explicit cancellation handle. Cancellation is checked during enumeration and metadata reads.
final class ScanCancellation {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

enum PhotoScanner {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp",
        "avif", "jp2", "jxl", "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "psd"
    ]

    /// Emits incremental BATCHES, not repeated copies of the full catalog.
    /// The consumer must append new files to its own model; finished is true exactly once
    /// if the scan wasn't cancelled. All completion callbacks arrive on the main queue.
    @discardableResult
    static func scan(_ folder: URL, recursive: Bool,
                     progress: @escaping ([PhotoFile], Bool) -> Void) -> ScanCancellation {
        let cancellation = ScanCancellation()
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let keys: Set<URLResourceKey> = [
                .isRegularFileKey, .isDirectoryKey, .isPackageKey,
                .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey
            ]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            var batch: [PhotoFile] = []
            batch.reserveCapacity(96)
            var lastEmit = Date()

            // Recursive traversal produces batches immediately instead of building
            // an O(total file count) URL list before the first image appears.
            func consume(_ url: URL) {
                guard !cancellation.isCancelled,
                      supportedExtensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else { return }
                let dimensions = dimensions(url)
                batch.append(PhotoFile(url: url, name: url.lastPathComponent,
                    size: Int64(values.fileSize ?? 0),
                    modified: values.contentModificationDate ?? .distantPast,
                    pixelWidth: dimensions.0, pixelHeight: dimensions.1))
                if batch.count >= 96 || (batch.count >= 24 && Date().timeIntervalSince(lastEmit) > 0.20) {
                    let emitted = batch
                    batch.removeAll(keepingCapacity: true)
                    lastEmit = Date()
                    DispatchQueue.main.async { if !cancellation.isCancelled { progress(emitted, false) } }
                }
            }

            if recursive {
                if let enumerator = fm.enumerator(at: folder,
                    includingPropertiesForKeys: Array(keys), options: options) {
                    while !cancellation.isCancelled, let url = enumerator.nextObject() as? URL {
                        if let values = try? url.resourceValues(forKeys: keys),
                           values.isSymbolicLink == true || values.isPackage == true {
                            enumerator.skipDescendants()
                            continue
                        }
                        consume(url)
                    }
                }
            } else {
                let urls = ((try? fm.contentsOfDirectory(at: folder,
                    includingPropertiesForKeys: Array(keys), options: options)) ?? [])
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                for url in urls {
                    if cancellation.isCancelled { return }
                    consume(url)
                }
            }
            guard !cancellation.isCancelled else { return }
            let finalBatch = batch
            DispatchQueue.main.async { if !cancellation.isCancelled { progress(finalBatch, true) } }
        }
        return cancellation
    }

    static func dimensions(_ url: URL) -> (Int, Int) {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let w = info[kCGImagePropertyPixelWidth as String] as? Int,
              let h = info[kCGImagePropertyPixelHeight as String] as? Int else { return (0, 0) }
        let orientation = info[kCGImagePropertyOrientation as String] as? Int ?? 1
        return (5...8).contains(orientation) ? (h, w) : (w, h)
    }
}
