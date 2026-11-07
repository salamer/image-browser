# SwiftLens 0.9 — Code Review / Root Cause

## 1. 报错定性

### Confirmed: NSScrollView / FolderOutlineView zero-width Auto Layout

日志明确显示：侧边栏 `NSVisualEffectView.width == 0`；`NSScrollView` 被必需约束固定在父视图宽度；其内部 `NSClipView` 因传统垂直滚动条预留 17pt，出现无法同时满足的方程。旧实现同时把初始 `FolderOutlineView.frame.width` 设为 240，增加布局协商不确定性。

**处理**：抽出 `SidebarExplorerView`，不再给内部 `scroll` 添加必需的四边锚点约束。父视图通过当前 bounds 直接计算 frame；小于 42pt 宽或 24pt 内容高时隐藏 scroller / document，并在恢复正常大小时重新启用。`SidebarGeometry` 纯函数覆盖边界。仍需要 Mac 上把系统滚动条偏好设为 Always 做 GUI 回归。

### Window double click

旧 `BrowserToolbarView.mouseDown` 不区分单击和双击，始终调用 `performDrag`，导致在自定义 full-size titlebar 中不能可靠地进行非全屏 Zoom。新版双击调用系统 `zoom(nil)`，其 delegate 返回屏幕 `visibleFrame`，保留标准窗口 restore 行为。Apple 官方说明 `zoom(_:)` 是标准窗口状态与用户状态之间切换，不等同于 fullscreen。

### Preview resize

旧版 Fit 虽实时重新计算，但不考虑固定胶片栏，图片可能被永久显示的胶片栏遮挡。新增 `PreviewGeometry.usableRect`，将固定胶片栏的预留高度纳入 Fit；仅临时 Hover 出现时不改变布局，避免图像移动。手动 100% 和手动 Pan 的语义保持不变。窗口 resize 结束及 backing scale 改变后，再安排高质量解码，避免持续 resize 重复读完整图片。

### Thumbnail zooming

旧滑杆仅藏在配置中、`isContinuous=false`，菜单的 preset 每次 `reloadData`。现在变成可见水平 slider（窗口空间允许时），连续拖动、双指横滑，通过 layout invalidation 更新照片尺寸。180ms debounce 后仅重新配置 `indexPathsForVisibleItems()`，避免几千张图全量重建。

### Missing Dock icon

`Assets.xcassets/AppIcon` 原始就有文件和资源 phase；旧脚本只校验源文件，没有检查真实 `.app/Contents/Resources`。本版增加 bundle fallback 资源，启动时 `NSApp.applicationIconImage = icon`，以及 build gate 验证 `Assets.car`、`SwiftLensIcon.png` 和 Info.plist 的 `CFBundleIconName`。这能提高可诊断性，但 macOS Dock/LaunchServices 旧缓存是否生效必须实机检查。

## 2. 没有擅自“修复”的系统警告

- `com.apple.linkd.autoShortcut`：系统 XPC 连接问题，不能认定应用本身错误，工程未导入 AppIntents。不屏蔽。
- `_NSGlassEffectWindow canBecomeKeyWindow = NO`：系统渲染窗口，不等于应用主窗口；不能仅从日志猜测源头。
- `task_name_for_pid`：系统权限/调试服务可能出现，不能归咎于 SwiftLens。

## 3. 验证边界与风险

**已执行**：40 个 Swift 语法解析、OpenStep pbxproj 解析、资源引用检查、纯逻辑/布局测试（含 0×0 / 极窄 / Retina 相关 Fit / 侧栏 290 条断言）、ZIP 校验。

**未执行**：macOS `swiftc` AppKit 类型检查、Xcode `clean build`、签名与分发、macOS 图形界面的 window resize、sidebar scroll / icon appearance、M5 性能实测。新脚本在 Mac 上会对 full build 和 icon 打包失败直接报错。

## 4. 下一个架构债务

1. 数据目录索引仍适合引入 SQLite 与文件系统增量监听（FSEvents）。
2. 图片极大尺寸 / 动图 / WebP 解码可进一步做分格式专用处理与失败次数指标。
3. 工具栏 frame layout 便于避免 required-constraint 冲突，但需要 VoiceOver 与窗口缩放状态更细的 UI 测试。
4. `NSCollectionView` 大规模瀑布流仍应 Instruments 量测 layout invalidation 的 O(N) 时间。
