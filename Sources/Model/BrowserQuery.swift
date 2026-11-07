import Foundation

/// Pure view-model logic; does not import AppKit and is unit-testable on Linux.
protocol BrowserAsset {
    var url: URL { get }
    var name: String { get }
    var size: Int64 { get }
    var modified: Date { get }
    var pixelWidth: Int { get }
    var pixelHeight: Int { get }
}

enum BrowserSort: Int, CaseIterable {
    case nameAscending = 0, nameDescending, modificationDescending, sizeDescending, pixelAreaDescending
}

struct BrowserFilter {
    var text: String = ""
    var minRating: Int = 0
    var favoritesOnly: Bool = false
}

enum BrowserQuery {
    static func sort<T: BrowserAsset>(_ items: [T], by sort: BrowserSort) -> [T] {
        items.sorted { a, b in
            let tieBreak = a.name.localizedStandardCompare(b.name) == .orderedAscending
            switch sort {
            case .nameAscending: return tieBreak
            case .nameDescending: return a.name.localizedStandardCompare(b.name) == .orderedDescending
            case .modificationDescending:
                return a.modified == b.modified ? tieBreak : a.modified > b.modified
            case .sizeDescending:
                return a.size == b.size ? tieBreak : a.size > b.size
            case .pixelAreaDescending:
                let aa = Double(a.pixelWidth) * Double(a.pixelHeight)
                let bb = Double(b.pixelWidth) * Double(b.pixelHeight)
                return aa == bb ? tieBreak : aa > bb
            }
        }
    }

    static func filter<T: BrowserAsset>(
        _ items: [T], using filter: BrowserFilter,
        annotation: (URL) -> (rating: Int, favorite: Bool)
    ) -> [T] {
        let term = filter.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            if !term.isEmpty && !item.name.localizedStandardContains(term) { return false }
            if filter.minRating == 0 && !filter.favoritesOnly { return true }
            let info = annotation(item.url)
            return info.rating >= filter.minRating && (!filter.favoritesOnly || info.favorite)
        }
    }
}
