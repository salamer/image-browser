import AppKit

final class PhotoTileView: NSView {
    let imageView = NSImageView()
    let nameLabel = NSTextField(labelWithString: "")
    let detailLabel = NSTextField(labelWithString: "")
    let indexBadge = NSTextField(labelWithString: "")
    let favoriteButton = NSButton()
    let ratingLabel = NSTextField(labelWithString: "")
    var contextMenuProvider: (() -> NSMenu?)?
    private var hovered = false
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = NSColor(calibratedWhite: 0.145, alpha: 1).cgColor
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = NSSize(width: 0, height: -3)
        layer?.shadowRadius = 9
        layer?.shadowOpacity = 0

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor(calibratedWhite: 0.115, alpha: 1).cgColor
        imageView.layer?.cornerRadius = 7
        imageView.layer?.masksToBounds = true
        nameLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.textColor = .labelColor
        detailLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        indexBadge.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        indexBadge.textColor = .white
        indexBadge.alignment = .center
        indexBadge.wantsLayer = true
        indexBadge.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.67).cgColor
        indexBadge.layer?.cornerRadius = 4
        favoriteButton.isBordered = false
        favoriteButton.imagePosition = .imageOnly
        favoriteButton.imageScaling = .scaleProportionallyDown
        favoriteButton.toolTip = "收藏 / 取消收藏 (F)"
        favoriteButton.contentTintColor = .white
        ratingLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        ratingLabel.textColor = NSColor(calibratedRed: 1, green: 0.76, blue: 0.25, alpha: 1)
        ratingLabel.alignment = .right
        addSubview(imageView)
        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(indexBadge)
        addSubview(favoriteButton)
        addSubview(ratingLabel)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    // Keep hit-testing on the tile so selection, double click and the context menu
    // work equally well on images, text, and empty padding.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        return hit === favoriteButton ? hit : self
    }

    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        if let tracking { addTrackingArea(tracking) }
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) {
        hovered = true
        layer?.shadowOpacity = 0.26
        refreshOverlay()
    }
    override func mouseExited(with event: NSEvent) {
        hovered = false
        layer?.shadowOpacity = 0
        refreshOverlay()
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        imageView.frame = NSRect(x: 3, y: 41, width: max(1, width - 6), height: max(1, height - 44))
        nameLabel.frame = NSRect(x: 7, y: 22, width: max(1, width - 14), height: 16)
        detailLabel.frame = NSRect(x: 7, y: 5, width: max(1, width - 14), height: 13)
        indexBadge.frame = NSRect(x: 9, y: height - 27, width: 33, height: 18)
        favoriteButton.frame = NSRect(x: width - 35, y: height - 34, width: 29, height: 29)
        ratingLabel.frame = NSRect(x: max(40, width - 94), y: 2, width: 85, height: 13)
    }

    func setSelected(_ selected: Bool) {
        layer?.borderWidth = selected ? 2 : 0
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = selected
            ? NSColor(calibratedWhite: 0.205, alpha: 1).cgColor
            : NSColor(calibratedWhite: 0.145, alpha: 1).cgColor
    }

    func refreshOverlay() { favoriteButton.alphaValue = hovered || isFavorite ? 1.0 : 0.62 }
    private var isFavorite = false
    func updateAnnotation(_ annotation: PhotoAnnotation) {
        isFavorite = annotation.favorite
        favoriteButton.image = NSImage(systemSymbolName: annotation.favorite ? "heart.fill" : "heart",
                                       accessibilityDescription: "收藏")
        favoriteButton.contentTintColor = annotation.favorite ? NSColor.systemPink : .white
        ratingLabel.stringValue = annotation.rating > 0 ? String(repeating: "★", count: annotation.rating) : ""
        refreshOverlay()
    }
}

final class PhotoTileItem: NSCollectionViewItem {
    var representedPhoto: PhotoFile?
    var openPhoto: ((PhotoFile) -> Void)?
    var onFavorite: ((PhotoFile) -> Void)?
    var onContextMenu: ((PhotoFile) -> NSMenu?)?
    private var pixelSize = 400
    private var thumbnailOperation: Operation?
    private var requestID = UUID()
    private var tile: PhotoTileView { view as! PhotoTileView }

    override func loadView() {
        view = PhotoTileView(frame: NSRect(x: 0, y: 0, width: 205, height: 220))
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        click.numberOfClicksRequired = 2
        view.addGestureRecognizer(click)
        tile.favoriteButton.target = self
        tile.favoriteButton.action = #selector(toggleFavorite)
        tile.contextMenuProvider = { [weak self] in
            guard let self, let photo = self.representedPhoto else { return nil }
            return self.onContextMenu?(photo)
        }
    }

    override var isSelected: Bool {
        didSet { if isViewLoaded { tile.setSelected(isSelected) } }
    }

    func configure(photo: PhotoFile, index: Int, pixelSize: Int,
                   onOpen: @escaping (PhotoFile) -> Void,
                   onFavorite: @escaping (PhotoFile) -> Void,
                   onContextMenu: @escaping (PhotoFile) -> NSMenu?) {
        thumbnailOperation?.cancel()
        requestID = UUID()
        let capturedRequest = requestID
        representedPhoto = photo
        openPhoto = onOpen
        self.onFavorite = onFavorite
        self.onContextMenu = onContextMenu
        self.pixelSize = pixelSize
        tile.indexBadge.stringValue = String(index + 1)
        tile.toolTip = photo.name + "\n" + photo.dimensions + " · " + photo.subtitle
        tile.nameLabel.stringValue = photo.name
        tile.detailLabel.stringValue = "\(photo.dimensions)  ·  \(photo.subtitle)"
        tile.imageView.image = nil
        tile.updateAnnotation(PhotoAnnotations.shared.annotation(for: photo.url))
        tile.setSelected(isSelected)
        thumbnailOperation = ThumbnailPipeline.shared.request(photo, pixelSize: pixelSize) { [weak self] image in
            guard let self, self.representedPhoto?.url == photo.url,
                  self.pixelSize == pixelSize, self.requestID == capturedRequest else { return }
            self.tile.imageView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailOperation?.cancel()
        thumbnailOperation = nil
        requestID = UUID()
        representedPhoto = nil
        openPhoto = nil
        onFavorite = nil
        onContextMenu = nil
        tile.imageView.image = nil
    }

    func refreshAnnotation() {
        guard let photo = representedPhoto else { return }
        tile.updateAnnotation(PhotoAnnotations.shared.annotation(for: photo.url))
    }

    @objc private func handleDoubleClick() {
        guard let representedPhoto else { return }
        openPhoto?(representedPhoto)
    }
    @objc private func toggleFavorite() {
        guard let representedPhoto else { return }
        onFavorite?(representedPhoto)
    }
}
