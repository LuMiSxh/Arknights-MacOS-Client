// SPDX-License-Identifier: MPL-2.0

import Foundation

/// User-facing status and errors that must never replace lifecycle state.
package struct LauncherPresentationState {
	package var status: LauncherStatus = .checking
	package var failure: LauncherFailurePresentation?
}
