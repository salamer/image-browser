import AppKit

extension BrowserViewController {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? FolderNode else { return roots.count }
        return node.loadChildren().count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? FolderNode { return node.loadChildren()[index] }
        return roots[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // Avoid scanning every directory just to draw the disclosure chevron.
        return true
    }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FolderNode else { return nil }
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let existing = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let icon = NSImageView()
            icon.imageScaling = .scaleProportionallyDown
            icon.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(icon)
            cell.imageView = icon
            let text = NSTextField(labelWithString: "")
            text.font = .systemFont(ofSize: 12)
            text.lineBreakMode = .byTruncatingTail
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            cell.textField = text
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 17),
                icon.heightAnchor.constraint(equalToConstant: 17),
                text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = node.title
        cell.textField?.font = .systemFont(ofSize: 12, weight: roots.contains { $0.url == node.url } ? .medium : .regular)
        cell.toolTip = node.url.path
        cell.imageView?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "文件夹")
        cell.imageView?.contentTintColor = NSColor.systemBlue
        return cell
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressOutlineNavigation, !outline.isSelectingContextItem else { return }
        let row = outline.selectedRow
        guard row >= 0, let node = outline.item(atRow: row) as? FolderNode else { return }
        if node.url != currentFolder { navigate(to: node.url) }
    }

    // MARK: Photo grid

    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        visiblePhotos.count
    }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("PhotoTile"), for: indexPath
        ) as! PhotoTileItem
        let photo = visiblePhotos[indexPath.item]
        item.configure(photo: photo, index: indexPath.item, pixelSize: thumbnailPixels,
                       onOpen: { [weak self] photo in
            guard let self, let index = self.visiblePhotos.firstIndex(where: { $0.url == photo.url }) else { return }
            self.openPreview(at: index)
        }, onFavorite: { [weak self] photo in self?.toggleFavorite(photo) },
                       onContextMenu: { [weak self] photo in self?.makeFileMenu(for: photo) })
        return item
    }
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let index = indexPaths.first?.item { selectedIndex = index }
        updateStatus()
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview === sidebar
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        sidebar.needsLayout = true
        gridDidScrollOrResize()
        if isPreview { adaptivePreview.refreshViewport(); resizePreviewHUD() }
        if !sidebarCollapsed && sidebar.frame.width > 130 {
            expandedSidebarWidth = sidebar.frame.width
            UserDefaults.standard.set(Double(expandedSidebarWidth), forKey: "ExplorerWidth")
        }
    }

    // MARK: Split view

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        sidebarCollapsed || splitView.bounds.width < 480 ? 0 : 175
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        sidebarCollapsed ? 0 : max(0, min(390, splitView.bounds.width - 280))
    }
}
