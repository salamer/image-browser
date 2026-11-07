#!/usr/bin/env python3
"""Recreate a deterministic Xcode project from the actual source file tree.

Avoids manual pbxproj paths and especially literal escaped backslashes that
previously caused AdaptivePreviewView\\.swift to appear as a missing file.
"""
from pathlib import Path
import re
import hashlib

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = Path(__file__).resolve().parent / 'pbxproj.template'
OUTPUT = ROOT / 'SwiftLens.xcodeproj' / 'project.pbxproj'


def identifier(kind: str, value: str) -> str:
    return hashlib.sha256(f'{kind}:{value}'.encode('utf-8')).hexdigest()[:24].upper()


def replace_section(project: str, name: str, data: str) -> str:
    pattern = rf'/\* Begin {re.escape(name)} section \*/.*?/\* End {re.escape(name)} section \*/'
    replacement = f'/* Begin {name} section */\n{data}/* End {name} section */'
    result, count = re.subn(pattern, lambda _: replacement, project, flags=re.S)
    assert count == 1, name
    return result


folders = sorted(p for p in (ROOT / 'Sources').iterdir() if p.is_dir())
files = sorted((ROOT / 'Sources').rglob('*.swift'))
assert len(files) >= 20, 'Missing source files'
for file in files:
    assert '\\' not in file.name, 'Invalid literal backslash in a source filename'

refs = {p: identifier('file', str(p.relative_to(ROOT))) for p in files}
builds = {p: identifier('build', str(p.relative_to(ROOT))) for p in files}
subgroups = {p: identifier('group', str(p.relative_to(ROOT))) for p in folders}
source_group = identifier('group', 'Sources')

build_files = ''.join(f'        {builds[p]} /* {p.name} in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {refs[p]} /* {p.name} */; }};\n' for p in files)
file_refs = ''.join(f'        {refs[p]} /* {p.name} */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{p.name}"; sourceTree = "<group>"; }};\n'
    for p in files)
file_refs += ('        B20000000000000000000003 /* SwiftLensIcon.png */ = '
              '{isa = PBXFileReference; lastKnownFileType = image.png; '
              'path = SwiftLensIcon.png; sourceTree = "<group>"; };\n')
file_refs += ('        B20000000000000000000001 /* Assets.xcassets */ = '
              '{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; '
              'path = Assets.xcassets; sourceTree = "<group>"; };\n')
file_refs += ('        A20000000000000000000006 /* SwiftLens.app */ = '
              '{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; '
              'path = SwiftLens.app; sourceTree = BUILT_PRODUCTS_DIR; };\n')

groups = (f'        A40000000000000000000001 = {{isa = PBXGroup; children = '
          f'({source_group} /* Sources */, B20000000000000000000002 /* Resources */, A40000000000000000000003 /* Products */); '
          'sourceTree = "<group>"; };\n')
groups += (f'        {source_group} /* Sources */ = {{isa = PBXGroup; children = ('
           + ', '.join(f'{subgroups[p]} /* {p.name} */' for p in folders)
           + '); path = Sources; sourceTree = "<group>"; };\n')
for folder in folders:
    folder_files = [p for p in files if p.parent == folder]
    assert folder_files, f'Empty Xcode source folder: {folder}'
    groups += (f'        {subgroups[folder]} /* {folder.name} */ = {{isa = PBXGroup; children = ('
               + ', '.join(f'{refs[p]} /* {p.name} */' for p in folder_files)
               + f'); path = {folder.name}; sourceTree = "<group>"; }};\n')
groups += ('        B20000000000000000000002 /* Resources */ = {isa = PBXGroup; children = '
           '(B20000000000000000000001 /* Assets.xcassets */, B20000000000000000000003 /* SwiftLensIcon.png */); path = Resources; '
           'sourceTree = "<group>"; };\n')
groups += ('        A40000000000000000000003 /* Products */ = '
           '{isa = PBXGroup; children = (A20000000000000000000006); name = Products; sourceTree = "<group>"; };\n')

source_phase = ('        A70000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; '
    'buildActionMask = 2147483647; files = (\n')
for p in files:
    source_phase += f'            {builds[p]} /* {p.name} in Sources */,\n'
source_phase += '        ); runOnlyForDeploymentPostprocessing = 0; };\n'

project = TEMPLATE.read_text()
build_files += ('        B10000000000000000000001 /* Assets.xcassets in Resources */ = '
                '{isa = PBXBuildFile; fileRef = B20000000000000000000001 /* Assets.xcassets */; };\n')
build_files += ('        B10000000000000000000003 /* SwiftLensIcon.png in Resources */ = '
                '{isa = PBXBuildFile; fileRef = B20000000000000000000003 /* SwiftLensIcon.png */; };\n')
project = replace_section(project, 'PBXBuildFile', build_files)
project = replace_section(project, 'PBXFileReference', file_refs)
project = replace_section(project, 'PBXGroup', groups)
project = replace_section(project, 'PBXSourcesBuildPhase', source_phase)
project = replace_section(project, 'PBXResourcesBuildPhase',
    '        A70000000000000000000002 /* Resources */ = {isa = PBXResourcesBuildPhase; '
    'buildActionMask = 2147483647; files = '
    '(B10000000000000000000001 /* Assets.xcassets in Resources */, '
    'B10000000000000000000003 /* SwiftLensIcon.png in Resources */); '
    'runOnlyForDeploymentPostprocessing = 0; };\n')
project = project.replace('MARKETING_VERSION = 0.4.0;', 'MARKETING_VERSION = 0.9.0;')
project = project.replace('CURRENT_PROJECT_VERSION = 4;', 'CURRENT_PROJECT_VERSION = 10;')
project = project.replace('PRODUCT_BUNDLE_IDENTIFIER = com.example.SwiftLens;',
                          'PRODUCT_BUNDLE_IDENTIFIER = com.swiftlens.local;')
project = project.replace('SWIFT_STRICT_CONCURRENCY = minimal;',
                          'SWIFT_STRICT_CONCURRENCY = minimal;\n            ARCHS = arm64;')
project = project.replace('GENERATE_INFOPLIST_FILE = YES;',
                          'GENERATE_INFOPLIST_FILE = YES;\n            ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n            INFOPLIST_KEY_CFBundleIconName = AppIcon;')
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(project)
print('Generated', OUTPUT, 'for', len(files), 'Swift sources')
