import AppKit

extension BrowserViewController {
    func handlePreviewMouse(_ position: NSPoint?) {
        guard isPreview, !isComparing else { return }
        let lowerArea = position.map { $0.y < 165 } ?? false
        previewHUD.alphaValue = lowerArea ? 1 : 0.32
        previewCaption.alphaValue = (position.map { $0.y > previewPanel.bounds.height - 110 } ?? false) ? 0.95 : 0.55
        guard !filmstripPinned else { return }
        guard let position else { scheduleFilmstripHide(); return }
        // PreviewMousePanel uses bottom-left coordinates. The bottom zone also
        // covers a visible filmstrip so the strip stays usable while scrolling.
        if position.y < 150 {
            showFilmstrip()
        } else {
            scheduleFilmstripHide()
        }
    }

    func showFilmstrip() {
        guard isPreview, !isComparing else { return }
        filmstripHideWork?.cancel()
        filmstripHideWork = nil
        if filmstripVisible { return }
        filmstripVisible = true
        filmstrip.isHidden = false
        filmstrip.alphaValue = 1
        previewPanel.showsFilmstrip = true
        filmstrip.layoutSubtreeIfNeeded()
        filmstrip.centerCurrent()
    }

    func scheduleFilmstripHide() {
        filmstripHideWork?.cancel()
        guard filmstripVisible, !filmstripPinned else { return }
        let task = DispatchWorkItem { [weak self] in
            guard let self, !self.filmstripPinned else { return }
            self.hideFilmstrip()
        }
        filmstripHideWork = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: task)
    }

    func hideFilmstrip() {
        filmstripHideWork?.cancel()
        filmstripHideWork = nil
        filmstripVisible = false
        filmstrip.isHidden = true
        previewPanel.showsFilmstrip = false
    }

    func toggleFilmstrip() {
        guard isPreview, !isComparing else { return }
        filmstripPinned.toggle()
        adaptivePreview.pinnedFilmstrip = filmstripPinned
        if filmstripPinned { showFilmstrip() }
        else { hideFilmstrip() }
    }

    @objc func toggleFilmstripAction() { toggleFilmstrip() }

}
