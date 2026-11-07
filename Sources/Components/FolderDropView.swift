import AppKit

/// Accept a Finder folder or image dragged anywhere into the application window.
final class FolderDropView: NSView {
    var onFolderDrop: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view only") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        candidateFolder(from: sender) == nil ? [] : .copy
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        candidateFolder(from: sender) != nil
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = candidateFolder(from: sender) else { return false }
        onFolderDrop?(url)
        return true
    }

    private func candidateFolder(from dragging: NSDraggingInfo) -> URL? {
        guard let first = dragging.draggingPasteboard.pasteboardItems?.first,
              let urlString = first.string(forType: .fileURL),
              let url = URL(string: urlString), url.isFileURL else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }
}
