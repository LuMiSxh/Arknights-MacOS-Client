// SPDX-License-Identifier: MPL-2.0

import Foundation

/// User-facing status and errors that must never replace lifecycle state.
struct LauncherPresentationState {
	var status: LauncherStatus = .checking
	var failure: LauncherFailurePresentation?
}
