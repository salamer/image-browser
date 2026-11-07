import Foundation

/// Raw macOS virtual-key codes for image navigation. Kept separate from AppKit
/// so switching the preview's first responder does not change their meaning.
enum PhotoKeymap {
    static func step(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 123, 40: return -1  // left arrow / K
        case 124, 38: return 1   // right arrow / J
        default: return nil
        }
    }
}
