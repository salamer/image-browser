import AppKit

/// Sidebar chrome owns the scroll view frame rather than pinning an NSScrollView
/// with four required constraints. NSScrollView may temporarily need 17 points
/// for a legacy scroller while NSSplitView offers zero width during startup or
/// collapse. We never create impossible zero-width required equations.
final class SidebarExplorerView: NSVisualEffectView {
    weak var outlineScrollView: NSScrollView?
    var headerHeight: CGFloat = 44

    override func layout() {
        super.layout()
        guard let scroll = outlineScrollView else { return }
        let newFrame = SidebarGeometry.scrollRect(container: bounds.size, header: headerHeight)
        let usable = SidebarGeometry.canShowScroller(in: newFrame)
        if !usable && scroll.hasVerticalScroller { scroll.hasVerticalScroller = false }
        scroll.isHidden = !usable
        if scroll.frame != newFrame { scroll.frame = newFrame }
        if usable && !scroll.hasVerticalScroller { scroll.hasVerticalScroller = true }
        if usable, let outline = scroll.documentView as? NSOutlineView {
            let clipWidth = max(0, scroll.contentView.bounds.width)
            let expectedHeight = max(scroll.contentView.bounds.height,
                                     CGFloat(outline.numberOfRows) * outline.rowHeight + 12)
            if abs(outline.frame.width - clipWidth) > 0.5 ||
                outline.frame.height + 0.5 < expectedHeight {
                outline.setFrameSize(NSSize(width: clipWidth, height: expectedHeight))
            }
        }
    }
}
