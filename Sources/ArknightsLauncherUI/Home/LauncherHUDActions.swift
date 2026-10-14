// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// The actions the launcher HUD can trigger, grouped so adding one does not widen every
/// initializer between `ContentView` and the control that invokes it. They stay closures so
/// the policy in `LauncherViewModel` is not bypassed.
package struct LauncherHUDActions {
	package let openLauncherUpdate: () -> Void
	package let checkGameUpdates: () -> Void
	package let selectRegion: (GameRegion) -> Void
	package let installOrUpdate: () -> Void
	package let cancelDownload: () -> Void
	package let launch: () -> Void
	package let stopGame: () -> Void
	let showFailureDetails: () -> Void
}
