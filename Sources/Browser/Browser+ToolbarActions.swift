import AppKit

extension BrowserViewController {
    @objc func sidebarToggleAction() { toggleSidebar() }
    @objc func toolbarSearchAction() { focusSearch() }
    @objc func toolbarToggleLayoutAction() {
        setGridMode(gridLayout.mode == .waterfall ? .regular : .waterfall)
        updateLayoutSymbol()
    }

    func updateLayoutSymbol() {
        toolbarLayoutButton.setSymbol(gridLayout.mode == .waterfall ? "square.grid.2x2" : "rectangle.grid.1x2",
                                       label: "切换图片布局 (⌘1 / ⌘2)")
    }

    @objc func toolbarMoreAction(_ sender: NSButton) {
        let menu = NSMenu(title: "视图与筛选")
        func item(_ title: String, icon: String, action: Selector, tag: Int = 0, checked: Bool = false) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            entry.tag = tag
            entry.state = checked ? .on : .off
            entry.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            menu.addItem(entry)
        }
        item("瀑布流", icon: "square.grid.2x2", action: #selector(toolbarLayoutItem(_:)), tag: 0,
             checked: gridLayout.mode == .waterfall)
        item("规则网格", icon: "rectangle.grid.1x2", action: #selector(toolbarLayoutItem(_:)), tag: 1,
             checked: gridLayout.mode == .regular)
        menu.addItem(.separator())
        for (index, title) in ["名称 ↑", "名称 ↓", "修改时间 ↓", "文件大小 ↓", "面积 ↓"].enumerated() {
            item(title, icon: "arrow.up.arrow.down", action: #selector(toolbarSortItem(_:)), tag: index,
                 checked: sortMenu.indexOfSelectedItem == index)
        }
        menu.addItem(.separator())
        item("递归包含子文件夹", icon: "folder.badge.gearshape", action: #selector(toolbarRecursiveItem), checked: recursive)
        item("仅显示收藏", icon: "heart", action: #selector(toolbarFavoritesItem), checked: favoritesOnly)
        for rating in 0...5 {
            item(rating == 0 ? "全部评分" : "至少 \\(rating) 星", icon: "star",
                 action: #selector(toolbarRatingItem(_:)), tag: rating, checked: minimumRating == rating)
        }
        menu.addItem(.separator())
        for (width, title) in [(140, "紧凑缩略图"), (205, "标准缩略图"), (290, "大缩略图")] {
            item(title, icon: "photo", action: #selector(toolbarSizeItem(_:)), tag: width,
                 checked: abs(thumbnailWidth - CGFloat(width)) < 2)
        }
        menu.addItem(.separator())
        item("打开文件夹…", icon: "folder.badge.plus", action: #selector(openFolderAction))
        item("新建文件夹…", icon: "folder.badge.plus", action: #selector(sidebarNewFolderAction))
        item("快捷键帮助", icon: "keyboard", action: #selector(toolbarShowHelp))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func toolbarLayoutItem(_ sender: NSMenuItem) {
        setGridMode(sender.tag == 0 ? .waterfall : .regular)
        updateLayoutSymbol()
    }
    @objc private func toolbarSortItem(_ sender: NSMenuItem) {
        sortMenu.selectItem(at: sender.tag)
        sortChanged()
    }
    @objc private func toolbarRecursiveItem() {
        recursiveButton.state = recursive ? .off : .on
        recursiveChanged()
    }
    @objc private func toolbarFavoritesItem() {
        favoriteOnlyButton.state = favoritesOnly ? .off : .on
        favoriteFilterChanged()
    }
    @objc private func toolbarRatingItem(_ sender: NSMenuItem) {
        ratingMenu.selectItem(at: sender.tag)
        ratingFilterChanged()
    }
    @objc private func toolbarSizeItem(_ sender: NSMenuItem) {
        gridSizeSlider.doubleValue = Double(sender.tag)
        gridSizeChanged()
    }
    @objc private func toolbarShowHelp() { showKeyboardShortcuts() }
}
