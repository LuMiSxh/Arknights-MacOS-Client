// SPDX-License-Identifier: MPL-2.0

import Foundation

enum WineRuntimeDiscoveryError: LocalizedError, Sendable {
	case missingRuntime(URL)
	case missingExecutable(URL)
	case unreadableConfiguration(URL, String)
	case invalidConfiguration(URL, String)

	var errorDescription: String? {
		switch self {
		case .missingRuntime(let url):
			"No Windows runtime is installed at \(url.path)."
		case .missingExecutable(let url):
			"The installed Windows runtime executable is missing or not executable: \(url.path)"
		case .unreadableConfiguration(let url, let reason):
			"The installed runtime metadata could not be read at \(url.path): \(reason)"
		case .invalidConfiguration(let url, let reason):
			"The installed runtime metadata is invalid at \(url.path): \(reason)"
		}
	}
}
