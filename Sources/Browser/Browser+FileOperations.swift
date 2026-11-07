import AppKit

extension BrowserViewController {
    func makeFileMenu(for photo: PhotoFile) -> NSMenu {
        if let index = visiblePhotos.firstIndex(where: { $0.url == photo.url }) {
            let path = IndexPath(item: index, section: 0)
            if !grid.selectionIndexPaths.contains(path) {
                grid.selectionIndexPaths = [path]
            }
            selectedIndex = index
        }
        let menu = NSMenu(title: photo.name)
        func add(_ title: String, _ icon: String, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = photo.url
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            menu.addItem(item)
        }
        add("打开预览", "eye", #selector(menuOpenPreview(_:)))
        add("在 Finder 中显示", "folder", #selector(menuReveal(_:)))
        menu.addItem(.separator())
        add("复制文件", "doc.on.doc", #selector(menuCopyFile(_:)))
        add("复制完整路径", "link", #selector(menuCopyPath(_:)))
        menu.addItem(.separator())
        add("重命名…", "pencil", #selector(menuRename(_:)))
        add("复制一份", "plus.square.on.square", #selector(menuDuplicate(_:)))
        add("移动到…", "folder.badge.plus", #selector(menuMove(_:)))
        menu.addItem(.separator())
        let ratingItem = NSMenuItem(title: "评分", action: nil, keyEquivalent: "")
        let ratings = NSMenu(title: "评分")
        for star in 0...5 {
            let item = NSMenuItem(title: star == 0 ? "清除评分" : String(repeating: "★", count: star),
                                  action: #selector(menuRate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = star
            item.representedObject = photo.url
            ratings.addItem(item)
        }
        menu.addItem(ratingItem)
        menu.setSubmenu(ratings, for: ratingItem)
        add(PhotoAnnotations.shared.annotation(for: photo.url).favorite ? "取消收藏" : "收藏", "heart", #selector(menuFavorite(_:)))
        menu.addItem(.separator())
        add("移到废纸篓…", "trash", #selector(menuTrash(_:)))
        return menu
    }

    func urlFromMenu(_ sender: NSMenuItem) -> URL? { sender.representedObject as? URL }

    func copyFile(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.writeObjects([url as NSURL])
    }

    func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    func selectedPhotosForFileOperations() -> [PhotoFile] {
        if isPreview { return selectedPhoto().map { [$0] } ?? [] }
        let paths = grid.selectionIndexPaths.sorted { $0.item < $1.item }
        let selected = paths.compactMap { visiblePhotos.indices.contains($0.item) ? visiblePhotos[$0.item] : nil }
        return selected.isEmpty ? (selectedPhoto().map { [$0] } ?? []) : selected
    }

    func copySelectedFile() {
        let photos = selectedPhotosForFileOperations()
        guard !photos.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.writeObjects(photos.map { $0.url as NSURL })
    }
    func copySelectedPath() { if let photo = selectedPhoto() { copyPath(photo.url) } }


    /// Finder-style copy/paste. No source is removed; names are collision-safe.
    func pasteIntoCurrentFolder() {
        guard let folder = currentFolder, !isPreview else { return }
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else {
            NSSound.beep()
            return
        }
        statusLabel.stringValue = "正在复制 \(urls.count) 个文件…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var errors: [String] = []
            var copied: [(URL, URL)] = []
            for source in urls where source.isFileURL {
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                let base = source.deletingPathExtension().lastPathComponent
                let suffix = source.pathExtension.isEmpty ? "" : "." + source.pathExtension
                var destination = folder.appendingPathComponent(source.lastPathComponent)
                var n = 1
                while FileManager.default.fileExists(atPath: destination.path) {
                    destination = folder.appendingPathComponent("\(base) copy\(n == 1 ? "" : " \(n)")\(suffix)")
                    n += 1
                }
                do {
                    try FileManager.default.copyItem(at: source, to: destination)
                    copied.append((source, destination))
                } catch { errors.append("\(source.lastPathComponent): \(error.localizedDescription)") }
            }
            DispatchQueue.main.async { [weak self] in
                for (source, destination) in copied {
                    PhotoAnnotations.shared.transfer(from: source, to: destination, copy: true)
                }
                if self?.currentFolder == folder { self?.refreshCurrentFolder() }
                if !errors.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "有些文件未能复制"
                    alert.informativeText = errors.prefix(5).joined(separator: "\n")
                    alert.runModal()
                }
            }
        }
    }

    func makeNewFolder() {
        guard let parent = currentFolder else { return }
        let alert = NSAlert()
        alert.messageText = "新建文件夹"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 26))
        field.stringValue = "未命名文件夹"
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else { return }
        do {
            try FileManager.default.createDirectory(at: parent.appendingPathComponent(name),
                withIntermediateDirectories: false)
            reloadSidebarTree()
        } catch { showFileError(error) }
    }

    /// File I/O is not performed on the main UI thread. All callbacks return to main.
    func performFileMutation(_ operation: @escaping () throws -> Void,
                             onSuccess: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try operation()
                DispatchQueue.main.async { onSuccess() }
            } catch {
                DispatchQueue.main.async { self?.showFileError(error) }
            }
        }
    }

    func showFileError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    func renameFile(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "重命名文件"
        alert.informativeText = "只修改文件名，不改变图片内容。"
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 25))
        field.stringValue = url.lastPathComponent
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              name != url.lastPathComponent else { return }
        let target = url.deletingLastPathComponent().appendingPathComponent(name)
        let openedFolder = currentFolder
        performFileMutation({ try FileManager.default.moveItem(at: url, to: target) }) { [weak self] in
            PhotoAnnotations.shared.transfer(from: url, to: target, copy: false)
            if self?.currentFolder == openedFolder { self?.refreshCurrentFolder() }
        }
    }

    @objc func menuOpenPreview(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender), let index = visiblePhotos.firstIndex(where: { $0.url == url }) else { return }
        openPreview(at: index)
    }
    @objc func menuReveal(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    @objc func menuCopyFile(_ sender: NSMenuItem) { if let url = urlFromMenu(sender) { copyFile(url) } }
    @objc func menuCopyPath(_ sender: NSMenuItem) { if let url = urlFromMenu(sender) { copyPath(url) } }
    @objc func menuRename(_ sender: NSMenuItem) { if let url = urlFromMenu(sender) { renameFile(url) } }
    @objc func menuRate(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender) else { return }
        PhotoAnnotations.shared.setRating(sender.tag, for: url)
        if let photo = visiblePhotos.first(where: { $0.url == url }) { refreshAnnotationUI(for: photo) }
    }
    @objc func menuFavorite(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender), let photo = visiblePhotos.first(where: { $0.url == url }) else { return }
        toggleFavorite(photo)
    }
    @objc func menuDuplicate(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender) else { return }
        let parent = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var number = 1
        var target: URL
        repeat {
            let suffix = number == 1 ? " copy" : " copy \(number)"
            let fileName = base + suffix + (ext.isEmpty ? "" : "." + ext)
            target = parent.appendingPathComponent(fileName)
            number += 1
        } while FileManager.default.fileExists(atPath: target.path)
        let openedFolder = currentFolder
        performFileMutation({ try FileManager.default.copyItem(at: url, to: target) }) { [weak self] in
            PhotoAnnotations.shared.transfer(from: url, to: target, copy: true)
            if self?.currentFolder == openedFolder { self?.refreshCurrentFolder() }
        }
    }
    @objc func menuMove(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender) else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "移动到此文件夹"
        panel.directoryURL = url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let target = destination.appendingPathComponent(url.lastPathComponent)
        let openedFolder = currentFolder
        performFileMutation({ try FileManager.default.moveItem(at: url, to: target) }) { [weak self] in
            PhotoAnnotations.shared.transfer(from: url, to: target, copy: false)
            if self?.currentFolder == openedFolder { self?.refreshCurrentFolder() }
        }
    }
    @objc func menuTrash(_ sender: NSMenuItem) {
        guard let url = urlFromMenu(sender) else { return }
        let alert = NSAlert()
        alert.messageText = "将“\(url.lastPathComponent)”移到废纸篓？"
        alert.informativeText = "你可以在 Finder 中从废纸篓恢复。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let openedFolder = currentFolder
        performFileMutation({ try FileManager.default.trashItem(at: url, resultingItemURL: nil) }) { [weak self] in
            guard let self else { return }
            if self.currentFolder == openedFolder {
                if self.isPreview { self.backToGrid() }
                self.refreshCurrentFolder()
            }
        }
    }

    // MARK: Actions

    @objc func pathComponentClicked(_ sender: NSPathControl) {
        guard let component = sender.clickedPathItem, let url = component.url else { return }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            navigate(to: url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

}
