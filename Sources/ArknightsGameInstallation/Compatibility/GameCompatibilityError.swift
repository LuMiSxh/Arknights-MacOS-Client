// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Failures raised while applying or restoring game-file compatibility components.
///
/// Installation and Runtime both call the compatibility manager; Runtime maps this error to
/// `GameRuntimeError` at its own boundary so Installation never names a Runtime type.
package enum GameCompatibilityError: LocalizedError, LauncherDiagnosticError, Sendable, Equatable {
	case setupFailed(String)

	package var errorDescription: String? {
		"Game-file compatibility setup could not be completed. Repair the game files and try again."
	}

	package var diagnosticDescription: String {
		switch self {
		case .setupFailed(let message):
			"Game compatibility setup could not be completed: \(message)"
		}
	}
}
