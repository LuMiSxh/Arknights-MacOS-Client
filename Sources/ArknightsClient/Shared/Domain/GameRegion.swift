// SPDX-License-Identifier: MPL-2.0

import Foundation

enum GameRegion: String, CaseIterable, Codable, Sendable, Identifiable {
	case global
	case japan
	case korea
	case china

	static let allCases: [GameRegion] = [.global, .japan, .korea, .china]
	static let yostarCases: [GameRegion] = [.global, .japan, .korea]

	static func selectableCases(canaryEnabled: Bool) -> [GameRegion] {
		canaryEnabled ? allCases : yostarCases
	}

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .china: "China (Canary)"
		}
	}

	var localizedDisplayName: String {
		L10n.string(SharedStrings.region(self))
	}

	/// Matches the `game_tag` the Yostar launcher API expects and, by convention in this
	/// codebase, the install directory name the official client uses for the region.
	var gameTag: String {
		switch self {
		case .global: "Arknights_EN"
		case .japan: "Arknights_JP"
		case .korea: "Arknights_KR"
		case .china: "Arknights_CN"
		}
	}

	var apiBaseURL: URL {
		switch self {
		case .global: URL(string: "https://api-launcher-en.yo-star.com")!
		case .japan: URL(string: "https://api-launcher-jp.yo-star.com")!
		case .korea: URL(string: "https://api-launcher-kr.yo-star.com")!
		case .china: preconditionFailure("China has no Yostar launcher API")
		}
	}

	var installDirectoryName: String {
		switch self {
		case .global: "Arknights-Global"
		case .japan: "Arknights-Japan"
		case .korea: "Arknights-Korea"
		case .china: "Arknights-China"
		}
	}
}
