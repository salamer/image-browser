# macOS M5 Acceptance Checklist — SwiftLens 0.9

1. **原生构建门禁**：在项目根目录运行 `bash Scripts/verify_macos_build.sh`，必须出现 `PASS full macOS arm64 AppKit build + bundled AppIcon metadata and fallback PNG`，不能只运行 Swift 语法解析。
2. **主窗口 Zoom**：双击工具栏空白区域 → 最大化到菜单栏 / Dock 以内；再次双击 → 恢复先前尺寸。绿色全屏按钮仍应走系统全屏而非双击 Zoom。
3. **侧栏零宽度**：连续 `⌘B` 十次；每次完全折叠/恢复，在 Xcode Console 不应有 `FolderOutlineView` / `NSClipView` 宽度与滚动条冲突。拖窄/变宽窗口再重复。特别检查系统滚动条设成“始终显示”时是否仍无约束异常。
4. **目录树**：展开 200+ 子目录，滚动到末尾、关闭再展开；侧栏高度变化时内容不应为空、剪裁或卡在 0 高度。
5. **图片 Fit**：浏览横图、竖图、超长图、正方形；窗口从 1600×1000 拖到最小再恢复；应居中不裁剪（Fit 模式），窗口 resize 不应突然跳至 100%。
6. **固定胶片栏**：预览按 T 固定；图片重新适配以避免被下方长期显示的胶片栏盖住。非固定情况下只把鼠标移到底边，主图不应跳动。
7. **缩略图尺寸**：网格模式右上方滑杆从 100→420pt 反复拖动；触控板在滑杆上横向滑动也能改变尺寸。图片不会滚回目录顶部，选中项保留。窄窗口滑杆收起后，视图菜单的三档仍可使用。
8. **Dock 图标**：用运行生成的 `.app` 启动，Dock 应使用 `SwiftLensIcon` 而非默认白纸；实际可通过 `plutil -p <APP>/Contents/Info.plist` 确认 `CFBundleIconName`，`Resources/Assets.car` 和 `Resources/SwiftLensIcon.png` 两文件都应存在。
9. **系统服务日志**：记录 `com.apple.linkd.autoShortcut` 是否仍出现；如果出现但是所有文件操作正常，不把它当作 SwiftLens 布局冲突；如果伴随崩溃则附带完整 crash report、macOS 版本、触发操作重新分析。
