// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Raw values start at 10 so a step saved by 0.6.1, which used 0 through 6, never decodes and
/// setup resumes at the system check instead of landing on an unrelated question.
enum OnboardingStep: Int, CaseIterable, Codable, Identifiable, Sendable {
	case welcome = 10
	case region = 11
	case display = 12
	case look = 13
	case extras = 14
	case finish = 15

	var id: Int { rawValue }

	var systemImage: String {
		switch self {
		case .welcome: "checkmark.shield"
		case .region: "globe"
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
