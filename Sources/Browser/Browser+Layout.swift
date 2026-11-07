import AppKit

extension BrowserViewController {
    func configureRootLayout() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.material = .headerView
        toolbar.blendingMode = .withinWindow
        split.translatesAutoresizingMaskIntoConstraints = false
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = self
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbar)
        view.addSubview(split)
        view.addSubview(statusLabel)
        let toolbarHeight = toolbar.heightAnchor.constraint(equalToConstant: 48)
        toolbarHeightConstraint = toolbarHeight
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarHeight,
            split.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            split.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            split.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -5),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -7),
            statusLabel.heightAnchor.constraint(equalToConstant: 18)
        ])

        sidebar.material = .sidebar
        sidebar.blendingMode = .withinWindow
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        rightPane.wantsLayer = true
        rightPane.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1).cgColor
        split.addArrangedSubview(sidebar)
        split.addArrangedSubview(rightPane)
        // Do NOT constrain arranged-subview width to >= 620. NSSplitView temporarily
        // lays them out at width zero; hard constraints caused startup Auto Layout warnings.
    }

    func configureToolbar() {
        func configure(_ button: HoverIconButton, symbol: String, tip: String, action: Selector) {
            button.setSymbol(symbol, label: tip)
            button.target = self
            button.action = action
        }
        configure(sidebarToggleButton, symbol: "sidebar.leading", tip: "显示或隐藏文件夹侧栏 (⌘B)", action: #selector(sidebarToggleAction))
        configure(toolbarBackButton, symbol: "chevron.left", tip: "后退 (⌘[)", action: #selector(historyBackAction))
        configure(toolbarForwardButton, symbol: "chevron.right", tip: "前进 (⌘])", action: #selector(historyForwardAction))
        configure(toolbarParentButton, symbol: "arrow.up", tip: "上级文件夹 (⌘↑)", action: #selector(historyParentAction))
        configure(toolbarLayoutButton, symbol: "square.grid.2x2", tip: "切换瀑布流 / 规则网格 (⌘1 / ⌘2)", action: #selector(toolbarToggleLayoutAction))
        configure(toolbarMoreButton, symbol: "slider.horizontal.3", tip: "排序、筛选与视图选项", action: #selector(toolbarMoreAction))
        configure(toolbarSearchButton, symbol: "magnifyingglass", tip: "搜索图片 (⌘F)", action: #selector(toolbarSearchAction))

        pathControl.pathStyle = .standard
        pathControl.isEditable = false
        pathControl.controlSize = .small
        pathControl.target = self
        pathControl.action = #selector(pathComponentClicked(_:))
        pathControl.toolTip = "点击路径中的文件夹打开 · 右键图片可复制完整路径"
        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        search.placeholderString = "搜索图片  ⌘F"
        search.delegate = self
        search.toolTip = "按文件名快速过滤；Esc 清除或返回图片"

        layoutMenu.addItems(withTitles: ["瀑布流", "整齐网格"])
        layoutMenu.target = self
        layoutMenu.action = #selector(layoutChanged)
        sortMenu.addItems(withTitles: ["名称 ↑", "名称 ↓", "修改时间 ↓", "文件大小 ↓", "面积 ↓"])
        sortMenu.target = self
        sortMenu.action = #selector(sortChanged)
        sortMenu.toolTip = "切换排序方式"
        ratingMenu.addItems(withTitles: ["全部评分", "≥1 星", "≥2 星", "≥3 星", "≥4 星", "5 星"])
        ratingMenu.target = self
        ratingMenu.action = #selector(ratingFilterChanged)
        recursiveButton.target = self
        recursiveButton.action = #selector(recursiveChanged)
        favoriteOnlyButton.target = self
        favoriteOnlyButton.action = #selector(favoriteFilterChanged)
        gridSizeSlider.target = self
        gridSizeSlider.action = #selector(gridSizeChanged)
        gridSizeSlider.isContinuous = true
        gridSizeSlider.doubleValue = Double(thumbnailWidth)
        gridSizeSlider.toolTip = "水平拖动或在滑杆上双指左右滑动，调整缩略图大小"
        gridSizeSlider.setAccessibilityLabel("缩略图大小")

        toolbar.configure(sidebar: sidebarToggleButton, back: toolbarBackButton,
                          forward: toolbarForwardButton, parent: toolbarParentButton,
                          path: pathControl, search: search, compactSearch: toolbarSearchButton,
                          layout: toolbarLayoutButton, sort: sortMenu,
                          thumbnailSize: gridSizeSlider, more: toolbarMoreButton)
        updateToolbarForWidth()
    }

    func configureSidebar() {
        let title = NSTextField(labelWithString: "文件资源管理器")
        title.font = .systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(title)

        func sideButton(_ symbol: String, _ description: String, _ selector: Selector) -> NSButton {
            let button = HoverIconButton()
            button.setSymbol(symbol, label: description)
            button.target = self
            button.action = selector
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 25),
                button.heightAnchor.constraint(equalToConstant: 25)
            ])
            return button
        }
        let addRoot = sideButton("folder.badge.plus", "添加文件夹", #selector(sidebarAddRootAction))
        let newFolder = sideButton("plus", "在选中文件夹中新建子文件夹", #selector(sidebarNewFolderAction))
        let collapse = sideButton("rectangle.compress.vertical", "折叠所有文件夹", #selector(sidebarCollapseAllAction))
        let headerActions = NSStackView(views: [addRoot, newFolder, collapse])
        headerActions.orientation = .horizontal
        headerActions.alignment = .centerY
        headerActions.spacing = 2
        headerActions.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(headerActions)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 14),
            title.centerYAnchor.constraint(equalTo: headerActions.centerYAnchor),
            headerActions.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -8),
            headerActions.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 8),
            headerActions.heightAnchor.constraint(equalToConstant: 30)
        ])

        outline.frame = .zero
        outline.autoresizingMask = [.width]
        outline.headerView = nil
        outline.rowHeight = 28
        outline.indentationPerLevel = 14
        outline.selectionHighlightStyle = .sourceList
        outline.backgroundColor = .clear
        outline.dataSource = self
        outline.delegate = self
        outline.doubleAction = #selector(sidebarDoubleClickAction)
        outline.target = self
        outline.contextMenuForRow = { [weak self] row in self?.folderContextMenu(row: row) }
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Folder"))
        col.title = "Folder"
        outline.addTableColumn(col)
        outline.outlineTableColumn = col

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = false  // enabled after nonzero layout
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = true
        scroll.frame = .zero
        scroll.isHidden = true
        sidebar.addSubview(scroll)
        sidebar.outlineScrollView = scroll
        sidebar.headerHeight = 44

        contentHost.translatesAutoresizingMaskIntoConstraints = false
        rightPane.addSubview(contentHost)
        NSLayoutConstraint.activate([
            contentHost.leadingAnchor.constraint(equalTo: rightPane.leadingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: rightPane.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: rightPane.topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: rightPane.bottomAnchor)
        ])
    }

    func configureGrid() {
        gridLayout.mode = .waterfall
        gridLayout.targetWidth = thumbnailWidth
        grid.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        grid.autoresizingMask = [.width]
        grid.collectionViewLayout = gridLayout
        grid.dataSource = self
        grid.delegate = self
        grid.isSelectable = true
        grid.allowsMultipleSelection = true
        grid.backgroundColors = [NSColor(calibratedWhite: 0.125, alpha: 1)]
        grid.register(PhotoTileItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("PhotoTile"))

        gridScroll.documentView = grid
        gridScroll.hasVerticalScroller = true
        gridScroll.autohidesScrollers = true
        gridScroll.drawsBackground = false
        gridScroll.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(gridScroll)
        constrainToParent(gridScroll, parent: contentHost)
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        emptyState.isHidden = true
        emptyState.onOpenFolder = { [weak self] in self?.openFolder() }
        emptyState.onShowShortcuts = { [weak self] in self?.showKeyboardShortcuts() }
        emptyState.onClearFilters = { [weak self] in self?.clearFilters() }
        contentHost.addSubview(emptyState)
        NSLayoutConstraint.activate([
            emptyState.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            emptyState.topAnchor.constraint(equalTo: contentHost.topAnchor),
            emptyState.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
        gridScroll.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(gridDidScrollOrResize),
            name: NSView.frameDidChangeNotification, object: gridScroll.contentView)
    }

    func configurePreview() {
        previewPanel.translatesAutoresizingMaskIntoConstraints = false
        previewPanel.wantsLayer = true
        previewPanel.layer?.backgroundColor = NSColor(calibratedWhite: 0.095, alpha: 1).cgColor
        contentHost.addSubview(previewPanel)
        constrainToParent(previewPanel, parent: contentHost)

        adaptivePreview.translatesAutoresizingMaskIntoConstraints = false
        adaptivePreview.onZoomChanged = { [weak self] value, automatic in
            self?.zoomLabel.stringValue = automatic ? "适应" : "\(Int((value * 100).rounded()))%"
        }
        previewPanel.addSubview(adaptivePreview)
        constrainToParent(adaptivePreview, parent: previewPanel)

        // CompareImageHost computes image frames from its bounds. No impossible
        // fixed 3-point gap constraint during a 0-wide initial layout pass.
        compareHost.translatesAutoresizingMaskIntoConstraints = false
        previewPanel.addSubview(compareHost)
        constrainToParent(compareHost, parent: previewPanel)
        compareHost.isHidden = true

        // Floating filmstrip is managed by PreviewMousePanel.layout() instead of
        // fixed side insets, which would be unsatisfiable at parent width zero.
        filmstrip.translatesAutoresizingMaskIntoConstraints = true
        filmstrip.isHidden = true
        filmstrip.onSelect = { [weak self] index in self?.openPreview(at: index) }
        previewPanel.addSubview(filmstrip)
        previewPanel.overlayFilmstrip = filmstrip
        previewPanel.onMouseLocation = { [weak self] location in self?.handlePreviewMouse(location) }

        // Small, unobtrusive file caption. Labels are frame-laid-out and remain
        // valid even when the parent is temporarily 0×0 during first attachment.
        previewCaption.material = .hudWindow
        previewCaption.blendingMode = .withinWindow
        previewCaption.wantsLayer = true
        previewCaption.layer?.cornerRadius = 9
        previewTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        previewTitle.lineBreakMode = .byTruncatingMiddle
        previewTitle.textColor = .labelColor
        previewMeta.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        previewMeta.textColor = .secondaryLabelColor
        for label in [previewTitle, previewMeta] {
            label.translatesAutoresizingMaskIntoConstraints = true
            previewCaption.addSubview(label)
        }
        previewCaption.translatesAutoresizingMaskIntoConstraints = true
        previewPanel.addSubview(previewCaption)
        previewPanel.overlayCaption = previewCaption
        previewPanel.captionTitle = previewTitle
        previewPanel.captionMeta = previewMeta

        previewHUD.material = .hudWindow
        previewHUD.blendingMode = .withinWindow
        previewHUD.wantsLayer = true
        previewHUD.layer?.cornerRadius = 12
        previewHUD.alphaValue = 0.75
        previewHUD.translatesAutoresizingMaskIntoConstraints = true
        previewPanel.addSubview(previewHUD)
        previewPanel.overlayHUD = previewHUD
        func hudButton(_ symbol: String, tooltip: String, action: Selector) -> NSButton {
            let b = HoverIconButton()
            b.setSymbol(symbol, label: tooltip)
            b.target = self
            b.action = action
            b.setAccessibilityLabel(tooltip)
            return b
        }
        let zoomOut = hudButton("minus.magnifyingglass", tooltip: "缩小 (⌘-)", action: #selector(zoomOutAction))
        let zoomIn = hudButton("plus.magnifyingglass", tooltip: "放大 (⌘+)", action: #selector(zoomInAction))
        let fit = hudButton("arrow.up.left.and.arrow.down.right", tooltip: "适应窗口 (⌘0)", action: #selector(fitAction))
        let actual = hudButton("1.magnifyingglass", tooltip: "实际像素 100% (双击切换)", action: #selector(actualSizeAction))
        let exit = hudButton("square.grid.2x2", tooltip: "返回图片列表 (Esc)", action: #selector(backToGridAction))
        let strip = hudButton("rectangle.on.rectangle", tooltip: "固定胶片栏 (T)", action: #selector(toggleFilmstripAction))
        previousButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "上一张")
        nextButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "下一张")
        for (button, action, title) in [(previousButton, #selector(previousAction), "上一张 ←"),
                                        (nextButton, #selector(nextAction), "下一张 →")] {
            button.bezelStyle = .inline
            button.contentTintColor = .secondaryLabelColor
            button.title = ""
            button.toolTip = title
            button.target = self
            button.action = action
            button.setAccessibilityLabel(title)
        }
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        zoomLabel.alignment = .center
        previewLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        previewLabel.alignment = .center
        previewHUD.install([
            .init(view: exit, width: 31, priority: 0),
            .init(view: previousButton, width: 31, priority: 0),
            .init(view: zoomOut, width: 31, priority: 2),
            .init(view: zoomLabel, width: 52, priority: 1),
            .init(view: zoomIn, width: 31, priority: 2),
            .init(view: fit, width: 31, priority: 1),
            .init(view: actual, width: 31, priority: 2),
            .init(view: strip, width: 31, priority: 2),
            .init(view: nextButton, width: 31, priority: 0),
            .init(view: previewLabel, width: 62, priority: 0)
        ])
        // HUD position and size are computed by PreviewMousePanel.layout().
        // Fixed-width constraints could not accommodate zero-width parents.
        previewPanel.isHidden = true
    }

    // MARK: Auto-revealed filmstrip

    func configureStatusBar() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.stringValue = "选择一个文件夹开始浏览 · 空格预览 · T 胶片栏 · ? 快捷键"
    }

    func constrainToParent(_ child: NSView, parent: NSView) {
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }

    // MARK: Directory navigation


    func toggleSidebar() {
        guard split.arrangedSubviews.count >= 2 else { return }
        if sidebarCollapsed {
            sidebarCollapsed = false
            split.setPosition(min(expandedSidebarWidth, max(180, split.bounds.width - 240)), ofDividerAt: 0)
        } else {
            let current = sidebar.frame.width
            if current > 120 { expandedSidebarWidth = current }
            sidebarCollapsed = true
            split.setPosition(0, ofDividerAt: 0)
        }
        sidebarToggleButton.contentTintColor = sidebarCollapsed ? .secondaryLabelColor : .controlAccentColor
        split.needsLayout = true
        gridDidScrollOrResize()
        adaptivePreview.refreshViewport()
    }

    func updateToolbarForWidth() {
        toolbar.needsLayout = true
        toolbar.layoutSubtreeIfNeeded()
    }
}
