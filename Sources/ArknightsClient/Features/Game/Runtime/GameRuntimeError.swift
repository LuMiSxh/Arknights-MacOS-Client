// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Failures raised while preparing, starting, and monitoring the Windows runtime and game process.
enum GameRuntimeError: LocalizedError, LauncherDiagnosticError, Sendable {
	case gameNotInstalled(URL)
	case wineRuntimeMissing
	case rosettaMissing
	case rosettaDisabledByGameTestMode
	case intelTranslationUnavailable
	case intelTranslationUnsupported
	case runtimeWindowTimeout
	case runtimeConfiguration(String)
	case gameCompatibility(String)
	case runtimeExited(status: Int32, log: URL)

	var errorDescription: String? {
		switch self {
		case .gameNotInstalled:
			"Arknights.exe was not found in the install folder. Install the game or locate an existing installation."
		case .wineRuntimeMissing:
			"No compatible Windows runtime found. Use a build that bundles Wine + DXMT."
		case .rosettaMissing:
			"Rosetta 2 is required to run the bundled Wine runtime. Install it by running \"softwareupdate --install-rosetta --agree-to-license\" in Terminal, then check again."
		case .rosettaDisabledByGameTestMode:
			"On macOS 27 beta, Legacy Game Test Mode disables the Rosetta translation required by Wine. Run \"sudo game-test-tool disable\" in Terminal, restart your Mac, then check again."
		case .intelTranslationUnavailable:
			"macOS could not start the Intel-based Wine runtime. Check that Rosetta 2 is installed and restart your Mac before trying again."
		case .intelTranslationUnsupported:
			"The launcher currently blocks this macOS version. Apple retains Rosetta only for certain legacy games, and whether this Wine and game setup qualifies is unconfirmed."
		case .runtimeWindowTimeout:
			"Arknights did not open a window within \(Self.windowTimeoutText). Check the Wine log in Settings and try again."
		case .runtimeConfiguration:
			"The Windows runtime could not complete the operation. Check the Wine log in Settings and try again."
		case .gameCompatibility:
			"Game-file compatibility setup could not be completed. Repair the game files and try again."
		case .runtimeExited:
			"Arknights closed unexpectedly. Check the Wine log in Settings and try again."
		}
	}

	var diagnosticDescription: String {
		switch self {
		case .gameNotInstalled(let url): "Arknights.exe was not found: \(url.path)"
		case .runtimeConfiguration(let message):
			"The Windows runtime could not be configured: \(message)"
		case .gameCompatibility(let message):
			"Game compatibility setup could not be completed: \(message)"
		case .runtimeExited(let status, let log):
			"The Windows runtime exited with status \(status). See \(log.path)."
		case .wineRuntimeMissing, .rosettaMissing, .rosettaDisabledByGameTestMode,
			.intelTranslationUnavailable, .intelTranslationUnsupported, .runtimeWindowTimeout:
			errorDescription ?? "The operation could not be completed."
		}
	}

	private static var windowTimeoutText: String {
		"\(AppConstants.Timeouts.windowReadiness.components.seconds) seconds"
	}
}
