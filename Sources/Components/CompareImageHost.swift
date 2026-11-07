import AppKit

/// Two comparison images without required width constraints. A split layout can
/// briefly report zero width during first attachment, hiding or sidebar resize.
final class CompareImageHost: NSView {
    let left = NSImageView()
    let right = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for image in [left, right] {
            image.imageScaling = .scaleProportionallyUpOrDown
            image.wantsLayer = true
            image.layer?.backgroundColor = NSColor(calibratedWhite: 0.095, alpha: 1).cgColor
            addSubview(image)
        }
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    override func layout() {
        super.layout()
        let frames = ChromeGeometry.preview(bounds.size, showFilmstrip: false)
        left.frame = frames.leftCompare
        right.frame = frames.rightCompare
    }
}
