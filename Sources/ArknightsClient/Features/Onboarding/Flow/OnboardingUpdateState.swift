// SPDX-License-Identifier: MPL-2.0

import Foundation

enum OnboardingUpdateState: Equatable, Sendable {
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
