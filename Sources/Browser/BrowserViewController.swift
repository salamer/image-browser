import AppKit

final class BrowserViewController: NSViewController,
                                   NSSplitViewDelegate,
                                   NSOutlineViewDataSource,
                                   NSOutlineViewDelegate,
                                   NSCollectionViewDataSource,
                                   NSCollectionViewDelegate,
                                   NSSearchFieldDelegate {
    let rootFolder = FolderNode(url: FileManager.default.homeDirectoryForCurrentUser)
    var roots: [FolderNode] = []
    var currentFolder: URL?
    var allPhotos: [PhotoFile] = []
    var visiblePhotos: [PhotoFile] = []
    var selectedIndex = 0
    var activePhotoURL: URL?
    var previewRequestID = UUID()
    var previewHighQualityDisplayed = false
    var currentPreviewDecodePixels = 0
    var resizeDecodeWork: DispatchWorkItem?
    var thumbnailQualityWork: DispatchWorkItem?
    var scanningID = UUID()
    var scanningComplete = true
    var catalogRefreshWork: DispatchWorkItem?
    var lastCatalogRefresh = Date.distantPast
    var pendingScrollRestore: CGFloat?
    var rememberedScrollOffsets: [String: CGFloat] = [:]
    var isPreview = false
    var isComparing = false
    var thumbnailWidth: CGFloat = max(100, min(420, CGFloat(UserDefaults.standard.double(forKey: "ThumbnailWidth") == 0 ? 205 : UserDefaults.standard.double(forKey: "ThumbnailWidth"))))
    var recursive = false
    var minimumRating = 0
    var favoritesOnly = false
    var thumbnailPixels: Int { Int(ceil(thumbnailWidth * 2.2)) }
    var toolbarHeightConstraint: NSLayoutConstraint?
    var isFocusMode = false
    var focusRestoresSidebar = false
    var didPlaceSidebar = false
    var sidebarCollapsed = false
    var expandedSidebarWidth: CGFloat = 246
    let sidebarToggleButton = HoverIconButton()
    let toolbarLayoutButton = HoverIconButton()
    let toolbarMoreButton = HoverIconButton()
    let toolbarSearchButton = HoverIconButton()
    let toolbarBackButton = HoverIconButton()
    let toolbarForwardButton = HoverIconButton()
    let toolbarParentButton = HoverIconButton()

    let toolbar = BrowserToolbarView()
    let split = NSSplitView()
    let sidebar = SidebarExplorerView()
    let outline = FolderOutlineView()
    let rightPane = NSView()
    let contentHost = NSView()
    let gridScroll = NSScrollView()
    let grid = NSCollectionView()
    let gridLayout = MasonryLayout()
    let adaptivePreview = AdaptivePreviewView()
    let compareHost = CompareImageHost()
    var leftCompare: NSImageView { compareHost.left }
    var rightCompare: NSImageView { compareHost.right }
    let previewPanel = PreviewMousePanel()
    let filmstrip = PreviewFilmstripView()
    var filmstripPinned = false
    var filmstripVisible = false
    var filmstripHideWork: DispatchWorkItem?
    var hudBottomConstraint: NSLayoutConstraint?
    var hudWidthConstraint: NSLayoutConstraint?
    var suppressOutlineNavigation = false
    let previewCaption = NSVisualEffectView()
    let emptyState = BrowserEmptyStateView()
    var showOnboardingOnEmpty = false
    var scanCancellation: ScanCancellation?
    var folderBackStack: [URL] = []
    var folderForwardStack: [URL] = []
    var isHistoryNavigation = false
    let previewHUD = PreviewHUDView()
    let pathControl = NSPathControl()
    let previewTitle = NSTextField(labelWithString: "")
    let previewMeta = NSTextField(labelWithString: "")
    let statusLabel = NSTextField(labelWithString: "")
    let previewLabel = NSTextField(labelWithString: "")
    let zoomLabel = NSTextField(labelWithString: "适应")
    let search = NSSearchField()
    let sortMenu = NSPopUpButton()
    let gridSizeSlider = ThumbnailSizeSlider(value: 205, minValue: 100, maxValue: 420, target: nil, action: nil)
    let layoutMenu = NSPopUpButton()
    let ratingMenu = NSPopUpButton()
    let recursiveButton = NSButton(checkboxWithTitle: "含子目录", target: nil, action: nil)
    let favoriteOnlyButton = NSButton(checkboxWithTitle: "仅收藏", target: nil, action: nil)
    let backButton = NSButton()
    let compareButton = NSButton()
    let previousButton = NSButton()
    let nextButton = NSButton()

    var previewPixelSize: Int {
        let scale = view.window?.backingScaleFactor ?? 2
        let bounds = adaptivePreview.bounds
        return max(2048, min(8192, Int(max(bounds.width, bounds.height) * scale * 3)))
    }

    override func loadView() {
        let dropRoot = FolderDropView(frame: NSRect(x: 0, y: 0, width: 1380, height: 860))
        dropRoot.onFolderDrop = { [weak self] url in self?.openDroppedFolder(url) }
        view = dropRoot
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.115, alpha: 1).cgColor
        configureRootLayout()
        configureToolbar()
        configureSidebar()
        configureGrid()
        configurePreview()
        configureStatusBar()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !didPlaceSidebar, split.arrangedSubviews.count >= 2 {
            didPlaceSidebar = true
            expandedSidebarWidth = max(180, min(380, CGFloat(UserDefaults.standard.double(forKey: "ExplorerWidth") == 0 ? 246 : UserDefaults.standard.double(forKey: "ExplorerWidth"))))
            split.setPosition(expandedSidebarWidth, ofDividerAt: 0)
        }
        view.window?.acceptsMouseMovedEvents = true
        view.window?.makeFirstResponder(grid)
        for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                     NSWindow.didChangeBackingPropertiesNotification] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(windowResized(_:)),
            name: NSWindow.didResizeNotification, object: view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowResized(_:)),
            name: NSWindow.didEndLiveResizeNotification, object: view.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowResized(_:)),
            name: NSWindow.didChangeBackingPropertiesNotification, object: view.window)
        updateToolbarForWidth()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if isPreview { adaptivePreview.refreshViewport() }
        resizePreviewHUD()
        gridDidScrollOrResize()
    }

    @objc func windowResized(_ notification: Notification) {
        adaptivePreview.refreshViewport()
        gridDidScrollOrResize()
        updateToolbarForWidth()
        resizePreviewHUD()
        // Resize geometry immediately, but re-decode a larger source only after
        // the user stops dragging the window: prevents dozens of decode jobs.
        resizeDecodeWork?.cancel()
        guard isPreview, !isComparing else { return }
        let task = DispatchWorkItem { [weak self] in self?.upgradePreviewAfterResize() }
        resizeDecodeWork = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }

    func resizePreviewHUD() {
        // The preview panel owns all overlay frames. It safely accepts zero size
        // during window attachment and recomputes them on every resize pass.
        previewPanel.needsLayout = true
    }

    func upgradePreviewAfterResize() {
        guard isPreview, !isComparing, let photo = selectedPhoto(),
              activePhotoURL == photo.url else { return }
        let proposed = previewPixelSize
        guard proposed > Int(Double(currentPreviewDecodePixels) * 1.3),
              max(photo.pixelWidth, photo.pixelHeight) > currentPreviewDecodePixels else { return }
        currentPreviewDecodePixels = proposed
        let requestID = previewRequestID
        let size = NSSize(width: CGFloat(photo.pixelWidth), height: CGFloat(photo.pixelHeight))
        PreviewPipeline.shared.request(photo.url, maxPixelSize: proposed) { [weak self] image in
            guard let self, self.isPreview, !self.isComparing,
                  self.previewRequestID == requestID, self.activePhotoURL == photo.url,
                  let image else { return }
            self.previewHighQualityDisplayed = true
            self.adaptivePreview.display(image, pixelSize: size, resetFit: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let pictures = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)
        let preferred = UserDefaults.standard.string(forKey: "LastOpenedFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
        let defaultFolder = preferred.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ??
            (FileManager.default.fileExists(atPath: pictures.path) ? pictures : rootFolder.url)
        showOnboardingOnEmpty = preferred == nil
        roots = [FolderNode(url: defaultFolder)]
        outline.reloadData()
        if let first = roots.first {
            outline.expandItem(first)
            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        navigate(to: defaultFolder)

        // BrowserWindow.sendEvent owns keyboard routing. No global/local monitor:
        // dialogs, text input and other windows must retain native key events.
    }

    deinit {
        resizeDecodeWork?.cancel()
        thumbnailQualityWork?.cancel()
        catalogRefreshWork?.cancel()
        scanCancellation?.cancel()
        filmstripHideWork?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Window layout

}
