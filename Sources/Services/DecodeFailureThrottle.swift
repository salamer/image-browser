import Foundation

/// Expiring negative cache for unsupported/corrupt images.
/// A failure is never permanent and a changed file has a different caller key.
/// The dictionary is bounded and protected because decoders run concurrently.
final class DecodeFailureThrottle {
    private let lock = NSLock()
    private var expiry: [String: Date] = [:]
    private let ttl: TimeInterval
    private let capacity: Int

    init(ttl: TimeInterval = 60, capacity: Int = 1024) {
        self.ttl = max(1, ttl)
        self.capacity = max(1, capacity)
    }

    func shouldSkip(_ key: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let deadline = expiry[key] else { return false }
        if deadline > now { return true }
        expiry.removeValue(forKey: key)
        return false
    }

    func record(_ key: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        expiry[key] = now.addingTimeInterval(ttl)
        if expiry.count > capacity {
            let count = expiry.count - capacity
            for entry in expiry.sorted(by: { $0.value < $1.value }).prefix(count) {
                expiry.removeValue(forKey: entry.key)
            }
        }
    }

    func clear(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        expiry.removeValue(forKey: key)
    }
}
