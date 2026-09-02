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
}
