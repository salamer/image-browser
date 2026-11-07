import Foundation

private struct SampleAsset: BrowserAsset {
    let url: URL
    let name: String
    let size: Int64
    let modified: Date
    let pixelWidth: Int
    let pixelHeight: Int

    init(_ name: String, size: Int64 = 0, day: TimeInterval = 0, w: Int = 1, h: Int = 1) {
        self.url = URL(fileURLWithPath: "/tmp/" + name)
        self.name = name
        self.size = size
        self.modified = Date(timeIntervalSince1970: day)
        self.pixelWidth = w
        self.pixelHeight = h
    }
}

@main
struct BrowserQueryTests {
    static func main() {
        var passed = 0
        func test(_ name: String, _ condition: @autoclosure () -> Bool) {
            precondition(condition(), "FAILED: \(name)")
            passed += 1
            print("PASS \(name)")
        }
        let items = [SampleAsset("image10.webp", size: 32, day: 20, w: 10, h: 5),
                     SampleAsset("image2.jpg", size: 64, day: 10, w: 15, h: 10),
                     SampleAsset("image1.png", size: 48, day: 30, w: 2, h: 2)]
        test("natural numeric name order", BrowserQuery.sort(items, by: .nameAscending).map(\.name) == ["image1.png", "image2.jpg", "image10.webp"])
        test("name descending", BrowserQuery.sort(items, by: .nameDescending).first?.name == "image10.webp")
        test("modified descending", BrowserQuery.sort(items, by: .modificationDescending).first?.name == "image1.png")
        test("size descending", BrowserQuery.sort(items, by: .sizeDescending).first?.name == "image2.jpg")
        test("pixel area descending", BrowserQuery.sort(items, by: .pixelAreaDescending).first?.name == "image2.jpg")
        test("case-insensitive search", BrowserQuery.filter(items, using: BrowserFilter(text: "IMAGE2"), annotation: { _ in (0,false) }).count == 1)
        test("whitespace search normalization", BrowserQuery.filter(items, using: BrowserFilter(text: "  image10  "), annotation: { _ in (0,false) }).first?.name == "image10.webp")
        test("no filters", BrowserQuery.filter(items, using: BrowserFilter(), annotation: { _ in (0,false) }).count == 3)
        test("rating threshold", BrowserQuery.filter(items, using: BrowserFilter(minRating: 4), annotation: { ($0.pathExtension == "jpg" ? 5 : 3, false) }).map(\.name) == ["image2.jpg"])
        test("favorites only", BrowserQuery.filter(items, using: BrowserFilter(favoritesOnly: true), annotation: { ($0.pathExtension == "jpg" ? 1 : 0, $0.pathExtension == "webp") }).map(\.name) == ["image10.webp"])
        test("rating AND favorite", BrowserQuery.filter(items, using: BrowserFilter(minRating: 3, favoritesOnly: true), annotation: { ($0.pathExtension == "webp" ? 4 : 2, $0.pathExtension == "webp") }).map(\.name) == ["image10.webp"])
        test("filter excludes everything", BrowserQuery.filter(items, using: BrowserFilter(text: "missing"), annotation: { _ in (0,false) }).isEmpty)
        let tie = [SampleAsset("b.jpg", size: 4), SampleAsset("a.jpg", size: 4)]
        test("stable deterministic tie break", BrowserQuery.sort(tie, by: .sizeDescending).map(\.name) == ["a.jpg", "b.jpg"])
        print("\(passed) BrowserQuery tests passed")
    }
}
