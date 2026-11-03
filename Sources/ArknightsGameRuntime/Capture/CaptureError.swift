// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Why a screenshot could not be taken or saved.
package enum CaptureError: LocalizedError, LauncherDiagnosticError, SupportCodeProviding, Sendable {
	case permissionDenied
	case noGameWindow
	case captureFailed(String)
	case saveFailed(String)

	package var errorDescription: String? {
		switch self {
		case .permissionDenied:
			"Screen Recording is off for Arknights Client. Allow it in System Settings."
		case .noGameWindow:
			"The launcher found no game window to capture. Show the game window and try again."
		case .captureFailed:
			"macOS could not capture the game window."
		case .saveFailed:
			"The launcher could not save the screenshot. Check the screenshot folder."
		}
	}

	package var diagnosticDescription: String {
		switch self {
		case .permissionDenied, .noGameWindow: errorDescription ?? "Screenshot failed."
		case .captureFailed(let detail): "Screen capture failed: \(detail)"
		case .saveFailed(let detail): "The screenshot could not be saved: \(detail)"
		}
	}

	package var supportCode: SupportCode? {
		switch self {
		case .permissionDenied: .screenCapturePermissionDenied
		case .noGameWindow: .screenCaptureWindowMissing
		case .captureFailed: nil
		case .saveFailed: .localFileFailed
		}
	}
}
