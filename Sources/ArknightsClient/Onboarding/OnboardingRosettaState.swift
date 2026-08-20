// SPDX-License-Identifier: MPL-2.0

import Foundation

enum OnboardingRosettaState: Equatable, Sendable {
	case pending
	case available
	case missing
}
