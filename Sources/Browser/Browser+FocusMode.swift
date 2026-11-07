import AppKit

extension BrowserViewController {
    /// Tab toggles a distraction-free canvas, leaving standard macOS window
    /// controls available. Returns to the original sidebar state on exit.
    func toggleFocusMode() {
        guard isPreview else { return }
        isFocusMode.toggle()
        if isFocusMode {
            focusRestoresSidebar = !sidebarCollapsed
            if focusRestoresSidebar { toggleSidebar() }
            toolbarHeightConstraint?.constant = 0
            toolbar.isHidden = true
        } else {
            toolbar.isHidden = false
            toolbarHeightConstraint?.constant = 48
            if focusRestoresSidebar && sidebarCollapsed { toggleSidebar() }
            focusRestoresSidebar = false
        }
        view.needsLayout = true
        adaptivePreview.refreshViewport()
        view.window?.makeFirstResponder(adaptivePreview)
    }
}
