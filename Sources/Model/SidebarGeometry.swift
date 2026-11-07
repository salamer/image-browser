import Foundation

/// Pure, deterministic sidebar sizing. Safe for NSView's transient 0×0 frames.
struct SidebarGeometry {
    static func scrollRect(container: CGSize, header: CGFloat = 44) -> CGRect {
        let width = container.width.isFinite ? max(0, container.width) : 0
        let height = container.height.isFinite ? max(0, container.height) : 0
        return CGRect(x: 0, y: 0, width: width, height: max(0, height - max(0, header)))
    }

    static func canShowScroller(in rect: CGRect) -> Bool {
        rect.width >= 42 && rect.height >= 24
    }
}
