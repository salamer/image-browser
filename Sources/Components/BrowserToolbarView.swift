import AppKit

/// A single-row, viewport-aware toolbar. Secondary actions move to an overflow
/// menu rather than making a second row or adding unsatisfiable constraints.
final class BrowserToolbarView: NSVisualEffectView {
    private weak var sidebarButton: NSButton?
    private weak var backButton: NSButton?
    private weak var forwardButton: NSButton?
    private weak var parentButton: NSButton?
    private weak var breadcrumb: NSPathControl?
    private weak var searchField: NSSearchField?
    private weak var searchButton: NSButton?
    private weak var layoutButton: NSButton?
    private weak var sortButton: NSPopUpButton?
    private weak var moreButton: NSButton?
    private weak var thumbnailSlider: NSSlider?
    var showsThumbnailSlider = true { didSet { needsLayout = true } }

    func configure(sidebar: NSButton, back: NSButton, forward: NSButton, parent: NSButton,
                   path: NSPathControl, search: NSSearchField, compactSearch: NSButton,
                   layout: NSButton, sort: NSPopUpButton,
                   thumbnailSize: NSSlider, more: NSButton) {
        [sidebar, back, forward, parent, path, search, compactSearch, layout, sort, thumbnailSize, more].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = true
            addSubview($0)
        }
        sidebarButton = sidebar
        backButton = back
        forwardButton = forward
        parentButton = parent
        breadcrumb = path
        searchField = search
        searchButton = compactSearch
        layoutButton = layout
        sortButton = sort
        moreButton = more
        thumbnailSlider = thumbnailSize
        material = .headerView
        blendingMode = .withinWindow
        needsLayout = true
    }

    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Standard macOS Zoom toggles the visible-screen maximum and the
        // previous size; it does not enter Space-style fullscreen.
        if event.clickCount == 2 {
            window?.zoom(nil)
            return
        }
        window?.performDrag(with: event)
    }

    override func layout() {
        super.layout()
        let w = max(0, bounds.width)
        let h: CGFloat = min(30, max(0, bounds.height))
        let y = max(0, (bounds.height - h) / 2)
        let gap: CGFloat = 5
        var x: CGFloat = 92 // Native macOS traffic-light controls occupy this area.

        func place(_ control: NSView?, width: CGFloat, when eligible: Bool) {
            guard let control else { return }
            // Keep room for the right-side overflow control; narrow windows
            // hide buttons instead of overlapping the titlebar and path bar.
            guard eligible && x + width + 65 < w else {
                control.isHidden = true
                return
            }
            control.isHidden = false
            control.frame = NSRect(x: x, y: y, width: width, height: h)
            x += width + gap
        }
        place(sidebarButton, width: 34, when: w >= 170)
        place(backButton, width: 28, when: w >= 430)
        place(forwardButton, width: 28, when: w >= 520)
        place(parentButton, width: 28, when: w >= 1050)

        var right = max(0, w - 11)
        @discardableResult
        func placeRight(_ control: NSView?, width: CGFloat, when eligible: Bool = true) -> Bool {
            guard let control else { return false }
            guard eligible && right - width >= x + 10 else {
                control.isHidden = true
                return false
            }
            right -= width
            control.isHidden = false
            control.frame = NSRect(x: right, y: y, width: width, height: h)
            right -= gap
            return true
        }
        placeRight(moreButton, width: 32, when: w >= 270)
        // Keep the live size scrubber at the right on normal laptop windows;
        // smaller windows prioritize image and breadcrumb space.
        placeRight(thumbnailSlider, width: w >= 1400 ? 122 : 98, when: showsThumbnailSlider && w >= 940)
        placeRight(layoutButton, width: 32, when: w >= 650)
        placeRight(sortButton, width: 112, when: w >= 1260)
        if w >= 800 {
            searchButton?.isHidden = true
            let searchWidth: CGFloat = w >= 1200 ? 226 : 158
            if !placeRight(searchField, width: searchWidth) {
                placeRight(searchButton, width: 32)
            }
        } else {
            searchField?.isHidden = true
            placeRight(searchButton, width: 32, when: w >= 390)
        }
        let available = max(0, right - x)
        let showPath = available >= 64
        breadcrumb?.isHidden = !showPath
        if showPath {
            breadcrumb?.frame = NSRect(x: x + 4, y: y, width: max(0, available - 8), height: h)
        }
    }
}
