# SwiftLens 0.7 · Code Review

## 已改的根因（不是只改按钮）

1. **侧边栏折叠无效**：0.6.1 调用 `sidebar.isHidden.toggle()`，但 NSSplitView 的 arranged-subview 实际仍占宽。0.7 使用分割线位置 `setPosition(0, ofDividerAt: 0)` 并让 `NSSplitViewDelegate` 在折叠时允许最小坐标为 0；展开恢复用户拖动的宽度。
2. **顶栏两行并且有布局警告**：删除原 78pt 的上下两段 Auto Layout 栈和固定搜索框宽度，改 `BrowserToolbarView` 在自己的 `layout()` 中计算一行位置；排序/筛选存在溢出菜单，窄窗隐藏非核心控件。免除强制约束冲突。
3. **事件路由不稳定**：删除 `NSEvent.addLocalMonitorForEvents`（不应该由单个 ViewController 拦截所有窗口输入）；改由 `BrowserWindow.sendEvent` 只拦截当前窗口的按键。明确保护 `NSTextView` 输入、侧栏箭头、Command 菜单；退出/进入预览重置 First Responder。
4. **底部工具栏挤压图片**：沿用无内部固定约束的 `PreviewHUDView`，随窗口宽度自动隐藏低优先级按钮；胶片栏默认仅鼠标靠近底部时覆盖显示。
5. **图片区域不够沉浸**：Preview Fit 在所有方向保留约 14pt 余量，避免贴边；图片外添加微弱阴影，但不改变图像像素。新增 `Tab` 专注模式。
6. **没有正式图标**：生成 10 个 PNG AppIcon 资源、配置 Asset Catalog Build Phase、生成脚本和静态资源检查双向校验。
7. **上版验证脚本本身损坏**：旧 `verify_macos_build.sh` 中的 `xcodebuild \n` 是字面量，不是 bash 续行。0.7 改为真正反斜杠换行；静态测试检查脚本语法和构建阶段。

## 当前架构边界

- `BrowserViewController` 仍负责跨功能协调，按 extension 拆成命令/预览/文件/数据源等；浏览状态和 UI 尚未彻底独立成可注入 Store。大规模重构应在 Mac 端通过编译/回归后进行，避免凭空添加未验证的跨模块接口。
- 缩略图处理/缓存、目录扫描和评分保存已有专门 Service/Model，不将 I/O 放到 AppKit cell 内执行。
- `BrowserToolbarView` 使用 frame 布局处理固定高度、可变宽度条带；正文仍由约束布局分割、Grid 虚拟复用。避免混用 fixed width 与父视图 0 宽时的约束竞争。

## 尚未完成（不得宣称超过 MediaOne）

- 完整的 macOS typecheck、M5 运行/屏幕录制和真实 benchmark；当前环境没有 Apple SDK。
- 更精细的文件树多根工作区保存、动态文件监控 / FSEvents、海量图片持久化索引、非图片资产导入、复杂批量处理、完整 Undo/Redo、视频/HEIC/动画兼容性矩阵。
- 10 万张以上文件的扫描吞吐、滚动丢帧和高 DPI 大图 Metal 分块渲染仍需要 Instruments 基准测试。
