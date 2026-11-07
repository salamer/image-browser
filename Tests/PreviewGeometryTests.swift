import Foundation

func near(_ value: CGFloat, _ expected: CGFloat, _ msg: String) {
    precondition(abs(value - expected) < 0.001, "\(msg): \(value) != \(expected)")
}

@main struct PreviewGeometryTests {
    static func main() {
        let image = CGSize(width: 1000, height: 1500)
        let large = CGSize(width: 1200, height: 900)
        let small = CGSize(width: 600, height: 450)
        near(PreviewGeometry.fitZoom(viewport: large, pixels: image, backingScale: 2), 1.2, "large fit")
        near(PreviewGeometry.fitZoom(viewport: small, pixels: image, backingScale: 2), 0.6, "small fit")
        let rect = PreviewGeometry.imageRect(viewport: large, pixels: image, backingScale: 2, zoom: 1.2)
        near(rect.origin.x, 300, "center x")
        near(rect.origin.y, 0, "center y")
        near(rect.width, 600, "draw width")
        near(rect.height, 900, "draw height")
        let pan = PreviewGeometry.clampPan(CGPoint(x: 10000, y: -10000),
              viewport: small, extent: CGSize(width: 1000, height: 800))
        near(pan.x, 200, "pan max x")
        near(pan.y, -175, "pan min y")
        let unclipped = PreviewGeometry.clampPan(CGPoint(x: 100, y: -100),
            viewport: large, extent: CGSize(width: 300, height: 300))
        near(unclipped.x, 0, "short x")
        near(unclipped.y, 0, "short y")
        let fit = PreviewGeometry.usableRect(in: CGSize(width: 1000, height: 700),
                                             margin: 14, pinnedFilmstrip: false)
        near(fit.width, 972, "fitted viewport width")
        near(fit.height, 672, "fitted viewport height")
        let pinned = PreviewGeometry.usableRect(in: CGSize(width: 1000, height: 700),
                                                margin: 14, pinnedFilmstrip: true)
        near(pinned.height, 556, "pinned filmstrip reserved height")
        near(pinned.minY, 14, "fit inset top")
        let empty = PreviewGeometry.usableRect(in: .zero, margin: 14, pinnedFilmstrip: true)
        near(empty.width, 0, "zero-width preview")
        near(empty.height, 0, "zero-height preview")
        for width: CGFloat in [0, 1, 30, 130, 700, 2000] {
            for height: CGFloat in [0, 1, 80, 600, 1200] {
                for pinned in [false, true] {
                    let rect = PreviewGeometry.usableRect(in: CGSize(width: width, height: height),
                                                          margin: 14, pinnedFilmstrip: pinned)
                    precondition(rect.width >= 0 && rect.height >= 0)
                    precondition(rect.maxX <= width + 0.001 && rect.maxY <= height + 0.001)
                }
            }
        }
        print("PASS 66 PreviewGeometry assertions and 60 window-size combinations")
    }
}
