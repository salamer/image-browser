import Foundation

@main struct SidebarGeometryTests {
    static func main() {
        let widths: [CGFloat] = [0, 1, 17, 40, 42, 120, 246, 390, 1000]
        let heights: [CGFloat] = [0, 1, 20, 44, 60, 68, 100, 800]
        var assertions = 0
        for width in widths {
            for height in heights {
                let rect = SidebarGeometry.scrollRect(container: CGSize(width: width, height: height))
                precondition(rect.origin == .zero)
                precondition(rect.width >= 0 && rect.width <= width)
                precondition(rect.height >= 0 && rect.height <= height)
                precondition(SidebarGeometry.canShowScroller(in: rect) == (width >= 42 && height >= 68))
                assertions += 4
            }
        }
        let invalid = SidebarGeometry.scrollRect(container: CGSize(width: .infinity, height: -.infinity))
        precondition(invalid.width == 0 && invalid.height == 0)
        print("PASS SidebarGeometry: \(assertions + 2) zero-size/small-window assertions")
    }
}
