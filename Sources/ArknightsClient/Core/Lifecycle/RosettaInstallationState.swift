// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RosettaInstallationState: Equatable, Sendable {
	case idle
	case installing
	case failed(String)

	var isInstalling: Bool {
		self == .installing
	}

	var failureMessage: String? {
		guard case .failed(let message) = self else { return nil }
		return message
	}
}
