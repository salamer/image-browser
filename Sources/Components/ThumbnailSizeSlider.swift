import AppKit

/// Live horizontal slider. Horizontal two-finger swipes while hovering the
/// control also nudge the size, without stealing vertical scrolls from the grid.
final class ThumbnailSizeSlider: NSSlider {
    override func scrollWheel(with event: NSEvent) {
        let dx = Double(event.scrollingDeltaX)
        guard abs(dx) > 0.01 else {
            super.scrollWheel(with: event)
            return
        }
        let step = event.hasPreciseScrollingDeltas ? dx * 1.2 : dx * 5
        let next = min(maxValue, max(minValue, doubleValue + step))
        guard abs(next - doubleValue) > 0.1 else { return }
        doubleValue = next
        if let action { _ = sendAction(action, to: target) }
    }
}
