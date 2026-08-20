// SPDX-License-Identifier: MPL-2.0

import Foundation

enum OnboardingStep: Int, CaseIterable, Codable, Identifiable, Sendable {
	case welcome
	case installation
	case game
	case personalization
	case icons
	case extras
	case finish

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .welcome: "Preflight"
		case .installation: "Region & Install"
		case .game: "Game Display"
		case .personalization: "Launcher"
		case .icons: "Icons"
		case .extras: "Updates & Audio"
		case .finish: "Ready"
		}
	}

	var systemImage: String {
		switch self {
		case .welcome: "checkmark.shield"
		case .installation: "arrow.down.app"
		case .game: "display"
		case .personalization: "paintbrush"
		case .icons: "app.dashed"
		case .extras: "slider.horizontal.3"
		case .finish: "flag.checkered"
		}
	}

	var next: OnboardingStep? {
		OnboardingStep(rawValue: rawValue + 1)
	}

	var previous: OnboardingStep? {
		OnboardingStep(rawValue: rawValue - 1)
	}
}
