import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var browser: BrowserViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        // Asset Catalog remains the authoritative CFBundleIconName. A bundled
        // PNG fallback makes Xcode Run/Dock display deterministic if the OS has
        // a stale icon cache during iterative development.
        if let url = Bundle.main.url(forResource: "SwiftLensIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        installMenu()

        browser = BrowserViewController()
        window = BrowserWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SwiftLens"
        window.minSize = NSSize(width: 710, height: 490)
        window.center()
        window.delegate = self
        window.contentViewController = browser
        (window as? BrowserWindow)?.browser = browser
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unifiedCompact
        // Image area captures mouse drags for preview/pan rather than dragging the window.
        window.isMovableByWindowBackground = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Double-click toolbar -> NSWindow.zoom(_:), not green-button fullscreen.
    /// Respect Dock/menu-bar safe visibleFrame and keep the restored frame.
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        window.screen?.visibleFrame ?? newFrame
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func installMenu() {
        let main = NSMenu()
        NSApp.mainMenu = main

        let applicationItem = NSMenuItem()
        main.addItem(applicationItem)
        let appMenu = NSMenu()
        applicationItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 SwiftLens", action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 SwiftLens", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "打开文件夹…", action: #selector(openFolder), keyEquivalent: "o").target = self
        fileMenu.addItem(withTitle: "刷新", action: #selector(refresh), keyEquivalent: "r").target = self
        fileMenu.addItem(withTitle: "在 Finder 中显示", action: #selector(revealFile), keyEquivalent: "").target = self
        fileMenu.addItem(withTitle: "新建文件夹…", action: #selector(newFolder), keyEquivalent: "N").target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "复制文件路径", action: #selector(copyPath), keyEquivalent: "C").target = self

        // Finder-/editor-like menu: text editor keeps normal editing semantics.
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "复制", action: #selector(copyOrText(_:)), keyEquivalent: "c").target = self
        editMenu.addItem(withTitle: "粘贴", action: #selector(pasteOrText(_:)), keyEquivalent: "v").target = self
        editMenu.addItem(withTitle: "全选", action: #selector(selectAllOrText(_:)), keyEquivalent: "a").target = self

        let goItem = NSMenuItem()
        main.addItem(goItem)
        let goMenu = NSMenu(title: "前往")
        goItem.submenu = goMenu
        goMenu.addItem(withTitle: "后退", action: #selector(goBack), keyEquivalent: "[").target = self
        goMenu.addItem(withTitle: "前进", action: #selector(goForward), keyEquivalent: "]").target = self
        goMenu.addItem(withTitle: "上级文件夹", action: #selector(goParent), keyEquivalent: "").target = self

        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: "显示")
        viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "查找图片", action: #selector(focusSearch), keyEquivalent: "f").target = self
        viewMenu.addItem(withTitle: "网格 / 大图", action: #selector(togglePreview), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "放大", action: #selector(zoomIn), keyEquivalent: "+").target = self
        viewMenu.addItem(withTitle: "缩小", action: #selector(zoomOut), keyEquivalent: "-").target = self
        viewMenu.addItem(withTitle: "适应窗口", action: #selector(fitImage), keyEquivalent: "0").target = self
        viewMenu.addItem(withTitle: "比较选中的两张", action: #selector(compare), keyEquivalent: "d").target = self
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "瀑布流布局", action: #selector(waterfallLayout), keyEquivalent: "1").target = self
        viewMenu.addItem(withTitle: "规则网格布局", action: #selector(regularLayout), keyEquivalent: "2").target = self
        viewMenu.addItem(withTitle: "显示 / 隐藏胶片栏", action: #selector(filmstrip), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "显示 / 隐藏侧边栏", action: #selector(sidebar), keyEquivalent: "b").target = self
        viewMenu.addItem(withTitle: "预览适应 / 原始大小", action: #selector(toggleFitActual), keyEquivalent: "").target = self
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "键盘快捷键…", action: #selector(shortcuts), keyEquivalent: "").target = self

        let organizeItem = NSMenuItem()
        main.addItem(organizeItem)
        let organize = NSMenu(title: "整理")
        organizeItem.submenu = organize
        for rating in 1...5 {
            let entry = organize.addItem(withTitle: "设置 \(rating) 星", action: #selector(rateFromMenu(_:)), keyEquivalent: "")
            entry.tag = rating
            entry.target = self
        }
        organize.addItem(withTitle: "清除评分", action: #selector(clearRating), keyEquivalent: "").target = self
        organize.addItem(withTitle: "收藏 / 取消收藏", action: #selector(toggleFavorite), keyEquivalent: "").target = self

        let helpItem = NSMenuItem()
        main.addItem(helpItem)
        let helpMenu = NSMenu(title: "帮助")
        helpItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "快捷键与基本用法…", action: #selector(shortcuts), keyEquivalent: "").target = self
        helpMenu.addItem(withTitle: "关于 SwiftLens", action: #selector(showAbout), keyEquivalent: "").target = self
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SwiftLens"
        alert.informativeText = "原生 macOS 图片浏览器。AppKit · ImageIO · 双层缩略图缓存。"
        alert.runModal()
    }

    @objc private func openFolder() { browser.openFolder() }
    @objc private func newFolder() { browser.makeNewFolder() }
    @objc private func copyPath() { browser.copySelectedPath() }
    @objc private func goBack() { browser.navigateBack() }
    @objc private func goForward() { browser.navigateForward() }
    @objc private func goParent() { browser.navigateParent() }
    @objc private func sidebar() { browser.toggleSidebar() }
    @objc private func copyOrText(_ sender: Any?) {
        if let editor = window.firstResponder as? NSTextView { editor.copy(sender) }
        else { browser.copySelectedFile() }
    }
    @objc private func pasteOrText(_ sender: Any?) {
        if let editor = window.firstResponder as? NSTextView { editor.paste(sender) }
        else { browser.pasteIntoCurrentFolder() }
    }
    @objc private func selectAllOrText(_ sender: Any?) {
        if let editor = window.firstResponder as? NSTextView { editor.selectAll(sender) }
        else { browser.selectAllPhotos() }
    }
    @objc private func refresh() { browser.refreshCurrentFolder() }
    @objc private func revealFile() { browser.revealSelectedInFinder() }
    @objc private func focusSearch() { browser.focusSearch() }
    @objc private func togglePreview() { browser.togglePreview() }
    @objc private func zoomIn() { browser.adjustZoom(multiplier: 1.25) }
    @objc private func zoomOut() { browser.adjustZoom(multiplier: 0.8) }
    @objc private func fitImage() { browser.fitPreview() }
    @objc private func compare() { browser.compareSelected() }
    @objc private func waterfallLayout() { browser.setGridMode(.waterfall) }
    @objc private func regularLayout() { browser.setGridMode(.regular) }
    @objc private func filmstrip() { browser.toggleFilmstrip() }
    @objc private func toggleFitActual() { browser.toggleFitActualSize() }
    @objc private func shortcuts() { browser.showKeyboardShortcuts() }
    @objc private func rateFromMenu(_ sender: NSMenuItem) { browser.setRatingFromMenu(sender.tag) }
    @objc private func clearRating() { browser.setRatingFromMenu(0) }
    @objc private func toggleFavorite() { browser.toggleFavoriteFromMenu() }
}
