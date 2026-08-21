// SPDX-License-Identifier: MPL-2.0

import AppKit
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherIconManagerTests {
	@Test
	func applyUpdatesPersistentRunningAndObservedIcons() {
		let bundled = NSImage(size: NSSize(width: 16, height: 16))
		let selected = NSImage(size: NSSize(width: 32, height: 32))
		var persistentIcon: NSImage?
		var runningIcon: NSImage?
		var observedIcon: NSImage?
		let manager = LauncherIconManager(
			setBundleIcon: {
				persistentIcon = $0
				return true
			},
			setRunningIcon: { runningIcon = $0 },
			defaultIcon: { bundled }
		)
		manager.iconDidChange = { observedIcon = $0 }

		#expect(manager.apply(selected))
		#expect(persistentIcon === selected)
		#expect(runningIcon === selected)
		#expect(manager.currentIcon === selected)
		#expect(observedIcon === selected)
	}

	@Test
	func resetClearsCustomSurfacesAndPublishesBundledIcon() {
		let bundled = NSImage(size: NSSize(width: 16, height: 16))
		let selected = NSImage(size: NSSize(width: 32, height: 32))
		var persistentIcon: NSImage?
		var runningIcon: NSImage?
		var observedIcon: NSImage?
		let manager = LauncherIconManager(
			setBundleIcon: {
				persistentIcon = $0
				return true
			},
			setRunningIcon: { runningIcon = $0 },
			defaultIcon: { bundled }
		)
		manager.iconDidChange = { observedIcon = $0 }
		manager.apply(selected)

		#expect(manager.reset())
		#expect(persistentIcon == nil)
		#expect(runningIcon == nil)
		#expect(manager.currentIcon === bundled)
		#expect(observedIcon === bundled)
	}

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
