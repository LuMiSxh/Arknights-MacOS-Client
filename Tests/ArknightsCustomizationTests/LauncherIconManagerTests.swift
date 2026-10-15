// SPDX-License-Identifier: MPL-2.0

import AppKit
import Testing

@testable import ArknightsCustomization

@MainActor
struct LauncherIconManagerTests {
	@Test
	func rejectedPersistentIconStillKeepsTheRunningProcessSynchronized() {
		let bundled = NSImage(size: NSSize(width: 16, height: 16))
		let selected = NSImage(size: NSSize(width: 32, height: 32))
		var runningIcon: NSImage?
		let manager = LauncherIconManager(
			setBundleIcon: { _ in false },
			setRunningIcon: { runningIcon = $0 },
			defaultIcon: { bundled }
		)

		#expect(!manager.apply(selected))
		#expect(runningIcon === selected)
		#expect(manager.currentIcon === selected)
	}
}
