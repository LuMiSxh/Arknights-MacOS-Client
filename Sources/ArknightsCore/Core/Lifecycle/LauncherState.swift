// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The launcher's hierarchical state tree. Its sub-states remain orthogonal so background
/// metadata refreshes and presentation failures cannot overwrite the active game lifecycle.
package struct LauncherState {
	package var activity: LauncherActivity = .idle
	package var refresh: LauncherRefreshState = .checking(requestID: nil)
	package var readiness = LauncherReadinessState()
	package var presentation = LauncherPresentationState()
}

package enum LauncherRefreshState: Equatable, Sendable {
	case idle
	case checking(requestID: UUID?)

	package var requestID: UUID? {
		guard case .checking(let requestID) = self else { return nil }
		return requestID
	}

	package var isChecking: Bool {
		if case .checking = self { return true }
		return false
	}
}

/// Independent prerequisites used to derive whether installation or launch actions are valid.
package struct LauncherReadinessState {
	package var configuration: GameConfiguration?
	package var runtimeName: String?
	package var isInstalled = false
	package var hasPartialDownload = false
	package var installedVersion: String?
	package var isGameUpdateAvailable = false
	package var intelTranslation: IntelTranslationState = .checking
	package var rosettaInstallation: RosettaInstallationState = .idle
}

/// User-facing status and errors that must never replace lifecycle state.
package struct LauncherPresentationState {
	package var status: LauncherStatus = .checking
	package var failure: LauncherFailurePresentation?
}

package enum RosettaInstallationState: Equatable, Sendable {
	case idle
	case installing
	case failed(String)

	package var isInstalling: Bool {
		self == .installing
	}

	package var failureMessage: String? {
		guard case .failed(let message) = self else { return nil }
		return message
	}
}

/// Readiness of the Intel translation layer required by the bundled x86-64 Wine runtime.
/// Only `available` permits launch; the remaining terminal states carry distinct recovery
/// guidance for setup and diagnostics.
package enum IntelTranslationState: Equatable, Sendable {
	case waitingForLauncherCheck
	case checking
	case available
	case rosettaMissing
	case gameTestModeEnabled
	case unavailable
	case unsupportedOS

	package var allowsWine: Bool {
		self == .available
	}

	package var diagnosticName: String {
		switch self {
		case .waitingForLauncherCheck: "waiting"
		case .checking: "checking"
		case .available: "available"
		case .rosettaMissing: "rosetta-missing"
		case .gameTestModeEnabled: "game-test-mode-enabled"
		case .unavailable: "unavailable"
		case .unsupportedOS: "unsupported-os"
		}
	}
}
