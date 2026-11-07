import Foundation

/// Pure geometry for the image viewport. No AppKit, scroll views or layout constraints.
/// Points are measured in a top-left-origin coordinate system.
struct PreviewGeometry {
    /// Returns an inset rectangle even when the host briefly has zero/non-finite
    /// size during resize. No negative or impossible frames are ever created.
    static func usableRect(in bounds: CGSize, margin: CGFloat, pinnedFilmstrip: Bool) -> CGRect {
        let width = bounds.width.isFinite ? max(0, bounds.width) : 0
        let height = bounds.height.isFinite ? max(0, bounds.height) : 0
        let m = min(max(0, margin), min(width, height) / 2)
        let extra = pinnedFilmstrip ? min(116, max(0, height - 2 * m)) : 0
        return CGRect(x: m, y: m, width: max(0, width - 2 * m),
                      height: max(0, height - 2 * m - extra))
    }
    static func fitZoom(viewport: CGSize, pixels: CGSize, backingScale: CGFloat) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0,
              pixels.width > 0, pixels.height > 0 else { return 1 }
        let backing = max(1, backingScale)
        return max(0.001, min(viewport.width / (pixels.width / backing),
                              viewport.height / (pixels.height / backing)))
    }

    static func imageExtent(pixels: CGSize, backingScale: CGFloat, zoom: CGFloat) -> CGSize {
        let backing = max(1, backingScale)
        let factor = max(0.01, zoom)
        return CGSize(width: max(1, pixels.width) / backing * factor,
                      height: max(1, pixels.height) / backing * factor)
    }

    static func clampPan(_ pan: CGPoint, viewport: CGSize, extent: CGSize) -> CGPoint {
        let xLimit = max(0, (extent.width - viewport.width) / 2)
        let yLimit = max(0, (extent.height - viewport.height) / 2)
        return CGPoint(x: max(-xLimit, min(xLimit, pan.x)),
                       y: max(-yLimit, min(yLimit, pan.y)))
    }

    static func imageRect(viewport: CGSize, pixels: CGSize, backingScale: CGFloat,
                          zoom: CGFloat, pan: CGPoint = .zero) -> CGRect {
        let extent = imageExtent(pixels: pixels, backingScale: backingScale, zoom: zoom)
        let clamped = clampPan(pan, viewport: viewport, extent: extent)
        return CGRect(x: (viewport.width - extent.width) / 2 + clamped.x,
                      y: (viewport.height - extent.height) / 2 + clamped.y,
                      width: extent.width, height: extent.height)
    }
}
