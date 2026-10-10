// SPDX-License-Identifier: MPL-2.0

package enum LauncherUpdateCheckOutcome: Sendable, Equatable {
	case current
	case updateAvailable(String)
	case failed

	/// Sparkle compares build numbers, so a local build (build 1) sees the published release of
	/// the same version as an update. Only a different version blocks setup or shows as available.
	package static func found(version offered: String, running: String?) -> Self {
		offered == running ? .current : .updateAvailable(offered)
	}
}
