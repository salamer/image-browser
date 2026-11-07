import AppKit

extension BrowserViewController {
    func updateMode() {
        previewPanel.isHidden = !isPreview
        toolbar.showsThumbnailSlider = !isPreview
        gridScroll.isHidden = isPreview
        emptyState.isHidden = isPreview || !visiblePhotos.isEmpty
        adaptivePreview.isHidden = isComparing
        compareHost.isHidden = !isComparing
        previewHUD.isHidden = isComparing
        previewCaption.isHidden = isComparing
        if isComparing || !isPreview { hideFilmstrip() }
        backButton.isEnabled = isPreview
        updateStatus()
        if !isPreview { view.window?.makeFirstResponder(grid) }
    }

    func openPreview(at index: Int) {
        guard visiblePhotos.indices.contains(index) else { return }
        selectedIndex = index
        let photo = visiblePhotos[index]
        activePhotoURL = photo.url
        isComparing = false
        isPreview = true
        pathControl.url = photo.url
        pathControl.toolTip = photo.url.path
        previewTitle.stringValue = photo.name
        previewMeta.stringValue = "\(photo.dimensions)   ·   \(photo.subtitle)   ·   双击切换 100%"
        previewLabel.stringValue = "\(index + 1) / \(visiblePhotos.count)"
        filmstrip.setSelection(photos: visiblePhotos, current: index)
        previousButton.isEnabled = index > 0
        nextButton.isEnabled = index < visiblePhotos.count - 1
        PreviewPipeline.shared.cancelPending()
        resizeDecodeWork?.cancel()
        previewRequestID = UUID()
        previewHighQualityDisplayed = false
        let requestID = previewRequestID
        adaptivePreview.clear()
        adaptivePreview.setContextMenu(makeFileMenu(for: photo))
        updateMode()
        view.window?.makeFirstResponder(adaptivePreview) // release stale search-field focus
        statusLabel.stringValue = "\(photo.name)  ·  \(photo.dimensions)  ·  \(photo.subtitle)"
        let size = NSSize(width: CGFloat(photo.pixelWidth), height: CGFloat(photo.pixelHeight))

        // Fast first paint. Full resolution replaces thumbnail without relocating it.
        if let cached = ThumbnailPipeline.shared.cachedImage(for: photo, pixelSize: thumbnailPixels) {
            adaptivePreview.display(cached, pixelSize: size, resetFit: true)
        } else {
            // Load a cheap first paint when the user jumps to an uncached picture.
            // A late thumbnail must never replace the full-resolution image.
            ThumbnailPipeline.shared.request(photo, pixelSize: thumbnailPixels) { [weak self] image in
                guard let self, self.previewRequestID == requestID,
                      !self.previewHighQualityDisplayed, self.isPreview,
                      self.activePhotoURL == photo.url, let image else { return }
                self.adaptivePreview.display(image, pixelSize: size, resetFit: false)
            }
        }
        let decodeSize = previewPixelSize
        currentPreviewDecodePixels = decodeSize
        PreviewPipeline.shared.request(photo.url, maxPixelSize: decodeSize) { [weak self] image in
            guard let self, self.previewRequestID == requestID, self.activePhotoURL == photo.url,
                  self.isPreview, !self.isComparing, let image else { return }
            self.previewHighQualityDisplayed = true
            self.adaptivePreview.display(image, pixelSize: size, resetFit: false)
            // Warm at most the two likely next images after the requested one is visible.
            for offset in [-1, 1] {
                let next = index + offset
                if self.visiblePhotos.indices.contains(next) {
                    PreviewPipeline.shared.request(self.visiblePhotos[next].url, maxPixelSize: decodeSize) { _ in }
                }
            }
        }
    }

    func togglePreview() {
        if isPreview {
            backToGrid()
        } else if !visiblePhotos.isEmpty {
            let selected = grid.selectionIndexPaths.first?.item ?? 0
            openPreview(at: selected)
        }
    }

    func backToGrid() {
        let lastURL = activePhotoURL
        activePhotoURL = nil
        if isFocusMode { toggleFocusMode() }
        isPreview = false
        isComparing = false
        filmstripPinned = false
        adaptivePreview.pinnedFilmstrip = false
        hideFilmstrip()
        if let currentFolder {
            pathControl.url = currentFolder
            pathControl.toolTip = currentFolder.path
        }
        updateMode()
        if let lastURL, let index = visiblePhotos.firstIndex(where: { $0.url == lastURL }) {
            let path = IndexPath(item: index, section: 0)
            grid.selectItems(at: [path], scrollPosition: [])
        }
    }

    func movePhoto(_ delta: Int) {
        if isComparing { return }
        let next = selectedIndex + delta
        guard visiblePhotos.indices.contains(next) else { return }
        if isPreview && !isComparing { openPreview(at: next) }
        else {
            selectedIndex = next
            grid.deselectAll(nil)
            grid.selectItems(at: [IndexPath(item: next, section: 0)], scrollPosition: .centeredVertically)
        }
    }

    func adjustZoom(multiplier: CGFloat) {
        guard isPreview, !isComparing else { return }
        adaptivePreview.adjustZoom(multiplier)
    }

    func fitPreview() {
        guard isPreview, !isComparing else { return }
        adaptivePreview.fit()
    }

    func toggleFitActualSize() {
        guard isPreview, !isComparing else { return }
        adaptivePreview.toggleFitActualSize()
    }

    func setGridMode(_ mode: MasonryLayout.Mode) {
        layoutMenu.selectItem(at: mode == .waterfall ? 0 : 1)
        layoutChanged()
        updateLayoutSymbol()
    }

    func showKeyboardShortcuts() {
        let alert = NSAlert()
        alert.messageText = "SwiftLens 快捷键"
        alert.informativeText = """
            空格 / Return   打开或退出图片预览
            ← / → · J / K   上一张 / 下一张
            Home / End      首张 / 末张
            Esc             返回瀑布流
            T               固定 / 隐藏底部胶片栏（靠近底边也会自动显示）
            Tab             专注看图：隐藏 / 恢复工具栏与侧栏
            Z               适应窗口 / 100% 像素
            ⌘0 / ⌘+ / ⌘-   适应窗口 / 放大 / 缩小
            1–5 / 0         星级评分 / 清除评分
            F               收藏或取消收藏
            ⌘F / ⌘O / ⌘R   搜索 / 打开目录 / 刷新
            ⌘1 / ⌘2       瀑布流 / 规则网格
            ⌘C / ⇧⌘C      复制文件 / 复制文件路径
            ⌘V             将文件粘贴到当前目录
            ⌘A             全选图片
            ⌘[ / ⌘] · ⌥←/→  后退 / 前进目录
            ⌘↑             上级目录
            ⇧⌘N           新建文件夹
            ⌘B             显示 / 隐藏侧边栏
            ⌘⌫              移到废纸篓（有确认）
            F2              重命名
            ⇧?              显示此帮助
            """
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    @objc func actualSizeAction() {
        guard isPreview, !isComparing else { return }
        adaptivePreview.actualSize()
    }

    func revealSelectedInFinder() {
        let photo = isPreview
            ? visiblePhotos.indices.contains(selectedIndex) ? visiblePhotos[selectedIndex] : nil
            : grid.selectionIndexPaths.first.flatMap { visiblePhotos.indices.contains($0.item) ? visiblePhotos[$0.item] : nil }
        if let photo { NSWorkspace.shared.activateFileViewerSelecting([photo.url]) }
        else if let currentFolder { NSWorkspace.shared.open(currentFolder) }
    }

    func focusSearch() { view.window?.makeFirstResponder(search) }

}
