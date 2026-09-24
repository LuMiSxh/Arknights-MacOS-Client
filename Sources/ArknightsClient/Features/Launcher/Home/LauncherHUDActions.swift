// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The actions the launcher HUD can trigger, grouped so adding one does not widen every
/// initializer between `ContentView` and the control that invokes it. They stay closures so
/// the policy in `LauncherViewModel` is not bypassed.
struct LauncherHUDActions {
	let openLauncherUpdate: () -> Void
	let checkGameUpdates: () -> Void
	let selectRegion: (GameRegion) -> Void
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void
	let showFailureDetails: () -> Void
}
