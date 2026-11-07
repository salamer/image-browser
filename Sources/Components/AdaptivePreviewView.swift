import AppKit

/// Single, resize-driven image surface.
/// No NSScrollView document sizing, nested autoresizing or image constraints:
/// the image rect is derived from the CURRENT viewport on every draw pass.
/// This makes Fit deterministic even during live window and sidebar resizing.
final class AdaptivePreviewView: NSView {
    private var renderedImage: NSImage?
    private var sourcePixels = NSSize.zero
    private var isAutoFit = true
    private var pan = CGPoint.zero
    var pinnedFilmstrip = false { didSet { if pinnedFilmstrip != oldValue { refreshViewport() } } }
    private var lastDragPoint: CGPoint?
    private(set) var zoom: CGFloat = 1
    var onZoomChanged: ((CGFloat, Bool) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1).cgColor
        layer?.needsDisplayOnBoundsChange = true
        toolTip = "双击：适应窗口 / 100% · 拖动：平移放大的图片 · ⌥滚轮：缩放"
        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(pinchZoom(_:)))
        addGestureRecognizer(pinch)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    func setContextMenu(_ menu: NSMenu?) { self.menu = menu }
    var hasImage: Bool { renderedImage != nil }
    var fitted: Bool { isAutoFit }

    func display(_ image: NSImage?, pixelSize: NSSize, resetFit: Bool) {
        renderedImage = image
        sourcePixels = pixelSize.width > 0 && pixelSize.height > 0 ? pixelSize : (image?.size ?? .zero)
        if resetFit { isAutoFit = true; pan = .zero }
        refreshViewport()
    }

    func clear() {
        renderedImage = nil
        sourcePixels = .zero
        isAutoFit = true
        pan = .zero
        zoom = 1
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(frame.width - newSize.width) > 0.5 || abs(frame.height - newSize.height) > 0.5
        super.setFrameSize(newSize)
        if changed { refreshViewport() }
    }

    override func layout() {
        super.layout()
        refreshViewport()
    }

    private func usableViewport() -> CGRect {
        PreviewGeometry.usableRect(in: bounds.size, margin: 14,
                                   pinnedFilmstrip: pinnedFilmstrip)
    }

    func refreshViewport() {
        let usable = usableViewport()
        guard hasImage, usable.width > 1, usable.height > 1 else { needsDisplay = true; return }
        let old = zoom
        if isAutoFit {
            zoom = PreviewGeometry.fitZoom(viewport: usable.size, pixels: sourcePixels,
                                           backingScale: window?.backingScaleFactor ?? 2)
            pan = .zero
        } else {
            let size = PreviewGeometry.imageExtent(pixels: sourcePixels,
                  backingScale: window?.backingScaleFactor ?? 2, zoom: zoom)
            pan = PreviewGeometry.clampPan(pan, viewport: bounds.size, extent: size)
        }
        needsDisplay = true
        if abs(old - zoom) > 0.0001 { onZoomChanged?(zoom, isAutoFit) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
        NSBezierPath(rect: dirtyRect).fill()
        guard let renderedImage, sourcePixels.width > 0, sourcePixels.height > 0 else { return }
        let usable = usableViewport()
        guard usable.width > 0, usable.height > 0 else { return }
        let scale = isAutoFit
            ? PreviewGeometry.fitZoom(viewport: usable.size, pixels: sourcePixels,
                                      backingScale: window?.backingScaleFactor ?? 2)
            : zoom
        // Manual mode keeps its pan relative to the complete viewport.
        // Fit mode accounts for space taken by a permanently pinned filmstrip.
        var rect = PreviewGeometry.imageRect(viewport: isAutoFit ? usable.size : bounds.size,
                    pixels: sourcePixels, backingScale: window?.backingScaleFactor ?? 2,
                    zoom: scale, pan: pan)
        if isAutoFit {
            rect.origin.x += usable.minX
            rect.origin.y += usable.minY
        }
        // A subtle image edge improves legibility on black without changing pixels.
        if isAutoFit {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 13
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
            shadow.set()
            NSColor(white: 0, alpha: 0.4).setFill()
            NSBezierPath(rect: rect).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.current?.imageInterpolation = .high
        renderedImage.draw(in: rect, from: .zero, operation: .sourceOver,
                           fraction: 1, respectFlipped: true, hints: nil)
    }

    func fit() { isAutoFit = true; pan = .zero; refreshViewport(); onZoomChanged?(zoom, true) }
    func actualSize() { setZoom(1) }
    func toggleFitActualSize() { if isAutoFit { actualSize() } else { fit() } }
    func setZoom(_ value: CGFloat) {
        guard hasImage else { return }
        isAutoFit = false
        zoom = min(16, max(0.02, value))
        refreshViewport()
        onZoomChanged?(zoom, false)
    }
    func adjustZoom(_ multiplier: CGFloat) { setZoom(zoom * multiplier) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount >= 2 {
            toggleFitActualSize()
            lastDragPoint = nil
        } else {
            lastDragPoint = convert(event.locationInWindow, from: nil)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard !isAutoFit, let old = lastDragPoint else { return }
        let now = convert(event.locationInWindow, from: nil)
        pan.x += now.x - old.x
        pan.y += now.y - old.y
        lastDragPoint = now
        refreshViewport()
    }
    override func mouseUp(with event: NSEvent) { lastDragPoint = nil }

    override func scrollWheel(with event: NSEvent) {
        guard hasImage else { return }
        if event.modifierFlags.contains(.option) {
            setZoom(zoom * CGFloat(exp(Double(-event.scrollingDeltaY) * 0.018)))
        } else if !isAutoFit {
            pan.x -= event.scrollingDeltaX
            pan.y -= event.scrollingDeltaY
            refreshViewport()
        } else { super.scrollWheel(with: event) }
    }

    @objc private func pinchZoom(_ recognizer: NSMagnificationGestureRecognizer) {
        guard hasImage, recognizer.state == .changed else { return }
        setZoom(zoom * max(0.1, 1 + recognizer.magnification))
        recognizer.magnification = 0
    }
}
