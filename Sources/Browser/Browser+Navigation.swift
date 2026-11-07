import AppKit

extension BrowserViewController {
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "打开"
        if let currentFolder { panel.directoryURL = currentFolder }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        showOnboardingOnEmpty = false
        roots = [FolderNode(url: url)]
        outline.reloadData()
        if let first = roots.first {
            outline.expandItem(first)
            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        navigate(to: url)
    }

    func openDroppedFolder(_ url: URL) {
        showOnboardingOnEmpty = false
        roots = [FolderNode(url: url)]
        outline.reloadData()
        if let first = roots.first {
            outline.expandItem(first)
            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        navigate(to: url)
    }

    func refreshCurrentFolder() {
        guard let currentFolder else { return }
        pendingScrollRestore = gridScroll.contentView.bounds.origin.y
        navigate(to: currentFolder, preservingScroll: true)
    }

    func navigate(to folder: URL, preservingScroll: Bool = false) {
        if !preservingScroll {
            if let previous = currentFolder, previous != folder, !isPreview {
                rememberedScrollOffsets[previous.path] = gridScroll.contentView.bounds.origin.y
            }
            pendingScrollRestore = rememberedScrollOffsets[folder.path]
        }
        if !isHistoryNavigation, let previous = currentFolder, previous != folder {
            folderBackStack.append(previous)
            if folderBackStack.count > 128 { folderBackStack.removeFirst() }
            folderForwardStack.removeAll()
        }
        currentFolder = folder
        synchronizeOutlineSelection(to: folder)
        UserDefaults.standard.set(folder.path, forKey: "LastOpenedFolder")
        pathControl.url = folder
        pathControl.toolTip = folder.path
        isPreview = false
        filmstripPinned = false
        hideFilmstrip()
        updateMode()
        scanCancellation?.cancel()
        catalogRefreshWork?.cancel()
        catalogRefreshWork = nil
        scanningID = UUID()
        scanningComplete = false
        let scanToken = scanningID
        ThumbnailPipeline.shared.cancelPending()
        PreviewPipeline.shared.cancelPending()
        allPhotos = []
        visiblePhotos = []
        activePhotoURL = nil
        gridLayout.photos = []
        grid.reloadData()
        if !preservingScroll {
            gridScroll.contentView.scroll(to: .zero)
            gridScroll.reflectScrolledClipView(gridScroll.contentView)
        }
        statusLabel.stringValue = "正在读取文件夹…  \(folder.path)"
        scanCancellation = PhotoScanner.scan(folder, recursive: recursive) { [weak self] photos, finished in
            guard let self, self.scanningID == scanToken else { return }
            self.scanningComplete = finished
            self.allPhotos.append(contentsOf: photos)
            self.scheduleCatalogRefresh(immediate: finished || self.allPhotos.count <= 128)
            if finished, let desiredY = self.pendingScrollRestore {
                self.pendingScrollRestore = nil
                self.grid.layoutSubtreeIfNeeded()
                self.gridScroll.contentView.scroll(to: NSPoint(x: 0, y: desiredY))
                self.gridScroll.reflectScrolledClipView(self.gridScroll.contentView)
            }
        }
    }

    func scheduleCatalogRefresh(immediate: Bool = false) {
        if immediate {
            catalogRefreshWork?.cancel()
            catalogRefreshWork = nil
            lastCatalogRefresh = Date()
            applySortAndFilter()
        } else if catalogRefreshWork == nil {
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.catalogRefreshWork = nil
                self.lastCatalogRefresh = Date()
                self.applySortAndFilter()
            }
            catalogRefreshWork = task
            let wait = max(0, 0.25 - Date().timeIntervalSince(lastCatalogRefresh))
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: task)
        }
    }

    func applySortAndFilter() {
        let previous = isPreview ? activePhotoURL :
            grid.selectionIndexPaths.first.flatMap { visiblePhotos.indices.contains($0.item) ? visiblePhotos[$0.item].url : nil }
        let sortOrder = BrowserSort(rawValue: sortMenu.indexOfSelectedItem) ?? .nameAscending
        let filter = BrowserFilter(text: search.stringValue, minRating: minimumRating, favoritesOnly: favoritesOnly)
        allPhotos = BrowserQuery.sort(allPhotos, by: sortOrder)
        visiblePhotos = BrowserQuery.filter(allPhotos, using: filter) { url in
            let annotation = PhotoAnnotations.shared.annotation(for: url)
            return (annotation.rating, annotation.favorite)
        }
        gridLayout.photos = visiblePhotos
        grid.reloadData()
        emptyState.isHidden = isPreview || !visiblePhotos.isEmpty
        if !scanningComplete {
            emptyState.configure(.loading)
        } else if allPhotos.isEmpty {
            emptyState.configure(showOnboardingOnEmpty ? .welcome : .emptyFolder)
        } else {
            emptyState.configure(.noResults)
        }
        if let previous, let i = visiblePhotos.firstIndex(where: { $0.url == previous }) {
            selectedIndex = i
            grid.selectionIndexPaths = [IndexPath(item: i, section: 0)]
        } else {
            selectedIndex = 0
            if isPreview { backToGrid() }
        }
        updateStatus()
    }

    func updateStatus() {
        let selected = isPreview ? selectedIndex : grid.selectionIndexPaths.first?.item
        let photo = selected.flatMap { visiblePhotos.indices.contains($0) ? visiblePhotos[$0] : nil }
        let count = favoritesOnly || minimumRating > 0 || !search.stringValue.isEmpty
            ? "筛选 \(visiblePhotos.count) / \(allPhotos.count) 张" : "\(visiblePhotos.count) 张图片"
        let prefix = scanningComplete ? count : count + " · 正在扫描…"
        if !isPreview && grid.selectionIndexPaths.count > 1 {
            statusLabel.stringValue = "\(prefix)   ·   已选 \(grid.selectionIndexPaths.count) 张   ·   ⌘C 复制 · ⌘D 比较"
        } else if let photo {
            let annotation = PhotoAnnotations.shared.annotation(for: photo.url)
            let stars = annotation.rating > 0 ? "  ·  \(annotation.rating) ★" : ""
            statusLabel.stringValue = "\(prefix)   ·   \(photo.name)   ·   \(photo.dimensions)   ·   \(photo.subtitle)\(stars)"
        } else { statusLabel.stringValue = prefix + "   ·   空格预览 · 1–5 评分 · F 收藏" }
        backButton.isEnabled = isPreview
        compareButton.isEnabled = !isPreview && grid.selectionIndexPaths.count == 2
    }

    // MARK: Browser interactions


    func synchronizeOutlineSelection(to folder: URL) {
        guard !suppressOutlineNavigation else { return }
        suppressOutlineNavigation = true
        defer { suppressOutlineNavigation = false }
        // Preserve all workspace roots instead of replacing the entire Explorer.
        if !roots.contains(where: { folder == $0.url || folder.path.hasPrefix($0.url.path + "/") }) {
            roots.append(FolderNode(url: folder))
            outline.reloadData()
        }
        guard let root = roots.filter({ folder == $0.url || folder.path.hasPrefix($0.url.path + "/") })
                .max(by: { $0.url.path.count < $1.url.path.count }) else { return }
        var node = root
        outline.expandItem(node)
        if folder != root.url {
            let relative = String(folder.path.dropFirst(root.url.path.count))
            for component in relative.split(separator: "/") {
                guard let next = node.loadChildren().first(where: { $0.title == String(component) }) else { break }
                node = next
                outline.expandItem(node)
            }
        }
        let targetRow = outline.row(forItem: node)
        if targetRow >= 0 {
            outline.selectRowIndexes(IndexSet(integer: targetRow), byExtendingSelection: false)
            outline.scrollRowToVisible(targetRow)
        }
    }

    func clearFilters() {
        search.stringValue = ""
        minimumRating = 0
        favoritesOnly = false
        ratingMenu.selectItem(at: 0)
        favoriteOnlyButton.state = .off
        applySortAndFilter()
    }

    func navigateBack() {
        guard let target = folderBackStack.popLast() else { NSSound.beep(); return }
        if let currentFolder { folderForwardStack.append(currentFolder) }
        isHistoryNavigation = true
        navigate(to: target)
        isHistoryNavigation = false
    }

    func navigateForward() {
        guard let target = folderForwardStack.popLast() else { NSSound.beep(); return }
        if let currentFolder { folderBackStack.append(currentFolder) }
        isHistoryNavigation = true
        navigate(to: target)
        isHistoryNavigation = false
    }

    func navigateParent() {
        guard let currentFolder else { return }
        let parent = currentFolder.deletingLastPathComponent()
        if parent != currentFolder { navigate(to: parent) }
    }
}
