import AppKit

/// Routes image-navigation keystrokes before AppKit's collection and toolbar
/// views consume them. Text editors and the sidebar retain native keyboard behavior.
final class BrowserWindow: NSWindow {
    weak var browser: BrowserViewController?

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isSidebarArrow = firstResponder is NSOutlineView &&
            modifiers.isEmpty && (event.keyCode == 123 || event.keyCode == 124 ||
                                  event.keyCode == 125 || event.keyCode == 126)
        if let browser,
           firstResponder as? NSTextView == nil,
           !isSidebarArrow,
           browser.handleKeyboard(event) { return }
        super.sendEvent(event)
    }
}
