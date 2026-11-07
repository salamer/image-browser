# SwiftLens 0.7 changelog

- Replaced 78pt two-row toolbar with a resizable single-row BrowserToolbarView and an overflow options menu.
- Restored useful titlebar space with a full-size-content transparent titlebar, while preserving traffic-light controls and a draggable blank toolbar region.
- Corrected NSSplitView collapse/restore behavior and preserved explorer widths.
- Replaced the local key event monitor with window-level event routing that respects search and outline editing focus.
- Added Tab focus mode for immersive preview; maintained image Fit when window or split divider changes size.
- Added restrained hover visuals, SF Symbol tooltips and accessible labels to main controls, and hover shadow for photo tiles.
- Added a real macOS AppIcon asset catalog (all ten sizes), a master transparent PNG and a regeneration script.
- Corrected the broken clean-build shell command in the previous macOS verifier; verified asset catalog references in Xcode build phases.
- Documentation: updated README, code review, hands-on M5 QA checklist.

Build status: static checks and platform-independent tests passed. Mac AppKit build not executed in this environment.
