import AppKit

/// Context menus follow the folder under the pointer, not the previously selected row.
final class FolderOutlineView: NSOutlineView {
    var contextMenuForRow: ((Int) -> NSMenu?)?
    private(set) var isSelectingContextItem = false

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let target = row(at: point)
        if target >= 0 {
            isSelectingContextItem = true
            selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
            isSelectingContextItem = false
        }
        return contextMenuForRow?(target) ?? super.menu(for: event)
    }
}
