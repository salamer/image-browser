# SwiftLens 0.6.1 — build-focused code review

## Root cause

Compiler diagnostic: `Cannot find 'NSRectFill' in scope` at `Sources/Components/AdaptivePreviewView.swift`. `NSRectFill` is a legacy drawing symbol; despite being documented in AppKit, it is unavailable as a Swift declaration in the user's SDK environment. Replaced with `NSBezierPath(rect: dirtyRect).fill()`, a documented AppKit Swift method.

## Inspected

- All files referenced by the generated pbxproj were checked against their actual paths.
- All Swift files parsed using the Linux Swift compiler. This does **not** typecheck AppKit.
- Pure Foundation geometry/filter/cache/keymap tests exercised by `Scripts/run_linux_tests.sh`.
- `Scripts/verify_macos_build.sh` now provides the missing full macOS ARM64 SDK clean-build gate.
- No code signing is required for local build verification.

## Not verified here

- AppKit framework name/type availability in Xcode 27.x.
- Native macOS compile/link.
- UI rendering, keyboard focus, resize/animation, performance on M5.

## Release policy

A green Linux syntax run is NOT a release approval. A Mac must execute `bash Scripts/verify_macos_build.sh`, and the human must test GUI interactions. CI workflow will enforce a macOS build if this source tree is committed to a GitHub repository.
