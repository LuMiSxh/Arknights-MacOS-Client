// SPDX-License-Identifier: MPL-2.0

enum LauncherUpdateCheckOutcome: Sendable, Equatable {
	case current
	case updateAvailable(String)
	case failed
}
