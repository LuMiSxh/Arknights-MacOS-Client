// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Independent prerequisites used to derive whether installation or launch actions are valid.
struct LauncherReadinessState {
	var configuration: GameConfiguration?
	var runtimeName: String?
	var isInstalled = false
	var hasPartialDownload = false
	var installedVersion: String?
	var isGameUpdateAvailable = false
	var intelTranslation: IntelTranslationState = .checking
	var rosettaInstallation: RosettaInstallationState = .idle
}
