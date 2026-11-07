import AppKit

extension BrowserViewController {
    @objc func historyBackAction() { navigateBack() }
    @objc func historyForwardAction() { navigateForward() }
    @objc func historyParentAction() { navigateParent() }
    @objc func openFolderAction() { openFolder() }
    @objc func refreshAction() { refreshCurrentFolder() }
    @objc func backToGridAction() { backToGrid() }
    @objc func previousAction() { movePhoto(-1) }
    @objc func nextAction() { movePhoto(1) }
    @objc func zoomOutAction() { adjustZoom(multiplier: 0.8) }
    @objc func zoomInAction() { adjustZoom(multiplier: 1.25) }
    @objc func fitAction() { fitPreview() }
    @objc func compareAction() { compareSelected() }
    func compareSelected() {
        guard !isPreview else { return }
        let selection = grid.selectionIndexPaths.map(\.item).sorted()
        guard selection.count == 2,
              selection.allSatisfy({ visiblePhotos.indices.contains($0) }) else {
            NSSound.beep()
            return
        }
        let a = visiblePhotos[selection[0]]
        let b = visiblePhotos[selection[1]]
        isPreview = true
        isComparing = true
        activePhotoURL = nil
        pathControl.url = currentFolder
        leftCompare.image = nil
        rightCompare.image = nil
        PreviewPipeline.shared.cancelPending()
        updateMode()
        statusLabel.stringValue = "图片比较  ·  \(a.name)   VS   \(b.name)   ·   Esc 返回"
        let pixelSize = max(2048, previewPixelSize / 2)
        PreviewPipeline.shared.request(a.url, maxPixelSize: pixelSize) { [weak self] image in
            guard let self, self.isComparing else { return }
            self.leftCompare.image = image
        }
        PreviewPipeline.shared.request(b.url, maxPixelSize: pixelSize) { [weak self] image in
            guard let self, self.isComparing else { return }
            self.rightCompare.image = image
        }
    }

    func setRatingFromMenu(_ rating: Int) { setSelectedRating(rating) }
    func toggleFavoriteFromMenu() { toggleSelectedFavorite() }

    @objc func gridSizeChanged() {
        let newWidth = max(100, min(420, CGFloat(gridSizeSlider.doubleValue)))
        guard abs(thumbnailWidth - newWidth) >= 0.5 else { return }
        thumbnailWidth = newWidth
        gridLayout.targetWidth = thumbnailWidth // invalidates layout, preserves scroll
        UserDefaults.standard.set(Double(thumbnailWidth), forKey: "ThumbnailWidth")
        // Wait until the scrub pauses before refreshing decode resolution.
        // Rebuilding every cell on each mouse-drag event creates flicker.
        thumbnailQualityWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isPreview else { return }
            let visible = self.grid.indexPathsForVisibleItems().filter { $0.item < self.visiblePhotos.count }
            if !visible.isEmpty { self.grid.reloadItems(at: Set(visible)) }
        }
        thumbnailQualityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }
    @objc func layoutChanged() {
        gridLayout.mode = layoutMenu.indexOfSelectedItem == 0 ? .waterfall : .regular
        grid.reloadData()
    }
    @objc func ratingFilterChanged() {
        minimumRating = ratingMenu.indexOfSelectedItem
        applySortAndFilter()
    }
    @objc func favoriteFilterChanged() {
        favoritesOnly = favoriteOnlyButton.state == .on
        applySortAndFilter()
    }
    @objc func recursiveChanged() {
        recursive = recursiveButton.state == .on
        refreshCurrentFolder()
    }

    func selectedPhoto() -> PhotoFile? {
        let index = isPreview ? selectedIndex : (grid.selectionIndexPaths.map(\.item).min() ?? selectedIndex)
        return visiblePhotos.indices.contains(index) ? visiblePhotos[index] : nil
    }
    func setSelectedRating(_ rating: Int) {
        guard let photo = selectedPhoto() else { return }
        PhotoAnnotations.shared.setRating(rating, for: photo.url)
        refreshAnnotationUI(for: photo)
    }
    func toggleSelectedFavorite() {
        guard let photo = selectedPhoto() else { return }
        toggleFavorite(photo)
    }
    func toggleFavorite(_ photo: PhotoFile) {
        PhotoAnnotations.shared.toggleFavorite(for: photo.url)
        refreshAnnotationUI(for: photo)
    }
    func refreshAnnotationUI(for photo: PhotoFile) {
        if favoritesOnly || minimumRating > 0 { applySortAndFilter() }
        else {
            for case let item as PhotoTileItem in grid.visibleItems() where item.representedPhoto?.url == photo.url {
                item.refreshAnnotation()
            }
            updateStatus()
        }
    }

    @objc func sortChanged() { applySortAndFilter() }
    @objc func gridDidScrollOrResize() {
        let width = gridScroll.contentView.bounds.width
        guard width > 100 else { return }
        if abs(grid.frame.width - width) > 1 {
            grid.setFrameSize(NSSize(width: width, height: grid.frame.height))
            gridLayout.invalidateLayout()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSSearchField === search { applySortAndFilter() }
    }

    // MARK: Outline view

}
