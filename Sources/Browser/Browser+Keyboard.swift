import AppKit

extension BrowserViewController {
    func handleKeyboard(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if flags == .command {
            switch event.keyCode {
            case 9: pasteIntoCurrentFolder(); return true          // ⌘V
            case 0: selectAllPhotos(); return true              // ⌘A (grid)
            case 33: navigateBack(); return true                 // ⌘[
            case 30: navigateForward(); return true             // ⌘] 
            case 126: navigateParent(); return true              // ⌘↑
            case 11: toggleSidebar(); return true                // ⌘B
            case 8: copySelectedFile(); return true               // ⌘C
            case 18: setGridMode(.waterfall); return true          // ⌘1
            case 19: setGridMode(.regular); return true            // ⌘2
            case 36: revealSelectedInFinder(); return true       // ⌘Return
            case 51: trashSelectedWithConfirmation(); return true // ⌘Delete
            default: return false // App menu owns ⌘O, ⌘F, ⌘R, ⌘+, ⌘-, ⌘0, ⌘D
            }
        }
        if flags == [.command, .shift] && event.keyCode == 45 {
            makeNewFolder(); return true                         // ⇧⌘N
        }
        if flags == [.command, .shift] && event.keyCode == 24 {
            showKeyboardShortcuts(); return true                 // ⇧⌘? (layout-dependent)
        }
        if flags == [.command, .shift] && event.keyCode == 8 {
            copySelectedPath(); return true                       // ⇧⌘C
        }
        if flags == .shift && event.charactersIgnoringModifiers == "/" {
            showKeyboardShortcuts(); return true                  // ?
        }
        if flags == .option {
            switch event.keyCode {
            case 123: navigateBack(); return true   // ⌥← (VS Code style)
            case 124: navigateForward(); return true // ⌥→
            default: return false
            }
        }
        if !flags.isEmpty { return false }
        if let step = PhotoKeymap.step(for: event.keyCode) {
            movePhoto(step)
            return true
        }
        switch event.keyCode {
        case 53: // Escape
            if isPreview { backToGrid(); return true }
            if !search.stringValue.isEmpty { clearFilters(); return true }
        case 49: // Space
            togglePreview(); return true
        case 36, 76: // Return / keypad Enter
            togglePreview(); return true
        case 125: if !isPreview { movePhoto(columnCount()); return true }  // ↓
        case 126: if !isPreview { movePhoto(-columnCount()); return true } // ↑
        case 116: // Page Up
            if !isPreview { movePhoto(-max(1, columnCount() * 3)); return true }
        case 121: // Page Down
            if !isPreview { movePhoto(max(1, columnCount() * 3)); return true }
        case 115: moveToEdge(first: true); return true             // Home
        case 119: moveToEdge(first: false); return true            // End
        case 48: // Tab: distraction-free preview (only in image view)
            if isPreview { toggleFocusMode(); return true }
        case 17: toggleFilmstrip(); return true                    // T
        case 6: toggleFitActualSize(); return true                 // Z
        case 120: // F2 (or fn + F2 on some Mac keyboards)
            if let photo = selectedPhoto() { renameFile(photo.url) }
            return true
        case 18, 19, 20, 21, 23, 29: // 1–5 or 0 rating
            let rating: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 29: 0]
            setSelectedRating(rating[event.keyCode] ?? 0)
            return true
        case 3: toggleSelectedFavorite(); return true            // F
        default: break
        }
        return false
    }

    func moveToEdge(first: Bool) {
        guard !visiblePhotos.isEmpty else { return }
        let destination = first ? 0 : visiblePhotos.count - 1
        if isPreview && !isComparing { openPreview(at: destination) }
        else if !isPreview {
            selectedIndex = destination
            grid.deselectAll(nil)
            grid.selectItems(at: [IndexPath(item: destination, section: 0)], scrollPosition: .centeredVertically)
        }
    }

    func trashSelectedWithConfirmation() {
        guard let photo = selectedPhoto() else { return }
        let fakeMenuItem = NSMenuItem()
        fakeMenuItem.representedObject = photo.url
        menuTrash(fakeMenuItem)
    }

    func columnCount() -> Int {
        let available = max(1, gridScroll.contentView.bounds.width - 36)
        return max(1, Int((available + 12) / (thumbnailWidth + 12)))
    }

    // MARK: File operations — intentionally a small VS Code / Finder-like menu


    func selectAllPhotos() {
        guard !isPreview else { return }
        guard !visiblePhotos.isEmpty else { return }
        grid.selectAll(nil)
        updateStatus()
    }
}
