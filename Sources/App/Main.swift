import AppKit

// Explicit entry point: no storyboard, nib, SwiftUI hosting view or web runtime.
// NSApplication.delegate is weak, so retain the delegate for the process lifetime.
@main
enum SwiftLensMain {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.run()
    }
}
