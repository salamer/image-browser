import AppKit

/// Reports the mouse position in the preview surface even when its child views
/// (image, HUD, filmstrip) receive the actual mouse events.
final class PreviewMousePanel: NSView {
    var onMouseLocation: ((NSPoint?) -> Void)?
    weak var overlayHUD: NSView?
    weak var overlayFilmstrip: NSView?
    weak var overlayCaption: NSView?
    weak var captionTitle: NSView?
    weak var captionMeta: NSView?
    var showsFilmstrip = false { didSet { needsLayout = true } }
    private var tracking: NSTrackingArea?

    override func layout() {
        super.layout()
        let frames = ChromeGeometry.preview(bounds.size, showFilmstrip: showsFilmstrip)
        overlayHUD?.frame = frames.hud
        overlayFilmstrip?.frame = frames.filmstrip
        overlayCaption?.frame = frames.caption
        let labelWidth = max(0, frames.caption.width - 24)
        let labelHeight = min(17, frames.caption.height / 2)
        captionTitle?.frame = NSRect(x: 12, y: max(0, frames.caption.height - 26),
                                     width: labelWidth, height: labelHeight)
        captionMeta?.frame = NSRect(x: 12, y: 8, width: labelWidth, height: labelHeight)
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        if let tracking { addTrackingArea(tracking) }
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) { report(event) }
    override func mouseEntered(with event: NSEvent) { report(event) }
    override func mouseExited(with event: NSEvent) { onMouseLocation?(nil) }
    private func report(_ event: NSEvent) {
        onMouseLocation?(convert(event.locationInWindow, from: nil))
    }
}

/// A lightweight, reused, horizontally scrolling filmstrip item.
/// Loads only a thumbnail, never a full-resolution preview.
private final class FilmstripTileView: NSView {
    let image = NSImageView()
    let caption = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor(white: 0.13, alpha: 0.75).cgColor
        image.imageScaling = .scaleProportionallyUpOrDown
        image.wantsLayer = true
        image.layer?.cornerRadius = 4
        image.layer?.masksToBounds = true
        caption.alignment = .center
        caption.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        caption.textColor = .secondaryLabelColor
        addSubview(image)
        addSubview(caption)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    override func layout() {
        super.layout()
        image.frame = NSRect(x: 5, y: 21, width: max(1, bounds.width - 10), height: max(1, bounds.height - 26))
        caption.frame = NSRect(x: 2, y: 3, width: max(1, bounds.width - 4), height: 15)
    }

    func highlight(_ active: Bool) {
        layer?.borderWidth = active ? 2 : 0
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        caption.textColor = active ? .labelColor : .secondaryLabelColor
    }
}

private final class FilmstripTileItem: NSCollectionViewItem {
    private var request: Operation?
    private var requestID = UUID()
    private var photoURL: URL?
    private var tile: FilmstripTileView { view as! FilmstripTileView }

    override func loadView() {
        view = FilmstripTileView(frame: NSRect(x: 0, y: 0, width: 100, height: 93))
    }

    override var isSelected: Bool {
        didSet { if isViewLoaded { tile.highlight(isSelected) } }
    }

    func configure(_ photo: PhotoFile, number: Int) {
        request?.cancel()
        requestID = UUID()
        let expectedID = requestID
        photoURL = photo.url
        tile.image.image = nil
        tile.caption.stringValue = String(number)
        tile.toolTip = "\(number) · \(photo.name)"
        tile.highlight(isSelected)
        request = ThumbnailPipeline.shared.request(photo, pixelSize: 230) { [weak self] image in
            guard let self, self.requestID == expectedID, self.photoURL == photo.url else { return }
            self.tile.image.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        request?.cancel()
        request = nil
        requestID = UUID()
        photoURL = nil
        tile.image.image = nil
    }
}

/// Bottom overlay (no permanent loss of image viewport height).
/// Only keeps a small window around the selected file to remain responsive
/// with directories containing thousands of photos.
final class PreviewFilmstripView: NSVisualEffectView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private struct Entry { let absoluteIndex: Int; let photo: PhotoFile }
    private let scroll = NSScrollView()
    private let collection = NSCollectionView()
    private let flow = NSCollectionViewFlowLayout()
    private var entries: [Entry] = []
    private var activeIndex = -1
    var onSelect: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        flow.scrollDirection = .horizontal
        flow.itemSize = NSSize(width: 102, height: 93)
        flow.minimumInteritemSpacing = 8
        flow.minimumLineSpacing = 8
        flow.sectionInset = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        collection.collectionViewLayout = flow
        collection.dataSource = self
        collection.delegate = self
        collection.isSelectable = true
        collection.allowsMultipleSelection = false
        collection.backgroundColors = [.clear]
        collection.register(FilmstripTileItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("FilmstripTile"))
        collection.frame = NSRect(x: 0, y: 0, width: 1100, height: 109)
        collection.autoresizingMask = [.height]

        scroll.documentView = collection
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = true
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    override func layout() {
        super.layout()
        scroll.frame = bounds
    }

    func setSelection(photos: [PhotoFile], current: Int) {
        guard photos.indices.contains(current) else {
            entries = []
            activeIndex = -1
            collection.reloadData()
            return
        }
        activeIndex = current
        // Prefetch/cell cost is bounded even with >100k files.
        let lower = max(0, current - 15)
        let upper = min(photos.count, current + 16)
        entries = (lower..<upper).map { Entry(absoluteIndex: $0, photo: photos[$0]) }
        collection.reloadData()
        let localIndex = current - lower
        collection.selectItems(at: [IndexPath(item: localIndex, section: 0)], scrollPosition: [])
        DispatchQueue.main.async { [weak self] in
            guard let self, self.activeIndex == current, !self.isHidden else { return }
            self.collection.scrollToItems(at: [IndexPath(item: localIndex, section: 0)], scrollPosition: .centeredHorizontally)
        }
    }

    func centerCurrent() {
        guard let local = entries.firstIndex(where: { $0.absoluteIndex == activeIndex }) else { return }
        collection.scrollToItems(at: [IndexPath(item: local, section: 0)], scrollPosition: .centeredHorizontally)
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { entries.count }
    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("FilmstripTile"),
                                           for: indexPath) as! FilmstripTileItem
        let entry = entries[indexPath.item]
        item.configure(entry.photo, number: entry.absoluteIndex + 1)
        return item
    }
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let index = indexPaths.first?.item, entries.indices.contains(index) else { return }
        let target = entries[index].absoluteIndex
        if target != activeIndex { onSelect?(target) }
    }
}
