import AppKit

/// Native, accessible icon button with restrained hover and pressed feedback.
final class HoverIconButton: NSButton {
    private var tracking: NSTrackingArea?
    private var pointerInside = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        imagePosition = .imageOnly
        wantsLayer = true
        layer?.cornerRadius = 7
        focusRingType = .exterior
        contentTintColor = .secondaryLabelColor
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        if let tracking { addTrackingArea(tracking) }
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerInside = true
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.105).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        pointerInside = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1 : 0.4 }
    }

    func setSymbol(_ symbol: String, label: String) {
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image = icon?.withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        title = ""
        toolTip = label
        setAccessibilityLabel(label)
    }
}
