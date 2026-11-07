#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -O Sources/Model/BrowserQuery.swift Tests/BrowserQueryTests.swift -o .build/browser-query-tests
.build/browser-query-tests
swiftc -O Sources/Services/DiskCacheJanitor.swift Tests/DiskCacheJanitorTests.swift -o .build/disk-cache-janitor-tests
.build/disk-cache-janitor-tests

swiftc -O Sources/Model/PreviewGeometry.swift Tests/PreviewGeometryTests.swift -o .build/preview-geometry-tests
.build/preview-geometry-tests

swiftc -O Sources/Model/PhotoKeymap.swift Tests/PhotoKeymapTests.swift -o .build/photo-keymap-tests
.build/photo-keymap-tests

swiftc -O Sources/Model/ChromeGeometry.swift Tests/ChromeGeometryTests.swift -o .build/chrome-geometry-tests
.build/chrome-geometry-tests

swiftc -O Sources/Services/DecodeFailureThrottle.swift Tests/DecodeFailureThrottleTests.swift -o .build/decode-failure-tests
.build/decode-failure-tests

swiftc -O Sources/Model/SidebarGeometry.swift Tests/SidebarGeometryTests.swift -o .build/sidebar-geometry-tests
.build/sidebar-geometry-tests
