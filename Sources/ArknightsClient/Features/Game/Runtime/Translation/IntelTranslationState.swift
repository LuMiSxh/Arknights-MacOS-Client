// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Readiness of the Intel translation layer required by the bundled x86-64 Wine runtime.
/// Only `available` permits launch; the remaining terminal states carry distinct recovery
/// guidance for setup and diagnostics.
enum IntelTranslationState: Equatable, Sendable {
	case waitingForLauncherCheck
	case checking
	case available
	case rosettaMissing
	case gameTestModeEnabled
	case unavailable
	case unsupportedOS

	var allowsWine: Bool {
		self == .available
	}

	var diagnosticName: String {
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
