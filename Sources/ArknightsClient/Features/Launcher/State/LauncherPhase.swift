// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A compact compatibility projection for views that only need the dominant launcher phase.
/// Lifecycle truth remains in `LauncherState` and errors remain presentation state.
enum LauncherPhase: Equatable, Sendable {
	case checking
	case ready
	case downloading
	case migrating
	case launching
	case running(processIdentifier: Int32)

	var title: String {
		switch self {
		case .checking: "Checking version"
		case .ready: "Ready"
		case .downloading: "Downloading game files"
		case .migrating: "Preparing Wine runtime"
		case .launching: "Starting Windows runtime"
		case .running: "Game started"
		}
	}
}
