import Foundation
@main struct PhotoKeymapTests {
    static func main() {
        precondition(PhotoKeymap.step(for: 123) == -1)
        precondition(PhotoKeymap.step(for: 124) == 1)
        precondition(PhotoKeymap.step(for: 40) == -1)
        precondition(PhotoKeymap.step(for: 38) == 1)
        precondition(PhotoKeymap.step(for: 49) == nil)
        print("PASS 5 photo navigation keymap assertions")
    }
}
