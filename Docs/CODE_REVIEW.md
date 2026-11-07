# SwiftLens 0.5 — Code Review 与决策记录

## 已从 0.4 修复的问题

| 级别 | 0.4 现象 / 根因 | 0.5 修改 |
|---|---|---|
| P0 构建失败 | `project.pbxproj` 将 `AdaptivePreviewView\\.swift` 当作实际路径（含反斜杠） | 工程按实际 `Sources` 路径生成；带 `+` 的文件名正确加双引号；全部源文件 Build Sources 完整性校验 |
| P1 可维护性 | 约 1,326 行浏览器控制器同时处理 UI/文件/扫描/键盘 | 拆为 9 个 Browser extension 文件，组件/服务/模型独立；总 24 个 Swift 文件 |
| P1 首次使用 | 无图片时只有简短/低对比文案或大片深色空间 | 独立空状态组件：欢迎/空目录/无结果/扫描中四态；打开文件夹、清除筛选、帮助入口 |
| P1 预览过时 | 旧预览缓存键仅路径与请求尺寸，原路径内容替换后不失效 | 文件路径 + 大小 + 修改时间 + 最大解码边长参与缓存键 |
| P1 缩略图不稳定 | Quick Look 回退达到 semaphore 8 便丢弃当前请求 | 非阻塞请求 broker，有界并发 4，剩余等待队列 |
| P1 大目录卡顿 | PhotoScanner 多次回传**完整**数组、浏览器反复 reload | 增量批次最多约 96；扫描可取消；浏览器显示节流至约 4 次/秒 |
| P1 文件操作卡 UI | 移动、复制和删除在主线程执行 | 后台文件 I/O，UI/注解在主线程应用结果 |
| P2 缓存无限增长 | JPG 磁盘缓存缺少容量控制 | 初次启动及周期性后台 prune，768 MB 上限策略 |
| P2 多选行为 | 键盘单步移动使用 `selectItems` 追加而非替换当前选择 | 键盘移动先取消旧选择；`⌘A` 调 AppKit 原生全选；`⌘C` 复制多个文件 |
| P2 目录体验 | 没有导航历史；目录切换时丢失滚动位置 | 后退/前进/上级目录、按目录保存滚动位置 |
| P2 本地评分 | 改名/移动/复制后基于路径的标注丢失 | 应用内文件操作成功后迁移/复制标注 |
| P2 Xcode console | 旧版 AppIntent/restorable-state 提示；布局曾冲突 | 实现 secure restorable state 声明；不再给 split 子视图强制宽度；双图比较改普通约束容器。**仍需实机检查新约束日志** |

## 仍未解决的风险（按优先级）

1. **P0 / 待验证**：没有 macOS AppKit SDK，不能进行 Swift 类型检查、链接、签名与交互自动化。静态 Swift 语法解析不能证明程序可运行。
2. **P1 / 性能**：`FolderNode.loadChildren()` 仍可能在主线程读取异常庞大、网络或同步盘目录。应该异步加载目录树和展示骨架状态。
3. **P1 / 性能**：初次目录枚举 + 每张图片 ImageIO properties 打开文件，100k 图片/网络盘场景仍可能较慢。下一步应使用 SQLite（文件身份、mtime/size 强失效）持久化 metadata index。
4. **P1 / 体验**：瀑布流视口变化会重新构造全部 cell layout attributes；尽管滚动查询已按空间桶优化，重排仍是 O(N)。对于几十万条应采用分区式增量布局和 anchor 保持。
5. **P1 / UI**：预览在图片切换时的 NSImageView 仍可能短暂出现背景色；长边极大图使用 ImageIO full-frame fallback，存在较高峰值 RAM。后续可做分级解码和高分辨率分片显示。
6. **P1 / 数据**：评分/收藏目前只存在 SwiftLens 的 `Application Support/annotations.json`，不是 XMP/Finder 标签；外部 Finder 更名或移动不会自动迁移记录。需要 fileResourceIdentifier 与文件系统监听策略。
7. **P2 / 文件管理**：粘贴/复制没有事务级取消、进度与 undo；目标文件夹碰撞时会跳过手动冲突选择。跨卷移动行为需实机确认。
8. **P2 / 支持范围**：不支持视频/音频、动画多帧、EXIF 编辑、批量转换；故不能标称 MediaOne 付费版完全对等。
9. **P2 / 无障碍**：需要 VoiceOver、Dynamic Type 类似字体缩放、RTL 与中英文国际化检查；目前 SF Symbols 控件部分有 toolTip 但没有完整 accessibility label 审计。

## 设计参考与明确取舍

- Apple Finder / Quick Look：Space 预览、⌘C/⌘V/⌘A、⌘⌫、⌘↑、⌘[/⌘]、面包屑、右键文件操作。
- VS Code：⌘B 隐藏/显示侧栏、F2 重命名、⏎/双击、以可发现性优先的命令和状态提示。
- Photo Mechanic：快速翻页、1–5 评分、胶片栏和无中断挑片操作。
- XnView MP：缩略图缓存、多种布局、按名称/日期/大小排序。
- MediaOne：多种缩略图布局、评分/标签、双栏比较、动画/视频/高级搜索/转换（后面四类仍是 v0.5 的差距）。

参考来源（截至 2026-11-07）：
- https://support.apple.com/en-us/102650
- https://docs.camerabits.com/support/solutions/articles/48001144384-the-preview-window
- https://apps.apple.com/jp/app/mediaone-photo-video-viewer/id1237328432?mt=12
- https://flowvision.app/
- https://newsgroup.xnview.com/viewtopic.php?t=47571

## 性能测量设计（不是实测结果）

应在 M5 上使用 Release + Instruments 的 Time Profiler / Allocations / Metal System Trace（如将来加入 Metal），基于同一目录比较 MediaOne、Finder 和 SwiftLens。建议数据集：1k JPEG、10k 混合 JPG+WebP、50k 小文件、10k 含大 HEIC/RAW，以及外置 SSD/network folder。记录：首次可交互时间、首屏填充 p50/p95、平滑滚动 FPS/p95 帧时长、翻页延迟 p50/p95、CPU 峰值、RSS 峰值、缓存热启动耗时。**不要把设计目标描述成已测成绩**。

建议验收目标（须实测验证）：热缓存翻页 p95 < 100ms；已有缓存的滚动 p95 帧时 < 16.7ms；重排行为无多余 scroll tail；快速切目录不会旧结果覆盖新目录；缩放滑动无同步解码卡 UI。
