import AppKit

/// Cached, column-balanced layout; only attributes near the viewport are returned.
/// This avoids O(number-of-photos) scans on every scroll event.
final class MasonryLayout: NSCollectionViewLayout {
    enum Mode { case waterfall, regular }
    var mode: Mode = .waterfall { didSet { invalidateLayout() } }
    var targetWidth: CGFloat = 205 { didSet { invalidateLayout() } }
    var photos: [PhotoFile] = [] { didSet { invalidateLayout() } }

    private let gutter: CGFloat = 12
    private let inset: CGFloat = 15
    private let bucketHeight: CGFloat = 400
    private var cachedAttributes: [NSCollectionViewLayoutAttributes] = []
    private var buckets: [Int: [Int]] = [:]
    private var contentSize = NSSize.zero
    private var preparedWidth: CGFloat = -1
    private var preparedCount: Int = -1

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let available = collectionView.bounds.width
        guard available > 1 else { return }
        guard preparedWidth != available || preparedCount != photos.count else { return }
        preparedWidth = available
        preparedCount = photos.count
        cachedAttributes.removeAll(keepingCapacity: true)
        buckets.removeAll(keepingCapacity: true)

        let cols = max(1, Int((available - 2 * inset + gutter) / (targetWidth + gutter)))
        let width = max(80, (available - 2 * inset - CGFloat(cols - 1) * gutter) / CGFloat(cols))
        var bottoms = [CGFloat](repeating: inset, count: cols)
        for (index, photo) in photos.enumerated() {
            let col: Int
            let pictureHeight: CGFloat
            if mode == .regular {
                col = index % cols
                pictureHeight = width * 0.77
            } else {
                col = bottoms.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
                pictureHeight = min(width * 1.75, max(width * 0.48, width / max(0.15, photo.aspectRatio)))
            }
            let itemHeight = pictureHeight + 44
            let frame = NSRect(x: inset + CGFloat(col) * (width + gutter), y: bottoms[col],
                               width: width, height: itemHeight)
            let attr = NSCollectionViewLayoutAttributes(forItemWith: IndexPath(item: index, section: 0))
            attr.frame = frame
            cachedAttributes.append(attr)
            let from = Int(floor(frame.minY / bucketHeight))
            let to = Int(floor(frame.maxY / bucketHeight))
            for bucket in from...to { buckets[bucket, default: []].append(index) }
            bottoms[col] += itemHeight + gutter
        }
        // Crucial: never use collectionView.bounds.height as a minimum here.
        // That height may equal an earlier (larger) document size. Including it
        // creates a feedback loop where the scroll range can never shrink.
        let occupied = photos.isEmpty ? 0 : (bottoms.max() ?? inset) - gutter + inset
        contentSize = NSSize(width: available, height: max(0, occupied))
    }

    override var collectionViewContentSize: NSSize { contentSize }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        guard !cachedAttributes.isEmpty else { return [] }
        let from = max(0, Int(floor(rect.minY / bucketHeight)))
        let to = max(from, Int(floor(rect.maxY / bucketHeight)))
        var seen = Set<Int>()
        var result: [NSCollectionViewLayoutAttributes] = []
        for bucket in from...to {
            for index in buckets[bucket] ?? [] where seen.insert(index).inserted {
                let attr = cachedAttributes[index]
                if attr.frame.intersects(rect) { result.append(attr) }
            }
        }
        return result
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        cachedAttributes.indices.contains(indexPath.item) ? cachedAttributes[indexPath.item] : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        abs((collectionView?.bounds.width ?? 0) - newBounds.width) > 0.5
    }

    override func invalidateLayout() {
        preparedWidth = -1
        preparedCount = -1
        super.invalidateLayout()
    }
}
