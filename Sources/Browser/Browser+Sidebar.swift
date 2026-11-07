import AppKit

/// Explorer actions are intentionally scoped to the selected folder, mirroring
/// Finder/VS Code. Image operations remain in Browser+FileOperations.
extension BrowserViewController {
    func sidebarSelectedURL() -> URL? {
        guard outline.selectedRow >= 0,
              let node = outline.item(atRow: outline.selectedRow) as? FolderNode else { return currentFolder }
        return node.url
    }

    @objc func sidebarAddRootAction() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "选择添加到文件资源管理器的文件夹"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !roots.contains(where: { $0.url == url }) {
            roots.append(FolderNode(url: url))
        }
        outline.reloadData()
        for root in roots { outline.expandItem(root) }
        if let first = panel.urls.first { navigate(to: first) }
    }

    @objc func sidebarNewFolderAction() {
        guard let parent = sidebarSelectedURL() else { return }
        let alert = NSAlert()
        alert.messageText = "在 \(parent.lastPathComponent) 中新建文件夹"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 27))
        input.stringValue = "新建文件夹"
        alert.accessoryView = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFolderName(name) else { NSSound.beep(); return }
        let destination = parent.appendingPathComponent(name, isDirectory: true)
        performFileMutation({
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        }) { [weak self] in
            self?.reloadSidebarTree()
            self?.navigate(to: destination)
        }
    }

    private func isValidFolderName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }

    @objc func sidebarRevealAction() {
        guard let url = sidebarSelectedURL() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func sidebarCollapseAllAction() {
        for root in roots { outline.collapseItem(root, collapseChildren: true) }
    }

    @objc func sidebarRefreshAction() { reloadSidebarTree() }

    func reloadSidebarTree(selecting selectedURL: URL? = nil) {
        let selected = selectedURL ?? sidebarSelectedURL()
        roots = roots.map { FolderNode(url: $0.url) }
        outline.reloadData()
        if let selected { synchronizeOutlineSelection(to: selected) }
        else { for root in roots { outline.expandItem(root) } }
    }

    @objc func sidebarDoubleClickAction() {
        let row = outline.clickedRow >= 0 ? outline.clickedRow : outline.selectedRow
        guard row >= 0, let node = outline.item(atRow: row) as? FolderNode else { return }
        if outline.isItemExpanded(node) { outline.collapseItem(node) }
        else { outline.expandItem(node) }
    }

    func folderContextMenu(row: Int) -> NSMenu? {
        guard row >= 0, let node = outline.item(atRow: row) as? FolderNode else { return nil }
        let folder = node.url
        let menu = NSMenu(title: node.title)
        func add(_ title: String, symbol: String, action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = folder
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            menu.addItem(item)
        }
        add("打开文件夹", symbol: "folder", action: #selector(sidebarOpenMenu(_:)))
        add("在 Finder 中显示", symbol: "arrow.up.right.square", action: #selector(sidebarRevealMenu(_:)))
        menu.addItem(.separator())
        add("新建子文件夹…", symbol: "folder.badge.plus", action: #selector(sidebarNewFolderMenu(_:)))
        add("复制路径", symbol: "link", action: #selector(sidebarCopyPathMenu(_:)))
        add("重命名文件夹…", symbol: "pencil", action: #selector(sidebarRenameMenu(_:)))
        if roots.contains(where: { $0.url == folder }) {
            menu.addItem(.separator())
            add("从侧边栏移除", symbol: "minus.circle", action: #selector(sidebarRemoveRootMenu(_:)))
        }
        return menu
    }

    @objc func sidebarOpenMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        navigate(to: url)
    }
    @objc func sidebarRevealMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    @objc func sidebarCopyPathMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        copyPath(url)
    }
    @objc func sidebarNewFolderMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let row = (0..<outline.numberOfRows).first {
            (outline.item(atRow: $0) as? FolderNode)?.url == url
        }
        if let row { outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        sidebarNewFolderAction()
    }
    @objc func sidebarRenameMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let alert = NSAlert()
        alert.messageText = "重命名文件夹"
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 27))
        input.stringValue = url.lastPathComponent
        alert.accessoryView = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFolderName(name), name != url.lastPathComponent else { return }
        let target = url.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
        let oldCurrent = currentFolder
        performFileMutation({
            guard !FileManager.default.fileExists(atPath: target.path) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.moveItem(at: url, to: target)
        }) { [weak self] in
            guard let self else { return }
            self.roots = self.roots.map { FolderNode(url: $0.url == url ? target : $0.url) }
            self.reloadSidebarTree(selecting: target)
            // If browsing inside renamed folder, preserve relative path.
            if let oldCurrent, (oldCurrent == url || oldCurrent.path.hasPrefix(url.path + "/")) {
                let suffix = String(oldCurrent.path.dropFirst(url.path.count))
                self.navigate(to: URL(fileURLWithPath: target.path + suffix, isDirectory: true))
            }
        }
    }
    @objc func sidebarRemoveRootMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        roots.removeAll { $0.url == url }
        if roots.isEmpty {
            roots = [FolderNode(url: FileManager.default.homeDirectoryForCurrentUser)]
        }
        outline.reloadData()
        outline.expandItem(roots.first)
        if let currentFolder,
           !roots.contains(where: { currentFolder == $0.url || currentFolder.path.hasPrefix($0.url.path + "/") }),
           let first = roots.first {
            navigate(to: first.url)
        }
    }
}
