import Foundation

/// Pure, testable geometry for temporary zero-sized AppKit parents.
/// All child rectangles are finite, nonnegative, and contained in their parent.
/// No layout priority games or required intrinsic-size constraints.
struct ChromeGeometry {
    struct PreviewFrames {
        let caption: CGRect
        let hud: CGRect
        let filmstrip: CGRect
        let leftCompare: CGRect
        let rightCompare: CGRect
    }

    struct EmptyFrames {
        let icon: CGRect
        let title: CGRect
        let subtitle: CGRect
        let open: CGRect
        let help: CGRect
        let tips: CGRect
    }

    private static func dimension(_ v: CGFloat) -> CGFloat {
        v.isFinite ? max(0, v) : 0
    }

    static func preview(_ viewport: CGSize, showFilmstrip: Bool) -> PreviewFrames {
        let w = dimension(viewport.width)
        let h = dimension(viewport.height)
        let gap = min(3, w)
        let half = (w - gap) / 2

        let filmMargin = min(14, w / 2)
        let stripWidth = max(0, w - filmMargin * 2)
        let stripHeight = min(110, max(0, h - 24))
        let filmY = min(12, max(0, h - stripHeight))

        let hudWidth = min(474, max(0, w - 24))
        let hudHeight = min(46, h)
        let desiredBottom: CGFloat = showFilmstrip ? 136 : 16
        let hudBottom = min(desiredBottom, max(0, h - hudHeight))

        let captionMargin = min(18, w / 2)
        let captionWidth = min(460, max(0, w - captionMargin * 2))
        let captionHeight = min(54, h)
        let captionTopMargin = min(16, max(0, h - captionHeight))

        return PreviewFrames(
            caption: CGRect(x: captionMargin, y: max(0, h - captionHeight - captionTopMargin),
                            width: captionWidth, height: captionHeight),
            hud: CGRect(x: (w - hudWidth) / 2, y: hudBottom, width: hudWidth, height: hudHeight),
            filmstrip: CGRect(x: filmMargin, y: filmY, width: stripWidth, height: stripHeight),
            leftCompare: CGRect(x: 0, y: 0, width: half, height: h),
            rightCompare: CGRect(x: half + gap, y: 0, width: half, height: h)
        )
    }

    static func empty(_ viewport: CGSize) -> EmptyFrames {
        let w = dimension(viewport.width)
        let h = dimension(viewport.height)
        let none = CGRect.zero
        guard w >= 140, h >= 110 else {
            return EmptyFrames(icon: none, title: none, subtitle: none,
                               open: none, help: none, tips: none)
        }
        let contentW = min(480, max(0, w - 24))
        let x = (w - contentW) / 2
        let center = h / 2
        let full = h >= 410
        let medium = h >= 245
        let iconRect = full ? CGRect(x: (w - 72) / 2, y: center + 76, width: 72, height: 54) : none
        let titleRect = CGRect(x: x, y: min(h - 31, center + (full ? 36 : medium ? 48 : 14)),
                               width: contentW, height: 29)
        let subtitleRect = medium ? CGRect(x: x, y: max(0, center - (full ? 26 : 12)),
                                            width: contentW, height: 49) : none
        let buttonWidth = min(198, contentW)
        let showHelp = contentW >= 330 && medium
        let buttonY = max(0, center - (full ? 90 : medium ? 81 : 32))
        let openX = showHelp ? x + (contentW - buttonWidth - 140 - 12) / 2 : (w - buttonWidth) / 2
        let openRect = CGRect(x: max(0, openX), y: buttonY, width: buttonWidth, height: 34)
        let helpRect = showHelp ? CGRect(x: max(0, openX) + buttonWidth + 12, y: buttonY,
                                         width: 140, height: 34) : none
        let tipsRect = full ? CGRect(x: x, y: max(0, center - 154), width: contentW, height: 40) : none
        return EmptyFrames(icon: iconRect, title: titleRect, subtitle: subtitleRect,
                           open: openRect, help: helpRect, tips: tipsRect)
    }
}
