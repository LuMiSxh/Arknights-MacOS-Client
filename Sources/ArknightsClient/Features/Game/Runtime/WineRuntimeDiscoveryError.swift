// SPDX-License-Identifier: MPL-2.0

import Foundation

enum WineRuntimeDiscoveryError: LocalizedError, Sendable {
	case missingResourceDirectory
	case missingExecutable(URL)
	case unreadableConfiguration(URL, String)
	case invalidConfiguration(URL, String)

	var errorDescription: String? {
		switch self {
		case .missingResourceDirectory:
			"The app bundle has no resource directory."
		case .missingExecutable(let url):
			"The bundled Windows runtime executable is missing or not executable: \(url.path)"
		case .unreadableConfiguration(let url, let reason):
			"The bundled runtime metadata could not be read at \(url.path): \(reason)"
		case .invalidConfiguration(let url, let reason):
			"The bundled runtime metadata is invalid at \(url.path): \(reason)"
		}
	}
}
