// SPDX-License-Identifier: MPL-2.0

import Foundation

enum GameRegion: String, CaseIterable, Codable, Sendable, Identifiable {
	case global
	case japan
	case korea
	case china
	case chinaBilibili

	static let allCases: [GameRegion] = [.global, .japan, .korea, .china, .chinaBilibili]
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
		case .chinaBilibili: "China — Bilibili (Canary)"
		}
	}

	var isChinaClient: Bool { self == .china || self == .chinaBilibili }

	var localizedDisplayName: String {
		L10n.string(SharedStrings.region(self))
	}

	/// Matches the `game_tag` the Yostar launcher API expects.
	var gameTag: String {
		switch self {
		case .global: "Arknights_EN"
		case .japan: "Arknights_JP"
		case .korea: "Arknights_KR"
		case .china: "Arknights_CN"
		case .chinaBilibili: "Arknights_CN_Bilibili"
		}
	}

	var apiBaseURL: URL {
		switch self {
		case .global: URL(string: "https://api-launcher-en.yo-star.com")!
		case .japan: URL(string: "https://api-launcher-jp.yo-star.com")!
		case .korea: URL(string: "https://api-launcher-kr.yo-star.com")!
		case .china, .chinaBilibili:
			preconditionFailure("China has no Yostar launcher API")
		}
	}

}
