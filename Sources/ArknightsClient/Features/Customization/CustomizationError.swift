// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Failures raised while loading remote artwork and applying custom images or app icons.
enum CustomizationError: LocalizedError, LauncherDiagnosticError, Sendable {
	case invalidRemoteAsset(URL)
	case invalidPresetImage(URL)
	case invalidCustomImage(URL)
	case cannotEncodeAppIcon
	case cannotSetAppIcon

	var errorDescription: String? {
		switch self {
		case .invalidRemoteAsset:
			"The requested content uses an unsupported download address. Check for a launcher update and try again."
		case .invalidPresetImage:
			"The gallery image could not be used. Choose another image."
		case .invalidCustomImage:
			"The selected file is not a supported image. Choose another image."
		case .cannotEncodeAppIcon:
			"The selected image could not be converted into an app icon."
		case .cannotSetAppIcon:
			"macOS refused to update the app icon."
		}
	}

	var diagnosticDescription: String {
		switch self {
		case .invalidRemoteAsset(let url):
			"Refused an unsupported remote asset URL: \(url.absoluteString)"
		case .invalidPresetImage(let url):
			"The preset asset is not a supported image or has unsafe dimensions: \(url.absoluteString)"
		case .invalidCustomImage(let url): "The selected file is not a supported image: \(url.path)"
		case .cannotEncodeAppIcon, .cannotSetAppIcon:
			errorDescription ?? "The operation could not be completed."
		}
	}
}
