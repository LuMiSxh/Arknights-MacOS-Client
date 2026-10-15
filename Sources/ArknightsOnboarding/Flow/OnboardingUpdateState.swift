// SPDX-License-Identifier: MPL-2.0

import Foundation

nonisolated enum OnboardingUpdateState: Equatable, Sendable {
	static let checkingTitle = "Checking…"

	case checking
	case current
	case updateRequired(String)
	case checkFailed

	var allowsSetup: Bool {
		switch self {
		case .current, .checkFailed: true
		case .checking, .updateRequired: false
		}
	}
}
