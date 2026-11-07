import AppKit
import QuickLookThumbnailing

/// A bounded, non-blocking Quick Look queue shared by the grid and full-screen preview.
/// No semaphores / dispatch_group.wait on user-interactive or decoding threads.
final class QuickLookBroker {
    static let shared = QuickLookBroker()
    private let lock = NSLock()
    private let failures = DecodeFailureThrottle(ttl: 75, capacity: 1024)
    private var pending: [() -> Void] = []
    private var inFlight = 0
    private let limit = 4

    func request(url: URL, pixelSize: Int, completion: @escaping (CGImage?) -> Void) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let version = "\(url.path)|\((attrs?[.size] as? NSNumber)?.int64Value ?? -1)|\((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)|\(pixelSize)"
        if failures.shouldSkip(version) { completion(nil); return }
        let job = { [weak self] in
            let size = CGFloat(max(64, pixelSize))
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: CGSize(width: size, height: size), scale: 1,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { result, _ in
                if result?.cgImage == nil { self?.failures.record(version) }
                else { self?.failures.clear(version) }
                completion(result?.cgImage)
                self?.finished()
            }
        }
        lock.lock()
        if inFlight < limit {
            inFlight += 1
            lock.unlock()
            job()
        } else {
            pending.append(job)
            lock.unlock()
        }
    }

    private func finished() {
        lock.lock()
        if pending.isEmpty {
            inFlight = max(0, inFlight - 1)
            lock.unlock()
        } else {
            let job = pending.removeFirst()
            lock.unlock()
            job()
        }
    }
}
