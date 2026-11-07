import AppKit

/// Lightweight floating preview controls. Intrinsic fixed-size stack constraints
/// were responsible for the 0.5 warnings whenever the window briefly had width 0.
/// Controls are simply laid out in frames; optional actions disappear when narrow.
final class PreviewHUDView: NSVisualEffectView {
    struct Control {
        let view: NSView
        let width: CGFloat
        let priority: Int // 0 = always visible, 1 = medium, 2 = roomy
    }
    private var controls: [Control] = []
    private let gap: CGFloat = 6

    func install(_ controls: [Control]) {
        self.controls.forEach { $0.view.removeFromSuperview() }
        self.controls = controls
        controls.forEach {
            $0.view.translatesAutoresizingMaskIntoConstraints = true
            addSubview($0.view)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard !controls.isEmpty else { return }
        let room = max(0, bounds.width - 20)
        var maxPriority = 2
        while maxPriority > 0 {
            let active = controls.filter { $0.priority <= maxPriority }
            let required = active.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(max(0, active.count - 1)) * gap
            if required <= room { break }
            maxPriority -= 1
        }
        var active = controls.filter { $0.priority <= maxPriority }
        func widthNeeded(_ values: [Control]) -> CGFloat {
            values.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(max(0, values.count - 1)) * gap
        }
        while !active.isEmpty && widthNeeded(active) > room {
            active.removeLast()
        }
        let required = widthNeeded(active)
        var x = max(0, (bounds.width - required) / 2)
        for entry in controls { entry.view.isHidden = !active.contains { $0.view === entry.view } }
        let controlHeight = min(30, max(0, bounds.height))
        for entry in active {
            entry.view.frame = NSRect(x: x, y: max(0, (bounds.height - controlHeight) / 2),
                                      width: entry.width, height: controlHeight)
            x += entry.width + gap
        }
    }
}
