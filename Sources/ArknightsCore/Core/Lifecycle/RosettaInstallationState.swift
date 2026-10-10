// SPDX-License-Identifier: MPL-2.0

import Foundation

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
