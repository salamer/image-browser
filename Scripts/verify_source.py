#!/usr/bin/env python3
"""Checks project/source references without a macOS SDK."""
from pathlib import Path
import re, subprocess
root = Path(__file__).resolve().parents[1]
files = sorted((root/'Sources').rglob('*.swift'))
pbx = (root/'SwiftLens.xcodeproj/project.pbxproj').read_text()
assert len(files) >= 20
for f in files:
    name = f.name
    rel = f.relative_to(root)
    assert f'path = "{name}";' in pbx, f'Xcode project missing {rel}'
    # Each file must be part of the build phase (and there must be exactly one source reference).
    assert len(re.findall(re.escape(name) + r' in Sources \*/', pbx)) == 2, f'Source build reference mismatch {rel}'
    assert '\\' not in name, f'Suspicious escaped filename {rel}'
assert '.swift\\.' not in pbx
print('PASS', len(files), 'source paths and build references')
res = subprocess.run(['plutil','-lint',str(root/'SwiftLens.xcodeproj/project.pbxproj')], capture_output=True, text=True)
if res.returncode:
    raise SystemExit(res.stdout + res.stderr)
print('PASS OpenStep Xcode project parse')

# Parse every source file with the installed Swift compiler (syntax, not AppKit typecheck).
import shutil
compiler = shutil.which('swiftc')
if compiler:
    check = subprocess.run([compiler, '-frontend', '-parse', *map(str, files)],
                           capture_output=True, text=True)
    if check.returncode:
        raise SystemExit('Swift syntax failure:\n' + check.stdout + check.stderr)
    print('PASS Swift parser:', len(files), 'source files')

# Fail early if a known unsupported old drawing call reappears.
legacy = 'NS' + 'RectFill' + '('
for file in files:
    assert legacy not in file.read_text(), f'Unsupported legacy fill API in {file}'
print('PASS AppKit drawing API regression check')

# Resource build phase must contain the app icon (not the framework phase).
resources = re.search(r'/\* Begin PBXResourcesBuildPhase section \*/(.*?)/\* End PBXResourcesBuildPhase section \*/', pbx, re.S)
frameworks = re.search(r'/\* Begin PBXFrameworksBuildPhase section \*/(.*?)/\* End PBXFrameworksBuildPhase section \*/', pbx, re.S)
assert resources and 'Assets.xcassets in Resources' in resources.group(1)
assert frameworks and 'Assets.xcassets' not in frameworks.group(1)
assert 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' in pbx
assert 'INFOPLIST_KEY_CFBundleIconName = AppIcon;' in pbx
assert 'SwiftLensIcon.png in Resources' in resources.group(1)
assert 'SwiftLensIcon.png' not in frameworks.group(1)
assert (root/'Resources/SwiftLensIcon.png').is_file()
assert 'NSApp.applicationIconImage = icon' in (root/'Sources/App/AppDelegate.swift').read_text()
assert 'window?.zoom(nil)' in (root/'Sources/Components/BrowserToolbarView.swift').read_text()
assert 'scroll.scrollerStyle = .overlay' in (root/'Sources/Browser/Browser+Layout.swift').read_text()
assert 'sidebar.outlineScrollView = scroll' in (root/'Sources/Browser/Browser+Layout.swift').read_text()
sidebar_setup = (root/'Sources/Browser/Browser+Layout.swift').read_text()
assert 'scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor)' not in sidebar_setup
assert 'scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor)' not in sidebar_setup
assert 'SidebarGeometry.scrollRect' in (root/'Sources/Components/SidebarExplorerView.swift').read_text()
assert 'NSWindow.didEndLiveResizeNotification' in (root/'Sources/Browser/BrowserViewController.swift').read_text()
assert 'grid.reloadItems(at: Set(visible))' in (root/'Sources/Browser/Browser+Actions.swift').read_text()

assert 'let gridSizeSlider = ThumbnailSizeSlider' in (root/'Sources/Browser/BrowserViewController.swift').read_text()

iconset = root / 'Resources/Assets.xcassets/AppIcon.appiconset'
import json
manifest = json.loads((iconset/'Contents.json').read_text())
assert len(manifest['images']) == 10
assert all((iconset/item['filename']).exists() for item in manifest['images'])
print('PASS AppIcon: asset catalog + bundled fallback + runtime initialization')

# Keep the genuine macOS compiler gate script syntactically valid.
assert subprocess.run(['bash','-n',str(root/'Scripts/verify_macos_build.sh')]).returncode == 0
assert '\\n  -project' not in (root/'Scripts/verify_macos_build.sh').read_text(), 'Broken literal slash-n build script'
print('PASS native build verifier shell syntax')

# Old zero-sized parent regression: the three former problem components must
# never acquire required stack or fixed-width constraints again.
for name in ['BrowserEmptyStateView.swift', 'CompareImageHost.swift']:
    component = (root/'Sources/Components'/name).read_text()
    assert 'NSStackView(' not in component and 'NSLayoutConstraint.activate' not in component, name
for source_name in ['BrowserEmptyStateView.swift', 'PreviewFilmstrip.swift', 'PreviewHUDView.swift']:
    component = (root/'Sources/Components'/source_name).read_text()
    assert 'override func layout()' in component, f'Missing frame-based layout: {source_name}'
preview_layout = (root/'Sources/Browser/Browser+Layout.swift').read_text()
assert 'filmstrip.leadingAnchor.constraint' not in preview_layout
assert 'leftCompare.widthAnchor.constraint' not in preview_layout
assert 'previewHUD.widthAnchor.constraint' not in preview_layout
print('PASS zero-sized parent layout regression guard')
