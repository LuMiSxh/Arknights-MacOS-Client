// SPDX-License-Identifier: MPL-2.0

package enum LauncherUpdateCheckOutcome: Sendable, Equatable {
	case current
	case updateAvailable(String)
	case failed

	/// Sparkle compares build numbers, so a local build (build 1) sees every published release as
	/// an update. Only a version newer than the running one blocks setup.
	package static func found(version offered: String, isNewerThanRunning: Bool) -> Self {
		isNewerThanRunning ? .updateAvailable(offered) : .current
	}
}
