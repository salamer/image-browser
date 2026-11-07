import AppKit
import CryptoKit
import ImageIO
import QuickLookThumbnailing

/// Decoder never waits synchronously for a Quick Look callback.
/// Broken WebP thumbnail paths fall back to full-frame decode and downsampling.
/// Color-profile warnings from Apple's decoder can still be logged for malformed source files.
enum ImageDecoder {
    private static let failures = DecodeFailureThrottle(ttl: 75, capacity: 1024)

    static func thumbnail(_ url: URL, maxPixelSize: Int) -> CGImage? {
        // The same incompatible WebP may be requested many times while scrolling.
        // Key by file version, so replacing it on disk immediately permits a retry.
        let isWebP = url.pathExtension.lowercased() == "webp"
        let attributes = isWebP ? (try? FileManager.default.attributesOfItem(atPath: url.path)) : nil
        let version = isWebP ? "\(url.path)|\((attributes?[.size] as? NSNumber)?.int64Value ?? -1)|\((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)" : ""
        if isWebP && failures.shouldSkip(version) { return nil }
        let options = [kCGImageSourceShouldCache: false,
                       kCGImageSourceShouldCacheImmediately: false] as CFDictionary
        if let source = CGImageSourceCreateWithURL(url as CFURL, options) {
            let thumb: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ]
            if url.pathExtension.lowercased() == "webp" {
                // Some macOS builds fail at WebP thumbnail generation even when frame decode works.
                if let full = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    return downsample(full, maxPixelSize: maxPixelSize)
                }
            } else if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumb as CFDictionary) {
                return image
            }
            if let fullImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return downsample(fullImage, maxPixelSize: maxPixelSize)
            }
        }
        // NSImage may use a different system decoder for some media formats.
        if let image = NSImage(contentsOf: url),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return downsample(cgImage, maxPixelSize: maxPixelSize)
        }
        if isWebP { failures.record(version) }
        return nil
    }

    static func downsample(_ input: CGImage, maxPixelSize: Int) -> CGImage? {
        let longest = max(input.width, input.height)
        guard longest > maxPixelSize else { return input }
        let factor = CGFloat(maxPixelSize) / CGFloat(longest)
        let size = CGSize(width: max(1, Int(CGFloat(input.width) * factor)),
                          height: max(1, Int(CGFloat(input.height) * factor)))
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return input }
        ctx.interpolationQuality = .high
        ctx.draw(input, in: CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }
}

final class ThumbnailPipeline {
    static let shared = ThumbnailPipeline()
    private let memory = NSCache<NSString, NSImage>()
    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SwiftLens.thumbnail.decode"
        queue.maxConcurrentOperationCount = min(6, max(2, ProcessInfo.processInfo.activeProcessorCount / 2))
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private let diskQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SwiftLens.thumbnail.cache.write"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    private let cacheDirectory: URL
    private var writesSinceCleanup = 0

    private init() {
        memory.totalCostLimit = 256 * 1024 * 1024
        memory.countLimit = 1200
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftLens/Thumbnails-v3", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let directory = cacheDirectory
        diskQueue.addOperation {
            DiskCacheJanitor.prune(directory, maxBytes: 768 * 1024 * 1024)
        }
    }

    func cancelPending() { decodeQueue.cancelAllOperations() }

    private func key(for photo: PhotoFile, pixelSize: Int) -> String {
        let raw = "3|\(photo.url.path)|\(photo.size)|\(photo.modified.timeIntervalSince1970)|\(pixelSize)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func cachedImage(for photo: PhotoFile, pixelSize: Int) -> NSImage? {
        memory.object(forKey: key(for: photo, pixelSize: pixelSize) as NSString)
    }

    @discardableResult
    func request(_ photo: PhotoFile, pixelSize: Int,
                 completion: @escaping (NSImage?) -> Void) -> Operation? {
        let key = key(for: photo, pixelSize: pixelSize)
        if let cached = memory.object(forKey: key as NSString) {
            completion(cached)
            return nil
        }
        let diskURL = cacheDirectory.appendingPathComponent(key + ".jpg")
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let self, let operation, !operation.isCancelled else { return }
            if FileManager.default.fileExists(atPath: diskURL.path),
               let cg = ImageDecoder.thumbnail(diskURL, maxPixelSize: pixelSize) {
                self.finish(cg, key: key, diskURL: nil, operation: operation, completion: completion)
                return
            }
            if let cg = ImageDecoder.thumbnail(photo.url, maxPixelSize: pixelSize) {
                self.finish(cg, key: key, diskURL: diskURL, operation: operation, completion: completion)
                return
            }
            // Broker bounds concurrent Quick Look decodes WITHOUT dropping requests
            // when its slots are busy, and does not block a high-QoS thread.
            QuickLookBroker.shared.request(url: photo.url, pixelSize: pixelSize) { [weak self] cg in
                guard let self, !operation.isCancelled, let cg else {
                    DispatchQueue.main.async { if !operation.isCancelled { completion(nil) } }
                    return
                }
                self.finish(cg, key: key, diskURL: diskURL, operation: operation, completion: completion)
            }
        }
        decodeQueue.addOperation(operation)
        return operation
    }

    private func finish(_ cg: CGImage, key: String, diskURL: URL?,
                        operation: Operation, completion: @escaping (NSImage?) -> Void) {
        guard !operation.isCancelled else { return }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        memory.setObject(image, forKey: key as NSString, cost: cg.width * cg.height * 4)
        if let diskURL, diskQueue.operationCount < 20 {
            diskQueue.addOperation { [weak self] in
                let rep = NSBitmapImageRep(cgImage: cg)
                if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.84]) {
                    try? data.write(to: diskURL, options: .atomic)
                    if let self {
                        self.writesSinceCleanup += 1 // serial utility queue only
                        if self.writesSinceCleanup >= 300 {
                            self.writesSinceCleanup = 0
                            DiskCacheJanitor.prune(self.cacheDirectory, maxBytes: 768 * 1024 * 1024)
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async { if !operation.isCancelled { completion(image) } }
    }
}

final class PreviewPipeline {
    static let shared = PreviewPipeline()
    private let memory = NSCache<NSString, NSImage>()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "SwiftLens.preview.decode"
        q.maxConcurrentOperationCount = 2
        q.qualityOfService = .userInitiated
        return q
    }()

    private init() { memory.totalCostLimit = 144 * 1024 * 1024 }
    func cancelPending() { queue.cancelAllOperations() }

    func request(_ url: URL, maxPixelSize: Int = 8192, completion: @escaping (NSImage?) -> Void) {
        // Include file identity so replacing an image in-place cannot reuse stale pixels.
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let changed = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(size)|\(changed)|\(maxPixelSize)" as NSString
        if let existing = memory.object(forKey: key) { completion(existing); return }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation, !operation.isCancelled else { return }
            let cg = ImageDecoder.thumbnail(url, maxPixelSize: maxPixelSize)
            guard !operation.isCancelled else { return }
            if let cg {
                let result = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                self?.memory.setObject(result, forKey: key, cost: cg.width * cg.height * 4)
                DispatchQueue.main.async { if !operation.isCancelled { completion(result) } }
            } else {
                QuickLookBroker.shared.request(url: url, pixelSize: maxPixelSize) { cg in
                    let result = cg.map { NSImage(cgImage: $0,
                                        size: NSSize(width: $0.width, height: $0.height)) }
                    DispatchQueue.main.async { if !operation.isCancelled { completion(result) } }
                }
            }
        }
        queue.addOperation(operation)
    }
}
