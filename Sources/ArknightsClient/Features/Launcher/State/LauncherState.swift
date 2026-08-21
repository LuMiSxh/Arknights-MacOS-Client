// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The launcher's hierarchical state tree. Its sub-states remain orthogonal so background
/// metadata refreshes and presentation failures cannot overwrite the active game lifecycle.
struct LauncherState {
	var activity: LauncherActivity = .idle
	var refresh: LauncherRefreshState = .checking(requestID: nil)
	var readiness = LauncherReadinessState()
	var presentation = LauncherPresentationState()
}
