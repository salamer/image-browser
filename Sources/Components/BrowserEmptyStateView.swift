import AppKit

/// Onboarding and empty-state UI, including when the window is still 0×0 during
/// AppKit's first layout pass. Frame geometry deliberately avoids intrinsic-size
/// stack constraints that cannot be satisfied in a zero-width parent.
final class BrowserEmptyStateView: NSView {
    enum Mode { case welcome, emptyFolder, noResults, loading }

    var onOpenFolder: (() -> Void)?
    var onShowShortcuts: (() -> Void)?
    var onClearFilters: (() -> Void)?

    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(wrappingLabelWithString: "")
    private let open = NSButton(title: "打开图片文件夹", target: nil, action: nil)
    private let help = NSButton(title: "查看键盘快捷键", target: nil, action: nil)
    private let tips = NSTextField(wrappingLabelWithString: "")
    private var mode = Mode.welcome

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.125, alpha: 1).cgColor
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .secondaryLabelColor
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        title.alignment = .center
        title.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.maximumNumberOfLines = 3
        tips.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tips.textColor = .tertiaryLabelColor
        tips.alignment = .center
        tips.maximumNumberOfLines = 4
        tips.stringValue = "双击 / 空格 预览   ← → 翻页   ⌘F 搜索\n1–5 评分   F 收藏   T 胶片栏   ? 快捷键"
        open.bezelStyle = .rounded
        open.target = self
        open.action = #selector(openClicked)
        help.bezelStyle = .rounded
        help.target = self
        help.action = #selector(helpClicked)
        for child in [icon, title, subtitle, open, help, tips] {
            child.translatesAutoresizingMaskIntoConstraints = true
            addSubview(child)
        }
        configure(.welcome)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic only") }

    override func layout() {
        super.layout()
        let f = ChromeGeometry.empty(bounds.size)
        icon.frame = f.icon
        title.frame = f.title
        subtitle.frame = f.subtitle
        open.frame = f.open
        help.frame = f.help
        tips.frame = f.tips
        icon.isHidden = f.icon.isEmpty
        title.isHidden = f.title.isEmpty
        subtitle.isHidden = f.subtitle.isEmpty
        open.isHidden = f.open.isEmpty
        help.isHidden = f.help.isEmpty
        tips.isHidden = f.tips.isEmpty
    }

    func configure(_ newMode: Mode) {
        mode = newMode
        switch mode {
        case .welcome:
            icon.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)
            title.stringValue = "欢迎使用 SwiftLens"
            subtitle.stringValue = "拖入图片文件夹，或点击下方按钮开始。原始图片不会被修改。"
            open.title = "打开图片文件夹…"
        case .emptyFolder:
            icon.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)
            title.stringValue = "这个文件夹还没有图片"
            subtitle.stringValue = "支持 JPG、PNG、HEIC、WebP 等格式；也可以开启包含子目录。"
            open.title = "选择其他文件夹…"
        case .noResults:
            icon.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: nil)
            title.stringValue = "没有符合条件的图片"
            subtitle.stringValue = "可以清除搜索、星级或收藏条件。"
            open.title = "清除筛选条件"
        case .loading:
            icon.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)
            title.stringValue = "正在发现图片…"
            subtitle.stringValue = "目录扫描和尺寸读取正在后台进行。"
            open.title = "打开其他目录…"
        }
        needsLayout = true
    }

    @objc private func openClicked() {
        if case .noResults = mode { onClearFilters?() } else { onOpenFolder?() }
    }
    @objc private func helpClicked() { onShowShortcuts?() }
}
