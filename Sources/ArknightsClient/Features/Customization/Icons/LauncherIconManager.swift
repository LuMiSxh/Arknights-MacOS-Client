// SPDX-License-Identifier: MPL-2.0

import AppKit
import Observation

/// Applies the launcher's icon to both the running process and its app bundle.
///
/// `NSApplication.applicationIconImage` updates the current Dock process only, while
/// `NSWorkspace.setIcon` supplies Finder, Spotlight, and later launches. Keeping both writes
/// here prevents icon sources from drifting as themes and persisted choices are reapplied.
@MainActor
@Observable
final class LauncherIconManager {
	typealias BundleIconSetter = (NSImage?) -> Bool
	typealias RunningIconSetter = (NSImage?) -> Void
	typealias DefaultIconProvider = () -> NSImage

	private let setBundleIcon: BundleIconSetter
	private let setRunningIcon: RunningIconSetter
	private let defaultIcon: DefaultIconProvider

	private(set) var currentIcon: NSImage
	@ObservationIgnored var iconDidChange: ((NSImage) -> Void)?

	convenience init(bundle: Bundle = .main, workspace: NSWorkspace = .shared) {
		let bundlePath = bundle.bundlePath
		let hasApplicationBundle = bundle.bundleURL.pathExtension == "app"
		self.init(
			setBundleIcon: { image in
				guard hasApplicationBundle else { return true }
				return workspace.setIcon(image, forFile: bundlePath, options: [])
			},
			setRunningIcon: { NSApp?.applicationIconImage = $0 },
			defaultIcon: { workspace.icon(forFile: bundlePath) }
		)
	}

	init(
		setBundleIcon: @escaping BundleIconSetter,
		setRunningIcon: @escaping RunningIconSetter,
		defaultIcon: @escaping DefaultIconProvider
	) {
		self.setBundleIcon = setBundleIcon
		self.setRunningIcon = setRunningIcon
		self.defaultIcon = defaultIcon
		currentIcon = defaultIcon()
	}

	/// Applies `image` everywhere macOS presents the launcher identity.
	/// Returns `false` when Finder rejected the persistent app-bundle icon.
	@discardableResult
	func apply(_ image: NSImage) -> Bool {
		let persisted = setBundleIcon(image)
		setRunningIcon(image)
		currentIcon = image
		iconDidChange?(image)
		return persisted
	}

	/// Clears every custom icon surface and publishes the app's bundled default icon.
	/// Returns `false` when Finder rejected removal of the persistent custom icon.
	@discardableResult
	func reset() -> Bool {
		let persisted = setBundleIcon(nil)
		setRunningIcon(nil)
		let resolvedDefault = defaultIcon()
		currentIcon = resolvedDefault
		iconDidChange?(resolvedDefault)
		return persisted
	}
}
