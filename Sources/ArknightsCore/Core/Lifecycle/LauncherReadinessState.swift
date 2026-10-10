// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Independent prerequisites used to derive whether installation or launch actions are valid.
package struct LauncherReadinessState {
	package var configuration: GameConfiguration?
	package var runtimeName: String?
	package var isInstalled = false
	package var hasPartialDownload = false
	package var installedVersion: String?
	package var isGameUpdateAvailable = false
	var intelTranslation: IntelTranslationState = .checking
	var rosettaInstallation: RosettaInstallationState = .idle
}
