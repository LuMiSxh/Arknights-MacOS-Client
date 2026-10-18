// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Grouped so adding an action does not widen every initializer between `ContentView` and the
// control. Closures keep the policy in `LauncherViewModel` from being bypassed.
struct LauncherHUDActions {
	let openLauncherUpdate: () -> Void
	let checkGameUpdates: () -> Void
	let selectRegion: (GameRegion) -> Void
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void
	let showFailureDetails: () -> Void
}
