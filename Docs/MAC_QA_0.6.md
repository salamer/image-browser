# SwiftLens 0.6 — Apple Silicon 实机 QA 清单

## 1. 编译

```bash
python3 Scripts/generate_project.py
python3 Scripts/verify_source.py
./Scripts/run_linux_tests.sh
xcodebuild -project SwiftLens.xcodeproj -scheme SwiftLens \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

注意：`swiftc -frontend -parse` 不是 AppKit Typecheck。若 `xcodebuild` 报错，请记录首条真实 `error:` 信息及对应文件行。

## 2. 真实图片与操作（优先级按故障严重程度）

- [ ] 用一个包含 10+ 张 JPG/WebP 的目录打开，双击第 7 张图片。
- [ ] 焦点原本在搜索框时打开图片：按 `←` → 变第 6 张、`→` → 回第 7 张；`J/K` 同理。
- [ ] 放大/缩小窗口（宽、高都拖），竖图始终居中且 Fit；横图也验证；切换图片继续 Fit。
- [ ] 改变 sidebar divider 宽度，预览实时居中，不留大片无效黑区。
- [ ] 双击大图变 100%，再次双击恢复 Fit；Option+滚轮缩放和拖动平移不跳动。
- [ ] 鼠标靠近底部 150pt 出现胶片栏；点击胶片栏缩略图正常翻页；`T` 固定。
- [ ] 逐步把窗口缩至允许的最小尺寸；HUD 动态隐藏非关键按钮，控制条不溢出或导致约束警告。
- [ ] 窗口顶部显示 macOS 系统标题栏，不再有旧版空白上边框。
- [ ] 添加两个 Explorer 根文件夹，右键第一个文件夹：复制路径、Finder 定位、新建子目录；重命名后路径更新。
- [ ] 双击文件夹展开/收起，点击文件夹正常切换，`⌘[`/`⌘]`、`⌘↑` 导航。
- [ ] 原目录空/搜索无结果/递归扫描中，都有清晰空状态。
- [ ] `⌘C/⌘V` 在搜索文本编辑时不误操作图片文件，退出搜索后可以复制文件。
- [ ] 1000 张混合图片目录滚动、Resize 网格；底部没有异常空白，排序和筛选正常。

## 3. Console 分类（不要混淆）

- **应用约束问题**：`Unable to simultaneously satisfy constraints`，需要修。
- **媒体文件问题**：`Invalid profile 'c2ci'`，多数来自图片内损坏 ICC profile；不是键盘事件失败的原因。
- **macOS 服务提示**：`com.apple.linkd.autoShortcut`、AppIntents 连接错误需看是否伴随实际功能失效，不应直接归因为 SwiftLens 主窗口崩溃。

## 4. M5 性能（Release + Instruments）

固定使用同一图片集，记录：冷/热启动到首屏时间、滚动 p95 帧时长、翻页 p50/p95 延迟、峰值 RSS、后台解码占用、窗口 Resize FPS。与 Finder 和 MediaOne 做**同目录实测比较**，不要根据芯片规格虚构速度提升。
