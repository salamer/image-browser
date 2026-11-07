# SwiftLens 0.8 · Runtime error review / 运行日志审查

输入：2026-11-07 上传的 AppKit 运行日志。**这份日志对应较早版本，不应据此断言当前构建一定产生同样问题。**

## 1. 确定性根因：暂时为零尺寸的父视图

日志多次出现 `NSAutoresizingMaskLayoutConstraint ... NSView.width == 0` 或 `height == 0`。这本身不是 bug：AppKit 在窗口首次附着、分栏切换和视图生命周期中可能出现临时的零尺寸。问题是子视图在此时仍要求必需宽度、间距或四周内边距。

| 日志中的视图 | 产生冲突的约束组合 | 0.8 处理 |
|---|---|---|
| `BrowserEmptyStateView` | 内层 `NSStackView` 居中 + 固定 72pt 图片图标 + 左右/上下最小边距，无法放入 0×0 父视图 | 去掉内部 Auto Layout stack，使用 `ChromeGeometry.empty` 布局；极小尺寸隐藏非必要内容 |
| `PreviewMousePanel` | 胶片栏要求左右各 14pt 边距，HUD / 标题浮层又有固定宽高 | 所有预览浮层改由 `PreviewMousePanel.layout()` 根据实时尺寸排版，父视图为 0 时子矩形宽高也为 0 |
| 双图比较 | 左右图片相等宽度 + 固定 3pt 间隔；父视图为 0 时无可行解 | 新建 `CompareImageHost`，两侧图片在 `layout()` 中用可收缩间距和非负宽度摆放 |
| 悬浮 HUD 内部 | 旧版控件有不可压缩宽度；窗口极窄时可能溢出 | 保留无约束的手工定位，宽度不足时逐项隐藏，控件高度也按窗口高度压缩 |
| 顶部工具栏 | 小窗口时控件可能相互覆盖 | 左侧/右侧工具按钮基于可用宽度隐藏，保留单行，不强制第二行 |

**重要：** 不能只降低约束 priority 来消除控制台警告。应消除无解约束组合。

## 2. WebP 解码失败与 Quick Look

日志中的 `CGImageSourceCreateImageAtIndex` / `WEBP` 失败来自系统 ImageIO 对特定文件的解码路径。单凭日志无法判断文件损坏、编码特性不兼容还是系统框架问题。旧代码会在图片重试时再次触发同样路径。

0.8 在 ImageIO（WebP 特殊处理）与 Quick Look 回退阶段分别加入 **75 秒短期失败抑制**。失败键包含完整文件路径、文件大小与修改时间（Quick Look 另含请求的尺寸），因此：

- 同一个失败文件不会因快速滚动而无限制重复触发昂贵解码或系统服务；
- 文件被修改之后立刻允许重新尝试；
- 到期之后允许重新尝试，不把暂时不可读永久标记为损坏；
- 失败缓存是锁保护且容量受限的，不需要向图片文件写入任何数据。

**这不等于所有 WebP 格式都能成功解码。** 若系统 ImageIO 和 Quick Look 都无法读取，当前版本只会保留占位图；未来若要做到更广泛兼容，应引入经安全审计的 WebP 解码库并增加测试素材集。

## 3. 不能直接归因于 App 的日志

- `com.apple.linkd.autoShortcut` / AppIntents `NSCocoaErrorDomain Code=4097`：属于系统服务连接失败；日志未证明是 SwiftLens UI 代码产生，也不能据此认定应用崩溃。
- `NSXPCDecoder validateAllowedClass`：系统或相关 XPC 服务的解码安全警告。需要堆栈与来源才可确定，不能通过忽略它来证明无问题。
- `ViewBridge ... Terminated` 和 `AppKit._NSGlassEffectWindow makeKeyWindow`：需结合是否出现真实 UI 异常判断。应用自身没有直接创建此类私有窗口。

## 4. 本轮确实完成的检查

- `python3 Scripts/generate_project.py`：37 个源文件准确进入 Xcode project；
- `python3 Scripts/verify_source.py`：OpenStep 工程格式、Swift **语法解析**、资源引用与构建脚本检查；
- `bash Scripts/run_linux_tests.sh`：排序/筛选、图像几何、键盘映射、缓存清理、极小窗口几何 255 项检查、失败缓存并发测试；
- ZIP 文件内容完整性验证。

**尚未完成：** macOS AppKit 实际类型检查、`xcodebuild clean build`、真人 GUI 测试、日志回归、M5 性能基准。缺少 macOS SDK 时绝不把语法解析称为完整编译。

## 5. 在 Mac 上验收

1. 在解压工程目录运行 `bash Scripts/verify_macos_build.sh`，必须出现 `PASS full macOS arm64 AppKit build`；若失败，保存原始完整 Xcode error，不只发最后一行。
2. Debug 启动，观察 Xcode 控制台是否仍有 `Unable to simultaneously satisfy constraints`；若有，用 `LAYOUT_CONSTRAINTS_NOT_SATISFIABLE` 符号断点找到第一处发起者。
3. 首次打开、空文件夹、无筛选结果、双图比较各测试一次；每次最小化、最大化、切换侧栏，观察布局恢复。
4. 在窄窗口与普通窗口反复 resize，确认单行工具栏无重叠，预览图片始终居中，底部胶片栏与 HUD 可正常收起/展开。
5. 用之前失败的 WebP 文件（以及一个新的损坏 WebP）验证：不闪退、不永久卡住、坏图有占位图，重复滚动的失败请求会被抑制。
6. Instruments 中记录 CPU、内存、主线程繁忙比例、首屏加载以及连续翻页延迟；尚无实测数据时不能宣称超过同类产品。
