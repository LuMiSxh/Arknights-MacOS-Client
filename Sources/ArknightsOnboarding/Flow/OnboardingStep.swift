// SPDX-License-Identifier: MPL-2.0

import Foundation

// Raw values start at 10 so a step saved by 0.6.1, which used 0 through 6, never decodes and
// setup resumes at the system check instead of landing on an unrelated question.
/// Which way a step change travels, so the page transition and Back agree.
nonisolated enum OnboardingTravelDirection: Sendable {
	case forward
	case backward
}

nonisolated enum OnboardingStep: Int, CaseIterable, Codable, Identifiable, Sendable {
	case welcome = 10
	case region = 11
	// Added after the 0.8.0 steps, so a saved step keeps its meaning. Setup 1.0 reuses raw
	// value 16 for Install, so a step saved on the old Runtime step resumes there.
	case install = 16
	case display = 12
	case look = 13
	case extras = 14
	case finish = 15

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .welcome: "System Check"
		case .region: "Server"
		case .install: "Install"
		case .display: "Display"
		case .look: "Look"
		case .extras: "Updates and Integrations"
		case .finish: "Ready"
		}
	}

	var systemImage: String {
		switch self {
		case .welcome: "checkmark.shield"
		case .region: "globe"
		case .install: "shippingbox"
		case .display: "display"
		case .look: "paintbrush"
		case .extras: "slider.horizontal.3"
		case .finish: "flag.checkered"
		}
	}

	var next: OnboardingStep? {
		guard let index = Self.allCases.firstIndex(of: self) else { return nil }
		return Self.allCases.dropFirst(index + 1).first
	}

	var previous: OnboardingStep? {
		guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
		return Self.allCases[index - 1]
	}
}
