// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

package enum CustomizationError: LocalizedError, LauncherDiagnosticError, Sendable {
	case invalidRemoteAsset(URL)
	case invalidPresetImage(URL)
	case invalidCustomImage(URL)
	case cannotEncodeAppIcon
	case cannotSetAppIcon
	case presetServiceFailed(status: Int)
	case presetNetworkFailed(detail: String)

	package var errorDescription: String? {
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
		case .presetServiceFailed:
			"The gallery service returned an error. Try again later."
		case .presetNetworkFailed:
			"The gallery could not be reached. Check your connection and try again."
		}
	}

	package var diagnosticDescription: String {
		switch self {
		case .invalidRemoteAsset(let url):
			"Refused an unsupported remote asset URL: \(url.absoluteString)"
		case .invalidPresetImage(let url):
			"The preset asset is not a supported image or has unsafe dimensions: \(url.absoluteString)"
		case .invalidCustomImage(let url): "The selected file is not a supported image: \(url.path)"
		case .presetServiceFailed(let status):
			"The preset service returned HTTP status \(status)."
		case .presetNetworkFailed(let detail):
			"The preset service could not be reached: \(detail)"
		case .cannotEncodeAppIcon, .cannotSetAppIcon:
			errorDescription ?? "The operation could not be completed."
		}
	}
}

extension CustomizationError: SupportCodeProviding {
	package var supportCode: SupportCode? {
		switch self {
		case .cannotEncodeAppIcon, .cannotSetAppIcon:
			.appIconFailed
		case .presetServiceFailed:
			.serviceError
		case .presetNetworkFailed:
			.networkUnavailable
		case .invalidRemoteAsset, .invalidPresetImage, .invalidCustomImage:
			nil
		}
	}
}
