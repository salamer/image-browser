# SwiftLens 0.6 — 针对 0.5 实机故障的 Code Review

## 已确认的问题与根因

| 优先级 | 0.5 现象 | 证据与原因 | 0.6 改动 |
|---|---|---|---|
| P0 | 图片详情左右键失效 | 搜索框仍为 `firstResponder`；`keyboardMonitor` 为保证输入安全直接跳过 `NSTextView`，方向键被搜索框处理 | `AdaptivePreviewView.acceptsFirstResponder=true`；`openPreview` 时主动 `makeFirstResponder`；将方向键映射提取为可测试逻辑 |
| P0 | Window Resize 不可靠 | 自适应预览依赖 `NSScrollView.contentView.bounds` 和文档视图大小；层层回调受布局状态与滚动文档尺寸影响 | 去掉预览滚动文档视图；绘制矩形始终由当前 `bounds`、像素尺寸、backingScale 和 zoom 直接计算 |
| P1 | 顶部空白，不像正常 Mac App | 窗口设 `fullSizeContentView`、`titleVisibility.hidden`，顶部 toolbar 内又向下偏移 27pt | 改为原生可见标题栏、两行紧凑顶部导航与工具条；标题由系统负责 |
| P1 | 大量 Auto Layout 冲突 | 日志明确有 NSButton.height=28 与 NSStackView.height=26 冲突；预览 HUD 固定数个 31pt 按钮与文本宽度，在窗口宽度=0 时不可能全部成立 | 工具行改为 30pt；HUD 改为自适应帧布局，窗口宽窄时分级隐藏控件；不再把 HUD 的 10 个内容项都放在刚性 Stack 里 |
| P1 | Explorer 侧栏操作少 | 单根目录；没有目录右键、创建子文件夹、折叠全部、重命名、复制路径 | 拆出 Browser+Sidebar、FolderOutlineView；支持多根、上下文菜单及双击展开 |
| P1 | 递归扫描等待太久 | 递归枚举先把所有 URL 放入数组，然后才开始 ImageIO 属性读取及向 UI 发送批次 | 递归枚举时直接 consume()、按 96 张提交增量 |
| P2 | 图标、间距不统一 | 图片卡片边缘密集，AppKit texturedRounded 的按钮比较突兀 | SF Symbols + inline bezel + 自然色图标；网格 gutter 12/inset 15，圆角 9 |

## 代码职责

- `AdaptivePreviewView`：仅处理图片 draw、缩放、拖动及触控板事件；无 NSScrollView 嵌套。
- `PreviewGeometry`：无 AppKit 的纯几何数学：Fit、物理像素比例、pan clamp、居中绘制。
- `PreviewHUDView`：根据宽度选择性展示控件；不依赖 10 个按钮的 intrinsic size 做约束。
- `Browser+Preview`：接管进入/退出预览、当前文件、翻页、解码结果过期处理。
- `Browser+Sidebar`：目录树菜单与文件夹操作；图片文件操作仍留在 `Browser+FileOperations`。
- `Browser+Keyboard` / `PhotoKeymap`：应用模式操作与纯按键映射分离。
- `PhotoScanner`：支持异步流式目录读取和扫描取消。

## 尚未解决／仍需实机验证

1. **Xcode 编译类型检查（P0）**：本环境为 Linux，没有 AppKit SDK，不能声明通过 Xcode 构建。需按 `MAC_QA_0.6.md` 完整编译。
2. **实际窗口 resize（P0）**：数学测试覆盖竖图与缩放坐标，但真实 Retina、多显示器、侧边栏宽度变化仍需要人工确认。
3. **边缘宽度/无障碍（P1）**：HUD 宽度最窄 190pt，控件会降级但需要实机检查 Hover/VoiceOver。
4. **极大目录树（P1）**：`FolderNode.loadChildren()` 仍是按需同步扫描，10 万级目录 / SMB/NAS 存在卡主线程风险。应演进为异步树节点和 SQLite 文件元信息索引。
5. **放大超大图（P1）**：当前使用 ImageIO 下采样渐进升级与 NSImage.draw，不是 Metal tiled renderer；巨图 100% 可能模糊或占内存，需要后续高分辨率瓦片读取。
6. **文件操作 Undo、进度、拖拽源（P2）**：尚无完整撤销事务、文件冲突选择或侧栏拖拽重排。
7. **文件格式/EXIF（P2）**：损坏 ICC profile（日志里 c2ci tag 重叠）源于某些媒体文件元数据；可支持更强的色彩管理回退，不能仅靠 UI 修复消除系统日志。
8. **对标 MediaOne（P2）**：尚未覆盖多帧动画/视频、元信息编辑、专业批量转换，不能声称付费版功能已经超越。

## 质量门槛

- `swiftc -frontend -parse`：29 个 Swift 文件通过（仅语法）。
- `python3 Scripts/verify_source.py`：29 文件 Xcode Build Sources 引用及 `plutil` 通过。
- Linux Swift 纯逻辑：BrowserQuery 13、DiskCacheJanitor 3、PreviewGeometry 9、PhotoKeymap 5，共 30 项断言通过。
- **尚未通过**：macOS AppKit typecheck / 真机启动 / Instruments 数据采样。

### 回归验收目标（非实测）

- 详情页左右键每次都切换正确图片；从搜索框进入预览不丢焦点。
- 竖图、横图在 Resize 过程中持续居中，不能等拖动结束才更新。
- 无 `NSButton.height=28 + NSStackView.height=26` 和预览 HUD 宽度过约束日志。
- 侧边栏新增 root、展开路径、创建子目录、右键重命名后导航正常。
- 1k/10k 混合 JPG+WebP 目录中流式扫图没有“扫描完全部才出首屏”。
