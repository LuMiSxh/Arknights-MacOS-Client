// SPDX-License-Identifier: MPL-2.0

import OSLog

/// Signposts for installer phases. Intervals appear in Instruments' Points of Interest lane.
enum InstallerSignposts {
	static let signposter = OSSignposter(
		subsystem: AppConstants.Logging.bundleIdentifier,
		category: AppConstants.Logging.installerSignpostCategory
	)

	/// Measures `body` as one interval and closes it on every exit path, including throws.
	static func measure<T>(
		_ name: StaticString,
		_ body: () throws -> T
	) rethrows -> T {
		let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
		defer { signposter.endInterval(name, state) }
		return try body()
	}
}
