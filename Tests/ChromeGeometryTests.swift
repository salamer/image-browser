import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

func within(_ rect: CGRect, _ size: CGSize) -> Bool {
    [rect.minX, rect.minY, rect.width, rect.height].allSatisfy { $0.isFinite } &&
    rect.minX >= -0.001 && rect.minY >= -0.001 &&
    rect.width >= 0 && rect.height >= 0 &&
    rect.maxX <= max(0, size.width) + 0.001 &&
    rect.maxY <= max(0, size.height) + 0.001
}

@main
enum ChromeGeometryTests {
    static func main() {
        let viewports: [CGSize] = [
            .zero, CGSize(width: 0, height: 700), CGSize(width: 1500, height: 0),
            CGSize(width: 1, height: 1), CGSize(width: 14, height: 14),
            CGSize(width: 100, height: 40), CGSize(width: 180, height: 110),
            CGSize(width: 290, height: 200), CGSize(width: 360, height: 280),
            CGSize(width: 480, height: 330), CGSize(width: 800, height: 450),
            CGSize(width: 1440, height: 900), CGSize(width: 3440, height: 1440),
            CGSize(width: -3, height: 100),
        ]
        var count = 0
        for size in viewports {
            let limit = CGSize(width: max(0, size.width), height: max(0, size.height))
            for visible in [false, true] {
                let f = ChromeGeometry.preview(size, showFilmstrip: visible)
                for r in [f.caption, f.hud, f.filmstrip, f.leftCompare, f.rightCompare] {
                    check(within(r, limit), "Preview rectangle escapes viewport \(size): \(r)")
                    count += 1
                }
                check(abs(f.leftCompare.maxX + min(3, limit.width) - f.rightCompare.minX) < 0.01,
                      "Compare gap wrong \(size)")
                count += 1
            }
            let f = ChromeGeometry.empty(size)
            for r in [f.icon, f.title, f.subtitle, f.open, f.help, f.tips] {
                check(within(r, limit), "Empty-state rectangle escapes viewport \(size): \(r)")
                count += 1
            }
        }
        let large = CGSize(width: 1100, height: 760)
        check(ChromeGeometry.preview(large, showFilmstrip: true).hud.minY >
              ChromeGeometry.preview(large, showFilmstrip: false).hud.minY, "Filmstrip must raise HUD")
        count += 1
        for size in [CGSize(width: CGFloat.nan, height: 200), CGSize(width: CGFloat.infinity, height: 100)] {
            let f = ChromeGeometry.preview(size, showFilmstrip: false)
            check(f.hud.width == 0 && f.filmstrip.width == 0, "invalid input must collapse to zero")
            count += 1
        }
        print("PASS ChromeGeometry: \(count) containment/zero-size/adaptive checks")
    }
}
