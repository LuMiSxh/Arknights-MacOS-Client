// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

enum RuntimeLoaderIcon {
	/// The Finder stores a custom icon in this file at the bundle root.
	static let markerName = "Icon\r"

	/// Gives the ARM loader bundle the launcher icon so per-app volume tools show it. Best effort
	/// and idempotent: it never fails a launch, and it skips a bundle that already has an icon.
	static func apply(
		to runtime: WineRuntime,
		log: LauncherLog,
		setIcon: (URL) throws -> Void
	) {
		guard runtime.isNativeARMLane else { return }
		let fileManager = FileManager.default
		guard
			let bundle = runtime.loaderBundleURLs.first(where: {
				fileManager.fileExists(atPath: $0.path)
			})
		else { return }
		let marker = bundle.path + "/" + markerName
		guard !fileManager.fileExists(atPath: marker) else { return }
		// The upstream signature seals the bundle; a Finder icon is an xattr plus a root file outside the seal.
		log.attempt("Setting the loader bundle icon") {
			try setIcon(bundle)
		}
	}
}
