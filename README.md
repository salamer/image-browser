# SwiftLens 0.9 — Window, Sidebar & App Icon Reliability

Swift / AppKit / ImageIO 原生 macOS 图片浏览器。Xcode 工程与所有源文件均在本 ZIP 中，支持 Apple Silicon arm64 构建。

> **验证边界**：当前交付已执行 Swift 语法解析、pbxproj 格式和文件引用检查、纯 Foundation 几何/缓存/筛选测试及 ZIP 校验；**尚未完成 macOS SDK 下的 Xcode 编译和 GUI 实测**。这不等于已验证可运行的安装包。

## 在 M5 Mac 上开始

1. 打开项目根目录中的 `SwiftLens.xcodeproj`，在 Xcode 中选择 My Mac，按 `⌘R`。
2. 或先在终端运行 `bash Scripts/verify_macos_build.sh`，进行 **真正的 arm64 clean build**，并检验构建产物的 `Assets.car`、`CFBundleIconName=AppIcon` 及 `SwiftLensIcon.png`。
3. `⌘O` 打开图片文件夹；双击图片预览；`← →` 翻页；`Space` 或 `Esc` 返回；`⌘B` 收起侧栏。
4. **双击上方工具栏的空白处**执行 macOS Zoom（最大化至屏幕可用范围，并可再次双击恢复），不是进入全屏。
5. 在图片网格模式的顶部右侧水平拖动缩略图尺寸滑杆，也可以将光标悬停在滑杆上后用触控板**双指左右滑动**调整。窄窗口会把滑杆收起，仍可从“视图与筛选”菜单选择三档大小。

## 0.9 具体修复

- **SidebarExplorerView**：侧栏 NSScrollView 改为由父容器管理 frame；零宽度时暂时关闭滚动条，不再以必需锚点约束强行将容纳滚动条的 NSClipView 挤成 0。展开后恢复滚动与目录行的尺寸。布局逻辑提取到独立可测试 `SidebarGeometry`。
- **Window Zoom**：标题栏空白区域双击调用 `NSWindow.zoom(nil)`；窗口 delegate 返回 `screen.visibleFrame`，切换到非全屏最大化并可恢复先前窗口大小。
- **Resize**：继续按实时视口重算图片 Fit，监听窗口 live-resize 结束和 Retina backing 变化；固定胶片栏预留布局空间，临时 Hover 胶片栏不挪动主图。
- **ThumbnailSizeSlider**：水平滑杆连续调整（100–420pt），增加双指横向滚动支持。拖动时只更新布局，停止动作约 180ms 后刷新**可见**缩略图解码，不整页重建；尺寸保存到偏好设置。
- **App Icon**：同时保留 AppIcon Asset Catalog 和可运行时加载的 `SwiftLensIcon.png`；生成的 Info.plist 明确写 `CFBundleIconName=AppIcon`，构建验证脚本检查实际 `.app` 资源。

## 关于你看到的日志

`NSScrollView` / `FolderOutlineView` / 17pt 传统滚动条的 Auto Layout 冲突是本版明确针对的应用代码问题。

`com.apple.linkd.autoShortcut` / `AppIntents framework` 的 NSCocoaErrorDomain 4097 连接失败来自 macOS 系统服务。工程**没有使用 AppIntents API**，仅凭这些日志不能确定是 SwiftLens 触发或能够在 SwiftLens 中修复。没有屏蔽日志；若所有功能正常，可优先观察是否为系统级非致命警告。`_NSGlassEffectWindow` 调用 makeKeyWindow 的警告也不能仅凭日志确定原因。

## 工程结构

```text
Sources/App/        启动、macOS window、键盘事件
Sources/Browser/    目录导航、图片选择、预览、过滤、文件管理、工具栏动作
Sources/Components/ 可复用 UI / 侧栏滚动容器 / 缩略图大小滑杆
Sources/Model/      纯逻辑布局几何、排序、键盘映射、图片元数据
Sources/Services/   文件扫描、ImageIO/QuickLook、缩略图缓存
Resources/          AppIcon.xcassets + SwiftLensIcon.png
Tests/              不依赖 AppKit 的回归测试
Scripts/            生成 Xcode 项目 / 测试 / 完整 Mac 构建验证
Docs/               逐项 Code Review / M5 实机验收清单
```

## 验证

- Linux 可跑：`python3 Scripts/verify_source.py`、`bash Scripts/run_linux_tests.sh`。
- 必须在 Mac 上跑：`bash Scripts/verify_macos_build.sh`（arm64 full build + asset packaging gate）。
- GUI 验收：见 `Docs/MAC_QA_0.9.md`。

不是已证明超过 MediaOne 的正式产品；仍需 M5 编译与实际性能/键鼠/缩放验证。
