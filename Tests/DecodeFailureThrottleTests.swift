import Foundation

@main
enum DecodeFailureThrottleTests {
    static func main() {
        let t = DecodeFailureThrottle(ttl: 5, capacity: 2)
        let start = Date(timeIntervalSince1970: 100)
        assert(!t.shouldSkip("image-a", now: start))
        t.record("image-a", now: start)
        assert(t.shouldSkip("image-a", now: start.addingTimeInterval(2)))
        assert(!t.shouldSkip("image-a", now: start.addingTimeInterval(5)))
        t.record("image-a", now: start)
        t.clear("image-a")
        assert(!t.shouldSkip("image-a", now: start))
        t.record("old", now: start)
        t.record("mid", now: start.addingTimeInterval(1))
        t.record("new", now: start.addingTimeInterval(2))
        assert(!t.shouldSkip("old", now: start.addingTimeInterval(2)))
        assert(t.shouldSkip("mid", now: start.addingTimeInterval(2)))
        assert(t.shouldSkip("new", now: start.addingTimeInterval(2)))
        let concurrent = DecodeFailureThrottle(ttl: 5, capacity: 32)
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            let key = "\(i % 20)"
            concurrent.record(key)
            _ = concurrent.shouldSkip(key)
        }
        print("PASS DecodeFailureThrottle: expiration, clear, capacity, concurrency")
    }
}
